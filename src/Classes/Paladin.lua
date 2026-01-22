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
    -- Defensive/Utility
    [642]    = { key = "DivineShield",        sound = "DivineShield.ogg" },
    [1022]   = { key = "HandofProtection",    sound = "HandofProtection.ogg" },
    [1044]   = { key = "HandofFreedom",       sound = "HandofFreedom.ogg" },
    [6940]   = { key = "HandofSacrifice",     sound = "HandofSacrifice.ogg" },
    [498]    = { key = "DivineProtection",    sound = "DivineProtection.ogg" },
    [31821]  = { key = "AuraMastery",         sound = "AuraMastery.ogg" },
    [853]    = { key = "HammerofJustice",     sound = "HammerofJustice.ogg" },
    [96231]  = { key = "Rebuke",              sound = "Rebuke.ogg" },
    
    -- Retribution DPS Abilities
    [31884]  = { key = "AvengingWrath",       sound = "AvengingWrath.ogg" },     -- 复仇之怒
    [35395]  = { key = "CrusaderStrike",      sound = "CrusaderStrike.ogg" },    -- 十字军打击
    [20271]  = { key = "Judgement",           sound = "Judgement.ogg" },         -- 审判
    [85256]  = { key = "TemplarsVerdict",     sound = "TemplarsVerdict.ogg" },   -- 圣殿骑士的裁决
    [53385]  = { key = "DivineStorm",         sound = "DivineStorm.ogg" },       -- 神圣风暴
    [48819]  = { key = "Consecration",        sound = "Consecration.ogg" },      -- 奉献
    [48817]  = { key = "HolyWrath",           sound = "HolyWrath.ogg" },         -- 神圣愤怒
    [48801]  = { key = "Exorcism",            sound = "Exorcism.ogg" },          -- 驱邪术
    [48806]  = { key = "HammerofWrath",       sound = "HammerofWrath.ogg" },     -- 正义之锤
    
    -- Holy/Protection Abilities
    [53563]  = { key = "BeaconofLight",       sound = "BeaconofLight.ogg" },     -- 圣光道标
    [53595]  = { key = "HammeroftheRighteous", sound = "HammeroftheRighteous.ogg" }, -- 正义之锤(防护)
    [20473]  = { key = "HolyShock",           sound = "HolyShock.ogg" },         -- 神圣震击
    [31935]  = { key = "AvengersShield",      sound = "AvengersShield.ogg" },    -- 复仇者之盾
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
