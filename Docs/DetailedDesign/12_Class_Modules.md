# 12 - 职业模块详细设计

## 模块概述

**文件**: `src/Classes/*.lua`

职业模块为每个职业/专精提供技能映射、天赋定义和默认配置，实现模块化的职业支持。

---

## 文件结构

```
Classes/
├── Registry.lua          # 职业注册中心
├── Mage.lua             # 法师模块
├── Warrior.lua          # 战士模块
├── Paladin.lua          # 圣骑士模块
├── DeathKnight.lua      # 死亡骑士模块
└── ...
```

---

## 职业模块结构

### 模块模板

```lua
local _, ns = ...
local ClassModule = {}

-- 职业信息
ClassModule.class = "MAGE"
ClassModule.localizedName = "法师"

-- SpellID 映射表（按专精划分）
ClassModule.SpellIDs = {
    Fire = {
        Fireball = 133,
        Pyroblast = 11366,
        FireBlast = 2136,
        Combustion = 11129,
        Scorch = 2948,
        -- ...
    },
    Frost = {
        Frostbolt = 116,
        IceLance = 30455,
        -- ...
    },
    Arcane = {
        ArcaneBlast = 30451,
        ArcaneMissiles = 5143,
        -- ...
    }
}

-- 天赋定义
ClassModule.Talents = {
    Fire = {
        {name = "Improved Fireball", ranks = 5},
        {name = "Hot Streak", ranks = 1},
        -- ...
    }
}

-- 默认 APL（按专精）
ClassModule.DefaultAPL = {
    Fire = {
        {action = "fireball", condition = "buff.hot_streak.up"},
        {action = "pyroblast", condition = "buff.hot_streak.down&cooldown.combustion.remains>10"},
        {action = "combustion", condition = "target.health.pct<35"},
        -- ...
    }
}

-- 默认布局
ClassModule.DefaultLayout = {
    Fire = {
        rows = 3,
        cols = 4,
        iconSize = 40,
        spacing = 6,
        slots = {
            {id = 1, actions = {"fireball"}},
            {id = 2, actions = {"pyroblast"}},
            {id = 3, actions = {"fire_blast"}},
            {id = 4, actions = {"combustion"}},
            -- ...
        }
    }
}

-- 注册到系统
ns.ClassRegistry:Register(ClassModule)
```

---

## 注册机制

### Registry.lua

```lua
local _, ns = ...
ns.ClassRegistry = {}

local registeredClasses = {}

-- 注册职业模块
function ns.ClassRegistry:Register(module)
    registeredClasses[module.class] = module
end

-- 获取职业模块
function ns.ClassRegistry:GetModule(class)
    return registeredClasses[class]
end

-- 获取 SpellID
function ns.ClassRegistry:GetSpellID(class, spec, actionName)
    local module = registeredClasses[class]
    if not module then return nil end
    
    local specData = module.SpellIDs[spec]
    if not specData then return nil end
    
    return specData[actionName]
end
```

---

## SpellID 映射表

### 设计原则
- 按专精划分（一个职业有多个专精）
- 使用统一的动作名（小写+下划线）
- 支持多个 SpellID（不同等级）

### 示例

```lua
SpellIDs = {
    Fire = {
        -- 基础技能
        fireball = 133,
        pyroblast = 11366,
        fire_blast = 2136,
        
        -- 冷却技能
        combustion = 11129,
        icy_veins = 12472,
        
        -- Buff
        hot_streak = 48108,
        pyroblast_buff = 48108,
    }
}
```

---

## 天赋定义

### 结构

```lua
Talents = {
    Fire = {
        -- 天赋名 → 最大等级
        {name = "Improved Fireball", ranks = 5},
        {name = "Impact", ranks = 3},
        {name = "Hot Streak", ranks = 1},
        -- ...
    }
}
```

### 用途
- 专精识别（天赋指纹）
- APL 条件判断（talent.hot_streak.enabled）

---

## 默认配置生成

### 生成内置配置

```lua
function ClassModule:GenerateBuiltinProfiles()
    local profiles = {}
    
    for spec, apl in pairs(self.DefaultAPL) do
        local profile = {
            id = self.class:lower() .. "_" .. spec:lower() .. "_default",
            name = self.localizedName .. " - " .. spec,
            
            meta = {
                class = self.class,
                spec = spec,
                version = "1.0",
                author = "WhackAMole",
                type = "builtin",
                desc = spec .. " 专精默认配置"
            },
            
            actions = apl,
            layout = self.DefaultLayout[spec]
        }
        
        table.insert(profiles, profile)
    end
    
    return profiles
end
```

---

## 加载流程

```lua
-- 插件启动时加载所有职业模块
ns.ClassRegistry:Register(require("Classes.Mage"))
ns.ClassRegistry:Register(require("Classes.Warrior"))
ns.ClassRegistry:Register(require("Classes.Paladin"))
ns.ClassRegistry:Register(require("Classes.DeathKnight"))

-- 生成内置配置
local _, playerClass = UnitClass("player")
local module = ns.ClassRegistry:GetModule(playerClass)

if module then
    local profiles = module:GenerateBuiltinProfiles()
    for _, profile in ipairs(profiles) do
        ns.ProfileManager:RegisterBuiltinProfile(profile)
    end
end
```

---

## 扩展新职业

### 步骤

1. 创建 `Classes/NewClass.lua`
2. 定义 SpellIDs、Talents、DefaultAPL、DefaultLayout
3. 调用 `ns.ClassRegistry:Register(module)`
4. 在 `WhackAMole.toc` 中添加文件

---

## 已知限制

1. **SpellID 维护成本**
   - 需要手动查询每个技能的 SpellID
   - 不同版本可能不同

2. **天赋指纹不稳定**
   - 玩家可能点出非标准天赋树
   - 需要定期更新指纹

3. **默认 APL 简化**
   - 仅提供基础逻辑
   - 高端玩家需自定义

---

## 依赖关系

### 被依赖的模块
- ProfileManager (注册内置配置)
- ActionMap (SpellID 查询)
- SpecDetection (天赋匹配)

---

## 相关文档
- [配置管理系统](02_ProfileManager.md)
- [专精检测](03_SpecDetection.md)
- [动作映射](13_ActionMap.md)
