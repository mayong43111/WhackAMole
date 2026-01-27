-- Core/ActionMap.lua
-- Defines the mapping from SimC Action Names (slugs) to Wow Spell IDs
local _, ns = ...

-- Reverse Mapping table: action_name -> spell_id
-- e.g. ["execute"] = 5308
ns.ActionMap = {}

-- Forward mapping: spellID -> action_name（用于效果模拟）
ns.ActionMap.spellIDToAction = {}

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
        
        -- 添加反向映射：spellID -> snake_case_action
        ns.ActionMap.spellIDToAction[id] = snake
    end

    -- 从 Constants.lua 的 ns.Spells 构建 ActionMap
    for id, data in pairs(ns.Spells) do
        addMapping(data.key, id)
    end
end

-- Initialize immediately if constants loaded
ns.BuildActionMap()

-- Also expose IDs for direct access in State logic
if not ns.ID then ns.ID = {} end
for id, data in pairs(ns.Spells) do
    if data.key then ns.ID[data.key] = id end
end
