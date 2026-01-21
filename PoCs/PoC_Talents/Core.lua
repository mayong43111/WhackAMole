-- ============================================================================
-- PoC_Talents - 天赋检测与导出工具 (针对 WotLK 3.3.5 / 泰坦服务器优化)
-- ============================================================================

-- ============================================================================
-- 配置常量
-- ============================================================================
local POLL_INTERVAL = 2.0  -- 轮询间隔（秒）
local SCAN_DELAY = 1.0     -- 检测到变化后的扫描延迟（秒）
local LOGIN_DELAY = 2.0    -- 登录后的初始扫描延迟（秒）

-- ============================================================================
-- C_Timer 兼容层 (3.3.5 客户端不支持 C_Timer API)
-- ============================================================================
if not C_Timer then
    C_Timer = {}
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        for i = #timers, 1, -1 do
            local timer = timers[i]
            timer.delay = timer.delay - elapsed
            if timer.delay <= 0 then
                table.remove(timers, i)
                if timer.func then 
                    pcall(timer.func) 
                end
            end
        end
    end)
    
    function C_Timer.After(delay, func)
        table.insert(timers, { delay = delay, func = func })
    end
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 获取当前激活的天赋组 (1 或 2)
local function GetCurrentTalentGroup()
    if GetActiveTalentGroup then
        return GetActiveTalentGroup(false, false) or 1
    end
    return 1
end

-- 构建天赋状态指纹（用于快速比对）
-- 格式: "G1:000123...|000456...|..."
local function BuildTalentFingerprint()
    local group = GetCurrentTalentGroup()
    local fingerprint = "G" .. group .. ":"
    
    for specIndex = 1, 3 do
        local numTalents = GetNumTalents(specIndex) or 0
        if numTalents > 0 then
            for talentIndex = 1, numTalents do
                local _, _, _, _, rank = GetTalentInfo(specIndex, talentIndex, false, false, group)
                fingerprint = fingerprint .. (rank or "0")
            end
        end
        fingerprint = fingerprint .. "|"
    end
    
    return fingerprint
end

-- 扫描单个天赋页
-- 返回: isValid, tabName, pointsSpent, exportString
local function ScanTalentTab(tabIndex, activeGroup)
    -- 尝试获取天赋页基本信息
    local _, name, _, _, points = GetTalentTabInfo(tabIndex, false, false, activeGroup)
    
    -- Fallback: 不带 group 参数重试
    if not points then
        _, name, _, _, points = GetTalentTabInfo(tabIndex)
    end
    
    -- 深度扫描：逐个天赋节点
    local numTalents = GetNumTalents(tabIndex) or 0
    if numTalents == 0 then
        return false, name or "未知", 0, ""
    end
    
    local totalPoints = 0
    local exportString = ""
    
    for talentIndex = 1, numTalents do
        local _, _, _, _, rank, maxRank = GetTalentInfo(tabIndex, talentIndex, false, false, activeGroup)
        
        -- 数据验证：maxRank 为 nil 表示数据未就绪
        if not maxRank then
            return false, name or "未知", 0, ""
        end
        
        rank = rank or 0
        if rank > 0 then
            totalPoints = totalPoints + rank
        end
        exportString = exportString .. rank
    end
    
    return true, name or "未知", totalPoints, exportString
end

-- ============================================================================
-- 核心功能：完整天赋扫描
-- ============================================================================
local lastFingerprint = nil

local function ScanTalents()
    print("PoC_Talents: 开始扫描天赋...")
    
    local activeGroup = GetCurrentTalentGroup()
    print("当前天赋组: " .. activeGroup)
    
    local logs = {}
    local exportParts = {}
    local allValid = true
    
    -- 扫描三个天赋页
    for tabIndex = 1, 3 do
        local isValid, name, points, exportStr = ScanTalentTab(tabIndex, activeGroup)
        
        if not isValid then
            allValid = false
            print(string.format("  天赋页 %d (%s) 数据未就绪", tabIndex, name))
            break
        end
        
        table.insert(logs, string.format("天赋页 %d (%s): %d 点", tabIndex, name, points))
        table.insert(exportParts, exportStr)
    end
    
    -- 数据未就绪时自动重试
    if not allValid then
        print("数据未就绪，1秒后重试...")
        C_Timer.After(SCAN_DELAY, ScanTalents)
        return
    end
    
    -- 打印结果
    for _, log in ipairs(logs) do
        print(log)
    end
    
    local exportString = table.concat(exportParts, "-")
    print("导出字符串: " .. exportString)
    print("扫描完成。")
    
    -- 更新指纹
    lastFingerprint = BuildTalentFingerprint()
end

-- ============================================================================
-- 轮询检测系统 (针对泰坦服务器，标准事件不可用)
-- ============================================================================
local pollFrame = CreateFrame("Frame")
local elapsed = 0

pollFrame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < POLL_INTERVAL then 
        return 
    end
    
    elapsed = 0
    local currentFingerprint = BuildTalentFingerprint()
    
    -- 检测到变化
    if lastFingerprint and lastFingerprint ~= currentFingerprint then
        print("|cff00ff00[PoC_Talents]|r 检测到天赋变化")
        C_Timer.After(SCAN_DELAY, ScanTalents)
    end
    
    lastFingerprint = currentFingerprint
end)

pollFrame:Hide()  -- 默认隐藏，登录后启动

-- ============================================================================
-- 事件系统
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00[PoC_Talents]|r 已加载")
        
        C_Timer.After(LOGIN_DELAY, function()
            ScanTalents()
            print("|cff00ff00[PoC_Talents]|r 启动轮询检测 (间隔 " .. POLL_INTERVAL .. " 秒)")
            pollFrame:Show()
        end)
    end
end)

-- ============================================================================
-- 斜杠命令
-- ============================================================================
SLASH_POCTALENT1 = "/poctalent"
SlashCmdList["POCTALENT"] = ScanTalents
