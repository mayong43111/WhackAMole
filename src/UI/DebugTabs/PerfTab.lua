local _, ns = ...

-- =========================================================================
-- PerfTab - 性能分析页签（整合性能、缓存、实时监控）
-- =========================================================================

local PerfTab = {}
ns.DebugTabs = ns.DebugTabs or {}
ns.DebugTabs.PerfTab = PerfTab

local AceGUI = LibStub("AceGUI-3.0")

--- 创建性能分析页签
function PerfTab:Create(container)
    if not ns.Logger or not ns.Logger.performance then
        local errorLabel = AceGUI:Create("Label")
        errorLabel:SetText("|cffff0000错误: Logger未初始化|r")
        errorLabel:SetFullWidth(true)
        container:AddChild(errorLabel)
        return
    end
    
    container:ReleaseChildren()
    container:SetLayout("List")
    
    -- 1. 实时监控 - FPS 和帧耗时
    local realtimeGroup = AceGUI:Create("InlineGroup")
    realtimeGroup:SetTitle("实时监控")
    realtimeGroup:SetFullWidth(true)
    realtimeGroup:SetLayout("Flow")
    
    -- FPS
    local fpsLabel = AceGUI:Create("Label")
    local fpsColor = "|cff00ff00"
    if ns.Logger.realtime.fps < 30 then
        fpsColor = "|cffff0000"
    elseif ns.Logger.realtime.fps < 50 then
        fpsColor = "|cffffa500"
    end
    fpsLabel:SetText(string.format("FPS: %s%.1f|r", fpsColor, ns.Logger.realtime.fps))
    fpsLabel:SetWidth(150)
    realtimeGroup:AddChild(fpsLabel)
    
    -- 平均帧耗时
    local avgFrameLabel = AceGUI:Create("Label")
    avgFrameLabel:SetText(string.format("平均耗时: %.2f ms", ns.Logger.realtime.avgFrameTime))
    avgFrameLabel:SetWidth(180)
    realtimeGroup:AddChild(avgFrameLabel)
    
    -- 峰值帧耗时
    local peakLabel = AceGUI:Create("Label")
    peakLabel:SetText(string.format("峰值耗时: %.2f ms", ns.Logger.realtime.peakFrameTime))
    peakLabel:SetWidth(180)
    realtimeGroup:AddChild(peakLabel)
    
    -- 内存
    local memLabel = AceGUI:Create("Label")
    memLabel:SetText(string.format("内存: %.2f MB", ns.Logger.realtime.memoryUsage))
    memLabel:SetWidth(150)
    realtimeGroup:AddChild(memLabel)
    
    container:AddChild(realtimeGroup)
    
    -- 2. 缓存统计
    local cacheGroup = AceGUI:Create("InlineGroup")
    cacheGroup:SetTitle("缓存统计")
    cacheGroup:SetFullWidth(true)
    cacheGroup:SetLayout("Flow")
    
    local queryTotal = ns.Logger.cache.query.hits + ns.Logger.cache.query.misses
    local queryRate = queryTotal > 0 and (ns.Logger.cache.query.hits / queryTotal * 100) or 0
    local scriptTotal = ns.Logger.cache.script.hits + ns.Logger.cache.script.misses
    local scriptRate = scriptTotal > 0 and (ns.Logger.cache.script.hits / scriptTotal * 100) or 0
    
    local cache1 = AceGUI:Create("Label")
    cache1:SetText(string.format("查询缓存: %.1f%% (%d/%d)", queryRate, ns.Logger.cache.query.hits, queryTotal))
    cache1:SetWidth(250)
    cacheGroup:AddChild(cache1)
    
    local cache2 = AceGUI:Create("Label")
    cache2:SetText(string.format("脚本缓存: %.1f%% (%d/%d)", scriptRate, ns.Logger.cache.script.hits, scriptTotal))
    cache2:SetWidth(250)
    cacheGroup:AddChild(cache2)
    
    container:AddChild(cacheGroup)
    
    -- 3. 性能统计摘要
    local summaryGroup = AceGUI:Create("InlineGroup")
    summaryGroup:SetTitle("性能统计")
    summaryGroup:SetFullWidth(true)
    summaryGroup:SetLayout("Flow")
    
    local stats = ns.Logger.performance
    local avgTime = stats.frameCount > 0 and (stats.totalTime / stats.frameCount) or 0
    
    local summary1 = AceGUI:Create("Label")
    summary1:SetText(string.format("总帧数: %d", stats.frameCount))
    summary1:SetWidth(150)
    summaryGroup:AddChild(summary1)
    
    local summary2 = AceGUI:Create("Label")
    summary2:SetText(string.format("总耗时: %.2f ms", stats.totalTime))
    summary2:SetWidth(180)
    summaryGroup:AddChild(summary2)
    
    local summary3 = AceGUI:Create("Label")
    summary3:SetText(string.format("模块平均: %.2f ms", avgTime))
    summary3:SetWidth(180)
    summaryGroup:AddChild(summary3)
    
    container:AddChild(summaryGroup)
    
    -- 4. 模块耗时分布
    local moduleGroup = AceGUI:Create("InlineGroup")
    moduleGroup:SetTitle("模块耗时分布")
    moduleGroup:SetFullWidth(true)
    moduleGroup:SetLayout("Flow")
    
    local modules = ns.Logger.performance.modules
    local totalTime = ns.Logger.performance.totalTime
    
    if totalTime == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cff808080暂无数据，请启动监控后会自动采集性能数据|r")
        emptyLabel:SetFullWidth(true)
        moduleGroup:AddChild(emptyLabel)
    else
        local moduleNames = {
            {key = "state", name = "State 快照"},
            {key = "apl", name = "APL 执行"},
            {key = "predict", name = "预测计算"},
            {key = "ui", name = "UI 更新"},
            {key = "audio", name = "音频播放"}
        }
        
        for _, m in ipairs(moduleNames) do
            local data = modules[m.key]
            local avgTime = data.count > 0 and (data.total / data.count) or 0
            local pct = (data.total / totalTime) * 100
            
            local label = AceGUI:Create("Label")
            label:SetText(string.format("%s: 平均 %.2f ms | 峰值 %.2f ms | 占比 %.1f%%", 
                m.name, avgTime, data.max, pct))
            label:SetWidth(400)
            moduleGroup:AddChild(label)
        end
    end
    
    container:AddChild(moduleGroup)
end