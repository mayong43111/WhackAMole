local addon, ns = ...

-- =========================================================================
-- Core/Lifecycle.lua - 生命周期管理
-- =========================================================================

-- 从 Core.lua 拆分而来，负责插件生命周期管理

local Lifecycle = {}
ns.CoreLifecycle = Lifecycle

-- 引用配置模块
local Config = ns.CoreConfig

-- 常量配置
local SPEC_CHECK_DELAY = 0.5        -- 专精检查初始延迟（秒）
local SPEC_CHECK_INTERVAL = 1.0     -- 专精检查重试间隔（秒）
local SPEC_CHECK_MAX_RETRIES = 10   -- 专精检查最大重试次数

-- 缓存施法信息（解决UnitCastingInfo时序问题）
Lifecycle.cachedCastInfo = {
    spellID = nil,
    startTime = nil,
    endTime = nil,
    castTime = nil
}

-- 施法状态机（P0优化：防止事件竞态）
local CastState = {
    IDLE = 0,        -- 空闲状态
    CASTING = 1,     -- 施法中
    SUCCEEDED = 2,   -- 施法成功
    STOPPED = 3      -- 施法停止
}
Lifecycle.CastState = CastState
Lifecycle.currentCastState = CastState.IDLE

-- =========================================================================
-- 初始化
-- =========================================================================

--- 插件初始化（从 OnInitialize 拆分）
-- @param addon WhackAMole 插件实例
function Lifecycle.Initialize(addon)
    -- 0. 记录启动日志
    if ns.Logger then
        ns.Logger:System("WhackAMole 插件初始化开始...")
    end
    
    -- 1. 重建 ActionMap (确保所有职业模块加载完毕后包含所有技能)
    if ns.BuildActionMap then
        ns.BuildActionMap()
    end

    -- 2. 检查依赖
    if not LibStub("AceDB-3.0", true) then
        ns.Logger:System("Error: AceDB-3.0 library missing.")
        return false
    end

    -- 3. 初始化数据库
    addon.db = LibStub("AceDB-3.0"):New("WhackAMoleDB", Config:GetDefaultDB())
    ns.Logger:System("数据库初始化完成")
    
    -- 4. 初始化子模块
    ns.ProfileManager:Initialize(addon.db)
    ns.UI.Grid:Initialize(addon.db.char)
    if ns.Audio then 
        ns.Audio:Initialize() 
    end
    ns.Logger:System("子模块初始化完成")
    
    -- 5. 注册配置界面
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WhackAMole", function() 
        return ns.UI.GetOptionsTable(addon) 
    end)
    addon.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhackAMole", "WhackAMole")
    
    -- 6. 注册聊天命令
    addon:RegisterChatCommand("wam", "OnChatCommand")
    addon:RegisterChatCommand("awm", "OnChatCommand")
    
    -- 7. 初始化事件节流系统
    addon.eventThrottle = {
        lastUpdate = 0,
        pendingEvents = {},
        priorityQueue = {}
    }
    
    -- 8. 注册事件
    addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEvent")
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellCastSucceeded")
    addon:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellCastStart")  -- 施法开始（主要检测点）
    addon:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnSpellCastChannelStart")
    addon:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnSpellCastChannelStop")
    addon:RegisterEvent("UNIT_SPELLCAST_STOP", "OnSpellCastStop")
    addon:RegisterEvent("UNIT_SPELLCAST_FAILED", "OnSpellCastFailed")
    addon:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnSpellCastInterrupted")
    -- P1优化：监听Buff/Debuff变化事件
    addon:RegisterEvent("UNIT_AURA", "OnUnitAura")
    
    -- 9. 初始化专精检测
    ns.SpecDetection:Initialize()
    
    ns.Logger:System("WhackAMole 插件初始化完成")
    
    return true
end

--- 玩家进入世界事件处理
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
-- @param isLogin 是否为登录
-- @param isReload 是否为重载UI
function Lifecycle.OnPlayerEnteringWorld(addon, event, isLogin, isReload)
    -- 取消事件注册，避免重复触发
    addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- 延迟等待天赋 API 和其他系统就绪
    C_Timer.After(SPEC_CHECK_DELAY, function()
        Lifecycle.WaitForSpecAndLoad(addon, 0)
    end)
end

--- 等待专精数据并加载配置
-- @param addon WhackAMole 插件实例
-- @param retryCount 重试次数
function Lifecycle.WaitForSpecAndLoad(addon, retryCount)
    retryCount = retryCount or 0
    local isLastAttempt = (retryCount >= SPEC_CHECK_MAX_RETRIES)
    
    -- 使用专精检测模块获取当前专精
    local spec = ns.SpecDetection and ns.SpecDetection:GetSpecID(isLastAttempt)
    
    if spec then
        -- 找到专精，初始化配置
        Lifecycle.LoadProfileWithSpec(addon, spec)
    elseif retryCount < SPEC_CHECK_MAX_RETRIES then
        -- 未找到专精，继续重试
        C_Timer.After(SPEC_CHECK_INTERVAL, function() 
            Lifecycle.WaitForSpecAndLoad(addon, retryCount + 1) 
        end)
    else
        -- 超时，加载通用配置
        ns.Logger:System("Timeout waiting for talent data. Loading generic profile if available.")
        Lifecycle.LoadProfileWithSpec(addon, 0)
    end
end

--- 加载专精配置并应用启用状态
-- @param addon WhackAMole 插件实例
-- @param specID 专精ID
function Lifecycle.LoadProfileWithSpec(addon, specID)
    if ns.CoreProfileLoader then
        ns.CoreProfileLoader.InitializeProfile(addon, specID)
    end
    
    -- 延迟应用启用状态
    C_Timer.After(0.1, function()
        Lifecycle.ApplyEnabledState(addon)
    end)
end

--- 应用插件启用状态
-- @param addon WhackAMole 插件实例
function Lifecycle.ApplyEnabledState(addon)
    if not (addon.db and addon.db.global) then
        return
    end
    
    if not addon.db.global.enabled then
        -- 禁用状态：隐藏UI
        if ns.UI and ns.UI.Grid and ns.UI.Grid.Hide then
            ns.UI.Grid:Hide()
        end
        ns.Logger:System("|cffFFD100WhackAMole:|r 插件已禁用，使用 /awm 启用")
    else
        ns.Logger:System("|cff00ff00WhackAMole:|r 插件已就绪")
    end
end

--- 专精变化回调（基于 PoC_Talents 验证结果）
-- @param addon WhackAMole 插件实例
-- @param newSpecID 新的专精ID
function Lifecycle.OnSpecChanged(addon, newSpecID)
    ns.Logger:System(string.format("检测到专精变化，重新加载配置... (SpecID: %d)", newSpecID))
    
    -- 停止当前引擎
    if addon.heartbeatFrame then
        addon.heartbeatFrame:SetScript("OnUpdate", nil)
    end
    
    -- 清除当前配置
    addon.currentProfile = nil
    addon.currentAPL = nil
    addon.logicFunc = nil
    
    -- 重新加载配置
    if ns.CoreProfileLoader then
        ns.CoreProfileLoader.InitializeProfile(addon, newSpecID)
    end
    
    -- 重启引擎
    if ns.CoreUpdateLoop then
        ns.CoreUpdateLoop.Start(addon)
    end
end

--- 聊天命令处理
-- @param addon WhackAMole 插件实例
-- @param input 命令输入
function Lifecycle.OnChatCommand(addon, input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "lock" then
        ns.UI.Grid:SetLock(true)
        addon:Print("框架已锁定")
    elseif command == "unlock" then
        ns.UI.Grid:SetLock(false)
        addon:Print("框架已解锁")
    elseif command == "debug" then
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        else
            addon:Print("调试窗口未初始化")
        end
    elseif command == "" then
        -- 打开配置界面
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    else
        -- 显示帮助
        addon:Print("可用命令:")
        addon:Print("  /wam 或 /awm - 打开配置界面")
        addon:Print("  /wam lock/unlock - 锁定/解锁框架")
        addon:Print("  /wam debug - 显示调试窗口")
    end
end

--- 施法开始事件处理（主要检测点）
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
-- @param unit 单位ID
-- @param castGUID 施法GUID
-- @param spellID 技能ID
function Lifecycle.OnSpellCastStart(addon, event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    
    -- P0优化：状态机防重复
    if Lifecycle.currentCastState ~= CastState.IDLE then
        ns.Logger:Debug("Predict", string.format(">>> SPELLCAST_START 忽略: 当前状态=%d (非IDLE)", Lifecycle.currentCastState))
        return
    end
    
    -- 更新状态机
    Lifecycle.currentCastState = CastState.CASTING
    
    -- 设置施法标志
    addon.playerIsCasting = true
    addon.castStartTime = GetTime()
    
    ns.Logger:Debug("Predict", string.format(">>> UNIT_SPELLCAST_START: spellID=%s, castGUID=%s", 
        tostring(spellID), tostring(castGUID)))
    
    -- 缓存施法信息
    if spellID and spellID > 0 then
        Lifecycle.CacheCastInfo(addon, spellID)
    end
    
    -- 立即清除所有预测缓存（UI会在下一帧OnUpdate中刷新）
    addon.lastPrimaryAction = nil
    addon.lastPrimarySlot = nil
    addon.lastSecondaryAction = nil
    addon.lastSecondarySlot = nil
end

--- 施法成功事件处理
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
-- @param unit 单位ID
-- @param castGUID 施法GUID
-- @param spellID 技能ID
function Lifecycle.OnSpellCastSucceeded(addon, event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    
    -- P0优化：状态机验证
    if Lifecycle.currentCastState ~= CastState.CASTING then
        ns.Logger:Debug("Predict", string.format(">>> SPELLCAST_SUCCEEDED 忽略: 当前状态=%d (非CASTING)", Lifecycle.currentCastState))
        return
    end
    
    -- 更新状态机
    Lifecycle.currentCastState = CastState.SUCCEEDED
    
    -- Buff消费现在由职业模块在虚拟预测中处理（Classes.XXX:SimulateSpecialEffect）
    -- 这里不再需要手动消耗buff
end

--- 缓存施法信息（规避 WoW 3.3.5 API 延迟）
-- @param addon WhackAMole 插件实例
-- @param spellID 技能ID
function Lifecycle.CacheCastInfo(addon, spellID)
    local spellName, _, _, castTime = GetSpellInfo(spellID)
    if not castTime or castTime <= 0 then
        return  -- 瞬发技能，无需缓存
    end
    
    local now = GetTime()
    local castSeconds = castTime / 1000
    
    -- 缓存施法时间信息
    Lifecycle.cachedCastInfo.spellID = spellID
    Lifecycle.cachedCastInfo.startTime = now
    Lifecycle.cachedCastInfo.endTime = now + castSeconds
    Lifecycle.cachedCastInfo.castTime = castSeconds
    
    -- 记录技能动作名（用于效果模拟）
    Lifecycle.RecordCastingAction(addon, spellID)
    
    -- 调试日志
    ns.Logger:Debug("Predict", string.format(">>> 检测到施法: spellID=%d (%s), 施法时间=%.2fs", 
        spellID, spellName or "unknown", castSeconds))
end

--- 记录正在施法的技能动作名
-- @param addon WhackAMole 插件实例
-- @param spellID 技能ID
function Lifecycle.RecordCastingAction(addon, spellID)
    if not (ns.ActionMap and ns.ActionMap.spellIDToAction) then
        return
    end
    
    addon.castingAction = ns.ActionMap.spellIDToAction[spellID]
end

--- 引导施法开始事件处理（用于预测）
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
-- @param unit 单位ID
function Lifecycle.OnSpellCastChannelStart(addon, event, unit)
    if unit ~= "player" then return end
    
    -- 记录引导施法开始标志
    addon.playerIsCasting = true
    addon.castStartTime = GetTime()
    
    ns.Logger:Debug("Predict", ">>> SPELL_CHANNEL_START detected")
end

--- 清除施法缓存（统一接口）
function Lifecycle.ClearCastCache()
    Lifecycle.cachedCastInfo.spellID = nil
    Lifecycle.cachedCastInfo.startTime = nil
    Lifecycle.cachedCastInfo.endTime = nil
    Lifecycle.cachedCastInfo.castTime = nil
end

--- 施法结束处理（停止/失败/打断统一逻辑）
-- @param addon WhackAMole 插件实例
-- @param unit 单位ID
-- @param immediate 是否立即清除（失败/打断时立即清除，成功时延迟）
function Lifecycle.HandleCastEnd(addon, unit, immediate)
    if unit ~= "player" then return end
    
    -- P0优化：状态机 - 无论什么状态都执行清理
    local previousState = Lifecycle.currentCastState
    Lifecycle.currentCastState = CastState.IDLE
    
    addon.playerIsCasting = false
    
    if immediate then
        -- 失败/打断：立即清除施法状态（保留预测状态让更新循环处理）
        ns.Logger:Debug("Predict", string.format(">>> 施法中断，清除施法标志 (之前状态=%d)", previousState))
        addon.castingAction = nil
        Lifecycle.ClearCastCache()
    else
        -- 正常结束：延迟清除施法缓存
        ns.Logger:Debug("Predict", string.format(">>> 施法停止，延迟清除缓存 (之前状态=%d)", previousState))
        C_Timer.After(0.1, function()
            if addon and addon.castingAction then
                addon.castingAction = nil
                Lifecycle.ClearCastCache()
            end
        end)
    end
end

--- 施法停止事件（正常完成，延迟清除）
function Lifecycle.OnSpellCastStop(addon, event, unit)
    Lifecycle.HandleCastEnd(addon, unit, false)
end

--- 施法失败事件（立即清除）
function Lifecycle.OnSpellCastFailed(addon, event, unit)
    Lifecycle.HandleCastEnd(addon, unit, true)
end

--- 施法打断事件（立即清除）
function Lifecycle.OnSpellCastInterrupted(addon, event, unit)
    Lifecycle.HandleCastEnd(addon, unit, true)
end

--- 引导结束事件（正常完成，延迟清除）
function Lifecycle.OnSpellCastChannelStop(addon, event, unit)
    Lifecycle.HandleCastEnd(addon, unit, false)
end

--- P1优化：Buff/Debuff变化事件（触发全量扫描）
function Lifecycle.OnUnitAura(addon, event, unit)
    -- 只关注玩家和目标的Aura变化
    if unit ~= "player" and unit ~= "target" then return end
    
    -- 标记需要全量扫描
    if ns.AuraTracking and ns.AuraTracking.MarkNeedFullScan then
        ns.AuraTracking.MarkNeedFullScan()
    end
end

return Lifecycle
