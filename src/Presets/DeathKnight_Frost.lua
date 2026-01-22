-- Frost Death Knight Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 冰霜DK (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DEATHKNIGHT",
        spec = 251, -- Frost
        desc = "WotLK Frost DK for Titan Forged T1. Focus on Obliterate + Frost Strike + disease uptime."
    },
    
    layout = {
        slots = {
            [1] = { action = "obliterate" },
            [2] = { action = "frost_strike" },
            [3] = { action = "howling_blast" },
            [4] = { action = "blood_strike" },
            [5] = { action = "death_strike" },
            [6] = { action = "plague_strike" },
            [7] = { action = "icy_touch" },
            [8] = { action = "horn_of_winter" },
            [9] = { action = "pestilence" }
        }
    },
    
    apl = {
        -- Priority 1: Horn of Winter (runic power generation)
        -- 2T1: Generates 15 runic power instead of 10 (+5 RP)
        -- Use frequently to maintain high RP pool
        "actions+=/horn_of_winter,if=runic_power<60",
        
        -- Priority 2: Icy Touch (apply Frost Fever)
        -- Maintain disease uptime (10-15% of total damage)
        "actions+=/icy_touch,if=!debuff.frost_fever.up|debuff.frost_fever.remains<3",
        
        -- Priority 3: Plague Strike (apply Blood Plague)
        -- Maintain disease uptime (10-15% of total damage)
        "actions+=/plague_strike,if=!debuff.blood_plague.up|debuff.blood_plague.remains<3",
        
        -- Priority 4: Obliterate (Killing Machine proc - guaranteed crit)
        -- 4T1: +5% damage
        -- Highest priority when Killing Machine is active
        "actions+=/obliterate,if=buff.killing_machine.up",
        
        -- Priority 5: Frost Strike (Killing Machine proc - guaranteed crit)
        -- 4T1: +5% damage
        "actions+=/frost_strike,if=buff.killing_machine.up&runic_power>=40",
        
        -- Priority 6: Obliterate (normal - core rune spender)
        -- 4T1: +5% damage
        -- Consumes 1 Frost + 1 Unholy rune (or Death runes)
        "actions+=/obliterate",
        
        -- Priority 7: Frost Strike (normal - core RP spender)
        -- 4T1: +5% damage
        -- Use when RP >= 40
        "actions+=/frost_strike,if=runic_power>=40",
        
        -- Priority 8: Howling Blast (AoE/filler)
        -- Triggers Icy Talons buff
        "actions+=/howling_blast",
        
        -- Priority 9: Horn of Winter (filler - no CD)
        -- 2T1: Generates 15 runic power
        "actions+=/horn_of_winter,if=runic_power<100"
    }
})
