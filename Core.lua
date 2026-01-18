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
        -- Validate spec match
        if p and (p.meta.spec == currentSpec or currentSpec == 0) then
            profile = p
        else
             if p then self:Print("Spec changed ("..p.meta.spec.."->"..currentSpec.."). Switching profile.") end
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
    -- 2. compile Script
    self:CompileScript(profile.script)
    -- 3. Notify Config
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end

-- =========================================================================
-- Logic Engine (Interpreter)
-- =========================================================================

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

    if not self.logicFunc then return end
    
    -- 1. Snapshot State (Virtual Time Start)
    ns.State.reset()
    
    -- 2. Run Logic (NOW)
    local status, activeSlot = pcall(self.logicFunc, ns.State)
    if not status then 
        -- In dev, maybe print error once? For MVP, fail silently to avoid spam
        activeSlot = nil 
    end
    
    -- 3. Prediction (Time Travel)
    local nextSlot = nil
    
    -- Check Casting
    local name, _, _, _, endTime = UnitCastingInfo("player")
    if not name then name, _, _, _, endTime = UnitChannelInfo("player") end
    
    if name and endTime then
        local now = GetTime()
        local finish = endTime / 1000
        local delta = finish - now
        
        if delta > 0.1 then
            ns.State.advance(delta) -- Travel forward
            local status2, result2 = pcall(self.logicFunc, ns.State)
            if status2 and result2 ~= activeSlot then
                nextSlot = result2
            end
        end
    end

    -- 4. Audio Feedback
    if self.db.global.audio.enabled then
        local soundSlot = nextSlot or activeSlot
        if soundSlot and self.currentProfile and self.currentProfile.layout.slots[soundSlot] then
            local slotDef = self.currentProfile.layout.slots[soundSlot]
            -- Use new Unified Constants if available, or raw ID
            if slotDef.id then
                ns.Audio:Play(slotDef.id)
            end
        end
    end
    
    -- 5. Visual Feedback
    -- Delegated to UI module
    ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot)
end

-- Register OnUpdate on a dedicated frame? 
-- AcetAddon doesn't have native OnUpdate, usually we hook a frame.
-- But wait, Core.lua IS an AceAddon. We need a frame for OnUpdate.
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(f, elapsed) WhackAMole:OnUpdate(elapsed) end)
