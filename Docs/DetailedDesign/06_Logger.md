# 06 - 调试与性能监控详细设计

## 模块概述

**核心文件**:
- `src/Core/Logger.lua` - 数据层：日志、性能、缓存统计
- `src/UI/DebugWindow.lua` - UI层：窗口管理和控制
- `src/UI/DebugTabs/LogTab.lua` - 日志页签
- `src/UI/DebugTabs/PerfTab.lua` - 性能监控页签

调试系统采用**数据层/UI层分离**的模块化设计，Logger 负责数据采集和存储，DebugWindow 负责可视化展示。

---

## 设计目标

1. **默认关闭**：监控默认关闭，按需通过 GUI 启用，避免性能开销
2. **GUI 控制**：通过窗口内按钮控制启动/停止/重置
3. **零资源占用**：窗口关闭时完全停止监控，不消耗任何资源
4. **高效刷新**：采用控件复用策略，避免内存泄漏
5. **轻量界面**：紧凑的窗口设计，支持拖动和调整大小

---

## 核心架构

### 窗口结构 (700x500, 可拖动/调整)

```
┌─────── WhackAMole 调试窗口 ───────┐
│ [启动] [停止] [重置] [导出]  ○ ╳ │
├───────────────────────────────────┤
│ [日志] [性能监控]                 │
├───────────────────────────────────┤
│                                   │
│  ┌────── 日志 (最近200条) ──────┐│
│  │ 日志 (1000 条, 最多显示最近   ││
│  │        200 条)                ││
│  │                               ││
│  │ [15:32:45] [APL] Condition.. ││
│  │ [15:32:46] [State] HP: 25k.. ││
│  │ [15:32:47] [System] 监控启动 ││
│  │                               ││
│  │ (单个 MultiLineEditBox)       ││
│  └───────────────────────────────┘│
│                                   │
│  ┌────── 性能监控 ──────┐        │
│  │ 实时监控:              │        │
│  │  FPS: 58.3 | 平均: 2.1ms│      │
│  │  峰值: 8.5ms | 内存: 1.2MB│    │
│  │                         │        │
│  │ 缓存统计:              │        │
│  │  查询: 80% (80/100)    │        │
│  │  脚本: 90% (90/100)    │        │
│  │                         │        │
│  │ 模块耗时分布:          │        │
│  │  State: 0.5ms (25%)    │        │
│  │  APL: 0.7ms (35%)      │        │
│  └─────────────────────────┘        │
└───────────────────────────────────┘
```

### 架构分层

**Logger (数据层)**
- 日志记录（分类、时间戳、消息）
- 性能统计（帧耗时、模块耗时分布）
- 缓存统计（命中率、查询计数）
- 实时指标（FPS、内存使用）

**DebugWindow (UI层)**
- 窗口生命周期管理（Show/Hide）
- 监控控制（Start/Stop/Reset）
- 页签切换和内容渲染
- 定时刷新（仅性能页签）

**LogTab (日志页签)**
- 使用单个 MultiLineEditBox 显示日志
- 限制显示最近 200 条（避免性能问题）
- 颜色编码（通过 WoW 颜色代码）
- **不自动刷新**（避免卡顿）

**PerfTab (性能监控页签)**
- **控件复用**：首次创建控件，后续只更新内容
- 实时监控、缓存统计、模块分布
- **每 2 秒自动刷新**（仅更新文本，不重建控件）

---

## 核心数据结构

### Logger (数据层)

```
Logger = {
    enabled = false                    -- 监控开关（默认关闭）
    
    logs = {
        lines = []                     -- 日志数组 (最多1000条)
        maxLines = 1000
    }
    
    performance = {
        frameTimes = []                -- 最近300帧耗时
        modules = {                    -- 各模块统计
            state:   {total, max, count}
            apl:     {total, max, count}
            predict: {total, max, count}
            ui:      {total, max, count}
            audio:   {total, max, count}
        }
        frameCount, totalTime
    }
    
    cache = {
        query:  {hits, misses}         -- 查询缓存统计
        script: {hits, misses}         -- 脚本缓存统计
    }
    
    realtime = {
        fps, avgFrameTime, peakFrameTime, memoryUsage
    }
}
```

### DebugWindow (UI层)

```
DebugWindow = {
    frame = nil                        -- AceGUI窗口实例
    tabGroup = nil                     -- 页签容器
    isVisible = false                  -- 窗口是否显示
    currentTab = "log"                 -- 当前页签
    updateTimer = nil                  -- 定时器句柄 (2秒)
    perfTabWidgets = nil               -- 性能页签控件引用（复用）
}
```

### 日志条目格式

```
{
    timestamp: "15:32:45"
    category: "APL" | "State" | "System" | "Error" | ...
    message: "具体日志消息"
}
```

---

## 核心功能实现

### 窗口生命周期

**Show() - 显示窗口**
```
if isVisible then return end

frame = CreateAceGUIFrame()
frame.size = {700, 500}
frame.enableResize = true
frame.onClose = Hide()

CreateControlButtons()
CreateTabGroup(["日志", "性能监控"])

isVisible = true
```

**Hide() - 隐藏窗口 (关键：完全释放资源)**
```
if not frame then return end

// 关键：停止所有资源消耗
Logger.enabled = false              // 停止数据采集
StopUpdateTimer()                   // 取消定时器

// 释放UI资源
ReleaseAllWidgets()
frame = nil
perfTabWidgets = nil                // 清空控件引用

isVisible = false
```

### 控制按钮

**启动监控**
```
Logger.enabled = true
StartUpdateTimer(2 seconds)
GenerateInitialTestData()
RefreshCurrentTab()
```

**停止监控**
```
Logger.enabled = false
StopUpdateTimer()
```

**重置统计**
```
Logger.Clear()
RefreshCurrentTab()
```

**导出日志**
```
CreateExportWindow()
DisplayAllLogsInEditBox()
```
### 页签设计

#### 日志页签 (LogTab)

**性能优化策略**：
- 使用单个 `MultiLineEditBox` 替代数百个 Label 控件
- 限制显示最近 200 条日志（避免 UI 卡顿）
- 不自动刷新（只在用户切换到日志页签时更新）
- 通过 WoW 颜色代码实现分类着色

**伪代码**：
```
function LogTab:Create(container)
    editBox = CreateMultiLineEditBox()
    editBox.label = "日志 (总数: X, 显示最近200条)"
    
    // 只取最近200条
    displayLimit = 200
    startIdx = max(1, totalLogs - 199)
    
    lines = []
    for i = totalLogs to startIdx do
        log = Logger.logs[i]
        color = GetColorByCategory(log.category)
        lines.append(color + "[" + log.timestamp + "] [" + log.category + "] " + log.message)
    end
    
    editBox.text = join(lines, "\n")
    container.addChild(editBox)
end
```

#### 性能监控页签 (PerfTab)

**性能优化策略**：
- **控件复用**：首次创建所有控件，保存引用
- **只更新内容**：后续刷新只调用 `SetText()`，不重新创建控件
- 每 2 秒自动刷新（仅限性能页签可见时）

**伪代码**：
```
function PerfTab:Create(container)
    widgets = {}  // 保存所有控件引用
    
    // 创建所有控件（一次性）
    widgets.fpsLabel = CreateLabel()
    widgets.avgFrameLabel = CreateLabel()
    widgets.peakLabel = CreateLabel()
    widgets.memLabel = CreateLabel()
    widgets.cache1 = CreateLabel()
    widgets.cache2 = CreateLabel()
    widgets.summary1/2/3 = CreateLabel()
    widgets.moduleLabels[] = CreateLabels(5)
    
    // 初始更新内容
    Update(widgets)
    
    return widgets  // 返回引用供后续复用
end

function PerfTab:Update(widgets)
    // 只更新文本，不重建控件
    widgets.fpsLabel.text = "FPS: " + realtime.fps
    widgets.avgFrameLabel.text = "平均: " + realtime.avgFrameTime
    widgets.memLabel.text = "内存: " + realtime.memoryUsage
    
    widgets.cache1.text = "查询缓存: " + cacheHitRate
    widgets.cache2.text = "脚本缓存: " + scriptHitRate
    
    for each module in moduleLabels do
        module.text = "模块名: 平均 X ms | 峰值 Y ms | 占比 Z%"
    end
end
```

### 定时刷新机制

**关键优化**：只刷新性能页签，不刷新日志页签

```
function StartUpdateTimer()
    updateTimer = NewTicker(2.0 seconds, function()
        UpdateRealtime()
    end)
end

function UpdateRealtime()
    // 关键检查：窗口不可见或监控未启用，直接返回
    if not isVisible or not Logger.enabled then
        return
    end
    
    // 模拟采集性能数据
    frameTime = GenerateRandomFrameTime()
    Logger.RecordFrameTime(frameTime)
    Logger.RecordPerformance("state", frameTime * 0.25)
    Logger.RecordPerformance("apl", frameTime * 0.35)
    ...
    
    // 计算实时指标
    realtime.fps = CalculateFPS()
    realtime.memoryUsage = GetAddOnMemoryUsage()
    
    // 关键：只刷新性能页签
    if currentTab == "perf" then
        if perfTabWidgets exists then
            PerfTab:Update(perfTabWidgets)  // 只更新内容
        else
            RefreshCurrentTab()              // 首次创建
        end
    end
end

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
## 性能开销分析

### 窗口关闭时（Hide状态）
- **零开销** ✅
  - Logger.enabled = false（数据采集停止）
  - 定时器已取消（无后台任务）
  - 所有控件已释放（无内存占用）

### 窗口打开但监控未启动
- **接近零开销**
  - Logger.enabled = false（不记录数据）
  - 定时器未运行（无定期刷新）
  - 仅窗口UI占用少量内存（~100KB）

### 监控启动时
- **数据采集**: ~0.1-0.3ms/帧
  - 记录帧耗时、模块统计
  - 日志写入（按需）
- **定时器**: ~0.1ms/2秒
  - 模拟性能数据生成
  - 计算 FPS、内存使用
- **总开销**: ~0.1-0.4ms/帧

### UI刷新开销
- **日志页签**: 
  - 切换时重建（~2-5ms）
  - 不自动刷新（避免卡顿）
- **性能页签**: 
  - 首次创建控件（~5-10ms）
  - 后续只更新文本（~0.5-1ms/2秒）
  - 控件复用避免内存泄漏

### 优化策略总结
1. **关闭即停止**：Hide()自动停止监控和定时器
2. **控件复用**：性能页签不重复创建控件
3. **选择性刷新**：只刷新当前可见的性能页签
4. **限制数据量**：日志最多1000条，显示最近200条
5. **按需记录**：Logger.enabled控制所有数据采集e(moduleName, elapsedTime)
  - moduleName: "state" | "apl" | "predict" | "ui" | "audio"
  - elapsedTime: 耗时（毫秒）
  
使用模式：
  startTime = debugprofilestop()
  ... 执行代码 ...
  elapsed = debugprofilestop() - startTime
  Logger:RecordPerformance("state", elapsed)

Logger:RecordFrameTime(frameTime)
  - 记录单帧总耗时
## 依赖关系

### Logger 依赖
- **无依赖**（纯数据层，独立模块）

### DebugWindow 依赖
- **AceGUI-3.0**：窗口和控件系统
- **C_Timer**：定时器（2秒刷新）
- **Logger**：数据源
- **LogTab、PerfTab**：页签模块

### 被依赖
- **Core**：`/wam debug` 命令调用 `DebugWindow:Show()`

```
Logger:Clear()
  - 清空所有日志和统计数据
## 已知限制

1. **显示限制**
   - 日志最多显示最近 200 条（性能考虑）
   - 总计保留 1000 条历史日志
   - 需要更多日志时使用"导出"功能

2. **刷新频率**
   - 性能页签每 2 秒更新一次
   - 日志页签不自动刷新（避免卡顿）
   - 可根据需要手动切换页签刷新

3. **内存占用**
   - 300 帧耗时数据 (~2.4KB)
   - 1000 行日志 (~100-200KB)
   - 窗口UI控件 (~100KB)
   - 总计约 ~200-300KB（可接受）

4. **测试数据**
   - 当前使用模拟数据（随机帧耗时）
   - 生产环境需集成真实性能采集

---

## 命令行集成

```
/wam debug
  → 调用 DebugWindow:Show()
  → 显示调试窗口
  → 所有控制通过窗口内按钮完成
```

---

## 设计亮点

1. **完全的资源释放**
   - Hide() 自动停止监控和定时器
   - 窗口关闭时零资源占用
   - 避免后台任务持续运行

2. **控件复用策略**
   - 性能页签首次创建控件，保存引用
   - 后续刷新只更新文本内容
   - 避免频繁创建/销毁导致的内存泄漏

3. **选择性刷新**
   - 只刷新当前可见的性能页签
   - 日志页签不自动刷新
   - 降低 CPU 和内存开销

4. **数据层/UI层分离**
   - Logger 纯数据，无UI依赖
   - DebugWindow 纯UI，无业务逻辑
   - 模块化设计便于维护和测试

5. **轻量高效**
   - 窗口尺寸紧凑（700x500）
   - 支持拖动和调整大小
   - MultiLineEditBox 替代数百个 Label