-- ============================================================================
-- PoC_Spells - 技能可用性验证工具
-- ============================================================================
-- 验证技能基础条件（怒气/法力/CD/距离）以及天赋触发时的特殊可用性状态
-- ============================================================================

local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("PLAYER_LOGIN")
addonFrame:RegisterEvent("UNIT_AURA")
addonFrame:RegisterEvent("UNIT_POWER_UPDATE")
addonFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
addonFrame:RegisterEvent("UNIT_HEALTH")

-- ============================================================================
-- 监控配置
-- ============================================================================
local monitorSpells = {
    -- 战士技能
    { id = 5308, name = "Execute" },           -- 斩杀
    { id = 7384, name = "Overpower" },         -- 压制
    { id = 1464, name = "Slam" },              -- 猛击
    { id = 12294, name = "Mortal Strike" },    -- 致死打击
    { id = 47450, name = "Heroic Strike" },    -- 英勇打击
    
    -- 你可以在这里添加更多要监控的技能
}

local monitorFrames = {}
local UPDATE_INTERVAL = 0.1  -- 更新频率（秒）
local lastUpdate = 0

-- ============================================================================
-- Helper: 扫描玩家 Buff (参考 WeakAuras 实现)
-- ============================================================================
local function GetPlayerBuff(spellNameOrId)
    local i = 1
    while true do
        local name, rank, icon, count, debuffType, duration, expirationTime, source = UnitBuff("player", i)
        if not name then return nil end
        
        -- WotLK 3.3.5 API 不返回 spellId (第11个参数)，只能通过名称匹配
        local targetName = type(spellNameOrId) == "number" and GetSpellInfo(spellNameOrId) or spellNameOrId
        if name == targetName then
            local remains = expirationTime > 0 and (expirationTime - GetTime()) or 0
            return {
                name = name,
                rank = rank,
                count = count or 1,
                duration = duration or 0,
                expirationTime = expirationTime or 0,
                remains = remains,
                source = source
            }
        end
        i = i + 1
        if i > 40 then break end -- WotLK 光环上限
    end
    return nil
end

-- ============================================================================
-- Helper: 获取玩家资源（怒气/法力/能量等）
-- ============================================================================
local function GetPlayerResource()
    local powerType = UnitPowerType("player")
    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)
    
    local powerNames = { [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [6] = "Runic Power" }
    local powerName = powerNames[powerType] or "Unknown"
    
    return {
        type = powerType,
        typeName = powerName,
        current = current,
        max = max
    }
end

-- ============================================================================
-- Helper: 获取目标状态和距离
-- ============================================================================
local function GetTargetInfo()
    if not UnitExists("target") then
        return { exists = false, health_pct = 0, range = nil, rangeText = "无目标" }
    end
    
    local health = UnitHealth("target")
    local healthMax = UnitHealthMax("target")
    local health_pct = healthMax > 0 and (health / healthMax * 100) or 0
    
    -- 距离估算（参考 HunterAssist 和 LibRangeCheck）
    -- WotLK 3.3.5 无法获取精确距离，只能通过 CheckInteractDistance 估算范围
    local rangeMin, rangeMax = 0, 0
    local rangeText = ""
    
    if not UnitCanAttack("player", "target") then
        -- 友方单位
        if CheckInteractDistance("target", 4) then -- < 5 码 (Follow)
            rangeMin, rangeMax = 0, 5
            rangeText = "0-5码"
        elseif CheckInteractDistance("target", 3) then -- < 10 码 (Duel)
            rangeMin, rangeMax = 5, 10
            rangeText = "5-10码"
        elseif CheckInteractDistance("target", 2) then -- < 11.11 码 (Trade)
            rangeMin, rangeMax = 10, 11
            rangeText = "10-11码"
        elseif CheckInteractDistance("target", 1) then -- < 28 码 (Inspect)
            rangeMin, rangeMax = 11, 28
            rangeText = "11-28码"
        else
            rangeMin, rangeMax = 28, 100
            rangeText = ">28码"
        end
    else
        -- 敌对单位
        if CheckInteractDistance("target", 3) then -- < 10 码 (Duel)
            rangeMin, rangeMax = 0, 10
            rangeText = "0-10码"
        elseif CheckInteractDistance("target", 2) then -- < 11.11 码 (Trade)
            rangeMin, rangeMax = 10, 11
            rangeText = "10-11码"
        elseif CheckInteractDistance("target", 1) then -- < 28 码 (Inspect)
            rangeMin, rangeMax = 11, 28
            rangeText = "11-28码"
        else
            rangeMin, rangeMax = 28, 100
            rangeText = ">28码"
        end
    end
    
    return {
        exists = true,
        health = health,
        healthMax = healthMax,
        health_pct = health_pct,
        range = (rangeMin + rangeMax) / 2, -- 中间值用于逻辑判断
        rangeMin = rangeMin,
        rangeMax = rangeMax,
        rangeText = rangeText
    }
end

-- ============================================================================
-- 核心测试函数
-- ============================================================================
local function TestSpell(id)
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(id)
    if not name then 
        print("|cFFFF0000[PoC_Spells]|r Spell " .. tostring(id) .. " not found.")
        return 
    end
    
    print("|cFF00FF00========================================|r")
    print(string.format("|cFFFFFF00Spell:|r %s |cFF888888(Rank: %s)|r", name, rank or "N/A"))
    print(string.format("|cFF888888Cost:|r %s %s | |cFF888888Cast Time:|r %.1fs", 
        cost or 0, powerType == 1 and "Rage" or (powerType == 0 and "Mana" or ""), (castTime or 0) / 1000))
    print(string.format("|cFF888888Range:|r %s - %s yards", minRange or 0, maxRange or 0))
    
    -- 1. Usable Check (基础资源/姿态/条件检查)
    local usable, nomana = IsUsableSpell(name)
    local usableText = usable and "|cFF00FF00可用|r" or "|cFFFF0000不可用|r"
    local resourceText = nomana and " |cFF0088FF(资源不足)|r" or ""
    print(string.format("|cFFFFFF00IsUsableSpell:|r %s%s", usableText, resourceText))
    
    -- 2. Cooldown Check
    local start, duration, enabled = GetSpellCooldown(name)
    local cdRemains = 0
    if start and start > 0 and duration and duration > 1.5 then
        cdRemains = math.max(0, (start + duration) - GetTime())
    end
    local cdText = cdRemains > 0 and string.format("|cFFFF8800%.1fs|r", cdRemains) or "|cFF00FF00就绪|r"
    print(string.format("|cFFFFFF00Cooldown:|r %s (Start: %.1f, Duration: %.1f)", cdText, start or 0, duration or 0))
    
    -- 3. Range Check (如果有目标)
    local target = GetTargetInfo()
    if target.exists then
        local inRange = IsSpellInRange(name, "target")
        local rangeText = inRange == 1 and "|cFF00FF00在范围内|r" or (inRange == 0 and "|cFFFF0000超出范围|r" or "|cFF888888无法判断|r")
        print(string.format("|cFFFFFF00Range Check:|r %s (Target: %.1f%% | 距离: %s)", rangeText, target.health_pct, target.rangeText))
    else
        print("|cFFFFFF00Range Check:|r |cFF888888无目标|r")
    end
    
    -- 4. 资源状态
    local resource = GetPlayerResource()
    print(string.format("|cFFFFFF00Player Resource:|r %s (%d / %d)", resource.typeName, resource.current, resource.max))
    
    -- 5. 特殊 Buff 检测 (用于天赋触发)
    print("|cFFFFFF00Talent Proc Buffs:|r")
    
    -- 常见天赋触发 Buff（示例）
    local commonProcs = {
        [52437] = "猝死 (Sudden Death)",           -- 战士：允许斩杀
        [60503] = "血之气息 (Taste for Blood)",    -- 战士：允许压制
        [57933] = "毁灭 (Decimation)",             -- 战士：处决狂暴减少费用
        [46916] = "血腥冲锋 (Bloodsurge)",         -- 战士：猛击瞬发
        [49284] = "深寒之风 (Freezing Fog)",       -- DK：凛风打击瞬发
        [51124] = "杀戮机器 (Killing Machine)",    -- DK：冰霜打击暴击
        [49016] = "符文涌动 (Hysteria)",           -- DK：20% 攻击速度
        [64823] = "苦行 (Elune's Wrath)",          -- 德鲁伊：愤怒瞬发
        [48517] = "日蚀 (Eclipse Solar)",          -- 德鲁伊：星火增强
        [48518] = "月蚀 (Eclipse Lunar)",          -- 德鲁伊：愤怒增强
        [54741] = "火焰冲击! (Lava Burst!)",       -- 萨满：熔岩爆裂瞬发
        [53817] = "漩涡武器 (Maelstrom Weapon)",   -- 萨满：闪电箭瞬发
        [44544] = "导弹连击! (Missile Barrage!)",  -- 法师：奥术飞弹瞬发
        [44401] = "导弹连击 (Missile Barrage)",    -- 法师：奥术飞弹瞬发 (旧)
        [48108] = "炎爆术! (Hot Streak!)",         -- 法师：炎爆术瞬发
        [57761] = "脑部冻结 (Brain Freeze)",       -- 法师：火球术瞬发
    }
    
    local foundProc = false
    for spellId, description in pairs(commonProcs) do
        local buff = GetPlayerBuff(spellId)
        if buff then
            foundProc = true
            print(string.format("  |cFF00FF00✓|r %s |cFF888888(%.1fs)|r", description, buff.remains))
        end
    end
    
    if not foundProc then
        print("  |cFF888888(无活动 Proc)|r")
    end
    
    print("|cFF00FF00========================================|r")
end

-- ============================================================================
-- UI: 创建监控框架
-- ============================================================================
local mainFrame
local rangeFrame

local function CreateRangeDisplay()
    -- 距离显示框
    rangeFrame = CreateFrame("Frame", "PoCSpellsRangeDisplay", UIParent)
    rangeFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, 237)
    rangeFrame:SetWidth(150)
    rangeFrame:SetHeight(30)
    rangeFrame:SetMovable(true)
    rangeFrame:EnableMouse(true)
    rangeFrame:RegisterForDrag("LeftButton")
    rangeFrame:SetScript("OnDragStart", rangeFrame.StartMoving)
    rangeFrame:SetScript("OnDragStop", rangeFrame.StopMovingOrSizing)
    
    -- 背景条
    rangeFrame.bg = rangeFrame:CreateTexture(nil, "BACKGROUND")
    rangeFrame.bg:SetAllPoints()
    rangeFrame.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rangeFrame.bg:SetVertexColor(1, 0.85, 0)
    
    -- 边框
    rangeFrame.border = rangeFrame:CreateTexture(nil, "ARTWORK")
    rangeFrame.border:SetTexture("Interface\\Tooltips\\UI-StatusBar-Border")
    rangeFrame.border:SetAllPoints()
    
    -- 文字
    rangeFrame.text = rangeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rangeFrame.text:SetPoint("CENTER", 0, 1)
    rangeFrame.text:SetJustifyH("CENTER")
    rangeFrame.text:SetText("距离: --")
    
    rangeFrame:Show()
end

local function UpdateRangeDisplay()
    if not rangeFrame then return end
    
    local target = GetTargetInfo()
    if target.exists then
        rangeFrame.text:SetText(string.format("|cFFFFFF00距离:|r %s", target.rangeText))
        rangeFrame:SetAlpha(1.0)
        
        -- 根据距离改变颜色
        if target.rangeMax <= 5 then
            rangeFrame.bg:SetVertexColor(0.8, 0.2, 0.2) -- 红色 (近战范围)
        elseif target.rangeMax <= 10 then
            rangeFrame.bg:SetVertexColor(1.0, 0.5, 0.0) -- 橙色
        elseif target.rangeMax <= 28 then
            rangeFrame.bg:SetVertexColor(1.0, 0.85, 0) -- 黄色
        else
            rangeFrame.bg:SetVertexColor(0.5, 0.5, 0.5) -- 灰色 (超出范围)
        end
    else
        rangeFrame.text:SetText("|cFF888888距离: 无目标|r")
        rangeFrame:SetAlpha(0.5)
        rangeFrame.bg:SetVertexColor(0.3, 0.3, 0.3)
    end
end

local function CreateMonitorUI()
    -- 主框架
    mainFrame = CreateFrame("Frame", "PoCSpellsMonitor", UIParent)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    mainFrame:SetWidth(250)
    mainFrame:SetHeight(40 + (#monitorSpells * 32))
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.8)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    
    -- 标题
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -15)
    title:SetText("PoC_Spells Monitor")
    
    -- 创建技能监控框
    for i, spell in ipairs(monitorSpells) do
        local frame = CreateFrame("Frame", nil, mainFrame)
        frame:SetPoint("TOPLEFT", 20, -35 - (i - 1) * 32)
        frame:SetWidth(210)
        frame:SetHeight(28)
        
        -- 背景
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAllPoints()
        frame.bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        frame.bg:SetAlpha(0.3)
        frame.bg:SetVertexColor(0.3, 0.3, 0.3)
        
        -- 技能图标
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("LEFT", 2, 0)
        frame.icon:SetWidth(24)
        frame.icon:SetHeight(24)
        
        -- 技能名称
        frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 5, 0)
        frame.name:SetJustifyH("LEFT")
        
        -- 状态文本
        frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.status:SetPoint("RIGHT", -5, 0)
        frame.status:SetJustifyH("RIGHT")
        
        -- 冷却动画
        frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        frame.cooldown:SetPoint("LEFT", 2, 0)
        frame.cooldown:SetWidth(24)
        frame.cooldown:SetHeight(24)
        
        frame.spellId = spell.id
        frame.spellName = spell.name
        
        monitorFrames[i] = frame
    end
    
    mainFrame:Show()
end

-- ============================================================================
-- UI: 更新监控框架
-- ============================================================================
local function UpdateMonitorFrame(frame)
    local spellId = frame.spellId
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spellId)
    
    if not name then
        frame.name:SetText("|cFFFF0000未学习|r")
        frame.status:SetText("")
        frame.bg:SetVertexColor(0.3, 0.3, 0.3)
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        return
    end
    
    -- 设置图标和名称
    frame.icon:SetTexture(icon)
    frame.name:SetText(name)
    
    -- 检查可用性
    local usable, nomana = IsUsableSpell(name)
    local start, duration, enabled = GetSpellCooldown(name)
    
    -- 检查距离
    local inRange = true
    if UnitExists("target") then
        local rangeCheck = IsSpellInRange(name, "target")
        inRange = rangeCheck == 1
    end
    
    -- 计算冷却剩余时间
    local cdRemains = 0
    if start and start > 0 and duration and duration > 1.5 then
        cdRemains = math.max(0, (start + duration) - GetTime())
        frame.cooldown:SetCooldown(start, duration)
    else
        frame.cooldown:Clear()
    end
    
    -- 检查天赋触发 Buff
    local hasProc = false
    local procBuffs = {
        [5308] = 52437,   -- 斩杀 -> 猝死
        [7384] = 60503,   -- 压制 -> 血之气息
        [1464] = 46916,   -- 猛击 -> 血腥冲锋
    }
    
    
    -- 更新距离显示
    UpdateRangeDisplay()
    if procBuffs[spellId] then
        local buff = GetPlayerBuff(procBuffs[spellId])
        if buff then
            hasProc = true
        end
    end
    
    -- 设置颜色和状态文本
    local statusText = ""
    local r, g, b = 0.3, 0.3, 0.3
    
    if cdRemains > 0 then
        -- 冷却中 - 蓝色
        r, g, b = 0.2, 0.4, 0.8
        statusText = string.format("%.1fs", cdRemains)
        frame.icon:SetVertexColor(0.5, 0.5, 0.5)
    elseif not usable and not nomana then
        -- 不可用（条件不满足）- 暗红色
        r, g, b = 0.5, 0.2, 0.2
        statusText = "|cFFFF6666不可用|r"
        frame.icon:SetVertexColor(0.4, 0.4, 0.4)
    elseif nomana then
        -- 资源不足 - 紫色
        r, g, b = 0.4, 0.2, 0.6
        statusText = "|cFFBB88FF缺资源|r"
        frame.icon:SetVertexColor(0.5, 0.5, 1.0)
    elseif not inRange then
        -- 超出范围 - 橙色
        r, g, b = 0.8, 0.4, 0.1
        statusText = "|cFFFFAA00距离|r"
        frame.icon:SetVertexColor(0.8, 0.6, 0.3)
    elseif hasProc then
        -- 天赋触发！- 闪亮的金色
        r, g, b = 1.0, 0.8, 0.0
        statusText = "|cFFFFFF00PROC!|r"
        frame.icon:SetVertexColor(1.0, 1.0, 0.5)
        frame.bg:SetAlpha(0.6)
    elseif usable then
        -- 可用 - 绿色
        r, g, b = 0.2, 0.8, 0.2
        statusText = "|cFF00FF00就绪|r"
        frame.icon:SetVertexColor(1.0, 1.0, 1.0)
    end
    
    frame.bg:SetVertexColor(r, g, b)
    frame.bg:SetAlpha(hasProc and 0.6 or 0.3)
    frame.status:SetText(statusText)
end

-- ============================================================================
-- UI: 更新所有监控框架
-- ============================================================================
local function UpdateAllMonitors()
    if not mainFrame or not mainFrame:IsVisible() then return end
    
    for _, frame in ipairs(monitorFrames) do
        UpdateMonitorFrame(frame)
    end
end

-- ============================================================================
-- 自动测试场景（进入游戏时）
-- ============================================================================
local function AutoTest()
    print("|cFF00FF00[PoC_Spells]|r 技能可用性验证工具已加载")
    print("|cFF00FF00使用方法:|r")
    print("  /pocspell [SpellID] - 测试特定技能")
    print("  /pocspell show - 显示监控窗口")
    print("  /pocspell hide - 隐藏监控窗口")
    print("  /pocspell range - 显示/隐藏距离显示")
    print("|cFF888888示例:|r /pocspell 5308 (斩杀)")
    print("")
    
    -- 创建监控UI
    CreateMonitorUI()
    CreateRangeDisplay()
end

addonFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(2, AutoTest)
    end
end)

-- OnUpdate 循环更新
addonFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= UPDATE_INTERVAL then
        UpdateAllMonitors()
        lastUpdate = 0
    end
end)

-- ============================================================================
-- Slash 命令
-- ============================================================================
SLASH_POCSPELL1 = "/pocspell"
SlashCmdList["POCSPELL"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "" then
        print("|cFF00FF00[PoC_Spells]|r 用法:")
        print("  /pocspell [SpellID] - 测试特定技能")
        print("  /pocspell show - 显示监控窗口")
        print("  /pocspell hide - 隐藏监控窗口")
        print("  /pocspell range - 显示/隐藏距离显示")
        print("|cFF888888示例:|r")
        print("  /pocspell 5308  |cFF888888(战士 - 斩杀 Execute)|r")
        print("  /pocspell 1464  |cFF888888(战士 - 猛击 Slam)|r")
        print("  /pocspell 7384  |cFF888888(战士 - 压制 Overpower)|r")
        return
    end
    
    if msg == "show" then
        if mainFrame then
            mainFrame:Show()
            print("|cFF00FF00[PoC_Spells]|r 监控窗口已显示")
        end
        return
    end
    
    if msg == "hide" then
        if mainFrame then
            mainFrame:Hide()
            print("|cFF00FF00[PoC_Spells]|r 监控窗口已隐藏")
        end
        return
    end
    
    if msg == "range" then
        if rangeFrame then
            if rangeFrame:IsVisible() then
                rangeFrame:Hide()
                print("|cFF00FF00[PoC_Spells]|r 距离显示已隐藏")
            else
                rangeFrame:Show()
                print("|cFF00FF00[PoC_Spells]|r 距离显示已显示")
            end
        end
        return
    end
    
    local id = tonumber(msg)
    if id then 
        TestSpell(id) 
    else 
        -- 尝试按名称查找
        local found = false
        for i = 1, 500 do
            local spellName = GetSpellInfo(i)
            if spellName and spellName:lower() == msg then
                TestSpell(i)
                found = true
                break
            end
        end
        
        if not found then
            -- 直接用名称测试
            print("|cFFFFAA00[PoC_Spells]|r 尝试测试技能: " .. msg)
            TestSpell(msg)
        end
    end
end

-- ============================================================================
-- C_Timer 兼容层 (WotLK 3.3.5 支持)
-- ============================================================================
if not C_Timer then
    C_Timer = {}
    function C_Timer.After(delay, callback)
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, e)
            elapsed = elapsed + e
            if elapsed >= delay then
                frame:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
end
