-- Prot Warrior Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 防御战 (Titan-Forged)",
        author = "Luminary Copilot",
        version = 2,
        class = "WARRIOR",
        spec = 73, -- Protection
        desc = "SimC APL. SW > SS > Rev > Dev."
    },
    
    layout = {
        slots = {
            [1] = { action = "shockwave" },
            [2] = { action = "shield_slam" },
            [3] = { action = "revenge" },
            [4] = { action = "devastate" },
            [5] = { action = "concussion_blow" },
            [6] = { action = "heroic_strike" }
        }
    },
    
    apl = {
        "actions+=/shockwave",
        "actions+=/shield_slam",
        "actions+=/revenge",
        "actions+=/devastate",
        "actions+=/concussion_blow",
        "actions+=/heroic_strike,if=rage>70"
    }
})
