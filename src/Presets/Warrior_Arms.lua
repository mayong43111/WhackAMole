-- Arms Warrior Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 武器战 (Titan-Forged)",
        author = "Skyline",
        version = 2,
        class = "WARRIOR",
        spec = 71, -- Arms
        desc = "SimC APL. Prioritizes Rend > Overpower > Execute."
    },
    
    layout = {
        slots = {
            [1] = { action = "mortal_strike" },
            [2] = { action = "overpower" },
            [3] = { action = "execute" },
            [4] = { action = "rend" },
            [5] = { action = "slam" },
            [6] = { action = "bladestorm" },
            [7] = { action = "thunder_clap" }
        }
    },
    
    apl = {
        "actions+=/rend,if=debuff.rend.remains<3&target.time_to_die>6",
        "actions+=/thunder_clap,if=debuff.thunder_clap.down",
        "actions+=/overpower",
        "actions+=/execute,if=target.health.pct<20|buff.sudden_death.up",
        "actions+=/bladestorm,if=target.health.pct>=20",
        "actions+=/mortal_strike",
        "actions+=/slam,if=rage>=15&!player.moving"
    }
})
