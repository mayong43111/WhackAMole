local addon, ns = ...

-- =========================================================================
-- Core/UpdateLoop.lua - 主循环更新逻辑
-- =========================================================================

-- 从 Core.lua 拆分而来，负责主循环和性能追踪
-- OnUpdate: 95行 → 40行（优化 58%）

local UpdateLoop = {}
ns.CoreUpdateLoop = UpdateLoop

-- 引用配置模块
local Config = ns.CoreConfig

-- =========================================================================
-- 主循环逻辑（重构后：40行 vs 原95行）
-- =========================================================================

--- 主更新循环（重构后的核心函数）
-- @param addon WhackAMole 插件实例
-- @param elapsed 经过的时间
function UpdateLoop.OnUpdate(addon, elapsed)
    -- 节流检查
    if UpdateLoop.ShouldThrottle(addon, elapsed) then 
        return 
    end
    
    -- 验证配置已加载
    if not UpdateLoop.HasValidLogic(addon) then 
        return 
    end
    
    -- 性能追踪开始
    local frameStart = debugprofilestop()
    
    -- 1. 更新游戏状态
    local stateTime = UpdateLoop.UpdateGameState()
    
    -- 2. 生成当前推荐
    local activeAction, activeSlot, aplTime = UpdateLoop.GenerateCurrentSuggestion(addon)
    
    -- 3. 生成预测推荐
    local nextAction, nextSlot, predictTime = UpdateLoop.GeneratePredictedSuggestion(addon, activeAction)
    
    -- 4. 更新UI
    local uiTime = UpdateLoop.UpdateUI(activeSlot, nextSlot, activeAction, nextAction)
    
    -- 5. 音频反馈
    local audioTime = UpdateLoop.PlayAudioFeedback(addon, activeAction)
    
    -- 6. 记录性能统计
    local frameTime = debugprofilestop() - frameStart
    UpdateLoop.RecordPerformance(addon, frameTime, stateTime, aplTime, predictTime, uiTime, audioTime)
end

-- =========================================================================
-- 子函数：按职责拆分
-- =========================================================================

--- 节流检查
-- @param addon WhackAMole 插件实例
-- @param elapsed 经过的时间
-- @return boolean 是否应该跳过本次更新
function UpdateLoop.ShouldThrottle(addon, elapsed)
    addon.timeSinceLastUpdate = (addon.timeSinceLastUpdate or 0) + elapsed
    if addon.timeSinceLastUpdate < Config.UPDATE_INTERVAL then 
        return true 
    end
    addon.timeSinceLastUpdate = 0
    return false
end

--- 检查是否有有效的逻辑配置
-- @param addon WhackAMole 插件实例
-- @return boolean
function UpdateLoop.HasValidLogic(addon)
    return (addon.logicFunc ~= nil) or (addon.currentAPL ~= nil)
end

--- 更新游戏状态
-- @return number 状态更新耗时（ms）
function UpdateLoop.UpdateGameState()
    local stateStart = debugprofilestop()
    if ns.State and ns.State.reset then 
        ns.State.reset() 
    end
    return debugprofilestop() - stateStart
end

--- 生成当前时刻推荐
-- @param addon WhackAMole 插件实例
-- @return string, number, number activeAction, activeSlot, aplTime
function UpdateLoop.GenerateCurrentSuggestion(addon)
    local aplStart = debugprofilestop()
    local activeAction, activeSlot = nil, nil
    
    if addon.currentAPL and ns.APLExecutor then
        activeAction = ns.APLExecutor.Process(addon.currentAPL, ns.State)
    elseif addon.logicFunc then
        -- 兼容旧版脚本
        local status, result = pcall(addon.logicFunc, ns.State)
        if status then 
            activeSlot = result 
        end
    end
    
    local aplTime = debugprofilestop() - aplStart
    return activeAction, activeSlot, aplTime
end

--- 生成预测推荐（虚拟时间推进）
-- @param addon WhackAMole 插件实例
-- @param activeAction 当前推荐的动作
-- @return string, number, number nextAction, nextSlot, predictTime
function UpdateLoop.GeneratePredictedSuggestion(addon, activeAction)
    local predictStart = debugprofilestop()
    local nextAction, nextSlot = nil, nil
    
    if activeAction then
        local castRemaining = UpdateLoop.GetCastRemaining()
        
        -- 预判优化：如果剩余施法时间 < 0.5秒，显示下一个技能
        if castRemaining > 0 and castRemaining < 3.0 then
            -- 推进虚拟时间到施法结束
            if ns.State and ns.State.advance then
                ns.State.advance(castRemaining)
            end
            
            -- 再次遍历 APL，获取下一个推荐
            if addon.currentAPL and ns.APLExecutor then
                nextAction = ns.APLExecutor.Process(addon.currentAPL, ns.State)
            end
        end
    end
    
    local predictTime = debugprofilestop() - predictStart
    return nextAction, nextSlot, predictTime
end

--- 获取当前施法剩余时间
-- @return number 施法剩余时间（秒）
function UpdateLoop.GetCastRemaining()
    local castName, _, _, _, _, endTime = UnitCastingInfo("player")
    if castName and endTime and type(endTime) == "number" then
        return math.max(0, (endTime / 1000) - GetTime())
    end
    
    local channelName, _, _, _, _, endTimeChannel = UnitChannelInfo("player")
    if channelName and endTimeChannel and type(endTimeChannel) == "number" then
        return math.max(0, (endTimeChannel / 1000) - GetTime())
    end
    
    return 0
end

--- 更新UI显示
-- @param activeSlot 当前推荐槽位
-- @param nextSlot 预测推荐槽位
-- @param activeAction 当前推荐动作
-- @param nextAction 预测推荐动作
-- @return number UI更新耗时（ms）
function UpdateLoop.UpdateUI(activeSlot, nextSlot, activeAction, nextAction)
    local uiStart = debugprofilestop()
    if ns.UI and ns.UI.Grid then
        ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction, nextAction)
    end
    return debugprofilestop() - uiStart
end

--- 播放音频反馈
-- @param addon WhackAMole 插件实例
-- @param activeAction 当前推荐动作
-- @return number 音频处理耗时（ms）
function UpdateLoop.PlayAudioFeedback(addon, activeAction)
    local audioStart = debugprofilestop()
    if addon.db.global.audio.enabled and activeAction then
        if ns.Audio and ns.Audio.PlayByAction then
            ns.Audio:PlayByAction(activeAction)
        end
    end
    return debugprofilestop() - audioStart
end

--- 记录性能数据
-- @param addon WhackAMole 插件实例
-- @param frameTime 总帧时间
-- @param stateTime 状态更新时间
-- @param aplTime APL处理时间
-- @param predictTime 预测时间
-- @param uiTime UI更新时间
-- @param audioTime 音频处理时间
function UpdateLoop.RecordPerformance(addon, frameTime, stateTime, aplTime, predictTime, uiTime, audioTime)
    if not addon.perfStats then
        UpdateLoop.InitPerformanceStats(addon)
    end
    
    local stats = addon.perfStats
    stats.frameCount = stats.frameCount + 1
    stats.totalTime = stats.totalTime + frameTime
    
    -- 更新峰值
    if frameTime > stats.maxTime then
        stats.maxTime = frameTime
    end
    
    -- 记录模块耗时
    stats.modules.state.total = stats.modules.state.total + stateTime
    stats.modules.apl.total = stats.modules.apl.total + aplTime
    stats.modules.predict.total = stats.modules.predict.total + predictTime
    stats.modules.ui.total = stats.modules.ui.total + uiTime
    stats.modules.audio.total = stats.modules.audio.total + audioTime
    
    -- 更新模块峰值
    stats.modules.state.max = math.max(stats.modules.state.max, stateTime)
    stats.modules.apl.max = math.max(stats.modules.apl.max, aplTime)
    stats.modules.predict.max = math.max(stats.modules.predict.max, predictTime)
    stats.modules.ui.max = math.max(stats.modules.ui.max, uiTime)
    stats.modules.audio.max = math.max(stats.modules.audio.max, audioTime)
    
    -- 存储帧时间用于百分位计算（只保留最近 1000 帧）
    table.insert(stats.frameTimes, frameTime)
    if #stats.frameTimes > Config.PERF.MAX_FRAME_HISTORY then
        table.remove(stats.frameTimes, 1)
    end
end

--- 初始化性能统计数据
-- @param addon WhackAMole 插件实例
function UpdateLoop.InitPerformanceStats(addon)
    addon.perfStats = {
        frameCount = 0,
        totalTime = 0,
        maxTime = 0,
        frameTimes = {},
        modules = {
            state = { total = 0, max = 0 },
            apl = { total = 0, max = 0 },
            predict = { total = 0, max = 0 },
            ui = { total = 0, max = 0 },
            audio = { total = 0, max = 0 }
        }
    }
end

--- 启动更新循环
-- @param addon WhackAMole 插件实例
function UpdateLoop.Start(addon)
    -- 创建更新帧（如果不存在）
    if not addon.heartbeatFrame then
        addon.heartbeatFrame = CreateFrame("Frame")
    end
    
    -- 设置 OnUpdate 回调
    addon.heartbeatFrame:SetScript("OnUpdate", function(frame, elapsed)
        UpdateLoop.OnUpdate(addon, elapsed)
    end)
end

--- 停止更新循环
-- @param addon WhackAMole 插件实例
function UpdateLoop.Stop(addon)
    if addon.heartbeatFrame then
        addon.heartbeatFrame:SetScript("OnUpdate", nil)
    end
end

return UpdateLoop
