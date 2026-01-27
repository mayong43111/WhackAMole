-- ============================================================================
-- 场景2: 施法技能正常施法
-- ============================================================================
-- 目的：验证普通施法技能从开始到完成的完整流程
-- 触发条件：施法技能（有施法时间）正常完成，elapsed > 0.5秒
-- 测试方法：施放霜火之箭、寒冰箭等有施法时间的技能
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景2: 普通施法"
Scenario.description = "施法技能正常施法（霜火之箭等）"

-- 监听施法成功事件
Scenario.events = {
    "UNIT_SPELLCAST_SUCCEEDED",
}

-- 事件处理器
function Scenario:OnEvent(eventName, state, ...)
    if eventName ~= "UNIT_SPELLCAST_SUCCEEDED" then
        return false
    end
    
    -- 检查是否是正常施法（有施法时间，不是瞬发）
    local elapsed = state.castStartTime > 0 and (GetTime() - state.castStartTime) or 0
    
    if elapsed > 0.5 then
        return true  -- 场景通过
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
