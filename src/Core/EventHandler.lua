local addon, ns = ...

-- =========================================================================
-- Core/EventHandler.lua - 事件处理和节流系统
-- =========================================================================

-- 从 Core.lua 拆分而来，负责战斗事件处理和事件节流

local EventHandler = {}
ns.CoreEventHandler = EventHandler

-- 引用配置模块
local Config = ns.CoreConfig

-- =========================================================================
-- 战斗日志事件处理（重构后：35行 vs 原50行）
-- =========================================================================

--- 战斗日志事件处理器
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
function EventHandler.OnCombatLogEvent(addon, event, ...)
    local timestamp, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    
    -- 只处理玩家相关事件
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    
    -- 检查是否为优先级事件
    local isPriority = Config:IsPriorityEvent(eventType)
    
    -- 检查节流间隔
    local now = GetTime()
    local timeSinceLastUpdate = now - addon.eventThrottle.lastUpdate
    
    if isPriority then
        -- 优先级事件立即加入优先队列
        EventHandler.AddPriorityEvent(addon, timestamp, eventType, destName)
        
        -- 如果距离上次更新超过节流间隔，立即触发更新
        if timeSinceLastUpdate >= Config.THROTTLE_INTERVAL then
            EventHandler.ProcessPendingEvents(addon)
            addon.eventThrottle.lastUpdate = now
        end
    else
        -- 普通事件加入待处理队列
        if timeSinceLastUpdate >= Config.THROTTLE_INTERVAL then
            EventHandler.AddNormalEvent(addon, timestamp, eventType, destName)
        end
    end
end

--- 添加优先级事件到队列
-- @param addon WhackAMole 插件实例
-- @param timestamp 时间戳
-- @param eventType 事件类型
-- @param destName 目标名称
function EventHandler.AddPriorityEvent(addon, timestamp, eventType, destName)
    table.insert(addon.eventThrottle.priorityQueue, {
        timestamp = timestamp,
        eventType = eventType,
        destName = destName
    })
end

--- 添加普通事件到队列
-- @param addon WhackAMole 插件实例
-- @param timestamp 时间戳
-- @param eventType 事件类型
-- @param destName 目标名称
function EventHandler.AddNormalEvent(addon, timestamp, eventType, destName)
    table.insert(addon.eventThrottle.pendingEvents, {
        timestamp = timestamp,
        eventType = eventType,
        destName = destName
    })
end

--- 处理待处理事件
-- @param addon WhackAMole 插件实例
function EventHandler.ProcessPendingEvents(addon)
    -- 先处理优先级队列
    for _, event in ipairs(addon.eventThrottle.priorityQueue) do
        EventHandler.HandleCombatEvent(addon, event)
    end
    
    -- 再处理普通队列
    for _, event in ipairs(addon.eventThrottle.pendingEvents) do
        EventHandler.HandleCombatEvent(addon, event)
    end
    
    -- 清空队列
    addon.eventThrottle.priorityQueue = {}
    addon.eventThrottle.pendingEvents = {}
end

--- 处理单个战斗事件
-- @param addon WhackAMole 插件实例
-- @param event 事件对象
function EventHandler.HandleCombatEvent(addon, event)
    -- 根据事件类型执行不同的逻辑
    if event.eventType == "SPELL_CAST_SUCCESS" then
        -- 技能施放成功
        if ns.Logger then
            ns.Logger:Debug("Combat", "Spell cast success: " .. (event.destName or "unknown"))
        end
    elseif event.eventType == "SPELL_INTERRUPT" then
        -- 技能被打断
        if ns.Logger then
            ns.Logger:Debug("Combat", "Spell interrupted")
        end
    end
    
    -- 可在此处添加更多事件处理逻辑
end

return EventHandler
