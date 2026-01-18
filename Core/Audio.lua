local addonName, ns = ...
local Audio = {}
ns.Audio = Audio

local throttle = {}
local THROTTLE_TIME = 2.0 -- Seconds to prevent spamming the same alert

function Audio:Play(spellID)
    -- 1. Check Master Switch
    local db = ns.WhackAMole and ns.WhackAMole.db
    if not db then return end
    
    if not db.global.audio or not db.global.audio.enabled then
        return
    end

    -- 2. Check if we have a sound for this spell in the new unified Constants
    -- Support both new structure (ns.Spells) and raw filename mapping (legacy support if strictly needed, but we aim for Constants)
    
    local soundFile = nil
    
    if ns.Spells and ns.Spells[spellID] and ns.Spells[spellID].sound then
        soundFile = ns.Spells[spellID].sound
    end
    
    -- Fallback/Legacy support if needed, but we're moving away from SoundPack global
    -- if not soundFile and ns.SoundPack then soundFile = ns.SoundPack[spellID] end

    if not soundFile then return end

    -- 3. Check Throttle
    local now = GetTime()
    if throttle[spellID] and (now - throttle[spellID] < THROTTLE_TIME) then
        return
    end
    
    -- 4. Play Sound
    -- Path format: Interface\AddOns\WhackAMole\Sounds\Execute.ogg
    local path = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\" .. soundFile
    PlaySoundFile(path, "Master")
    
    -- 5. Update State
    throttle[spellID] = now
    
    -- Debug
    -- print("WhackAMole Audio: Playing " .. soundFile)
end

function Audio:Initialize()
    -- No-op for now, DB handled by Core
end
