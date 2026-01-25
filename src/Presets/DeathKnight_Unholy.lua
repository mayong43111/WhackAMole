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
        -- Pre-combat / Opener
        -- 起手：大军 (通常战斗前)
        "actions+=/army_of_the_dead,if=time=0",

        -- Burst Cooldowns
        -- 爆发：石像鬼 (吃急速/AP快照)，符文武器增效
        "actions+=/summon_gargoyle,if=buff.potion_of_speed.up|buff.bloodlust.up|buff.heroism.up|time<20",
        "actions+=/empower_rune_weapon,if=runes.blood<1&runes.unholy<1&runes.frost<1&runic_power<30",

        -- Disease Management
        -- 疾病管理：断病补病
        "actions+=/icy_touch,if=!dot.frost_fever.ticking",
        "actions+=/plague_strike,if=!dot.blood_plague.ticking",
        
        -- Core Rotation
        -- 1. Death and Decay: Top priority (AOE & Single Target on this server/patch)
        -- 枯萎凋零：卡CD施放 (T1阶段核心)
        "actions+=/death_and_decay,if=cooldown.death_and_decay.ready",

        -- 2. Scourge Strike: Main spender (Un + Fr/Death)
        -- 天灾打击：核心符文消耗
        "actions+=/scourge_strike,if=runes.unholy>=1&runes.frost>=1",
        "actions+=/scourge_strike,if=runes.death>=2",

        -- 3. Blood Strike: Convert Blood runes to Death runes & Maintain Desolation
        -- 鲜血打击：维持荒凉Buff + 转死亡符文
        "actions+=/blood_strike,if=buff.desolation.remains<3|runes.blood>=1",

        -- 4. Death Coil: Runic Power Dump (Buffed by T1)
        -- 凋零缠绕：符能溢出或触发免费缠绕 (T1套装+5%伤害)
        "actions+=/death_coil,if=runic_power>80|buff.sudden_doom.react",
        "actions+=/death_coil", -- General dump if nothing else

        -- 5. Filler
        -- 填充
        "actions+=/horn_of_winter"
    }
})
