local _, ns = ...

-- Core/SpecDetection.lua
-- Encapsulated logic for detecting player specialization
-- 基于 PoC_Talents 验证结果实现天赋变化检测

ns.SpecDetection = {}

-- =========================================================================
-- 常量定义（基于 PoC_Talents 验证结果）
-- =========================================================================
local POLL_INTERVAL = 2.0    -- 轮询间隔（秒）
local SCAN_DELAY = 1.0       -- 检测到变化后延迟扫描（秒）
local LOGIN_DELAY = 2.0      -- 登录后延迟首次扫描（秒）
local MAX_RETRY = 3          -- 数据未就绪时最大重试次数

-- =========================================================================
-- 内部状态
-- =========================================================================
local lastFingerprint = nil  -- 上次天赋指纹
local lastSpecID = nil       -- 上次检测的专精ID
local retryCount = 0         -- 重试计数器

-- =========================================================================
-- 工具函数（基于 PoC_Talents 验证结果）
-- =========================================================================

--- 获取当前激活的天赋组 (1 或 2)
local function GetCurrentTalentGroup()
    if GetActiveTalentGroup then
        return GetActiveTalentGroup(false, false) or 1
    end
    return 1
end

--- 构建天赋指纹（用于快速比对变化）
-- 格式: "G1:000123...|000456...|..."
-- 基于 PoC_Talents/Core.lua:53-68
local function BuildTalentFingerprint()
    local group = GetCurrentTalentGroup()
    local fingerprint = "G" .. group .. ":"
    
    for tabIndex = 1, 3 do
        local numTalents = GetNumTalents(tabIndex) or 0
        if numTalents > 0 then
            for talentIndex = 1, numTalents do
                local _, _, _, _, rank, maxRank = GetTalentInfo(tabIndex, talentIndex, false, false, group)
                
                -- 数据未就绪检测
                if not maxRank then
                    return nil  -- 返回 nil 表示数据未就绪
                end
                
                fingerprint = fingerprint .. (rank or "0")
            end
        end
        fingerprint = fingerprint .. "|"
    end
    
    return fingerprint
end

-- =========================================================================
-- 核心功能：专精检测
-- =========================================================================

--- 获取玩家当前专精ID
-- @param isDebug 是否输出调试信息
-- @param skipRetry 跳过重试机制（内部递归调用时使用）
-- @return number|nil 专精ID，失败返回 nil
function ns.SpecDetection:GetSpecID(isDebug, skipRetry)
    local _, playerClass = UnitClass("player")
    
    local maxPoints = -1
    local specIndex = 1
    local activeGroup = GetCurrentTalentGroup()
    
    -- 检测数据是否就绪
    local dataReady = true
    
    -- Scan Tabs
    for i = 1, 3 do
        -- Method 1: Standard API with Active Group
        local _, _, points = GetTalentTabInfo(i, false, false, activeGroup)
        
        -- Fallback A: Try without group arg if points is nil
        if not points then 
            _, _, points = GetTalentTabInfo(i)
        end
        
        -- Method 2: Manual Scan (Deep Search) - FORCE if points is 0 or nil
        if not points or points == 0 then
             local numTalents = GetNumTalents(i) or 0
             local total = 0
             for t = 1, numTalents do
                 local _, _, _, _, rank, maxRank = GetTalentInfo(i, t, false, false, activeGroup)
                 
                 -- 数据未就绪检测（基于 PoC_Talents 验证）
                 if not maxRank then
                     dataReady = false
                     break
                 end
                 
                 if not rank then
                     -- Try without group
                     _, _, _, _, rank = GetTalentInfo(i, t)
                 end

                 if rank then 
                    total = total + rank 
                 end
             end
             
             if not dataReady then
                 break
             end
             
             if total > 0 then 
                points = total 
             end
        end

        points = tonumber(points) or 0
        
        if points > maxPoints then
            maxPoints = points
            specIndex = i
        end
    end
    
    -- 数据未就绪时重试（基于 PoC_Talents 验证结果）
    if not dataReady and not skipRetry then
        retryCount = retryCount + 1
        if retryCount <= MAX_RETRY then
            if isDebug then 
                ns.Logger:System(string.format("WhackAMole: 天赋数据未就绪，%d秒后重试 (第%d/%d次)", SCAN_DELAY, retryCount, MAX_RETRY))
            end
            
            -- 使用 C_Timer.After 延迟重试
            if C_Timer and C_Timer.After then
                C_Timer.After(SCAN_DELAY, function()
                    local specID = ns.SpecDetection:GetSpecID(isDebug, false)
                    if specID then
                        -- 触发专精变化事件
                        ns.SpecDetection:OnSpecChanged(specID)
                    end
                end)
            end
            return nil
        else
            if isDebug then 
                ns.Logger:System("WhackAMole: 天赋数据重试失败，已达最大重试次数")
            end
            retryCount = 0  -- 重置计数器
        end
    end
    
    -- 重置重试计数器（成功获取数据）
    if dataReady then
        retryCount = 0
    end
    
    -- Method 3: Spell Book Heuristics (Final Fallback)
    if maxPoints <= 10 then 
        local detectedSpec = ns.SpecRegistry and ns.SpecRegistry:Detect(playerClass)
        if detectedSpec then
             if isDebug then ns.Logger:System("WhackAMole Debug: Heuristic detected spec: " .. detectedSpec) end
            return detectedSpec
        end
    end
    
    -- 低等级玩家降级方案（基于 TODO.md 任务 0.3 要求）
    if maxPoints <= 0 then
        if UnitLevel("player") <= 10 then
            if isDebug then ns.Logger:System("WhackAMole Debug: 低等级角色，返回默认专精") end
            -- 返回第一个专精作为默认值
            return ns.SpecDetection:GetDefaultSpecID(playerClass)
        elseif UnitLevel("player") > 10 then
            if isDebug then ns.Logger:System("WhackAMole Debug: Spec Detection Failed (MaxPoints="..maxPoints..")") end
            return nil
        end
    end
    
    -- Map Index to SpecID based on highest points tab
    local specID = 0
    -- WotLK 3.3.5 Spec IDs Mapping
    if playerClass == "WARRIOR" then
        specID = (specIndex == 1) and 71 or ((specIndex == 2 and 72) or 73)
    elseif playerClass == "PALADIN" then
        specID = (specIndex == 1) and 65 or ((specIndex == 2 and 66) or 70)
    elseif playerClass == "HUNTER" then
        specID = (specIndex == 1) and 253 or ((specIndex == 2 and 254) or 255)
    elseif playerClass == "ROGUE" then
        specID = (specIndex == 1) and 259 or ((specIndex == 2 and 260) or 261)
    elseif playerClass == "PRIEST" then
        specID = (specIndex == 1) and 256 or ((specIndex == 2 and 257) or 258)
    elseif playerClass == "DEATHKNIGHT" then
        specID = (specIndex == 1) and 250 or ((specIndex == 2 and 251) or 252)
    elseif playerClass == "SHAMAN" then
        specID = (specIndex == 1) and 262 or ((specIndex == 2 and 263) or 264)
    elseif playerClass == "MAGE" then
        specID = (specIndex == 1) and 62 or ((specIndex == 2 and 63) or 64)
    elseif playerClass == "WARLOCK" then
        specID = (specIndex == 1) and 265 or ((specIndex == 2 and 266) or 267)
    elseif playerClass == "DRUID" then
        specID = (specIndex == 1) and 102 or ((specIndex == 2 and 103) or 105)
    end
    
    -- 更新缓存的专精ID
    lastSpecID = specID
    
    return specID
end

--- 获取职业的默认专精ID（用于低等级角色）
-- @param playerClass 职业名称
-- @return number 默认专精ID（第一个专精）
function ns.SpecDetection:GetDefaultSpecID(playerClass)
    local defaults = {
        WARRIOR = 71,      -- 武器
        PALADIN = 65,      -- 神圣
        HUNTER = 253,      -- 野兽控制
        ROGUE = 259,       -- 刺杀
        PRIEST = 256,      -- 戒律
        DEATHKNIGHT = 250, -- 鲜血
        SHAMAN = 262,      -- 元素
        MAGE = 62,         -- 奥术
        WARLOCK = 265,     -- 痛苦
        DRUID = 102        -- 平衡
    }
    return defaults[playerClass] or 0
end

-- =========================================================================
-- 轮询检测系统（基于 PoC_Talents 验证结果）
-- =========================================================================

--- 启动天赋变化轮询检测
-- 基于 PoC_Talents/Core.lua:160-182
function ns.SpecDetection:StartPolling()
    if self.pollFrame then
        return  -- 已经启动
    end
    
    -- 创建轮询Frame
    self.pollFrame = CreateFrame("Frame")
    local elapsed = 0
    
    self.pollFrame:SetScript("OnUpdate", function(frame, dt)
        elapsed = elapsed + dt
        if elapsed < POLL_INTERVAL then 
            return 
        end
        
        elapsed = 0
        local currentFingerprint = BuildTalentFingerprint()
        
        -- 数据未就绪，跳过本次检查
        if not currentFingerprint then
            return
        end
        
        -- 检测到变化
        if lastFingerprint and lastFingerprint ~= currentFingerprint then
            ns.Logger:System("|cff00ff00[WhackAMole]|r 检测到天赋变化，重新扫描专精...")
            
            -- 延迟扫描（避免数据未就绪）
            if C_Timer and C_Timer.After then
                C_Timer.After(SCAN_DELAY, function()
                    local newSpecID = ns.SpecDetection:GetSpecID(false, false)
                    if newSpecID and newSpecID ~= lastSpecID then
                        ns.SpecDetection:OnSpecChanged(newSpecID)
                    end
                end)
            end
        end
        
        lastFingerprint = currentFingerprint
    end)
    
    self.pollFrame:Show()
end

--- 停止轮询检测
function ns.SpecDetection:StopPolling()
    if self.pollFrame then
        self.pollFrame:Hide()
        self.pollFrame = nil
    end
end

--- 专精变化回调（供外部覆盖）
-- @param newSpecID 新的专精ID
function ns.SpecDetection:OnSpecChanged(newSpecID)
    ns.Logger:System(string.format("|cff00ff00[WhackAMole]|r 专精变化: %d -> %d", lastSpecID or 0, newSpecID))
    
    -- 触发事件通知Core重新加载
    if ns.Core and ns.Core.OnSpecChanged then
        ns.Core:OnSpecChanged(newSpecID)
    end
end

--- 初始化（登录后延迟启动）
-- 基于 PoC_Talents/Core.lua:191-203
function ns.SpecDetection:Initialize()
    -- 延迟首次扫描和启动轮询
    if C_Timer and C_Timer.After then
        C_Timer.After(LOGIN_DELAY, function()
            -- 首次扫描
            local specID = self:GetSpecID(false, false)
            if specID then
                lastSpecID = specID
                lastFingerprint = BuildTalentFingerprint()
            end
            
            -- 启动轮询
            self:StartPolling()
        end)
    else
        -- 降级方案：立即扫描
        local specID = self:GetSpecID(false, false)
        if specID then
            lastSpecID = specID
            lastFingerprint = BuildTalentFingerprint()
        end
        self:StartPolling()
    end
end
