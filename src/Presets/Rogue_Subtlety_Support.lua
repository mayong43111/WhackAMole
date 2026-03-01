-- Rogue Subtlety Preset - Team Support (Expose Armor Priority)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] SUPPORT - 敏锐贼·团队破甲 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "ROGUE",
        spec = 261, -- Subtlety
        desc = "泰坦T1敏锐团队增益版。优先保持破甲覆盖，为物理队提供稳定增益，同时维持个人输出节奏。"
    },

    layout = {
        slots = {
            [1] = { action = "vanish" },        -- 消失（低频）
            [2] = { action = "slice_and_dice" }, -- 切割
            [3] = { action = "hemorrhage" },    -- 出血（高频）
            [4] = { action = "rupture" },       -- 割裂
            [5] = { action = "shadowstep" },    -- 暗影步（低频）
            [6] = { action = "premeditation" }, -- 预谋（低频）
            [7] = { action = "expose_armor" },  -- 破甲
            [8] = { action = "eviscerate" },    -- 刺骨（高频）
            [9] = { action = "ambush" },        -- 伏击
            [10] = { action = "shadow_dance" }  -- 暗影之舞（低频）
        }
    },

    apl = {
        -- 常驻维护（团队增益）
        "actions+=/slice_and_dice,if=!buff.slice_and_dice.up|buff.slice_and_dice.remains<3,combo_points>=1", -- 切割：攻速核心Buff，未覆盖或<3秒时立刻刷新，至少1星即可启动循环
        "actions+=/expose_armor,if=!debuff.expose_armor.up|debuff.expose_armor.remains<4,combo_points>=1",  -- 破甲：团队增益核心Debuff，优先保证覆盖，避免物理队增益断档
        "actions+=/rupture,if=combo_points>=5&(!debuff.rupture.up|debuff.rupture.remains<4)",                -- 割裂：仅在5星且需补割裂时施放，避免低星浪费终结技

        -- 爆发窗口：高能量开舞
        "actions+=/premeditation,if=cooldown.shadow_dance.remains<2&combo_points<=3",                         -- 预谋：影舞前预装连击点，避免开窗后前几拍浪费在低收益构建
        "actions+=/shadow_dance,if=energy>=70",                                                                 -- 暗影之舞：能量>=70再开，确保窗口内可连续打伏击/终结
        "actions+=/ambush,if=buff.shadow_dance.up",                                                            -- 伏击：影舞期间最高收益构建技，优先吃满影舞时间

        -- 终结与填充
        "actions+=/eviscerate,if=combo_points>=5&buff.slice_and_dice.remains>4&debuff.rupture.remains>4",    -- 刺骨：5星终结；仅在切割/割裂都安全时释放，防止为打刺骨导致维护断档
        "actions+=/shadowstep,if=player.moving",                                                               -- 暗影步：移动补位，降低位移导致的空GCD与近战断档
        "actions+=/hemorrhage,if=combo_points<5"                                                               -- 出血：默认填充构建技，负责平稳期连击点生成
    }
})
