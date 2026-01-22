local _, ns = ...

-- =========================================================================
-- LogTab - 日志页签
-- =========================================================================

local LogTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.LogTab = LogTab

local AceGUI = LibStub("AceGUI-3.0")

--- 创建日志页签
function LogTab:Create(container)
    -- 安全检查
    if not ns.Logger or not ns.Logger.logs or not ns.Logger.logs.lines then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000错误: Logger未初始化|r")
        errorLabel:SetFullWidth(true)
        container:AddChild(errorLabel)
        return
    end
    
    container:SetLayout("Fill")
    
    -- 使用MultiLineEditBox显示日志（更高效，占满整个容器）
    local logBox = AceGUI:Create("MultiLineEditBox")
    logBox:SetFullWidth(true)
    logBox:SetFullHeight(true)
    logBox:DisableButton(true)
    logBox:SetLabel(string.format("日志 (%d 条，最多显示最近 200 条) - 可直接选中复制", #ns.Logger.logs.lines))
    
    if #ns.Logger.logs.lines == 0 then
        logBox:SetText("|cff808080暂无日志记录\n请点击 [启动监控] 按钮开始记录|r")
    else
        -- 只显示最近200条日志，避免性能问题
        local displayLimit = 200
        local startIdx = math.max(1, #ns.Logger.logs.lines - displayLimit + 1)
        local lines = {}
        
        -- 反向遍历（最新在上）
        for i = #ns.Logger.logs.lines, startIdx, -1 do
            local log = ns.Logger.logs.lines[i]
            
            -- 检查过滤器
            if ns.Logger.logs.filters[log.category] then
                -- 根据分类设置颜色
                local color = "|cffffffff"
                if log.category == "Error" then
                    color = "|cffff0000"
                elseif log.category == "Warn" then
                    color = "|cffffa500"
                elseif log.category == "System" then
                    color = "|cff00ff00"
                elseif log.category == "APL" then
                    color = "|cff00ffff"
                elseif log.category == "State" then
                    color = "|cffffcc00"
                end
                
                table.insert(lines, string.format("%s[%s] [%s] %s|r",
                    color, log.timestamp, log.category, log.message))
            end
        end
        
        logBox:SetText(table.concat(lines, "\n"))
    end
    
    container:AddChild(logBox)
end

