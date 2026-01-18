local addonName, ns = ...
local Audio = {}
ns.Audio = Audio

-- Default Sound Pack Mapping (WotLK Warrior)
-- Note: GladiatorlosSA packs primarily contain Cooldowns, not Rotation spells.
local SoundPack = ns.SoundPack or {}

local throttle = {}
local THROTTLE_TIME = 2.0 -- Seconds to prevent spamming the same alert
local lastPlayedSpell = 0

function Audio:Play(spellID)
    -- 1. Check Master Switch
    -- Access AceDB via the Addon object (Runtime only)
    local db = ns.Luminary and ns.Luminary.db
    if not db then return end
    
    if not db.global.audio or not db.global.audio.enabled then
        return
    end

    -- 2. Check if we have a sound for this spell
    local soundFile = SoundPack[spellID]
    if not soundFile then return end

    -- 3. Check Throttle
    local now = GetTime()
    if throttle[spellID] and (now - throttle[spellID] < THROTTLE_TIME) then
        return
    end
    
    -- 4. Play Sound
    -- Path format: Interface\AddOns\Luminary\Sounds\Execute.ogg
    local path = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\" .. soundFile
    PlaySoundFile(path, "Master")
    
    -- 5. Update State
    throttle[spellID] = now
    lastPlayedSpell = spellID
    
    -- Debug
    -- print("Luminary Audio: Playing " .. soundFile)
end

function Audio:Initialize()
    -- No-op for now, DB handled by Core
end
