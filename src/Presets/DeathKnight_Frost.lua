-- Frost Death Knight Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 冰霜DK (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DEATHKNIGHT",
        spec = 251, -- Frost
        desc = "WotLK Frost DK for Titan Forged T1. Focus on Obliterate + Frost Strike + disease uptime."
    },
    
    layout = {
        slots = {
            [1] = { action = "obliterate" },       -- 湮没
            [2] = { action = "frost_strike" },     -- 冰霜打击
            [3] = { action = "howling_blast" },    -- 凛风冲击
            [4] = { action = "blood_strike" },     -- 鲜血打击
            [5] = { action = "death_strike" },     -- 死亡打击
            [6] = { action = "plague_strike" },    -- 瘟疫打击
            [7] = { action = "icy_touch" },        -- 冰冷触摸
            [8] = { action = "horn_of_winter" },   -- 寒冬号角
            [9] = { action = "pestilence" }        -- 瘟疫蔓延
        }
    },
    
    apl = {
        "actions+=/horn_of_winter,if=runic_power<60",                                    -- 寒冬号角：保持高符能池（2T1产生15符能而非10）
        "actions+=/icy_touch,if=!debuff.frost_fever.up|debuff.frost_fever.remains<3",   -- 冰冷触摸：维持冰霜疾病（占总伤10-15%）
        "actions+=/plague_strike,if=!debuff.blood_plague.up|debuff.blood_plague.remains<3", -- 瘟疫打击：维持血液瘟疫（占总伤10-15%）
        "actions+=/obliterate,if=buff.killing_machine.up",                               -- 湮没：绞肉机触发时优先使用（保证暴击，4T1+5%伤害）
        "actions+=/frost_strike,if=buff.killing_machine.up&runic_power>=40",             -- 冰霜打击：绞肉机触发时使用（保证暴击，4T1+5%伤害）
        "actions+=/obliterate",                                                           -- 湮没：核心符文消耗技能（消耗冰霜+邪恶符文，4T1+5%伤害）
        "actions+=/frost_strike,if=runic_power>=40",                                      -- 冰霜打击：核心符能消耗技能（符能≥40时使用，4T1+5%伤害）
        "actions+=/howling_blast",                                                        -- 凛风冲击：AOE填充技能（触发冰冷之爪buff）
        "actions+=/horn_of_winter,if=runic_power<100"                                     -- 寒冬号角：填充技能（无CD，2T1产生15符能）
    }
})
