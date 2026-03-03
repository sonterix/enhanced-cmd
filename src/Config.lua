-- Enhanced CDM: Configuration — constants, defaults, display maps
local _, ns          = ...

-- Default saved variable values
ns.DEFAULTS          = {
    maxPerRow        = 6,
    growDirection    = "DOWN",
    align            = "CENTER",
    layout           = "STATIC",
    bars_orientation = "VERTICAL",
    bars_layout      = "STATIC",
    bars_align       = "CENTER",
    bars_maxPerRow   = 2,
}

-- Display text for UI labels
ns.DIRECTION_DISPLAY   = { DOWN = "Down", UP = "Up" }
ns.ALIGN_DISPLAY       = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
ns.LAYOUT_DISPLAY      = { STATIC = "Static", DYNAMIC = "Dynamic" }
ns.ORIENTATION_DISPLAY = { VERTICAL = "Vertical", HORIZONTAL = "Horizontal" }
ns.BAR_ALIGN_V_DISPLAY = { DOWN = "Down", UP = "Up" }
ns.BAR_ALIGN_H_DISPLAY = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
