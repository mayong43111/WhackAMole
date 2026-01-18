local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "练级战士 (通用)",
        author = "WhackAMole",
        version = 1,
        class = "WARRIOR",
        spec = nil,
        desc = "1-80 级通用练级配置。自动适应技能解锁状态。优先使用乘胜追击保持续航。支持武器/狂暴/防御天赋练级。"
    },
    layout = {
        slots = {
            [1] = { action = "charge" },
            [2] = { action = "rend" },
            [3] = { action = "victory_rush" },
            [4] = { action = "overpower" },
            [5] = { action = "mortal_strike" },
            [6] = { action = "execute" },
            [7] = { action = "battle_shout" },
            [8] = { action = "bloodthirst" },
            [9] = { action = "heroic_strike" },
            [10] = { action = "thunder_clap" }
        }
    },
    apl = {
        -- Buffs
        { action = "battle_shout", condition = "buff.battle_shout.down" },
        
        -- Start
        { action = "charge", condition = "target.range >= 8 & target.range <= 25 & !player.combat" },
        
        -- High Prio
        { action = "victory_rush" }, 
        { action = "execute", condition = "target.health_pct < 20 & rage > 15" },
        { action = "overpower" }, 
        
        -- Maintenance
        { action = "rend", condition = "debuff.rend.down & target.time_to_die > 6" },
        
        -- Main
        { action = "mortal_strike" },
        { action = "bloodthirst" },
        { action = "shield_slam" },
        
        -- Filler
        { action = "thunder_clap", condition = "active_enemies >= 2" },
        { action = "heroic_strike", condition = "rage > 60 | (rage > 30 & target.health_pct < 20)" },
        { action = "slam", condition = "talent.improved_slam & !player.moving" }
    }
})
