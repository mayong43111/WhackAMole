local addon, ns = ...

-- Core/ProfileManager.lua
-- Manages both Built-in presets (read-only) and User profiles (DB).

ns.ProfileManager = {
    builtIn = {}, -- { [id] = profileTable }
    db = nil      -- Reference to AceDB (set in Initialize)
}

-- Called by Presets/*.lua files to register themselves
function ns.ProfileManager:RegisterPreset(profile)
    -- Generate a stable ID for the preset, e.g., "PRESET:Name"
    -- We assume profile.meta exists and is valid.
    if not profile or not profile.meta then return end
    
    local id = "PRESET:" .. profile.meta.name
    self.builtIn[id] = profile
    
    -- Indexing for lookup (could add class/spec indices here)
end

function ns.ProfileManager:Initialize(db)
    self.db = db
    
    -- Ensure DB structure exists
    if not self.db.global.profiles then
        self.db.global.profiles = {}
    end
end

-- Returns a list of profiles suitable for the current class
function ns.ProfileManager:GetProfilesForClass(class, specId)
    local list = {}
    
    -- 1. Built-in
    for id, p in pairs(self.builtIn) do
        if p.meta.class == class then
            -- Optional: Check spec if strictly required
            table.insert(list, {
                id = id,
                name = "[Built-in] " .. p.meta.name,
                profile = p
            })
        end
    end
    
    -- 2. User DB
    -- keys in db.global.profiles are UUIDs or Names
    for id, p in pairs(self.db.global.profiles) do
        if p.meta.class == class then
            table.insert(list, {
                id = id,
                name = p.meta.name,
                profile = p
            })
        end
    end
    
    return list
end

-- Fetch a specific profile by ID
function ns.ProfileManager:GetProfile(id)
    if not id then return nil end
    
    if self.builtIn[id] then
        return self.builtIn[id]
    end
    
    if self.db.global.profiles[id] then
        return self.db.global.profiles[id]
    end
    
    return nil
end

-- API to Import (User Profile)
function ns.ProfileManager:SaveUserProfile(profile)
    local id = "USER:" .. profile.meta.name .. ":" .. os.time()
    self.db.global.profiles[id] = profile
    return id
end
