# 07 - 状态快照系统详细设计

## 模块概述

**文件**: `src/Engine/State.lua`

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
| | `player.power.max` | 最大资源值 | ℹ️ 未实现 | P1 | - |
| | `player.power.pct` | 资源百分比 | ℹ️ 未实现 | P1 | - |
| | `player.power.regen` | 每秒回复量 | ℹ️ 未实现 | P2 | - |
| | `rage` | 怒气值 | ✅ 已实现 | - | - |
| | `mana` | 法力值 | ✅ 已实现 | - | - |
| | `energy` | 能量值 | ✅ 已实现 | - | - |
| | `runic_power` | 符文能量 | ✅ 已实现 | - | - |
| | `mana.pct` | 法力百分比 | ✅ 已实现 | - | 火法 Preset 使用 |
| | `energy.pct` | 能量百分比 | ⚠️ 部分实现 | P1 | - |
| | `rage.pct` | 怒气百分比 | ⚠️ 部分实现 | P1 | - |
| | `runic_power.pct` | 符能百分比 | ⚠️ 部分实现 | P1 | - |
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
| **职业-符文** | `runes.blood` | 鲜血符文数量 | ⚠️ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.frost` | 冰霜符文数量 | ⚠️ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.unholy` | 邪恶符文数量 | ⚠️ 未实现 | **P0** | 死骑 Preset 使用 |
| | `runes.death` | 死亡符文数量 | ⚠️ 未实现 | **P0** | 死骑 Preset 使用 |
| **职业-连击** | `combo_points` | 连击点数 | ✅ 已实现 | - | 盗贼/德鲁伊 |
| **战斗环境** | `active_enemies` | 激活敌人数量 | ⚠️ Placeholder | P1 | 固定值 1 |

### 实现状态说明

- **✅ 已实现**: 功能完整可用
- **⚠️ 部分实现**: 基础功能可用，但需要增强（如 Placeholder、缺少字段等）
- **ℹ️ 未实现**: 文档定义但代码中未实现

### 优先级说明

- **P0（紧急）**: Preset 中已使用，必须立即实现
  - `runes.*` (blood/frost/unholy/death) - 死骑 Preset 使用（7处引用）

- **P1（高优先级）**: 功能完整性，可快速实现
  - `energy.pct`, `rage.pct`, `runic_power.pct` - 资源百分比（复用 mana 元表方案）
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

### 状态快照 (Context)

```lua
context = {
    -- 时间戳
    now = 12345.67,           -- GetTime()
    combat_time = 45.2,       -- 战斗时长
    
    -- 玩家状态
    player = {
        health = {
            current = 25000,
            max = 30000,
            pct = 83.3
        },
        power = {
            type = "MANA",    -- MANA/RAGE/ENERGY/RUNIC_POWER
            current = 8500,
            max = 10000,
            pct = 85.0,
            regen = 250       -- 每秒回复
        },
        casting = {
            spell = "Fireball",
            spell_id = 133,
            target = "target",
            end_time = 12348.17,
            remains = 2.5
        },
        gcd = {
            active = false,
            remains = 0
        }
    },
    
    -- 目标状态
    target = {
        exists = true,
        health = {
            current = 150000,
            max = 500000,
            pct = 30.0
        },
        casting = {
            spell = "Shadowbolt",
            interruptible = true
        }
    },
    
    -- 元表字段（动态查询）
    buff = <metatable>,      -- buff.hot_streak.up
    debuff = <metatable>,    -- debuff.flame_shock.remains
    cooldown = <metatable>,  -- cooldown.combustion.ready
    talent = <metatable>     -- talent.improved_scorch.enabled
}
```

### 查询缓存

```lua
query_cache = {
    -- 缓存键格式: "type:name:field"
    ["buff:hot_streak:up"] = true,
    ["cooldown:combustion:remains"] = 15.3,
    ["target:health:pct"] = 42.5,
    -- ...
}

cache_stats = {
    hits = 1832,
    misses = 456,
    total = 2288,
    hitRate = 0.801
}
```

### 对象池

```lua
buffCachePool = {
    {name = "Hot Streak", ...},  -- 可复用对象
    {name = "Pyroblast!", ...},
    -- ...
}

-- 使用模式：
local buff = GetFromPool(buffCachePool)
buff.name = "Hot Streak"
buff.expires = GetTime() + 10
-- ... 使用完毕
ReleaseToPool(buffCachePool, buff)
```

---

## 状态快照构建流程

### BuildContext() 主流程

```lua
function State:BuildContext()
    local ctx = {}
    
    -- 1. 时间戳
    ctx.now = GetTime()
    ctx.combat_time = self:GetCombatTime()
    
    -- 2. 玩家状态
    ctx.player = {
        health = self:GetPlayerHealth(),
        power = self:GetPlayerPower(),
        casting = self:GetPlayerCasting(),
        gcd = self:GetGCD()
    }
    
    -- 3. 目标状态
    ctx.target = {
        exists = UnitExists("target"),
        health = self:GetTargetHealth(),
        casting = self:GetTargetCasting()
    }
    
    -- 4. 设置元表（动态查询）
    setmetatable(ctx, {
        __index = {
            buff = self:CreateBuffAccessor(),
            debuff = self:CreateDebuffAccessor(),
            cooldown = self:CreateCooldownAccessor(),
            talent = self:CreateTalentAccessor()
        }
    })
    
    return ctx
end
```

---

## 元表动态查询机制

### Buff 访问器

```lua
function CreateBuffAccessor()
    return setmetatable({}, {
        __index = function(_, buffName)
            -- 返回 Buff 对象
            return setmetatable({
                _name = buffName
            }, {
                __index = function(buff, field)
                    -- 构建缓存键
                    local cacheKey = "buff:" .. buffName .. ":" .. field
                    
                    -- 查询缓存
                    if query_cache[cacheKey] ~= nil then
                        cache_stats.hits = cache_stats.hits + 1
                        return query_cache[cacheKey]
                    end
                    
                    -- 缓存未命中，执行实际查询
                    cache_stats.misses = cache_stats.misses + 1
                    local result = QueryBuff(buffName, field)
                    query_cache[cacheKey] = result
                    
                    return result
                end
            })
        end
    })
end
```

### Buff 查询实现

```lua
function QueryBuff(buffName, field)
    -- 扫描玩家 Buff 槽位
    for i = 1, MAX_AURA_SLOTS do
        local name, _, count, _, duration, expirationTime, unitCaster = 
            UnitBuff("player", i)
        
        if not name then break end
        
        -- 名称匹配
        if name:lower() == buffName:lower() then
            -- 根据字段返回值
            if field == "up" then
                return true
            elseif field == "down" then
                return false
            elseif field == "remains" then
                if expirationTime == 0 then
                    return 9999  -- 永久 Buff
                else
                    return math.max(0, expirationTime - GetTime())
                end
            elseif field == "count" or field == "stacks" then
                return count or 1
            elseif field == "mine" then
                return unitCaster == "player"
            end
        end
    end
    
    -- 未找到 Buff
    if field == "up" then
        return false
    elseif field == "down" then
        return true
    elseif field == "remains" then
        return 0
    elseif field == "count" or field == "stacks" then
        return 0
    end
end
```

### Cooldown 访问器

```lua
function CreateCooldownAccessor()
    return setmetatable({}, {
        __index = function(_, spellName)
            return setmetatable({
                _name = spellName
            }, {
                __index = function(cd, field)
                    local cacheKey = "cooldown:" .. spellName .. ":" .. field
                    
                    if query_cache[cacheKey] ~= nil then
                        cache_stats.hits = cache_stats.hits + 1
                        return query_cache[cacheKey]
                    end
                    
                    cache_stats.misses = cache_stats.misses + 1
                    local result = QueryCooldown(spellName, field)
                    query_cache[cacheKey] = result
                    
                    return result
                end
            })
        end
    })
end
```

### Cooldown 查询实现

```lua
function QueryCooldown(spellName, field)
    -- 获取 SpellID
    local spellID = ns.ActionMap:GetSpellID(spellName)
    if not spellID then return nil end
    
    -- 查询冷却
    local start, duration, enabled = GetSpellCooldown(spellID)
    
    -- 过滤 GCD（duration <= 1.5 秒视为 GCD，不是真实 CD）
    if duration <= GCD_THRESHOLD then
        if field == "ready" then
            return true
        elseif field == "remains" then
            return 0
        end
    end
    
    -- 计算剩余时间
    local remains = 0
    if start > 0 and duration > 0 then
        remains = math.max(0, start + duration - GetTime())
    end
    
    if field == "ready" then
        return remains == 0
    elseif field == "remains" then
        return remains
    elseif field == "charges" then
        return GetSpellCharges(spellID) or 1
    end
end
```

---

## 查询缓存系统

### 缓存策略

- **粒度**：帧级缓存（每帧构建一次 Context，期间缓存有效）
- **失效**：帧结束调用 `ClearQueryCache()` 清空
- **键格式**：`"type:name:field"`（例如 `"buff:hot_streak:up"`）

### 缓存管理

```lua
--- 清空查询缓存（每帧调用）
function State:ClearQueryCache()
    wipe(query_cache)
end

--- 获取缓存统计
function State:GetCacheStats()
    cache_stats.total = cache_stats.hits + cache_stats.misses
    
    if cache_stats.total > 0 then
        cache_stats.hitRate = cache_stats.hits / cache_stats.total
    else
        cache_stats.hitRate = 0
    end
    
    return cache_stats
end

--- 重置缓存统计
function State:ResetCacheStats()
    cache_stats.hits = 0
    cache_stats.misses = 0
    cache_stats.total = 0
    cache_stats.hitRate = 0
end
```

---

## 对象池机制

### 设计目标
- 减少频繁创建/销毁临时对象
- 降低 GC 压力
- 提升性能

### 池管理 API

```lua
--- 从池中获取对象
-- @param pool 对象池
-- @return table 可重用的对象
function GetFromPool(pool)
    return table.remove(pool) or {}
end

--- 释放对象到池
-- @param pool 对象池
-- @param obj 要释放的对象
function ReleaseToPool(pool, obj)
    if obj then
        wipe(obj)  -- 清空内容
        table.insert(pool, obj)
    end
end
```

### 使用示例

```lua
-- 获取缓存对象
local buffResult = GetFromPool(buffCachePool)
buffResult.name = "Hot Streak"
buffResult.expires = GetTime() + 10
buffResult.stacks = 1

-- ... 使用完毕后释放
ReleaseToPool(buffCachePool, buffResult)
```

---

## 虚拟时间推进

### 设计目标
- 在不改变真实游戏状态的前提下，模拟未来状态
- 用于"下一步预测"功能

### advance(seconds) 实现

```lua
function State:advance(seconds)
    -- 1. 推进时间戳
    self.now = self.now + seconds
    self.combat_time = self.combat_time + seconds
    
    -- 2. 推进 GCD
    if self.player.gcd.active then
        self.player.gcd.remains = math.max(0, 
            self.player.gcd.remains - seconds)
        
        if self.player.gcd.remains == 0 then
            self.player.gcd.active = false
        end
    end
    
    -- 3. 资源自然回复
    if self.player.power.type == "ENERGY" then
        local regen = 10  -- 能量每秒回复 10 点
        self.player.power.current = math.min(
            self.player.power.max,
            self.player.power.current + regen * seconds
        )
    elseif self.player.power.type == "RUNIC_POWER" then
        -- 符文能量每秒衰减 10 点
        self.player.power.current = math.max(0,
            self.player.power.current - 10 * seconds
        )
    end
    
    -- 4. Buff/Debuff 剩余时间衰减
    for buffName, buffData in pairs(buff_cache) do
        if buffData.expires > 0 then
            buffData.remains = math.max(0, 
                buffData.expires - self.now)
            
            if buffData.remains == 0 then
                buffData.up = false
                buffData.down = true
            end
        end
    end
    
    -- 5. 读条完成
    if self.player.casting.end_time > 0 then
        self.player.casting.remains = math.max(0,
            self.player.casting.end_time - self.now)
        
        if self.player.casting.remains == 0 then
            self.player.casting.spell = nil
            self.player.casting.spell_id = nil
        end
    end
end
```

---

## 重置机制

### 双模式重置

```lua
--- 重置状态（支持完全重置或部分重置）
-- @param full boolean 是否完全重置
function State:reset(full)
    if full then
        -- 完全重置：清空所有缓存
        wipe(buff_cache)
        wipe(debuff_cache)
        wipe(query_cache)
        
        -- 清空统计（可选）
        -- self:ResetCacheStats()
    else
        -- 轻量级重置：仅更新时间戳和 GCD
        self.now = GetTime()
        self.player.gcd = self:GetGCD()
    end
    
    -- 清空查询缓存（必须）
    self:ClearQueryCache()
end
```

### 重置时机

- **完全重置**：配置切换、进入战斗、脱离战斗
- **部分重置**：每帧开始（高频调用）

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
