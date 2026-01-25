local _, ns = ...
ns = ns or {}
local SimCParser = {}
ns.SimCParser = SimCParser

-- ============================
-- 脚本缓存系统
-- ============================
-- 使用弱引用表自动清理内存
local compiledScripts = setmetatable({}, { __mode = "v" })
local compileStats = {
    hits = 0,
    misses = 0,
    total = 0
}

-- 获取缓存统计
function SimCParser.GetCacheStats()
    local hitRate = compileStats.total > 0 
        and (compileStats.hits / compileStats.total * 100) 
        or 0
    return {
        hits = compileStats.hits,
        misses = compileStats.misses,
        total = compileStats.total,
        hitRate = hitRate,
        cacheSize = 0  -- 弱引用表无法准确计数
    }
end

-- 同步缓存统计到Logger
function SimCParser.SyncStatsToLogger()
    if ns.Logger and ns.Logger.enabled then
        ns.Logger:UpdateCacheStats("script", compileStats.hits, compileStats.misses, "set")
    end
end

-- 重置缓存统计
function SimCParser.ResetCacheStats()
    compileStats.hits = 0
    compileStats.misses = 0
    compileStats.total = 0
end

-- 清空脚本缓存（配置更改时调用）
function SimCParser.ClearCache()
    compiledScripts = setmetatable({}, { __mode = "v" })
    compileStats.misses = compileStats.misses + compileStats.total  -- 记录缓存失效
    compileStats.total = 0
    compileStats.hits = 0
end

-- 操作符优先级定义（数字越大优先级越高）
local PRECEDENCE = {
    ["or"] = 1,
    ["|"] = 1,
    ["and"] = 2,
    ["&"] = 2,
    ["not"] = 3,
    ["!"] = 3,
}

-- Lua 关键字和保留字
local LUA_KEYWORDS = {
    ["and"] = true, ["or"] = true, ["not"] = true,
    ["true"] = true, ["false"] = true, ["nil"] = true,
    ["if"] = true, ["then"] = true, ["else"] = true,
    ["end"] = true, ["return"] = true, ["function"] = true,
}

-- 词法分析：将表达式分解为 token 流
local function Tokenize(condStr)
    local tokens = {}
    local i = 1
    local len = #condStr
    
    while i <= len do
        local char = condStr:sub(i, i)
        
        -- 跳过空白字符
        if char:match("%s") then
            i = i + 1
        -- 比较运算符
        elseif char == "!" and condStr:sub(i+1, i+1) == "=" then
            table.insert(tokens, "~=")
            i = i + 2
        elseif char == "=" and condStr:sub(i+1, i+1) == "=" then
            table.insert(tokens, "==")
            i = i + 2
        elseif char == "<" and condStr:sub(i+1, i+1) == "=" then
            table.insert(tokens, "<=")
            i = i + 2
        elseif char == ">" and condStr:sub(i+1, i+1) == "=" then
            table.insert(tokens, ">=")
            i = i + 2
        elseif char == "=" then
            table.insert(tokens, "==")
            i = i + 1
        elseif char == "<" or char == ">" then
            table.insert(tokens, char)
            i = i + 1
        -- 逻辑运算符
        elseif char == "&" then
            table.insert(tokens, "and")
            i = i + 1
        elseif char == "|" then
            table.insert(tokens, "or")
            i = i + 1
        elseif char == "!" then
            table.insert(tokens, "not")
            i = i + 1
        -- 括号
        elseif char == "(" or char == ")" then
            table.insert(tokens, char)
            i = i + 1
        -- 标识符或数字
        elseif char:match("[%a_]") then
            local j = i
            while j <= len and condStr:sub(j, j):match("[%w_]") do
                j = j + 1
            end
            table.insert(tokens, condStr:sub(i, j-1))
            i = j
        elseif char:match("%d") then
            local j = i
            local hasDot = false
            while j <= len do
                local c = condStr:sub(j, j)
                if c:match("%d") then
                    j = j + 1
                elseif c == "." and not hasDot then
                    hasDot = true
                    j = j + 1
                else
                    break
                end
            end
            table.insert(tokens, condStr:sub(i, j-1))
            i = j
        -- 点号（用于访问嵌套字段）
        elseif char == "." then
            table.insert(tokens, ".")
            i = i + 1
        else
            -- 未知字符，跳过
            i = i + 1
        end
    end
    
    return tokens
end

-- 解析表达式（支持优先级和括号）
local function ParseExpression(tokens)
    local pos = 1
    
    local function peek()
        return tokens[pos]
    end
    
    local function consume()
        local token = tokens[pos]
        pos = pos + 1
        return token
    end
    
    -- 前向声明
    local parseAtom, parseComparison, parseAnd, parseOr
    
    -- 解析原子（变量、数字、括号表达式）
    function parseAtom()
        local token = peek()
        
        if not token then
            return "true"
        end
        
        -- 括号表达式
        if token == "(" then
            consume() -- (
            local expr = parseOr()
            if peek() == ")" then
                consume() -- )
            end
            return "(" .. expr .. ")"
        end
        
        -- not 运算符
        if token == "not" then
            consume()
            return "not " .. parseAtom()
        end
        
        -- 变量或数字
        consume()
        
        -- 数字字面量
        if tonumber(token) then
            return token
        end
        
        -- Lua 关键字
        if LUA_KEYWORDS[token] then
            return token
        end
        
        -- 变量（需要添加 state. 前缀）
        local varPath = "state." .. token
        
        -- 处理点号访问（如 buff.hot_streak.up）
        while peek() == "." do
            consume() -- .
            local field = consume()
            if field then
                varPath = varPath .. "." .. field
            end
        end
        
        return varPath
    end
    
    -- 解析比较表达式
    function parseComparison()
        local left = parseAtom()
        local op = peek()
        
        if op == "==" or op == "~=" or op == "<" or op == ">" or op == "<=" or op == ">=" then
            consume()
            local right = parseAtom()
            return left .. " " .. op .. " " .. right
        end
        
        return left
    end
    
    -- 解析 AND 表达式
    function parseAnd()
        local left = parseComparison()
        
        while peek() == "and" do
            consume()
            local right = parseComparison()
            left = left .. " and " .. right
        end
        
        return left
    end
    
    -- 解析 OR 表达式（最低优先级）
    function parseOr()
        local left = parseAnd()
        
        while peek() == "or" do
            consume()
            local right = parseAnd()
            left = left .. " or " .. right
        end
        
        return left
    end
    
    return parseOr()
end

function SimCParser.ParseCondition(condStr)
    if not condStr or condStr == "" then
        return "true"
    end
    
    -- 词法分析
    local success, tokens = pcall(Tokenize, condStr)
    if not success then
        ns.Logger:Warn("SimCParser", "Tokenize failed for: " .. condStr)
        return "true"
    end
    
    -- 语法分析
    local success, parsed = pcall(ParseExpression, tokens)
    if not success then
        ns.Logger:Warn("SimCParser", "ParseExpression failed for: " .. condStr)
        return "true"
    end
    
    return parsed
end

function SimCParser.Compile(condStr)
    compileStats.total = compileStats.total + 1
    
    -- 检查缓存
    if compiledScripts[condStr] then
        compileStats.hits = compileStats.hits + 1
        
        -- 每100次查询同步一次统计到Logger
        if compileStats.total % 100 == 0 then
            SimCParser.SyncStatsToLogger()
        end
        
        return compiledScripts[condStr]
    end
    
    -- 缓存未命中，编译新函数
    compileStats.misses = compileStats.misses + 1
    
    -- 同步统计
    SimCParser.SyncStatsToLogger()
    
    local luaCode = SimCParser.ParseCondition(condStr)
    
    -- 预处理：将资源对象访问转换为数值访问（解决元表比较问题）
    -- 匹配 state.资源名（但不匹配 state.资源名.属性）
    local resources = {"rage", "energy", "mana", "runic_power", "focus"}
    for _, res in ipairs(resources) do
        -- 使用模式：state.资源名 后面不是 . 或 _
        -- 替换为：(state.资源名._value or state.资源名)
        luaCode = luaCode:gsub("(state%." .. res .. ")([^%._])", "%1._value%2")
        luaCode = luaCode:gsub("(state%." .. res .. ")$", "%1._value")
    end
    
    -- Wrap in a function that takes 'state' as an argument
    local funcBody = "local state = ...; return " .. luaCode
    local func, err = loadstring(funcBody)
    
    if not func then
        ns.Logger:Error("SimCParser", "Compilation error for '" .. condStr .. "': " .. (err or "unknown"))
        ns.Logger:Error("SimCParser", "Generated code: " .. funcBody)
        func = function() return false end
    end
    
    -- 缓存编译结果
    compiledScripts[condStr] = func
    
    return func
end

function SimCParser.ParseActionLine(line)
    line = line:gsub("^actions%+=/", "")
    
    local firstComma = line:find(",")
    local actionName, rest
    
    if firstComma then
        actionName = line:sub(1, firstComma - 1)
        rest = line:sub(firstComma + 1)
    else
        actionName = line
        rest = ""
    end
    
    local conditionFunc = nil
    
    if rest and rest ~= "" then
        -- 查找 if= 条件
        local ifPos = rest:find("if=")
        if ifPos then
            local condStr = rest:sub(ifPos + 3)
            
            -- 移除末尾可能的其他参数（用逗号分隔）
            -- SimC 通常将 if 放在最后，但我们做防御性处理
            local nextComma = condStr:find(",")
            if nextComma then
                condStr = condStr:sub(1, nextComma - 1)
            end
            
            condStr = condStr:gsub("^%s*", ""):gsub("%s*$", "") -- 去除首尾空格
            conditionFunc = SimCParser.Compile(condStr)
        end
    end
    
    if not conditionFunc then
        conditionFunc = function() return true end
    end
    
    return {
        action = actionName:gsub("^%s*", ""):gsub("%s*$", ""), -- 去除空格
        condition = conditionFunc,
        original = line
    }
end

return SimCParser
