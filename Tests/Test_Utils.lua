-- Test_Utils.lua
local RunnerClass = require("Tests.TestRunner")
local Runner = RunnerClass:New()

-- Simulate Addon Environment

local addonName = "WhackAMole"
local ns = {}
-- Load the file under test
-- Manually loading because Lua's require doesn't handle the "..." args like WoW does
local chunk, err = loadfile("Utils.lua")
if not chunk then 
    error("Failed to load Utils.lua: " .. err)
end
chunk(addonName, ns) 


-- Tests
Runner:Desc("formatKey should normalize strings", function()
    local input = "Mortal Strike"
    local expected = "mortal_strike"
    local actual = ns.formatKey(input)
    AssertEq(expected, actual, "Should convert to snake_case")
end)

Runner:Desc("formatKey should remove special chars", function()
    local input = "Heroic Strike!"
    local expected = "heroic_strike"
    local actual = ns.formatKey(input)
    AssertEq(expected, actual, "Should remove non-alphanumeric chars")
end)

Runner:Desc("deepCopy should copy tables recursively", function()
    local original = { a = 1, b = { c = 2 } }
    local copy = ns.deepCopy(original)
    
    AssertEq(original.a, copy.a, "Top level value match")
    AssertEq(original.b.c, copy.b.c, "Nested value match")
    
    copy.b.c = 3
    AssertEq(2, original.b.c, "Modifying copy should not affect original")
end)

return Runner
