-- ============================================================================
-- 场景3: 施法技能被打断
-- ============================================================================
-- 目的：验证施法打断事件的触发
-- 触发条件：UNIT_SPELLCAST_INTERRUPTED事件触发
-- 测试方法：施放霜火之箭等技能，然后移动或被敌人击中打断
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景3: 施法打断"
Scenario.description = "普通施法被打断（引导技能打断触发CHANNEL_STOP）"

-- 监听打断事件
Scenario.events = {
    "UNIT_SPELLCAST_INTERRUPTED",      -- 普通施法打断
}

-- 事件处理器
function Scenario:OnEvent(eventName, state, ...)
    if eventName == "UNIT_SPELLCAST_INTERRUPTED" then
        -- 普通施法被打断
        return true
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
