local _, ns = ...

-- =========================================================================
-- DebugWindow - 调试窗口（UI显示）
-- =========================================================================
-- 依赖: Logger (Core/Logger.lua 必须先加载)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

if not AceGUI then
    print("|cffff0000WhackAMole Error: AceGUI-3.0 not found!|r")
    print("|cffff0000Please make sure Ace3 libraries are installed.|r")
    return
end

local DebugWindow = {}
ns.DebugWindow = DebugWindow

-- 窗口状态
DebugWindow.frame = nil
DebugWindow.tabGroup = nil
DebugWindow.isVisible = false
DebugWindow.currentTab = "log"
DebugWindow.btnStart = nil
DebugWindow.btnStop = nil
DebugWindow.updateTimer = nil

-- =========================================================================
-- 窗口管理
-- =========================================================================

--- 显示调试窗口
function DebugWindow:Show()
    if self.isVisible and self.frame then
        return  -- 已显示，不重复创建
    end
    
    if not AceGUI then
        print("|cffff0000WhackAMole: AceGUI not available|r")
        return
    end
    
    -- 创建主窗口
    local frame = AceGUI:Create("Frame")
    
    if not frame then
        return
    end
    frame:SetTitle("WhackAMole 调试窗口")
    frame:SetWidth(900)
    frame:SetHeight(700)
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget)
        self:Hide()
    end)
    
    self.frame = frame
    self.isVisible = true
    
    -- 创建控制按钮组
    self:CreateControlButtons(frame)
    
    -- 创建页签容器
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs({
        {text = "日志", value = "log"},
        {text = "性能监控", value = "perf"}
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        self:SelectTab(container, group)
    end)
    
    -- 恢复上次使用的页签（默认为日志）
    local lastTab = self.currentTab or "log"
    tabGroup:SelectTab(lastTab)
    
    frame:AddChild(tabGroup)
    self.tabGroup = tabGroup
end

--- 隐藏调试窗口
function DebugWindow:Hide()
    if self.frame then
        AceGUI:Release(self.frame)
        self.frame = nil
        self.tabGroup = nil
        self.btnStart = nil
        self.btnStop = nil
        self.isVisible = false
    end
end

--- 切换页签
function DebugWindow:SelectTab(container, tabName)
    container:ReleaseChildren()
    
    -- 记录当前页签
    self.currentTab = tabName
    
    -- 根据页签渲染对应内容
    local success, err = pcall(function()
        if tabName == "log" then
            ns.DebugTabs.LogTab:Create(container)
        elseif tabName == "perf" then
            ns.DebugTabs.PerfTab:Create(container)
        end
    end)
    
    if not success then
        -- 显示错误信息
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000错误: " .. tostring(err) .. "|r")
        errorLabel:SetFullWidth(true)
        container:AddChild(errorLabel)
    end
end

--- 刷新当前页签
function DebugWindow:RefreshCurrentTab()
    if self.tabGroup then
        self:SelectTab(self.tabGroup, self.currentTab)
    end
end

-- =========================================================================
-- 控制按钮组
-- =========================================================================

--- 创建控制按钮组
function DebugWindow:CreateControlButtons(frame)
    -- 1. 启动监控按钮
    local btnStart = AceGUI:Create("Button")
    btnStart:SetText("启动监控")
    btnStart:SetWidth(120)
    btnStart:SetCallback("OnClick", function()
        self:StartMonitoring()
    end)
    frame:AddChild(btnStart)
    self.btnStart = btnStart
    
    -- 2. 停止监控按钮
    local btnStop = AceGUI:Create("Button")
    btnStop:SetText("停止监控")
    btnStop:SetWidth(120)
    btnStop:SetDisabled(true)  -- 初始禁用
    btnStop:SetCallback("OnClick", function()
        self:StopMonitoring()
    end)
    frame:AddChild(btnStop)
    self.btnStop = btnStop
    
    -- 3. 重置统计按钮
    local btnReset = AceGUI:Create("Button")
    btnReset:SetText("重置统计")
    btnReset:SetWidth(120)
    btnReset:SetCallback("OnClick", function()
        self:ResetStats()
    end)
    frame:AddChild(btnReset)
    
    -- 4. 导出日志按钮
    local btnExport = AceGUI:Create("Button")
    btnExport:SetText("导出日志")
    btnExport:SetWidth(120)
    btnExport:SetCallback("OnClick", function()
        self:ExportLogs()
    end)
    frame:AddChild(btnExport)
end

-- =========================================================================
-- 监控控制
-- =========================================================================

--- 启动监控
function DebugWindow:StartMonitoring()
    if not ns.Logger then
        return
    end
    
    if ns.Logger.enabled then return end
    
    ns.Logger.enabled = true
    
    -- 更新按钮状态
    if self.btnStart then
        self.btnStart:SetDisabled(true)
    end
    if self.btnStop then
        self.btnStop:SetDisabled(false)
    end
    
    -- 启动定时器（实时数据更新）
    self:StartUpdateTimer()
    
    -- 记录启动日志（此时Logger.enabled已经为true，所以会记录）
    ns.Logger:Log("System", "监控已启动")
    
    -- 添加一些示例数据以便测试
    ns.Logger:Log("System", "开始收集性能数据...")
    
    -- 模拟一些初始性能数据
    for i = 1, 10 do
        local frameTime = 1.5 + math.random() * 0.5
        ns.Logger:RecordFrameTime(frameTime)
        ns.Logger:RecordPerformance("state", frameTime * 0.3)
        ns.Logger:RecordPerformance("apl", frameTime * 0.5)
        ns.Logger:RecordPerformance("ui", frameTime * 0.2)
    end
    
    ns.Logger:UpdateCacheStats("query", 80, 20)
    ns.Logger:UpdateCacheStats("script", 90, 10)
    
    -- 刷新当前页签以显示数据
    self:RefreshCurrentTab()
end

--- 停止监控
function DebugWindow:StopMonitoring()
    if not ns.Logger or not ns.Logger.enabled then return end
    
    ns.Logger.enabled = false
    
    -- 更新按钮状态
    if self.btnStart then
        self.btnStart:SetDisabled(false)
    end
    if self.btnStop then
        self.btnStop:SetDisabled(true)
    end
    
    -- 停止定时器
    self:StopUpdateTimer()
    
    -- 记录日志
    ns.Logger:Log("System", "监控已停止")
end

--- 重置统计
function DebugWindow:ResetStats()
    ns.Logger:Clear()
    
    -- 刷新当前页签
    self:RefreshCurrentTab()
    
    ns.Logger:Log("System", "统计数据已重置")
end

--- 复制日志到剪贴板（使用可编辑框）
function DebugWindow:CopyLogsToClipboard()
    -- 委托给 LogTab
    ns.DebugTabs.LogTab:CopyLogsToClipboard()
end

--- 导出日志
function DebugWindow:ExportLogs()
    if not ns.Logger or not ns.Logger.logs or #ns.Logger.logs.lines == 0 then
        return
    end
    
    -- 创建导出窗口
    local exportFrame = AceGUI:Create("Frame")
    exportFrame:SetTitle("导出日志")
    exportFrame:SetLayout("Fill")
    exportFrame:SetWidth(700)
    exportFrame:SetHeight(500)
    exportFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    
    -- 创建多行文本框
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("日志内容 (Ctrl+A, Ctrl+C 复制)")
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
    
    exportFrame:AddChild(editBox)
end

-- =========================================================================
-- 定时器管理
-- =========================================================================

--- 启动更新定时器
function DebugWindow:StartUpdateTimer()
    if self.updateTimer then return end
    
    -- 使用 C_Timer 创建重复定时器（每 2 秒）
    self.updateTimer = C_Timer.NewTicker(2.0, function()
        self:UpdateRealtime()
    end)
end

--- 停止更新定时器
function DebugWindow:StopUpdateTimer()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
end

--- 更新实时数据
function DebugWindow:UpdateRealtime()
    if not ns.Logger or not ns.Logger.enabled then return end
    
    -- 模拟一帧的性能数据（用于测试）
    local frameTime = 1.0 + math.random() * 2.0
    ns.Logger:RecordFrameTime(frameTime)
    ns.Logger:RecordPerformance("state", frameTime * 0.25)
    ns.Logger:RecordPerformance("apl", frameTime * 0.35)
    ns.Logger:RecordPerformance("ui", frameTime * 0.20)
    ns.Logger:RecordPerformance("predict", frameTime * 0.15)
    ns.Logger:RecordPerformance("audio", frameTime * 0.05)
    
    -- 偶尔记录一条日志
    if math.random() < 0.1 then
        local categories = {"APL", "State", "Performance"}
        local messages = {
            "Condition evaluated",
            "Buff checked",
            "Frame processed",
            "Cache accessed",
            "Update completed"
        }
        ns.Logger:Log(
            categories[math.random(#categories)],
            messages[math.random(#messages)]
        )
    end
    
    -- 1. 计算 FPS（基于最近 10 帧）
    local frameCount = #ns.Logger.performance.frameTimes
    if frameCount > 0 then
        local startIdx = math.max(1, frameCount - 9)
        local sum = 0
        for i = startIdx, frameCount do
            sum = sum + ns.Logger.performance.frameTimes[i]
        end
        local avgFrameTime = sum / (frameCount - startIdx + 1)
        
        ns.Logger.realtime.fps = 1000.0 / avgFrameTime  -- ms -> FPS
        ns.Logger.realtime.avgFrameTime = avgFrameTime
    end
    
    -- 2. 获取内存使用
    UpdateAddOnMemoryUsage()
    ns.Logger.realtime.memoryUsage = GetAddOnMemoryUsage("WhackAMole") / 1024  -- KB -> MB
    
    -- 3. 更新峰值帧耗时
    for _, frameTime in ipairs(ns.Logger.performance.frameTimes) do
        if frameTime > ns.Logger.realtime.peakFrameTime then
            ns.Logger.realtime.peakFrameTime = frameTime
        end
    end
    
    -- 4. 刷新当前显示的页签（实时更新UI）
    if self.isVisible then
        self:RefreshCurrentTab()
    end
end
