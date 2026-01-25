local addon, ns = ...

-- ========================================================================
-- 状态推进模块（虚拟时间系统）
-- ========================================================================
-- 从 State.lua 拆分而来，负责虚拟时间推进逻辑

-- 依赖其他 State 模块
local StateResources = ns.StateResources
local AuraTracking = ns.AuraTracking

-- ========================================================================
-- 光环和冷却推进函数
-- ========================================================================

-- ========================================================================
-- 光环和冷却推进函数
-- ========================================================================

--- 推进 Buff/Debuff 剩余时间（更新光环过期状态）
-- @param state 状态对象
local function AdvanceAuras(state)
    AuraTracking.UpdateAuraRemains(AuraTracking.buff_cache, state.now)
    AuraTracking.UpdateAuraRemains(AuraTracking.debuff_cache, state.now)
end

--- 推进 GCD 剩余时间（全局冷却倡计时）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceGCD(state, seconds)
    if state.gcd.active then
        state.gcd.remains = math.max(0, state.gcd.remains - seconds)
        if state.gcd.remains <= 0 then
            state.gcd.active = false
        end
    end
end

--- 推进战斗时间（更新持续战斗时长）
-- @param state 状态对象
-- @param combat_start_time 战斗开始时间
local function AdvanceCombatTime(state, combat_start_time)
    if state.player.in_combat and combat_start_time then
        state.player.combat_time = state.now - combat_start_time
    end
end

-- ========================================================================
-- 主推进函数
-- ========================================================================

--- 推进虚拟时间（协调各模块完成状态推进）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
-- @param combat_start_time 战斗开始时间（可选）
local function Advance(state, seconds, combat_start_time)
    if not seconds or seconds <= 0 then return end
    
    -- 更新虚拟时间戳
    local oldNow = state.now
    state.now = state.now + seconds
    
    -- 委托资源管理器推进资源回复/衰减
    StateResources.AdvanceAll(state, seconds)
    
    -- 推进光环过期检测
    AdvanceAuras(state)
    
    -- 推进战斗时长统计
    AdvanceCombatTime(state, combat_start_time)
    
    -- 推进全局冷却时间
    AdvanceGCD(state, seconds)
    
    -- 调用自定义钩子（允许职业模块注入额外逻辑）
    if ns.CallHook then
        ns.CallHook("advance", seconds)
    end
end

-- ========================================================================
-- 导出模块
-- ========================================================================

ns.StateAdvance = {
    -- 主推进函数
    Advance = Advance,
    
    -- 子推进函数
    AdvanceAuras = AdvanceAuras,
    AdvanceGCD = AdvanceGCD,
    AdvanceCombatTime = AdvanceCombatTime,
}
