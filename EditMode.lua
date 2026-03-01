-- Enhanced CDM: Edit Mode — settings panel shown when Tracked Buffs is selected
local _, ns = ...

local editModePanel
local editModeHooked = false

-- ---------------------------------------------------------------------------
-- Panel creation — builds the settings panel (slider + 2 dropdowns)
-- ---------------------------------------------------------------------------

local function CreateEditModePanel()
    if editModePanel then return end

    local db = ns.db

    local f = CreateFrame("Frame", "EnhancedCDMEditModePanel", UIParent)
    f:EnableMouse(true)
    f:SetFrameStrata("DIALOG")
    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(f)
    f:Hide()

    local LABEL_WIDTH = 140
    local CONTENT_LEFT = 20
    local CONTENT_TOP = 20
    local CONTENT_BOTTOM = 20
    local ROW_HEIGHT = 34

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -CONTENT_TOP)
    title:SetText("Enhanced CDM")

    local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

    -- Row 1: Icons Per Row — [label] [slider] [value]
    local row1 = CreateFrame("Frame", nil, f)
    row1:SetHeight(ROW_HEIGHT)
    row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
    row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -titleBottom)

    local perRowLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowLabel:SetPoint("LEFT", 0, 0)
    perRowLabel:SetWidth(LABEL_WIDTH)
    perRowLabel:SetJustifyH("LEFT")
    perRowLabel:SetText("Icons Per Row")

    local perRowValue = row1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    perRowValue:SetPoint("RIGHT", 0, 0)
    perRowValue:SetJustifyH("RIGHT")
    perRowValue:SetText(tostring(db.maxPerRow))

    local steppers = CreateFrame("Frame", "EnhancedCDMPerRowStepper", row1, "MinimalSliderWithSteppersTemplate")
    steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
    steppers:SetPoint("RIGHT", perRowValue, "LEFT", -8, 0)
    steppers:SetHeight(17)

    local slider = steppers.Slider
    slider:SetMinMaxValues(1, 40)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db.maxPerRow)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        ns.db.maxPerRow = value
        perRowValue:SetText(tostring(value))
        ns.ApplyLayout()
    end)

    -- Row 2: Icons Growth Direction — [label] [dropdown]
    local row2 = CreateFrame("Frame", nil, f)
    row2:SetHeight(ROW_HEIGHT)
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
    row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

    local growLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    growLabel:SetPoint("LEFT", 0, 0)
    growLabel:SetWidth(LABEL_WIDTH)
    growLabel:SetJustifyH("LEFT")
    growLabel:SetText("Icons Growth")

    local dropdown = CreateFrame("DropdownButton", "EnhancedCDMGrowDropdown", row2, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", growLabel, "RIGHT", 5, 0)
    dropdown:SetPoint("RIGHT", row2, "RIGHT", 0, 0)
    dropdown:SetDefaultText(ns.DIRECTION_DISPLAY[db.growDirection])
    dropdown:SetupMenu(function(owner, rootDescription)
        for _, dir in ipairs({ "DOWN", "UP" }) do
            rootDescription:CreateRadio(
                ns.DIRECTION_DISPLAY[dir],
                function() return ns.db.growDirection == dir end,
                function()
                    ns.db.growDirection = dir
                    ns.ApplyLayout()
                end,
                dir
            )
        end
    end)

    -- Row 3: Icons Alignment — [label] [dropdown]
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)
    row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, 0)
    row3:SetPoint("TOPRIGHT", row2, "BOTTOMRIGHT", 0, 0)

    local alignLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    alignLabel:SetPoint("LEFT", 0, 0)
    alignLabel:SetWidth(LABEL_WIDTH)
    alignLabel:SetJustifyH("LEFT")
    alignLabel:SetText("Icons Alignment")

    local alignDropdown = CreateFrame("DropdownButton", "EnhancedCDMAlignDropdown", row3, "WowStyle1DropdownTemplate")
    alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
    alignDropdown:SetPoint("RIGHT", row3, "RIGHT", 0, 0)
    alignDropdown:SetDefaultText(ns.ALIGN_DISPLAY[db.align])
    alignDropdown:SetupMenu(function(owner, rootDescription)
        for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
            rootDescription:CreateRadio(
                ns.ALIGN_DISPLAY[a],
                function() return ns.db.align == a end,
                function()
                    ns.db.align = a
                    ns.ApplyLayout()
                end,
                a
            )
        end
    end)

    f.perRowValue = perRowValue
    f.growDropdown = dropdown
    f.alignDropdown = alignDropdown
    editModePanel = f

    f:SetSize(480, titleBottom + (ROW_HEIGHT * 3) + CONTENT_BOTTOM)
end

-- ---------------------------------------------------------------------------
-- Panel refresh / show / hide
-- ---------------------------------------------------------------------------

-- Syncs all panel widgets with current saved variable values
local function RefreshEditModePanel()
    if not editModePanel then return end
    local db = ns.db
    local steppers = _G["EnhancedCDMPerRowStepper"]
    if steppers and steppers.Slider then
        steppers.Slider:SetValue(db.maxPerRow)
    end
    if editModePanel.perRowValue then
        editModePanel.perRowValue:SetText(tostring(db.maxPerRow))
    end
    if editModePanel.growDropdown then
        editModePanel.growDropdown:SetDefaultText(ns.DIRECTION_DISPLAY[db.growDirection])
    end
    if editModePanel.alignDropdown then
        editModePanel.alignDropdown:SetDefaultText(ns.ALIGN_DISPLAY[db.align])
    end
end

-- Anchors panel below Blizzard's settings dialog and shows it
local function ShowEnhancedCDMPanel()
    CreateEditModePanel()
    RefreshEditModePanel()

    local blizzDialog = _G["EditModeSystemSettingsDialog"]
    local viewer = ns.viewer
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

local function HideEnhancedCDMPanel()
    if editModePanel then
        editModePanel:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- Edit Mode hooks — show/hide panel when Tracked Buffs system is selected
-- ---------------------------------------------------------------------------

function ns.SetupEditMode()
    if not EditModeManagerFrame then return end
    if editModeHooked then return end
    editModeHooked = true

    local ok, err = pcall(function()
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(self, systemFrame)
            local buffViewer = _G["BuffIconCooldownViewer"]
            if systemFrame == buffViewer then
                ShowEnhancedCDMPanel()
                if ns.ScheduleLayout then ns.ScheduleLayout() end
            else
                HideEnhancedCDMPanel()
            end
        end)

        if EditModeManagerFrame.ClearSelectedSystem then
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
                HideEnhancedCDMPanel()
            end)
        end

        -- Hide panel on Edit Mode exit and refresh layout to clear stale positions
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            HideEnhancedCDMPanel()
            if ns.ScheduleLayout then ns.ScheduleLayout() end
        end)
    end)

    if not ok then
        editModeHooked = false
        print("|cffff6600Enhanced CDM:|r Edit Mode integration unavailable. Use /ecdm to configure.")
    end
end
