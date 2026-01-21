local _, ns = ...

-- Core/SpecDetection.lua
-- Encapsulated logic for detecting player specialization

ns.SpecDetection = {}

function ns.SpecDetection:GetSpecID(isDebug)
    local _, playerClass = UnitClass("player")
    
    local maxPoints = -1
    local specIndex = 1
    local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    
    -- Scan Tabs
    for i = 1, 3 do
        -- Method 1: Standard API with Active Group
        local _, _, points = GetTalentTabInfo(i, false, false, activeGroup)
        
        -- Fallback A: Try without group arg if points is nil
        if not points then 
            _, _, points = GetTalentTabInfo(i)
        end
        
        -- Method 2: Manual Scan (Deep Search) - FORCE if points is 0 or nil
        if not points or points == 0 then
             local numTalents = GetNumTalents(i) or 0
             local total = 0
             for t = 1, numTalents do
                 -- GetTalentInfo(tab, index, isInspect, isPet, group)
                 local _, _, _, _, rank = GetTalentInfo(i, t, false, false, activeGroup)
                 if not rank then
                     -- Try without group
                     _, _, _, _, rank = GetTalentInfo(i, t)
                 end

                 if rank then 
                    total = total + rank 
                 end
             end
             
             if total > 0 then 
                points = total 
             end
        end

        points = tonumber(points) or 0
        
        if points > maxPoints then
            maxPoints = points
            specIndex = i
        end
    end
    
    -- Method 3: Spell Book Heuristics (Final Fallback)
    if maxPoints <= 10 then 
        local detectedSpec = ns.SpecRegistry and ns.SpecRegistry:Detect(playerClass)
        if detectedSpec then
             if isDebug then print("WhackAMole Debug: Heuristic detected spec: " .. detectedSpec) end
            return detectedSpec
        end
    end
    
    -- If MaxPoints is 0, we might be low level OR data not loaded.
    if maxPoints <= 0 and UnitLevel("player") > 10 then
        if isDebug then print("WhackAMole Debug: Spec Detection Failed (MaxPoints="..maxPoints..")") end
        return nil
    end
    
    -- Map Index to SpecID based on highest points tab
    local specID = 0
    -- WotLK 3.3.5 Spec IDs Mapping
    if playerClass == "WARRIOR" then
        specID = (specIndex == 1) and 71 or ((specIndex == 2 and 72) or 73)
    elseif playerClass == "PALADIN" then
        specID = (specIndex == 1) and 65 or ((specIndex == 2 and 66) or 70)
    elseif playerClass == "HUNTER" then
        specID = (specIndex == 1) and 253 or ((specIndex == 2 and 254) or 255)
    elseif playerClass == "ROGUE" then
        specID = (specIndex == 1) and 259 or ((specIndex == 2 and 260) or 261)
    elseif playerClass == "PRIEST" then
        specID = (specIndex == 1) and 256 or ((specIndex == 2 and 257) or 258)
    elseif playerClass == "DEATHKNIGHT" then
        specID = (specIndex == 1) and 250 or ((specIndex == 2 and 251) or 252)
    elseif playerClass == "SHAMAN" then
        specID = (specIndex == 1) and 262 or ((specIndex == 2 and 263) or 264)
    elseif playerClass == "MAGE" then
        specID = (specIndex == 1) and 62 or ((specIndex == 2 and 63) or 64)
    elseif playerClass == "WARLOCK" then
        specID = (specIndex == 1) and 265 or ((specIndex == 2 and 266) or 267)
    elseif playerClass == "DRUID" then
        specID = (specIndex == 1) and 102 or ((specIndex == 2 and 103) or 105)
    end
    
    return specID
end
