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

-- 专精配置
ns.Classes.WARRIOR[71] = {  -- Arms
    name = "武器战",
}

ns.Classes.WARRIOR[72] = {  -- Fury
    name = "狂怒战",
}

ns.Classes.WARRIOR[73] = {  -- Protection
    name = "防护战",
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
