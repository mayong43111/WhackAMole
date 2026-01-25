local addon, ns = ...

-- ========================================================================
-- State 初始化模块
-- ========================================================================
-- 提供基础数据结构和向后兼容接口

-- 依赖其他 State 模块
local StateConfig = ns.StateConfig
local StateCache = ns.StateCache

-- ========================================================================
-- 基础 Aura 结构（表示光环不存在的默认状态）
-- ========================================================================

local aura_down = {
    up = false,         -- 光环未激活
    down = true,        -- 光环已失效
    count = 0,          -- 光环层数
    remains = 0,        -- 剩余时间（秒）
    duration = 0,       -- 总持续时间（秒）
    mine = false,       -- 是否由玩家施放
    react = false       -- Buff 响应/触发状态（SimC 兼容）
}

-- ========================================================================
-- 导出模块
-- ========================================================================

ns.StateInit = {
    -- 常量（从 Config 引用）
    GCD_THRESHOLD = StateConfig.GCD_THRESHOLD,
    MAX_AURA_SLOTS = StateConfig.MAX_AURA_SLOTS,
    
    -- 对象池（从 Cache 引用）
    GetFromPool = StateCache.GetFromPool,
    ReleaseToPool = StateCache.ReleaseToPool,
    buffCachePool = StateCache.buffCachePool,
    debuffCachePool = StateCache.debuffCachePool,
    
    -- 查询缓存（从 Cache 引用）
    GetCacheKey = StateCache.GetCacheKey,
    GetCachedResult = StateCache.GetCachedResult,
    SetCachedResult = StateCache.SetCachedResult,
    ClearQueryCache = StateCache.ClearQueryCache,
    
    -- 基础结构
    aura_down = aura_down
}

-- 向后兼容：导出到全局命名空间
ns.GetFromPool = StateCache.GetFromPool
ns.ReleaseToPool = StateCache.ReleaseToPool
