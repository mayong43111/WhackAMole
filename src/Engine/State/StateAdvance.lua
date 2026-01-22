local addon, ns = ...

-- =========================================================================
-- 状态推进模块（虚拟时间系统）
-- =========================================================================

-- 从 State.lua 拆分而来，负责虚拟时间推进逻辑

local AuraTracking = ns.AuraTracking

-- =========================================================================
-- 资源回复计算函数
-- =========================================================================

--- 推进能量回复（盗贼/德鲁伊猫形态）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceEnergy(state, seconds)
    if not state.energy then return end
    
    local energyRegen = 10 -- 基础回复速度（10/秒）
    -- TODO: 添加急速加成计算 energyRegen = energyRegen * (1 + hasteBonus)
    
    local newEnergy = state.energy + (energyRegen * seconds)
    state.energy = math.min(100, newEnergy) -- 能量上限 100
end

--- 推进法力回复（施法者）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceMana(state, seconds)
    if not state.mana then return end
    
    -- TODO: 使用 GetPowerRegen() 获取精确回复速率
    -- local manaRegen = GetManaRegen() or 0
    -- local newMana = state.mana + (manaRegen * seconds)
    -- state.mana = math.min(UnitPowerMax("player", 0), newMana)
end

--- 推进怒气衰减（战士）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceRage(state, seconds)
    if not state.rage then return end
    
    -- 非战斗中每秒 -1
    if not state.player.combat then
        local newRage = state.rage - (1 * seconds)
        state.rage = math.max(0, newRage)
        state.player.power.rage.current = state.rage
    end
end

--- 推进符文能量回复（死亡骑士）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceRunicPower(state, seconds)
    if not state.runic then return end
    
    local runicRegen = 10 -- 基础回复速度
    local newRunic = state.runic + (runicRegen * seconds)
    state.runic = math.min(100, newRunic) -- 符文能量上限 100
end

--- 推进所有资源
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceResources(state, seconds)
    AdvanceEnergy(state, seconds)
    AdvanceMana(state, seconds)
    AdvanceRage(state, seconds)
    AdvanceRunicPower(state, seconds)
end

-- =========================================================================
-- 光环和冷却推进函数
-- =========================================================================

--- 推进 Buff/Debuff 剩余时间
-- @param state 状态对象
local function AdvanceAuras(state)
    AuraTracking.UpdateAuraRemains(AuraTracking.buff_cache, state.now)
    AuraTracking.UpdateAuraRemains(AuraTracking.debuff_cache, state.now)
end

--- 推进 GCD 剩余时间
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

--- 推进战斗时间
-- @param state 状态对象
-- @param combat_start_time 战斗开始时间
local function AdvanceCombatTime(state, combat_start_time)
    if state.player.combat and combat_start_time then
        state.player.combat_time = state.now - combat_start_time
    end
end

-- =========================================================================
-- 主推进函数
-- =========================================================================

--- 推进虚拟时间（重构后：25行 vs 原86行）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
-- @param combat_start_time 战斗开始时间（可选）
local function Advance(state, seconds, combat_start_time)
    if not seconds or seconds <= 0 then return end
    
    local oldNow = state.now
    state.now = state.now + seconds
    
    -- 推进资源回复
    AdvanceResources(state, seconds)
    
    -- 推进光环过期
    AdvanceAuras(state)
    
    -- 推进战斗时间
    AdvanceCombatTime(state, combat_start_time)
    
    -- 推进 GCD
    AdvanceGCD(state, seconds)
    
    -- 调用钩子（自定义推进逻辑）
    if ns.CallHook then
        ns.CallHook("advance", seconds)
    end
end

-- =========================================================================
-- 导出模块
-- =========================================================================

ns.StateAdvance = {
    Advance = Advance,
    AdvanceResources = AdvanceResources,
    AdvanceAuras = AdvanceAuras,
    AdvanceGCD = AdvanceGCD,
    AdvanceCombatTime = AdvanceCombatTime,
    -- 资源子函数
    AdvanceEnergy = AdvanceEnergy,
    AdvanceMana = AdvanceMana,
    AdvanceRage = AdvanceRage,
    AdvanceRunicPower = AdvanceRunicPower
}
