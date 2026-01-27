-- ============================================================================
-- 场景6: 非 GCD 技能监控
-- ============================================================================
-- 目的：验证不触发全局冷却的技能检测
-- 触发条件：UNIT_SPELLCAST_SUCCEEDED 事件触发但没有对应的 START 事件
-- 测试方法：使用饰品等不触发 GCD 的物品
-- 特征：这些技能只有 SUCCEEDED 事件，没有 START 事件
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景6: 非GCD技能"
Scenario.description = "不触发GCD的技能（饰品等）"

-- 监听 START 和 SUCCEEDED 事件
Scenario.events = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED",
}

-- 记录最近的 START 事件（带时间戳）
local recentStarts = {}  -- { [spellID] = timestamp }
local WINDOW_TIME = 0.5  -- 时间窗口：500ms

-- 事件处理器
function Scenario:OnEvent(eventName, state, unit, castGUID, spellID)
    local now = GetTime()
    
    if eventName == "UNIT_SPELLCAST_START" then
        -- 记录这个技能的 START 事件
        recentStarts[spellID] = now
        return false
        
    elseif eventName == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 检查是否有对应的 START 事件
        local startTime = recentStarts[spellID]
        
        if not startTime or (now - startTime) > WINDOW_TIME then
            -- 没有 START 事件，或者时间窗口已过 -> 非 GCD 技能
            return true
        else
            -- 清理已匹配的 START 记录
            recentStarts[spellID] = nil
        end
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
