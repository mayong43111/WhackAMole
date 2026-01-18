local _, ns = ...

-- Sound Mapping Table
-- spellId -> filename (in Sounds/ folder)
ns.SoundPack = {
    -- warrior
    [100]    = "Charge.ogg",              -- Charge
    [5308]   = "Execute.ogg",             -- Execute
    [12294]  = "MortalStrike.ogg",        -- Mortal Strike
    [7384]   = "Overpower.ogg",           -- Overpower
    [46924]  = "Bladestorm.ogg",          -- Bladestorm
    [1719]   = "recklessness.ogg",        -- Recklessness
    [871]    = "ShieldWall.ogg",          -- Shield Wall
    [12975]  = "LastStand.ogg",           -- Last Stand
    [2565]   = "ShieldBlock.ogg",         -- Shield Block
    [676]    = "Disarm.ogg",              -- Disarm
    [6552]   = "Pummel.ogg",              -- Pummel
    [23920]  = "SpellReflection.ogg",     -- Spell Reflection
    [3411]   = "Intervene.ogg",           -- Intervene
    [12328]  = "sweepingStrikes.ogg",     -- Sweeping Strikes
    [64382]  = "ShatteringThrow.ogg",     -- Shattering Throw
    [5246]   = "IntimidatingShout.ogg",   -- Intimidating Shout
    
    -- DK
    [48707]  = "AntiMagicShell.ogg",      -- Anti-Magic Shell
    [48792]  = "IceboundFortitude.ogg",   -- Icebound Fortitude
    [49028]  = "DancingRuneWeapon.ogg",   -- Dancing Rune Weapon
    [49039]  = "Lichborne.ogg",           -- Lichborne
    [55233]  = "VampiricBlood.ogg",       -- Vampiric Blood
    [49222]  = "BoneShield.ogg",          -- Bone Shield
    [47476]  = "Strangulate.ogg",         -- Strangulate
    [47528]  = "MindFreeze.ogg",          -- Mind Freeze
    [51271]  = "PillarofFrost.ogg",       -- Pillar of Frost
    [49206]  = "SummonGargoyle.ogg",      -- Summon Gargoyle
    [63560]  = "DarkTransformation.ogg",  -- Dark Transformation
    [108194] = "Asphyxiate.ogg",          -- Asphyxiate
    
    -- Paladin
    [642]    = "DivineShield.ogg",        -- Divine Shield
    [1022]   = "HandofProtection.ogg",    -- Hand of Protection
    [1044]   = "HandofFreedom.ogg",       -- Hand of Freedom
    [6940]   = "HandofSacrifice.ogg",     -- Hand of Sacrifice
    [31884]  = "AvengingWrath.ogg",       -- Avenging Wrath
    [498]    = "DivineProtection.ogg",    -- Divine Protection
    [31821]  = "AuraMastery.ogg",         -- Aura Mastery
    [853]    = "HammerofJustice.ogg",     -- Hammer of Justice
    [96231]  = "Rebuke.ogg",              -- Rebuke
    
    -- Priest
    [33206]  = "PainSuppression.ogg",     -- Pain Suppression
    [47585]  = "Dispersion.ogg",          -- Dispersion
    [10060]  = "PowerInfusion.ogg",       -- Power Infusion
    [8122]   = "PsychicScream.ogg",       -- Psychic Scream
    [64044]  = "PsychicHorror.ogg",       -- Psychic Horror
    [15487]  = "Silence.ogg",             -- Silence
    [32375]  = "MassDissipation.ogg",     -- Mass Dissipation (MassDispell.ogg likely)
    [47788]  = "GuardianSpirit.ogg",      -- Guardian Spirit

    -- Rogue
    [31224]  = "CloakofShadows.ogg",      -- Cloak of Shadows
    [2983]   = "Sprint.ogg",              -- Sprint
    [1856]   = "Vanish.ogg",              -- Vanish
    [5277]   = "Evasion.ogg",             -- Evasion
    [2094]   = "Blind.ogg",               -- Blind
    [408]    = "KidneyShot.ogg",          -- Kidney Shot
    [1766]   = "Kick.ogg",                -- Kick
    [51713]  = "ShadowDance.ogg",         -- Shadow Dance
    [5171]   = "SliceandDice.ogg",        -- Slice and Dice
    
    -- Druid
    [22812]  = "Barkskin.ogg",            -- Barkskin
    [61336]  = "SurvivalInstincts.ogg",   -- Survival Instincts
    [29166]  = "Innervate.ogg",           -- Innervate
    [33786]  = "Cyclone.ogg",             -- Cyclone
    [106839] = "SkullBash.ogg",           -- Skull Bash
    
    -- Shaman
    [2825]   = "Bloodlust.ogg",           -- Bloodlust
    [32182]  = "Heroism.ogg",             -- Heroism
    [57994]  = "WindShear.ogg",           -- Wind Shear
    [51514]  = "Hex.ogg",                 -- Hex
    [8143]   = "TremorTotem.ogg",         -- Tremor Totem
    
    -- Mage
    [45438]  = "IceBlock.ogg",            -- Ice Block
    [12051]  = "Evocation.ogg",           -- Evocation
    [2139]   = "Counterspell.ogg",        -- Counterspell
    [118]    = "Polymorph.ogg",           -- Polymorph
    [12472]  = "IcyVeins.ogg",            -- Icy Veins
    
    -- Warlock
    [17928]  = "HowlOfTerror.ogg",        -- Howl of Terror
    [5782]   = "Fear.ogg",                -- Fear
    [19647]  = "SpellLock.ogg",           -- Spell Lock
    
    -- Hunter
    [781]    = "Disengage.ogg",           -- Disengage
    [19263]  = "Deterrence.ogg",          -- Deterrence
    [34477]  = "Misdirection.ogg",        -- Misdirection
    [19503]  = "ScatterShot.ogg",         -- Scatter Shot
    
    -- General
    [20594]  = "Stoneform.ogg",           -- Stoneform
    [59752]  = "EveryManforHimself.ogg",  -- Every Man for Himself
    [7744]   = "WilloftheForsaken.ogg",   -- Will of the Forsaken
    [20589]  = "EscapeArtist.ogg",        -- Escape Artist
    [42292]  = "PvPTrinket.ogg",          -- PvP Trinket
}

-- Return the table for external use
return ns.SoundPack
