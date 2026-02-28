-- AuraRows: Core — layout engine, hooks, init, slash commands, events
local ADDON_NAME, ns = ...

local db
local viewer
local hookedFrames = {}
local pendingLayout = false
local mixinHooksInstalled = false
local hooksInstalled = false
local layoutTimer = nil
local VERSION

-- ---------------------------------------------------------------------------
-- Layout — positions visible icons in a multi-row grid and sizes the viewer
-- ---------------------------------------------------------------------------

local visibleBuf = {}

local function ApplyLayout()
    if not viewer then return end
    if InCombatLockdown() then
        pendingLayout = true
        return
    end

    -- Collect visible icon children
    wipe(visibleBuf)
    local children = { viewer:GetChildren() }
    local n = 0
    for i = 1, #children do
        local child = children[i]
        if child.cooldownID and child:IsShown() then
            n = n + 1
            visibleBuf[n] = child
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
    local numCols = math.min(maxPerRow, totalIcons)
    local numRows = math.ceil(totalIcons / maxPerRow)
    local fullRowWidth = numCols * (iconW + spacing) - spacing

    -- Position each icon in the grid
    for i = 1, n do
        local frame = visibleBuf[i]
        local idx = i - 1
        local col = idx % maxPerRow
        local row = math.floor(idx / maxPerRow)

        -- Shift incomplete last rows for center/right alignment
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
    local totalW = (numCols * (iconW + spacing) - spacing) * scale
    local totalH = (numRows * (iconH + spacing) - spacing) * scale
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

local function HookFrame(frame)
    if hookedFrames[frame] then return end
    hookedFrames[frame] = true

    -- Intercept Blizzard repositioning and enforce our cached grid position
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

    -- Visibility changes (SetIsActive → SetShown) can flip icons without
    -- triggering Layout() or SetCooldownID — catch those too.
    hooksecurefunc(frame, "Show", function(self)
        if self:GetParent() == viewer then ScheduleLayout() end
    end)
    hooksecurefunc(frame, "Hide", function(self)
        if self:GetParent() == viewer then ScheduleLayout() end
    end)
end

-- ---------------------------------------------------------------------------
-- Mixin hooks — catch new frames, cooldown changes, and CDM settings updates
-- ---------------------------------------------------------------------------

local function InstallMixinHooks()
    if mixinHooksInstalled then return end
    mixinHooksInstalled = true

    -- Hook new icon frame acquisition (fires when Blizzard creates/recycles icons)
    if CooldownViewerMixin and CooldownViewerMixin.OnAcquireItemFrame then
        hooksecurefunc(CooldownViewerMixin, "OnAcquireItemFrame", function(self, frame)
            if self ~= viewer then return end
            HookFrame(frame)
            ScheduleLayout()
        end)
    end

    -- Hook cooldown assignment/removal (triggers relayout when buffs change)
    if CooldownViewerItemDataMixin then
        local function IsOurFrame(frame)
            local parent = frame and frame:GetParent()
            return parent == viewer
        end

        if CooldownViewerItemDataMixin.SetCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "SetCooldownID", function(self)
                if IsOurFrame(self) then ScheduleLayout() end
            end)
        end
        if CooldownViewerItemDataMixin.ClearCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "ClearCooldownID", function(self)
                if IsOurFrame(self) then ScheduleLayout() end
            end)
        end
    end

    -- Relayout when CDM settings change (icon size, padding, etc.)
    if EventRegistry then
        EventRegistry:RegisterCallback(
            "CooldownViewerSettings.OnDataChanged",
            ScheduleLayout,
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

        -- Hide Blizzard's "Icon Direction" setting — our Align dropdown replaces it
        local origShouldShow = viewer.ShouldShowSetting
        if origShouldShow then
            viewer.ShouldShowSetting = function(self, settingID)
                if settingID == Enum.EditModeCooldownViewerSetting.IconDirection then
                    return false
                end
                return origShouldShow(self, settingID)
            end
            viewer._arShouldShowPatched = true
        end

        -- Override Blizzard's C++ GridLayoutFrame engine with our grid layout
        viewer.Layout = function(self)
            ScheduleLayout()
        end

        -- Hook all existing children
        local children = { viewer:GetChildren() }
        for _, child in ipairs(children) do
            HookFrame(child)
        end

        ApplyLayout()
    end)

    if not ok then
        hooksInstalled = false
        print("|cffff6600AuraRows:|r Hook installation failed — layout disabled.")
    end
end

-- ---------------------------------------------------------------------------
-- Deferred init — polls for BuffIconCooldownViewer (may not exist immediately)
-- ---------------------------------------------------------------------------

local function TryInit()
    -- Handle viewer recreation across loading screens
    local newViewer = _G["BuffIconCooldownViewer"]
    if newViewer and newViewer ~= viewer then
        viewer = newViewer
        ns.viewer = viewer
        hooksInstalled = false
        wipe(hookedFrames)
        InstallHooks()
        if ns.SetupEditMode then ns.SetupEditMode() end
        return
    end
    if viewer then return end

    -- Poll every 0.5s for up to 10s until the viewer appears
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(0.5, function()
        attempts = attempts + 1
        local found = _G["BuffIconCooldownViewer"]
        if found then
            viewer = found
            ns.viewer = viewer
            ticker:Cancel()
            InstallHooks()
            if ns.SetupEditMode then ns.SetupEditMode() end
        elseif attempts >= 20 then
            ticker:Cancel()
            print("|cffff6600AuraRows:|r BuffIconCooldownViewer not found. Is the Cooldown Manager enabled?")
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Slash commands — /aurarows or /ar
-- ---------------------------------------------------------------------------

local function RegisterSlashCommands()
    SLASH_AURAROWS1 = "/aurarows"
    SLASH_AURAROWS2 = "/ar"

    SlashCmdList["AURAROWS"] = function(msg)
        local cmd, arg = msg:match("^(%S+)%s*(.*)")
        cmd = cmd and cmd:lower() or msg:lower()

        if cmd == "rows" or cmd == "perrow" then
            local n = tonumber(arg)
            if n and n >= 1 and n <= 40 then
                db.maxPerRow = math.floor(n)
                print("|cff00ccffAuraRows:|r Icons per row set to " .. db.maxPerRow)
                ApplyLayout()
            else
                print("|cff00ccffAuraRows:|r Usage: /ar rows <1-40>")
            end
        elseif cmd == "grow" or cmd == "direction" then
            local dir = arg:upper()
            if dir == "UP" or dir == "DOWN" then
                db.growDirection = dir
                print("|cff00ccffAuraRows:|r Growth set to " .. ns.DIRECTION_DISPLAY[dir])
                ApplyLayout()
            else
                print("|cff00ccffAuraRows:|r Usage: /ar grow <up|down>")
            end
        elseif cmd == "align" then
            local a = arg:upper()
            if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                db.align = a
                print("|cff00ccffAuraRows:|r Alignment set to " .. ns.ALIGN_DISPLAY[a])
                ApplyLayout()
            else
                print("|cff00ccffAuraRows:|r Usage: /ar align <left|center|right>")
            end
        else
            print("|cff00ccffAuraRows|r v" .. (VERSION or "?"))
            local dirDisplay = ns.DIRECTION_DISPLAY[db.growDirection]
            local alignDisplay = ns.ALIGN_DISPLAY[db.align]
            print("  Current: " .. db.maxPerRow .. " per row, grow " .. dirDisplay .. ", align " .. alignDisplay)
            print("  /ar rows <1-40>              - Icons per row")
            print("  /ar grow <up|down>           - Row growth direction")
            print("  /ar align <left|center|right> - Row alignment")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events — ADDON_LOADED (init DB), PLAYER_ENTERING_WORLD (find viewer),
--          PLAYER_REGEN_ENABLED (flush deferred layout after combat)
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not AuraRowsDB then
            AuraRowsDB = {}
        end
        for k, v in pairs(ns.DEFAULTS) do
            if AuraRowsDB[k] == nil then
                AuraRowsDB[k] = v
            end
        end
        db = AuraRowsDB
        ns.db = db
        VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        RegisterSlashCommands()
    elseif event == "PLAYER_ENTERING_WORLD" then
        TryInit()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingLayout then
            pendingLayout = false
            ApplyLayout()
        end
    end
end)
