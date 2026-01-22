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
    -- ==================== Core DPS Abilities ====================
    -- Frost
    [51425]  = { key = "Obliterate",          sound = "Obliterate.ogg",         desc = "核心技能，消耗冰霜+邪恶符文" },
    [55268]  = { key = "FrostStrike",         sound = "FrostStrike.ogg",        desc = "符能消耗，40符能" },
    [51411]  = { key = "HowlingBlast",        sound = "HowlingBlast.ogg",       desc = "AOE技能，冰霜符文" },
    [49909]  = { key = "IcyTouch",            sound = "IcyTouch.ogg",           desc = "施加冰霜疫病" },
    [49921]  = { key = "PlagueStrike",        sound = "PlagueStrike.ogg",       desc = "施加血腥疫病" },
    [57623]  = { key = "HornOfWinter",        sound = "HornOfWinter.ogg",       desc = "产生符能，无CD" },
    [50842]  = { key = "Pestilence",          sound = "Pestilence.ogg",         desc = "传播疫病" },
    
    -- Blood/Unholy shared
    [49998]  = { key = "DeathStrike",         sound = "DeathStrike.ogg",        desc = "治疗+伤害" },
    [49930]  = { key = "BloodStrike",         sound = "BloodStrike.ogg",        desc = "鲜血打击" },
    [55050]  = { key = "HeartStrike",         sound = "HeartStrike.ogg",        desc = "心脏打击（鲜血）" },
    [55090]  = { key = "ScourgeStrike",       sound = "ScourgeStrike.ogg",      desc = "天灾打击（邪恶）" },
    
    -- ==================== Defensive/Utility ====================
    [48707]  = { key = "AntiMagicShell",      sound = "AntiMagicShell.ogg",     desc = "反魔法护罩" },
    [48792]  = { key = "IceboundFortitude",   sound = "IceboundFortitude.ogg",  desc = "冰封之韧" },
    [49028]  = { key = "DancingRuneWeapon",   sound = "DancingRuneWeapon.ogg",  desc = "符文刃舞（鲜血）" },
    [49039]  = { key = "Lichborne",           sound = "Lichborne.ogg",          desc = "巫妖之躯" },
    [55233]  = { key = "VampiricBlood",       sound = "VampiricBlood.ogg",      desc = "吸血鬼之血（鲜血）" },
    [49222]  = { key = "BoneShield",          sound = "BoneShield.ogg",         desc = "白骨之盾（邪恶）" },
    [47476]  = { key = "Strangulate",         sound = "Strangulate.ogg",        desc = "绞袭，打断" },
    [47528]  = { key = "MindFreeze",          sound = "MindFreeze.ogg",         desc = "心灵冰冻，打断" },
    
    -- ==================== Cooldowns ====================
    [51271]  = { key = "PillarOfFrost",       sound = "PillarOfFrost.ogg",      desc = "冰霜之柱（冰霜）" },
    [49206]  = { key = "SummonGargoyle",      sound = "SummonGargoyle.ogg",     desc = "召唤石像鬼（邪恶）" },
    [63560]  = { key = "DarkTransformation",  sound = "DarkTransformation.ogg", desc = "黑暗突变（邪恶）" },
    [56222]  = { key = "DarkCommand",         sound = "DarkCommand.ogg",        desc = "黑暗命令，嘲讽" },
    [56815]  = { key = "RuneStrike",          sound = "RuneStrike.ogg",         desc = "符文打击，招架后可用" },
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
