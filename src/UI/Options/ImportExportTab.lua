local _, ns = ...

-- UI/Options/ImportExportTab.lua
-- Import configuration tab

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

function ns.UI.Options:GetImportExportTab(WhackAMole)
    return {
        type = "group",
        name = "导入配置",
        order = 2,
        args = {
            import_header = {
                type = "header",
                name = "导入配置",
                order = 1
            },
            import_desc = {
                type = "description",
                name = "粘贴从他人获得的配置字符串到下方文本框，点击导入按钮即可加载配置。\n\n" ..
                      "|cffFFD100提示:|r 导出功能位于「配置选择」标签页。",
                fontSize = "medium",
                order = 2
            },
            import_input = {
                type = "input",
                name = "粘贴配置字符串",
                desc = "将配置字符串粘贴到此处",
                get = function() return WhackAMole.importString or "" end,
                set = function(_, val) WhackAMole.importString = val end,
                multiline = 25,
                width = "full",
                order = 3
            },
            import_button = {
                type = "execute",
                name = "导入配置",
                desc = "导入上方文本框中的配置字符串",
                func = function()
                    local inputString = WhackAMole.importString
                    
                    if not inputString or inputString == "" then
                        ns.Logger:System("|cffff0000WhackAMole:|r 请先粘贴配置字符串")
                        return
                    end
                    
                    -- Parse profile
                    local profile, err = ns.Serializer:ImportProfile(inputString)
                    if not profile then
                        ns.Logger:System("|cffff0000WhackAMole:|r 导入失败: " .. (err or "未知错误"))
                        return
                    end
                    
                    -- Validate profile
                    local valid, validErr = ns.Serializer:Validate(profile)
                    if not valid then
                        ns.Logger:System("|cffff0000WhackAMole:|r 配置校验失败: " .. validErr)
                        return
                    end
                    
                    -- Save as user profile
                    local profileID = ns.ProfileManager:SaveUserProfile(profile)
                    
                    -- Switch to new profile
                    WhackAMole.db.char.activeProfileID = profileID
                    if WhackAMole.SwitchProfile then
                        WhackAMole:SwitchProfile(profile)
                    else
                        WhackAMole.currentProfile = profile
                        if ns.UI.Grid.Create then 
                            ns.UI.Grid:Create(profile.layout, {iconSize=40, spacing=6}) 
                        end
                        if WhackAMole.CompileScript then 
                            WhackAMole:CompileScript(profile.script) 
                        end
                    end
                    
                    -- Clear input and refresh
                    WhackAMole.importString = ""
                    ns.Logger:System("|cff00ff00WhackAMole:|r 导入成功: " .. profile.meta.name)
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end,
                order = 4,
                width = "normal"
            },
            clear_button = {
                type = "execute",
                name = "清空",
                desc = "清空文本框内容",
                func = function()
                    WhackAMole.importString = ""
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end,
                order = 5,
                width = "normal"
            }
        }
    }
end
