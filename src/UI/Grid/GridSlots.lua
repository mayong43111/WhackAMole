local _, ns = ...

-- UI/Grid/GridSlots.lua
-- Manages button slots creation and spell assignment

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}

-- Create individual slot button
local function CreateSlotButton(slotIndex, slotDef, container, iconSize, cols, rows, spacing)
    local state = ns.UI.GridState
    local btnName = "WhackAMoleBtn" .. slotIndex
    
    -- Re-use existing frame if possible
    local btn = _G[btnName]
    if not btn then
        btn = CreateFrame("Button", btnName, container, "SecureActionButtonTemplate")
    end
    
    btn:SetParent(container)
    btn:SetSize(iconSize, iconSize)
    btn:Show()
    
    -- Setup backdrop for border effects
    if not btn.backdropSet then
        -- Ensure backdrop API is available
        if btn.SetBackdrop then
            btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn:SetBackdropColor(0, 0, 0, 0)
            btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
        end
        btn.backdropSet = true
    end
    
    -- Calculate position
    local col = (slotIndex - 1) % cols
    local row = math.floor((slotIndex - 1) / cols)
    local x = col * (iconSize + spacing) + (spacing / 2)
    local y = -(row * (iconSize + spacing) + (spacing / 2))
    
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
    
    -- Create main icon texture
    if not btn.icon then
        local icon = btn:CreateTexture(btnName .. "Icon", "ARTWORK")
        icon:SetAllPoints()
        btn.icon = icon
    end
    
    -- Create cooldown frame
    if not btn.cooldown then
        local cooldown = CreateFrame("Cooldown", btnName .. "Cooldown", btn, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetDrawEdge(true)
        cooldown:SetDrawSwipe(true)
        cooldown:SetReverse(true)  -- 反向转动
        btn.cooldown = cooldown
    end
    
    -- Create ghost icon (hint)
    if not btn.ghost then
        local ghost = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        ghost:SetAllPoints()
        ghost:SetDesaturated(true)
        ghost:SetVertexColor(1, 1, 1, 0.4)
        btn.ghost = ghost
    end
    
    -- Set ghost icon texture
    local _, _, hintIcon = GetSpellInfo(slotDef.id)
    btn.ghost:SetTexture(hintIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Store metadata
    btn.color = slotDef.color
    btn.slotId = slotIndex
    
    -- Store SimC action name if provided
    if slotDef.action then
        btn.action = slotDef.action
        -- Try to resolve ID from action name
        if (not slotDef.id) and ns.ActionMap and ns.ActionMap[slotDef.action] then
            slotDef.id = ns.ActionMap[slotDef.action]
        end
    end
    
    -- Add tooltip on hover
    if not btn.tooltipSet then
        btn:SetScript("OnEnter", function(self)
            local spellName = self:GetAttribute("spell")
            if spellName then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpell(spellName)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        btn.tooltipSet = true
    end
    
    return btn
end

-- Create all slot buttons
function ns.UI.Grid:CreateSlots(layout, iconSize, spacing, cols, rows)
    local state = ns.UI.GridState
    
    for i, slotDef in pairs(layout.slots) do
        if type(i) == "number" then
            local btn = CreateSlotButton(i, slotDef, state.container, iconSize, cols, rows, spacing)
            
            -- Attach drag/drop handlers
            ns.UI.Grid:AttachDragDropHandlers(btn)
            
            state.slots[i] = btn
        end
    end
end

-- Update a single button's spell assignment
function ns.UI.Grid:UpdateButtonSpell(btn, spellIdOrName)
    if InCombatLockdown() then
        print("WhackAMole: Cannot change spells in combat!")
        return
    end
    
    local state = ns.UI.GridState
    local name, _, iconTexture = GetSpellInfo(spellIdOrName)
    if not name then return end

    -- Set secure attributes
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", name)
    
    -- Update icon
    if btn.icon then
        btn.icon:SetTexture(iconTexture)
        btn.icon:SetVertexColor(1, 1, 1, 1)
        btn.icon:SetAlpha(1.0)
    end
    
    -- Hide ghost icon
    if btn.ghost then
        btn.ghost:SetAlpha(0)
    end
    
    -- Save to database
    if state.db and state.db.assignments then
        state.db.assignments[btn.slotId] = name
    end
end

-- Clear all slot assignments
function ns.UI.Grid:ClearAllAssignments()
    if InCombatLockdown() then 
        print("WhackAMole: Cannot clear spells in combat!")
        return 
    end
    
    local state = ns.UI.GridState
    
    if state.db and state.db.assignments then
        table.wipe(state.db.assignments)
    end
    
    for i, btn in pairs(state.slots) do
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        
        local icon = _G[btn:GetName() .. "Icon"]
        if icon then icon:SetTexture(nil) end
    end
    
    print("WhackAMole: Action Bar Cleared.")
end

-- Restore saved assignments from database
function ns.UI.Grid:RestoreAssignments()
    local state = ns.UI.GridState
    
    for i, btn in pairs(state.slots) do
        local savedSpell = state.db.assignments and state.db.assignments[i]
        if savedSpell then
            self:UpdateButtonSpell(btn, savedSpell)
        end
    end
end

-- Context Menu
function ns.UI.Grid:OpenContextMenu(anchor)
    local menu = {
        { text = "WhackAMole 选项", isTitle = true, notCheckable = true },
        { 
            text = ns.UI.GridState.locked and "解锁框架" or "锁定框架",
            func = function() 
                self:SetLock(not ns.UI.GridState.locked) 
                LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
            end,
            notCheckable = true
        },
        {
            text = "清空动作条",
            func = function() self:ClearAllAssignments() end,
            notCheckable = true
        },
        { 
            text = "设置 ...",
            func = function() LibStub("AceConfigDialog-3.0"):Open("WhackAMole") end,
            notCheckable = true
        },
        { text = "取消", notCheckable = true, func = function() end }
    }
    
    local menuFrame = _G.WhackAMoleContextMenu
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "WhackAMoleContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    
    local function InitMenu(frame, level, menuList)
        for _, item in ipairs(menu) do
            UIDropDownMenu_AddButton(item, level)
        end
    end

    UIDropDownMenu_Initialize(menuFrame, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, anchor, 0, 0)
end
