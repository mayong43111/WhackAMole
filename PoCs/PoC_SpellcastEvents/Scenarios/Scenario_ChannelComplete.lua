-- ============================================================================
-- 场景5: 引导技能正常释放
-- ============================================================================
-- 目的：验证引导技能完整释放的流程
-- 触发条件：UNIT_SPELLCAST_CHANNEL_STOP事件触发
-- 测试方法：施放暴风雪等引导技能，让其完整释放完毕
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景5: 引导施法"
Scenario.description = "引导技能正常释放（暴风雪等）"

-- 监听引导停止事件
Scenario.events = {
    "UNIT_SPELLCAST_CHANNEL_STOP",
}

-- 事件处理器
function Scenario:OnEvent(eventName, state, ...)
    if eventName == "UNIT_SPELLCAST_CHANNEL_STOP" then
        return true  -- 场景通过
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
