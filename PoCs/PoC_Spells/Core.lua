-- ============================================================================
-- PoC_Spells - 技能状态检测验证工具
-- ============================================================================
-- 验证 IsUsableSpell、GetSpellCooldown、UnitCastingInfo 等核心 API
-- ============================================================================

-- ============================================================================
-- 配置
-- ============================================================================
local MONITOR_SPELLS = {
    { id = 12294, name = "Mortal Strike" },   -- 致死打击
    { id = 1464,  name = "Slam" },            -- 猛击
    { id = 5308,  name = "Execute" },         -- 斩杀
    { id = 46924, name = "Bladestorm" },      -- 利刃风暴
}

local CONFIG = {
    FRAME_WIDTH = 280,
    FRAME_HEIGHT = 240,
    ICON_SIZE = 40,
    SPACING = 8,
    UPDATE_INTERVAL = 0.1,  -- 更新频率（秒）
}

local COLORS = {
    READY = { r = 0.2, g = 0.8, b = 0.2, a = 0.5 },      -- 绿色 - 就绪
    COOLDOWN = { r = 0.2, g = 0.5, b = 0.9, a = 0.5 },   -- 蓝色 - 冷却中
    NO_RESOURCE = { r = 0.6, g = 0.3, b = 0.9, a = 0.5 }, -- 紫色 - 资源不足
    UNUSABLE = { r = 0.6, g = 0.2, b = 0.2, a = 0.5 },   -- 暗红色 - 不可用
    CASTING = { r = 0.9, g = 0.7, b = 0.2, a = 0.6 },    -- 黄色 - 正在施法
}

-- ============================================================================
-- 全局变量
-- ============================================================================
local mainFrame
local spellFrames = {}
local updateTimer = 0

-- ============================================================================
-- 工具函数：检测技能状态
-- ============================================================================
--- 获取技能状态信息
-- @param spellId 技能ID
-- @return table 包含状态信息的表 { state, text, color }
local function GetSpellState(spellId)
    local spellName = GetSpellInfo(spellId)
    if not spellName then
        return { state = "unknown", text = "Unknown", color = COLORS.UNUSABLE }
    end
    
    -- 检查是否正在施法
    local castName = UnitCastingInfo("player")
    local channelName = UnitChannelInfo("player")
    if (castName and castName == spellName) or (channelName and channelName == spellName) then
        return { state = "casting", text = "Casting...", color = COLORS.CASTING }
    end
    
    -- 检查冷却
    local start, duration, enabled = GetSpellCooldown(spellName)
    if start and duration and start > 0 and duration > 1.5 then  -- 排除GCD
        local remaining = math.ceil((start + duration) - GetTime())
        if remaining > 0 then
            return { 
                state = "cooldown", 
                text = string.format("%ds", remaining), 
                color = COLORS.COOLDOWN 
            }
        end
    end
    
    -- 检查可用性
    local usable, nomana = IsUsableSpell(spellName)
    
    if usable then
        -- 技能就绪
        return { state = "ready", text = "Ready", color = COLORS.READY }
    elseif nomana then
        -- 资源不足
        return { state = "nomana", text = "No Resource", color = COLORS.NO_RESOURCE }
    else
        -- 不可用（条件不满足）
        return { state = "unusable", text = "Unusable", color = COLORS.UNUSABLE }
    end
end

-- ============================================================================
-- UI: 更新技能状态
-- ============================================================================
local function UpdateSpellFrames()
    for _, frame in ipairs(spellFrames) do
        local stateInfo = GetSpellState(frame.spellId)
        
        -- 更新背景颜色
        local color = stateInfo.color
        frame.bg:SetVertexColor(color.r, color.g, color.b)
        frame.bg:SetAlpha(color.a)
        
        -- 更新状态文本
        frame.statusText:SetText(stateInfo.text)
        
        -- 设置文本颜色
        if stateInfo.state == "ready" then
            frame.statusText:SetTextColor(0.2, 1, 0.2)
        elseif stateInfo.state == "cooldown" then
            frame.statusText:SetTextColor(0.4, 0.8, 1)
        elseif stateInfo.state == "nomana" then
            frame.statusText:SetTextColor(0.8, 0.5, 1)
        elseif stateInfo.state == "casting" then
            frame.statusText:SetTextColor(1, 0.9, 0.3)
        else
            frame.statusText:SetTextColor(1, 0.4, 0.4)
        end
    end
end

-- ============================================================================
-- UI: 创建主框架
-- ============================================================================
local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "PoCSpellsMonitor", UIParent)
    mainFrame:SetPoint("CENTER", 0, 200)
    mainFrame:SetSize(CONFIG.FRAME_WIDTH, CONFIG.FRAME_HEIGHT)
    
    -- 背景
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- 边框
    local border = mainFrame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.4, 0.4, 0.4, 1)
    
    local innerBg = mainFrame:CreateTexture(nil, "ARTWORK")
    innerBg:SetPoint("TOPLEFT", 1, -1)
    innerBg:SetPoint("BOTTOMRIGHT", -1, 1)
    innerBg:SetColorTexture(0.12, 0.12, 0.12, 0.95)
    
    -- 标题栏
    local titleBg = mainFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", -1, -1)
    titleBg:SetHeight(30)
    titleBg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cFF4FC3F7技能状态监控|r")
    
    -- 可拖动
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    
    -- 更新循环
    mainFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= CONFIG.UPDATE_INTERVAL then
            UpdateSpellFrames()
            updateTimer = 0
        end
    end)
    
    mainFrame:Show()
end

-- ============================================================================
-- UI: 创建技能框
-- ============================================================================
local function CreateSpellFrame(index, spellId, spellName)
    local frame = CreateFrame("Frame", nil, mainFrame)
    local yOffset = -40 - (index - 1) * (CONFIG.ICON_SIZE + CONFIG.SPACING)
    frame:SetPoint("TOP", 0, yOffset)
    frame:SetSize(240, CONFIG.ICON_SIZE)
    
    -- 背景
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    frame.bg:SetVertexColor(0.3, 0.3, 0.3)
    frame.bg:SetAlpha(0.3)
    
    -- 技能图标
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("LEFT", 4, 0)
    frame.icon:SetSize(CONFIG.ICON_SIZE - 8, CONFIG.ICON_SIZE - 8)
    
    -- 获取技能信息
    local name, rank, icon = GetSpellInfo(spellId)
    if icon then
        frame.icon:SetTexture(icon)
    else
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- 技能名称
    frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.nameText:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
    frame.nameText:SetText(name or spellName)
    
    -- 状态文本
    frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.statusText:SetPoint("RIGHT", -8, 0)
    frame.statusText:SetText("--")
    
    frame.spellId = spellId
    frame.spellName = spellName
    
    return frame
end

-- ============================================================================
-- 初始化
-- ============================================================================
local function Initialize()
    CreateMainFrame()
    
    -- 创建技能监控框
    for i, spell in ipairs(MONITOR_SPELLS) do
        local frame = CreateSpellFrame(i, spell.id, spell.name)
        table.insert(spellFrames, frame)
    end
    
    print("|cFF00FF00[PoC_Spells]|r 技能状态监控已加载")
    print("|cFF888888命令:|r /pocspell show/hide - 显示/隐藏窗口")
end

-- ============================================================================
-- 事件处理
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
    end
end)

-- ============================================================================
-- Slash 命令
-- ============================================================================
SLASH_POCSPELL1 = "/pocspell"
SlashCmdList["POCSPELL"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "show" then
        if mainFrame then
            mainFrame:Show()
            print("|cFF00FF00[PoC_Spells]|r 窗口已显示")
        end
    elseif msg == "hide" then
        if mainFrame then
            mainFrame:Hide()
            print("|cFF00FF00[PoC_Spells]|r 窗口已隐藏")
        end
    else
        print("|cFF00FF00[PoC_Spells]|r 用法:")
        print("  /pocspell show - 显示监控窗口")
        print("  /pocspell hide - 隐藏监控窗口")
    end
end
