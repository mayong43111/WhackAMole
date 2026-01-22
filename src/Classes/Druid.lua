-- Classes/Druid.lua
-- Druid class definition with spell database and spec detection
local _, ns = ...

--- @class DruidClass
local Druid = {}
ns.Classes = ns.Classes or {}
ns.Classes.Druid = Druid

--- 德鲁伊专精检测
--- 基于 PoC_Talents 和 SpecDetection.lua 的机制
--- @return number specIndex 专精索引 (1=平衡, 2=野性战斗, 3=恢复)
function Druid:DetectSpec()
    -- 51点天赋签名技能
    local hasStarfall = select(5, GetTalentInfo(1, 20)) > 0       -- 星辰坠落 (平衡第20层)
    local hasBerserk = select(5, GetTalentInfo(2, 23)) > 0        -- 狂暴 (野性战斗第23层)
    local hasTreeOfLife = select(5, GetTalentInfo(3, 18)) > 0     -- 生命之树 (恢复第18层)
    
    if hasStarfall then
        return 1 -- 平衡 (Balance)
    elseif hasBerserk then
        return 2 -- 野性战斗 (Feral Combat)
    elseif hasTreeOfLife then
        return 3 -- 恢复 (Restoration)
    end
    
    -- 31点天赋签名技能（副专精判断）
    local hasForceOfNature = select(5, GetTalentInfo(1, 17)) > 0  -- 自然之力 (平衡第17层)
    local hasMangle = select(5, GetTalentInfo(2, 17)) > 0          -- 割裂 (野性第17层)
    
    if hasForceOfNature then
        return 1 -- 平衡
    elseif hasMangle then
        return 2 -- 野性战斗
    else
        return 3 -- 默认恢复
    end
end

--- 德鲁伊技能数据库
--- 包含平衡、野性、恢复三个专精的核心技能
--- @type table<string, {id: number, audioKey?: string, desc?: string}>
Druid.druidSpells = {
    -- ==================== Balance (平衡) ====================
    -- 主要输出技能
    Wrath = { id = 48461, audioKey = "Wrath", desc = "快速自然伤害，推日蚀" },
    Starfire = { id = 48465, audioKey = "Starfire", desc = "慢速奥术/自然伤害，推月蚀" },
    Moonfire = { id = 48463, audioKey = "Moonfire", desc = "瞬发DoT" },
    InsectSwarm = { id = 48468, audioKey = "InsectSwarm", desc = "瞬发DoT，需天赋" },
    Starfall = { id = 53201, audioKey = "Starfall", desc = "AOE爆发，CD 90秒" },
    ForceOfNature = { id = 33831, audioKey = "ForceOfNature", desc = "召唤树人，CD 3分钟" },
    Typhoon = { id = 61384, audioKey = "Typhoon", desc = "击退+伤害" },
    Hurricane = { id = 48467, audioKey = "Hurricane", desc = "引导型AOE" },
    
    -- 形态和辅助
    MoonkinForm = { id = 24858, audioKey = "MoonkinForm", desc = "枭兽形态" },
    
    -- ==================== Feral (野性战斗) ====================
    -- 猫形态输出
    MangleCat = { id = 48566, audioKey = "MangleCat", desc = "割裂（猫），连击点生成" },
    Rake = { id = 48574, audioKey = "Rake", desc = "扫击，流血DoT" },
    Rip = { id = 49800, audioKey = "Rip", desc = "撕裂，高伤害DoT" },
    FerociousBite = { id = 48577, audioKey = "FerociousBite", desc = "凶猛撕咬，终结技" },
    Shred = { id = 48572, audioKey = "Shred", desc = "撕碎，高伤害连击点生成" },
    SavageRoar = { id = 52610, audioKey = "SavageRoar", desc = "野蛮咆哮，30%伤害增益" },
    SwipeCat = { id = 62078, audioKey = "SwipeCat", desc = "横扫（豹），AOE技能" },
    Berserk = { id = 50334, audioKey = "Berserk", desc = "狂暴，割裂无CD" },
    TigersFury = { id = 50213, audioKey = "TigersFury", desc = "猛虎之怒，60能量+伤害增益" },
    
    -- 熊形态坦克
    Maul = { id = 48480, audioKey = "Maul", desc = "槌击，熊主要威胁" },
    SwipeBear = { id = 48562, audioKey = "SwipeBear", desc = "熊横扫" },
    MangleBear = { id = 48564, audioKey = "MangleBear", desc = "割裂（熊），威胁生成" },
    
    -- 形态
    CatForm = { id = 768, audioKey = "CatForm", desc = "猫形态" },
    BearForm = { id = 5487, audioKey = "BearForm", desc = "熊形态" },
    DireBearForm = { id = 9634, audioKey = "DireBearForm", desc = "巨熊形态" },
    
    -- ==================== Restoration (恢复) ====================
    -- 主要治疗技能
    Rejuvenation = { id = 48441, audioKey = "Rejuvenation", desc = "回春术，核心HoT" },
    Regrowth = { id = 48443, audioKey = "Regrowth", desc = "愈合，直接治疗+HoT" },
    Nourish = { id = 50464, audioKey = "Nourish", desc = "滋养，快速治疗" },
    HealingTouch = { id = 48378, audioKey = "HealingTouch", desc = "治疗之触，大治疗" },
    WildGrowth = { id = 53251, audioKey = "WildGrowth", desc = "野性成长，群疗HoT" },
    Swiftmend = { id = 18562, audioKey = "Swiftmend", desc = "迅捷治愈，瞬发急救" },
    Tranquility = { id = 48447, audioKey = "Tranquility", desc = "宁静，引导群疗" },
    
    -- 辅助和形态
    TreeOfLife = { id = 33891, audioKey = "TreeOfLife", desc = "生命之树形态" },
    Barkskin = { id = 22812, audioKey = "Barkskin", desc = "树皮术，减伤" },
    Innervate = { id = 29166, audioKey = "Innervate", desc = "激活，法力恢复" },
    
    -- ==================== 通用技能 ====================
    MarkOfTheWild = { id = 48469, audioKey = "MarkOfTheWild", desc = "野性印记，团队Buff" },
    Thorns = { id = 53307, audioKey = "Thorns", desc = "荆棘术" },
    Rebirth = { id = 48477, audioKey = "Rebirth", desc = "复生，战斗复活" },
}

--- 返回德鲁伊技能表
--- @return table
function Druid:GetSpells()
    return self.druidSpells
end

return Druid
