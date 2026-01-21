# WhackAMole WoW API 接口使用分析

本文档详细列出了 WhackAMole 插件（`src` 目录）所使用的 World of Warcraft API 接口及其具体用途。PoC 验证工具用于验证这些 API 的正确使用方法。

---

## WhackAMole API 使用总览

### 已验证的核心 API

以下 API 已通过 PoC 验证工具验证其正确使用方法：

| API | 用途 | 验证工具 | 状态 |
| :--- | :--- | :--- | :--- |
| `CheckInteractDistance()` | 距离检测 | PoC_Range | ✅ 已验证 |
| `IsUsableSpell()` | 技能可用性判断 | PoC_Spells | ✅ 已验证 |
| `GetSpellCooldown()` | 技能冷却时间 | PoC_Spells | ✅ 已验证 |
| `UnitCastingInfo()` | 施法状态检测（读条） | PoC_Spells | ✅ 已验证 |
| `UnitChannelInfo()` | 施法状态检测（引导） | PoC_Spells | ✅ 已验证 |
| `GetTalentInfo()` | 天赋点数扫描 | PoC_Talents | ✅ 已验证 |
| `GetTalentTabInfo()` | 天赋树投入点数 | PoC_Talents | ✅ 已验证 |
| `GetNumTalents()` | 天赋总数 | PoC_Talents | ✅ 已验证 |
| `GetActiveTalentGroup()` | 双天赋切换 | PoC_Talents | ✅ 已验证 |
| `UnitAura()` | 光环扫描（Buff/Debuff） | PoC_UnitState | ✅ 已验证 |
| `UnitHealth()` | 生命值获取 | PoC_UnitState | ✅ 已验证 |
| `UnitPower()` | 资源值获取 | PoC_UnitState | ✅ 已验证 |
| `UnitExists()` | 单位存在性检查 | PoC_UnitState | ✅ 已验证 |

### 使用中的其他 API

以下 API 在 WhackAMole 中使用，但暂未通过专门的 PoC 验证：

**基础框架库：**
- `LibStub`, `AceAddon-3.0`, `AceConsole-3.0`, `AceEvent-3.0`, `AceDB-3.0`, `AceConfig-3.0`, `AceConfigDialog-3.0`, `LibCustomGlow-1.0`

**单位状态 API：**
- `GetTime()`, `UnitHealthMax()`, `UnitAffectingCombat()`, `GetUnitSpeed()`, `UnitDebuff()`, `UnitClass()`, `UnitLevel()`

**技能相关 API：**
- `GetSpellInfo()`

**UI 与安全模板 API：**
- `CreateFrame()`, `InCombatLockdown()`, `SetAttribute()`, `SetPoint()`, `SetSize()`, `SetScript()`, `HookScript()`, `SetAlpha()`, `_G[name]`

**工具函数：**
- `print()`, `C_Timer.After()`, `date()`, `tostring()`, `tonumber()`, `pairs()`, `ipairs()`, `next()`, `pcall()`

---

## 目录

1. [基础框架与库](#1-基础框架与库-libraries--infrastructure)
2. [玩家与目标状态](#2-玩家与目标状态-unit--state-apis)
3. [技能与冷却](#3-技能与冷却-spells--cooldowns)
4. [天赋与专精检测](#4-天赋与专精检测-talents--specialization)
5. [界面与安全模板](#5-界面与安全模板-ui--secure-actions)
6. [其他常用工具](#6-其他常用工具-utilities)
7. [PoC 验证工具说明](#7-poc-验证工具说明)

---

## 1. 基础框架与库 (Libraries & Infrastructure)

项目主要依赖 **Ace3** 框架进行插件的初始化、配置管理和事件处理。

| API / Library | 用途 | 所在文件 |
| :--- | :--- | :--- |
| `LibStub` | 库版本管理，用于加载其他依赖库。 | `Core.lua` |
| `AceAddon-3.0` | 插件核心框架，提供 `NewAddon` 方法创建插件实例。 | `Core.lua` |
| `AceConsole-3.0` | 注册聊天命令 (`/wam`)。 | `Core.lua` |
| `AceEvent-3.0` | 事件监听与分发 (虽在代码中引用，但主要通过框架处理)。 | `Core.lua` |
| `AceDB-3.0` | 数据库管理 (`SavedVariables`)，用于保存配置文件和角色设置。 | `Core.lua` |
| `AceConfig-3.0` | 配置表注册，生成插件设置界面。 | `Core.lua` |
| `AceConfigDialog-3.0` | 将配置表添加到暴雪默认的界面选项中。 | `Core.lua` |
| `LibCustomGlow-1.0` | (UI) 用于在技能图标上显示高亮发光效果。 | `UI/Grid.lua` |

## 2. 玩家与目标状态 (Unit & State APIs)

主要集中在 `Engine/State.lua` 中，用于实时抓取游戏状态（快照）。

| API | 参数示例 | 用途 | 所在文件 |
| :--- | :--- | :--- | :--- |
| `GetTime()` | - | 获取当前游戏时间，用于计算冷却和 Buff 剩余时间。 | `Engine/State.lua` |
| `UnitPower()` | `"player", type` | 获取玩家资源值（法力、怒气、能量、符文能量等）。 | `Engine/State.lua` |
| `UnitHealth()` | `"target"` | 获取目标当前生命值。 | `Engine/State.lua` |
| `UnitHealthMax()` | `"target"` | 获取目标最大生命值，结合当前值计算百分比。 | `Engine/State.lua` |
| `UnitAffectingCombat()` | `"player"` | 检测玩家是否处于战斗状态。 | `Engine/State.lua` |
| `GetUnitSpeed()` | `"player"` | 检测玩家是否在移动（速度 > 0）。 | `Engine/State.lua` |
| `UnitExists()` | `"target"` | 判断目标是否存在。 | `Engine/State.lua` |
| `CheckInteractDistance()` | `"target", index` | 估算与目标的距离（使用交易、观察等特定索引距离判断）。 | `Engine/State.lua` |
| `UnitAura()` | `"unit", index, filter` | 获取 Unit 的 Buff 信息（名称、持续时间、层数等）。 | `Engine/State.lua` |
| `UnitDebuff()` | `"target", index` | 获取目标的 Debuff 信息。代码中包含针对 WotLK 私服返回参数偏移的特殊处理。 | `Engine/State.lua` |

## 3. 技能与冷却 (Spells & Cooldowns)

用于判断技能是否可用、是否冷却完毕。

| API | 参数示例 | 用途 | 所在文件 |
| :--- | :--- | :--- | :--- |
| `GetSpellInfo()` | `id` or `name` | 获取技能的本地化名称、图标纹理等信息。 | `Engine/State.lua`, `UI/Grid.lua` |
| `IsUsableSpell()` | `name` | 判断技能当前是否满足使用条件（法力、姿态等）。代码中包含针对战士斩杀(Execute)的特殊修正逻辑。 | `Engine/State.lua` |
| `GetSpellCooldown()` | `name` | 获取技能的开始冷却时间与持续时间。返回 `(start, duration, enabled)`。 | `Engine/State.lua` |

## 4. 天赋与专精检测 (Talents & Specialization)

位于 `UI/Grid.lua`，用于创建和管理动作条按钮。

| API | 描述 / 用途 | 所在文件 |
| :--- | :--- | :--- |
| `CreateFrame()` | 创建 UI 框架元素（Frame、Button、FontString 等）。 | `UI/Grid.lua` |
| `InCombatLockdown()` | 检查是否处于战斗锁定状态。战斗中无法修改安全按钮属性。 | `UI/Grid.lua` |
| `SetAttribute("type", "spell")` | **主要机制**：设置按钮为施法类型。 | `UI/Grid.lua` |
| `SetAttribute("spell", name)` | **主要机制**：设置按钮点击时释放的具体技能名称。 | `UI/Grid.lua` |
| `SetPoint()`, `SetSize()` | 设置 UI 元素的位置和大小。 | `UI/Grid.lua` |
| `SetScript()` / `HookScript()` | 处理 UI 交互事件（如 `OnEnter` 显示提示, `OnLeave` 隐藏）。 | `UI/Grid.lua` |
| `SetAlpha()` | 控制透明度，实现锁定/解锁时的视觉反馈。 | `UI/Grid.lua` |
| `_G[name]` | 通过全局环境查找按钮对应的 Icon 纹理对象进行更新。 | `UI/Grid.lua` |

## 6. 其他常用工具 (Utilities)

## 6. 其他常用工具 (Utilities)

| API | 用途 | 所在文件 |
| :--- | :--- | :--- |
| `print()` | 输出调试信息到聊天框。 | 多个文件 |
| `C_Timer.After()` | 延时执行函数，用于等待数据加载。 | `Core.lua` |
| `date()` | 获取格式化后的日期时间字符串。 | `Core/SpecDetection.lua` |
| `tostring()`, `tonumber()` | 类型转换，确保数据安全。 | 多个文件 |
| `pairs()`, `ipairs()`, `next()` | 表遍历。 | 多个文件 |
| `pcall()` | 保护模式调用函数，用于安全执行 APL 条件逻辑。 | `Engine/APL.lua` |

---

## 7. PoC 验证工具说明

PoC（Proof of Concept）验证工具用于验证 WhackAMole 使用的 WoW API 的正确使用方法。每个 PoC 专注验证特定的 API 集合，确保插件能够准确可靠地使用这些接口。

### 7.1 PoC_Range - 距离检测验证

**验证目标：** `CheckInteractDistance` API 的使用方法

**验证内容：**
- 通过不同 index 参数检测 5 个距离区间（0-5码、5-10码、10-11码、11-28码、>28码）
- 验证距离检测的准确性和可靠性
- 测试距离判断逻辑在实际游戏中的表现

**验证逻辑：**
```lua
-- 通过多个索引检测判断距离区间
local checks = {
    [4] = CheckInteractDistance("target", 4),  -- < 5 码
    [3] = CheckInteractDistance("target", 3),  -- < 10 码
    [2] = CheckInteractDistance("target", 2),  -- < 11 码
    [1] = CheckInteractDistance("target", 1),  -- < 28 码
}

-- 距离越近，越多的 check 为 true
if checks[4] then return "0-5码"
elseif checks[3] then return "5-10码"
elseif checks[2] then return "10-11码"
elseif checks[1] then return "11-28码"
else return ">28码"
end
```

**配置参数：**
- 更新频率：0.2秒（5 FPS，低性能消耗）
- 实时显示当前距离区间和所有检测点状态
- 深色主题UI，可拖动，带关闭按钮

### 7.2 PoC_Spells - 技能状态检测验证

**验证目标：** `IsUsableSpell`、`GetSpellCooldown`、`UnitCastingInfo`、`UnitChannelInfo` API

**验证内容：**
- 技能可用性判断（区分可用、资源不足、条件不满足三种状态）
- 技能冷却时间计算（自动排除 GCD ≤1.5秒）
- 施法状态检测（读条技能和引导法术）

**验证要点：**
- `IsUsableSpell` 返回 `(usable, nomana)` 两个值
- `GetSpellCooldown` 返回 `(start, duration, enabled)` 三个值
- `UnitCastingInfo` 和 `UnitChannelInfo` 检测当前施法状态

**状态显示：**
- **绿色背景** - 技能就绪（usable=true）
- **蓝色背景** - 冷却中（显示剩余秒数）
- **紫色背景** - 资源不足（nomana=true）
- **暗红色背景** - 不可用（条件不满足）
- **黄色背景** - 正在释放中（施法或引导）

**配置参数：**
- 更新频率：0.1秒
- 监控战士技能：致死打击(12294)、猛击(1464)、斩杀(5308)、利刃风暴(46924)

### 7.3 PoC_Talents - 天赋检测验证

**验证目标：** `GetTalentInfo`、`GetTalentTabInfo`、`GetNumTalents`、`GetActiveTalentGroup` API

**验证内容：**
- 天赋点数扫描和天赋树识别
- 双天赋切换检测
- Titan 服务器 API 参数偏移处理
- 天赋变化轮询机制

**验证机制：**
- 构建天赋指纹（Fingerprint）：`"G1:000123...|000456...|..."`
- 2秒轮询间隔检测天赋更改
- 检测到变化后延迟1秒扫描（避免数据未就绪）
- 登录后延迟2秒进行首次扫描

**兼容性处理：**
- 实现 C_Timer.After 兼容层（WotLK 3.3.5 原生不支持）
- 处理 `GetTalentTabInfo` 参数偏移问题

### 7.4 PoC_UnitState - 单位状态与光环验证

**验证目标：** `UnitAura`、`UnitHealth`、`UnitPower`、`UnitExists` API

**验证内容：**
- Buff/Debuff 光环扫描（最多40个槽位）
- 生命值和资源值获取
- 光环施法者识别
- WotLK 3.3.5 光环 API 返回值顺序差异处理

**验证要点：**
- 光环事件节流：0.5秒（防止事件风暴）
- 显示施法者标签（玩家/宠物/其他单位）
- 格式化时间显示（剩余/总时长）
- 处理 WotLK 私服 Debuff 返回参数偏移

---

### PoC 工具设计原则

1. **单一职责**：每个 PoC 专注验证特定 API 集合
2. **实时监控**：所有 PoC 都提供可视化实时数据显示
3. **低性能消耗**：使用节流机制（0.1-0.5秒更新间隔）
4. **兼容性处理**：针对 WotLK 3.3.5 和 Titan 服务器的特殊处理
5. **代码优雅**：采用 CONFIG 表、模块化函数、职责单一原则

---

**生成时间**: 2026-01-21  
**分析范围**: src/ 目录（主要） + PoCs/ 验证工具（辅助）  
**分析工具**: GitHub Copilot
