# WhackAMole WoW API 接口使用分析

本文档详细列出了 WhackAMole 项目（包括 `src` 目录和 `PoCs` 验证工具）所使用的 World of Warcraft API 接口及其具体用途。

---

## 目录

1. [基础框架与库](#1-基础框架与库-libraries--infrastructure)
2. [玩家与目标状态](#2-玩家与目标状态-unit--state-apis)
3. [技能与冷却](#3-技能与冷却-spells--cooldowns)
4. [施法状态检测](#4-施法状态检测-casting-detection)
5. [天赋与专精检测](#5-天赋与专精检测-talents--specialization)
6. [距离检测](#6-距离检测-range-detection)
7. [光环（Buff/Debuff）扫描](#7-光环buffdebuff扫描)
8. [界面与安全模板](#8-界面与安全模板-ui--secure-actions)
9. [定时器与兼容性](#9-定时器与兼容性)
10. [其他常用工具](#10-其他常用工具-utilities)

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

用于判断技能是否可用、是否冷却完毕。**PoC_Spells** 专门验证这些核心 API。

| API | 参数示例 | 用途 | 验证工具 |
| :--- | :--- | :--- | :--- |
| `GetSpellInfo()` | `id` or `name` | 获取技能的本地化名称、图标纹理等信息。 | PoC_Spells, src |
| `IsUsableSpell()` | `name` | 判断技能当前是否满足使用条件（法力、姿态等）。代码中包含针对战士斩杀(Execute)的特殊修正逻辑。 | PoC_Spells, src |
| `GetSpellCooldown()` | `name` | 获取技能的开始冷却时间与持续时间。返回 `(start, duration, enabled)`。 | PoC_Spells, src |

**PoC_Spells 验证要点：**
- 区分可用(`usable=true`)、资源不足(`nomana=true`)、条件不满足(`usable=false, nomana=false`)三种状态
- 自动排除 GCD（公共冷却时间 ≤1.5秒）
- 实时更新频率：0.1秒
- 监控的战士技能：致死打击(12294)、猛击(1464)、斩杀(5308)、利刃风暴(46924)

## 4. 施法状态检测 (Casting Detection)

检测玩家是否正在施法或引导技能。**PoC_Spells** 验证施法状态 API。

| API | 参数 | 返回值 | 用途 | 验证工具 |
| :--- | :--- | :--- | :--- | :--- |
| `UnitCastingInfo()` | `"player"` | `name, text, texture, startTime, endTime, isTradeSkill, castID, interrupt` | 获取正在施放的技能信息（读条技能）。如果未在施法则返回 `nil`。 | PoC_Spells |
| `UnitChannelInfo()` | `"player"` | `name, text, texture, startTime, endTime, isTradeSkill, interrupt` | 获取正在引导的技能信息（引导法术）。如果未在引导则返回 `nil`。 | PoC_Spells |

**PoC_Spells 验证逻辑：**
```lua
-- 检查技能是否正在施法
local castName = UnitCastingInfo("player")
local channelName = UnitChannelInfo("player")
if (castName == spellName) or (channelName == spellName) then
    -- 显示黄色背景 "Casting..."
end
```

## 5. 天赋与专精检测 (Talents & Specialization)

## 5. 天赋与专精检测 (Talents & Specialization)

位于 `Core/SpecDetection.lua`，用于在 3.3.5 版本（无直接 Spec API）中推断玩家天赋。**PoC_Talents** 专门验证天赋检测 API。

| API | 参数示例 | 用途 | 验证工具 |
| :--- | :--- | :--- | :--- |
| `UnitClass()` | `"player"` | 获取玩家职业。 | src, PoC_Talents |
| `GetActiveTalentGroup()` | - | 获取当前启用的双天赋索引 (1 或 2)。 | src, PoC_Talents |
| `GetTalentTabInfo()` | `tabIndex` | 获取特定天赋树投入的点数，用于判断主专精。 | src, PoC_Talents |
| `GetNumTalents()` | `tabIndex` | 获取某系天赋的总数，用于遍历扫描。 | src, PoC_Talents |
| `GetTalentInfo()` | `tab, index` | 获取具体某个天赋的等级，用于深度扫描检测。 | src, PoC_Talents |
| `UnitLevel()` | `"player"` | 获取玩家等级，用于低等级下的逻辑降级处理。 | src, PoC_UnitState |

**PoC_Talents 验证机制：**
- 构建天赋指纹（Fingerprint）：`"G1:000123...|000456...|..."`，快速比对天赋变化
- 2秒轮询间隔检测天赋更改
- 检测到变化后延迟1秒扫描（避免数据未就绪）
- 处理 Titan 服务器的 `GetTalentTabInfo` 参数偏移问题
- 登录后延迟2秒进行首次扫描

## 6. 距离检测 (Range Detection)

**PoC_Range** 专门验证 WotLK 3.3.5 的距离检测 API。

| API | 参数 | 返回值 | 用途 | 验证工具 |
| :--- | :--- | :--- | :--- | :--- |
| `CheckInteractDistance()` | `"target", index` | `boolean` | 估算与目标的距离。通过不同的 index 参数判断特定距离阈值。 | PoC_Range, src |

**CheckInteractDistance 索引说明：**
| Index | 距离阈值 | 对应交互 | 验证结果 |
| :--- | :--- | :--- | :--- |
| 4 | < 5码 | Follow（跟随） | PoC_Range |
| 3 | < 10码 | Duel（决斗） | PoC_Range |
| 2 | < 11码 | Trade（交易） | PoC_Range |
| 1 | < 28码 | Inspect（观察） | PoC_Range |

**PoC_Range 验证逻辑：**
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

**PoC_Range 配置：**
- 更新频率：0.2秒（5 FPS，低性能消耗）
- 实时显示当前距离区间和所有检测点状态
- 深色主题UI，可拖动，带关闭按钮

## 7. 光环（Buff/Debuff）扫描

**PoC_UnitState** 验证单位状态和光环扫描 API。

| API | 参数 | 返回值 | 用途 | 验证工具 |
| :--- | :--- | :--- | :--- | :--- |
| `UnitAura()` | `"unit", index, filter` | `name, rank, icon, count, type, duration, expires, caster, ...` | 获取 Unit 的 Buff/Debuff 信息（名称、持续时间、层数、施法者等）。 | PoC_UnitState, src |
| `UnitBuff()` | `"unit", index` | 同 `UnitAura` | 专门获取 Buff（增益效果）。 | PoC_UnitState |
| `UnitDebuff()` | `"target", index` | 同 `UnitAura` | 获取目标的 Debuff 信息。代码中包含针对 WotLK 私服返回参数偏移的特殊处理。 | PoC_UnitState, src |

**PoC_UnitState 验证要点：**
- 最多扫描 40 个光环槽位（`MAX_AURA_SCAN = 40`）
- 光环事件节流：0.5秒（防止事件风暴）
- 处理 WotLK 3.3.5 光环 API 返回值顺序差异
- 显示施法者标签（玩家/宠物/其他单位）
- 格式化时间显示（剩余/总时长）

## 8. 界面与安全模板 (UI & Secure Actions)

## 8. 界面与安全模板 (UI & Secure Actions)

位于 `UI/Grid.lua`，用于创建和管理动作条按钮。所有 PoC 工具都使用基础 UI API。

| API | 描述 / 用途 | 使用位置 |
| :--- | :--- | :--- |
| `CreateFrame()` | 创建 UI 框架元素（Frame、Button、FontString 等）。 | 所有 PoC, src |
| `InCombatLockdown()` | 检查是否处于战斗锁定状态。战斗中无法修改安全按钮属性。 | src/UI |
| `SetAttribute("type", "spell")` | **主要机制**：设置按钮为施法类型。 | src/UI |
| `SetAttribute("spell", name)` | **主要机制**：设置按钮点击时释放的具体技能名称。 | src/UI |
| `SetPoint()`, `SetSize()` | 设置 UI 元素的位置和大小。 | 所有 PoC, src |
| `SetScript()` / `HookScript()` | 处理 UI 交互事件（如 `OnEnter` 显示提示, `OnLeave` 隐藏，`OnUpdate` 更新循环）。 | 所有 PoC, src |
| `SetAlpha()` | 控制透明度，实现锁定/解锁时的视觉反馈。 | src/UI |
| `CreateTexture()` | 创建纹理层（背景、边框、图标等）。 | 所有 PoC |
| `SetTexture()` / `SetColorTexture()` | 设置纹理内容或纯色。 | 所有 PoC |
| `SetVertexColor()` | 设置纹理顶点颜色（用于状态变化）。 | PoC_Spells |
| `CreateFontString()` | 创建文本元素。 | 所有 PoC |
| `SetMovable()` / `EnableMouse()` / `RegisterForDrag()` | 使框架可拖动。 | PoC_Range, PoC_Spells |
| `_G[name]` | 通过全局环境查找按钮对应的 Icon 纹理对象进行更新。 | src |

**PoC UI 设计模式：**
- **深色主题**：背景色 RGB(0.12, 0.12, 0.12)，边框色 RGB(0.4, 0.4, 0.4)
- **标题栏**：高度 30 像素，背景色 RGB(0.2, 0.2, 0.25)
- **可拖动**：通过 `OnDragStart` / `OnDragStop` 实现
- **更新循环**：使用 `OnUpdate` 脚本，通过计时器控制更新频率
- **模块化**：拆分为 `CreateFrameBackground`, `CreateTitleBar`, `CreateContentArea` 等函数

## 9. 定时器与兼容性

**PoC_Talents** 和 **PoC_UnitState** 实现了 C_Timer 兼容层。

| API / 实现 | 用途 | 兼容性 |
| :--- | :--- | :--- |
| `C_Timer.After()` | 延时执行函数，用于等待数据加载。 | WotLK 3.3.5 原生不支持，PoC_Talents 提供兼容层 |
| `OnUpdate` 定时器 | 基于 Frame 的 `OnUpdate` 事件实现定时任务。 | 所有版本通用 |
| `GetTime()` | 获取当前游戏时间，用于计算冷却和 Buff 剩余时间。 | src, 所有 PoC |

**C_Timer 兼容层实现（PoC_Talents）：**
```lua
if not C_Timer then
    C_Timer = {}
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        for i = #timers, 1, -1 do
            local timer = timers[i]
            timer.delay = timer.delay - elapsed
            if timer.delay <= 0 then
                table.remove(timers, i)
                pcall(timer.func)  -- 保护模式执行
            end
        end
    end)
    
    function C_Timer.After(delay, func)
        table.insert(timers, { delay = delay, func = func })
    end
end
```

## 10. 其他常用工具 (Utilities)

## 10. 其他常用工具 (Utilities)

| API | 用途 | 使用位置 |
| :--- | :--- | :--- |
| `print()` | 输出调试信息到聊天框。 | 所有 PoC, src |
| `date()` | 获取格式化后的日期时间字符串。 | src |
| `tostring()`, `tonumber()` | 类型转换，确保数据安全。 | src, PoC_UnitState |
| `pairs()`, `ipairs()`, `next()` | 表遍历。 | src, 所有 PoC |
| `pcall()` | 保护模式调用函数，用于安全执行 APL 条件逻辑。 | src, PoC_Talents |
| `math.ceil()`, `math.floor()` | 数学运算（向上/向下取整）。 | PoC_Spells, PoC_UnitState |
| `string.format()` | 格式化字符串输出。 | 所有 PoC, src |
| `table.insert()`, `table.remove()` | 表操作（插入/删除元素）。 | src, PoC_Talents |
| `unpack()` | 解包表为多个返回值。 | PoC_Spells |

---

## PoC 验证工具总览

| PoC 工具 | 验证目标 | 核心 API | 状态 |
| :--- | :--- | :--- | :--- |
| **PoC_Range** | 距离检测 | `CheckInteractDistance` | ✅ 已验证 |
| **PoC_Spells** | 技能状态检测 | `IsUsableSpell`, `GetSpellCooldown`, `UnitCastingInfo`, `UnitChannelInfo` | ✅ 已验证 |
| **PoC_Talents** | 天赋检测与导出 | `GetTalentInfo`, `GetTalentTabInfo`, `GetNumTalents`, `GetActiveTalentGroup` | ✅ 已验证 |
| **PoC_UnitState** | 单位状态与光环 | `UnitAura`, `UnitHealth`, `UnitPower`, `UnitExists` | ✅ 已验证 |

**PoC 工具设计原则：**
1. **单一职责**：每个 PoC 专注验证特定 API 集合
2. **实时监控**：所有 PoC 都提供可视化实时数据显示
3. **低性能消耗**：使用节流机制（0.1-0.5秒更新间隔）
4. **兼容性处理**：针对 WotLK 3.3.5 和 Titan 服务器的特殊处理
5. **代码优雅**：采用 CONFIG 表、模块化函数、职责单一原则

---

**生成时间**: 2026-01-21  
**分析范围**: src/ 目录 + PoCs/ 验证工具  
**分析工具**: GitHub Copilot
