local addonName, ns = ...
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")

ns.Serializer = {}

-- Config Header (similar to WA)
local HEADER_V1 = "Luminary:v1:"

-- Compresses a table into a string
function ns.Serializer:ExportProfile(profileTable)
    if not profileTable then return nil end
    
    -- 1. Serialize to string (AceSerializer)
    local serialized = AceSerializer:Serialize(profileTable)
    if not serialized then return nil end
    
    -- 2. Compress (LibDeflate)
    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then return nil end
    
    -- 3. Encode (LibDeflate - ForWoW)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then return nil end
    
    return HEADER_V1 .. encoded
end

-- Decompresses a string into a table
function ns.Serializer:ImportProfile(inputString)
    if not inputString or type(inputString) ~= "string" then return nil, "Invalid input" end
    
    inputString = inputString:trim()
    
    -- Check Header
    local dataStr
    if inputString:find("^" .. HEADER_V1) then
        dataStr = inputString:sub(#HEADER_V1 + 1)
    else
        return nil, "Invalid Luminary string header (Must start with 'Luminary:v1:')"
    end
    
    -- 1. Decode
    local compressed = LibDeflate:DecodeForPrint(dataStr)
    if not compressed then return nil, "Decoding failed" end
    
    -- 2. Decompress
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil, "Decompression failed" end
    
    -- 3. Deserialize
    local success, profileTable = AceSerializer:Deserialize(serialized)
    if not success then return nil, "Deserialization failed" end
    
    -- 4. 自动标记为用户配置
    if profileTable and profileTable.meta then
        profileTable.meta.type = "user"
    end
    
    return profileTable
end

-- 校验配置结构完整性
function ns.Serializer:Validate(profile)
    if not profile then
        return false, "Profile is nil"
    end
    
    -- 检查 meta 结构
    if not profile.meta then
        return false, "Missing meta table"
    end
    
    if not profile.meta.name or profile.meta.name == "" then
        return false, "Missing profile name"
    end
    
    if not profile.meta.class or profile.meta.class == "" then
        return false, "Missing class"
    end
    
    -- 职业匹配检查
    local playerClass = select(2, UnitClass("player"))
    if profile.meta.class ~= playerClass then
        return false, "Class mismatch: profile is for " .. profile.meta.class .. ", but you are " .. playerClass
    end
    
    -- 专精匹配（可选警告）
    if profile.meta.spec_id then
        local currentSpec = ns.SpecDetection:GetSpecID()
        if currentSpec and profile.meta.spec_id ~= currentSpec then
            -- 这是警告，不阻止导入
            ns.Logger:Warn("Serializer", "Spec mismatch: profile is for spec " .. profile.meta.spec_id .. ", current spec is " .. currentSpec)
        end
    end
    
    -- 版本检查
    if profile.meta.version and profile.meta.version > 2 then
        return false, "Profile version too high: " .. profile.meta.version .. " (max supported: 2)"
    end
    
    -- 检查必要字段
    if not profile.apl or type(profile.apl) ~= "table" then
        return false, "Missing or invalid APL table"
    end
    
    if not profile.layout or type(profile.layout) ~= "table" then
        return false, "Missing or invalid layout table"
    end
    
    return true, "Validation passed"
end
