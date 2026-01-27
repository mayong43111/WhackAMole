local addon, ns = ...

-- =========================================================================
-- Core/ProfileLoader.lua - 配置文件加载和编译
-- =========================================================================

-- 从 Core.lua 拆分而来，负责配置文件加载、切换和编译

local ProfileLoader = {}
ns.CoreProfileLoader = ProfileLoader

-- =========================================================================
-- 配置初始化（重构后：40行 vs 原63行）
-- =========================================================================

--- 初始化并加载配置文件
-- @param addon WhackAMole 插件实例
-- @param currentSpec 当前专精ID
function ProfileLoader.InitializeProfile(addon, currentSpec)
    local _, playerClass = UnitClass("player")
    
    -- 加载职业模块的技能数据
    ProfileLoader.LoadClassSpells(playerClass, currentSpec)
    
    -- 获取可用的配置文件
    local candidates = ns.ProfileManager:GetProfilesForClass(playerClass)
    
    if #candidates == 0 then
        ns.Logger:System("No profiles found for class: " .. playerClass)
        return
    end

    -- 尝试加载上次选择的配置或自动检测
    local profile = ProfileLoader.SelectProfile(addon, candidates, currentSpec)
    
    if profile then
        ProfileLoader.SwitchProfile(addon, profile)
    end
end

--- 验证职业专精数据
-- @param playerClass 职业名称
-- @param currentSpec 当前专精ID
function ProfileLoader.LoadClassSpells(playerClass, currentSpec)
    -- 验证职业专精配置是否存在（仅用于日志）
    if ns.Classes and ns.Classes[playerClass] and ns.Classes[playerClass][currentSpec] then
        local specModule = ns.Classes[playerClass][currentSpec]
        ns.Logger:System("Class", string.format("已加载 %s 专精 %d: %s", playerClass, currentSpec, specModule.name or "未知"))
    else
        ns.Logger:System("Warning", string.format("未找到 %s 专精 %d 的配置", playerClass, tostring(currentSpec)))
    end
    
    -- 注意：不再覆盖 ns.Spells，统一使用 Constants.lua 中的全局定义
end

--- 选择合适的配置文件
-- @param addon WhackAMole 插件实例
-- @param candidates 候选配置列表
-- @param currentSpec 当前专精ID
-- @return table|nil 选中的配置
function ProfileLoader.SelectProfile(addon, candidates, currentSpec)
    local profile = nil
    local savedID = addon.db.char.activeProfileID
    
    -- 尝试加载上次保存的配置
    if savedID then
        local p = ns.ProfileManager:GetProfile(savedID)
        -- 验证专精匹配（nil spec 表示通用配置）
        if p and (p.meta.spec == nil or p.meta.spec == currentSpec or currentSpec == 0) then
            profile = p
        else
            local oldSpec = p and p.meta.spec or "nil"
            if p then 
                ns.Logger:System("Spec changed (" .. oldSpec .. "->" .. currentSpec .. "). Switching profile.") 
            end
        end
    end
    
    -- 自动检测：如果没有有效的保存配置
    if not profile then
        -- 查找匹配当前专精的配置
        for _, cand in ipairs(candidates) do
            if cand.profile.meta.spec == currentSpec then
                profile = cand.profile
                addon.db.char.activeProfileID = cand.id
                break
            end
        end
        
        -- 后备方案：使用第一个可用的配置
        if not profile then
            profile = candidates[1].profile
            addon.db.char.activeProfileID = candidates[1].id
        end
    end
    
    return profile
end

--- 切换配置文件（重构后：35行 vs 原35行，保持简洁）
-- @param addon WhackAMole 插件实例
-- @param profile 配置文件对象
function ProfileLoader.SwitchProfile(addon, profile)
    addon.currentProfile = profile
    
    -- 清空脚本缓存（配置更改）
    if ns.SimCParser and ns.SimCParser.ClearCache then
        ns.SimCParser.ClearCache()
    end
    
    -- 0. 切换到该配置的专属 assignments（每个配置独立保存技能分配）
    local profileKey = profile.meta.name or "default"
    if not addon.db.char.profileAssignments then
        addon.db.char.profileAssignments = {}
    end
    if not addon.db.char.profileAssignments[profileKey] then
        addon.db.char.profileAssignments[profileKey] = {}
    end
    addon.db.char.assignments = addon.db.char.profileAssignments[profileKey]
    
    -- 更新 GridState.db 引用，确保 RestoreAssignments 读取正确的表
    if ns.UI.GridState then
        ns.UI.GridState.db = addon.db.char
    end
    
    -- 1. 创建/调整格子布局
    ns.UI.Grid:Create(profile.layout, {
        iconSize = 40,
        spacing = 6
    })
    
    -- 2. 编译 APL 或脚本
    if profile.apl then
        ProfileLoader.CompileAPL(addon, profile.apl)
    elseif profile.script then
        -- 兼容旧版脚本
        ProfileLoader.CompileScript(addon, profile.script)
    else
        ns.Logger:System("Error: No actionable logic (APL/Script) in profile.")
    end
    
    -- 3. 通知配置系统更新
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end

--- 编译 APL（Action Priority List）
-- @param addon WhackAMole 插件实例
-- @param aplLines APL 行数组
function ProfileLoader.CompileAPL(addon, aplLines)
    addon.compilingAPL = true
    addon.currentAPL = {}
    
    if not ns.SimCParser then
        ns.Logger:System("Error: SimCParser module not found!")
        return
    end

    ns.Logger:System(string.format("编译 APL: %d 行", #aplLines))
    
    for idx, line in ipairs(aplLines) do
        local entry = ns.SimCParser.ParseActionLine(line)
        if entry then
            table.insert(addon.currentAPL, entry)
            ns.Logger:System("APL", string.format("  [%d] 解析成功: %s", idx, entry.action or "Unknown"))
        else
            ns.Logger:System("APL", string.format("  [%d] 解析失败: %s", idx, line))
        end
    end
    
    ns.Logger:System(string.format("APL 编译完成: %d 条有效规则", #addon.currentAPL))
    
    -- 打印 ActionMap 中的关键技能
    if ns.ActionMap then
        local keySpells = {"judgement", "crusader_strike", "divine_storm", "avenging_wrath", "hammer_of_wrath"}
        for _, spell in ipairs(keySpells) do
            local id = ns.ActionMap[spell]
            if id then
                ns.Logger:System("APL", string.format("  ActionMap[%s] = %d", spell, id))
            else
                ns.Logger:System("APL", string.format("  ActionMap[%s] = nil (缺失!)", spell))
            end
        end
    end
    
    addon.logicFunc = nil -- 清除旧版脚本
end

--- 编译 Lua 脚本（兼容旧版）
-- @param addon WhackAMole 插件实例
-- @param scriptBody 脚本内容
function ProfileLoader.CompileScript(addon, scriptBody)
    -- 构建技能ID注入字符串
    local injection = ""
    if ns.Spells then
        for id, data in pairs(ns.Spells) do
            if data and data.key then
                -- 注入: local S_Charge = 100
                local varName = "S_" .. data.key:gsub("[^%w]", "")
                injection = injection .. string.format("local %s = %d;\n", varName, id)
            end
        end
    end

    local fullScript = "local env = ...; " .. injection .. scriptBody
    local func, err = loadstring(fullScript)
    if not func then
        ns.Logger:System("Script Compilation Error: " .. tostring(err))
        addon.logicFunc = nil
    else
        addon.logicFunc = func
        addon.currentAPL = nil -- 清除 APL
    end
end

return ProfileLoader
