# 14 - 钩子系统详细设计

## 模块概述

**文件**: `src/Core/Hooks.lua`

Hooks 提供事件订阅机制，允许职业模块和外部扩展注册回调函数，实现职业特殊机制和模块间解耦。

---

## 设计目标

1. **解耦**：核心系统与职业逻辑分离
2. **扩展性**：轻松添加新事件和处理器
3. **可靠性**：单个处理器错误不影响其他处理器
4. **性能**：低开销的事件分发

---

## 职责

1. **钩子注册**
   - 注册事件处理器
   - 支持多个处理器订阅同一事件

2. **钩子触发**
   - 按顺序调用所有处理器
   - 错误隔离与日志记录

3. **钩子注销**
   - 移除特定处理器
   - 清空特定事件的所有处理器

---

## 核心数据结构

### 钩子存储表

```lua
ns.hooks = {
    ["runHandler"] = {
        function(event, action) ... end,
        function(event, action) ... end,
    },
    ["reset_preauras"] = {
        function(event) ... end,
    },
    ["startCombat"] = {
        function(event) ... end,
    },
    -- ...
}
```

---

## 核心 API

### RegisterHook - 注册钩子

```lua
function ns.RegisterHook(event, handler)
    -- 1. 参数校验
    if type(event) ~= "string" then
        error("RegisterHook: event must be a string", 2)
    end
    if type(handler) ~= "function" then
        error("RegisterHook: handler must be a function", 2)
    end
    
    -- 2. 初始化事件表
    ns.hooks[event] = ns.hooks[event] or {}
    
    -- 3. 添加处理器
    table.insert(ns.hooks[event], handler)
end

-- 使用示例
ns.RegisterHook("runHandler", function(event, action)
    if action == "execute" then
        -- 战士 Execute 特殊处理
        ClearSuddenDeathBuff()
    end
end)
```

### CallHook - 触发钩子

```lua
function ns.CallHook(event, ...)
    -- 1. 获取处理器列表
    local handlers = ns.hooks[event]
    if not handlers then return end
    
    -- 2. 遍历调用所有处理器
    for i, handler in ipairs(handlers) do
        local success, err = pcall(handler, event, ...)
        
        -- 3. 错误隔离
        if not success then
            if ns.Logger then
                ns.Logger:Error("Hook error [" .. event .. "]: " .. tostring(err))
            else
                print("WhackAMole: Hook error [" .. event .. "]: " .. tostring(err))
            end
        end
    end
end

-- 使用示例
ns.CallHook("runHandler", "execute")
ns.CallHook("reset_preauras")
```

### UnregisterHook - 注销钩子

```lua
function ns.UnregisterHook(event, handler)
    local handlers = ns.hooks[event]
    if not handlers then return end
    
    -- 从数组中移除指定处理器
    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
        end
    end
end

-- 使用示例
local myHandler = function(event) ... end
ns.RegisterHook("startCombat", myHandler)

-- 稍后注销
ns.UnregisterHook("startCombat", myHandler)
```

### ClearHooks - 清空钩子

```lua
function ns.ClearHooks(event)
    if event then
        -- 清空特定事件的所有处理器
        ns.hooks[event] = nil
    else
        -- 清空所有钩子
        ns.hooks = {}
    end
end

-- 使用示例
ns.ClearHooks("runHandler")   -- 清空 runHandler 事件
ns.ClearHooks()                -- 清空所有事件
```

---

## 核心钩子事件

### 1. runHandler

**触发时机**：技能执行后

**参数**：
- `event` (string): "runHandler"
- `action` (string): 技能键名（SimC action name）

**用途**：职业特殊机制处理

```lua
-- 战士：Execute 清除猝死 Buff
ns.RegisterHook("runHandler", function(event, action)
    if action == "execute" then
        local suddenDeathID = ns.ID.SuddenDeath
        if suddenDeathID then
            -- 移除 Buff 缓存
            buff_cache[suddenDeathID] = nil
        end
    end
end)
```

### 2. reset_preauras

**触发时机**：State.reset() 扫描光环**之前**

**参数**：
- `event` (string): "reset_preauras"

**用途**：预处理光环数据

```lua
-- 示例：记录重置前的状态
ns.RegisterHook("reset_preauras", function(event)
    if ns.Logger and ns.Logger.enabled then
        ns.Logger:Debug("Hooks", "Resetting state, clearing aura cache")
    end
end)
```

### 3. reset_postauras

**触发时机**：State.reset() 扫描光环**之后**

**参数**：
- `event` (string): "reset_postauras"

**用途**：后处理光环数据

```lua
-- 示例：验证关键 Buff
ns.RegisterHook("reset_postauras", function(event)
    local hotStreakID = ns.ID.HotStreak
    if hotStreakID then
        local buff = buff_cache[hotStreakID]
        if buff and buff.up then
            print("Hot Streak active!")
        end
    end
end)
```

### 4. startCombat

**触发时机**：进入战斗

**参数**：
- `event` (string): "startCombat"

**用途**：战斗开始时的初始化

```lua
-- 示例：重置统计数据
ns.RegisterHook("startCombat", function(event)
    combatStartTime = GetTime()
    totalDamage = 0
    print("Combat started!")
end)
```

### 5. endCombat

**触发时机**：离开战斗

**参数**：
- `event` (string): "endCombat"

**用途**：战斗结束时的清理

```lua
-- 示例：输出战斗统计
ns.RegisterHook("endCombat", function(event)
    local duration = GetTime() - combatStartTime
    local dps = totalDamage / duration
    
    print(string.format(
        "Combat ended. Duration: %.1fs, DPS: %.0f",
        duration, dps
    ))
end)
```

### 6. profile_switched

**触发时机**：配置切换后

**参数**：
- `event` (string): "profile_switched"
- `profile` (table): 新配置对象

**用途**：配置切换后的自定义处理

```lua
-- 示例：清理职业特定状态
ns.RegisterHook("profile_switched", function(event, profile)
    -- 清空职业缓存
    classCachedData = {}
    
    print("Switched to profile: " .. profile.name)
end)
```

### 7. check_spell_usable ⭐ **新增**

**触发时机**：State.spell 查询技能可用性时

**参数**：
- `event` (string): "check_spell_usable"
- `spellID` (number): 技能 ID
- `spellName` (string): 技能名称
- `usable` (boolean): 原始 IsUsableSpell 返回值
- `nomana` (boolean): 原始资源不足标志

**返回值**：
- `{ usable = boolean, nomana = boolean }` - 覆盖原始判断
- `nil` - 使用原始判断

**用途**：职业特殊技能可用性检查（解决技术债务）

```lua
-- 战士：Execute 特殊可用性检查
ns.RegisterHook("check_spell_usable", function(event, spellID, spellName, usable, nomana)
    -- 仅处理 Execute
    if spellID ~= ns.ID.Execute then return nil end
    
    local state = ns.State
    
    -- 条件 1：目标 < 20% HP
    local cond_hp = (state.target.health.pct < 20)
    
    -- 条件 2：有猝死 Buff
    local cond_sd = false
    if ns.ID.SuddenDeath then
        local buffCache = rawget(state.player.buff, "__cache")
        if buffCache then
            local aura = buffCache[ns.ID.SuddenDeath]
            if aura and aura.up then cond_sd = true end
        end
    end
    
    -- 满足条件时，手动检查怒气
    if cond_hp or cond_sd then
        if state.rage >= 10 then
            return { usable = true, nomana = false }
        else
            return { usable = false, nomana = true }
        end
    end
    
    -- 不满足条件，使用原始判断
    return nil
end)
```

**设计说明**：
- 此钩子通过 `CallHookWithReturn()` 调用，支持返回值
- 第一个返回非 nil 的处理器生效，其他处理器不再调用
- 用于解决技术债务：将硬编码在 State.lua 中的 Execute 逻辑抽象化
- 其他职业可使用相同机制（如死骑的 Killing Machine）

---

## CallHookWithReturn - 支持返回值的钩子

**用途**：部分钩子需要返回值来影响核心逻辑（如 `check_spell_usable`）

```lua
function ns.CallHookWithReturn(event, ...)
    local handlers = ns.hooks[event]
    if not handlers then return nil end
    
    for i, handler in ipairs(handlers) do
        local success, result = pcall(handler, event, ...)
        if success and result ~= nil then
            return result  -- 返回第一个非 nil 结果
        elseif not success then
            -- 错误记录
            if ns.Logger then
                ns.Logger:Error("Hook error [" .. event .. "]: " .. tostring(result))
            end
        end
    end
    
    return nil
end

-- 使用示例（在 State.lua 中）
if ns.CallHookWithReturn then
    local hookResult = ns.CallHookWithReturn("check_spell_usable", id, name, usable, nomana)
    if hookResult then
        usable = hookResult.usable
        nomana = hookResult.nomana
    end
end
```

---

## 错误隔离机制

### pcall 保护

```lua
function ns.CallHook(event, ...)
    local handlers = ns.hooks[event]
    if not handlers then return end
    
    for i, handler in ipairs(handlers) do
        -- 使用 pcall 捕获错误
        local success, err = pcall(handler, event, ...)
        
        if not success then
            -- 记录错误但不中断执行
            if ns.Logger then
                ns.Logger:Error(
                    "Hook error [" .. event .. "]",
                    tostring(err)
                )
            else
                print("WhackAMole: Hook error [" .. event .. "]: " .. tostring(err))
            end
        end
    end
end
```

### 错误不影响其他处理器

```lua
-- 注册 3 个处理器
ns.RegisterHook("runHandler", function() print("Handler 1") end)
ns.RegisterHook("runHandler", function() error("Oops!") end)  -- 错误
ns.RegisterHook("runHandler", function() print("Handler 3") end)

-- 触发钩子
ns.CallHook("runHandler", "fireball")

-- 输出：
-- Handler 1
-- WhackAMole: Hook error [runHandler]: Oops!
-- Handler 3
```

---

## 职业模块集成

### 战士模块示例

```lua
-- Classes/Warrior.lua

local function RegisterWarriorHooks()
    -- 1. Execute 清除猝死 Buff
    ns.RegisterHook("runHandler", function(event, action)
        if action == "execute" then
            local suddenDeathID = ns.ID.SuddenDeath
            if suddenDeathID and buff_cache[suddenDeathID] then
                buff_cache[suddenDeathID] = nil
            end
        end
    end)
    
    -- 2. 战斗开始重置怒气
    ns.RegisterHook("startCombat", function(event)
        -- 某些职业机制需要重置状态
        rageDeficit = 0
    end)
end

-- 在职业模块加载时注册
RegisterWarriorHooks()
```

---

## Core.lua 中的钩子触发

### runHandler 触发

```lua
function WhackAMole:RunHandler()
    -- ... APL 执行逻辑 ...
    
    local action = logicFunc(ctx)
    
    if action then
        -- 触发钩子
        ns.CallHook("runHandler", action)
    end
    
    return action
end
```

### reset_preauras/reset_postauras 触发

```lua
function State:reset(full)
    -- 触发预处理钩子
    ns.CallHook("reset_preauras")
    
    -- 扫描光环
    self:ScanAuras()
    
    -- 触发后处理钩子
    ns.CallHook("reset_postauras")
end
```

### startCombat/endCombat 触发

```lua
function WhackAMole:PLAYER_REGEN_DISABLED()
    -- 进入战斗
    self.inCombat = true
    ns.CallHook("startCombat")
end

function WhackAMole:PLAYER_REGEN_ENABLED()
    -- 离开战斗
    self.inCombat = false
    ns.CallHook("endCombat")
end
```

### profile_switched 触发

```lua
function WhackAMole:SwitchProfile(profile)
    -- ... 配置切换逻辑 ...
    
    self.currentProfile = profile
    
    -- 触发钩子
    ns.CallHook("profile_switched", profile)
end
```

---

## 性能优化

### 优化策略

| 策略 | 效果 |
|------|------|
| 仅在有处理器时遍历 | 无钩子时零开销 |
| 数组存储 | 顺序访问，缓存友好 |
| 错误隔离 | 单个错误不影响整体性能 |

### 性能指标

- **注册开销**：< 0.01ms
- **触发开销**：< 0.1ms（无处理器）
- **处理器调用**：< 0.5ms（10 个处理器）

---

## 已知限制

1. **执行顺序不保证**
   - 处理器按注册顺序执行
   - 需要依赖执行顺序时需手动管理

2. **无返回值**
   - 钩子不返回值给调用者
   - 仅用于"通知"模式

3. **无优先级**
   - 所有处理器优先级相同
   - 未来可扩展优先级系统

4. **全局命名空间**
   - 事件名全局共享
   - 需避免命名冲突

---

## 扩展方向

### 未来可能的功能

1. **优先级系统**
   ```lua
   ns.RegisterHook("runHandler", handler, {priority = 10})
   ```

2. **条件钩子**
   ```lua
   ns.RegisterHook("runHandler", handler, {
       condition = function(action) 
           return action == "execute" 
       end
   })
   ```

3. **一次性钩子**
   ```lua
   ns.RegisterHookOnce("startCombat", handler)  -- 触发一次后自动注销
   ```

4. **钩子统计**
   ```lua
   ns.GetHookStats("runHandler")  -- 返回调用次数、平均耗时等
   ```

---

## 依赖关系

### 依赖的模块
- Logger (错误日志记录)

### 被依赖的模块
- Core (触发各类钩子)
- Classes (职业模块注册钩子)
- State (reset 钩子)

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [职业模块](12_Class_Modules.md)
- [状态快照系统](07_State.md)
- [日志与调试](06_Logger.md)
