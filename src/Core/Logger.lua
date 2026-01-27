local _, ns = ...

-- =========================================================================
-- Logger - 日志记录模块
-- =========================================================================
-- 负责日志、性能数据的记录，内部判断是否启用

local Logger = {}
ns.Logger = Logger

-- 日志状态
Logger.enabled = false  -- 是否启用日志记录

-- 日志数据
Logger.logs = {
    lines = {},           -- 普通日志行数组 [{timestamp, category, message}]
    maxLines = 1000       -- 最大行数
}

-- 系统日志数据（独立存储）
Logger.systemLogs = {
    lines = {},           -- 系统日志行数组 [{timestamp, category, message}]
    maxLines = 1000       -- 最大行数
}

-- 性能数据
Logger.performance = {
    frameTimes = {},      -- 最近 300 帧的耗时
    modules = {           -- 模块统计
        state = { total = 0, max = 0, count = 0 },
        apl = { total = 0, max = 0, count = 0 },
        predict = { total = 0, max = 0, count = 0 },
        ui = { total = 0, max = 0, count = 0 },
        audio = { total = 0, max = 0, count = 0 }
    },
    frameCount = 0,
    totalTime = 0
}

-- 缓存统计
Logger.cache = {
    query = { hits = 0, misses = 0 },
    script = { hits = 0, misses = 0 }
}

-- 实时指标
Logger.realtime = {
    fps = 0,
    avgFrameTime = 0,
    peakFrameTime = 0,
    memoryUsage = 0,
    lastUpdate = 0
}

--- 添加日志行
function Logger:Log(category, message)
    local timestamp = date("%H:%M:%S")
    local logEntry = {
        timestamp = timestamp,
        category = category,
        message = message
    }
    
    -- 系统日志单独存储，不受 enabled 控制
    if category == "System" then
        table.insert(self.systemLogs.lines, logEntry)
        
        -- 限制最大行数
        if #self.systemLogs.lines > self.systemLogs.maxLines then
            table.remove(self.systemLogs.lines, 1)
        end
        
        -- 通知 DebugWindow 刷新系统日志页签
        if ns.DebugWindow and ns.DebugWindow.isVisible and ns.DebugWindow.currentTab == "system" then
            ns.DebugWindow:RefreshCurrentTab()
        end
    else
        -- 普通日志需要检查 enabled
        if not self.enabled then return end
        
        table.insert(self.logs.lines, logEntry)
        
        -- 限制最大行数
        if #self.logs.lines > self.logs.maxLines then
            table.remove(self.logs.lines, 1)
        end
        
        -- 通知 DebugWindow 刷新日志页签
        if ns.DebugWindow and ns.DebugWindow.isVisible and ns.DebugWindow.currentTab == "log" then
            ns.DebugWindow:RefreshCurrentTab()
        end
    end
end

--- 记录性能数据
function Logger:RecordPerformance(moduleName, elapsedTime)
    if not self.enabled then return end
    
    local moduleData = self.performance.modules[moduleName]
    if not moduleData then return end
    
    moduleData.total = moduleData.total + elapsedTime
    moduleData.count = moduleData.count + 1
    if elapsedTime > moduleData.max then
        moduleData.max = elapsedTime
    end
    
    self.performance.frameCount = self.performance.frameCount + 1
    self.performance.totalTime = self.performance.totalTime + elapsedTime
end

--- 记录帧耗时
function Logger:RecordFrameTime(frameTime)
    if not self.enabled then return end
    
    table.insert(self.performance.frameTimes, frameTime)
    
    if #self.performance.frameTimes > 300 then
        table.remove(self.performance.frameTimes, 1)
    end
end

--- 更新缓存统计（支持增量更新）
-- @param cacheType "query" | "script"
-- @param hits 命中次数
-- @param misses 未命中次数
-- @param mode "set" | "add" (默认: "set")
function Logger:UpdateCacheStats(cacheType, hits, misses, mode)
    if not self.enabled then return end
    
    mode = mode or "set"
    
    if cacheType == "query" then
        if mode == "add" then
            self.cache.query.hits = self.cache.query.hits + (hits or 0)
            self.cache.query.misses = self.cache.query.misses + (misses or 0)
        else
            self.cache.query.hits = hits or self.cache.query.hits
            self.cache.query.misses = misses or self.cache.query.misses
        end
    elseif cacheType == "script" then
        if mode == "add" then
            self.cache.script.hits = self.cache.script.hits + (hits or 0)
            self.cache.script.misses = self.cache.script.misses + (misses or 0)
        else
            self.cache.script.hits = hits or self.cache.script.hits
            self.cache.script.misses = misses or self.cache.script.misses
        end
    end
end

--- 清空所有数据
function Logger:Clear()
    self.logs.lines = {}
    self.systemLogs.lines = {}
    self.performance.frameTimes = {}
    for _, modData in pairs(self.performance.modules) do
        modData.total = 0
        modData.max = 0
        modData.count = 0
    end
    self.performance.frameCount = 0
    self.performance.totalTime = 0
    self.cache.query.hits = 0
    self.cache.query.misses = 0
    self.cache.script.hits = 0
    self.cache.script.misses = 0
    self.realtime.peakFrameTime = 0
end

--- 错误日志
function Logger:Error(category, message)
    self:Log("Error", string.format("[%s] %s", category, message))
end

--- 警告日志
function Logger:Warn(category, message)
    self:Log("Warn", string.format("[%s] %s", category, message))
end

--- 调试日志
function Logger:Debug(category, message)
    self:Log(category, message)
end

--- 系统日志
function Logger:System(...)
    local args = {...}
    local msg = ""
    for i, v in ipairs(args) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(v)
    end
    self:Log("System", msg)
end

--- 启动监控（兼容旧命令）
function Logger:Start()
    if ns.DebugWindow then
        ns.DebugWindow:StartMonitoring()
    end
end

--- 停止监控（兼容旧命令）
function Logger:Stop()
    if ns.DebugWindow then
        ns.DebugWindow:StopMonitoring()
    end
end

--- 显示窗口（兼容旧命令）
function Logger:Show()
    if ns.DebugWindow then
        ns.DebugWindow:Show()
    end
end