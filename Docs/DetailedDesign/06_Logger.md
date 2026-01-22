# 06 - 日志与调试详细设计

## 模块概述

**文件**: `src/Core/Logger.lua`

Logger 提供调试日志记录、COMBAT_LOG 事件监听和日志查看界面，帮助开发者和高级用户排查问题。

---

## 设计目标

1. **按需启用**：日志系统默认关闭，避免性能开销
2. **事件捕获**：记录 COMBAT_LOG 事件用于分析
3. **易于查看**：提供 GUI 界面查看和复制日志
4. **内存安全**：限制日志行数，防止内存泄漏

---

## 职责

1. **日志记录**
   - 按时间戳记录消息
   - 分类管理（Combat/State/APL 等）

2. **事件监听**
   - 注册 COMBAT_LOG_EVENT_UNFILTERED
   - 过滤玩家相关事件

3. **日志查看**
   - AceGUI 窗口显示日志
   - 支持全选复制

4. **内存管理**
   - 限制最大行数（1000 行）
   - 自动移除旧日志

---

## 核心数据结构

### 日志存储

```lua
Logger = {
    enabled = false,           -- 是否启用日志
    lines = {},                -- 日志行数组
    maxLines = 1000,           -- 最大行数
    lastPlayedAction = nil     -- 最后播放的动作（调试用）
}
```

### 日志行格式

```
[HH:MM:SS] 消息内容
[14:23:45] [CLEU] SPELL_CAST_SUCCESS: Fireball (ID:133) [Player -> Boss]
```

---

## 日志记录

### 核心函数

```lua
function Logger:Log(msg)
    if not self.enabled then return end
    
    -- 1. 生成时间戳
    local time = date("%H:%M:%S")
    
    -- 2. 格式化日志行
    local line = string.format("[%s] %s", time, msg)
    
    -- 3. 添加到日志数组
    table.insert(self.lines, line)
    
    -- 4. 限制最大行数（防止内存泄漏）
    if #self.lines > self.maxLines then
        table.remove(self.lines, 1)  -- 移除最旧的一行
    end
end
```

### 分类日志

```lua
-- 通用日志
Logger:Log("System initialized")

-- 分类日志（建议格式）
Logger:Log("[Combat] Entered combat")
Logger:Log("[State] HP: 25000/30000 (83%)")
Logger:Log("[APL] Action selected: fireball")
Logger:Log("[Error] Failed to parse condition")
```

---

## 启动与停止

### 启动日志

```lua
function Logger:Start()
    -- 1. 清空旧日志
    self.lines = {}
    
    -- 2. 启用日志
    self.enabled = true
    
    -- 3. 注册事件
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- 4. 记录启动
    self:Log("Logging started.")
    
    -- 5. 用户反馈
    print("|cff00ff00WhackAMole Logging Started.|r")
end
```

### 停止日志

```lua
function Logger:Stop()
    -- 1. 禁用日志
    self.enabled = false
    
    -- 2. 取消事件注册
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- 3. 记录停止
    self:Log("Logging stopped.")
    
    -- 4. 用户反馈
    print("|cffff0000WhackAMole Logging Stopped.|r Type /wam debug show to view.")
end
```

---

## COMBAT_LOG 事件监听

### 事件处理器

```lua
function Logger:COMBAT_LOG_EVENT_UNFILTERED(
    event, timestamp, eventType, 
    sourceGUID, sourceName, sourceFlags,
    destGUID, destName, destFlags,
    spellId, spellName, spellSchool, ...
)
    if not self.enabled then return end
    
    -- 过滤：仅记录玩家施放的技能
    -- （可选：移除过滤以查看所有事件）
    -- if sourceGUID ~= UnitGUID("player") then
    --     return
    -- end
    
    -- 记录技能施放成功事件
    if eventType == "SPELL_CAST_SUCCESS" then
        local src = sourceName or "Unknown"
        local dst = destName or "Unknown"
        
        self:Log(string.format(
            "[CLEU] %s: %s (ID:%s) [%s -> %s]",
            eventType,
            tostring(spellName),
            tostring(spellId),
            src,
            dst
        ))
    end
    
    -- 可扩展：记录其他事件类型
    -- SPELL_AURA_APPLIED, SPELL_INTERRUPT 等
end
```

---

## 日志查看界面

### AceGUI 窗口

```lua
function Logger:Show()
    -- 1. 获取 AceGUI 库
    local AceGUI = LibStub("AceGUI-3.0")
    if not AceGUI then
        print("WhackAMole: AceGUI-3.0 not found.")
        return
    end
    
    -- 2. 创建窗口
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("WhackAMole Debug Log")
    frame:SetLayout("Fill")
    frame:SetWidth(800)
    frame:SetHeight(600)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    
    -- 3. 创建多行文本框
    local edit = AceGUI:Create("MultiLineEditBox")
    edit:SetLabel("Log Output (Ctrl+A, Ctrl+C to copy)")
    
    -- 4. 填充日志内容
    local text = table.concat(self.lines, "\n")
    if text == "" then
        text = "No logs recorded."
    end
    
    edit:SetText(text)
    edit:SetFullWidth(true)
    edit:SetFullHeight(true)
    edit:DisableButton(true)  -- 隐藏"Accept"按钮
    
    -- 5. 添加到窗口
    frame:AddChild(edit)
end
```

---

## 命令行集成

### /wam debug 命令

```lua
function WhackAMole:OnChatCommand(input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "debug" then
        if args == "on" or args == "start" then
            if ns.Logger then
                ns.Logger:Start()
                self:Print("调试日志已开启")
            end
            
        elseif args == "off" or args == "stop" then
            if ns.Logger then
                ns.Logger:Stop()
                self:Print("调试日志已关闭")
            end
            
        elseif args == "show" or args == "" then
            if ns.Logger then
                ns.Logger:Show()
            end
            
        else
            self:Print("用法: /wam debug [on|off|show]")
        end
    end
    -- ... 其他命令
end
```

---

## 扩展日志功能

### Debug 辅助函数

```lua
-- 添加到 Logger 模块
function Logger:Debug(category, message)
    if not self.enabled then return end
    self:Log(string.format("[%s] %s", category, message))
end

function Logger:Error(category, message)
    self:Log(string.format("[ERROR:%s] %s", category, message))
end

function Logger:Warn(category, message)
    self:Log(string.format("[WARN:%s] %s", category, message))
end

-- 使用示例
ns.Logger:Debug("APL", "Condition evaluated to false")
ns.Logger:Error("SimCParser", "Failed to parse: " .. conditionStr)
ns.Logger:Warn("State", "Buff cache miss: hot_streak")
```

---

## 性能分析器集成

### ShowProfileStats 输出

```lua
function WhackAMole:ShowProfileStats(reset)
    -- ... 性能统计计算 ...
    
    -- 格式化输出
    self:Print("========== WhackAMole 性能分析 ==========")
    self:Print(string.format("总帧数: %d 帧", frameCount))
    self:Print(string.format("平均帧耗时: %.2f ms", avgFrameTime))
    self:Print(string.format("峰值帧耗时: %.2f ms", maxFrameTime))
    
    self:Print("\n模块耗时分布:")
    self:Print(string.format("  State 重置: %.2f ms", stateTime))
    self:Print(string.format("  APL 执行: %.2f ms", aplTime))
    
    self:Print("\n查询缓存统计:")
    local cacheStats = ns.State:GetCacheStats()
    self:Print(string.format("  命中率: %.1f%%", cacheStats.hitRate * 100))
    
    self:Print("\n脚本编译缓存统计:")
    local scriptStats = ns.SimCParser.GetCacheStats()
    self:Print(string.format("  命中率: %.1f%%", scriptStats.hitRate))
    
    self:Print("========================================")
    
    -- 可选：同时记录到日志
    if ns.Logger and ns.Logger.enabled then
        ns.Logger:Log("=== Performance Stats ===")
        ns.Logger:Log(string.format("Avg Frame: %.2f ms", avgFrameTime))
        -- ...
    end
end
```

---

## 内存管理

### 最大行数限制

```lua
maxLines = 1000  -- 约占用 100-200KB 内存

-- 超出限制时自动删除旧日志
if #self.lines > self.maxLines then
    table.remove(self.lines, 1)
end
```

### 清空日志

```lua
function Logger:Clear()
    self.lines = {}
    self:Log("Logs cleared.")
end
```

---

## 调试最佳实践

### 排查性能问题

```lua
-- 在关键路径添加计时
local startTime = debugprofilestop()

-- ... 执行代码 ...

local elapsed = debugprofilestop() - startTime
ns.Logger:Debug("Performance", string.format("Operation took %.2f ms", elapsed))
```

### 排查 APL 错误

```lua
-- 记录条件评估
ns.Logger:Debug("APL", string.format(
    "Condition: %s -> %s",
    conditionStr,
    result and "true" or "false"
))

-- 记录动作选择
ns.Logger:Debug("APL", string.format(
    "Action selected: %s (index %d)",
    actionName,
    actionIndex
))
```

### 排查状态快照问题

```lua
-- 记录关键状态
ns.Logger:Debug("State", string.format(
    "HP: %d/%d (%.1f%%), Mana: %d/%d (%.1f%%)",
    currentHP, maxHP, hpPct,
    currentMana, maxMana, manaPct
))

-- 记录 Buff 查询
ns.Logger:Debug("State", string.format(
    "Buff check: %s -> %s",
    buffName,
    found and "UP" or "DOWN"
))
```

---

## 已知限制

1. **性能开销**
   - 启用日志后每帧约增加 0.5-1ms 开销
   - COMBAT_LOG 事件密集时开销更高

2. **内存占用**
   - 1000 行日志约占用 100-200KB
   - 长时间开启可能累积较多内存

3. **事件过滤**
   - 当前仅记录 SPELL_CAST_SUCCESS
   - 其他事件类型需手动添加

4. **GUI 性能**
   - 日志内容过多时（>5000 行）窗口可能卡顿
   - 建议定期清空或重启日志

---

## 依赖关系

### 依赖的库
- AceEvent-3.0 (事件监听)
- AceGUI-3.0 (日志窗口)

### 被依赖的模块
- Core (命令行调用)
- 所有模块 (可选使用 Logger 记录调试信息)

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [状态快照系统](07_State.md)
- [SimC 解析器](08_SimCParser.md)
