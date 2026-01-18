local _, ns = ...

-- Mage Spec Detection Logic
ns.SpecRegistry:Register("MAGE", function()
    -- Arcane: Arcane Barrage (44425)
    if IsPlayerSpell(44425) then return 62 end
    
    -- Fire: Living Bomb (44457) or Dragon's Breath (31661)
    if IsPlayerSpell(44457) or IsPlayerSpell(31661) then return 63 end
    
    -- Frost: Deep Freeze (44572)
    if IsPlayerSpell(44572) then return 64 end

    return nil
end)
