-- AuraRows: Multi-row layout for the Cooldown Manager aura tracker
-- Repositions BuffIconCooldownViewer children into a configurable grid

local ADDON_NAME = "AuraRows"
local db

local DEFAULTS = {
    maxPerRow     = 8,
    growDirection = "DOWN",
}

local viewer
local hookedFrames = {}
local pendingLayout = false
local hooksInstalled = false
local layoutTimer = nil
local SetupEditMode  -- forward declaration

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function ApplyLayout()
    if not viewer then return end
    if InCombatLockdown() then
        pendingLayout = true
        return
    end

    local children = { viewer:GetChildren() }
    local visible = {}

    for _, child in ipairs(children) do
        if child.cooldownID and child:IsShown() then
            visible[#visible + 1] = child
        end
    end

    if #visible == 0 then return end

    local maxPerRow = db.maxPerRow
    local growDown = (db.growDirection == "DOWN")

    local iconW = visible[1]:GetWidth()
    local iconH = visible[1]:GetHeight()
    if iconW < 1 then iconW = 36 end
    if iconH < 1 then iconH = 36 end
    local spacing = 2

    local totalIcons = #visible
    local numCols = math.min(maxPerRow, totalIcons)
    local numRows = math.ceil(totalIcons / maxPerRow)

    for i, frame in ipairs(visible) do
        local idx = i - 1
        local col = idx % maxPerRow
        local row = math.floor(idx / maxPerRow)

        local x = col * (iconW + spacing)
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
        viewer:SetSize(totalW, totalH)
    end
end

-- ---------------------------------------------------------------------------
-- Debounced scheduling
-- ---------------------------------------------------------------------------

local function ScheduleLayout()
    if layoutTimer then layoutTimer:Cancel() end
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

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

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

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        HookFrame(child)
    end

    ApplyLayout()
end

-- ---------------------------------------------------------------------------
-- Deferred init
-- ---------------------------------------------------------------------------

local function TryInit()
    local newViewer = _G["BuffIconCooldownViewer"]
    if newViewer and newViewer ~= viewer then
        viewer = newViewer
        hooksInstalled = false
        wipe(hookedFrames)
        InstallHooks()
        SetupEditMode()
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
            ticker:Cancel()
            InstallHooks()
            SetupEditMode()
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
                print("|cff00ccffAuraRows:|r Growth direction set to " .. (dir == "DOWN" and "Down" or "Up"))
                ApplyLayout()
            else
                print("|cff00ccffAuraRows:|r Usage: /ar grow <up|down>")
            end

        else
            print("|cff00ccffAuraRows|r v1.0.0")
            local dirDisplay = db.growDirection == "DOWN" and "Down" or "Up"
            print("  Current: " .. db.maxPerRow .. " per row, grow " .. dirDisplay)
            print("  /ar rows <1-40>      - Icons per row")
            print("  /ar grow <up|down>   - Row growth direction")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Edit Mode panel
-- ---------------------------------------------------------------------------

local editModePanel

-- Display text for direction values (capitalized for UI)
local DIRECTION_DISPLAY = { DOWN = "Down", UP = "Up" }

local function CreateEditModePanel()
    if editModePanel then return end

    local f = CreateFrame("Frame", "AuraRowsEditModePanel", UIParent, "BackdropTemplate")
    f:EnableMouse(true)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:Hide()

    local LABEL_WIDTH = 120
    local CONTENT_LEFT = 15
    local ROW_HEIGHT = 32

    -- Title — matches "Tracked Buffs" header style
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("AuraRows")

    -- Row 1: Per Row — [label] [slider + value]
    local row1 = CreateFrame("Frame", nil, f)
    row1:SetHeight(ROW_HEIGHT)
    row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -42)
    row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -42)

    local perRowLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowLabel:SetPoint("LEFT", 0, 0)
    perRowLabel:SetWidth(LABEL_WIDTH)
    perRowLabel:SetJustifyH("LEFT")
    perRowLabel:SetText("Per Row")

    local perRowValue = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowValue:SetPoint("RIGHT", 0, 0)
    perRowValue:SetJustifyH("RIGHT")
    perRowValue:SetText(tostring(db.maxPerRow))

    local slider = CreateFrame("Slider", "AuraRowsPerRowSlider", row1, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
    slider:SetPoint("RIGHT", perRowValue, "LEFT", -8, 0)
    slider:SetHeight(17)
    slider:SetMinMaxValues(1, 40)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db.maxPerRow)
    -- Hide the default OptionsSliderTemplate labels
    _G[slider:GetName() .. "Low"]:SetText("")
    _G[slider:GetName() .. "High"]:SetText("")
    _G[slider:GetName() .. "Text"]:SetText("")
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db.maxPerRow = value
        perRowValue:SetText(tostring(value))
        ApplyLayout()
    end)

    -- Row 2: Growth Direction — [label] [dropdown]
    local row2 = CreateFrame("Frame", nil, f)
    row2:SetHeight(ROW_HEIGHT)
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
    row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

    local growLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    growLabel:SetPoint("LEFT", 0, 0)
    growLabel:SetWidth(LABEL_WIDTH)
    growLabel:SetJustifyH("LEFT")
    growLabel:SetText("Growth Direction")

    local dropdown = CreateFrame("Frame", "AuraRowsGrowDropdown", row2, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", growLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(dropdown, 140)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, dir in ipairs({"DOWN", "UP"}) do
            info.text = DIRECTION_DISPLAY[dir]
            info.value = dir
            info.checked = (db.growDirection == dir)
            info.func = function(btn)
                db.growDirection = btn.value
                UIDropDownMenu_SetText(dropdown, DIRECTION_DISPLAY[btn.value])
                CloseDropDownMenus()
                ApplyLayout()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(dropdown, DIRECTION_DISPLAY[db.growDirection])

    f.growDropdown = dropdown
    f.perRowValue = perRowValue
    editModePanel = f

    -- Set a default size — will be overridden by ShowAuraRowsPanel
    f:SetSize(480, 110)
end

local function RefreshEditModePanel()
    if not editModePanel then return end
    local slider = _G["AuraRowsPerRowSlider"]
    if slider then
        slider:SetValue(db.maxPerRow)
    end
    if editModePanel.perRowValue then
        editModePanel.perRowValue:SetText(tostring(db.maxPerRow))
    end
    if editModePanel.growDropdown then
        UIDropDownMenu_SetText(editModePanel.growDropdown, DIRECTION_DISPLAY[db.growDirection])
    end
end

local function ShowAuraRowsPanel()
    CreateEditModePanel()
    RefreshEditModePanel()

    -- Match width to Blizzard's settings dialog
    local blizzDialog = _G["EditModeSystemSettingsDialog"]
    if blizzDialog and blizzDialog:IsShown() then
        editModePanel:SetWidth(blizzDialog:GetWidth())
        editModePanel:ClearAllPoints()
        editModePanel:SetPoint("TOP", blizzDialog, "BOTTOM", 0, -4)
    elseif viewer then
        editModePanel:ClearAllPoints()
        editModePanel:SetPoint("BOTTOM", viewer, "TOP", 0, 8)
    else
        editModePanel:ClearAllPoints()
        editModePanel:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
    editModePanel:Show()
end

local function HideAuraRowsPanel()
    if editModePanel then
        editModePanel:Hide()
    end
end

SetupEditMode = function()
    if not EditModeManagerFrame then return end

    local ok, err = pcall(function()
        -- Show panel only when Tracked Buffs (our viewer) is selected
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(self, systemFrame)
            if systemFrame == viewer then
                ShowAuraRowsPanel()
            else
                HideAuraRowsPanel()
            end
        end)

        -- Hide when selection is cleared
        if EditModeManagerFrame.ClearSelectedSystem then
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
                HideAuraRowsPanel()
            end)
        end

        -- Safety: hide on Edit Mode exit
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            HideAuraRowsPanel()
        end)
    end)

    if not ok then
        print("|cffff6600AuraRows:|r Edit Mode integration unavailable. Use /ar to configure.")
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
        for k, v in pairs(DEFAULTS) do
            if AuraRowsDB[k] == nil then
                AuraRowsDB[k] = v
            end
        end
        db = AuraRowsDB
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
