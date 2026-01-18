-- Simple Lua Unit Testing Framework
local TestRunner = {}

function TestRunner:New()
    local newObj = { tests = {} }
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

function TestRunner:Desc(description, func)
    table.insert(self.tests, { desc = description, func = func })
end

function TestRunner:Run()
    print("--------------------------------------------------")
    print("Running Tests...")
    print("--------------------------------------------------")
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(self.tests) do
        local status, err = pcall(test.func)
        if status then
            print("[PASS] " .. test.desc)
            passed = passed + 1
        else
            print("[FAIL] " .. test.desc)
            print("       Error: " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("--------------------------------------------------")
    print(string.format("Summary: %d Passed, %d Failed", passed, failed))
    print("--------------------------------------------------")
    return failed == 0
end

-- Assertions
function AssertEq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s [Expected: %s, Actual: %s]", msg or "Assertion Failed", tostring(expected), tostring(actual)), 2)
    end
end

function AssertTrue(val, msg)
    if not val then
        error(msg or "Expected true, got false", 2)
    end
end

return TestRunner
