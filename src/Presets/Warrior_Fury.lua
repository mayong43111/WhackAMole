-- Fury Warrior Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 狂暴战(Titan-Forged)",
        author = "Luminary Copilot",
        version = 2,
        class = "WARRIOR",
        spec = 72, -- Fury
        desc = "SimC APL. BT > WW > Slam(Proc) > Execute."
    },
    
    layout = {
        slots = {
            [1] = { action = "bloodthirst" },
            [2] = { action = "whirlwind" },
            [3] = { action = "slam" },
            [4] = { action = "execute" },
            [5] = { action = "victory_rush" }
        }
    },
    
    apl = {
        "actions+=/victory_rush",
        "actions+=/bloodthirst",
        "actions+=/whirlwind",
        "actions+=/slam,if=buff.bloodsurge.up",
        "actions+=/execute,if=target.health.pct<20"
    }
})
