local _, ns = ...

-- Core/Constants.lua
-- Centralized definition for all Spell IDs, Buff IDs, and associated Metadata (Audio, Keys)

ns.Constants = {}

-- ----------------------------------------------------------------------------
-- Spell Database
-- Structure: [SpellID] = { key = "StringKey", sound = "Filename.ogg" }
-- ----------------------------------------------------------------------------
-- Why unified? Because WoW APIs use SpellID for everything (Active Skills, Buffs, Procs).

ns.Spells = {
    -- ---------------------------------------------------------------
    -- WARRIOR (战士)
    -- ---------------------------------------------------------------
    [100]    = { key = "Charge",              sound = "Charge.ogg" },              -- 冲锋
    [5308]   = { key = "Execute",             sound = "Execute.ogg" },             -- 斩杀
    [12294]  = { key = "MortalStrike",        sound = "MortalStrike.ogg" },        -- 致死打击
    [7384]   = { key = "Overpower",           sound = "Overpower.ogg" },           -- 压制
    [46924]  = { key = "Bladestorm",          sound = "Bladestorm.ogg" },          -- 利刃风暴
    [1719]   = { key = "Recklessness",        sound = "Recklessness.ogg" },        -- 鲁莽
    [871]    = { key = "ShieldWall",          sound = "ShieldWall.ogg" },          -- 盾墙
    [12975]  = { key = "LastStand",           sound = "LastStand.ogg" },           -- 破釜沉舟
    [2565]   = { key = "ShieldBlock",         sound = "ShieldBlock.ogg" },         -- 盾牌格挡
    [6673]   = { key = "BattleShout",         sound = "BattleShout.ogg" },         -- 战斗怒吼
    [6343]   = { key = "ThunderClap",         sound = "ThunderClap.ogg" },         -- 雷霆一击
    [676]    = { key = "Disarm",              sound = "Disarm.ogg" },              -- 缴械
    [6552]   = { key = "Pummel",              sound = "Pummel.ogg" },              -- 拳击
    [23920]  = { key = "SpellReflection",     sound = "SpellReflection.ogg" },     -- 法术反射
    [3411]   = { key = "Intervene",           sound = "Intervene.ogg" },           -- 援护
    [12328]  = { key = "SweepingStrikes",     sound = "SweepingStrikes.ogg" },     -- 横扫攻击
    [64382]  = { key = "ShatteringThrow",     sound = "ShatteringThrow.ogg" },     -- 碎裂投掷
    [5246]   = { key = "IntimidatingShout",   sound = "IntimidatingShout.ogg" },   -- 破胆怒吼
    [23881]  = { key = "Bloodthirst",         sound = "Bloodthirst.ogg" },         -- 嗜血
    [1680]   = { key = "Whirlwind",           sound = "Whirlwind.ogg" },           -- 旋风斩
    [1464]   = { key = "Slam",                sound = "Slam.ogg" },                -- 猛击
    [34428]  = { key = "VictoryRush",         sound = "VictoryRush.ogg" },         -- 乘胜追击
    [47465]  = { key = "Rend",                sound = "Rend.ogg" },                -- 撕裂 (等级10, 80级最高等级)
    [6572]   = { key = "Revenge",             sound = "Revenge.ogg" },             -- 复仇
    [23922]  = { key = "ShieldSlam",          sound = "ShieldSlam.ogg" },          -- 盾牌猛击
    [46968]  = { key = "Shockwave",           sound = "Shockwave.ogg" },           -- 震荡波
    [20243]  = { key = "Devastate",           sound = "Devastate.ogg" },           -- 毁灭打击
    [12809]  = { key = "ConcussionBlow",      sound = "ConcussionBlow.ogg" },      -- 震荡猛击
    [78]     = { key = "HeroicStrike",        sound = "HeroicStrike.ogg" },        -- 英勇打击
    [52437]  = { key = "SuddenDeath" },                                            -- 猝死 (Buff)
    [46916]  = { key = "Bloodsurge" },                                             -- 猛击! (Buff)

    -- ---------------------------------------------------------------
    -- DEATH KNIGHT (死亡骑士)
    -- ---------------------------------------------------------------
    [48707]  = { key = "AntiMagicShell",      sound = "AntiMagicShell.ogg" },      -- 反魔法护罩
    [48792]  = { key = "IceboundFortitude",   sound = "IceboundFortitude.ogg" },   -- 冰封之韧
    [49028]  = { key = "DancingRuneWeapon",   sound = "DancingRuneWeapon.ogg" },   -- 符文刃舞
    [49039]  = { key = "Lichborne",           sound = "Lichborne.ogg" },           -- 巫妖之躯
    [55233]  = { key = "VampiricBlood",       sound = "VampiricBlood.ogg" },       -- 吸血鬼之血
    [49222]  = { key = "BoneShield",          sound = "BoneShield.ogg" },          -- 白骨之盾
    [47476]  = { key = "Strangulate",         sound = "Strangulate.ogg" },         -- 绞袭
    [47528]  = { key = "MindFreeze",          sound = "MindFreeze.ogg" },          -- 心灵冰冻
    [51271]  = { key = "PillarofFrost",       sound = "PillarofFrost.ogg" },       -- 冰柱
    [49206]  = { key = "SummonGargoyle",      sound = "SummonGargoyle.ogg" },      -- 召唤石像鬼
    [63560]  = { key = "DarkTransformation",  sound = "DarkTransformation.ogg" },  -- 黑暗突变
    [108194] = { key = "Asphyxiate",          sound = "Asphyxiate.ogg" },          -- 窒息

    -- ---------------------------------------------------------------
    -- PALADIN (圣骑士)
    -- ---------------------------------------------------------------
    [642]    = { key = "DivineShield",        sound = "DivineShield.ogg" },        -- 圣盾术
    [1022]   = { key = "HandofProtection",    sound = "HandofProtection.ogg" },    -- 保护之手
    [1044]   = { key = "HandofFreedom",       sound = "HandofFreedom.ogg" },       -- 自由之手
    [6940]   = { key = "HandofSacrifice",     sound = "HandofSacrifice.ogg" },     -- 牺牲之手
    [31884]  = { key = "AvengingWrath",       sound = "AvengingWrath.ogg" },       -- 复仇之怒
    [498]    = { key = "DivineProtection",    sound = "DivineProtection.ogg" },    -- 圣佑术
    [31821]  = { key = "AuraMastery",         sound = "AuraMastery.ogg" },         -- 光环掌握
    [853]    = { key = "HammerofJustice",     sound = "HammerofJustice.ogg" },     -- 制裁之锤
    [96231]  = { key = "Rebuke",              sound = "Rebuke.ogg" },              -- 责难

    -- ---------------------------------------------------------------
    -- PRIEST (牧师)
    -- ---------------------------------------------------------------
    [33206]  = { key = "PainSuppression",     sound = "PainSuppression.ogg" },     -- 痛苦压制
    [47585]  = { key = "Dispersion",          sound = "Dispersion.ogg" },          -- 消散
    [10060]  = { key = "PowerInfusion",       sound = "PowerInfusion.ogg" },       -- 能量灌注
    [8122]   = { key = "PsychicScream",       sound = "PsychicScream.ogg" },       -- 心灵尖啸
    [64044]  = { key = "PsychicHorror",       sound = "PsychicHorror.ogg" },       -- 惊骇
    [15487]  = { key = "Silence",             sound = "Silence.ogg" },             -- 沉默
    [32375]  = { key = "MassDissipation",     sound = "MassDissipation.ogg" },     -- 群体驱散
    [47788]  = { key = "GuardianSpirit",      sound = "GuardianSpirit.ogg" },      -- 守护之魂

    -- ---------------------------------------------------------------
    -- ROGUE (潜行者)
    -- ---------------------------------------------------------------
    [31224]  = { key = "CloakofShadows",      sound = "CloakofShadows.ogg" },      -- 暗影斗篷
    [2983]   = { key = "Sprint",              sound = "Sprint.ogg" },              -- 疾跑
    [1856]   = { key = "Vanish",              sound = "Vanish.ogg" },              -- 消失
    [5277]   = { key = "Evasion",             sound = "Evasion.ogg" },             -- 闪避
    [2094]   = { key = "Blind",               sound = "Blind.ogg" },               -- 致盲
    [408]    = { key = "KidneyShot",          sound = "KidneyShot.ogg" },          -- 肾击
    [1766]   = { key = "Kick",                sound = "Kick.ogg" },                -- 脚踢
    [51713]  = { key = "ShadowDance",         sound = "ShadowDance.ogg" },         -- 暗影之舞
    [5171]   = { key = "SliceandDice",        sound = "SliceandDice.ogg" },        -- 切割

    -- ---------------------------------------------------------------
    -- DRUID (德鲁伊)
    -- ---------------------------------------------------------------
    [22812]  = { key = "Barkskin",            sound = "Barkskin.ogg" },            -- 树皮术
    [61336]  = { key = "SurvivalInstincts",   sound = "SurvivalInstincts.ogg" },   -- 生存本能
    [29166]  = { key = "Innervate",           sound = "Innervate.ogg" },           -- 激活
    [33786]  = { key = "Cyclone",             sound = "Cyclone.ogg" },             -- 吹风
    [106839] = { key = "SkullBash",           sound = "SkullBash.ogg" },           -- 迎头痛击

    -- ---------------------------------------------------------------
    -- SHAMAN (萨满祭司)
    -- ---------------------------------------------------------------
    [2825]   = { key = "Bloodlust",           sound = "Bloodlust.ogg" },           -- 嗜血
    [32182]  = { key = "Heroism",             sound = "Heroism.ogg" },             -- 英勇
    [57994]  = { key = "WindShear",           sound = "WindShear.ogg" },           -- 风剪
    [51514]  = { key = "Hex",                 sound = "Hex.ogg" },                 -- 妖术
    [8143]   = { key = "TremorTotem",         sound = "TremorTotem.ogg" },         -- 战栗图腾

    -- ---------------------------------------------------------------
    -- MAGE (法师)
    -- ---------------------------------------------------------------
    [45438]  = { key = "IceBlock",            sound = "IceBlock.ogg" },            -- 寒冰屏障
    [12051]  = { key = "Evocation",           sound = "Evocation.ogg" },           -- 唤醒
    [2139]   = { key = "Counterspell",        sound = "Counterspell.ogg" },        -- 法术反制
    [118]    = { key = "Polymorph",           sound = "Polymorph.ogg" },           -- 变形术
    [12472]  = { key = "IcyVeins",            sound = "IcyVeins.ogg" },            -- 冰冷血脉
    [55360]  = { key = "LivingBomb",          sound = "LivingBomb.ogg" },          -- 活体炸弹
    [42891]  = { key = "Pyroblast",           sound = "Pyroblast.ogg" },           -- 炎爆术
    [42833]  = { key = "Fireball",            sound = "Fireball.ogg" },            -- 火球术
    [42859]  = { key = "Scorch",              sound = "Scorch.ogg" },              -- 灼烧
    [11129]  = { key = "Combustion",          sound = "Combustion.ogg" },          -- 燃烧
    [55342]  = { key = "MirrorImage",         sound = "MirrorImage.ogg" },         -- 镜像
    [42873]  = { key = "FireBlast",           sound = "FireBlast.ogg" },           -- 火焰冲击
    [42950]  = { key = "DragonsBreath",       sound = "DragonsBreath.ogg" },       -- 龙息术
    [48108]  = { key = "HotStreak" },                                              -- 炎爆术! (Buff)
    [22959]  = { key = "ImprovedScorch" },
    [17800]  = { key = "ShadowMastery" },
    [12579]  = { key = "WintersChill" },

    -- ---------------------------------------------------------------
    -- WARLOCK (术士)
    -- ---------------------------------------------------------------
    [17928]  = { key = "HowlOfTerror",        sound = "HowlOfTerror.ogg" },        -- 恐惧嚎叫
    [5782]   = { key = "Fear",                sound = "Fear.ogg" },                -- 恐惧术
    [19647]  = { key = "SpellLock",           sound = "SpellLock.ogg" },           -- 法术封锁

    -- ---------------------------------------------------------------
    -- HUNTER (猎人)
    -- ---------------------------------------------------------------
    [781]    = { key = "Disengage",           sound = "Disengage.ogg" },           -- 逃脱
    [19263]  = { key = "Deterrence",          sound = "Deterrence.ogg" },          -- 威慑
    [34477]  = { key = "Misdirection",        sound = "Misdirection.ogg" },        -- 误导
    [19503]  = { key = "ScatterShot",         sound = "ScatterShot.ogg" },         -- 驱散射击
}

-- ----------------------------------------------------------------------------
-- Reverse Lookup (Name -> ID)
-- ----------------------------------------------------------------------------
-- Populated automatically from ns.Spells to ensure consistency.
-- Accessible as ns.ID.MortalStrike (returns 12294)

ns.ID = {}

-- Helper to convert CamelCaseOnly to snake_case_only
local function CamelToSnake(str)
    -- Insert underscore before capital letters (except the first one)
    local s = str:gsub("(%l)(%u)", "%1_%2")
    return s:lower()
end
ns.CamelToSnake = CamelToSnake

ns.ActionMap = {} -- For SimC mapping

for id, data in pairs(ns.Spells) do
    if data.key then
        ns.ID[data.key] = id
        
        -- Create snake_case action alias
        local snake = CamelToSnake(data.key)
        ns.ActionMap[snake] = id
    end
end
