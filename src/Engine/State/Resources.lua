local addon, ns = ...

-- ========================================================================
-- 资源管理模块
-- ========================================================================
-- 统一管理所有玩家资源：创建、查询、推进（回复/衰减）

local StateConfig = ns.StateConfig
local POWER_TYPES = StateConfig.POWER_TYPES
local RESOURCE_CAPS = StateConfig.RESOURCE_CAPS
local RESOURCE_REGEN_RATES = StateConfig.RESOURCE_REGEN_RATES

-- ========================================================================
-- 资源对象元表（支持 SimC 风格查询）
-- ========================================================================

-- 资源对象元表定义（全局复用，避免每次创建资源都分配新元表）
local ResourceMetatable = {
    __index = function(t, k)
        if k == "pct" then
            -- 返回资源百分比（0-100），避免除零错误
            return (t._max > 0) and ((t._value / t._max) * 100) or 0
        elseif k == "current" then
            -- 返回当前资源值
            return t._value
        elseif k == "max" then
            -- 返回最大资源值
            return t._max
        end
        return nil
    end,
    -- 支持数值比较运算符（增强版，支持双向比较）
    __lt = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val < o_val
    end,
    __le = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val <= o_val
    end,
    __eq = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val == o_val
    end,
    -- 支持算术运算符
    __add = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val + o_val
    end,
    __sub = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val - o_val
    end,
    __mul = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val * o_val
    end,
    __div = function(t, other)
        local t_val = type(t) == "table" and t._value or t
        local o_val = type(other) == "table" and other._value or other
        return t_val / o_val
    end,
    -- 支持字符串转换，用于 print() 调试输出
    __tostring = function(t) return tostring(t._value) end,
    -- 关键：在数值上下文中自动转换为 _value（解决 APL 比较问题）
    __unm = function(t) return -t._value end
}

--- 创建资源对象（工厂函数）
-- @param current 当前资源值
-- @param max 最大资源值
-- @return table 资源元表对象，支持 .pct/.current/.max 访问和数值运算
local function CreateResource(current, max)
    return setmetatable({
        _value = current or 0,
        _max = max or 0
    }, ResourceMetatable)
end

-- ========================================================================
-- 资源初始化（从游戏 API 读取）
-- ========================================================================

--- 初始化所有玩家资源
-- @param state 状态对象
local function InitializeResources(state)
    -- 创建主要资源对象（Type: 0=法力 1=怒气 3=能量 6=符文能量）
    -- 使用元表支持 .pct 百分比查询、数值比较和算术运算
    state.mana = CreateResource(
        UnitPower("player", POWER_TYPES.mana), 
        UnitPowerMax("player", POWER_TYPES.mana)
    )
    state.rage = CreateResource(
        UnitPower("player", POWER_TYPES.rage), 
        UnitPowerMax("player", POWER_TYPES.rage)
    )
    state.energy = CreateResource(
        UnitPower("player", POWER_TYPES.energy), 
        UnitPowerMax("player", POWER_TYPES.energy)
    )
    state.runic_power = CreateResource(
        UnitPower("player", POWER_TYPES.runic_power), 
        UnitPowerMax("player", POWER_TYPES.runic_power)
    )
    
    -- 同步到 player.power 完整路径结构（用于规范化访问）
    state.player.power = state.player.power or {}
    
    state.player.power.mana = state.player.power.mana or {}
    state.player.power.mana.current = state.mana._value
    
    state.player.power.rage = state.player.power.rage or {}
    state.player.power.rage.current = state.rage._value
    
    state.player.power.energy = state.player.power.energy or {}
    state.player.power.energy.current = state.energy._value
    
    state.player.power.runic_power = state.player.power.runic_power or {}
    state.player.power.runic_power.current = state.runic_power._value
    
    -- 圣能（Holy Power）特殊处理：WotLK 3.3.5 原版不支持此资源类型
    -- 泰坦服务器可能已实现 Type 9 支持，若不支持则初始化为 0 防止报错
    local hp = UnitPower("player", 9)
    state.holy_power = (hp and hp >= 0) and hp or 0

    -- 连击点数（盗贼/德鲁伊共用）：依赖当前目标，无目标时为 0
    state.combo_points = GetComboPoints("player", "target") or 0
end

-- ========================================================================
-- 资源推进（虚拟时间回复/衰减）
-- ========================================================================

--- 推进能量回复（盗贼/德鲁伊猫形态）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceEnergy(state, seconds)
    if not state.energy or not state.energy._value then return end
    
    -- 基础能量回复速度：10/秒（实际受急速影响，此处简化）
    local energyRegen = RESOURCE_REGEN_RATES.energy
    -- TODO: 添加急速加成计算 energyRegen = energyRegen * (1 + hasteBonus)
    
    -- 计算新值并封顶
    local newEnergy = state.energy._value + (energyRegen * seconds)
    state.energy._value = math.min(RESOURCE_CAPS.energy, newEnergy)
end

--- 推进法力回复（施法者职业）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceMana(state, seconds)
    if not state.mana or not state.mana._value then return end
    
    -- 法力回复受多种因素影响（精神、施法/非施法、五秒回蓝规则等）
    -- TODO: 使用 GetManaRegen() 获取精确回复速率
    -- local manaRegen = GetManaRegen() or 0
    -- local newMana = state.mana._value + (manaRegen * seconds)
    -- state.mana._value = math.min(state.mana._max, newMana)
end

--- 推进怒气衰减（战士/德鲁伊熊形态）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceRage(state, seconds)
    if not state.rage or not state.rage._value then return end
    
    -- 怒气脱战衰减：每秒 -1（战斗中不衰减）
    if not state.player.in_combat then
        local newRage = state.rage._value - (RESOURCE_REGEN_RATES.rage_decay * seconds)
        state.rage._value = math.max(0, newRage)
        -- 同步到完整路径
        state.player.power.rage.current = state.rage._value
    end
end

--- 推进符文能量回复（死亡骑士）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceRunicPower(state, seconds)
    if not state.runic_power or not state.runic_power._value then return end
    
    -- 符文能量基础回复：10/秒（平坦回复，不受急速影响）
    local runicRegen = RESOURCE_REGEN_RATES.runic_power
    local newRunic = state.runic_power._value + (runicRegen * seconds)
    state.runic_power._value = math.min(RESOURCE_CAPS.runic_power, newRunic)
end

--- 推进所有资源（统一入口）
-- @param state 状态对象
-- @param seconds 推进的时间（秒）
local function AdvanceAll(state, seconds)
    AdvanceEnergy(state, seconds)
    AdvanceMana(state, seconds)
    AdvanceRage(state, seconds)
    AdvanceRunicPower(state, seconds)
end

-- ========================================================================
-- 资源更新（手动设置资源值，用于技能消耗模拟）
-- ========================================================================

--- 更新资源值（用于虚拟施法消耗）
-- @param state 状态对象
-- @param resourceName 资源名称（"mana"/"rage"/"energy"/"runic_power"）
-- @param delta 变化量（正数增加，负数减少）
local function UpdateResource(state, resourceName, delta)
    local resource = state[resourceName]
    if not resource or not resource._value then return end
    
    local newValue = resource._value + delta
    -- 确保在 [0, max] 范围内
    resource._value = math.max(0, math.min(resource._max, newValue))
    
    -- 同步到完整路径（如果存在）
    if state.player.power[resourceName] then
        state.player.power[resourceName].current = resource._value
    end
end

-- ========================================================================
-- 导出模块
-- ========================================================================

ns.StateResources = {
    -- 工厂函数
    CreateResource = CreateResource,
    
    -- 初始化
    InitializeResources = InitializeResources,
    
    -- 推进（回复/衰减）
    AdvanceAll = AdvanceAll,
    AdvanceEnergy = AdvanceEnergy,
    AdvanceMana = AdvanceMana,
    AdvanceRage = AdvanceRage,
    AdvanceRunicPower = AdvanceRunicPower,
    
    -- 更新（手动修改）
    UpdateResource = UpdateResource,
}
