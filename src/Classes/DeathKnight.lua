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

-- Death Knight Spell Database
local deathKnightSpells = {
    [48707]  = { key = "AntiMagicShell",      sound = "AntiMagicShell.ogg" },
    [48792]  = { key = "IceboundFortitude",   sound = "IceboundFortitude.ogg" },
    [49028]  = { key = "DancingRuneWeapon",   sound = "DancingRuneWeapon.ogg" },
    [49039]  = { key = "Lichborne",           sound = "Lichborne.ogg" },
    [55233]  = { key = "VampiricBlood",       sound = "VampiricBlood.ogg" },
    [49222]  = { key = "BoneShield",          sound = "BoneShield.ogg" },
    [47476]  = { key = "Strangulate",         sound = "Strangulate.ogg" },
    [47528]  = { key = "MindFreeze",          sound = "MindFreeze.ogg" },
    [51271]  = { key = "PillarofFrost",       sound = "PillarofFrost.ogg" },
    [49206]  = { key = "SummonGargoyle",      sound = "SummonGargoyle.ogg" },
    [63560]  = { key = "DarkTransformation",  sound = "DarkTransformation.ogg" },
    [108194] = { key = "Asphyxiate",          sound = "Asphyxiate.ogg" },
}

ns.Classes.DEATHKNIGHT[250] = {  -- Blood
    name = "鲜血死骑",
    spells = deathKnightSpells,
}

ns.Classes.DEATHKNIGHT[251] = {  -- Frost
    name = "冰霜死骑",
    spells = deathKnightSpells,
}

ns.Classes.DEATHKNIGHT[252] = {  -- Unholy
    name = "邪恶死骑",
    spells = deathKnightSpells,
}
