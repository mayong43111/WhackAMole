# 06 - 调试与性能监控详细设计

## 模块概述

**核心文件**:
- `src/Core/Logger.lua` - 数据层：日志、性能、缓存统计
- `src/UI/DebugWindow.lua` - UI层：窗口管理和控制
- `src/UI/DebugTabs/LogTab.lua` - 日志页签
- `src/UI/DebugTabs/PerfTab.lua` - 性能监控页签（整合性能、缓存、实时监控）

调试系统采用模块化设计，Logger 负责数据采集和存储，DebugWindow 负责可视化展示。

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
│ [日志] [性能监控]                                           │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────── 日志页签 ───────────┐                       │
│  │ [复制所有日志]                  │                       │
│  │ [15:32:45] [APL] Condition...  │                       │
│  │ [15:32:46] [State] HP: 25k/30k │                       │
│  │ ...                             │                       │
│  └─────────────────────────────────┘                       │
│                                                              │
│  ┌──────── 性能监控页签 ──────────┐                       │
│  │  ┌─ 实时监控 ─────────────┐    │                       │
│  │  │ FPS: 58.3 | 平均: 2.1ms│    │                       │
│  │  │ 峰值: 8.5ms | 内存: 1.2MB│   │                       │
│  │  └─────────────────────────┘    │                       │
│  │  ┌─ 缓存统计 ─────────────┐    │                       │
│  │  │ 查询缓存: 80% (80/100)  │    │                       │
│  │  │ 脚本缓存: 90% (90/100)  │    │                       │
│  │  └─────────────────────────┘    │                       │
│  │  ┌─ 性能统计 ─────────────┐    │                       │
│  │  │ 总帧数: 1000            │    │                       │
│  │  │ 总耗时: 2000ms          │    │                       │
│  │  │ 模块平均: 2.0ms         │    │                       │
│  │  └─────────────────────────┘    │                       │
│  │  ┌─ 模块耗时分布 ─────────┐    │                       │
│  │  │ State 快照: 平均 0.5ms...│   │                       │
│  │  │ APL 执行: 平均 0.7ms...  │   │                       │
│  │  └─────────────────────────┘    │                       │
│  └─────────────────────────────────┘                       │
└────────────────────────────────────────────────────────────┘
Logger (数据层)
- 日志记录（系统日志、APL日志、性能日志）
- 性能统计（帧耗时、模块耗时）
- 缓存统计（命中率、查询数）
- 实时指标（FPS、内存使用）

### DebugWindow (UI层)
- 创建/显示/隐藏调试窗口
- 页签切换（日志/性能监控）
- 监控控制（启动/停止/重置）
- 定时刷新（每 2 秒自动更新UI）

### LogTab (日志页签)
- 日志滚动列表（支持分类过滤）
- 复制日志功能
- 颜色编码（错误/警告/系统等）

### PerfTab (性能监控页签)
- 实时监控（FPS、帧耗时、内存）
- 缓存统计（查询缓存、脚本缓存）
- 性能统计（总帧数、总耗时、平均耗时）
- 模块耗时分布（State、APL、预测、UI、音频g、系统日志）
- 性能统计（帧耗时、模块耗时）
- 缓存统计（命中率、查询数）
- 实时指标（FPS、内存使用）

### 4. 数据展示
- 日志滚动列表（支持过滤）
- 性能图表（折线图、饼图）
- 实时仪表盘（数字 + 进度条）

---

## 核Logger 数据结构（Core/Logger.lua）

```lua
Logger = {
    enabled = false,          -- 是否启用日志记录
    
    -- 日志数据
    logs = {
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
    },
    
    -- 性能数据
    performance = {
        frameTimes = {},      -- 最近 300 帧的耗时 [1.2, 2.3, 1.8, ...]
        modules = {           -- 模块统计
            state = { total = 0, max = 0, count = 0 },
            apl = { total = 0, max = 0, count = 0 },
            predict = { total = 0, max = 0, count = 0 },
            ui = { total = 0, max = 0, count = 0 },
            audio = { total = 0, max = 0, count = 0 }
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

### DebugWindow 状态（UI/DebugWindow.lua）

```lua
DebugWindow = {
    frame = nil,              -- AceGUI Frame 实例
    tabGroup = nil,           -- 页签容器
    isVisible = false,        -- 窗口是否可见
    currentTab = "log",       -- 当前页签 (log/perf)
    btnStart = nil,           -- 启动按钮引用
    btnStop = nil,            -- 停止按钮引用
    updateTimer = nil         -- 自动刷新定时器 (2秒)   memoryUsage = 0,      -- 内存使用 (MB)
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
    frame:SetTitl日志", value = "log"},
        {text = "性能监控", value = "perf
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
（委托给独立的Tab模块）
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
        container:AddChild(errorLabel
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

```lua启动监控")
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
    btnExport:SetText("t)
    
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

### 启动监not ns.Logger then return end
    if ns.Logger.enabled then return end
    
    ns.Logger.enabled = true
    
    -- 更新按钮状态
    if self.btnStart then
        self.btnStart:SetDisabled(true)
    end
    if self.btnStop then
        self.btnStop:SetDisabled(false)
    end
    
    -- 启动定时器（每 2 秒刷新UI）
    self:StartUpdateTimer()
    
    -- 记录启动日志
    ns.Logger:Log("System", "监控已启动")
    
    -- 生成一些初始测试数据
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

function DebugWindow:StopMonitoring()
    if not ns.Logger or not ns.Logger.enabled then return end
    
    ns.Logger.enabled = false
    
    -- 更新按钮状态
    if self.btnStart then
   性能监控页签（PerfTab）

### 页签布局

```lua
-- 文件: src/UI/DebugTabs/PerfTab.lua
function PerfTab:Createrue)
    end
    
    -- 停止定时器
    self:StopUpdateTimer()
    
    -- 记录日志
    ns.Logger:Log("System", "监控已停止")
end

function DebugWindow:ResetStats()
    ns.Logger:Clear()
    
    -- 刷新当前页签
    self:RefreshCurrentTab()
    
    ns.Logger:Log("System", "统计数据已重置")
end

--- 启动更新定时器
function DebugWindow:StartUpdateTimer()
    if self.updateTimer then return end
    
    -- 4. 模块耗时分布
    local moduleGroup = AceGUI:Create("InlineGroup")
    moduleGroup:SetTitle("模块耗时分布")
    moduleGroup:SetFullWidth(true)
    moduleGroup:SetLayout("Flow")
    
    local modules = ns.Logger.performance.modules
    local totalTime = ns.Logger.performance.totalTime
    
    if totalTime == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cff808080暂无数据，请启动监控后会自动采集性能数据|r")
        emptyLabel:SetFullWidth(true)
        moduleGroup:AddChild(emptyLabel)
    else
        local moduleNames = {
            {key = "state", name = "State 快照"},
            {key = "apl", name = "APL 执行"},
            {key = "predict", name = "预测计算"},
            {key = "ui", name = "UI 更新"},
            {key = "audio", name = "音频播放"}
        }
        
        for _, m in ipairs(moduleNames) do
            local data = modules[m.key]
            local avgTime = data.count > 0 and (data.total / data.count) or 0
            local pct = (data.total / totalTime) * 100
            
            local label = AceGUI:Create("Label")
            label:SetText(string.format("%s: 平均 %.2f ms | 峰值 %.2f ms | 占比 %.1f%%", 
                m.name, avgTime, data.max, pct))
            label:SetWidth(400)
            moduleGroup:AddChild(label)
        end
    end
    
    container:AddChild(moduleGroup)
end
```

**注**：移除了 ASCII 趋势图以简化UI，改用固定 Label 显示模块统计信息。 chartLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
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
## Logger API

### 日志记录

```lua
-- 添加日志
ns.Logger:Log(category, message)
-- 示例
ns.Logger:Log("APL", "Condition evaluated to false")
ns.Logger:Log("Error", "Failed to parse condition")
ns.Logger:Log("State", "Buff cache miss: hot_streak")
```

### 性能统计

```lua
-- 记录模块耗时
ns.Logger:RecordPerformance(moduleName, elapsedTime)
-- 示例
local startTime = debugprofilestop()
-- ... 执行代码 ...
local elapsed = debugprofilestop() - startTime
ns.Logger:RecordPerformance("state", elapsed)

-- 记录帧耗时
ns.Logger:RecordFrameTime(frameTime)
```

### 缓存统计

```lua
-- 更新缓存统计
ns.Logger:UpdateCacheStats(cacheType, hits, misses)
-- 示例
ns.Logger:UpdateCacheStats("query", 80, 20)
ns.Logger:UpdateCacheStats("script", 90, 10)
```

### 清空数据

```lua
-- 清空所有统计数据
ns.Logger:Clear()
```

---

##  
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
   -Logger.enabled = false（默认）
- 零开销（所有记录函数直接返回）

### Logger.enabled = true
- 数据采集: ~0.1-0.3ms/帧（记录性能数据）
- 日志记录: ~0.05ms/条（仅在需要时）
- 实时更新: ~0.1ms/2s（定时器开销）
- **总开销**: ~0.1-0.4ms/帧

### 窗口显示时
- 页签刷新: ~1-2ms（每 2 秒自动刷新）
- UI 渲染: ~1-3ms（取决于日志数量
## 日志记录功能

---

## 命令行集成

### Logger (Core/Logger.lua)
**依赖**: 无（纯数据层）

### DebugWindow (UI/DebugWindow.lua)
**依赖**:
- AceGUI-3.0 (窗口界面)
- C_Timer (定时器)
- Logger (数据层)
- LogTab、PerfTab (页签模块)

### LogTab (UI/DebugTabs/LogTab.lua)
**依赖**:
- AceGUI-3.0
- Logger

### PerfTab (UI/DebugTabs/PerfTab.lua)
**依赖**:
- AceGUI-3.0
- Logger

### 被依赖se
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
    "实时更新频率**
   - 当前 2 秒更新一次UI
   - 可根据需要调整刷新频率

2. **内存占用**
   - 300 帧耗时数据 (~2.4KB)
   - 1000 行日志 (~100-200KB)
   - 总计约 ~200-300KB（可接受）

3. **窗口响应**
   - 大量日志时（>1000 行）滚动可能卡顿
   - 建议定期使用"重置统计"按钮

4. **测试数据**
   - 当前使用模拟数据生成测试
   - 未来需集成真实的性能采集约占用 100-200KB
   - 长时间开启可能累积较多内存

3. **事件过滤**
   - 当前仅记录 SPELL_CAST_SUCCESS
   - 其他事件类型需手动添加

4. **GUI 性能**
   - 日志内容过多时（>5000 行）窗口可能卡顿
   - 建议定期使用重置按钮清空统计数据

---

## 依赖关系

###命令行集成

### /wam debug 命令

```lua
function WhackAMole:OnChatCommand(input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "debug" then
        -- 直接显示调试窗口，所有控制在窗口内完成
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        end
        
    else
        -- 帮助信息
        self:Print("WhackAMole 命令:")
        self:Print("  /wam debug    - 打开调试窗口")
        self:Print("  /wam lock     - 锁定/解锁网格")
        self:Print("  /wam state    - 显示状态快照")
    end
end数据分离**
   - Logger 为纯数据层，无UI依赖
   - DebugWindow 为纯UI层，无业务逻辑
   - 模块化设计便于维护和测试

2. **自动刷新**
   - 监控启动后每 2 秒自动刷新UI
   - 停止监控后停止刷新以节省资源

3. **清洁输出**
   - 移除了所有调试 print 语句
   - 错误信息直接显示在UI中

4. **简化展示**
   - 移除了 ASCII 趋势图
   - 使用固定 Label 显示模块统计
   - 合并了实时监控、缓存、性能到一个页签