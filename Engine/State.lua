local addon, ns = ...
local WhackAMole = _G[addon]

local state = {}
ns.State = state

-- Cache tables
local buff_cache = {}
local debuff_cache = {}

-- Helper to create a dummy "down" state
local aura_down = { up = false, count = 0, remains = 0, duration = 0 }

-- =========================================================================
-- Buff / Debuff Metatables
-- =========================================================================

local function FindAura(cache, id)
    -- 1. Try exact ID match
    if cache[id] then return cache[id] end
    
    -- 2. Try Name match (Handles Ranks)
    if type(id) == "number" then
        local name = GetSpellInfo(id)
        if name and cache[name] then
            return cache[name]
        end
    elseif type(id) == "string" and cache[id] then
        return cache[id]
    end
    
    return aura_down
end

local mt_buff = {
    __call = function(t, id)
        local aura = FindAura(buff_cache, id)
        -- Virtualize 'remains' based on state.now
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then -- Permanent
                return aura
            end
            
            local remains = math.max(0, expires - state.now)
            if remains == 0 then return aura_down end -- Expired in future
            
            -- Return a lightweight copy with updated remains
            -- (Optimization: could use a shared temp table to avoid GC churn)
            return {
                up = true,
                count = aura.count,
                remains = remains,
                duration = aura.duration
            }
        end
        return aura
    end
}

local mt_debuff = {
    __call = function(t, id)
        local aura = FindAura(debuff_cache, id)
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then return aura end
            
            local remains = math.max(0, expires - state.now)
            if remains == 0 then return aura_down end
            
            return {
                up = true,
                count = aura.count,
                remains = remains,
                duration = aura.duration
            }
        end
        return aura
    end
}

-- =========================================================================
-- Spell Metatable
-- =========================================================================

local mt_spell = {
    __call = function(t, id)
        -- Check usability
        local usable, nomana = IsUsableSpell(id)
        
        -- Check cooldown
        local start, duration, enabled = GetSpellCooldown(id)
        local on_cooldown = false
        
        local remains = 0
        if start > 0 and duration > 1.5 then -- Ignore GCD (approx)
             -- Calculate when it comes off CD
             local readyAt = start + duration
             remains = math.max(0, readyAt - state.now)
             if remains > 0 then on_cooldown = true end
        end
        
        -- Allow glow if usable OR if only missing resources (nomana)
        -- AND not on cooldown relative to virtual time
        local ready = (not on_cooldown) and (usable or nomana)
        
        return {
            usable = usable,
            ready = ready,
            cooldown_remains = remains
        }
    end
}

-- =========================================================================
-- State Structure
-- =========================================================================

state.now = 0 -- Virtual Time

state.player = {
    buff = setmetatable({}, mt_buff),
    power = { rage = { current = 0 } },
    moving = false
}

state.target = {
    debuff = setmetatable({}, mt_debuff),
    health_pct = 0,
    time_to_die = 99
}

state.spell = setmetatable({}, mt_spell)

state.active_enemies = 1

-- =========================================================================
-- Reset / Update Function (Call every frame)
-- =========================================================================

local function ScanAuras(unit, cache, filter)
    wipe(cache)
    local i = 1
    while true do
        -- Classic WotLK / Modern API signature
        local name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId = UnitAura(unit, i, filter)
        if not name then break end
        
        if spellId then
            local aura = {
                up = true,
                count = count,
                -- Store RAW expiration time to allow virtualization
                expires = (expirationTime == 0) and 0 or expirationTime, 
                duration = duration,
                remains = 0 -- Calculated dynamically
            }
            cache[spellId] = aura
            if name then cache[name] = aura end
        end
        i = i + 1
    end
end

function state.reset()
    state.now = GetTime()

    -- 1. Snapshot Player Stats
    state.player.power.rage.current = UnitPower("player", 1) -- 1=Rage
    state.player.moving = GetUnitSpeed("player") > 0
    state.active_enemies = 1 -- Placeholder
    
    -- 2. Snapshot Target Stats
    if UnitExists("target") then
        local hp = UnitHealth("target")
        local max = UnitHealthMax("target")
        state.target.health_pct = (max > 0) and ((hp / max) * 100) or 0
        state.target.time_to_die = 99 -- Placeholder
    else
        state.target.health_pct = 0
    end
    
    -- 3. Snapshot Auras (Efficiency: Scan once per frame)
    ScanAuras("player", buff_cache, "HELPFUL")
    if UnitExists("target") then
        ScanAuras("target", debuff_cache, "HARMFUL|PLAYER") -- Only my debuffs? Or all? "PLAYER" filter means cast by me.
    else
        wipe(debuff_cache)
    end
end

function state.advance(seconds)
    if not seconds or seconds <= 0 then return end
    state.now = state.now + seconds
    
    -- Future: Simulate resource regeneration here (Energy/Focus/Mana)
    -- local regen = GetPowerRegen() 
    -- state.player.power.current = state.player.power.current + (regen * seconds)
end
