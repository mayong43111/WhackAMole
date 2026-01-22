# 02 - 配置管理系统详细设计

## 模块概述

**文件**: `src/Core/ProfileManager.lua`

ProfileManager 负责管理插件的所有配置（Profile），包括内置配置和用户配置的加载、保存、校验和查询。

---

## 职责

1. **配置加载**
   - 加载内置配置（职业模块预设）
   - 加载用户配置（数据库中）
   - 职业/专精过滤

2. **配置保存**
   - 保存用户配置到数据库
   - 自动生成配置 ID

3. **配置查询**
   - 根据 ID 查询配置
   - 根据职业/专精查询可用配置
   - 获取默认配置

4. **配置校验**
   - 元信息完整性检查
   - 职业/专精匹配检查
   - 数据结构合法性检查

---

## 配置结构

```lua
profile = {
    id = "mage_fire_default",      -- 唯一标识
    name = "法师 - 火焰",           -- 显示名称
    
    meta = {
        class = "MAGE",            -- 职业 (大写)
        spec = "Fire",             -- 专精
        version = "1.0",           -- 版本号
        author = "WhackAMole",     -- 作者
        type = "builtin",          -- builtin | user
        desc = "默认火焰法配置",    -- 描述
        docs = "..."               -- 完整文档
    },
    
    actions = {                    -- APL 动作列表
        {
            action = "fireball",
            condition = "buff.hot_streak.up"
        },
        {
            action = "pyroblast",
            condition = "buff.hot_streak.down&cooldown.combustion.remains>10"
        },
        -- ...
    },
    
    layout = {                     -- 网格布局
        rows = 3,
        cols = 4,
        iconSize = 40,
        spacing = 6,
        slots = {
            {id = 1, actions = {"fireball"}},
            {id = 2, actions = {"pyroblast"}},
            -- ...
        }
    }
}
```

---

## 初始化流程

```lua
function ProfileManager:Initialize(db)
    self.db = db
    
    -- 1. 加载内置配置（职业模块注册）
    self:LoadBuiltinProfiles()
    
    -- 2. 加载用户配置（数据库）
    self:LoadUserProfiles()
end
```

---

## 配置加载

### 加载内置配置

```lua
function ProfileManager:LoadBuiltinProfiles()
    -- 职业模块注册内置配置
    -- 例如：Classes/Mage.lua 中注册 mage_fire_default
    
    -- 内置配置存储在 ns.BuiltinProfiles
    self.builtinProfiles = ns.BuiltinProfiles or {}
end
```

### 加载用户配置

```lua
function ProfileManager:LoadUserProfiles()
    self.userProfiles = self.db.global.profiles or {}
end
```

---

## 配置查询

### 根据 ID 获取配置

```lua
function ProfileManager:GetProfile(profileID)
    if not profileID then return nil end
    
    -- 1. 优先查询用户配置
    if self.userProfiles[profileID] then
        return self.userProfiles[profileID]
    end
    
    -- 2. 回退到内置配置
    if self.builtinProfiles[profileID] then
        return self.builtinProfiles[profileID]
    end
    
    return nil
end
```

### 获取职业可用配置

```lua
function ProfileManager:GetProfilesForClass(class)
    local profiles = {}
    
    -- 1. 添加内置配置
    for id, profile in pairs(self.builtinProfiles) do
        if profile.meta.class == class then
            table.insert(profiles, profile)
        end
    end
    
    -- 2. 添加用户配置
    for id, profile in pairs(self.userProfiles) do
        if profile.meta.class == class then
            table.insert(profiles, profile)
        end
    end
    
    return profiles
end
```

### 获取专精默认配置

```lua
function ProfileManager:GetBuiltinProfile(spec)
    for id, profile in pairs(self.builtinProfiles) do
        if profile.meta.spec == spec then
            return profile
        end
    end
    return nil
end
```

---

## 配置保存

### 保存用户配置

```lua
function ProfileManager:SaveUserProfile(profile)
    -- 1. 生成 ID（如果没有）
    if not profile.id then
        profile.id = self:GenerateProfileID(profile)
    end
    
    -- 2. 标记为用户配置
    profile.meta.type = "user"
    
    -- 3. 保存到数据库
    self.userProfiles[profile.id] = profile
    self.db.global.profiles = self.userProfiles
    
    return profile.id
end
```

### 生成配置 ID

```lua
function ProfileManager:GenerateProfileID(profile)
    local base = profile.meta.class:lower() .. "_" .. 
                 profile.meta.spec:lower() .. "_user"
    
    local id = base
    local counter = 1
    
    -- 避免 ID 冲突
    while self:GetProfile(id) do
        counter = counter + 1
        id = base .. "_" .. counter
    end
    
    return id
end
```

---

## 配置校验

### 校验完整性

```lua
function ProfileManager:ValidateProfile(profile)
    -- 1. 必需字段检查
    if not profile.meta then
        return false, "Missing meta information"
    end
    
    if not profile.meta.class then
        return false, "Missing class"
    end
    
    if not profile.meta.spec then
        return false, "Missing spec"
    end
    
    if not profile.actions or #profile.actions == 0 then
        return false, "Missing actions"
    end
    
    if not profile.layout or not profile.layout.slots then
        return false, "Missing layout"
    end
    
    -- 2. 职业匹配检查（导入时）
    local _, playerClass = UnitClass("player")
    if profile.meta.class ~= playerClass then
        return false, string.format(
            "Class mismatch: profile is for %s, but you are %s",
            profile.meta.class,
            playerClass
        )
    end
    
    return true, nil
end
```

---

## 配置优先级

**加载顺序**：
1. 用户配置（最高优先级）
2. 内置配置（回退）

**原因**：
- 用户配置可以覆盖内置配置
- 支持自定义与分享

---

## 依赖关系

### 依赖的模块
- AceDB-3.0 (数据持久化)
- Classes (职业模块)

### 被依赖的模块
- Core (配置加载与切换)
- Options UI (配置列表显示)
- Serializer (配置导入导出)

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [序列化与导入导出](04_Serializer.md)
- [配置界面](11_Options_UI.md)
- [职业模块](12_Class_Modules.md)
