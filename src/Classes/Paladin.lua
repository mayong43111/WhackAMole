local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.PALADIN = {}

-- Paladin Spec Detection Logic
ns.SpecRegistry:Register("PALADIN", function()
    -- 51 Point Talents
    if IsPlayerSpell(53385) then return 70 end -- Divine Storm (Ret)
    if IsPlayerSpell(53651) then return 65 end -- Beacon of Light (Holy)
    if IsPlayerSpell(53595) then return 66 end -- Hammer of the Righteous (Prot)

    -- 31 Point Talents
    if IsPlayerSpell(20473) then return 65 end -- Holy Shock (Holy)
    if IsPlayerSpell(31935) then return 66 end -- Avenger's Shield (Prot)
    if IsPlayerSpell(35395) then return 70 end -- Crusader Strike (Ret)

    return nil
end)

-- 专精配置
ns.Classes.PALADIN[65] = {  -- Holy
    name = "神圣骑士",
}

ns.Classes.PALADIN[66] = {  -- Protection
    name = "防护骑士",
}

ns.Classes.PALADIN[70] = {  -- Retribution
    name = "惩戒骑士",
}
