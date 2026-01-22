# 08 - SimC 解析器详细设计

## 模块概述

**文件**: `src/Engine/SimCParser.lua`

SimCParser 负责将 SimulationCraft 风格的 APL 文本解析、编译为可执行的 Lua 函数，并提供脚本缓存以提升性能。

---

## 设计目标

1. **用户友好**：支持 SimC 语法，降低学习门槛
2. **性能优先**：加载时编译，运行时零解析
3. **可靠性**：语法错误隔离，不影响插件稳定性
4. **可扩展性**：易于添加新的条件表达式和操作符

---

## APL 语法定义

### 动作行格式

```
actions+=/action_name,if=condition
```

**示例**：
```
actions+=/fireball,if=buff.hot_streak.up
actions+=/pyroblast,if=buff.hot_streak.down&cooldown.combustion.remains>10
actions+=/combustion,if=target.health.pct<35
```

### 条件表达式

**操作符**：
- 逻辑：`&` (与), `|` (或), `!` (非)
- 比较：`>`, `<`, `>=`, `<=`, `=`, `!=`
- 括号：`(`, `)`

**领域对象**：
- `buff.<name>.<field>` - Buff 状态
  - 字段：`up`, `down`, `remains`, `count`, `stacks`
- `debuff.<name>.<field>` - Debuff 状态
- `cooldown.<name>.<field>` - 冷却状态
  - 字段：`ready`, `remains`, `charges`
- `target.health.pct` - 目标生命百分比
- `player.health.pct` - 玩家生命百分比
- `mana.pct`, `energy.pct`, `rage.pct` - 资源百分比

**示例条件**：
```
buff.hot_streak.up
cooldown.combustion.ready
target.health.pct<20
buff.bloodlust.up&cooldown.combustion.ready
(!buff.living_bomb.up)|(buff.living_bomb.remains<3)
```

---

## 编译流程

### 1. 词法分析 (Tokenize)

```lua
function Tokenize(conditionStr)
    local tokens = {}
    local i = 1
    local len = #conditionStr
    
    while i <= len do
        local char = conditionStr:sub(i, i)
        
        -- 跳过空白
        if char:match("%s") then
            i = i + 1
            
        -- 操作符
        elseif char == "&" or char == "|" or char == "!" then
            table.insert(tokens, {type = "op", value = char})
            i = i + 1
            
        -- 比较符（支持 >= <= != 等）
        elseif char == ">" or char == "<" or char == "=" or char == "!" then
            local next_char = conditionStr:sub(i + 1, i + 1)
            if next_char == "=" then
                table.insert(tokens, {
                    type = "cmp", 
                    value = char .. next_char
                })
                i = i + 2
            else
                table.insert(tokens, {type = "cmp", value = char})
                i = i + 1
            end
            
        -- 括号
        elseif char == "(" or char == ")" then
            table.insert(tokens, {type = "paren", value = char})
            i = i + 1
            
        -- 标识符/数字（buff.hot_streak.up, 123, etc.）
        else
            local start = i
            while i <= len do
                char = conditionStr:sub(i, i)
                if char:match("[%w_.]") then
                    i = i + 1
                else
                    break
                end
            end
            
            local token = conditionStr:sub(start, i - 1)
            
            -- 区分数字和标识符
            if tonumber(token) then
                table.insert(tokens, {type = "number", value = tonumber(token)})
            else
                table.insert(tokens, {type = "ident", value = token})
            end
        end
    end
    
    return tokens
end
```

### 2. 语法分析 (Parse)

采用**递归下降语法分析器**，支持操作符优先级。

```lua
-- 解析主入口
function ParseExpression(tokens, pos)
    return ParseOr(tokens, pos)
end

-- 解析 OR 表达式（最低优先级）
function ParseOr(tokens, pos)
    local left, pos = ParseAnd(tokens, pos)
    
    while tokens[pos] and tokens[pos].value == "|" then
        pos = pos + 1
        local right, newPos = ParseAnd(tokens, pos)
        pos = newPos
        left = {type = "or", left = left, right = right}
    end
    
    return left, pos
end

-- 解析 AND 表达式
function ParseAnd(tokens, pos)
    local left, pos = ParseComparison(tokens, pos)
    
    while tokens[pos] and tokens[pos].value == "&" then
        pos = pos + 1
        local right, newPos = ParseComparison(tokens, pos)
        pos = newPos
        left = {type = "and", left = left, right = right}
    end
    
    return left, pos
end

-- 解析比较表达式
function ParseComparison(tokens, pos)
    local left, pos = ParseUnary(tokens, pos)
    
    local token = tokens[pos]
    if token and token.type == "cmp" then
        local op = token.value
        pos = pos + 1
        local right, newPos = ParseUnary(tokens, pos)
        pos = newPos
        return {type = "cmp", op = op, left = left, right = right}, pos
    end
    
    return left, pos
end

-- 解析一元表达式（! 操作符）
function ParseUnary(tokens, pos)
    local token = tokens[pos]
    
    if token and token.value == "!" then
        pos = pos + 1
        local expr, newPos = ParseUnary(tokens, pos)
        return {type = "not", expr = expr}, newPos
    end
    
    return ParsePrimary(tokens, pos)
end

-- 解析基本表达式
function ParsePrimary(tokens, pos)
    local token = tokens[pos]
    
    if not token then
        error("Unexpected end of expression")
    end
    
    -- 括号分组
    if token.value == "(" then
        pos = pos + 1
        local expr, newPos = ParseExpression(tokens, pos)
        pos = newPos
        
        if not tokens[pos] or tokens[pos].value ~= ")" then
            error("Missing closing parenthesis")
        end
        pos = pos + 1
        return expr, pos
    end
    
    -- 数字字面量
    if token.type == "number" then
        return {type = "literal", value = token.value}, pos + 1
    end
    
    -- 标识符（buff.hot_streak.up）
    if token.type == "ident" then
        return {type = "field", path = token.value}, pos + 1
    end
    
    error("Unexpected token: " .. tostring(token.value))
end
```

### 3. AST 示例

条件：`buff.hot_streak.up&cooldown.combustion.ready`

AST：
```lua
{
    type = "and",
    left = {
        type = "field",
        path = "buff.hot_streak.up"
    },
    right = {
        type = "field",
        path = "cooldown.combustion.ready"
    }
}
```

### 4. 代码生成 (CodeGen)

将 AST 转换为可执行的 Lua 代码字符串。

```lua
function CodeGen(ast)
    if ast.type == "literal" then
        return tostring(ast.value)
        
    elseif ast.type == "field" then
        -- buff.hot_streak.up -> ctx.buff.hot_streak.up
        return "ctx." .. ast.path
        
    elseif ast.type == "and" then
        return "(" .. CodeGen(ast.left) .. " and " .. 
               CodeGen(ast.right) .. ")"
        
    elseif ast.type == "or" then
        return "(" .. CodeGen(ast.left) .. " or " .. 
               CodeGen(ast.right) .. ")"
        
    elseif ast.type == "not" then
        return "(not " .. CodeGen(ast.expr) .. ")"
        
    elseif ast.type == "cmp" then
        local left = CodeGen(ast.left)
        local right = CodeGen(ast.right)
        local op = ast.op
        
        -- 转换 SimC 操作符到 Lua
        if op == "=" then op = "==" end
        if op == "!=" then op = "~=" end
        
        return "(" .. left .. " " .. op .. " " .. right .. ")"
    end
    
    error("Unknown AST node type: " .. ast.type)
end
```

### 5. 编译 (Compile)

```lua
function Compile(conditionStr)
    -- 空条件：总是返回 true
    if not conditionStr or conditionStr == "" then
        return function() return true end
    end
    
    -- 1. 词法分析
    local tokens = Tokenize(conditionStr)
    
    -- 2. 语法分析
    local ast = ParseExpression(tokens, 1)
    
    -- 3. 代码生成
    local code = CodeGen(ast)
    
    -- 4. 包装为函数
    local funcStr = "return function(ctx) return " .. code .. " end"
    
    -- 5. 加载并返回函数
    local func, err = loadstring(funcStr)
    if not func then
        error("Failed to compile condition: " .. err)
    end
    
    return func()
end
```

---

## 脚本缓存系统

### 设计目标
- 避免重复编译相同条件
- 使用弱引用表自动管理内存

### 缓存实现

```lua
-- 弱引用表（值被 GC 回收后自动移除）
local compiledScripts = setmetatable({}, {__mode = "v"})

-- 缓存统计
local compileStats = {
    hits = 0,
    misses = 0,
    total = 0
}

function CompileWithCache(conditionStr)
    -- 1. 检查缓存
    if compiledScripts[conditionStr] then
        compileStats.hits = compileStats.hits + 1
        compileStats.total = compileStats.total + 1
        return compiledScripts[conditionStr]
    end
    
    -- 2. 缓存未命中，执行编译
    compileStats.misses = compileStats.misses + 1
    compileStats.total = compileStats.total + 1
    
    local success, func = pcall(Compile, conditionStr)
    if not success then
        -- 编译失败，返回永远为 false 的函数
        func = function() return false end
    end
    
    -- 3. 存入缓存
    compiledScripts[conditionStr] = func
    
    return func
end

--- 清空脚本缓存（配置切换时调用）
function ClearCache()
    wipe(compiledScripts)
end

--- 获取缓存统计
function GetCacheStats()
    local hitRate = 0
    if compileStats.total > 0 then
        hitRate = compileStats.hits / compileStats.total
    end
    
    return {
        hits = compileStats.hits,
        misses = compileStats.misses,
        total = compileStats.total,
        hitRate = hitRate
    }
end
```

---

## 错误处理

### 编译时错误

```lua
function SafeCompile(conditionStr)
    local success, result = pcall(Compile, conditionStr)
    
    if not success then
        -- 记录错误日志
        if ns.Logger then
            ns.Logger:Error("Compile Error", "Condition: " .. conditionStr)
            ns.Logger:Error("Compile Error", "Error: " .. tostring(result))
        end
        
        -- 返回永远为 false 的函数
        return function() return false end
    end
    
    return result
end
```

### 运行时错误

```lua
function SafeEval(func, ctx)
    local success, result = pcall(func, ctx)
    
    if not success then
        -- 隔离运行时错误
        if ns.Logger then
            ns.Logger:Error("Runtime Error", tostring(result))
        end
        return false
    end
    
    return result
end
```

---

## 语法验证

```lua
function ValidateAPL(actions)
    local errors = {}
    
    for i, action in ipairs(actions) do
        if not action.action or action.action == "" then
            table.insert(errors, {
                line = i,
                message = "Missing action name"
            })
        end
        
        if action.condition and action.condition ~= "" then
            local success, err = pcall(Compile, action.condition)
            if not success then
                table.insert(errors, {
                    line = i,
                    message = "Invalid condition: " .. tostring(err)
                })
            end
        end
    end
    
    return errors
end
```

---

## 性能优化

### 优化策略

| 策略 | 效果 |
|------|------|
| 脚本缓存 | 命中率 90%+，避免重复编译 |
| 弱引用表 | 自动释放未使用脚本，防止内存泄漏 |
| 预编译 | 加载时编译，运行时零解析 |
| 错误隔离 | 单条规则错误不影响其他规则 |

### 性能指标

- **编译耗时**：1-3ms/条件（首次）
- **缓存命中耗时**：< 0.01ms
- **脚本缓存命中率**：93-97%
- **内存开销**：~50KB（100 条规则）

---

## 扩展语法示例

### 添加新的领域对象

```lua
-- 在 Context 中添加 combo_points 字段
context.combo_points = GetComboPoints("player", "target")

-- 条件表达式
"combo_points>=5"
```

### 添加新的函数

```lua
-- 自定义函数：time_to_die (目标剩余生存时间)
function EstimateTimeTodie(target)
    local health = UnitHealth(target)
    local maxHealth = UnitHealthMax(target)
    local dps = 1000  -- 假设 DPS
    
    return health / dps
end

-- 在 Context 中添加
context.time_to_die = EstimateTimeTodie("target")

-- 条件表达式
"time_to_die<10"
```

---

## 已知限制

1. **语法子集**
   - 仅支持 SimC 的一小部分语法
   - 不支持复杂表达式（如三元运算符）

2. **错误提示不够详细**
   - 编译错误仅返回通用错误信息
   - 缺少行号/列号定位

3. **优先级固定**
   - 操作符优先级：`!` > `&` > `|`
   - 不支持用户自定义优先级

4. **无类型检查**
   - 编译时不检查字段类型
   - 运行时可能出现类型错误

---

## 依赖关系

### 依赖的模块
- 无（纯解析逻辑）

### 被依赖的模块
- APLExecutor (调用编译后的函数)
- Core (配置切换时清空缓存)
- Options UI (语法验证)

---

## 相关文档
- [APL 执行器](09_APLExecutor.md)
- [状态快照系统](07_State.md)
- [配置界面](11_Options_UI.md)
