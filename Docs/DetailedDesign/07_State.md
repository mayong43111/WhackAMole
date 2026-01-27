# 07 - 状态快照系统详细设计

## 模块概述

**主文件**: `src/Engine/State.lua`

**子模块结构** (Phase 2 重构):
- `Config.lua` - 配置常量（GCD阈值、资源类型、回复速率等）
- `Cache.lua` - 缓存系统（对象池、查询缓存）
- `Resources.lua` - 资源生命周期管理（创建、初始化、推进）
- `Init.lua` - 基础结构和兼容性层
- `AuraTracking.lua` - Buff/Debuff 扫描和查询
- `StateReset.lua` - 状态重置协调器
- `StateAdvance.lua` - 虚拟时间推进协调器

State 模块负责构建游戏状态的只读快照（Context），为 APL 条件判断提供一致的数据视图，并支持虚拟时间推进以实现预测功能。

---

## 设计目标

1. **一致性**：快照在单帧内保持不变，避免 API 调用返回值变化
2. **性能**：通过查询缓存和对象池减少开销
3. **可预测性**：支持虚拟时间推进，模拟未来状态
4. **可扩展性**：易于添加新的状态字段

---

## 职责

1. **状态快照构建**
   - 玩家状态（生命/资源/GCD/施法）
   - 目标状态（存在性/生命/施法）
   - Buff/Debuff 查询
   - Cooldown 查询
   - Talent 查询

2. **查询缓存系统**
   - 帧级缓存（同一帧重复查询命中缓存）
   - 缓存统计（命中率/总查询数）
   - 自动失效（帧结束清空）

3. **对象池管理**
   - Buff/Debuff 结果对象复用
   - 减少 GC 压力

4. **虚拟时间推进**
   - 资源自然回复
   - Buff/Debuff 过期预测
   - GCD 推进
   - 读条完成模拟

---

## APL 条件表达式可用参数

> **说明**：完整的参数列表、实现状态和优先级请参见下方的[参数完整列表与实现状态](#参数完整列表与实现状态)表格。

### 参数完整列表与实现状态

| 分类 | 参数 | 描述 | 实现状态 | 优先级 | 备注 |
|------|------|------|----------|--------|------|
| **时间** | `now` | 当前时间戳 (GetTime()) | ✅ 已实现 | - | - |
| | `combat_time` | 战斗时长（秒） | ✅ 已实现 | - | - |
| **玩家-生命** | `player.health.current` | 当前生命值 | ✅ 已实现 | - | - |
| | `player.health.max` | 最大生命值 | ✅ 已实现 | - | - |
| | `player.health.pct` | 生命百分比 | ✅ 已实现 | - | 防护战 Preset 使用 |
| **玩家-资源** | `player.power.type` | 资源类型 | ℹ️ 未实现 | P2 | - |
| | `player.power.current` | 当前资源值 | ✅ 已实现 | - | 仅 rage 完整实现 |
| | `player.power.max` | 最大资源值 | ❌ 未实现 | P2 | 需扩展 player.power 结构 |
| | `player.power.pct` | 资源百分比 | ❌ 未实现 | P2 | 需扩展 player.power 结构 |
| | `player.power.regen` | 每秒回复量 | ℹ️ 未实现 | P2 | - |
| | `rage` | 怒气值 | ✅ 已实现 | - | - |
| | `mana` | 法力值 | ✅ 已实现 | - | - |
| | `energy` | 能量值 | ✅ 已实现 | - | - |
| | `runic_power` | 符文能量 | ✅ 已实现 | - | - |
| | `mana.pct` | 法力百分比 | ✅ 已实现 | - | 火法 Preset 使用 |
| | `energy.pct` | 能量百分比 | ✅ 已实现 | - | 通过元表 __index |
| | `rage.pct` | 怒气百分比 | ✅ 已实现 | - | 通过元表 __index |
| | `runic_power.pct` | 符能百分比 | ✅ 已实现 | - | 通过元表 __index |
| **玩家-读条** | `player.casting.spell` | 施法名称 | ℹ️ 未实现 | P2 | - |
| | `player.casting.spell_id` | 法术 ID | ℹ️ 未实现 | P2 | - |
| | `player.casting.target` | 施法目标 | ℹ️ 未实现 | P2 | - |
| | `player.casting.end_time` | 读条结束时间 | ℹ️ 未实现 | P2 | - |
| | `player.casting.remains` | 读条剩余时间 | ℹ️ 未实现 | P2 | - |
| **玩家-GCD** | `player.gcd.active` | GCD 是否激活 | ✅ 已实现 | - | - |
| | `player.gcd.remains` | GCD 剩余时间 | ✅ 已实现 | - | - |
| **玩家-移动** | `player.moving` | 是否正在移动 | ✅ 已实现 | - | - |
| **玩家-战斗** | `player.in_combat` | 战斗状态 | ✅ 已实现 | - | - |
| **目标-存在** | `target.exists` | 目标是否存在 | ✅ 已实现 | - | - |
| **目标-生命** | `target.health.current` | 当前生命值 | ✅ 已实现 | - | - |
| | `target.health.max` | 最大生命值 | ✅ 已实现 | - | - |
| | `target.health.pct` | 生命百分比 | ✅ 已实现 | - | - |
| **目标-读条** | `target.casting.spell` | 施法名称 | ℹ️ 未实现 | P2 | 打断逻辑需要 |
| | `target.casting.interruptible` | 是否可打断 | ℹ️ 未实现 | P2 | - |
| **目标-其他** | `target.time_to_die` | 预计存活时间 | ⚠️ Placeholder | P2 | 固定值 99 |
| | `target.range` | 目标距离 | ✅ 已实现 | - | 粗略检测 |
| **Buff** | `buff.NAME.up` | Buff 是否存在 | ✅ 已实现 | - | - |
| | `buff.NAME.down` | Buff 是否不存在 | ✅ 已实现 | - | - |
| | `buff.NAME.remains` | Buff 剩余时间 | ✅ 已实现 | - | - |
| | `buff.NAME.count` | Buff 层数 | ✅ 已实现 | - | - |
| | `buff.NAME.mine` | 是否玩家施加 | ✅ 已实现 | - | - |
| | `buff.NAME.react` | 是否可响应/触发 | ✅ 已实现 | - | SimC兼容 |
| **Debuff** | `debuff.NAME.up` | Debuff 是否存在 | ✅ 已实现 | - | - |
| | `debuff.NAME.down` | Debuff 是否不存在 | ✅ 已实现 | - | - |
| | `debuff.NAME.remains` | Debuff 剩余时间 | ✅ 已实现 | - | - |
| | `debuff.NAME.count` | Debuff 层数 | ✅ 已实现 | - | - |
| **冷却** | `cooldown.NAME.ready` | 冷却是否就绪 | ✅ 已实现 | - | - |
| | `cooldown.NAME.remains` | 冷却剩余时间 | ✅ 已实现 | - | - |
| | `cooldown.NAME.charges` | 技能层数 | ℹ️ 未实现 | P2 | - |
| **天赋** | `talent.NAME.enabled` | 天赋是否学习 | ℹ️ 未实现 | P2 | - |
| **职业-符文** | `runes.blood` | 鲜血符文数量 | ❌ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.frost` | 冰霜符文数量 | ❌ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.unholy` | 邪恶符文数量 | ❌ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.death` | 死亡符文数量 | ❌ 未实现 | **P0** | 死骑 Preset 使用 |
| **职业-连击** | `combo_points` | 连击点数 | ✅ 已实现 | - | 盗贼/德鲁伊 |
| **战斗环境** | `active_enemies` | 激活敌人数量 | ⚠️ Placeholder | P1 | 固定值 1 |

### 实现状态说明

- **✅ 已实现**: 功能完整可用
- **⚠️ 部分实现**: 基础功能可用，但需要增强（如 Placeholder、缺少字段等）
- **❌ 未实现**: 代码中完全未实现（需要新增功能）
- **ℹ️ 未实现**: 文档定义但代码中未实现（低优先级）

### 优先级说明

- **P0（紧急）**: Preset 中已使用，必须立即实现
  - `runes.*` (blood/frost/unholy/death) - 死骑 Preset 使用（7处引用）
  - **状态**: 完全未实现，需要实现 GetRuneCooldown API 调用和符文类型转换机制

- **P1（高优先级）**: 功能完整性
  - `active_enemies` - 多目标判断（当前固定为1，需实现敌人计数）

- **P2（中优先级）**: 系统完整性
  - `player.power.max`, `player.power.pct` - 资源系统完善
  - `player.casting.*` - 玩家施法状态追踪

- **P3（低优先级）**: 增强功能
  - `target.time_to_die` - 复杂的存活时间算法
  - `target.casting.*` - 目标施法检测（打断逻辑）
  - `talent.*` - 天赋检测
  - `cooldown.NAME.charges` - 多层数技能支持
  - `player.power.type`, `player.power.regen` - 资源类型和回复速度

---

## 条件表达式操作符

**示例**:
```lua
cooldown.combustion.ready           -- 燃烧冷却就绪
cooldown.mirror_image.remains > 20  -- 镜像冷却剩余时间 > 20 秒
cooldown.overpower.ready            -- 压制可以使用
```

#### 7. 天赋状态 (talent.NAME.FIELD)

支持的字段：
- `talent.NAME.enabled` - 天赋是否学习（返回 boolean）

**逻辑操作符**:
- `&` - 逻辑与 (AND)
- `|` - 逻辑或 (OR)
- `!` - 逻辑非 (NOT)

**比较操作符**:
- `>` - 大于
- `<` - 小于
- `>=` - 大于等于
- `<=` - 小于等于
- `=` - 等于（编译为 Lua 的 `==`）
- `!=` - 不等于（编译为 Lua 的 `~=`）

**分组**:
- `( )` - 括号用于改变优先级

### 使用示例

```lua
-- 生命值检查
"actions+=/shield_wall,if=player.health.pct<20"
"actions+=/hammer_of_wrath,if=target.health.pct<20"

-- Buff/Debuff 检查
"actions+=/pyroblast,if=buff.hot_streak.up"
"actions+=/rend,if=debuff.rend.remains<3&target.time_to_die>6"
"actions+=/moonfire,if=!debuff.moonfire.up"

-- 冷却检查
"actions+=/combustion,if=cooldown.combustion.ready"
"actions+=/overpower"  -- 无条件，等效于 if=cooldown.overpower.ready

-- 复合条件
"actions+=/pyroblast,if=buff.hot_streak.up&cooldown.combustion.ready"
"actions+=/execute,if=target.health.pct<20|buff.sudden_death.up"
"actions+=/savage_roar,if=!buff.savage_roar.up|buff.savage_roar.remains<2"

-- 资源检查
"actions+=/evocation,if=mana.pct<10"
"actions+=/heroic_strike,if=rage>=60&target.health.pct>=20"
"actions+=/tigers_fury,if=energy<30"
"actions+=/frost_strike,if=runic_power>=40"

-- 移动状态
"actions+=/fire_blast,if=player.moving"
"actions+=/slam,if=!player.moving&rage>=20"

-- 符文检查（死亡骑士）
"actions+=/scourge_strike,if=runes.unholy>=1&runes.frost>=1"
"actions+=/blood_strike,if=runes.blood>=1"

-- Debuff 检查（DoT 等效于 Debuff）
"actions+=/icy_touch,if=!debuff.frost_fever.up"
"actions+=/plague_strike,if=!debuff.blood_plague.up"

-- Buff 响应/触发检查
"actions+=/death_coil,if=buff.sudden_doom.react"

-- 团队增益检查
"actions+=/summon_gargoyle,if=buff.potion_of_speed.up|buff.bloodlust.up|buff.heroism.up"

-- 连击点检查（盗贼/德鲁伊）
"actions+=/rip,if=combo_points>=5&debuff.rake.up"
"actions+=/ferocious_bite,if=combo_points>=5"

-- 多目标检查
"actions+=/swipe_cat,if=active_enemies>=2&energy>=45"
"actions+=/thunder_clap,if=debuff.thunder_clap.down&active_enemies>=2"
```

---

## 核心数据结构

### 状态快照 (Context) 结构

状态快照是一个不可变的数据结构，包含以下主要部分：

```lua
context = {
    now = <timestamp>,          -- 当前时间戳
    combat_time = <seconds>,    -- 战斗持续时间
    
    player = {                  -- 玩家状态
        health = {current, max, pct},
        power = {type, current, max, pct, regen},
        casting = {spell, spell_id, end_time, remains},
        gcd = {active, remains},
        moving = <boolean>,
        in_combat = <boolean>
    },
    
    target = {                  -- 目标状态
        exists = <boolean>,
        health = {current, max, pct},
        casting = {spell, interruptible},
        range = <number>
    },
    
    -- 动态查询字段（通过元表实现）
    buff = <metatable>,         -- 如 buff.hot_streak.up
    debuff = <metatable>,       -- 如 debuff.rend.remains
    cooldown = <metatable>,     -- 如 cooldown.combustion.ready
    talent = <metatable>,       -- 如 talent.improved_scorch.enabled
    
    -- 职业特定字段
    rage = <resource_object>,   -- 怒气（战士）
    energy = <resource_object>, -- 能量（盗贼/德鲁伊）
    combo_points = <number>,    -- 连击点（盗贼/德鲁伊）
    runic_power = <resource_object>, -- 符文能量（死亡骑士）
    holy_power = <number>       -- 圣能（圣骑士，泰坦服）
    -- 注意: runes (blood/frost/unholy/death) 尚未实现
}
```

---

## 设计原理

### 1. 元表动态查询机制

**设计思路**：
- Buff/Debuff/Cooldown 查询采用**延迟计算**策略
- 只有当 APL 条件实际访问某个字段时才执行 WoW API 查询
- 通过 Lua 元表的 `__index` 元方法实现两层嵌套查询

**查询链路**：
```
APL 条件: buff.hot_streak.up
         ↓
State Context 元表触发
         ↓
创建 Buff 代理对象 (hot_streak)
         ↓
访问字段 'up' 触发第二层元表
         ↓
检查查询缓存
         ↓
缓存未命中 → 执行 UnitBuff() 扫描
         ↓
返回结果并缓存
```

**关键优势**：
- 避免每帧扫描所有 Buff（WotLK 有 40 个槽位）
- 条件中未使用的 Buff 不会触发查询
- 自然支持任意 Buff 名称（无需预定义）

**元表结构**：
- 第一层元表：`context.buff[buffName]` → 返回 Buff 代理对象
- 第二层元表：`buffProxy[field]` → 执行实际查询并缓存

### 2. 查询缓存系统

**设计思路**：
- 单帧内重复查询同一字段会命中缓存（如多个条件都检查 `buff.hot_streak.up`）
- 缓存粒度为单帧，每帧结束自动失效
- 缓存键格式：`"type:name:field"`（如 `"buff:hot_streak:up"`）

**缓存策略**：
| 场景 | 缓存有效性 | 失效机制 |
|------|-----------|----------|
| 同一帧内重复查询 | ✅ 命中缓存 | - |
| 下一帧查询 | ❌ 已失效 | 帧开始时清空 |
| 虚拟时间推进后 | ❌ 需重新计算 | advance() 后清空 |

**典型命中率**：75-80%（Preset APL 中大量重复条件查询）

### 3. 对象池机制

**设计目标**：
- 减少 Buff/Debuff 查询结果对象的频繁创建/销毁
- 降低 Lua GC 压力（WoW 客户端单线程，GC 暂停影响帧率）

**工作原理**：
- 预分配一批可复用的表对象
- 使用时从池中取出，使用完毕后清空并归还
- 池为空时动态创建新对象

**适用场景**：
- Aura 查询结果缓存
- 临时计算数据存储

---

## 状态快照构建流程

### BuildContext() 主要步骤

1. **创建基础快照对象**
   - 获取当前时间戳（`GetTime()`）
   - 计算战斗时长（`now - combat_start_time`）

2. **查询玩家静态状态**
   - 生命值：`UnitHealth("player")` / `UnitHealthMax("player")`
   - 资源：`UnitPower("player", powerType)` / `UnitPowerMax("player", powerType)`
   - GCD：`GetSpellCooldown(61304)` 检测 1.5 秒全局冷却
   - 移动状态：通过事件监听器维护标志位

3. **查询目标静态状态**
   - 存在性：`UnitExists("target")`
   - 生命值：`UnitHealth("target")` / `UnitHealthMax("target")`
   - 距离：通过技能范围 API 粗略判断

4. **设置动态查询元表**
   - 为 `buff`, `debuff`, `cooldown`, `talent` 字段设置元表
   - 元表的 `__index` 方法返回代理对象
   - 代理对象的 `__index` 方法执行实际查询

5. **初始化职业资源**
   - 通用资源：mana（法力）
   - 战士/德鲁伊熊形态：rage（怒气）
   - 盗贼/德鲁伊猫形态：energy（能量）、combo_points（连击点）
   - 死亡骑士：runic_power（符文能量）
   - 圣骑士（泰坦服）：holy_power（圣能）
   - **未实现**：死亡骑士符文槽位（runes.blood/frost/unholy/death）

---

## 虚拟时间推进机制

### 设计目标
- 在**不改变真实游戏状态**的前提下，模拟未来某个时间点的状态
- 用于"下一步最优动作预测"功能

### advance(seconds) 推进逻辑

**1. 时间戳推进**
- `now` 增加指定秒数
- `combat_time` 相应增加

**2. GCD 推进**
- GCD 剩余时间递减
- 剩余时间归零时，`gcd.active` 置为 `false`

**3. 资源自然变化**
| 资源类型 | 变化规则 |
|---------|---------|
| Energy（能量） | 每秒回复 10 点（受天赋影响） |
| Runic Power（符能） | 每秒衰减 10 点（自然流失） |
| Rage（怒气） | 战斗中自然衰减，脱战快速清空 |
| Mana（法力） | 根据精神属性计算回复速率 |

**4. Buff/Debuff 时间衰减**
- 所有 Aura 的 `remains` 字段递减
- 剩余时间归零时，标记为 `down` 状态

**5. 读条状态更新**
- 玩家/目标读条的 `remains` 递减
- 读条完成时清除施法信息

### 使用场景

**Scenario 1：预测 GCD 后的资源状态**
```
当前：能量 40，GCD 剩余 0.8 秒
推进 0.8 秒后：能量 48（回复 8 点），GCD 结束
```

**Scenario 2：判断 Buff 是否会过期**
```
当前：Hot Streak 剩余 9 秒，下一次施法耗时 2 秒
推进 2 秒后：Hot Streak 剩余 7 秒（仍然存在）
```

---

## 状态重置机制

### 双模式设计

**完全重置 (`reset(true)`)**
- 触发时机：进入战斗、脱离战斗、切换 Preset
- 清空内容：所有缓存、Buff/Debuff 数据、统计信息
- 耗时：~0.3ms

**轻量级重置 (`reset(false)`)**
- 触发时机：每帧开始（高频调用，每秒 60-100 次）
- 清空内容：仅查询缓存
- 耗时：~0.08ms

### 重置流程对比

| 操作 | 完全重置 | 轻量级重置 |
|------|---------|-----------|
| 清空查询缓存 | ✅ | ✅ |
| 清空 Buff 缓存 | ✅ | ❌ |
| 重置统计数据 | ✅ | ❌ |
| 重置时间戳 | ✅ | ✅ |
| 刷新 GCD | ✅ | ✅ |

**设计权衡**：
- 高频场景使用轻量级重置，避免性能损耗
- Buff 数据虽然未清空，但查询时会验证过期状态
- 查询缓存必须每帧清空，否则会返回过期数据

---

## 性能优化总结

### 优化策略

| 策略 | 效果 | 开销 |
|------|------|------|
| 查询缓存 | 命中率 75-80%，减少重复 API 调用 | 内存：~10KB/帧 |
| 对象池 | 减少 GC 暂停 | CPU：微小 |
| 元表懒加载 | 仅查询需要的字段 | CPU：微小 |
| 部分重置 | 高频场景降低 70% 耗时 | - |

### 性能指标

- **完全重置耗时**：0.3ms
- **部分重置耗时**：0.08ms
- **Context 构建耗时**：0.5ms（无缓存）/ 0.15ms（有缓存）
- **查询缓存命中率**：75-80%

---

## 已知限制

1. **距离查询缺失**
   - 当前未实现 `target.distance` 字段
   - WotLK API 限制，需通过技能范围推断

2. **Buff 槽位限制**
   - 仅扫描前 40 个槽位
   - 超出部分无法查询

3. **虚拟时间精度**
   - 资源回复假设为固定速率
   - 未考虑天赋/装备加成

4. **缓存失效时机**
   - 仅在帧结束清空，事件驱动场景可能滞后

---

## 依赖关系

### 依赖的模块
- ActionMap (SpellID 映射)
- Constants (常量定义)

### 被依赖的模块
- APLExecutor (使用 Context 执行决策)
- Core (调用 BuildContext 和 reset)

---

## 相关文档
- [APL 执行器](09_APLExecutor.md)
- [SimC 解析器](08_SimCParser.md)
- [动作映射](13_ActionMap.md)
- [生命周期与主控制器](01_Core_Lifecycle.md)
