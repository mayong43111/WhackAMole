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
        -- 优先级 0.5: 唤醒 (紧急回蓝)
        "actions+=/evocation,if=mana.pct<10",

        -- 优先级 1: 镜像爆发 (提供18%法伤加成!)
        "actions+=/mirror_image",
        -- 优先级 2: 消耗法术连击 (4T1效果触发非常频繁!)
        "actions+=/pyroblast,if=buff.hot_streak.up",
        -- 优先级 3: 维持活动炸弹 (等待爆炸，不要提前覆盖)
        "actions+=/living_bomb,if=debuff.living_bomb.down&target.health.pct>0",
        -- 优先级 4: 卡CD使用燃烧 (配合4T1产生更多暴击触发连击)
        "actions+=/combustion,if=debuff.living_bomb.up",

        -- 1. 移动且有法术连击时，打瞬发炎爆
        "actions+=/pyroblast,if=buff.hot_streak.up&player.moving",
        
        -- 2. 移动且目标无炸弹时，补活动炸弹
        "actions+=/living_bomb,if=debuff.living_bomb.down&player.moving",
        
        -- 3. 移动且无上述情况时，使用火焰冲击填充
        "actions+=/fire_blast,if=player.moving",
        
        -- 主要填充: 火球术 (读条直到触发法术连击)
        "actions+=/fireball,if=!player.moving"
    }
})
