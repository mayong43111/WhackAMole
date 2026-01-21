local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

local function TestSpell(id)
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(id)
    if not name then 
        print("Spell " .. id .. " not found.")
        return 
    end
    
    print(string.format("Spell: %s (Rank: %s)", name, rank or "N/A"))
    
    -- Usable Check
    local usable, nomana = IsUsableSpell(name)
    print(string.format("IsUsable: %s | NoMana: %s", tostring(usable), tostring(nomana)))
    
    -- Cooldown Check
    local start, duration, enabled = GetSpellCooldown(name)
    print(string.format("CD Start: %s | Dur: %s | Enabled: %s", tostring(start), tostring(duration), tostring(enabled)))
end

frame:SetScript("OnEvent", function()
    print("PoC_Spells: Testing Spells...")
    -- Test Hearthstone (Universal)
    TestSpell(8690) 
    -- Test Attack
    TestSpell(6603)
end)

-- Slash Command to test specific ID
SLASH_POCSPELL1 = "/pocspell"
SlashCmdList["POCSPELL"] = function(msg)
    local id = tonumber(msg)
    if id then TestSpell(id) else TestSpell(msg) end
end
