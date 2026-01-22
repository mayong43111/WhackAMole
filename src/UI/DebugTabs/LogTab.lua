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
    
    container:SetLayout("List")
    
    -- 添加复制按钮
    local copyBtn = AceGUI:Create("Button")
    copyBtn:SetText("复制所有日志")
    copyBtn:SetWidth(150)
    copyBtn:SetCallback("OnClick", function()
        self:CopyLogsToClipboard()
    end)
    container:AddChild(copyBtn)
    
    -- 创建滚动容器
    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetLayout("Flow")
    
    if #ns.Logger.logs.lines == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cff808080暂无日志记录\n请点击 [启动监控] 按钮开始记录|r")
        emptyLabel:SetFullWidth(true)
        scrollContainer:AddChild(emptyLabel)
    else
        -- 显示日志行
        for i = #ns.Logger.logs.lines, 1, -1 do  -- 反向显示（最新在上）
            local log = ns.Logger.logs.lines[i]
            
            -- 检查过滤器
            if ns.Logger.logs.filters[log.category] then
                local logLabel = AceGUI:Create("Label")
                
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
                
                local text = string.format("%s[%s] [%s] %s|r", 
                    color, log.timestamp, log.category, log.message)
                logLabel:SetText(text)
                logLabel:SetFullWidth(true)
                scrollContainer:AddChild(logLabel)
            end
        end
    end
    
    container:AddChild(scrollContainer)
end

--- 复制日志到剪贴板
function LogTab:CopyLogsToClipboard()
    if not ns.Logger or not ns.Logger.logs or #ns.Logger.logs.lines == 0 then
        return
    end
    
    -- 创建临时窗口
    local copyFrame = AceGUI:Create("Frame")
    copyFrame:SetTitle("复制日志")
    copyFrame:SetLayout("Fill")
    copyFrame:SetWidth(700)
    copyFrame:SetHeight(500)
    copyFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    
    -- 创建可编辑文本框
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("全选 (Ctrl+A) 并复制 (Ctrl+C)")
    editBox:SetFullWidth(true)
    editBox:SetFullHeight(true)
    editBox:DisableButton(true)
    
    -- 生成日志文本
    local lines = {}
    for _, log in ipairs(ns.Logger.logs.lines) do
        table.insert(lines, string.format("[%s] [%s] %s", 
            log.timestamp, log.category, log.message))
    end
    editBox:SetText(table.concat(lines, "\n"))
    
    -- 自动全选文本
    editBox:SetFocus()
    editBox.editBox:HighlightText()
    
    copyFrame:AddChild(editBox)
end
