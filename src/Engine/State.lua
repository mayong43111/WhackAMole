local addon, ns = ...
local WhackAMole = _G[addon]

-- ========================================================================
-- State.lua - 状态管理主接口
-- ========================================================================
-- 职责：提供统一的游戏状态查询接口，聚合各子模块功能
--
-- 子模块说明：
--   Config      - 配置常量（GCD阈值、资源类型、回复速率等）
--   Cache       - 缓存系统（对象池、查询缓存、性能优化）
--   Resources   - 资源管理（法力、怒气、能量、符文能量等）
--   Init        - 初始化和基础结构
--   AuraTracking - Buff/Debuff 扫描和查询
--   StateReset  - 状态重置协调
--   StateAdvance - 虚拟时间推进
--
-- 使用示例：
--   state.reset()              -- 重置状态
--   if state.buff(12345).up then ... end  -- 查询 Buff
--   state.advance(1.5)         -- 推进1.5秒
-- ========================================================================

local state = {}
ns.State = state

-- ========================================================================
-- 导入子模块
-- ========================================================================

-- 等待子模块加载（确保加载顺序正确）
local StateConfig = ns.StateConfig
local StateCache = ns.StateCache
local StateResources = ns.StateResources
local StateInit = ns.StateInit
local AuraTracking = ns.AuraTracking
local StateReset = ns.StateReset
local StateAdvance = ns.StateAdvance

-- 从配置模块导入常量
local GCD_THRESHOLD = StateConfig.GCD_THRESHOLD
local MAX_AURA_SLOTS = StateConfig.MAX_AURA_SLOTS
local aura_down = StateInit.aura_down

-- 从 AuraTracking 模块导入缓存表和元表
local buff_cache = AuraTracking.buff_cache
local debuff_cache = AuraTracking.debuff_cache
local mt_buff = AuraTracking.CreateBuffMetatable()
local mt_debuff = AuraTracking.CreateDebuffMetatable()

-- ========================================================================
-- 辅助函数
-- ========================================================================

--- 检查技能是否正在施法或引导
-- @param spellName 技能名称或 ID
-- @return boolean 是否正在施法
-- @return string 施法类型（"cast" 或 "channel"）
function IsSpellCasting(spellName)
    local castName, _, _, _, _, _, _, notInterruptible, spellId = UnitCastingInfo("player")
    if castName == spellName then
        return true, "cast"
    end
    
    local channelName, _, _, _, _, _, _, notInterruptible, spellId = UnitChannelInfo("player")
    if channelName == spellName then
        return true, "channel"
    end
    
    return false, nil
end

-- ========================================================================
-- 技能查询元表（支持冷却和可用性检测）
-- ========================================================================

-- 确保 ActionMap 已加载（技能名称到 ID 的映射）
if ns.BuildActionMap and (not ns.ActionMap or not next(ns.ActionMap)) then
    ns.BuildActionMap()
end

-- ========================================================================
-- 施法记录（用于延迟补偿）
-- ========================================================================
state.lastSpellCast = {}

--- 记录施法时间（用于 Debuff 延迟补偿）
-- @param spellID 技能 ID
-- @param spellName 技能名称
function state:RecordSpellCast(spellID, spellName)
    local now = GetTime()
    if spellID then
        self.lastSpellCast[spellID] = now
    end
    if spellName then
        self.lastSpellCast[spellName] = now
    end
end

local mt_spell = {
    __call = function(t, id)
        -- 获取技能名称以处理等级问题
        local req = id
        local name = GetSpellInfo(id)
        if name then req = name end

        -- 检查可用性
        local usable, nomana = IsUsableSpell(req)
        
        -- 职业特殊技能可用性检查（通过钩子系统）
        if ns.CallHookWithReturn then
            local hookResult = ns.CallHookWithReturn("check_spell_usable", id, name, usable, nomana)
            if hookResult then
                usable = hookResult.usable
                nomana = hookResult.nomana
            end
        end

        -- 检查施法状态（虚拟预测时跳过，因为查询的是真实游戏状态）
        local isCasting, castType = false, nil
        if not state.isVirtualState then
            isCasting, castType = IsSpellCasting(name or req)
        end

        -- 检查冷却：优先使用虚拟 CD（用于次预测）
        local on_cooldown = false
        local remains = 0
        
        -- 从 ActionMap 反查 SimC action 名称
        local action = nil
        if ns.ActionMap then
            for k, v in pairs(ns.ActionMap) do
                if v == id then
                    action = k
                    break
                end
            end
        end
        
        -- 优先使用虚拟 CD
        if action and state.virtualCooldowns and state.virtualCooldowns[action] then
            local vcd = state.virtualCooldowns[action]
            remains = vcd.remains
            on_cooldown = remains > 0
        else
            -- 回退到 WoW API 查询
            local start, duration, enabled = GetSpellCooldown(req)
            if start and start > 0 and duration > GCD_THRESHOLD then
                local readyAt = start + duration
                remains = math.max(0, readyAt - state.now)
                if remains > 0 then on_cooldown = true end
            end
        end
        
        -- 技能就绪：可用或仅缺资源，且不在CD，且GCD已过，且未施法
        local ready = (not on_cooldown) and (not state.gcd.active) and (usable or nomana) and (not isCasting)
        
        return {
            usable = usable,
            ready = ready,
            cooldown_remains = remains,
            casting = isCasting,
            cast_type = castType,
            -- SimC 别名
            up = ready,
            remains = remains
        }
    end,
    __index = function(t, k)
        if type(k) == "string" then
            if ns.ActionMap and ns.ActionMap[k] then
                return t(ns.ActionMap[k])
            end
            
            -- 返回默认值（技能不可用）
            return {
                usable = false,
                ready = false,
                cooldown_remains = 0,
                casting = false,
                cast_type = nil,
                up = false,
                remains = 0,
                cast_time = 0 
            }
        end
    end
}

-- ========================================================================
-- State 结构初始化
-- ========================================================================

state.now = 0  -- 当前虚拟时间戳

-- 技能查询接口
state.spell = setmetatable({}, mt_spell)
state.cooldown = state.spell  -- SimC 别名

-- 玩家状态
state.player = {
    buff = setmetatable({}, mt_buff),  -- Buff 查询接口
    power = { rage = { current = 0 } },  -- 资源容器（由 StateReset 填充）
    moving = false,  -- 是否移动中
    combat = false,  -- 是否战斗中（已废弃，使用 in_combat）
    combat_time = 0  -- 战斗持续时间
}
state.buff = state.player.buff  -- SimC 别名

-- 目标状态
state.target = {
    debuff = setmetatable({}, mt_debuff),  -- Debuff 查询接口
    health = { pct = 0, current = 0, max = 0 },  -- 生命值
    time_to_die = 99  -- 预测死亡时间（秒）
}
state.debuff = state.target.debuff  -- SimC 别名

-- GCD 状态
state.gcd = {
    active = false,
    remains = 0,
    duration = 1.5
}

state.active_enemies = 1

-- 虚拟冷却跟踪（用于次预测）
state.virtualCooldowns = {}

-- 虚拟预测模式标志（用于跳过真实游戏状态查询）
state.isVirtualState = false

-- Buff/Debuff 元表需要访问 state 对象
mt_buff._state = state
mt_debuff._state = state

-- ========================================================================
-- 公共 API（委托给子模块实现）
-- ========================================================================

--- 重置游戏状态（从 WoW API 读取最新数据）
-- @param full 是否完整重置（默认 true）；false 时仅更新关键字段
function state.reset(full)
    StateReset.Reset(state, full)
end

--- 推进虚拟时间（用于预测未来状态）
-- @param seconds 推进的秒数
function state.advance(seconds)
    StateAdvance.Advance(state, seconds)
end

--- 设置虚拟冷却（用于效果模拟）
-- @param action 技能名称（SimC格式）
-- @param duration 冷却时长（秒）
function state:SetCooldown(action, duration)
    if not action or not duration then return end
    self.virtualCooldowns[action] = {
        remains = duration,
        duration = duration
    }
end

--- 触发 GCD（用于效果模拟）
-- @param duration GCD 时长（秒），默认 1.5
function state:TriggerGCD(duration)
    self.gcd.active = true
    self.gcd.remains = duration or 1.5
    self.gcd.duration = duration or 1.5
end

--- 添加 Buff（用于效果模拟）
-- @param name Buff 名称或 spellID
-- @param duration 持续时间（秒）
function state:AddBuff(name, duration)
    if not name then return end
    AuraTracking.AddVirtualBuff(name, duration, self.now)
end

--- 消耗 Buff（减少层数或移除）
-- @param name Buff 名称或 spellID
function state:ConsumeBuff(name)
    if not name then return end
    AuraTracking.ConsumeVirtualBuff(name)
end

--- 添加 Debuff（用于效果模拟）
-- @param name Debuff 名称或 spellID
-- @param duration 持续时间（秒）
function state:AddDebuff(name, duration)
    if not name then return end
    AuraTracking.AddVirtualDebuff(name, duration, self.now)
end

--- 获取缓存统计信息
-- @return table 包含 hits/misses/total_queries/hit_rate 的统计数据
function state.GetCacheStats()
    return StateCache.GetCacheStats()
end

--- 重置缓存统计计数器
function state.ResetCacheStats()
    StateCache.ResetCacheStats()
end

-- ========================================================================
-- 向后兼容性导出（供其他模块使用）
-- ========================================================================

-- 导出对象池 API
ns.GetFromPool = StateCache.GetFromPool
ns.ReleaseToPool = StateCache.ReleaseToPool

-- 导出光环扫描函数（供钩子系统使用）
ns.ScanBuffs = AuraTracking.ScanBuffs
ns.ScanDebuffs = AuraTracking.ScanDebuffs

-- ========================================================================
-- 模块完成标记
-- ========================================================================

-- 标记 State 模块已完成职责优化
ns.StateRefactoredPhase2 = true

--[[
    架构特点：
    - 配置集中管理：所有常量在 Config.lua 统一维护
    - 性能优化集中：对象池和查询缓存在 Cache.lua 统一管理
    - 资源完整生命周期：创建、初始化、推进统一在 Resources.lua
    - 协调器职责单一：StateReset 和 StateAdvance 仅负责协调
    - 模块可独立测试：每个模块职责清晰，依赖关系明确
]]
