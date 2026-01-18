local RunnerClass = require("Tests.TestRunner")
local Runner = RunnerClass:New()

local parse = require("Engine.SimCParser").Compile
local parseLine = require("Engine.SimCParser").ParseActionLine
local ns = {} -- Test Utils not needed/available

-- Mock State setup
local state = {
    buff = {
        enrage = { up = true, remains = 5 },
        weakness = { up = false, remains = 0 }
    },
    debuff = {
        wound = { up = true, stack = 3 }
    },
    cooldown = {
        mortal_strike = { remains = 0 },
        execute = { remains = 5 }
    },
    target = {
        time_to_die = 10,
        health = { pct = 20 }
    }
}
-- Bind state globally as SimCParser likely looks for it there or via ns.state
_G.state = state

Runner:Desc("SimCParser: Basic Condition", function()
    local func, err = parse("buff.enrage.up")
    assert(func, "Should return a function. Error: " .. tostring(err))
    assert(func() == true, "buff.enrage.up should be true")

    local func2 = parse("buff.weakness.up")
    assert(func2() == false, "buff.weakness.up should be false")
end)

Runner:Desc("SimCParser: Logic Operators", function()
    -- OR
    local f1 = parse("buff.enrage.up|buff.weakness.up")
    assert(f1() == true, "OR operator (true|false) failed")
    
    -- AND
    local f2 = parse("buff.enrage.up&buff.weakness.up")
    assert(f2() == false, "AND operator (true&false) failed")

    -- NOT
    local f3 = parse("!buff.weakness.up")
    assert(f3() == true, "NOT operator (!false) failed")
end)

Runner:Desc("SimCParser: Comparisons", function()
    -- Stack check
    local f1 = parse("debuff.wound.stack>=3")
    assert(f1() == true, "Stack check >= 3 failed")

    -- Health check
    local f2 = parse("target.health.pct<20") -- logic says 20
    assert(f2() == false, "Health check < 20 failed (is 20)")

    local f3 = parse("target.health.pct<=20")
    assert(f3() == true, "Health check <= 20 failed")
end)

Runner:Desc("SimCParser: Parse Action Line", function()
    local line = "actions+=/mortal_strike,if=buff.enrage.up&target.health.pct<=20"
    local action = parseLine(line)
    
    assert(action, "Failed to parse action line")
    assert(action.name == "mortal_strike", "Wrong action name: " .. tostring(action.name))
    assert(type(action.condition) == "function", "Condition should be a function")
    
    local res = action.condition()
    assert(res == true, "Complex condition should evaluate to true")
end)

Runner:Desc("SimCParser: Parse Action without Condition", function()
    local line = "actions+=/execute"
    local action = parseLine(line)
    
    assert(action, "Should parse unconditional action")
    assert(action.name == "execute")
    assert(action.condition() == true, "Unconditional action should return true")
end)

return Runner
