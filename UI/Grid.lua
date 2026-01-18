local _, ns = ...

-- UI/Grid.lua
-- Manages the Grid Frame, Buttons, Interaction (Drag/Drop), and visual updates.

ns.UI = ns.UI or {}
ns.UI.Grid = {}

local LCG = LibStub("LibCustomGlow-1.0")

-- References injected by Init
local dbChecked = false
local db = nil -- Reference to WhackAMole.db.char for persistence

-- Local Config Constants (should ideally strictly come from Core's config)
local DEFAULT_ICON_SIZE = 40
local DEFAULT_SPACING = 6

-- Store references
local container = nil
local slots = {}
local handle = nil
local bg = nil
local locked = true

function ns.UI.Grid:Initialize(database)
    db = database
end

function ns.UI.Grid:SetLock(isLocked)
    locked = isLocked
    
    if not container or not handle then return end

    if locked then
        bg:Hide()
        container:EnableMouse(false)
        
        -- Locked Style: Small unobtrusive button
        handle:ClearAllPoints()
        handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 0)
        handle:SetSize(20, 20) -- Small square
        
        handle.text:SetText("") -- No text
        handle.tex:SetColorTexture(0.3, 0.3, 0.3, 0.3) -- Faint Drag Handle
        
        -- Hover effect to find it easily
        handle:SetAlpha(0.2)
        handle:SetScript("OnEnter", function(f) f:SetAlpha(1.0) end)
        handle:SetScript("OnLeave", function(f) f:SetAlpha(0.2) end)
    else
        bg:Show()
        container:EnableMouse(true)
        
        -- Unlocked Style: Full Bar
        handle:ClearAllPoints()
        handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 0)
        handle:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 0)
        handle:SetHeight(18)
        
        handle.text:SetText("WhackAMole")
        handle.tex:SetColorTexture(0.1, 0.1, 0.1, 0.9) -- Solid Header
        
        -- Reset Alpha & Scripts
        handle:SetAlpha(1.0)
        handle:SetScript("OnEnter", nil)
        handle:SetScript("OnLeave", nil)
    end
end

-- Update a Single Button's Assignment (Spell)
function ns.UI.Grid:UpdateButtonSpell(btn, spellIdOrName)
    if InCombatLockdown() then
        print("WhackAMole: Cannot change spells in combat!")
        return
    end
    
    -- Update Secure Attributes
    -- WotLK: use "spell" type and Spell ID or Name
    local name, _, iconTexture = GetSpellInfo(spellIdOrName)
    if not name then return end

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", name) -- Using name handles ranks automatically usually
    
    -- Update UI
    -- icon is the texture object, not the path. 
    -- GetSpellInfo returns: name, rank, icon, ...
    local icon = _G[btn:GetName().."Icon"]
    if icon then
        icon:SetTexture(iconTexture)
        icon:SetVertexColor(1, 1, 1, 1)
    end
    
    -- Save DB
    if db and db.assignments then
        db.assignments[btn.slotId] = name
    end
end

-- Clear all assignments
function ns.UI.Grid:ClearAllAssignments()
    if InCombatLockdown() then 
        print("WhackAMole: Cannot clear spells in combat!")
        return 
    end
    
    if db and db.assignments then
        table.wipe(db.assignments)
    end
    
    for i, btn in pairs(slots) do
        btn:SetAttribute("type", nil) -- Removes click action
        btn:SetAttribute("spell", nil)
        
        local icon = _G[btn:GetName().."Icon"]
        if icon then icon:SetTexture(nil) end
    end
    print("WhackAMole: Action Bar Cleared.")
end

-- Open Context Menu
function ns.UI.Grid:OpenContextMenu(anchor)
    local menu = {
        { text = "WhackAMole 选项", isTitle = true, notCheckable = true },
        { 
            text = locked and "解锁框架" or "锁定框架",
            func = function() 
                self:SetLock(not locked) 
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

-- Main Creation Function
function ns.UI.Grid:Create(layout, config)
    if container then container:Hide() end
    
    local iconSize = config.iconSize or DEFAULT_ICON_SIZE
    local spacing = config.spacing or DEFAULT_SPACING

    local count = 0
    for _ in pairs(layout.slots) do count = count + 1 end
    
    -- Dynamic Layout: Max 5 cols, try to balance
    local cols, rows
    
    if layout.cols and layout.rows then
        cols = layout.cols
        rows = layout.rows
    else
        local MAX_COLS = 5
        if count <= MAX_COLS then
            cols = count
            rows = 1
        else
            rows = math.ceil(count / MAX_COLS)
            cols = math.ceil(count / rows)
        end
    end
    
    -- Ensure min dimensions
    if cols < 1 then cols = 1 end
    if rows < 1 then rows = 1 end

    local w = cols * (iconSize + spacing)
    local h = rows * (iconSize + spacing)
    
    if not container then
        container = CreateFrame("Frame", "WhackAMoleGrid", UIParent)
    end
    container:SetSize(w, h)
    container:Show()
    
    -- Restore Position
    local pos = db and db.position
    if pos and pos.point then
        container:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        container:SetPoint("CENTER", 0, -220)
    end
    
    -- Dragging
    container:SetMovable(true)
    container:EnableMouse(true)
    
    -- Background
    if not bg then
        bg = container:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
    end

    -- Drag Handle
    if not handle then
        handle = CreateFrame("Button", "WhackAMoleDragHandle", container)
        handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        local handleTex = handle:CreateTexture(nil, "ARTWORK")
        handleTex:SetAllPoints()
        handle.tex = handleTex
        
        local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        handleText:SetPoint("CENTER")
        handle.text = handleText
        
        handle:SetScript("OnMouseDown", function(f, button)
            if button == "LeftButton" and not locked then
                container:StartMoving()
            end
        end)
        handle:SetScript("OnMouseUp", function(f, button)
            if button == "LeftButton" then
                 if not locked then
                    container:StopMovingOrSizing()
                    -- Save Position
                    local point, _, relPoint, x, y = container:GetPoint()
                    if db then
                        db.position = { point = point, relativePoint = relPoint, x = x, y = y }
                    end
                 end
            elseif button == "RightButton" then
                 self:OpenContextMenu(f)
            end
        end)
    end
    
    self:SetLock(true)

    -- Reset Slots
    slots = {}
    -- Note: We might need to recycle frames instead of making new ones endlessly if layout changes often.
    -- For now, MVP assumes layout changes are rare (spec change).
    
    for i, slotDef in pairs(layout.slots) do
        if type(i) == "number" then
            local btnName = "WhackAMoleBtn"..i
            -- Re-use existing frame if possible (by name global lookup)
            local btn = _G[btnName] or CreateFrame("Button", btnName, container, "SecureActionButtonTemplate, ActionButtonTemplate")
            
            btn:SetParent(container)
            btn:SetSize(iconSize, iconSize)
            btn:Show()
            
            -- Simple Grid Layouting
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            
            local x = col * (iconSize + spacing) + (spacing/2)
            local y = -(row * (iconSize + spacing) + (spacing/2))
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            
            -- Ghost Icon
            if not btn.ghost then
                local ghost = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
                ghost:SetAllPoints()
                ghost:SetDesaturated(true)
                ghost:SetVertexColor(1, 1, 1, 0.4)
                btn.ghost = ghost
            end
            
            local _, _, hintIcon = GetSpellInfo(slotDef.id)
            btn.ghost:SetTexture(hintIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            btn.color = slotDef.color
            btn.slotId = i
            
             -- NEW: Store Action (snake_case) on button if provided
            if slotDef.action then
                btn.action = slotDef.action
                -- If ID is missing but Action is provided, try to resolve it via Global Mapping
                if (not slotDef.id) and ns.ActionMap and ns.ActionMap[slotDef.action] then
                    slotDef.id = ns.ActionMap[slotDef.action]
                end
            end
            
            local _, _, hintIcon = GetSpellInfo(slotDef.id)
            btn.ghost:SetTexture(hintIcon or "Interface\\Icons\\INV_Misc_QuestionMark")

            btn:SetScript("OnReceiveDrag", function(self)
                local type, id, subType = GetCursorInfo()
                if type == "spell" then
                    local name = GetSpellInfo(id, subType)
                    if name then
                        ns.UI.Grid:UpdateButtonSpell(self, name)
                    end
                    ClearCursor()
                end
            end)

            btn:RegisterForDrag("LeftButton")
            btn:SetScript("OnDragStart", function(self)
                if InCombatLockdown() or locked then return end
                
                local assigned = db.assignments and db.assignments[self.slotId]
                if assigned then
                    PickupSpell(assigned)
                    db.assignments[self.slotId] = nil
                    self:SetAttribute("type", nil)
                    self:SetAttribute("spell", nil)
                    local icon = _G[self:GetName().."Icon"]
                    if icon then icon:SetTexture(nil) end
                end
            end)
            
            slots[i] = btn
        end
    end
    
    -- Hide unused buttons from previous layouts if any (Primitive recycling check)
    -- Ideally we loop known max buttons.
    
    -- Restore Assignments
    for i, btn in pairs(slots) do
        local savedSpell = db.assignments and db.assignments[i]
        if savedSpell then
            self:UpdateButtonSpell(btn, savedSpell)
        end
    end
end

-- Visual Update for OnUpdate loop
function ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction)
    for i, btn in pairs(slots) do
        local spellName = btn:GetAttribute("spell")
        
        -- CD
        if spellName then
            local cooldown = _G[btn:GetName().."Cooldown"]
            if cooldown then
                local start, duration = GetSpellCooldown(spellName)
                if start and duration then
                    cooldown:SetCooldown(start, duration)
                end
            end
        end

        -- Usable Color
        if spellName then
            local icon = _G[btn:GetName().."Icon"]
            if icon then
                local isUsable, noMana = IsUsableSpell(spellName)
                if not isUsable and not noMana then
                    icon:SetVertexColor(0.3, 0.3, 0.3)
                elseif noMana then
                    icon:SetVertexColor(0.5, 0.5, 1.0)
                else
                    icon:SetVertexColor(1, 1, 1)
                end
            end
        end

        -- Highlights
        local shouldGlow = false
        
        -- 1. Try matching by SimC Action Name
        if activeAction and btn.action and btn.action == activeAction then
            shouldGlow = true
        end

        -- 2. Fallback: Match by Slot ID (Legacy)
        if (not shouldGlow) and (i == activeSlot) then
            shouldGlow = true
        end

        if shouldGlow then
            LCG.AutoCastGlow_Stop(btn) 
            local c = {1, 0.8, 0, 1} 
            LCG.PixelGlow_Start(btn, c, nil, -0.25, nil, 3)
            
        elseif i == nextSlot then
            LCG.PixelGlow_Stop(btn)
            LCG.AutoCastGlow_Start(btn, {0, 1, 1, 1}, 4, 0.25, 1, 0, 0)
        else
            LCG.PixelGlow_Stop(btn)
            LCG.AutoCastGlow_Stop(btn)
        end
    end
end

-- Get Specific Slot ID for Audio logic in Core
function ns.UI.Grid:GetSlotDef(slotIndex)
     -- This requires access to the layout data which lived in Core.
     -- Ideally Grid should store layout too.
     -- For now we return nil, caller might need to pass Layout.
end
