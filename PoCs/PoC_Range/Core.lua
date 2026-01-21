-- ============================================================================
-- PoC_Range - 距离检测验证工具
-- 验证 WotLK 3.3.5 中的距离检测 API
-- ============================================================================

-- ============================================================================
-- 配置常量
-- ============================================================================
local CONFIG = {
    UPDATE_INTERVAL = 0.2,  -- 更新频率（秒）- 5 FPS
    FRAME_WIDTH = 300,
    FRAME_HEIGHT = 200,
    TITLE_HEIGHT = 30,
    CLOSE_BTN_SIZE = 20,
}

local COLORS = {
    TITLE = "|cFF4FC3F7%s|r",         -- 蓝色标题
    DISTANCE = "|cFFFFFF00%s|r",      -- 黄色距离
    HIGHLIGHT = "|cFF00FF00%s|r",     -- 绿色高亮
    GRAY = "|cFF888888%s|r",          -- 灰色
    SECTION = "|cFF00FF00%s|r",       -- 绿色分组标题
}

local RANGE_BRACKETS = {
    { min = 0,  max = 5,   text = "0-5码",   checkIndex = 4 },
    { min = 5,  max = 10,  text = "5-10码",  checkIndex = 3 },
    { min = 10, max = 11,  text = "10-11码", checkIndex = 2 },
    { min = 11, max = 28,  text = "11-28码", checkIndex = 1 },
    { min = 28, max = 100, text = ">28码",   checkIndex = 0 },
}

local CHECK_LABELS = {
    [4] = "Follow (<5码)",
    [3] = "Duel (<10码)",
    [2] = "Trade (<11码)",
    [1] = "Inspect (<28码)",
}

-- ============================================================================
-- 全局变量
-- ============================================================================
local rangeFrame
local lastUpdate = 0
local eventFrame = CreateFrame("Frame")

-- ============================================================================
-- 核心函数 - 距离检测
-- ============================================================================

--- 获取目标距离信息
-- @return table 包含距离区间和检测数据的表
local function GetTargetRange()
    if not UnitExists("target") then
        return {
            exists = false,
            rangeText = "无目标",
            checkData = {}
        }
    end
    
    -- 执行所有距离检测
    local checks = {
        [4] = CheckInteractDistance("target", 4),  -- < 5 码
        [3] = CheckInteractDistance("target", 3),  -- < 10 码
        [2] = CheckInteractDistance("target", 2),  -- < 11 码
        [1] = CheckInteractDistance("target", 1),  -- < 28 码
    }
    
    -- 判断距离区间（距离越近，越多的check为true）
    local rangeText
    if not checks[1] then
        rangeText = ">28码"
    elseif checks[1] and not checks[2] then
        rangeText = "11-28码"
    elseif checks[2] and not checks[3] then
        rangeText = "10-11码"
    elseif checks[3] and not checks[4] then
        rangeText = "5-10码"
    else
        rangeText = "0-5码"
    end
    
    return {
        exists = true,
        rangeText = rangeText,
        checkData = checks,
    }
end

-- ============================================================================
-- UI 创建函数
-- ============================================================================

--- 创建框架背景和边框
local function CreateFrameBackground(frame)
    -- 外层边框
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(0.4, 0.4, 0.4, 1)
    
    -- 主背景
    local bg = frame:CreateTexture(nil, "ARTWORK")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)
    
    -- 标题栏背景
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", -1, -1)
    titleBg:SetHeight(CONFIG.TITLE_HEIGHT)
    titleBg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
end

--- 创建标题和关闭按钮
local function CreateTitleBar(frame)
    -- 标题文字
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    title:SetText(COLORS.TITLE:format("距离检测"))
    
    -- 关闭按钮
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetSize(CONFIG.CLOSE_BTN_SIZE, CONFIG.CLOSE_BTN_SIZE)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
end

--- 创建内容显示区域
local function CreateContentArea(frame)
    -- 主显示 - 距离范围
    frame.mainText = frame:CreateFontString(nil, "OVERLAY")
    frame.mainText:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    frame.mainText:SetPoint("TOP", 0, -50)
    frame.mainText:SetText(COLORS.GRAY:format("--"))
    
    -- 详细信息
    frame.detailText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.detailText:SetPoint("TOP", 0, -90)
    frame.detailText:SetWidth(280)
    frame.detailText:SetJustifyH("LEFT")
    frame.detailText:SetText("")
end

--- 创建主UI框架
local function CreateRangeUI()
    rangeFrame = CreateFrame("Frame", "PoCRangeDisplay", UIParent)
    rangeFrame:SetPoint("CENTER")
    rangeFrame:SetSize(CONFIG.FRAME_WIDTH, CONFIG.FRAME_HEIGHT)
    rangeFrame:SetFrameStrata("MEDIUM")
    rangeFrame:SetFrameLevel(100)
    
    -- 设置可拖动
    rangeFrame:SetMovable(true)
    rangeFrame:EnableMouse(true)
    rangeFrame:RegisterForDrag("LeftButton")
    rangeFrame:SetScript("OnDragStart", rangeFrame.StartMoving)
    rangeFrame:SetScript("OnDragStop", rangeFrame.StopMovingOrSizing)
    
    -- 创建UI元素
    CreateFrameBackground(rangeFrame)
    CreateTitleBar(rangeFrame)
    CreateContentArea(rangeFrame)
    
    rangeFrame:Show()
end

-- ============================================================================
-- UI 更新函数
-- ============================================================================

--- 生成检测详情文本
local function BuildDetailText(rangeInfo)
    local lines = { COLORS.SECTION:format("CheckInteractDistance:") }
    
    for i = 4, 1, -1 do
        local label = CHECK_LABELS[i]
        local isActive = rangeInfo.rangeText == ({
            [4] = "0-5码",
            [3] = "5-10码",
            [2] = "10-11码",
            [1] = "11-28码"
        })[i]
        
        local status
        if isActive then
            status = COLORS.HIGHLIGHT:format(">>> 当前区间")
        elseif rangeInfo.checkData[i] then
            status = COLORS.GRAY:format("✓")
        else
            status = COLORS.GRAY:format("✗")
        end
        
        table.insert(lines, string.format("  [%d] %s: %s", i, label, status))
    end
    
    -- 特殊处理 >28码
    if rangeInfo.rangeText == ">28码" then
        table.insert(lines, "  " .. COLORS.HIGHLIGHT:format(">>> 当前区间: >28码"))
    end
    
    return table.concat(lines, "\n")
end

--- 更新UI显示
local function UpdateRangeDisplay()
    if not rangeFrame or not rangeFrame:IsVisible() then return end
    
    local rangeInfo = GetTargetRange()
    
    if not rangeInfo.exists then
        rangeFrame.mainText:SetText(COLORS.GRAY:format("无目标"))
        rangeFrame.detailText:SetText("")
        return
    end
    
    -- 更新主显示
    rangeFrame.mainText:SetText(COLORS.DISTANCE:format(rangeInfo.rangeText))
    
    -- 更新详细信息
    rangeFrame.detailText:SetText(BuildDetailText(rangeInfo))
end

-- ============================================================================
-- 事件处理和命令
-- ============================================================================

--- OnUpdate回调
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= CONFIG.UPDATE_INTERVAL then
        UpdateRangeDisplay()
        lastUpdate = 0
    end
end)

--- 事件处理
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CreateRangeUI()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateRangeDisplay()
    end
end)

--- Slash命令
SLASH_POCRANGE1 = "/range"
SlashCmdList["POCRANGE"] = function()
    if rangeFrame then
        if rangeFrame:IsVisible() then
            rangeFrame:Hide()
        else
            rangeFrame:Show()
        end
    end
end
