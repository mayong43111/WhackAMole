local addonName, ns = ...
local Audio = {}
ns.Audio = Audio

local throttle = {}
local THROTTLE_TIME = 2.0 -- Seconds to prevent spamming the same alert
local lastPlayedAction = nil -- Track last played action name for unified trigger logic

-- Play by Action Name (unified trigger logic)
function Audio:PlayByAction(actionName)
    if not actionName then return end
    
    -- 1. Check Master Switch
    local db = ns.WhackAMole and ns.WhackAMole.db
    if not db then return end
    
    if not db.global.audio or not db.global.audio.enabled then
        return
    end
    
    -- 2. Get volume setting (0.0 - 1.0)
    local volume = db.global.audio.volume or 1.0
    if volume <= 0 then return end
    
    -- 3. Resolve Action Name -> SpellID
    local spellID = ns.ActionMap and ns.ActionMap[actionName]
    if not spellID then return end
    
    -- 4. Get sound file
    local soundFile = nil
    if ns.Spells and ns.Spells[spellID] and ns.Spells[spellID].sound then
        soundFile = ns.Spells[spellID].sound
    end
    
    if not soundFile then return end
    
    -- 5. Check Throttle (prevent same action spamming)
    local now = GetTime()
    if throttle[actionName] and (now - throttle[actionName] < THROTTLE_TIME) then
        return
    end
    
    -- 6. Play Sound with volume control
    local path = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\" .. soundFile
    PlaySoundFile(path, "Master")
    
    -- Note: PlaySoundFile doesn't support volume in WotLK, 
    -- but we keep the setting for future compatibility
    
    -- 7. Update State
    throttle[actionName] = now
    lastPlayedAction = actionName
end

-- Legacy support: Play by SpellID directly
function Audio:Play(spellID)
    if not spellID then return end
    
    -- Find action name from reverse map
    if not ns.ReverseActionMap then
        ns.ReverseActionMap = {}
        if ns.ActionMap then
            for action, id in pairs(ns.ActionMap) do
                ns.ReverseActionMap[id] = action
            end
        end
    end
    
    local actionName = ns.ReverseActionMap[spellID]
    if actionName then
        self:PlayByAction(actionName)
    end
end

function Audio:Initialize()
    -- Ensure volume setting exists
    local db = ns.WhackAMole and ns.WhackAMole.db
    if db and db.global and db.global.audio then
        db.global.audio.volume = db.global.audio.volume or 1.0
    end
end

-- Get last played action (for debugging)
function Audio:GetLastPlayed()
    return lastPlayedAction
end

-- Clear throttle for specific action (manual reset)
function Audio:ClearThrottle(actionName)
    if actionName then
        throttle[actionName] = nil
    else
        throttle = {}
    end
end
