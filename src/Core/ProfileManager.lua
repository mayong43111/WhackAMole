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
    
    -- 自动添加 type = "builtin" 字段
    profile.meta.type = "builtin"
    
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
-- 优先级：用户配置（type="user"）> 内置配置（type="builtin"）
function ns.ProfileManager:GetProfilesForClass(class, specId)
    local list = {}
    
    -- 1. 先遍历用户配置（优先级更高）
    for id, p in pairs(self.db.global.profiles) do
        if p.meta.class == class and p.meta.type == "user" then
            table.insert(list, {
                id = id,
                name = "[User] " .. p.meta.name,
                profile = p,
                type = "user"
            })
        end
    end
    
    -- 2. 回退到内置配置
    for id, p in pairs(self.builtIn) do
        if p.meta.class == class and p.meta.type == "builtin" then
            -- Optional: Check spec if strictly required
            table.insert(list, {
                id = id,
                name = "[Built-in] " .. p.meta.name,
                profile = p,
                type = "builtin"
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

-- Fetch a profile by name (searches both builtin and user profiles)
function ns.ProfileManager:GetProfileByName(name)
    if not name then return nil end
    
    -- Search in builtin profiles
    for id, profile in pairs(self.builtIn) do
        if profile.meta and profile.meta.name == name then
            return profile, id
        end
    end
    
    -- Search in user profiles
    for id, profile in pairs(self.db.global.profiles) do
        if profile.meta and profile.meta.name == name then
            return profile, id
        end
    end
    
    return nil, nil
end

-- API to Import (User Profile)
function ns.ProfileManager:SaveUserProfile(profile)
    -- 自动标记为用户配置
    if not profile.meta then
        profile.meta = {}
    end
    profile.meta.type = "user"
    
    -- 强制添加 [USER] 前缀（如果没有）
    if profile.meta.name and not profile.meta.name:match("^%[USER%]") then
        profile.meta.name = "[USER] " .. profile.meta.name
    end
    
    -- 检查是否已存在同名配置
    local existingProfile, existingID = self:GetProfileByName(profile.meta.name)
    if existingProfile and existingID then
        -- 覆盖已有配置
        self.db.global.profiles[existingID] = profile
        return existingID
    else
        -- 创建新配置
        local id = "USER:" .. profile.meta.name .. ":" .. time()
        self.db.global.profiles[id] = profile
        return id
    end
end
