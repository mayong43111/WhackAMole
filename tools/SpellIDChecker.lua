-- 泰坦服技能ID检测工具
-- 使用方法：在游戏中运行 /run 加载此脚本，然后使用 /checkspell 刺骨 来检测技能ID

-- 检测技能的实际ID
local function FindSpellID(spellName)
    print("=== 搜索技能: " .. spellName .. " ===")
    
    -- 方法1：遍历技能书
    local i = 1
    while true do
        local name, _, _, _, _, _, id = GetSpellInfo(i, BOOKTYPE_SPELL)
        if not name then break end
        
        if name:find(spellName) then
            print(string.format("技能书 Tab %d: %s (ID: %s)", 1, name, tostring(id)))
        end
        i = i + 1
    end
    
    -- 方法2：直接通过名称查询
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spellName)
    if name then
        print(string.format("GetSpellInfo: %s | 图标: %s", name, icon or "nil"))
    else
        print("GetSpellInfo: 未找到")
    end
    
    -- 方法3：尝试常见的等级版本ID
    local commonIDs = {
        -- 刺骨 (Eviscerate) 可能的ID
        48668, 48669, 31016, 27611, 8623, 11299, 11300, 6761, 1329, 1752,
        -- 伏击 (Ambush) 可能的ID  
        48691, 48690, 26865, 8676, 8675, 2070, 1768, 8721,
        -- 切割 (Slice and Dice)
        6774, 5171,
        -- 暗影之舞 (Shadow Dance)
        51713,
    }
    
    print("\n检测常见ID范围:")
    for _, id in ipairs(commonIDs) do
        local n, r, ic = GetSpellInfo(id)
        if n and n:find(spellName) then
            print(string.format("ID %d: %s (等级: %s)", id, n, r or "无"))
        end
    end
    
    print("=== 检测完成 ===\n")
end

-- 注册命令
SLASH_CHECKSPELL1 = "/checkspell"
SlashCmdList["CHECKSPELL"] = function(msg)
    if msg and msg ~= "" then
        FindSpellID(msg)
    else
        print("用法: /checkspell 技能名称")
        print("例如: /checkspell 刺骨")
    end
end

print("技能ID检测工具已加载！使用 /checkspell 技能名称 来检测")
