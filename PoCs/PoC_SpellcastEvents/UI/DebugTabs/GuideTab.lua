-- ============================================================================
-- GuideTab - 测试指导页签
-- ============================================================================
local addonName, ns = ...

local GuideTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.GuideTab = GuideTab

--- 创建测试指导页签
-- @param container 父容器
-- @param State 全局状态
-- @param ScenarioRegistry 场景注册表
function GuideTab:Create(container, State, ScenarioRegistry)
    -- 创建滚动容器
    local scrollContainer = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollContainer:SetPoint("TOPLEFT", 10, -10)
    scrollContainer:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- 内容框架
    local content = CreateFrame("Frame", nil, scrollContainer)
    content:SetSize(scrollContainer:GetWidth() - 20, 600)
    scrollContainer:SetScrollChild(content)
    
    -- 标题
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("施法事件测试指导")
    title:SetTextColor(0, 1, 0)
    
    -- 说明
    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", 0, -35)
    desc:SetText("请按照以下场景进行测试，状态会自动更新")
    
    -- 表头
    local headerY = -65
    local headers = {
        {x = 20, text = "场景"},
        {x = 180, text = "描述"},
        {x = -20, text = "状态", align = "RIGHT"}
    }
    
    for _, header in ipairs(headers) do
        local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOP" .. (header.align == "RIGHT" and "RIGHT" or "LEFT"), header.x, headerY)
        text:SetText(header.text)
        text:SetTextColor(1, 0.8, 0)
    end
    
    -- 动态生成场景行
    local yOffset = -90
    for _, scenario in ipairs(ScenarioRegistry:GetAll()) do
        local row = {}
        
        row.nameText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("TOPLEFT", 20, yOffset)
        row.nameText:SetText(scenario.name)
        row.nameText:SetWidth(150)
        row.nameText:SetJustifyH("LEFT")
        
        row.descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.descText:SetPoint("TOPLEFT", 180, yOffset)
        row.descText:SetText(scenario.description)
        row.descText:SetTextColor(0.8, 0.8, 0.8)
        row.descText:SetWidth(320)
        row.descText:SetJustifyH("LEFT")
        row.descText:SetWordWrap(true)
        row.descText:SetMaxLines(3)
        
        row.statusText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.statusText:SetPoint("TOPRIGHT", -20, yOffset)
        row.statusText:SetText("未测试")
        row.statusText:SetTextColor(0.6, 0.6, 0.6)
        
        State.scenarioRows[scenario.id] = row
        
        -- 使用场景自定义的行高，默认为 30
        local rowHeight = (scenario.module and scenario.module.rowHeight) or 30
        yOffset = yOffset - rowHeight
    end
    
    -- 调整内容高度以适应所有场景
    local totalHeight = math.abs(yOffset) + 50
    content:SetHeight(totalHeight)
end

return GuideTab
