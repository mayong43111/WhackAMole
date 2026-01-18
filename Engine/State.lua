local addon, ns = ...
local WhackAMole = _G[addon]

local state = {}
ns.State = state

-- Cache tables
local buff_cache = {}
local debuff_cache = {}

-- Helper to create a dummy "down" state
local aura_down = { up = false, down = true, count = 0, remains = 0, duration = 0 }

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
        
        -- 3. Fallback for Private Servers / ID Mismatches
        -- If ID 52437 (Sudden Death) fails, try looking for the name manually
        if id == 52437 then 
             if cache["Sudden Death"] then return cache["Sudden Death"] end
             if cache["猝死"] then return cache["猝死"] end
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
                down = false,
                count = aura.count,
                -- Safe fallback for remains calculation
                remains = (expires == 0) and 9999 or math.max(0, expires - state.now),
                duration = aura.duration
            }
        end
        return aura
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             return aura_down
        end
    end
}

local mt_debuff = {
    __call = function(t, id)
        local aura = FindAura(debuff_cache, id)
        if aura.up then
            local expires = aura.expires or 0
            if expires == 0 then return aura end
            
            -- Safe fallback for remains calculation
            local remains = 0
            if expires == 0 then
                remains = 9999
            else
                 -- Ensure state.now and expires are numbers before math
                 local now = tonumber(state.now) or GetTime()
                 local exp = tonumber(expires) or now
                 remains = math.max(0, exp - now)
            end
            
            if remains == 0 and expires ~= 0 then return aura_down end
            
            return {
                up = true,
                down = false,
                count = aura.count,
                remains = remains,
                duration = aura.duration
            }
        end
        return aura
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             return aura_down
        end
    end
}

-- =========================================================================
-- Spell Metatable
-- =========================================================================
-- Ensure ActionMap is populated properly (fallback if called too early)
if ns.BuildActionMap and (not ns.ActionMap or not next(ns.ActionMap)) then
    ns.BuildActionMap()
end

local mt_spell = {
    __call = function(t, id)
        -- Retrieve Spell Name to handle Ranks automatically
        -- IsUsableSpell(ID) only works if you have that specific Rank ID.
        -- IsUsableSpell(Name) works for highest rank.
        local req = id
        local name = GetSpellInfo(id)
        if name then req = name end

        -- Check usability
        local usable, nomana = IsUsableSpell(req)
        
        -- WARRIOR Fix: Execute with Sudden Death
        -- IsUsableSpell("Execute") sometimes returns false on >20% HP even with Sudden Death buff
        if ns.ID and ns.ID.Execute and (id == ns.ID.Execute or name == GetSpellInfo(ns.ID.Execute)) then
            -- Custom logic for Execute:
            -- 1. Check Conditions: < 20% HP OR Sudden Death Buff
            local cond_hp = (state.target.health.pct < 20)
            local cond_sd = false
            
            if ns.ID.SuddenDeath then
                local aura = FindAura(buff_cache, ns.ID.SuddenDeath)
                if aura and aura.up then cond_sd = true end
            end
            
            -- 2. If valid condition, check Rage manually
            if cond_hp or cond_sd then
                -- Assuming Min Rage Cost = 10 (Sudden Death retains 10, Talents reduce cost)
                -- We use our own rage check instead of standard IsUsableSpell
                if state.rage >= 10 then
                    usable = true
                    nomana = false
                else
                    usable = false
                    nomana = true -- Signal "Resource Missing" (blue highlight usually)
                end
            end
        end

        -- Check cooldown
        local start, duration, enabled = GetSpellCooldown(req)
        local on_cooldown = false
        
        local remains = 0
        if start and start > 0 and duration > 1.5 then -- Ignore GCD (approx)
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
            cooldown_remains = remains,
            -- SimC Aliases
            up = ready,
            remains = remains
        }
    end,
    __index = function(t, k)
        if type(k) == "string" then
             if ns.ActionMap and ns.ActionMap[k] then
                 return t(ns.ActionMap[k])
             end
             
             -- DEBUG Log only if requested? Or hard fail?
             -- Actually, Execute might be failing because ActionMap isn't loaded yet?
             -- We added BuildActionMap call above.
             
             return {
                usable = false,
                ready = false,
                cooldown_remains = 0,
                up = false,
                remains = 0,
                cast_time = 0 
             }
        end
    end
}

-- =========================================================================
-- State Structure
-- =========================================================================

state.now = 0 -- Virtual Time

state.spell = setmetatable({}, mt_spell)
state.cooldown = state.spell

state.player = {
    buff = setmetatable({}, mt_buff),
    power = { rage = { current = 0 } },
    moving = false
}
state.buff = state.player.buff

state.target = {
    debuff = setmetatable({}, mt_debuff),
    health = { pct = 0, current = 0, max = 0 },
    time_to_die = 99
}
state.debuff = state.target.debuff


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
        
        -- Sanitize expirationTime (Fix for potential string returns on private servers)
        expirationTime = tonumber(expirationTime) or 0
        
        -- DEBUG: Log EVERYTHING found on target to debug visibility
        if unit == "target" and ns.Logger then
             ns.Logger:Log("Scan: [" .. i .. "] " .. (name or "nil") .. " ID: " .. (spellId or "nil") .. " Exp: " .. expirationTime)
        end
        
        local aura = {
            up = true,
            down = false,
            count = count,
            -- Store RAW expiration time to allow virtualization
            expires = (expirationTime == 0) and 0 or expirationTime, 
            duration = duration,
            -- If expiration is 0 (permanent), remains should be infinite (9999)
            -- Otherwise request dynamic calc (0 placeholder)
            remains = (expirationTime == 0) and 9999 or 0 
        }

        if spellId then
            cache[spellId] = aura
        end
        
        if name then 
            cache[name] = aura 
        end

        i = i + 1
    end
end

function state.reset()
    state.now = GetTime()

    -- 1. Snapshot Player Stats
    state.player.power.rage.current = UnitPower("player", 1) -- 1=Rage
    
    -- SimC Aliases (Direct access for conditions like 'rage > 10')
    state.rage = state.player.power.rage.current
    state.mana = UnitPower("player", 0)
    state.energy = UnitPower("player", 3)
    state.runic = UnitPower("player", 6)
    
    state.player.moving = GetUnitSpeed("player") > 0
    state.player.combat = UnitAffectingCombat("player")
    state.active_enemies = 1 -- Placeholder
    
    -- 2. Snapshot Target Stats
    if UnitExists("target") then
        local hp = UnitHealth("target")
        local max = UnitHealthMax("target")
        local pct = (max > 0) and ((hp / max) * 100) or 0
        
        state.target.health.current = hp
        state.target.health.max = max
        state.target.health.pct = pct
        
        -- Legacy alias if needed
        state.target.health_pct = pct 
        
        state.target.time_to_die = 99 -- Placeholder
        
        -- Range Check (Approximate for WotLK)
        if CheckInteractDistance("target", 3) then -- < 10y (Duel)
            state.target.range = 5
        elseif CheckInteractDistance("target", 2) then -- < 11.11y (Trade)
            state.target.range = 10
        elseif CheckInteractDistance("target", 1) then -- < 28y (Inspect)
            state.target.range = 25
        else
            state.target.range = 40
        end
    else
        state.target.health_pct = 0
        state.target.range = 100
    end
    
    -- 3. Snapshot Auras (Efficiency: Scan once per frame)
    ScanAuras("player", buff_cache, "HELPFUL")
    if UnitExists("target") then
        -- WARRIOR FIX: Use UnitDebuff directly without complex filters first to ensure we see everything
        -- iterate by index explicitly 1 to 40
        wipe(debuff_cache)
        for i = 1, 40 do
            -- Try simplest call: UnitDebuff(unit, i)
            local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", i)
            if not name then break end
            
            -- Sanitize
            expirationTime = tonumber(expirationTime) or 0
            
            -- Log finding
            if ns.Logger and (name == "撕裂" or name == "Rend") then
                 ns.Logger:Log("Scan Found Raw: " .. name .. " Exp: " .. expirationTime .. " Caster: " .. (unitCaster or "nil"))
            end
            
            local aura = {
               up = true,
               count = count,
               expires = (expirationTime == 0) and 0 or expirationTime,
               duration = duration,
               remains = (expirationTime == 0) and 9999 or math.max(0, expirationTime - state.now)
            }
            
            -- Store by ID (if available)
            if spellId then debuff_cache[spellId] = aura end
            -- Store by Name (Always)
            if name then debuff_cache[name] = aura end
        end
    else
        wipe(debuff_cache)
    end

    -- 4. Set SimC Aliases
    state.buff = state.player.buff
    state.debuff = state.target.debuff
    state.cooldown = state.spell -- Aliasing Spell checks as Cooldown checks (SimC style)
end

function state.advance(seconds)
    if not seconds or seconds <= 0 then return end
    state.now = state.now + seconds
    
    -- Future: Simulate resource regeneration here (Energy/Focus/Mana)
    -- local regen = GetPowerRegen() 
    -- state.player.power.current = state.player.power.current + (regen * seconds)
end
