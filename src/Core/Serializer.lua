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
    
    return profileTable
end
