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
    
    -- 2. Import/Export
    args["import_export"] = {
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
                        print("|cffff0000WhackAMole:|r 没有激活的配置可导出")
                        return
                    end
                    
                    local exportString = ns.Serializer:ExportProfile(profile)
                    if exportString then
                        WhackAMole.exportString = exportString
                        print("|cff00ff00WhackAMole:|r 导出成功！请复制下方文本框中的字符串。")
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    else
                        print("|cffff0000WhackAMole:|r 导出失败")
                    end
                end,
                order = 3
            },
            export_display = {
                type = "input",
                name = "导出字符串",
                desc = "复制此字符串分享配置",
                get = function() return WhackAMole.exportString or "点击上方按钮生成" end,
                set = function() end, -- 只读
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
                        print("|cffff0000WhackAMole:|r 请先粘贴配置字符串")
                        return
                    end
                    
                    -- 解析配置
                    local profile, err = ns.Serializer:ImportProfile(inputString)
                    if not profile then
                        print("|cffff0000WhackAMole:|r 导入失败: " .. (err or "未知错误"))
                        return
                    end
                    
                    -- 校验配置
                    local valid, validErr = ns.Serializer:Validate(profile)
                    if not valid then
                        print("|cffff0000WhackAMole:|r 配置校验失败: " .. validErr)
                        return
                    end
                    
                    -- 保存为用户配置
                    local profileID = ns.ProfileManager:SaveUserProfile(profile)
                    
                    -- 切换到新配置
                    WhackAMole.db.char.activeProfileID = profileID
                    if WhackAMole.SwitchProfile then
                        WhackAMole:SwitchProfile(profile)
                    else
                        WhackAMole.currentProfile = profile
                        if ns.UI.Grid.Create then ns.UI.Grid:Create(profile.layout, {iconSize=40, spacing=6}) end
                        if WhackAMole.CompileScript then WhackAMole:CompileScript(profile.script) end
                    end
                    
                    -- 清空输入框并刷新
                    WhackAMole.importString = ""
                    print("|cff00ff00WhackAMole:|r 导入成功: " .. profile.meta.name)
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end,
                order = 13
            }
        }
    }
    
    -- 3. APL Editor
    args["apl_editor"] = {
        type = "group",
        name = "APL 编辑器",
        order = 3,
        args = {
            editor_header = {
                type = "header",
                name = "编辑行动优先级列表",
                order = 1
            },
            editor_desc = {
                type = "description",
                name = "修改当前配置的 APL 脚本。警告：修改内置配置会创建副本。",
                fontSize = "medium",
                order = 2
            },
            apl_input = {
                type = "input",
                name = "APL 脚本",
                desc = "每行一个动作规则，格式：actions+=/action_name,if=condition",
                multiline = 25,  -- 多行编辑器
                width = "full",
                get = function()
                    local p = ns.ProfileManager:GetProfile(WhackAMole.db.char.activeProfileID)
                    if p and p.script then
                        return p.script
                    end
                    return "# 无配置"
                end,
                set = function(_, val)
                    local profileID = WhackAMole.db.char.activeProfileID
                    local p = ns.ProfileManager:GetProfile(profileID)
                    
                    if not p then return end
                    
                    -- 如果是内置配置，创建用户副本
                    if p.meta.type == "builtin" then
                        local newID = profileID .. "_user"
                        local userProfile = ns.Util.DeepCopy(p)
                        userProfile.id = newID
                        userProfile.meta.type = "user"
                        userProfile.meta.name = p.meta.name .. " (自定义)"
                        userProfile.script = val
                        
                        ns.ProfileManager:SaveUserProfile(userProfile)
                        WhackAMole.db.char.activeProfileID = newID
                        WhackAMole:SwitchProfile(userProfile)
                        
                        print("WhackAMole: 已创建用户配置副本：" .. userProfile.meta.name)
                    else
                        -- 直接修改用户配置
                        p.script = val
                        ns.ProfileManager:SaveUserProfile(p)
                        WhackAMole:SwitchProfile(p)
                    end
                    
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end,
                order = 3
            },
            syntax_help = {
                type = "description",
                name = [[
|cff00ff00语法参考:|r
• actions+=/动作名,if=条件
• 条件运算符: and, or, not, ==, ~=, <, >, <=, >=
• 示例: actions+=/execute,if=target.health.pct<20 and rage>10

|cffff8800常用字段:|r
• buff.<name>.up / .down / .remains
• debuff.<name>.up / .down / .remains
• cooldown.<name>.ready / .remains
• rage, energy, health.pct
• target.health.pct, gcd.remains
                ]],
                fontSize = "small",
                order = 4
            },
            validate_button = {
                type = "execute",
                name = "验证语法",
                desc = "检查 APL 脚本是否有语法错误",
                func = function()
                    local p = ns.ProfileManager:GetProfile(WhackAMole.db.char.activeProfileID)
                    if not p or not p.script then
                        print("WhackAMole: 无配置可验证")
                        return
                    end
                    
                    -- 尝试编译
                    local success, err = pcall(function()
                        WhackAMole:CompileScript(p.script)
                    end)
                    
                    if success then
                        print("|cff00ff00WhackAMole: APL 语法验证通过！|r")
                    else
                        print("|cffff0000WhackAMole: APL 语法错误:|r " .. tostring(err))
                    end
                end,
                order = 5
            },
            reset_button = {
                type = "execute",
                name = "重置为默认",
                desc = "恢复当前配置为初始版本（仅用户配置）",
                func = function()
                    local profileID = WhackAMole.db.char.activeProfileID
                    local p = ns.ProfileManager:GetProfile(profileID)
                    
                    if not p or p.meta.type == "builtin" then
                        print("WhackAMole: 内置配置无法重置")
                        return
                    end
                    
                    -- 找到对应的内置配置
                    local builtinID = profileID:gsub("_user$", "")
                    local builtinProfile = ns.ProfileManager:GetProfile(builtinID)
                    
                    if builtinProfile then
                        p.script = builtinProfile.script
                        ns.ProfileManager:SaveUserProfile(p)
                        WhackAMole:SwitchProfile(p)
                        print("WhackAMole: 已重置为默认 APL")
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    else
                        print("WhackAMole: 找不到对应的内置配置")
                    end
                end,
                order = 6
            }
        }
    }
    
    -- 4. Settings
    args["settings"] = {
        type = "group",
        name = "设置",
        order = 4,
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
             audio_volume = {
                 type = "range",
                 name = "音量",
                 desc = "调整声音提示音量（0-100%）",
                 min = 0,
                 max = 1.0,
                 step = 0.05,
                 get = function() return WhackAMole.db.global.audio.volume or 1.0 end,
                 set = function(_, val) WhackAMole.db.global.audio.volume = val end,
                 width = "full",
                 order = 12,
                 disabled = function() return not WhackAMole.db.global.audio.enabled end
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
    
    -- 5. About
    args["about"] = {
        type = "group",
        name = "关于",
        order = 5,
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
