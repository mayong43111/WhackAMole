-- ============================================================================
-- DebugWindow - 多页签调试窗口
-- ============================================================================
-- 依赖: Logger, State, ScenarioRegistry

local addonName, ns = ...

local DebugWindow = {}

-- 窗口状态
DebugWindow.frame = nil
DebugWindow.tabGroup = nil
DebugWindow.currentTab = "guide"
DebugWindow.isVisible = false

--- 显示调试窗口
-- @param Logger Logger实例
-- @param State 全局状态
-- @param ScenarioRegistry 场景注册表
function DebugWindow.Show(Logger, State, ScenarioRegistry)
    if DebugWindow.isVisible and DebugWindow.frame then
        DebugWindow.frame:Show()
        return
    end
    
    local frame = CreateFrame("Frame", "PoC_DebugWindow", UIParent)
    frame:SetSize(700, 500)
    frame:SetPoint("CENTER")
    
    -- 背景
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.9)
    
    -- 边框
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    -- 标题
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("PoC 施法事件调试窗口")
    title:SetTextColor(0, 1, 0)
    
    -- 创建页签按钮组
    local tabButtons = {}
    local tabData = {
        {key = "guide", text = "测试指导"},
        {key = "log", text = "日志导出"}
    }
    
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", 20, -45)
    tabContainer:SetSize(660, 30)
    
    for i, tab in ipairs(tabData) do
        local btn = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
        btn:SetSize(100, 25)
        btn:SetPoint("LEFT", (i - 1) * 105, 0)
        btn:SetText(tab.text)
        btn:SetScript("OnClick", function()
            DebugWindow.SelectTab(tab.key, Logger, State, ScenarioRegistry)
        end)
        tabButtons[tab.key] = btn
    end
    
    -- 内容容器
    local contentContainer = CreateFrame("Frame", nil, frame)
    contentContainer:SetPoint("TOPLEFT", 20, -80)
    contentContainer:SetPoint("BOTTOMRIGHT", -20, 50)
    
    -- 重置按钮
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("BOTTOMLEFT", 20, 15)
    resetBtn:SetText("重置测试数据")
    resetBtn:SetScript("OnClick", function()
        ScenarioRegistry:Reset()
        State.eventsTriggered = {}
        Logger:Clear()
        State.eventCount = {}
        
        for _, row in pairs(State.scenarioRows) do
            row.statusText:SetText("未测试")
            row.statusText:SetTextColor(0.6, 0.6, 0.6)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00已重置所有测试数据|r")
    end)
    
    -- 关闭按钮
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    closeBtn:SetText("关闭")
    closeBtn:SetScript("OnClick", function()
        DebugWindow.Hide()
    end)
    
    DebugWindow.frame = frame
    DebugWindow.tabButtons = tabButtons
    DebugWindow.contentContainer = contentContainer
    DebugWindow.isVisible = true
    
    -- 默认显示测试指导页签
    DebugWindow.SelectTab(DebugWindow.currentTab, Logger, State, ScenarioRegistry)
    
    frame:Show()
end

--- 隐藏调试窗口
function DebugWindow.Hide()
    if DebugWindow.frame then
        DebugWindow.frame:Hide()
        DebugWindow.isVisible = false
    end
end

--- 切换页签
-- @param tabKey 页签键值
-- @param Logger Logger实例
-- @param State 全局状态
-- @param ScenarioRegistry 场景注册表
function DebugWindow.SelectTab(tabKey, Logger, State, ScenarioRegistry)
    if not DebugWindow.contentContainer then return end
    
    -- 清空内容容器
    local container = DebugWindow.contentContainer
    for _, child in ipairs({container:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- 更新按钮状态
    for key, btn in pairs(DebugWindow.tabButtons) do
        if key == tabKey then
            btn:Disable()
            btn:SetAlpha(1.0)
        else
            btn:Enable()
            btn:SetAlpha(0.7)
        end
    end
    
    -- 记录当前页签
    DebugWindow.currentTab = tabKey
    
    -- 渲染对应页签内容
    if tabKey == "guide" then
        ns.DebugTabs.GuideTab:Create(container, State, ScenarioRegistry)
    elseif tabKey == "log" then
        ns.DebugTabs.LogExportTab:Create(container, Logger)
    end
end

--- 刷新当前页签
function DebugWindow.Refresh(Logger, State, ScenarioRegistry)
    if DebugWindow.isVisible then
        DebugWindow.SelectTab(DebugWindow.currentTab, Logger, State, ScenarioRegistry)
    end
end

--- 兼容旧接口（保留 Create 函数用于向后兼容）
function DebugWindow.Create(Logger, State)
    DebugWindow.Show(Logger, State, ns.ScenarioRegistry)
end

-- 导出到命名空间
ns.DebugWindow = DebugWindow

