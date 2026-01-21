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
    TITLE_HEIGHT = 30,
    ICON_SIZE = 40,
    ICON_PADDING = 4,
    SPACING = 8,
    CONTENT_TOP_OFFSET = 40,
    UPDATE_INTERVAL = 0.1,
    GCD_THRESHOLD = 1.5,
}

local COLORS = {
    READY = { r = 0.2, g = 0.8, b = 0.2, a = 0.5 },      -- 绿色 - 就绪
    COOLDOWN = { r = 0.2, g = 0.5, b = 0.9, a = 0.5 },   -- 蓝色 - 冷却中
    NO_RESOURCE = { r = 0.6, g = 0.3, b = 0.9, a = 0.5 }, -- 紫色 - 资源不足
    UNUSABLE = { r = 0.6, g = 0.2, b = 0.2, a = 0.5 },   -- 暗红色 - 不可用
    CASTING = { r = 0.9, g = 0.7, b = 0.2, a = 0.6 },    -- 黄色 - 正在施法
}

local TEXT_COLORS = {
    ready = { 0.2, 1, 0.2 },
    cooldown = { 0.4, 0.8, 1 },
    nomana = { 0.8, 0.5, 1 },
    casting = { 1, 0.9, 0.3 },
    unusable = { 1, 0.4, 0.4 },
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
--- 检查技能是否正在施法或引导
local function IsSpellCasting(spellName)
    local castName = UnitCastingInfo("player")
    local channelName = UnitChannelInfo("player")
    return (castName == spellName) or (channelName == spellName)
end

--- 检查技能冷却状态
local function GetSpellCooldownRemaining(spellName)
    local start, duration, enabled = GetSpellCooldown(spellName)
    if start and duration and start > 0 and duration > CONFIG.GCD_THRESHOLD then
        local remaining = math.ceil((start + duration) - GetTime())
        return remaining > 0 and remaining or nil
    end
    return nil
end

--- 获取技能状态信息
-- @param spellId 技能ID
-- @return table 包含状态信息的表 { state, text, color }
local function GetSpellState(spellId)
    local spellName = GetSpellInfo(spellId)
    if not spellName then
        return { state = "unknown", text = "Unknown", color = COLORS.UNUSABLE }
    end
    
    -- 检查施法状态
    if IsSpellCasting(spellName) then
        return { state = "casting", text = "Casting...", color = COLORS.CASTING }
    end
    
    -- 检查冷却状态
    local cdRemaining = GetSpellCooldownRemaining(spellName)
    if cdRemaining then
        return { 
            state = "cooldown", 
            text = string.format("%ds", cdRemaining), 
            color = COLORS.COOLDOWN 
        }
    end
    
    -- 检查可用性
    local usable, nomana = IsUsableSpell(spellName)
    if usable then
        return { state = "ready", text = "Ready", color = COLORS.READY }
    elseif nomana then
        return { state = "nomana", text = "No Resource", color = COLORS.NO_RESOURCE }
    else
        return { state = "unusable", text = "Unusable", color = COLORS.UNUSABLE }
    end
end

-- ============================================================================
-- UI: 更新技能状态
-- ============================================================================
--- 设置状态文本颜色
local function SetStatusTextColor(textWidget, state)
    local color = TEXT_COLORS[state] or TEXT_COLORS.unusable
    textWidget:SetTextColor(unpack(color))
end

--- 更新所有技能框显示
local function UpdateSpellFrames()
    for _, frame in ipairs(spellFrames) do
        local stateInfo = GetSpellState(frame.spellId)
        
        -- 更新背景颜色
        local color = stateInfo.color
        frame.bg:SetVertexColor(color.r, color.g, color.b)
        frame.bg:SetAlpha(color.a)
        
        -- 更新状态文本和颜色
        frame.statusText:SetText(stateInfo.text)
        SetStatusTextColor(frame.statusText, stateInfo.state)
    end
end

-- ============================================================================
-- UI: 创建主框架
-- ============================================================================
--- 创建框架背景和边框
local function CreateFrameBackground(frame)
    -- 外边框
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.4, 0.4, 0.4, 1)
    
    -- 内部背景
    local bg = frame:CreateTexture(nil, "ARTWORK")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)
end

--- 创建标题栏
local function CreateTitleBar(frame)
    -- 标题栏背景
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", -1, -1)
    titleBg:SetHeight(CONFIG.TITLE_HEIGHT)
    titleBg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    
    -- 标题文本
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cFF4FC3F7技能状态监控|r")
end

--- 设置框架可拖动
local function MakeFrameDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

--- 设置更新循环
local function SetupUpdateLoop(frame)
    frame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= CONFIG.UPDATE_INTERVAL then
            UpdateSpellFrames()
            updateTimer = 0
        end
    end)
end

--- 创建主框架
local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "PoCSpellsMonitor", UIParent)
    mainFrame:SetPoint("CENTER", 0, 200)
    mainFrame:SetSize(CONFIG.FRAME_WIDTH, CONFIG.FRAME_HEIGHT)
    
    CreateFrameBackground(mainFrame)
    CreateTitleBar(mainFrame)
    MakeFrameDraggable(mainFrame)
    SetupUpdateLoop(mainFrame)
    
    mainFrame:Show()
end

-- ============================================================================
-- UI: 创建技能框
-- ============================================================================
--- 创建技能图标
local function CreateSpellIcon(frame, spellId)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", CONFIG.ICON_PADDING, 0)
    icon:SetSize(CONFIG.ICON_SIZE - 8, CONFIG.ICON_SIZE - 8)
    
    local _, _, texture = GetSpellInfo(spellId)
    icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    return icon
end

--- 创建技能名称文本
local function CreateSpellNameText(frame, spellId, spellName)
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
    
    local name = GetSpellInfo(spellId)
    nameText:SetText(name or spellName)
    
    return nameText
end

--- 创建状态文本
local function CreateStatusText(frame)
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", -8, 0)
    statusText:SetText("--")
    
    return statusText
end

--- 创建技能监控框
local function CreateSpellFrame(index, spellId, spellName)
    local frame = CreateFrame("Frame", nil, mainFrame)
    local yOffset = -CONFIG.CONTENT_TOP_OFFSET - (index - 1) * (CONFIG.ICON_SIZE + CONFIG.SPACING)
    frame:SetPoint("TOP", 0, yOffset)
    frame:SetSize(240, CONFIG.ICON_SIZE)
    
    -- 背景
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    frame.bg:SetVertexColor(0.3, 0.3, 0.3)
    frame.bg:SetAlpha(0.3)
    
    -- 创建子元素
    frame.icon = CreateSpellIcon(frame, spellId)
    frame.nameText = CreateSpellNameText(frame, spellId, spellName)
    frame.statusText = CreateStatusText(frame)
    
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
