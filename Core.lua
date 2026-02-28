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
-- Layout
-- ---------------------------------------------------------------------------

local visibleBuf = {}

local function ApplyLayout()
    if not viewer then return end
    if InCombatLockdown() then
        pendingLayout = true
        return
    end

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

    table.sort(visibleBuf, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local maxPerRow = db.maxPerRow
    local growDown = (db.growDirection == "DOWN")
    local align = db.align

    local scale = visibleBuf[1]:GetScale()
    if scale < 0.01 then scale = 1 end
    local iconW = visibleBuf[1]:GetWidth() * scale
    local iconH = visibleBuf[1]:GetHeight() * scale
    if iconW < 1 then iconW = 36 end
    if iconH < 1 then iconH = 36 end
    local spacing = ns.ICON_SPACING

    local totalIcons = n
    local numCols = math.min(maxPerRow, totalIcons)
    local numRows = math.ceil(totalIcons / maxPerRow)
    local fullRowWidth = numCols * (iconW + spacing) - spacing

    for i = 1, n do
        local frame = visibleBuf[i]
        local idx = i - 1
        local col = idx % maxPerRow
        local row = math.floor(idx / maxPerRow)

        -- Alignment offset for incomplete rows
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

    local totalW = numCols * (iconW + spacing) - spacing
    local totalH = numRows * (iconH + spacing) - spacing
    if totalW > 0 and totalH > 0 then
        viewer._arTargetW = totalW
        viewer._arTargetH = totalH
        viewer._arSettingSize = true
        viewer:SetSize(totalW, totalH)
        viewer._arSettingSize = false
    end
end

-- Expose for EditMode and slash commands
ns.ApplyLayout = ApplyLayout

-- ---------------------------------------------------------------------------
-- Debounced scheduling
-- ---------------------------------------------------------------------------

local function ScheduleLayout()
    if layoutTimer then layoutTimer:Cancel() end

    -- Clear cached positions so SetPoint/SetSize hooks don't enforce
    -- stale values while Blizzard repositions frames during the transition.
    -- ApplyLayout() will set fresh values next frame.
    if viewer then
        viewer._arTargetW = nil
        viewer._arTargetH = nil
    end
    for frame in pairs(hookedFrames) do
        if frame:GetParent() ~= viewer then
            hookedFrames[frame] = nil
        else
            frame._arTargetX = nil
            frame._arTargetY = nil
        end
    end

    layoutTimer = C_Timer.NewTimer(0, function()
        layoutTimer = nil
        ApplyLayout()
    end)
end

-- ---------------------------------------------------------------------------
-- Per-frame hook
-- ---------------------------------------------------------------------------

local function HookFrame(frame)
    if hookedFrames[frame] then return end
    hookedFrames[frame] = true

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
end

-- ---------------------------------------------------------------------------
-- CDM hooks
-- ---------------------------------------------------------------------------

local function InstallMixinHooks()
    if mixinHooksInstalled then return end
    mixinHooksInstalled = true

    if CooldownViewerMixin and CooldownViewerMixin.OnAcquireItemFrame then
        hooksecurefunc(CooldownViewerMixin, "OnAcquireItemFrame", function(self, frame)
            if self ~= viewer then return end
            HookFrame(frame)
            ScheduleLayout()
        end)
    end

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

    if CooldownViewerSettings then
        local layoutMgr = CooldownViewerSettings.GetLayoutManager
            and CooldownViewerSettings:GetLayoutManager()
        if layoutMgr and layoutMgr.NotifyListeners then
            hooksecurefunc(layoutMgr, "NotifyListeners", function()
                ScheduleLayout()
            end)
        end
    end

    if EventRegistry then
        EventRegistry:RegisterCallback(
            "CooldownViewerSettings.OnDataChanged",
            ScheduleLayout,
            ADDON_NAME
        )
    end
end

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
        end

        -- Prevent Blizzard from overriding our grid size on the viewer
        hooksecurefunc(viewer, "SetSize", function(self)
            if self._arSettingSize then return end
            if not self._arTargetW then return end
            self._arSettingSize = true
            self:SetSize(self._arTargetW, self._arTargetH)
            self._arSettingSize = false
        end)

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
-- Deferred init
-- ---------------------------------------------------------------------------

local function TryInit()
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
-- Slash commands
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
-- Event handler
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
