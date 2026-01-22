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
    lines = {},           -- 日志行数组 [{timestamp, category, message}]
    maxLines = 1000,      -- 最大行数
    filters = {           -- 过滤器
        Combat = true,
        State = true,
        APL = true,
        Error = true,
        Warn = true,
        System = true,
        Performance = true
    }
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
    if not self.enabled then return end
    
    local timestamp = date("%H:%M:%S")
    table.insert(self.logs.lines, {
        timestamp = timestamp,
        category = category,
        message = message
    })
    
    -- 限制最大行数
    if #self.logs.lines > self.logs.maxLines then
        table.remove(self.logs.lines, 1)
    end
    
    -- 通知 DebugWindow 刷新（如果正在显示日志页签）
    if ns.DebugWindow and ns.DebugWindow.isVisible and ns.DebugWindow.currentTab == "log" then
        ns.DebugWindow:RefreshCurrentTab()
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

--- 更新缓存统计
function Logger:UpdateCacheStats(cacheType, hits, misses)
    if not self.enabled then return end
    
    if cacheType == "query" then
        self.cache.query.hits = hits or self.cache.query.hits
        self.cache.query.misses = misses or self.cache.query.misses
    elseif cacheType == "script" then
        self.cache.script.hits = hits or self.cache.script.hits
        self.cache.script.misses = misses or self.cache.script.misses
    end
end

--- 清空所有数据
function Logger:Clear()
    self.logs.lines = {}
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

-- =========================================================================
-- DebugWindow - 调试窗口（UI显示）
-- =========================================================================

local AceGUI = LibStub("AceGUI-3.0")

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
    
    -- 创建主窗口
    local frame = AceGUI:Create("Frame")
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
        {text = "📋 日志", value = "log"},
        {text = "📊 性能分析", value = "perf"},
        {text = "💾 缓存统计", value = "cache"},
        {text = "⚡ 实时监控", value = "realtime"}
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
    if tabName == "log" then
        self:CreateLogTab(container)
    elseif tabName == "perf" then
        self:CreatePerfTab(container)
    elseif tabName == "cache" then
        self:CreateCacheTab(container)
    elseif tabName == "realtime" then
        self:CreateRealtimeTab(container)
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
    btnStart:SetText("▶ 启动监控")
    btnStart:SetWidth(120)
    btnStart:SetCallback("OnClick", function()
        self:StartMonitoring()
    end)
    frame:AddChild(btnStart)
    self.btnStart = btnStart
    
    -- 2. 停止监控按钮
    local btnStop = AceGUI:Create("Button")
    btnStop:SetText("⏸ 停止监控")
    btnStop:SetWidth(120)
    btnStop:SetDisabled(true)  -- 初始禁用
    btnStop:SetCallback("OnClick", function()
        self:StopMonitoring()
    end)
    frame:AddChild(btnStop)
    self.btnStop = btnStop
    
    -- 3. 重置统计按钮
    local btnReset = AceGUI:Create("Button")
    btnReset:SetText("🔄 重置统计")
    btnReset:SetWidth(120)
    btnReset:SetCallback("OnClick", function()
        self:ResetStats()
    end)
    frame:AddChild(btnReset)
    
    -- 4. 导出日志按钮
    local btnExport = AceGUI:Create("Button")
    btnExport:SetText("📋 导出日志")
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
    
    -- 记录日志
    ns.Logger:Log("System", "监控已启动")
    
    print("|cff00ff00WhackAMole: 监控已启动|r")
end

--- 停止监控
function DebugWindow:StopMonitoring()
    if not ns.Logger.enabled then return end
    
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
    
    print("|cffff0000WhackAMole: 监控已停止|r")
end

--- 重置统计
function DebugWindow:ResetStats()
    ns.Logger:Clear()
    
    -- 刷新当前页签
    self:RefreshCurrentTab()
    
    ns.Logger:Log("System", "统计数据已重置")
    print("|cff00ff00WhackAMole: 统计数据已重置|r")
end

--- 导出日志
function DebugWindow:ExportLogs()
    if #ns.Logger.logs.lines == 0 then
        print("|cffff0000WhackAMole: 没有日志可导出|r")
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
    
    print("|cff00ff00WhackAMole: 日志已导出到窗口|r")
end

-- =========================================================================
-- 定时器管理
-- =========================================================================

--- 启动更新定时器
function DebugWindow:StartUpdateTimer()
    if self.updateTimer then return end
    
    -- 使用 C_Timer 创建重复定时器（每 0.5 秒）
    self.updateTimer = C_Timer.NewTicker(0.5, function()
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
    if not ns.Logger.enabled then return end
    
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
    
    -- 4. 刷新实时监控页签（如果当前显示）
    if self.currentTab == "realtime" and self.isVisible then
        self:RefreshCurrentTab()
    end
end

-- =========================================================================
-- 页签实现
-- =========================================================================

--- 创建日志页签
function DebugWindow:CreateLogTab(container)
    container:ReleaseChildren()
    
    -- 创建滚动容器
    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Flow")
    
    if #ns.Logger.logs.lines == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cff808080暂无日志记录\n请点击 [▶ 启动监控] 按钮开始记录|r")
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

--- 创建性能分析页签
function DebugWindow:CreatePerfTab(container)
    container:ReleaseChildren()
    
    -- 1. 关键指标摘要
    local summaryGroup = AceGUI:Create("InlineGroup")
    summaryGroup:SetTitle("关键指标")
    summaryGroup:SetFullWidth(true)
    summaryGroup:SetLayout("Flow")
    
    local stats = ns.Logger.performance
    local avgTime = stats.frameCount > 0 and (stats.totalTime / stats.frameCount) or 0
    
    local summary1 = AceGUI:Create("Label")
    summary1:SetText(string.format("总帧数: %d", stats.frameCount))
    summary1:SetWidth(200)
    summaryGroup:AddChild(summary1)
    
    local summary2 = AceGUI:Create("Label")
    summary2:SetText(string.format("平均耗时: %.2f ms", avgTime))
    summary2:SetWidth(200)
    summaryGroup:AddChild(summary2)
    
    local summary3 = AceGUI:Create("Label")
    summary3:SetText(string.format("峰值耗时: %.2f ms", ns.Logger.realtime.peakFrameTime))
    summary3:SetWidth(200)
    summaryGroup:AddChild(summary3)
    
    local summary4 = AceGUI:Create("Label")
    summary4:SetText(string.format("当前 FPS: %.1f", ns.Logger.realtime.fps))
    summary4:SetWidth(200)
    summaryGroup:AddChild(summary4)
    
    container:AddChild(summaryGroup)
    
    -- 2. 帧耗时趋势图
    local chartGroup = AceGUI:Create("InlineGroup")
    chartGroup:SetTitle("帧耗时趋势（最近 300 帧）")
    chartGroup:SetFullWidth(true)
    chartGroup:SetLayout("Fill")
    
    local chartText = self:GenerateFrameTimeChart()
    local chartLabel = AceGUI:Create("Label")
    chartLabel:SetText(chartText)
    chartLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    chartLabel:SetFullWidth(true)
    
    chartGroup:AddChild(chartLabel)
    container:AddChild(chartGroup)
    
    -- 3. 模块耗时分布
    local moduleGroup = AceGUI:Create("InlineGroup")
    moduleGroup:SetTitle("模块耗时分布")
    moduleGroup:SetFullWidth(true)
    moduleGroup:SetLayout("Fill")
    
    local moduleText = self:GenerateModuleStats()
    local moduleLabel = AceGUI:Create("Label")
    moduleLabel:SetText(moduleText)
    moduleLabel:SetFullWidth(true)
    
    moduleGroup:AddChild(moduleLabel)
    container:AddChild(moduleGroup)
end

--- 生成帧耗时趋势图（ASCII 图表）
function DebugWindow:GenerateFrameTimeChart()
    local times = ns.Logger.performance.frameTimes
    if #times == 0 then
        return "|cff808080暂无数据\n请启动监控并执行一些操作|r"
    end
    
    -- 计算最大值用于归一化
    local maxTime = 0
    for _, t in ipairs(times) do
        maxTime = math.max(maxTime, t)
    end
    
    if maxTime == 0 then maxTime = 1 end
    
    -- 生成 20 行高度的图表
    local chartHeight = 20
    local lines = {}
    
    -- Y 轴刻度
    for i = chartHeight, 1, -1 do
        local threshold = (i / chartHeight) * maxTime
        local line = string.format("%5.1f ms |", threshold)
        
        -- 绘制数据点
        for _, t in ipairs(times) do
            local normalized = (t / maxTime) * chartHeight
            if normalized >= i then
                line = line .. "█"
            else
                line = line .. " "
            end
        end
        
        table.insert(lines, line)
    end
    
    -- X 轴
    local xAxis = "       └" .. string.rep("─", #times)
    table.insert(lines, xAxis)
    table.insert(lines, string.format("        0%s帧%d", string.rep(" ", #times - 10), #times))
    
    return table.concat(lines, "\n")
end

--- 生成模块统计表格
function DebugWindow:GenerateModuleStats()
    local modules = ns.Logger.performance.modules
    local totalTime = ns.Logger.performance.totalTime
    
    if totalTime == 0 then
        return "|cff808080暂无数据\n请启动监控后会自动采集性能数据|r"
    end
    
    local lines = {}
    table.insert(lines, "模块       平均耗时   峰值耗时   占比")
    table.insert(lines, "─────────────────────────────────────────")
    
    local moduleNames = {
        {key = "state", name = "State 快照"},
        {key = "apl", name = "APL 执行 "},
        {key = "predict", name = "预测计算 "},
        {key = "ui", name = "UI 更新  "},
        {key = "audio", name = "音频播放 "}
    }
    
    for _, m in ipairs(moduleNames) do
        local data = modules[m.key]
        local avgTime = data.count > 0 and (data.total / data.count) or 0
        local pct = (data.total / totalTime) * 100
        
        table.insert(lines, string.format(
            "%s  %.2f ms   %.2f ms   %.1f%%",
            m.name, avgTime, data.max, pct
        ))
    end
    
    return table.concat(lines, "\n")
end

--- 创建缓存统计页签
function DebugWindow:CreateCacheTab(container)
    container:ReleaseChildren()
    
    -- 查询缓存统计
    local queryGroup = AceGUI:Create("InlineGroup")
    queryGroup:SetTitle("查询缓存统计（State 模块）")
    queryGroup:SetFullWidth(true)
    queryGroup:SetLayout("Flow")
    
    local queryTotal = ns.Logger.cache.query.hits + ns.Logger.cache.query.misses
    local queryRate = queryTotal > 0 
        and (ns.Logger.cache.query.hits / queryTotal * 100) or 0
    
    local queryLabel1 = AceGUI:Create("Label")
    queryLabel1:SetText(string.format("命中次数: %d", ns.Logger.cache.query.hits))
    queryLabel1:SetWidth(200)
    queryGroup:AddChild(queryLabel1)
    
    local queryLabel2 = AceGUI:Create("Label")
    queryLabel2:SetText(string.format("未命中次数: %d", ns.Logger.cache.query.misses))
    queryLabel2:SetWidth(200)
    queryGroup:AddChild(queryLabel2)
    
    local queryLabel3 = AceGUI:Create("Label")
    queryLabel3:SetText(string.format("命中率: %.1f%%", queryRate))
    queryLabel3:SetWidth(200)
    queryGroup:AddChild(queryLabel3)
    
    container:AddChild(queryGroup)
    
    -- 脚本缓存统计
    local scriptGroup = AceGUI:Create("InlineGroup")
    scriptGroup:SetTitle("脚本缓存统计（SimCParser 模块）")
    scriptGroup:SetFullWidth(true)
    scriptGroup:SetLayout("Flow")
    
    local scriptTotal = ns.Logger.cache.script.hits + ns.Logger.cache.script.misses
    local scriptRate = scriptTotal > 0 
        and (ns.Logger.cache.script.hits / scriptTotal * 100) or 0
    
    local scriptLabel1 = AceGUI:Create("Label")
    scriptLabel1:SetText(string.format("命中次数: %d", ns.Logger.cache.script.hits))
    scriptLabel1:SetWidth(200)
    scriptGroup:AddChild(scriptLabel1)
    
    local scriptLabel2 = AceGUI:Create("Label")
    scriptLabel2:SetText(string.format("未命中次数: %d", ns.Logger.cache.script.misses))
    scriptLabel2:SetWidth(200)
    scriptGroup:AddChild(scriptLabel2)
    
    local scriptLabel3 = AceGUI:Create("Label")
    scriptLabel3:SetText(string.format("命中率: %.1f%%", scriptRate))
    scriptLabel3:SetWidth(200)
    scriptGroup:AddChild(scriptLabel3)
    
    container:AddChild(scriptGroup)
    
    -- 说明文字
    local noteLabel = AceGUI:Create("Label")
    noteLabel:SetText("\n|cff808080提示: 缓存命中率越高，性能越好。\n建议保持在 80% 以上以获得最佳性能。|r")
    noteLabel:SetFullWidth(true)
    container:AddChild(noteLabel)
end

--- 创建实时监控页签
function DebugWindow:CreateRealtimeTab(container)
    container:ReleaseChildren()
    
    -- 1. FPS 指示器
    local fpsGroup = AceGUI:Create("InlineGroup")
    fpsGroup:SetTitle("帧率 (FPS)")
    fpsGroup:SetFullWidth(true)
    
    local fpsLabel = AceGUI:Create("Label")
    local fpsColor = "|cff00ff00"
    if ns.Logger.realtime.fps < 30 then
        fpsColor = "|cffff0000"
    elseif ns.Logger.realtime.fps < 50 then
        fpsColor = "|cffffa500"
    end
    fpsLabel:SetText(string.format("%s%.1f FPS|r", fpsColor, ns.Logger.realtime.fps))
    fpsLabel:SetFont("Fonts\\FRIZQT__.TTF", 24)
    fpsLabel:SetFullWidth(true)
    
    fpsGroup:AddChild(fpsLabel)
    container:AddChild(fpsGroup)
    
    -- 2. 帧耗时指示器
    local frameTimeGroup = AceGUI:Create("InlineGroup")
    frameTimeGroup:SetTitle("帧耗时")
    frameTimeGroup:SetFullWidth(true)
    frameTimeGroup:SetLayout("Flow")
    
    self:AddLabelWithProgress(frameTimeGroup, "平均", 
        ns.Logger.realtime.avgFrameTime, 5.0, "ms")
    self:AddLabelWithProgress(frameTimeGroup, "峰值", 
        ns.Logger.realtime.peakFrameTime, 10.0, "ms")
    
    container:AddChild(frameTimeGroup)
    
    -- 3. 缓存命中率
    local cacheGroup = AceGUI:Create("InlineGroup")
    cacheGroup:SetTitle("缓存效率")
    cacheGroup:SetFullWidth(true)
    cacheGroup:SetLayout("Flow")
    
    local queryTotal = ns.Logger.cache.query.hits + ns.Logger.cache.query.misses
    local queryRate = queryTotal > 0 
        and (ns.Logger.cache.query.hits / queryTotal * 100) or 0
    
    local scriptTotal = ns.Logger.cache.script.hits + ns.Logger.cache.script.misses
    local scriptRate = scriptTotal > 0 
        and (ns.Logger.cache.script.hits / scriptTotal * 100) or 0
    
    self:AddLabelWithProgress(cacheGroup, "查询缓存", queryRate, 100, "%")
    self:AddLabelWithProgress(cacheGroup, "脚本缓存", scriptRate, 100, "%")
    
    container:AddChild(cacheGroup)
    
    -- 4. 内存使用
    local memGroup = AceGUI:Create("InlineGroup")
    memGroup:SetTitle("内存使用")
    memGroup:SetFullWidth(true)
    
    local memLabel = AceGUI:Create("Label")
    memLabel:SetText(string.format("%.2f MB", ns.Logger.realtime.memoryUsage))
    memLabel:SetFullWidth(true)
    
    memGroup:AddChild(memLabel)
    container:AddChild(memGroup)
end

--- 创建带进度条的标签
function DebugWindow:AddLabelWithProgress(container, label, value, maxValue, unit)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    group:SetFullWidth(true)
    
    local textLabel = AceGUI:Create("Label")
    textLabel:SetText(string.format("%s: %.2f %s", label, value, unit))
    textLabel:SetWidth(200)
    group:AddChild(textLabel)
    
    -- 进度条（用颜色编码的文本模拟）
    local pct = math.min(value / maxValue, 1.0)
    local barLength = 30
    local filled = math.floor(pct * barLength)
    local bar = string.rep("█", filled) .. string.rep("░", barLength - filled)
    
    -- 根据值设置颜色
    local color = "|cff00ff00"  -- 绿色
    if pct > 0.8 then
        color = "|cffff0000"  -- 红色
    elseif pct > 0.6 then
        color = "|cffffa500"  -- 橙色
    end
    
    local barLabel = AceGUI:Create("Label")
    barLabel:SetText(color .. bar .. "|r")
    barLabel:SetWidth(200)
    group:AddChild(barLabel)
    
    container:AddChild(group)
end
