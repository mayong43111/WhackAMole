local _, ns = ...

-- Death Knight Spec Detection Logic
ns.SpecRegistry:Register("DEATHKNIGHT", function()
    -- Key Talents
    if IsPlayerSpell(55050) then return 250 end -- Heart Strike (Blood)
    if IsPlayerSpell(49143) then return 251 end -- Frost Strike (Frost)
    if IsPlayerSpell(55090) then return 252 end -- Scourge Strike (Unholy)
    
    -- Alternatives?
    if IsPlayerSpell(49028) then return 250 end -- Dancing Rune Weapon (Blood 51)
    if IsPlayerSpell(49184) then return 251 end -- Howling Blast (Frost 51)
    if IsPlayerSpell(49206) then return 252 end -- Summon Gargoyle (Unholy 51)

    return nil
end)
