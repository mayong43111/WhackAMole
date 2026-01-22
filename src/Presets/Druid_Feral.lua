-- Feral Druid Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 猫德 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DRUID",
        spec = 103, -- Feral Combat
        desc = "WotLK Feral Cat for Titan Forged T1. Focus on Savage Roar uptime + DoT maintenance + combo point management."
    },
    
    layout = {
        slots = {
            [1] = { action = "mangle_cat" },
            [2] = { action = "rake" },
            [3] = { action = "shred" },
            [4] = { action = "rip" },
            [5] = { action = "ferocious_bite" },
            [6] = { action = "savage_roar" },
            [7] = { action = "swipe_cat" },
            [8] = { action = "berserk" },
            [9] = { action = "tigers_fury" }
        }
    },
    
    apl = {
        -- Priority 1: Savage Roar (MUST maintain 100% uptime - 30% damage boost)
        -- Emergency refresh at <2s even with 1 combo point
        "actions+=/savage_roar,if=!buff.savage_roar.up|buff.savage_roar.remains<2,combo_points>=1",
        
        -- Priority 2: Berserk (major burst CD - use with Tiger's Fury)
        -- 4T1: Duration increased from 15s to 18s (+20% burst window)
        "actions+=/berserk,if=buff.tigers_fury.up",
        
        -- Priority 3: Tiger's Fury (energy restore + 15% damage buff)
        -- Use at <30 energy to avoid overflow
        "actions+=/tigers_fury,if=energy<30",
        
        -- Priority 4: Rake (maintain bleed DoT)
        -- 15-20% of total damage
        "actions+=/rake,if=!debuff.rake.up|debuff.rake.remains<3",
        
        -- Priority 5: Rip (maintain highest damage DoT at 5 combo points)
        -- 25-30% of total damage
        "actions+=/rip,if=(!debuff.rip.up|debuff.rip.remains<3)&combo_points>=5",
        
        -- Priority 6: Ferocious Bite (finisher at 5 combo points)
        -- Only when Rake + Rip are active and Savage Roar >10s
        "actions+=/ferocious_bite,if=combo_points>=5&debuff.rake.up&debuff.rip.up&buff.savage_roar.remains>10",
        
        -- Priority 7: Mangle (combo point builder - 1s CD)
        -- Free during Berserk
        "actions+=/mangle_cat,if=combo_points<5",
        
        -- Priority 8: Shred (high damage combo point builder - requires backstab position)
        -- 42 energy cost (or free with Omen of Clarity)
        "actions+=/shred,if=combo_points<5&energy>=42",
        
        -- Priority 9: Swipe (AoE ability)
        -- 2T1: Energy cost reduced from 50 to 45
        "actions+=/swipe_cat,if=active_enemies>=2&energy>=45"
    }
})
