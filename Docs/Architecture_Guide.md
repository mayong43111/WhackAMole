# WhackAMole 架构指南与开发手册

本文档旨在为开发人员提供关于 `WhackAMole` 内部架构的深入指导，明确设计原则、模块职责及核心工作流程。

## 1. 设计原则

本项目遵循以下核心原则，以确保插件在高性能要求下的可维护性：

*   **性能优先 (Performance First)**
    *   WoW 插件运行在主线程，任何微小的卡顿都会导致掉帧。
    *   **惰性求值 (Lazy Evaluation)**: 除非 APL 逻辑明确需要，否则绝不调用 WoW API（如 `UnitAura`、`GetSpellCooldown`）。这是通过 Lua 元表 (`metatable`) 实现的。
    *   **零 GC 压力**: 主循环 (`OnUpdate`) 中禁止创建临时的 Table。必须使用对象池 (`ObjectPool`) 或复用静态变量。
    *   **事件节流**: 战斗日志 (`COMBAT_LOG_EVENT_UNFILTERED`) 数据量巨大，必须进行节流和队列处理。

*   **关注点分离 (SoC) & 单一职责 (SRP)**
    *   `Engine` 层只负责决策，不知道 UI 的存在。
    *   `SimCParser` 只负责将字符串翻译为 Lua 函数，不负责执行。
    *   `Classes` 模块只提供数据（技能 ID、检测逻辑），不包含通用逻辑。

*   **配置驱动 (Configuration Driven)**
    *   所有的输出策略（Rotation）都必须定义在 Profile（配置文件）中。
    *   Lua 代码只提供“机制”（如何执行列表），而不包含“策略”（先打哪个技能）。

## 2. 系统架构

### 2.1 模块概览 (`src/`)

| 模块目录 | 职责 | 核心组件 |
| :--- | :--- | :--- |
| **src/Core** | **基础设施**。负责插件生命周期、事件分发、配置管理。 | `Lifecycle`, `EventHandler`, `ProfileManager`, `UpdateLoop` |
| **src/Engine** | **决策引擎**。负责状态快照、脚本解析、优先级执行。 | `State` (数据层), `SimCParser` (编译层), `APLExecutor` (执行层) |
| **src/Classes** | **领域数据**。职业特定的常量和检测逻辑。 | `SpecRegistry` (专精检测), 技能 ID 映射表 |
| **src/UI** | **表现层**。负责界面渲染和用户交互。 | `Grid` (网格显示), `Options` (设置面板) |

### 2.2 核心数据流

```mermaid
graph TD
    WoW_API -->|Lazy Fetch| State[Engine/State]
    Profile[Profile (Lua/DB)] -->|Load| ProfileManager
    ProfileManager -->|APL Strings| SimCParser[Engine/SimCParser]
    SimCParser -->|Compiled Predicates| APLExecutor[Engine/APLExecutor]
    
    UpdateLoop[Core/UpdateLoop] -->|Tick| APLExecutor
    State -->|Context| APLExecutor
    APLExecutor -->|Action Event| GridUI[UI/Grid]
```

## 3. 核心机制详解

### 3.1 状态管理 (`Engine/State`)

这是整个插件的性能核心。它不是一个存满数据的 Table，而是一个**代理 (Proxy)**。

*   **实现机制**:
    *   `state` 表初始为空。
    *   使用 `setmetatable(state, { __index = ... })` 拦截所有访问。
*   **工作流**:
    1.  APL 脚本访问 `state.rage`。
    2.  触发 `__index`。
    3.  代码调用 `UnitPower("player", 1)` 获取怒气值。
    4.  **缓存**: 将结果存入 `state` 表中。
    5.  **后续访问**: 同一帧内后续访问直接从 `state` 表读取，不再触发 `__index`（不再调用 WoW API）。
    6.  **重置**: 每帧结束调用 `State.Reset()` 清空缓存。

### 3.2 动态编译器 (`Engine/SimCParser`)

为了支持用户自定义逻辑且保持高性能，我们不解释执行，而是**编译执行**。

*   **流程**: `Raw String` $\to$ `Tokenizer` $\to$ `Lua Source Gen` $\to$ `loadstring` $\to$ `Function`
*   **示例**:
    *   **输入**: `rage > 80 & target.health_pct < 20`
    *   **生成的 Lua**: `return state.rage > 80 and state.target.health_pct < 20`
*   **缓存**: 
    *   解析器内部维护一个 `weak table` 缓存。
    *   如果两个 Profile 目前都使用 `rage > 80`，它们共享同一个编译好的 Lua 函数闭包。

## 4. 关键业务流程

### 4.1 初始化与专精切换 (Lifecycle)

1.  **事件**: `PLAYER_ENTERING_WORLD` 或 `PLAYER_SPECIALIZATION_CHANGED`。
2.  **检测**: 调用 `ns.SpecRegistry:Detect(playerClass)` 确定当前的 Spec ID (例如 72 - Fury Warrior)。
3.  **加载**: 
    *   `ProfileLoader` 寻找匹配的 Profile。
    *   生成 `ActionMap` (将技能别名映射到 SpellID)。
    *   调用 `SimCParser` **预编译** Profile 中所有的条件表达式。
    *   如果编译失败，降级为 `false` 并记录错误，不中断加载。

### 4.2 主循环 (The Loop)

由 `Core/UpdateLoop.lua` 驱动，目标 FPS 20-60 (取决于节流设置)。

1.  **节流 (Throttling)**: 检查 `timeSinceLastUpdate < Config.UPDATE_INTERVAL`。
2.  **清理 (Reset)**: 调用 `State.Reset()` 清除上一帧的状态缓存，确保获取最新快照。
3.  **当前决策 (Current Decision)**:
    *   调用 `APLExecutor.Process(apl, state)` 基于当前状态执行优先级列表。
    *   返回 `activeAction` (当前推荐动作)。
4.  **预测 (Forecast - Optional)**:
    *   如果开启预测功能，调用 `StateAdvance.Advance(state, activeAction)` 推进虚拟时间（模拟 GCD 转完、资源消耗等）。
    *   再次调用 `APLExecutor.Process` 基于推进后的**虚拟状态**获取 `nextAction`。
5.  **渲染 (Update UI)**:
    *   将 `activeAction` 和 `nextAction` 发送给 `UI` 层。
    *   UI 计算对应的 Grid 槽位并更新高亮动画。
6.  **音频 (Audio)**:
    *   根据动作变化触发语音播报（带去重/节流保护）。

## 5. 开发者指南

### 5.1 如何添加新职业/专精支持

1.  **创建文件**: 在 `src/Classes/` 下创建 `MyClass.lua`。
2.  **注册检测**:
    ```lua
    ns.SpecRegistry:Register("MYCLASS", function()
        if IsPlayerSpell(12345) then return 1 end -- Spec 1
        return nil
    end)
    ```
3.  **定义技能书**: 创建 `SpellMap`，包含 `key` (SimC 名称) 和 `id` (WoW Spell ID)。
4.  **创建预设**: 在 `src/Presets/` 下添加默认的 Lua 格式 Profile。

### 5.2 如何添加新的 SimC 语法支持

1.  **修改 Parser**: 在 `src/Engine/SimCParser.lua` 的 `Tokenize` 函数中添加新的操作符或关键字处理。
2.  **修改 State**: 
    *   如果涉及新属性（例如 `pet.health`），在 `src/Engine/State.lua` (或其子模块) 的元表中添加对应的 Getter。
    *   确保该 Getter 调用了正确的 API 并进行了错误处理。

### 5.3 调试与日志

*   **Logging**: 使用 `ns.Logger:Log(category, message)`。
*   **调试窗口**: 使用 `/wam debug` 打开 Debug 窗口。
    *   **Debug Logs Tab**: 查看实时运行日志、APL 决策过程和错误信息。
    *   **Performance Tab**: 查看各模块（APL、State、Parser）的 CPU 耗时统计、缓存命中率等性能指标。
*   **调试命令**:
    *   `/wam eval "condition_str"`: 测试条件表达式在当前状态下的值。
