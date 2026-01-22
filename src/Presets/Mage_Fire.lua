-- Fire Mage Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 火法 (T1)",
        author = "WhackAMole",
        version = 7,
        class = "MAGE",
        spec = 63, -- Fire
        desc = "WotLK Fire for Titan Forged T1. Focus on Hot Streak spam."
    },
    
    layout = {
        slots = {
            [1] = { action = "fireball" },
            [2] = { action = "pyroblast" },
            [3] = { action = "living_bomb" },
            [4] = { action = "scorch" },
            [5] = { action = "combustion" },
            [6] = { action = "mirror_image" },
            [7] = { action = "fire_blast" }
            -- 注意: 龙息术(Dragons Breath)不在DPS循环中，需要时手动放到技能栏
        }
    },
    
    apl = {
        -- Priority 1: Mirror Image for burst (18% spell power buff!)
        "actions+=/mirror_image",
        -- Priority 2: Consume Hot Streak (4T1 makes this proc very often!)
        "actions+=/pyroblast,if=buff.hot_streak.up",
        -- Priority 3: Maintain Living Bomb (wait for explosion, don't clip)
        "actions+=/living_bomb,if=debuff.living_bomb.down&target.health.pct>0",
        -- Priority 4: Use Combustion on CD (synergizes with 4T1 to generate more Hot Streaks)
        "actions+=/combustion,if=debuff.living_bomb.up",
        -- Priority 5: Maintain 5% Crit Debuff (if missing)
        "actions+=/scorch,if=!debuff.improved_scorch.up&!debuff.shadow_mastery.up&!debuff.winters_chill.up&target.health.pct>0&!player.moving",
        -- Movement: Consume Hot Streak first, then Fire Blast
        "actions+=/pyroblast,if=buff.hot_streak.up&player.moving",
        "actions+=/fire_blast,if=player.moving",
        "actions+=/scorch,if=player.moving",
        -- Main Filler: Fireball (spam until Hot Streak procs)
        "actions+=/fireball,if=!player.moving"
    }
})
