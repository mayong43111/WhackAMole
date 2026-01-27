-- Classes/Druid.lua
-- Druid class definition with spec detection
local _, ns = ...

-- 初始化职业数据空间
ns.Classes = ns.Classes or {}
ns.Classes.DRUID = {}

-- Druid Spec Detection Logic
ns.SpecRegistry:Register("DRUID", function()
    -- 51点天赋
    if IsPlayerSpell(53201) then return 102 end -- Starfall (Balance)
    if IsPlayerSpell(50334) then return 103 end -- Berserk (Feral)
    if IsPlayerSpell(33891) then return 105 end -- Tree of Life (Restoration)
    
    -- 31点天赋
    if IsPlayerSpell(33831) then return 102 end -- Force of Nature (Balance)
    if IsPlayerSpell(48566) or IsPlayerSpell(48564) then return 103 end -- Mangle (Feral)
    
    return nil
end)

-- 专精配置
ns.Classes.DRUID[102] = {  -- Balance
    name = "平衡德鲁伊",
}

ns.Classes.DRUID[103] = {  -- Feral
    name = "野性德鲁伊",
}

ns.Classes.DRUID[105] = {  -- Restoration
    name = "恢复德鲁伊",
}

-- =========================================================================
-- 德鲁伊特殊效果模拟（扩展点）
-- =========================================================================

--- 模拟德鲁伊特殊效果（形态切换等复杂机制）
-- @param action SimC action名称
-- @param state 虚拟状态对象
function ns.Classes.DRUID:SimulateSpecialEffect(action, state)
    -- 形态切换（特殊机制）
    if action == "cat_form" then
        -- 切换到猫形态
        if state.ChangeForm then
            state:ChangeForm("cat")
        end
        -- 法力转能量（简化处理：假设转换完成）
        if state.ConvertResource then
            state:ConvertResource("mana", "energy")
        end
        
    elseif action == "bear_form" then
        -- 切换到熊形态
        if state.ChangeForm then
            state:ChangeForm("bear")
        end
        -- 法力转怒气（简化处理：假设转换完成）
        if state.ConvertResource then
            state:ConvertResource("mana", "rage")
        end
    end
end
