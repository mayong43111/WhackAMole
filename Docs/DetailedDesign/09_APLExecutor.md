# 09 - APL 执行器详细设计

## 模块概述

**文件**: `src/Engine/APLExecutor.lua`

APLExecutor 负责执行编译后的 APL 规则，根据当前状态快照选择推荐动作，并支持虚拟时间预测。

---

## 职责

1. **创建决策函数**
   - 将 actions 列表编译为单一决策函数
   - 错误隔离

2. **执行 APL**
   - 按顺序遍历规则
   - 返回第一个满足条件的动作

3. **预测下一步**
   - 虚拟时间推进
   - 模拟未来状态
   - 返回预测动作

---

## 核心流程

### CreateLogicFunc

```lua
function APLExecutor.CreateLogicFunc(actions)
    -- 编译所有条件
    local compiledActions = {}
    
    for i, action in ipairs(actions) do
        local condFunc
        
        if action.condition and action.condition ~= "" then
            -- 使用脚本缓存编译
            condFunc = ns.SimCParser.Compile(action.condition)
        else
            -- 无条件：永远为 true
            condFunc = function() return true end
        end
        
        table.insert(compiledActions, {
            action = action.action,
            condFunc = condFunc
        })
    end
    
    -- 返回决策函数
    return function(ctx)
        for _, compiled in ipairs(compiledActions) do
            -- 评估条件
            local success, result = pcall(compiled.condFunc, ctx)
            
            if success and result then
                return compiled.action
            end
        end
        
        return nil  -- 无动作满足条件
    end
end
```

---

## 预测机制

### PredictNext

```lua
function APLExecutor.PredictNext(currentAction, logicFunc, state)
    -- 1. 复制当前状态
    local futureState = CopyState(state)
    
    -- 2. 模拟当前动作执行
    if currentAction then
        SimulateAction(futureState, currentAction)
    end
    
    -- 3. 推进虚拟时间
    -- 假设 GCD 1.5 秒
    futureState:advance(1.5)
    
    -- 4. 构建未来 Context
    local futureCtx = futureState:BuildContext()
    
    -- 5. 执行 APL 获取预测动作
    local nextAction = logicFunc(futureCtx)
    
    return nextAction
end
```

### SimulateAction

```lua
function SimulateAction(state, actionName)
    -- 1. 触发 GCD
    state.player.gcd.active = true
    state.player.gcd.remains = 1.5
    
    -- 2. 消耗资源
    local cost = GetActionCost(actionName)
    if cost then
        state.player.power.current = state.player.power.current - cost
    end
    
    -- 3. 添加技能效果（简化）
    -- 实际需要根据技能类型处理
    -- 例如：施加 Buff、触发冷却等
end
```

---

## 错误处理

### 条件评估错误

```lua
function SafeEvalCondition(condFunc, ctx)
    local success, result = pcall(condFunc, ctx)
    
    if not success then
        if ns.Logger then
            ns.Logger:Error("Condition eval failed: " .. tostring(result))
        end
        return false
    end
    
    return result
end
```

---

## 依赖关系

### 依赖的模块
- SimCParser (条件编译)
- State (状态快照)

### 被依赖的模块
- Core (调用决策函数)

---

## 相关文档
- [SimC 解析器](08_SimCParser.md)
- [状态快照系统](07_State.md)
- [生命周期与主控制器](01_Core_Lifecycle.md)
