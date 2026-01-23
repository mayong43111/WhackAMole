local addon, ns = ...

-- =========================================================================
-- 钩子系统（任务 5.5 - 借鉴 Hekili）
-- =========================================================================
-- 提供事件订阅机制，允许职业模块和外部扩展注册回调函数

--- 钩子存储表
-- 格式：{ ["eventName"] = { handler1, handler2, ... } }
ns.hooks = {}

--- 注册钩子处理器
-- @param event 事件名称（如 "runHandler", "reset_preauras"）
-- @param handler 处理函数，接收 (event, ...) 参数
function ns.RegisterHook(event, handler)
    if type(event) ~= "string" then
        error("RegisterHook: event must be a string", 2)
    end
    if type(handler) ~= "function" then
        error("RegisterHook: handler must be a function", 2)
    end
    
    ns.hooks[event] = ns.hooks[event] or {}
    table.insert(ns.hooks[event], handler)
end

--- 调用钩子处理器
-- @param event 事件名称
-- @param ... 传递给处理器的参数
function ns.CallHook(event, ...)
    local handlers = ns.hooks[event]
    if not handlers then return end
    
    for i, handler in ipairs(handlers) do
        local success, err = pcall(handler, event, ...)
        if not success then
            ns.Logger:Error("Hook", "Hook error [" .. event .. "]: " .. tostring(err))
            ns.Logger:System("WhackAMole: Hook error [" .. event .. "]: " .. tostring(err))
        end
    end
end

--- 注销钩子处理器
-- @param event 事件名称
-- @param handler 要移除的处理函数
function ns.UnregisterHook(event, handler)
    local handlers = ns.hooks[event]
    if not handlers then return end
    
    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
        end
    end
end

--- 清除特定事件的所有钩子
-- @param event 事件名称
function ns.ClearHooks(event)
    if event then
        ns.hooks[event] = nil
    else
        ns.hooks = {}
    end
end

--- 调用钩子并返回第一个非 nil 结果
-- @param event 事件名称
-- @param ... 传递给处理器的参数
-- @return 第一个处理器返回的非 nil 值，或 nil
function ns.CallHookWithReturn(event, ...)
    local handlers = ns.hooks[event]
    if not handlers then return nil end
    
    for i, handler in ipairs(handlers) do
        local success, result = pcall(handler, event, ...)
        if success and result ~= nil then
            return result
        elseif not success then
            ns.Logger:Error("Hook", "Hook error [" .. event .. "]: " .. tostring(result))
            ns.Logger:System("WhackAMole: Hook error [" .. event .. "]: " .. tostring(result))
        end
    end
    
    return nil
end

-- =========================================================================
-- 核心钩子事件定义
-- =========================================================================
--[[
可用的钩子事件：

1. runHandler (key, ...)
   - 触发时机：技能执行后
   - 参数：技能键名（SimC action name）
   - 用途：职业特殊机制（如战士 Execute 清除猝死 Buff）

2. reset_preauras
   - 触发时机：State.reset() 扫描光环之前
   - 参数：无
   - 用途：预处理光环数据

3. reset_postauras
   - 触发时机：State.reset() 扫描光环之后
   - 参数：无
   - 用途：后处理光环数据

4. startCombat
   - 触发时机：进入战斗
   - 参数：无
   - 用途：战斗开始时的初始化

5. endCombat
   - 触发时机：离开战斗
   - 参数：无
   - 用途：战斗结束时的清理

6. advance (delta)
   - 触发时机：虚拟时间推进时
   - 参数：推进的时间（秒）
   - 用途：资源回复、Buff 过期等预测逻辑

使用示例：
```lua
-- 在职业模块中注册钩子
ns.RegisterHook("runHandler", function(event, key)
    if key == "execute" then
        -- 战士 Execute 执行后，清除猝死 Buff
        ns.State.buff.sudden_death.expires = 0
    end
end)
```
--]]
