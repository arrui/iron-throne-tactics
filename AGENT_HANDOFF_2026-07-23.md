# Iron Throne Tactics Handoff

更新日期：2026-07-23（在 2026-07-14 基础上核实并刷新）

## 当前基线

- 仓库分支：`main`
- Godot 主工程：`game/冰与火`（Godot 4.6.3）
- 自动化测试当前基线：`2074 通过 / 0 失败 / 41 套件`

测试命令：

```bash
./scripts/test.sh
# 或直接：
cd game/冰与火 && HOME=/tmp godot --headless --path . --script tests/run_tests.gd
```

CI：`.github/workflows/godot-tests.yml` 已接入，push / PR 触发跑 `test.sh`（Ubuntu runner）。

## 07-14 → 07-23 期间已完成（核实结果）

下列事项在 07-14 handoff 中曾列为"缺口/下一步"，现核实已全部完成：

### UI 主题统一（曾列为第一/第二优先级，已完成）

共享主题脚本 `scripts/ui/BattleChromeTheme.gd` 已接入**全部战斗内外浮层**：

- 战斗内：`BattleMap` HUD、`ActionMenu`、`PredictPanel`、`ResultPanel`、`DialogueBox`（含 PredictPanel 取消按钮弱化语义、平地贴墙墙脚阴影等收尾）
- 战斗外：`ChapterTransition`、`GameOver`、`SupportPopup`、`DeployScreen_Ch4`、`SettingsMenu`（07-23 新接入，含新增 `OVERLAY_DIM` 模态遮罩常量）
- 主题色/按钮/面板全部由 `BattleChromeTheme` 常量驱动，tscn 侧重复硬编码已清理（DialogueBox、SettingsMenu 已让脚本成为单一来源）

### 地图视觉语言规范 v1 的自动化回归（曾列为第三优先级，已完成）

`11-map-visual-language-spec-v1.md` 第 6 节列出的 6 项可机器验证内容**全部已落地为回归测试**（见 `_test_map_visual_language_spec`）：

1. 出生点可通行 ✅
2. 关键胜利格可通行 ✅
3. 桥邻接河流 ✅
4. Ch2 三桥存在且方向正确 ✅
5. Ch4 中轴桥 / 城墙 / 护城河数量与结构 ✅
6. 出生点到目标的可达路径 ✅（Ch1/Ch2/Ch3/Ch4 全四章）

地图精修本身仍在以 `ux:` 提交系列持续推进（森林/沼泽边缘转角、河岸、连续墙分段、墙脚阴影、门前阈值等），但**规范→回归的闭环已建立**。

### 章节级端到端回归（曾列为中优先级，已完成）

`_test_chapter_event_flow` 已覆盖 Ch2（雷加阵亡→过场→推进 Ch3）、Ch3（塔门→戴恩事件→莱安娜过场→推进 Ch4）、Ch4（指挥官死亡→归降→结局→返回 Opening）的关键事件流 + 章节推进 + 存档同步。

### 工程边界收口

- 仓库根 `game/scripts`、`game/data`、`game/assets` 旧原型残留已于 07-23 清理删除
- `tmp/`（本地生成产物：imagegen、review 图、map-sprite 脚本）已加入 `.gitignore`

### 战斗交互状态机加固

07-14 后有大量 `fix: handle removed unit...` / `fix: recover when...` 提交，处理单位在攻击确认/目标选择/道具面板中途死亡时的状态恢复，以及各章结束时的交互状态复位。这条硬化线已基本收尾。

## 目前仍然缺什么（07-23 真实状态）

### 高优先级（但需人工或外部资源，非纯代码可推进）

- **手玩过四章验证体验通顺**：自动化绿 ≠ 体验通。需人工验证 Ch3 是否有唯一解、Ch4 后期清兵是否拖沓、各章结算→跳章的交互残留是否彻底
- **数值与关卡节奏平衡**：Ch1 是否过平、Ch2 三桥压力、Ch3 唯一解、Ch4 后期节奏——需手玩反馈 + 数据回归一起做

### 地图精灵（07-23 核实：非占位，已完成）

`*_map.png` **不是占位**，而是 16 个单位各具独立剪影/调色板/武器的程序化像素艺术（96×32 横向三帧待机动画）。07-23 已将生成器作为权威来源入仓：

- `design/map-sprites/generate.py`：唯一权威生成器，确定、无随机，reproduce 当前 runtime 精灵逐字节一致
- `design/map-sprites/README.md`：配置字段、阵营色彩语言、重生成流程
- `design/map-sprites/review/map_sprites_contact_sheet.png`：放大预览
- 回归测试 `_test_map_sprite_assets_and_animation` 已覆盖：16 单位一对一映射、96×32 三帧、各帧可见像素、运行时动画切换、生成器入仓保存

进一步精灵美化需在游戏中肉眼检视后改 `generate.py` 重生成（流程已打通），不宜盲改。

### 中优先级

- ChapterTransition / GameOver / SupportPopup 的 tscn 仍有少量硬编码颜色与脚本覆盖重复（双源），视觉无影响，属洁癖项，低优先
- 无视觉/截图级回归
- 无系统化资源清单文档（列明占位/正式资产）

### 暂不作为当前阶段目标

- 第一幕《五王之战·罗柏线》开发（序章纵切片验收签字后再进）
- 龙机制实战化（主线此阶段不激活，见 `07-future-works.md`）

## 建议下一个 agent 从哪里开始

**不要再回头核实 07-14 handoff 的旧待办**——它们已完成（见上）。真实下一步按可用资源分：

1. **若有手玩时间**：从 Opening 跑完整四章，记录 Ch3 唯一解、Ch4 后期节奏、跳章残留等问题，再据此修。
2. **若要美化地图精灵**：在游戏中肉眼检视 `*_map.png` 后，改 `design/map-sprites/generate.py` 重生成（流程已打通，跑 `./scripts/test.sh` 验证）。不建议盲改。
3. **若纯代码推进**：可考虑建关卡数据回归基线（回合数/伤亡/资源消耗），为数值平衡提供自动护栏；或开始第一幕罗柏线的设计文档与骨架。

## 建议执行流程

每轮迭代仍按：一小块明确目标 → 补/更新测试 → `./scripts/test.sh` 全绿 → 下一块。

## 备注

- 本 handoff 基于 07-23 实际工作区与实跑测试结果（2074 通过）撰写。
- 07-14 handoff 原文已被本版替换；其历史可通过 git 查看。
- 当前最稳的接手方式，是先确认上述"已完成"项确实落地（跑一次 `./scripts/test.sh`），再从"真实下一步"切入，而不是再次核实旧待办。
