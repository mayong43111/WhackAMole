# PoC_Spells

## 简介
此 PoC 用于验证技能状态检测相关的核心 API，确保插件能够准确判断技能的可用性、冷却状态和施法状态。

## 核心验证目标
验证以下三个关键 API 的准确性和可靠性：

1. **`IsUsableSpell(name)`** - 技能是否可用
   - 验证资源检测（怒气/法力/能量是否足够）
   - 验证条件限制（姿态/形态/Buff要求）
   - 验证目标要求（是否需要目标、目标类型）

2. **`GetSpellCooldown(name)`** - 技能冷却时间
   - 验证冷却开始时间的准确性
   - 验证冷却持续时间的计算
   - 验证公共 GCD 和独立 CD 的区分

3. **施法状态检测** - 是否正在释放技能
   - 验证 `UnitCastingInfo("player")` - 检测施法进度
   - 验证 `UnitChannelInfo("player")` - 检测引导法术
   - 验证施法打断和完成状态

## 验证的 API
*   `IsUsableSpell(name)` - **核心 API 1**：判断技能是否可用
*   `GetSpellCooldown(name)` - **核心 API 2**：获取技能冷却时间
*   `UnitCastingInfo("player")` - **核心 API 3a**：获取当前施法信息
*   `UnitChannelInfo("player")` - **核心 API 3b**：获取当前引导法术信息
*   `GetSpellInfo(id/name)` - 辅助 API：获取技能基础信息

## 使用方法
1.  进入游戏，在插件列表中启用 **PoC_Spells**。
2.  插件加载后会自动显示技能监控窗口（可拖动）。
3.  监控窗口实时显示技能状态：
    *   **绿色背景** - 技能就绪，可以使用
    *   **蓝色背景** - 技能冷却中，显示剩余秒数
    *   **紫色背景** - 资源不足（怒气/法力/能量不够）
    *   **暗红色背景** - 不可用（条件不满足，如错误姿态）
    *   **黄色背景** - 正在释放中（施法或引导）
4.  命令：
    *   `/pocspell show` - 显示监控窗口
    *   `/pocspell hide` - 隐藏监控窗口
5.  测试施法状态：
    *   施放技能时，监控窗口会显示黄色背景表示正在释放
    *   验证 `UnitCastingInfo` 和 `UnitChannelInfo` 的检测准确性

## 预期结果
*   `IsUsableSpell` 能准确反映技能是否可用，区分"不可用"和"资源不足"
*   `GetSpellCooldown` 返回的时间戳和持续时间准确无误
*   施法状态检测能正确识别：
    - 当前是否在施法
    - 施法的技能名称和图标
    - 施法进度百分比
    - 剩余施法时间
    - 是否可被打断
*   监控窗口颜色变化与实际技能状态完全同步

## 技术说明
### API 返回值说明

#### IsUsableSpell(name)
返回两个值：
- `usable` (boolean) - 技能是否可用
- `nomana` (boolean) - 是否因资源不足而不可用

#### GetSpellCooldown(name)
返回三个值：
- `start` (number) - 冷却开始时间（GetTime()的时间戳）
- `duration` (number) - 冷却持续时间（秒）
- `enabled` (boolean) - 冷却是否启用

计算剩余冷却时间：`remaining = (start + duration) - GetTime()`

#### UnitCastingInfo("player")
返回多个值（如果正在施法）：
- `name` (string) - 技能名称
- `text` (string) - 显示文本
- `texture` (string) - 技能图标路径
- `startTime` (number) - 施法开始时间（毫秒）
- `endTime` (number) - 施法结束时间（毫秒）
- `isTradeSkill` (boolean) - 是否为商业技能
- `castID` (number) - 施法ID
- `interrupt` (boolean) - 是否可被打断

如果没有在施法，返回 nil。

### 测试场景
1. **冷却测试**：使用一个有明显CD的技能，观察冷却倒计时
2. **资源测试**：消耗全部资源后尝试使用技能，验证 nomana 标志
3. **施法测试**：施放一个读条技能，验证施法信息的准确性
4. **引导测试**：施放引导法术（如奥术飞弹），验证 UnitChannelInfo

## 监控技能列表
默认监控以下战士技能（可在 Core.lua 中修改 `monitorSpells` 表）：
*   致死打击 (Mortal Strike) - 12294
*   猛击 (Slam) - 1464
*   斩杀 (Execute) - 5308
*   利刃风暴 (Bladestorm) - 46924

