local addon, ns = ...

-- ========================================================================
-- 光环查询和缓存模块
-- ========================================================================
-- 从 State.lua 拆分而来，负责 Buff/Debuff 查询和缓存

-- 依赖其他 State 模块
local StateInit = ns.StateInit
local StateCache = ns.StateCache
local StateConfig = ns.StateConfig

-- 常量引用
local GCD_THRESHOLD = StateConfig.GCD_THRESHOLD
local MAX_AURA_SLOTS = StateConfig.MAX_AURA_SLOTS
local SPELL_LATENCY_WINDOW = StateConfig.SPELL_LATENCY_WINDOW
local aura_down = StateInit.aura_down

-- 光环缓存表
local buff_cache = {}
local debuff_cache = {}

-- P1优化：扫描控制标志
local needFullScan = true  -- 是否需要全量扫描
local lastScanTime = 0     -- 上次扫描时间
local INCREMENTAL_SCAN_INTERVAL = 0.1  -- 增量扫描间隔（0.1秒）

-- P1优化：虚拟状态的COW缓存（只在需要时创建）
local virtual_buff_cache = nil
local virtual_debuff_cache = nil
local isVirtualMode = false

-- ========================================================================
-- 缓存查询辅助函数
-- ========================================================================

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
    -- Step 1: 检查查询缓存（帧级缓存，避免重复查询）
    -- 注意：虚拟模式下不使用查询缓存，因为虚拟缓存与真实缓存不同
    local cached = nil
    if not isVirtualMode then
        local cacheType = (cache == buff_cache) and "buff" or "debuff"
        local cacheKey = StateCache.GetCacheKey(cacheType, id, stateNow)
        cached = StateCache.GetCachedResult(cacheKey)
        if cached then
            return cached
        end
    end
    
    -- Step 2: 查询 Aura 缓存（从上次扫描的结果中查找）
    local result = QueryAuraCache(cache, id)

    -- Step 2.5: 延迟补偿（处理网络延迟：如果 Debuff 还没出现，但我们刚刚施放过，则假定它存在）
    -- 注意: 只应用在配置的窗口内的施法记录，避免过期的施法干扰
    if not result and cache == debuff_cache and ns.State and ns.State.lastSpellCast then
        local lastTime = ns.State.lastSpellCast[id]
        if lastTime and (GetTime() - lastTime) < SPELL_LATENCY_WINDOW then
             result = {
                  up = true,
                  down = false,
                  mine = true,
                  count = 1,
                  remains = 12,        -- 假定持续时间（足够通过检测即可）
                  duration = 12,
                  expirationTime = GetTime() + 12
             }
        end
    end
    
    -- Step 3: 返回结果（未找到则返回 aura_down）
    result = result or aura_down
    
    -- Step 4: 缓存结果并返回（仅在真实模式下缓存）
    if not isVirtualMode then
        local cacheType = (cache == buff_cache) and "buff" or "debuff"
        local cacheKey = StateCache.GetCacheKey(cacheType, id, stateNow)
        StateCache.SetCachedResult(cacheKey, result)
    end
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

--- P1优化：增量更新光环剩余时间（轻量级更新）
-- 只更新已知buff的剩余时间，不进行全量扫描
-- @param cache 缓存表
-- @param stateNow 当前时间
local function IncrementalUpdateRemains(cache, stateNow)
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

--- P1优化：标记需要全量扫描
-- 由事件触发调用
local function MarkNeedFullScan()
    needFullScan = true
end

--- P1优化：深拷贝表（用于COW）
-- @param orig 原始表
-- @return table 深拷贝的表
local function deepcopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deepcopy(v)
        end
    else
        copy = orig
    end
    return copy
end

--- P1优化：进入虚拟模式（启用COW）
local function EnterVirtualMode()
    isVirtualMode = true
    -- 清空之前的虚拟缓存（设置为nil，让GetActiveCache重新创建带metatable的表）
    virtual_buff_cache = nil
    virtual_debuff_cache = nil
end

--- P1优化：退出虚拟模式
local function ExitVirtualMode()
    isVirtualMode = false
    virtual_buff_cache = nil
    virtual_debuff_cache = nil
end

--- P1优化：获取有效的缓存（真实或虚拟）
-- @param isBuffCache 是否是buff缓存
-- @return table 有效的缓存表
local function GetActiveCache(isBuffCache)
    if not isVirtualMode then
        return isBuffCache and buff_cache or debuff_cache
    end
    
    local virtualCache = isBuffCache and virtual_buff_cache or virtual_debuff_cache
    local realCache = isBuffCache and buff_cache or debuff_cache
    
    -- COW实现：通过metatable实现写时复制
    if not virtualCache then
        if isBuffCache then
            virtual_buff_cache = setmetatable({}, {
                __index = buff_cache  -- 读取时回退到真实缓存
            })
            return virtual_buff_cache
        else
            virtual_debuff_cache = setmetatable({}, {
                __index = debuff_cache
            })
            return virtual_debuff_cache
        end
    end
    
    return virtualCache
end

--- P1优化：智能扫描策略
-- 根据标志决定全量扫描还是增量更新
-- @return boolean 是否执行了全量扫描
local function SmartScan()
    local currentTime = GetTime()
    
    -- 策略1：如果标记需要全量扫描，立即执行
    if needFullScan then
        ScanBuffs("player", buff_cache)
        ScanDebuffs("target", debuff_cache)
        UpdateAuraRemains(buff_cache, currentTime)
        UpdateAuraRemains(debuff_cache, currentTime)
        needFullScan = false
        lastScanTime = currentTime
        return true
    end
    
    -- 策略2：增量更新（只更新剩余时间）
    if currentTime - lastScanTime >= INCREMENTAL_SCAN_INTERVAL then
        IncrementalUpdateRemains(buff_cache, currentTime)
        IncrementalUpdateRemains(debuff_cache, currentTime)
        lastScanTime = currentTime
        return false
    end
    
    return false
end

-- =========================================================================
-- Buff / Debuff 元表
-- =========================================================================

local mt_buff = {
    __call = function(t, id)
        local stateNow = (t._state and t._state.now) or GetTime()
        -- 虚拟模式下使用虚拟缓存
        local cache = GetActiveCache(true)  -- true = buff_cache
        local aura = FindAura(cache, id, stateNow)
        
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
                duration = aura.duration,
                mine = aura.mine or false,
                react = true  -- Buff存在时可响应（SimC兼容）
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
        -- 虚拟模式下使用虚拟缓存
        local cache = GetActiveCache(false)  -- false = debuff_cache
        local aura = FindAura(cache, id, stateNow)
        
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
-- 虚拟光环添加函数（用于效果模拟）
-- =========================================================================

--- 添加虚拟 Buff（用于次预测）
-- @param name Buff 名称或 spellID
-- @param duration 持续时间（秒）
-- @param stateNow 当前虚拟时间
local function AddVirtualBuff(name, duration, stateNow)
    local spellID = nil
    local spellName = nil
    
    -- 确定 ID 和 名称
    if type(name) == "number" then
        -- 输入是数字ID
        spellID = name
        spellName = GetSpellInfo(name) or tostring(name)
    else
        -- 输入是字符串名称，从ActionMap查找ID
        spellName = name
        spellID = ns.ActionMap and ns.ActionMap[name] or nil
    end
    
    if not spellName then return end
    
    -- P1优化：使用COW获取虚拟缓存
    local cache = GetActiveCache(true)  -- true = buff_cache
    
    local expires = stateNow + duration
    local buffData = {
        up = true,
        down = false,
        mine = true,
        count = 1,
        expires = expires,
        duration = duration,
        remains = duration  -- 会被 UpdateAuraRemains 更新
    }
    
    -- 同时用名称和ID作为key（解决ID/名称不匹配问题）
    cache[spellName] = buffData
    if spellID then
        cache[spellID] = buffData  -- 同一个表引用
    end
end

--- 添加虚拟 Debuff（用于次预测）
-- @param name Debuff 名称或 spellID
-- @param duration 持续时间（秒）
-- @param stateNow 当前虚拟时间
local function AddVirtualDebuff(name, duration, stateNow)
    local spellID = nil
    local spellName = nil
    
    -- 确定 ID 和 名称
    if type(name) == "number" then
        -- 输入是数字ID
        spellID = name
        spellName = GetSpellInfo(name) or tostring(name)
    else
        -- 输入是字符串名称，从ActionMap查找ID
        spellName = name
        spellID = ns.ActionMap and ns.ActionMap[name] or nil
    end
    
    if not spellName then return end
    
    -- P1优化：使用COW获取虚拟缓存
    local cache = GetActiveCache(false)  -- false = debuff_cache
    
    local expires = stateNow + duration
    local debuffData = {
        up = true,
        down = false,
        mine = true,
        count = 1,
        expires = expires,
        duration = duration,
        remains = duration  -- 会被 UpdateAuraRemains 更新
    }
    
    -- 同时用名称和ID作为key（解决ID/名称不匹配问题）
    cache[spellName] = debuffData
    if spellID then
        cache[spellID] = debuffData  -- 同一个表引用
    end
end

--- 消耗虚拟 Buff（减少层数或移除）
-- @param name Buff 名称或 spellID
local function ConsumeVirtualBuff(name)
    -- 转换 spellID 为名称
    local originalName = name
    if type(name) == "number" then
        name = GetSpellInfo(name) or tostring(name)
    end
    
    if not name then 
        return 
    end
    
    -- P1优化：使用COW获取虚拟缓存
    local cache = GetActiveCache(true)  -- true = buff_cache
    
    -- 从缓存中查找 buff
    local buff = cache[name]
    if not buff or not buff.up then
        return  -- Buff 不存在或未激活
    end
    
    -- P1优化：写时复制 - 修改前先复制
    if isVirtualMode and cache[name] == buff_cache[name] then
        -- buff还是从真实缓存继承的，需要复制
        cache[name] = deepcopy(buff)
        buff = cache[name]
    end
    
    -- 减少层数
    if buff.count and buff.count > 1 then
        buff.count = buff.count - 1
    else
        -- 只有1层或无层数信息，直接移除
        buff.up = false
        buff.down = true
        buff.count = 0
        buff.remains = 0
    end
end

--- 消耗真实 Buff（用于施法成功时立即更新缓存）
-- @param name Buff 名称或 spellID
local function ConsumeRealBuff(name)
    -- 转换 spellID 为名称
    local originalName = name
    if type(name) == "number" then
        name = GetSpellInfo(name) or tostring(name)
    end
    
    if not name then return end
    
    -- 从缓存中查找 buff
    local buff = buff_cache[name]
    if not buff or not buff.up then
        return  -- Buff 不存在或未激活
    end
    
    -- 减少层数（与虚拟消耗相同）
    if buff.count and buff.count > 1 then
        buff.count = buff.count - 1
    else
        -- 只有1层或无层数信息，直接移除
        buff.up = false
        buff.down = true
        buff.count = 0
        buff.remains = 0
    end
end

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
    
    -- P1优化：智能扫描
    SmartScan = SmartScan,
    MarkNeedFullScan = MarkNeedFullScan,
    IncrementalUpdateRemains = IncrementalUpdateRemains,
    
    -- P1优化：COW虚拟状态
    EnterVirtualMode = EnterVirtualMode,
    ExitVirtualMode = ExitVirtualMode,
    GetActiveCache = GetActiveCache,
    
    -- 虚拟光环添加
    AddVirtualBuff = AddVirtualBuff,
    AddVirtualDebuff = AddVirtualDebuff,
    ConsumeVirtualBuff = ConsumeVirtualBuff,
    ConsumeRealBuff = ConsumeRealBuff,
    
    -- 更新函数
    UpdateAuraRemains = UpdateAuraRemains,
    
    -- 元表
    CreateBuffMetatable = function() return mt_buff end,
    CreateDebuffMetatable = function() return mt_debuff end
}
