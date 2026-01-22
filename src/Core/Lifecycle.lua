local addon, ns = ...

-- =========================================================================
-- Core/Lifecycle.lua - 生命周期管理
-- =========================================================================

-- 从 Core.lua 拆分而来，负责插件生命周期管理

local Lifecycle = {}
ns.CoreLifecycle = Lifecycle

-- 引用配置模块
local Config = ns.CoreConfig

-- =========================================================================
-- 初始化
-- =========================================================================

--- 插件初始化（从 OnInitialize 拆分）
-- @param addon WhackAMole 插件实例
function Lifecycle.Initialize(addon)
    -- 1. 检查依赖
    if not LibStub("AceDB-3.0", true) then
        addon:Print("Error: AceDB-3.0 library missing.")
        return false
    end

    -- 2. 初始化数据库
    addon.db = LibStub("AceDB-3.0"):New("WhackAMoleDB", Config:GetDefaultDB())
    
    -- 3. 初始化子模块
    ns.ProfileManager:Initialize(addon.db)
    ns.UI.Grid:Initialize(addon.db.char)
    if ns.Audio then 
        ns.Audio:Initialize() 
    end
    
    -- 4. 注册配置界面
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WhackAMole", function() 
        return ns.UI.GetOptionsTable(addon) 
    end)
    addon.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhackAMole", "WhackAMole")
    
    -- 5. 注册聊天命令
    addon:RegisterChatCommand("wam", "OnChatCommand")
    
    -- 6. 初始化事件节流系统
    addon.eventThrottle = {
        lastUpdate = 0,
        pendingEvents = {},
        priorityQueue = {}
    }
    
    -- 7. 注册事件
    addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEvent")
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    
    -- 8. 初始化专精检测
    ns.SpecDetection:Initialize()
    
    return true
end

--- 玩家进入世界事件处理
-- @param addon WhackAMole 插件实例
-- @param event 事件名称
-- @param isLogin 是否为登录
-- @param isReload 是否为重载UI
function Lifecycle.OnPlayerEnteringWorld(addon, event, isLogin, isReload)
    -- 取消事件注册，避免重复触发
    addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- 延迟 0.5 秒等待天赋 API 和其他系统就绪（优化启动速度）
    C_Timer.After(0.5, function()
        Lifecycle.WaitForSpecAndLoad(addon, 0)
    end)
end

--- 等待专精数据并加载配置
-- @param addon WhackAMole 插件实例
-- @param retryCount 重试次数
function Lifecycle.WaitForSpecAndLoad(addon, retryCount)
    retryCount = retryCount or 0
    local isLastAttempt = (retryCount >= 10)
    
    -- 使用专精检测模块获取当前专精
    local spec = ns.SpecDetection:GetSpecID(isLastAttempt)
    
    if spec then
        -- 找到专精，初始化配置
        if ns.CoreProfileLoader then
            ns.CoreProfileLoader.InitializeProfile(addon, spec)
        end
    else
        -- 未找到专精，继续重试
        if retryCount < 10 then
            C_Timer.After(1, function() 
                Lifecycle.WaitForSpecAndLoad(addon, retryCount + 1) 
            end)
        else
            -- 超时，加载通用配置
            addon:Print("Timeout waiting for talent data. Loading generic profile if available.")
            if ns.CoreProfileLoader then
                ns.CoreProfileLoader.InitializeProfile(addon, 0)
            end
        end
    end
end

--- 专精变化回调（基于 PoC_Talents 验证结果）
-- @param addon WhackAMole 插件实例
-- @param newSpecID 新的专精ID
function Lifecycle.OnSpecChanged(addon, newSpecID)
    addon:Print(string.format("检测到专精变化，重新加载配置... (SpecID: %d)", newSpecID))
    
    -- 停止当前引擎
    if addon.heartbeatFrame then
        addon.heartbeatFrame:SetScript("OnUpdate", nil)
    end
    
    -- 清除当前配置
    addon.currentProfile = nil
    addon.currentAPL = nil
    addon.logicFunc = nil
    
    -- 重新加载配置
    if ns.CoreProfileLoader then
        ns.CoreProfileLoader.InitializeProfile(addon, newSpecID)
    end
    
    -- 重启引擎
    if ns.CoreUpdateLoop then
        ns.CoreUpdateLoop.Start(addon)
    end
end

--- 聊天命令处理
-- @param addon WhackAMole 插件实例
-- @param input 命令输入
function Lifecycle.OnChatCommand(addon, input)
    local command, args = input:match("^(%S*)%s*(.-)$")
    
    if command == "lock" then
        ns.UI.Grid:SetLock(true)
        addon:Print("框架已锁定")
    elseif command == "unlock" then
        ns.UI.Grid:SetLock(false)
        addon:Print("框架已解锁")
    elseif command == "debug" then
        if ns.DebugWindow then
            ns.DebugWindow:Show()
        else
            addon:Print("调试窗口未初始化")
        end
    elseif command == "" then
        -- 打开配置界面
        LibStub("AceConfigDialog-3.0"):Open("WhackAMole")
    else
        -- 显示帮助
        addon:Print("可用命令:")
        addon:Print("  /wam lock/unlock - 锁定/解锁框架")
        addon:Print("  /wam debug - 显示调试窗口")
    end
end

return Lifecycle
