-- Enhanced CDM: Edit Mode — settings panel shown when Tracked Buffs is selected
local _, ns = ...

local editModePanel
local barsEditModePanel
local essentialHotkeysPanel
local utilityHotkeysPanel
local editModeHooked = false

-- Layout constants shared by all panels
local LABEL_WIDTH    = 110
local DROPDOWN_WIDTH = 225
local SLIDER_WIDTH   = 200
local CONTENT_LEFT   = 20
local CONTENT_TOP    = 15
local CONTENT_BOTTOM = 20
local ROW_HEIGHT     = 34
local DIVIDER_GAP    = 28

local POSITION_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER" }

-- Embed-into-dialog constants
local EMBED_COL_WIDTH = 380
local activeEmbeddedPanel = nil
local wrapperFrame = nil

-- Creates a red button matching Blizzard's Edit Mode style.
local function CreateRedButton(parent, label, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetHeight(30)
    btn:SetText(label)
    btn:SetNormalFontObject("GameFontNormal")
    btn:SetHighlightFontObject("GameFontHighlight")
    local normalTex = btn:GetNormalTexture()
    if normalTex then normalTex:SetVertexColor(0.7, 0.1, 0.1) end
    local pushedTex = btn:GetPushedTexture()
    if pushedTex then pushedTex:SetVertexColor(0.6, 0.05, 0.05) end
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Forward declaration for refresh (defined after panel creation)
local RefreshEditModePanel

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
    f._border = border
    f:Hide()

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
    layoutDropdown:SetWidth(DROPDOWN_WIDTH)
    layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.layout])
    layoutDropdown:SetupMenu(function(owner, rootDescription)
        for _, l in ipairs({ "STATIC", "DYNAMIC" }) do
            rootDescription:CreateRadio(
                ns.LAYOUT_DISPLAY[l],
                function() return ns.db.layout == l end,
                function()
                    ns.db.layout = l
                    if ns.ApplyLayout then ns.ApplyLayout() end
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
    perRowLabel:SetText("Per Row")

    local steppers = CreateFrame("Frame", "EnhancedCDMPerRowStepper", row2, "MinimalSliderWithSteppersTemplate")
    steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
    steppers:SetWidth(SLIDER_WIDTH)
    steppers:SetHeight(17)
    local fmt = {}
    fmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    steppers:Init(db.maxPerRow, 1, 40, 39, fmt)
    steppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db.maxPerRow = value
        if ns.ApplyLayout then ns.ApplyLayout() end
    end, steppers)

    -- Row 3: Icons Growth Direction
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)
    row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, 0)
    row3:SetPoint("TOPRIGHT", row2, "BOTTOMRIGHT", 0, 0)

    local growLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    growLabel:SetPoint("LEFT", 0, 0)
    growLabel:SetWidth(LABEL_WIDTH)
    growLabel:SetJustifyH("LEFT")
    growLabel:SetText("Growth")

    local dropdown = CreateFrame("DropdownButton", "EnhancedCDMGrowDropdown", row3, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", growLabel, "RIGHT", 5, 0)
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetDefaultText(ns.DIRECTION_DISPLAY[db.growDirection])
    dropdown:SetupMenu(function(owner, rootDescription)
        for _, dir in ipairs({ "DOWN", "UP" }) do
            rootDescription:CreateRadio(
                ns.DIRECTION_DISPLAY[dir],
                function() return ns.db.growDirection == dir end,
                function()
                    ns.db.growDirection = dir
                    if ns.ApplyLayout then ns.ApplyLayout() end
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
    alignLabel:SetText("Alignment")

    local alignDropdown = CreateFrame("DropdownButton", "EnhancedCDMAlignDropdown", row4, "WowStyle1DropdownTemplate")
    alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
    alignDropdown:SetWidth(DROPDOWN_WIDTH)
    alignDropdown:SetDefaultText(ns.ALIGN_DISPLAY[db.align])
    alignDropdown:SetupMenu(function(owner, rootDescription)
        for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
            rootDescription:CreateRadio(
                ns.ALIGN_DISPLAY[a],
                function() return ns.db.align == a end,
                function()
                    ns.db.align = a
                    if ns.ApplyLayout then ns.ApplyLayout() end
                end,
                a
            )
        end
    end)

    -- -----------------------------------------------------------------------
    -- Stack Text section — divider + 4 rows
    -- -----------------------------------------------------------------------

    local bStacksPrefix = "buffs_stacks_"

    local bDivider = f:CreateTexture(nil, "ARTWORK")
    bDivider:SetHeight(1)
    bDivider:SetColorTexture(1, 1, 1, 0.3)
    bDivider:SetPoint("TOPLEFT", row4, "BOTTOMLEFT", 0, -12)
    bDivider:SetPoint("TOPRIGHT", row4, "BOTTOMRIGHT", 0, -12)

    local bStackTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
    bStackTitle:SetPoint("TOP", bDivider, "BOTTOM", 0, -10)
    bStackTitle:SetText("Stacks")

    -- Row S1: Font Size
    local bsRow1 = CreateFrame("Frame", nil, f)
    bsRow1:SetHeight(ROW_HEIGHT)
    bsRow1:SetPoint("TOP", bStackTitle, "BOTTOM", 0, -6)
    bsRow1:SetPoint("LEFT", f, "LEFT", CONTENT_LEFT, 0)
    bsRow1:SetPoint("RIGHT", f, "RIGHT", -CONTENT_LEFT, 0)

    local bsFontLabel = bsRow1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    bsFontLabel:SetPoint("LEFT", 0, 0)
    bsFontLabel:SetWidth(LABEL_WIDTH)
    bsFontLabel:SetJustifyH("LEFT")
    bsFontLabel:SetText("Font Size")

    local bsFontStepperName = "EnhancedCDMBuffsStackFontStepper"
    local bsFontSteppers = CreateFrame("Frame", bsFontStepperName, bsRow1, "MinimalSliderWithSteppersTemplate")
    bsFontSteppers:SetPoint("LEFT", bsFontLabel, "RIGHT", 5, 0)
    bsFontSteppers:SetWidth(SLIDER_WIDTH)
    bsFontSteppers:SetHeight(17)
    local bsfFmt = {}
    bsfFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    bsFontSteppers:Init(db[bStacksPrefix .. "fontSize"], 6, 32, 26, bsfFmt)
    bsFontSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[bStacksPrefix .. "fontSize"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, bsFontSteppers)

    -- Row S2: Position
    local bsRow2 = CreateFrame("Frame", nil, f)
    bsRow2:SetHeight(ROW_HEIGHT)
    bsRow2:SetPoint("TOPLEFT", bsRow1, "BOTTOMLEFT", 0, 0)
    bsRow2:SetPoint("TOPRIGHT", bsRow1, "BOTTOMRIGHT", 0, 0)

    local bsPosLabel = bsRow2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    bsPosLabel:SetPoint("LEFT", 0, 0)
    bsPosLabel:SetWidth(LABEL_WIDTH)
    bsPosLabel:SetJustifyH("LEFT")
    bsPosLabel:SetText("Position")

    local bsPosDropdown = CreateFrame("DropdownButton", "EnhancedCDMBuffsStackPosDropdown", bsRow2, "WowStyle1DropdownTemplate")
    bsPosDropdown:SetPoint("LEFT", bsPosLabel, "RIGHT", 5, 0)
    bsPosDropdown:SetWidth(DROPDOWN_WIDTH)
    bsPosDropdown:SetDefaultText(ns.HOTKEY_POSITION_DISPLAY[db[bStacksPrefix .. "position"]])

    bsPosDropdown:SetupMenu(function(owner, rootDescription)
        for _, pos in ipairs(POSITION_ORDER) do
            rootDescription:CreateRadio(
                ns.HOTKEY_POSITION_DISPLAY[pos],
                function() return ns.db[bStacksPrefix .. "position"] == pos end,
                function()
                    ns.db[bStacksPrefix .. "position"] = pos
                    local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                    if anchor then
                        ns.db[bStacksPrefix .. "offsetX"] = anchor.x
                        ns.db[bStacksPrefix .. "offsetY"] = anchor.y
                    end
                    if ns.RefreshAllStacks then ns.RefreshAllStacks() end
                    -- Sync slider widgets
                    local soxS = _G["EnhancedCDMBuffsStackOffsetXStepper"]
                    if soxS and soxS.Slider then soxS.Slider:SetValue(ns.db[bStacksPrefix .. "offsetX"]) end
                    local soyS = _G["EnhancedCDMBuffsStackOffsetYStepper"]
                    if soyS and soyS.Slider then soyS.Slider:SetValue(ns.db[bStacksPrefix .. "offsetY"]) end
                end,
                pos
            )
        end
    end)

    -- Row S3: Horizontal Offset
    local bsRow3 = CreateFrame("Frame", nil, f)
    bsRow3:SetHeight(ROW_HEIGHT)
    bsRow3:SetPoint("TOPLEFT", bsRow2, "BOTTOMLEFT", 0, 0)
    bsRow3:SetPoint("TOPRIGHT", bsRow2, "BOTTOMRIGHT", 0, 0)

    local bsOffsetXLabel = bsRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    bsOffsetXLabel:SetPoint("LEFT", 0, 0)
    bsOffsetXLabel:SetWidth(LABEL_WIDTH)
    bsOffsetXLabel:SetJustifyH("LEFT")
    bsOffsetXLabel:SetText("Horizontal")

    local bsOffsetXStepperName = "EnhancedCDMBuffsStackOffsetXStepper"
    local bsOffsetXSteppers = CreateFrame("Frame", bsOffsetXStepperName, bsRow3, "MinimalSliderWithSteppersTemplate")
    bsOffsetXSteppers:SetPoint("LEFT", bsOffsetXLabel, "RIGHT", 5, 0)
    bsOffsetXSteppers:SetWidth(SLIDER_WIDTH)
    bsOffsetXSteppers:SetHeight(17)
    local bsoxFmt = {}
    bsoxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    bsOffsetXSteppers:Init(db[bStacksPrefix .. "offsetX"], -40, 40, 80, bsoxFmt)
    bsOffsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[bStacksPrefix .. "offsetX"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, bsOffsetXSteppers)

    -- Row S4: Vertical Offset
    local bsRow4 = CreateFrame("Frame", nil, f)
    bsRow4:SetHeight(ROW_HEIGHT)
    bsRow4:SetPoint("TOPLEFT", bsRow3, "BOTTOMLEFT", 0, 0)
    bsRow4:SetPoint("TOPRIGHT", bsRow3, "BOTTOMRIGHT", 0, 0)

    local bsOffsetYLabel = bsRow4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    bsOffsetYLabel:SetPoint("LEFT", 0, 0)
    bsOffsetYLabel:SetWidth(LABEL_WIDTH)
    bsOffsetYLabel:SetJustifyH("LEFT")
    bsOffsetYLabel:SetText("Vertical")

    local bsOffsetYStepperName = "EnhancedCDMBuffsStackOffsetYStepper"
    local bsOffsetYSteppers = CreateFrame("Frame", bsOffsetYStepperName, bsRow4, "MinimalSliderWithSteppersTemplate")
    bsOffsetYSteppers:SetPoint("LEFT", bsOffsetYLabel, "RIGHT", 5, 0)
    bsOffsetYSteppers:SetWidth(SLIDER_WIDTH)
    bsOffsetYSteppers:SetHeight(17)
    local bsoyFmt = {}
    bsoyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    bsOffsetYSteppers:Init(db[bStacksPrefix .. "offsetY"], -40, 40, 80, bsoyFmt)
    bsOffsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[bStacksPrefix .. "offsetY"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, bsOffsetYSteppers)

    -- Reset To Default button
    local BUFFS_KEYS = { "maxPerRow", "growDirection", "align", "layout",
        "buffs_stacks_fontSize", "buffs_stacks_position", "buffs_stacks_offsetX", "buffs_stacks_offsetY" }
    local resetBtn = CreateRedButton(f, "Reset To Default", function()
        for _, key in ipairs(BUFFS_KEYS) do
            ns.db[key] = ns.DEFAULTS[key]
        end
        RefreshEditModePanel()
        if ns.ApplyLayout then ns.ApplyLayout() end
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end)
    local resetDivider = f:CreateTexture(nil, "ARTWORK")
    resetDivider:SetHeight(1)
    resetDivider:SetColorTexture(1, 1, 1, 0.3)
    resetDivider:SetPoint("TOPLEFT", bsRow4, "BOTTOMLEFT", 0, -12)
    resetDivider:SetPoint("TOPRIGHT", bsRow4, "BOTTOMRIGHT", 0, -12)
    resetBtn:SetPoint("TOPLEFT", resetDivider, "BOTTOMLEFT", 0, -10)
    resetBtn:SetPoint("TOPRIGHT", resetDivider, "BOTTOMRIGHT", 0, -10)

    f.growDropdown = dropdown
    f.alignDropdown = alignDropdown
    f.layoutDropdown = layoutDropdown
    f.bsPosDropdown = bsPosDropdown
    editModePanel = f

    local stacksExtraHeight = DIVIDER_GAP + bStackTitle:GetStringHeight() + 6 + (ROW_HEIGHT * 4)
    f:SetSize(480, titleBottom + (ROW_HEIGHT * 4) + stacksExtraHeight + CONTENT_BOTTOM + 52)
end

-- ---------------------------------------------------------------------------
-- Panel refresh / show / hide
-- ---------------------------------------------------------------------------

-- Updates a WowStyle1Dropdown's visible text and default text.
local function SetDropdownText(dropdown, text)
    if not dropdown then return end
    dropdown:SetDefaultText(text)
    if dropdown.Text then dropdown.Text:SetText(text) end
end

-- Syncs all panel widgets with current saved variable values
RefreshEditModePanel = function()
    if not editModePanel then return end
    local db = ns.db
    local steppers = _G["EnhancedCDMPerRowStepper"]
    if steppers and steppers.Slider then
        steppers.Slider:SetValue(db.maxPerRow)
    end
    SetDropdownText(editModePanel.growDropdown, ns.DIRECTION_DISPLAY[db.growDirection])
    SetDropdownText(editModePanel.alignDropdown, ns.ALIGN_DISPLAY[db.align])
    SetDropdownText(editModePanel.layoutDropdown, ns.LAYOUT_DISPLAY[db.layout])
    SetDropdownText(editModePanel.bsPosDropdown, ns.HOTKEY_POSITION_DISPLAY[db.buffs_stacks_position])
    local bsfS = _G["EnhancedCDMBuffsStackFontStepper"]
    if bsfS and bsfS.Slider then bsfS.Slider:SetValue(db.buffs_stacks_fontSize) end
    local bsoxS = _G["EnhancedCDMBuffsStackOffsetXStepper"]
    if bsoxS and bsoxS.Slider then bsoxS.Slider:SetValue(db.buffs_stacks_offsetX) end
    local bsoyS = _G["EnhancedCDMBuffsStackOffsetYStepper"]
    if bsoyS and bsoyS.Slider then bsoyS.Slider:SetValue(db.buffs_stacks_offsetY) end
end

-- Hides the Blizzard dialog's border/background (dialog.Border frame).
local function HideDialogBorder(dialog)
    if dialog.Border then dialog.Border:Hide() end
end

-- Restores the Blizzard dialog's border/background.
local function ShowDialogBorder(dialog)
    if dialog.Border then dialog.Border:Show() end
end

-- Embeds a panel as the LEFT column beside Blizzard's settings dialog.
-- Both panels become borderless; a shared wrapper provides the unified border.
-- Falls back to standalone positioning if the dialog is unavailable.
local function EmbedPanelInDialog(panel)
    local dialog = _G["EditModeSystemSettingsDialog"]
    if not dialog or not dialog:IsShown() then
        -- Fallback: show standalone
        if panel._border then panel._border:Show() end
        if panel._ecdmDivider then panel._ecdmDivider:Hide() end
        panel:SetParent(UIParent)
        panel:SetFrameStrata("DIALOG")
        panel:ClearAllPoints()
        panel:SetPoint("TOP", UIParent, "TOP", 0, -100)
        panel:Show()
        return
    end

    -- Hide panel's own border
    if panel._border then panel._border:Hide() end

    -- Hide Blizzard dialog's border/background
    HideDialogBorder(dialog)

    -- Create or reuse the wrapper frame that provides the shared border
    if not wrapperFrame then
        wrapperFrame = CreateFrame("Frame", "EnhancedCDMWrapperFrame", UIParent)
        wrapperFrame:EnableMouse(false)
        wrapperFrame:SetFrameStrata("DIALOG")
        local wrapBorder = CreateFrame("Frame", nil, wrapperFrame, "DialogBorderTranslucentTemplate")
        wrapBorder:SetAllPoints(wrapperFrame)
        wrapperFrame._border = wrapBorder
    end

    -- Position panel to the LEFT of dialog, matching its height
    panel:SetParent(UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", dialog, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMLEFT", 0, 0)
    panel:SetWidth(EMBED_COL_WIDTH)
    panel:Show()

    -- Ensure panel content renders above the wrapper background
    panel:SetFrameLevel(dialog:GetFrameLevel() + 1)

    -- Position wrapper to span both panel (left) and dialog (right)
    wrapperFrame:SetFrameLevel(dialog:GetFrameLevel() - 1)
    wrapperFrame:ClearAllPoints()
    wrapperFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    wrapperFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", 0, 0)
    wrapperFrame:Show()

    -- Vertical divider between columns (on panel's right edge)
    if not panel._ecdmDivider then
        panel._ecdmDivider = panel:CreateTexture(nil, "OVERLAY")
        panel._ecdmDivider:SetWidth(1)
        panel._ecdmDivider:SetColorTexture(1, 1, 1, 0.15)
    end
    panel._ecdmDivider:ClearAllPoints()
    panel._ecdmDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -10)
    panel._ecdmDivider:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)
    panel._ecdmDivider:Show()

    activeEmbeddedPanel = panel
end

-- Removes the embedded panel and restores the dialog's original border.
local function UnembedPanel()
    if activeEmbeddedPanel then
        activeEmbeddedPanel:Hide()
        activeEmbeddedPanel:SetParent(UIParent)
        activeEmbeddedPanel:SetFrameStrata("DIALOG")
        if activeEmbeddedPanel._border then
            activeEmbeddedPanel._border:Show()
        end
        if activeEmbeddedPanel._ecdmDivider then
            activeEmbeddedPanel._ecdmDivider:Hide()
        end
        activeEmbeddedPanel = nil
    end

    -- Restore Blizzard dialog's border
    local dialog = _G["EditModeSystemSettingsDialog"]
    if dialog then ShowDialogBorder(dialog) end

    -- Hide wrapper
    if wrapperFrame then
        wrapperFrame:Hide()
    end
end

local function ShowEnhancedCDMPanel()
    CreateEditModePanel()
    RefreshEditModePanel()
    EmbedPanelInDialog(editModePanel)
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
    f._border = border
    f:SetWidth(480)
    f:Hide()

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
    orientLabel:SetText("Orientation")

    local orientDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsOrientDropdown", row1, "WowStyle1DropdownTemplate")
    orientDropdown:SetPoint("LEFT", orientLabel, "RIGHT", 5, 0)
    orientDropdown:SetWidth(DROPDOWN_WIDTH)
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
    layoutLabel:SetText("Layout")

    local layoutDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsLayoutDropdown", row2, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("LEFT", layoutLabel, "RIGHT", 5, 0)
    layoutDropdown:SetWidth(DROPDOWN_WIDTH)
    layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.bars_layout])

    -- Row 3: Alignment — conditional: visible when layout=DYNAMIC
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)

    local alignLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    alignLabel:SetPoint("LEFT", 0, 0)
    alignLabel:SetWidth(LABEL_WIDTH)
    alignLabel:SetJustifyH("LEFT")
    alignLabel:SetText("Alignment")

    local alignDropdown = CreateFrame("DropdownButton", "EnhancedCDMBarsAlignDropdown", row3, "WowStyle1DropdownTemplate")
    alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
    alignDropdown:SetWidth(DROPDOWN_WIDTH)

    -- Row 4: Bars Per Row — conditional: visible when orientation=HORIZONTAL
    local row4 = CreateFrame("Frame", nil, f)
    row4:SetHeight(ROW_HEIGHT)

    local perRowLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    perRowLabel:SetPoint("LEFT", 0, 0)
    perRowLabel:SetWidth(LABEL_WIDTH)
    perRowLabel:SetJustifyH("LEFT")
    perRowLabel:SetText("Per Row")

    local steppers = CreateFrame("Frame", "EnhancedCDMBarsPerRowStepper", row4, "MinimalSliderWithSteppersTemplate")
    steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
    steppers:SetWidth(SLIDER_WIDTH)
    steppers:SetHeight(17)
    local fmt = {}
    fmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    steppers:Init(db.bars_maxPerRow, 1, 8, 7, fmt)
    steppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db.bars_maxPerRow = value
        if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
    end, steppers)

    -- Forward-declared update function, reset button, and divider
    local UpdateBarsPanel
    local barsResetBtn
    local barsResetDivider

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
        SetDropdownText(orientDropdown, ns.ORIENTATION_DISPLAY[ns.db.bars_orientation])
        SetDropdownText(layoutDropdown, ns.LAYOUT_DISPLAY[ns.db.bars_layout])
        local alignText
        if ns.db.bars_orientation == "VERTICAL" then
            alignText = ns.BAR_ALIGN_V_DISPLAY[ns.db.bars_align] or "Down"
        else
            alignText = ns.BAR_ALIGN_H_DISPLAY[ns.db.bars_align] or "Center"
        end
        SetDropdownText(alignDropdown, alignText)

        -- Update slider
        local barsSteppers = _G["EnhancedCDMBarsPerRowStepper"]
        if barsSteppers and barsSteppers.Slider then
            barsSteppers.Slider:SetValue(ns.db.bars_maxPerRow)
        end

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
            lastRow = row4
            visibleRows = visibleRows + 1
        else
            row4:Hide()
        end

        barsResetDivider:ClearAllPoints()
        barsResetDivider:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -12)
        barsResetDivider:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -12)
        barsResetBtn:ClearAllPoints()
        barsResetBtn:SetPoint("TOPLEFT", barsResetDivider, "BOTTOMLEFT", 0, -10)
        barsResetBtn:SetPoint("TOPRIGHT", barsResetDivider, "BOTTOMRIGHT", 0, -10)

        f:SetHeight(titleBottom + (ROW_HEIGHT * visibleRows) + CONTENT_BOTTOM + 52)
    end

    -- Reset To Default button
    local BARS_KEYS = { "bars_orientation", "bars_layout", "bars_align", "bars_maxPerRow" }
    barsResetDivider = f:CreateTexture(nil, "ARTWORK")
    barsResetDivider:SetHeight(1)
    barsResetDivider:SetColorTexture(1, 1, 1, 0.3)

    barsResetBtn = CreateRedButton(f, "Reset To Default", function()
        for _, key in ipairs(BARS_KEYS) do
            ns.db[key] = ns.DEFAULTS[key]
        end
        UpdateBarsPanel()
        if ns.ApplyBarsLayout then ns.ApplyBarsLayout() end
    end)

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
    EmbedPanelInDialog(barsEditModePanel)
end

local function HideBarsPanel()
    if barsEditModePanel then
        barsEditModePanel:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- Hotkeys panel factory — creates a checkbox + position + font size panel
-- ---------------------------------------------------------------------------

local function CreateHotkeysPanelForViewer(frameName, titleText, prefix)
    local db = ns.db

    local f = CreateFrame("Frame", frameName, UIParent)
    f:EnableMouse(true)
    f:SetFrameStrata("DIALOG")
    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(f)
    f._border = border
    f:SetWidth(480)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -CONTENT_TOP)
    title:SetText(titleText)

    local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

    -- Row 1: Show Keybinds checkbox
    local row1 = CreateFrame("Frame", nil, f)
    row1:SetHeight(ROW_HEIGHT)
    row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
    row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -titleBottom)

    local checkbox = CreateFrame("CheckButton", frameName .. "Checkbox", row1, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", 0, 0)
    checkbox:SetSize(30, 30)

    local showLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    showLabel:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    showLabel:SetJustifyH("LEFT")
    showLabel:SetText("Show Keybinds")

    -- Row 2: Shorten Keybinds Text — conditional: visible when show=true
    local row2 = CreateFrame("Frame", nil, f)
    row2:SetHeight(ROW_HEIGHT)

    local shortenCheckbox = CreateFrame("CheckButton", frameName .. "ShortenCheckbox", row2, "UICheckButtonTemplate")
    shortenCheckbox:SetPoint("LEFT", 0, 0)
    shortenCheckbox:SetSize(30, 30)

    local shortenLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    shortenLabel:SetPoint("LEFT", shortenCheckbox, "RIGHT", 5, 0)
    shortenLabel:SetJustifyH("LEFT")
    shortenLabel:SetText("Shorten Keybinds Text")

    -- Row 3: Font Size — conditional: visible when show=true
    local row3 = CreateFrame("Frame", nil, f)
    row3:SetHeight(ROW_HEIGHT)

    local fontLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    fontLabel:SetPoint("LEFT", 0, 0)
    fontLabel:SetWidth(LABEL_WIDTH)
    fontLabel:SetJustifyH("LEFT")
    fontLabel:SetText("Font Size")

    local stepperName = frameName .. "FontStepper"
    local fontSteppers = CreateFrame("Frame", stepperName, row3, "MinimalSliderWithSteppersTemplate")
    fontSteppers:SetPoint("LEFT", fontLabel, "RIGHT", 5, 0)
    fontSteppers:SetWidth(SLIDER_WIDTH)
    fontSteppers:SetHeight(17)
    local fontFmt = {}
    fontFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    fontSteppers:Init(db[prefix .. "fontSize"], 6, 32, 26, fontFmt)
    fontSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[prefix .. "fontSize"] = value
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
    end, fontSteppers)

    -- Row 4: Position — conditional: visible when show=true
    local row4 = CreateFrame("Frame", nil, f)
    row4:SetHeight(ROW_HEIGHT)

    local posLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    posLabel:SetPoint("LEFT", 0, 0)
    posLabel:SetWidth(LABEL_WIDTH)
    posLabel:SetJustifyH("LEFT")
    posLabel:SetText("Position")

    local posDropdown = CreateFrame("DropdownButton", frameName .. "PosDropdown", row4, "WowStyle1DropdownTemplate")
    posDropdown:SetPoint("LEFT", posLabel, "RIGHT", 5, 0)
    posDropdown:SetWidth(DROPDOWN_WIDTH)

    local UpdatePanel
    local hotkeyResetBtn
    local hotkeyResetDivider

    posDropdown:SetupMenu(function(owner, rootDescription)
        for _, pos in ipairs(POSITION_ORDER) do
            rootDescription:CreateRadio(
                ns.HOTKEY_POSITION_DISPLAY[pos],
                function() return ns.db[prefix .. "position"] == pos end,
                function()
                    ns.db[prefix .. "position"] = pos
                    local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                    if anchor then
                        ns.db[prefix .. "offsetX"] = anchor.x
                        ns.db[prefix .. "offsetY"] = anchor.y
                    end
                    if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
                    UpdatePanel()
                end,
                pos
            )
        end
    end)

    -- Row 5: Horizontal Offset — conditional: visible when show=true
    local row5 = CreateFrame("Frame", nil, f)
    row5:SetHeight(ROW_HEIGHT)

    local offsetXLabel = row5:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    offsetXLabel:SetPoint("LEFT", 0, 0)
    offsetXLabel:SetWidth(LABEL_WIDTH)
    offsetXLabel:SetJustifyH("LEFT")
    offsetXLabel:SetText("Horizontal")

    local offsetXStepperName = frameName .. "OffsetXStepper"
    local offsetXSteppers = CreateFrame("Frame", offsetXStepperName, row5, "MinimalSliderWithSteppersTemplate")
    offsetXSteppers:SetPoint("LEFT", offsetXLabel, "RIGHT", 5, 0)
    offsetXSteppers:SetWidth(SLIDER_WIDTH)
    offsetXSteppers:SetHeight(17)
    local oxFmt = {}
    oxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    offsetXSteppers:Init(db[prefix .. "offsetX"], -40, 40, 80, oxFmt)
    offsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[prefix .. "offsetX"] = value
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
    end, offsetXSteppers)

    -- Row 6: Vertical Offset — conditional: visible when show=true
    local row6 = CreateFrame("Frame", nil, f)
    row6:SetHeight(ROW_HEIGHT)

    local offsetYLabel = row6:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    offsetYLabel:SetPoint("LEFT", 0, 0)
    offsetYLabel:SetWidth(LABEL_WIDTH)
    offsetYLabel:SetJustifyH("LEFT")
    offsetYLabel:SetText("Vertical")

    local offsetYStepperName = frameName .. "OffsetYStepper"
    local offsetYSteppers = CreateFrame("Frame", offsetYStepperName, row6, "MinimalSliderWithSteppersTemplate")
    offsetYSteppers:SetPoint("LEFT", offsetYLabel, "RIGHT", 5, 0)
    offsetYSteppers:SetWidth(SLIDER_WIDTH)
    offsetYSteppers:SetHeight(17)
    local oyFmt = {}
    oyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    offsetYSteppers:Init(db[prefix .. "offsetY"], -40, 40, 80, oyFmt)
    offsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[prefix .. "offsetY"] = value
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
    end, offsetYSteppers)

    -- -----------------------------------------------------------------------
    -- Stack Text section — divider + 4 rows (always visible)
    -- -----------------------------------------------------------------------

    local stacksPrefix = prefix:gsub("hotkeys_$", "stacks_")

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.3)

    local stackTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
    stackTitle:SetText("Stacks")

    -- Row S1: Font Size
    local sRow1 = CreateFrame("Frame", nil, f)
    sRow1:SetHeight(ROW_HEIGHT)

    local sFontLabel = sRow1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    sFontLabel:SetPoint("LEFT", 0, 0)
    sFontLabel:SetWidth(LABEL_WIDTH)
    sFontLabel:SetJustifyH("LEFT")
    sFontLabel:SetText("Font Size")

    local sFontStepperName = frameName .. "StackFontStepper"
    local sFontSteppers = CreateFrame("Frame", sFontStepperName, sRow1, "MinimalSliderWithSteppersTemplate")
    sFontSteppers:SetPoint("LEFT", sFontLabel, "RIGHT", 5, 0)
    sFontSteppers:SetWidth(SLIDER_WIDTH)
    sFontSteppers:SetHeight(17)
    local sfFmt = {}
    sfFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    sFontSteppers:Init(db[stacksPrefix .. "fontSize"], 6, 32, 26, sfFmt)
    sFontSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[stacksPrefix .. "fontSize"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, sFontSteppers)

    -- Row S2: Position
    local sRow2 = CreateFrame("Frame", nil, f)
    sRow2:SetHeight(ROW_HEIGHT)

    local sPosLabel = sRow2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    sPosLabel:SetPoint("LEFT", 0, 0)
    sPosLabel:SetWidth(LABEL_WIDTH)
    sPosLabel:SetJustifyH("LEFT")
    sPosLabel:SetText("Position")

    local sPosDropdown = CreateFrame("DropdownButton", frameName .. "StackPosDropdown", sRow2, "WowStyle1DropdownTemplate")
    sPosDropdown:SetPoint("LEFT", sPosLabel, "RIGHT", 5, 0)
    sPosDropdown:SetWidth(DROPDOWN_WIDTH)

    local UpdateStacksWidgets

    sPosDropdown:SetupMenu(function(owner, rootDescription)
        for _, pos in ipairs(POSITION_ORDER) do
            rootDescription:CreateRadio(
                ns.HOTKEY_POSITION_DISPLAY[pos],
                function() return ns.db[stacksPrefix .. "position"] == pos end,
                function()
                    ns.db[stacksPrefix .. "position"] = pos
                    local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                    if anchor then
                        ns.db[stacksPrefix .. "offsetX"] = anchor.x
                        ns.db[stacksPrefix .. "offsetY"] = anchor.y
                    end
                    if ns.RefreshAllStacks then ns.RefreshAllStacks() end
                    if UpdateStacksWidgets then UpdateStacksWidgets() end
                end,
                pos
            )
        end
    end)

    -- Row S3: Horizontal Offset
    local sRow3 = CreateFrame("Frame", nil, f)
    sRow3:SetHeight(ROW_HEIGHT)

    local sOffsetXLabel = sRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    sOffsetXLabel:SetPoint("LEFT", 0, 0)
    sOffsetXLabel:SetWidth(LABEL_WIDTH)
    sOffsetXLabel:SetJustifyH("LEFT")
    sOffsetXLabel:SetText("Horizontal")

    local sOffsetXStepperName = frameName .. "StackOffsetXStepper"
    local sOffsetXSteppers = CreateFrame("Frame", sOffsetXStepperName, sRow3, "MinimalSliderWithSteppersTemplate")
    sOffsetXSteppers:SetPoint("LEFT", sOffsetXLabel, "RIGHT", 5, 0)
    sOffsetXSteppers:SetWidth(SLIDER_WIDTH)
    sOffsetXSteppers:SetHeight(17)
    local soxFmt = {}
    soxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    sOffsetXSteppers:Init(db[stacksPrefix .. "offsetX"], -40, 40, 80, soxFmt)
    sOffsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[stacksPrefix .. "offsetX"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, sOffsetXSteppers)

    -- Row S4: Vertical Offset
    local sRow4 = CreateFrame("Frame", nil, f)
    sRow4:SetHeight(ROW_HEIGHT)

    local sOffsetYLabel = sRow4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    sOffsetYLabel:SetPoint("LEFT", 0, 0)
    sOffsetYLabel:SetWidth(LABEL_WIDTH)
    sOffsetYLabel:SetJustifyH("LEFT")
    sOffsetYLabel:SetText("Vertical")

    local sOffsetYStepperName = frameName .. "StackOffsetYStepper"
    local sOffsetYSteppers = CreateFrame("Frame", sOffsetYStepperName, sRow4, "MinimalSliderWithSteppersTemplate")
    sOffsetYSteppers:SetPoint("LEFT", sOffsetYLabel, "RIGHT", 5, 0)
    sOffsetYSteppers:SetWidth(SLIDER_WIDTH)
    sOffsetYSteppers:SetHeight(17)
    local soyFmt = {}
    soyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    sOffsetYSteppers:Init(db[stacksPrefix .. "offsetY"], -40, 40, 80, soyFmt)
    sOffsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        ns.db[stacksPrefix .. "offsetY"] = value
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end, sOffsetYSteppers)

    UpdateStacksWidgets = function()
        local sfSteppers = _G[sFontStepperName]
        if sfSteppers and sfSteppers.Slider then
            sfSteppers.Slider:SetValue(ns.db[stacksPrefix .. "fontSize"])
        end

        SetDropdownText(sPosDropdown, ns.HOTKEY_POSITION_DISPLAY[ns.db[stacksPrefix .. "position"]])

        local soxSteppers = _G[sOffsetXStepperName]
        if soxSteppers and soxSteppers.Slider then
            soxSteppers.Slider:SetValue(ns.db[stacksPrefix .. "offsetX"])
        end

        local soySteppers = _G[sOffsetYStepperName]
        if soySteppers and soySteppers.Slider then
            soySteppers.Slider:SetValue(ns.db[stacksPrefix .. "offsetY"])
        end
    end

    -- -----------------------------------------------------------------------

    checkbox:SetScript("OnClick", function(self)
        ns.db[prefix .. "show"] = self:GetChecked()
        UpdatePanel()
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
    end)

    shortenCheckbox:SetScript("OnClick", function(self)
        ns.db[prefix .. "shorten"] = self:GetChecked()
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
    end)

    UpdatePanel = function()
        local showHotkeys = ns.db[prefix .. "show"]
        checkbox:SetChecked(showHotkeys)
        shortenCheckbox:SetChecked(ns.db[prefix .. "shorten"])

        local fSteppers = _G[stepperName]
        if fSteppers and fSteppers.Slider then
            fSteppers.Slider:SetValue(ns.db[prefix .. "fontSize"])
        end

        SetDropdownText(posDropdown, ns.HOTKEY_POSITION_DISPLAY[ns.db[prefix .. "position"]])

        local oxSteppers = _G[offsetXStepperName]
        if oxSteppers and oxSteppers.Slider then
            oxSteppers.Slider:SetValue(ns.db[prefix .. "offsetX"])
        end

        local oySteppers = _G[offsetYStepperName]
        if oySteppers and oySteppers.Slider then
            oySteppers.Slider:SetValue(ns.db[prefix .. "offsetY"])
        end

        UpdateStacksWidgets()

        local visibleRows = 1
        local lastRow = row1

        if showHotkeys then
            row2:ClearAllPoints()
            row2:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row2:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row2:Show()
            lastRow = row2
            visibleRows = visibleRows + 1

            row3:ClearAllPoints()
            row3:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row3:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row3:Show()
            lastRow = row3
            visibleRows = visibleRows + 1

            row4:ClearAllPoints()
            row4:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row4:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row4:Show()
            lastRow = row4
            visibleRows = visibleRows + 1

            row5:ClearAllPoints()
            row5:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row5:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row5:Show()
            lastRow = row5
            visibleRows = visibleRows + 1

            row6:ClearAllPoints()
            row6:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
            row6:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
            row6:Show()
            lastRow = row6
            visibleRows = visibleRows + 1
        else
            row2:Hide()
            row3:Hide()
            row4:Hide()
            row5:Hide()
            row6:Hide()
        end

        -- Stack Text divider + rows (always visible)
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -12)
        divider:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -12)

        stackTitle:ClearAllPoints()
        stackTitle:SetPoint("TOP", divider, "BOTTOM", 0, -10)

        sRow1:ClearAllPoints()
        sRow1:SetPoint("TOP", stackTitle, "BOTTOM", 0, -6)
        sRow1:SetPoint("LEFT", f, "LEFT", CONTENT_LEFT, 0)
        sRow1:SetPoint("RIGHT", f, "RIGHT", -CONTENT_LEFT, 0)
        sRow1:Show()

        sRow2:ClearAllPoints()
        sRow2:SetPoint("TOPLEFT", sRow1, "BOTTOMLEFT", 0, 0)
        sRow2:SetPoint("TOPRIGHT", sRow1, "BOTTOMRIGHT", 0, 0)
        sRow2:Show()

        sRow3:ClearAllPoints()
        sRow3:SetPoint("TOPLEFT", sRow2, "BOTTOMLEFT", 0, 0)
        sRow3:SetPoint("TOPRIGHT", sRow2, "BOTTOMRIGHT", 0, 0)
        sRow3:Show()

        sRow4:ClearAllPoints()
        sRow4:SetPoint("TOPLEFT", sRow3, "BOTTOMLEFT", 0, 0)
        sRow4:SetPoint("TOPRIGHT", sRow3, "BOTTOMRIGHT", 0, 0)
        sRow4:Show()

        hotkeyResetDivider:ClearAllPoints()
        hotkeyResetDivider:SetPoint("TOPLEFT", sRow4, "BOTTOMLEFT", 0, -12)
        hotkeyResetDivider:SetPoint("TOPRIGHT", sRow4, "BOTTOMRIGHT", 0, -12)
        hotkeyResetBtn:ClearAllPoints()
        hotkeyResetBtn:SetPoint("TOPLEFT", hotkeyResetDivider, "BOTTOMLEFT", 0, -10)
        hotkeyResetBtn:SetPoint("TOPRIGHT", hotkeyResetDivider, "BOTTOMRIGHT", 0, -10)

        local stacksExtraHeight = DIVIDER_GAP + stackTitle:GetStringHeight() + 6 + (ROW_HEIGHT * 4)
        f:SetHeight(titleBottom + (ROW_HEIGHT * visibleRows) + stacksExtraHeight + CONTENT_BOTTOM + 52)
    end

    -- Reset To Default button
    local hotkeyKeys = {}
    for key in pairs(ns.DEFAULTS) do
        if key:find("^" .. prefix) or key:find("^" .. stacksPrefix) then
            hotkeyKeys[#hotkeyKeys + 1] = key
        end
    end
    hotkeyResetDivider = f:CreateTexture(nil, "ARTWORK")
    hotkeyResetDivider:SetHeight(1)
    hotkeyResetDivider:SetColorTexture(1, 1, 1, 0.3)

    hotkeyResetBtn = CreateRedButton(f, "Reset To Default", function()
        for _, key in ipairs(hotkeyKeys) do
            ns.db[key] = ns.DEFAULTS[key]
        end
        UpdatePanel()
        if ns.RefreshAllHotkeys then ns.RefreshAllHotkeys() end
        if ns.RefreshAllStacks then ns.RefreshAllStacks() end
    end)

    f.UpdatePanel = UpdatePanel
    UpdatePanel()

    return f
end

-- ---------------------------------------------------------------------------
-- Essential / Utility hotkeys panel show / hide
-- ---------------------------------------------------------------------------

local function ShowEssentialHotkeysPanel()
    if not essentialHotkeysPanel then
        essentialHotkeysPanel = CreateHotkeysPanelForViewer(
            "EnhancedCDMEssentialHotkeysPanel", "Enhanced CDM - Essential", "essential_hotkeys_")
    end
    essentialHotkeysPanel.UpdatePanel()
    EmbedPanelInDialog(essentialHotkeysPanel)
end

local function HideEssentialHotkeysPanel()
    if essentialHotkeysPanel then
        essentialHotkeysPanel:Hide()
    end
end

local function ShowUtilityHotkeysPanel()
    if not utilityHotkeysPanel then
        utilityHotkeysPanel = CreateHotkeysPanelForViewer(
            "EnhancedCDMUtilityHotkeysPanel", "Enhanced CDM - Utility", "utility_hotkeys_")
    end
    utilityHotkeysPanel.UpdatePanel()
    EmbedPanelInDialog(utilityHotkeysPanel)
end

local function HideUtilityHotkeysPanel()
    if utilityHotkeysPanel then
        utilityHotkeysPanel:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- Edit Mode hooks — show/hide panel when Tracked Buffs system is selected
-- ---------------------------------------------------------------------------

local function HideAllPanels()
    UnembedPanel()
    HideEnhancedCDMPanel()
    HideBarsPanel()
    HideEssentialHotkeysPanel()
    HideUtilityHotkeysPanel()
end

local function SetupEditMode()
    if not EditModeManagerFrame then return end
    if editModeHooked then return end
    editModeHooked = true

    local ok = pcall(function()
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(self, systemFrame)
            local buffViewer = _G["BuffIconCooldownViewer"]
            local buffBarViewer = _G["BuffBarCooldownViewer"]
            local essViewer = _G["EssentialCooldownViewer"]
            local utilViewer = _G["UtilityCooldownViewer"]
            HideAllPanels()
            if systemFrame == buffViewer then
                ShowEnhancedCDMPanel()
                if ns.ScheduleLayout then ns.ScheduleLayout() end
            elseif systemFrame == buffBarViewer then
                ShowBarsPanel()
                if ns.ScheduleBarsLayout then ns.ScheduleBarsLayout() end
            elseif systemFrame == essViewer then
                ShowEssentialHotkeysPanel()
            elseif systemFrame == utilViewer then
                ShowUtilityHotkeysPanel()
            end
        end)

        if EditModeManagerFrame.ClearSelectedSystem then
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
                HideAllPanels()
            end)
        end

        -- Hide panels on Edit Mode exit and refresh layouts to clear stale positions
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            HideAllPanels()
            if ns.ScheduleLayout then ns.ScheduleLayout() end
            if ns.ScheduleBarsLayout then ns.ScheduleBarsLayout() end
        end)

        -- Hide the "Icon Direction" setting when a CDM viewer is selected
        local dialog = _G["EditModeSystemSettingsDialog"]
        if dialog then
            if dialog.UpdateSettings then
                hooksecurefunc(dialog, "UpdateSettings", function(self)
                    local buffViewer = _G["BuffIconCooldownViewer"]
                    local buffBarViewer = _G["BuffBarCooldownViewer"]
                    if self.attachedToSystem == buffViewer or self.attachedToSystem == buffBarViewer then
                        local children = { self.Settings:GetChildren() }
                        for _, child in ipairs(children) do
                            if child.setting == Enum.EditModeCooldownViewerSetting.IconDirection then
                                child:Hide()
                            end
                        end
                        self.Settings:Layout()
                    end
                end)
            end

            -- Clean up embed state when dialog hides (e.g. close button)
            dialog:HookScript("OnHide", function()
                UnembedPanel()
            end)
        end
    end)

    if not ok then
        editModeHooked = false
        print("|cffff6600Enhanced CDM:|r Edit Mode integration unavailable. Use /ecdm to configure.")
    end
end

ns.SetupEditMode = SetupEditMode

-- ---------------------------------------------------------------------------
-- Bar gradient colors — context menu integration for Tracked Bars entries
-- ---------------------------------------------------------------------------

-- Apply gradient preview to a settings-panel bar entry
local function ApplySettingsBarPreview(entry)
    if not entry or not entry.cooldownID then return end
    local db = ns.db
    if not db then return end
    local colors = db.bars_colors and db.bars_colors[entry.cooldownID]
    if colors then
        if ns.ApplyBarGradient then ns.ApplyBarGradient(entry) end
    else
        if ns.ResetBarGradient then ns.ResetBarGradient(entry) end
    end
end

local function OpenBarColorPicker(id, colorKey, label, settingsEntry)
    local db = ns.db
    if not db then return end

    local hadColors = (db.bars_colors[id] ~= nil)

    local function ensureColors()
        if not db.bars_colors[id] then
            db.bars_colors[id] = { sR=1, sG=0.5, sB=0.25, eR=1, eG=0.5, eB=0.25 }
        end
        return db.bars_colors[id]
    end

    local c = db.bars_colors[id]
    local rKey = colorKey .. "R"
    local gKey = colorKey .. "G"
    local bKey = colorKey .. "B"
    local r = c and c[rKey] or 1
    local g = c and c[gKey] or 0.5
    local b = c and c[bKey] or 0.25

    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        hasOpacity = false,
        swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local colors = ensureColors()
            colors[rKey], colors[gKey], colors[bKey] = nr, ng, nb
            if ns.RefreshAllBarGradients then ns.RefreshAllBarGradients() end
            ApplySettingsBarPreview(settingsEntry)
        end,
        cancelFunc = function(prev)
            if hadColors then
                local colors = db.bars_colors[id]
                if colors then
                    colors[rKey], colors[gKey], colors[bKey] = prev.r, prev.g, prev.b
                end
            else
                db.bars_colors[id] = nil
            end
            if ns.RefreshAllBarGradients then ns.RefreshAllBarGradients() end
            ApplySettingsBarPreview(settingsEntry)
        end,
    })
end

-- Scan all descendants for bar entries (frames with cooldownID + StatusBar child)
local function ScanAndApplyBarPreviews(frame, depth)
    if depth > 8 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.cooldownID then
            -- Leaf entry — check for StatusBar child (bar vs icon)
            for _, sub in ipairs({ child:GetChildren() }) do
                if sub:GetObjectType() == "StatusBar" then
                    ApplySettingsBarPreview(child)
                    break
                end
            end
        else
            ScanAndApplyBarPreviews(child, depth + 1)
        end
    end
end

-- Apply gradient previews to settings-panel bar entries after tab/view change
local settingsPreviewHooked = false
local function ScheduleSettingsBarScan()
    local settingsFrame = _G["CooldownViewerSettings"]
    if not settingsFrame or not settingsFrame:IsVisible() then return end
    local db = ns.db
    if not db or not db.bars_colors or not next(db.bars_colors) then return end
    -- Delay one frame so scroll pool entries are created
    C_Timer.NewTimer(0, function()
        ScanAndApplyBarPreviews(settingsFrame, 0)
    end)
end

local function HookSettingsBarPreview()
    if settingsPreviewHooked then return end
    local settingsFrame = _G["CooldownViewerSettings"]
    if not settingsFrame then return end
    settingsPreviewHooked = true

    -- Hook both tab button clicks — scan after content populates
    if settingsFrame.TabButtons then
        for _, tab in pairs(settingsFrame.TabButtons) do
            if type(tab) == "table" and tab.HookScript then
                tab:HookScript("OnMouseUp", ScheduleSettingsBarScan)
            end
        end
    end

    -- Also scan on settings panel open (covers case where bars tab is already active)
    settingsFrame:HookScript("OnShow", ScheduleSettingsBarScan)
end

-- Wrap MenuUtil.CreateContextMenu to inject gradient options on bar entries
-- NOTE: Direct replacement is required here because hooksecurefunc is a
-- post-hook and cannot modify the generator callback before it executes.
-- No alternative WoW API exists for injecting context menu items.
-- This is a documented exception to the "always use hooksecurefunc" rule.
local menuHooked = false
local function HookBarContextMenu()
    if menuHooked then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    menuHooked = true

    local origCreate = MenuUtil.CreateContextMenu
    MenuUtil.CreateContextMenu = function(owner, generator, ...)
        local db = ns.db
        if owner and owner.cooldownID and owner.GetCooldownID and db then
            local wrappedGenerator = function(ownerInner, rootDescription)
                generator(ownerInner, rootDescription)

                local id = ownerInner.cooldownID
                if not id then return end

                rootDescription:CreateDivider()
                rootDescription:CreateTitle("Gradient Colors")
                rootDescription:CreateButton("Set Start Color", function()
                    OpenBarColorPicker(id, "s", "Start", ownerInner)
                end)
                rootDescription:CreateButton("Set End Color", function()
                    OpenBarColorPicker(id, "e", "End", ownerInner)
                end)
                if db.bars_colors and db.bars_colors[id] then
                    rootDescription:CreateButton("Reset Gradient", function()
                        db.bars_colors[id] = nil
                        if ns.RefreshAllBarGradients then ns.RefreshAllBarGradients() end
                        ApplySettingsBarPreview(ownerInner)
                    end)
                end
            end
            return origCreate(owner, wrappedGenerator, ...)
        end
        return origCreate(owner, generator, ...)
    end
end

-- Retry hook installation + refresh previews on data changes
EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
    HookSettingsBarPreview()
    ScheduleSettingsBarScan()
end, "EnhancedCDM_SettingsBarPreview")

-- Hook when SetupEditMode is called (viewers exist at that point)
local origSetupEditMode = ns.SetupEditMode
ns.SetupEditMode = function()
    origSetupEditMode()
    HookBarContextMenu()
    HookSettingsBarPreview()
end
