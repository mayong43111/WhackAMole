local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.WARRIOR = {}

-- Warrior Spec Detection Logic
ns.SpecRegistry:Register("WARRIOR", function()
    -- 51 Point Talents
    if IsPlayerSpell(46924) then return 71 end -- Bladestorm (Arms)
    if IsPlayerSpell(46917) then return 72 end -- Titan's Grip (Fury)
    if IsPlayerSpell(46968) then return 73 end -- Shockwave (Prot)
    
    -- 31 Point Talents (Fallback for lower levels)
    if IsPlayerSpell(12294) then return 71 end -- Mortal Strike (Arms)
    if IsPlayerSpell(23881) then return 72 end -- Bloodthirst (Fury)
    if IsPlayerSpell(23922) then return 73 end -- Shield Slam (Prot)

    return nil
end)

-- Warrior Spell Database
local warriorSpells = {
    -- 通用技能
    [100]    = { key = "Charge",              sound = "Charge.ogg" },
    [5308]   = { key = "Execute",             sound = "Execute.ogg" },
    [6673]   = { key = "BattleShout",         sound = "BattleShout.ogg" },
    [6343]   = { key = "ThunderClap",         sound = "ThunderClap.ogg" },
    [676]    = { key = "Disarm",              sound = "Disarm.ogg" },
    [6552]   = { key = "Pummel",              sound = "Pummel.ogg" },
    [23920]  = { key = "SpellReflection",     sound = "SpellReflection.ogg" },
    [3411]   = { key = "Intervene",           sound = "Intervene.ogg" },
    [64382]  = { key = "ShatteringThrow",     sound = "ShatteringThrow.ogg" },
    [5246]   = { key = "IntimidatingShout",   sound = "IntimidatingShout.ogg" },
    [772]    = { key = "Rend",                sound = "Rend.ogg" },
    [34428]  = { key = "VictoryRush",         sound = "VictoryRush.ogg" },
    [78]     = { key = "HeroicStrike",        sound = "HeroicStrike.ogg" },
    [355]    = { key = "Taunt",               sound = "Taunt.ogg" },
    [1161]   = { key = "ChallengingShout",    sound = "ChallengingShout.ogg" },
    [694]    = { key = "MockingBlow",         sound = "MockingBlow.ogg" },
    [845]    = { key = "Cleave",              sound = "Cleave.ogg" },
    [1160]   = { key = "DemoralizingShout",   sound = "DemoralizingShout.ogg" },
    [20230]  = { key = "Retaliation",         sound = "Retaliation.ogg" },
    [469]    = { key = "CommandingShout",     sound = "CommandingShout.ogg" },
    [18499]  = { key = "BerserkerRage",       sound = "BerserkerRage.ogg" },
    
    -- 防御技能
    [871]    = { key = "ShieldWall",          sound = "ShieldWall.ogg" },
    [12975]  = { key = "LastStand",           sound = "LastStand.ogg" },
    [2565]   = { key = "ShieldBlock",         sound = "ShieldBlock.ogg" },
    
    -- Arms 专精
    [12294]  = { key = "MortalStrike",        sound = "MortalStrike.ogg" },
    [7384]   = { key = "Overpower",           sound = "Overpower.ogg" },
    [46924]  = { key = "Bladestorm",          sound = "Bladestorm.ogg" },
    [1719]   = { key = "Recklessness",        sound = "recklessness.ogg" },
    [12328]  = { key = "SweepingStrikes",     sound = "sweepingStrikes.ogg" },
    [60503]  = { key = "TasteForBlood" },     -- Buff
    [52437]  = { key = "SuddenDeath" },       -- Buff
    
    -- Fury 专精
    [23881]  = { key = "Bloodthirst",         sound = "Bloodthirst.ogg" },
    [1680]   = { key = "Whirlwind",           sound = "Whirlwind.ogg" },
    [1464]   = { key = "Slam",                sound = "Slam.ogg" },
    [60970]  = { key = "HeroicFury",          sound = "HeroicFury.ogg" },
    [29801]  = { key = "Rampage" },           -- Buff
    [46916]  = { key = "Bloodsurge" },        -- Buff
    
    -- Protection 专精
    [6572]   = { key = "Revenge",             sound = "Revenge.ogg" },
    [23922]  = { key = "ShieldSlam",          sound = "ShieldSlam.ogg" },
    [46968]  = { key = "Shockwave",           sound = "Shockwave.ogg" },
    [20243]  = { key = "Devastate",           sound = "Devastate.ogg" },
    [12809]  = { key = "ConcussionBlow",      sound = "ConcussionBlow.ogg" },
}

-- 专精配置
ns.Classes.WARRIOR[71] = {  -- Arms
    name = "武器战",
    spells = warriorSpells,
    -- 这里将来可以添加默认 APL 和 Layout
}

ns.Classes.WARRIOR[72] = {  -- Fury
    name = "狂怒战",
    spells = warriorSpells,
}

ns.Classes.WARRIOR[73] = {  -- Protection
    name = "防护战",
    spells = warriorSpells,
}

-- =========================================================================
-- Warrior 特殊机制钩子
-- =========================================================================

--- Execute 技能可用性检查
-- 解决技术债务：从 State.lua 移除硬编码逻辑，改用钩子系统
ns.RegisterHook("check_spell_usable", function(event, spellID, spellName, usable, nomana)
    -- 仅处理 Execute
    if not ns.ID or not ns.ID.Execute then return nil end
    if spellID ~= ns.ID.Execute and spellName ~= GetSpellInfo(ns.ID.Execute) then
        return nil
    end
    
    -- Execute 特殊逻辑：
    -- 1. 检查条件：目标 < 20% HP 或有猝死 Buff
    local state = ns.State
    local cond_hp = (state.target.health.pct < 20)
    local cond_sd = false
    
    if ns.ID.SuddenDeath then
        -- 从 buff_cache 检查猝死 Buff
        local buffCache = rawget(state.player.buff, "__cache")
        if buffCache then
            local aura = buffCache[ns.ID.SuddenDeath]
            if aura and aura.up then
                cond_sd = true
            end
        end
    end
    
    -- 2. 如果满足条件，手动检查怒气
    if cond_hp or cond_sd then
        local rageRequired = 10  -- Execute 基础消耗
        if state.rage >= rageRequired then
            return { usable = true, nomana = false }
        else
            return { usable = false, nomana = true }  -- 资源不足
        end
    end
    
    -- 不满足条件，使用原始判断
    return nil
end)

--- Execute 执行后清除猝死 Buff
ns.RegisterHook("runHandler", function(event, actionName)
    if actionName ~= "execute" then return end
    
    -- 清除猝死 Buff 缓存
    if ns.ID and ns.ID.SuddenDeath then
        local state = ns.State
        local buffCache = rawget(state.player.buff, "__cache")
        if buffCache then
            buffCache[ns.ID.SuddenDeath] = nil
        end
    end
end)
