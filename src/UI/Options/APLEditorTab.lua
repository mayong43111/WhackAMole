local _, ns = ...

-- UI/Options/APLEditorTab.lua
-- APL editor tab with three-field editing

ns.UI = ns.UI or {}
ns.UI.Options = ns.UI.Options or {}

-- 职业-天赋映射数据
local CLASS_SPEC_DATA = {
    WARRIOR = {
        name = "战士",
        specs = {
            {id = 71, name = "武器"},
            {id = 72, name = "狂暴"},
            {id = 73, name = "防护"}
        },
        skills = {
            "mortal_strike", "overpower", "execute", "rend", "heroic_strike",
            "bloodthirst", "whirlwind", "slam", "rampage",
            "shield_slam", "revenge", "devastate", "shield_block", "last_stand"
        }
    },
    PALADIN = {
        name = "圣骑士",
        specs = {
            {id = 65, name = "神圣"},
            {id = 66, name = "防护"},
            {id = 70, name = "惩戒"}
        },
        skills = {
            "flash_of_light", "holy_light", "holy_shock", "beacon_of_light",
            "avengers_shield", "holy_shield", "consecration", "hammer_of_the_righteous",
            "crusader_strike", "judgement", "exorcism", "divine_storm", "templars_verdict"
        }
    },
    HUNTER = {
        name = "猎人",
        specs = {
            {id = 253, name = "野兽控制"},
            {id = 254, name = "射击"},
            {id = 255, name = "生存"}
        },
        skills = {
            "kill_command", "bestial_wrath", "arcane_shot",
            "aimed_shot", "steady_shot", "chimera_shot", "serpent_sting",
            "explosive_shot", "black_arrow", "raptor_strike", "mongoose_bite"
        }
    },
    ROGUE = {
        name = "潜行者",
        specs = {
            {id = 259, name = "刺杀"},
            {id = 260, name = "战斗"},
            {id = 261, name = "敏锐"}
        },
        skills = {
            "mutilate", "envenom", "rupture", "deadly_poison",
            "sinister_strike", "slice_and_dice", "eviscerate", "adrenaline_rush",
            "backstab", "hemorrhage", "ambush", "shadowstep"
        }
    },
    PRIEST = {
        name = "牧师",
        specs = {
            {id = 256, name = "戒律"},
            {id = 257, name = "神圣"},
            {id = 258, name = "暗影"}
        },
        skills = {
            "penance", "power_word_shield", "flash_heal",
            "renew", "prayer_of_mending", "circle_of_healing",
            "mind_blast", "mind_flay", "shadow_word_pain", "shadow_word_death", "vampiric_touch"
        }
    },
    DEATHKNIGHT = {
        name = "死亡骑士",
        specs = {
            {id = 250, name = "鲜血"},
            {id = 251, name = "冰霜"},
            {id = 252, name = "邪恶"}
        },
        skills = {
            "heart_strike", "death_strike", "rune_tap", "vampiric_blood",
            "obliterate", "frost_strike", "howling_blast", "pillar_of_frost",
            "scourge_strike", "death_coil", "festering_strike", "unholy_blight"
        }
    },
    SHAMAN = {
        name = "萨满祭司",
        specs = {
            {id = 262, name = "元素"},
            {id = 263, name = "增强"},
            {id = 264, name = "恢复"}
        },
        skills = {
            "lightning_bolt", "lava_burst", "chain_lightning", "flame_shock", "earth_shock",
            "stormstrike", "lava_lash", "windfury_weapon", "flametongue_weapon",
            "healing_wave", "chain_heal", "riptide", "earth_shield"
        }
    },
    MAGE = {
        name = "法师",
        specs = {
            {id = 62, name = "奥术"},
            {id = 63, name = "火焰"},
            {id = 64, name = "冰霜"}
        },
        skills = {
            "arcane_blast", "arcane_missiles", "arcane_barrage",
            "fireball", "pyroblast", "living_bomb", "combustion",
            "frostbolt", "ice_lance", "deep_freeze", "frozen_orb"
        }
    },
    WARLOCK = {
        name = "术士",
        specs = {
            {id = 265, name = "痛苦"},
            {id = 266, name = "恶魔学识"},
            {id = 267, name = "毁灭"}
        },
        skills = {
            "corruption", "unstable_affliction", "haunt", "drain_soul",
            "shadow_bolt", "soul_fire", "immolate", "incinerate",
            "chaos_bolt", "conflagrate", "shadowburn"
        }
    },
    DRUID = {
        name = "德鲁伊",
        specs = {
            {id = 102, name = "平衡"},
            {id = 103, name = "野性战斗"},
            {id = 105, name = "恢复"}
        },
        skills = {
            "wrath", "starfire", "moonfire", "insect_swarm", "starfall",
            "mangle", "shred", "rip", "savage_roar", "ferocious_bite",
            "rejuvenation", "regrowth", "nourish", "wild_growth", "swiftmend"
        }
    }
}

-- 临时编辑缓冲区
local editBuffer = {
    name = "",
    class = "",
    spec = 0,
    skillSlots = "",
    aplScript = ""
}

-- 从配置加载到编辑缓冲区
local function LoadProfileToBuffer(profile)
    if not profile then
        local _, playerClass = UnitClass("player")
        local currentSpec = ns.SpecDetection and ns.SpecDetection:GetSpecID() or 0
        
        editBuffer.name = "[USER] 新配置"
        editBuffer.class = playerClass
        editBuffer.spec = currentSpec
        editBuffer.skillSlots = ""
        editBuffer.aplScript = ""
        return
    end
    
    editBuffer.name = profile.meta.name or ""
    editBuffer.class = profile.meta.class or select(2, UnitClass("player"))
    editBuffer.spec = profile.meta.spec or 0
    
    -- 解析技能槽
    local slots = {}
    if profile.layout and profile.layout.slots then
        for _, slot in pairs(profile.layout.slots) do
            if slot.action then
                table.insert(slots, slot.action)
            end
        end
    end
    editBuffer.skillSlots = table.concat(slots, ",")
    
    -- 加载APL脚本
    editBuffer.aplScript = profile.script or ""
end

-- 组装完整配置
local function AssembleProfile()
    -- 1. 强制添加 [USER] 前缀
    local name = editBuffer.name or "[USER] 新配置"
    if not name:match("^%[USER%]") then
        name = "[USER] " .. name
    end
    
    -- 2. 解析技能槽
    local slots = {}
    local slotIndex = 1
    for skill in string.gmatch(editBuffer.skillSlots or "", "([^,]+)") do
        skill = strtrim(skill)
        if skill ~= "" then
            slots[slotIndex] = { action = skill }
            slotIndex = slotIndex + 1
        end
    end
    
    -- 3. 组装完整结构
    local profile = {
        meta = {
            name = name,
            type = "user",
            class = editBuffer.class or select(2, UnitClass("player")),
            spec = editBuffer.spec or 0,
            author = "User",
            version = 1,
            desc = "用户自定义配置"
        },
        layout = {
            slots = slots
        },
        script = editBuffer.aplScript or ""
    }
    
    return profile
end

function ns.UI.Options:GetAPLEditorTab(WhackAMole)
    local _, playerClass = UnitClass("player")
    
    return {
        type = "group",
        name = "APL 编辑器",
        order = 3,
        args = {
            select_header = {
                type = "header",
                name = "选择配置",
                order = 1
            },
            profile_select = {
                type = "select",
                name = "基础配置",
                desc = "选择要编辑的配置（内置或用户）",
                width = "normal",
                order = 2,
                values = function()
                    -- 获取所有配置（包括内置和用户）
                    local allProfiles = ns.ProfileManager:GetProfilesForClass(playerClass) or {}
                    local values = {}
                    for _, p in ipairs(allProfiles) do
                        values[p.id] = p.meta.name or p.name or p.id
                    end
                    if next(values) == nil then
                        values["none"] = "无"
                    end
                    return values
                end,
                get = function()
                    return WhackAMole.editingProfileID or "none"
                end,
                set = function(_, val)
                    WhackAMole.editingProfileID = val
                    local profile = ns.ProfileManager:GetProfile(val)
                    LoadProfileToBuffer(profile)
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end
            },
            new_button = {
                type = "execute",
                name = "新建配置",
                desc = "创建一个新的空白配置",
                width = "normal",
                order = 3,
                func = function()
                    WhackAMole.editingProfileID = nil
                    LoadProfileToBuffer(nil)
                    ns.Logger:System("WhackAMole: 已创建新配置模板")
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end
            },
            edit_header = {
                type = "header",
                name = "编辑配置",
                order = 10
            },
            config_name = {
                type = "input",
                name = "配置名称",
                desc = "配置的显示名称（保存时自动添加 [USER] 前缀）",
                width = "full",
                order = 11,
                get = function()
                    return editBuffer.name
                end,
                set = function(_, val)
                    editBuffer.name = val
                end
            },
            config_class = {
                type = "select",
                name = "职业",
                desc = "选择配置适用的职业",
                width = "normal",
                order = 12,
                values = function()
                    local classes = {}
                    for classKey, classData in pairs(CLASS_SPEC_DATA) do
                        classes[classKey] = classData.name
                    end
                    return classes
                end,
                get = function()
                    return editBuffer.class
                end,
                set = function(_, val)
                    editBuffer.class = val
                    -- 切换职业时重置天赋为该职业第一个天赋
                    if CLASS_SPEC_DATA[val] and CLASS_SPEC_DATA[val].specs[1] then
                        editBuffer.spec = CLASS_SPEC_DATA[val].specs[1].id
                    else
                        editBuffer.spec = 0
                    end
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end
            },
            config_spec = {
                type = "select",
                name = "天赋",
                desc = "选择配置适用的天赋专精",
                width = "normal",
                order = 13,
                values = function()
                    local specs = {}
                    local classKey = editBuffer.class
                    if classKey and CLASS_SPEC_DATA[classKey] then
                        for _, specData in ipairs(CLASS_SPEC_DATA[classKey].specs) do
                            specs[specData.id] = specData.name
                        end
                    end
                    if next(specs) == nil then
                        specs[0] = "无"
                    end
                    return specs
                end,
                get = function()
                    return editBuffer.spec or 0
                end,
                set = function(_, val)
                    editBuffer.spec = val
                end
            },
            skill_slots = {
                type = "input",
                name = "技能槽",
                desc = "逗号分隔的技能名称，例如：obliterate,frost_strike,howling_blast",
                width = "full",
                order = 14,
                get = function()
                    return editBuffer.skillSlots
                end,
                set = function(_, val)
                    editBuffer.skillSlots = val
                end
            },
            skill_picker = {
                type = "select",
                name = "添加技能",
                desc = "从列表中选择技能添加到技能槽",
                width = "normal",
                order = 15,
                values = function()
                    local skills = {}
                    local classKey = editBuffer.class
                    if classKey and CLASS_SPEC_DATA[classKey] and CLASS_SPEC_DATA[classKey].skills then
                        -- 添加占位选项
                        skills[""] = "-- 选择技能 --"
                        -- 添加职业技能
                        for _, skillName in ipairs(CLASS_SPEC_DATA[classKey].skills) do
                            skills[skillName] = skillName
                        end
                    else
                        skills[""] = "请先选择职业"
                    end
                    return skills
                end,
                get = function()
                    return "" -- 始终显示占位文本
                end,
                set = function(_, val)
                    if val and val ~= "" then
                        -- 追加技能到技能槽
                        local current = editBuffer.skillSlots or ""
                        if current == "" then
                            editBuffer.skillSlots = val
                        else
                            -- 检查是否已存在
                            local exists = false
                            for skill in string.gmatch(current, "([^,]+)") do
                                if strtrim(skill) == val then
                                    exists = true
                                    break
                                end
                            end
                            
                            if not exists then
                                editBuffer.skillSlots = current .. "," .. val
                            else
                                ns.Logger:System("|cffFFD100WhackAMole:|r 技能已存在: " .. val)
                            end
                        end
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                    end
                end
            },
            clear_skills_button = {
                type = "execute",
                name = "清空技能槽",
                desc = "清空所有技能槽内容",
                width = "normal",
                order = 16,
                func = function()
                    editBuffer.skillSlots = ""
                    ns.Logger:System("WhackAMole: 已清空技能槽")
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end
            },
            apl_script = {
                type = "input",
                name = "APL 脚本",
                desc = "每行一个动作规则，格式：actions+=/action_name,if=condition",
                multiline = 25,
                width = "full",
                order = 17,
                get = function()
                    return editBuffer.aplScript
                end,
                set = function(_, val)
                    editBuffer.aplScript = val
                end
            },
            action_header = {
                type = "header",
                name = "操作",
                order = 20
            },
            save_button = {
                type = "execute",
                name = "保存配置",
                desc = "保存当前编辑的配置（同名配置将被覆盖）",
                width = "normal",
                order = 21,
                func = function()
                    -- 组装配置
                    local profile = AssembleProfile()
                    
                    -- 检查是否同名配置存在
                    local existingProfile = ns.ProfileManager:GetProfileByName(profile.meta.name)
                    if existingProfile then
                        ns.Logger:System("|cffFFD100WhackAMole:|r 覆盖已有配置: " .. profile.meta.name)
                    else
                        ns.Logger:System("|cff00ff00WhackAMole:|r 创建新配置: " .. profile.meta.name)
                    end
                    
                    -- 保存
                    local profileID = ns.ProfileManager:SaveUserProfile(profile)
                    
                    -- 切换到新配置
                    WhackAMole.db.char.activeProfileID = profileID
                    WhackAMole:SwitchProfile(profile)
                    WhackAMole.editingProfileID = profileID
                    
                    ns.Logger:System("|cff00ff00WhackAMole:|r 配置已保存")
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
                end
            },
            validate_button = {
                type = "execute",
                name = "验证语法",
                desc = "检查 APL 脚本是否有语法错误",
                width = "normal",
                order = 22,
                func = function()
                    if not editBuffer.aplScript or editBuffer.aplScript == "" then
                        ns.Logger:System("WhackAMole: 无 APL 脚本可验证")
                        return
                    end
                    
                    -- 尝试编译
                    local success, err = pcall(function()
                        WhackAMole:CompileScript(editBuffer.aplScript)
                    end)
                    
                    if success then
                        ns.Logger:System("|cff00ff00WhackAMole: APL 语法验证通过！|r")
                    else
                        ns.Logger:System("|cffff0000WhackAMole: APL 语法错误:|r " .. tostring(err))
                    end
                end
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

|cffFFD100技能槽示例:|r
obliterate,frost_strike,howling_blast,blood_strike
                ]],
                fontSize = "small",
                order = 30
            }
        }
    }
end
