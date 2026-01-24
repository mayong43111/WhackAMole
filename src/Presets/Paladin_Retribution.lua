-- Retribution Paladin Preset (APL v1.1)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[Titan] Retribution DPS (T1)",
        author = "WhackAMole",
        version = 6,
        class = "PALADIN",
        spec = 70, -- Retribution
        desc = "WotLK 3.3.5a Retribution rotation - Hekili optimized with seal stacking, mana management, consecration buff check, and seal switching."
    },

    layout = {
        slots = {
            [1] = { action = "crusader_strike" },      -- 十字军打击
            [2] = { action = "judgement" },            -- 审判
            [3] = { action = "divine_storm" },         -- 神圣风暴
            [4] = { action = "avenging_wrath" },       -- 复仇之怒
            [5] = { action = "consecration" },         -- 奉献
            [6] = { action = "exorcism" },             -- 驱邪术
            [7] = { action = "holy_wrath" },           -- 神圣愤怒
            [8] = { action = "hammer_of_wrath" },      -- 愤怒之锤
            [9] = { action = "hand_of_reckoning" }     -- 清算之手
        }
    },

    apl = {
        -- Execute Phase (<20% health): Hammer of Wrath becomes top priority
        -- 斩杀阶段：愤怒之锤最高优先级
        "actions+=/avenging_wrath,if=target.health.pct<20&dot.holy_vengeance.stack>4",
        "actions+=/hammer_of_wrath,if=target.health.pct<20",
        "actions+=/hand_of_reckoning,if=target.health.pct<20",
        "actions+=/judgement,if=target.health.pct<20&mana.percent<90",
        "actions+=/crusader_strike,if=target.health.pct<20",
        "actions+=/divine_storm,if=target.health.pct<20",
        
        -- Normal Phase: Seal stacking and mana-aware rotation
        -- 常规阶段
        
        -- Priority 1: Avenging Wrath (Wait for 5 stacks)
        -- 复仇之怒：等待复仇圣印叠满5层
        "actions+=/avenging_wrath,if=dot.holy_vengeance.stack>4",
        
        -- Priority 2: Hand of Reckoning (High DPE when not tanking)
        -- 清算之手：8秒CD，高伤害（非坦克时）
        "actions+=/hand_of_reckoning",

        -- Priority 3: Judgement (mana regen priority when low)
        -- 审判：蓝量低于90%时优先施放，触发"审判贤者"回蓝
        "actions+=/judgement,if=mana.percent<90",
        "actions+=/judgement",
        
        -- Priority 4: Crusader Strike (core damage, 2pc T1 +6%)
        -- 十字军打击：核心输出技能
        "actions+=/crusader_strike",
        
        -- Priority 5: Divine Storm (AOE/single, 4pc T1 CD-1s)
        -- 神圣风暴：AOE和单体都强
        "actions+=/divine_storm",
        
        -- Priority 6: Exorcism (filler when Art of War procs)
        -- 驱邪术：战争艺术触发时的填充技能
        "actions+=/exorcism,if=buff.the_art_of_war.up",
        "actions+=/exorcism",
        
        -- Priority 7: Consecration (filler when buff expires)
        -- 奉献：只在buff不存在或剩余<2秒时施放
        "actions+=/consecration,if=!buff.consecration.up|buff.consecration.remains<2",
        
        -- Priority 8: Holy Wrath (filler)
        -- 神圣愤怒：填充技能
        "actions+=/holy_wrath",
        
        -- Priority 9: Mana Management
        -- 蓝量管理
        "actions+=/seal_of_wisdom,if=mana.percent<30&cooldown.divine_plea.remains>0",
        "actions+=/seal_of_vengeance,if=mana.percent>70&!buff.seal_of_vengeance.up"
    }
})
