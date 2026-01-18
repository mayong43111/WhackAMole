-- Test_SpecDetection.lua
local RunnerClass = require("Tests.TestRunner")
local Runner = RunnerClass:New()

-- 1. Setup Environment
require("Tests.MockWoW")

local addonName = "WhackAMole"
local ns = {}
-- Add minimal Registry stub usually found in Classes/Registry.lua
ns.SpecRegistry = {}
ns.SpecRegistry.handlers = {}
function ns.SpecRegistry:Register(class, func)
    self.handlers[class] = func
end
function ns.SpecRegistry:Detect(class)
    if self.handlers[class] then return self.handlers[class]() end
    return nil
end

-- 2. Load File Under Test
local chunk, err = loadfile("Core/SpecDetection.lua")
if not chunk then error("Failed to load Core/SpecDetection.lua: " .. err) end
chunk(addonName, ns)

-- 3. Register a Mock Class Handler (Like Classes/Warrior.lua)
ns.SpecRegistry:Register("WARRIOR", function()
    if IsPlayerSpell(46924) then return 71 end -- Bladestorm -> Arms
    if IsPlayerSpell(46917) then return 72 end -- Titan's Grip -> Fury
    if IsPlayerSpell(46968) then return 73 end -- Shockwave -> Prot
    return nil
end)


-- Tests

Runner:Desc("SpecDetection: Should detect spec by Talent Points (Arms)", function()
    -- Arms: Tab 1 has most points
    MockWoW:Setup("WARRIOR", 80, {51, 10, 0}, {})
    
    local specID = ns.SpecDetection:GetSpecID()
    AssertEq(71, specID, "Should detect Arms (71) based on Tab 1 points")
end)

Runner:Desc("SpecDetection: Should detect spec by Talent Points (Fury)", function()
    -- Fury: Tab 2 has most points
    MockWoW:Setup("WARRIOR", 80, {5, 51, 5}, {})
    
    local specID = ns.SpecDetection:GetSpecID()
    AssertEq(72, specID, "Should detect Fury (72) based on Tab 2 points")
end)

Runner:Desc("SpecDetection: Should detect spec by Spell Book (Low Level/No Talents)", function()
    -- Low level, no talents, but has Bladestorm spell learned (unlikely scenario but tests logic)
    MockWoW:Setup("WARRIOR", 80, {0, 0, 0}, {[46924] = true}) -- 46924 is Bladestorm
    
    local specID = ns.SpecDetection:GetSpecID()
    AssertEq(71, specID, "Should detect Arms (71) via Spell Heuristic")
end)

Runner:Desc("SpecDetection: Should return nil if detection fails (Max Level, No Points)", function()
    MockWoW:Setup("WARRIOR", 80, {0, 0, 0}, {}) -- Max level but no data
    
    local specID = ns.SpecDetection:GetSpecID()
    AssertEq(nil, specID, "Should return nil for unknown spec") 
end)

return Runner
