local _, ns = ...

local S_Revenge = 6572
local S_ShieldSlam = 23922
local S_Shockwave = 46968
local S_Devastate = 20243
local S_ConcussionBlow = 12809
local S_Execute = 5308
local S_HeroicStrike = 78

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 防御战 (Titan-Forged)",
        author = "Luminary Copilot",
        version = 1,
        class = "WARRIOR",
        spec = 73, -- Protection
        desc = "Based on WotLK Prot Priority: SW (AoE) > Rev > SS > Dev."
    },
    
    layout = {
        slots = {
            [1] = { int_id = 1, id = S_Shockwave },      -- Shockwave (AoE/Stun)
            [2] = { int_id = 2, id = S_ShieldSlam },     -- Shield Slam (Threat)
            [3] = { int_id = 3, id = S_Revenge },        -- Revenge (Cleave/Threat)
            [4] = { int_id = 4, id = S_Devastate },      -- Devastate (Filler)
            [5] = { int_id = 5, id = S_ConcussionBlow }, -- CC
            [6] = { int_id = 6, id = S_HeroicStrike }    -- HS (Rage Dump)
        }
    },
    
    script = [[
        local target = env.target
        local player = env.player
        local spell = env.spell
        
        local S_Revenge = 6572
        local S_ShieldSlam = 23922
        local S_Shockwave = 46968
        local S_Devastate = 20243
        local S_ConcussionBlow = 12809
        local S_HeroicStrike = 78
        
        local rage = player.power.rage.current
        
        -- Logic Flow (Basic Threat / Mitigation)
        
        -- 1. Shockwave (On CD for AoE Threat or Stun)
        -- In single target maybe lower prio, but for general mapping high works.
        if spell(S_Shockwave).ready then
            return 1 
        end
        
        -- 2. Shield Slam (High Threat)
        if spell(S_ShieldSlam).ready then
            return 2
        end
        
        -- 3. Revenge (Must be Usable - Block/Dodge/Parry)
        if spell(S_Revenge).usable then
            return 3
        end
        
        -- 4. Devastate (Filler)
        if spell(S_Devastate).ready then
            return 4
        end
        
        -- 5. Concussion Blow (If nothing else)
        if spell(S_ConcussionBlow).ready then
            return 5
        end
        
        -- 6. Heroic Strike (Off GCD Dump)
        -- Visualizing Off-GCD spells is tricky in "Next Slot" paradigm.
        -- Usually we only highlight main GCD abilities.
        -- But if we have tons of Rage (> 70), we light it up.
        if rage > 70 then
            return 6
        end
        
        return nil
    ]]
})
