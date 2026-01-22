local addon, ns = ...
local WhackAMole = _G[addon]

local state = {}
ns.State = state

-- =========================================================================
-- 常量定义（基于 PoC 验证结果）
-- =========================================================================
local GCD_THRESHOLD = 1.5  -- GCD 阈值，duration <= 1.5 秒视为全局冷却，不是真实技能冷却
local MAX_AURA_SLOTS = 40  -- 最大光环槽位数

-- Cache tables
local buff_cache = {}
local debuff_cache = {}

-- =========================================================================
-- 对象池系统（任务 5.3 - 借鉴 Hekili）
-- =========================================================================
-- 对象池用于减少 GC 压力，避免频繁创建/销毁临时表

-- Buff/Debuff 查询结果缓存池
local buffCachePool = {}
local debuffCachePool = {}

--- 从缓存池获取对象
-- @param pool 对象池
-- @return table 可重用的表对象
local function GetFromPool(pool)
    return tremove(pool) or {}
end

--- 释放对象到缓存池
-- @param pool 对象池
-- @param obj 要释放的对象
local function ReleaseToPool(pool, obj)
    if obj then
        wipe(obj)  -- 清空表内容
        tinsert(pool, obj)
    end
end

-- 导出对象池 API
ns.GetFromPool = GetFromPool
ns.ReleaseToPool = ReleaseToPool

-- =========================================================================
-- 查询结果缓存系统（任务 5.1）
-- =========================================================================
local query_cache = {}  -- 查询结果缓存
local cache_stats = {   -- 缓存统计
    hits = 0,
    misses = 0,
    total_queries = 0
}

--- 生成缓存键
-- @param queryType 查询类型（"buff"/"debuff"/"cooldown"/"distance"）
-- @param id 查询标识（SpellID 或名称）
-- @param timestamp 时间戳（用于帧级失效）
-- @return string 缓存键
local function GetCacheKey(queryType, id, timestamp)
    return string.format("%s_%s_%.3f", queryType, tostring(id), timestamp or state.now)
end

--- 获取缓存结果
-- @param key 缓存键
-- @return table|nil 缓存的结果
local function GetCachedResult(key)
    cache_stats.total_queries = cache_stats.total_queries + 1
    local result = query_cache[key]
    if result then
        cache_stats.hits = cache_stats.hits + 1
        return result
    else
        cache_stats.misses = cache_stats.misses + 1
        return nil
    end
end

--- 设置缓存结果
-- @param key 缓存键
-- @param value 要缓存的值
local function SetCachedResult(key, value)
    query_cache[key] = value
end

--- 清空查询缓存（每帧调用）
local function ClearQueryCache()
    -- 使用 wipe 比重新创建表更高效
    for k in pairs(query_cache) do
        query_cache[k] = nil
    end
end

--- 获取缓存统计信息
function state.GetCacheStats()
    local hitRate = 0
    if cache_stats.total_queries > 0 then
        hitRate = (cache_stats.hits / cache_stats.total_queries) * 100
    end
    return {
        hits = cache_stats.hits,
        misses = cache_stats.misses,
        total = cache_stats.total_queries,
        hitRate = hitRate
    }
end

--- 重置缓存统计
function state.ResetCacheStats()
    cache_stats.hits = 0
    cache_stats.misses = 0
    cache_stats.total_queries = 0
end

-- =========================================================================
-- 工具函数（基于 PoC 验证结果）
-- =========================================================================

--- 检查技能是否正在施法或引导
-- 基于 PoC_Spells 验证结果
-- @param spellName 技能名称
-- @return boolean, string - (正在施法, 施法类型 "cast"/"channel"/nil)
local function IsSpellCasting(spellName)
    -- 检查读条技能（如猛击、火球术）
    local castName = UnitCastingInfo("player")
    if castName == spellName then
        return true, "cast"
    end
    
    -- 检查引导技能（如利刃风暴、奥术飞弹）
    local channelName = UnitChannelInfo("player")
    if channelName == spellName then
        return true, "channel"
    end
    
    return false, nil
end

-- Helper to create a dummy "down" state
local aura_down = { up = false, down = true, count = 0, remains = 0, duration = 0 }

-- =========================================================================
-- Buff / Debuff Metatables
-- =========================================================================

local function FindAura(cache, id)
    -- 检查查询缓存
    local cacheType = (cache == buff_cache) and "buff" or "debuff"
    local cacheKey = GetCacheKey(cacheType, id, state.now)
    local cached = GetCachedResult(cacheKey)
    if cached then
        return cached
    end
    
    -- 执行实际查询
    local result = aura_down
    
    -- 1. Try exact ID match
    if cache[id] then 
        result = cache[id]
    -- 2. Try Name match (Handles Ranks)
    elseif type(id) == "number" then
        local name = GetSpellInfo(id)
        if name and cache[name] then
            result = cache[name]
        else
            -- 3. Fallback for Private Servers / ID Mismatches
            -- If ID 52437 (Sudden Death) fails, try looking for the name manually
            if id == 52437 then 
                if cache["Sudden Death"] then 
                    result = cache["Sudden Death"]
                elseif cache["猝死"] then 
                    result = cache["猝死"]
                end
            end
        end
    elseif type(id) == "string" and cache[id] then
        result = cache[id]
    end
    
    -- 缓存结果
    SetCachedResult(cacheKey, result)
    return result
end

local mt_buff = {
    __call = function(t, id)
        local aura = FindAura(buff_cache, id)
        -- Virtualize 'remains' based on state.now
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then -- Permanent
                return aura
            end
            
            local remains = math.max(0, expires - state.now)
            if remains == 0 then return aura_down end -- Expired in future
            
            -- Return a lightweight copy with updated remains
            -- (Optimization: could use a shared temp table to avoid GC churn)
            return {
                up = true,
                down = false,
                count = aura.count,
                -- Safe fallback for remains calculation
                remains = (expires == 0) and 9999 or math.max(0, expires - state.now),
                duration = aura.duration
            }
        end
        return aura
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             return aura_down
        end
    end
}

local mt_debuff = {
    __call = function(t, id)
        local aura = FindAura(debuff_cache, id)
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then return aura end
            
            -- Safe fallback for remains calculation
            local remains = 0
            if expires == 0 then
                remains = 9999
            else
                 -- Ensure state.now and expires are numbers before math
                 local now = tonumber(state.now) or GetTime()
                 local exp = tonumber(expires) or now
                 remains = math.max(0, exp - now)
            end
            
            if remains == 0 and expires ~= 0 then return aura_down end
            
            return {
                up = true,
                down = false,
                count = aura.count,
                remains = remains,
                duration = aura.duration
            }
        end
        return aura
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             return aura_down
        end
    end
}

-- =========================================================================
-- Spell Metatable
-- =========================================================================
-- Ensure ActionMap is populated properly (fallback if called too early)
if ns.BuildActionMap and (not ns.ActionMap or not next(ns.ActionMap)) then
    ns.BuildActionMap()
end

local mt_spell = {
    __call = function(t, id)
        -- Retrieve Spell Name to handle Ranks automatically
        -- IsUsableSpell(ID) only works if you have that specific Rank ID.
        -- IsUsableSpell(Name) works for highest rank.
        local req = id
        local name = GetSpellInfo(id)
        if name then req = name end

        -- Check usability
        local usable, nomana = IsUsableSpell(req)
        
        -- 职业特殊技能可用性检查（通过钩子系统）
        -- 技术债务已解决：不再硬编码 Execute 逻辑
        if ns.CallHookWithReturn then
            local hookResult = ns.CallHookWithReturn("check_spell_usable", id, name, usable, nomana)
            if hookResult then
                usable = hookResult.usable
                nomana = hookResult.nomana
            end
        end

        -- 检查施法状态（基于 PoC_Spells 验证结果）
        local isCasting, castType = IsSpellCasting(name or req)

        -- Check cooldown (基于 PoC_Spells 验证结果：使用 GCD_THRESHOLD 常量过滤 GCD)
        local start, duration, enabled = GetSpellCooldown(req)
        local on_cooldown = false
        
        local remains = 0
        if start and start > 0 and duration > GCD_THRESHOLD then -- 使用常量过滤 GCD
             -- Calculate when it comes off CD
             local readyAt = start + duration
             remains = math.max(0, readyAt - state.now)
             if remains > 0 then on_cooldown = true end
        end
        
        -- Allow glow if usable OR if only missing resources (nomana)
        -- AND not on cooldown relative to virtual time
        -- AND not currently casting (基于 PoC_Spells 验证结果)
        local ready = (not on_cooldown) and (usable or nomana) and (not isCasting)
        
        return {
            usable = usable,
            ready = ready,
            cooldown_remains = remains,
            casting = isCasting,          -- 新增：施法状态
            cast_type = castType,         -- 新增：施法类型 ("cast"/"channel")
            -- SimC Aliases
            up = ready,
            remains = remains
        }
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             
             -- DEBUG Log only if requested? Or hard fail?
             -- Actually, Execute might be failing because ActionMap isn't loaded yet?
             -- We added BuildActionMap call above.
             
             return {
                usable = false,
                ready = false,
                cooldown_remains = 0,
                casting = false,         -- 新增字段
                cast_type = nil,         -- 新增字段
                up = false,
                remains = 0,
                cast_time = 0 
             }
        end
    end
}

-- =========================================================================
-- State Structure
-- =========================================================================

state.now = 0 -- Virtual Time

state.spell = setmetatable({}, mt_spell)
state.cooldown = state.spell

state.player = {
    buff = setmetatable({}, mt_buff),
    power = { rage = { current = 0 } },
    moving = false,
    combat = false,           -- 战斗状态
    combat_time = 0           -- 战斗持续时间（秒）
}
state.buff = state.player.buff

state.target = {
    debuff = setmetatable({}, mt_debuff),
    health = { pct = 0, current = 0, max = 0 },
    time_to_die = 99
}
state.debuff = state.target.debuff

-- GCD State (基于 TODO.md P1 任务 1.1)
state.gcd = {
    active = false,           -- GCD 是否激活
    remains = 0,              -- GCD 剩余时间（秒）
    duration = 1.5            -- GCD 基础持续时间
}

state.active_enemies = 1

-- 战斗时间追踪（内部变量）
local combat_start_time = nil

-- =========================================================================
-- Reset / Update Function (Call every frame)
-- =========================================================================

-- =========================================================================
-- 光环扫描函数（基于 PoC_UnitState 验证结果）
-- =========================================================================

--- 扫描单位的 Buff（增益光环）
-- 基于 PoC_UnitState 验证：UnitBuff 返回标准顺序
-- @param unit 单位标识符
-- @param cache 缓存表
local function ScanBuffs(unit, cache)
    wipe(cache)
    for i = 1, MAX_AURA_SLOTS do
        -- 标准 API（7 个返回值）- 基于 PoC_UnitState 验证
        local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitBuff(unit, i)
        
        if not name then break end
        
        -- Sanitize expirationTime
        expirationTime = tonumber(expirationTime) or 0
        
        -- 判断所有权（基于 PoC_UnitState 验证）
        local isMine = (unitCaster == "player" or unitCaster == "pet")
        
        local aura = {
            up = true,
            down = false,
            mine = isMine,
            count = count or 1,
            expires = (expirationTime == 0) and 0 or expirationTime,
            duration = duration or 0,
            remains = (expirationTime == 0) and 9999 or 0  -- 动态计算占位符
        }
        
        -- 通过名称存储
        if name then
            cache[name] = aura
        end
        
        -- 尝试通过技能 ID 存储（需要手动映射，因为 WotLK UnitBuff 不返回 spellId）
        -- 这里暂时跳过，依赖名称查找
    end
end

--- 扫描单位的 Debuff（减益光环）
-- 注意：此函数假设 Debuff API 无参数偏移
-- 如果测试发现偏移存在，需要保留 State.lua:338-407 的复杂处理逻辑
-- @param unit 单位标识符
-- @param cache 缓存表
local function ScanDebuffs(unit, cache)
    wipe(cache)
    for i = 1, MAX_AURA_SLOTS do
        -- 标准 API（7 个返回值）- 假设无偏移（需要通过 DebuffOffsetTest 验证）
        local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitDebuff(unit, i)
        
        if not name then break end
        
        -- Sanitize expirationTime
        expirationTime = tonumber(expirationTime) or 0
        
        -- 判断所有权（基于 PoC_UnitState 验证）
        local isMine = (unitCaster == "player" or unitCaster == "pet")
        
        local aura = {
            up = true,
            down = false,
            mine = isMine,
            count = count or 1,
            expires = (expirationTime == 0) and 0 or expirationTime,
            duration = duration or 0,
            remains = (expirationTime == 0) and 9999 or 0  -- 动态计算占位符
        }
        
        -- 优先存储玩家施放的 Debuff
        if name then
            if isMine or not cache[name] then
                cache[name] = aura
            end
        end
    end
end

-- =========================================================================
-- State Reset Functions（任务 5.4 - 部分重置优化）
-- =========================================================================

--- 完整状态重置（扫描光环、更新资源）
-- @param full 是否执行完整重置（默认 true）
function state.reset(full)
    if full == nil then full = true end
    
    -- 始终更新的关键字段
    state.now = GetTime()
    
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
    
    -- GCD 检测
    local gcdStart, gcdDuration, gcdEnabled = GetSpellCooldown(61304)
    if gcdStart and gcdDuration and gcdStart > 0 and gcdDuration > 0 and gcdDuration <= GCD_THRESHOLD then
        state.gcd.active = true
        state.gcd.remains = math.max(0, (gcdStart + gcdDuration) - state.now)
    else
        state.gcd.active = false
        state.gcd.remains = 0
    end
    
    -- 轻量级重置：仅更新关键字段
    if not full then
        return
    end
    
    -- ===== 完整重置：扫描所有状态 =====
    
    -- 清空查询缓存（任务 5.1 - 帧级失效）
    ClearQueryCache()

    -- 1. Snapshot Player Stats
    state.player.power.rage.current = UnitPower("player", 1) -- 1=Rage
    
    -- SimC Aliases (Direct access for conditions like 'rage > 10')
    state.rage = state.player.power.rage.current
    state.mana = UnitPower("player", 0)
    state.energy = UnitPower("player", 3)
    state.runic = UnitPower("player", 6)
    
    state.player.moving = GetUnitSpeed("player") > 0
    state.player.combat = UnitAffectingCombat("player")
    
    state.active_enemies = 1 -- Placeholder
    
    -- 2. Snapshot Target Stats
    if UnitExists("target") then
        local hp = UnitHealth("target")
        local max = UnitHealthMax("target")
        local pct = (max > 0) and ((hp / max) * 100) or 0
        
        state.target.health.current = hp
        state.target.health.max = max
        state.target.health.pct = pct
        
        -- Legacy alias if needed
        state.target.health_pct = pct 
        
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
    
    -- 钩子：reset_preauras（任务 5.5）
    if ns.CallHook then
        ns.CallHook("reset_preauras")
    end
    
    -- 3. Snapshot Auras (基于 PoC_UnitState 验证结果)
    ScanBuffs("player", buff_cache)  -- 使用简化的标准 API
    
    if UnitExists("target") then
        -- 基于 PoC_UnitState 验证：标准 UnitDebuff API 工作正常，无需复杂偏移处理
        ScanDebuffs("target", debuff_cache)
    else
        wipe(debuff_cache)
    end
    
    -- 钩子：reset_postauras（任务 5.5）
    if ns.CallHook then
        ns.CallHook("reset_postauras")
    end

    -- 4. Set SimC Aliases
    state.buff = state.player.buff
    state.debuff = state.target.debuff
    state.cooldown = state.spell -- Aliasing Spell checks as Cooldown checks (SimC style)
end

-- =========================================================================
-- Virtual Time Advance (基于 TODO.md P1 任务 1.3 - 虚拟时间系统)
-- =========================================================================

--- 推进虚拟时间，模拟资源回复和 Buff 衰减
-- @param seconds 推进的时间（秒）
function state.advance(seconds)
    if not seconds or seconds <= 0 then return end
    
    local oldNow = state.now
    state.now = state.now + seconds
    
    -- 1. 资源回复计算（基于 TODO.md P1 任务 1.3）
    
    -- 能量回复（盗贼/德鲁伊猫形态）：基础 10/秒 × 急速加成
    if state.energy then
        local energyRegen = 10 -- 基础回复速度
        -- TODO: 添加急速加成计算 energyRegen = energyRegen * (1 + hasteBonus)
        local newEnergy = state.energy + (energyRegen * seconds)
        state.energy = math.min(100, newEnergy) -- 能量上限 100
    end
    
    -- 法力回复（施法者）
    if state.mana then
        -- TODO: 使用 GetPowerRegen() 获取精确回复速率
        -- local manaRegen = GetManaRegen() or 0
        -- local newMana = state.mana + (manaRegen * seconds)
        -- state.mana = math.min(UnitPowerMax("player", 0), newMana)
    end
    
    -- 怒气衰减（战士）：非战斗中每秒 -1
    if state.rage and not state.player.combat then
        local newRage = state.rage - (1 * seconds)
        state.rage = math.max(0, newRage)
        state.player.power.rage.current = state.rage
    end
    
    -- 符文能量回复（死亡骑士）
    if state.runic then
        local runicRegen = 10 -- 基础回复速度
        local newRunic = state.runic + (runicRegen * seconds)
        state.runic = math.min(100, newRunic) -- 符文能量上限 100
    end
    
    -- 2. Buff/Debuff 过期处理（基于 TODO.md P1 任务 1.3）
    
    -- 更新 Buff 剩余时间
    for name, aura in pairs(buff_cache) do
        if aura.expires and aura.expires > 0 then
            local newRemains = math.max(0, aura.expires - state.now)
            aura.remains = newRemains
            
            -- 标记过期的 Buff
            if newRemains <= 0 then
                aura.up = false
                aura.down = true
            end
        end
    end
    
    -- 更新 Debuff 剩余时间
    for name, aura in pairs(debuff_cache) do
        if aura.expires and aura.expires > 0 then
            local newRemains = math.max(0, aura.expires - state.now)
            aura.remains = newRemains
            
            -- 标记过期的 Debuff
            if newRemains <= 0 then
                aura.up = false
                aura.down = true
            end
        end
    end
    
    -- 3. 更新战斗时间
    if state.player.combat and combat_start_time then
        state.player.combat_time = state.now - combat_start_time
    end
    
    -- 4. 更新 GCD 剩余时间
    if state.gcd.active then
        state.gcd.remains = math.max(0, state.gcd.remains - seconds)
        if state.gcd.remains <= 0 then
            state.gcd.active = false
        end
    end
    
    -- Call hook for custom advance logic
    if ns.CallHook then
        ns.CallHook("advance", seconds)
    end
end
