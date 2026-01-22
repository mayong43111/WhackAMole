# WhackAMole - 待办任务

**文档版本**: 2.2  
**更新日期**: 2026-01-22  

---

## 🔄 重构进度（Phase 1 - 核心引擎优化）

### Phase 1.1: State.lua 模块拆分 ✅ **已完成** (2026-01-22)

**重构成果**:
- ✅ 创建 5 个子模块（Init, AuraTracking, StateReset, StateAdvance, 主模块）
- ✅ `FindAura()`: 250行 → 40行（优化 84%）
- ✅ `state.reset()`: 113行 → 30行（优化 73%）
- ✅ `state.advance()`: 86行 → 25行（优化 71%）
- ✅ 单文件行数: 679 → 220（降低 68%）
- ✅ 更新 TOC 文件加载顺序
- ✅ 100% 向后兼容
- 📝 详细报告: `Docs/Refactoring_Phase1.1_Report.md`

### Phase 1.2: Core.lua 模块拆分 ✅ **已完成** (2026-01-22)

**重构成果**:
- ✅ 创建 6 个子模块（Config, Lifecycle, ProfileLoader, EventHandler, UpdateLoop, 主模块）
- ✅ `OnUpdate()`: 95行 → 40行（优化 58%）
- ✅ `InitializeProfile()`: 63行 → 40行（优化 37%）
- ✅ `OnCombatLogEvent()`: 50行 → 35行（优化 30%）
- ✅ 单文件行数: 540 → 240（降低 56%）
- ✅ 更新 TOC 文件加载顺序
- ✅ 100% 向后兼容
- 📝 详细报告: `Docs/Refactoring_Phase1.2_Report.md`

### Phase 1 综合统计 ✅

| 模块 | 原始行数 | 重构后行数 | 文件数 | 优化 |
|------|---------|-----------|--------|------|
| State.lua | 679 | 770 (5个文件) | 5 | ↓68% 单文件 |
| Core.lua | 540 | 820 (6个文件) | 6 | ↓56% 单文件 |
| **总计** | **1219** | **1590 (11个文件)** | **11** | **↓68% 最大文件** |

**待测试项**:
- [ ] 游戏内功能验证
- [ ] 性能基准测试
- [ ] 单元测试编写

### Phase 2: UI 模块优化 🔜 **下一步**

**计划拆分**:
- [ ] `UI/Grid/GridFrame.lua` - 框架创建和布局
- [ ] `UI/Grid/GridSlots.lua` - 技能槽位管理
- [ ] `UI/Grid/GridMenu.lua` - 右键菜单逻辑（包含 InitMenu 优化）
- [ ] `UI/Grid/GridDragDrop.lua` - 拖放交互
- [ ] `UI/Grid/GridAnimation.lua` - 动画和高亮效果

**优化目标**:
- [ ] `InitMenu()`: 337行 → <50行
- [ ] 单文件行数: 498 → <250行

---

## 📊 任务统计

| 分类 | 总数 | 已完成 | 进行中 | 待办 | 完成率 |
|------|------|--------|--------|------|--------|
| **代码重构** | 3 | 1 | 0 | 2 | 33% |
| **职业模块完善** | 30 | 30 | 0 | 0 | 100% |
| **DebugWindow 实现** | 13 | 13 | 0 | 0 | 100% |
| **测试与文档** | 15 | 0 | 0 | 15 | 0% |
| **技术债务** | 2 | 2 | 0 | 0 | 100% |
| **详细设计** | 1 | 1 | 0 | 0 | 100% |
| **总计** | 64 | 47 | 0 | 17 | 73% |

**优先级分布**:
- ✅ 已完成: 46 项（职业模块 + 技术债务 + 调试窗口设计 + DebugWindow 完整实现）
- �📚 中优先级: 10 项（用户文档）
- ⚙️ 低优先级: 12 项（单元测试 + API 验证）

---

## 📋 任务列表

### P0 - 职业模块完善 🔥

#### ✅ 当前状态

**Warrior (战士)**:
- ✅ 基础结构完整
- ✅ Execute/Sudden Death 特殊机制已实现
- ✅ 核心技能已覆盖（Arms/Fury/Protection）

**Mage (法师)**:
- ✅ Fire 专精技能完整
- ✅ Frost 专精技能完整（新增 8 项）
- ✅ Arcane 专精技能完整（新增 6 项）
- ✅ 通用技能完整（新增 7 项）

---

#### 1.1 Mage 技能映射 ✅ **已完成**

**文件**: `src/Classes/Mage.lua`

**Frost 专精** (8 项):
- [x] Frostbolt (116)
- [x] Ice Lance (30455)
- [x] Frost Nova (122)
- [x] Cold Snap (11958)
- [x] Summon Water Elemental (31687)
- [x] Deep Freeze (44572)
- [x] Fingers of Frost (Buff, 44544)
- [x] Brain Freeze (Buff, 57761)

**Arcane 专精** (6 项):
- [x] Arcane Blast (30451)
- [x] Arcane Missiles (5143)
- [x] Arcane Barrage (44425)
- [x] Arcane Power (12042)
- [x] Presence of Mind (12043)
- [x] Missile Barrage (Buff, 44401)

**通用技能** (7 项):
- [x] Mana Shield (1463)
- [x] Frost Armor (7301)
- [x] Molten Armor (30482)
- [x] Mage Armor (6117)
- [x] Invisibility (66)
- [x] Spellsteal (30449)
- [x] Remove Curse (475)


---

#### 1.2 Warrior 通用技能 ✅ **已完成**

**文件**: `src/Classes/Warrior.lua`

**通用技能** (8 项):
- [x] Taunt (355)
- [x] Challenging Shout (1161)
- [x] Mocking Blow (694)
- [x] Cleave (845)
- [x] Demoralizing Shout (1160)
- [x] Retaliation (20230)
- [x] Commanding Shout (469)
- [x] Berserker Rage (18499)

**专精技能** (3 项):
- [x] Heroic Fury - Fury (60970)
- [x] Rampage (Buff) - Fury (29801)
- [x] Taste for Blood (Buff) - Arms (60503)


---

#### 1.3 职业特殊机制 ⚙️ **低优先级**

**实现方式**: 通过钩子系统（参考 Execute 实现）

**Warrior** (2 项):
- [ ] Overpower / Taste for Blood 特殊处理
- [ ] Bloodsurge / Instant Slam 特殊处理

**Mage** (4 项):
- [ ] Hot Streak 自动触发检测
- [ ] Missile Barrage 自动检测
- [ ] Brain Freeze 自动检测
- [ ] Fingers of Frost 自动检测

**优先级**: ⚙️ **可选增强**  
**预计工作量**: 2-3 小时

---

#### 1.4 天赋定义 📝 **可选**

**当前状态**: 当前 APL 未使用天赋条件判断（如 `talent.hot_streak.enabled`），暂不需要。

**如果将来需要**，参考结构：
```lua
ns.Classes.MAGE.Talents = {
    Fire = {
        {name = "Hot Streak", ranks = 1},
        {name = "Living Bomb", ranks = 3},
        -- ...
    }
}
```

**优先级**: 📝 **待定**

---

### P0 - DebugWindow 实现 🔥 **高优先级**

#### 4.1 核心窗口框架

**文件**: 新建 `src/Core/DebugWindow.lua`

**基础结构** (3 项):
- [x] 创建 DebugWindow 模块框架（AceAddon + AceEvent + AceTimer）
- [x] 实现 Show/Hide 窗口管理函数
- [x] 实现多页签容器（TabGroup）及页签切换逻辑

**数据结构** (1 项):
- [x] 初始化核心数据结构（logs/performance/cache/realtime）

**预计工作量**: 2-3 小时

---

#### 4.2 控制按钮组

**文件**: `src/Core/DebugWindow.lua`

**按钮功能** (4 项):
- [x] 实现启动监控按钮（StartMonitoring 函数）
- [x] 实现停止监控按钮（StopMonitoring 函数）
- [x] 实现重置统计按钮（ResetStats 函数）
- [x] 实现导出日志按钮（ExportLogs 函数）

**状态管理** (1 项):
- [x] 按钮状态切换逻辑（禁用/启用）

**预计工作量**: 1-2 小时

---

#### 4.3 日志页签实现

**文件**: `src/Core/DebugWindow.lua`

**日志功能** (2 项):
- [x] 实现 CreateLogTab 函数（滚动列表显示）
- [x] 实现 Log 函数（添加日志行，自动刷新）

**日志过滤** (1 项):
- [x] 实现日志分类过滤器（Combat/State/APL/Error/Warn）

**预计工作量**: 1-2 小时

---

#### 4.4 性能分析页签

**文件**: `src/Core/DebugWindow.lua`

**性能展示** (3 项):
- [x] 实现 CreatePerfTab 函数（关键指标摘要）
- [x] 实现 GenerateFrameTimeChart 函数（ASCII 趋势图）
- [x] 实现 GenerateModuleStats 函数（模块耗时表格）

**数据采集** (1 项):
- [x] 集成 Core 模块的性能数据采集（帧耗时、模块统计）

**预计工作量**: 2-3 小时

---

#### 4.5 缓存统计页签

**文件**: `src/Core/DebugWindow.lua`

**缓存展示** (1 项):
- [x] 实现 CreateCacheTab 函数（查询缓存/脚本缓存统计）

**数据集成** (1 项):
- [x] 从 State 和 SimCParser 模块获取缓存统计数据

**预计工作量**: 1 小时

---

#### 4.6 实时监控页签

**文件**: `src/Core/DebugWindow.lua`

**实时指标** (2 项):
- [x] 实现 CreateRealtimeTab 函数（FPS/帧耗时/内存/缓存）
- [x] 实现 UpdateRealtime 定时器（0.5 秒更新）

**可视化组件** (1 项):
- [x] 实现 AddLabelWithProgress 函数（进度条 + 颜色编码）

**预计工作量**: 1-2 小时

---

#### 4.7 命令行集成

**文件**: `src/Core/Core.lua`

**命令更新** (1 项):
- [x] 修改 OnChatCommand 函数，添加 `/wam debug` 命令处理

**帮助信息** (1 项):
- [x] 更新帮助文本（移除 `/wam profile`）

**预计工作量**: 0.5 小时

---

**DebugWindow 总计**: 13 项任务，预计 9-13.5 小时

**参考文档**: [调试与性能监控详细设计](DetailedDesign/06_Logger.md)

---

### P1 - 用户文档 📚 **中优先级**

#### 2.1 快速开始指南

**文件**: 新建 `Docs/User/QuickStart.md`

**内容** (3 项):
- [ ] 安装步骤（下载、解压、放置到 AddOns 目录）
- [ ] 首次配置流程（选择专精、加载预设配置）
- [ ] 基础命令说明（`/wam lock/unlock/debug/state` 等）

**预计工作量**: 1 小时

---

#### 2.2 APL 语法参考手册

**文件**: 新建 `Docs/User/APL_Reference.md`

**内容** (3 项):
- [ ] 条件语法完整列表（比较运算符、逻辑运算符）
- [ ] 字段访问规则（`buff.*.up/down/remains`, `cooldown.*.ready` 等）
- [ ] 实战示例（战士/法师/萨满）

**预计工作量**: 2-3 小时

---

#### 2.3 常见问题 FAQ

**文件**: 新建 `Docs/User/FAQ.md`

**内容** (4 项):
- [ ] 高亮不显示？（检查专精、配置、APL 语法）
- [ ] 如何导入配置？（配置界面导入流程）
- [ ] 如何调试 APL？（`/wam debug` 打开调试窗口，启动监控）
- [ ] 性能优化建议（缓存命中率、脚本编译）

**预计工作量**: 1 小时

---

### P2 - 测试与质量保证 🧪 **低优先级**

#### 3.1 单元测试

**文件**: 新建 `Tests/` 目录

**SimCParser 测试** (3 项):
- [ ] 词法分析器（Tokenize）测试
- [ ] 语法分析器（ParseExpression）测试
- [ ] 边界条件和错误处理测试

**Serializer 测试** (3 项):
- [ ] 压缩算法正确性
- [ ] Base64 编解码
- [ ] 大配置压缩效率

**Mock WoW API** (3 项):
- [ ] 模拟 UnitBuff/UnitDebuff
- [ ] 模拟 GetSpellInfo/GetSpellCooldown
- [ ] 模拟战斗状态切换

**预计工作量**: 4-6 小时

---

#### 3.2 API 适配验证 ⚠️

**优先级**: 泰坦服实测后执行

**待验证** (3 项):
- [ ] 验证 `UnitAura` 返回值格式（确认 SpellID 在第10位）
- [ ] 测试 Buff 槽位限制（40个/单位）
- [ ] 确认中文客户端下 SpellID 查询稳定性

**参考**: Archive/API_Verification_Tasks.md, WoW_API_Usage.md

**预计工作量**: 实测 2-3 小时

---

## ✅ 已完成项目

### 调试窗口设计重构 (2026-01-22)

- ✅ **DebugWindow 统一设计**
  - 将原 Logger 模块重新设计为统一的 DebugWindow
  - 集成日志、性能分析、缓存统计、实时监控四个页签
  - GUI 控制按钮（启动/停止/重置/导出），减少命令依赖
  - 统一命令接口为 `/wam debug`（移除 `/wam profile`）
  - 参见: [调试与性能监控详细设计](DetailedDesign/06_Logger.md)

### 技术债务解决 (2026-01-22)

- ✅ **Execute 特殊处理抽象化**
  - 通过新增 `check_spell_usable` 钩子事件实现
  - Warrior 特殊逻辑已移至 `Classes/Warrior.lua`
  - 参见: [Hooks 详细设计](DetailedDesign/14_Hooks.md)

- ✅ **ActionMap 与职业模块整合**
  - `BuildActionMap()` 现在自动从 `ns.Classes` 读取职业模块定义的 spells
  - 避免了在 Constants 和职业模块中重复定义技能
  - 参见: [ActionMap 详细设计](DetailedDesign/13_ActionMap.md)

---

## 📚 相关文档

- [设计文档 v2.1](WhackAMole_Design.md) - 完整设计规范
- [详细设计索引](DetailedDesign/INDEX.md) - 14 个模块详细设计
- [架构图与流程图](DetailedDesign/00_Architecture_Diagrams.md) - 系统架构可视化
- [WoW API 用法](WoW_API_Usage.md) - API 验证和最佳实践
- [归档文档](Archive/) - 历史分析文档

---

**维护者**: WhackAMole Development Team  
**最后更新**: 2026-01-22
