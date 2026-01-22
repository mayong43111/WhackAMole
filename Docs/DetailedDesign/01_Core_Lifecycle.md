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
        "SPELL_AURA_REMOVED"
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
    maxTime = 0,
    frameTimes = {},  -- 最近 1000 帧的耗时记录
    modules = {
        state = { total = 0, max = 0 },
        apl = { total = 0, max = 0 },
        predict = { total = 0, max = 0 },
        ui = { total = 0, max = 0 },
        audio = { total = 0, max = 0 }
    }
}
```

---

## 初始化流程

### 1. OnInitialize (插件加载时)

```
1. 检查依赖库（AceDB-3.0）
2. 初始化 AceDB 数据库
3. 初始化子模块：
   - ProfileManager
   - UI.Grid
   - Audio
4. 注册配置界面到 Blizzard UI
5. 注册斜杠命令 /wam
6. 初始化事件节流系统
7. 注册战斗事件 (COMBAT_LOG_EVENT_UNFILTERED)
8. 注册初始化事件 (PLAYER_ENTERING_WORLD)
9. 初始化专精检测系统
```

### 2. OnPlayerEnteringWorld (玩家进入世界)

```
1. 取消 PLAYER_ENTERING_WORLD 事件注册（避免重复触发）
2. 延迟 2 秒等待天赋 API 就绪
3. 检测专精 ID（最多重试 10 次）
4. 初始化配置：
   - 加载职业技能数据
   - 重建 ActionMap
   - 选择匹配的配置文件
   - 自动选择或使用上次配置
5. 切换到选定配置：
   - 清空脚本编译缓存
   - 创建/调整 UI 网格
   - 编译 APL
6. 帧更新循环自动运行（由 OnUpdate 帧驱动）
```

### 3. 配置初始化 (InitializeProfile)

```
1. 获取当前职业和专精
2. 加载对应的技能数据模块
3. 获取职业可用配置列表
4. 尝试恢复上次使用的配置
5. 如果专精不匹配，自动选择匹配的配置
6. 如果没有匹配配置，使用第一个可用配置
7. 调用 SwitchProfile 切换配置
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
function WhackAMole:OnCombatLogEvent(event, ...)
    local timestamp, eventType, _, sourceGUID = CombatLogGetCurrentEventInfo()
    
    -- 1. 仅处理玩家相关事件
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    
    -- 2. 检查是否为优先级事件
    local isPriority = self:IsPriorityEvent(eventType)
    
    -- 3. 检查节流间隔
    local now = GetTime()
    local timeSinceLastUpdate = now - self.eventThrottle.lastUpdate
    
    if isPriority then
        -- 优先级事件立即加入优先队列
        table.insert(self.eventThrottle.priorityQueue, {
            timestamp = timestamp,
            eventType = eventType,
            destName = destName
        })
        
        -- 如果距离上次更新超过节流间隔，立即触发更新
        if timeSinceLastUpdate >= CONFIG.throttleInterval then
            self:ProcessPendingEvents()
            self.eventThrottle.lastUpdate = now
        end
    else
        -- 普通事件加入待处理队列
        if timeSinceLastUpdate >= CONFIG.throttleInterval then
            table.insert(self.eventThrottle.pendingEvents, {
                timestamp = timestamp,
                eventType = eventType,
                destName = destName
            })
        end
    end
end
```

---

## 命令行接口

### 命令列表

| 命令 | 功能 | 参数 |
|------|------|------|
| `/wam` | 打开配置面板 | - |
| `/wam lock` | 锁定框架 | - |
| `/wam unlock` | 解锁框架 | - |
| `/wam debug` | 显示调试窗口 | - |

### 命令处理流程

```lua
function WhackAMole:OnChatCommand(input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "lock" then
        ns.UI.Grid:SetLock(true)
        self:Print("框架已锁定")
    elseif command == "unlock" then
        ns.UI.Grid:SetLock(false)
        self:Print("框架已解锁")
    elseif command == "debug" then
        -- 显示调试窗口
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        else
            self:Print("调试窗口未初始化")
        end
    elseif command == "" then
        -- 打开配置界面
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    else
        -- 显示帮助
        self:Print("可用命令:")
        self:Print("  /wam lock/unlock - 锁定/解锁框架")
        self:Print("  /wam debug - 显示调试窗口")
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

2. **事件节流机制**
   - 16ms 间隔可能在极高 APM 场景下丢失部分事件
   - 仅注册 COMBAT_LOG_EVENT_UNFILTERED，依赖单一事件源

3. **性能统计开销**
   - debugprofilestop() 本身有微小开销
   - 保留最近 1000 帧记录占用内存

4. **专精检测延迟**
   - 登录后延迟 2 秒检测天赋，可能导致初始化稍慢
   - 最多重试 10 次，极端情况可能超时

---

## 相关文档
- [配置管理系统](02_ProfileManager.md)
- [状态快照系统](07_State.md)
- [APL 执行器](09_APLExecutor.md)
- [网格 UI](10_Grid_UI.md)
- [日志与调试](06_Logger.md)
