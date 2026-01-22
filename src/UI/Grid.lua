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

-- 状态跟踪，避免每帧重复启动动画
local lastActiveSlot = nil
local lastNextSlot = nil
local lastActiveAction = nil
local lastNextAction = nil

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
    
    -- Update UI with visible icon
    local icon = _G[btn:GetName().."Icon"]
    if icon then
        icon:SetTexture(iconTexture)
        icon:SetVertexColor(1, 1, 1, 1)
        icon:SetAlpha(1.0)  -- 显示实际技能图标
    end
    
    -- Hide ghost icon when spell is assigned
    if btn.ghost then
        btn.ghost:SetAlpha(0)
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
    if container then 
        container:Hide() 
        print("[WhackAMole] Grid: Hiding existing container for rebuild")
    end
    
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
                        -- 检查目标槽位是否已有技能
                        local existingSpell = db.assignments and db.assignments[self.slotId]
                        if existingSpell then
                            -- 技能交换：将目标槽位的技能放到光标
                            PickupSpell(existingSpell)
                        end
                        
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
                    if icon then 
                        icon:SetTexture(nil)
                        icon:SetAlpha(0)
                    end
                    
                    -- 显示底层幽灵图标
                    self.ghost:SetAlpha(0.3)
                end
            end)
            
            -- 拖拽预览：高亮目标槽位
            btn:SetScript("OnEnter", function(self)
                local type, id = GetCursorInfo()
                if type == "spell" and not InCombatLockdown() and not locked then
                    -- 预览效果：边框高亮
                    self:SetBackdropBorderColor(0.8, 0.8, 0.0, 1.0)
                end
            end)
            
            btn:SetScript("OnLeave", function(self)
                -- 恢复默认边框
                if self.color then
                    self:SetBackdropBorderColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1.0)
                else
                    self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
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
-- 基于 TODO.md P1 任务 1.3 和 3.3 - 支持主要高亮和次要高亮（预测）
function ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction, nextAction)
    -- 检查状态是否改变
    local stateChanged = (activeSlot ~= lastActiveSlot) or 
                         (nextSlot ~= lastNextSlot) or 
                         (activeAction ~= lastActiveAction) or 
                         (nextAction ~= lastNextAction)
    
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

        -- Highlights (基于 TODO.md P1 任务 3.3 - 视觉反馈完善)
        local isPrimary = false    -- 主要高亮（金色）
        local isSecondary = false  -- 次要高亮（蓝色）
        
        -- 1. 检查主要推荐：通过 SimC Action Name 匹配
        if activeAction and btn.action and btn.action == activeAction then
            isPrimary = true
        end

        -- 2. Fallback：通过 Slot ID 匹配（Legacy）
        if (not isPrimary) and (i == activeSlot) then
            isPrimary = true
        end
        
        -- 3. 检查次要推荐（预测）：通过 SimC Action Name 匹配
        if (not isPrimary) and nextAction and btn.action and btn.action == nextAction then
            isSecondary = true
        end
        
        -- 4. Fallback：通过 Slot ID 匹配次要推荐
        if (not isPrimary) and (not isSecondary) and (i == nextSlot) then
            isSecondary = true
        end

        -- 5. 应用高亮效果（仅在状态改变时更新）
        if stateChanged then
            if isPrimary then
                -- 主要高亮：金色像素光（PixelGlow）
                LCG.PixelGlow_Stop(btn)
                LCG.AutoCastGlow_Stop(btn) 
                local c = {1, 0.8, 0, 1}  -- 金色
                -- 参数：color, N(线条数), frequency(频率), length(长度), th(粗细)
                -- frequency=0.125 → period=8秒（较慢）
                LCG.PixelGlow_Start(btn, c, 8, 0.125, nil, 2)
                
            elseif isSecondary then
                -- 次要高亮：蓝色像素光（PixelGlow）- 基于 TODO.md P1 任务 3.3
                LCG.PixelGlow_Stop(btn)
                LCG.AutoCastGlow_Stop(btn)
                local c = {0.3, 0.6, 1, 1}  -- 蓝色
                -- 较慢的频率，较少的线条
                -- frequency=0.08 → period=12.5秒（很慢）
                LCG.PixelGlow_Start(btn, c, 6, 0.08, nil, 1.5)
            else
                -- 清除所有高亮
                LCG.PixelGlow_Stop(btn)
                LCG.AutoCastGlow_Stop(btn)
            end
        end
    end
    
    -- 更新状态跟踪
    if stateChanged then
        lastActiveSlot = activeSlot
        lastNextSlot = nextSlot
        lastActiveAction = activeAction
        lastNextAction = nextAction
    end
end

-- Get Specific Slot ID for Audio logic in Core
function ns.UI.Grid:GetSlotDef(slotIndex)
     -- This requires access to the layout data which lived in Core.
     -- Ideally Grid should store layout too.
     -- For now we return nil, caller might need to pass Layout.
end
