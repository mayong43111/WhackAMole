local _, ns = ...

-- =========================================================================
-- SystemLogTab - 系统日志页签
-- =========================================================================

local SystemLogTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.SystemLogTab = SystemLogTab

local AceGUI = LibStub("AceGUI-3.0")

--- 创建系统日志页签
function SystemLogTab:Create(container)
    -- 安全检查
    if not ns.Logger or not ns.Logger.systemLogs or not ns.Logger.systemLogs.lines then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000错误: Logger未初始化|r")
        errorLabel:SetFullWidth(true)
        container:AddChild(errorLabel)
        return
    end
    
    container:SetLayout("Fill")
    
    -- 使用MultiLineEditBox显示系统日志
    local logBox = AceGUI:Create("MultiLineEditBox")
    logBox:SetFullWidth(true)
    logBox:SetFullHeight(true)
    logBox:DisableButton(true)
    logBox:SetLabel(string.format("系统日志 (%d 条，最多显示最近 200 条) - 可直接选中复制", #ns.Logger.systemLogs.lines))
    
    if #ns.Logger.systemLogs.lines == 0 then
        logBox:SetText("|cff808080暂无系统日志记录|r")
    else
        -- 只显示最近200条日志，避免性能问题
        local displayLimit = 200
        local startIdx = math.max(1, #ns.Logger.systemLogs.lines - displayLimit + 1)
        local lines = {}
        
        -- 反向遍历（最新在上）
        for i = #ns.Logger.systemLogs.lines, startIdx, -1 do
            local log = ns.Logger.systemLogs.lines[i]
            
            -- 系统日志使用特殊颜色
            local color = "|cff00ff00"  -- 绿色
            
            table.insert(lines, string.format("%s[%s] [System] %s|r",
                color, log.timestamp, log.message))
        end
        
        logBox:SetText(table.concat(lines, "\n"))
    end
    
    container:AddChild(logBox)
end

--- 复制系统日志到剪贴板（供导出功能调用）
function SystemLogTab:CopyLogsToClipboard()
    if not ns.Logger or not ns.Logger.systemLogs or #ns.Logger.systemLogs.lines == 0 then
        return
    end
    
    local lines = {}
    for _, log in ipairs(ns.Logger.systemLogs.lines) do
        table.insert(lines, string.format("[%s] [System] %s", 
            log.timestamp, log.message))
    end
    
    return table.concat(lines, "\n")
end
