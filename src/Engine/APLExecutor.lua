local _, ns = ...
local APLExecutor = {}
ns.APLExecutor = APLExecutor

-- 缓存上次执行的动作，用于减少日志记录
local lastAction = nil
local lastVirtualAction = nil  -- 虚拟预测的独立缓存

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
    
    -- 判断是否为虚拟预测模式
    local isVirtual = state and state.isVirtualState
    local lastActionCache = isVirtual and lastVirtualAction or lastAction

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
                     end
                 else
                     -- 错误必须记录
                     ready = false
                     ns.Logger:Warn("APL", string.format("[%d] 技能状态缺失: %s (ActionMap未找到)", i, entry.action))
                 end
             end

             if ready then
                 -- 只有当动作发生变化时才记录，并输出前3个技能的状态
                 if lastActionCache ~= entry.action then
                     ns.Logger:Log("APL", string.format("切换技能: %s -> %s", lastActionCache or "None", entry.action))
                     
                     -- 输出前3个技能的状态（帮助理解为什么选择了这个技能）
                     for debugIdx = 1, math.min(3, #apl) do
                         local debugEntry = apl[debugIdx]
                         local debugState = state.spell[debugEntry.action]
                         if debugIdx == i then
                             ns.Logger:Log("APL", string.format("  [%d] %s: ✓ 选中", debugIdx, debugEntry.action))
                         elseif debugState and debugState.ready == false then
                             ns.Logger:Log("APL", string.format("  [%d] %s: CD %.1fs", debugIdx, debugEntry.action, debugState.cooldown_remains or 0))
                         else
                             ns.Logger:Log("APL", string.format("  [%d] %s: 条件不满足", debugIdx, debugEntry.action))
                         end
                     end
                     
                     -- 更新对应的缓存
                     if isVirtual then
                         lastVirtualAction = entry.action
                     else
                         lastAction = entry.action
                     end
                 end
                 return entry.action
             end
        end
    end
    
    -- 只有当从有动作变为无动作时才记录
    if lastAction ~= nil then
        ns.Logger:Log("APL", "切换技能: " .. lastAction .. " -> None (无可用动作)")
        lastAction = nil
    end
end