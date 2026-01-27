-- ============================================================================
-- LogExportTab - 日志导出页签
-- ============================================================================
local addonName, ns = ...

local LogExportTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.LogExportTab = LogExportTab

--- 创建日志导出页签
-- @param container 父容器
-- @param Logger Logger实例
function LogExportTab:Create(container, Logger)
    -- 创建滚动框架
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    -- 文本框
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(false)
    
    -- 生成彩色日志
    local logLines = {}
    if Logger:Count() == 0 then
        table.insert(logLines, "日志为空。请施放任何法术来触发事件记录。")
        table.insert(logLines, "")
        table.insert(logLines, "测试步骤：")
        table.insert(logLines, "1. 切换到测试指导页签")
        table.insert(logLines, "2. 施放任意法术（即时/引导/持续施法均可）")
        table.insert(logLines, "3. 返回本页签查看日志")
    else
        -- 最多显示最近500条
        local displayLimit = 500
        local startIdx = math.max(1, Logger:Count() - displayLimit + 1)
        
        for i = Logger:Count(), startIdx, -1 do
            local entry = Logger.logs.lines[i]
            if Logger.logs.filters[entry.category] then
                -- 根据分类设置颜色
                local color = "|cffffffff"
                if entry.category == "Error" then
                    color = "|cffff0000"
                elseif entry.category == "Warn" then
                    color = "|cffffa500"
                elseif entry.category == "System" then
                    color = "|cff00ff00"
                elseif entry.category == "Cast" then
                    color = "|cff00ffff"
                elseif entry.category == "Channel" then
                    color = "|cffffcc00"
                elseif entry.category == "Event" then
                    color = "|cffaaaaaa"
                end
                
                table.insert(logLines, string.format("%s[%s] [%s] %s|r",
                    color, entry.timestamp, entry.category, entry.message))
            end
        end
    end
    
    editBox:SetText(table.concat(logLines, "\n"))
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    
    scrollFrame:SetScrollChild(editBox)
    
    -- 按钮容器
    local btnContainer = CreateFrame("Frame", nil, container)
    btnContainer:SetPoint("BOTTOMLEFT", 20, 10)
    btnContainer:SetPoint("BOTTOMRIGHT", -20, 10)
    btnContainer:SetHeight(30)
    
    -- 刷新按钮
    local refreshBtn = CreateFrame("Button", nil, btnContainer, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 25)
    refreshBtn:SetPoint("LEFT", 0, 0)
    refreshBtn:SetText("刷新")
    refreshBtn:SetScript("OnClick", function()
        -- 重新生成日志文本
        local newLogLines = {}
        if Logger:Count() == 0 then
            table.insert(newLogLines, "日志为空")
        else
            local displayLimit = 500
            local startIdx = math.max(1, Logger:Count() - displayLimit + 1)
            
            for i = Logger:Count(), startIdx, -1 do
                local entry = Logger.logs.lines[i]
                if Logger.logs.filters[entry.category] then
                    local color = "|cffffffff"
                    if entry.category == "Error" then
                        color = "|cffff0000"
                    elseif entry.category == "Warn" then
                        color = "|cffffa500"
                    elseif entry.category == "System" then
                        color = "|cff00ff00"
                    elseif entry.category == "Cast" then
                        color = "|cff00ffff"
                    elseif entry.category == "Channel" then
                        color = "|cffffcc00"
                    elseif entry.category == "Event" then
                        color = "|cffaaaaaa"
                    end
                    
                    table.insert(newLogLines, string.format("%s[%s] [%s] %s|r",
                        color, entry.timestamp, entry.category, entry.message))
                end
            end
        end
        
        editBox:SetText(table.concat(newLogLines, "\n"))
    end)
    
    -- 清空按钮
    local clearBtn = CreateFrame("Button", nil, btnContainer, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 25)
    clearBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
    clearBtn:SetText("清空")
    clearBtn:SetScript("OnClick", function()
        Logger:Clear()
        editBox:SetText("日志已清空")
    end)
    
    -- 全选按钮
    local selectAllBtn = CreateFrame("Button", nil, btnContainer, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(80, 25)
    selectAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    selectAllBtn:SetText("全选")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

return LogExportTab
