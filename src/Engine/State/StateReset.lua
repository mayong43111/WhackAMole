local addon, ns = ...

-- =========================================================================
-- 状态重置模块
-- =========================================================================

-- 从 State.lua 拆分而来，负责状态重置逻辑

local StateInit = ns.StateInit
local AuraTracking = ns.AuraTracking
local GCD_THRESHOLD = StateInit.GCD_THRESHOLD

-- 战斗时间追踪（内部变量）
local combat_start_time = nil

-- =========================================================================
-- 子重置函数（按职责拆分）
-- =========================================================================

--- 重置战斗状态
-- @param state 状态对象
local function ResetCombatState(state)
    state.player.combat = UnitAffectingCombat("player")
    
    -- 战斗时间追踪
    if state.player.combat then
        if not combat_start_time then
            combat_start_time = state.now
        end
        state.player.combat_time = state.now - combat_start_time
    else
        combat_start_time = nil
        state.player.combat_time = 0
    end
end

--- 重置资源状态
-- @param state 状态对象
local function ResetResources(state)
    -- 快照玩家资源
    state.player.power.rage.current = UnitPower("player", 1) -- 1=Rage
    
    -- SimC 别名（直接访问，用于条件判断如 'rage > 10'）
    state.rage = state.player.power.rage.current
    state.mana = UnitPower("player", 0)
    state.energy = UnitPower("player", 3)
    state.runic = UnitPower("player", 6)
    
    state.player.moving = GetUnitSpeed("player") > 0
    state.active_enemies = 1 -- Placeholder
end

--- 重置冷却状态（GCD 检测）
-- @param state 状态对象
local function ResetCooldowns(state)
    -- GCD 检测
    local gcdStart, gcdDuration, gcdEnabled = GetSpellCooldown(61304)
    if gcdStart and gcdDuration and gcdStart > 0 and gcdDuration > 0 and gcdDuration <= GCD_THRESHOLD then
        state.gcd.active = true
        state.gcd.remains = math.max(0, (gcdStart + gcdDuration) - state.now)
    else
        state.gcd.active = false
        state.gcd.remains = 0
    end
end

--- 重置目标状态
-- @param state 状态对象
local function ResetTargetState(state)
    if UnitExists("target") then
        local hp = UnitHealth("target")
        local max = UnitHealthMax("target")
        local pct = (max > 0) and ((hp / max) * 100) or 0
        
        state.target.health.current = hp
        state.target.health.max = max
        state.target.health.pct = pct
        state.target.health_pct = pct -- Legacy alias
        
        state.target.time_to_die = 99 -- Placeholder
        
        -- Range Check (Approximate for WotLK)
        if CheckInteractDistance("target", 3) then -- < 10y (Duel)
            state.target.range = 5
        elseif CheckInteractDistance("target", 2) then -- < 11.11y (Trade)
            state.target.range = 10
        elseif CheckInteractDistance("target", 1) then -- < 28y (Inspect)
            state.target.range = 25
        else
            state.target.range = 40
        end
    else
        state.target.health_pct = 0
        state.target.range = 100
    end
end

--- 重置光环状态
-- @param state 状态对象
local function ResetAuras(state)
    -- 钩子：reset_preauras（任务 5.5）
    if ns.CallHook then
        ns.CallHook("reset_preauras")
    end
    
    -- 扫描 Buff
    AuraTracking.ScanBuffs("player", AuraTracking.buff_cache)
    
    -- 扫描 Debuff
    if UnitExists("target") then
        AuraTracking.ScanDebuffs("target", AuraTracking.debuff_cache)
    else
        wipe(AuraTracking.debuff_cache)
    end
    
    -- 钩子：reset_postauras（任务 5.5）
    if ns.CallHook then
        ns.CallHook("reset_postauras")
    end
end

-- =========================================================================
-- 主重置函数
-- =========================================================================

--- 完整状态重置（重构后：30行 vs 原113行）
-- @param state 状态对象
-- @param full 是否执行完整重置（默认 true）
local function Reset(state, full)
    if full == nil then full = true end
    
    -- 始终更新的关键字段
    state.now = GetTime()
    
    -- 重置战斗状态
    ResetCombatState(state)
    
    -- 重置冷却状态
    ResetCooldowns(state)
    
    -- 轻量级重置：仅更新关键字段
    if not full then
        return
    end
    
    -- ===== 完整重置：扫描所有状态 =====
    
    -- 清空查询缓存（任务 5.1 - 帧级失效）
    StateInit.ClearQueryCache()
    
    -- 重置资源
    ResetResources(state)
    
    -- 重置目标状态
    ResetTargetState(state)
    
    -- 重置光环
    ResetAuras(state)
    
    -- 设置 SimC 别名
    state.buff = state.player.buff
    state.debuff = state.target.debuff
    state.cooldown = state.spell
end

-- =========================================================================
-- 导出模块
-- =========================================================================

ns.StateReset = {
    Reset = Reset,
    ResetCombatState = ResetCombatState,
    ResetResources = ResetResources,
    ResetCooldowns = ResetCooldowns,
    ResetTargetState = ResetTargetState,
    ResetAuras = ResetAuras
}
