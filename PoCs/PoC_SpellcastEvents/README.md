# PoC_SpellcastEvents - 施法事件检测验证工具

## 目的

验证 WoW 3.3.5 (WotLK) 中施法相关事件的行为和时序，特别是：
- 事件触发顺序和参数完整性
- UnitCastingInfo API 延迟问题
- 施法时间计算准确性
- 事件完整性（START → SUCCEEDED/STOP/FAILED/INTERRUPTED 链路）

## 功能特性

- **静默运行**：所有事件日志仅保存在内存中，不输出到聊天窗口
- **表格界面**：测试指导窗口以表格形式显示5个测试场景和实时状态
- **智能日志**：Logger类管理日志，最多保存1000条，超出自动删除最早记录
- **实时状态**：测试场景状态自动更新（未测试/✓ 已通过/✗ 出错）

## 监听的事件

| 事件 | 说明 | 参数 | 备注 |
|------|------|------|------|
| `ADDON_LOADED` | 插件加载完成 | addonName | - |
| `PLAYER_LOGIN` | 玩家登录完成 | - | - |
| `UNIT_SPELLCAST_START` | 普通施法开始 | unit, castGUID, spellID | - |
| `UNIT_SPELLCAST_CHANNEL_START` | 引导施法开始 | unit | - |
| `UNIT_SPELLCAST_CHANNEL_UPDATE` | 引导施法更新 | unit | - |
| `UNIT_SPELLCAST_CHANNEL_STOP` | 引导施法结束 | unit | - |
| `UNIT_SPELLCAST_STOP` | 施法正常结束 | unit, castGUID, spellID | - |
| `UNIT_SPELLCAST_FAILED` | 施法失败 | unit, castGUID, spellID | - |
| `UNIT_SPELLCAST_INTERRUPTED` | 施法被打断 | unit, castGUID, spellID | ⚠️ **单次打断会触发4次** |
| `UNIT_SPELLCAST_SUCCEEDED` | 施法成功完成 | unit, castGUID, spellID | - |

> ⚠️ **重要**: `UNIT_SPELLCAST_INTERRUPTED` 事件在 WoW 3.3.5 客户端中会为同一次打断触发**4次**（第一次单独，随后连续3次，间隔约0.1秒）。这是客户端行为特性，实际应用中需要使用 castGUID + 时间窗口进行去重。

## 使用方法

### 1. 安装
将 `PoC_SpellcastEvents` 文件夹复制到魔兽世界的 `Interface\AddOns\` 目录。

### 2. 启用
在游戏角色选择界面点击"插件"按钮，启用 **PoC_SpellcastEvents**。

### 3. 测试
进入游戏后，会自动弹出**测试指导窗口**，显示测试场景表格：

| 场景 | 描述 | 状态 |
|------|------|------|
| 场景1: 事件验证 | 监听所有10个事件 | 未测试 |
| 场景2: 普通施法 | 施放带施法时间的技能 | 未测试 |
| 场景3: 施法打断 | 被怪物打断施法 | 未测试 |
| 场景4: 施法失败 | 超出射程/移动中 | 未测试 |
| 场景5: 引导完成 | 施放引导技能完整流程 | 未测试 |

按照场景进行测试，状态会自动更新为 "✓ 已通过" 或 "✗ 出错"。

**重要**：日志不会输出到聊天窗口，只保存在内存中。

### 4. 导出日志
使用以下方式导出完整日志：

**方法1: 命令导出**
```
/pocspell export
```

**方法2: 使用快捷命令**
```
/pse export
```

导出窗口功能：
- � **日志统计**: 显示当前日志数量（最多1000条）
- 🔄 **刷新按钮**: 更新最新日志内容
- 🗑️ **清空按钮**: 清除所有历史日志
- 📋 **全选复制**: 点击文本框自动全选，Ctrl+C 复制

### 5. 命令

| 命令 | 说明 |
|------|------|
| `/pocspell` 或 `/pse` | 显示测试指导窗口（默认） |
| `/pocspell guide` | 显示测试指导窗口 |
| `/pocspell export` | 导出日志到窗口 |
| `/pocspell reset` | 重置所有测试数据和状态 |
| `/pocspell help` | 显示帮助 |

## 测试场景

### 场景1: 事件验证
**操作**: 触发所有10个核心事件（ADDON_LOADED、PLAYER_LOGIN、8个UNIT_SPELLCAST_*事件）

**检测内容**:
- 所有事件至少触发一次
- 实时显示已触发/待触发事件列表
- 事件完整性验证

### 场景2: 普通施法
**操作**: 施放带施法时间的技能（如火球术）

**检测内容**:
- UNIT_SPELLCAST_START 事件触发
- 技能信息记录完整
- 施法时间计算正确

### 场景3: 施法打断
**操作**: 施法过程中被怪物打断

**检测内容**:
- UNIT_SPELLCAST_INTERRUPTED 事件触发
- 打断时间记录

### 场景4: 施法失败
**操作**: 超出射程、移动中施法等导致失败

**检测内容**:
- UNIT_SPELLCAST_FAILED 事件触发
- 失败原因记录

### 场景5: 引导完成
**操作**: 施放引导技能并让其正常完成（如暴风雪）

**检测内容**:
- UNIT_SPELLCAST_CHANNEL_START 事件触发
- UNIT_SPELLCAST_CHANNEL_STOP 事件触发
- UnitChannelInfo API 可用性

## 关键发现

### 日志管理
1. **Logger类设计**:
   - 最多保存1000条日志
   - 超出限制自动删除最早记录
   - 所有日志仅保存在内存，不输出到聊天窗口

2. **状态管理**:
   - 每个测试场景有三种状态：未测试、✓ 已通过、✗ 出错
   - 状态实时更新，无需手动刷新
   - 可通过 `/pocspell reset` 重置所有状态

3. **日志示例**:
```
======================================================================
[START #1] @12.345
  unit: player
  castGUID: Cast-3-0-12345
  spellID: 133
  spellName: 火球术
  castTime: 3.50秒
  expectedEndTime: 15.845
  ✓ API正常
======================================================================
[SUCCEEDED #1] @15.847
  unit: player
  spellID: 133
  spellName: 火球术
  elapsed: 3.502秒
  timing: 预期结束时间差: 0.002秒
======================================================================
```

### WoW 3.3.5 已知问题
1. **UnitCastingInfo 延迟**: 
   - `UNIT_SPELLCAST_START` 触发后，`UnitCastingInfo()` 可能返回 nil（延迟 30-100ms）
   - 解决方案：事件中缓存 spellID，使用 `GetSpellInfo()` 获取施法时间

2. **事件顺序**:
   - 正常流程: START → SUCCEEDED → STOP
   - SUCCEEDED 和 STOP 几乎同时触发（差异 < 10ms）

3. **引导施法特殊性**:
   - 只有 CHANNEL_START 和 STOP
   - 没有 SUCCEEDED 事件

4. **INTERRUPTED 事件多次触发**:
   - WoW 3.3.5 客户端在单次打断时会触发多次 `UNIT_SPELLCAST_INTERRUPTED` 事件（通常4次）
   - 触发时间分两组：第一次单独触发，随后连续触发3次（间隔约0.1秒）
   - 这是客户端行为特性，不是插件代码问题
   - **重要**: 实际应用中需要去重（例如使用 castGUID + 时间窗口）

5. **SetBackdrop不可用**:
   - WoW 3.3.5 不支持 SetBackdrop API
   - 使用 SetColorTexture 创建纯色背景代替

## 新特性

### 📊 静默日志系统
- 所有事件日志仅保存在内存，不输出到聊天窗口
- Logger类自动管理日志，最多保存1000条
- 通过 `/pocspell export` 查看完整日志

### 📋 测试指导表格
- 表格形式显示5个测试场景
- 实时状态更新（未测试/✓ 已通过/✗ 出错）
- 清晰的场景描述和当前状态显示
- 无需"开始测试"按钮，直接进行测试即可

## 依赖关系

- 无外部依赖
- 纯 WoW 3.3.5 原生 API
- 兼容层：C_Timer（3.3.5 不支持，已内置兼容实现）

## 相关文件

- `Core.lua` - 主逻辑和事件处理
- `PoC_SpellcastEvents.toc` - 插件清单
- `README.md` - 本文档

## 参考资料

- WoW API: UNIT_SPELLCAST 事件系列
- WhackAMole 预测系统设计文档（Docs/DetailedDesign/15_Prediction_System.md）
