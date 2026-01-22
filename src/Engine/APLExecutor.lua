local _, ns = ...
local APLExecutor = {}
ns.APLExecutor = APLExecutor

--- Iterates through the APL and returns the first action whose condition is met.
-- @param apl table: The APL list (array of entries). Each entry should have { action = "name", condition = function(state) ... end }
-- @param state table: The current game state object.
-- @return string|nil: The name of the action to perform, or nil if no action is met.
function APLExecutor.Process(apl, state)
    if not apl then return nil end
    
    -- 直接调用，内部会判断是否需要记录
    ns.Logger:Log("APL", "--- Start APL Process ---")

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
                    ns.Logger:Log("APL", string.format("Action: %s | Cond: TRUE", entry.action or "Unknown"))
                else
                    -- On error, treat as false? Or log?
                    allowed = false
                    ns.Logger:Log("Error", string.format("Action: %s | Cond: ERROR (%s)", entry.action or "Unknown", tostring(result)))
                end
            else
                -- If it's not a function (e.g. static boolean), use it directly
                allowed = entry.condition
                ns.Logger:Log("APL", string.format("Action: %s | Cond: Static %s", entry.action or "Unknown", tostring(allowed)))
            end
        else
            ns.Logger:Log("APL", string.format("Action: %s | Cond: NONE (Always True)", entry.action or "Unknown"))
        end
        
        if allowed then
             -- Implicit SimC Check: Action must be ready (Cooldown up & Usable)
             -- This handles reactive spells like Overpower (requires proc) or Rampage.
             local ready = true
             
             if state and state.spell and entry.action then
                 -- Access state.spell to trigger metatable logic
                 -- This performs IsUsableSpell() + GetSpellCooldown()
                 local spellState = state.spell[entry.action]
                 
                 -- If the spell exists in our map/book
                 if spellState and type(spellState) == "table" then
                     -- Check consistency
                     if spellState.ready == false then
                         ready = false
                         ns.Logger:Log("APL", string.format(" -> Skipped: Not Ready (Usable=%s, CD_Remains=%s)", tostring(spellState.usable), tostring(spellState.cooldown_remains)))
                     end
                 else
                     ns.Logger:Log("Warn", string.format(" -> Skipped: Spell State Missing for '%s'", entry.action))
                 end
             end

             if ready then
                 ns.Logger:Log("APL", " -> EXECUTING: " .. entry.action)
                 return entry.action
             end
        end
    end
    
    ns.Logger:Log("APL", "--- No Action Met ---")
    return nil
end
