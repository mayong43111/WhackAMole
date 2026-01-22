# 06 - 调试与性能监控详细设计

## 模块概述

**文件**: `src/Core/DebugWindow.lua`

调试窗口（DebugWindow）提供统一的可视化界面，集成日志记录、性能分析、实时监控和图表展示功能。

---

## 设计目标

1. **默认关闭**：监控默认关闭，按需通过 GUI 启用，避免性能开销
2. **GUI 控制**：通过窗口内按钮控制启动/停止/重置，减少命令依赖
3. **可视化分析**：提供实时性能图表和关键指标仪表盘
4. **多页签设计**：日志、性能、缓存统计分离到不同标签页

---

## 核心架构

### 窗口结构

```
┌─────────────────── WhackAMole 调试窗口 ────────────────────┐
│ [启动监控] [停止监控] [重置统计] [导出日志]    ○ ╳       │
├────────────────────────────────────────────────────────────┤
│ [日志] [性能分析] [缓存统计] [实时监控]                    │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────── 日志页签 ───────────┐                       │
│  │ [15:32:45] [APL] Condition...  │                       │
│  │ [15:32:46] [State] HP: 25k/30k │                       │
│  │ ...                             │                       │
│  └─────────────────────────────────┘                       │
│                                                              │
│  ┌──────── 性能分析页签 ──────────┐                       │
│  │  帧耗时趋势 (最近 60s)          │                       │
│  │  ████████▁▁▁███▁▁▁▁▁▁          │                       │
│  │                                 │                       │
│  │  模块占比饼图                   │                       │
│  │   ● State 16% ● APL 32%        │                       │
│  └─────────────────────────────────┘                       │
│                                                              │
│  ┌─────── 实时监控页签 ────────┐                          │
│  │  当前帧率: 58.3 FPS           │                          │
│  │  平均帧耗时: 2.13 ms          │                          │
│  │  峰值帧耗时: 8.45 ms          │                          │
│  │  缓存命中率: 80.1%            │                          │
│  └───────────────────────────────┘                          │
└────────────────────────────────────────────────────────────┘
```

---

## 职责划分

### 1. 窗口管理
- 创建/显示/隐藏调试窗口
- 页签切换（日志/性能/缓存/实时）
- 窗口尺寸记忆

### 2. 监控控制
- 启动监控（注册事件、开始采集）
- 停止监控（取消事件、停止采集）
- 重置统计（清空数据、重置计数器）

### 3. 数据采集
- 日志记录（Combat Log、系统日志）
- 性能统计（帧耗时、模块耗时）
- 缓存统计（命中率、查询数）
- 实时指标（FPS、内存使用）

### 4. 数据展示
- 日志滚动列表（支持过滤）
- 性能图表（折线图、饼图）
- 实时仪表盘（数字 + 进度条）

---

## 核心数据结构

### 监控状态

```lua
DebugWindow = {
    -- 窗口状态
    frame = nil,              -- AceGUI Frame 实例
    isMonitoring = false,     -- 是否正在监控
    isVisible = false,        -- 窗口是否可见
    currentTab = "log",       -- 当前页签 (log/perf/cache/realtime)
    
    -- 日志数据
    logs = {
        lines = {},           -- 日志行数组 [{timestamp, category, message}]
        maxLines = 1000,      -- 最大行数
        filters = {}          -- 过滤器 {Combat=true, State=false, ...}
    },
    
    -- 性能数据
    performance = {
        frameTimes = {},      -- 最近 300 帧的耗时 [1.2, 2.3, 1.8, ...]
        modules = {           -- 模块统计
            state = { total = 0, max = 0, samples = {} },
            apl = { total = 0, max = 0, samples = {} },
            predict = { total = 0, max = 0, samples = {} },
            ui = { total = 0, max = 0, samples = {} },
            audio = { total = 0, max = 0, samples = {} }
        },
        frameCount = 0,
        totalTime = 0
    },
    
    -- 缓存统计
    cache = {
        query = { hits = 0, misses = 0 },
        script = { hits = 0, misses = 0 }
    },
    
    -- 实时指标
    realtime = {
        fps = 0,              -- 当前帧率
        avgFrameTime = 0,     -- 平均帧耗时
        peakFrameTime = 0,    -- 峰值帧耗时
        memoryUsage = 0,      -- 内存使用 (MB)
        lastUpdate = 0        -- 上次更新时间
    }
}
```

### 日志行格式

```lua
{
    timestamp = "15:32:45.123",
    category = "APL",  -- Combat/State/APL/Error/Warn
    message = "Condition evaluated: buff.hot_streak.up -> true"
}
```

---

## 窗口界面设计

### 主窗口创建

```lua
function DebugWindow:Show()
    if self.isVisible and self.frame then
        return  -- 已显示，不重复创建
    end
    
    local AceGUI = LibStub("AceGUI-3.0")
    
    -- 1. 创建主窗口
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
    
    -- 2. 创建控制按钮组
    self:CreateControlButtons(frame)
    
    -- 3. 创建页签容器
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

function DebugWindow:Hide()
    if self.frame then
        AceGUI:Release(self.frame)
        self.frame = nil
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
```

### 控制按钮组

```lua
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
```

---

## 启动/停止监控

### 启动监控

```lua
function DebugWindow:StartMonitoring()
    if self.isMonitoring then return end
    
    self.isMonitoring = true
    
    -- 1. 注册事件
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- 2. 启动定时器（实时数据更新）
    self:ScheduleRepeatingTimer("UpdateRealtime", 0.5)
    
    -- 3. 更新按钮状态
    self.btnStart:SetDisabled(true)
    self.btnStop:SetDisabled(false)
    
    -- 4. 记录日志
    self:Log("System", "监控已启动")
    
    print("|cff00ff00WhackAMole: 监控已启动|r")
end

function DebugWindow:StopMonitoring()
    if not self.isMonitoring then return end
    
    self.isMonitoring = false
    
    -- 1. 取消事件
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- 2. 停止定时器
    self:CancelAllTimers()
    
    -- 3. 更新按钮状态
    self.btnStart:SetDisabled(false)
    self.btnStop:SetDisabled(true)
    
    -- 4. 记录日志
    self:Log("System", "监控已停止")
    
    print("|cffff0000WhackAMole: 监控已停止|r")
end

function DebugWindow:ResetStats()
    -- 页签

### 页签布局

```lua
function DebugWindow:CreatePerfTab(container)
    container:ReleaseChildren()
    
    -- 1. 关键指标摘要
    local summaryGroup = AceGUI:Create("InlineGroup")
    summaryGroup:SetTitle("关键指标")
    summaryGroup:SetFullWidth(true)
    summaryGroup:SetLayout("Flow")
    
    local stats = self.performance
    local avgTime = stats.frameCount > 0 and (stats.totalTime / stats.frameCount) or 0
    
    self:AddLabel(summaryGroup, string.format("总帧数: %d", stats.frameCount))
    self:AddLabel(summaryGroup, string.format("平均耗时: %.2f ms", avgTime))
    self:AddLabel(summaryGroup, string.format("峰值耗时: %.2f ms", 
        self.realtime.peakFrameTime))
    self:AddLabel(summaryGroup, string.format("当前 FPS: %.1f", self.realtime.fps))
    
    container:AddChild(summaryGroup)
    
    -- 2. 帧耗时趋势图（ASCII 艺术图或简化条形图）
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
    
    -- 3. 模块耗时分布（表格形式）
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
    local times = self.performance.frameTimes
    if #times == 0 then
        return "暂无数据"
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
        local line = string.format("%5.1f ms │", threshold)
        
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
    local xAxis = "       └" .. string.rep("─", #times) .. "─"
    table.insert(lines, xAxis)
    table.insert(lines, string.format("        0%50s帧300", ""))
    
    return table.concat(lines, "\n")
end

--- 生成模块统计表格
function DebugWindow:GenerateModuleStats()
    local modules = self.performance.modules
    local totalTime = self.performance.totalTime
    
    if totalTime == 0 then
        return "暂无数据"
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
        local avgTime = self.performance.frameCount > 0 
            and (data.total / self.performance.frameCount) or 0
        local pct = (data.total / totalTime) * 100
        
        table.insert(lines, string.format(
            "%s  %.2f ms   %.2f ms   %.1f%%",
            m.name, avgTime, data.max, pct
        ))
    end
    
    return table.concat(lines, "\n")
end
```

---

## 实时监控页签

### 实时指标仪表盘

```lua
function DebugWindow:CreateRealtimeTab(container)
    container:ReleaseChildren()
    
    -- 1. FPS 指示器
    local fpsGroup = AceGUI:Create("InlineGroup")
    fpsGroup:SetTitle("帧率 (FPS)")
    fpsGroup:SetFullWidth(true)
    
    local fpsLabel = AceGUI:Create("Label")
    fpsLabel:SetText(string.format("|cff00ff00%.1f FPS|r", self.realtime.fps))
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
        self.realtime.avgFrameTime, 5.0, "ms")
    self:AddLabelWithProgress(frameTimeGroup, "峰值", 
        self.realtime.peakFrameTime, 10.0, "ms")
    
    container:AddChild(frameTimeGroup)
    
    -- 3. 缓存命中率
    local cacheGroup = AceGUI:Create("InlineGroup")
    cacheGroup:SetTitle("缓存效率")
    cacheGroup:SetFullWidth(true)
    cacheGroup:SetLayout("Flow")
    
    local queryTotal = self.cache.query.hits + self.cache.query.misses
    local queryRate = queryTotal > 0 
        and (self.cache.query.hits / queryTotal * 100) or 0
    
    local scriptTotal = self.cache.script.hits + self.cache.script.misses
    local scriptRate = scriptTotal > 0 
        and (self.cache.script.hits / scriptTotal * 100) or 0
    
    self:AddLabelWithProgress(cacheGroup, "查询缓存", queryRate, 100, "%")
    self:AddLabelWithProgress(cacheGroup, "脚本缓存", scriptRate, 100, "%")
    
    container:AddChild(cacheGroup)
    
    -- 4. 内存使用
    local memGroup = AceGUI:Create("InlineGroup")
    memGroup:SetTitle("内存使用")
    memGroup:SetFullWidth(true)
    
    local memLabel = AceGUI:Create("Label")
    memLabel:SetText(string.format("%.2f MB", self.realtime.memoryUsage))
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

--- 定时更新实时数据
function DebugWindow:UpdateRealtime()
    if not self.isMonitoring then return end
    
    -- 1. 计算 FPS（基于最近 10 帧）
    local recentFrames = {}
    for i = math.max(1, #self.performance.frameTimes - 9), 
            #self.performance.frameTimes do
        table.insert(recentFrames, self.performance.frameTimes[i])
    end
    
    if #recentFrames > 0 then
        local avgFrameTime = 0
        for _, t in ipairs(recentFrames) do
            avgFrameTime = avgFrameTime + t
        end
        avgFrameTime = avgFrameTime / #recentFrames
        
        self.realtime.fps = 1000.0 / avgFrameTime  -- ms -> FPS
        self.realtime.avgFrameTime = avgFrameTime
    end
    
    -- 2. 获取内存使用
    UpdateAddOnMemoryUsage()
    self.realtime.memoryUsage = GetAddOnMemoryUsage("WhackAMole") / 1024  -- KB -> MB
    
    -- 3. 获取峰值帧耗时
   性能开销

### 监控关闭时
- 零开销（无事件注册、无数据采集）

### 监控开启时
- 数据采集: ~0.3ms/帧（记录性能数据）
- COMBAT_LOG 事件: ~0.2-1.0ms/帧（取决于战斗强度）
- 实时更新: ~0.1ms/0.5s（定时器开销）
- **总开销**: ~0.5-1.5ms/帧

### 窗口显示时
- 页签刷新: ~1-2ms（手动触发或定时）
- 图表生成: ~2-5ms（仅在性能页签切换时）
- **建议**: 非必要时隐藏窗口以降低开销

---

## 依赖关系

### 依赖的库
- AceEvent-3.0 (事件监听)
- AceGUI-3.0 (窗口界面)
- AceTimer-3.0 (定时器)

### 依赖的模块
- State (查询缓存统计)
- SimCParser (脚本缓存统计)
- Core (性能数据采集)

### 被依赖的模块
- Core (命令行调用 `/wam debug`)

---

## 已知限制

1. **图表精度**
   - ASCII 图表精度有限，仅适合趋势观察
   - 建议: 未来可考虑集成 LibGraph-2.0 绘制精确图表

2. **实时更新频率**
   - 当前 0.5 秒更新一次实时数据
   - 高频更新会增加 CPU 开销

3. **内存占用**
   - 300 帧耗时数据 (~2.4KB)
   - 1000 行日志 (~100-200KB)
   - 总计约 ~300KB（可接受）

4. **窗口响应**
   - 大量日志时（>5000 行）滚动可能卡顿
   - 建议定期重置统计

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [状态快照系统](07_State.md)
- [SimC 解析器](08_SimCParser.md)
- [架构图与流程图](00_Architecture_Diagrams.md)

---

## 日志记录功能

---

## 命令行集成

### /wam debug 命令

```lua
function WhackAMole:OnChatCommand(input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "debug" then
        -- 直接显示调试窗口，所有控制在窗口内完成
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        else
            self:Print("调试窗口未初始化")
        end
        
    else
        -- 帮助信息
        self:Print("WhackAMole 命令:")
        self:Print("  /wam debug    - 打开调试窗口")
        self:Print("  /wam lock     - 锁定/解锁网格")
        self:Print("  /wam state    - 显示状态快照")
    end
end
```

---

## 调试辅助函数

在 DebugWindow 中集成了日志记录功能：

```lua
-- 添加日志行
function DebugWindow:Log(category, message)
    if not self.isMonitoring then return end
    
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
    
    -- 刷新日志页签（如果当前显示）
    if self.currentTab == "log" then
        self:RefreshCurrentTab()
    end
end

-- 使用示例
ns.DebugWindow:Log("APL", "Condition evaluated to false")
ns.DebugWindow:Log("Error", "Failed to parse: " .. conditionStr)
ns.DebugWindow:Log("State", "Buff cache miss: hot_streak")
```

---

## 调试最佳实践

### 排查性能问题

```lua
-- 在关键路径添加计时
local startTime = debugprofilestop()

-- ... 执行代码 ...

local elapsed = debugprofilestop() - startTime
ns.DebugWindow:Log("Performance", string.format("Operation took %.2f ms", elapsed))
```

### 排查 APL 错误

```lua
-- 记录条件评估
ns.DebugWindow:Log("APL", string.format(
    "Condition: %s -> %s",
    conditionStr,
    result and "true" or "false"
))

-- 记录动作选择
ns.DebugWindow:Log("APL", string.format(
    "Action selected: %s (index %d)",
    actionName,
    actionIndex
))
```

### 排查状态快照问题

```lua
-- 记录关键状态
ns.DebugWindow:Log("State", string.format(
    "HP: %d/%d (%.1f%%), Mana: %d/%d (%.1f%%)",
    currentHP, maxHP, hpPct,
    currentMana, maxMana, manaPct
))

-- 记录 Buff 查询
ns.DebugWindow:Log("State", string.format(
    "Buff check: %s -> %s",
    buffName,
    found and "UP" or "DOWN"
))
```

---

## 已知限制

1. **性能开销**
   - 启用监控后每帧约增加 0.5-1ms 开销
   - COMBAT_LOG 事件密集时开销更高

2. **内存占用**
   - 1000 行日志约占用 100-200KB
   - 长时间开启可能累积较多内存

3. **事件过滤**
   - 当前仅记录 SPELL_CAST_SUCCESS
   - 其他事件类型需手动添加

4. **GUI 性能**
   - 日志内容过多时（>5000 行）窗口可能卡顿
   - 建议定期使用重置按钮清空统计数据

---

## 依赖关系

### 依赖的库
- AceEvent-3.0 (事件监听)
- AceGUI-3.0 (窗口界面)
- AceTimer-3.0 (定时器)

### 被依赖的模块
- Core (命令行调用 `/wam debug`)
- 所有模块 (可选使用 DebugWindow 记录调试信息)

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [状态快照系统](07_State.md)
- [SimC 解析器](08_SimCParser.md)
