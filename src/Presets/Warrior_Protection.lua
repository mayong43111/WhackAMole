-- Protection Warrior Preset (APL v1.0)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] 坦克 - 防护战 - 单体BOSS (T1)",
        author = "WhackAMole",
        version = 1,
        class = "WARRIOR",
        spec = 73, -- Protection
        desc = "泰坦重铸 防护战 T1阶段。单体Boss循环，生存优先，稳定威胁。AOE场景需手动穿插冲击波。"
    },
    
    layout = {
        slots = {
            [1] = { action = "shield_slam" },       -- 盾牌猛击
            [2] = { action = "revenge" },           -- 复仇
            [3] = { action = "devastate" },         -- 毁灭打击
            [4] = { action = "shield_block" },      -- 盾牌格挡
            [5] = { action = "heroic_strike" },     -- 英勇打击
            [6] = { action = "thunder_clap" },      -- 雷霆一击
            [7] = { action = "enraged_regeneration" }, -- 狂怒回复
            [8] = { action = "last_stand" },        -- 破釜沉舟
            [9] = { action = "shield_wall" }        -- 盾墙
        }
    },
    
    apl = {
        -- === 生存优先（血量阈值触发）===
        "actions+=/shield_wall,if=player.health.pct<20",              -- 盾墙：血量<20%终极保命（60%减伤12秒）
        "actions+=/last_stand,if=player.health.pct<40",               -- 破釜沉舟：血量<40%先扩血量池（+30%最大生命20秒）
        "actions+=/enraged_regeneration,if=player.health.pct<35",     -- 狂怒回复：血量<35%治疗+免死（在扩大血量池上治疗更高效）
        
        -- === 主动防御 ===
        "actions+=/shield_block,if=cooldown.shield_block.ready",      -- 盾牌格挡：CD好就用（100%格挡10秒，触发复仇）
        "actions+=/shield_bash",                                      -- 盾牌反击：打断施法（手动判断目标施法）
        
        -- === 威胁循环 ===
        "actions+=/revenge",                                          -- 复仇：最高优先级（5怒气必爆，DPE最高）
        "actions+=/shield_slam",                                      -- 盾牌猛击：主要威胁技能（20怒气，CD 6秒）
        "actions+=/thunder_clap,if=!debuff.thunder_clap.up&player.power.rage.current>=20", -- 雷霆一击：挂Debuff（20怒气，确保有资源）
        "actions+=/devastate",                                        -- 毁灭打击：填充技能（15怒气，叠破甲，4T1威胁+30%）
        
        -- === 怒气管理 ===
        "actions+=/heroic_strike,if=player.power.rage.current>=60",  -- 英勇打击：怒气≥60泄怒（不占GCD，防止浪费）
        
        -- === Buff维持 ===
        "actions+=/commanding_shout,if=buff.commanding_shout.remains<30",  -- 命令怒吼：Buff<30秒刷新（增加生命值和耐力）
        "actions+=/demoralizing_shout,if=!debuff.demoralizing_shout.up"   -- 挫志怒吼：Debuff消失时补上（降低敌人攻击强度）
    }
})
