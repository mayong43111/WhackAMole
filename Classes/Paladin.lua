local _, ns = ...

-- Paladin Spec Detection Logic
ns.SpecRegistry:Register("PALADIN", function()
    -- 51 Point Talents
    if IsPlayerSpell(53385) then return 70 end -- Divine Storm (Ret)
    -- Beacon of Light (Holy) 53651 ? 
    if IsPlayerSpell(53651) then return 65 end 
    -- Hammer of the Righteous (Prot) 53595
    if IsPlayerSpell(53595) then return 66 end

    -- 31 Point Talents
    if IsPlayerSpell(20473) then return 65 end -- Holy Shock (Holy)
    if IsPlayerSpell(31935) then return 66 end -- Avenger's Shield (Prot)
    if IsPlayerSpell(35395) then return 70 end -- Crusader Strike (Ret)

    return nil
end)
