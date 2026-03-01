-- Rogue Subtlety Preset - Pure DPS
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 敏锐贼·纯输出 (T1)",
        author = "WhackAMole",
        version = 1,
        class = "ROGUE",
        spec = 261, -- Subtlety
        desc = "泰坦T1敏锐纯输出版。不主动维护破甲，终结资源集中用于割裂/刺骨与影舞窗口。"
    },

    layout = {
        slots = {
            [1] = { action = "slice_and_dice" }, -- 切割
            [2] = { action = "rupture" },        -- 割裂
            [3] = { action = "shadow_dance" },   -- 暗影之舞
            [4] = { action = "ambush" },         -- 伏击
            [5] = { action = "eviscerate" },     -- 刺骨
            [6] = { action = "hemorrhage" },     -- 出血
            [7] = { action = "shadowstep" },     -- 暗影步
            [8] = { action = "premeditation" },  -- 预谋
            [9] = { action = "vanish" },         -- 消失
            [10] = { action = "preparation" }    -- 伺机待发
        }
    },

    apl = {
        -- 常驻维护（纯输出）
        "actions+=/slice_and_dice,if=!buff.slice_and_dice.up|buff.slice_and_dice.remains<3,combo_points>=1", -- 切割：攻速核心Buff，优先保持高覆盖率，避免平砍与回能节奏下滑
        "actions+=/rupture,if=!debuff.rupture.up|debuff.rupture.remains<4,combo_points>=5",                  -- 割裂：5星流血终结，纯输出版本中与刺骨共同构成主要终结收益

        -- 爆发窗口：高能量开舞
        "actions+=/premeditation,if=cooldown.shadow_dance.remains<2&combo_points<=3",                         -- 预谋：影舞前补连击点，提升窗口内伏击与终结密度
        "actions+=/shadow_dance,if=energy>=70",                                                                 -- 暗影之舞：高能量开窗，减少窗口内能量空转
        "actions+=/ambush,if=buff.shadow_dance.up",                                                            -- 伏击：影舞中的首选构建技能，爆发期优先级最高

        -- 终结与填充
        "actions+=/eviscerate,if=combo_points>=5&buff.slice_and_dice.remains>4&debuff.rupture.remains>4",    -- 刺骨：5星主要伤害终结技，维护安全时优先转化连击点为直伤
        "actions+=/shadowstep,if=player.moving",                                                               -- 暗影步：位移补偿，保证近战贴身与输出连贯性
        "actions+=/hemorrhage,if=combo_points<5"                                                               -- 出血：默认填充技能，用于持续生成连击点
    }
})
