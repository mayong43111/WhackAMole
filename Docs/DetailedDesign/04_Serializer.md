# 04 - 序列化与导入导出详细设计

## 模块概述

**文件**: `src/Core/Serializer.lua`

Serializer 负责配置的序列化/反序列化、压缩/解压缩和编码/解码，支持配置的导入/导出功能。

---

## 职责

1. **序列化**：Lua Table → String
2. **反序列化**：String → Lua Table
3. **压缩**：减小字符串大小
4. **解压缩**：还原压缩数据
5. **编码**：Base64 编码（适合聊天框粘贴）
6. **解码**：Base64 解码

---

## 数据流

```
导出: Profile → Serialize → Compress → Encode → String
导入: String → Decode → Decompress → Deserialize → Profile
```

---

## 序列化实现

### 序列化 (Lua Table → String)

```lua
function Serializer:Serialize(profile)
    local parts = {}
    
    -- 序列化为 Lua 代码
    table.insert(parts, "return {")
    
    -- Meta
    table.insert(parts, "meta={")
    for k, v in pairs(profile.meta) do
        table.insert(parts, k .. "=" .. self:SerializeValue(v) .. ",")
    end
    table.insert(parts, "},")
    
    -- Actions
    table.insert(parts, "actions={")
    for _, action in ipairs(profile.actions) do
        table.insert(parts, "{")
        table.insert(parts, "action=" .. self:SerializeValue(action.action) .. ",")
        table.insert(parts, "condition=" .. self:SerializeValue(action.condition) .. ",")
        table.insert(parts, "},")
    end
    table.insert(parts, "},")
    
    -- Layout
    table.insert(parts, "layout=" .. self:SerializeTable(profile.layout))
    
    table.insert(parts, "}")
    
    return table.concat(parts)
end

function Serializer:SerializeValue(val)
    local t = type(val)
    
    if t == "string" then
        return string.format("%q", val)  -- 引号包裹
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        return self:SerializeTable(val)
    else
        return "nil"
    end
end
```

### 反序列化 (String → Lua Table)

```lua
function Serializer:Deserialize(str)
    -- 加载 Lua 代码
    local func, err = loadstring(str)
    
    if not func then
        return nil, "Failed to parse: " .. err
    end
    
    -- 执行获取表
    local success, profile = pcall(func)
    
    if not success then
        return nil, "Failed to execute: " .. profile
    end
    
    return profile, nil
end
```

---

## 压缩与解压

使用 **LibDeflate** 库进行 DEFLATE 压缩。

```lua
local LibDeflate = LibStub:GetLibrary("LibDeflate")

function Serializer:Compress(str)
    return LibDeflate:CompressDeflate(str)
end

function Serializer:Decompress(compressed)
    return LibDeflate:DecompressDeflate(compressed)
end
```

---

## 编码与解码

使用 **Base64** 编码，适合聊天框粘贴。

```lua
function Serializer:Encode(data)
    return LibDeflate:EncodeForPrint(data)
end

function Serializer:Decode(encoded)
    return LibDeflate:DecodeForPrint(encoded)
end
```

---

## 完整导出流程

```lua
function Serializer:ExportProfile(profile)
    -- 1. 序列化
    local serialized = self:Serialize(profile)
    
    -- 2. 压缩
    local compressed = self:Compress(serialized)
    
    -- 3. 编码
    local encoded = self:Encode(compressed)
    
    return encoded
end
```

---

## 完整导入流程

```lua
function Serializer:ImportProfile(str)
    -- 1. 解码
    local decoded = self:Decode(str)
    if not decoded then
        return nil, "Invalid Base64 string"
    end
    
    -- 2. 解压
    local decompressed = self:Decompress(decoded)
    if not decompressed then
        return nil, "Decompression failed"
    end
    
    -- 3. 反序列化
    local profile, err = self:Deserialize(decompressed)
    if not profile then
        return nil, err
    end
    
    return profile, nil
end
```

---

## 校验机制

```lua
function Serializer:Validate(profile)
    -- 1. 类型检查
    if type(profile) ~= "table" then
        return false, "Profile must be a table"
    end
    
    -- 2. 必需字段
    if not profile.meta or not profile.actions or not profile.layout then
        return false, "Missing required fields"
    end
    
    -- 3. 职业匹配
    local _, playerClass = UnitClass("player")
    if profile.meta.class ~= playerClass then
        return false, "Class mismatch"
    end
    
    return true, nil
end
```

---

## 错误处理

| 错误类型 | 处理方式 |
|---------|---------|
| 解码失败 | 返回 nil + 错误信息 |
| 解压失败 | 返回 nil + 错误信息 |
| 反序列化失败 | 返回 nil + 错误信息 |
| 校验失败 | 返回 nil + 错误信息 |

---

## 依赖关系

### 依赖的库
- LibDeflate (压缩/解压/编码/解码)

### 被依赖的模块
- Options UI (导入/导出界面)
- ProfileManager (保存用户配置)

---

## 相关文档
- [配置管理系统](02_ProfileManager.md)
- [配置界面](11_Options_UI.md)
