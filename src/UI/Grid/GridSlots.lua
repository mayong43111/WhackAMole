local _, ns = ...

-- UI/Grid/GridSlots.lua
-- Manages button slots creation and spell assignment

ns.UI = ns.UI or {}
ns.UI.Grid = ns.UI.Grid or {}

local function ResolveHighestKnownSpellByAction(action)
    if not action or not ns.ActionMap then
        return nil
    end

    local mappedSpellID = ns.ActionMap[action]
    if not mappedSpellID then
        return nil
    end

    local baseSpellName = GetSpellInfo(mappedSpellID)
    if not baseSpellName then
        return nil
    end

    local bestName = nil
    local bestRank = -1
    local index = 1
    while true do
        local spellName, spellRank = GetSpellBookItemName(index, BOOKTYPE_SPELL)
        if not spellName then
            break
        end

        if spellName == baseSpellName then
            local rankNum = tonumber((spellRank or ""):match("(%d+)")) or 0
            if rankNum >= bestRank then
                bestRank = rankNum
                bestName = spellName
            end
        end

        index = index + 1
    end

    return bestName
end

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
    
    -- 清空旧的spell属性（重要：切换配置时）
    if not InCombatLockdown() then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
    end
    
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
    
    -- 清空主图标（确保显示ghost）
    btn.icon:SetTexture(nil)
    btn.icon:SetAlpha(0)
    
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
    
    -- Resolve spell ID from action name BEFORE using it
    if slotDef.action and (not slotDef.id) and ns.ActionMap and ns.ActionMap[slotDef.action] then
        slotDef.id = ns.ActionMap[slotDef.action]
    end
    
    -- Set ghost icon texture and ensure it's visible
    local _, _, hintIcon = GetSpellInfo(slotDef.id)
    btn.ghost:SetTexture(hintIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.ghost:SetAlpha(1.0)
    
    -- Store metadata
    btn.color = slotDef.color
    btn.slotId = slotIndex
    
    -- Store SimC action name if provided
    if slotDef.action then
        btn.action = slotDef.action
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
        ns.Logger:System("WhackAMole: Cannot change spells in combat!")
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
        ns.Logger:System("WhackAMole: Cannot clear spells in combat!")
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
    
    ns.Logger:System("WhackAMole: Action Bar Cleared.")
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

function ns.UI.Grid:AutoFillSlotsWithHighestRank()
    if InCombatLockdown() then
        ns.Logger:System("WhackAMole: Cannot auto-fill spells in combat!")
        return
    end

    local state = ns.UI.GridState
    local slotIndexes = {}
    for slotIndex in pairs(state.slots) do
        table.insert(slotIndexes, slotIndex)
    end
    table.sort(slotIndexes)

    local filledCount = 0
    local skippedCount = 0

    for _, slotIndex in ipairs(slotIndexes) do
        local btn = state.slots[slotIndex]
        if btn and btn.action then
            local highestSpellName = ResolveHighestKnownSpellByAction(btn.action)
            if highestSpellName then
                self:UpdateButtonSpell(btn, highestSpellName)
                filledCount = filledCount + 1
            else
                skippedCount = skippedCount + 1
            end
        else
            skippedCount = skippedCount + 1
        end
    end

    ns.Logger:System(string.format("WhackAMole: 自动填充完成（已填充 %d，跳过 %d）。", filledCount, skippedCount))
end

function ns.UI.Grid:GetCurrentPresetName()
    local addon = ns.WhackAMole
    if addon and addon.currentProfile and addon.currentProfile.meta and addon.currentProfile.meta.name then
        return addon.currentProfile.meta.name
    end

    local activeID = addon and addon.db and addon.db.char and addon.db.char.activeProfileID
    if activeID and ns.ProfileManager and ns.ProfileManager.GetProfile then
        local profile = ns.ProfileManager:GetProfile(activeID)
        if profile and profile.meta and profile.meta.name then
            return profile.meta.name
        end
    end

    return "未选择"
end

function ns.UI.Grid:QuickSwitchPreset()
    if InCombatLockdown() then
        ns.Logger:System("WhackAMole: Cannot switch preset in combat!")
        return
    end

    local addon = ns.WhackAMole
    if not (addon and addon.db and addon.db.char and ns.ProfileManager) then
        ns.Logger:System("WhackAMole: 配置系统未就绪，无法切换。")
        return
    end

    local _, playerClass = UnitClass("player")
    local currentSpec = nil
    if ns.SpecDetection and ns.SpecDetection.GetSpecID then
        currentSpec = ns.SpecDetection:GetSpecID(false)
    end

    local candidates = ns.ProfileManager:GetProfilesForClass(playerClass) or {}
    local selectable = {}
    for _, cand in ipairs(candidates) do
        local profile = cand.profile
        local spec = profile and profile.meta and profile.meta.spec
        if currentSpec == nil or spec == nil or spec == currentSpec then
            table.insert(selectable, cand)
        end
    end

    if #selectable == 0 then
        ns.Logger:System("WhackAMole: 未找到可切换的配置。")
        return
    end

    table.sort(selectable, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    local currentID = addon.db.char.activeProfileID
    local currentIndex = 0
    for i, cand in ipairs(selectable) do
        if cand.id == currentID then
            currentIndex = i
            break
        end
    end

    local nextIndex = (currentIndex % #selectable) + 1
    local nextCandidate = selectable[nextIndex]
    if not nextCandidate or not nextCandidate.profile then
        ns.Logger:System("WhackAMole: 切换失败，目标配置无效。")
        return
    end

    addon.db.char.activeProfileID = nextCandidate.id
    addon:SwitchProfile(nextCandidate.profile)

    local nextName = nextCandidate.profile.meta and nextCandidate.profile.meta.name or "未知配置"
    ns.Logger:System("WhackAMole: 已切换到配置 - " .. nextName)
end

-- Context Menu
function ns.UI.Grid:OpenContextMenu(anchor)
    local currentPresetName = self:GetCurrentPresetName()
    local menu = {
        { text = "WhackAMole 选项", isTitle = true, notCheckable = true },
        { text = "当前 Preset: " .. currentPresetName, notCheckable = true, disabled = true },
        { 
            text = ns.UI.GridState.locked and "解锁框架" or "锁定框架",
            func = function() 
                self:SetLock(not ns.UI.GridState.locked) 
                LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
            end,
            notCheckable = true
        },
        {
            text = "快速切换 Preset",
            func = function() self:QuickSwitchPreset() end,
            notCheckable = true
        },
        {
            text = "清空动作条",
            func = function() self:ClearAllAssignments() end,
            notCheckable = true
        },
        {
            text = "自动填充（最高等级）",
            func = function() self:AutoFillSlotsWithHighestRank() end,
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
