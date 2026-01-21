# PoC_Spells

## 简介
此 PoC 用于验证技能查询与冷却相关 API 的准确性。主要用于测试技能 ID 映射是否正确，判断技能是否可用（法力/姿态/资源），以及冷却时间计算是否符合预期。

## 验证的 API
*   `GetSpellInfo(id/name)`
*   `IsUsableSpell(name)`
*   `GetSpellCooldown(name)`

## 使用方法
1.  进入游戏。
2.  插件加载时会自动测试 "Hearthstone" (炉石, ID 8690) 和 "Attack" (普通攻击, ID 6603)。
3.  使用命令 `/pocspell [SpellID 或 技能名称]` 测试特定技能。
    *   例如：`/pocspell 5308` (测试斩杀 Execute)
    *   例如：`/pocspell Fireball` (测试火球术)

## 预期结果
*   能够正确输出技能名称、等级。
*   `IsUsable` 能够正确反映当前是否缺蓝、姿态不对或缺少资源。
*   `Cooldown` 数据（开始时间、持续时间）准确，未冷却技能应显示 `Start > 0`。
