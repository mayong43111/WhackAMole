-- Classes/Rogue.lua
-- Rogue class definition with spec detection
local _, ns = ...

-- 初始化职业数据空间
ns.Classes = ns.Classes or {}
ns.Classes.ROGUE = {}

-- Rogue Spec Detection Logic
ns.SpecRegistry:Register("ROGUE", function()
    -- 51点天赋
    if IsPlayerSpell(14177) then return 259 end -- Cold Blood (Assassination)
    if IsPlayerSpell(13877) then return 260 end -- Blade Flurry (Combat)
    if IsPlayerSpell(14183) then return 261 end -- Premeditation (Subtlety)
    
    -- 41点天赋
    if IsPlayerSpell(14156) then return 259 end -- Mutilate (Assassination)
    if IsPlayerSpell(13750) then return 260 end -- Adrenaline Rush (Combat)
    if IsPlayerSpell(14185) then return 261 end -- Preparation (Subtlety)
    
    return nil
end)

-- 专精配置
ns.Classes.ROGUE[259] = {  -- Assassination
    name = "刺杀盗贼",
}

ns.Classes.ROGUE[260] = {  -- Combat
    name = "战斗盗贼",
}

ns.Classes.ROGUE[261] = {  -- Subtlety
    name = "敏锐盗贼",
}

-- =========================================================================
-- 盗贼特殊效果模拟（扩展点）
-- =========================================================================

--- 模拟盗贼特殊效果（潜行减耗等特殊机制）
-- @param action SimC action名称
-- @param state 虚拟状态对象
function ns.Classes.ROGUE:SimulateSpecialEffect(action, state)
    -- 潜行状态下能量消耗减半（特殊机制）
    if state.stealth and action:match("_strike$") then
        local SpellDatabase = ns.SpellDatabase
        if SpellDatabase then
            local spellData = SpellDatabase.Get(action)
            if spellData and spellData.cost and spellData.cost.energy then
                -- 返还一半能量
                if state.RefundEnergy then
                    state:RefundEnergy(spellData.cost.energy * 0.5)
                end
            end
        end
    end
end
