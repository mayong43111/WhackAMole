-- ============================================================================
-- 场景1: 所有事件触发验证
-- ============================================================================
-- 目的：验证所有关键施法事件是否都能被正常触发
-- 触发条件：所有关键事件（START, SUCCEEDED, CHANNEL_START, INTERRUPTED）都被触发过
-- ============================================================================

local addonName, ns = ...
ns.Scenarios = ns.Scenarios or {}

local Scenario = {}

Scenario.name = "场景1: 事件验证"
Scenario.description = "所有事件触发一次"
Scenario.rowHeight = 60  -- 需要更多空间显示多行文本

-- 事件名称映射（用于显示）
local eventDisplayNames = {
    ADDON_LOADED = "插件加载",
    PLAYER_LOGIN = "玩家登录",
    UNIT_SPELLCAST_START = "施法开始",
    UNIT_SPELLCAST_CHANNEL_START = "引导开始",
    UNIT_SPELLCAST_CHANNEL_STOP = "引导停止",
    UNIT_SPELLCAST_CHANNEL_UPDATE = "引导更新",
    UNIT_SPELLCAST_STOP = "施法停止",
    UNIT_SPELLCAST_FAILED = "施法失败",
    UNIT_SPELLCAST_INTERRUPTED = "施法打断",
    UNIT_SPELLCAST_SUCCEEDED = "施法成功"
}

-- 监听所有事件
Scenario.events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_SUCCEEDED"
}

-- 事件处理器
function Scenario:OnEvent(eventName, state, ...)
    -- 标记事件已触发
    if eventName == "ADDON_LOADED" then
        state.eventsTriggered.ADDON_LOADED = true
    elseif eventName == "PLAYER_LOGIN" then
        state.eventsTriggered.PLAYER_LOGIN = true
    elseif eventName == "UNIT_SPELLCAST_START" then
        state.eventsTriggered.START = true
    elseif eventName == "UNIT_SPELLCAST_CHANNEL_START" then
        state.eventsTriggered.CHANNEL_START = true
    elseif eventName == "UNIT_SPELLCAST_CHANNEL_STOP" then
        state.eventsTriggered.CHANNEL_STOP = true
    elseif eventName == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        state.eventsTriggered.CHANNEL_UPDATE = true
    elseif eventName == "UNIT_SPELLCAST_STOP" then
        state.eventsTriggered.STOP = true
    elseif eventName == "UNIT_SPELLCAST_FAILED" then
        state.eventsTriggered.FAILED = true
    elseif eventName == "UNIT_SPELLCAST_INTERRUPTED" then
        state.eventsTriggered.INTERRUPTED = true
    elseif eventName == "UNIT_SPELLCAST_SUCCEEDED" then
        state.eventsTriggered.SUCCEEDED = true
    end
    
    -- 计算已触发的事件数量
    local triggeredCount = 0
    local totalCount = 10
    local triggeredList = {}
    local missingList = {}
    
    local checkList = {
        {key = "ADDON_LOADED", name = "插件加载"},
        {key = "PLAYER_LOGIN", name = "玩家登录"},
        {key = "START", name = "施法开始"},
        {key = "CHANNEL_START", name = "引导开始"},
        {key = "CHANNEL_STOP", name = "引导停止"},
        {key = "CHANNEL_UPDATE", name = "引导更新"},
        {key = "STOP", name = "施法停止"},
        {key = "FAILED", name = "施法失败"},
        {key = "INTERRUPTED", name = "施法打断"},
        {key = "SUCCEEDED", name = "施法成功"}
    }
    
    for _, item in ipairs(checkList) do
        if state.eventsTriggered[item.key] then
            triggeredCount = triggeredCount + 1
            table.insert(triggeredList, item.name)
        else
            table.insert(missingList, item.name)
        end
    end
    
    -- 更新描述显示进度和详情
    local descParts = {}
    table.insert(descParts, string.format("%d/%d 事件已触发", triggeredCount, totalCount))
    
    if #missingList > 0 then
        table.insert(descParts, "待触发: " .. table.concat(missingList, ", "))
    end
    
    Scenario.description = table.concat(descParts, " | ")
    
    -- 更新UI显示
    if state.scenarioRows and state.scenarioRows[1] then
        local row = state.scenarioRows[1]
        if row.descText then
            row.descText:SetText(Scenario.description)
        end
    end
    
    -- 检查是否所有事件都已触发
    if triggeredCount == totalCount then
        return true  -- 返回true表示场景通过
    end
    
    return false
end

table.insert(ns.Scenarios, Scenario)
