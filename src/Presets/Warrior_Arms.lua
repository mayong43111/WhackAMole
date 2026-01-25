-- Arms Warrior Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 武器战 (T1)",
        author = "WhackAMole",
        version = 3,
        class = "WARRIOR",
        spec = 71, -- Arms
        desc = "WotLK Arms for Titan Forged T1. Focus on Rend > Overpower > Execute priority."
    },
    
    layout = {
        slots = {
            [1] = { action = "mortal_strike" },      -- 致死打击
            [2] = { action = "overpower" },          -- 压制
            [3] = { action = "execute" },            -- 斩杀
            [4] = { action = "rend" },               -- 撕裂
            [5] = { action = "slam" },               -- 猛击
            [6] = { action = "bladestorm" },         -- 剑刃风暴
            [7] = { action = "heroic_strike" },      -- 英勇打击
            [8] = { action = "thunder_clap" }        -- 雷霆一击
        }
    },
    
    apl = {
        "actions+=/rend,if=debuff.rend.remains<3&target.time_to_die>6",                  -- 撕裂：维持DoT，触发鲜血渴望使压制可用
        "actions+=/overpower",                                                            -- 压制：5怒气必暴击，最高伤害效率（4T1使撕裂跳动35%触发几率）
        "actions+=/execute,if=buff.sudden_death.up&target.health.pct>=20",               -- 斩杀：突然死亡触发时可在高血量使用（4T1提升触发率至8-11%）
        "actions+=/execute,if=target.health.pct<20&rage>=30",                            -- 斩杀：斩杀阶段优先使用（血量<20%，怒气>=30）
        "actions+=/mortal_strike",                                                        -- 致死打击：核心输出技能，CD好就用
        "actions+=/bladestorm,if=!buff.sudden_death.up&!cooldown.overpower.ready",          -- 剑刃风暴：CD好就用，但不浪费突然死亡和压制触发
        "actions+=/slam,if=!player.moving&rage>=20&target.health.pct>=20",               -- 猛击：填充技能（2T1+3%伤害，需静止且怒气>=20）
        "actions+=/heroic_strike,if=rage>=60&target.health.pct>=20",                     -- 英勇打击：高怒气消耗（怒气>=60时使用，防止溢出）
        "actions+=/thunder_clap,if=debuff.thunder_clap.down&active_enemies>=2"           -- 雷霆一击：多目标时施加减速debuff
    }
})
