-- Feral Druid Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 猫德 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DRUID",
        spec = 103, -- Feral Combat
        desc = "WotLK Feral Cat for Titan Forged T1. Focus on Savage Roar uptime + DoT maintenance + combo point management."
    },
    
    layout = {
        slots = {
            [1] = { action = "mangle_cat" },      -- 割碎（猫）
            [2] = { action = "rake" },            -- 斜掠
            [3] = { action = "shred" },           -- 撕碎
            [4] = { action = "rip" },             -- 割裂
            [5] = { action = "ferocious_bite" },  -- 凶猛撕咬
            [6] = { action = "savage_roar" },     -- 野蛮咆哮
            [7] = { action = "swipe_cat" },       -- 横扫（猫）
            [8] = { action = "berserk" },         -- 狂暴
            [9] = { action = "tigers_fury" }      -- 猛虎之怒
        }
    },
    
    apl = {
        "actions+=/savage_roar,if=!buff.savage_roar.up|buff.savage_roar.remains<2,combo_points>=1",  -- 野蛮咆哮：必须保持100%覆盖（+30%伤害，剩余<2秒紧急刷新）
        "actions+=/berserk,if=buff.tigers_fury.up",                                                    -- 狂暴：配合猛虎之怒使用（4T1持续时间15秒→18秒）
        "actions+=/tigers_fury,if=energy<30",                                                          -- 猛虎之怒：能量<30时使用（恢复能量+15%伤害）
        "actions+=/rake,if=!debuff.rake.up|debuff.rake.remains<3",                                    -- 斜掠：维持流血DoT（占总伤15-20%）
        "actions+=/rip,if=(!debuff.rip.up|debuff.rip.remains<3)&combo_points>=5",                     -- 割裂：5连击点维持最高伤害DoT（占总伤25-30%）
        "actions+=/ferocious_bite,if=combo_points>=5&debuff.rake.up&debuff.rip.up&buff.savage_roar.remains>10", -- 凶猛撕咬：5连击点终结技（斜掠和割裂存在且野蛮咆哮>10秒）
        "actions+=/mangle_cat,if=combo_points<5",                                                      -- 割碎：连击点生成（CD 1秒，狂暴期间免费）
        "actions+=/shred,if=combo_points<5&energy>=42",                                                -- 撕碎：高伤害连击点生成（需背刺位置，42能量）
        "actions+=/swipe_cat,if=active_enemies>=2&energy>=45"                                          -- 横扫：AOE技能（2T1能量消耗50→45）
    }
})
