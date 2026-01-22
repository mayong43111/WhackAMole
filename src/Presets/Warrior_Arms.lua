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
            [1] = { action = "mortal_strike" },
            [2] = { action = "overpower" },
            [3] = { action = "execute" },
            [4] = { action = "rend" },
            [5] = { action = "slam" },
            [6] = { action = "bladestorm" },
            [7] = { action = "heroic_strike" },
            [8] = { action = "thunder_clap" }
        }
    },
    
    apl = {
        -- Priority 1: Maintain Rend (triggers Taste for Blood for Overpower)
        "actions+=/rend,if=debuff.rend.remains<3&target.time_to_die>6",
        -- Priority 2: Overpower (5 rage, guaranteed crit, highest DPE!)
        -- 4T1 makes this proc 35% of the time from Rend ticks
        "actions+=/overpower",
        -- Priority 3: Sudden Death Execute (use above 20% HP)
        -- 4T1 increases proc rate to 8-11%
        "actions+=/execute,if=buff.sudden_death.up&target.health.pct>=20",
        -- Priority 4: Execute Phase (below 20% HP)
        "actions+=/execute,if=target.health.pct<20&rage>=30",
        -- Priority 5: Mortal Strike (on CD)
        "actions+=/mortal_strike",
        -- Priority 6: Bladestorm (on CD, but avoid wasting procs)
        "actions+=/bladestorm,if=!buff.sudden_death.up&!spell.overpower.ready",
        -- Priority 7: Slam (filler with 2T1 +3% damage bonus)
        "actions+=/slam,if=!player.moving&rage>=20&target.health.pct>=20",
        -- Priority 8: Heroic Strike (rage dump at high rage)
        "actions+=/heroic_strike,if=rage>=60&target.health.pct>=20",
        -- Utility: Thunder Clap for debuff
        "actions+=/thunder_clap,if=debuff.thunder_clap.down&active_enemies>=2"
    }
})
