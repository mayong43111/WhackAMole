-- Frost Mage Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 冰法 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "MAGE",
        spec = 64, -- Frost
        desc = "WotLK Frost for Titan Forged T1. Focus on Fingers of Frost and Brain Freeze."
    },

    layout = {
        slots = {
            [1] = { action = "frostbolt" },
            [2] = { action = "ice_lance" },
            [3] = { action = "deep_freeze" },
            [4] = { action = "frostfire_bolt" },
            [5] = { action = "cone_of_cold" },
            [6] = { action = "frost_nova" },
            [7] = { action = "blizzard" },
            [8] = { action = "mirror_image" }
        }
    },

    apl = {
        -- Priority 1: Mirror Image for burst
        "actions+=/mirror_image",
        -- Priority 2: Deep Freeze on Fingers of Frost
        "actions+=/deep_freeze,if=buff.fingers_of_frost.up",
        -- Priority 3: Consume Fingers of Frost with Ice Lance
        "actions+=/ice_lance,if=buff.fingers_of_frost.up",
        -- Priority 4: Consume Brain Freeze with Frostfire Bolt
        "actions+=/frostfire_bolt,if=buff.brain_freeze.up",
        -- Priority 5: Cone of Cold in melee range
        "actions+=/cone_of_cold,if=target.distance<10&!player.moving",
        -- Movement: Ice Lance
        "actions+=/ice_lance,if=player.moving",
        -- Main Filler: Frostbolt
        "actions+=/frostbolt,if=!player.moving"
    }
})
