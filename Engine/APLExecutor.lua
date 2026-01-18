local _, ns = ...
local APLExecutor = {}
ns.APLExecutor = APLExecutor

--- Iterates through the APL and returns the first action whose condition is met.
-- @param apl table: The APL list (array of entries). Each entry should have { action = "name", condition = function(state) ... end }
-- @param state table: The current game state object.
-- @return string|nil: The name of the action to perform, or nil if no action is met.
function APLExecutor.Process(apl, state)
    if not apl then return nil end
    
    for i, entry in ipairs(apl) do
        local allowed = true
        
        -- If there is a condition, check it
        if entry.condition then
            -- condition is expected to be a compiled function from SimCParser
            -- entry.condition(state)
            if type(entry.condition) == "function" then
                -- Safely execute
                local success, result = pcall(entry.condition, state)
                if success then
                    allowed = result
                else
                    -- On error, treat as false? Or log?
                    allowed = false
                end
            else
                -- If it's not a function (e.g. static boolean), use it directly
                allowed = entry.condition
            end
        end
        
        if allowed then
             return entry.action
        end
    end
    
    return nil
end
