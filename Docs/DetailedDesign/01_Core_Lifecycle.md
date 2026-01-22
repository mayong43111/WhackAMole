# 01 - 生命周期与主控制器

## 模块概述

**文件**: `src/Core.lua`

Core.lua 是 WhackAMole 插件的主控制器，负责插件的完整生命周期管理、事件分发、帧更新循环和用户命令处理。

---

## 职责

1. **生命周期管理**
   - 插件初始化（OnInitialize）
   - 启用时配置加载（OnEnable）
   - 禁用时资源清理（OnDisable）

2. **事件管理**
   - 游戏事件注册与分发
   - 事件节流机制（防止高频事件风暴）

3. **帧更新循环**
   - 战斗中的决策循环（每帧）
   - 状态快照生成
   - APL 执行与预测
   - UI 更新触发

4. **命令行接口**
   - `/wam` 命令注册
   - 调试命令（debug/state/eval/profile）
   - 配置切换命令

---

## 核心数据结构

### 配置常量

```lua
CONFIG = {
    updateInterval = 0.05,        -- 主循环间隔（秒）
    throttleInterval = 0.016,     -- 事件节流间隔（~60 FPS）
    priorityEvents = {            -- 需要优先处理的事件
        "SPELL_CAST_SUCCESS",
        "SPELL_INTERRUPT",
        "SPELL_AURA_APPLIED",
        "SPELL_AURA_REMOVED",
        "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_INTERRUPTED"
    }
}
```

### 运行时状态

```lua
WhackAMole.currentProfile  -- 当前加载的配置对象
WhackAMole.logicFunc       -- 编译后的 APL 决策函数
WhackAMole.db              -- AceDB 数据库引用
```

### 性能统计

```lua
WhackAMole.perfStats = {
    frameCount = 0,
    totalTime = 0,
    maxFrameTime = 0,
    lastResetTime = 0,
    -- 模块级统计
    state_time = 0,
    apl_time = 0,
    predict_time = 0,
    ui_time = 0,
    audio_time = 0,
    -- 帧耗时分布
    frameTimes = {}  -- 最近 1000 帧的耗时记录
}
```

---

## 初始化流程

### 1. OnInitialize (插件加载时)

```
1. 检查依赖库（AceDB-3.0, AceConfig-3.0 等）
2. 初始化 AceDB 数据库
3. 注册配置界面到 Blizzard UI
4. 初始化子系统：
   - Logger
   - Constants
   - SpecDetection
   - ProfileManager
   - ActionMap
   - Audio
   - Hooks
5. 注册斜杠命令 /wam
```

### 2. OnEnable (角色登录后)

```
1. 检测职业与专精
2. 延迟 2 秒后检测天赋（等待 API 就绪）
3. 加载当前配置：
   - 优先用户配置
   - 回退内置配置
4. 编译 APL 条件表达式
5. 初始化 UI 网格
6. 注册游戏事件：
   - PLAYER_REGEN_DISABLED (进入战斗)
   - PLAYER_REGEN_ENABLED (脱离战斗)
   - PLAYER_TALENT_UPDATE (天赋变更)
   - ACTIVE_TALENT_GROUP_CHANGED (切换天赋方案)
7. 启动帧更新循环
```

### 3. OnDisable (插件卸载时)

```
1. 取消所有注册的事件
2. 停止帧更新循环
3. 清理性能统计
4. 注销钩子
```

---

## 帧更新循环

### 主循环逻辑 (OnUpdate)

```lua
function WhackAMole:OnUpdate(elapsed)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
    
    -- 节流：仅在达到更新间隔后执行
    if self.timeSinceLastUpdate < CONFIG.updateInterval then
        return
    end
    
    local frameStart = debugprofilestop()
    
    -- 1. 重置状态快照（轻量级）
    ns.State:reset(false)  -- 不完全重置，仅更新时间/GCD
    
    -- 2. 执行 APL 决策
    local action = self:RunHandler()
    
    -- 3. 虚拟时间预测（可选）
    local nextAction = self:PredictNext()
    
    -- 4. 更新 UI 高亮
    ns.UI.Grid:UpdateHighlights(action, nextAction)
    
    -- 5. 触发音频提示
    if action then
        ns.Audio:PlayByAction(action)
    end
    
    -- 6. 记录性能统计
    local frameTime = debugprofilestop() - frameStart
    self:RecordFrameTime(frameTime)
    
    self.timeSinceLastUpdate = 0
end
```

### 决策函数 (RunHandler)

```lua
function WhackAMole:RunHandler()
    if not self.logicFunc then return nil end
    
    local startTime = debugprofilestop()
    
    -- 构建 Context（状态快照）
    local ctx = ns.State:BuildContext()
    
    -- 调用编译后的 APL 函数
    local success, action = pcall(self.logicFunc, ctx)
    
    -- 错误处理
    if not success then
        ns.Logger:Error("APL execution failed: " .. tostring(action))
        return nil
    end
    
    -- 记录耗时
    self.perfStats.apl_time = self.perfStats.apl_time + 
        (debugprofilestop() - startTime)
    
    return action
end
```

---

## 事件节流机制

### 设计目标
- 防止高频事件导致性能问题
- 保证优先级事件及时处理
- 平衡响应性与性能

### 实现机制

```lua
local lastEventTime = 0
local eventQueue = {}

function WhackAMole:OnCombatLogEvent(...)
    local timestamp, event, _, sourceGUID = ...
    
    -- 1. 仅处理玩家事件
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    
    -- 2. 检查节流间隔
    local now = GetTime()
    if now - lastEventTime < CONFIG.throttleInterval then
        -- 3. 非优先级事件延迟处理
        if not tContains(CONFIG.priorityEvents, event) then
            tinsert(eventQueue, {timestamp, ...})
            return
        end
    end
    
    -- 4. 立即处理优先级事件
    lastEventTime = now
    self:HandleCombatEvent(event, ...)
end
```

---

## 命令行接口

### 命令列表

| 命令 | 功能 | 参数 |
|------|------|------|
| `/wam` | 打开配置面板 | - |
| `/wam debug` | 切换调试模式 | - |
| `/wam state` | 输出状态快照 | - |
| `/wam eval <condition>` | 测试 APL 条件 | 条件表达式 |
| `/wam profile` | 显示性能统计 | - |
| `/wam profile reset` | 重置性能统计 | - |

### 命令处理流程

```lua
function WhackAMole:HandleSlashCommand(input)
    -- 解析命令
    local cmd, args = self:GetArgs(input, 2)
    
    -- 路由到处理函数
    if cmd == "debug" then
        self:ToggleDebug()
    elseif cmd == "state" then
        self:PrintStateSnapshot()
    elseif cmd == "eval" then
        self:EvaluateCondition(args)
    elseif cmd == "profile" then
        if args == "reset" then
            self:ResetPerfStats()
        else
            self:ShowProfileStats()
        end
    else
        -- 默认：打开配置面板
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
end
```

---

## 配置切换

### SwitchProfile 流程

```lua
function WhackAMole:SwitchProfile(profile)
    -- 1. 保存当前配置引用
    self.currentProfile = profile
    self.db.char.activeProfileID = profile.id
    
    -- 2. 清理旧状态
    ns.State:reset(true)           -- 完全重置状态
    ns.SimCParser.ClearCache()     -- 清空编译缓存
    
    -- 3. 重新编译 APL
    local actions = profile.actions or {}
    self.logicFunc = ns.APLExecutor.CreateLogicFunc(actions)
    
    -- 4. 重建网格 UI
    ns.UI.Grid:Rebuild(profile.layout)
    
    -- 5. 触发钩子
    ns.Hooks:Call("profile_switched", profile)
    
    -- 6. 用户反馈
    self:Print(string.format("已切换到配置: %s", profile.name))
end
```

---

## 性能统计

### 统计指标

- **帧级统计**
  - 平均帧耗时
  - 峰值帧耗时
  - 95 分位、99 分位
  - 帧数/秒

- **模块级统计**
  - State 重置耗时
  - APL 执行耗时
  - 预测计算耗时
  - UI 更新耗时
  - 音频播放耗时

- **缓存统计**
  - 查询缓存命中率
  - 脚本编译缓存命中率

### 输出示例

```
========== WhackAMole 性能分析 ==========
总帧数: 2456 帧
总耗时: 5.234 秒
平均帧耗时: 2.13 ms
峰值帧耗时: 8.45 ms
95分位帧耗时: 3.21 ms
99分位帧耗时: 5.67 ms

模块耗时分布:
  State 重置: 0.35 ms (16.4%)
  APL 执行: 0.68 ms (31.9%)
  预测计算: 0.42 ms (19.7%)
  UI 更新: 0.51 ms (23.9%)
  音频播放: 0.17 ms (8.0%)

查询缓存统计:
  命中: 1832 次
  未命中: 456 次
  命中率: 80.1%

脚本编译缓存统计:
  命中: 2301 次
  未命中: 155 次
  命中率: 93.7%
========================================
```

---

## 依赖关系

### 依赖的模块
- AceAddon-3.0 (插件框架)
- AceDB-3.0 (数据持久化)
- AceConfig-3.0 (配置界面)
- AceConsole-3.0 (命令行)
- AceEvent-3.0 (事件管理)

### 被依赖的模块
- 所有子系统都依赖 Core 的生命周期管理

---

## 已知限制

1. **帧更新间隔固定**
   - 当前为 50ms (20 FPS)，未根据战斗强度动态调整

2. **事件节流粒度较粗**
   - 16ms 间隔可能在极高 APM 场景下丢失部分事件

3. **性能统计开销**
   - debugprofilestop() 本身有微小开销

4. **配置热切换不完全**
   - 切换配置后部分状态可能需要重载 UI

---

## 相关文档
- [配置管理系统](02_ProfileManager.md)
- [状态快照系统](07_State.md)
- [APL 执行器](09_APLExecutor.md)
- [网格 UI](10_Grid_UI.md)
- [日志与调试](06_Logger.md)
