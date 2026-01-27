-- ============================================================================
-- 场景4: 施法技能失败
-- ============================================================================
-- 目的：验证施法失败事件的触发
-- 触发条件：UNIT_SPELLCAST_FAILED事件触发
-- 测试方法：尝试对超出射程的目标施法，或者在不满足条件时施法
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景4: 施法失败"
Scenario.description = "施法技能失败（超出射程等）"

-- 监听失败事件
Scenario.events = {
    "UNIT_SPELLCAST_FAILED",
}

-- 事件处理器
function Scenario:OnEvent(eventName, state, ...)
    if eventName == "UNIT_SPELLCAST_FAILED" then
        return true  -- 场景通过
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
