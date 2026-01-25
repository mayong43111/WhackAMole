local _, ns = ...
local APLExecutor = {}
ns.APLExecutor = APLExecutor

-- 缓存上次执行的动作，用于减少日志记录
local lastAction = nil

--- Iterates through the APL and returns the first action whose condition is met.
-- @param apl table: The APL list (array of entries). Each entry should have { action = "name", condition = function(state) ... end }
-- @param state table: The current game state object.
-- @return string|nil: The name of the action to perform, or nil if no action is met.
function APLExecutor.Process(apl, state)
    if not apl then 
        ns.Logger:Warn("APL", "APL is nil!")
        return nil 
    end
    
    if #apl == 0 then
        ns.Logger:Warn("APL", "APL is empty!")
        return nil
    end

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
                    -- 错误必须记录
                    allowed = false
                    ns.Logger:Error("APL", string.format("条件评估错误 - Action: %s | Error: %s", entry.action or "Unknown", tostring(result)))
                end
            else
                -- If it's not a function (e.g. static boolean), use it directly
                allowed = entry.condition
            end
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
                         -- 详细记录为什么不可用
                         ns.Logger:Log("APL", string.format("[%d] %s: 条件通过但技能不可用 (CD:%.1f, usable:%s)", 
                             i, entry.action, spellState.cooldown_remains or 0, tostring(spellState.usable)))
                     end
                 else
                     -- 错误必须记录
                     ready = false
                     ns.Logger:Warn("APL", string.format("[%d] 技能状态缺失: %s (ActionMap未找到)", i, entry.action))
                 end
             end

             if ready then
                 -- 只有当动作发生变化时才记录
                 if lastAction ~= entry.action then
                     ns.Logger:Log("APL", string.format("切换技能: %s -> %s", lastAction or "None", entry.action))
                     lastAction = entry.action
                 end
                 return entry.action
             end
        else
            -- 条件不满足时也记录（仅前3个）
            if i <= 3 then
                ns.Logger:Log("APL", string.format("[%d] %s: 条件不满足", i, entry.action or "Unknown"))
            end
        end
    end
    
    -- 只有当从有动作变为无动作时才记录
    if lastAction ~= nil then
        ns.Logger:Log("APL", "切换技能: " .. lastAction .. " -> None (无可用动作)")
        lastAction = nil
    end
end