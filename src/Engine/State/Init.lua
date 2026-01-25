local addon, ns = ...

-- =========================================================================
-- State 初始化和配置
-- =========================================================================

-- 从主模块拆分而来，负责状态初始化和常量定义

-- =========================================================================
-- 常量定义（基于 PoC 验证结果）
-- =========================================================================
local GCD_THRESHOLD = 1.5  -- GCD 阈值，duration <= 1.5 秒视为全局冷却，不是真实技能冷却
local MAX_AURA_SLOTS = 40  -- 最大光环槽位数

-- =========================================================================
-- 对象池系统（任务 5.3 - 借鉴 Hekili）
-- =========================================================================

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
    return string.format("%s_%s_%.3f", queryType, tostring(id), timestamp or 0)
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
    -- 同步缓存统计到Logger（如果启用）
    if ns.Logger and ns.Logger.enabled then
        ns.Logger:UpdateCacheStats("query", cache_stats.hits, cache_stats.misses, "set")
    end
    
    -- 使用 wipe 比重新创建表更高效
    for k in pairs(query_cache) do
        query_cache[k] = nil
    end
end

-- =========================================================================
-- 基础 Aura 结构
-- =========================================================================

local aura_down = {
    up = false,
    down = true,
    count = 0,
    remains = 0,
    duration = 0,
    mine = false
}

-- =========================================================================
-- 导出模块
-- =========================================================================

ns.StateInit = {
    -- 常量
    GCD_THRESHOLD = GCD_THRESHOLD,
    MAX_AURA_SLOTS = MAX_AURA_SLOTS,
    
    -- 对象池
    GetFromPool = GetFromPool,
    ReleaseToPool = ReleaseToPool,
    buffCachePool = buffCachePool,
    debuffCachePool = debuffCachePool,
    
    -- 查询缓存
    GetCacheKey = GetCacheKey,
    GetCachedResult = GetCachedResult,
    SetCachedResult = SetCachedResult,
    ClearQueryCache = ClearQueryCache,
    
    -- 基础结构
    aura_down = aura_down
}

-- 导出到全局命名空间以保持兼容性
ns.GetFromPool = GetFromPool
ns.ReleaseToPool = ReleaseToPool
