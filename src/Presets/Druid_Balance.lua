-- Balance Druid Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 平衡德 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DRUID",
        spec = 102, -- Balance
        desc = "WotLK Balance for Titan Forged T1. Focus on Eclipse rotation + DoT maintenance."
    },
    
    layout = {
        slots = {
            [1] = { action = "wrath" },
            [2] = { action = "starfire" },
            [3] = { action = "moonfire" },
            [4] = { action = "insect_swarm" },
            [5] = { action = "starfall" },
            [6] = { action = "force_of_nature" },
            [7] = { action = "typhoon" },
            [8] = { action = "hurricane" }
        }
    },
    
    apl = {
        -- Priority 1: Starfall (major burst CD)
        -- 4T1: Duration increased from 10s to 12s (+20% damage)
        "actions+=/starfall",
        
        -- Priority 2: Force of Nature (summon treants on CD)
        -- 2T1: Summons 4 treants instead of 3 (+33% treants)
        "actions+=/force_of_nature",
        
        -- Priority 3: Moonfire (maintain core DoT)
        -- Refresh when missing or <3 seconds remaining
        "actions+=/moonfire,if=!debuff.moonfire.up|debuff.moonfire.remains<3",
        
        -- Priority 4: Insect Swarm (maintain core DoT)
        -- Refresh when missing or <3 seconds remaining
        "actions+=/insect_swarm,if=!debuff.insect_swarm.up|debuff.insect_swarm.remains<3",
        
        -- Priority 5: Starfire (during Lunar Eclipse)
        -- Lunar Eclipse: +40% Starfire damage
        "actions+=/starfire,if=buff.lunar_eclipse.up",
        
        -- Priority 6: Wrath (during Solar Eclipse)
        -- Solar Eclipse: +40% Wrath damage
        "actions+=/wrath,if=buff.solar_eclipse.up",
        
        -- Priority 7: Wrath (default filler to push toward Solar Eclipse)
        "actions+=/wrath",
        
        -- Priority 8: Starfire (alternate filler)
        "actions+=/starfire",
        
        -- Priority 9: Typhoon (emergency filler/knockback)
        "actions+=/typhoon"
    }
})
