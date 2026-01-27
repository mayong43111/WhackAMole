# 12 - 职业模块详细设计

## 模块概述

**文件**: `src/Classes/*.lua`

职业模块负责：
1. **专精检测**：通过天赋特征技能识别玩家当前专精
2. **专精配置**：定义各专精的元数据（名称、技能列表）
3. **职业特殊逻辑**：通过钩子系统处理职业特殊机制（如战士斩杀条件）

---

## 文件结构

```
Classes/
├── Registry.lua          # 专精检测注册中心
├── Mage.lua             # 法师模块
├── Warrior.lua          # 战士模块（包含特殊逻辑钩子）
├── Paladin.lua          # 圣骑士模块
├── DeathKnight.lua      # 死亡骑士模块
├── Druid.lua            # 德鲁伊模块
└── ...
```

---

## 核心组件

### 1. 专精检测注册机制

**设计目标**：通过特征技能动态识别玩家专精，避免硬编码或手动配置。

**设计目标**：通过特征技能动态识别玩家专精，避免硬编码或手动配置。

#### Registry.lua 接口

```lua
local _, ns = ...
ns.SpecRegistry = {}
ns.SpecRegistry.handlers = {}

-- 注册专精检测函数
function ns.SpecRegistry:Register(class, func)
    self.handlers[class] = func
end

-- 执行专精检测
function ns.SpecRegistry:Detect(class)
    local func = self.handlers[class]
    if func then
        return func()  -- 返回 specID (如 62, 63, 64)
    end
    return nil
end
```

#### 职业文件中的注册示例

```lua
-- Mage.lua
ns.SpecRegistry:Register("MAGE", function()
    if IsPlayerSpell(44425) then return 62 end  -- Arcane: Arcane Barrage
    if IsPlayerSpell(44457) then return 63 end  -- Fire: Living Bomb
    if IsPlayerSpell(44572) then return 64 end  -- Frost: Deep Freeze
    return nil
end)
```

**检测原理**：
- 使用 `IsPlayerSpell(spellID)` 检查玩家是否学会特定天赋技能
- 按专精优先级顺序检查，返回第一个匹配的 SpecID
- SpecID 为 WoW 标准专精 ID（如法师奥术=62、火焰=63、冰霜=64）

---

### 2. 职业数据结构

```lua
ns.Classes = {
    MAGE = {
        [62] = { name = "奥术法师", spells = {...} },  -- ⚠️ spells 是否使用待确认
        [63] = { name = "火焰法师", spells = {...} },
        [64] = { name = "冰霜法师", spells = {...} },
    },
    WARRIOR = {
        [71] = { name = "武器战", spells = {...} },
        [72] = { name = "狂怒战", spells = {...} },
        [73] = { name = "防护战", spells = {...} },
    },
    -- ...
}
### 2. 职业数据结构

各职业模块通过 `ns.Classes` 命名空间注册专精元数据：

```lua
ns.Classes = {
    MAGE = {
        [62] = { name = "奥术法师", spells = {...} },
        [63] = { name = "火焰法师", spells = {...} },
        [64] = { name = "冰霜法师", spells = {...} },
    },
    WARRIOR = {
        [71] = { name = "武器战", spells = {...} },
        [72] = { name = "狂怒战", spells = {...} },
        [73] = { name = "防护战", spells = {...} },
    },
    -- ...
}
```

**字段说明**：
- `name`：专精本地化名称（用于 UI 显示）
- `spells`：技能数据表（SpellID → {key, sound}）

**设计考虑**：
- `spells` 字段与 `Constants.lua` 中的全局 `ns.Spells` 存在功能重叠
- 可考虑替换为 `spellIDs = {5308, 12294, ...}` 仅存储 ID 列表，通过全局表查询详情

---

### 3. 技能数据查询接口

系统提供多层级的技能数据查询接口，支持不同场景需求：

系统提供多层级的技能数据查询接口，支持不同场景需求：

```lua
-- 1. 通过 SpellID 查询完整技能数据（用于音频系统）
local spellData = ns.Spells[5308]
-- 返回: { key = "Execute", sound = "Execute.ogg" }

-- 2. 通过 Key 查询 SpellID（CamelCase 格式）
local spellID = ns.ID.Execute  -- 5308

-- 3. 通过 SimC 动作名查询 SpellID（snake_case 格式）
local spellID = ns.ActionMap["execute"]  -- 5308

-- 4. 反向查询：SpellID → SimC 动作名
local actionName = ns.ReverseActionMap[5308]  -- "execute"
```

**数据源**：所有映射表在 `Constants.lua` 中统一维护和自动生成：

```lua
-- Constants.lua 自动生成逻辑
ns.ID = {}        -- CamelCase Key → SpellID
ns.ActionMap = {} -- snake_case 动作名 → SpellID

for id, data in pairs(ns.Spells) do
    if data.key then
        ns.ID[data.key] = id                        -- Execute → 5308
        ns.ActionMap[CamelToSnake(data.key)] = id   -- execute → 5308
    end
end
```

---

### 4. 职业特殊逻辑扩展（钩子系统）

部分职业有特殊机制无法通过通用系统处理，通过钩子系统实现扩展。

#### 示例：战士斩杀可用性检查

**问题**：斩杀技能仅在目标血量 < 20% 或拥有猝死 Buff 时可用，但 WoW API 不提供此信息。

**解决方案**：通过 `check_spell_usable` 钩子手动检查条件。

```lua
-- Warrior.lua
ns.RegisterHook("check_spell_usable", function(event, spellID, spellName, usable, nomana)
    if spellID ~= ns.ID.Execute then return nil end
    
    -- 检查特殊条件
    local cond_hp = (state.target.health.pct < 20)
    local cond_sd = HasBuff(ns.ID.SuddenDeath)
    
    if cond_hp or cond_sd then
        -- 满足条件时，手动检查资源
        local hasRage = (state.rage >= 10)
        return { usable = hasRage, nomana = not hasRage }
    end
    
    -- 不满足条件时，使用原始判断
    return nil
end)
```

#### 示例：技能效果模拟

```lua
-- 战士斩杀后清除猝死 Buff
ns.RegisterHook("runHandler", function(event, actionName)
    if actionName ~= "execute" then return end
    
    -- 清除 Buff 缓存，避免下次判断错误
    if ns.ID.SuddenDeath then
        local buffCache = state.player.buff.__cache
        if buffCache then
            buffCache[ns.ID.SuddenDeath] = nil
        end
    end
end)
```

**钩子类型**：
- `check_spell_usable`：技能可用性检查扩展
- `runHandler`：技能施放后的状态清理
- （未来扩展）`SimulateSpecialEffect`：预测系统中的技能效果模拟

---

## 职业模块实现模板

### 基础模板（纯数据配置）

```lua
-- Classes/Mage.lua
local _, ns = ...

-- 初始化命名空间
ns.Classes = ns.Classes or {}
ns.Classes.MAGE = {}

-- 专精检测
ns.SpecRegistry:Register("MAGE", function()
    if IsPlayerSpell(44425) then return 62 end  -- Arcane
    if IsPlayerSpell(44457) then return 63 end  -- Fire
    if IsPlayerSpell(44572) then return 64 end  -- Frost
    return nil
end)

-- 专精配置
ns.Classes.MAGE[62] = { name = "奥术法师" }
ns.Classes.MAGE[63] = { name = "火焰法师" }
ns.Classes.MAGE[64] = { name = "冰霜法师" }
```

### 扩展模板（包含特殊逻辑）

```lua
-- Classes/Warrior.lua
local _, ns = ...

ns.Classes = ns.Classes or {}
ns.Classes.WARRIOR = {}

-- 专精检测
ns.SpecRegistry:Register("WARRIOR", function()
    if IsPlayerSpell(46924) then return 71 end  -- Arms
    if IsPlayerSpell(46917) then return 72 end  -- Fury
    if IsPlayerSpell(46968) then return 73 end  -- Prot
    return nil
end)

-- 专精配置
ns.Classes.WARRIOR[71] = { name = "武器战" }
ns.Classes.WARRIOR[72] = { name = "狂怒战" }
ns.Classes.WARRIOR[73] = { name = "防护战" }

-- 特殊逻辑钩子
ns.RegisterHook("check_spell_usable", function(event, spellID, spellName, usable, nomana)
    if spellID ~= ns.ID.Execute then return nil end
    -- ... 战士斩杀条件检查
end)

ns.RegisterHook("runHandler", function(event, actionName)
    if actionName ~= "execute" then return end
    -- ... 猝死 Buff 清理
end)
```

---

## 已实现职业

| 职业 | 文件 | 专精检测 | 特殊逻辑 | 备注 |
|------|------|----------|----------|------|
| Mage | Mage.lua | ✅ | ❌ | 纯数据配置 |
| Warrior | Warrior.lua | ✅ | ✅ | Execute 钩子 |
| Druid | Druid.lua | ✅ | ❌ | 多形态职业 |
| DeathKnight | DeathKnight.lua | ✅ | ❌ | 符文系统 |
| Paladin | Paladin.lua | ✅ | ❌ | 标准配置 |

---

## 设计优势

1. **模块化**：每个职业独立文件，职责清晰
2. **可扩展**：通过钩子系统支持职业特殊逻辑，不影响核心系统
3. **自动检测**：基于天赋特征技能识别专精，无需手动配置
4. **统一接口**：所有职业遵循相同的结构规范，易于维护
5. **集中数据源**：技能数据在 `Constants.lua` 统一管理，避免分散

---

## 设计限制

### 1. 专精检测依赖天赋

- **限制**：检测基于特定天赋技能，玩家非标准天赋树可能识别失败
- **影响范围**：极少数使用非主流天赋的玩家
- **缓解措施**：可提供手动切换专精的 UI 选项（未实现）

### 2. 跨版本兼容性

- **限制**：SpellID 在不同 WoW 版本（正式服/怀旧服/私服）可能不同
- **维护成本**：需要为不同版本维护独立的 SpellID 映射表
- **建议**：使用 [WoWHead](https://wowhead.com) 或游戏内 `/dump GetSpellInfo(技能名)` 查询正确 ID

### 3. 钩子系统性能考虑

- **限制**：钩子在每次技能检查时触发，需保持轻量级
- **最佳实践**：
  - 使用早期返回（`return nil`）快速过滤无关技能
  - 避免在钩子中进行复杂计算或 I/O 操作
  - 缓存计算结果以减少重复查询

---

## 依赖关系

### 上游依赖
- `Core/Constants.lua`：全局技能数据库（`ns.Spells`、`ns.ID`、`ns.ActionMap`）
- `Core/Lifecycle.lua`：钩子系统支持（`ns.RegisterHook`）

### 下游依赖
- `Engine/State.lua`：使用 `ns.SpecRegistry:Detect()` 获取专精 ID
- `Core/Audio.lua`：使用 `ns.Spells` 查询音频文件
- `UI` 模块：使用 `ns.Classes[class][specID].name` 显示专精名称

---

## 扩展新职业指南

### 步骤

1. **创建职业文件** `Classes/NewClass.lua`
   ```lua
   local _, ns = ...
   ns.Classes = ns.Classes or {}
   ns.Classes.NEWCLASS = {}
   ```

2. **注册专精检测**
   ```lua
   ns.SpecRegistry:Register("NEWCLASS", function()
       if IsPlayerSpell(xxxxx) then return specID1 end
       if IsPlayerSpell(yyyyy) then return specID2 end
       return nil
   end)
   ```

3. **定义专精配置**
   ```lua
   ns.Classes.NEWCLASS[specID] = {
       name = "专精名称",
   }
   ```

4. **（可选）添加特殊逻辑钩子**
   ```lua
   ns.RegisterHook("check_spell_usable", function(...) end)
   ns.RegisterHook("runHandler", function(...) end)
   ```

5. **在 `WhackAMole.toc` 中添加文件**
   ```
   src\Classes\NewClass.lua
   ```

### 查找特征技能

使用以下方法确定专精特征技能：
1. 查看天赋树最后一层（51 点天赋）的终极技能
2. 游戏内使用 `/dump GetSpellInfo("技能名")` 获取 SpellID
3. 在 [WoWHead Talent Calculator](https://wowhead.com/wotlk/talent-calc) 确认天赋 ID

---

## 相关文档
- [07 - State](07_State.md) - 状态系统（钩子调用方）
- [15 - 预测系统](15_Prediction_System.md) - 职业特殊效果模拟扩展点
- [Constants.lua](../Reference/Constants.md) - 统一技能数据源
