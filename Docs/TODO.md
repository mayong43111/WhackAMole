# WhackAMole - 待办任务

**文档版本**: 2.1  
**更新日期**: 2026-01-22  

---

## 📊 任务统计

| 分类 | 总数 | 已完成 | 进行中 | 待办 | 完成率 |
|------|------|--------|--------|------|--------|
| **职业模块完善** | 30 | 0 | 0 | 30 | 0% |
| **测试与文档** | 12 | 0 | 0 | 12 | 0% |
| **技术债务** | 2 | 2 | 0 | 0 | 100% |
| **总计** | 44 | 2 | 0 | 42 | 5% |

**优先级分布**:
- 🔥 高优先级: 18 项（职业模块 Mage 技能映射）
- 🛡️ 中优先级: 11 项（职业模块 Warrior 技能 + 用户文档）
- ⚙️ 低优先级: 15 项（特殊机制 + 单元测试 + API 验证）

---

## 📋 任务列表

### P0 - 职业模块完善 🔥

#### ✅ 当前状态

**Warrior (战士)**:
- ✅ 基础结构完整
- ✅ Execute/Sudden Death 特殊机制已实现
- ✅ 核心技能已覆盖（Arms/Fury/Protection）

**Mage (法师)**:
- ✅ Fire 专精技能基本完整
- ⚠️ Frost/Arcane 专精技能缺失

---

#### 1.1 Mage 技能映射 🔥 **高优先级**

**文件**: `src/Classes/Mage.lua`

**Frost 专精** (8 项):
- [ ] Frostbolt (116)
- [ ] Ice Lance (30455)
- [ ] Frost Nova (122)
- [ ] Cold Snap (11958)
- [ ] Summon Water Elemental (31687)
- [ ] Deep Freeze (44572)
- [ ] Fingers of Frost (Buff, 44544)
- [ ] Brain Freeze (Buff, 57761)

**Arcane 专精** (6 项):
- [ ] Arcane Blast (30451)
- [ ] Arcane Missiles (5143)
- [ ] Arcane Barrage (44425)
- [ ] Arcane Power (12042)
- [ ] Presence of Mind (12043)
- [ ] Missile Barrage (Buff, 44401)

**通用技能** (7 项):
- [ ] Mana Shield (1463)
- [ ] Frost Armor (7301)
- [ ] Molten Armor (30482)
- [ ] Mage Armor (6117)
- [ ] Invisibility (66)
- [ ] Spellsteal (30449)
- [ ] Remove Curse (475)

**优先级**: 🔥🔥🔥 **立即执行**  
**预计工作量**: 1-2 小时

---

#### 1.2 Warrior 通用技能 🛡️ **中优先级**

**文件**: `src/Classes/Warrior.lua`

**通用技能** (8 项):
- [ ] Taunt (355)
- [ ] Challenging Shout (1161)
- [ ] Mocking Blow (694)
- [ ] Cleave (845)
- [ ] Demoralizing Shout (1160)
- [ ] Retaliation (20230)
- [ ] Commanding Shout (469)
- [ ] Berserker Rage (18499)

**专精技能** (3 项):
- [ ] Heroic Fury - Fury (60970)
- [ ] Rampage (Buff) - Fury (29801)
- [ ] Taste for Blood (Buff) - Arms (60503)

**优先级**: 🛡️ **按需补充**  
**预计工作量**: 30 分钟

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

### P1 - 用户文档 📚 **中优先级**

#### 2.1 快速开始指南

**文件**: 新建 `Docs/User/QuickStart.md`

**内容** (3 项):
- [ ] 安装步骤（下载、解压、放置到 AddOns 目录）
- [ ] 首次配置流程（选择专精、加载预设配置）
- [ ] 基础命令说明（`/wam lock/unlock/debug/profile` 等）

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
- [ ] 如何调试 APL？（`/wam debug on/show`）
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
