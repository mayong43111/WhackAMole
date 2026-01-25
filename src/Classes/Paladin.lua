local _, ns = ...

-- ��ʼ��ְҵ�����ռ�
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
    [1022]   = { key = "HandOfProtection",    sound = "HandofProtection.ogg" },
    [1044]   = { key = "HandOfFreedom",       sound = "HandofFreedom.ogg" },
    [6940]   = { key = "HandOfSacrifice",     sound = "HandofSacrifice.ogg" },
    [498]    = { key = "DivineProtection",    sound = "DivineProtection.ogg" },
    [31821]  = { key = "AuraMastery",         sound = "AuraMastery.ogg" },
    [853]    = { key = "HammerOfJustice",     sound = "HammerofJustice.ogg" },
    
    -- Retribution DPS Abilities
    [31884]  = { key = "AvengingWrath",       sound = "AvengingWrath.ogg" },     -- ����֮ŭ
    [35395]  = { key = "CrusaderStrike",      sound = "CrusaderStrike.ogg" },    -- ʮ�־����
    
    -- Judgement Logic:
    -- Map "Judgement" to the baseline spell [20271] (Judgement of Light) for compatibility.
    -- Users should place the specific Judgement they want (Wisdom/Light/Justice) on their bar.
    [20271]  = { key = "Judgement",           sound = "Judgement.ogg" },         -- ����(����/ͨ��)
    -- Defining specific ones just in case
    [53408]  = { key = "JudgementOfWisdom",   sound = "Judgement.ogg" },
    [53407]  = { key = "JudgementOfJustice",  sound = "Judgement.ogg" },
    
    -- WotLK has Divine Storm, NOT Templar's Verdict (Cata)
    [53385]  = { key = "DivineStorm",         sound = "DivineStorm.ogg" },       -- ��ʥ�籩
    
    [48819]  = { key = "Consecration",        sound = "Consecration.ogg" },      -- ����
    [48817]  = { key = "HolyWrath",           sound = "HolyWrath.ogg" },         -- ��ʥ��ŭ
    [48801]  = { key = "Exorcism",            sound = "Exorcism.ogg" },          -- ��а��
    [48806]  = { key = "HammerOfWrath",       sound = "HammerofWrath.ogg" },     -- ��ŭ֮��
    [62124]  = { key = "HandOfReckoning",     sound = "Reckoning.ogg" },         -- 清算之手
    
    -- Holy/Protection Abilities
    [53563]  = { key = "BeaconOfLight",       sound = "BeaconofLight.ogg" },     -- ʥ�����
    [53595]  = { key = "HammerOfTheRighteous", sound = "HammeroftheRighteous.ogg" }, -- ����֮��(����)
    [20473]  = { key = "HolyShock",           sound = "HolyShock.ogg" },         -- ��ʥ���
    [31935]  = { key = "AvengersShield",      sound = "AvengersShield.ogg" },    -- ������֮��
}

ns.Classes.PALADIN[65] = {  -- Holy
    name = "��ʥ��ʿ",
    spells = paladinSpells,
}

ns.Classes.PALADIN[66] = {  -- Protection
    name = "������ʿ",
    spells = paladinSpells,
}

ns.Classes.PALADIN[70] = {  -- Retribution
    name = "�ͽ���ʿ",
    spells = paladinSpells,
}

-- �ֶ�ע�ᶯ��ӳ�䣬��ֹ�Զ������߼�ʧЧ�����˳������
if ns.ActionMap then
    local function toSnakeCase(str)
        local snake = str:gsub("(%u)", "_%1")
        if snake:sub(1,1) == "_" then snake = snake:sub(2) end
        return snake:lower()
    end

    for id, data in pairs(paladinSpells) do
        if data.key then
            -- 1. ע��ȫСд��ʽ (TemplarsVerdict -> templarsverdict)
            ns.ActionMap[string.lower(data.key)] = id
            
            -- 2. ע������������ʽ (TemplarsVerdict -> templars_verdict)
            local snakeKey = toSnakeCase(data.key)
            ns.ActionMap[snakeKey] = id
        end
    end
end
