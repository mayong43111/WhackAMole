# WhackAMole 架构图与流程图

本文档包含 WhackAMole 系统的各类架构图和流程图，帮助理解系统整体结构和运行机制。

---

## 1. 系统分层架构

```mermaid
graph TB
    subgraph "表现层 (Presentation Layer)"
        Grid[Grid UI<br/>网格界面]
        Options[Options UI<br/>配置界面]
    end
    
    subgraph "引擎层 (Engine Layer)"
        State[State<br/>状态快照]
        Parser[SimCParser<br/>SimC解析器]
        Executor[APLExecutor<br/>APL执行器]
    end
    
    subgraph "核心层 (Core Layer)"
        Core[Core<br/>生命周期管理]
        ProfileMgr[ProfileManager<br/>配置管理]
        SpecDetect[SpecDetection<br/>专精检测]
        Audio[Audio<br/>音频系统]
        Logger[Logger<br/>日志系统]
        Serializer[Serializer<br/>序列化]
    end
    
    subgraph "数据层 (Data Layer)"
        ActionMap[ActionMap<br/>动作映射]
        ClassModules[Class Modules<br/>职业模块]
    end
    
    subgraph "扩展层 (Extension Layer)"
        Hooks[Hooks<br/>钩子系统]
    end
    
    %% 表现层依赖
    Grid --> Core
    Grid --> State
    Grid --> ActionMap
    Options --> ProfileMgr
    Options --> Serializer
    
    %% 引擎层依赖
    State --> ActionMap
    State --> Hooks
    Parser --> ActionMap
    Executor --> State
    Executor --> Parser
    
    %% 核心层依赖
    Core --> ProfileMgr
    Core --> SpecDetect
    Core --> State
    Core --> Executor
    Core --> Audio
    Core --> Logger
    Core --> Hooks
    ProfileMgr --> Serializer
    Audio --> ActionMap
    
    %% 数据层
    ClassModules --> ActionMap
    
    %% 扩展层被多个模块使用
    Hooks -.-> ClassModules
    
    style Grid fill:#e1f5ff
    style Options fill:#e1f5ff
    style State fill:#fff4e1
    style Parser fill:#fff4e1
    style Executor fill:#fff4e1
    style Core fill:#e8f5e9
    style ProfileMgr fill:#e8f5e9
    style SpecDetect fill:#e8f5e9
    style Audio fill:#e8f5e9
    style Logger fill:#e8f5e9
    style Serializer fill:#e8f5e9
    style ActionMap fill:#f3e5f5
    style ClassModules fill:#f3e5f5
    style Hooks fill:#ffe0b2
```

---

## 2. 模块依赖关系图

```mermaid
graph LR
    %% 核心模块
    Core[Core<br/>01]
    ProfileMgr[ProfileManager<br/>02]
    SpecDetect[SpecDetection<br/>03]
    Serializer[Serializer<br/>04]
    Audio[Audio<br/>05]
    Logger[Logger<br/>06]
    
    %% 引擎模块
    State[State<br/>07]
    Parser[SimCParser<br/>08]
    Executor[APLExecutor<br/>09]
    
    %% 表现模块
    Grid[Grid UI<br/>10]
    Options[Options UI<br/>11]
    
    %% 数据模块
    ClassModules[Class Modules<br/>12]
    ActionMap[ActionMap<br/>13]
    
    %% 扩展模块
    Hooks[Hooks<br/>14]
    
    %% 依赖关系
    Core --> ProfileMgr
    Core --> SpecDetect
    Core --> State
    Core --> Executor
    Core --> Audio
    Core --> Hooks
    
    ProfileMgr --> Serializer
    ProfileMgr --> ClassModules
    
    SpecDetect --> ProfileMgr
    
    State --> ActionMap
    State --> Hooks
    
    Parser --> ActionMap
    
    Executor --> State
    Executor --> Parser
    
    Grid --> Core
    Grid --> State
    Grid --> ActionMap
    
    Options --> ProfileMgr
    Options --> Serializer
    
    Audio --> ActionMap
    
    ClassModules --> ActionMap
    
    Hooks -.虚线表示被依赖.-> ClassModules
    Hooks -.-> Core
    
    style Core fill:#4caf50,color:#fff
    style State fill:#ff9800,color:#fff
    style Parser fill:#ff9800,color:#fff
    style Executor fill:#ff9800,color:#fff
    style Grid fill:#2196f3,color:#fff
    style Hooks fill:#f44336,color:#fff
```

---

## 3. 技能决策完整流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant Core as Core<br/>(OnUpdate)
    participant State as State
    participant Executor as APL Executor
    participant Parser as SimC Parser
    participant Grid as Grid UI
    participant Audio as Audio
    participant Hooks as Hooks
    
    User->>Core: 进入游戏/战斗
    
    loop 每帧 (30-60 FPS)
        Core->>State: reset() - 重置状态
        State->>Hooks: CallHook("reset_preauras")
        State->>State: 扫描光环 (Buffs/Debuffs)
        State->>Hooks: CallHook("reset_postauras")
        State->>State: 查询游戏状态 (HP/Mana/CD)
        State-->>Core: Context 快照完成
        
        Core->>Executor: RunHandler() - 执行决策
        Executor->>Parser: 获取已编译的 APL 函数
        Parser-->>Executor: logicFunc(ctx)
        Executor->>Executor: 评估 APL 条件
        Executor->>State: 查询 ctx (buff.xxx, cd.yyy)
        State-->>Executor: 返回查询结果 (缓存)
        Executor-->>Core: 返回动作名 "fireball"
        
        Core->>Hooks: CallHook("runHandler", "fireball")
        Hooks->>Hooks: 职业特殊处理
        
        Core->>Grid: UpdateHighlights(action)
        Grid->>Grid: 高亮对应按钮
        
        Core->>Audio: PlayByAction("fireball")
        Audio->>Audio: 检查节流 (2秒)
        Audio-->>Audio: 播放音频文件
    end
    
    User->>Grid: 点击高亮按钮
    Grid->>Grid: 执行技能宏
```

---

## 4. 配置加载与切换流程

```mermaid
flowchart TD
    Start([插件启动]) --> LoadDB[加载 SavedVariables]
    LoadDB --> CheckSpec{专精已检测?}
    
    CheckSpec -->|否| WaitSpec[等待专精检测]
    WaitSpec --> PollTalent[轮询天赋数据<br/>2秒间隔]
    PollTalent --> GetSpec[识别专精]
    GetSpec --> CheckSpec
    
    CheckSpec -->|是| LoadProfile[加载对应配置]
    LoadProfile --> TryBuiltin{内置配置存在?}
    
    TryBuiltin -->|是| UseBuiltin[使用内置配置]
    TryBuiltin -->|否| UseDefault[使用默认配置]
    
    UseBuiltin --> MergeUser{用户配置存在?}
    UseDefault --> MergeUser
    
    MergeUser -->|是| Merge[合并用户配置]
    MergeUser -->|否| Skip[跳过合并]
    
    Merge --> Validate[校验配置完整性]
    Skip --> Validate
    
    Validate --> ParseAPL[解析 APL 脚本]
    ParseAPL --> CompileAPL[编译为 Lua 函数]
    CompileAPL --> CacheScript[缓存编译结果]
    
    CacheScript --> BuildGrid[构建 Grid UI]
    BuildGrid --> Ready([准备就绪])
    
    Ready --> Monitor[监听天赋变更]
    Monitor --> TalentChange{天赋变更?}
    TalentChange -->|否| Monitor
    TalentChange -->|是| ReloadProfile[重新加载配置]
    ReloadProfile --> LoadProfile
    
    style Start fill:#4caf50,color:#fff
    style Ready fill:#4caf50,color:#fff
    style LoadProfile fill:#2196f3,color:#fff
    style ParseAPL fill:#ff9800,color:#fff
    style CompileAPL fill:#ff9800,color:#fff
```

---

## 5. APL 编译与执行流程

```mermaid
flowchart LR
    subgraph "编译阶段 (一次性)"
        APL[APL 文本<br/>actions+=/fireball,if=buff.hot_streak.up]
        --> Tokenize[词法分析<br/>Token流]
        --> Parse[语法分析<br/>AST树]
        --> Codegen[代码生成<br/>Lua函数]
        --> Cache[脚本缓存<br/>弱引用表]
    end
    
    subgraph "执行阶段 (每帧)"
        GetFunc[获取缓存函数] --> Execute[logicFunc ctx]
        Execute --> EvalCond{条件评估}
        EvalCond -->|true| ReturnAction[返回动作名]
        EvalCond -->|false| NextRule[下一条规则]
        NextRule --> EvalCond
        ReturnAction --> Highlight[高亮 UI]
        ReturnAction --> PlaySound[播放音频]
    end
    
    Cache -.读取.-> GetFunc
    
    style APL fill:#e8f5e9
    style Codegen fill:#fff4e1
    style Cache fill:#f3e5f5
    style Execute fill:#e1f5ff
    style ReturnAction fill:#4caf50,color:#fff
```

---

## 6. 状态快照与查询缓存机制

```mermaid
flowchart TD
    FrameStart([帧开始]) --> Reset[State.reset]
    
    Reset --> ClearCache[清空查询缓存]
    ClearCache --> ScanAura[扫描光环<br/>UnitBuff/UnitDebuff]
    ScanAura --> BuildContext[构建 Context 元表]
    
    BuildContext --> Ready[快照完成]
    
    Ready --> APLQuery1[APL查询: buff.hot_streak]
    APLQuery1 --> CheckCache1{缓存命中?}
    CheckCache1 -->|是| ReturnCached1[返回缓存值]
    CheckCache1 -->|否| QueryGame1[查询游戏API]
    QueryGame1 --> SaveCache1[保存到缓存]
    SaveCache1 --> ReturnCached1
    
    ReturnCached1 --> APLQuery2[APL查询: cd.pyroblast]
    APLQuery2 --> CheckCache2{缓存命中?}
    CheckCache2 -->|是| ReturnCached2[返回缓存值]
    CheckCache2 -->|否| QueryGame2[查询游戏API]
    QueryGame2 --> SaveCache2[保存到缓存]
    SaveCache2 --> ReturnCached2
    
    ReturnCached2 --> FrameEnd([帧结束])
    
    FrameEnd --> NextFrame{下一帧?}
    NextFrame -->|是| FrameStart
    NextFrame -->|否| Stop([停止])
    
    style Reset fill:#ff9800,color:#fff
    style CheckCache1 fill:#4caf50,color:#fff
    style CheckCache2 fill:#4caf50,color:#fff
    style ReturnCached1 fill:#4caf50,color:#fff
    style ReturnCached2 fill:#4caf50,color:#fff
```

---

## 7. 钩子系统事件流

```mermaid
sequenceDiagram
    participant Core
    participant Hooks
    participant Warrior as Warrior Module
    participant Mage as Mage Module
    
    Note over Core,Mage: 插件初始化
    Warrior->>Hooks: RegisterHook("runHandler", handler1)
    Mage->>Hooks: RegisterHook("runHandler", handler2)
    
    Note over Core,Mage: 进入战斗
    Core->>Hooks: CallHook("startCombat")
    Hooks->>Warrior: handler(event)
    Hooks->>Mage: handler(event)
    
    Note over Core,Mage: 每帧决策
    Core->>Core: 执行 APL
    Core->>Hooks: CallHook("runHandler", "execute")
    
    Hooks->>Warrior: handler("runHandler", "execute")
    Note right of Warrior: 检查是否 Execute<br/>清除猝死 Buff
    
    Hooks->>Mage: handler("runHandler", "execute")
    Note right of Mage: 跳过，不处理
    
    Note over Core,Mage: 离开战斗
    Core->>Hooks: CallHook("endCombat")
    Hooks->>Warrior: handler(event)
    Hooks->>Mage: handler(event)
```

---

## 8. Grid UI 拖拽绑定流程

```mermaid
stateDiagram-v2
    [*] --> Unlocked: 解锁模式
    
    Unlocked --> Dragging: 开始拖拽技能
    Dragging --> Hovering: 悬停在槽位上
    Hovering --> Dropped: 释放鼠标
    
    Dropped --> ValidateSpell: 校验技能有效性
    ValidateSpell --> UpdateSlot: 更新槽位配置
    UpdateSlot --> SaveProfile: 保存到配置
    SaveProfile --> Refresh: 刷新 Grid
    
    Refresh --> Unlocked
    
    Unlocked --> Locked: 锁定模式
    Locked --> Highlighting: APL 决策高亮
    Highlighting --> Locked
    
    Locked --> Unlocked: 解锁模式
    
    Hovering --> Dragging: 移出槽位
    Dragging --> Unlocked: 取消拖拽
```

---

## 9. 性能优化关键点

```mermaid
mindmap
    root((性能优化))
        状态快照
            查询缓存
                单帧内缓存
                命中率 95%+
            对象池
                Context 复用
                减少 GC
            惰性查询
                按需计算
                元表 __index
        SimC 解析
            脚本缓存
                弱引用表
                命中率 99%+
            编译优化
                局部变量
                避免闭包
        UI 渲染
            按需更新
                仅高亮变化时刷新
            节流
                最小间隔 0.05s
        音频系统
            播放节流
                2秒间隔
                防止音频风暴
        事件处理
            事件节流
                UNIT_AURA 0.1s
            批量处理
                合并多次更新
```

---

## 10. 模块通信模式

```mermaid
graph TB
    subgraph "直接调用"
        A[Core] -->|直接调用| B[State]
        A -->|直接调用| C[Executor]
    end
    
    subgraph "事件驱动"
        D[SpecDetection] -.天赋变更.-> E[EventBus]
        E -.触发.-> F[Core]
        F -->|重新加载| G[ProfileManager]
    end
    
    subgraph "钩子机制"
        H[Core] -->|CallHook| I[Hooks]
        I -.分发.-> J[Warrior]
        I -.分发.-> K[Mage]
    end
    
    subgraph "配置驱动"
        L[ProfileManager] -->|提供配置| M[Grid UI]
        L -->|提供配置| N[APL Executor]
    end
    
    style A fill:#4caf50,color:#fff
    style E fill:#ff9800,color:#fff
    style I fill:#f44336,color:#fff
    style L fill:#2196f3,color:#fff
```

---

## 图表说明

### Mermaid 渲染
所有图表使用 Mermaid 语法编写，可在以下环境中正确渲染：
- GitHub (原生支持)
- VS Code (Markdown Preview Mermaid Support 插件)
- 在线工具 (https://mermaid.live)

### 图例

| 颜色 | 含义 |
|------|------|
| 🟢 绿色 | 核心层模块 |
| 🟠 橙色 | 引擎层模块 |
| 🔵 蓝色 | 表现层模块 |
| 🟣 紫色 | 数据层模块 |
| 🔴 红色 | 扩展层模块 |

| 线条 | 含义 |
|------|------|
| 实线箭头 | 直接依赖 |
| 虚线箭头 | 被动依赖/事件触发 |
| 双向箭头 | 相互通信 |

---

## 相关文档

- [主设计文档](../WhackAMole_Design.md) - 系统概览
- [详细设计索引](INDEX.md) - 14 个模块详细设计
- [阅读指南](README.md) - 推荐阅读路径
