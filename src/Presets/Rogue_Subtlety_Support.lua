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
        -- 常驻维护（统一版）
        "actions+=/slice_and_dice,if=(!buff.slice_and_dice.up|buff.slice_and_dice.remains<3)&combo_points>=1", -- 切割：攻速核心Buff，未覆盖或<3秒时立刻刷新
        "actions+=/death_mark_titan,if=cooldown.death_mark_titan.remains<=0&combo_points>=1",                  -- 死亡印记：重制后核心终结技，尽量按CD施放
        "actions+=/expose_armor,if=(!debuff.expose_armor.up|debuff.expose_armor.remains<4)&combo_points>=1",  -- 破甲：统一版常驻维护
        "actions+=/rupture,if=!debuff.rupture.up&combo_points>=5",                                               -- 割裂：条件维护，仅在缺失时补一次（死亡印记可刷新）

        -- 爆发窗口：高能量开舞
        "actions+=/premeditation,if=cooldown.shadow_dance.remains<2&combo_points<=3",                         -- 预谋：影舞前预装连击点，避免开窗后前几拍浪费在低收益构建
        "actions+=/shadow_dance,if=energy>=70",                                                                 -- 暗影之舞：能量>=70再开，确保窗口内可连续打伏击/终结
        "actions+=/ambush,if=buff.shadow_dance.up",                                                            -- 伏击：影舞期间最高收益构建技，优先吃满影舞时间

        -- 终结与填充
        "actions+=/eviscerate,if=combo_points>=5&buff.slice_and_dice.remains>4&debuff.rupture.remains>2",    -- 刺骨：5星终结；在维护安全时转化伤害
        "actions+=/hemorrhage,if=combo_points<5"                                                               -- 出血：默认填充构建技，负责平稳期连击点生成
    }
})
