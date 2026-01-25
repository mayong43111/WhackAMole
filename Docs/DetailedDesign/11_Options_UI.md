# 11 - 配置界面详细设计

## 模块概述

**主文件**: `src/UI/Options.lua`  
**子模块**: 
- `src/UI/Options/ProfileTab.lua` - 配置选择与导出
- `src/UI/Options/ImportExportTab.lua` - 导入配置
- `src/UI/Options/APLEditorTab.lua` - APL 编辑器
- `src/UI/Options/SettingsTab.lua` - 通用设置
- `src/UI/Options/AboutTab.lua` - 关于信息

Options UI 基于 Ace3 配置系统构建，采用模块化架构，每个标签页独立文件。

---

## 设计理念

- **模块化架构**：每个标签页独立文件，便于维护和扩展
- **层次化组织**：树形布局（childGroups = "tree"），标签页显示在左侧
- **实时反馈**：配置变更立即生效或提示
- **写时复制**：修改内置配置时自动创建用户副本

---

## 主文件结构

`Options.lua` 负责组装完整的 AceConfig 选项表：

```lua
function ns.UI.GetOptionsTable(WhackAMole)
    local args = {}
    args["profiles"] = ns.UI.Options:GetProfileTab(WhackAMole)
    args["import_export"] = ns.UI.Options:GetImportExportTab(WhackAMole)
    args["apl_editor"] = ns.UI.Options:GetAPLEditorTab(WhackAMole)
    args["settings"] = ns.UI.Options:GetSettingsTab(WhackAMole)
    args["about"] = ns.UI.Options:GetAboutTab(WhackAMole)

    return {
        name = "WhackAMole 选项",
        handler = WhackAMole,
        type = "group",
        childGroups = "tree",
        args = args
    }
end
```

---

## 配置选择标签页 (ProfileTab)

### 核心功能
- 动态生成当前职业的配置列表（`ns.ProfileManager:GetProfilesForClass`）
- 切换配置并调用 `WhackAMole:SwitchProfile`
- 显示配置文档（`profile.meta.docs`），管道符 `|` 需转义为 `||`
- **导出配置**: 点击导出按钮弹出对话框，显示可复制的配置字符串

### 关键实现
- **下拉列表**: `type = "select"`，使用 `values` 函数动态生成
- **导出按钮**: `type = "execute"`，调用 `Serializer:ExportProfile` → 弹出 `StaticPopup` 显示字符串
- **文档显示**: `type = "description"`，使用 `name` 函数实时更新
- **数据绑定**: `get/set` 读写 `WhackAMole.db.char.activeProfileID`

### 导出对话框
使用 `StaticPopupDialogs` 创建弹窗：
```lua
StaticPopupDialogs["WHACKAMOLE_EXPORT"] = {
    text = "导出配置字符串（Ctrl+C 复制）:",
    button1 = "关闭",
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        self.editBox:SetText(exportString)
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}
```

---

## 导入配置标签页 (ImportExportTab)

### 核心功能
- **导入流程**: 读取输入 → `Serializer:ImportProfile` → `Serializer:Validate` → `ProfileManager:SaveUserProfile` → `SwitchProfile`
- **自动标记**: 导入的配置自动标记为 `type = "user"`
- **名称规范**: 如果配置名称不是 `[USER]` 开头，自动添加前缀
- **错误处理**: 捕获解析/校验错误，通过 `ns.Logger:System` 显示带颜色的提示信息

### 关键UI元素
- **导入文本框** (`multiline = 25`): 接收用户粘贴的配置字符串
- **导入按钮** (`type = "execute"`): 执行完整的导入+校验+保存+切换流程
- **清空按钮**: 清空文本框内容
- **帮助文档**: 说明如何获取和使用导入字符串

### 导入处理逻辑
```lua
-- 在 Serializer:ImportProfile 中自动处理
if profileTable and profileTable.meta then
    profileTable.meta.type = "user"
    
    -- 强制添加 [USER] 前缀
    if not profileTable.meta.name:match("^%[USER%]") then
        profileTable.meta.name = "[USER] " .. profileTable.meta.name
    end
end
```

**注意**: 导出功能已移至"配置选择"标签页

---

## APL 编辑器标签页 (APLEditorTab)

### 核心功能
- **配置选择**: 下拉列表选择已有配置（内置或用户）
- **新建配置**: 点击"新建配置"按钮创建空白配置
- **五字段编辑**: 
  - 配置名称（单行文本）
  - 职业选择（下拉列表）
  - 天赋选择（下拉列表，根据职业联动）
  - 技能槽列表（逗号分隔，如：`obliterate,frost_strike,howling_blast`）
  - APL脚本（多行文本，25行）
- **职业-天赋联动**: 选择职业后，天赋列表动态更新为该职业的专精
- **自动组装**: 程序根据五个字段自动组装为完整的 Lua 配置结构
- **写时保存**: 所有配置保存时强制添加 `[USER]` 前缀
- **同名覆盖**: 根据配置名称判断是否覆盖已有配置

### 职业-天赋数据映射

内置职业和天赋数据：

| 职业 | 天赋专精 |
|------|---------|
| 战士 (WARRIOR) | 武器 (71), 狂暴 (72), 防护 (73) |
| 圣骑士 (PALADIN) | 神圣 (65), 防护 (66), 惩戒 (70) |
| 猎人 (HUNTER) | 野兽控制 (253), 射击 (254), 生存 (255) |
| 潜行者 (ROGUE) | 刺杀 (259), 战斗 (260), 敏锐 (261) |
| 牧师 (PRIEST) | 戒律 (256), 神圣 (257), 暗影 (258) |
| 死亡骑士 (DEATHKNIGHT) | 鲜血 (250), 冰霜 (251), 邪恶 (252) |
| 萨满祭司 (SHAMAN) | 元素 (262), 增强 (263), 恢复 (264) |
| 法师 (MAGE) | 奥术 (62), 火焰 (63), 冰霜 (64) |
| 术士 (WARLOCK) | 痛苦 (265), 恶魔学识 (266), 毁灭 (267) |
| 德鲁伊 (DRUID) | 平衡 (102), 野性战斗 (103), 恢复 (105) |

### UI元素结构

```lua
args = {
    -- 1. 配置选择区域
    select_header = { type = "header", name = "选择配置" },
    
    profile_select = {
        type = "select",
        name = "基础配置",
        desc = "选择要编辑的配置（内置或用户）",
        values = function() 
            -- 返回所有配置（包括内置）
        end
    },
    
    new_button = {
        type = "execute",
        name = "新建配置",
        desc = "创建一个新的空白配置",
        func = function()
            -- 清空所有字段
            -- 设置默认名称 "[USER] 新配置"
            -- 设置当前职业和天赋
        end
    },
    
    -- 2. 编辑区域
    edit_header = { type = "header", name = "编辑配置" },
    
    config_name = {
        type = "input",
        name = "配置名称",
        desc = "配置的显示名称",
        width = "full"
    },
    
    config_class = {
        type = "select",
        name = "职业",
        desc = "选择配置适用的职业",
        values = CLASS_SPEC_DATA,  -- 所有职业
        set = function(val)
            -- 更新职业
            -- 自动重置天赋为该职业第一个专精
            -- 刷新UI
        end
    },
    
    config_spec = {
        type = "select",
        name = "天赋",
        desc = "选择配置适用的天赋专精",
        values = function()
            -- 根据选中职业动态返回天赋列表
            return CLASS_SPEC_DATA[selectedClass].specs
        end
    },
    
    skill_slots = {
        type = "input",
        name = "技能槽",
        desc = "逗号分隔的技能名称",
        width = "full"
    },
    
    apl_script = {
        type = "input",
        name = "APL 脚本",
        desc = "每行一个动作规则",
        multiline = 25,
        width = "full"
    },
    
    -- 3. 操作区域
    save_button = {
        type = "execute",
        name = "保存配置",
        func = function()
            -- 1. 检查name是否[USER]开头，没有则添加
            -- 2. 解析技能槽（split by comma）
            -- 3. 组装完整配置结构（包括class和spec）
            -- 4. 保存（同名覆盖）
        end
    }
}
```

### 配置组装逻辑

```lua
-- 将五个字段组装为完整配置
function AssembleProfile(name, class, spec, skillSlots, aplScript)
    -- 1. 强制添加 [USER] 前缀
    if not name:match("^%[USER%]") then
        name = "[USER] " .. name
    end
    
    -- 2. 解析技能槽
    local slots = {}
    local slotIndex = 1
    for skill in string.gmatch(skillSlots, "([^,]+)") do
        skill = strtrim(skill)
        if skill ~= "" then
            slots[slotIndex] = { action = skill }
            slotIndex = slotIndex + 1
        end
    end
    
    -- 3. 解析APL（按行分割）
    local aplLines = {}
    for line in aplScript:gmatch("[^\r\n]+") do
        line = strtrim(line)
        if line ~= "" and not line:match("^#") then
            table.insert(aplLines, line)
        end
    end
    
    -- 4. 组装完整结构
    local profile = {
        meta = {
            name = name,
            type = "user",
            class = class,      -- 用户选择的职业
            spec = spec,        -- 用户选择的天赋ID
            author = "User",
            version = 1
        },
        layout = {
            slots = slots
        },
        script = table.concat(aplLines, "\n")
    }
    
    return profile
end
```

### 保存逻辑

```lua
-- 保存配置时的处理
function SaveEditedProfile()
    -- 1. 组装配置（包含职业和天赋）
    local profile = AssembleProfile(name, class, spec, skillSlots, aplScript)
    
    -- 2. 根据name判断是否覆盖
    local existingProfile = ns.ProfileManager:GetProfileByName(profile.meta.name)
    if existingProfile then
        -- 同名配置存在，覆盖
        ns.Logger:System("|cffFFD100WhackAMole:|r 覆盖已有配置: " .. profile.meta.name)
    else
        -- 新配置
        ns.Logger:System("|cff00ff00WhackAMole:|r 创建新配置: " .. profile.meta.name)
    end
    
    -- 3. 保存
    ns.ProfileManager:SaveUserProfile(profile)
    
    -- 4. 切换到新配置
    WhackAMole:SwitchProfile(profile)
    
    -- 5. 刷新UI
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end
```

### 职业-天赋联动逻辑

```lua
-- 职业选择变更时
set = function(_, val)
    editBuffer.class = val
    
    -- 自动重置天赋为该职业第一个专精
    if CLASS_SPEC_DATA[val] and CLASS_SPEC_DATA[val].specs[1] then
        editBuffer.spec = CLASS_SPEC_DATA[val].specs[1].id
    else
        editBuffer.spec = 0
    end
    
    -- 刷新UI以更新天赋下拉列表
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end

-- 天赋下拉列表动态生成
values = function()
    local specs = {}
    local classKey = editBuffer.class
    
    if classKey and CLASS_SPEC_DATA[classKey] then
        for _, specData in ipairs(CLASS_SPEC_DATA[classKey].specs) do
            specs[specData.id] = specData.name
        end
    end
    
    if next(specs) == nil then
        specs[0] = "无"
    end
    
    return specs
end
```

### 设计要点

1. **[USER]前缀强制**: 无论选择内置还是用户配置，保存时都强制添加 `[USER]` 前缀
2. **同名覆盖**: 根据 `meta.name` 判断是否为同名配置，同名则覆盖
3. **选择内置配置**: 可以选择内置配置作为模板，编辑后保存成为用户配置
4. **修改名称**: 修改名称后保存，视为创建新配置（不覆盖原配置）
5. **职业-天赋联动**: 选择职业时自动重置天赋为该职业第一个专精，天赋列表仅显示当前职业的专精
6. **跨职业配置**: 用户可以为任意职业/天赋组合创建配置，不限于当前角色
7. **技能槽格式**: 用户只需输入技能名称列表，程序自动组装为 `layout.slots` 结构
8. **APL格式**: 用户输入纯文本APL，程序自动过滤注释和空行

### 用户体验流程

**编辑内置配置**:
1. 选择内置配置（如：`[内置] 冰霜DK`）
2. 加载配置内容到五个编辑框（包括职业=DEATHKNIGHT, 天赋=冰霜）
3. 修改内容（如修改APL优先级或切换天赋）
4. 保存时自动添加 `[USER]` 前缀 → `[USER] [内置] 冰霜DK`
5. 成为独立的用户配置

**创建新配置**:
1. 点击"新建配置"
2. 清空所有字段，名称默认为 `[USER] 新配置`
3. 职业和天赋默认为当前角色的职业和天赋
4. 填写名称、选择职业/天赋、填写技能槽、APL
5. 保存时检查同名配置，存在则覆盖

**跨职业创建配置**:
1. 当前角色是战士，但想为死亡骑士创建配置
2. 点击"新建配置"
3. 选择职业 → 死亡骑士
4. 天赋列表自动更新为：鲜血、冰霜、邪恶
5. 选择天赋 → 冰霜
6. 填写技能和APL
7. 保存后成为死亡骑士冰霜天赋的配置

**职业切换联动**:
1. 正在编辑一个战士配置
2. 选择职业下拉框 → 切换为法师
3. 天赋自动重置为"奥术"（法师第一个专精）
4. 天赋下拉框更新显示：奥术、火焰、冰霜
5. 可以选择其他天赋继续编辑

**修改名称**:
1. 选择已有配置 `[USER] 我的配置`
2. 修改名称为 `[USER] 我的配置 v2`
3. 保存时视为新配置，不覆盖原配置

---

## 通用设置标签页 (SettingsTab)

### UI元素概览
- **插件启用**: 主开关，控制整个插件功能
  - 禁用时：隐藏动作条、停止技能计算、关闭所有功能
  - 读写 `db.global.enabled`
  - 变更时调用 `WhackAMole:SetEnabled(val)` 切换状态
- **锁定框架**: 切换 `ns.UI.GridState.locked`，调用 `Grid:SetLock`
  - 当插件禁用时自动禁用此选项
- **音频启用**: 读写 `db.global.audio.enabled`
- **音量滑块**: `type = "range"`, min=0, max=1.0, step=0.05
  - 使用 `disabled` 函数联动音频启用状态
- **清空绑定**: 调用 `Grid:ClearAllAssignments()`

### 插件启用/禁用机制

**实现要点**:
```lua
function WhackAMole:SetEnabled(enabled)
    self.db.global.enabled = enabled
    
    if enabled then
        -- 启用：显示网格、启动引擎
        ns.UI.Grid:Show()
        self:StartEngine()
    else
        -- 禁用：隐藏网格、停止引擎
        ns.UI.Grid:Hide()
        self:StopEngine()
    end
end
```

**状态检查**:
- 在 `OnUpdate` 中首先检查 `db.global.enabled`，禁用时跳过所有计算
- 在 `PLAYER_LOGIN` 时根据保存的状态决定是否启动
- 配置界面始终可通过 `/awm` 打开，不受此开关影响

---

## 关于标签页 (AboutTab)

显示版本信息和特性列表，使用 WoW 颜色代码美化文本。

---

## 颜色代码规范

| 颜色 | 代码 | 用途 |
|------|------|------|
| 绿色 | `\|cff00ff00` | 成功消息 |
| 红色 | `\|cffff0000` | 错误消息 |
| 黄色 | `\|cffFFD100` | 标题、重点 |
| 橙色 | `\|cffff8800` | 次级标题 |
| 青色 | `\|cff00ccff` | 品牌色 |
| 重置 | `\|r` | 结束颜色 |

示例：`ns.Logger:System("|cff00ff00WhackAMole:|r 导入成功")`

---

## 技术要点

### 动态内容更新
使用函数返回值实现实时更新：
```lua
name = function()
    return GetCurrentProfileInfo()
end
```

### UI刷新通知
配置变更后调用：
```lua
LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
```

### 错误处理策略
| 场景 | 检测点 | 提示 |
|------|--------|------|
| 空输入 | 导入前 | "请先粘贴配置字符串" |
| 解析失败 | `ImportProfile` | "导入失败: [详情]" |
| 校验失败 | `Validate` | "配置校验失败: [详情]" |
| 编译错误 | `CompileScript` | "APL 语法错误: [详情]" |

### 写时复制机制
```lua
-- 检测内置配置
if profile.meta.type == "builtin" then
    -- 创建副本：id 加 "_user" 后缀
    -- 修改 meta.type = "user"
    -- 添加 " (自定义)" 到名称
    -- 保存并切换
end
```

---

## 模块化架构

### 文件组织
```
src/UI/
├── Options.lua              # 主入口
└── Options/
    ├── ProfileTab.lua       # 配置选择
    ├── ImportExportTab.lua  # 导入/导出
    ├── APLEditorTab.lua     # APL 编辑
    ├── SettingsTab.lua      # 通用设置
    └── AboutTab.lua         # 关于信息
```

### TOC 加载顺序
子模块必须在主文件之前加载：
```toc
src\UI\Options\ProfileTab.lua
src\UI\Options\ImportExportTab.lua
src\UI\Options\APLEditorTab.lua
src\UI\Options\SettingsTab.lua
src\UI\Options\AboutTab.lua
src\UI\Options.lua
```

---

## 依赖关系

### 依赖的库
- **AceConfig-3.0** / **AceConfigDialog-3.0** / **AceConfigRegistry-3.0** - 配置系统
- **AceDB-3.0** - 数据持久化

### 依赖的模块
- **ProfileManager** - 配置管理（获取、保存、验证）
- **Serializer** - 序列化（导入/导出、校验）
- **UI.Grid** - 网格控制（锁定、清空）
- **Logger** - 日志输出
- **Util** - 工具函数（`DeepCopy`）

---

## 已知限制

1. **导入字符串长度**: 聊天框可能截断，建议使用文本编辑器
2. **配置命名冲突**: 用户配置用 `_user` 后缀区分，重复导入会覆盖
3. **无撤销/重做**: 误操作需手动恢复或重新导入
4. **音量控制**: 当前处于禁用状态（预留接口）
5. **插件禁用重启**: 禁用插件后需重新启用才会恢复技能推荐，不会自动恢复

---

## 常见使用场景

### 临时禁用插件
1. 打开配置面板（`/awm`）
2. 在"设置"标签页，取消勾选"启用插件"
3. 动作条隐藏，技能计算停止
4. 需要时重新勾选即可恢复

### 调试与测试
```lua
-- 手动切换插件状态
/run WhackAMole:SetEnabled(false)  -- 禁用
/run WhackAMole:SetEnabled(true)   -- 启用

-- 检查当前状态
/dump WhackAMole.db.global.enabled
```

---

## 调试技巧

```lua
-- 查看当前配置
/dump WhackAMole.db.char.activeProfileID
/dump ns.ProfileManager:GetProfile(WhackAMole.db.char.activeProfileID)

-- 刷新配置界面
/run LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")

-- 强制刷新
/reload
```

---

## 相关文档
- [配置管理系统](02_ProfileManager.md) - 配置的加载、保存、验证
- [序列化与导入导出](04_Serializer.md) - 配置字符串的编解码
- [网格 UI](10_Grid_UI.md) - 技能网格的显示与交互
- [日志系统](06_Logger.md) - 系统消息输出
- [APL 编译器](03_Compiler.md) - APL 脚本编译与执行
