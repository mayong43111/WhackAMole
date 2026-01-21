# WhackAMole WoW API 接口使用分析

本文档详细列出了 `src` 目录下 WhackAMole 项目所使用的 World of Warcraft API 接口及其具体用途。

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

| API | 参数示例 | 用途 |
| :--- | :--- | :--- |
| `GetTime()` | - | 获取当前游戏时间，用于计算冷却和 Buff 剩余时间。 |
| `UnitPower()` | `"player", type` | 获取玩家资源值（法力、怒气、能量、符文能量等）。 |
| `UnitHealth()` | `"target"` | 获取目标当前生命值。 |
| `UnitHealthMax()` | `"target"` | 获取目标最大生命值，结合当前值计算百分比。 |
| `UnitAffectingCombat()` | `"player"` | 检测玩家是否处于战斗状态。 |
| `GetUnitSpeed()` | `"player"` | 检测玩家是否在移动（速度 > 0）。 |
| `UnitExists()` | `"target"` | 判断目标是否存在。 |
| `CheckInteractDistance()` | `"target", index` | 估算与目标的距离（使用交易、观察等特定索引距离判断）。 |
| `UnitAura()` | `"unit", index, filter` | 获取 Unit 的 Buff 信息（名称、持续时间、层数等）。 |
| `UnitDebuff()` | `"target", index` | 获取目标的 Debuff 信息。代码中包含针对 WotLK 私服返回参数偏移的特殊处理。 |

## 3. 技能与冷却 (Spells & Cooldowns)

用于判断技能是否可用、是否冷却完毕。

| API | 参数示例 | 用途 |
| :--- | :--- | :--- |
| `GetSpellInfo()` | `id` or `name` | 获取技能的本地化名称、图标纹理等信息。 |
| `IsUsableSpell()` | `name` | 判断技能当前是否满足使用条件（法力、姿态等）。代码中包含针对战士斩杀(Execute)的特殊修正逻辑。 |
| `GetSpellCooldown()` | `name` | 获取技能的开始冷却时间与持续时间。 |

## 4. 天赋与专精检测 (Talents & Specialization)

位于 `Core/SpecDetection.lua`，用于在 3.3.5 版本（无直接 Spec API）中推断玩家天赋。

| API | 参数示例 | 用途 |
| :--- | :--- | :--- |
| `UnitClass()` | `"player"` | 获取玩家职业。 |
| `GetActiveTalentGroup()` | - | 获取当前启用的双天赋索引 (1 或 2)。 |
| `GetTalentTabInfo()` | `tabIndex` | 获取特定天赋树投入的点数，用于判断主专精。 |
| `GetNumTalents()` | `tabIndex` | 获取某系天赋的总数，用于遍历扫描。 |
| `GetTalentInfo()` | `tab, index` | 获取具体某个天赋的等级，用于深度扫描检测。 |
| `UnitLevel()` | `"player"` | 获取玩家等级，用于低等级下的逻辑降级处理。 |

## 5. 界面与安全模板 (UI & Secure Actions)

位于 `UI/Grid.lua`，用于创建和管理动作条按钮。

| API | 描述 / 用途 |
| :--- | :--- |
| `InCombatLockdown()` | 检查是否处于战斗锁定状态。战斗中无法修改安全按钮属性。 |
| `SetAttribute("type", "spell")` | **主要机制**：设置按钮为施法类型。 |
| `SetAttribute("spell", name)` | **主要机制**：设置按钮点击时释放的具体技能名称。 |
| `SetPoint()`, `SetSize()` | 设置 UI 元素的位置和大小。 |
| `SetScript() / HookScript()` | 处理 UI 交互事件（如 `OnEnter` 显示提示, `OnLeave` 隐藏）。 |
| `SetAlpha()` | 控制透明度，实现锁定/解锁时的视觉反馈。 |
| `_G[name]` | 通过全局环境查找按钮对应的 Icon 纹理对象进行更新。 |

## 6. 其他常用工具 (Utilities)

| API | 用途 |
| :--- | :--- |
| `print()` | 输出调试信息到聊天框。 |
| `C_Timer.After()` | 延时执行函数，用于等待数据加载。 |
| `date()` | 获取格式化后的日期时间字符串。 |
| `tostring()`, `tonumber()` | 类型转换，确保数据安全。 |
| `pairs()`, `ipairs()`, `next()` | 表遍历。 |
| `pcall()` | 保护模式调用函数，用于安全执行 APL 条件逻辑。 |

---
**生成时间**: 2026-01-21
**分析工具**: Copilot Agent
