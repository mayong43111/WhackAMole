local _, ns = ...

-- 初始化职业命名空间
ns.Classes = ns.Classes or {}
ns.Classes.MAGE = {}

-- Mage Spec Detection Logic
ns.SpecRegistry:Register("MAGE", function()
    -- Arcane: Arcane Barrage (44425)
    if IsPlayerSpell(44425) then return 62 end
    
    -- Fire: Living Bomb (44457) or Dragon's Breath (31661)
    if IsPlayerSpell(44457) or IsPlayerSpell(31661) then return 63 end
    
    -- Frost: Deep Freeze (44572)
    if IsPlayerSpell(44572) then return 64 end

    return nil
end)

-- 专精配置
ns.Classes.MAGE[62] = {  -- Arcane
    name = "奥术法师",
}

ns.Classes.MAGE[63] = {  -- Fire
    name = "火焰法师",
}

ns.Classes.MAGE[64] = {  -- Frost
    name = "冰霜法师",
}

--- 模拟法师特殊效果（Buff消费等职业特定机制）
-- @param action SimC action名称
-- @param state 虚拟状态对象
function ns.Classes.MAGE:SimulateSpecialEffect(action, state)
    local Logger = ns.Logger
    
    -- ========================================
    -- 冰霜系：寒冰指 (Fingers of Frost, 44544)
    -- ========================================
    -- ice_lance 和 frostbolt 都会消耗寒冰指buff
    -- 寒冰指最多2层，ConsumeBuff会自动处理层数递减
    if action == "ice_lance" or action == "frostbolt" then
        if state.ConsumeBuff then
            state:ConsumeBuff(44544)  -- Fingers of Frost
        end
        return
    end
    
    -- ========================================
    -- 火焰系：热能奔流 (Hot Streak, 48108)
    -- ========================================
    -- pyroblast, fireball, frostfire_bolt 都会消耗热能奔流
    if action == "pyroblast" or action == "fireball" or action == "frostfire_bolt" then
        if state.ConsumeBuff then
            state:ConsumeBuff(48108)  -- Hot Streak (rank 2, WotLK)
        end
        return
    end
    
    -- ========================================
    -- 火焰系：冲击 (Impact, 64343)
    -- ========================================
    -- fire_blast 和 flamestrike 消耗冲击buff（如果有）
    if action == "fire_blast" or action == "flamestrike" then
        if state.ConsumeBuff then
            state:ConsumeBuff(64343)  -- Impact
        end
        return
    end
end
