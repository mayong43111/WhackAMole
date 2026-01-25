local _, ns = ...

-- UI/Options/SettingsTab.lua
-- General settings tab (UI, audio, etc.)

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

function ns.UI.Options:GetSettingsTab(WhackAMole)
    return {
        type = "group",
        name = "设置",
        order = 4,
        args = {
            header_general = { 
                type = "header", 
                name = "通用", 
                order = 0 
            },
            enable_addon = {
                type = "toggle",
                name = "启用插件",
                desc = "关闭后将隐藏动作条并停止技能推荐。可随时通过 /awm 重新启用。",
                get = function() 
                    return WhackAMole.db.global.enabled 
                end,
                set = function(_, val) 
                    WhackAMole.db.global.enabled = val
                    if WhackAMole.SetEnabled then
                        WhackAMole:SetEnabled(val)
                    end
                end,
                width = "full",
                order = 1
            },
            header_ui = { 
                type = "header", 
                name = "界面", 
                order = 10 
            },
            lock = {
                type = "toggle",
                name = "锁定框架",
                desc = "解锁以移动动作条。",
                get = function() 
                    return ns.UI.GridState and ns.UI.GridState.locked 
                end,
                set = function(_, val) 
                    ns.UI.Grid:SetLock(val) 
                end, 
                width = "full",
                order = 11,
                disabled = function()
                    return not WhackAMole.db.global.enabled
                end
            },
            header_audio = { 
                type = "header", 
                name = "音频", 
                order = 20 
            },
            enable_audio = {
                type = "toggle",
                name = "启用声音提示",
                desc = "为关键技能播放声音。",
                get = function() 
                    return WhackAMole.db.global.audio.enabled 
                end,
                set = function(_, val) 
                    WhackAMole.db.global.audio.enabled = val 
                end,
                width = "full",
                order = 21
            },
            audio_volume = {
                type = "range",
                name = "音量",
                desc = "调整声音提示音量（0-100%）",
                min = 0,
                max = 1.0,
                step = 0.05,
                get = function() 
                    return WhackAMole.db.global.audio.volume or 1.0 
                end,
                set = function(_, val) 
                    WhackAMole.db.global.audio.volume = val 
                end,
                width = "full",
                order = 22,
                disabled = function() 
                    return not WhackAMole.db.global.audio.enabled 
                end
            },
            clear_assigns = {
                type = "execute",
                name = "清除按键绑定",
                desc = "清除网格中所有拖放的技能。",
                func = function() 
                    ns.UI.Grid:ClearAllAssignments() 
                end,
                order = 30,
                disabled = function()
                    return not WhackAMole.db.global.enabled
                end
            }
        }
    }
end
