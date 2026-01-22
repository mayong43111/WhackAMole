local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.PALADIN = {}

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

-- Paladin Spell Database
local paladinSpells = {
    [642]    = { key = "DivineShield",        sound = "DivineShield.ogg" },
    [1022]   = { key = "HandofProtection",    sound = "HandofProtection.ogg" },
    [1044]   = { key = "HandofFreedom",       sound = "HandofFreedom.ogg" },
    [6940]   = { key = "HandofSacrifice",     sound = "HandofSacrifice.ogg" },
    [31884]  = { key = "AvengingWrath",       sound = "AvengingWrath.ogg" },
    [498]    = { key = "DivineProtection",    sound = "DivineProtection.ogg" },
    [31821]  = { key = "AuraMastery",         sound = "AuraMastery.ogg" },
    [853]    = { key = "HammerofJustice",     sound = "HammerofJustice.ogg" },
    [96231]  = { key = "Rebuke",              sound = "Rebuke.ogg" },
}

ns.Classes.PALADIN[65] = {  -- Holy
    name = "神圣骑士",
    spells = paladinSpells,
}

ns.Classes.PALADIN[66] = {  -- Protection
    name = "防护骑士",
    spells = paladinSpells,
}

ns.Classes.PALADIN[70] = {  -- Retribution
    name = "惩戒骑士",
    spells = paladinSpells,
}
