-- Tests for Config — defaults, display maps, anchor tables
local ns = _G._test_ns

describe("Config defaults", function()
    it("has all expected default keys", function()
        local expected = {
            "maxPerRow", "growDirection", "align", "layout",
            "bars_orientation", "bars_layout", "bars_align", "bars_maxPerRow", "bars_colors",
            "essential_hotkeys_show", "essential_hotkeys_position", "essential_hotkeys_fontSize", "essential_hotkeys_shorten",
            "essential_hotkeys_offsetX", "essential_hotkeys_offsetY",
            "utility_hotkeys_show", "utility_hotkeys_position", "utility_hotkeys_fontSize", "utility_hotkeys_shorten",
            "utility_hotkeys_offsetX", "utility_hotkeys_offsetY",
            "essential_stacks_fontSize", "essential_stacks_position",
            "essential_stacks_offsetX", "essential_stacks_offsetY",
            "utility_stacks_fontSize", "utility_stacks_position",
            "utility_stacks_offsetX", "utility_stacks_offsetY",
            "buffs_stacks_fontSize", "buffs_stacks_position",
            "buffs_stacks_offsetX", "buffs_stacks_offsetY",
        }
        for _, key in ipairs(expected) do
            expect(ns.DEFAULTS[key] ~= nil).to_be_truthy()
        end
    end)

    it("has sensible default values", function()
        expect(ns.DEFAULTS.maxPerRow).to_equal(6)
        expect(ns.DEFAULTS.growDirection).to_equal("DOWN")
        expect(ns.DEFAULTS.align).to_equal("CENTER")
        expect(ns.DEFAULTS.layout).to_equal("STATIC")
        expect(ns.DEFAULTS.essential_hotkeys_show).to_equal(false)
        expect(ns.DEFAULTS.utility_hotkeys_show).to_equal(false)
        expect(ns.DEFAULTS.bars_colors).to_be_type("table")
        expect(next(ns.DEFAULTS.bars_colors) == nil).to_be_truthy()
    end)

    it("offset defaults match TOPLEFT anchor values", function()
        local anchor = ns.HOTKEY_POSITION_ANCHORS["TOPLEFT"]
        expect(ns.DEFAULTS.essential_hotkeys_offsetX).to_equal(anchor.x)
        expect(ns.DEFAULTS.essential_hotkeys_offsetY).to_equal(anchor.y)
        expect(ns.DEFAULTS.utility_hotkeys_offsetX).to_equal(anchor.x)
        expect(ns.DEFAULTS.utility_hotkeys_offsetY).to_equal(anchor.y)
    end)

    it("stacks offset defaults match BOTTOMRIGHT anchor values", function()
        local anchor = ns.HOTKEY_POSITION_ANCHORS["BOTTOMRIGHT"]
        expect(ns.DEFAULTS.essential_stacks_offsetX).to_equal(anchor.x)
        expect(ns.DEFAULTS.essential_stacks_offsetY).to_equal(anchor.y)
        expect(ns.DEFAULTS.utility_stacks_offsetX).to_equal(anchor.x)
        expect(ns.DEFAULTS.utility_stacks_offsetY).to_equal(anchor.y)
        expect(ns.DEFAULTS.buffs_stacks_offsetX).to_equal(anchor.x)
        expect(ns.DEFAULTS.buffs_stacks_offsetY).to_equal(anchor.y)
    end)

    it("stacks defaults have sensible values", function()
        expect(ns.DEFAULTS.essential_stacks_fontSize).to_equal(12)
        expect(ns.DEFAULTS.essential_stacks_position).to_equal("BOTTOMRIGHT")
        expect(ns.DEFAULTS.utility_stacks_fontSize).to_equal(12)
        expect(ns.DEFAULTS.utility_stacks_position).to_equal("BOTTOMRIGHT")
        expect(ns.DEFAULTS.buffs_stacks_fontSize).to_equal(12)
        expect(ns.DEFAULTS.buffs_stacks_position).to_equal("BOTTOMRIGHT")
    end)
end)

describe("Display maps", function()
    it("maps all direction values", function()
        expect(ns.DIRECTION_DISPLAY["DOWN"]).to_equal("Down")
        expect(ns.DIRECTION_DISPLAY["UP"]).to_equal("Up")
    end)

    it("maps all align values", function()
        expect(ns.ALIGN_DISPLAY["LEFT"]).to_equal("Left")
        expect(ns.ALIGN_DISPLAY["CENTER"]).to_equal("Center")
        expect(ns.ALIGN_DISPLAY["RIGHT"]).to_equal("Right")
    end)

    it("maps all layout values", function()
        expect(ns.LAYOUT_DISPLAY["STATIC"]).to_equal("Static")
        expect(ns.LAYOUT_DISPLAY["DYNAMIC"]).to_equal("Dynamic")
    end)

    it("maps all hotkey positions", function()
        local positions = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT",
            "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER" }
        for _, pos in ipairs(positions) do
            expect(ns.HOTKEY_POSITION_DISPLAY[pos] ~= nil).to_be_truthy()
        end
    end)
end)

describe("Hotkey position anchors", function()
    it("has anchors for all positions", function()
        for pos, _ in pairs(ns.HOTKEY_POSITION_DISPLAY) do
            local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
            expect(anchor ~= nil).to_be_truthy()
            expect(anchor.point).to_be_type("string")
            expect(anchor.x).to_be_type("number")
            expect(anchor.y).to_be_type("number")
        end
    end)

    it("has justify for all positions", function()
        for pos, _ in pairs(ns.HOTKEY_POSITION_DISPLAY) do
            local justify = ns.HOTKEY_POSITION_JUSTIFY[pos]
            expect(justify ~= nil).to_be_truthy()
        end
    end)

    it("uses correct justify for left/center/right columns", function()
        expect(ns.HOTKEY_POSITION_JUSTIFY["TOPLEFT"]).to_equal("LEFT")
        expect(ns.HOTKEY_POSITION_JUSTIFY["TOP"]).to_equal("CENTER")
        expect(ns.HOTKEY_POSITION_JUSTIFY["TOPRIGHT"]).to_equal("RIGHT")
        expect(ns.HOTKEY_POSITION_JUSTIFY["LEFT"]).to_equal("LEFT")
        expect(ns.HOTKEY_POSITION_JUSTIFY["CENTER"]).to_equal("CENTER")
        expect(ns.HOTKEY_POSITION_JUSTIFY["RIGHT"]).to_equal("RIGHT")
    end)
end)

describe("SavedVariables merge", function()
    it("populated ns.db with defaults on ADDON_LOADED", function()
        -- The runner triggers ADDON_LOADED via loading Core.lua
        -- which sets up EnhancedCDMDB and ns.db
        expect(ns.db ~= nil).to_be_truthy()
        for k, v in pairs(ns.DEFAULTS) do
            if type(v) == "table" then
                expect(type(ns.db[k])).to_equal("table")
            else
                expect(ns.db[k]).to_equal(v)
            end
        end
    end)
end)
