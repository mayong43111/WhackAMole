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
    [52437]  = { key = "SuddenDeath",         sound = "Execute.ogg"},              -- 猝死 (Buff) -> 斩杀音效
    [46916]  = { key = "Bloodsurge",          sound = "Slam.ogg" },                -- 猛击! (Buff) -> 猛击音效
    [55694]  = { key = "EnragedRegeneration",  sound = "EnragedRegeneration.ogg" }, -- 狂怒回复
    [469]    = { key = "CommandingShout",      sound = "CommandingShout.ogg" },     -- 命令怒吼
    [1160]   = { key = "DemoralizingShout",    sound = "DemoralizingShout.ogg" },   -- 挫志怒吼

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
    [45902]  = { key = "BloodStrike",         sound = "BloodStrike.ogg" },         -- 鲜血打击
    [45477]  = { key = "IcyTouch",            sound = "IcyTouch.ogg" },            -- 冰冷触摸
    [45462]  = { key = "PlagueStrike",        sound = "PlagueStrike.ogg" },        -- 瘟疫打击
    [49998]  = { key = "DeathStrike",         sound = "DeathStrike.ogg" },         -- 死亡打击
    [51425]  = { key = "Obliterate",          sound = "Obliterate.ogg" },          -- 湮没
    [49143]  = { key = "FrostStrike",         sound = "FrostStrike.ogg" },         -- 冰霜打击
    [49184]  = { key = "HowlingBlast",        sound = "HowlingBlast.ogg" },        -- 凛风冲击
    [43265]  = { key = "DeathAndDecay",       sound = "DeathAndDecay.ogg" },       -- 枯萎凋零
    [47541]  = { key = "DeathCoil",           sound = "DeathCoil.ogg" },           -- 凋零缠绕
    [55271]  = { key = "ScourgeStrike",       sound = "ScourgeStrike.ogg" },       -- 天灾打击
    [50842]  = { key = "Pestilence",          sound = "Pestilence.ogg" },          -- 瘟疫蔓延
    [57623]  = { key = "HornOfWinter",        sound = "HornOfWinter.ogg" },        -- 寒冬号角
    [42650]  = { key = "ArmyOfTheDead",       sound = "ArmyOfTheDead.ogg" },       -- 亡者大军
    [47568]  = { key = "EmpowerRuneWeapon",   sound = "EmpowerRuneWeapon.ogg" },   -- 符文武器增效
    [55095]  = { key = "FrostFever" },                                             -- 冰霜疾病 (Debuff)
    [55078]  = { key = "BloodPlague" },                                            -- 血液瘟疫 (Debuff)
    [51124]  = { key = "KillingMachine" },                                         -- 绞肉机 (Buff)
    [66817]  = { key = "Desolation" },                                             -- 荒凉 (Buff)
    [49530]  = { key = "SuddenDoom" },                                             -- 突然末日 (Buff)

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
    [35395]  = { key = "CrusaderStrike",      sound = "CrusaderStrike.ogg" },      -- 十字军打击
    [20271]  = { key = "Judgement",           sound = "Judgement.ogg" },           -- 审判
    [53385]  = { key = "DivineStorm",         sound = "DivineStorm.ogg" },         -- 神圣风暴
    [62124]  = { key = "HandOfReckoning",     sound = "HandOfReckoning.ogg" },     -- 清算之手
    [48819]  = { key = "Consecration",        sound = "Consecration.ogg" },        -- 奉献
    [48801]  = { key = "Exorcism",            sound = "Exorcism.ogg" },            -- 驱邪术
    [48806]  = { key = "HammerOfWrath",       sound = "HammerOfWrath.ogg" },       -- 愤怒之锤

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
    [48463]  = { key = "Moonfire",            sound = "Moonfire.ogg" },            -- 月火术
    [48465]  = { key = "Starfire",            sound = "Starfire.ogg" },            -- 星火术
    [48461]  = { key = "Wrath",               sound = "Wrath.ogg" },               -- 愤怒
    [48468]  = { key = "InsectSwarm",         sound = "InsectSwarm.ogg" },         -- 虫群
    [48505]  = { key = "Starfall",            sound = "Starfall.ogg" },            -- 星辰坠落
    [770]    = { key = "FaerieFire",          sound = "FaerieFire.ogg" },          -- 精灵之火
    [61384]  = { key = "Typhoon",             sound = "Typhoon.ogg" },             -- 台风
    [48467]  = { key = "Hurricane",           sound = "Hurricane.ogg" },           -- 飓风
    [48566]  = { key = "MangleCat",           sound = "MangleCat.ogg" },           -- 割碎(猫)
    [48574]  = { key = "Rake",                sound = "Rake.ogg" },                -- 斜掠
    [48572]  = { key = "Shred",               sound = "Shred.ogg" },               -- 撕碎
    [49800]  = { key = "Rip",                 sound = "Rip.ogg" },                 -- 割裂
    [48577]  = { key = "FerociousBite",       sound = "FerociousBite.ogg" },       -- 凶猛撕咬
    [52610]  = { key = "SavageRoar",          sound = "SavageRoar.ogg" },          -- 野蛮咆哮
    [48562]  = { key = "SwipeCat",            sound = "SwipeCat.ogg" },            -- 横扫(猫)
    [50334]  = { key = "Berserk",             sound = "Berserk.ogg" },             -- 狂暴
    [50213]  = { key = "TigersFury",          sound = "TigersFury.ogg" },          -- 猛虎之怒
    [48518]  = { key = "LunarEclipse" },                                           -- 月蚀 (Buff)
    [48517]  = { key = "SolarEclipse" },                                           -- 日蚀 (Buff)

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
    [42842]  = { key = "Frostbolt",           sound = "Frostbolt.ogg" },           -- 寒冰箭
    [42914]  = { key = "IceLance",            sound = "IceLance.ogg" },            -- 冰枪术
    [47610]  = { key = "FrostfireBolt",       sound = "FrostfireBolt.ogg" },       -- 霜火之箭
    [31687]  = { key = "SummonWaterElemental", sound = "SummonWaterElemental.ogg" }, -- 召唤水元素
    [44614]  = { key = "FrozenOrb",           sound = "FrozenOrb.ogg" },           -- 冰冻宝珠
    [42931]  = { key = "ConeOfCold",          sound = "ConeOfCold.ogg" },          -- 冰锥术
    [48108]  = { key = "HotStreak" },                                              -- 炎爆术! (Buff)
    [57761]  = { key = "BrainFreeze" },                                            -- 思维冷却 (Buff)
    [44544]  = { key = "FingersOfFrost" },                                         -- 寒冰指 (Buff)
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
    
    -- ---------------------------------------------------------------
    -- CONSUMABLES (消耗品)
    -- ---------------------------------------------------------------
    [53908]  = { key = "PotionOfSpeed" },                                          -- 急速药水 (Buff)
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
