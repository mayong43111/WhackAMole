local _, ns = ...

-- UI/Options/ProfileTab.lua
-- Profile selection and documentation tab

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

function ns.UI.Options:GetProfileTab(WhackAMole)
    local _, playerClass = UnitClass("player")
    local profiles = ns.ProfileManager:GetProfilesForClass(playerClass) or {}
    
    return {
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
                width = "double",  -- 从 normal 改为 double，显示更宽
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
                        WhackAMole:SwitchProfile(p)
                    end
                end 
            },
            export_button = {
                type = "execute",
                name = "导出配置",
                desc = "导出当前配置为字符串，可分享给他人。",
                order = 3,
                width = "half",  -- 从 normal 改为 half，按钮变小
                func = function()
                    local profileID = WhackAMole.db.char.activeProfileID
                    local profile = ns.ProfileManager:GetProfile(profileID)
                    
                    if not profile then
                        ns.Logger:System("|cffff0000WhackAMole:|r 没有激活的配置可导出")
                        return
                    end
                    
                    local exportString = ns.Serializer:ExportProfile(profile)
                    if exportString then
                        -- 注册并显示弹窗
                        if not StaticPopupDialogs["WHACKAMOLE_EXPORT"] then
                            StaticPopupDialogs["WHACKAMOLE_EXPORT"] = {
                                text = "导出配置字符串（Ctrl+C 复制）:",
                                button1 = "关闭",
                                hasEditBox = true,
                                editBoxWidth = 350,
                                OnShow = function(self)
                                    local editBox = self.editBox or _G[self:GetName().."EditBox"]
                                    if editBox then
                                        editBox:SetText(self.text.text_arg1 or "")
                                        editBox:HighlightText()
                                        editBox:SetFocus()
                                    end
                                end,
                                timeout = 0,
                                whileDead = true,
                                hideOnEscape = true,
                                preferredIndex = 3
                            }
                        end
                        
                        local dialog = StaticPopup_Show("WHACKAMOLE_EXPORT")
                        if dialog then
                            dialog.text.text_arg1 = exportString
                            local editBox = dialog.editBox or _G[dialog:GetName().."EditBox"]
                            if editBox then
                                editBox:SetText(exportString)
                                editBox:HighlightText()
                                editBox:SetFocus()
                            end
                        end
                        
                        ns.Logger:System("|cff00ff00WhackAMole:|r 配置已导出，请复制弹窗中的字符串")
                    else
                        ns.Logger:System("|cffff0000WhackAMole:|r 导出失败")
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
                        text = text:gsub("|", "||")  -- Escape pipe characters
                        return text
                    end
                    return "选择一个配置以查看文档。"
                end,
                fontSize = "medium",
                order = 11
            }
        }
    }
end
