local _, ns = ...

-- UI/Options/APLEditorTab.lua
-- APL script editor tab

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

-- Create user copy of builtin profile
local function CreateUserCopy(profile, newScript)
    local newID = profile.id .. "_user"
    local userProfile = ns.Util.DeepCopy(profile)
    userProfile.id = newID
    userProfile.meta.type = "user"
    userProfile.meta.name = profile.meta.name .. " (自定义)"
    userProfile.script = newScript
    return userProfile
end

function ns.UI.Options:GetAPLEditorTab(WhackAMole)
    return {
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
                multiline = 25,
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
                    
                    -- Create user copy if modifying builtin profile
                    if p.meta.type == "builtin" then
                        local userProfile = CreateUserCopy(p, val)
                        ns.ProfileManager:SaveUserProfile(userProfile)
                        WhackAMole.db.char.activeProfileID = userProfile.id
                        WhackAMole:SwitchProfile(userProfile)
                        ns.Logger:System("WhackAMole: 已创建用户配置副本：" .. userProfile.meta.name)
                    else
                        -- Directly modify user profile
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
                        ns.Logger:System("WhackAMole: 无配置可验证")
                        return
                    end
                    
                    -- Try to compile
                    local success, err = pcall(function()
                        WhackAMole:CompileScript(p.script)
                    end)
                    
                    if success then
                        ns.Logger:System("|cff00ff00WhackAMole: APL 语法验证通过！|r")
                    else
                        ns.Logger:System("|cffff0000WhackAMole: APL 语法错误:|r " .. tostring(err))
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
                        ns.Logger:System("WhackAMole: 内置配置无法重置")
                        return
                    end
                    
                    -- Find corresponding builtin profile
                    local builtinID = profileID:gsub("_user$", "")
                    local builtinProfile = ns.ProfileManager:GetProfile(builtinID)
                    
                    if builtinProfile then
                        p.script = builtinProfile.script
                        ns.ProfileManager:SaveUserProfile(p)
                        WhackAMole:SwitchProfile(p)
                        ns.Logger:System("WhackAMole: 已重置为默认 APL")
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    else
                        ns.Logger:System("WhackAMole: 找不到对应的内置配置")
                    end
                end,
                order = 6
            }
        }
    }
end
