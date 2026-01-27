-- ============================================================================
-- PoC_SpellcastEvents - 施法事件检测验证工具 (WotLK 3.3.5)
-- ============================================================================
-- 模块化架构：独立的 Logger、DebugWindow、ScenarioRegistry
-- 场景注册机制：每个测试场景独立实现
-- ============================================================================

-- ============================================================================
-- 命名空间和依赖模块
-- ============================================================================
local addonName, ns = ...

-- 引用已加载的模块（通过TOC文件顺序加载）
local Logger = ns.Logger
local DebugWindow = ns.DebugWindow
local ScenarioRegistry = ns.ScenarioRegistry

-- ============================================================================
-- 全局状态
-- ============================================================================
local State = {
    -- 施法状态
    castingSpellID = nil,
    castingSpellName = nil,
    castStartTime = 0,
    castEndTime = 0,
    
    -- UI引用
    guideWindow = nil,
    window = nil,
    scenarioRows = {},
    
    -- 事件计数
    eventCount = {},
    
    -- 事件触发标记（用于场景1：验证所有事件）
    eventsTriggered = {},
}

-- ============================================================================
-- C_Timer 兼容层（3.3.5支持）
-- ============================================================================
if not C_Timer then
    C_Timer = {}
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        for i = #timers, 1, -1 do
            local timer = timers[i]
            timer.delay = timer.delay - elapsed
            if timer.delay <= 0 then
                table.remove(timers, i)
                if timer.func then 
                    pcall(timer.func)
                end
            end
        end
    end)
    
    function C_Timer.After(delay, func)
        table.insert(timers, { delay = delay, func = func })
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

local function Now()
    return GetTime()
end

local function FormatTime(timestamp)
    return string.format("%.3f", timestamp or 0)
end

local function LogSeparator()
    Logger:Event(string.rep("=", 70))
end

local function LogEvent(eventName)
    State.eventCount[eventName] = (State.eventCount[eventName] or 0) + 1
    Logger:Event(string.format("[%s #%d] @%s", eventName, State.eventCount[eventName], FormatTime(Now())))
end

local function LogParam(name, value)
    Logger:Event("  " .. name .. ": " .. tostring(value))
end

-- ============================================================================
-- 事件处理器（精简版）
-- ============================================================================

-- 通用事件处理器模板
local function HandleSpellEvent(eventName, unit, castGUID, spellID)
    if unit ~= "player" then return end
    
    LogSeparator()
    LogEvent(eventName)
    LogParam("unit", unit)
    
    if castGUID then LogParam("castGUID", castGUID) end
    if spellID then
        LogParam("spellID", spellID)
        LogParam("spellName", GetSpellInfo(spellID) or "unknown")
    end
    
    return unit, castGUID, spellID
end

-- START事件：记录施法开始
local function OnSpellCastStart(unit, castGUID, spellID)
    local now = Now()
    State.castingSpellID = spellID
    State.castingSpellName = GetSpellInfo(spellID)
    State.castStartTime = now
    
    -- 获取实际施法时间（含急速）
    local castName, _, _, startTimeMs, endTimeMs = UnitCastingInfo("player")
    if castName and endTimeMs then
        State.castEndTime = endTimeMs / 1000
        LogParam("castTime", string.format("%.2f秒", (endTimeMs - startTimeMs) / 1000))
        LogParam("expectedEnd", FormatTime(State.castEndTime))
    else
        -- 回退到基础施法时间
        local _, _, _, baseCastTime = GetSpellInfo(spellID)
        if baseCastTime and baseCastTime > 0 then
            State.castEndTime = now + baseCastTime / 1000
            LogParam("castTime", string.format("%.2f秒（基础）", baseCastTime / 1000))
            LogParam("expectedEnd", FormatTime(State.castEndTime))
        end
    end
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_START", State, unit, castGUID, spellID)
end

-- CHANNEL_START事件：引导施法开始
local function OnSpellCastChannelStart(unit)
    State.castStartTime = Now()
    
    local channelName, _, _, _, _, endTimeMs = UnitChannelInfo("player")
    if channelName then
        LogParam("channelName", channelName)
        if endTimeMs and endTimeMs > 0 then
            LogParam("remaining", string.format("%.2f秒", (endTimeMs / 1000) - Now()))
        end
    end
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_CHANNEL_START", State, unit)
end

-- CHANNEL_STOP事件：引导施法停止
local function OnSpellCastChannelStop(unit)
    LogParam("elapsed", string.format("%.3f秒", Now() - State.castStartTime))
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_CHANNEL_STOP", State, unit)
end

-- CHANNEL_UPDATE事件：引导施法更新（可能被打断）
local function OnSpellCastChannelUpdate(unit)
    local channelName, _, _, _, _, endTimeMs = UnitChannelInfo("player")
    if channelName then
        LogParam("channelName", channelName)
        if endTimeMs and endTimeMs > 0 then
            LogParam("remaining", string.format("%.2f秒", (endTimeMs / 1000) - Now()))
        end
    else
        Logger:Channel("  ⚠️ 引导施法被打断")
    end
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", State, unit)
end

-- STOP事件：常规施法停止
local function OnSpellCastStop(unit)
    local elapsed = State.castStartTime > 0 and (Now() - State.castStartTime) or 0
    LogParam("elapsed", string.format("%.3f秒", elapsed))
    
    if State.castingSpellName then
        LogParam("wasCasting", State.castingSpellName)
    end
    
    State.castingSpellID = nil
    State.castingSpellName = nil
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_STOP", State, unit)
end

-- FAILED事件：施法失败
local function OnSpellCastFailed(unit, castGUID, spellID)
    State.castingSpellID = nil
    State.castingSpellName = nil
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_FAILED", State, unit, castGUID, spellID)
end

-- INTERRUPTED事件：施法被打断
local function OnSpellCastInterrupted(unit, castGUID, spellID)
    local elapsed = State.castStartTime > 0 and (Now() - State.castStartTime) or 0
    LogParam("elapsed", string.format("%.3f秒", elapsed))
    
    State.castingSpellID = nil
    State.castingSpellName = nil
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_INTERRUPTED", State, unit, castGUID, spellID)
end

-- SUCCEEDED事件：施法成功
local function OnSpellCastSucceeded(unit, castGUID, spellID)
    local now = Now()
    local elapsed = State.castStartTime > 0 and (now - State.castStartTime) or 0
    LogParam("elapsed", string.format("%.3f秒", elapsed))
    
    if State.castEndTime > 0 then
        LogParam("timeDiff", string.format("%.3f秒", now - State.castEndTime))
    end
    
    ScenarioRegistry:DispatchEvent("UNIT_SPELLCAST_SUCCEEDED", State, unit, castGUID, spellID)
end

-- ============================================================================
-- GUI - 由 DebugWindow 模块处理
-- ============================================================================

-- ============================================================================
-- 场景状态更新回调
-- ============================================================================

State.OnScenarioStatusChanged = function(scenarioId, status, count)
    local row = State.scenarioRows[scenarioId]
    if not row then return end
    
    local statusMap = {
        passed = {text = "passed " .. count, color = {0, 1, 0}},
        untested = {text = "未测试", color = {0.6, 0.6, 0.6}},
        error = {text = "failed " .. count, color = {1, 0, 0}}
    }
    
    local statusInfo = statusMap[status] or {text = "未知", color = {1, 1, 1}}
    row.statusText:SetText(statusInfo.text)
    row.statusText:SetTextColor(unpack(statusInfo.color))
end

-- ============================================================================
-- 命令处理
-- ============================================================================

local CommandHandlers = {
    guide = function()
        DebugWindow.Show(Logger, State, ScenarioRegistry)
    end,
    
    export = function()
        DebugWindow.Show(Logger, State, ScenarioRegistry)
    end,
    
    reset = function()
        ScenarioRegistry:Reset()
        State.eventsTriggered = {}
        Logger:Clear()
        State.eventCount = {}
        
        for _, row in pairs(State.scenarioRows) do
            row.statusText:SetText("未测试")
            row.statusText:SetTextColor(0.6, 0.6, 0.6)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00已重置所有测试数据|r")
    end,
    
    help = function()
        local messages = {
            "|cff00ff00=== PoC_SpellcastEvents 命令 ===|r",
            "/pocspell guide - 显示测试指导窗口",
            "/pocspell export - 导出日志",
            "/pocspell reset - 重置测试数据",
            "/pocspell help - 显示此帮助",
            " ",
            "|cffff8800已注册场景数: " .. #ScenarioRegistry:GetAll() .. "|r"
        }
        for _, msg in ipairs(messages) do
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end
}

SLASH_POCSPELL1 = "/pocspell"
SLASH_POCSPELL2 = "/pse"
SlashCmdList["POCSPELL"] = function(msg)
    local cmd = msg:lower():trim()
    local handler = CommandHandlers[cmd] or CommandHandlers.guide
    handler()
end

-- ============================================================================
-- 事件分发器
-- ============================================================================

local EventHandlers = {
    UNIT_SPELLCAST_START = function(_, unit, castGUID, spellID)
        local u, g, s = HandleSpellEvent("START", unit, castGUID, spellID)
        if u then OnSpellCastStart(u, g, s) end
    end,
    
    UNIT_SPELLCAST_CHANNEL_START = function(_, unit, ...)
        local u = HandleSpellEvent("CHANNEL_START", unit)
        if u then OnSpellCastChannelStart(u) end
    end,
    
    UNIT_SPELLCAST_CHANNEL_STOP = function(_, unit, ...)
        local u = HandleSpellEvent("CHANNEL_STOP", unit)
        if u then OnSpellCastChannelStop(u) end
    end,
    
    UNIT_SPELLCAST_CHANNEL_UPDATE = function(_, unit, ...)
        local u = HandleSpellEvent("CHANNEL_UPDATE", unit)
        if u then OnSpellCastChannelUpdate(u) end
    end,
    
    UNIT_SPELLCAST_STOP = function(_, unit)
        local u = HandleSpellEvent("STOP", unit)
        if u then OnSpellCastStop(u) end
    end,
    
    UNIT_SPELLCAST_FAILED = function(_, unit, castGUID, spellID)
        local u, g, s = HandleSpellEvent("FAILED", unit, castGUID, spellID)
        if u then OnSpellCastFailed(u, g, s) end
    end,
    
    UNIT_SPELLCAST_INTERRUPTED = function(_, unit, castGUID, spellID)
        Logger:System(string.format("[TRACE] INTERRUPTED 事件原始触发: unit=%s, castGUID=%s, spellID=%s", 
            tostring(unit), tostring(castGUID), tostring(spellID)))
        local u, g, s = HandleSpellEvent("INTERRUPTED", unit, castGUID, spellID)
        if u then 
            Logger:System("[TRACE] 调用 OnSpellCastInterrupted")
            OnSpellCastInterrupted(u, g, s)
        else
            Logger:System("[TRACE] unit 不是 player，忽略")
        end
    end,
    
    UNIT_SPELLCAST_SUCCEEDED = function(_, unit, castGUID, spellID)
        local u, g, s = HandleSpellEvent("SUCCEEDED", unit, castGUID, spellID)
        if u then OnSpellCastSucceeded(u, g, s) end
    end,
    
    ADDON_LOADED = function(_, addonName)
        if addonName ~= "PoC_SpellcastEvents" then return end
        
        -- 加载所有场景
        -- 注册所有场景（通过TOC文件加载后已存储在ns.Scenarios中）
        if ns.Scenarios then
            for _, scenario in ipairs(ns.Scenarios) do
                ScenarioRegistry:Register(scenario)
            end
        end
        
        -- 输出加载信息
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00PoC_SpellcastEvents 已加载|r")
        DEFAULT_CHAT_FRAME:AddMessage("已注册 |cffffcc00" .. #ScenarioRegistry:GetAll() .. " 个场景|r")
        DEFAULT_CHAT_FRAME:AddMessage("使用 |cffffcc00/pocspell|r 显示测试指导")
        
        -- 记录到日志
        Logger:System("========================================")
        Logger:System("插件已加载")
        Logger:System("已注册场景数: " .. #ScenarioRegistry:GetAll())
        Logger:System("========================================")
        
        -- 分发 ADDON_LOADED 事件到场景
        ScenarioRegistry:DispatchEvent("ADDON_LOADED", State, addonName)
    end,
    
    PLAYER_LOGIN = function(_)
        -- 分发 PLAYER_LOGIN 事件到场景
        ScenarioRegistry:DispatchEvent("PLAYER_LOGIN", State)
        
        C_Timer.After(1, function()
            DebugWindow.Show(Logger, State, ScenarioRegistry)
        end)
    end
}

-- ============================================================================
-- 事件注册
-- ============================================================================

local eventFrame = CreateFrame("Frame")
local events = {
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

for _, event in ipairs(events) do
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = EventHandlers[event]
    if handler then
        handler(event, ...)
    end
end)
