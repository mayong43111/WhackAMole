local _, ns = ...

-- UI/Options.lua
-- Generates the AceConfig-3.0 Table

ns.UI = ns.UI or {}

function ns.UI.GetOptionsTable(WhackAMole)
    local _, playerClass = UnitClass("player")
    local profiles = ns.ProfileManager:GetProfilesForClass(playerClass) or {}
    
    local args = {}
    
    -- 1. Profile Selection & Documentation (Group)
    args["profiles"] = {
        type = "group",
        name = "Profile Selection",
        order = 1,
        args = {
            select_header = {
                type = "header",
                name = "Choose Logic",
                order = 1
            },
            profile_select = {
                type = "select",
                name = "Active Profile",
                desc = "Select your specialization logic.",
                order = 2,
                width = "full",
                values = function()
                     local t = {}
                     for _, p in ipairs(profiles) do
                         t[p.id] = p.name
                     end
                     if next(t) == nil then t["none"] = "None" end
                     return t
                end,
                get = function() return WhackAMole.db.char.activeProfileID end,
                set = function(_, val)
                    WhackAMole.db.char.activeProfileID = val
                    local p = ns.ProfileManager:GetProfile(val)
                    if p then
                        WhackAMole.currentProfile = p
                        -- Logic Hook: We need to trigger Grid Rebuild and Compile
                        -- Ideally we call a method on WhackAMole that handles Profile Switching
                        if WhackAMole.SwitchProfile then
                            WhackAMole:SwitchProfile(p)
                        else
                             -- Fallback (should be deleted after full refactor)
                             if ns.UI.Grid.Create then ns.UI.Grid:Create(p.layout, {iconSize=40, spacing=6}) end
                             if WhackAMole.CompileScript then WhackAMole:CompileScript(p.script) end
                        end
                        
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    end
                end 
            },
            doc_header = {
                type = "header",
                name = "Manual & Tips",
                order = 10
            },
            documentation = {
                type = "description",
                name = function()
                    local p = ns.ProfileManager:GetProfile(WhackAMole.db.char.activeProfileID)       
                    if p then
                        local text = p.meta.docs or p.meta.desc or "No documentation."
                        text = text:gsub("|", "||")
                        return text
                    end
                    return "Select a profile to view documentation."
                end,
                fontSize = "medium",
                order = 11
            }
        }
    }
    
    -- 2. Settings
    args["settings"] = {
        type = "group",
        name = "Settings",
        order = 2,
        args = {
             header_ui = { type = "header", name = "Interface", order = 1 },
             lock = {
                 type = "toggle",
                 name = "Lock Frame",
                 desc = "Unlock to move the action bar.",
                 get = function() return ns.UI.Grid.locked end,
                 set = function(_, val) 
                     ns.UI.Grid:SetLock(val) 
                     -- Notify config change to update context menu if needed? Unlikely.
                 end, 
                 width = "full",
                 order = 2
             },
             header_audio = { type = "header", name = "Audio", order = 10 },
             enable_audio = {
                 type = "toggle",
                 name = "Enable Sound Cues",
                 desc = "Play sounds for key abilities.",
                 get = function() return WhackAMole.db.global.audio.enabled end,
                 set = function(_, val) WhackAMole.db.global.audio.enabled = val end,
                 width = "full",
                 order = 11
             },
             clear_assigns = {
                 type = "execute",
                 name = "Clear Keybindings",
                 desc = "Clear all drag-and-dropped spells from the grid.",
                 func = function() ns.UI.Grid:ClearAllAssignments() end,
                 order = 20
             }
        }
    }
    
    -- 3. About
    args["about"] = {
        type = "group",
        name = "About",
        order = 3,
        args = {
            title = {
                type = "description",
                name = "|cff00ccffWhackAMole|r MVP",
                fontSize = "large",
                order = 1
            },
            version = {
                type = "description",
                name = "Version: 1.1 (Titan-Forged Edition)\n\nDesigned for WotLK 3.3.5a.",    
                fontSize = "medium",
                order = 2
            }
        }
    }

    return {
        name = "WhackAMole Options",
        handler = WhackAMole, -- Keep Handler for future extensions
        type = "group",
        childGroups = "tree", -- Root is a Tree (List on left)
        args = args
    }
end
