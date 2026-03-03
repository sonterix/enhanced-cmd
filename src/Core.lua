-- Enhanced CDM: Core — layout engine, hooks, init, slash commands, events
local ADDON_NAME, ns = ...

local db
local viewer
local hookedFrames = {}
local mixinHooksInstalled = false
local hooksInstalled = false
local layoutTimer = nil
local VERSION

local barViewer
local barHookedFrames = {}
local barHooksInstalled = false
local barLayoutTimer = nil

-- ---------------------------------------------------------------------------
-- Layout — positions visible icons in a multi-row grid and sizes the viewer
-- ---------------------------------------------------------------------------

local visibleBuf = {}
local HookFrame  -- forward declaration; defined after ScheduleLayout

local barVisibleBuf = {}
local HookBarFrame  -- forward declaration; defined after ScheduleBarsLayout

local function ApplyLayout()
    if not viewer then return end

    -- Collect icon children based on layout mode
    -- Static: all icons (preserves fixed grid positions even when hidden)
    -- Dynamic: only visible icons (packs tightly, no gaps)
    local isDynamic = (db.layout == "DYNAMIC")
    wipe(visibleBuf)
    local children = { viewer:GetChildren() }
    local n = 0
    local withCooldownID = 0
    for i = 1, #children do
        local child = children[i]
        HookFrame(child)  -- idempotent; catches frames created after init
        if child.cooldownID then
            withCooldownID = withCooldownID + 1
            if not isDynamic or child:IsShown() then
                n = n + 1
                visibleBuf[n] = child
            end
        end
    end

    if n == 0 then return end

    -- Sort by Blizzard's layout ordering
    table.sort(visibleBuf, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local maxPerRow = db.maxPerRow
    local growDown = (db.growDirection == "DOWN")
    local align = db.align

    local scale = visibleBuf[1]:GetScale()
    if scale < 0.01 then scale = 1 end

    -- SetPoint offsets are in the CHILD's coordinate space and get multiplied
    -- by the child's scale automatically.  Use unscaled dimensions for
    -- positioning so coordinates aren't double-scaled.
    local iconW = visibleBuf[1]:GetWidth()
    local iconH = visibleBuf[1]:GetHeight()
    if iconW < 1 then iconW = 36 end
    if iconH < 1 then iconH = 36 end

    -- Blizzard's iconPadding + additional offset gives the native inter-icon gap
    local spacing = 0
    if viewer.iconPadding ~= nil then
        local offset = viewer.GetAdditionalPaddingOffset
            and viewer:GetAdditionalPaddingOffset() or -4
        spacing = viewer.iconPadding + offset
    end

    local totalIcons = n
    local numRows = math.ceil(totalIcons / maxPerRow)
    -- Keep viewer at full maxPerRow width so the container stays fixed
    -- regardless of how many icons are currently visible
    local refCols = maxPerRow
    local refRows = isDynamic and math.max(numRows, math.ceil(withCooldownID / maxPerRow)) or numRows
    local fullRowWidth = refCols * (iconW + spacing) - spacing

    -- Position each icon in the grid
    for i = 1, n do
        local frame = visibleBuf[i]
        local idx = i - 1
        local col = idx % maxPerRow
        local row = math.floor(idx / maxPerRow)

        -- Shift incomplete rows for center/right alignment
        local alignOffset = 0
        if align ~= "LEFT" then
            local rowStart = row * maxPerRow
            local iconsOnRow = math.min(maxPerRow, totalIcons - rowStart)
            local rowWidth = iconsOnRow * (iconW + spacing) - spacing
            if align == "CENTER" then
                alignOffset = (fullRowWidth - rowWidth) / 2
            elseif align == "RIGHT" then
                alignOffset = fullRowWidth - rowWidth
            end
        end

        local x = alignOffset + col * (iconW + spacing)
        local y = row * (iconH + spacing)

        -- Cache target position for the SetPoint hook to enforce
        frame._arTargetX = x
        frame._arTargetY = y
        frame._arSettingPos = true
        frame:ClearAllPoints()
        if growDown then
            frame:SetPoint("TOPLEFT", viewer, "TOPLEFT", x, -y)
        else
            frame:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", x, y)
        end
        frame._arSettingPos = false
    end

    -- Viewer size is in the viewer's own coordinate space (not child-scaled),
    -- so scale up the unscaled grid dimensions.
    local totalW = (refCols * (iconW + spacing) - spacing) * scale
    local totalH = (refRows * (iconH + spacing) - spacing) * scale
    if totalW > 0 and totalH > 0 then
        viewer:SetSize(totalW, totalH)
    end
end

-- ---------------------------------------------------------------------------
-- Debounced scheduling — batches rapid triggers into a single next-frame layout
-- ---------------------------------------------------------------------------

local function ScheduleLayout()
    if layoutTimer then layoutTimer:Cancel() end

    layoutTimer = C_Timer.NewTimer(0, function()
        layoutTimer = nil
        ApplyLayout()
    end)
end

ns.ApplyLayout = ApplyLayout
ns.ScheduleLayout = ScheduleLayout

-- ---------------------------------------------------------------------------
-- Per-frame hook — overrides Blizzard's SetPoint and relayouts on show/hide
-- ---------------------------------------------------------------------------

HookFrame = function(frame)
    if hookedFrames[frame] then return end
    hookedFrames[frame] = true

    -- Intercept Blizzard repositioning and enforce our cached grid position
    -- CDM children are not protected — SetPoint is safe during combat
    hooksecurefunc(frame, "SetPoint", function(self)
        if self._arSettingPos then return end
        if not self._arTargetX then return end
        if self:GetParent() ~= viewer then return end

        local growDown = (db.growDirection == "DOWN")
        self._arSettingPos = true
        self:ClearAllPoints()
        if growDown then
            self:SetPoint("TOPLEFT", viewer, "TOPLEFT", self._arTargetX, -self._arTargetY)
        else
            self:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", self._arTargetX, self._arTargetY)
        end
        self._arSettingPos = false
    end)

    -- Show/hide changes visible count in dynamic mode — relayout needed
    -- Use HookScript (fires on any visibility change) not hooksecurefunc
    -- (only fires on explicit Lua Show/Hide calls)
    frame:HookScript("OnShow", function(self)
        if self:GetParent() ~= viewer then return end
        ScheduleLayout()
    end)
    frame:HookScript("OnHide", function(self)
        if self:GetParent() ~= viewer then return end
        ScheduleLayout()
    end)

end

-- ---------------------------------------------------------------------------
-- Bars layout — positions bar children in a vertical column or horizontal grid
-- ---------------------------------------------------------------------------

local function ApplyBarsLayout()
    if not barViewer then return end

    local isDynamic = (db.bars_layout == "DYNAMIC")
    local isHorizontal = (db.bars_orientation == "HORIZONTAL")

    wipe(barVisibleBuf)
    local children = { barViewer:GetChildren() }
    local n = 0
    local withCooldownID = 0
    for i = 1, #children do
        local child = children[i]
        HookBarFrame(child)
        if child.cooldownID then
            withCooldownID = withCooldownID + 1
            if not isDynamic or child:IsShown() then
                n = n + 1
                barVisibleBuf[n] = child
            end
        end
    end

    if n == 0 then return end

    table.sort(barVisibleBuf, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local scale = barVisibleBuf[1]:GetScale()
    if scale < 0.01 then scale = 1 end

    local barW = barVisibleBuf[1]:GetWidth()
    local barH = barVisibleBuf[1]:GetHeight()
    if barW < 1 then barW = 220 end
    if barH < 1 then barH = 30 end

    local spacing = 0
    if barViewer.iconPadding ~= nil then
        local offset = barViewer.GetAdditionalPaddingOffset
            and barViewer:GetAdditionalPaddingOffset() or -4
        spacing = barViewer.iconPadding + offset
    end

    local align = db.bars_align

    if isHorizontal then
        -- Multi-row grid (wraps at bars_maxPerRow)
        local maxPerRow = db.bars_maxPerRow
        local totalBars = n
        local numRows = math.ceil(totalBars / maxPerRow)
        local refCols = maxPerRow
        local refRows = isDynamic and math.max(numRows, math.ceil(withCooldownID / maxPerRow)) or numRows
        local fullRowWidth = refCols * (barW + spacing) - spacing

        for i = 1, n do
            local frame = barVisibleBuf[i]
            local idx = i - 1
            local col = idx % maxPerRow
            local row = math.floor(idx / maxPerRow)

            local alignOffset = 0
            if isDynamic and align ~= "LEFT" then
                local rowStart = row * maxPerRow
                local barsOnRow = math.min(maxPerRow, totalBars - rowStart)
                local rowWidth = barsOnRow * (barW + spacing) - spacing
                if align == "CENTER" then
                    alignOffset = (fullRowWidth - rowWidth) / 2
                elseif align == "RIGHT" then
                    alignOffset = fullRowWidth - rowWidth
                end
            end

            local x = alignOffset + col * (barW + spacing)
            local y = row * (barH + spacing)

            frame._arTargetX = x
            frame._arTargetY = y
            frame._arSettingPos = true
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", barViewer, "TOPLEFT", x, -y)
            frame._arSettingPos = false
        end

        local totalW = (refCols * (barW + spacing) - spacing) * scale
        local totalH = (refRows * (barH + spacing) - spacing) * scale
        if totalW > 0 and totalH > 0 then
            barViewer:SetSize(totalW, totalH)
        end
    else
        -- Single column (vertical)
        local refRows = isDynamic and math.max(n, withCooldownID) or n
        local growDown = (align ~= "UP") -- DOWN is default / static behavior

        for i = 1, n do
            local frame = barVisibleBuf[i]
            local row = i - 1
            local y = row * (barH + spacing)

            frame._arTargetX = 0
            frame._arTargetY = y
            frame._arSettingPos = true
            frame:ClearAllPoints()
            if growDown or not isDynamic then
                frame:SetPoint("TOPLEFT", barViewer, "TOPLEFT", 0, -y)
            else
                frame:SetPoint("BOTTOMLEFT", barViewer, "BOTTOMLEFT", 0, y)
            end
            frame._arSettingPos = false
        end

        local totalW = barW * scale
        local totalH = (refRows * (barH + spacing) - spacing) * scale
        if totalW > 0 and totalH > 0 then
            barViewer:SetSize(totalW, totalH)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Bars debounced scheduling
-- ---------------------------------------------------------------------------

local function ScheduleBarsLayout()
    if barLayoutTimer then barLayoutTimer:Cancel() end

    barLayoutTimer = C_Timer.NewTimer(0, function()
        barLayoutTimer = nil
        ApplyBarsLayout()
    end)
end

ns.ApplyBarsLayout = ApplyBarsLayout
ns.ScheduleBarsLayout = ScheduleBarsLayout

-- ---------------------------------------------------------------------------
-- Per-bar-frame hook — overrides Blizzard's SetPoint and relayouts on show/hide
-- ---------------------------------------------------------------------------

HookBarFrame = function(frame)
    if barHookedFrames[frame] then return end
    barHookedFrames[frame] = true

    hooksecurefunc(frame, "SetPoint", function(self)
        if self._arSettingPos then return end
        if not self._arTargetX then return end
        if self:GetParent() ~= barViewer then return end

        local isHorizontal = (db.bars_orientation == "HORIZONTAL")
        local growDown = isHorizontal or (db.bars_align ~= "UP") or (db.bars_layout ~= "DYNAMIC")

        self._arSettingPos = true
        self:ClearAllPoints()
        if growDown then
            self:SetPoint("TOPLEFT", barViewer, "TOPLEFT", self._arTargetX, -self._arTargetY)
        else
            self:SetPoint("BOTTOMLEFT", barViewer, "BOTTOMLEFT", self._arTargetX, self._arTargetY)
        end
        self._arSettingPos = false
    end)

    frame:HookScript("OnShow", function(self)
        if self:GetParent() ~= barViewer then return end
        ScheduleBarsLayout()
    end)
    frame:HookScript("OnHide", function(self)
        if self:GetParent() ~= barViewer then return end
        ScheduleBarsLayout()
    end)
end

-- ---------------------------------------------------------------------------
-- Mixin hooks — catch new frames, cooldown changes, and CDM settings updates
-- ---------------------------------------------------------------------------

local function InstallMixinHooks()
    if mixinHooksInstalled then return end
    mixinHooksInstalled = true

    -- Hook new frame acquisition (fires when Blizzard creates/recycles frames)
    if CooldownViewerMixin and CooldownViewerMixin.OnAcquireItemFrame then
        hooksecurefunc(CooldownViewerMixin, "OnAcquireItemFrame", function(self, frame)
            if self == viewer then
                HookFrame(frame)
                ScheduleLayout()
            elseif self == barViewer then
                HookBarFrame(frame)
                ScheduleBarsLayout()
            end
        end)
    end

    -- Hook cooldown assignment/removal (triggers relayout when buffs change)
    if CooldownViewerItemDataMixin then
        local function DispatchSchedule(frame)
            local parent = frame and frame:GetParent()
            if parent == viewer then
                ScheduleLayout()
            elseif parent == barViewer then
                ScheduleBarsLayout()
            end
        end

        if CooldownViewerItemDataMixin.SetCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "SetCooldownID", function(self)
                DispatchSchedule(self)
            end)
        end
        if CooldownViewerItemDataMixin.ClearCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "ClearCooldownID", function(self)
                DispatchSchedule(self)
            end)
        end
    end

    -- Relayout when CDM settings change (icon size, padding, etc.)
    if EventRegistry then
        EventRegistry:RegisterCallback(
            "CooldownViewerSettings.OnDataChanged",
            function()
                ScheduleLayout()
                ScheduleBarsLayout()
            end,
            ADDON_NAME
        )
    end
end

-- ---------------------------------------------------------------------------
-- Hook installation — patches the viewer instance once it's found
-- ---------------------------------------------------------------------------

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    local ok, err = pcall(function()
        InstallMixinHooks()

        -- Hook Blizzard's layout engine — let the original run untainted, then
        -- schedule our grid repositioning for the next frame.
        hooksecurefunc(viewer, "Layout", function()
            ScheduleLayout()
        end)

        -- Hook all existing children
        local children = { viewer:GetChildren() }
        for _, child in ipairs(children) do
            HookFrame(child)
        end

        ApplyLayout()
    end)

    if not ok then
        hooksInstalled = false
        print("|cffff6600Enhanced CDM:|r Hook installation failed — layout disabled.")
    end
end

-- ---------------------------------------------------------------------------
-- Bar hook installation — patches the bar viewer instance once it's found
-- ---------------------------------------------------------------------------

local function InstallBarsHooks()
    if barHooksInstalled then return end
    barHooksInstalled = true

    local ok, err = pcall(function()
        InstallMixinHooks()

        hooksecurefunc(barViewer, "Layout", function()
            ScheduleBarsLayout()
        end)

        local children = { barViewer:GetChildren() }
        for _, child in ipairs(children) do
            HookBarFrame(child)
        end

        ApplyBarsLayout()
    end)

    if not ok then
        barHooksInstalled = false
        print("|cffff6600Enhanced CDM:|r Bar hook installation failed — bars layout disabled.")
    end
end

-- ---------------------------------------------------------------------------
-- Deferred init — polls for both viewers (may not exist immediately)
-- ---------------------------------------------------------------------------

local function TryInit()
    -- Handle viewer recreation across loading screens
    local newViewer = _G["BuffIconCooldownViewer"]
    local newBarViewer = _G["BuffBarCooldownViewer"]
    local needEditMode = false

    if newViewer and newViewer ~= viewer then
        viewer = newViewer
        ns.viewer = viewer
        hooksInstalled = false
        wipe(hookedFrames)
        InstallHooks()
        needEditMode = true
    end

    if newBarViewer and newBarViewer ~= barViewer then
        barViewer = newBarViewer
        ns.barViewer = barViewer
        barHooksInstalled = false
        wipe(barHookedFrames)
        InstallBarsHooks()
        needEditMode = true
    end

    if needEditMode then
        if ns.SetupEditMode then ns.SetupEditMode() end
    end

    -- Both already found — nothing to do
    if viewer and barViewer then return end

    -- Poll every 0.5s for up to 10s until both viewers appear
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(0.5, function()
        attempts = attempts + 1
        local foundNew = false

        local foundViewer = _G["BuffIconCooldownViewer"]
        if foundViewer and not viewer then
            viewer = foundViewer
            ns.viewer = viewer
            InstallHooks()
            foundNew = true
        end

        local foundBarViewer = _G["BuffBarCooldownViewer"]
        if foundBarViewer and not barViewer then
            barViewer = foundBarViewer
            ns.barViewer = barViewer
            InstallBarsHooks()
            foundNew = true
        end

        if foundNew then
            if ns.SetupEditMode then ns.SetupEditMode() end
        end

        if (viewer and barViewer) or attempts >= 20 then
            ticker:Cancel()
            if not viewer and not barViewer then
                print("|cffff6600Enhanced CDM:|r No CDM viewers found. Is the Cooldown Manager enabled?")
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Slash commands — /enhancedcdm or /ecdm
-- ---------------------------------------------------------------------------

local function RegisterSlashCommands()
    SLASH_ENHANCEDCDM1 = "/enhancedcdm"
    SLASH_ENHANCEDCDM2 = "/ecdm"

    SlashCmdList["ENHANCEDCDM"] = function(msg)
        local cmd, arg = msg:match("^(%S+)%s*(.*)")
        cmd = cmd and cmd:lower() or msg:lower()

        if cmd == "rows" or cmd == "perrow" then
            local n = tonumber(arg)
            if n and n >= 1 and n <= 40 then
                db.maxPerRow = math.floor(n)
                print("|cff00ccffEnhanced CDM:|r Icons per row set to " .. db.maxPerRow)
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm rows <1-40>")
            end
        elseif cmd == "grow" or cmd == "direction" then
            local dir = arg:upper()
            if dir == "UP" or dir == "DOWN" then
                db.growDirection = dir
                print("|cff00ccffEnhanced CDM:|r Growth set to " .. ns.DIRECTION_DISPLAY[dir])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm grow <up|down>")
            end
        elseif cmd == "align" then
            local a = arg:upper()
            if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                db.align = a
                print("|cff00ccffEnhanced CDM:|r Alignment set to " .. ns.ALIGN_DISPLAY[a])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm align <left|center|right>")
            end
        elseif cmd == "layout" then
            local l = arg:upper()
            if l == "STATIC" or l == "DYNAMIC" then
                db.layout = l
                print("|cff00ccffEnhanced CDM:|r Layout set to " .. ns.LAYOUT_DISPLAY[l])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm layout <static|dynamic>")
            end
        elseif cmd == "bars" then
            local subCmd, subArg = arg:match("^(%S+)%s*(.*)")
            subCmd = subCmd and subCmd:lower() or ""

            if subCmd == "orientation" then
                local o = subArg:upper()
                if o == "VERTICAL" or o == "HORIZONTAL" then
                    db.bars_orientation = o
                    if o == "VERTICAL" then
                        db.bars_align = "DOWN"
                        db.bars_maxPerRow = ns.DEFAULTS.bars_maxPerRow
                    elseif o == "HORIZONTAL" then
                        db.bars_align = "CENTER"
                    end
                    print("|cff00ccffEnhanced CDM:|r Bars orientation set to " .. ns.ORIENTATION_DISPLAY[o])
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars orientation <vertical|horizontal>")
                end
            elseif subCmd == "layout" then
                local l = subArg:upper()
                if l == "STATIC" or l == "DYNAMIC" then
                    db.bars_layout = l
                    print("|cff00ccffEnhanced CDM:|r Bars layout set to " .. ns.LAYOUT_DISPLAY[l])
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars layout <static|dynamic>")
                end
            elseif subCmd == "align" then
                local a = subArg:upper()
                if db.bars_orientation == "VERTICAL" then
                    if a == "DOWN" or a == "UP" then
                        db.bars_align = a
                        print("|cff00ccffEnhanced CDM:|r Bars alignment set to " .. ns.BAR_ALIGN_V_DISPLAY[a])
                        ApplyBarsLayout()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars align <up|down>")
                    end
                else
                    if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                        db.bars_align = a
                        print("|cff00ccffEnhanced CDM:|r Bars alignment set to " .. ns.BAR_ALIGN_H_DISPLAY[a])
                        ApplyBarsLayout()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars align <left|center|right>")
                    end
                end
            elseif subCmd == "perrow" then
                local n = tonumber(subArg)
                if n and n >= 1 and n <= 8 then
                    db.bars_maxPerRow = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r Bars per row set to " .. db.bars_maxPerRow)
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars perrow <1-8>")
                end
            else
                local orientDisplay = ns.ORIENTATION_DISPLAY[db.bars_orientation]
                local layoutDisplay = ns.LAYOUT_DISPLAY[db.bars_layout]
                local alignMap = db.bars_orientation == "VERTICAL" and ns.BAR_ALIGN_V_DISPLAY or ns.BAR_ALIGN_H_DISPLAY
                local alignDisplay = alignMap[db.bars_align] or db.bars_align
                print("|cff00ccffEnhanced CDM — Bars:|r " .. orientDisplay .. ", " .. layoutDisplay .. ", align " .. alignDisplay .. ", " .. db.bars_maxPerRow .. " per row")
                print("  /ecdm bars orientation <vertical|horizontal>")
                print("  /ecdm bars layout <static|dynamic>")
                print("  /ecdm bars align <up|down|left|center|right>")
                print("  /ecdm bars perrow <1-8>")
            end
        else
            print("|cff00ccffEnhanced CDM|r v" .. (VERSION or "?"))
            local dirDisplay = ns.DIRECTION_DISPLAY[db.growDirection]
            local alignDisplay = ns.ALIGN_DISPLAY[db.align]
            local layoutDisplay = ns.LAYOUT_DISPLAY[db.layout]
            print("  Icons: " .. db.maxPerRow .. " per row, grow " .. dirDisplay .. ", align " .. alignDisplay .. ", layout " .. layoutDisplay)
            local bOrient = ns.ORIENTATION_DISPLAY[db.bars_orientation]
            local bLayout = ns.LAYOUT_DISPLAY[db.bars_layout]
            local bAlignMap = db.bars_orientation == "VERTICAL" and ns.BAR_ALIGN_V_DISPLAY or ns.BAR_ALIGN_H_DISPLAY
            local bAlign = bAlignMap[db.bars_align] or db.bars_align
            print("  Bars:  " .. bOrient .. ", " .. bLayout .. ", align " .. bAlign .. ", " .. db.bars_maxPerRow .. " per row")
            print("  /ecdm rows <1-40>               - Icons per row")
            print("  /ecdm grow <up|down>             - Row growth direction")
            print("  /ecdm align <left|center|right>  - Row alignment")
            print("  /ecdm layout <static|dynamic>    - Layout mode")
            print("  /ecdm bars                       - Bars settings and commands")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events — ADDON_LOADED (init DB), PLAYER_ENTERING_WORLD (find viewer)
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not EnhancedCDMDB then
            EnhancedCDMDB = {}
        end
        for k, v in pairs(ns.DEFAULTS) do
            if EnhancedCDMDB[k] == nil then
                EnhancedCDMDB[k] = v
            end
        end
        db = EnhancedCDMDB
        ns.db = db
        VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        RegisterSlashCommands()
    elseif event == "PLAYER_ENTERING_WORLD" then
        TryInit()
    end
end)
