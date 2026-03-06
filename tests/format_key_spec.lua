-- Tests for FormatKeyText — abbreviates raw WoW key names
local ns = _G._test_ns

describe("FormatKeyText", function()
    local fmt = ns._FormatKeyText

    it("returns nil for nil input", function()
        expect(fmt(nil)).to_be_nil()
    end)

    it("passes through simple keys unchanged", function()
        expect(fmt("1")).to_equal("1")
        expect(fmt("Q")).to_equal("Q")
        expect(fmt("F1")).to_equal("F1")
    end)

    it("abbreviates SHIFT- to S", function()
        expect(fmt("SHIFT-1")).to_equal("S1")
        expect(fmt("SHIFT-Q")).to_equal("SQ")
    end)

    it("abbreviates CTRL- to C", function()
        expect(fmt("CTRL-1")).to_equal("C1")
        expect(fmt("CTRL-F")).to_equal("CF")
    end)

    it("abbreviates ALT- to A", function()
        expect(fmt("ALT-1")).to_equal("A1")
        expect(fmt("ALT-Z")).to_equal("AZ")
    end)

    it("abbreviates combined modifiers", function()
        expect(fmt("SHIFT-CTRL-1")).to_equal("SC1")
        expect(fmt("CTRL-ALT-F1")).to_equal("CAF1")
        expect(fmt("SHIFT-ALT-Q")).to_equal("SAQ")
    end)

    it("abbreviates MOUSEWHEELUP to MWU", function()
        expect(fmt("MOUSEWHEELUP")).to_equal("MWU")
        expect(fmt("SHIFT-MOUSEWHEELUP")).to_equal("SMWU")
    end)

    it("abbreviates MOUSEWHEELDOWN to MWD", function()
        expect(fmt("MOUSEWHEELDOWN")).to_equal("MWD")
    end)

    it("abbreviates BUTTON# to M#", function()
        expect(fmt("BUTTON4")).to_equal("M4")
        expect(fmt("BUTTON5")).to_equal("M5")
        expect(fmt("SHIFT-BUTTON4")).to_equal("SM4")
    end)

    it("abbreviates NUMPAD# to N#", function()
        expect(fmt("NUMPAD0")).to_equal("N0")
        expect(fmt("NUMPAD9")).to_equal("N9")
    end)

    it("abbreviates NUMPADDECIMAL to N.", function()
        expect(fmt("NUMPADDECIMAL")).to_equal("N.")
    end)

    it("abbreviates NUMPADPLUS to N+", function()
        expect(fmt("NUMPADPLUS")).to_equal("N+")
    end)

    it("abbreviates NUMPADMINUS to N-", function()
        expect(fmt("NUMPADMINUS")).to_equal("N-")
    end)

    it("abbreviates NUMPADMULTIPLY to N*", function()
        expect(fmt("NUMPADMULTIPLY")).to_equal("N*")
    end)

    it("abbreviates NUMPADDIVIDE to N/", function()
        expect(fmt("NUMPADDIVIDE")).to_equal("N/")
    end)

    it("abbreviates PAGEUP to PU", function()
        expect(fmt("PAGEUP")).to_equal("PU")
        expect(fmt("SHIFT-PAGEUP")).to_equal("SPU")
    end)

    it("abbreviates PAGEDOWN to PD", function()
        expect(fmt("PAGEDOWN")).to_equal("PD")
    end)

    it("abbreviates SPACEBAR to SP", function()
        expect(fmt("SPACEBAR")).to_equal("SP")
        expect(fmt("CTRL-SPACEBAR")).to_equal("CSP")
    end)

    it("abbreviates SPACE to SP", function()
        expect(fmt("SPACE")).to_equal("SP")
        expect(fmt("SHIFT-SPACE")).to_equal("SSP")
    end)

    it("abbreviates BACKSPACE to BS", function()
        expect(fmt("BACKSPACE")).to_equal("BS")
    end)

    it("abbreviates CAPSLOCK to CAP", function()
        expect(fmt("CAPSLOCK")).to_equal("CAP")
    end)

    it("abbreviates INSERT to INS", function()
        expect(fmt("INSERT")).to_equal("INS")
    end)

    it("abbreviates DELETE to DEL", function()
        expect(fmt("DELETE")).to_equal("DEL")
    end)

    it("abbreviates HOME to HM", function()
        expect(fmt("HOME")).to_equal("HM")
    end)

    it("abbreviates arrow keys", function()
        expect(fmt("DOWNARROW")).to_equal("DN")
        expect(fmt("UPARROW")).to_equal("UP")
        expect(fmt("LEFTARROW")).to_equal("LT")
        expect(fmt("RIGHTARROW")).to_equal("RT")
        expect(fmt("SHIFT-DOWNARROW")).to_equal("SDN")
    end)
end)
