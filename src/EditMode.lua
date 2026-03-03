-- Enhanced CDM: Edit Mode — settings panel shown when Tracked Buffs is selected
local _, ns = ...

local editModePanel
local barsEditModePanel
local editModeHooked = false

-- ---------------------------------------------------------------------------
-- Panel creation — builds the settings panel (slider + 3 dropdowns)
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
    local CONTENT_TOP = 15
    local CONTENT_BOTTOM = 20
    local ROW_HEIGHT = 34

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -CONTENT_TOP)
    title:SetText("Enhanced CDM - Buffs")

    local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

    -- Row 1: Layout Mode — [label] [dropdown]
    local row1 = CreateFrame("Frame", nil, f)
    row1:SetHeight(ROW_HEIGHT)
    row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
    row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -titleBottom)

    local layoutLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    layoutLabel:SetPoint("LEFT", 0, 0)
    layoutLabel:SetWidth(LABEL_WIDTH)
    layoutLabel:SetJustifyH("LEFT")
    layoutLabel:SetText("Layout")

    local layoutDropdown = CreateFrame("DropdownButton", "EnhancedCDMLayoutDropdown", row1, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("LEFT", layoutLabel, "RIGHT", 5, 0)
    layoutDropdown:SetPoint("RIGHT", row1, "RIGHT", 0, 0)
    layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.layout])
    layoutDropdown:SetupMenu(function(owner, rootDescription)
        for _, l in ipairs({ "STATIC", "DYNAMIC" }) do
            rootDescription:CreateRadio(
                ns.LAYOUT_DISPLAY[l],
                function() return ns.db.layout == l end,
                function()
                    ns.db.layout = l
                    ns.ApplyLayout()
                end,
                l
            )
        end
    end)

    -- Row 2: Icons Per Row
    local row2 = CreateFrame("Frame", nil, f)
    row2:SetHeight(ROW_HEIGHT)
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
    row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

    local perRowLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowLabel:SetPoint("LEFT", 0, 0)
    perRowLabel:SetWidth(LABEL_WIDTH)
    perRowLabel:SetJustifyH("LEFT")
    perRowLabel:SetText("Icons Per Row")

    local perRowValue = row2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    perRowValue:SetPoint("RIGHT", 0, 0)
    perRowValue:SetJustifyH("RIGHT")
    perRowValue:SetText(tostring(db.maxPerRow))

    local steppers = CreateFrame("Frame", "EnhancedCDMPerRowStepper", row2, "MinimalSliderWithSteppersTemplate")
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

    -- Row 3: Icons Growth Direction
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)
    row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, 0)
    row3:SetPoint("TOPRIGHT", row2, "BOTTOMRIGHT", 0, 0)

    local growLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    growLabel:SetPoint("LEFT", 0, 0)
    growLabel:SetWidth(LABEL_WIDTH)
    growLabel:SetJustifyH("LEFT")
    growLabel:SetText("Icons Growth")

    local dropdown = CreateFrame("DropdownButton", "EnhancedCDMGrowDropdown", row3, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", growLabel, "RIGHT", 5, 0)
    dropdown:SetPoint("RIGHT", row3, "RIGHT", 0, 0)
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

    -- Row 4: Icons Alignment
    local row4 = CreateFrame("Frame", nil, f)
    row4:SetHeight(ROW_HEIGHT)
    row4:SetPoint("TOPLEFT", row3, "BOTTOMLEFT", 0, 0)
    row4:SetPoint("TOPRIGHT", row3, "BOTTOMRIGHT", 0, 0)

    local alignLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    alignLabel:SetPoint("LEFT", 0, 0)
    alignLabel:SetWidth(LABEL_WIDTH)
    alignLabel:SetJustifyH("LEFT")
    alignLabel:SetText("Icons Alignment")

    local alignDropdown = CreateFrame("DropdownButton", "EnhancedCDMAlignDropdown", row4, "WowStyle1DropdownTemplate")
    alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
    alignDropdown:SetPoint("RIGHT", row4, "RIGHT", 0, 0)
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
    f.layoutDropdown = layoutDropdown
    editModePanel = f

    f:SetSize(480, titleBottom + (ROW_HEIGHT * 4) + CONTENT_BOTTOM)
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
    if editModePanel.layoutDropdown then
        editModePanel.layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.layout])
    end
end

-- Anchors panel to the left of Blizzard's settings dialog and shows it
local function ShowEnhancedCDMPanel()
    CreateEditModePanel()
    RefreshEditModePanel()

    local blizzDialog = _G["EditModeSystemSettingsDialog"]
    local viewer = ns.viewer
    if blizzDialog and blizzDialog:IsShown() then
        editModePanel:SetFrameLevel(blizzDialog:GetFrameLevel())
        editModePanel:SetWidth(blizzDialog:GetWidth())
        editModePanel:ClearAllPoints()
        editModePanel:SetPoint("TOPRIGHT", blizzDialog, "TOPLEFT", -4, 0)
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
-- Bars panel creation — builds the bars settings panel (dropdowns + slider)
-- ---------------------------------------------------------------------------

local function CreateBarsEditModePanel()
    if barsEditModePanel then return end

    local db = ns.db

    local f = CreateFrame("Frame", "EnhancedCDMBarsEditModePanel", UIParent)
    f:EnableMouse(true)
    f:SetFrameStrata("DIALOG")
    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(f)
    f:SetWidth(480)
    f:Hide()

    local LABEL_WIDTH = 140
    local CONTENT_LEFT = 20
    local CONTENT_TOP = 15
    local CONTENT_BOTTOM = 20
    local ROW_HEIGHT = 34

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -CONTENT_TOP)
    title:SetText("Enhanced CDM - Bars")

    local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

    -- Row 1: Orientation
    local row1 = CreateFrame("Frame", nil, f)
    row1:SetHeight(ROW_HEIGHT)
    row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
    row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -titleBottom)

    local orientLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    orientLabel:SetPoint("LEFT", 0, 0)
    orientLabel:SetWidth(LABEL_WIDTH)
    orientLabel:SetJustifyH("LEFT")
    orientLabel:SetText("Bars Orientation")

    local orientDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsOrientDropdown", row1, "WowStyle1DropdownTemplate")
    orientDropdown:SetPoint("LEFT", orientLabel, "RIGHT", 5, 0)
    orientDropdown:SetPoint("RIGHT", row1, "RIGHT", 0, 0)
    orientDropdown:SetDefaultText(ns.ORIENTATION_DISPLAY[db.bars_orientation])

    -- Row 2: Layout
    local row2 = CreateFrame("Frame", nil, f)
    row2:SetHeight(ROW_HEIGHT)
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
    row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

    local layoutLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    layoutLabel:SetPoint("LEFT", 0, 0)
    layoutLabel:SetWidth(LABEL_WIDTH)
    layoutLabel:SetJustifyH("LEFT")
    layoutLabel:SetText("Bars Layout")

    local layoutDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsLayoutDropdown", row2, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("LEFT", layoutLabel, "RIGHT", 5, 0)
    layoutDropdown:SetPoint("RIGHT", row2, "RIGHT", 0, 0)
    layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.bars_layout])

    -- Row 3: Alignment — conditional: visible when layout=DYNAMIC
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)

    local alignLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    alignLabel:SetPoint("LEFT", 0, 0)
    alignLabel:SetWidth(LABEL_WIDTH)
    alignLabel:SetJustifyH("LEFT")
    alignLabel:SetText("Bars Alignment")

    local alignDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsAlignDropdown", row3, "WowStyle1DropdownTemplate")
    alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
    alignDropdown:SetPoint("RIGHT", row3, "RIGHT", 0, 0)

    -- Row 4: Bars Per Row — conditional: visible when orientation=HORIZONTAL
    local row4 = CreateFrame("Frame", nil, f)
    row4:SetHeight(ROW_HEIGHT)

    local perRowLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowLabel:SetPoint("LEFT", 0, 0)
    perRowLabel:SetWidth(LABEL_WIDTH)
    perRowLabel:SetJustifyH("LEFT")
    perRowLabel:SetText("Bars Per Row")

    local perRowValue = row4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    perRowValue:SetPoint("RIGHT", 0, 0)
    perRowValue:SetJustifyH("RIGHT")
    perRowValue:SetText(tostring(db.bars_maxPerRow))

    local steppers = CreateFrame("Frame", "EnhancedCDMBarsPerRowStepper", row4, "MinimalSliderWithSteppersTemplate")
    steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
    steppers:SetPoint("RIGHT", perRowValue, "LEFT", -8, 0)
    steppers:SetHeight(17)

    local slider = steppers.Slider
    slider:SetMinMaxValues(1, 8)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db.bars_maxPerRow)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        ns.db.bars_maxPerRow = value
        perRowValue:SetText(tostring(value))
        if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
    end)

    -- Forward-declared update function
    local UpdateBarsPanel

    -- Setup dropdown menus (use generators so they rebuild on each open)
    orientDropdown:SetupMenu(function(owner, rootDescription)
        for _, o in ipairs({ "VERTICAL", "HORIZONTAL" }) do
            rootDescription:CreateRadio(
                ns.ORIENTATION_DISPLAY[o],
                function() return ns.db.bars_orientation == o end,
                function()
                    ns.db.bars_orientation = o
                    if o == "VERTICAL" then
                        ns.db.bars_align = "DOWN"
                        ns.db.bars_maxPerRow = ns.DEFAULTS.bars_maxPerRow
                    elseif o == "HORIZONTAL" then
                        ns.db.bars_align = "CENTER"
                    end
                    if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
                    UpdateBarsPanel()
                end,
                o
            )
        end
    end)

    layoutDropdown:SetupMenu(function(owner, rootDescription)
        for _, l in ipairs({ "STATIC", "DYNAMIC" }) do
            rootDescription:CreateRadio(
                ns.LAYOUT_DISPLAY[l],
                function() return ns.db.bars_layout == l end,
                function()
                    ns.db.bars_layout = l
                    if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
                    UpdateBarsPanel()
                end,
                l
            )
        end
    end)

    alignDropdown:SetupMenu(function(owner, rootDescription)
        if ns.db.bars_orientation == "VERTICAL" then
            for _, a in ipairs({ "DOWN", "UP" }) do
                rootDescription:CreateRadio(
                    ns.BAR_ALIGN_V_DISPLAY[a],
                    function() return ns.db.bars_align == a end,
                    function()
                        ns.db.bars_align = a
                        if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
                    end,
                    a
                )
            end
        else
            for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
                rootDescription:CreateRadio(
                    ns.BAR_ALIGN_H_DISPLAY[a],
                    function() return ns.db.bars_align == a end,
                    function()
                        ns.db.bars_align = a
                        if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
                    end,
                    a
                )
            end
        end
    end)

    -- Update panel visibility, anchoring, and sizing based on current settings
    UpdateBarsPanel = function()
        local showAlign = (ns.db.bars_layout == "DYNAMIC")
        local showPerRow = (ns.db.bars_orientation == "HORIZONTAL")

        -- Update dropdown texts
        orientDropdown:SetDefaultText(ns.ORIENTATION_DISPLAY[ns.db.bars_orientation])
        layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[ns.db.bars_layout])
        if ns.db.bars_orientation == "VERTICAL" then
            alignDropdown:SetDefaultText(ns.BAR_ALIGN_V_DISPLAY[ns.db.bars_align])
        else
            alignDropdown:SetDefaultText(ns.BAR_ALIGN_H_DISPLAY[ns.db.bars_align])
        end

        -- Update slider
        local barsSteppers = _G["EnhancedCDMBarsPerRowStepper"]
        if barsSteppers and barsSteppers.Slider then
            barsSteppers.Slider:SetValue(ns.db.bars_maxPerRow)
        end
        perRowValue:SetText(tostring(ns.db.bars_maxPerRow))

        -- Dynamic row anchoring
        local visibleRows = 2 -- orientation + layout always visible
        local lastRow = row2

        if showAlign then
            row3:ClearAllPoints()
            row3:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row3:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row3:Show()
            lastRow = row3
            visibleRows = visibleRows + 1
        else
            row3:Hide()
        end

        if showPerRow then
            row4:ClearAllPoints()
            row4:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row4:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row4:Show()
            visibleRows = visibleRows + 1
        else
            row4:Hide()
        end

        f:SetHeight(titleBottom + (ROW_HEIGHT * visibleRows) + CONTENT_BOTTOM)
    end

    f.UpdateBarsPanel = UpdateBarsPanel
    barsEditModePanel = f

    -- Initial layout
    UpdateBarsPanel()
end

-- ---------------------------------------------------------------------------
-- Bars panel refresh / show / hide
-- ---------------------------------------------------------------------------

local function ShowBarsPanel()
    CreateBarsEditModePanel()
    if barsEditModePanel.UpdateBarsPanel then
        barsEditModePanel.UpdateBarsPanel()
    end

    local blizzDialog = _G["EditModeSystemSettingsDialog"]
    local bViewer = ns.barViewer
    if blizzDialog and blizzDialog:IsShown() then
        barsEditModePanel:SetFrameLevel(blizzDialog:GetFrameLevel())
        barsEditModePanel:SetWidth(blizzDialog:GetWidth())
        barsEditModePanel:ClearAllPoints()
        barsEditModePanel:SetPoint("TOPRIGHT", blizzDialog, "TOPLEFT", -4, 0)
    elseif bViewer then
        barsEditModePanel:ClearAllPoints()
        barsEditModePanel:SetPoint("BOTTOM", bViewer, "TOP", 0, 8)
    else
        barsEditModePanel:ClearAllPoints()
        barsEditModePanel:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end

    barsEditModePanel:Show()
end

local function HideBarsPanel()
    if barsEditModePanel then
        barsEditModePanel:Hide()
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
            local buffBarViewer = _G["BuffBarCooldownViewer"]
            if systemFrame == buffViewer then
                ShowEnhancedCDMPanel()
                HideBarsPanel()
                if ns.ScheduleLayout then ns.ScheduleLayout() end
            elseif systemFrame == buffBarViewer then
                ShowBarsPanel()
                HideEnhancedCDMPanel()
                if ns.ScheduleBarsLayout then ns.ScheduleBarsLayout() end
            else
                HideEnhancedCDMPanel()
                HideBarsPanel()
            end
        end)

        if EditModeManagerFrame.ClearSelectedSystem then
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
                HideEnhancedCDMPanel()
                HideBarsPanel()
            end)
        end

        -- Hide panels on Edit Mode exit and refresh layouts to clear stale positions
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            HideEnhancedCDMPanel()
            HideBarsPanel()
            if ns.ScheduleLayout then ns.ScheduleLayout() end
            if ns.ScheduleBarsLayout then ns.ScheduleBarsLayout() end
        end)

        -- Hide the "Icon Direction" setting from Blizzard's dialog for our viewers
        local dialog = _G["EditModeSystemSettingsDialog"]
        if dialog and dialog.UpdateSettings then
            hooksecurefunc(dialog, "UpdateSettings", function(self)
                local buffViewer = _G["BuffIconCooldownViewer"]
                local buffBarViewer = _G["BuffBarCooldownViewer"]
                if self.attachedToSystem ~= buffViewer and self.attachedToSystem ~= buffBarViewer then return end
                local children = { self.Settings:GetChildren() }
                for _, child in ipairs(children) do
                    if child.setting == Enum.EditModeCooldownViewerSetting.IconDirection then
                        child:Hide()
                    end
                end
                self.Settings:Layout()
            end)
        end
    end)

    if not ok then
        editModeHooked = false
        print("|cffff6600Enhanced CDM:|r Edit Mode integration unavailable. Use /ecdm to configure.")
    end
end
