-- Balance Druid Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 平衡德 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DRUID",
        spec = 102, -- Balance
        desc = "泰坦T1平衡德鲁伊。日月蚀循环是核心，在Buff期间100% spam对应技能（+40%伤害）。DoT低优先级维持。"
    },
    
    layout = {
        slots = {
            [1] = { action = "wrath" },            -- 愤怒
            [2] = { action = "starfire" },         -- 星火术
            [3] = { action = "moonfire" },         -- 月火术
            [4] = { action = "insect_swarm" },     -- 虫群
            [5] = { action = "starfall" },         -- 星辰坠落
            [6] = { action = "typhoon" },          -- 台风
            [7] = { action = "hurricane" }         -- 飓风
        }
    },
    
    apl = {
        -- 爆发技能：CD好立即使用
        "actions+=/starfall",                                          -- 星辰坠落：顶级AOE，4T1后持续12秒（+20%伤害）
        
        -- 日月蚀循环：核心机制（+40%伤害加成）
        "actions+=/starfire,if=buff.lunar_eclipse.up",                -- 星火术：月蚀期间100% spam
        "actions+=/wrath,if=buff.solar_eclipse.up",                   -- 愤怒：日蚀期间100% spam
        
        -- DoT维持：低优先级，不打断日月蚀循环
        "actions+=/moonfire,if=!debuff.moonfire.up|debuff.moonfire.remains<5",      -- 月火术：DoT剩余<5秒刷新
        "actions+=/insect_swarm,if=!debuff.insect_swarm.up|debuff.insect_swarm.remains<3",  -- 虫群：DoT剩余<3秒刷新
        
        -- 主要填充：愤怒推动日蚀循环
        "actions+=/wrath"                                              -- 愤怒：默认填充技能，推动日蚀循环
    }
})
