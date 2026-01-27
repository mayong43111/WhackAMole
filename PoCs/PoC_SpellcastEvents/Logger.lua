-- ============================================================================
-- Logger - 日志管理器
-- ============================================================================

local addonName, ns = ...

local Logger = {
    logs = {
        lines = {},      -- 日志行数组 [{timestamp, category, message}]
        maxLines = 1000, -- 最大行数
        filters = {      -- 过滤器
            Event = true,
            Cast = true,
            Channel = true,
            System = true,
            Error = true,
            Warn = true,
        }
    }
}

--- 格式化时间戳为 HH:MM:SS
local function FormatTimestamp()
    return date("%H:%M:%S")
end

--- 添加日志行
function Logger:Log(category, message)
    -- 去除颜色代码
    local plainText = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    
    local logEntry = {
        timestamp = FormatTimestamp(),
        category = category or "System",
        message = plainText
    }
    
    table.insert(self.logs.lines, logEntry)
    
    -- 限制日志数量
    while #self.logs.lines > self.logs.maxLines do
        table.remove(self.logs.lines, 1)
    end
end

--- 快捷方法 - 事件日志
function Logger:Event(message)
    self:Log("Event", message)
end

--- 快捷方法 - 施法日志
function Logger:Cast(message)
    self:Log("Cast", message)
end

--- 快捷方法 - 引导日志
function Logger:Channel(message)
    self:Log("Channel", message)
end

--- 快捷方法 - 系统日志
function Logger:System(message)
    self:Log("System", message)
end

--- 快捷方法 - 错误日志
function Logger:Error(message)
    self:Log("Error", message)
end

--- 快捷方法 - 警告日志
function Logger:Warn(message)
    self:Log("Warn", message)
end

--- 获取所有日志（格式化为文本）
function Logger:GetAll()
    local result = {}
    for _, entry in ipairs(self.logs.lines) do
        -- 检查过滤器
        if self.logs.filters[entry.category] then
            table.insert(result, string.format("[%s] [%s] %s",
                entry.timestamp, entry.category, entry.message))
        end
    end
    return table.concat(result, "\n")
end

--- 清空日志
function Logger:Clear()
    self.logs.lines = {}
end

--- 获取日志数量
function Logger:Count()
    return #self.logs.lines
end

-- 导出到命名空间
ns.Logger = Logger
