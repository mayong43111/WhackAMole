-- Fire Mage Profile for WhackAMole (Titan-Forged / 3.3.5a)
-- 泰坦服务�?火法输出方案

local _, ns = ...

-- Spell IDs are managed in Core/Constants.lua
-- Buff/Debuff IDs
local B_HotStreak = 48108
local D_Scorch    = 22959
local D_Shadow    = 17800 -- Improved Shadow Bolt (Warlock)
local D_Winters   = 12579 -- Winter's Chill (Frost Mage)

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "Titan Fire Mage",
        author = "WhackAMole",
        version = 4,
        class = "MAGE",
        spec = 63, -- Fire (WotLK)
        desc = "Titan. 4T10 Mirror > Bomb > Hot Streak > Fireball.\n(Scorch only if missing debuff)"
    },
    
    layout = {
        slots = {
            -- Row 1: Main Action (Freq High)
            [1] = { int_id = 1, id = ns.ID.Fireball },  -- Filler
            [2] = { int_id = 2, id = ns.ID.Pyroblast }, -- Proc
            [3] = { int_id = 3, id = ns.ID.LivingBomb },-- DoT
            [4] = { int_id = 7, id = ns.ID.Scorch },    -- Debuff
            
            -- Row 2: Movement / Situational 
            [5] = { int_id = 6, id = ns.ID.FireBlast }, -- Move
            
            -- Row 2 (End): Big CDs (Rarely clicked)
            [6] = { int_id = 5, id = ns.ID.Combustion },
            [7] = { int_id = 4, id = ns.ID.MirrorImage },
            
            -- Row 3: Utility (Optional)
            [8] = { int_id = 8, id = ns.ID.DragonsBreath }
        }
    },
    
    script = [[
        local target = env.target
        local player = env.player
        local spell = env.spell
        local buff = player.buff
        local debuff = target.debuff

        -- Spell IDs
        -- Injected by Core/Constants.lua

        
        local B_HotStreak = 48108
        -- Debuff Group: Critical Mass (5% Spell Crit)
        local D_Scorch    = 22959
        local D_Shadow    = 17800
        local D_Winters   = 12579

        -- 1. Mirror Image (Titan 4T10 Burst)
        if spell(S_MirrorImage).ready then
            return 4
        end

        -- 2. Combustion
        if spell(S_Combustion).ready and debuff(S_LivingBomb).up then
            return 5
        end

        -- 3. Hot Streak (Instant Pyro)
        if buff(B_HotStreak).up then
            return 2
        end

        -- 4. Living Bomb (Apply if missing)
        -- Logic: If NOT Up AND (Target High HP or Boss)
        -- Note: target.time_to_die is placeholder 99.
        if debuff(S_LivingBomb).down and target.health_pct > 0 then
            return 3
        end

        -- 5. Scorch (Critical Debuff)
        
        -- Use ID lookup (Engine handles Name conversion automatically)
        -- 22959: Improved Scorch (Mage)
        -- 17800: Shadow Mastery (Warlock)
        -- 12579: Winter's Chill (Frost Mage)
        local hasCritDebuff = debuff(D_Scorch).up or debuff(D_Shadow).up or debuff(D_Winters).up
        
        -- Latency Protection: Assume we have it if casting Scorch
        local scorchName = GetSpellInfo(S_Scorch)
        local currentCast = UnitCastingInfo("player")
        if currentCast == scorchName then
             hasCritDebuff = true
        end
        
        -- Talent Check (Rank 1 ID)
        local hasTalent = IsSpellKnown(11095) 

        -- Logic: If I have the talent, AND the debuff is missing, AND target is worthy (alive)
        if hasTalent and not hasCritDebuff and target.health_pct > 0 and not player.moving then
            return 7
        end

        -- 6. Movement Rotation
        if player.moving then
            if buff(B_HotStreak).up then return 2 end
            if debuff(S_LivingBomb).down then return 3 end
            if spell(S_FireBlast).ready then return 6 end
            if spell(S_DragonsBreath).ready then return 8 end
            return 7 -- Fallback to Scorch while moving
        end

        -- 7. Filler (Fireball)
        return 1
    ]]
})
