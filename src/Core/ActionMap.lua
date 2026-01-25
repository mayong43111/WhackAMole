-- Core/ActionMap.lua
-- Defines the mapping from SimC Action Names (slugs) to Wow Spell IDs
local _, ns = ...

-- Reverse Mapping table: action_name -> spell_id
-- e.g. ["execute"] = 5308
ns.ActionMap = {}

-- Utility to build the map from Constants
function ns.BuildActionMap()
    if not ns.Spells then return end
    
    local function addMapping(key, id)
        if not key then return end
        
        -- Basic Lowercase: "TemplarsVerdict" -> "templarsverdict"
        local lowerKey = string.lower(key)
        ns.ActionMap[lowerKey] = id
        
        -- Snake Case conversion: "TemplarsVerdict" -> "templars_verdict"
        -- Logic: Insert underscore before Uppercase letters, then lowercase everything.
        -- Handle leading underscore correctly.
        local snake = key:gsub("(%u)", "_%1")
        if snake:sub(1,1) == "_" then
            snake = snake:sub(2)
        end
        snake = snake:lower()
        
        if snake ~= lowerKey then
             ns.ActionMap[snake] = id
        end
    end

    for id, data in pairs(ns.Spells) do
        addMapping(data.key, id)
    end
    
    -- 解决技术债务：自动从职业模块加载 spells
    -- 整合职业模块定义的技能到全局 ActionMap
    if ns.Classes then
        for className, classData in pairs(ns.Classes) do
            for specID, specData in pairs(classData) do
                if type(specData) == "table" and specData.spells then
                    for id, data in pairs(specData.spells) do
                        addMapping(data.key, id)
                    end
                end
            end
        end
    end
end

-- Initialize immediately if constants loaded
ns.BuildActionMap()

-- Also expose IDs for direct access in State logic
if not ns.ID then ns.ID = {} end
for id, data in pairs(ns.Spells) do
    if data.key then ns.ID[data.key] = id end
end
