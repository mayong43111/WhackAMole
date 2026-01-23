-- Retribution Paladin Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 惩戒骑 (T1)",
        author = "WhackAMole",
        version = 3, -- Updated again
        class = "PALADIN",
        spec = 70, -- Retribution
        desc = "WotLK Retribution for Titan Forged T1. Priority: Judgement (Mana) > DS > CS."
    },

    layout = {
        slots = {
            [1] = { action = "crusader_strike" },   -- 十字军打击
            [2] = { action = "judgement" },         -- 审判 (回蓝/伤害)
            [3] = { action = "divine_storm" },      -- 神圣风暴
            [4] = { action = "avenging_wrath" },    -- 复仇之怒
            [5] = { action = "consecration" },      -- 奉献
            [6] = { action = "exorcism" },          -- 驱邪术
            [7] = { action = "holy_wrath" },        -- 神圣愤怒
            [8] = { action = "hammer_of_justice" }, -- 制裁
            [9] = { action = "hammer_of_wrath" }    -- 愤怒之锤
        }
    },

    apl = {
        -- 优先级 1: 复仇之怒 (CD好爆发)
        "actions+=/avenging_wrath",

        -- 优先级 2: 愤怒之锤 (斩杀)
        "actions+=/hammer_of_wrath,if=target.health.pct<20|buff.avenging_wrath.up",

        -- 优先级 3: 审判 (回蓝 & 伤害)
        -- 放在十字军打击之前，确保回蓝
        "actions+=/judgement",

        -- 优先级 4: 神圣风暴 (核心伤害 / 4T1)
        "actions+=/divine_storm",

        -- 优先级 5: 十字军打击 (核心伤害)
        "actions+=/crusader_strike",

        -- 优先级 6: 驱邪术 (战争艺术)
        -- 仅在瞬发时使用
        "actions+=/exorcism,if=buff.the_art_of_war.up",

        -- 优先级 7: 奉献 (填充)
        "actions+=/consecration,if=!debuff.consecration.up",

        -- 优先级 8: 神圣愤怒 (填充 / AOE)
        "actions+=/holy_wrath",
        
        -- 优先级 9: 制裁之锤 (填充)
        "actions+=/hammer_of_justice"
    }
})
