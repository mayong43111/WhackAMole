-- Fire Mage Preset (APL v1.2)
local _, ns = ...

ns.ProfileManager:RegisterPreset({
    meta = {
        name = "[泰坦] DPS - 火法 (T1)",
        author = "WhackAMole",
        version = 7,
        class = "MAGE",
        spec = 63, -- Fire
        desc = "WotLK Fire for Titan Forged T1. Focus on Hot Streak spam."
    },
    
    layout = {
        slots = {
            [1] = { action = "fireball" },     -- 火球术
            [2] = { action = "pyroblast" },    -- 炎爆术
            [3] = { action = "living_bomb" },  -- 活动炸弹
            [4] = { action = "combustion" },   -- 燃烧
            [5] = { action = "mirror_image" }, -- 镜像
            [6] = { action = "fire_blast" },   -- 火焰冲击
            [7] = { action = "evocation" }     -- 唤醒
            -- 注意: 龙息术(Dragons Breath)不在DPS循环中，需要时手动放到技能栏
        }
    },
    
    apl = {
        "actions+=/evocation,if=mana.pct<10",                              -- 唤醒：紧急回蓝（法力<10%）
        "actions+=/mirror_image",                                          -- 镜像：爆发技能（提供18%法伤加成）
        "actions+=/pyroblast,if=buff.hot_streak.up",                      -- 炎爆术：消耗法术连击（4T1触发频繁）
        "actions+=/living_bomb,if=debuff.living_bomb.down&target.health.pct>0", -- 活动炸弹：维持DoT（等待爆炸不提前覆盖）
        "actions+=/combustion,if=debuff.living_bomb.up",                  -- 燃烧：卡CD使用（配合4T1产生更多暴击）
        "actions+=/pyroblast,if=buff.hot_streak.up&player.moving",        -- 炎爆术：移动时消耗法术连击
        "actions+=/living_bomb,if=debuff.living_bomb.down&player.moving", -- 活动炸弹：移动时补DoT
        "actions+=/fire_blast,if=player.moving",                          -- 火焰冲击：移动时填充
        "actions+=/fireball,if=!player.moving"                            -- 火球术：主要填充技能（读条触发法术连击）
    }
})
