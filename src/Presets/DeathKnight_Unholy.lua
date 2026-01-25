-- Unholy Death Knight Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[Titan] Unholy DPS (T1)",
        author = "WhackAMole",
        version = 1,
        class = "DEATHKNIGHT",
        spec = 252, -- Unholy
        desc = "WotLK 3.3.5a Unholy rotation - Optimized for Titan Forged T1 set (Death Coil buff)."
    },

    layout = {
        slots = {
            [1] = { action = "icy_touch" },           -- 冰冷触摸
            [2] = { action = "plague_strike" },       -- 暗影打击
            [3] = { action = "scourge_strike" },      -- 天灾打击
            [4] = { action = "death_and_decay" },     -- 枯萎凋零
            [5] = { action = "blood_strike" },        -- 鲜血打击
            [6] = { action = "death_coil" },          -- 凋零缠绕
            [7] = { action = "summon_gargoyle" },     -- 召唤石像鬼
            [8] = { action = "empower_rune_weapon" }, -- 符文武器增效
            [9] = { action = "army_of_the_dead" },    -- 亡者大军
            [10] = { action = "horn_of_winter" }      -- 寒冬号角
        }
    },

    apl = {
        "actions+=/army_of_the_dead,if=combat_time=0",                                          -- 亡者大军：起手使用（战斗开始前施放）
        "actions+=/summon_gargoyle,if=buff.potion_of_speed.up|buff.bloodlust.up|buff.heroism.up|combat_time<20", -- 召唤石像鬼：爆发期使用（吃急速/AP快照）
        "actions+=/empower_rune_weapon,if=runes.blood<1&runes.unholy<1&runes.frost<1&runic_power<30",     -- 符文武器增效：符文耗尽且符能低时使用
        "actions+=/icy_touch,if=!debuff.frost_fever.up",                                -- 冰冷触摸：维持冰霜疾病
        "actions+=/plague_strike,if=!debuff.blood_plague.up",                           -- 瘟疫打击：维持血液瘟疫
        "actions+=/death_and_decay,if=cooldown.death_and_decay.ready",                  -- 枯萎凋零：卡CD施放（T1阶段核心技能）
        "actions+=/scourge_strike,if=runes.unholy>=1&runes.frost>=1",                   -- 天灾打击：核心符文消耗（邪恶+冰霜符文）
        "actions+=/scourge_strike,if=runes.death>=2",                                    -- 天灾打击：使用死亡符文
        "actions+=/blood_strike,if=buff.desolation.remains<3|runes.blood>=1",           -- 鲜血打击：维持荒凉buff+转死亡符文
        "actions+=/death_coil,if=runic_power>80|buff.sudden_doom.react",                -- 凋零缠绕：符能溢出或突然末日触发（T1+5%伤害）
        "actions+=/death_coil",                                                          -- 凋零缠绕：符能消耗
        "actions+=/horn_of_winter"                                                       -- 寒冬号角：填充技能
    }
})
