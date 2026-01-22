# 13 - 动作映射详细设计

## 模块概述

**文件**: `src/Core/ActionMap.lua`

ActionMap 负责建立 SimC 风格动作名到 WoW SpellID 的映射关系，是 APL 系统与游戏 API 之间的桥梁。

---

## 设计目标

1. **统一命名**：使用 SimC 风格的小写下划线命名
2. **快速查询**：O(1) 哈希表查询
3. **自动生成**：从 Constants 自动构建映射表
4. **可扩展性**：支持同义词和多种命名风格

---

## 职责

1. **映射表构建**
   - 从 `ns.Spells` 读取 SpellID 和 key
   - 生成小写和蛇形命名映射

2. **查询接口**
   - 提供 ActionName → SpellID 查询
   - 支持多种命名风格

3. **反向映射**
   - SpellID → ActionName 查询（用于音频系统）

4. **ID 常量导出**
   - 为 State 模块提供快速访问

---

## 核心数据结构

### ActionMap 表

```lua
ns.ActionMap = {
    -- 小写映射
    ["fireball"] = 133,
    ["pyroblast"] = 11366,
    ["fire_blast"] = 2136,
    
    -- 蛇形命名映射
    ["fire_blast"] = 2136,
    ["mortal_strike"] = 12294,
    
    -- 同义词映射（可选）
    ["fb"] = 133,  -- fireball 缩写
    ["pyro"] = 11366,  -- pyroblast 缩写
    -- ...
}
```

### ReverseActionMap 表（反向）

```lua
ns.ReverseActionMap = {
    [133] = "fireball",
    [11366] = "pyroblast",
    [2136] = "fire_blast",
    -- ...
}
```

### ID 常量表

```lua
ns.ID = {
    Fireball = 133,
    Pyroblast = 11366,
    FireBlast = 2136,
    -- ...
}
```

---

## 映射表构建

### BuildActionMap 函数

```lua
function ns.BuildActionMap()
    if not ns.Spells then return end
    
    -- 清空旧映射
    wipe(ns.ActionMap)
    
    -- 遍历所有技能
    for id, data in pairs(ns.Spells) do
        if data.key then
            -- 1. 小写映射
            -- "Fireball" -> "fireball"
            local lowerKey = string.lower(data.key)
            ns.ActionMap[lowerKey] = id
            
            -- 2. 蛇形命名映射
            -- "MortalStrike" -> "mortal_strike"
            local snakeKey = ConvertToSnakeCase(data.key)
            if snakeKey ~= lowerKey then
                ns.ActionMap[snakeKey] = id
            end
            
            -- 3. 同义词映射（可选）
            if data.aliases then
                for _, alias in ipairs(data.aliases) do
                    ns.ActionMap[string.lower(alias)] = id
                end
            end
        end
    end
    
    -- ⭐ 职业模块整合（解决技术债务）
    -- 自动从职业模块加载 spells
    if ns.Classes then
        for className, classData in pairs(ns.Classes) do
            for specID, specData in pairs(classData) do
                if type(specData) == "table" and specData.spells then
                    for id, data in pairs(specData.spells) do
                        if data.key and not ns.ActionMap[string.lower(data.key)] then
                            local lowerKey = string.lower(data.key)
                            ns.ActionMap[lowerKey] = id
                            
                            local snake = data.key:gsub("(%u)", "_%1"):sub(2):lower()
                            if snake ~= lowerKey then
                                ns.ActionMap[snake] = id
                            end
                        end
                    end
                end
            end
        end
    end
end
```

**设计说明**：
- **第一阶段**：从 `ns.Spells`（全局常量）读取技能
- **第二阶段**：从 `ns.Classes`（职业模块）读取职业特定技能
- **去重机制**：职业模块技能不会覆盖全局技能（避免冲突）
- **解决技术债务**：职业模块新增技能自动生效，无需手动同步到 Constants

**优势**：
1. 职业模块定义的技能自动集成到 ActionMap
2. 避免在 Constants 和职业模块中重复定义
3. 职业模块可独立维护自己的技能数据
4. 降低维护成本，减少数据不一致风险

### 蛇形命名转换

```lua
function ConvertToSnakeCase(str)
    -- "MortalStrike" -> "mortal_strike"
    -- "FireBlast" -> "fire_blast"
    
    local snake = str:gsub("(%u)", "_%1"):sub(2):lower()
    return snake
end

-- 示例：
-- ConvertToSnakeCase("MortalStrike")  -> "mortal_strike"
-- ConvertToSnakeCase("Fireball")      -> "fireball"
-- ConvertToSnakeCase("Execute")       -> "execute"
```

---

## Constants 结构

### ns.Spells 定义

```lua
-- 在 Core/Constants.lua 中定义
ns.Spells = {
    -- Warrior
    [12294] = {
        key = "MortalStrike",
        name = "致死打击",
        sound = "mortal_strike.ogg",
        aliases = {"ms"}  -- 可选：同义词
    },
    
    [5308] = {
        key = "Execute",
        name = "斩杀",
        sound = "execute.ogg",
        aliases = {"exec"}
    },
    
    -- Mage
    [133] = {
        key = "Fireball",
        name = "火球术",
        sound = "fireball.ogg",
        aliases = {"fb"}
    },
    
    [11366] = {
        key = "Pyroblast",
        name = "炎爆术",
        sound = "pyroblast.ogg",
        aliases = {"pyro"}
    },
    
    -- ...
}
```

---

## 查询接口

### 根据 ActionName 获取 SpellID

```lua
-- 直接访问表
local spellID = ns.ActionMap["fireball"]  -- 返回 133

-- 使用函数封装（推荐）
function ns.GetSpellID(actionName)
    if not actionName then return nil end
    return ns.ActionMap[string.lower(actionName)]
end

-- 示例
local spellID = ns.GetSpellID("Fireball")    -- 133
local spellID = ns.GetSpellID("fire_blast")  -- 2136
local spellID = ns.GetSpellID("fb")          -- 133 (别名)
```

### 根据 SpellID 获取 ActionName

```lua
-- 构建反向映射（懒加载）
function ns.GetActionName(spellID)
    if not spellID then return nil end
    
    -- 懒加载反向映射
    if not ns.ReverseActionMap then
        ns.ReverseActionMap = {}
        for action, id in pairs(ns.ActionMap) do
            if not ns.ReverseActionMap[id] then
                ns.ReverseActionMap[id] = action
            end
        end
    end
    
    return ns.ReverseActionMap[spellID]
end

-- 示例
local actionName = ns.GetActionName(133)     -- "fireball"
local actionName = ns.GetActionName(12294)   -- "mortal_strike"
```

---

## ID 常量导出

### ns.ID 表

```lua
-- 自动生成 ID 常量表
ns.ID = {}

for id, data in pairs(ns.Spells) do
    if data.key then
        ns.ID[data.key] = id
    end
end

-- 使用示例（在 State.lua 中）
if spellID == ns.ID.Execute then
    -- Execute 特殊处理
end

if ns.ID.SuddenDeath then
    -- 检查猝死 Buff
    local buff = FindAura(buff_cache, ns.ID.SuddenDeath)
end
```

---

## 初始化时机

### 加载顺序

```lua
-- 1. Constants.lua 先加载（定义 ns.Spells）
-- 2. Classes/*.lua 加载（定义职业模块 spells）
-- 3. ActionMap.lua 加载时自动构建映射
ns.BuildActionMap()

-- 4. 导出 ID 常量（从 ns.Spells 和 ns.Classes）
for id, data in pairs(ns.Spells) do
    if data.key then
        ns.ID[data.key] = id
    end
end

-- 职业模块 ID 也会被导出
if ns.Classes then
    for className, classData in pairs(ns.Classes) do
        for specID, specData in pairs(classData) do
            if type(specData) == "table" and specData.spells then
                for id, data in pairs(specData.spells) do
                    if data.key and not ns.ID[data.key] then
                        ns.ID[data.key] = id
                    end
                end
            end
        end
    end
end
```

**设计原则**：
- Constants 优先：全局技能定义优先级高于职业模块
- 延迟加载：职业模块可在后续按需加载，自动集成
- 热重载支持：调用 `BuildActionMap()` 可重新构建映射

---

## APL 中的使用

### 动作名解析

```lua
-- APL 规则：
"actions+=/fireball,if=buff.hot_streak.up"

-- SimCParser 编译时不需要 SpellID
-- 仅在 State 或 Grid 需要时查询

-- 在 State.lua 中查询技能可用性：
local spellID = ns.ActionMap["fireball"]
if spellID then
    local usable = IsUsableSpell(spellID)
end

-- 在 Grid.lua 中绑定槽位：
local spellID = ns.ActionMap[slotDef.actions[1]]
btn:SetAttribute("spell", spellID)
```

---

## 多语言支持

### 技能名称本地化

```lua
-- Constants.lua 中存储多语言名称
ns.Spells = {
    [133] = {
        key = "Fireball",
        name = {
            ["enUS"] = "Fireball",
            ["zhCN"] = "火球术",
            ["zhTW"] = "火球術",
        },
        sound = "fireball.ogg"
    }
}

-- 获取本地化名称
function ns.GetSpellName(spellID)
    local locale = GetLocale()
    local data = ns.Spells[spellID]
    
    if data and data.name then
        if type(data.name) == "table" then
            return data.name[locale] or data.name["enUS"]
        else
            return data.name
        end
    end
    
    return GetSpellInfo(spellID)  -- 回退到 API
end
```

---

## 扩展职业支持

### 添加新职业技能

```lua
-- 1. 在 Constants.lua 中添加 SpellID 定义
ns.Spells = {
    -- ... 现有技能 ...
    
    -- 新增：盗贼技能
    [1752] = {
        key = "Sinister Strike",
        name = "邪恶攻击",
        sound = "sinister_strike.ogg"
    },
    
    [1776] = {
        key = "Gouge",
        name = "凿击",
        sound = "gouge.ogg",
        aliases = {"gouge"}
    },
    -- ...
}

-- 2. 重新构建映射表
ns.BuildActionMap()

-- 3. ActionMap 自动包含新技能
-- ns.ActionMap["sinister_strike"] = 1752
-- ns.ActionMap["gouge"] = 1776
```

---

## 性能优化

### 优化策略

| 策略 | 效果 |
|------|------|
| 哈希表查询 | O(1) 复杂度 |
| 懒加载反向映射 | 减少启动开销 |
| 预计算蛇形命名 | 避免运行时转换 |

### 性能指标

- **查询耗时**：< 0.01ms（哈希表访问）
- **构建耗时**：< 5ms（800+ 技能）
- **内存占用**：< 50KB（800+ 映射）

---

## 已知限制

1. **同名技能**
   - 不同职业可能有同名技能（如 "Charge"）
   - 需要在 Constants 中明确区分

2. **蛇形转换不完美**
   - 简单正则可能处理不当连续大写（如 "DBM"）
   - 建议手动指定特殊情况

3. **别名冲突**
   - 需手动管理别名，避免冲突
   - 例如 "ms" 可能是 "MortalStrike" 或 "MindSear"

4. **SpellID 变更**
   - 不同服务器版本 SpellID 可能不同
   - 需要维护多版本映射表

---

## 依赖关系

### 依赖的模块
- Constants (SpellID 定义)

### 被依赖的模块
- State (技能可用性查询)
- Grid (槽位绑定)
- Audio (音频播放)
- SimCParser (条件编译时引用)

---

## 相关文档
- [职业模块](12_Class_Modules.md)
- [状态快照系统](07_State.md)
- [网格 UI](10_Grid_UI.md)
- [音频系统](05_Audio.md)
