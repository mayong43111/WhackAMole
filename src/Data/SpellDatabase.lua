local addon, ns = ...

-- =========================================================================
-- Data/SpellDatabase.lua - 技能效果数据库
-- =========================================================================

local SpellDatabase = {}
ns.SpellDatabase = SpellDatabase

-- 技能效果数据配置（集中管理）
-- 只配置确定性效果，不配置随机触发
local SPELL_DATA = {
    -- =========================================================================
    -- 盗贼技能 (Rogue)
    -- =========================================================================
    rip = {
        debuff = { name = "rip", duration = 12 },
        cost = { comboPoints = 5 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    sinister_strike = {
        gain = { comboPoints = 1 },
        cost = { energy = 45 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    eviscerate = {
        cost = { comboPoints = 5 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    slice_and_dice = {
        buff = { name = "slice_and_dice", duration = 9 },  -- 基础持续时间（1连击点）
        cost = { comboPoints = 1 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    
    -- =========================================================================
    -- 法师技能 (Mage)
    -- =========================================================================
    frostbolt = {
        cost = { mana = 330 },
        castTime = 2.5,
        gcd = 1.5
    },
    icy_veins = {
        buff = { name = "icy_veins", duration = 20 },
        cooldown = 180,
        gcd = 1.5
    },
    ice_lance = {
        cost = { mana = 180 },
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    frostfire_bolt = {
        cost = { mana = 330 },
        castTime = 3.0,  -- 默认施法时间（思维冷却时瞬发）
        gcd = 1.5
    },
    
    -- =========================================================================
    -- 德鲁伊技能 (Druid)
    -- =========================================================================
    mangle_cat = {
        gain = { comboPoints = 1 },
        cost = { energy = 45 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    rake = {
        debuff = { name = "rake", duration = 9 },
        gain = { comboPoints = 1 },
        cost = { energy = 35 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    shred = {
        gain = { comboPoints = 1 },
        cost = { energy = 60 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    savage_roar = {
        buff = { name = "savage_roar", duration = 9 },  -- 基础持续时间（1连击点）
        cost = { comboPoints = 1 },
        castTime = 0,  -- 瞬发
        gcd = 1.0
    },
    cat_form = {
        buff = { name = "cat_form", duration = -1 },  -- -1 表示持续直到取消
        cost = { mana = 0 },  -- 进入形态不消耗法力
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    bear_form = {
        buff = { name = "bear_form", duration = -1 },
        cost = { mana = 0 },
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    
    -- =========================================================================
    -- 战士技能 (Warrior)
    -- =========================================================================
    mortal_strike = {
        cost = { rage = 30 },
        cooldown = 6,  -- 6秒CD
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    overpower = {
        cost = { rage = 5 },
        cooldown = 5,  -- 5秒CD
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    execute = {
        cost = { rage = 10 },  -- 基础消耗10怒气
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    rend = {
        debuff = { name = "rend", duration = 15 },  -- 撕裂DoT 15秒
        cost = { rage = 10 },
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
    slam = {
        cost = { rage = 15 },
        castTime = 1.5,  -- 1.5秒施法
        gcd = 1.5
    },
    bladestorm = {
        cooldown = 90,  -- 90秒CD
        cost = { rage = 25 },
        castTime = 0,  -- 瞬发（但会引导6秒）
        gcd = 1.5
    },
    heroic_strike = {
        cost = { rage = 15 },
        castTime = 0,  -- 下次近战替换，视为瞬发
        gcd = 1.5
    },
    thunder_clap = {
        debuff = { name = "thunder_clap", duration = 30 },  -- 减速debuff
        cost = { rage = 20 },
        cooldown = 6,  -- 6秒CD
        castTime = 0,  -- 瞬发
        gcd = 1.5
    },
}

--- 获取技能数据
-- @param action SimC action名称
-- @return table|nil 技能数据，不存在则返回nil
function SpellDatabase.Get(action)
    return SPELL_DATA[action]
end

--- 获取技能施法时间
-- @param action SimC action名称
-- @return number 施法时间（秒），瞬发技能返回 GCD（1.5秒）
function SpellDatabase.GetCastTime(action)
    local data = SPELL_DATA[action]
    if data then
        local castTime = data.castTime
        -- 明确区分：castTime = 0（瞬发） vs castTime = nil（未定义）
        if castTime and castTime > 0 then
            return castTime
        end
        -- 瞬发或未定义，返回 GCD
        return data.gcd or 1.5
    end
    -- 未知技能默认 GCD
    return 1.5
end

--- 注册自定义技能数据（供插件扩展）
-- @param action SimC action名称
-- @param data 技能数据表
function SpellDatabase.Register(action, data)
    if not action or not data then return end
    SPELL_DATA[action] = data
end

--- 批量注册技能数据
-- @param spells 技能数据表 { action = data, ... }
function SpellDatabase.RegisterBatch(spells)
    if type(spells) ~= "table" then return end
    for action, data in pairs(spells) do
        SPELL_DATA[action] = data
    end
end

return SpellDatabase
