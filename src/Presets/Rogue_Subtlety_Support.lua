-- Rogue Subtlety Preset - Unified (Always Expose Armor)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 敏锐贼 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "ROGUE",
        spec = 261, -- Subtlety
        desc = "泰坦T1敏锐统一版。无论团队配置均保持破甲覆盖，死亡印记+刺骨双终结，技能位按高频操作居中排布。"
    },

    layout = {
        slots = {
            [1] = { action = "vanish" },          -- 消失（低频，边位）
            [2] = { action = "premeditation" },   -- 预谋（低频）
            [3] = { action = "hemorrhage" },      -- 出血（最高频，第一排中位）
            [4] = { action = "death_mark_titan" },-- 死亡印记（高频终结）
            [5] = { action = "shadow_dance" },    -- 暗影之舞（低频爆发，边位）
            [6] = { action = "rupture" },         -- 割裂（条件维护，边位）
            [7] = { action = "slice_and_dice" },  -- 切割（高频维护）
            [8] = { action = "eviscerate" },      -- 刺骨（最高频终结，第二排中位）
            [9] = { action = "ambush" },          -- 伏击（爆发高频）
            [10] = { action = "expose_armor" }    -- 破甲（常驻维护，边位）
        }
    },

    apl = {
        -- 常驻维护（最高优先级，但仅在低星时）
        "actions+=/slice_and_dice,if=(!buff.slice_and_dice.up|buff.slice_and_dice.remains<3)&combo_points>=1&combo_points<5", -- 切割：1-4星时刷新，不抢占5星
        "actions+=/expose_armor,if=!debuff.expose_armor.up&combo_points>=1&combo_points<5",                                   -- 破甲：仅低星时补，不抢占5星

        -- 爆发窗口（最高优先级）
        "actions+=/premeditation,if=combo_points<=2",                                                          -- 预谋：低星时直接用
        "actions+=/shadow_dance,if=cooldown.shadow_dance.remains<=0",                                          -- 暗影之舞：CD好了就用
        "actions+=/ambush",                                                                                    -- 伏击：爆发期高优先级

        -- 终结技能优先级（刺骨为主，死亡印记控制频率）
        "actions+=/eviscerate,if=combo_points>=2",                                                             -- 刺骨：降至2星即可使用，提高频率
        "actions+=/death_mark_titan,if=cooldown.death_mark_titan.remains<=0&combo_points==1&energy>=50",      -- 死亡印记：1星+能量门槛，控制使用频率
        "actions+=/rupture,if=!debuff.rupture.up&combo_points>=2&combo_points<3",                             -- 割裂：限制为2星
        
        -- 填充
        "actions+=/hemorrhage,if=combo_points<5"                                                               -- 出血：默认填充构建技
    }
})
