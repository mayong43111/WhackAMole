-- Balance Druid Preset (APL v2.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 平衡德 (T1)",
        author = "WhackAMole",
        version = 2.1,
        class = "DRUID",
        spec = 102, -- Balance
        desc = "基于WCL高端数据优化。开局精灵之火+DoT，日月蚀循环100% spam对应技能，DoT仅紧急刷新。"
    },
    
    layout = {
        slots = {
            [1] = { action = "wrath" },            -- 愤怒
            [2] = { action = "starfire" },         -- 星火术
            [3] = { action = "moonfire" },         -- 月火术
            [4] = { action = "insect_swarm" },     -- 虫群
            [5] = { action = "starfall" },         -- 星辰坠落
            [6] = { action = "faerie_fire" },      -- 精灵之火
            [7] = { action = "typhoon" },          -- 台风
            [8] = { action = "hurricane" }         -- 飓风
        }
    },
    
    apl = {
        -- 开局debuff：战斗开始立即施放（+3%伤害）
        "actions+=/faerie_fire,if=!debuff.faerie_fire.up",           -- 精灵之火：开局debuff，降低目标护甲
        
        -- 开局DoT：战斗初期立即上DoT
        "actions+=/moonfire,if=!debuff.moonfire.up",                 -- 月火术：开局立即上DoT
        "actions+=/insect_swarm,if=!debuff.insect_swarm.up",         -- 虫群：开局立即上DoT
        
        -- 爆发技能：CD好立即使用
        "actions+=/starfall",                                          -- 星辰坠落：CD好就用，4T1后持续12秒
        
        -- 日月蚀循环：核心机制（+40%伤害加成）
        "actions+=/starfire,if=buff.lunar_eclipse.up",                -- 星火术：月蚀期间100% spam
        "actions+=/wrath,if=buff.solar_eclipse.up",                   -- 愤怒：日蚀期间100% spam
        
        -- DoT刷新：仅紧急刷新，优先日月蚀循环
        "actions+=/moonfire,if=debuff.moonfire.remains<3",            -- 月火术：DoT剩余<3秒紧急刷新（21秒持续）
        "actions+=/insect_swarm,if=debuff.insect_swarm.remains<3",    -- 虫群：DoT剩余<3秒紧急刷新（12秒持续）
        
        -- 主要填充：愤怒推动日蚀循环
        "actions+=/wrath"                                              -- 愤怒：默认填充技能，推动日蚀循环
    }
})
