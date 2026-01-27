local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.DEATHKNIGHT = {}

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

-- 专精配置
ns.Classes.DEATHKNIGHT[250] = {  -- Blood
    name = "鲜血死骑",
}

ns.Classes.DEATHKNIGHT[251] = {  -- Frost
    name = "冰霜死骑",
}

ns.Classes.DEATHKNIGHT[252] = {  -- Unholy
    name = "邪恶死骑",
}
