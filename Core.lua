local addonName, ns = ...
local WhackAMole = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

_G.WhackAMole = WhackAMole
ns.WhackAMole = WhackAMole

-- Constants
local CONFIG = {
    updateInterval = 0.05
}

-- Runtime State
WhackAMole.currentProfile = nil
WhackAMole.logicFunc = nil

-- Default Saved Variables
local defaultDB = {
    global = {
        audio = { enabled = false },
        profiles = {} -- User Profiles
    },
    char = {
        assignments = {}, -- [slotId] = spellID
        position = { point = "CENTER", x = 0, y = -220 },
        activeProfileID = nil
    }
}

-- =========================================================================
-- Lifecycle
-- =========================================================================

function WhackAMole:OnInitialize()
    -- Check for Dependencies
    if not LibStub("AceDB-3.0", true) then
        self:Print("Error: AceDB-3.0 library missing.")
        return
    end

    -- 1. Initialize DB
    self.db = LibStub("AceDB-3.0"):New("WhackAMoleDB", defaultDB)
    
    -- 2. Initialize Modules
    ns.ProfileManager:Initialize(self.db)
    ns.UI.Grid:Initialize(self.db.char)
    if ns.Audio then ns.Audio:Initialize() end

    self:Print("WhackAMole v1.1 (Refactored) Loaded. " .. date("%H:%M"))
    
    -- 3. Register Config & Commands
    -- Note: UI.GetOptionsTable requires 'self' (WhackAMole) to access runtime state
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WhackAMole", function() 
        return ns.UI.GetOptionsTable(self) 
    end)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhackAMole", "WhackAMole")
    
    self:RegisterChatCommand("wam", "OnChatCommand")
    
    -- 4. Start Loading Process
    self:WaitForSpecAndLoad(0)
end

function WhackAMole:OnChatCommand(input)
    if input == "lock" then
        ns.UI.Grid:SetLock(true)
    elseif input == "unlock" then
        ns.UI.Grid:SetLock(false)
    elseif input == "log start" then
        if ns.Logger then ns.Logger:Start() end
    elseif input == "log stop" then
        if ns.Logger then ns.Logger:Stop() end
    elseif input == "log show" then
        if ns.Logger then ns.Logger:Show() end
    else
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    end
end

-- =========================================================================
-- Profile & Loading Logic
-- =========================================================================

function WhackAMole:WaitForSpecAndLoad(retryCount)
    retryCount = retryCount or 0
    local isLastAttempt = (retryCount >= 10)
    
    -- Use new encapsulated SpecDetection
    local spec = ns.SpecDetection:GetSpecID(isLastAttempt)
    
    if spec then
        self:Print("Detected SpecID: " .. tostring(spec))
        self:InitializeProfile(spec)
    else
        if retryCount < 10 then
            C_Timer.After(1, function() self:WaitForSpecAndLoad(retryCount + 1) end)
        else
            self:Print("Timeout waiting for talent data. Loading generic profile if available.")
            self:InitializeProfile(0)
        end
    end
end

function WhackAMole:InitializeProfile(currentSpec)
    local _, playerClass = UnitClass("player")
    local candidates = ns.ProfileManager:GetProfilesForClass(playerClass)
    
    if #candidates == 0 then
        self:Print("No profiles found for class: " .. playerClass)
        return
    end

    -- Try to load last selected profile or auto-detect
    local profile = nil
    local savedID = self.db.char.activeProfileID
    
    if savedID then
        local p = ns.ProfileManager:GetProfile(savedID)
        -- Validate spec match (nil spec means "universal")
        if p and (p.meta.spec == nil or p.meta.spec == currentSpec or currentSpec == 0) then
            profile = p
        else
             local oldSpec = p and p.meta.spec or "nil"
             if p then self:Print("Spec changed ("..oldSpec.."->"..currentSpec.."). Switching profile.") end
        end
    end
    
    -- Auto-detect if no valid saved profile
    if not profile then
        for _, cand in ipairs(candidates) do
            if cand.profile.meta.spec == currentSpec then
                profile = cand.profile
                self.db.char.activeProfileID = cand.id
                break
            end
        end
        -- Fallback to first available
        if not profile then
            profile = candidates[1].profile
            self.db.char.activeProfileID = candidates[1].id
        end
        self:Print("Auto-selected profile: " .. profile.meta.name)
    else
        self:Print("Loaded profile: " .. profile.meta.name)
    end
    
    self:SwitchProfile(profile)
end

function WhackAMole:SwitchProfile(profile)
    self.currentProfile = profile
    -- 1. Create/Resize Grid
    ns.UI.Grid:Create(profile.layout, CONFIG)
    
    -- 2. Compile APL
    if profile.apl then
        self:CompileAPL(profile.apl)
    elseif profile.script then
        -- Legacy Support
        self:CompileScript(profile.script)
    else
        self:Print("Error: No actionable logic (APL/Script) in profile.")
    end
    
    -- 3. Notify Config
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end

-- =========================================================================
-- Logic Engine (Interpreter)
-- =========================================================================

function WhackAMole:CompileAPL(aplLines)
    self.compilingAPL = true
    self.currentAPL = {}
    
    if not ns.SimCParser then
        self:Print("Error: SimCParser module not found!")
        return
    end

    for _, line in ipairs(aplLines) do
        local entry = ns.SimCParser.ParseActionLine(line)
        if entry then
            table.insert(self.currentAPL, entry)
        else
            -- self:Print("Warning: Failed to parse APL line: " .. line)
        end
    end
    
    self.logicFunc = nil -- clear legacy
    self:Print("APL Compiled. " .. #self.currentAPL .. " actions loaded.")
end

function WhackAMole:CompileScript(scriptBody)
    -- Build ID injection string from Constants
    local injection = ""
    if ns.Spells then
        for id, data in pairs(ns.Spells) do
            -- Inject: local S_Charge = 100
            -- Naming Convention: S_CamelCase
            if data and data.key then
                 -- Sanitize key to ensure valid variable name
                 local varName = "S_" .. data.key:gsub("[^%w]", "")
                 injection = injection .. string.format("local %s = %d;\n", varName, id)
            end
        end
    end

    local fullScript = "local env = ...; " .. injection .. scriptBody
    local func, err = loadstring(fullScript)
    if not func then
        self:Print("Script Compilation Error: " .. tostring(err))
        self.logicFunc = nil
    else
        self.logicFunc = func
        self.currentAPL = nil -- clear APL
        -- self:Print("Rotation logic compiled successfully.")
    end
end

-- =========================================================================
-- Main Event Loop
-- =========================================================================

function WhackAMole:OnUpdate(elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate < CONFIG.updateInterval then return end
    self.timeSinceLastUpdate = 0

    if (not self.logicFunc) and (not self.currentAPL) then return end
    
    -- 1. Snapshot State (Virtual Time Start)
    if ns.State.reset then ns.State.reset() end
    
    local activeAction = nil
    local activeSlot = nil

    -- 2. Run Logic
    if self.currentAPL then
        if ns.APLExecutor then
            activeAction = ns.APLExecutor.Process(self.currentAPL, ns.State)
        end
    elseif self.logicFunc then
         -- Legacy
        local status, result = pcall(self.logicFunc, ns.State)
        if status then activeSlot = result end
    end
    
    -- 3. Update Visuals
    -- Grid expects: (activeSlot, nextSlot, activeAction)
    if ns.UI.Grid then
        ns.UI.Grid:UpdateVisuals(activeSlot, nil, activeAction)
    end
    
    -- 4. Audio Feedback (Simple: Logic on Current only for now)
    if self.db.global.audio.enabled then
        -- Requires mapping Action Name -> ID if using APL
        local soundID = nil
        
        if activeAction and ns.ActionMap then
             soundID = ns.ActionMap[activeAction]
        elseif activeSlot and self.currentProfile and self.currentProfile.layout.slots[activeSlot] then
             soundID = self.currentProfile.layout.slots[activeSlot].id
        end

        if soundID then
            ns.Audio:Play(soundID)
        end
    end
end

-- Register OnUpdate on a dedicated frame? 
-- AcetAddon doesn't have native OnUpdate, usually we hook a frame.
-- But wait, Core.lua IS an AceAddon. We need a frame for OnUpdate.
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(f, elapsed) WhackAMole:OnUpdate(elapsed) end)
