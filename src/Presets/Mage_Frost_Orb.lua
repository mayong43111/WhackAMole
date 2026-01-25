-- Frost Mage Preset - Frozen Orb Build (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 冰法·冰冻宝珠流派 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "MAGE",
        spec = 64, -- Frost
        desc = "泰坦T1冰冻宝珠流派。第9层天赋选择冰冻宝珠，高机动性+AOE。适合需要移动和多目标战斗。"
    },

    layout = {
        slots = {
            [1] = { action = "icy_veins" },         -- 冰冷血脉
            [2] = { action = "mirror_image" },      -- 镜像
            [3] = { action = "frozen_orb" },        -- 冰冻宝珠
            [4] = { action = "frostfire_bolt" },    -- 霜火之箭
            [5] = { action = "ice_lance" },         -- 冰枪术
            [6] = { action = "cone_of_cold" },      -- 冰锥术
            [7] = { action = "frostbolt" },         -- 寒冰箭
            [8] = { action = "summon_water_elemental" }  -- 召唤水元素
        }
    },

    apl = {
        -- 爆发技能：CD好立即使用
        "actions+=/icy_veins",                                   -- 冰冷血脉：大幅提升施法速度
        "actions+=/mirror_image",                                -- 镜像：威胁转移+额外DPS
        
        -- 核心输出：冰冻宝珠流派的关键技能
        "actions+=/frozen_orb",                                  -- 冰冻宝珠：第9层天赋，穿透伤害可触发寒冰指和思维冷却
        
        -- 触发消耗：优先级最高
        "actions+=/frostfire_bolt,if=buff.brain_freeze.up",     -- 霜火之箭：思维冷却触发(8/15%)，瞬发+伤害提高15/30%+不消耗法力
        "actions+=/ice_lance,if=buff.fingers_of_frost.up",      -- 冰枪术：寒冰指触发(10/20%)，对冻结目标五倍伤害
        
        -- 移动填充：保持输出
        "actions+=/ice_lance,if=player.moving",                 -- 冰枪术：移动时使用(无CD)
        
        -- 主要填充：寒冰箭spam
        "actions+=/frostbolt"                                    -- 寒冰箭：主要填充技能，必定触发法力恢复
    }
})
