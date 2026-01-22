# 10 - 网格 UI 详细设计

## 模块概述

**文件**: `src/UI/Grid.lua`

Grid UI 是 WhackAMole 的核心交互界面，提供可视化的网格布局来表达键位映射，并通过高亮动画反馈当前推荐动作。

---

## 设计理念

**Show, Don't Tell**：
- 不显示技能图标队列（传统模式）
- 而是高亮玩家键位布局上的对应槽位
- 强化肌肉记忆与键位一致性

---

## 职责

1. **网格渲染与布局**
   - 根据配置动态生成网格按钮
   - 自适应行列计算
   - 响应布局变更（专精切换）

2. **槽位绑定**
   - 拖拽技能/物品到槽位
   - 显示已绑定技能的图标
   - 保存/加载绑定关系

3. **高亮动画**
   - 主要高亮：当前推荐动作（金色像素光）
   - 次要高亮：预测动作（蓝色像素光）
   - 状态跟踪避免动画闪烁

4. **锁定/解锁模式**
   - 锁定：隐藏边框，半透明拖拽把手
   - 解锁：显示边框，完整标题栏，可拖拽移动

5. **右键菜单**
   - 快速访问锁定/解锁
   - 清空动作条
   - 打开配置界面

---

## 核心数据结构

### 网格容器

```lua
container = CreateFrame("Frame", "WhackAMoleFrame", UIParent)
-- 属性：
--   movable: true/false
--   position: {point, x, y}
--   size: 根据 iconSize × cols/rows 计算
```

### 槽位按钮

```lua
slots = {}  -- 数组，索引为槽位 ID

-- 单个 slot 结构：
slot = {
    slotId = 1,                    -- 槽位编号
    frame = <SecureActionButton>,  -- 按钮对象
    ghost = <Texture>,             -- 幽灵图标（拖拽预览）
    actions = {"spell_name"},      -- 绑定的动作列表
}
```

### 高亮状态

```lua
-- 状态跟踪避免重复触发动画
lastActiveSlot = 3        -- 上一帧主要高亮槽位
lastNextSlot = 5          -- 上一帧次要高亮槽位
lastActiveAction = "fireball"  -- 上一帧主要动作
lastNextAction = "pyroblast"   -- 上一帧次要动作
```

---

## 布局算法

### 自适应行列计算

```lua
-- 输入：槽位总数 (count)
-- 输出：cols, rows

if count <= 5 then
    cols = count
    rows = 1
else
    local MAX_COLS = 5
    rows = math.ceil(count / MAX_COLS)
    cols = math.ceil(count / rows)
end
```

### 槽位坐标计算

```lua
-- 槽位 i（从 1 开始）
local col = (i - 1) % cols
local row = math.floor((i - 1) / cols)

-- 像素位置
local x = col * (iconSize + spacing) + (spacing / 2)
local y = -(row * (iconSize + spacing) + (spacing / 2))

btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
```

---

## 拖拽绑定机制

### 拖拽接收器设置

```lua
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnReceiveDrag", function(self)
    local cursorType, cursorInfo = GetCursorInfo()
    
    if cursorType == "spell" then
        -- cursorInfo 是 spellID (数字)
        ns.UI.Grid:UpdateButtonSpell(self, cursorInfo)
        ClearCursor()
    elseif cursorType == "item" then
        -- 支持物品绑定（未来扩展）
    end
end)
```

### 拖拽预览

```lua
btn:SetScript("OnEnter", function(self)
    local cursorType = GetCursorInfo()
    if cursorType then
        -- 显示幽灵图标（半透明预览）
        if self.ghost then
            self.ghost:SetAlpha(0.6)
            LCG.PixelGlow_Start(self, {1, 0.82, 0}, ...)
        end
    end
end)

btn:SetScript("OnLeave", function(self)
    if self.ghost then
        self.ghost:SetAlpha(0.4)
        LCG.PixelGlow_Stop(self)
    end
end)
```

### 绑定更新流程

```lua
function UpdateButtonSpell(btn, spellIdOrName)
    -- 1. 战斗锁定检查
    if InCombatLockdown() then
        print("Cannot change spells in combat!")
        return
    end
    
    -- 2. 获取技能信息
    local name, _, icon = GetSpellInfo(spellIdOrName)
    if not name then return end
    
    -- 3. 设置按钮属性（SecureActionButton）
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", name)
    
    -- 4. 更新图标显示
    local iconTexture = _G[btn:GetName().."Icon"]
    if iconTexture then
        iconTexture:SetTexture(icon)
    end
    
    -- 5. 隐藏幽灵图标
    if btn.ghost then
        btn.ghost:SetAlpha(0)
    end
    
    -- 6. 保存到数据库
    db.assignments[btn.slotId] = name
end
```

---

## 高亮动画系统

### LibCustomGlow 集成

使用 LibCustomGlow-1.0 提供的两种动画：
- **PixelGlow**：像素光（金色/蓝色边缘光效）
- **AutoCastGlow**：自动施法光（旋转光芒）

### 高亮更新逻辑

```lua
function UpdateHighlights(action, nextAction)
    -- 1. 映射动作到槽位
    local activeSlots = FindSlotsForAction(action)
    local nextSlots = FindSlotsForAction(nextAction)
    
    -- 2. 状态跟踪：仅在动作变化时更新
    if action ~= lastActiveAction then
        -- 停止旧高亮
        if lastActiveSlot then
            LCG.PixelGlow_Stop(slots[lastActiveSlot])
        end
        
        -- 启动新高亮（金色像素光）
        if activeSlots[1] then
            LCG.PixelGlow_Start(
                slots[activeSlots[1]],
                {1, 0.82, 0},  -- 金色 RGB
                12,            -- 线条数
                0.25,          -- 频率
                2,             -- 长度
                1              -- 厚度
            )
        end
        
        lastActiveAction = action
        lastActiveSlot = activeSlots[1]
    end
    
    -- 3. 次要高亮（预测）
    if nextAction ~= lastNextAction then
        if lastNextSlot then
            LCG.PixelGlow_Stop(slots[lastNextSlot])
        end
        
        if nextSlots[1] and nextSlots[1] ~= activeSlots[1] then
            LCG.PixelGlow_Start(
                slots[nextSlots[1]],
                {0.3, 0.6, 1},  -- 蓝色 RGB
                8,
                0.15,
                1.5,
                0.8
            )
        end
        
        lastNextAction = nextAction
        lastNextSlot = nextSlots[1]
    end
end
```

### 动作到槽位映射

```lua
function FindSlotsForAction(actionName)
    if not actionName then return {} end
    
    local result = {}
    for i, slot in pairs(slots) do
        -- 检查 slot.actions 是否包含 actionName
        if slot.actions then
            for _, action in ipairs(slot.actions) do
                if action == actionName then
                    table.insert(result, i)
                end
            end
        end
    end
    return result
end
```

---

## 锁定/解锁模式

### 锁定状态 (默认)

```lua
locked = true

-- 视觉效果：
container:EnableMouse(false)      -- 禁用鼠标穿透
bg:Hide()                         -- 隐藏背景边框

-- 拖拽把手样式：
handle:SetSize(20, 20)            -- 小方块
handle:SetAlpha(0.2)              -- 半透明
handle.text:SetText("")           -- 无文字
handle.tex:SetColorTexture(0.3, 0.3, 0.3, 0.3)

-- 鼠标悬停提示：
handle:SetScript("OnEnter", function(f) 
    f:SetAlpha(1.0)  -- 悬停时完全可见
end)
handle:SetScript("OnLeave", function(f) 
    f:SetAlpha(0.2)  -- 恢复半透明
end)
```

### 解锁状态

```lua
locked = false

-- 视觉效果：
container:EnableMouse(true)       -- 启用鼠标交互
bg:Show()                         -- 显示背景边框

-- 拖拽把手样式：
handle:SetPoint("TOPLEFT/TOPRIGHT")  -- 占据整个顶部
handle:SetHeight(18)                 -- 标题栏高度
handle:SetAlpha(1.0)                 -- 完全可见
handle.text:SetText("WhackAMole")    -- 显示标题
handle.tex:SetColorTexture(0.1, 0.1, 0.1, 0.9)  -- 深色背景

-- 拖拽移动：
handle:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
        container:StartMoving()
    end
end)

handle:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
        container:StopMovingOrSizing()
        -- 保存位置到数据库
        local point, _, relPoint, x, y = container:GetPoint()
        db.position = {point = point, x = x, y = y}
    elseif button == "RightButton" then
        OpenContextMenu()
    end
end)
```

---

## 右键菜单

### 菜单结构

```lua
menu = {
    {text = "WhackAMole 选项", isTitle = true},
    {
        text = locked and "解锁框架" or "锁定框架",
        func = function() 
            SetLock(not locked)
        end
    },
    {
        text = "清空动作条",
        func = function() 
            ClearAllAssignments()
        end
    },
    {
        text = "设置 ...",
        func = function() 
            LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
        end
    },
    {text = "取消", func = function() end}
}
```

### 菜单显示

```lua
-- 使用 UIDropDownMenu 系统
local menuFrame = CreateFrame("Frame", "WhackAMoleContextMenu", 
                              UIParent, "UIDropDownMenuTemplate")

UIDropDownMenu_Initialize(menuFrame, function(frame, level)
    for _, item in ipairs(menu) do
        UIDropDownMenu_AddButton(item, level)
    end
end, "MENU")

ToggleDropDownMenu(1, nil, menuFrame, anchor, 0, 0)
```

---

## 重建流程

### Rebuild 触发时机
- 首次加载
- 专精切换
- 配置导入
- 手动刷新

### 重建步骤

```lua
function Rebuild(layout, config)
    -- 1. 隐藏旧网格
    if container then 
        container:Hide() 
    end
    
    -- 2. 计算布局参数
    local iconSize = config.iconSize or 40
    local spacing = config.spacing or 6
    local count = #layout.slots
    local cols, rows = CalculateLayout(count)
    
    -- 3. 创建/更新容器
    if not container then
        container = CreateFrame("Frame", "WhackAMoleFrame", UIParent)
        container:SetMovable(true)
        -- 初始化背景、把手等
    end
    
    -- 4. 调整容器尺寸
    local width = cols * (iconSize + spacing) + spacing
    local height = rows * (iconSize + spacing) + spacing
    container:SetSize(width, height)
    
    -- 5. 创建/复用槽位按钮
    slots = {}
    for i, slotDef in ipairs(layout.slots) do
        local btn = GetOrCreateButton(i)
        btn:SetSize(iconSize, iconSize)
        PositionButton(btn, i, cols, iconSize, spacing)
        ConfigureButton(btn, slotDef)
        slots[i] = btn
    end
    
    -- 6. 恢复位置
    RestorePosition()
    
    -- 7. 恢复绑定
    LoadAssignments()
    
    -- 8. 显示网格
    container:Show()
end
```

---

## 数据持久化

### 保存内容

```lua
db.char = {
    -- 网格位置
    position = {
        point = "CENTER",
        x = 0,
        y = -220
    },
    
    -- 槽位绑定
    assignments = {
        [1] = "Fireball",
        [2] = "Pyroblast",
        [3] = "Fire Blast",
        -- ...
    }
}
```

### 加载时恢复

```lua
function LoadAssignments()
    if not db or not db.assignments then return end
    
    for slotId, spellName in pairs(db.assignments) do
        local btn = slots[slotId]
        if btn then
            UpdateButtonSpell(btn, spellName)
        end
    end
end
```

---

## 战斗锁定限制

### Blizzard 安全机制
- 战斗中不允许修改 SecureActionButton 的属性
- 拖拽绑定、清空动作条等操作被禁止

### 处理策略

```lua
function UpdateButtonSpell(btn, spellId)
    if InCombatLockdown() then
        print("WhackAMole: Cannot change spells in combat!")
        return
    end
    
    -- 继续绑定逻辑...
end
```

---

## 性能优化

### 动画状态跟踪
- 通过 `lastActiveAction/lastNextAction` 避免每帧重复启动动画
- 仅在动作变化时调用 `PixelGlow_Start/Stop`

### 按钮复用
- 创建时优先查找已存在的全局按钮对象
- 避免频繁创建/销毁 Frame

### 条件渲染
- 锁定状态下隐藏不必要的视觉元素（背景、文字）

---

## 已知限制

1. **布局变更限制**
   - 战斗中无法重建网格（SecureActionButton 限制）

2. **高亮冲突**
   - 同一槽位同时绑定多个动作时，仅高亮第一个

3. **Z-Order 问题**
   - 网格可能被其他插件遮挡，需手动调整 strata

4. **性能开销**
   - LibCustomGlow 动画在低端设备可能造成卡顿

---

## 依赖关系

### 依赖的库
- LibCustomGlow-1.0 (高亮动画)
- AceDB-3.0 (数据持久化)
- Blizzard ActionButtonTemplate (按钮模板)

### 被依赖的模块
- Core.lua 调用 `UpdateHighlights()` 更新高亮
- Options.lua 控制锁定状态与配置

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [配置界面](11_Options_UI.md)
- [APL 执行器](09_APLExecutor.md)
- [动作映射](13_ActionMap.md)
