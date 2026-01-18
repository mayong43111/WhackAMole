-- MockWoW.lua
-- Simulates WoW API for unit testing outside the game client.

_G.MockWoW = {}
_G.MockWoW.PlayerClass = "WARRIOR"
_G.MockWoW.PlayerLevel = 80
_G.MockWoW.ActiveTalentGroup = 1
_G.MockWoW.Talents = {} -- [tabIndex] = points
_G.MockWoW.Spells = {} -- [spellID] = true

-- Global WoW API Mocks
function UnitClass(unit)
    if unit == "player" then
        return "Player", _G.MockWoW.PlayerClass
    end
    return "Unknown", "UNKNOWN"
end

function UnitLevel(unit)
    if unit == "player" then
        return _G.MockWoW.PlayerLevel
    end
    return 1
end

function GetActiveTalentGroup()
    return _G.MockWoW.ActiveTalentGroup
end

-- WotLK Signature: name, icon, points, background, previewPoints = GetTalentTabInfo(tabIndex, inspect, pet, group)
function GetTalentTabInfo(tabIndex, inspect, pet, group)
    local points = _G.MockWoW.Talents[tabIndex] or 0
    -- Return: name, icon, points, background, previewPoints
    return "Tab"..tabIndex, "Interface\\Icons\\Spell_Nature_StormReach", points, "Interface\\TalentFrame\\WarriorArms", 0
end

function GetNumTalents(tabIndex)
    return 20 -- Arbitrary number
end

function GetTalentInfo(tabIndex, talentIndex)
    -- Simply return 0 rank for now unless we need complex talent tree mocking
    return "TalentName", "Icon", 1, 1, 0, 5
end

function IsPlayerSpell(spellID)
    return _G.MockWoW.Spells[spellID] or false
end

-- Utils for setting up test state
function _G.MockWoW:Setup(class, level, talents, knownSpells)
    self.PlayerClass = class or "WARRIOR"
    self.PlayerLevel = level or 80
    self.Talents = talents or {0, 0, 0}
    self.Spells = knownSpells or {}
end

print("MockWoW API Loaded.")
