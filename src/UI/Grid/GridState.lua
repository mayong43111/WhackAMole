local _, ns = ...

-- UI/Grid/GridState.lua
-- Manages Grid state, configuration, and references

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}
ns.UI.GridState = {}

-- Local Config Constants
ns.UI.GridState.DEFAULT_ICON_SIZE = 40
ns.UI.GridState.DEFAULT_SPACING = 6

-- Store references (exposed for other Grid modules)
ns.UI.GridState.db = nil
ns.UI.GridState.container = nil
ns.UI.GridState.slots = {}
ns.UI.GridState.handle = nil
ns.UI.GridState.bg = nil
ns.UI.GridState.locked = true

-- Visual state tracking (避免每帧重复启动动画)
ns.UI.GridState.lastActiveSlot = nil
ns.UI.GridState.lastNextSlot = nil
ns.UI.GridState.lastActiveAction = nil
ns.UI.GridState.lastNextAction = nil

-- Initialize database reference
function ns.UI.Grid:Initialize(database)
    ns.UI.GridState.db = database
end

-- Lock/Unlock State Setter
function ns.UI.Grid:SetLock(isLocked)
    local state = ns.UI.GridState
    state.locked = isLocked
    
    if not state.container or not state.handle then return end

    if state.locked then
        state.bg:Hide()
        state.container:EnableMouse(false)
        
        -- Locked Style: Small unobtrusive button
        state.handle:ClearAllPoints()
        state.handle:SetPoint("BOTTOMLEFT", state.container, "TOPLEFT", 0, 0)
        state.handle:SetSize(20, 20)
        
        state.handle.text:SetText("")
        state.handle.tex:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        
        -- Hover effect to find it easily
        state.handle:SetAlpha(0.2)
        state.handle:SetScript("OnEnter", function(f) f:SetAlpha(1.0) end)
        state.handle:SetScript("OnLeave", function(f) f:SetAlpha(0.2) end)
    else
        state.bg:Show()
        state.container:EnableMouse(true)
        
        -- Unlocked Style: Full Bar
        state.handle:ClearAllPoints()
        state.handle:SetPoint("BOTTOMLEFT", state.container, "TOPLEFT", 0, 0)
        state.handle:SetPoint("BOTTOMRIGHT", state.container, "TOPRIGHT", 0, 0)
        state.handle:SetHeight(18)
        
        state.handle.text:SetText("WhackAMole")
        state.handle.tex:SetColorTexture(0.1, 0.1, 0.1, 0.9)
        
        -- Reset Alpha & Scripts
        state.handle:SetAlpha(1.0)
        state.handle:SetScript("OnEnter", nil)
        state.handle:SetScript("OnLeave", nil)
    end
end
