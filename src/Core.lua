local addonName, ns = ...
local WhackAMole = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

_G.WhackAMole = WhackAMole
ns.WhackAMole = WhackAMole

-- Constants
local CONFIG = {
    updateInterval = 0.05,
    -- 任务 5.2 - 事件节流配置
    throttleInterval = 0.016,  -- 16ms 防抖（~60 FPS）
    priorityEvents = {         -- 优先级事件列表
        "SPELL_CAST_SUCCESS",
        "SPELL_INTERRUPT",
        "SPELL_AURA_APPLIED",
        "SPELL_AURA_REMOVED"
    }
}

-- Runtime State
WhackAMole.currentProfile = nil
WhackAMole.logicFunc = nil

-- Default Saved Variables
local defaultDB = {
    global = {
        audio = { 
            enabled = false,
            volume = 1.0  -- 0.0 to 1.0 (future-proofing for volume control)
        },
        profiles = {} -- User Profiles
    },
    char = {
        assignments = {}, -- [slotId] = spellID
        position = { point = "CENTER", x = 0, y = -220 },
        activeProfileID = nil
    }
}

-- =========================================================================
-- Lifecycle
-- =========================================================================

function WhackAMole:OnInitialize()
    -- Check for Dependencies
    if not LibStub("AceDB-3.0", true) then
        self:Print("Error: AceDB-3.0 library missing.")
        return
    end

    -- 1. Initialize DB
    self.db = LibStub("AceDB-3.0"):New("WhackAMoleDB", defaultDB)
    
    -- 2. Initialize Modules
    ns.ProfileManager:Initialize(self.db)
    ns.UI.Grid:Initialize(self.db.char)
    if ns.Audio then ns.Audio:Initialize() end
    
    -- 3. Register Config & Commands
    -- Note: UI.GetOptionsTable requires 'self' (WhackAMole) to access runtime state
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WhackAMole", function() 
        return ns.UI.GetOptionsTable(self) 
    end)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhackAMole", "WhackAMole")
    
    self:RegisterChatCommand("wam", "OnChatCommand")
    
    -- 4. 初始化事件节流系统（任务 5.2）
    self.eventThrottle = {
        lastUpdate = 0,
        pendingEvents = {},
        priorityQueue = {}
    }
    
    -- 注册战斗事件
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEvent")
    
    -- 注册初始化事件（玩家进入世界后触发）
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    
    -- Initialize Spec Detection
    ns.SpecDetection:Initialize()
end

-- 玩家进入世界事件（登录后触发）
function WhackAMole:OnPlayerEnteringWorld(event, isLogin, isReload)
    -- 取消事件注册，避免重复触发
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- 延迟 2 秒等待天赋 API 和其他系统就绪
    C_Timer.After(2, function()
        self:WaitForSpecAndLoad(0)
    end)
end

function WhackAMole:OnChatCommand(input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "lock" then
        ns.UI.Grid:SetLock(true)
        self:Print("框架已锁定")
    elseif command == "unlock" then
        ns.UI.Grid:SetLock(false)
        self:Print("框架已解锁")
    elseif command == "debug" then
        -- 显示调试窗口，所有控制在窗口内完成
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        else
            self:Print("调试窗口未初始化")
        end
    elseif command == "" then
        -- 打开配置界面
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    else
        -- 显示帮助
        self:Print("可用命令:")
        self:Print("  /wam lock/unlock - 锁定/解锁框架")
        self:Print("  /wam debug - 显示调试窗口")
    end
end

-- =========================================================================
-- 事件节流系统（任务 5.2）
-- =========================================================================

--- 判断是否为优先级事件
function WhackAMole:IsPriorityEvent(eventType)
    for _, priority in ipairs(CONFIG.priorityEvents) do
        if eventType == priority then
            return true
        end
    end
    return false
end

--- 战斗日志事件处理器
function WhackAMole:OnCombatLogEvent(event, ...)
    local timestamp, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    
    -- 只处理玩家相关事件
    if sourceGUID ~= UnitGUID("player") then
        return
    end
    
    -- 检查是否为优先级事件
    local isPriority = self:IsPriorityEvent(eventType)
    
    -- 检查节流间隔
    local now = GetTime()
    local timeSinceLastUpdate = now - self.eventThrottle.lastUpdate
    
    if isPriority then
        -- 优先级事件立即加入优先队列
        table.insert(self.eventThrottle.priorityQueue, {
            timestamp = timestamp,
            eventType = eventType,
            destName = destName
        })
        
        -- 如果距离上次更新超过节流间隔，立即触发更新
        if timeSinceLastUpdate >= CONFIG.throttleInterval then
            self:ProcessPendingEvents()
            self.eventThrottle.lastUpdate = now
        end
    else
        -- 普通事件加入待处理队列
        if timeSinceLastUpdate >= CONFIG.throttleInterval then
            table.insert(self.eventThrottle.pendingEvents, {
                timestamp = timestamp,
                eventType = eventType,
                destName = destName
            })
        end
    end
end

--- 处理待处理事件
function WhackAMole:ProcessPendingEvents()
    -- 先处理优先级队列
    for _, event in ipairs(self.eventThrottle.priorityQueue) do
        self:HandleCombatEvent(event)
    end
    
    -- 再处理普通队列
    for _, event in ipairs(self.eventThrottle.pendingEvents) do
        self:HandleCombatEvent(event)
    end
    
    -- 清空队列
    self.eventThrottle.priorityQueue = {}
    self.eventThrottle.pendingEvents = {}
end

--- 处理单个战斗事件
function WhackAMole:HandleCombatEvent(event)
    -- 这里可以根据事件类型执行不同的逻辑
    -- 例如：更新 State、触发音频提示等
    if event.eventType == "SPELL_CAST_SUCCESS" then
        -- 技能施放成功
        ns.Logger:Debug("Combat", "Spell cast success: " .. (event.destName or "unknown"))
    elseif event.eventType == "SPELL_INTERRUPT" then
        -- 技能被打断
        ns.Logger:Debug("Combat", "Spell interrupted")
    end
end

-- =========================================================================
-- Profile & Loading Logic
-- =========================================================================

function WhackAMole:WaitForSpecAndLoad(retryCount)
    retryCount = retryCount or 0
    local isLastAttempt = (retryCount >= 10)
    
    -- Use new encapsulated SpecDetection
    local spec = ns.SpecDetection:GetSpecID(isLastAttempt)
    
    if spec then
        self:InitializeProfile(spec)
    else
        if retryCount < 10 then
            C_Timer.After(1, function() self:WaitForSpecAndLoad(retryCount + 1) end)
        else
            self:Print("Timeout waiting for talent data. Loading generic profile if available.")
            self:InitializeProfile(0)
        end
    end
end

function WhackAMole:InitializeProfile(currentSpec)
    local _, playerClass = UnitClass("player")
    
    -- 加载职业模块的技能数据
    if ns.Classes and ns.Classes[playerClass] and ns.Classes[playerClass][currentSpec] then
        local specModule = ns.Classes[playerClass][currentSpec]
        ns.Spells = specModule.spells
        
        -- 重建 ActionMap
        if ns.BuildActionMap then
            ns.BuildActionMap()
        end
    else
        self:Print("Warning: No spell data for class " .. playerClass .. " spec " .. tostring(currentSpec))
    end
    
    local candidates = ns.ProfileManager:GetProfilesForClass(playerClass)
    
    if #candidates == 0 then
        self:Print("No profiles found for class: " .. playerClass)
        return
    end

    -- Try to load last selected profile or auto-detect
    local profile = nil
    local savedID = self.db.char.activeProfileID
    
    if savedID then
        local p = ns.ProfileManager:GetProfile(savedID)
        -- Validate spec match (nil spec means "universal")
        if p and (p.meta.spec == nil or p.meta.spec == currentSpec or currentSpec == 0) then
            profile = p
        else
             local oldSpec = p and p.meta.spec or "nil"
             if p then self:Print("Spec changed ("..oldSpec.."->"..currentSpec.."). Switching profile.") end
        end
    end
    
    -- Auto-detect if no valid saved profile
    if not profile then
        for _, cand in ipairs(candidates) do
            if cand.profile.meta.spec == currentSpec then
                profile = cand.profile
                self.db.char.activeProfileID = cand.id
                break
            end
        end
        -- Fallback to first available
        if not profile then
            profile = candidates[1].profile
            self.db.char.activeProfileID = candidates[1].id
        end
    end
    
    self:SwitchProfile(profile)
end

-- =========================================================================
-- Spec Change Handling (基于 PoC_Talents 验证结果)
-- =========================================================================

--- 专精变化回调
-- @param newSpecID 新的专精ID
function WhackAMole:OnSpecChanged(newSpecID)
    self:Print(string.format("检测到专精变化，重新加载配置... (SpecID: %d)", newSpecID))
    
    -- 停止当前引擎
    if self.heartbeatFrame then
        self.heartbeatFrame:SetScript("OnUpdate", nil)
    end
    
    -- 清除当前配置
    self.currentProfile = nil
    self.currentAPL = nil
    self.logicFunc = nil
    
    -- 重新加载配置
    self:InitializeProfile(newSpecID)
    
    -- 重启引擎
    self:Start()
end

function WhackAMole:SwitchProfile(profile)
    self.currentProfile = profile
    
    -- 清空脚本缓存（配置更改）
    if ns.SimCParser and ns.SimCParser.ClearCache then
        ns.SimCParser.ClearCache()
    end
    
    -- 1. Create/Resize Grid
    ns.UI.Grid:Create(profile.layout, CONFIG)
    
    -- 2. Compile APL
    if profile.apl then
        self:CompileAPL(profile.apl)
    elseif profile.script then
        -- Legacy Support
        self:CompileScript(profile.script)
    else
        self:Print("Error: No actionable logic (APL/Script) in profile.")
    end
    
    -- 3. Notify Config
    LibStub("AceConfigRegistry-3.0"):NotifyChange("WhackAMole")
end

-- =========================================================================
-- Logic Engine (Interpreter)
-- =========================================================================

function WhackAMole:CompileAPL(aplLines)
    self.compilingAPL = true
    self.currentAPL = {}
    
    if not ns.SimCParser then
        self:Print("Error: SimCParser module not found!")
        return
    end

    for _, line in ipairs(aplLines) do
        local entry = ns.SimCParser.ParseActionLine(line)
        if entry then
            table.insert(self.currentAPL, entry)
        else
            -- self:Print("Warning: Failed to parse APL line: " .. line)
        end
    end
    
    self.logicFunc = nil -- clear legacy
end

function WhackAMole:CompileScript(scriptBody)
    -- Build ID injection string from Constants
    local injection = ""
    if ns.Spells then
        for id, data in pairs(ns.Spells) do
            -- Inject: local S_Charge = 100
            -- Naming Convention: S_CamelCase
            if data and data.key then
                 -- Sanitize key to ensure valid variable name
                 local varName = "S_" .. data.key:gsub("[^%w]", "")
                 injection = injection .. string.format("local %s = %d;\n", varName, id)
            end
        end
    end

    local fullScript = "local env = ...; " .. injection .. scriptBody
    local func, err = loadstring(fullScript)
    if not func then
        self:Print("Script Compilation Error: " .. tostring(err))
        self.logicFunc = nil
    else
        self.logicFunc = func
        self.currentAPL = nil -- clear APL
        -- self:Print("Rotation logic compiled successfully.")
    end
end

-- =========================================================================
-- Main Event Loop
-- =========================================================================

function WhackAMole:OnUpdate(elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate < CONFIG.updateInterval then return end
    self.timeSinceLastUpdate = 0

    if (not self.logicFunc) and (not self.currentAPL) then return end
    
    -- 性能追踪开始
    local frameStart = debugprofilestop()
    
    -- 1. Snapshot State (Virtual Time Start)
    local stateStart = debugprofilestop()
    if ns.State.reset then ns.State.reset() end
    local stateTime = debugprofilestop() - stateStart
    
    local activeAction = nil
    local activeSlot = nil
    local nextAction = nil
    local nextSlot = nil

    -- 2. 第一次遍历：当前时刻推荐（基于 TODO.md P1 任务 1.3）
    local aplStart = debugprofilestop()
    if self.currentAPL then
        if ns.APLExecutor then
            activeAction = ns.APLExecutor.Process(self.currentAPL, ns.State)
        end
    elseif self.logicFunc then
         -- Legacy
        local status, result = pcall(self.logicFunc, ns.State)
        if status then activeSlot = result end
    end
    local aplTime = debugprofilestop() - aplStart
    
    -- 3. 第二次遍历：预测推荐（基于 TODO.md P1 任务 1.3 - 虚拟时间系统）
    -- 如果玩家正在施法，预测施法结束后的下一个技能
    local predictStart = debugprofilestop()
    if activeAction then
        local castName, _, _, _, _, endTime = UnitCastingInfo("player")
        local channelName, _, _, _, _, endTimeChannel = UnitChannelInfo("player")
        
        local castRemaining = 0
        if castName then
            castRemaining = (endTime / 1000) - GetTime()
        elseif channelName then
            castRemaining = (endTimeChannel / 1000) - GetTime()
        end
        
        if castRemaining > 0 then
            -- 推进虚拟时间到施法结束
            if ns.State.advance then
                ns.State.advance(castRemaining)
            end
            
            -- 再次遍历 APL，获取下一个推荐
            if self.currentAPL and ns.APLExecutor then
                nextAction = ns.APLExecutor.Process(self.currentAPL, ns.State)
            end
        end
    end
    local predictTime = debugprofilestop() - predictStart
    
    -- 4. Update Visuals
    -- Grid expects: (activeSlot, nextSlot, activeAction)
    local uiStart = debugprofilestop()
    if ns.UI.Grid then
        ns.UI.Grid:UpdateVisuals(activeSlot, nextSlot, activeAction, nextAction)
    end
    local uiTime = debugprofilestop() - uiStart
    
    -- 5. Audio Feedback (Unified: Use Action Name)
    local audioStart = debugprofilestop()
    if self.db.global.audio.enabled and activeAction then
        -- Use unified PlayByAction instead of Play(spellID)
        if ns.Audio and ns.Audio.PlayByAction then
            ns.Audio:PlayByAction(activeAction)
        end
    end
    local audioTime = debugprofilestop() - audioStart
    
    -- 记录性能统计
    local frameTime = debugprofilestop() - frameStart
    self:RecordPerformance(frameTime, stateTime, aplTime, predictTime, uiTime, audioTime)
end

-- Register OnUpdate on a dedicated frame? 
-- AcetAddon doesn't have native OnUpdate, usually we hook a frame.
-- But wait, Core.lua IS an AceAddon. We need a frame for OnUpdate.
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(f, elapsed) WhackAMole:OnUpdate(elapsed) end)

-- =========================================================================
-- 性能统计（供 Debug Window 使用）
-- =========================================================================

--- 记录性能数据
function WhackAMole:RecordPerformance(frameTime, stateTime, aplTime, predictTime, uiTime, audioTime)
    if not self.perfStats then
        self:InitPerformanceStats()
    end
    
    local stats = self.perfStats
    stats.frameCount = stats.frameCount + 1
    stats.totalTime = stats.totalTime + frameTime
    
    -- 更新峰值
    if frameTime > stats.maxTime then
        stats.maxTime = frameTime
    end
    
    -- 记录模块耗时
    stats.modules.state.total = stats.modules.state.total + stateTime
    stats.modules.apl.total = stats.modules.apl.total + aplTime
    stats.modules.predict.total = stats.modules.predict.total + predictTime
    stats.modules.ui.total = stats.modules.ui.total + uiTime
    stats.modules.audio.total = stats.modules.audio.total + audioTime
    
    -- 更新模块峰值
    stats.modules.state.max = math.max(stats.modules.state.max, stateTime)
    stats.modules.apl.max = math.max(stats.modules.apl.max, aplTime)
    stats.modules.predict.max = math.max(stats.modules.predict.max, predictTime)
    stats.modules.ui.max = math.max(stats.modules.ui.max, uiTime)
    stats.modules.audio.max = math.max(stats.modules.audio.max, audioTime)
    
    -- 存储帧时间用于百分位计算（只保留最近 1000 帧）
    table.insert(stats.frameTimes, frameTime)
    if #stats.frameTimes > 1000 then
        table.remove(stats.frameTimes, 1)
    end
end

--- 初始化性能统计数据
function WhackAMole:InitPerformanceStats()
    self.perfStats = {
        frameCount = 0,
        totalTime = 0,
        maxTime = 0,
        frameTimes = {},
        modules = {
            state = { total = 0, max = 0 },
            apl = { total = 0, max = 0 },
            predict = { total = 0, max = 0 },
            ui = { total = 0, max = 0 },
            audio = { total = 0, max = 0 }
        }
    }
end
