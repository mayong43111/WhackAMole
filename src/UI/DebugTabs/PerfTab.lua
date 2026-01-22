local _, ns = ...

-- =========================================================================
-- PerfTab - 性能分析页签（整合性能、缓存、实时监控）
-- =========================================================================

local PerfTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.PerfTab = PerfTab

local AceGUI = LibStub("AceGUI-3.0")

--- 创建性能分析页签（返回控件引用）
function PerfTab:Create(container)
    if not ns.Logger or not ns.Logger.performance then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000错误: Logger未初始化|r")
        errorLabel:SetFullWidth(true)
        container:AddChild(errorLabel)
        return nil
    end
    
    container:SetLayout("List")
    
    local widgets = {}  -- 保存所有控件引用
    
    -- 1. 实时监控 - FPS 和帧耗时
    local realtimeGroup = AceGUI:Create("InlineGroup")
    realtimeGroup:SetTitle("实时监控")
    realtimeGroup:SetFullWidth(true)
    realtimeGroup:SetLayout("Flow")
    
    -- FPS
    widgets.fpsLabel = AceGUI:Create("Label")
    widgets.fpsLabel:SetWidth(150)
    realtimeGroup:AddChild(widgets.fpsLabel)
    
    -- 平均帧耗时
    widgets.avgFrameLabel = AceGUI:Create("Label")
    widgets.avgFrameLabel:SetWidth(180)
    realtimeGroup:AddChild(widgets.avgFrameLabel)
    
    -- 峰值帧耗时
    widgets.peakLabel = AceGUI:Create("Label")
    widgets.peakLabel:SetWidth(180)
    realtimeGroup:AddChild(widgets.peakLabel)
    
    -- 内存
    widgets.memLabel = AceGUI:Create("Label")
    widgets.memLabel:SetWidth(150)
    realtimeGroup:AddChild(widgets.memLabel)
    
    container:AddChild(realtimeGroup)
    
    -- 2. 缓存统计
    local cacheGroup = AceGUI:Create("InlineGroup")
    cacheGroup:SetTitle("缓存统计")
    cacheGroup:SetFullWidth(true)
    cacheGroup:SetLayout("Flow")
    
    widgets.cache1 = AceGUI:Create("Label")
    widgets.cache1:SetWidth(250)
    cacheGroup:AddChild(widgets.cache1)
    
    widgets.cache2 = AceGUI:Create("Label")
    widgets.cache2:SetWidth(250)
    cacheGroup:AddChild(widgets.cache2)
    
    container:AddChild(cacheGroup)
    
    -- 3. 性能统计摘要
    local summaryGroup = AceGUI:Create("InlineGroup")
    summaryGroup:SetTitle("性能统计")
    summaryGroup:SetFullWidth(true)
    summaryGroup:SetLayout("Flow")
    
    widgets.summary1 = AceGUI:Create("Label")
    widgets.summary1:SetWidth(150)
    summaryGroup:AddChild(widgets.summary1)
    
    widgets.summary2 = AceGUI:Create("Label")
    widgets.summary2:SetWidth(180)
    summaryGroup:AddChild(widgets.summary2)
    
    widgets.summary3 = AceGUI:Create("Label")
    widgets.summary3:SetWidth(180)
    summaryGroup:AddChild(widgets.summary3)
    
    container:AddChild(summaryGroup)
    
    -- 4. 模块耗时分布
    local moduleGroup = AceGUI:Create("InlineGroup")
    moduleGroup:SetTitle("模块耗时分布")
    moduleGroup:SetFullWidth(true)
    moduleGroup:SetLayout("Flow")
    
    -- 创建5个模块标签
    widgets.moduleLabels = {}
    local moduleNames = {
        {key = "state", name = "State 快照"},
        {key = "apl", name = "APL 执行"},
        {key = "predict", name = "预测计算"},
        {key = "ui", name = "UI 更新"},
        {key = "audio", name = "音频播放"}
    }
    
    for i, m in ipairs(moduleNames) do
        local label = AceGUI:Create("Label")
        label:SetWidth(400)
        moduleGroup:AddChild(label)
        widgets.moduleLabels[i] = {widget = label, key = m.key, name = m.name}
    end
    
    container:AddChild(moduleGroup)
    
    -- 初始更新内容
    self:Update(widgets)
    
    return widgets
end

--- 更新性能监控页签内容（不重新创建控件）
function PerfTab:Update(widgets)
    if not widgets or not ns.Logger or not ns.Logger.performance then
        return
    end
    
    -- 更新实时监控
    local fpsColor = "|cff00ff00"
    if ns.Logger.realtime.fps < 30 then
        fpsColor = "|cffff0000"
    elseif ns.Logger.realtime.fps < 50 then
        fpsColor = "|cffffa500"
    end
    widgets.fpsLabel:SetText(string.format("FPS: %s%.1f|r", fpsColor, ns.Logger.realtime.fps))
    widgets.avgFrameLabel:SetText(string.format("平均: %.2f ms", ns.Logger.realtime.avgFrameTime))
    widgets.peakLabel:SetText(string.format("峰值: %.2f ms", ns.Logger.realtime.peakFrameTime))
    widgets.memLabel:SetText(string.format("内存: %.2f MB", ns.Logger.realtime.memoryUsage))
    
    -- 更新缓存统计
    local queryTotal = ns.Logger.cache.query.hits + ns.Logger.cache.query.misses
    local queryRate = queryTotal > 0 and (ns.Logger.cache.query.hits / queryTotal * 100) or 0
    local scriptTotal = ns.Logger.cache.script.hits + ns.Logger.cache.script.misses
    local scriptRate = scriptTotal > 0 and (ns.Logger.cache.script.hits / scriptTotal * 100) or 0
    
    widgets.cache1:SetText(string.format("查询缓存: %.1f%% (%d/%d)", queryRate, ns.Logger.cache.query.hits, queryTotal))
    widgets.cache2:SetText(string.format("脚本缓存: %.1f%% (%d/%d)", scriptRate, ns.Logger.cache.script.hits, scriptTotal))
    
    -- 更新性能统计
    local stats = ns.Logger.performance
    local avgTime = stats.frameCount > 0 and (stats.totalTime / stats.frameCount) or 0
    
    widgets.summary1:SetText(string.format("总帧数: %d", stats.frameCount))
    widgets.summary2:SetText(string.format("总耗时: %.2f ms", stats.totalTime))
    widgets.summary3:SetText(string.format("模块平均: %.2f ms", avgTime))
    
    -- 更新模块耗时分布
    local modules = ns.Logger.performance.modules
    local totalTime = ns.Logger.performance.totalTime
    
    if totalTime == 0 then
        for _, moduleLabel in ipairs(widgets.moduleLabels) do
            moduleLabel.widget:SetText("|cff808080暂无数据|r")
        end
    else
        for _, moduleLabel in ipairs(widgets.moduleLabels) do
            local data = modules[moduleLabel.key]
            local avgTime = data.count > 0 and (data.total / data.count) or 0
            local pct = (data.total / totalTime) * 100
            
            moduleLabel.widget:SetText(string.format("%s: 平均 %.2f ms | 峰值 %.2f ms | 占比 %.1f%%", 
                moduleLabel.name, avgTime, data.max, pct))
        end
    end
end