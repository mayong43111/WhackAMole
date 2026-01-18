# Luminary - 插件设计文档 v1.0

## 1. 产品愿景 (Product Vision)
Luminary 是一个可视化的输出循环辅助插件。与 Hekili 不同，它不直接显示“下一个技能图标”，而是**高亮玩家现有动作条中的特定位置**（或者插件自带的独立动作条）。
它的核心理念是：**"Show, don't tell"（展示位置，而非告知图标）**，帮助玩家建立键位肌肉记忆，并允许高度定制化的逻辑分享。

## 2. 核心功能模块 (Core Modules)

### 2.1 视觉与听觉反馈 (Visual & Audio Feedback)
*   **Grid Frame**: 一个 $N \times M$ 的矩形网格（用户可定义的动作条）。
*   **Runtime Mode (运行模式)**:
    *   插件内核计算出当前应该施放什么技能。
    *   **Visual**: UI 寻找该技能对应的格子，触发 **Glow Effect (边缘发光动画)**。
    *   **Audio (Voice Alerts)**: 如果预测结果发生了变化。
        *   **内置映射**: 插件内置所有技能的语音文件（类似于 GladiatorlosSA 或 DBM-Voice）。通过 `SpellID` 自动查表播放（例如 ID 5308 -> 播放 `Sounds/Execute.ogg`）。
        *   不支持在 Profile 中自定义每个技能的语音，以保持配置简洁。

### 2.2 逻辑内核 (Logic Core - The "Engine")
*   **解耦设计**: 引擎**不包含**任何硬编码的输出手法。它只是一个解释器。
*   **Virtual Time (虚拟时间)**:
    *   引擎不再直接调用 `GetTime()`。而是依赖 `state.now`。
    *   **Time Travel**: 允许引擎通过 `state.advance(seconds)` "快进"时间。这使得我们可以模拟"当前正在读条的技能施放完毕后"的世界状态，从而提前预测下一个技能。
*   **Sandbox**: 提供 `player.buff(id).remains` 等 API。这些 API 会自动根据 `state.now` 计算剩余时间，而不是真实时间。
*   **Decision Tree**: 引擎遍历导入的脚本，返回决策结果 —— 但决策结果不是 `SpellID`，而是 `SlotID` (槽位ID)。

### 2.3 数据交换层 (Import/Export Layer)
*   所有配置（逻辑脚本 + 槽位定义）被压缩为一个字符串。
*   格式参考 WA 字符串（Base64 + Deflate/LibCompress）。
*   **校验机制**: 字符串头部包含 `ClassID` 和 `SpecID` 校验，防止将法师的字符串导入给战士。

---

## 3. 架构分层 (Architecture)

```mermaid
graph TD
    UserInput[User / Web Editor] -->|Config String| ImportModule
    ImportModule -->|Parse & Validate| ProfileManager
    
    subgraph "Core Engine"
        ProfileManager -->|Load Layout| UIGrid
        ProfileManager -->|Load Script| LogicSandbox
        WoWEvent[WoW Events] -->|Update State| LogicSandbox
        LogicSandbox -->|Decision: SlotID| UIGrid
    end
    
    UIGrid -->|Glow/Highlight| Screen
    LogicSandbox -->|Decision: SlotID| AudioEngine
    AudioEngine -->|Play Sound "Execute"| Speakers
```

## 4. 数据结构设计 (Data Structures)

### 3.1 核心配置对象 (The Profile)
这是一个可导出的 Table 结构：

```lua
{
    -- 元数据：定义配置的基本信息
    meta = {
        name = "WotLK 武器战 (Titan-Forged)",
        author = "Luminary Copilot",
        version = 1,
        class = "WARRIOR",
        spec = 71, -- Arms (Weapon)
        date = "2026-01-17",
        desc = "基于 Hekili 泰坦时空版 APL 转换。包含斩杀阶段判定与姿态舞提示。"
    },

    -- 布局定义：定义界面上显示哪些技能槽位
    -- 为了模拟肌肉记忆，我们不仅显示'下一个技能'，而是高亮技能所在的固定位置
    layout = {
        rows = 1,
        cols = 6,
        slots = {
            -- Slot 1: 致死打击 (核心循环) - 黄色
            [1] = { 
                type = "spell", 
                id = 12294, -- Mortal Strike 
                color = "FFD700", 
                tooltip = "致死打击: 卡CD使用" 
            },
            -- Slot 2: 压制 (高亮触发) - 橙色
            [2] = { 
                type = "spell", 
                id = 7384, -- Overpower
                color = "FF4500", 
                tooltip = "压制: 触发后立即使用" 
            },
            -- Slot 3: 斩杀 (收尾/猝死) - 红色
            [3] = { 
                type = "spell", 
                id = 5308, -- Execute
                color = "FF0000", 
                tooltip = "斩杀: 20%血量以下或猝死触发时" 
            },
            -- Slot 4: 撕裂 (DoT维护) - 绿色
            [4] = { 
                type = "spell", 
                id = 772, -- Rend
                color = "00FF00", 
                tooltip = "撕裂: 保持DoT覆盖" 
            },
            -- Slot 5: 猛击 (填充) - 蓝色
            [5] = { 
                type = "spell", 
                id = 1464, -- Slam
                color = "00BFFF", 
                tooltip = "猛击: 怒气充足且站桩时使用" 
            },
            -- Slot 6:剑刃风暴 (大爆发) - 紫色
            [6] = { 
                type = "spell", 
                id = 46924, -- Bladestorm
                color = "800080", 
                tooltip = "剑刃风暴: 爆发CD" 
            }
        }
    },

    -- 逻辑脚本：Lua代码，每一帧(或每次事件)运行一次
    -- 返回值: SlotID (要高亮的槽位索引) 或 nil
    script = [[
        -- 引入环境 API
        local target = env.target
        local player = env.player
        local spell = env.spell
        local buff = player.buff
        local debuff = target.debuff

        -- 定义技能ID常量 (WotLK 3.3.5)
        local S_MortalStrike = 12294
        local S_Overpower = 7384
        local S_Execute = 5308
        local S_Rend = 772
        local S_Slam = 1464
        local S_Bladestorm = 46924
        
        -- 定义 Buff/Talent ID
        local B_SuddenDeath = 52437 -- 猝死
        local B_TasteForBlood = 60503 -- 嗜血成性 (压制触发)

        -- 对应 layout.slots 的索引
        local SLOT_MS = 1
        local SLOT_OP = 2
        local SLOT_EXEC = 3
        local SLOT_REND = 4
        local SLOT_SLAM = 5
        local SLOT_BS = 6

        -- 辅助变量
        local active_enemies = env.active_enemies or 1
        local execute_phase = target.health_pct < 20
        local rage = player.power.rage.current

        -------------------------------------------------------------
        -- 优先级 1: 撕裂 (Rend)
        -- 规则: 如果撕裂剩余时间 < 3秒，且目标存活时间够长
        -------------------------------------------------------------
        if debuff(S_Rend).remains < 3 and target.time_to_die > 6 then
            return SLOT_REND
        end

        -------------------------------------------------------------
        -- 优先级 2: 压制 (Overpower)
        -- 规则: 嗜血成性 Buff 存在, 或技能可用(被闪避触发)
        -------------------------------------------------------------
        -- 注意: IsUsableSpell 在脚本层通常会被封装进 spell(id).usable
        if spell(S_Overpower).usable then 
            return SLOT_OP
        end

        -------------------------------------------------------------
        -- 优先级 3: 斩杀 (Execute) - 斩杀阶段
        -- 规则: 目标血量<20%
        -------------------------------------------------------------
        if execute_phase and spell(S_Execute).ready then
            return SLOT_EXEC
        end

        -------------------------------------------------------------
        -- 优先级 4: 剑刃风暴 (Bladestorm) - 非斩杀阶段
        -- 规则: CD就绪, 且没有压制待打 (Simc为了防吞压制)
        -------------------------------------------------------------
        if not execute_phase and spell(S_Bladestorm).ready and not spell(S_Overpower).usable then
            return SLOT_BS
        end

        -------------------------------------------------------------
        -- 优先级 5: 致死打击 (Mortal Strike)
        -- 规则: 卡CD打
        -------------------------------------------------------------
        if spell(S_MortalStrike).ready then
            return SLOT_MS
        end

        -------------------------------------------------------------
        -- 优先级 6: 猝死斩杀 (Execute - Sudden Death)
        -- 规则: 猝死 Buff 触发时，即便不在斩杀线也可以打斩杀
        -------------------------------------------------------------
        if buff(B_SuddenDeath).up and spell(S_Execute).ready then
            return SLOT_EXEC
        end

        -------------------------------------------------------------
        -- 优先级 7: 猛击 (Slam)
        -- 规则: 填充技能，怒气 > 15 且没有在移动
        -------------------------------------------------------------
        -- 注意: assuming env.player.moving is available
        if not player.moving and rage >= 15 and spell(S_Slam).ready then
            return SLOT_SLAM
        end

        -- 如果没有技能可用，返回 nil (不点亮任何格子)
        return nil
    ]]
}
```

---

## 5. UI 交互流程 (User Flow)

### 5.1 首次使用 / 导入流程
1.  用户打开 Luminary 面板。
2.  点击 **"Import"**，粘贴字符串。
3.  系统解析字符串，检测职业/天赋匹配。
    *   *如果不匹配*：弹出警告，禁止导入。
    *   *如果匹配*：加载配置。
4.  **映射阶段 (Mapping Phase)**:
    *   屏幕上出现半透明的矩形动作条。
    *   槽位 1 亮起红色，并在中心显示“嗜血”图标。
    *   **用户操作**：用户需要将自己的技能书里的“嗜血”拖拽到这个格子里（或者通过插件设置这个格子对应快捷键 `1`）。
    *   这一步是为了让插件知道：**“Slot 1”对应玩家界面上的哪个真实按钮**。

### 5.2 战斗流程
1.  `OnUpdate` 循环触发引擎。
2.  引擎运行 `script`。
3.  脚本返回 `return 2`。
4.  UI 层查找 Slot 2 对应的 Frame。
5.  在 Frame 边缘绘制金色呼吸灯发光 (`LibCustomGlow`)。
6.  用户按下对应按键，技能施放，事件触发状态更新。

---

## 6. 在线编辑器设计 (Web Editor Concept)

为了实现“在线编辑后导出”，需要一个配套的 Web 工具 (类似于 wago.io 的 IDE)。

*   **左侧**: 可视化布局编辑器。用户在网页上拖拽 1x5, 2x4 的格子，并给每个格子分配预期技能 ID 和背景色。
*   **中间**: 代码编辑器 (Monaco Editor)。编写 Lua 逻辑或 SimC 风格 DSL。支持语法高亮和自动补全。
*   **右侧**: 模拟器/调试器。网页端模拟 `env` 状态，实时显示脚本会高亮哪个格子（例如拖动“怒气”滑块，看是否会高亮“暴怒”格子）。
*   **底部**: 导出按钮。生成 Base64 字符串。

---

## 7. 技术实现难点与方案

### 7.1 性能隔离
*   **问题**: 用户导入的 Lua 脚本可能有死循环或低效代码。
*   **方案**: 使用 `pcall` 执行脚本，可以在循环中设置指令计数器作为“燃料(Gas)”，防止脚本卡死游戏主线程。

### 7.2 技能匹配与 Mapping
*   **问题**: 用户的技能可能在默认动作条，可能在 Bartender4，也可能在 ElvUI 动作条。
*   **方案**:
    *   **方案 A (独立动作条)**: Luminary 自带一个动作条，用户必须把技能拖进来。这是最简单的。
    *   **方案 B (Overlay 覆盖层)**: Luminary 只是一个透明的“蒙版”，用户拖拽框体覆盖在自己的 ElvUI 动作条上。这需要复杂的坐标计算。
    *   **推荐**: 先实现方案 A。

### 7.3 字符串压缩
*   使用 `LibDeflate` + `LibBase64-1.0`。这是魔兽插件界的标准压缩栈。

---

## 8. 预测引擎与虚拟时间 (Predictive Engine & Virtual Time) (New)

### 8.1 核心挑战
传统的 SimC 模拟器是一次性模拟未来几分钟的战斗。而游戏内插件(Addon)需要在每帧(16ms)内做出决策。
当玩家正在施放一个 2.5秒 的《火球术》时，如果我们只基于"当前"状态做决策，插件会再次推荐《火球术》（因为它还没打出去，目标身上还没有点燃）。
**目标**: 在读条期间，插件应该"看到"读条结束后的未来，并推荐下一个技能。

### 8.2 解决方案：时间旅行 (Time Travel)
我们引入 `state.now` (虚拟当前时间) 的概念，脱离 WoW 的真实 API `GetTime()`。

1.  **快照 (Snapshot)**: 每一帧开始时，`state.reset()` 将 `state.now` 同步为 `GetTime()`。拷贝此时的 Buff/Cooldown 状态。
2.  **第一次模拟 (Now)**: 运行脚本。如果玩家未在施法，直接输出结果。
3.  **预测分支 (Prediction)**: 如果玩家正在施法(endTime > now):
    *   **Advance**: 执行 `state.advance(endTime - now)`。
        *   `state.now` 被推移到未来。
        *   所有 Buff/Debuff 的 `remains` 自动减少。
        *   所有 Cooldown 的 `remains` 自动减少。
        *   资源(Energy/Mana)根据回复速度自动增加。
    *   **Apply Side Effects**: (可选 MVP+) 模拟当前正在读条的法术命中的效果（例如：扣除蓝量，施加Debuff）。*MVP阶段暂不模拟复杂Side Effect，只处理时间推移。*
    *   **第二次模拟 (Next)**: 再次运行脚本。得到"下一个技能"。
4.  **视觉反馈**:
    *   当前技能（如果是瞬发）: 正常高亮。
    *   下一个技能（预测结果）: 使用不同的颜色（例如蓝色呼吸灯）或次级高亮效果。

---

## 9. 项目目录结构设计 (Directory Structure)

### Root
*   `Luminary.toc`: 插件索引文件，定义依赖 (Ace3, LibCustomGlow, etc.) 和加载顺序。
*   `Luminary.lua`: 插件入口。初始化 `AceAddon`，处理 `OnInitialize`, `OnEnable`。
*   `embeds.xml`: 引用所有第三方库。

### Core/ (核心代码)
*   `Core/Constants.lua`: 全局常量（如 ClassID, SpecID 枚举）。
*   `Core/Utils.lua`: 通用工具函数。
*   `Core/Serializer.lua`: 处理字符串的压缩、解压、校验逻辑 (Import/Export, LibDeflate + LibBase64)。
*   `Core/ProfileManager.lua`: 管理配置文件的加载、存储、默认预设。

### Engine/ (逻辑引擎)
*   `Engine/State.lua`: **核心状态机**。实现"虚拟时间"(Virtual Time)机制。支持 `state.now` 和 `state.advance(seconds)` 以进行未来预测模拟。
*   `Engine/ScriptExecutor.lua`: (规划中) 负责安全执行 (`pcall`) 用户导入的 Lua 脚本。

### Presets/ (预设配置)
*   `Presets/Warrior_Arms.lua`: 战士预设逻辑。
*   `Presets/Paladin_Ret.lua`: 惩戒骑预设逻辑。

### GUI/ (界面层)
*   `UI/UI.lua`: 负责绘制主动作条网格 (Grid) 和 Glow 效果。
*   `UI/Options.lua`: 配置面板逻辑 (AceConfig-3.0)。

### Locales/ (本地化)
*   `Locales/enUS.lua`
*   `Locales/zhCN.lua`

### Libs/ (第三方库)
*   `Libs/Ace3/`: 基础框架。
*   `Libs/LibCustomGlow/`: 实现精美的发光效果。
*   `Libs/LibDeflate/`: 字符串压缩。
*   `Libs/LibBase64/`: 编码。

---

## 10. 开发路线图 (Roadmap) - MVP 优先策略

### Phase 0: 概念验证 (PoC - "Hello Glow")
**目标**: 验证 "逻辑 -> 槽位高亮" 的核心链路，不考虑任何架构洁癖。只做一个单一文件插件。
1.  **基础工程**: 创建 `Luminary.toc` 和 `Core.lua`。
2.  **死板的 UI**: 用 Lua 绘制 4 个固定的方块在屏幕中间 (红/绿/蓝/黄)。
3.  **死板的逻辑**:
    *   在 `OnUpdate` 中每 0.1秒检查一次。
    *   `if UnitPower("player") > 50 then Glow(Slot1) else StopGlow(Slot1) end`。
    *   `if UnitHealth("target")/UnitHealthMax("target") < 0.2 then Glow(Slot2) end`。
4.  **验证点**: 确认 `LibCustomGlow` 能在 Grid Frame 上正常工作，且不掉帧。

### Phase 1: 最小可行性产品 (MVP - Hardcoded Warrior)
**目标**: 一个可以实际进本打副本的**武器战**专用插件，没有任何配置界面。
1.  **引入状态机 (State)**: 移植 Hekili 的 `State.lua` (主要为了 `setmetatable` 的魔法访问器 `state.buff.foo.up`)。
2.  **硬编码 Profile**: 将前面设计的 "武器战 Table" 直接写死在 `Modules/Warrior.lua` 中。
3.  **脚本执行器**: 实现 `loadstring` 或 `pcall` 运行 Profile 中的 `script` 字段。
4.  **简单的映射**: 暂时假设 Slot 1-4 对应 ActionButton 1-4 (或者让用户自己把技能拖到一个独立的 Luminary 动作条上)。
5.  **实战测试**: 进木桩测试，确认 "撕裂 -> 压制 -> 斩杀" 的逻辑循环正确点亮。

### Phase 2: 交互与架构完善 (The Architecture)
**目标**: 将硬编码部分解耦，引入配置界面。
1.  **UI 交互**: 实现 Grid 的拖拽移动、锁定/解锁。
2.  **数据层**: 引入 `AceDB`，保存框体位置。
3.  **多职业框架**: 实现 `Loader.lua`，根据玩家职业加载不同模块 (虽然目前只有战士)。

### Phase 3: 配置化与分享 (The Ecosystem)
**目标**: 不需要写代码也能修改逻辑。
1.  **序列化**: 实现 Import/Export 字符串功能。
2.  **配置面板**: 使用 `AceConfig` 制作选项界面。

### Phase 4: 听觉反馈系统 (Audio Feedback)
**目标**: 增加“听觉辅助”，在视觉疲劳时提供第二维度的提示。
1.  **资源库构建**: 集成一套通用的技能语音包 (参考 GladiatorlosSA)。
    *   *Action*: 下载并筛选常用技能语音 (如 "Execute.ogg", "Overpower.ogg")，存放入 `Sounds/` 目录。
2.  **音频引擎**: 实现 `AudioEngine`，监听预测引擎的输出。当 `activeSlot` 或 `nextSlot` 发生关键变化时，查表播放对应语音。
3.  **防刷屏控制 (Throttle)**: 增加 1-2秒 的内置冷却，防止因为高频刷新导致的语音鬼畜。
4.  **配置选项**: 在配置面板增加“开启语音提示”的总开关 (Master Switch)。

---

## 11. 附录：技术复用指南 (Migration Guide from Hekili)

Luminary 并非从零开始，我们将复用 Hekili 约 60% 的底层代码。这些代码经过了多年的生产环境验证，极其稳定。

### 11.1 核心工具类 (Utilities) -> **直接复用**
*   **来源文件**: `Hekili/Utils.lua`
*   **Luminary 对应**: `Luminary/Utils.lua`
*   **复用内容**: 
    - `ns.FindUnitBuffByID` / `ns.FindUnitDebuffByID`: 极其高效的 Aura 查找封装。
    - `ns.deepCopy`: 深度拷贝 Table。
    - `ns.formatKey`: 字符串 Key 归一化处理。

### 11.2 状态管理 (State Machine) -> **核心修改复用**
这是最复杂的模块，我们将 fork `Hekili/State.lua` 并进行精简。
*   **来源文件**: `Hekili/State.lua`
*   **Luminary 对应**: `Luminary/Engine/State.lua`
*   **保留**:
    - `state.reset()`: 每次 Decision Cycle 开始前获取真实游戏数据的逻辑（Sync with Game Client）。
    - `mt_state` (元表): 实现 `state.buff.foo.up` 转译为函数调用的魔法（元表黑科技）。
    - `state.cooldown`: 智能的 CD 管理层，支持充能系统 (Charge System)。
    - `state.history`: 施法历史记录，用于判断 "上一个技能是什么"。
*   **移除**:
    - 移除 `Predictive Engine` (长线预测引擎)：Luminary 不需要模拟未来 10 秒的 5 个技能，只需要判断**当前**点亮谁，或者最多预判 1 个 GCD。
    - 移除 `Pack` / `List` 相关的 APL 遍历逻辑。

### 11.3 职业模块 (Class Modules) -> **数据定义复用**
*   **来源文件**: `Hekili/Classes.lua` 及 `Hekili/Wrath/*.lua` (例如 `Paladin.lua`)
*   **Luminary 对应**: `Luminary/Modules/Warrior.lua` 等
*   **复用内容**: 
    - **Spell Data**: 技能 ID 映射表，包括 `toggle` 类型定义。
    - **Talent Mapping**: `spec:RegisterTalents(...)` 中的天赋 ID 映射表，这是无价之宝，如果不复用需要手动查几百个 TalentID。
    - **Set Bonuses**: `spec:RegisterGear(...)` 中对 T7/T8/T9/T10 套装 ItemID 的定义。
    - **Combat Log Hooks**: 处理特殊资源（如：盾击层数、灭寂触发白霜）的战斗日志监听逻辑。

### 11.4 事件驱动 (Event System) -> **逻辑复用**
*   **来源文件**: `Hekili/Events.lua`
*   **Luminary 对应**: `Luminary/Core/Events.lua`
*   **复用内容**: 
    - `COMBAT_LOG_EVENT_UNFILTERED` 解析器：Hekili 已经处理好了源/目标 GUID 过滤。
    - `UNIT_SPELLCAST_SUCCEEDED` 监听：用于确认技能施放成功并扣除资源。
    - **De-bouncing (防抖)**: Hekili 包含防止同一帧多次触发计算的逻辑，这部分代码可以直接拿来用。

### 11.5 差异化开发 (需要新写的部分)
*   **UI Grid System**: `Hekili/UI.lua` 是基于图标队列的，Luminary 是基于固定网格高亮的。**这部分无法复用，需要重写**。
*   **Import/Export**: Hekili 使用 SimC 文本格式，Luminary 将使用压缩 Table 格式。这部分需要参考 `WeakAuras` 的序列化代码。


