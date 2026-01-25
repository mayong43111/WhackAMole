-- Classes/Druid.lua
-- Druid class definition with spell database and spec detection
local _, ns = ...

-- 初始化职业数据空间
ns.Classes = ns.Classes or {}
ns.Classes.DRUID = {}

-- Druid Spec Detection Logic
ns.SpecRegistry:Register("DRUID", function()
    -- 51点天赋
    if IsPlayerSpell(53201) then return 102 end -- Starfall (Balance)
    if IsPlayerSpell(50334) then return 103 end -- Berserk (Feral)
    if IsPlayerSpell(33891) then return 105 end -- Tree of Life (Restoration)
    
    -- 31点天赋
    if IsPlayerSpell(33831) then return 102 end -- Force of Nature (Balance)
    if IsPlayerSpell(48566) or IsPlayerSpell(48564) then return 103 end -- Mangle (Feral)
    
    return nil
end)

-- Druid Spell Database
local druidSpells = {
    -- ==================== Balance (平衡) ====================
    [48461]  = { key = "Wrath",           sound = "Wrath.ogg" },
    [48465]  = { key = "Starfire",        sound = "Starfire.ogg" },
    [48463]  = { key = "Moonfire",        sound = "Moonfire.ogg" },
    [48468]  = { key = "InsectSwarm",     sound = "InsectSwarm.ogg" },
    [53201]  = { key = "Starfall",        sound = "Starfall.ogg" },
    [33831]  = { key = "ForceOfNature",   sound = "ForceOfNature.ogg" },
    [61384]  = { key = "Typhoon",         sound = "Typhoon.ogg" },
    [48467]  = { key = "Hurricane",       sound = "Hurricane.ogg" },
    [770]    = { key = "FaerieFire",      sound = "FaerieFire.ogg" },
    [24858]  = { key = "MoonkinForm",     sound = "MoonkinForm.ogg" },
    
    -- ==================== Feral (野性战斗) ====================
    [48566]  = { key = "MangleCat",       sound = "MangleCat.ogg" },
    [48574]  = { key = "Rake",            sound = "Rake.ogg" },
    [49800]  = { key = "Rip",             sound = "Rip.ogg" },
    [48577]  = { key = "FerociousBite",   sound = "FerociousBite.ogg" },
    [48572]  = { key = "Shred",           sound = "Shred.ogg" },
    [52610]  = { key = "SavageRoar",      sound = "SavageRoar.ogg" },
    [62078]  = { key = "SwipeCat",        sound = "SwipeCat.ogg" },
    [50334]  = { key = "Berserk",         sound = "Berserk.ogg" },
    [50213]  = { key = "TigersFury",      sound = "TigersFury.ogg" },
    [48480]  = { key = "Maul",            sound = "Maul.ogg" },
    [48562]  = { key = "SwipeBear",       sound = "SwipeBear.ogg" },
    [48564]  = { key = "MangleBear",      sound = "MangleBear.ogg" },
    [768]    = { key = "CatForm",         sound = "CatForm.ogg" },
    [5487]   = { key = "BearForm",        sound = "BearForm.ogg" },
    [9634]   = { key = "DireBearForm",    sound = "DireBearForm.ogg" },
    
    -- ==================== Restoration (恢复) ====================
    [48441]  = { key = "Rejuvenation",    sound = "Rejuvenation.ogg" },
    [48443]  = { key = "Regrowth",        sound = "Regrowth.ogg" },
    [50464]  = { key = "Nourish",         sound = "Nourish.ogg" },
    [48378]  = { key = "HealingTouch",    sound = "HealingTouch.ogg" },
    [53251]  = { key = "WildGrowth",      sound = "WildGrowth.ogg" },
    [18562]  = { key = "Swiftmend",       sound = "Swiftmend.ogg" },
    [48447]  = { key = "Tranquility",     sound = "Tranquility.ogg" },
    [33891]  = { key = "TreeOfLife",      sound = "TreeOfLife.ogg" },
    [22812]  = { key = "Barkskin",        sound = "Barkskin.ogg" },
    [29166]  = { key = "Innervate",       sound = "Innervate.ogg" },
    
    -- ==================== 通用技能 ====================
    [48469]  = { key = "MarkOfTheWild",   sound = "MarkOfTheWild.ogg" },
    [53307]  = { key = "Thorns",          sound = "Thorns.ogg" },
    [48477]  = { key = "Rebirth",         sound = "Rebirth.ogg" },
}

ns.Classes.DRUID[102] = {  -- Balance
    name = "平衡德鲁伊",
    spells = druidSpells,
}

ns.Classes.DRUID[103] = {  -- Feral
    name = "野性德鲁伊",
    spells = druidSpells,
}

ns.Classes.DRUID[105] = {  -- Restoration
    name = "恢复德鲁伊",
    spells = druidSpells,
}

-- 手动注册动作映射，防止自动生成逻辑失效（兼容旧格式）
if ns.ActionMap then
    local function toSnakeCase(str)
        local snake = str:gsub("(%u)", "_%1")
        if snake:sub(1,1) == "_" then snake = snake:sub(2) end
        return snake:lower()
    end

    for id, data in pairs(druidSpells) do
        if data.key then
            -- 1. 注册全小写格式 (InsectSwarm -> insectswarm)
            ns.ActionMap[string.lower(data.key)] = id
            
            -- 2. 注册蛇形命名格式 (InsectSwarm -> insect_swarm)
            local snakeKey = toSnakeCase(data.key)
            ns.ActionMap[snakeKey] = id
        end
    end
end
