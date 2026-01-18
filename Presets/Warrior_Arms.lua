-- This file represents the data structure that will be serialized for Import/Export.
-- It matches the 'ns.Modules.Warrior' structure used in the MVP.

local _, ns = ...

-- IDs are now managed in Core/Constants.lua
-- Access them via ns.ID.SpellName


ns.ProfileManager:RegisterPreset({
    meta = {
        name = "WotLK 武器战 (Titan-Forged)",
        author = "Skyline",
        version = 1,
        class = "WARRIOR",
        spec = 71, -- Arms
        desc = "Based on Hekili logic. Prioritizes Rend > Overpower > Execute."
    },
    
    layout = {
        -- Defines visuals and slots. 
        -- 'int_id' matches the return value of the script.
        slots = {
            [1] = { int_id = 1, id = ns.ID.MortalStrike }, -- MS
            [2] = { int_id = 2, id = ns.ID.Overpower },    -- OP
            [3] = { int_id = 3, id = ns.ID.Execute },      -- Exec
            [4] = { int_id = 4, id = ns.ID.Rend },         -- Rend
            [5] = { int_id = 5, id = ns.ID.Slam },         -- Slam
            [6] = { int_id = 6, id = ns.ID.Bladestorm }    -- BS
        }
    },
    
    -- The logic script to be compiled at runtime
    script = [[
        local target = env.target
        local player = env.player
        local spell = env.spell
        local buff = player.buff
        local debuff = target.debuff

        -- IDs are injected by Core (S_MortalStrike, etc.)
        
        local B_SuddenDeath = 52437 

        -- Logic Flow
        
        local execute_phase = target.health_pct < 20
        local rage = player.power.rage.current

        -- 1. Rend: < 3s remaining
        if debuff(S_Rend).remains < 3 and target.time_to_die > 6 then
            return 4 -- SLOT_REND
        end

        -- 2. Overpower
        if spell(S_Overpower).ready then 
            return 2 -- SLOT_OP
        end

        -- 3. Execute (Phase OR Sudden Death)
        if (execute_phase or buff(B_SuddenDeath).up) and spell(S_Execute).ready then
            return 3 -- SLOT_EXEC
        end

        -- 4. Bladestorm
        if not execute_phase and spell(S_Bladestorm).ready and not spell(S_Overpower).ready then
            return 6 -- SLOT_BS
        end

        -- 5. Mortal Strike
        if spell(S_MortalStrike).ready then
            return 1 -- SLOT_MS
        end

        -- 6. Slam (Filler)
        if rage >= 15 and spell(S_Slam).ready then 
            if not player.moving then
                return 5 -- SLOT_SLAM
            end
        end

        return nil
    ]]
})