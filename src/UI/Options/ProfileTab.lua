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
                        WhackAMole:SwitchProfile(p)
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
