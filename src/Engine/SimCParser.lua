local _, ns = ...
ns = ns or {}
local SimCParser = {}
ns.SimCParser = SimCParser

function SimCParser.ParseCondition(condStr)
    if not condStr or condStr == "" then
        return "true"
    end

    local parsed = condStr

    -- 1. Replace Operators
    parsed = parsed:gsub("!=", "~=")
    parsed = parsed:gsub("([^<>~=])=", "%1==")
    parsed = parsed:gsub("^=", "==")
    parsed = parsed:gsub("&", " and ")
    parsed = parsed:gsub("|", " or ")
    parsed = parsed:gsub("!", " not ")

    -- 2. Translate Variables
    parsed = parsed:gsub("([%a_][%w_%.]*)", function(token)
        if token == "and" or token == "or" or token == "not" or
           token == "true" or token == "false" or token == "nil" then
            return token
        end
        return "state." .. token
    end)

    return parsed
end

function SimCParser.Compile(condStr)
    local luaCode = SimCParser.ParseCondition(condStr)
    -- Wrap in a function that takes 'state' as an argument
    local funcBody = "local state = ...; return " .. luaCode
    local func, err = loadstring(funcBody)
    if not func then
        -- ns.Error("SimC Compilation Error: " .. (err or "unknown") .. " for: " .. condStr)
        return function() return false end
    end
    return func
end

function SimCParser.ParseActionLine(line)
    line = line:gsub("^actions%+=/", "")
    local parts = {}
    -- Fix: split by comma but respect basic nesting? SimC is usually simple.
    -- Simple gmatch [^,]+ fails on "if=foo,target=bar".
    -- But for MVP, we might just assume the first comma separates action from params.
    
    local firstComma = line:find(",")
    local actionName, rest
    
    if firstComma then
        actionName = line:sub(1, firstComma - 1)
        rest = line:sub(firstComma + 1)
    else
        actionName = line
        rest = ""
    end
    
    local conditionFunc = nil
    
    if rest and rest ~= "" then
         -- Look for if= condition
         local ifPos = rest:find("if=")
         if ifPos then
             local condStr = rest:sub(ifPos + 3)
             -- Cut off any future params if needed? APL usually puts if at the end.
             conditionFunc = SimCParser.Compile(condStr)
         end
    end
    
    if not conditionFunc then
        conditionFunc = function() return true end
    end
    
    return {
        action = actionName, -- Was 'name' before, changed to 'action' to match Executor
        condition = conditionFunc,
        original = line
    }
end

return SimCParser
