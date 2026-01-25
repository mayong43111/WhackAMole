local addon, ns = ...

-- ========================================================================
-- 缓存系统模块
-- ========================================================================
-- 提供高性能缓存机制：对象池 + 查询缓存

-- ========================================================================
-- 对象池系统（减少 GC 压力）
-- ========================================================================

-- Buff/Debuff 查询结果对象池
local buffCachePool = {}
local debuffCachePool = {}

--- 从对象池获取可复用对象（避免频繁创建新表）
-- @param pool 对象池（table 数组）
-- @return table 可重用的表对象
local function GetFromPool(pool)
    return tremove(pool) or {}
end

--- 释放对象回对象池（wipe 后复用，减少 GC）
-- @param pool 对象池
-- @param obj 要释放的对象
local function ReleaseToPool(pool, obj)
    if obj then
        wipe(obj)  -- 清空表内容但保留内存
        tinsert(pool, obj)
    end
end

-- ========================================================================
-- 查询结果缓存系统（帧级缓存，避免重复计算）
-- ========================================================================

-- 查询结果缓存表（key = 查询标识，value = 查询结果）
local query_cache = {}

-- 缓存统计数据（用于性能分析和调优）
local cache_stats = {
    hits = 0,       -- 缓存命中次数
    misses = 0,     -- 缓存未命中次数
    total_queries = 0  -- 总查询次数
}

--- 生成查询缓存键（确保唯一性）
-- @param queryType 查询类型（"buff"/"debuff"/"cooldown"/"distance"）
-- @param id 查询标识符（SpellID 或技能名称）
-- @param timestamp 时间戳（用于帧级失效）
-- @return string 缓存键
local function GetCacheKey(queryType, id, timestamp)
    return string.format("%s_%s_%.3f", queryType, tostring(id), timestamp or 0)
end

--- 获取缓存的查询结果（带统计）
-- @param key 缓存键
-- @return table|nil 缓存的结果，未命中返回 nil
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

--- 设置查询结果到缓存
-- @param key 缓存键
-- @param value 要缓存的值（table）
local function SetCachedResult(key, value)
    query_cache[key] = value
end

--- 清空查询缓存（每帧调用，实现帧级失效）
local function ClearQueryCache()
    -- 同步缓存统计到日志系统（如果启用）
    if ns.Logger and ns.Logger.enabled then
        ns.Logger:UpdateCacheStats("query", cache_stats.hits, cache_stats.misses, "set")
    end
    
    -- 使用 pairs 遍历清空（比重新创建表更高效，避免 GC）
    for k in pairs(query_cache) do
        query_cache[k] = nil
    end
end

--- 获取缓存统计信息（用于性能分析）
-- @return table 包含 hits/misses/total_queries/hit_rate 的统计表
local function GetCacheStats()
    local hit_rate = (cache_stats.total_queries > 0) 
        and (cache_stats.hits / cache_stats.total_queries * 100) 
        or 0
    
    return {
        hits = cache_stats.hits,
        misses = cache_stats.misses,
        total_queries = cache_stats.total_queries,
        hit_rate = hit_rate
    }
end

--- 重置缓存统计（用于性能测试）
local function ResetCacheStats()
    cache_stats.hits = 0
    cache_stats.misses = 0
    cache_stats.total_queries = 0
end

-- ========================================================================
-- 导出模块
-- ========================================================================

ns.StateCache = {
    -- 对象池接口
    GetFromPool = GetFromPool,
    ReleaseToPool = ReleaseToPool,
    buffCachePool = buffCachePool,
    debuffCachePool = debuffCachePool,
    
    -- 查询缓存接口
    GetCacheKey = GetCacheKey,
    GetCachedResult = GetCachedResult,
    SetCachedResult = SetCachedResult,
    ClearQueryCache = ClearQueryCache,
    
    -- 统计接口
    GetCacheStats = GetCacheStats,
    ResetCacheStats = ResetCacheStats,
}

-- 向后兼容：导出到全局命名空间
ns.GetFromPool = GetFromPool
ns.ReleaseToPool = ReleaseToPool
