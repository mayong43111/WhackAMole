-- PoC_UnitState: 验证 WotLK 3.3.5 的单位状态 API
-- 基于 WeakAuras、TUnitFrame、TotemTimers 的参考实现

-- ============================================================================
-- 配置项
-- ============================================================================
local CONFIG = {
    AURA_THROTTLE = 0.5,      -- 光环事件节流时间（秒）：防止光环更新过于频繁
    MAX_AURA_SCAN = 40,       -- 最大光环扫描数量：每个单位最多扫描的光环数
    TARGET_UNIT = "target",   -- 监控的单位：当前目标
}

-- 能量类型名称映射表
local POWER_NAMES = {
    [0] = "法力",      -- 法师、术士、牧师等职业
    [1] = "怒气",      -- 战士、熊德
    [2] = "集中",      -- 猎人
    [3] = "能量",      -- 盗贼、猫德
    [6] = "符文能量"   -- 死亡骑士
}

-- ============================================================================
-- 状态管理
-- ============================================================================
local State = {
    lastAuraUpdate = 0,  -- 上次光环更新的时间戳
}

-- ============================================================================
-- 工具函数
-- ============================================================================
local Utils = {}

-- 安全检查单位是否存在
-- @param unit 单位标识符（如 "player"、"target"、"focus" 等）
-- @return boolean 单位是否存在且有效
function Utils.SafeUnitExists(unit)
    return unit and UnitExists(unit)
end

-- 获取单位名称
-- @param unit 单位标识符
-- @return string 单位名称，如果无法获取则返回"未知"
function Utils.GetUnitName(unit)
    return UnitName(unit) or "未知"
end

-- 获取施法者标签
-- @param unitCaster 施法者的单位标识符
-- @return string 格式化的施法者标签（如 "[玩家]"、"[宠物]" 等）
function Utils.GetCasterLabel(unitCaster)
    if unitCaster == "player" then
        return "[玩家]"
    elseif unitCaster == "pet" then
        return "[宠物]"
    elseif unitCaster then
        return "[" .. tostring(unitCaster) .. "]"
    end
    return ""
end

-- 格式化时间显示
-- @param remaining 剩余时间（秒）
-- @param duration 总持续时间（秒）
-- @return string 格式化的时间字符串
function Utils.FormatTime(remaining, duration)
    if duration > 0 and remaining > 0 then
        return string.format(" (%.1f/%.1f秒)", remaining, duration)
    end
    return ""
end

-- ============================================================================
-- 显示函数
-- ============================================================================
local Display = {}

-- 显示单位的生命值信息
-- @param unit 单位标识符
function Display.Health(unit)
    if not Utils.SafeUnitExists(unit) then return end
    
    local hp = UnitHealth(unit)       -- 当前生命值
    local maxHp = UnitHealthMax(unit) -- 最大生命值
    
    -- 防止除以零的保护
    if maxHp <= 0 then 
        print(string.format("[生命值] %s: 无效 (最大生命值=0)", unit))
        return 
    end
    
    local hpPercent = floor((hp / maxHp) * 100)
    print(string.format("[生命值] %s: %d/%d (%d%%)", unit, hp, maxHp, hpPercent))
end

-- 显示单位的能量值信息
-- @param unit 单位标识符
function Display.Power(unit)
    if not Utils.SafeUnitExists(unit) then return end
    
    local power = UnitPower(unit)         -- 当前能量值
    local maxPower = UnitPowerMax(unit)   -- 最大能量值
    local powerType = UnitPowerType(unit) -- 能量类型（0=法力, 1=怒气, 等）
    local powerName = POWER_NAMES[powerType] or "未知"
    
    if maxPower > 0 then
        print(string.format("[能量值] %s: %d/%d %s", unit, power, maxPower, powerName))
    else
        print(string.format("[能量值] %s: 无 (%s)", unit, powerName))
    end
end

-- 显示单个光环的详细信息
-- @param index 光环索引
-- @param name 光环名称
-- @param count 光环层数
-- @param unitCaster 施法者
-- @param duration 光环总持续时间
-- @param expirationTime 光环到期时间
function Display.Aura(index, name, count, unitCaster, duration, expirationTime)
    local output = string.format("  [%d] %s", index, name)
    
    -- 添加层数信息（如果层数大于1）
    if count and count > 1 then
        output = output .. " x" .. count
    end
    
    -- 添加施法者标签
    output = output .. Utils.GetCasterLabel(unitCaster)
    
    -- 添加剩余时间信息
    if duration and duration > 0 and expirationTime and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        output = output .. Utils.FormatTime(remaining, duration)
    end
    
    print(output)
end

-- ============================================================================
-- 光环扫描器
-- ============================================================================
local AuraScanner = {}

-- 扫描并显示单位的光环
-- @param unit 单位标识符
-- @param isBuff true=增益光环(buff), false=减益光环(debuff)
-- @param playerOnly 是否只显示玩家或宠物施放的光环
-- @return number 找到的光环数量
function AuraScanner.Scan(unit, isBuff, playerOnly)
    if not Utils.SafeUnitExists(unit) then return 0 end
    
    playerOnly = playerOnly or false
    local auraCount = 0
    local filterName = isBuff and "增益" or "减益"
    
    print(string.format("--- %s 光环 (%s) ---", unit, filterName))
    
    -- 遍历所有光环槽位
    for i = 1, CONFIG.MAX_AURA_SCAN do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster
        
        -- 根据光环类型调用相应的 API
        if isBuff then
            name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitBuff(unit, i)
        else
            name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitDebuff(unit, i)
        end
        
        -- 如果没有光环名称，说明已经扫描完毕
        if not name then break end
        
        -- 判断是否应该显示此光环（根据 playerOnly 过滤）
        local shouldDisplay = not playerOnly or unitCaster == "player" or unitCaster == "pet"
        
        if shouldDisplay then
            auraCount = auraCount + 1
            Display.Aura(i, name, count, unitCaster, duration, expirationTime)
        end
    end
    
    -- 如果没有找到任何光环，显示提示信息
    if auraCount == 0 then
        print(string.format("  (无%s光环)", filterName))
    end
    
    return auraCount
end

-- 扫描并显示单位的所有光环（增益和减益）
-- @param unit 单位标识符
function AuraScanner.ScanAll(unit)
    if not Utils.SafeUnitExists(unit) then return end
    
    local buffCount = AuraScanner.Scan(unit, true, false)   -- 扫描增益光环
    local debuffCount = AuraScanner.Scan(unit, false, false) -- 扫描减益光环
    
    print(string.format("[统计] 增益: %d个, 减益: %d个", buffCount, debuffCount))
end

-- ============================================================================
-- 主监控器
-- ============================================================================
local Monitor = {}

-- 显示单位的完整信息（生命、能量、所有光环）
-- @param unit 单位标识符，默认为 "target"
function Monitor.ShowUnitInfo(unit)
    unit = unit or CONFIG.TARGET_UNIT
    
    if not Utils.SafeUnitExists(unit) then
        print(string.format("PoC_单位状态: 无效的单位 '%s'", unit))
        return
    end
    
    print("=== PoC_单位状态测试 ===")
    print(string.format("单位: %s (%s)", Utils.GetUnitName(unit), unit))
    
    Display.Health(unit)     -- 显示生命值
    Display.Power(unit)      -- 显示能量值
    AuraScanner.ScanAll(unit) -- 显示所有光环
    
    print("=== 测试完成 ===")
end

-- 处理目标切换事件
-- 当玩家切换目标时自动触发
function Monitor.OnTargetChanged()
    local target = CONFIG.TARGET_UNIT
    if Utils.SafeUnitExists(target) then
        Monitor.ShowUnitInfo(target)
    else
        print("PoC_单位状态: 目标已清除")
    end
end

-- 处理光环变化事件
-- 当单位的光环发生变化时触发（带节流控制）
-- @param unit 发生光环变化的单位
function Monitor.OnAuraChanged(unit)
    -- 只监控目标单位
    if unit ~= CONFIG.TARGET_UNIT then return end
    
    -- 节流控制：避免光环更新过于频繁
    local now = GetTime()
    if now - State.lastAuraUpdate < CONFIG.AURA_THROTTLE then return end
    
    State.lastAuraUpdate = now
    
    if Utils.SafeUnitExists(CONFIG.TARGET_UNIT) then
        print("\n[光环更新]")
        AuraScanner.ScanAll(CONFIG.TARGET_UNIT)
    end
end

-- ============================================================================
-- 事件注册
-- ============================================================================
-- 初始化事件监听系统
local function InitializeEvents()
    local frame = CreateFrame("Frame")
    
    -- 注册需要监听的事件
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")  -- 玩家切换目标
    frame:RegisterEvent("UNIT_AURA")              -- 单位光环变化
    
    -- 设置事件处理函数
    frame:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_TARGET_CHANGED" then
            -- 处理目标切换事件
            Monitor.OnTargetChanged()
        elseif event == "UNIT_AURA" then
            -- 处理光环变化事件
            Monitor.OnAuraChanged(unit)
        end
    end)
end

-- ============================================================================
-- 插件初始化
-- ============================================================================
InitializeEvents()
print("PoC_单位状态 已加载！自动监控目标状态...")
