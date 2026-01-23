local _, ns = ...

-- UI/Options/ImportExportTab.lua
-- Import/Export configuration tab

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

function ns.UI.Options:GetImportExportTab(WhackAMole)
    return {
        type = "group",
        name = "导入/导出",
        order = 2,
        args = {
            export_header = {
                type = "header",
                name = "导出配置",
                order = 1
            },
            export_desc = {
                type = "description",
                name = "将当前配置导出为字符串，可分享给他人。",
                fontSize = "medium",
                order = 2
            },
            export_button = {
                type = "execute",
                name = "生成导出字符串",
                desc = "导出当前激活的配置",
                func = function()
                    local profileID = WhackAMole.db.char.activeProfileID
                    local profile = ns.ProfileManager:GetProfile(profileID)
                    
                    if not profile then
                        ns.Logger:System("|cffff0000WhackAMole:|r 没有激活的配置可导出")
                        return
                    end
                    
                    local exportString = ns.Serializer:ExportProfile(profile)
                    if exportString then
                        WhackAMole.exportString = exportString
                        ns.Logger:System("|cff00ff00WhackAMole:|r 导出成功！请复制下方文本框中的字符串。")
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    else
                        ns.Logger:System("|cffff0000WhackAMole:|r 导出失败")
                    end
                end,
                order = 3
            },
            export_display = {
                type = "input",
                name = "导出字符串",
                desc = "复制此字符串分享配置",
                get = function() return WhackAMole.exportString or "点击上方按钮生成" end,
                set = function() end, -- Read-only
                multiline = 8,
                width = "full",
                order = 4
            },
            import_header = {
                type = "header",
                name = "导入配置",
                order = 10
            },
            import_desc = {
                type = "description",
                name = "粘贴从他人获得的配置字符串，导入到你的插件中。",
                fontSize = "medium",
                order = 11
            },
            import_input = {
                type = "input",
                name = "粘贴字符串",
                desc = "粘贴配置字符串到此处",
                get = function() return WhackAMole.importString or "" end,
                set = function(_, val) WhackAMole.importString = val end,
                multiline = 8,
                width = "full",
                order = 12
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
                order = 13
            }
        }
    }
end
