# WhackAMole - 插件设计文档 v1.2

## 1. 产品愿景 (Product Vision)
WhackAMole 是一个可视化的输出循环辅助插件。它不直接显示“下一个技能图标”，而是**高亮玩家现有动作条中的特定位置**（或者插件自带的独立动作条）。
它的核心理念是：**"Show, don't tell"（展示位置，而非告知图标）**，帮助玩家建立键位肌肉记忆，并允许高度定制化的逻辑分享。

## 2. 核心功能模块 (Core Modules)

### 2.1 视觉与听觉反馈 (Visual & Audio Feedback)
*   **Grid Frame**: 一个 $N \times M$ 的矩形网格（用户可定义的动作条）。
*   **Runtime Mode (运行模式)**:
    *   插件内核计算出当前应该施放什么技能。
    *   **Visual**: UI 寻找该技能对应的格子，触发 **Glow Effect (边缘发光动画)**。
    *   **Audio (Voice Alerts)**: 如果预测结果发生了变化。
        *   **内置映射**: 插件在 `Core/Constants.lua` 集中管理所有法术音频。支持 `ns.ID.SpellName` 反向查找。
        *   不支持在 Profile 中自定义每个技能的语音，以保持配置简洁。

### 2.2 逻辑内核 (Logic Core - APL Engine)
*   **APL (Action Priority List) System**: 采用 SimC 风格的优先级列表作为核心驱动。
    *   **SimC Engine**: 引擎不再执行 Raw Lua 脚本，而是解析一个有序的动作列表 (Action List)。
    *   **Parser & Compiler**:
        *   参考 Hekili 的实现，并在加载时将 SimC 文本 (e.g., `actions+=/stormstrike,if=cooldown.remains=0`) 编译为 Lua 函数。
        *   这样做既保留了高性能 (编译后本质上还是 Lua Function)，又大大降低了用户编写逻辑的门槛。
*   **Mapping Strategy (映射策略)**:
    *   **Action Name**: 每个动作都有一个唯一标识符 (SimC Name, e.g., `lava_lash`, `earth_shock`).
    *   **Slot Mapping**: Profile 中不再只是简单的 `SpellID -> Slot`，而是建立 `SimC Name -> Slot(s)` 的索引。
    *   **Broadcast**: 当引擎决定 "推荐施放 Lava Lash" 时，它会查找所有绑定了 `lava_lash` 的格子并点亮。
*   **Virtual Time (虚拟时间)**:
    *   引擎不再直接调用 `GetTime()`。而是依赖 `state.now`。
    *   **Time Travel**: 允许引擎通过 `state.advance(seconds)` "快进"时间。这使得我们可以模拟"当前正在读条的技能施放完毕后"的世界状态，从而提前预测下一个技能。
*   **Sandbox**: 提供 `player.buff(id).remains` 等 API。这些 API 会自动根据 `state.now` 计算剩余时间，而不是真实时间。

### 2.3 数据交换层 (Import/Export Layer)
*   所有配置（逻辑脚本 + 槽位定义）被压缩为一个字符串。
*   格式参考 WA 字符串（Base64 + Deflate/LibCompress）。
*   **校验机制**: 字符串头部包含 `ClassID` 和 `SpecID` 校验。

---

## 3. 架构分层 (Architecture)

```mermaid
graph TD
    UserInput[User / Web Editor] -->|Config String| ImportModule
    ImportModule -->|Parse & Validate| ProfileManager
    
    subgraph "Core Engine"
        ProfileManager -->|Load Layout| UIGrid
        ProfileManager -->|Compile SimC APL| LogicSandbox
        WoWEvent[WoW Events] -->|Update State| LogicSandbox
        LogicSandbox -->|Decision: SlotID| UIGrid
    end
    
    UIGrid -->|Glow/Highlight| Screen
    LogicSandbox -->|Decision: SlotID| AudioEngine
    AudioEngine -->|Play Sound "Execute"| Speakers
```

## 4. 数据结构设计 (Data Structures)

### 3.1 核心配置对象 (The Profile)
这是一个可导出的 Table 结构，采用 SimC APL 驱动：

```lua
{
    -- 元数据：定义配置的基本信息
    meta = {
        name = "WotLK 增强萨满 (Titan-Forged)",
        author = "WhackAMole Copilot",
        version = 2, -- V2 for APL support
        class = "SHAMAN",
        spec = 263, -- Enhancement
        date = "2026-01-18",
        desc = "SimC 移植示例"
    },

    -- 布局定义：定义 Action Name 到 Grid Slot 的映射
    -- "action" 字段对应 SimC 中的动作名。
    -- 运行时，插件会自动查表将 action (e.g. "stormstrike") 转换为 SpellID (17364) 以显示图标和Tooltip。
    layout = {
        rows = 1,
        cols = 6,
        slots = {
            -- Slot 1: 风暴打击 (对应 APL 中的 stormstrike)
            [1] = { action = "stormstrike" },
            -- Slot 2: 熔岩猛击
            [2] = { action = "lava_lash" },
            -- Casting Slot
            [3] = { action = "lightning_bolt" },
            -- ...
        }
    },

    -- 优先级列表 (APL)
    -- 这是一个有序列表，引擎从上到下遍历。
    -- 支持两种格式：
    -- 1. 解析后的 Table (性能更好，加载快)
    -- 2. 原始 SimC 字符串 (需运行时解析)
    apl = {
        -- 优先处理高优先级技能
        { action = "wind_shear", condition = "target.casting" },
        { action = "shamanistic_rage", condition = "mana.pct<30" },
        
        -- 循环主体 (示例)
        "actions+=/stormstrike,if=debuff.stormstrike.down",
        "actions+=/lava_lash,if=cooldown.lava_lash.ready",
        "actions+=/earth_shock,if=buff.stormstrike.up",
        "actions+=/lightning_shield,if=buff.lightning_shield.down",
    }
}
```

---

## 5. UI 交互流程 (User Flow)

### 5.1 首次使用 / 导入流程
1.  用户打开 WhackAMole 面板 (`/wam`)。
2.  点击 **"Import"**，粘贴字符串。
3.  系统解析字符串，检测职业/天赋匹配。
4.  **映射阶段**:
    *   **用户操作**：用户需要将自己的技能书里的图表拖拽到这个格子里。
    *   这一步是为了让插件知道：**“Slot X”对应用户期望的哪个技能**。

### 5.2 战斗流程
1.  `OnUpdate` 循环触发引擎。
2.  **Snapshot**: 引擎获取当前状态 (`GetTime`, Buffs, Cooldowns)。
3.  **Evaluate**: 引擎遍历 APL 列表，执行 Lua-compiled 条件。
4.  **Decision**: 命中第一条满足条件的 Action (e.g., "lava_lash")。
5.  **Lookup**: 查找绑定了 "lava_lash" 的所有 Slot (e.g., Slot 2)。
6.  **Highlight**: UI 层查找 Slot 2 对应的 Frame，绘制金色呼吸灯发光。

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
    *   **方案 A (独立动作条)**: WhackAMole 自带一个动作条，用户必须把技能拖进来。这是最简单的。
    *   **方案 B (Overlay 覆盖层)**: WhackAMole 只是一个透明的“蒙版”，用户拖拽框体覆盖在自己的 ElvUI 动作条上。这需要复杂的坐标计算。
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
*   `WhackAMole.toc`: 插件索引文件，定义依赖 (Ace3, LibCustomGlow, etc.) 和加载顺序。
*   `Core.lua`: 插件入口。初始化 `AceAddon`，处理 `OnInitialize`, `OnEnable`。
*   `embeds.xml`: 引用所有第三方库。

### Core/ (核心代码)
*   `Core/SpecDetection.lua`: **[New]** 专精检测模块，提供 `ns.SpecDetection:GetSpecID()`。
*   `Core/Constants.lua`: **[New]** 全局常量 (ClassID, SpecID, Spells)。数据中心，包含音频和法术 ID 定义。
*   `Core/Utils.lua`: 通用工具函数。
*   `Core/Serializer.lua`: 处理字符串的压缩、解压、校验逻辑 (Import/Export, LibDeflate + LibBase64)。
*   `Core/ProfileManager.lua`: 管理配置文件的加载、存储、默认预设。

### Engine/ (逻辑引擎)
*   `Engine/State.lua`: **核心状态机**。实现"虚拟时间"(Virtual Time)机制。支持 `state.now` 和 `state.advance(seconds)` 以进行未来预测模拟。
*   `Engine/SimCParser.lua`: **[New]** 负责将 SimC 文本解析并编译为 Lua Function。
*   `Engine/APLExecutor.lua`: 负责在运行时遍历 APL 并执行条件检查。

### Classes/ (职业模块)
*   `Classes/Mage.lua`: 法师逻辑。
*   `Classes/DeathKnight.lua`: DK 逻辑。

### UI/ (界面层)
*   `UI/Grid.lua`: **[New]** 负责绘制主动作条网格 (Grid) 和 Glow 效果。
*   `UI/Options.lua`: **[New]** 配置面板逻辑 (AceConfig-3.0)。

### Tests/ (单元测试)
*   `Tests/run_tests.lua`: 测试入口。
*   `Tests/MockWoW.lua`: WoW API 模拟器。

### Locales/ (本地化)
*   `Locales/enUS.lua`
*   `Locales/zhCN.lua`

### Libs/ (第三方库)
*   `Libs/Ace3/`: 基础框架。
*   `Libs/LibCustomGlow/`: 实现精美的发光效果。
*   `Libs/LibDeflate/`: 字符串压缩。
*   `Libs/LibBase64/`: 编码。

---

## 10. 开发状态与未来计划 (Development Status & Roadmap)

### 已完成功能 (Implemented)
-   **重构 (Refactoring)**:
    - **MVC架构**: 成功分离了 `Core`, `UI`, `SpecDetection`, `Options`。
    - **数据统一**: `Core/Constants.lua` 现在是整个职业法术 ID 和音频的单一数据源。
    - **代码注入 (Injection)**: 实现了 Scheme A，自动将 `S_SpellName` 变量注入用户脚本，消除魔法数字。
-   **品牌重塑**: 项目正式更名为 **WhackAMole (打地鼠)**，并完成所有代码引用替换。
-   **核心架构**: 基于 Hekili 优化的状态机，针对 WotLK 3.3.5a 修复了 `UnitAura` 返回值问题。
-   **基础 UI**: 
    - 实现 $N \times M$ 网格，支持拖拽绑定技能。
    - 新增 **"清除所有按键映射" (Clear Assignments)** 功能，优化 UX。
-   **职业支持**: 
    - 深度适配 **法师 (Fire Mage)** 逻辑。
    - 包含 死亡骑士 (DK) 与 战士 (Warrior) 的基础框架。
-   **配置系统**:
    - 基于 AceConfig-3.0 的完整配置面板。
    - 支持 `/wam` 和 `/wam unlock` 快捷指令。
-   **工程化与部署**:
    - 自动化发布脚本 (`publish.ps1`)，支持 `.env` 配置与文件过滤。
    - 完成 GitHub 仓库初始化与代码推送。
    - **单元测试**: 新增 `Tests/` 目录和 `MockWoW.lua`，支持本地 Lua 5.1 运行单元测试。
-   **文档与本地化**:
    - `README.md` 全文中文化。
    - 设计文档同步更新至 v1.2。

### 未来计划 (Future Roadmap)
1.  **Web 编辑器**: 开发在线工具，允许用户在网页端可视化编辑布局和逻辑，生成导入字符串。
2.  **高级预测**: 完善 `Engine` 的预测模型，支持读条期间的资源扣除和 Buff 触发模拟。
3.  **更多专精适配**: 扩展支持 惩戒骑、暗牧、痛苦术 等 WotLK 热门专精。
4.  **性能优化**: 针对大型团本环境（如 ICC 25H）进行 Lua 内存与 CPU 占用优化。

---

## 11. 附录：技术复用指南 (Migration Guide from Hekili)

WhackAMole 并非从零开始，我们将复用 Hekili 约 60% 的底层代码。这些代码经过了多年的生产环境验证，极其稳定。

### 11.1 核心工具类 (Utilities) -> **直接复用**
*   **来源文件**: `Hekili/Utils.lua`
*   **WhackAMole 对应**: `WhackAMole/Utils.lua`
*   **复用内容**: 
    - `ns.FindUnitBuffByID` / `ns.FindUnitDebuffByID`: 极其高效的 Aura 查找封装。
    - `ns.deepCopy`: 深度拷贝 Table。
    - `ns.formatKey`: 字符串 Key 归一化处理。

### 11.2 状态管理 (State Machine) -> **核心修改复用**
这是最复杂的模块，我们将 fork `Hekili/State.lua` 并进行精简。
*   **来源文件**: `Hekili/State.lua`
*   **WhackAMole 对应**: `WhackAMole/Engine/State.lua`
*   **保留**:
    - `state.reset()`: 每次 Decision Cycle 开始前获取真实游戏数据的逻辑（Sync with Game Client）。
    - `mt_state` (元表): 实现 `state.buff.foo.up` 转译为函数调用的魔法（元表黑科技）。
    - `state.cooldown`: 智能的 CD 管理层，支持充能系统 (Charge System)。
    - `state.history`: 施法历史记录，用于判断 "上一个技能是什么"。
*   **移除**:
    - 移除 `Predictive Engine` (长线预测引擎)：WhackAMole 不需要模拟未来 10 秒的 5 个技能，只需要判断**当前**点亮谁，或者最多预判 1 个 GCD。
    - 移除 `Pack` / `List` 相关的 APL 遍历逻辑。

### 11.3 职业模块 (Class Modules) -> **数据定义复用**
*   **来源文件**: `Hekili/Classes.lua` 及 `Hekili/Wrath/*.lua` (例如 `Paladin.lua`)
*   **WhackAMole 对应**: `WhackAMole/Classes/Warrior.lua` 等
*   **复用内容**: 
    - **Spell Data**: 技能 ID 映射表，包括 `toggle` 类型定义。
    - **Talent Mapping**: `spec:RegisterTalents(...)` 中的天赋 ID 映射表，这是无价之宝，如果不复用需要手动查几百个 TalentID。
    - **Set Bonuses**: `spec:RegisterGear(...)` 中对 T7/T8/T9/T10 套装 ItemID 的定义。
    - **Combat Log Hooks**: 处理特殊资源（如：盾击层数、灭寂触发白霜）的战斗日志监听逻辑。

### 11.4 事件驱动 (Event System) -> **逻辑复用**
*   **来源文件**: `Hekili/Events.lua`
*   **WhackAMole 对应**: `WhackAMole/Core/Events.lua`
*   **复用内容**: 
    - `COMBAT_LOG_EVENT_UNFILTERED` 解析器：Hekili 已经处理好了源/目标 GUID 过滤。
    - `UNIT_SPELLCAST_SUCCEEDED` 监听：用于确认技能施放成功并扣除资源。
    - **De-bouncing (防抖)**: Hekili 包含防止同一帧多次触发计算的逻辑，这部分代码可以直接拿来用。

### 11.5 差异化开发 (需要新写的部分)
*   **UI Grid System**: `Hekili/UI.lua` 是基于图标队列的，WhackAMole 是基于固定网格高亮的。**这部分无法复用，需要重写**。
*   **Import/Export**: Hekili 使用 SimC 文本格式，WhackAMole 将使用压缩 Table 格式。这部分需要参考 `WeakAuras` 的序列化代码。


