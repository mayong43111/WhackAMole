# 11 - 配置界面详细设计

## 模块概述

**文件**: `src/UI/Options.lua`

Options UI 基于 Ace3 配置系统构建，提供完整的插件配置界面，包括配置选择、APL 编辑、布局管理、导入/导出和音频控制。

---

## 设计理念

- **层次化组织**：按功能分组（配置选择、APL 编辑、布局、导入导出、音频）
- **实时反馈**：配置变更立即生效或提示
- **用户友好**：提供语法帮助、错误提示、默认值重置

---

## 职责

1. **配置选择**
   - 显示当前可用配置列表
   - 切换配置
   - 显示配置元信息

2. **APL 编辑**
   - 25 行多行文本编辑器
   - 实时语法验证
   - 语法帮助文档
   - 重置为默认

3. **布局管理**
   - 显示当前布局信息
   - 清空绑定
   - 锁定/解锁网格

4. **导入/导出**
   - 导出当前配置为压缩字符串
   - 从字符串导入配置
   - 校验与错误提示

5. **音频控制**
   - 启用/禁用语音提示
   - 音量控制（预留）

---

## 界面结构

### AceConfig 配置表结构

```lua
options = {
    type = "group",
    name = "WhackAMole",
    args = {
        profiles = {
            type = "group",
            name = "配置选择",
            order = 1,
            args = { ... }
        },
        apl_editor = {
            type = "group",
            name = "APL 编辑",
            order = 2,
            args = { ... }
        },
        layout = {
            type = "group",
            name = "布局管理",
            order = 3,
            args = { ... }
        },
        import_export = {
            type = "group",
            name = "导入/导出",
            order = 4,
            args = { ... }
        },
        audio = {
            type = "group",
            name = "音频",
            order = 5,
            args = { ... }
        }
    }
}
```

---

## 配置选择组

### UI 元素

#### 配置下拉列表

```lua
profile_select = {
    type = "select",
    name = "当前配置",
    desc = "选择您的专精逻辑",
    width = "full",
    
    -- 动态生成选项列表
    values = function()
        local profiles = ns.ProfileManager:GetProfilesForClass(playerClass)
        local options = {}
        for _, p in ipairs(profiles) do
            options[p.id] = p.name
        end
        return options
    end,
    
    -- 获取当前值
    get = function() 
        return WhackAMole.db.char.activeProfileID 
    end,
    
    -- 设置新值
    set = function(_, val)
        WhackAMole.db.char.activeProfileID = val
        local profile = ns.ProfileManager:GetProfile(val)
        if profile then
            WhackAMole:SwitchProfile(profile)
        end
    end
}
```

#### 配置信息显示

```lua
profile_info = {
    type = "description",
    name = function()
        local profile = WhackAMole.currentProfile
        if not profile then 
            return "未选择配置" 
        end
        
        return string.format([[
|cff00ff00当前配置|r: %s
|cff808080类型|r: %s
|cff808080专精|r: %s
|cff808080版本|r: %s
        ]],
        profile.name,
        profile.meta.type == "builtin" and "内置" or "用户",
        profile.meta.spec or "未知",
        profile.meta.version or "1.0"
        )
    end,
    fontSize = "medium"
}
```

---

## APL 编辑组

### UI 元素

#### 多行文本编辑器

```lua
apl_text = {
    type = "input",
    name = "优先级列表",
    desc = "每行一条规则，格式: action,if=condition",
    width = "full",
    multiline = 25,  -- 25 行高度
    
    get = function()
        local profile = WhackAMole.currentProfile
        if not profile or not profile.actions then 
            return "" 
        end
        
        -- 将 actions 表转为文本
        local lines = {}
        for _, action in ipairs(profile.actions) do
            local line = action.action
            if action.condition and action.condition ~= "" then
                line = line .. ",if=" .. action.condition
            end
            table.insert(lines, line)
        end
        return table.concat(lines, "\n")
    end,
    
    set = function(_, val)
        -- 解析文本为 actions 表
        local lines = {strsplit("\n", val)}
        local actions = {}
        
        for _, line in ipairs(lines) do
            line = strtrim(line)
            if line ~= "" and not line:match("^#") then
                local action, condition = ParseAPLLine(line)
                table.insert(actions, {
                    action = action,
                    condition = condition or ""
                })
            end
        end
        
        -- 更新配置
        if WhackAMole.currentProfile then
            WhackAMole.currentProfile.actions = actions
            -- 重新编译
            WhackAMole:RecompileAPL()
        end
    end
}
```

#### 语法验证提示

```lua
apl_validate = {
    type = "execute",
    name = "验证语法",
    desc = "检查 APL 语法是否正确",
    func = function()
        local profile = WhackAMole.currentProfile
        if not profile then 
            print("未选择配置")
            return 
        end
        
        local errors = ns.SimCParser.ValidateAPL(profile.actions)
        if #errors == 0 then
            print("|cff00ff00✓|r APL 语法正确")
        else
            print("|cffff0000✗|r 发现 " .. #errors .. " 个错误:")
            for i, err in ipairs(errors) do
                print("  行 " .. err.line .. ": " .. err.message)
            end
        end
    end
}
```

#### 语法帮助

```lua
apl_help = {
    type = "description",
    name = [[
|cffFFD100语法示例:|r

actions+=/fireball,if=buff.hot_streak.up
actions+=/pyroblast,if=buff.hot_streak.down&cooldown.combustion.remains>10
actions+=/combustion,if=target.health.pct<35

|cffFFD100条件语法:|r
- buff.<name>.up/down/remains
- cooldown.<name>.ready/remains
- resource.pct (mana/energy/rage/runic_power)
- target.health.pct
- target.casting

|cffFFD100操作符:|r
- & (与), | (或), ! (非)
- >, <, >=, <=, =, !=
- ( ) 分组
    ]],
    fontSize = "small"
}
```

#### 重置按钮

```lua
apl_reset = {
    type = "execute",
    name = "重置为默认",
    desc = "恢复当前专精的默认 APL",
    confirm = true,
    func = function()
        local spec = ns.SpecDetection:GetCurrentSpec()
        local defaultProfile = ns.ProfileManager:GetBuiltinProfile(spec)
        
        if defaultProfile then
            WhackAMole.currentProfile.actions = CopyTable(defaultProfile.actions)
            WhackAMole:RecompileAPL()
            LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
            print("已重置为默认 APL")
        end
    end
}
```

---

## 布局管理组

### UI 元素

#### 布局信息

```lua
layout_info = {
    type = "description",
    name = function()
        local profile = WhackAMole.currentProfile
        if not profile or not profile.layout then 
            return "未加载布局" 
        end
        
        local layout = profile.layout
        return string.format([[
|cff00ff00当前布局|r:
  槽位数: %d
  行数: %d
  列数: %d
  图标大小: %d
        ]],
        #layout.slots,
        layout.rows or 0,
        layout.cols or 0,
        layout.iconSize or 40
        )
    end
}
```

#### 清空绑定按钮

```lua
layout_clear = {
    type = "execute",
    name = "清空所有绑定",
    desc = "移除所有槽位的技能绑定",
    confirm = true,
    func = function()
        ns.UI.Grid:ClearAllAssignments()
    end
}
```

#### 锁定/解锁开关

```lua
layout_lock = {
    type = "toggle",
    name = "锁定框架",
    desc = "锁定后无法拖动框架",
    get = function()
        return ns.UI.Grid.isLocked()
    end,
    set = function(_, val)
        ns.UI.Grid:SetLock(val)
    end
}
```

---

## 导入/导出组

### UI 元素

#### 导出文本框

```lua
export_text = {
    type = "input",
    name = "导出字符串",
    desc = "复制此字符串分享给他人",
    width = "full",
    multiline = 5,
    
    get = function()
        local profile = WhackAMole.currentProfile
        if not profile then 
            return "未选择配置" 
        end
        
        -- 序列化 + 压缩 + 编码
        local serialized = ns.Serializer:Serialize(profile)
        local compressed = ns.Serializer:Compress(serialized)
        local encoded = ns.Serializer:Encode(compressed)
        
        return encoded
    end,
    
    set = function() end  -- 只读
}
```

#### 导出按钮

```lua
export_button = {
    type = "execute",
    name = "生成导出字符串",
    desc = "将当前配置转为字符串",
    func = function()
        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
        print("已生成导出字符串，请复制上方文本框内容")
    end
}
```

#### 导入文本框

```lua
import_text = {
    type = "input",
    name = "导入字符串",
    desc = "粘贴配置字符串到此处",
    width = "full",
    multiline = 5,
    
    get = function()
        return WhackAMole.importBuffer or ""
    end,
    
    set = function(_, val)
        WhackAMole.importBuffer = val
    end
}
```

#### 导入按钮

```lua
import_button = {
    type = "execute",
    name = "导入配置",
    desc = "从字符串加载配置",
    func = function()
        local str = WhackAMole.importBuffer
        if not str or str == "" then
            print("|cffff0000错误:|r 请先粘贴配置字符串")
            return
        end
        
        -- 解码 + 解压 + 反序列化
        local success, profile = pcall(function()
            local decoded = ns.Serializer:Decode(str)
            local decompressed = ns.Serializer:Decompress(decoded)
            return ns.Serializer:Deserialize(decompressed)
        end)
        
        if not success then
            print("|cffff0000错误:|r 配置字符串无效")
            return
        end
        
        -- 校验配置
        local valid, err = ns.ProfileManager:ValidateProfile(profile)
        if not valid then
            print("|cffff0000错误:|r " .. err)
            return
        end
        
        -- 保存为用户配置
        profile.meta.type = "user"
        ns.ProfileManager:SaveUserProfile(profile)
        
        -- 切换到新配置
        WhackAMole:SwitchProfile(profile)
        
        print("|cff00ff00✓|r 配置已导入: " .. profile.name)
        WhackAMole.importBuffer = ""
    end
}
```

---

## 音频控制组

### UI 元素

#### 启用开关

```lua
audio_enabled = {
    type = "toggle",
    name = "启用语音提示",
    desc = "播放技能名称语音",
    width = "full",
    
    get = function()
        return WhackAMole.db.global.audio.enabled
    end,
    
    set = function(_, val)
        WhackAMole.db.global.audio.enabled = val
        if ns.Audio then
            ns.Audio:SetEnabled(val)
        end
    end
}
```

#### 音量滑块（预留）

```lua
audio_volume = {
    type = "range",
    name = "音量",
    desc = "调整语音提示音量",
    min = 0.0,
    max = 1.0,
    step = 0.1,
    
    get = function()
        return WhackAMole.db.global.audio.volume
    end,
    
    set = function(_, val)
        WhackAMole.db.global.audio.volume = val
        if ns.Audio then
            ns.Audio:SetVolume(val)
        end
    end,
    
    disabled = true  -- 当前未实现音量控制
}
```

---

## 配置编辑保护

### 内置配置写时复制

```lua
-- 当用户尝试编辑内置配置时，自动创建副本
function EnsureEditableProfile(profile)
    if profile.meta.type == "builtin" then
        -- 创建用户副本
        local userProfile = CopyTable(profile)
        userProfile.id = profile.id .. "_user"
        userProfile.name = profile.name .. " (自定义)"
        userProfile.meta.type = "user"
        
        -- 保存并切换
        ns.ProfileManager:SaveUserProfile(userProfile)
        WhackAMole:SwitchProfile(userProfile)
        
        print("已创建可编辑副本: " .. userProfile.name)
        return userProfile
    end
    return profile
end
```

---

## 实时刷新机制

### AceConfig 通知

```lua
-- 配置变更后通知 UI 刷新
LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
```

### 自动刷新字段

```lua
-- 使用函数返回值实现动态内容
profile_info = {
    type = "description",
    name = function()
        -- 每次渲染时重新计算
        return GetCurrentProfileInfo()
    end
}
```

---

## 错误处理

### 导入错误类型

| 错误类型 | 原因 | 提示信息 |
|---------|------|---------|
| 解码失败 | 字符串格式错误 | "配置字符串无效或已损坏" |
| 解压失败 | 压缩数据损坏 | "配置数据解压失败" |
| 反序列化失败 | Lua 语法错误 | "配置数据格式错误" |
| 校验失败 | 缺少必需字段 | "配置缺少必需字段: xxx" |
| 职业不匹配 | 职业/专精不符 | "此配置适用于 Mage，但您是 Warrior" |

### 错误提示样式

```lua
-- 成功：绿色 + ✓
print("|cff00ff00✓|r 配置已导入")

-- 错误：红色 + ✗
print("|cffff0000✗|r 配置字符串无效")

-- 警告：黄色 + !
print("|cffFFD100!|r 此配置可能已过期")
```

---

## 性能优化

1. **延迟加载**
   - 配置面板打开时才构建选项表
   - 使用 `function()` 包装返回值

2. **避免重复编译**
   - APL 文本变更后仅在 `set` 回调时编译
   - 验证语法不触发编译

3. **缓存配置列表**
   - `GetProfilesForClass()` 结果在职业内固定

---

## 依赖关系

### 依赖的库
- AceConfig-3.0 (配置框架)
- AceConfigDialog-3.0 (配置对话框)
- AceConfigRegistry-3.0 (配置注册)
- AceDB-3.0 (数据持久化)

### 依赖的模块
- ProfileManager (配置管理)
- Serializer (导入导出)
- SimCParser (APL 验证)
- Audio (音频控制)
- UI.Grid (网格控制)

---

## 已知限制

1. **战斗中编辑限制**
   - APL 可随时编辑，但槽位绑定受战斗锁定限制

2. **导入字符串长度**
   - 聊天框可能截断超长字符串，需分段复制

3. **配置冲突检测**
   - 当前未检测同名配置覆盖问题

4. **撤销/重做**
   - 不支持编辑历史，误操作需手动恢复

---

## 相关文档
- [配置管理系统](02_ProfileManager.md)
- [序列化与导入导出](04_Serializer.md)
- [网格 UI](10_Grid_UI.md)
- [SimC 解析器](08_SimCParser.md)
- [音频系统](05_Audio.md)
