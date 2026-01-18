local _, ns = ...

local S_Bloodthirst = 23881
local S_Whirlwind = 1680
local S_Slam = 1464
local S_Execute = 5308
local S_VictoryRush = 34428
local S_InstantSlamProc = 46916 -- Bloodsurge

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 狂暴战 (Titan-Forged)",
        author = "Luminary Copilot",
        version = 1,
        class = "WARRIOR",
        spec = 72, -- Fury
        desc = "Based on WotLK Fury Priority: BT > WW > Slam (Proc) > Execute."
    },
    
    layout = {
        slots = {
            [1] = { int_id = 1, id = S_Bloodthirst }, -- BT
            [2] = { int_id = 2, id = S_Whirlwind },   -- WW
            [3] = { int_id = 3, id = S_Slam },        -- Slam (Instant)
            [4] = { int_id = 4, id = S_Execute },     -- Execute
            [5] = { int_id = 5, id = S_VictoryRush }  -- VR (Free heal/dmg)
        }
    },
    
    script = [[
        local target = env.target
        local player = env.player
        local spell = env.spell
        local buff = player.buff
        local debuff = target.debuff

        local S_Bloodthirst = 23881
        local S_Whirlwind = 1680
        local S_Slam = 1464
        local S_Execute = 5308
        local S_VictoryRush = 34428
        
        local B_Bloodsurge = 46916 -- Instant Slam Proc
        local B_SuddenDeath = 52437 -- Arms talent, but just in case
        
        -- Logic Flow
        
        local execute_phase = target.health_pct < 20
        
        -- 1. Victory Rush (Free Damage/Heal if available, usually high prio for leveling/grinding)
        if spell(S_VictoryRush).usable then
            return 5 -- SLOT_VR
        end
        
        -- 2. Bloodthirst (Main Rage Generator)
        if spell(S_Bloodthirst).ready then
            return 1 -- SLOT_BT
        end
        
        -- 3. Whirlwind (Main AoE/Cleave Damage)
        if spell(S_Whirlwind).ready then
            return 2 -- SLOT_WW
        end
        
        -- 4. Slam (Only with Bloodsurge Proc)
        if buff(B_Bloodsurge).up and spell(S_Slam).ready then
            return 3 -- SLOT_SLAM (Instant)
        end
        
        -- 5. Execute
        -- In standard Fury rotation without secondary resource, Execute is used when available?
        -- Actually in 3.3.5 Fury Execute can be lower prio than BT/WW unless you have rage dump needs.
        -- We'll put it later.
        if execute_phase and spell(S_Execute).ready then
            return 4 -- SLOT_EXEC
        end
        
        -- 6. Casting Slam (Not recommended for Fury usually, but if nothing else to do and rage > 40?)
        -- Skipping hard cast slam for now.
        
        return nil
    ]]
})
