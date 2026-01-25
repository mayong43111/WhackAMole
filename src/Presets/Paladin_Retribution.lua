-- Retribution Paladin Preset (APL v1.1)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[Titan] Retribution DPS (T1)",
        author = "WhackAMole",
        version = 7,
        class = "PALADIN",
        spec = 70, -- Retribution
        desc = "WotLK 3.3.5a Retribution rotation - Based on WCL top parse analysis. Judgement highest priority, removed Holy Wrath."
    },

    layout = {
        slots = {
            [1] = { action = "crusader_strike" },      -- 十字军打击
            [2] = { action = "judgement" },            -- 审判
            [3] = { action = "divine_storm" },         -- 神圣风暴
            [4] = { action = "avenging_wrath" },       -- 复仇之怒
            [5] = { action = "hand_of_reckoning" },    -- 清算之手
            [6] = { action = "consecration" },         -- 奉献
            [7] = { action = "exorcism" },             -- 驱邪术
            [8] = { action = "hammer_of_wrath" }       -- 愤怒之锤
        }
    },

    apl = {
        -- Execute Phase (<20% health)
        "actions+=/avenging_wrath,if=target.health.pct<20",     -- 斩杀阶段：复仇之怒
        "actions+=/hammer_of_wrath,if=target.health.pct<20",    -- 斩杀阶段：愤怒之锤（最高优先级）
        "actions+=/judgement,if=target.health.pct<20",          -- 斩杀阶段：审判
        "actions+=/crusader_strike,if=target.health.pct<20",    -- 斩杀阶段：十字军打击
        "actions+=/hand_of_reckoning,if=target.health.pct<20",  -- 斩杀阶段：清算之手
        "actions+=/divine_storm,if=target.health.pct<20",       -- 斩杀阶段：神圣风暴
        
        -- Normal Phase
        "actions+=/avenging_wrath",                             -- 复仇之怒：CD好就用（WCL显示战斗开始3秒就使用，不需要等待）
        "actions+=/judgement",                                  -- 审判：最高优先级，无条件卡CD（智慧审判回蓝+伤害，CD利用率88%）
        "actions+=/crusader_strike",                            -- 十字军打击：核心输出技能，2T1+6%伤害（CD利用率87%）
        "actions+=/hand_of_reckoning",                          -- 清算之手：高伤害单体技能（仅目标未攻击你时有效，CD利用率96%）
        "actions+=/divine_storm",                               -- 神圣风暴：AOE和单体都强，4T1减CD至9秒（CD利用率86%）
        "actions+=/exorcism",                                   -- 驱邪术：CD好就用（WCL显示使用8次，平均18.3秒）
        "actions+=/consecration,if=!buff.consecration.up|buff.consecration.remains<2"  -- 奉献：低优先级填充（CD利用率66%）
    }
})
