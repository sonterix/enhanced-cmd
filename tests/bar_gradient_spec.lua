-- Tests for ApplyBarGradient and ResetBarGradient
local ns = _G._test_ns

-- Helper: create a mock bar frame with a StatusBar child and trackable texture
local function makeMockBarFrame(cooldownID)
    local barFrame = CreateFrame("Frame")
    local statusBar = CreateFrame("StatusBar", nil, barFrame)
    local tex = { _gradientCalls = {} }
    tex.SetGradient = function(self, orient, startColor, endColor)
        table.insert(self._gradientCalls, {
            orient = orient, startColor = startColor, endColor = endColor
        })
    end
    statusBar._statusBarTexture = tex
    barFrame.cooldownID = cooldownID
    return barFrame, statusBar, tex
end

describe("ApplyBarGradient", function()
    it("applies gradient from db.bars_colors", function()
        local barFrame, _, tex = makeMockBarFrame(42)
        ns.db.bars_colors = {[42] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        ns.ApplyBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0)
        expect(call.startColor.b).to_equal(0)
        expect(call.endColor.r).to_equal(0)
        expect(call.endColor.g).to_equal(1)
        expect(call.endColor.b).to_equal(0)
        ns.db.bars_colors = {}
    end)

    it("does nothing when cooldownID has no color", function()
        local barFrame, _, tex = makeMockBarFrame(99)
        ns.db.bars_colors = {}
        ns.ApplyBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(0)
    end)

    it("does nothing when no StatusBar child", function()
        local barFrame = CreateFrame("Frame")
        barFrame.cooldownID = 50
        ns.db.bars_colors = {[50] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        -- Should not error
        ns.ApplyBarGradient(barFrame)
        ns.db.bars_colors = {}
    end)

    it("does nothing when texture is nil", function()
        local barFrame = CreateFrame("Frame")
        local statusBar = CreateFrame("StatusBar", nil, barFrame)
        statusBar._statusBarTexture = nil
        barFrame.cooldownID = 55
        ns.db.bars_colors = {[55] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        -- Should not error
        ns.ApplyBarGradient(barFrame)
        ns.db.bars_colors = {}
    end)
end)

describe("ResetBarGradient", function()
    it("resets to default orange", function()
        local barFrame, _, tex = makeMockBarFrame(42)
        ns.ResetBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0.5)
        expect(call.startColor.b).to_equal(0.25)
        expect(call.endColor.r).to_equal(1)
        expect(call.endColor.g).to_equal(0.5)
        expect(call.endColor.b).to_equal(0.25)
    end)

    it("does nothing when no StatusBar child", function()
        local barFrame = CreateFrame("Frame")
        -- Should not error
        ns.ResetBarGradient(barFrame)
    end)
end)
