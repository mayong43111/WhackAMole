local addon, ns = ...

-- =========================================================================
-- Core/UpdateLoop.lua - 主循环更新逻辑
-- =========================================================================

local UpdateLoop = {}
ns.CoreUpdateLoop = UpdateLoop

-- 引用配置模块
local Config = ns.CoreConfig

-- 缓存上次预测结果（用于去重日志）
local lastNextAction = nil

-- =========================================================================
-- 主循环逻辑（重构后：40行 vs 原95行）
-- =========================================================================

--- 主更新循环（重构后的核心函数）
-- @param addon WhackAMole 插件实例
-- @param elapsed 经过的时间
function UpdateLoop.OnUpdate(addon, elapsed)
    -- 检查插件是否启用
    if addon.db and addon.db.global and not addon.db.global.enabled then
        return
    end
    
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
    
    -- 2. 生成主预测（金色，仅在无动作时显示）
    local primaryAction, primarySlot, aplTime = UpdateLoop.GeneratePrimaryPrediction(addon)
    
    -- 3. 生成次预测（蓝色，基于当前动作计算）
    local secondaryAction, secondarySlot, predictTime = UpdateLoop.GenerateSecondaryPrediction(addon, primaryAction)
    
    -- 4. 状态保持与更新逻辑：
    -- 主预测：施法/GCD时清除，有新值时更新
    if addon.playerIsCasting or (ns.State and ns.State.gcd and ns.State.gcd.active) then
        -- 施法中或GCD中：清除主预测显示
        addon.lastPrimaryAction = nil
        addon.lastPrimarySlot = nil
    elseif primaryAction then
        -- 无施法/GCD且有新主预测：更新
        addon.lastPrimaryAction = primaryAction
        addon.lastPrimarySlot = primarySlot
    end
    
    -- 次预测：始终尝试更新
    if secondaryAction then
        addon.lastSecondaryAction = secondaryAction
        addon.lastSecondarySlot = secondarySlot
    -- 只在完全无动作时清除次预测（避免闪烁）
    elseif not addon.playerIsCasting and not primaryAction and not addon.lastPrimaryAction then
        addon.lastSecondaryAction = nil
        addon.lastSecondarySlot = nil
    end
    
    -- 5. 使用保持的状态更新 UI
    local displayPrimary = addon.lastPrimaryAction
    local displayPrimarySlot = addon.lastPrimarySlot
    local displaySecondary = addon.lastSecondaryAction
    local displaySecondarySlot = addon.lastSecondarySlot
    
    -- 6. 更新UI（主预测 = 金色，次预测 = 蓝色）
    local uiTime = UpdateLoop.UpdateUI(displayPrimarySlot, displaySecondarySlot, displayPrimary, displaySecondary)
    
    -- 7. 音频反馈（基于实际计算的新值，不使用保持状态）
    local audioTime = UpdateLoop.PlayAudioFeedback(addon, primaryAction, secondaryAction)
    
    -- 7. 记录性能统计
    local frameTime = debugprofilestop() - frameStart
    UpdateLoop.RecordPerformance(addon, frameTime, stateTime, aplTime, predictTime, uiTime, audioTime)
end

-- =========================================================================
-- 子函数：按职责拆分
-- =========================================================================

--- 节流检查（智能间隔）
-- @param addon WhackAMole 插件实例
-- @param elapsed 经过的时间
-- @return boolean 是否应该跳过本次更新
function UpdateLoop.ShouldThrottle(addon, elapsed)
    addon.timeSinceLastUpdate = (addon.timeSinceLastUpdate or 0) + elapsed
    
    -- 智能选择更新间隔
    local interval
    if addon.playerIsCasting then
        -- 施法中：最快更新（30ms）
        interval = Config.UPDATE_INTERVAL_CASTING
    elseif UnitAffectingCombat("player") then
        -- 战斗中：正常更新（50ms）
        interval = Config.UPDATE_INTERVAL_COMBAT
    else
        -- 非战斗：慢速更新（200ms）
        interval = Config.UPDATE_INTERVAL_IDLE
    end
    
    if addon.timeSinceLastUpdate < interval then 
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
    
    -- P1优化：使用智能扫描策略
    if ns.AuraTracking and ns.AuraTracking.SmartScan then
        ns.AuraTracking.SmartScan()
    end
    
    if ns.State and ns.State.reset then 
        ns.State.reset() 
    end
    return debugprofilestop() - stateStart
end

-- 缓存上次主预测结果（用于去重日志）
local lastPrimaryAction = nil

--- 生成主预测（金色光效，仅在无动作时显示）
-- @param addon WhackAMole 插件实例
-- @return string, number, number primaryAction, primarySlot, aplTime
function UpdateLoop.GeneratePrimaryPrediction(addon)
    local aplStart = debugprofilestop()
    
    -- 施法中或GCD中不显示主预测（玩家已做决策）
    if addon.playerIsCasting or (ns.State and ns.State.gcd and ns.State.gcd.active) then
        -- 施法/GCD时清除主预测缓存
        if lastPrimaryAction ~= nil then
            lastPrimaryAction = nil
        end
        return nil, nil, debugprofilestop() - aplStart
    end
    
    local primaryAction, primarySlot = nil, nil
    
    if addon.currentAPL and ns.APLExecutor then
        primaryAction = ns.APLExecutor.Process(addon.currentAPL, ns.State)
    elseif addon.logicFunc then
        -- 兼容旧版脚本
        local status, result = pcall(addon.logicFunc, ns.State)
        if status then 
            primarySlot = result 
        end
    end
    
    -- 记录主预测日志（去重）
    if primaryAction ~= lastPrimaryAction then
        if primaryAction then
            ns.Logger:Debug("Predict", string.format(">>> 主预测: %s", primaryAction))
        else
            ns.Logger:Debug("Predict", ">>> 主预测: 无可用动作")
        end
        lastPrimaryAction = primaryAction
    end
    
    local aplTime = debugprofilestop() - aplStart
    return primaryAction, primarySlot, aplTime
end

--- 生成次预测（蓝色光效，基于当前动作预测下一步）
-- 当前动作定义：
--   - 施法中：正在施法的技能
--   - 无动作：主预测的技能
-- @param addon WhackAMole 插件实例
-- @param primaryAction 主预测动作
-- @return string, number, number secondaryAction, secondarySlot, predictTime
function UpdateLoop.GenerateSecondaryPrediction(addon, primaryAction)
    local predictStart = debugprofilestop()
    local secondaryAction, secondarySlot = nil, nil
    

    -- 1. 确定"当前动作"（预测起点）
    local currentAction, currentCastTime
    if addon.playerIsCasting then
        -- 施法中：当前动作 = 正在施法的技能
        currentAction = addon.castingAction
        currentCastTime = UpdateLoop.GetCastRemaining(addon)
        
        -- 后备方案：如果 API 提前返回 0（已知问题），使用技能数据库时间
        if currentCastTime <= 0 and currentAction then
            currentCastTime = ns.SpellDatabase and ns.SpellDatabase.GetCastTime(currentAction) or 1.5
        end
    elseif addon.castingAction then
        -- 施法标志已清除但还有缓存的施法动作（STOP 事件提前触发）
        -- 使用缓存的施法时间继续预测
        currentAction = addon.castingAction
        currentCastTime = UpdateLoop.GetCastRemaining(addon)
        if currentCastTime <= 0 then
            -- 缓存的施法时间也已过期，使用数据库默认值
            currentCastTime = ns.SpellDatabase and ns.SpellDatabase.GetCastTime(currentAction) or 1.5
        end
    else
        -- 无动作：当前动作 = 主预测
        if not primaryAction then
            UpdateLoop.ClearPredictionCache()
            return secondaryAction, secondarySlot, debugprofilestop() - predictStart
        end
        currentAction = primaryAction
        -- 从技能数据库获取施法时间（瞬发技能会返回GCD时间）
        currentCastTime = ns.SpellDatabase and ns.SpellDatabase.GetCastTime(currentAction) or 1.5
    end
    
    -- 2. 验证预测条件（施法时间 0-3秒）
    if not UpdateLoop.ShouldPredict(currentCastTime) then
        UpdateLoop.ClearPredictionCache()
        return secondaryAction, secondarySlot, debugprofilestop() - predictStart
    end
    
    -- 3. 验证当前动作存在
    if not currentAction then
        UpdateLoop.ClearPredictionCache()
        return secondaryAction, secondarySlot, debugprofilestop() - predictStart
    end
    
    -- P0优化已禁用：HasPotentialActions 检查有误（currentAPL.actions 结构问题）
    -- 让次预测总是执行，由 APLExecutor 决定是否有可用技能
    
    -- 4. 执行虚拟预测
    secondaryAction = UpdateLoop.RunVirtualPrediction(addon, currentAction, currentCastTime)
    
    -- 5. 记录预测结果（去重）
    UpdateLoop.LogSecondaryPrediction(currentAction, secondaryAction)
    
    local predictTime = debugprofilestop() - predictStart
    return secondaryAction, secondarySlot, predictTime
end

--- 判断是否应该执行预测
-- @param castRemaining 剩余施法时间（包括 GCD）
-- @return boolean
function UpdateLoop.ShouldPredict(castRemaining)
    -- 只要还在施法/GCD 中（> 0）就预测
    -- 上限 3 秒：排除异常长的 CD
    return castRemaining > 0 and castRemaining < 3.0
end

--- P0优化：快速检测是否有潜在可用技能（避免无意义的虚拟预测）
-- @param addon WhackAMole 插件实例
-- @param currentAction 当前动作
-- @param castTime 施法时间
-- @return boolean 是否有潜在可用技能
function UpdateLoop.HasPotentialActions(addon, currentAction, castTime)
    if not ns.State then return true end  -- 安全降级：无State模块时继续预测
    
    -- 获取当前APL
    local currentAPL = addon.currentAPL
    if not currentAPL then
        ns.Logger:Debug("Predict", ">>> HasPotentialActions=false: addon.currentAPL 为 nil")
        return false
    end
    if not currentAPL.actions then
        ns.Logger:Debug("Predict", string.format(">>> HasPotentialActions=false: currentAPL.actions 为 nil (currentAPL=%s)", tostring(currentAPL)))
        return false
    end
    
    -- P0优化：只对能量职业启用，避免对法力职业误判
    -- 检查当前能量类型（0=法力, 1=怒气, 2=集中, 3=能量）
    local powerType = UnitPowerType("player")
    if powerType ~= 3 then
        return true  -- 非能量职业（法师、鸟德等）：跳过资源优化，继续预测
    end
    
    -- 快速资源检查（能量类职业）
    local currentEnergy = UnitPower("player", 3)  -- 3 = 能量
    if currentEnergy then
        local energyRegen = 10  -- 能量恢复速度：10/秒
        local virtualEnergy = currentEnergy + (castTime * energyRegen)
        
        -- 查找APL中最低能量消耗
        local minEnergyCost = 999
        for _, rule in ipairs(currentAPL.actions) do
            local action = rule.action
            if action then
                local spellData = ns.SpellDatabase and ns.SpellDatabase.Get(action)
                if spellData and spellData.cost and spellData.cost.energy then
                    minEnergyCost = math.min(minEnergyCost, spellData.cost.energy)
                end
            end
        end
        
        -- 如果虚拟能量不足以释放任何技能，且所有技能CD > castTime
        if minEnergyCost < 999 and virtualEnergy < minEnergyCost then
            -- TODO: 进一步检查是否有CD转好的技能
            -- 当前简化实现：只要能量不足就跳过
            -- 未来优化：检查是否有即将转好的技能（CD < castTime）
            return false
        end
    end
    
    -- 其他情况：假设有可用技能（避免误判）
    return true
end

--- 执行虚拟状态预测
-- @param addon WhackAMole 插件实例
-- @param castingAction 正在施法的技能
-- @param castRemaining 剩余施法时间
-- @return string 预测的下一个动作
function UpdateLoop.RunVirtualPrediction(addon, castingAction, castRemaining)
    -- P1优化：进入虚拟模式（启用COW）
    if ns.AuraTracking and ns.AuraTracking.EnterVirtualMode then
        ns.AuraTracking.EnterVirtualMode()
    end
    
    -- 0. 标记进入虚拟预测模式
    if ns.State then
        ns.State.isVirtualState = true
    end
    
    -- 1. 模拟施法效果（触发 CD 和 GCD）
    if ns.EffectSimulator then
        ns.EffectSimulator.SimulateSpell(castingAction, ns.State)
    end
    
    -- 2. 推进虚拟时间（让 GCD/CD 过期）
    if ns.State and ns.State.advance then
        ns.State.advance(castRemaining)
    end
    
    -- 3. 执行 APL 获取下一个推荐
    local nextAction = nil
    if addon.currentAPL and ns.APLExecutor then
        nextAction = ns.APLExecutor.Process(addon.currentAPL, ns.State)
    end
    
    -- 4. 恢复真实状态
    if ns.State and ns.State.reset then
        ns.State.isVirtualState = false
        ns.State.reset(false)
    end
    
    -- P1优化：退出虚拟模式（清理COW缓存）
    if ns.AuraTracking and ns.AuraTracking.ExitVirtualMode then
        ns.AuraTracking.ExitVirtualMode()
    end
    
    return nextAction
end

-- 缓存上次跳过日志（用于去重）
local lastSkipAction = nil
local lastCurrentAction = nil  -- 缓存上次预测起点

--- 记录次预测跳过日志（已禁用，P0优化已移除）
-- @param currentAction 当前动作（预测起点）
function UpdateLoop.LogSkipPrediction(currentAction)
    -- 不再输出，保留函数以免报错
end

--- 记录次预测日志（去重）
-- @param currentAction 当前动作（预测起点）
-- @param secondaryAction 次预测结果
function UpdateLoop.LogSecondaryPrediction(currentAction, secondaryAction)
    -- 注意：不完全去重，因为即使结果相同，玩家也需要知道"基于XX"的信息
    -- 只在连续多次完全相同时才跳过（避免刷屏）
    if secondaryAction == lastNextAction and currentAction == lastCurrentAction then
        return  -- 结果和起点都未变化，跳过
    end
    
    lastNextAction = secondaryAction
    lastCurrentAction = currentAction
    lastSkipAction = nil  -- 清除跳过缓存（因为有了新的次预测）
    
    if secondaryAction then
        ns.Logger:Debug("Predict", string.format(">>> 次预测: %s (基于 %s)", 
            secondaryAction, currentAction))
    else
        ns.Logger:Debug("Predict", string.format(">>> 次预测: 无可用动作 (基于 %s)", currentAction))
    end
end

--- 清除预测缓存
function UpdateLoop.ClearPredictionCache()
    if lastNextAction ~= nil then
        lastNextAction = nil
    end
    if lastSkipAction ~= nil then
        lastSkipAction = nil
    end
end

--- 获取当前施法剩余时间
-- @param addon WhackAMole 插件实例
-- @return number 施法剩余时间（秒）
function UpdateLoop.GetCastRemaining(addon)
    -- 优先使用 API（普通施法）
    local remaining = UpdateLoop.GetCastRemainingFromAPI()
    if remaining > 0 then
        return remaining
    end
    
    -- 引导施法
    remaining = UpdateLoop.GetChannelRemainingFromAPI()
    if remaining > 0 then
        return remaining
    end
    
    -- 使用缓存（解决 WoW 3.3.5 API 延迟问题）
    remaining = UpdateLoop.GetCastRemainingFromCache()
    if remaining > 0 then
        return remaining
    end
    
    return 0
end

--- 从 API 获取普通施法剩余时间
-- @return number
function UpdateLoop.GetCastRemainingFromAPI()
    local castName, _, _, _, _, endTime = UnitCastingInfo("player")
    if castName and endTime and type(endTime) == "number" then
        return math.max(0, (endTime / 1000) - GetTime())
    end
    return 0
end

--- 从 API 获取引导施法剩余时间
-- @return number
function UpdateLoop.GetChannelRemainingFromAPI()
    local channelName, _, _, _, _, endTime = UnitChannelInfo("player")
    if channelName and endTime and type(endTime) == "number" then
        return math.max(0, (endTime / 1000) - GetTime())
    end
    return 0
end

--- 从缓存获取施法剩余时间
-- @return number
function UpdateLoop.GetCastRemainingFromCache()
    local Lifecycle = ns.CoreLifecycle
    if not Lifecycle.cachedCastInfo.endTime then
        return 0
    end
    
    local remaining = Lifecycle.cachedCastInfo.endTime - GetTime()
    if remaining > 0 then
        return remaining
    end
    
    -- 缓存已过期，清理
    Lifecycle.ClearCastCache()
    
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
-- @param primaryAction 主预测动作
-- @param secondaryAction 次预测动作
-- @return number 音频处理耗时（ms）
function UpdateLoop.PlayAudioFeedback(addon, primaryAction, secondaryAction)
    local audioStart = debugprofilestop()
    if addon.db.global.audio.enabled then
        local targetAction = primaryAction
        
        -- Requirement 4: Prompt next possible skill 0.5s before current cast ends
        -- (Only switching if we are actually casting and close to finish)
        local castRemaining = UpdateLoop.GetCastRemaining(addon)
        if castRemaining > 0 and castRemaining <= 0.5 and secondaryAction then
             targetAction = secondaryAction
        end

        if targetAction and ns.Audio and ns.Audio.PlayByAction then
            ns.Audio:PlayByAction(targetAction)
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
