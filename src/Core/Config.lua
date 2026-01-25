local addon, ns = ...

-- =========================================================================
-- Core/Config.lua - 配置常量和默认值
-- =========================================================================

-- 从 Core.lua 拆分而来，负责配置管理

local Config = {}
ns.CoreConfig = Config

-- =========================================================================
-- 配置常量
-- =========================================================================

Config.UPDATE_INTERVAL = 0.05  -- 主循环更新间隔（50ms = 20 FPS）
Config.THROTTLE_INTERVAL = 0.016  -- 事件节流间隔（16ms ≈ 60 FPS）

-- 优先级事件列表（立即处理，不节流）
Config.PRIORITY_EVENTS = {
    "SPELL_CAST_SUCCESS",
    "SPELL_INTERRUPT",
    "SPELL_AURA_APPLIED",
    "SPELL_AURA_REMOVED"
}

-- =========================================================================
-- 默认数据库结构
-- =========================================================================

Config.DEFAULT_DB = {
    global = {
        audio = { 
            enabled = false,
            volume = 1.0  -- 0.0 to 1.0 (预留音量控制)
        },
        profiles = {} -- 用户配置文件
    },
    char = {
        assignments = {},  -- [slotId] = spellID
        position = { point = "CENTER", x = 0, y = -220 },
        activeProfileID = nil  -- 当前激活的配置ID
    }
}

-- =========================================================================
-- 性能配置
-- =========================================================================

Config.PERF = {
    MAX_FRAME_HISTORY = 1000,  -- 保留最近1000帧用于统计
    STATS_RESET_INTERVAL = 300  -- 每5分钟重置统计（可选）
}

-- =========================================================================
-- 导出函数
-- =========================================================================

--- 获取配置表的深拷贝（避免外部修改）
function Config:GetDefaultDB()
    -- 简单深拷贝（仅支持表和基础类型）
    local function deepCopy(orig)
        local copy
        if type(orig) == 'table' then
            copy = {}
            for k, v in pairs(orig) do
                copy[k] = deepCopy(v)
            end
        else
            copy = orig
        end
        return copy
    end
    
    return deepCopy(self.DEFAULT_DB)
end

--- 判断事件是否为优先级事件
-- @param eventType 事件类型
-- @return boolean
function Config:IsPriorityEvent(eventType)
    for _, priority in ipairs(self.PRIORITY_EVENTS) do
        if eventType == priority then
            return true
        end
    end
    return false
end

return Config
