-- ============================================================================
-- ScenarioRegistry - 场景注册器
-- ============================================================================
-- 负责管理所有测试场景的注册、状态追踪和事件分发
-- ============================================================================

local addonName, ns = ...

local ScenarioRegistry = {
    scenarios = {},  -- 已注册的场景列表
    scenarioById = {},  -- 通过ID快速查找场景
    nextId = 1,  -- 自动分配的场景ID
}

-- 注册一个新场景
-- @param scenarioModule: 场景模块，必须包含以下属性：
--   - name: 场景名称（字符串）
--   - description: 场景描述（字符串）
--   - events: 监听的事件列表（数组）
--   - OnEvent(eventName, ...): 事件处理函数
--   - ShouldTrigger(state): 判断是否应该触发标记为通过（可选）
function ScenarioRegistry:Register(scenarioModule)
    -- 验证必需属性
    if not scenarioModule.name then
        error("场景缺少必需属性: name")
    end
    if not scenarioModule.description then
        error("场景缺少必需属性: description")
    end
    if not scenarioModule.OnEvent then
        error("场景缺少必需方法: OnEvent")
    end
    
    -- 分配ID
    local id = self.nextId
    self.nextId = self.nextId + 1
    
    -- 创建场景实例
    local scenario = {
        id = id,
        name = scenarioModule.name,
        description = scenarioModule.description,
        events = scenarioModule.events or {},
        status = "untested",
        count = 0,
        lastTriggerTime = 0,
        lastTriggerSpellID = 0,
        module = scenarioModule,
    }
    
    table.insert(self.scenarios, scenario)
    self.scenarioById[id] = scenario
    
    return id
end

-- 获取所有已注册的场景
function ScenarioRegistry:GetAll()
    return self.scenarios
end

-- 根据ID获取场景
function ScenarioRegistry:GetById(id)
    return self.scenarioById[id]
end

-- 分发事件到所有监听该事件的场景
function ScenarioRegistry:DispatchEvent(eventName, state, ...)
    for _, scenario in ipairs(self.scenarios) do
        -- 检查场景是否监听此事件
        local shouldHandle = false
        if scenario.events and #scenario.events > 0 then
            for _, ev in ipairs(scenario.events) do
                if ev == eventName then
                    shouldHandle = true
                    break
                end
            end
        else
            -- 如果没有指定events列表，则处理所有事件
            shouldHandle = true
        end
        
        if shouldHandle and scenario.module.OnEvent then
            -- 调用场景的事件处理器
            local success, result = pcall(scenario.module.OnEvent, scenario.module, eventName, state, ...)
            
            if success and result then
                -- 场景返回true表示应该标记为通过
                self:MarkPassed(scenario.id, state)
            elseif not success then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[场景" .. scenario.id .. "错误] " .. tostring(result) .. "|r")
            end
        end
    end
end

-- 标记场景为通过
function ScenarioRegistry:MarkPassed(scenarioId, state)
    local scenario = self.scenarioById[scenarioId]
    if not scenario then return end
    
    -- 更新状态
    scenario.status = "passed"
    scenario.count = scenario.count + 1
    scenario.lastTriggerTime = GetTime()
    
    -- 通知UI更新
    if state.OnScenarioStatusChanged then
        state.OnScenarioStatusChanged(scenarioId, "passed", scenario.count)
    end
end

-- 重置所有场景
function ScenarioRegistry:Reset()
    for _, scenario in ipairs(self.scenarios) do
        scenario.status = "untested"
        scenario.count = 0
        scenario.lastTriggerTime = 0
        scenario.lastTriggerSpellID = 0
    end
end

-- 导出到命名空间
ns.ScenarioRegistry = ScenarioRegistry
