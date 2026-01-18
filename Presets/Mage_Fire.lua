-- Fire Mage Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "Titan Fire Mage",
        author = "WhackAMole",
        version = 5,
        class = "MAGE",
        spec = 63, -- Fire
        desc = "SimC APL. 4T10 Mirror > Bomb > Hot Streak > Fireball."
    },
    
    layout = {
        slots = {
            [1] = { action = "fireball" },
            [2] = { action = "pyroblast" },
            [3] = { action = "living_bomb" },
            [4] = { action = "mirror_image" },
            [5] = { action = "combustion" },
            [6] = { action = "fire_blast" },
            [7] = { action = "scorch" },
            [8] = { action = "dragons_breath" }
        }
    },
    
    apl = {
        "actions+=/mirror_image",
        "actions+=/combustion,if=debuff.living_bomb.up",
        "actions+=/pyroblast,if=buff.hot_streak.up",
        "actions+=/living_bomb,if=debuff.living_bomb.down&target.health.pct>0",
        -- Maintain Critical Mass Debuff
        "actions+=/scorch,if=!debuff.improved_scorch.up&!debuff.shadow_mastery.up&!debuff.winters_chill.up&target.health.pct>0&!player.moving",
        -- Movement
        "actions+=/pyroblast,if=buff.hot_streak.up&player.moving",
        "actions+=/living_bomb,if=debuff.living_bomb.down&player.moving",
        "actions+=/fire_blast,if=player.moving",
        "actions+=/dragons_breath,if=player.moving",
        "actions+=/scorch,if=player.moving",
        -- Filler
        "actions+=/fireball,if=!player.moving"
    }
})
