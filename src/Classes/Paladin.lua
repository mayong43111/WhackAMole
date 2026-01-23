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
    [1022]   = { key = "HandOfProtection",    sound = "HandofProtection.ogg" },
    [1044]   = { key = "HandOfFreedom",       sound = "HandofFreedom.ogg" },
    [6940]   = { key = "HandOfSacrifice",     sound = "HandofSacrifice.ogg" },
    [498]    = { key = "DivineProtection",    sound = "DivineProtection.ogg" },
    [31821]  = { key = "AuraMastery",         sound = "AuraMastery.ogg" },
    [853]    = { key = "HammerOfJustice",     sound = "HammerofJustice.ogg" },
    
    -- Retribution DPS Abilities
    [31884]  = { key = "AvengingWrath",       sound = "AvengingWrath.ogg" },     -- 复仇之怒
    [35395]  = { key = "CrusaderStrike",      sound = "CrusaderStrike.ogg" },    -- 十字军打击
    
    -- Judgement Logic:
    -- Map "Judgement" to the baseline spell [20271] (Judgement of Light) for compatibility.
    -- Users should place the specific Judgement they want (Wisdom/Light/Justice) on their bar.
    [20271]  = { key = "Judgement",           sound = "Judgement.ogg" },         -- 审判(光明/通用)
    -- Defining specific ones just in case
    [53408]  = { key = "JudgementOfWisdom",   sound = "Judgement.ogg" },
    [53407]  = { key = "JudgementOfJustice",  sound = "Judgement.ogg" },
    
    -- WotLK has Divine Storm, NOT Templar's Verdict (Cata)
    [53385]  = { key = "DivineStorm",         sound = "DivineStorm.ogg" },       -- 神圣风暴
    
    [48819]  = { key = "Consecration",        sound = "Consecration.ogg" },      -- 奉献
    [48817]  = { key = "HolyWrath",           sound = "HolyWrath.ogg" },         -- 神圣愤怒
    [48801]  = { key = "Exorcism",            sound = "Exorcism.ogg" },          -- 驱邪术
    [48806]  = { key = "HammerOfWrath",       sound = "HammerofWrath.ogg" },     -- 愤怒之锤
    
    -- Holy/Protection Abilities
    [53563]  = { key = "BeaconOfLight",       sound = "BeaconofLight.ogg" },     -- 圣光道标
    [53595]  = { key = "HammerOfTheRighteous", sound = "HammeroftheRighteous.ogg" }, -- 正义之锤(防护)
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

-- 手动注册动作映射，防止自动生成逻辑失效或加载顺序问题
if ns.ActionMap then
    local function toSnakeCase(str)
        local snake = str:gsub("(%u)", "_%1")
        if snake:sub(1,1) == "_" then snake = snake:sub(2) end
        return snake:lower()
    end

    for id, data in pairs(paladinSpells) do
        if data.key then
            -- 1. 注册全小写形式 (TemplarsVerdict -> templarsverdict)
            ns.ActionMap[string.lower(data.key)] = id
            
            -- 2. 注册蛇形命名形式 (TemplarsVerdict -> templars_verdict)
            local snakeKey = toSnakeCase(data.key)
            ns.ActionMap[snakeKey] = id
        end
    end
end
