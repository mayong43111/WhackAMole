local addon, ns = ...

-- ========================================================================
-- 状态重置模块
-- ========================================================================
-- 从 State.lua 拆分而来，负责状态重置逻辑

-- 依赖其他 State 模块
local StateInit = ns.StateInit
local StateCache = ns.StateCache
local StateConfig = ns.StateConfig
local StateResources = ns.StateResources
local AuraTracking = ns.AuraTracking

-- 常量引用
local GCD_THRESHOLD = StateConfig.GCD_THRESHOLD

-- 战斗时间追踪（内部变量）
local combat_start_time = nil

-- ========================================================================
-- 子重置函数（按职责拆分）
-- ========================================================================

--- 重置战斗状态（检测是否进入/脱离战斗并追踪战斗时长）
-- @param state 状态对象
local function ResetCombatState(state)
    -- 检测玩家是否处于战斗状态（影响技能使用和资源回复）
    state.player.in_combat = UnitAffectingCombat("player")
    
    if state.player.in_combat then
        -- 进入战斗时记录开始时间（仅首次记录）
        if not combat_start_time then
            combat_start_time = state.now
        end
        -- 计算持续战斗时长（秒）
        state.player.combat_time = state.now - combat_start_time
    else
        -- 脱离战斗时清空时间追踪
        combat_start_time = nil
        state.player.combat_time = 0
    end
end

--- 重置资源状态（委托给资源管理器）
-- @param state 状态对象
local function ResetResources(state)
    -- 委托给 StateResources 模块初始化所有资源
    StateResources.InitializeResources(state)

    -- 移动状态：GetUnitSpeed 返回码率（大于 0 表示移动中）
    state.player.moving = GetUnitSpeed("player") > 0
    
    -- 当前活跃敌人数量（用于 AOE 判断，P1 优先级待实现真实扫描）
    state.active_enemies = 1
    
    -- 向后兼容：为 APL 提供直接数值访问（避免元表比较问题）
    -- 注意：这些别名会在每次 reset 时更新
    if state.rage and state.rage._value ~= nil then
        state.rage_value = state.rage._value  -- 用于 APL 中的直接数值比较
    end
    if state.energy and state.energy._value ~= nil then
        state.energy_value = state.energy._value
    end
    if state.runic_power and state.runic_power._value ~= nil then
        state.runic_power_value = state.runic_power._value
    end
end

--- 重置玩家生命状态（更新当前血量、最大血量和百分比）
-- @param state 状态对象
local function ResetPlayerHealth(state)
    local hp = UnitHealth("player")
    local maxHp = UnitHealthMax("player")
    -- 计算生命百分比（0-100），避免除零错误
    local pct = (maxHp > 0) and ((hp / maxHp) * 100) or 0
    
    -- 初始化健康表（防止首次访问时为 nil）
    state.player.health = state.player.health or {}
    state.player.health.current = hp
    state.player.health.max = maxHp
    state.player.health.pct = pct
end

--- 重置冷却状态（检测全局 GCD 是否激活）
-- @param state 状态对象
local function ResetCooldowns(state)
    -- 使用技能 ID 61304（全局 GCD 哨兵）检测公共冷却时间
    local gcdStart, gcdDuration, gcdEnabled = GetSpellCooldown(61304)
    -- 判断 GCD 是否激活：开始时间 > 0 且持续时间在阈值内（排除长 CD）
    if gcdStart and gcdDuration and gcdStart > 0 and gcdDuration > 0 and gcdDuration <= GCD_THRESHOLD then
        -- 计算 GCD 剩余时间（秒），确保不为负数
        local gcdRemains = math.max(0, (gcdStart + gcdDuration) - state.now)
        
        -- 应用GCD提前量：当剩余时间≤0.5秒时，认为GCD已结束
        local gcdAnticipation = (ns.CoreConfig and ns.CoreConfig.GCD_ANTICIPATION) or 0.5
        if gcdRemains <= gcdAnticipation then
            state.gcd.active = false
            state.gcd.remains = 0
        else
            state.gcd.active = true
            -- 减去提前量，让预测系统提前计算
            state.gcd.remains = gcdRemains - gcdAnticipation
        end
    else
        state.gcd.active = false
        state.gcd.remains = 0
    end
    
    -- 清空虚拟冷却（恢复到真实游戏状态）
    if state.virtualCooldowns then
        wipe(state.virtualCooldowns)
    end
end

--- 重置目标状态（更新目标生命、距离和预测死亡时间）
-- @param state 状态对象
local function ResetTargetState(state)
    if UnitExists("target") then
        -- 读取目标当前和最大生命值
        local hp = UnitHealth("target")
        local max = UnitHealthMax("target")
        local pct = (max > 0) and ((hp / max) * 100) or 0
        
        state.target.health.current = hp
        state.target.health.max = max
        state.target.health.pct = pct
        
        -- 预测目标死亡时间（秒，P2 优先级待实现 DPS 计算）
        state.target.time_to_die = 99
        
        -- 估算目标距离（WotLK 使用交互距离 API 近似）
        -- CheckInteractDistance 参数：3=决斗(<10码) 2=交易(<11码) 1=观察(<28码)
        local targetRange = 40  -- 默认超远距离
        if CheckInteractDistance("target", 3) then
            targetRange = 5  -- 近战范围
        elseif CheckInteractDistance("target", 2) then
            targetRange = 10  -- 近距施法范围
        elseif CheckInteractDistance("target", 1) then
            targetRange = 25  -- 中距施法范围
        end
        state.target.range = targetRange
    else
        -- 无目标时重置为安全默认值（避免 APL 条件判断出错）
        state.target.health.current = 0
        state.target.health.max = 0
        state.target.health.pct = 0
        state.target.range = 100
    end
end

--- 重置光环状态（扫描玩家 Buff 和目标 Debuff）
-- @param state 状态对象
local function ResetAuras(state)
    -- 执行光环扫描前钩子（允许职业模块进行预处理）
    if ns.CallHook then
        ns.CallHook("reset_preauras")
    end
    
    -- 扫描玩家身上的所有增益效果（Buff）
    AuraTracking.ScanBuffs("player", AuraTracking.buff_cache)
    
    -- 扫描目标身上的减益效果（Debuff）
    if UnitExists("target") then
        AuraTracking.ScanDebuffs("target", AuraTracking.debuff_cache)
    else
        -- 无目标时清空 Debuff 缓存（避免使用旧目标数据）
        wipe(AuraTracking.debuff_cache)
    end
    
    -- 执行光环扫描后钩子（允许职业模块进行后处理）
    if ns.CallHook then
        ns.CallHook("reset_postauras")
    end
end

-- ========================================================================
-- 主重置函数
-- ========================================================================

--- 完整状态重置（每帧调用以同步游戏状态到 APL 引擎）
-- @param state 状态对象
-- @param full 是否执行完整重置（默认 true）；false 时仅更新关键字段以提升性能
local function Reset(state, full)
    if full == nil then full = true end
    
    -- 更新当前时间戳（所有时间计算的基准）
    state.now = GetTime()
    
    -- 更新战斗状态和时长（影响资源回复和技能可用性）
    ResetCombatState(state)
    
    -- 更新全局冷却时间（决定能否立即施法）
    ResetCooldowns(state)
    
    -- 轻量级重置模式：仅更新高频变化的关键字段，跳过资源和光环扫描
    if not full then
        return
    end
    
    -- ===== 完整重置模式：扫描所有游戏状态 =====
    
    -- 清空上一帧的查询缓存（实现帧级失效机制）
    StateCache.ClearQueryCache()
    
    -- 更新玩家资源（法力、怒气、能量、符文能量等）
    ResetResources(state)
    
    -- 更新玩家生命值（当前/最大/百分比）
    ResetPlayerHealth(state)
    
    -- 更新目标状态（生命、距离、预测死亡时间）
    ResetTargetState(state)
    
    -- 扫描玩家 Buff 和目标 Debuff
    ResetAuras(state)
    
    -- 设置 SimC 风格的别名（简化 APL 条件表达式书写）
    state.buff = state.player.buff
    state.debuff = state.target.debuff
    state.cooldown = state.spell
end

-- ========================================================================
-- 导出模块
-- ========================================================================

ns.StateReset = {
    Reset = Reset,
    ResetCombatState = ResetCombatState,
    ResetResources = ResetResources,
    ResetPlayerHealth = ResetPlayerHealth,
    ResetCooldowns = ResetCooldowns,
    ResetTargetState = ResetTargetState,
    ResetAuras = ResetAuras
}
