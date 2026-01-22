local addon, ns = ...

-- =========================================================================
-- 光环查询和缓存模块
-- =========================================================================

-- 从 State.lua 拆分而来，负责 Buff/Debuff 查询和缓存

local StateInit = ns.StateInit
local GCD_THRESHOLD = StateInit.GCD_THRESHOLD
local MAX_AURA_SLOTS = StateInit.MAX_AURA_SLOTS
local aura_down = StateInit.aura_down

-- Cache tables
local buff_cache = {}
local debuff_cache = {}

-- =========================================================================
-- 缓存查询辅助函数
-- =========================================================================

--- 从缓存中查询光环（优化后的函数）
-- @param cache 缓存表 (buff_cache 或 debuff_cache)
-- @param id 技能 ID 或名称
-- @return table 光环对象
local function QueryAuraCache(cache, id)
    -- 1. Try exact ID match
    if cache[id] then 
        return cache[id]
    end
    
    -- 2. Try Name match (Handles Ranks)
    if type(id) == "number" then
        local name = GetSpellInfo(id)
        if name and cache[name] then
            return cache[name]
        end
        
        -- 3. Fallback for specific Private Server ID Mismatches
        if id == 52437 then -- Sudden Death
            if cache["Sudden Death"] then 
                return cache["Sudden Death"]
            elseif cache["猝死"] then 
                return cache["猝死"]
            end
        end
    elseif type(id) == "string" and cache[id] then
        return cache[id]
    end
    
    return nil
end

--- 主光环查询函数（重构后：40行 vs 原250行）
-- @param cache 缓存表
-- @param id 技能 ID 或名称
-- @param stateNow 当前虚拟时间
-- @return table 光环对象
local function FindAura(cache, id, stateNow)
    -- Step 1: 检查查询缓存
    local cacheType = (cache == buff_cache) and "buff" or "debuff"
    local cacheKey = StateInit.GetCacheKey(cacheType, id, stateNow)
    local cached = StateInit.GetCachedResult(cacheKey)
    if cached then
        return cached
    end
    
    -- Step 2: 查询 Aura 缓存
    local result = QueryAuraCache(cache, id) or aura_down
    
    -- Step 3: 缓存结果并返回
    StateInit.SetCachedResult(cacheKey, result)
    return result
end

-- =========================================================================
-- 光环扫描函数（基于 PoC_UnitState 验证结果）
-- =========================================================================

--- 扫描单位的 Buff（增益光环）
-- @param unit 单位标识符
-- @param cache 缓存表
local function ScanBuffs(unit, cache)
    wipe(cache)
    for i = 1, MAX_AURA_SLOTS do
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
    end
end

--- 扫描单位的 Debuff（减益光环）
-- @param unit 单位标识符
-- @param cache 缓存表
local function ScanDebuffs(unit, cache)
    wipe(cache)
    for i = 1, MAX_AURA_SLOTS do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitDebuff(unit, i)
        
        if not name then break end
        
        -- Sanitize expirationTime
        expirationTime = tonumber(expirationTime) or 0
        
        -- 判断所有权
        local isMine = (unitCaster == "player" or unitCaster == "pet")
        
        local aura = {
            up = true,
            down = false,
            mine = isMine,
            count = count or 1,
            expires = (expirationTime == 0) and 0 or expirationTime,
            duration = duration or 0,
            remains = (expirationTime == 0) and 9999 or 0
        }
        
        -- 优先存储玩家施放的 Debuff（玩家的总是覆盖其他玩家的）
        if name then
            if isMine then
                cache[name] = aura  -- 玩家的Debuff优先，直接覆盖
            elseif not cache[name] then
                cache[name] = aura  -- 其他玩家的只在不存在时存储
            end
        end
    end
end

--- 更新光环剩余时间（虚拟时间推进时调用）
-- @param cache 缓存表
-- @param stateNow 当前虚拟时间
local function UpdateAuraRemains(cache, stateNow)
    for name, aura in pairs(cache) do
        if aura.expires and aura.expires > 0 then
            local newRemains = math.max(0, aura.expires - stateNow)
            aura.remains = newRemains
            
            -- 标记过期的光环
            if newRemains <= 0 then
                aura.up = false
                aura.down = true
            end
        end
    end
end

-- =========================================================================
-- Buff / Debuff 元表
-- =========================================================================

local mt_buff = {
    __call = function(t, id)
        local stateNow = (t._state and t._state.now) or GetTime()
        local aura = FindAura(buff_cache, id, stateNow)
        
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then -- Permanent
                return aura
            end
            
            local remains = math.max(0, expires - stateNow)
            if remains == 0 then return aura_down end
            
            return {
                up = true,
                down = false,
                count = aura.count,
                remains = (expires == 0) and 9999 or math.max(0, expires - stateNow),
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
        local stateNow = (t._state and t._state.now) or GetTime()
        local aura = FindAura(debuff_cache, id, stateNow)
        
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then return aura end
            
            local now = tonumber(stateNow) or GetTime()
            local exp = tonumber(expires) or now
            local remains = math.max(0, exp - now)
            
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
-- 导出模块
-- =========================================================================

ns.AuraTracking = {
    -- 缓存表
    buff_cache = buff_cache,
    debuff_cache = debuff_cache,
    
    -- 查询函数
    FindAura = FindAura,
    QueryAuraCache = QueryAuraCache,
    
    -- 扫描函数
    ScanBuffs = ScanBuffs,
    ScanDebuffs = ScanDebuffs,
    
    -- 更新函数
    UpdateAuraRemains = UpdateAuraRemains,
    
    -- 元表
    CreateBuffMetatable = function() return mt_buff end,
    CreateDebuffMetatable = function() return mt_debuff end
}
