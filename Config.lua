-- AuraRows: Configuration — constants, defaults, display maps
local _, ns = ...

-- Default saved variable values
ns.DEFAULTS = {
    maxPerRow     = 8,
    growDirection = "DOWN",
    align         = "LEFT",
}

-- Layout constants
ns.ICON_SPACING = 2

-- Display text for UI labels
ns.DIRECTION_DISPLAY = { DOWN = "Down", UP = "Up" }
ns.ALIGN_DISPLAY     = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
