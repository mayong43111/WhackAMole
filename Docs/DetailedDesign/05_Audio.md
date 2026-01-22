# 05 - 音频系统详细设计

## 模块概述

**文件**: `src/Core/Audio.lua`

Audio 模块负责播放技能名称语音提示，提供可选的音频反馈通道，并通过节流机制避免重复播报。

---

## 设计目标

1. **非侵入性**：音频是可选功能，不影响核心决策
2. **易用性**：通过动作名自动解析音频文件
3. **性能优先**：节流避免音频风暴
4. **可扩展性**：支持未来的音量控制等特性

---

## 职责

1. **音频播放**
   - 根据动作名播放对应音频文件
   - 支持 SpellID 直接播放（向后兼容）

2. **节流机制**
   - 同一动作 2 秒内仅播放一次
   - 防止重复播报

3. **配置控制**
   - 全局开关（启用/禁用）
   - 音量控制（预留）

4. **反向映射**
   - SpellID → ActionName 转换

---

## 核心数据结构

### 节流表

```lua
throttle = {
    ["fireball"] = 12345.67,   -- 上次播放时间戳
    ["pyroblast"] = 12347.45,
    -- ...
}

THROTTLE_TIME = 2.0  -- 节流间隔（秒）
```

### 音频文件映射

```lua
-- 定义在 Constants.lua
ns.Spells = {
    [133] = {  -- Fireball SpellID
        key = "Fireball",
        sound = "fireball.ogg"  -- 音频文件名
    },
    [11366] = {  -- Pyroblast
        key = "Pyroblast",
        sound = "pyroblast.ogg"
    },
    -- ...
}
```

---

## 播放流程

### PlayByAction (主要接口)

```lua
function Audio:PlayByAction(actionName)
    -- 1. 检查主开关
    local db = ns.WhackAMole and ns.WhackAMole.db
    if not db or not db.global.audio or not db.global.audio.enabled then
        return
    end
    
    -- 2. 检查音量设置
    local volume = db.global.audio.volume or 1.0
    if volume <= 0 then return end
    
    -- 3. 解析 ActionName → SpellID
    local spellID = ns.ActionMap and ns.ActionMap[actionName]
    if not spellID then return end
    
    -- 4. 获取音频文件名
    local soundFile = nil
    if ns.Spells and ns.Spells[spellID] and ns.Spells[spellID].sound then
        soundFile = ns.Spells[spellID].sound
    end
    
    if not soundFile then return end
    
    -- 5. 检查节流
    local now = GetTime()
    if throttle[actionName] and (now - throttle[actionName] < THROTTLE_TIME) then
        return  -- 2 秒内已播放，跳过
    end
    
    -- 6. 播放音频
    local path = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\" .. soundFile
    PlaySoundFile(path, "Master")
    
    -- 注意：WotLK 的 PlaySoundFile 不支持音量参数
    -- 音量设置预留给未来版本或其他实现方式
    
    -- 7. 更新节流表
    throttle[actionName] = now
    lastPlayedAction = actionName
end
```

---

## 播放触发点

### Core.lua 中的集成

```lua
function WhackAMole:OnUpdate(elapsed)
    -- ... 帧循环逻辑 ...
    
    -- 1. 执行 APL 决策
    local action = self:RunHandler()
    
    -- 2. 更新 UI 高亮
    ns.UI.Grid:UpdateHighlights(action, nextAction)
    
    -- 3. 触发音频提示
    if action then
        ns.Audio:PlayByAction(action)
    end
    
    -- ...
end
```

---

## 反向映射（向后兼容）

### Play by SpellID

```lua
function Audio:Play(spellID)
    if not spellID then return end
    
    -- 1. 构建反向映射表（懒加载）
    if not ns.ReverseActionMap then
        ns.ReverseActionMap = {}
        if ns.ActionMap then
            for action, id in pairs(ns.ActionMap) do
                ns.ReverseActionMap[id] = action
            end
        end
    end
    
    -- 2. SpellID → ActionName
    local actionName = ns.ReverseActionMap[spellID]
    
    -- 3. 调用主接口
    if actionName then
        self:PlayByAction(actionName)
    end
end
```

---

## 配置控制

### 全局开关

```lua
-- 数据库结构
db.global.audio = {
    enabled = false,    -- 默认关闭
    volume = 1.0        -- 音量（0.0 - 1.0）
}

-- 检查开关
if not db.global.audio.enabled then
    return  -- 音频已禁用
end
```

### 音量控制（预留）

```lua
-- 当前 WotLK API 限制：
-- PlaySoundFile(path, channel) 不支持音量参数
-- 
-- 未来可能的实现方式：
-- 1. 使用 SetCVar("Sound_MasterVolume", volume)（全局影响）
-- 2. 预处理音频文件（不同音量版本）
-- 3. 使用第三方音频库
```

---

## 节流机制

### 设计目标
- 防止同一技能在短时间内重复播报
- 降低音频风暴对性能的影响

### 实现逻辑

```lua
function CheckThrottle(actionName)
    local now = GetTime()
    local lastPlayed = throttle[actionName]
    
    -- 检查距离上次播放的时间
    if lastPlayed and (now - lastPlayed < THROTTLE_TIME) then
        return false  -- 节流中，禁止播放
    end
    
    return true  -- 允许播放
end

function UpdateThrottle(actionName)
    throttle[actionName] = GetTime()
end
```

### 节流时间选择

- **2.0 秒**：平衡响应性与避免重复
- 大多数技能 GCD 1.5 秒，2 秒可以覆盖一次技能施放周期

---

## 音频文件管理

### 文件结构

```
Sounds/
├── fireball.ogg
├── pyroblast.ogg
├── combustion.ogg
├── execute.ogg
└── ...
```

### 命名规范

- 使用 `.ogg` 格式（WoW 支持）
- 文件名与 `ns.Spells[spellID].sound` 字段对应
- 小写 + 下划线命名（如 `fire_blast.ogg`）

### 音频来源

- 游戏内提取（DBM/WeakAuras 音频）
- TTS 生成（文字转语音）
- 自定义录制

---

## 调试功能

### 手动清除节流

```lua
function Audio:ClearThrottle(actionName)
    if actionName then
        throttle[actionName] = nil
    else
        throttle = {}  -- 清空所有
    end
end
```

### 查询最后播放

```lua
function Audio:GetLastPlayed()
    return lastPlayedAction
end

-- 使用示例
/run print(ns.Audio:GetLastPlayed())
```

---

## 初始化

```lua
function Audio:Initialize()
    -- 1. 确保配置结构存在
    local db = ns.WhackAMole and ns.WhackAMole.db
    if db and db.global and db.global.audio then
        -- 2. 设置默认音量
        db.global.audio.volume = db.global.audio.volume or 1.0
    end
    
    -- 3. 清空节流表
    throttle = {}
    lastPlayedAction = nil
end
```

---

## 性能优化

### 优化策略

| 策略 | 效果 |
|------|------|
| 节流机制 | 降低 80% 音频调用 |
| 懒加载反向映射 | 减少启动开销 |
| 快速路径检查 | 开关关闭时零开销 |

### 性能指标

- **播放检查耗时**：< 0.1ms（开关关闭）
- **播放触发耗时**：< 0.2ms（节流命中）
- **实际播放耗时**：< 1ms（API 调用）

---

## 已知限制

1. **音量控制不可用**
   - WotLK API 限制，无法独立控制音量
   - 音量设置预留给未来扩展

2. **音频文件固定**
   - 需要手动添加音频文件到 Sounds/ 目录
   - 无法动态生成或在线下载

3. **节流粒度固定**
   - 2 秒间隔对所有技能统一
   - 未来可支持按技能配置

4. **多语言支持**
   - 当前仅提供中文/英文音频
   - 需要为每种语言准备音频文件

---

## 配置界面集成

### Options.lua 中的音频控制

```lua
audio_group = {
    type = "group",
    name = "音频",
    order = 5,
    args = {
        audio_enabled = {
            type = "toggle",
            name = "启用语音提示",
            desc = "播放技能名称语音",
            get = function()
                return WhackAMole.db.global.audio.enabled
            end,
            set = function(_, val)
                WhackAMole.db.global.audio.enabled = val
            end
        },
        audio_volume = {
            type = "range",
            name = "音量",
            desc = "调整语音提示音量（预留功能）",
            min = 0.0,
            max = 1.0,
            step = 0.1,
            get = function()
                return WhackAMole.db.global.audio.volume
            end,
            set = function(_, val)
                WhackAMole.db.global.audio.volume = val
            end,
            disabled = true  -- 当前不可用
        }
    }
}
```

---

## 依赖关系

### 依赖的模块
- Constants (音频文件映射)
- ActionMap (动作名到 SpellID 转换)

### 被依赖的模块
- Core (主循环中调用播放)
- Options UI (音频开关控制)

---

## 扩展方向

### 未来可能的功能

1. **音量控制**
   - 通过第三方库实现
   - 或使用预处理的不同音量音频文件

2. **自定义音频**
   - 允许用户替换音频文件
   - 提供音频包导入功能

3. **多语言音频**
   - 根据客户端语言自动选择
   - 社区贡献音频包

4. **音频队列**
   - 同时触发多个技能时排队播放
   - 避免声音重叠

---

## 相关文档
- [生命周期与主控制器](01_Core_Lifecycle.md)
- [配置界面](11_Options_UI.md)
- [动作映射](13_ActionMap.md)
