# WhackAMole v0.0.1 发布说明

## 🎉 首个泰坦重铸（Titan Forged）T1阶段版本

这是 WhackAMole 插件的首个正式版本，专为**泰坦重铸服务器**（WotLK 3.3.5a核心 + 魔改T1套装）优化。

---

## ✨ 新增职业预设

本版本新增 **5个职业** 的 T1 阶段完整 APL 预设：

### 🔥 火焰法师 (Mage_Fire)
- **2T1**: 法术命中率 +1%，法术消耗 -1%
- **4T1**: 法术连击（Hot Streak）暴击率 +2%（触发频率提升约10%）
- **核心机制**: Hot Streak 消耗 > Living Bomb 维持 > Combustion 爆发

### ⚔️ 武器战士 (Warrior_Arms)
- **2T1**: 猛击/旋风斩伤害 +3%
- **4T1**: 鲜血狂暴触发率 +5%，致死打击触发率 +2%
- **核心机制**: 断筋维持 > 压制 > 致命打击 > 猛击（修复多个APL关键错误）

### 🛡️ 惩戒骑士 (Paladin_Retribution)
- **2T1**: 十字军打击伤害 +6%
- **4T1**: 神圣风暴CD缩短1秒（10秒→9秒，+11%使用频率）
- **核心机制**: 审判（回蓝/Buff，优先级最高） > 十字军打击 > 神圣风暴（AOE/单体核心） *[修正：WotLK无圣能系统]*

### 🌙 平衡德鲁伊 (Druid_Balance)
- **2T1**: 自然之力召唤树人 +1个（3→4个）
- **4T1**: 星辰坠落持续时间 +2秒（10秒→12秒，+20%伤害）
- **核心机制**: 日月蚀循环 + DoT维持（月火术+虫群）

### 🐱 野性德鲁伊 (Druid_Feral)
- **2T1**: 横扫（豹）能量消耗 -5（50→45）
- **4T1**: 狂暴持续时间 +3秒（15秒→18秒，+20%爆发期）
- **核心机制**: 野蛮咆哮100%覆盖 + DoT维持（扫击+撕裂） + 连击点管理

### ❄️ 冰霜死亡骑士 (DeathKnight_Frost)
- **2T1**: 寒冬号角符文能量 +5（10→15，+50%符能生成）
- **4T1**: 凋零缠绕和冰霜打击伤害 +5%（占总伤害50-60%）
- **核心机制**: 疫病维持 + 杀戮机器优化 + 符文能量管理

---

## 📚 完整设计文档

每个职业都包含详细的设计文档（位于 `Docs/profiles/`）：

- **服务器版本说明**: 泰坦重铸特色机制
- **T1 套装分析**: 数学模型 + 实战价值评估
- **技能数据表**: 完整的技能ID和说明
- **优先级队列**: 详细的APL逻辑解析
- **FAQ**: 常见问题解答

文档示例：
- `Docs/profiles/Mage_Fire_Logic.md`
- `Docs/profiles/Warrior_Arms_Logic.md`
- `Docs/profiles/Paladin_Retribution_Logic.md`
- `Docs/profiles/Druid_Balance_Logic.md`
- `Docs/profiles/Druid_Feral_Logic.md`
- `Docs/profiles/DeathKnight_Frost_Logic.md`

---

## 🛠️ 技术改进

### 职业系统扩展
- **新增**: `Classes/Paladin.lua`（23个技能）
- **新增**: `Classes/Druid.lua`（38个技能：平衡/野性/恢复）
- **扩展**: `Classes/DeathKnight.lua`（28个技能：冰霜/鲜血/邪恶）

### APL 预设系统
- **新增**: 6个完整 APL 预设文件
- **修复**: 武器战 APL 关键错误（Thunder Clap 优先级、Execute 逻辑、Heroic Strike）
- **优化**: 所有预设都包含详细的条件判断和注释

---

## 📦 安装说明

1. **下载**: 下载附件 `WhackAMole-0.0.1.zip`
2. **解压**: 解压到魔兽世界 `Interface/AddOns` 目录
3. **确认**: 确保解压后路径为 `Interface/AddOns/WhackAMole/WhackAMole.toc`
4. **启动**: 进入游戏，输入 `/wam` 打开配置界面
5. **选择预设**: 在预设列表中选择对应职业的 `[泰坦] DPS` 预设

---

## ⚠️ 注意事项

- **服务器限定**: 本版本专为泰坦重铸服务器优化，其他服务器可能需要调整
- **T1 阶段**: 套装效果数据基于T1阶段，后续版本会更新其他阶段
- **测试反馈**: 欢迎在 Issues 中反馈实际测试结果和建议

---

## 🎯 后续计划

- [ ] 新增更多职业（猎人、盗贼、术士、萨满、牧师）
- [ ] T2/T3 阶段套装优化
- [ ] 完善 UI 配置界面
- [ ] 添加实时 DPS 统计功能
- [ ] 支持自定义 APL 编辑

---

## 🙏 致谢

感谢泰坦重铸服务器提供的魔改T1套装数据，以及所有提供反馈的测试玩家！

---

**完整更新日志**: 查看所有提交记录 [Commits](https://github.com/mayong43111/WhackAMole/commits/main)

**问题反馈**: [GitHub Issues](https://github.com/mayong43111/WhackAMole/issues)

**使用帮助**: 查看 [README.md](https://github.com/mayong43111/WhackAMole/blob/main/README.md)
