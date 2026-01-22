-- Retribution Paladin Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 惩戒骑 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "PALADIN",
        spec = 70, -- Retribution
        desc = "WotLK Retribution for Titan Forged T1. Focus on Crusader Strike > Judgement > Holy Power management."
    },
    
    layout = {
        slots = {
            [1] = { action = "crusader_strike" },
            [2] = { action = "judgement" },
            [3] = { action = "templars_verdict" },
            [4] = { action = "avenging_wrath" },
            [5] = { action = "consecration" },
            [6] = { action = "divine_storm" },
            [7] = { action = "holy_wrath" },
            [8] = { action = "exorcism" },
            [9] = { action = "hammer_of_wrath" }
        }
    },
    
    apl = {
        -- Priority 1: Avenging Wrath (use on CD for burst)
        "actions+=/avenging_wrath",
        
        -- Priority 2: Crusader Strike (Holy Power generation + 4T1 proc)
        -- 4T1: Crit has 10% chance to enhance next Templar's Verdict by 50%
        "actions+=/crusader_strike",
        
        -- Priority 3: Judgement (high damage, use on CD)
        -- 2T1: +3% damage
        "actions+=/judgement",
        
        -- Priority 4: Templar's Verdict (Holy Power spender)
        -- Use at 3 Holy Power or when 4T1 enhanced buff is active
        "actions+=/templars_verdict,if=holy_power>=3",
        
        -- Priority 5: Hammer of Wrath (execute ability)
        -- Only usable below 20% HP or during Avenging Wrath
        "actions+=/hammer_of_wrath,if=target.health.pct<20|buff.avenging_wrath.up",
        
        -- Priority 6: Exorcism (when Art of War procs)
        "actions+=/exorcism,if=buff.the_art_of_war.up",
        
        -- Priority 7: Consecration (filler with ground AoE)
        -- 2T1: +2 seconds duration (8s -> 10s)
        "actions+=/consecration,if=!debuff.consecration.up",
        
        -- Priority 8: Holy Wrath (CD ability, good against demons/undead)
        "actions+=/holy_wrath",
        
        -- Priority 9: Divine Storm (AoE Holy Power spender)
        -- Use in multi-target scenarios
        "actions+=/divine_storm,if=active_enemies>=2&holy_power>=3"
    }
})
