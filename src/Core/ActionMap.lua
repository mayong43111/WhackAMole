-- Core/ActionMap.lua
-- Defines the mapping from SimC Action Names (slugs) to Wow Spell IDs
local _, ns = ...

-- Reverse Mapping table: action_name -> spell_id
-- e.g. ["execute"] = 5308
ns.ActionMap = {}

-- Utility to build the map from Constants
function ns.BuildActionMap()
    if not ns.Spells then return end
    
    for id, data in pairs(ns.Spells) do
        if data.key then
            -- Convert "Execute" -> "execute" (SimC is lowercase)
            -- Convert "MortalStrike" -> "mortal_strike" (CamelCase to snake_case?)
            -- Usually SimC uses snake_case.
            
            -- Basic Lowercase
            local lowerKey = string.lower(data.key)
            ns.ActionMap[lowerKey] = id
            
            -- Snake Case conversion? 
            -- If key is "MortalStrike", SimC uses "mortal_strike".
            -- Simple regex to insert underscore before Caps?
            local snake = data.key:gsub("(%u)", "_%1"):sub(2):lower()
            if snake ~= lowerKey then
                ns.ActionMap[snake] = id
            end
        end
    end
    
    -- 解决技术债务：自动从职业模块加载 spells
    -- 整合职业模块定义的技能到全局 ActionMap
    if ns.Classes then
        for className, classData in pairs(ns.Classes) do
            for specID, specData in pairs(classData) do
                if type(specData) == "table" and specData.spells then
                    for id, data in pairs(specData.spells) do
                        if data.key and not ns.ActionMap[string.lower(data.key)] then
                            local lowerKey = string.lower(data.key)
                            ns.ActionMap[lowerKey] = id
                            
                            local snake = data.key:gsub("(%u)", "_%1"):sub(2):lower()
                            if snake ~= lowerKey then
                                ns.ActionMap[snake] = id
                            end
                        end
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
