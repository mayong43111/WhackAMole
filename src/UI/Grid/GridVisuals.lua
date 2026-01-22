local _, ns = ...

-- UI/Grid/GridVisuals.lua
-- Manages visual updates: cooldowns, usability, and highlights

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}

local LCG = LibStub("LibCustomGlow-1.0")

-- Update cooldown display for a button
local function UpdateCooldown(btn, spellName)
    if not spellName then return end
    
    if btn.cooldown then
        local start, duration = GetSpellCooldown(spellName)
        if start and duration then
            btn.cooldown:SetCooldown(start, duration)
        end
    end
end

-- Update usability color for button icon
local function UpdateUsability(btn, spellName)
    if not spellName then return end
    
    if not btn.icon then return end
    
    local isUsable, noMana = IsUsableSpell(spellName)
    if not isUsable and not noMana then
        btn.icon:SetVertexColor(0.3, 0.3, 0.3)  -- Unusable: dark gray
    elseif noMana then
        btn.icon:SetVertexColor(0.5, 0.5, 1.0)  -- No mana: blue tint
    else
        btn.icon:SetVertexColor(1, 1, 1)        -- Usable: normal
    end
end

-- Check if button is primary recommendation
local function IsPrimary(btn, slotIndex, activeSlot, activeAction)
    -- 1. Match by SimC action name (preferred)
    if activeAction and btn.action and btn.action == activeAction then
        return true
    end
    
    -- 2. Match by slot ID (fallback)
    if slotIndex == activeSlot then
        return true
    end
    
    return false
end

-- Check if button is secondary recommendation (prediction)
local function IsSecondary(btn, slotIndex, nextSlot, nextAction, isPrimary)
    if isPrimary then return false end
    
    -- 1. Match by SimC action name (preferred)
    if nextAction and btn.action and btn.action == nextAction then
        return true
    end
    
    -- 2. Match by slot ID (fallback)
    if slotIndex == nextSlot then
        return true
    end
    
    return false
end

-- Apply glow effect based on recommendation level
local function ApplyGlow(btn, isPrimary, isSecondary)
    if isPrimary then
        -- Primary: Gold pixel glow
        LCG.PixelGlow_Stop(btn)
        LCG.AutoCastGlow_Stop(btn) 
        local color = {1, 0.8, 0, 1}
        LCG.PixelGlow_Start(btn, color, 8, 0.125, nil, 2)
        
    elseif isSecondary then
        -- Secondary: Blue pixel glow
        LCG.PixelGlow_Stop(btn)
        LCG.AutoCastGlow_Stop(btn)
        local color = {0.3, 0.6, 1, 1}
        LCG.PixelGlow_Start(btn, color, 6, 0.08, nil, 1.5)
    else
        -- Clear all glows
        LCG.PixelGlow_Stop(btn)
        LCG.AutoCastGlow_Stop(btn)
    end
end

-- Main visual update function (called from OnUpdate loop)
function ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction, nextAction)
    local state = ns.UI.GridState
    
    -- Check if state changed
    local stateChanged = (activeSlot ~= state.lastActiveSlot) or 
                         (nextSlot ~= state.lastNextSlot) or 
                         (activeAction ~= state.lastActiveAction) or 
                         (nextAction ~= state.lastNextAction)
    
    for i, btn in pairs(state.slots) do
        local spellName = btn:GetAttribute("spell")
        
        -- Update cooldown
        UpdateCooldown(btn, spellName)
        
        -- Update usability color
        UpdateUsability(btn, spellName)
        
        -- Update highlights (only if state changed)
        if stateChanged then
            local isPrimary = IsPrimary(btn, i, activeSlot, activeAction)
            local isSecondary = IsSecondary(btn, i, nextSlot, nextAction, isPrimary)
            ApplyGlow(btn, isPrimary, isSecondary)
        end
    end
    
    -- Update state tracking
    if stateChanged then
        state.lastActiveSlot = activeSlot
        state.lastNextSlot = nextSlot
        state.lastActiveAction = activeAction
        state.lastNextAction = nextAction
    end
end

-- Get slot definition (for audio logic in Core)
function ns.UI.Grid:GetSlotDef(slotIndex)
    -- Requires access to layout data from Core
    return nil
end
