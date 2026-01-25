-- Frost Mage Preset - Traditional Build (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 冰法·传统流派 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "MAGE",
        spec = 64, -- Frost
        desc = "泰坦T1传统冰法流派。90%时间寒冰箭spam，思维冷却和寒冰指触发消耗。稳定单体DPS。"
    },

    layout = {
        slots = {
            [1] = { action = "icy_veins" },       -- 冰冷血脉
            [2] = { action = "mirror_image" },    -- 镜像
            [3] = { action = "frostfire_bolt" },  -- 霜火之箭
            [4] = { action = "ice_lance" },       -- 冰枪术
            [5] = { action = "frostbolt" },       -- 寒冰箭
            [6] = { action = "fire_blast" },      -- 火焰冲击
            [7] = { action = "summon_water_elemental" }  -- 召唤水元素
        }
    },

    apl = {
        -- 爆发技能：CD好立即使用
        "actions+=/icy_veins",                                   -- 冰冷血脉：大幅提升施法速度
        "actions+=/mirror_image",                                -- 镜像：威胁转移+额外DPS
        
        -- 触发消耗：优先级最高
        "actions+=/frostfire_bolt,if=buff.brain_freeze.up",     -- 霜火之箭：思维冷却触发(8/15%)，瞬发+伤害提高15/30%+不消耗法力
        "actions+=/ice_lance,if=buff.fingers_of_frost.up",      -- 冰枪术：寒冰指触发(10/20%)，对冻结目标五倍伤害
        
        -- 移动填充：保持输出
        "actions+=/fire_blast,if=player.moving",                -- 火焰冲击：移动时优先使用(有CD)
        "actions+=/ice_lance,if=player.moving",                 -- 冰枪术：移动时备选(无CD)
        
        -- 主要填充：90%时间都在读条
        "actions+=/frostbolt"                                    -- 寒冰箭：主要填充技能，必定触发法力恢复
    }
})
