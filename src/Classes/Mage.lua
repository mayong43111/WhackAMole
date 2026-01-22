local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.MAGE = {}

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

-- Mage Spell Database
local mageSpells = {
    -- 通用技能
    [45438]  = { key = "IceBlock",            sound = "IceBlock.ogg" },
    [12051]  = { key = "Evocation",           sound = "Evocation.ogg" },
    [2139]   = { key = "Counterspell",        sound = "Counterspell.ogg" },
    [118]    = { key = "Polymorph",           sound = "Polymorph.ogg" },
    [55342]  = { key = "MirrorImage",         sound = "MirrorImage.ogg" },
    [1463]   = { key = "ManaShield",          sound = "ManaShield.ogg" },
    [7301]   = { key = "FrostArmor",          sound = "FrostArmor.ogg" },
    [30482]  = { key = "MoltenArmor",         sound = "MoltenArmor.ogg" },
    [6117]   = { key = "MageArmor",           sound = "MageArmor.ogg" },
    [66]     = { key = "Invisibility",        sound = "Invisibility.ogg" },
    [30449]  = { key = "Spellsteal",          sound = "Spellsteal.ogg" },
    [475]    = { key = "RemoveCurse",         sound = "RemoveCurse.ogg" },
    
    -- Fire 专精
    [55360]  = { key = "LivingBomb",          sound = "LivingBomb.ogg" },
    [42891]  = { key = "Pyroblast",           sound = "Pyroblast.ogg" },
    [42833]  = { key = "Fireball",            sound = "Fireball.ogg" },
    [42859]  = { key = "Scorch",              sound = "Scorch.ogg" },
    [11129]  = { key = "Combustion",          sound = "Combustion.ogg" },
    [42873]  = { key = "FireBlast",           sound = "FireBlast.ogg" },
    [42950]  = { key = "DragonsBreath",       sound = "DragonsBreath.ogg" },
    [48108]  = { key = "HotStreak" },         -- Buff
    [22959]  = { key = "ImprovedScorch" },    -- Debuff
    
    -- Frost 专精
    [116]    = { key = "Frostbolt",           sound = "Frostbolt.ogg" },
    [30455]  = { key = "IceLance",            sound = "IceLance.ogg" },
    [122]    = { key = "FrostNova",           sound = "FrostNova.ogg" },
    [11958]  = { key = "ColdSnap",            sound = "ColdSnap.ogg" },
    [31687]  = { key = "SummonWaterElemental", sound = "SummonWaterElemental.ogg" },
    [44572]  = { key = "DeepFreeze",          sound = "DeepFreeze.ogg" },
    [44544]  = { key = "FingersOfFrost" },    -- Buff
    [57761]  = { key = "BrainFreeze" },       -- Buff
    [12472]  = { key = "IcyVeins",            sound = "IcyVeins.ogg" },
    [12579]  = { key = "WintersChill" },      -- Debuff
    
    -- Arcane 专精
    [30451]  = { key = "ArcaneBlast",         sound = "ArcaneBlast.ogg" },
    [5143]   = { key = "ArcaneMissiles",      sound = "ArcaneMissiles.ogg" },
    [44425]  = { key = "ArcaneBarrage",       sound = "ArcaneBarrage.ogg" },
    [12042]  = { key = "ArcanePower",         sound = "ArcanePower.ogg" },
    [12043]  = { key = "PresenceOfMind",      sound = "PresenceOfMind.ogg" },
    [44401]  = { key = "MissileBarrage" },    -- Buff
    [17800]  = { key = "ShadowMastery" },     -- Debuff
}

-- 专精配置
ns.Classes.MAGE[62] = {  -- Arcane
    name = "奥术法师",
    spells = mageSpells,
}

ns.Classes.MAGE[63] = {  -- Fire
    name = "火焰法师",
    spells = mageSpells,
}

ns.Classes.MAGE[64] = {  -- Frost
    name = "冰霜法师",
    spells = mageSpells,
}
