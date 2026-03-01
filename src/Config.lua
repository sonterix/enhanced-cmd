-- Enhanced CDM: Configuration — constants, defaults, display maps
local _, ns          = ...

-- Default saved variable values
ns.DEFAULTS          = {
    maxPerRow     = 6,
    growDirection = "DOWN",
    align         = "CENTER",
    layout        = "STATIC",
}

-- Display text for UI labels
ns.DIRECTION_DISPLAY = { DOWN = "Down", UP = "Up" }
ns.ALIGN_DISPLAY     = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
ns.LAYOUT_DISPLAY    = { STATIC = "Static", DYNAMIC = "Dynamic" }
