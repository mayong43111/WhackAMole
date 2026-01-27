local addonName, ns = ...
local Audio = {}
ns.Audio = Audio

local throttle = {}
local lastCastTime = {}
local lastGlobalCastTime = 0 -- Track any spell cast
local lastPlayedAction = nil
local THROTTLE_TIME = 2.0 -- Default throttle for un-cast actions (nagging interval)
local PREDICT_WINDOW = 0.5 -- Allow prompting same action if cast is ending soon

-- Register Event listener for cast success to reset throttle
-- This ensures "Prompt -> Cast -> Prompt Again" flow works immediately
function Audio:OnSpellCastSucceeded(event, unit, _, spellID)
    if unit ~= "player" then return end
    
    lastGlobalCastTime = GetTime()

    -- Ensure ReverseMap exists
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
        lastCastTime[actionName] = GetTime()
        -- Reset throttle logic is now handled in PlayByAction by comparing lastCastTime vs throttle time
        -- We no longer mechanically set throttle to 0.
    end
end

function Audio:PlayByAction(actionName)
    if not actionName then return end
    
    -- Requirement 1: No audio if not in combat
    if not UnitAffectingCombat("player") then return end

    local db = ns.WhackAMole and ns.WhackAMole.db
    if not db or not db.global.audio or not db.global.audio.enabled then return end
    
    local volume = db.global.audio.volume or 1.0
    if volume <= 0 then return end
    
    local spellID = ns.ActionMap and ns.ActionMap[actionName]
    if not spellID then return end
    
    local soundFile = nil
    if ns.Spells and ns.Spells[spellID] and ns.Spells[spellID].sound then
        soundFile = ns.Spells[spellID].sound
    end
    
    if not soundFile then return end
    
    local now = GetTime()
    
    -- Smart Logic 1: Silence if currently casting THIS action (Requirement 3)
    -- Unless the cast is nearly finished (Requirement 4 support logic is mostly in UpdateLoop, but redundancy helps)
    local castName, _, _, _, _, castEnd, _, castID = UnitCastingInfo("player")
    if not castName then
         castName, _, _, _, _, castEnd, _, castID = UnitChannelInfo("player")
    end
    
    if castID and castID == spellID then
        -- Casting the suggested action
        local remaining = 0
        if castEnd then
            remaining = (castEnd / 1000) - now
        end
        
        -- If we are in the middle of casting, do NOT prompt the same spell.
        -- Only prompt if we are very close to finish (chaining)
        if remaining > PREDICT_WINDOW then
            return
        end
    end
    
    -- Smart Logic 2: Throttle Management
    
    -- Case A: New action (different from last played) -> Play Immediately
    if actionName ~= lastPlayedAction then
        self:DoPlay(soundFile, actionName, now)
        return
    end
    
    -- Case B: Same action (Requirement 2: Only prompt if cast again or cast ending)
    
    -- B1. Check for Cast Ending Exception
    local isCastEnding = false
    if castEnd then
         local remaining = (castEnd / 1000) - now
         if remaining > 0 and remaining <= PREDICT_WINDOW then
             isCastEnding = true
         end
    end

    local t_last_play = throttle[actionName] or 0

    -- If we are in the "Cast Ending" window (0.5s), allow re-prompting with a short throttle (0.4s)
    -- This handles the case where we are chaining the same spell
    if isCastEnding then
        if (now - t_last_play) > 0.4 then
            self:DoPlay(soundFile, actionName, now)
        end
        return
    end

    -- B2. Normal State: Check if we have cast this spell SINCE the last prompt
    -- If we haven't cast it since we last yelled at the user, stay silent.
    -- (Requirement: "Unless I have released it... can prompt again")
    -- Requirement 2 Update: Also allow prompt if we cast ANY other spell since last prompt
    local t_last_cast = lastCastTime[actionName] or 0
    
    if t_last_cast > t_last_play or lastGlobalCastTime > t_last_play then
        -- User has cast the spell (or any spell) since our last prompt -> Allow new prompt
        self:DoPlay(soundFile, actionName, now)
    else
        -- User has NOT cast the spell -> Suppress prompt (Infinite throttle)
        return 
    end
end

function Audio:DoPlay(soundFile, actionName, now)
    local path = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\" .. soundFile
    PlaySoundFile(path, "Master")
    
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
    
    -- 注意：不再在这里注册事件，通过 Core.lua 的 OnSpellCastSucceeded 回调
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
