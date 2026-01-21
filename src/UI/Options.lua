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
        name = "配置选择",
        order = 1,
        args = {
            select_header = {
                type = "header",
                name = "选择逻辑",
                order = 1
            },
            profile_select = {
                type = "select",
                name = "当前配置",
                desc = "选择您的专精逻辑。",
                order = 2,
                width = "full",
                values = function()
                     local t = {}
                     for _, p in ipairs(profiles) do
                         t[p.id] = p.name
                     end
                     if next(t) == nil then t["none"] = "无" end
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
                name = "手册与提示",
                order = 10
            },
            documentation = {
                type = "description",
                name = function()
                    local p = ns.ProfileManager:GetProfile(WhackAMole.db.char.activeProfileID)       
                    if p then
                        local text = p.meta.docs or p.meta.desc or "无文档。"
                        text = text:gsub("|", "||")
                        return text
                    end
                    return "选择一个配置以查看文档。"
                end,
                fontSize = "medium",
                order = 11
            }
        }
    }
    
    -- 2. Settings
    args["settings"] = {
        type = "group",
        name = "设置",
        order = 2,
        args = {
             header_ui = { type = "header", name = "界面", order = 1 },
             lock = {
                 type = "toggle",
                 name = "锁定框架",
                 desc = "解锁以移动动作条。",
                 get = function() return ns.UI.Grid.locked end,
                 set = function(_, val) 
                     ns.UI.Grid:SetLock(val) 
                     -- Notify config change to update context menu if needed? Unlikely.
                 end, 
                 width = "full",
                 order = 2
             },
             header_audio = { type = "header", name = "音频", order = 10 },
             enable_audio = {
                 type = "toggle",
                 name = "启用声音提示",
                 desc = "为关键技能播放声音。",
                 get = function() return WhackAMole.db.global.audio.enabled end,
                 set = function(_, val) WhackAMole.db.global.audio.enabled = val end,
                 width = "full",
                 order = 11
             },
             clear_assigns = {
                 type = "execute",
                 name = "清除按键绑定",
                 desc = "清除网格中所有拖放的技能。",
                 func = function() ns.UI.Grid:ClearAllAssignments() end,
                 order = 20
             }
        }
    }
    
    -- 3. About
    args["about"] = {
        type = "group",
        name = "关于",
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
                name = "版本: 1.1 (泰坦造物版)\n\n专为 WotLK 3.3.5a 设计。",    
                fontSize = "medium",
                order = 2
            }
        }
    }

    return {
        name = "WhackAMole 选项",
        handler = WhackAMole, -- Keep Handler for future extensions
        type = "group",
        childGroups = "tree", -- Root is a Tree (List on left)
        args = args
    }
end
