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
            local lastStart = btn.cooldown._lastStart or 0
            local lastDuration = btn.cooldown._lastDuration or 0
            local updateTime = btn.cooldown._lastUpdateTime or 0
            local now = GetTime()
            
            -- 防抖动：0.1秒内不重复更新（除非CD完全结束）
            if now - updateTime < 0.1 and not (start == 0 and duration == 0 and lastDuration > 0) then
                return
            end
            
            -- 只在有意义的变化时更新
            local hasCD = duration > 0
            local hadCD = lastDuration > 0
            
            if hasCD and hadCD then
                -- 都有CD：只在duration明显变化时更新（超过0.5秒差异）
                if math.abs(duration - lastDuration) < 0.5 then
                    return
                end
            elseif not hasCD and hadCD then
                -- CD结束：更新
            elseif hasCD and not hadCD then
                -- CD开始：更新
            else
                -- 都没CD：不更新
                return
            end
            
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown._lastStart = start
            btn.cooldown._lastDuration = duration
            btn.cooldown._lastUpdateTime = now
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

-- Update cast progress bar (施法进度条)
local function UpdateCastProgress(btn, spellName)
    -- 获取当前施法信息
    local castName, _, _, castStartTime, castEndTime = UnitCastingInfo("player")
    local channelName, _, _, channelStartTime, channelEndTime = UnitChannelInfo("player")
    
    local isCasting = false
    local progress = 0
    local isSameSpell = false
    
    if castName and castEndTime and type(castEndTime) == "number" then
        -- 正在施法
        local now = GetTime() * 1000
        local total = castEndTime - castStartTime
        local elapsed = now - castStartTime
        progress = total > 0 and (elapsed / total) or 0
        isCasting = true
        isSameSpell = (castName == spellName)
    elseif channelName and channelEndTime and type(channelEndTime) == "number" then
        -- 正在引导
        local now = GetTime() * 1000
        local total = channelEndTime - channelStartTime
        local remaining = channelEndTime - now
        progress = total > 0 and (remaining / total) or 0
        isCasting = true
        isSameSpell = (channelName == spellName)
    end
    
    -- 创建进度条（如果不存在）
    if not btn.castBar then
        btn.castBar = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        btn.castBar:SetColorTexture(0.1, 1, 0.1, 0.6)  -- 绿色半透明
        btn.castBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        btn.castBar:SetHeight(4)
    end
    
    -- 显示/隐藏进度条
    if isCasting and isSameSpell and progress > 0 and progress < 1 then
        local width = (btn:GetWidth() - 4) * progress
        btn.castBar:SetWidth(width)
        btn.castBar:Show()
    else
        btn.castBar:Hide()
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
        LCG.PixelGlow_Start(btn, color, 8, -0.25, nil, 2)
        
    elseif isSecondary then
        -- Secondary: Static border overlay (静态边框)
        LCG.PixelGlow_Stop(btn)
        LCG.AutoCastGlow_Stop(btn)
        
        -- 创建静态边框（如果不存在）
        if not btn.secondaryBorder then
            btn.secondaryBorder = btn:CreateTexture(nil, "OVERLAY")
            btn.secondaryBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            btn.secondaryBorder:SetBlendMode("ADD")
            btn.secondaryBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -12, 12)
            btn.secondaryBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 12, -12)
        end
        btn.secondaryBorder:SetVertexColor(0.3, 0.7, 1, 0.8)
        btn.secondaryBorder:Show()
    else
        -- Clear all glows
        LCG.PixelGlow_Stop(btn)
        LCG.AutoCastGlow_Stop(btn)
        if btn.secondaryBorder then
            btn.secondaryBorder:Hide()
        end
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
        
        -- Update cast progress bar (施法进度条)
        UpdateCastProgress(btn, spellName)
        
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
