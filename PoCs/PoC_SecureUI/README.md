# PoC_SecureUI

## 简介
此 PoC 用于验证 WoW 的安全模板 (`SecureActionButtonTemplate`) 及其属性设置行为。这是 WhackAMole 能够在战斗中通过“打地鼠”方式施法的核心机制。

## 验证的 API
*   `CreateFrame("Button", ..., "SecureActionButtonTemplate")`
*   `SetAttribute("type", "spell")`
*   `SetAttribute("spell", name)`
*   `InCombatLockdown()`

## 使用方法
1.  进入游戏，屏幕中央会出现一个红色的方块按钮，显示 "Click Me"。
2.  **默认行为**：点击该按钮尝试进行普通攻击 (Attack)。
3.  **动态修改**：非战斗状态下，输入 `/pocui [技能名称]` 修改按钮绑定的技能。
    *   例如：`/pocui Flash of Light` (圣光闪现)
    *   此时点击红框应施放圣光闪现。
4.  **战斗测试**：尝试进入战斗（例如攻击假人），然后尝试输入 `/pocui` 命令，观察是否提示无法修改（战斗锁定）。

## 预期结果
*   点击红框能正常触发技能。
*   非战斗状态下可以随意更换绑定的技能。
*   进入战斗后，无法通过 Lua 脚本修改按钮属性（验证安全锁机制生效）。
