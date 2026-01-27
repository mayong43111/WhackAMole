local addon, ns = ...

-- =========================================================================
-- Engine/EffectSimulator.lua - 技能效果模拟器
-- =========================================================================

local EffectSimulator = {}
ns.EffectSimulator = EffectSimulator

local SpellDatabase = ns.SpellDatabase
local State = ns.State
local Logger = ns.Logger
local Classes = ns.Classes

--- 模拟技能效果（混合架构：通用框架 + 职业扩展）
-- @param action SimC action名称
-- @param state 虚拟状态对象
function EffectSimulator.SimulateSpell(action, state)
    if not action or not state then return end
    
    -- 1. 先查询技能数据库（统一配置，80%通用情况）
    local spellData = SpellDatabase and SpellDatabase.Get(action)
    
    if spellData then
        EffectSimulator.ApplyCommonEffects(spellData, state, action)
    else
        -- 技能不在数据库中，应用默认效果（GCD + CD）
        if state.TriggerGCD then
            state:TriggerGCD(1.5)  -- 默认 GCD 1.5秒
        end
        -- 大部分技能都没有CD，这里不设置默认CD
    end
    
    -- 2. 调用职业特殊逻辑（扩展点，20%特殊情况）
    local class = state.playerClass
    if class and Classes and Classes[class] and Classes[class].SimulateSpecialEffect then
        Classes[class]:SimulateSpecialEffect(action, state)
    end
end

--- 应用通用效果（数据驱动）
-- @param data 技能数据
-- @param state 虚拟状态对象
-- @param action 技能名称（用于日志）
function EffectSimulator.ApplyCommonEffects(data, state, action)
    -- Debuff 效果
    if data.debuff and state.AddDebuff then
        state:AddDebuff(data.debuff.name, data.debuff.duration)
    end
    
    -- Buff 效果
    if data.buff and state.AddBuff then
        state:AddBuff(data.buff.name, data.buff.duration)
    end
    
    -- 资源消耗
    if data.cost then
        for resource, amount in pairs(data.cost) do
            if resource == "comboPoints" and state.ConsumeComboPoints then
                state:ConsumeComboPoints()
            elseif resource == "energy" and state.ConsumeEnergy then
                state:ConsumeEnergy(amount)
            elseif resource == "mana" and state.ConsumeMana then
                state:ConsumeMana(amount)
            elseif resource == "rage" and state.ConsumeRage then
                state:ConsumeRage(amount)
            elseif resource == "runicPower" and state.ConsumeRunicPower then
                state:ConsumeRunicPower(amount)
            end
        end
    end
    
    -- 资源生成
    if data.gain then
        for resource, amount in pairs(data.gain) do
            if resource == "comboPoints" and state.AddComboPoints then
                state:AddComboPoints(amount)
            elseif resource == "energy" and state.AddEnergy then
                state:AddEnergy(amount)
            elseif resource == "mana" and state.AddMana then
                state:AddMana(amount)
            elseif resource == "rage" and state.AddRage then
                state:AddRage(amount)
            elseif resource == "runicPower" and state.AddRunicPower then
                state:AddRunicPower(amount)
            end
        end
    end
    
    -- 触发 CD
    if data.cooldown and state.SetCooldown then
        state:SetCooldown(action, data.cooldown)
    end
    
    -- 触发 GCD
    if state.TriggerGCD then
        local gcd = data.gcd or 1.5
        state:TriggerGCD(gcd)
    end
end

return EffectSimulator
