local _, ns = ...

-- Warrior Spec Detection Logic
ns.SpecRegistry:Register("WARRIOR", function()
    -- 51 Point Talents
    if IsPlayerSpell(46924) then return 71 end -- Bladestorm (Arms)
    if IsPlayerSpell(46917) then return 72 end -- Titan's Grip (Fury)
    if IsPlayerSpell(46968) then return 73 end -- Shockwave (Prot)
    
    -- 31 Point Talents (Fallback for lower levels)
    if IsPlayerSpell(12294) then return 71 end -- Mortal Strike (Arms)
    if IsPlayerSpell(23881) then return 72 end -- Bloodthirst (Fury)
    if IsPlayerSpell(23922) then return 73 end -- Shield Slam (Prot)

    return nil
end)
