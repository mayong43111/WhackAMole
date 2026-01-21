# PoC_UnitState

## 简介
此 PoC (Proof of Concept) 用于验证 World of Warcraft 3.3.5 (WotLK) 客户端中的单位状态 API 接口。基于 **WeakAuras**、**TUnitFrame**、**TotemTimers** 等主流插件的实现模式，验证目标单位的生命值、能量值读取，以及 Buff/Debuff 扫描逻辑。

## 验证的 API

### 核心单位状态 API
*   `UnitExists(unit)` - 单位存在性检查（必须先验证）
*   `UnitHealth(unit)` / `UnitHealthMax(unit)` - 生命值获取
*   `UnitPower(unit, powerType)` / `UnitPowerMax(unit, powerType)` - 能量值获取
*   `UnitPowerType(unit)` - 能量类型识别（Mana/Rage/Energy/Runic Power等）

### Aura (光环) API
*   `UnitBuff(unit, index)` - 查询增益效果
*   `UnitDebuff(unit, index)` - 查询减益效果

**注意**: 泰坦服不支持 `UnitAura(unit, index, filter)` 统一接口，必须分别使用 UnitBuff/UnitDebuff。

### WotLK 3.3.5 标准返回值（11个）
```lua
name, rank, icon, count, debuffType, duration, expirationTime, 
unitCaster, isStealable, shouldConsolidate, spellId
```

| 位置 | 字段名 | 类型 | 说明 | 泰坦服支持 |
|------|--------|------|------|-----------|
| 1 | name | string | 光环名称（受本地化影响） | ✅ |
| 2 | rank | string | 等级文本（如"等级 1"，通常为空） | ✅ |
| 3 | icon | string | 图标材质路径 | ✅ |
| 4 | count | number | 叠加层数（无叠加时为 0） | ✅ |
| 5 | debuffType | string | 减益类型（Magic/Disease/Poison/Curse/nil） | ❌ 总是 nil |
| 6 | duration | number | 总持续时间（秒，0=永久） | ✅ |
| 7 | expirationTime | number | 过期时间戳（GetTime()基准） | ✅ |
| 8 | unitCaster | string | 施法者单位ID（"player"/"pet"/其他） | ✅ 关键！ |
| 9 | isStealable | boolean | 是否可偷取/驱散 | ❌ 未测试 |
| 10 | shouldConsolidate | boolean | UI是否应合并显示 | ❌ 未测试 |
| 11 | spellId | number | 法术ID（推荐用于判断，不受语言影响） | ❌ 不支持 |

**泰坦服实测支持**: 返回值 1-8，其中第 8 个 `unitCaster` 可用于判断施法者。

**关键用法：**
```lua
-- 参考 TotemTimers 实现
name, _, icon, count, debuffType, duration, expirationTime, unitCaster = UnitDebuff("target", i)

-- 判断是否为玩家施放
if unitCaster == "player" then
    -- 这是玩家自己施放的减益
end
```

## 使用方法

1.  进入游戏后，插件自动加载
2.  选中任意目标（玩家/NPC/Boss），自动输出完整状态信息
3.  目标光环变化时（带 0.5 秒节流），自动更新光环信息

## 输出示例
```
=== PoC_单位状态测试 ===
单位: 训练假人 (target)
[生命值] target: 4980/5000 (99%)
[能量值] target: 无 (未知)
--- target 增益 (增益) ---
  [1] 嗜血 x3 [玩家] (25.3/40.0秒)
  [2] 术士护甲 (1125.5/1800.0秒)
--- target 减益 (减益) ---
  [1] 腐蚀术 [玩家] (12.5/18.0秒)
  [2] 痛苦诅咒 [玩家] (20.1/120.0秒)
  [3] 献祭 (18.3/30.0秒)
[统计] 增益: 2个, 减益: 3个
=== 测试完成 ===
```

**说明**:
- `[玩家]` - 表示该光环由玩家施放
- `[宠物]` - 表示该光环由宠物施放
- 无标记 - 其他单位施放（如其他玩家、NPC）

## 泰坦服 API 限制总结

### ✅ 可用功能
- **UnitBuff/UnitDebuff**: 前 8 个返回值可用
- **unitCaster (第8个)**: **关键！** 可用于判断施法者是否为 "player" 或 "pet"
- **时间计算**: duration 和 expirationTime 工作正常
- **层数统计**: count 字段正确

### ❌ 不可用功能
- **debuffType (第5个)**: 总是返回 `nil`，无法判断 Magic/Poison/Curse/Disease
- **spellId (第11个)**: 不支持，无法通过法术ID判断
- **UnitAura 统一接口**: 不支持 filter 参数

### 🔧 解决方案
**施法者识别（已实现）**:
```lua
-- 判断光环施法者
name, _, icon, count, _, duration, expirationTime, unitCaster = UnitDebuff("target", i)
if unitCaster == "player" then
    -- 玩家施放
elseif unitCaster == "pet" then
    -- 宠物施放
end
```

**Debuff 类型判断（替代方案）**:
- 无法通过 API 直接获取
- 需要维护法术名称→类型映射表
- 或使用 COMBAT_LOG_EVENT_UNFILTERED 事件追踪

## 关键实现特性（参考主流插件）

### 1. 安全检查模式
*   所有 API 调用前先验证 `UnitExists()`（参考 **TotemTimers**）
*   防止 `maxHP = 0` 导致除零错误（参考 **TUnitFrame**）

### 2. 高效 Aura 扫描
*   使用 `UnitBuff()`/`UnitDebuff()` 循环扫描，直到返回 `nil`（参考 **TotemTimers**）
*   泰坦服不支持 UnitAura 统一接口，必须分别调用
*   建议最大扫描 40 个光环（WotLK 单位光环上限）
*   使用第 8 个返回值 `unitCaster` 判断施法者（参考 **TotemTimers EnhanceCDs_Wod.lua**）

### 3. 时间计算
*   剩余时间 = `expirationTime - GetTime()`
*   判断永久光环：`duration == 0` 或 `expirationTime == 0`

### 4. 施法者识别
*   **泰坦服方案**: 直接判断 `unitCaster == "player"` 或 `unitCaster == "pet"`
*   标准方案: 使用 `UnitIsUnit(caster, "player")` 判断（泰坦服未测试）

### 5. 节流机制
*   `UNIT_AURA` 事件高频触发，使用 0.5 秒节流避免刷屏（参考 **WeakAuras**）

## 参考实现来源
*   **WeakAuras** (`BuffTrigger2.lua`, `AuraEnvironment.lua`) - Aura 扫描逻辑
*   **TUnitFrame** (`BUnitFrame.lua`, `InfoPane.lua`) - 生命值/能量条更新
*   **TotemTimers** (`EnhanceCDs_Wod.lua`) - Debuff 扫描和施法者判断
