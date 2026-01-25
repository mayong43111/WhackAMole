local _, ns = ...

-- UI/Grid/GridDragDrop.lua
-- Manages drag-and-drop interactions for spell assignment

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}

-- Handle receiving dragged spells
local function OnReceiveDrag(btn)
    local state = ns.UI.GridState
    local type, id, subType = GetCursorInfo()
    
    if type == "spell" then
        local name = GetSpellInfo(id, subType)
        if name then
            -- Check if target slot already has a spell
            local existingSpell = state.db.assignments and state.db.assignments[btn.slotId]
            if existingSpell then
                -- Swap: put target slot's spell on cursor
                PickupSpell(existingSpell)
            end
            
            ns.UI.Grid:UpdateButtonSpell(btn, name)
        end
        ClearCursor()
    end
end

-- Handle dragging spells out
local function OnDragStart(btn)
    local state = ns.UI.GridState
    
    if InCombatLockdown() or state.locked then return end
    
    local assigned = state.db.assignments and state.db.assignments[btn.slotId]
    if assigned then
        PickupSpell(assigned)
        state.db.assignments[btn.slotId] = nil
        
        -- Clear button attributes
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        
        -- Clear icon
        local icon = _G[btn:GetName() .. "Icon"]
        if icon then 
            icon:SetTexture(nil)
            icon:SetAlpha(0)
        end
        
        -- Show ghost icon
        btn.ghost:SetAlpha(0.3)
    end
end

-- Highlight slot on hover during drag
local function OnEnter(btn)
    local type, id = GetCursorInfo()
    if type == "spell" and not InCombatLockdown() and not ns.UI.GridState.locked then
        -- Preview effect: border highlight
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.8, 0.8, 0.0, 1.0)
        end
    end
end

-- Restore border on leave
local function OnLeave(btn)
    -- Restore default border
    if btn.SetBackdropBorderColor then
        if btn.color then
            btn:SetBackdropBorderColor(
                btn.color[1], 
                btn.color[2], 
                btn.color[3], 
                btn.color[4] or 1.0
            )
        else
            btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
        end
    end
end

-- Attach drag/drop handlers to button
function ns.UI.Grid:AttachDragDropHandlers(btn)
    btn:SetScript("OnReceiveDrag", OnReceiveDrag)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", OnDragStart)
    btn:SetScript("OnEnter", OnEnter)
    btn:SetScript("OnLeave", OnLeave)
end
