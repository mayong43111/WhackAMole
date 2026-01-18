local addonName, ns = ...
local WhackAMole = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

_G.WhackAMole = WhackAMole
ns.WhackAMole = WhackAMole

local CONFIG = {
    iconSize = 40,
    spacing = 6,
    updateInterval = 0.05
}

WhackAMole.slots = {} -- will store the frame objects
WhackAMole.currentProfile = nil
WhackAMole.logicFunc = nil

-- Default DB
local defaultDB = {
    global = {
        audio = { enabled = false }
    },
    profile = {
        minimap = { hide = false },
    },
    char = {
        assignments = {}, -- [slotId] = spellID
        position = { point = "CENTER", x = 0, y = -220 }
    }
}

function WhackAMole:GetPlayerSpec(isDebug)
    local _, playerClass = UnitClass("player")
    
    local maxPoints = -1
    local specIndex = 1
    local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    
    if isDebug then
        self:Print("Debug: Checking Spec for " .. playerClass .. " (Group: " .. tostring(activeGroup) .. ")")
    end

    -- Scan Tabs
    for i = 1, 3 do
        -- Method 1: Standard API with Active Group
        local _, _, points = GetTalentTabInfo(i, false, false, activeGroup)
        
        -- Fallback A: Try without group arg if points is nil
        if not points then 
            _, _, points = GetTalentTabInfo(i)
        end
        
        if isDebug then
            self:Print("Debug: Tab " .. i .. " API Points: " .. tostring(points))
        end

        -- Method 2: Manual Scan (Deep Search) - FORCE if points is 0 or nil
        -- Lua treats 0 as true, so we must explicitly check for 0
        if not points or points == 0 then
             local numTalents = GetNumTalents(i) or 0
             local total = 0
             for t = 1, numTalents do
                 -- GetTalentInfo(tab, index, isInspect, isPet, group)
                 local _, _, _, _, rank = GetTalentInfo(i, t, false, false, activeGroup)
                 if not rank then
                     -- Try without group
                     _, _, _, _, rank = GetTalentInfo(i, t)
                 end

                 if rank then 
                    total = total + rank 
                 end
             end
             
             if total > 0 then 
                points = total 
                if isDebug then self:Print("Debug: Manual Scan Tab " .. i .. " found " .. total .. " points") end
             else
                if isDebug then self:Print("Debug: Manual Scan Tab " .. i .. " found 0 points (NumTalents="..numTalents..")") end
             end
        end

        points = tonumber(points) or 0
        
        if points > maxPoints then
            maxPoints = points
            specIndex = i
        end
    end
    
    -- Method 3: Spell Book Heuristics (Final Fallback)
    -- If talent data is totally borked, check for signature spells
    -- Only do this if we haven't found significant points (e.g. < 10)
    if maxPoints <= 10 then 
        if isDebug then self:Print("Debug: Talent Data missing/low. Trying Spell Heuristics...") end
        local detectedSpec = ns.SpecRegistry and ns.SpecRegistry:Detect(playerClass)
        if detectedSpec then
            if isDebug then self:Print("Debug: Heuristic detected spec: " .. detectedSpec) end
            return detectedSpec
        end
    end
    
    -- If MaxPoints is 0, we might be low level OR data not loaded.
    if maxPoints <= 0 and UnitLevel("player") > 10 then
        if isDebug then self:Print("Debug: Spec Detection Failed (MaxPoints="..maxPoints..")") end
        return nil -- Return nil to indicate "Not Ready"
    end
    
    -- Map Index to SpecID based on highest points tab
    local specID = 0
    if playerClass == "WARRIOR" then
        specID = (specIndex == 1) and 71 or ((specIndex == 2 and 72) or 73)
    elseif playerClass == "PALADIN" then
        specID = (specIndex == 1) and 65 or ((specIndex == 2 and 66) or 70)
    elseif playerClass == "HUNTER" then
        specID = (specIndex == 1) and 253 or ((specIndex == 2 and 254) or 255)
    elseif playerClass == "ROGUE" then
        specID = (specIndex == 1) and 259 or ((specIndex == 2 and 260) or 261)
    elseif playerClass == "PRIEST" then
        specID = (specIndex == 1) and 256 or ((specIndex == 2 and 257) or 258)
    elseif playerClass == "DEATHKNIGHT" then
        specID = (specIndex == 1) and 250 or ((specIndex == 2 and 251) or 252)
    elseif playerClass == "SHAMAN" then
        specID = (specIndex == 1) and 262 or ((specIndex == 2 and 263) or 264)
    elseif playerClass == "MAGE" then
        specID = (specIndex == 1) and 62 or ((specIndex == 2 and 63) or 64)
    elseif playerClass == "WARLOCK" then
        specID = (specIndex == 1) and 265 or ((specIndex == 2 and 266) or 267)
    elseif playerClass == "DRUID" then
        specID = (specIndex == 1) and 102 or ((specIndex == 2 and 103) or 105)
    end
    
    if isDebug then self:Print("Debug: Detected SpecID=" .. specID) end
    return specID
end

function WhackAMole:InitializeProfile(currentSpec)
    local _, playerClass = UnitClass("player")
    local candidates = ns.ProfileManager:GetProfilesForClass(playerClass)
    
    if #candidates == 0 then
        self:Print("未找到该职业的配�? " .. playerClass)
        return
    else
        -- Try to load last used
        local profile = nil
        local savedID = self.db.char.activeProfileID
        
        if savedID then
            local p = ns.ProfileManager:GetProfile(savedID)
            -- Only use saved profile if it matches current spec (or if detection failed)
            if p and (p.meta.spec == currentSpec or currentSpec == 0) then
                profile = p
            else
                 if p then
                     self:Print("专精变更，正在切换配�?(已保�? "..p.meta.spec..", 当前: "..currentSpec..")")
                 end
            end
        end
        
        -- Fallback: Auto-detect based on Spec
        if not profile then
            for _, cand in ipairs(candidates) do
                if cand.profile.meta.spec == currentSpec then
                    profile = cand.profile
                    self.db.char.activeProfileID = cand.id
                    break
                end
            end
            
            -- Fallback 2: First available
            if not profile then
                profile = candidates[1].profile
                self.db.char.activeProfileID = candidates[1].id
            end
            
            self:Print("自动选择配置: " .. profile.meta.name)
        else
             self:Print("正在加载配置: " .. profile.meta.name)
        end
        
        self.currentProfile = profile
        self:CreateGrid(self.currentProfile.layout)
        self:CompileScript(self.currentProfile.script)
    end
end

function WhackAMole:WaitForSpecAndLoad(retryCount)
    retryCount = retryCount or 0
    local isLastAttempt = (retryCount >= 10)
    
    -- Use debug mode on first and last attempt if needed
    local spec = self:GetPlayerSpec(isLastAttempt)
    
    if spec then
        -- Always print success so user knows what happened
        self:Print("接收到天赋数据。专精ID: " .. tostring(spec) .. " (尝试次数: " .. (retryCount + 1) .. ")")
        self:InitializeProfile(spec)
    else
        if retryCount < 10 then
            if retryCount == 0 then self:Print("正在等待天赋数据...") end
            C_Timer.After(1, function() self:WaitForSpecAndLoad(retryCount + 1) end)
        else
            self:Print("放弃等待天赋数据。加载默认配置�?)
            self:InitializeProfile(0)
        end
    end
end

function WhackAMole:OnInitialize()
    -- Check for AceDB
    if not LibStub("AceDB-3.0", true) then
        self:Print("Error: AceDB-3.0 library missing. Please restart WoW client if you just installed it.")
        return
    end

    self.db = LibStub("AceDB-3.0"):New("WhackAMoleDB", defaultDB)
    
    -- Initialize Profile Manager
    ns.ProfileManager:Initialize(self.db)
    
    -- Initialize Audio Engine
    if ns.Audio then ns.Audio:Initialize() end

    self:Print("WhackAMole 第二阶段 (实体按钮) 加载�?.. (版本: " .. date("%H:%M:%S") .. ")")
    
    -- Start Async Loading
    self:WaitForSpecAndLoad(0)
    
    -- Setup Config
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WhackAMole", function() return self:GetOptions() end)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhackAMole", "WhackAMole")
    
    -- Register chat command
    self:RegisterChatCommand("WhackAMole", "OnChatCommand")
    self:RegisterChatCommand("mole", "OnChatCommand")
    self:RegisterChatCommand("bis", "OnChatCommand")
end

function WhackAMole:OnChatCommand(input)
    -- Allow direct commands or open config
    if input == "lock" then
        self:SetLock(true)
    elseif input == "unlock" then
        self:SetLock(false)
    else
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    end
end

function WhackAMole:GetOptions()
    local _, playerClass = UnitClass("player")
    local profiles = ns.ProfileManager:GetProfilesForClass(playerClass) or {}
    
    local args = {}
    
    -- 1. Profile Selection & Documentation (Group)
    -- Instead of a sub-tree of profiles, we use a Dropdown select.
    -- This is safer and cleaner. Left side is "Documentation & Selection"
    
    args["profiles"] = {
        type = "group",
        name = "Profile Selection",
        order = 1,
        args = {
            select_header = {
                type = "header",
                name = "Choose Logic",
                order = 1
            },
            profile_select = {
                type = "select",
                name = "Active Profile",
                desc = "Select your specialization logic.",
                order = 2,
                width = "full",
                values = function()
                     local t = {}
                     for _, p in ipairs(profiles) do
                         t[p.id] = p.name
                     end
                     if next(t) == nil then t["none"] = "None" end
                     return t
                end,
                get = function() return self.db.char.activeProfileID end,
                set = function(_, val)
                    self.db.char.activeProfileID = val
                    local p = ns.ProfileManager:GetProfile(val)
                    if p then
                        self.currentProfile = p
                        self:CreateGrid(p.layout)
                        self:CompileScript(p.script)
                        -- Notify to refresh the documentation below
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    end
                end 
            },
            doc_header = {
                type = "header",
                name = "Manual & Tips",
                order = 10
            },
            -- Dynamic Documentation Area
            documentation = {
                type = "description",
                name = function()
                    local p = ns.ProfileManager:GetProfile(self.db.char.activeProfileID)       
                    if p then
                        local text = p.meta.docs or p.meta.desc or "No documentation."
                        text = text:gsub("|", "||") -- Escape pipes
                        return text
                    end
                    return "Select a profile to view documentation."
                end,
                fontSize = "medium",
                order = 11
            }
        }
    }
    
    -- 2. Settings (Group in Tree)
    args["settings"] = {
        type = "group",
        name = "Settings",
        order = 2,
        args = {
             header_ui = { type = "header", name = "Interface", order = 1 },
             lock = {
                 type = "toggle",
                 name = "Lock Frame",
                 desc = "Unlock to move the action bar.",
                 get = function() return self.locked end,
                 set = function(_, val) self:SetLock(val) end, 
                 width = "full",
                 order = 2
             },
             header_audio = { type = "header", name = "Audio", order = 10 },
             enable_audio = {
                 type = "toggle",
                 name = "Enable Sound Cues",
                 desc = "Play sounds for key abilities.",
                 get = function() return self.db.global.audio.enabled end,
                 set = function(_, val) self.db.global.audio.enabled = val end,
                 width = "full",
                 order = 11
             }
        }
    }
    
    -- 3. About
    args["about"] = {
        type = "group",
        name = "About",
        order = 3,
        args = {
            title = {
                type = "description",
                name = "|cff00ccffWhackAMole|r MVP",
                fontSize = "large",
                order = 1
            },
            version = {
                type = "description",
                name = "Version: 1.0 (Titan-Forged Edition)\n\nDesigned for WotLK 3.3.5a.",    
                fontSize = "medium",
                order = 2
            }
        }
    }

    return {
        name = "WhackAMole Options",
        handler = self,
        type = "group",
        childGroups = "tree", -- Root is a Tree (List on left)
        args = args
    }
end

function WhackAMole:CheckProfileSpec()
    local _, playerClass = UnitClass("player")
    local currentSpec = self:GetPlayerSpec()
    
    -- Debug
    -- self:Print("CheckProfileSpec: CurrentSpec=" .. currentSpec .. " ActiveProfile=" .. (self.currentProfile and self.currentProfile.meta.name or "None"))
    
    -- If we failed to get spec earlier or just want to be sure
    -- Logic similar to OnInit but we can be more aggressive
    
    -- If current active profile mismatches spec, force switch
    if self.currentProfile then
        if self.currentProfile.meta.spec ~= currentSpec and currentSpec and currentSpec ~= 0 then
             self:Print("检测到专精变更: " .. tostring(self.currentProfile.meta.spec) .. " -> " .. tostring(currentSpec))
             -- Trigger auto-selection
             local candidates = ns.ProfileManager:GetProfilesForClass(playerClass)
             local found = nil
             for _, cand in ipairs(candidates) do
                if cand.profile.meta.spec == currentSpec then
                    found = cand
                    break
                end
            end
            
            if found then
                self.currentProfile = found.profile
                self.db.char.activeProfileID = found.id
                self:CreateGrid(self.currentProfile.layout)
                self:CompileScript(self.currentProfile.script)
                self:Print("已切换到配置: " .. self.currentProfile.meta.name)
            else
                self:Print("未找到匹配专精ID的配�? " .. currentSpec)
            end
        end
    end
end

function WhackAMole:OnEnable()
    -- Re-check Spec and Reload Profile if needed
    self:CheckProfileSpec()
    
    -- Register events to catch late talent loading
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "CheckProfileSpec")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckProfileSpec")
    
    -- Delayed check for robustness
    if C_Timer then
        C_Timer.After(2, function() self:CheckProfileSpec() end)
    end

    self.driver = CreateFrame("Frame", nil, UIParent)
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)
    self.timeSinceLastUpdate = 0
    
    -- Restore assignments
    for i, btn in ipairs(self.slots) do
        local savedSpell = self.db.char.assignments[i]
        if savedSpell then
            self:UpdateButtonSpell(btn, savedSpell)
        end
    end
end

-- =========================================================================
-- Button Creation
-- =========================================================================

function WhackAMole:CreateGrid(layout)
    if self.container then self.container:Hide() end

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

    local w = cols * (CONFIG.iconSize + CONFIG.spacing)
    local h = rows * (CONFIG.iconSize + CONFIG.spacing)
    
    local container = CreateFrame("Frame", "WhackAMoleGrid", UIParent)
    self.container = container
    container:SetSize(w, h)
    
    -- Restore Position
    local pos = self.db.char.position
    if pos and pos.point then
        container:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        container:SetPoint("CENTER", 0, -220)
    end
    
    -- Dragging
    container:SetMovable(true)
    container:EnableMouse(true)
    -- We will drag via the handle primarily
    
    -- Background for drag (Container BG - usually hidden when locked)
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    self.bg = bg

    -- Drag Handle (The "Tab")
    local handle = CreateFrame("Button", "WhackAMoleDragHandle", container)
    -- Initial props (will be overridden by SetLock)
    handle:SetHeight(18)
    handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    local handleTex = handle:CreateTexture(nil, "ARTWORK")
    handleTex:SetAllPoints()
    handle.tex = handleTex
    
    local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    handleText:SetPoint("CENTER")
    handle.text = handleText
    
    -- Handle Scripts
    handle:SetScript("OnMouseDown", function(f, button)
        if button == "LeftButton" and not self.locked then
            container:StartMoving()
        end
    end)
    handle:SetScript("OnMouseUp", function(f, button)
        if button == "LeftButton" then
             if not self.locked then
                container:StopMovingOrSizing()
                -- Save Position
                local point, _, relPoint, x, y = container:GetPoint()
                self.db.char.position = { point = point, relativePoint = relPoint, x = x, y = y }
             end
        elseif button == "RightButton" then
             -- Context Menu
             self:OpenContextMenu(f)
        end
    end)
    self.handle = handle
    
    -- Start locked by default
    self:SetLock(true)

    self.slots = {}
    
    -- Slot Creation Loop
    
    for i, slotDef in pairs(layout.slots) do
        -- Only process integer indexed slots
        if type(i) == "number" then
            -- Create SECURE ACTION BUTTON
            local btnName = "WhackAMoleBtn"..i
            local btn = CreateFrame("Button", btnName, container, "SecureActionButtonTemplate, ActionButtonTemplate")
            btn:SetSize(CONFIG.iconSize, CONFIG.iconSize)
            
            -- Simple Grid Layouting
            -- (i-1) % cols = x index (0-based)
            -- floor((i-1) / cols) = y index (0-based)
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            
            local x = col * (CONFIG.iconSize + CONFIG.spacing) + (CONFIG.spacing/2)
            local y = -(row * (CONFIG.iconSize + CONFIG.spacing) + (CONFIG.spacing/2))
            
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            
            -- Normal Texture (Icon) comes from template: _G[btnName.."Icon"]
            -- We want a "Ghost" texture behind it to show what SHOULD be here
            local ghost = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
            ghost:SetAllPoints()
            local _, _, hintIcon = GetSpellInfo(slotDef.id)
            ghost:SetTexture(hintIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            ghost:SetDesaturated(true)
            ghost:SetVertexColor(1, 1, 1, 0.4)
            btn.ghost = ghost
            
            -- Store Color
            btn.color = slotDef.color
            btn.slotId = i
            
            -- Handle Drag & Drop (Pseudo)
            -- Secure buttons are tricky with drag. 
            -- We interpret 'OnReceiveDrag' as "User wants to bind this spell".
            -- Note: in combat we CANNOT SetAttribute.
            btn:SetScript("OnReceiveDrag", function(self)
                local type, id, subType = GetCursorInfo()
                if type == "spell" then
                    -- 'id' is Index in WotLK, we want Name or ID. 
                    -- GetSpellInfo(id, subType) returns Name as 1st arg.
                    local name = GetSpellInfo(id, subType)
                    if name then
                        WhackAMole:UpdateButtonSpell(self, name)
                    end
                    ClearCursor()
                elseif type == "item" then
                    -- Support items? MVP maybe later
                end
            end)

            -- Allow dragging OFF to remove
            btn:RegisterForDrag("LeftButton")
            btn:SetScript("OnDragStart", function(self)
                if InCombatLockdown() or WhackAMole.locked then return end
                
                local assigned = WhackAMole.db.char.assignments[self.slotId]
                if assigned then
                    -- Pickup current spell (put on cursor)
                    PickupSpell(assigned)
                    
                    -- Clear logic
                    WhackAMole.db.char.assignments[self.slotId] = nil
                    
                    self:SetAttribute("type", nil)
                    self:SetAttribute("spell", nil)
                    
                    local icon = _G[self:GetName().."Icon"]
                    if icon then icon:SetTexture(nil) end
                end
            end)
            
            -- Click support setup done by Template automatically
            
            self.slots[i] = btn
        end
    end

    -- Restore Assignments immediately after creation
    -- This fixes the issue where Async Loading creates the grid AFTER OnEnable restored nothing
    for i, btn in pairs(self.slots) do
        local savedSpell = self.db.char.assignments[i]
        if savedSpell then
            self:UpdateButtonSpell(btn, savedSpell)
        end
    end
end

function WhackAMole:UpdateButtonSpell(btn, spellIdOrName)
    if InCombatLockdown() then
        self:Print("Cannot change spells in combat!")
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
    self.db.char.assignments[btn.slotId] = name
end

function WhackAMole:SetLock(locked)
    self.locked = locked
    if locked then
        self.bg:Hide()
        self.container:EnableMouse(false)
        
        -- Locked Style: Small unobtrusive button
        self.handle:ClearAllPoints()
        self.handle:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 0, 0)
        self.handle:SetSize(20, 20) -- Small square
        
        self.handle.text:SetText("") -- No text
        self.handle.tex:SetColorTexture(0.3, 0.3, 0.3, 0.3) -- Faint Drag Handle
        
        -- Hover effect to find it easily
        self.handle:SetAlpha(0.2)
        self.handle:SetScript("OnEnter", function(f) f:SetAlpha(1.0) end)
        self.handle:SetScript("OnLeave", function(f) f:SetAlpha(0.2) end)
    else
        self.bg:Show()
        self.container:EnableMouse(true)
        
        -- Unlocked Style: Full Bar
        self.handle:ClearAllPoints()
        self.handle:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 0, 0)
        self.handle:SetPoint("BOTTOMRIGHT", self.container, "TOPRIGHT", 0, 0)
        self.handle:SetHeight(18)
        
        self.handle.text:SetText("WhackAMole")
        self.handle.tex:SetColorTexture(0.1, 0.1, 0.1, 0.9) -- Solid Header
        
        -- Reset Alpha & Scripts
        self.handle:SetAlpha(1.0)
        self.handle:SetScript("OnEnter", nil)
        self.handle:SetScript("OnLeave", nil)
    end
end

function WhackAMole:ClearAllAssignments()
    if InCombatLockdown() then 
        self:Print("Cannot clear spells in combat!")
        return 
    end
    
    table.wipe(self.db.char.assignments)
    
    if self.slots then
        for i, btn in pairs(self.slots) do
            btn:SetAttribute("type", nil) -- Removes click action
            btn:SetAttribute("spell", nil)
            
            local icon = _G[btn:GetName().."Icon"]
            if icon then icon:SetTexture(nil) end
        end
    end
    self:Print("Action Bar Cleared.")
end

function WhackAMole:OpenContextMenu(anchor)
    local menu = {
        { text = "WhackAMole Options", isTitle = true, notCheckable = true },
        { 
            text = self.locked and "Unlock Frame" or "Lock Frame",
            func = function() 
                self:SetLock(not self.locked) 
                LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
            end,
            notCheckable = true
        },
        {
            text = "Clear Action Bar",
            func = function() self:ClearAllAssignments() end,
            notCheckable = true
        },
        { 
            text = "Configure ...",
            func = function() LibStub("AceConfigDialog-3.0"):Open("WhackAMole") end,
            notCheckable = true
        },
        { text = "Cancel", notCheckable = true, func = function() end }
    }
    
    local menuFrame = _G.WhackAMoleContextMenu
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "WhackAMoleContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    
    -- EasyMenu replacement (since global EasyMenu might be missing/tainted)
    -- We define a local initializer that adds our button defs
    local function InitMenu(frame, level, menuList)
        for _, item in ipairs(menu) do
            UIDropDownMenu_AddButton(item, level)
        end
    end

    UIDropDownMenu_Initialize(menuFrame, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, anchor, 0, 0)
end

-- =========================================================================
-- Logic Engine
-- =========================================================================

function WhackAMole:CompileScript(scriptBody)
    local fullScript = "local env = ...; " .. scriptBody
    local func, err = loadstring(fullScript)
    if not func then
        self:Print("脚本编译错误: " .. err)
    else
        self.logicFunc = func
        self:Print("逻辑脚本编译成功�?)
    end
end

function WhackAMole:OnUpdate(elapsed)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
    if self.timeSinceLastUpdate < CONFIG.updateInterval then return end
    self.timeSinceLastUpdate = 0

    if not self.logicFunc then return end
    
    -- 1. Snapshot Current State (NOW)
    ns.State.reset()
    
    -- 2. Run Logic for NOW
    local status, activeSlot = pcall(self.logicFunc, ns.State)
    if not status then activeSlot = nil end
    
    -- 3. Check for Prediction (Time Travel)
    local nextSlot = nil
    
    -- Check Casting or Channeling
    local name, _, _, _, endTime = UnitCastingInfo("player")
    if not name then
        name, _, _, _, endTime = UnitChannelInfo("player")
    end
    
    if name and endTime then
        -- WoW APIs return time in MS usually, but GetTime() is seconds. 
        -- UnitCastingInfo endTime is MS from GetTime()*1000 approximately? 
        -- Actually UnitCastingInfo returns MS based system time.
        -- Usage: remains = (endTime / 1000) - GetTime()
        local now = GetTime()
        local finish = endTime / 1000
        local delta = finish - now
        
        -- Only predict if cast is significant (>0.2s remains)
        -- If it's about to end, the "Now" logic will catch up soon.
        if delta > 0.1 then
            -- Time Travel! Advance state to the future
            ns.State.advance(delta)
            
            local status2, result2 = pcall(self.logicFunc, ns.State)
            if status2 and result2 ~= activeSlot then
                nextSlot = result2
            end
        end
    end

    -- Audio Feedback Logic
    -- Priority: Prediction (Next) > Current (Active)
    local soundSlot = nextSlot or activeSlot
    if soundSlot and self.currentProfile and self.currentProfile.layout.slots[soundSlot] then
        local slotDef = self.currentProfile.layout.slots[soundSlot]
        if slotDef.id then
             ns.Audio:Play(slotDef.id)
        end
    end
    
    -- 4. Update UI
    for i, btn in pairs(self.slots) do
        
        local spellName = btn:GetAttribute("spell")
        
        -- CD Feedback (Cooldown Spinner)
        if spellName then
            local cooldown = _G[btn:GetName().."Cooldown"]
            if cooldown then
                local start, duration = GetSpellCooldown(spellName)
                if start and duration then
                    -- Optimize: Only update if changed? SetCooldown handles it reasonably well usually.
                    -- But let's simple call it.
                    cooldown:SetCooldown(start, duration)
                end
            end
        end

        -- Manual Desaturation for Unusable Spells
        if spellName then
            local icon = _G[btn:GetName().."Icon"]
            if icon then
                local isUsable, noMana = IsUsableSpell(spellName)
                if not isUsable and not noMana then
                    -- Unusable (Gray)
                    icon:SetVertexColor(0.3, 0.3, 0.3)
                elseif noMana then
                    -- No Mana (Blueish)
                    icon:SetVertexColor(0.5, 0.5, 1.0)
                else
                    -- Usable (White)
                    icon:SetVertexColor(1, 1, 1)
                end
            end
        end

        -- Check if we need to change state to avoid flicker
        -- (LCG handles duplication well, but explicit is better)
        
        if i == activeSlot then
            LCG.AutoCastGlow_Stop(btn) -- Priority to PixelGlow
            
            -- Primary: Use Fixed Gold Color for all active spells
            local c = {1, 0.8, 0, 1} 
            
            LCG.PixelGlow_Start(btn, c, nil, -0.25, nil, 3)
            
        elseif i == nextSlot then
            LCG.PixelGlow_Stop(btn)
            
            -- Prediction: Cyan AutoCast
            LCG.AutoCastGlow_Start(btn, {0, 1, 1, 1}, 4, 0.25, 1, 0, 0)
            
        else
            LCG.PixelGlow_Stop(btn)
            LCG.AutoCastGlow_Stop(btn)
        end
    end
end
