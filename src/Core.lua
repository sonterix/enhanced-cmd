-- Enhanced CDM: Core — layout engine, hooks, init, slash commands, events
local ADDON_NAME, ns = ...

local db
local viewer
local hookedFrames = {}
local mixinHooksInstalled = false
local hookState = { installed = false }
local layoutTimer = nil
local VERSION

local barViewer
local barHookedFrames = {}
local barHookState = { installed = false }
local barLayoutTimer = nil

local essentialViewer
local utilityViewer
local slotToBinding = {}
local initTicker = nil

-- ---------------------------------------------------------------------------
-- Keybinding engine — maps spellID → formatted hotkey text
-- ---------------------------------------------------------------------------

-- Action bar frame-name → binding-command-prefix mapping
local ACTION_BAR_BINDINGS = {
    { frame = "ActionButton",             binding = "ACTIONBUTTON" },
    { frame = "MultiBarBottomLeftButton", binding = "MULTIACTIONBAR1BUTTON" },
    { frame = "MultiBarBottomRightButton",binding = "MULTIACTIONBAR2BUTTON" },
    { frame = "MultiBarRightButton",      binding = "MULTIACTIONBAR3BUTTON" },
    { frame = "MultiBarLeftButton",       binding = "MULTIACTIONBAR4BUTTON" },
    { frame = "MultiBar5Button",          binding = "MULTIACTIONBAR5BUTTON" },
    { frame = "MultiBar6Button",          binding = "MULTIACTIONBAR6BUTTON" },
    { frame = "MultiBar7Button",          binding = "MULTIACTIONBAR7BUTTON" },
}

-- Builds slotNumber → bindingCommandName lookup from actual button frames
local function BuildSlotToBindingMap()
    wipe(slotToBinding)
    for _, info in ipairs(ACTION_BAR_BINDINGS) do
        for i = 1, 12 do
            local btn = _G[info.frame .. i]
            if btn then
                local slot = btn:GetAttribute("action")
                    or (btn.GetAction and btn:GetAction())
                    or (btn.action)
                -- Main action bar uses a page-based state driver that may not
                -- be ready during initial login; fall back to button index
                -- which equals the correct slot on page 1.
                if (not slot or slot == 0) and info.frame == "ActionButton" then
                    slot = i
                end
                if slot then
                    slotToBinding[tonumber(slot)] = info.binding .. i
                end
            end
        end
    end
end

-- Abbreviate raw key names for compact display
local function FormatKeyText(key)
    if not key then return nil end
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("BUTTON(%d+)", "M%1")
    key = key:gsub("NUMPAD(%d+)", "N%1")
    key = key:gsub("NUMPADDECIMAL", "N.")
    key = key:gsub("NUMPADPLUS", "N+")
    key = key:gsub("NUMPADMINUS", "N-")
    key = key:gsub("NUMPADMULTIPLY", "N*")
    key = key:gsub("NUMPADDIVIDE", "N/")
    key = key:gsub("PAGEUP", "PU")
    key = key:gsub("PAGEDOWN", "PD")
    key = key:gsub("SPACEBAR", "SP")
    key = key:gsub("BACKSPACE", "BS")
    key = key:gsub("CAPSLOCK", "CAP")
    key = key:gsub("INSERT", "INS")
    key = key:gsub("DELETE", "DEL")
    key = key:gsub("HOME", "HM")
    key = key:gsub("DOWNARROW", "DN")
    key = key:gsub("UPARROW", "UP")
    key = key:gsub("LEFTARROW", "LT")
    key = key:gsub("RIGHTARROW", "RT")
    return key
end

-- Returns formatted hotkey text for a spellID, or nil if not bound
-- When shorten is false, returns the raw key name without abbreviation
local function GetHotkeyText(spellID, shorten)
    if not spellID then return nil end

    -- Try finding action bar slots for this spell
    local slots = C_ActionBar and C_ActionBar.FindSpellActionButtons
        and C_ActionBar.FindSpellActionButtons(spellID)

    -- If not found, try override spell resolution
    if (not slots or #slots == 0) and C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if overrideID and overrideID ~= spellID
            and C_ActionBar and C_ActionBar.FindSpellActionButtons then
            slots = C_ActionBar.FindSpellActionButtons(overrideID)
        end
    end

    if not slots or #slots == 0 then return nil end

    -- Check each slot for a binding (prefer the first one found)
    for _, slot in ipairs(slots) do
        local bindingName = slotToBinding[slot]
        if bindingName then
            local key = GetBindingKey(bindingName)
            if key then
                return shorten and FormatKeyText(key) or key
            end
        end
    end

    return nil
end

-- Returns the settings prefix ("essential_hotkeys_" or "utility_hotkeys_") for a frame
local function GetHotkeyPrefix(frame)
    local parent = frame and frame:GetParent()
    if parent == essentialViewer then
        return "essential_hotkeys_"
    elseif parent == utilityViewer then
        return "utility_hotkeys_"
    end
    return nil
end

-- Create or update the hotkey FontString on a cooldown viewer icon
local function UpdateFrameHotkey(frame)
    if not frame or not db then
        if frame and frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    local prefix = GetHotkeyPrefix(frame)
    if not prefix or not db[prefix .. "show"] then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    -- Get spellID from the frame
    local spellID = (frame.GetBaseSpellID and frame:GetBaseSpellID())
        or frame.rangeCheckSpellID
    if not spellID then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    local shorten = db[prefix .. "shorten"]
    local text = GetHotkeyText(spellID, shorten)
    if not text then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    -- Create an overlay frame above the Cooldown frame so text renders on top of the swipe
    if not frame._ecdmHotkeyText then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        if frame.Cooldown then
            overlay:SetFrameLevel(frame.Cooldown:GetFrameLevel() + 1)
        end
        local fs = overlay:CreateFontString(nil, "OVERLAY")
        fs:SetTextColor(1, 1, 1, 1)
        frame._ecdmHotkeyText = fs
    end

    local fs = frame._ecdmHotkeyText
    local position = db[prefix .. "position"]
    local fontSize = db[prefix .. "fontSize"]
    local anchor = ns.HOTKEY_POSITION_ANCHORS[position]
        or ns.HOTKEY_POSITION_ANCHORS["TOPLEFT"]
    local justify = ns.HOTKEY_POSITION_JUSTIFY[position] or "LEFT"

    fs:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
    fs:ClearAllPoints()
    fs:SetPoint(anchor.point, frame, anchor.point, anchor.x, anchor.y)
    fs:SetJustifyH(justify)
    fs:SetText(text)
    fs:Show()
end

-- Refresh hotkey text on all tracked Essential/Utility children
local function RefreshAllHotkeys()
    BuildSlotToBindingMap()

    local viewers = { essentialViewer, utilityViewer }
    for _, v in ipairs(viewers) do
        if v then
            local children = { v:GetChildren() }
            for _, child in ipairs(children) do
                if child.cooldownID then
                    UpdateFrameHotkey(child)
                end
            end
        end
    end
end

ns.RefreshAllHotkeys = RefreshAllHotkeys

local hotkeyRefreshTimer = nil
local function ScheduleHotkeyRefresh()
    if hotkeyRefreshTimer then hotkeyRefreshTimer:Cancel() end
    hotkeyRefreshTimer = C_Timer.NewTimer(0, function()
        hotkeyRefreshTimer = nil
        RefreshAllHotkeys()
    end)
end

-- ---------------------------------------------------------------------------
-- Grid math — pure position calculation, no frame dependencies
-- ---------------------------------------------------------------------------

-- Calculates the x,y position for icon at 1-based index in a grid.
-- Returns x, y (unscaled pixel offsets from the grid origin).
local function CalcGridPosition(index, maxPerRow, iconW, iconH, spacing, align, totalIcons, fullRowWidth)
    local idx = index - 1
    local col = idx % maxPerRow
    local row = math.floor(idx / maxPerRow)

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
    return x, y
end

-- ---------------------------------------------------------------------------
-- Layout — positions visible icons in a multi-row grid and sizes the viewer
-- ---------------------------------------------------------------------------

local visibleBuf = {}
local HookFrame  -- forward declaration; defined after ScheduleLayout

local barVisibleBuf = {}
local HookBarFrame  -- forward declaration; defined after ScheduleBarsLayout

local function SortByLayoutIndex(a, b)
    return (a.layoutIndex or 0) < (b.layoutIndex or 0)
end

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
    table.sort(visibleBuf, SortByLayoutIndex)

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
        local x, y = CalcGridPosition(i, maxPerRow, iconW, iconH, spacing, align, totalIcons, fullRowWidth)

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

-- Shared hook installer for both icon and bar viewer children.
-- Uses getter functions so hooks always read the current viewer/growDown
-- even after viewer recreation in TryInit.
local function HookViewerChild(frame, hookedSet, getViewer, getGrowDown, scheduleFn)
    if hookedSet[frame] then return end
    hookedSet[frame] = true

    -- Intercept Blizzard repositioning and enforce our cached grid position
    -- CDM children are not protected — SetPoint is safe during combat
    hooksecurefunc(frame, "SetPoint", function(self)
        if self._arSettingPos then return end
        if not self._arTargetX then return end
        local v = getViewer()
        if self:GetParent() ~= v then return end

        self._arSettingPos = true
        self:ClearAllPoints()
        if getGrowDown() then
            self:SetPoint("TOPLEFT", v, "TOPLEFT", self._arTargetX, -self._arTargetY)
        else
            self:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", self._arTargetX, self._arTargetY)
        end
        self._arSettingPos = false
    end)

    -- Show/hide changes visible count in dynamic mode — relayout needed
    -- Use HookScript (fires on any visibility change) not hooksecurefunc
    -- (only fires on explicit Lua Show/Hide calls)
    frame:HookScript("OnShow", function(self)
        if self:GetParent() ~= getViewer() then return end
        scheduleFn()
    end)
    frame:HookScript("OnHide", function(self)
        if self:GetParent() ~= getViewer() then return end
        scheduleFn()
    end)
end

HookFrame = function(frame)
    HookViewerChild(frame, hookedFrames,
        function() return viewer end,
        function() return db.growDirection == "DOWN" end,
        ScheduleLayout)
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

    table.sort(barVisibleBuf, SortByLayoutIndex)

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
-- Per-bar-frame hook — uses shared HookViewerChild with bar-specific config
-- ---------------------------------------------------------------------------

HookBarFrame = function(frame)
    HookViewerChild(frame, barHookedFrames,
        function() return barViewer end,
        function()
            return (db.bars_orientation == "HORIZONTAL")
                or (db.bars_align ~= "UP")
                or (db.bars_layout ~= "DYNAMIC")
        end,
        ScheduleBarsLayout)
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
            elseif self == essentialViewer or self == utilityViewer then
                BuildSlotToBindingMap()
                UpdateFrameHotkey(frame)
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
            elseif parent == essentialViewer or parent == utilityViewer then
                UpdateFrameHotkey(frame)
            end
        end

        local function DispatchClear(frame)
            local parent = frame and frame:GetParent()
            if parent == viewer then
                ScheduleLayout()
            elseif parent == barViewer then
                ScheduleBarsLayout()
            elseif parent == essentialViewer or parent == utilityViewer then
                if frame._ecdmHotkeyText then
                    frame._ecdmHotkeyText:Hide()
                end
            end
        end

        if CooldownViewerItemDataMixin.SetCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "SetCooldownID", function(self)
                DispatchSchedule(self)
            end)
        end
        if CooldownViewerItemDataMixin.ClearCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "ClearCooldownID", function(self)
                DispatchClear(self)
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
                ScheduleHotkeyRefresh()
            end,
            ADDON_NAME
        )
    end
end

-- ---------------------------------------------------------------------------
-- Hook installation — shared installer + per-viewer wrappers
-- ---------------------------------------------------------------------------

local function InstallViewerHooks(state, getViewer, hookChildFn, scheduleFn, applyFn, errorLabel)
    if state.installed then return end
    state.installed = true

    local ok = pcall(function()
        InstallMixinHooks()

        local v = getViewer()
        hooksecurefunc(v, "Layout", function()
            scheduleFn()
        end)

        local children = { v:GetChildren() }
        for _, child in ipairs(children) do
            hookChildFn(child)
        end

        applyFn()
    end)

    if not ok then
        state.installed = false
        print("|cffff6600Enhanced CDM:|r " .. errorLabel)
    end
end

local function InstallHooks()
    InstallViewerHooks(hookState, function() return viewer end,
        HookFrame, ScheduleLayout, ApplyLayout,
        "Hook installation failed — layout disabled.")
end

local function InstallBarsHooks()
    InstallViewerHooks(barHookState, function() return barViewer end,
        HookBarFrame, ScheduleBarsLayout, ApplyBarsLayout,
        "Bar hook installation failed — bars layout disabled.")
end

-- ---------------------------------------------------------------------------
-- Deferred init — polls for both viewers (may not exist immediately)
-- ---------------------------------------------------------------------------

local function TryInit()
    -- Handle viewer recreation across loading screens
    local newViewer = _G["BuffIconCooldownViewer"]
    local newBarViewer = _G["BuffBarCooldownViewer"]
    local newEssential = _G["EssentialCooldownViewer"]
    local newUtility = _G["UtilityCooldownViewer"]
    local needEditMode = false

    if newViewer and newViewer ~= viewer then
        viewer = newViewer
        ns.viewer = viewer
        hookState.installed = false
        wipe(hookedFrames)
        InstallHooks()
        needEditMode = true
    end

    if newBarViewer and newBarViewer ~= barViewer then
        barViewer = newBarViewer
        ns.barViewer = barViewer
        barHookState.installed = false
        wipe(barHookedFrames)
        InstallBarsHooks()
        needEditMode = true
    end

    local needHotkeyRefresh = false

    if newEssential and newEssential ~= essentialViewer then
        essentialViewer = newEssential
        ns.essentialViewer = essentialViewer
        needEditMode = true
        needHotkeyRefresh = true
    end

    if newUtility and newUtility ~= utilityViewer then
        utilityViewer = newUtility
        ns.utilityViewer = utilityViewer
        needEditMode = true
        needHotkeyRefresh = true
    end

    if needHotkeyRefresh then
        RefreshAllHotkeys()
    end

    if needEditMode then
        if ns.SetupEditMode then ns.SetupEditMode() end
    end

    -- All already found — nothing to do
    if viewer and barViewer and essentialViewer and utilityViewer then return end

    -- Cancel any existing polling ticker before starting a new one
    if initTicker then initTicker:Cancel() end

    -- Poll every 0.5s for up to 10s until all viewers appear
    local attempts = 0
    initTicker = C_Timer.NewTicker(0.5, function()
        attempts = attempts + 1
        local foundNew = false

        local foundViewer = _G["BuffIconCooldownViewer"]
        if foundViewer and foundViewer ~= viewer then
            viewer = foundViewer
            ns.viewer = viewer
            hookState.installed = false
            wipe(hookedFrames)
            InstallHooks()
            foundNew = true
        end

        local foundBarViewer = _G["BuffBarCooldownViewer"]
        if foundBarViewer and foundBarViewer ~= barViewer then
            barViewer = foundBarViewer
            ns.barViewer = barViewer
            barHookState.installed = false
            wipe(barHookedFrames)
            InstallBarsHooks()
            foundNew = true
        end

        local needHotkeyRefresh = false

        local foundEssential = _G["EssentialCooldownViewer"]
        if foundEssential and foundEssential ~= essentialViewer then
            essentialViewer = foundEssential
            ns.essentialViewer = essentialViewer
            foundNew = true
            needHotkeyRefresh = true
        end

        local foundUtility = _G["UtilityCooldownViewer"]
        if foundUtility and foundUtility ~= utilityViewer then
            utilityViewer = foundUtility
            ns.utilityViewer = utilityViewer
            foundNew = true
            needHotkeyRefresh = true
        end

        if needHotkeyRefresh then
            RefreshAllHotkeys()
        end

        if foundNew then
            if ns.SetupEditMode then ns.SetupEditMode() end
        end

        if (viewer and barViewer and essentialViewer and utilityViewer) or attempts >= 20 then
            initTicker:Cancel()
            initTicker = nil
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
        elseif cmd == "essential" or cmd == "utility" then
            local prefix = cmd == "essential" and "essential_hotkeys_" or "utility_hotkeys_"
            local label = cmd == "essential" and "Essential" or "Utility"
            local subCmd, subArg = arg:match("^(%S+)%s*(.*)")
            subCmd = subCmd and subCmd:lower() or ""

            if subCmd == "show" then
                db[prefix .. "show"] = true
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkeys enabled")
                RefreshAllHotkeys()
            elseif subCmd == "hide" then
                db[prefix .. "show"] = false
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkeys disabled")
                RefreshAllHotkeys()
            elseif subCmd == "position" or subCmd == "pos" then
                local pos = subArg:upper()
                if ns.HOTKEY_POSITION_DISPLAY[pos] then
                    db[prefix .. "position"] = pos
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey position set to " .. ns.HOTKEY_POSITION_DISPLAY[pos])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " position <topleft|top|topright|right|bottomright|bottom|bottomleft|left|center>")
                end
            elseif subCmd == "fontsize" or subCmd == "size" then
                local n = tonumber(subArg)
                if n and n >= 8 and n <= 20 then
                    db[prefix .. "fontSize"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey font size set to " .. db[prefix .. "fontSize"])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " fontsize <8-20>")
                end
            elseif subCmd == "shorten" then
                db[prefix .. "shorten"] = true
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey text shortening enabled")
                RefreshAllHotkeys()
            elseif subCmd == "noshorten" then
                db[prefix .. "shorten"] = false
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey text shortening disabled")
                RefreshAllHotkeys()
            else
                local showText = db[prefix .. "show"] and "Shown" or "Hidden"
                local posText = ns.HOTKEY_POSITION_DISPLAY[db[prefix .. "position"]] or db[prefix .. "position"]
                local shortenText = db[prefix .. "shorten"] and "Shortened" or "Full"
                print("|cff00ccffEnhanced CDM — " .. label .. " Hotkeys:|r " .. showText .. ", position " .. posText .. ", font size " .. db[prefix .. "fontSize"] .. ", text " .. shortenText)
                print("  /ecdm " .. cmd .. " show              - Show keybinds")
                print("  /ecdm " .. cmd .. " hide              - Hide keybinds")
                print("  /ecdm " .. cmd .. " position <pos>    - Set position")
                print("  /ecdm " .. cmd .. " fontsize <8-20>   - Set font size")
                print("  /ecdm " .. cmd .. " shorten           - Shorten keybind text")
                print("  /ecdm " .. cmd .. " noshorten         - Show full keybind text")
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
            local eShow = db.essential_hotkeys_show and "Shown" or "Hidden"
            local ePos = ns.HOTKEY_POSITION_DISPLAY[db.essential_hotkeys_position] or db.essential_hotkeys_position
            local eShorten = db.essential_hotkeys_shorten and "Shortened" or "Full"
            print("  Essential: " .. eShow .. ", position " .. ePos .. ", font size " .. db.essential_hotkeys_fontSize .. ", text " .. eShorten)
            local uShow = db.utility_hotkeys_show and "Shown" or "Hidden"
            local uPos = ns.HOTKEY_POSITION_DISPLAY[db.utility_hotkeys_position] or db.utility_hotkeys_position
            local uShorten = db.utility_hotkeys_shorten and "Shortened" or "Full"
            print("  Utility:   " .. uShow .. ", position " .. uPos .. ", font size " .. db.utility_hotkeys_fontSize .. ", text " .. uShorten)
            print("  /ecdm rows <1-40>               - Icons per row")
            print("  /ecdm grow <up|down>             - Row growth direction")
            print("  /ecdm align <left|center|right>  - Row alignment")
            print("  /ecdm layout <static|dynamic>    - Layout mode")
            print("  /ecdm bars                       - Bars settings and commands")
            print("  /ecdm essential                  - Essential hotkey settings")
            print("  /ecdm utility                    - Utility hotkey settings")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events — ADDON_LOADED (init DB), PLAYER_ENTERING_WORLD (find viewer)
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

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
    elseif event == "UPDATE_BINDINGS"
        or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        RefreshAllHotkeys()
    end
end)

-- Test-only exports — used by tests/runner.lua, not by other addon files
ns._FormatKeyText = FormatKeyText
ns._CalcGridPosition = CalcGridPosition
