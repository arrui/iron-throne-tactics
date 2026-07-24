# 第一幕第一章《呓语森林之战》设计稿

> 日期：2026-07-24
> 范围：第一幕《五王之战·罗柏线》开篇章节。第一幕规划 6-7 章、止于红色婚礼，本稿只设计第一章，后续章节各自走独立的设计→计划→实现循环。

## 0. 背景与决策摘要

序章（篡夺者战争·奈德视角，4 章）已完整可玩，2078 测试全绿，主题统一/CI/地图规范回归/端到端测试等工程基线已建立。本稿启动正篇第一幕。

本稿六章关键决策：

| 维度 | 决策 |
|------|------|
| 开篇战役 | 呓语森林之战（罗柏首胜、夜袭生擒詹姆） |
| 机制范围 | 复用序章现有系统 + 最小新增（战争迷雾） |
| 章节系统 | 引入 act（幕）概念重构，序章零改动兼容 |
| 夜袭机制 | 完整战争迷雾，方案 C：地形全知、敌军显隐、单向迷雾、`fog_enabled` 开关 |
| 胜负条件 | 击溃詹姆（min_hp=1）→ 生擒过场 → 胜利 |
| 美术资产 | 地图精灵本章做（程序化、可验证）；立绘先用占位，后补 |

## 1. 章节系统重构（act 幕结构）

### 问题

`GameState.current_chapter` 是单整数 1-4，散落在 `Opening.gd`、`BattleBootstrap.gd`、`SaveSystem.gd` 的硬编码里（`chapter > 4` 回绕、`match current_chapter` 分发、Debug 按钮 `range(1,5)`）。正篇章节无法直接接入。

### 设计

`GameState` 扩展为幕+章双字段，序章用兼容别名零改动：

```gdscript
class_name GameState
static var act: int = 0          # 0=序章, 1=第一幕(罗柏), ...
static var chapter: int = 1      # 幕内章节序号
# 序章兼容别名：act==0 时返回 chapter，否则 -1（序章代码读 current_chapter 不变）
static var current_chapter: int:
    get: return act if ... # 见实现：act==0 ? chapter : -1
static func global_chapter_id() -> String  # "prologue.1" / "act1.1"
```

> 实现注意：GDScript 的 static var 不支持自定义 getter 写法，`current_chapter` 实际以普通 static func 或在 set 时同步维护。实现计划阶段定具体写法，语义不变。

存档结构升级，向后兼容：

```json
// 旧存档（序章）
{ "chapter": 3, "completed_chapters": [1, 2] }

// 新存档
{ "act": 1, "chapter": 1, "completed": ["prologue.1", "prologue.2", "prologue.3", "prologue.4"] }
```

`SaveSystem` 读档时：若存在旧 `chapter` 字段且无 `act`，推断 `act=0, chapter=旧值`，`completed` 从 `completed_chapters` 映射为 `"prologue.N"`。写档用新结构。

### 改动点

- **`Opening.gd`**：`CHAPTER_SCENE_MAP` 从 `int→String` 改为 `(act,chapter)→String` 双键映射（或 `global_chapter_id()→String`）。序章完成后推进到 `act1.ch1`。Debug 按钮新增"呓语森林"。
- **`BattleBootstrap.gd`**：`match current_chapter` 分发改为按 `global_chapter_id()` 分发；序章 `_setup_chN` 不动。
- **`BattleBootstrap_A1C1.gd`**（新，继承基类）：呓语森林专属逻辑（迷雾 + 生擒），独立于序章 Bootstrap，避免基类 `_ready` 分支臃肿。

### 回归保护（硬约束）

序章 1-4 现有 41 套件全部保持绿。新增 `_test_chapter_act_structure` 套件覆盖 global_chapter_id 映射、存档兼容、序章别名分发。

## 2. 呓语森林之战：叙事、地图、敌我、胜负

### 叙事节拍

- **开场过场**（`act1_ch1_opening.json`）：奔流城外军帐。罗柏得知詹姆扎营呓语森林。凯特琳与黑鱼劝稳守，罗柏决意夜袭。沉重，少年领主第一次豪赌，非热血。
- **战前对话**（`act1_ch1_pre.json`）：黑鱼交代林地路径，凯特琳叮嘱"把你的人带回来"。
- **战斗**：夜袭林中伏击，敌军从松懈转入慌乱（迷雾机制承载）。
- **生擒詹姆**（`act1_ch1_jaime_capture.json`）：詹姆 HP 触底（min_hp=1）→ 过场，缴械生擒，詹姆冷笑"杀了我，你就再无筹码"。
- **战后对话**（`act1_ch1_post.json`）：罗柏未杀詹姆（留作筹码），黑鱼赞调度。旁白引向下一战。

### 地图

约 22×16（与序章同档）。地形构成：

- 中部南北向**森林带**：夜袭掩护、玩家推进主轴
- 西侧**河流/浅滩**：徒利领地、呼应奔流城背景、不可强渡区封边
- 东侧**峭壁**封边
- 北部**詹姆营地**：敌军出生/目标区，篝火/营帐装饰格（plain 变体）
- 南部**玩家集结林缘**

### 我方（罗柏线首次登场）

- 罗柏·史塔克 — 剑/骑，is_protagonist，level 1
- 黑鱼·徒利·布莱登 — 枪/重装，副将
- 北境骑士×2、荒野游侠×1（弓，伏击远程）

### 敌方

- 詹姆·兰尼斯特 — Boss，min_hp=1，剑/骑（立绘/精灵已存在，仅缺单位 json）
- 兰尼斯特士兵×若干（资源已存在）
- 金狮骑士×1-2 — 兰尼斯特精锐（新单位 json，复用 `royal_guard_captain_map.png` 精灵或新增）

### 胜负条件

- **胜利**：詹姆 HP 触底（min_hp=1）→ 触发生擒过场 → 章节推进到 act1.ch2 占位
- **失败**：罗柏死亡（is_protagonist → GameOver）
- 不要求全歼（呼应序章"胜利条件≠全歼"设计语言）

## 3. 战争迷雾系统（方案 C）

### 核心数据

挂为 BattleMap 子节点或独立 `FogSystem.gd`：

```gdscript
var _visible_tiles: Dictionary    # 本回合可见格（Vector2i -> true）
var _explored_tiles: Dictionary   # 累计已探索格（永久）
var _visible_enemies: Array[Unit] # 本回合可见敌军
```

### 视野计算

每回合重算（玩家回合开始 + 敌军回合结束后）。每个我方单位视野半径 `vision = unit.data.move + 2`；罗柏/黑鱼 +1 加成。可见格 = 以每个我方单位为中心、切比雪夫距离 ≤ vision 的格。视野穿墙（不做遮挡，降低复杂度与风险）。

### 敌军显隐（核心）

- 敌军在 `_visible_tiles` 内 → 正常渲染、可被锁定攻击、计入危险区预测
- 敌军在迷雾内 → `visible=false`、不参与玩家攻击锁定、不进危险区预测
- 已探索格内的敌军按当前可见性显隐（不"记住"敌军位置，只记住地形——符合方案 C"地形全知、敌军显隐"）

### 与现有系统交互（风险点逐个落实）

1. **HighlightLayer**：新增 `_draw_fog_overlay()`——可见格正常亮度、已探索不可见格降明度、未探索格全黑。复用网格绘制。
2. **危险区预测**（`_show_enemy_preview` / move_range 危险标红）：仅计入 `_visible_enemies`，迷雾中敌军攻击范围不显示（夜袭紧张感来源）。
3. **EnemyAI**：**不受迷雾影响**（敌方营地有火把，单向迷雾）。敌军正常寻路攻击玩家。敌军从迷雾现身接近时，玩家回合开始看到新敌军亮起，制造伏击被打断的紧张感。
4. **寻路**：不受影响（地形全知）。
5. **生擒/胜利检查**：詹姆在视野内才可攻击；若在迷雾中，玩家需先推进揭开视野——夜袭推进动力。

### 隔离开关

`fog_enabled: bool`。序章 1-4 设 `false`（零行为变化，回归全绿），呓语森林设 `true`。迷雾是"呓语森林特性"而非全局改动，风险隔离。

### 新测试（`_test_fog_of_war` 套件）

视野计算正确性、敌军显隐切换、危险区不计迷雾敌军、`fog_enabled=false` 时行为与无迷雾完全一致（关键回归断言）。

## 4. 资产与文件清单

### 新增单位数据（`data/units/`）

- `robb_stark.json` — 罗柏，剑/骑，主角，level 1
- `brynden_tully.json` — 黑鱼，枪/重装，副将
- `north_knight_robb.json` — 北境骑士（罗柏线，与序章 `northern_knight` 区分阵营归属，或复用）
- `jaime_lannister.json` — 詹姆，Boss，min_hp=1（资源已存在，仅缺 json）
- `golden_lion_knight.json` — 金狮骑士（复用 `royal_guard_captain_map.png` 或新增精灵）

### 美术资产

- **地图精灵**：本章做。在 `design/map-sprites/generate.py` 的 `P` 字典新增罗柏、黑鱼条目（金狮骑士若新增同此），重生成。复用现有生成器流程与回归护栏。
- **立绘**：本章占位。罗柏、黑鱼用占位矩形 + 待生成标记；詹姆立绘已存在。立绘后补不阻塞玩法代码。

### 对话/过场数据

- `data/dialogues/act1_ch1_pre.json` / `act1_ch1_post.json`
- `data/cutscenes/act1_ch1_opening.json` / `act1_ch1_jaime_capture.json`

### 新增脚本/场景

- `scripts/battle/BattleBootstrap_A1C1.gd`（继承基类）
- `scenes/battle/BattleMap_A1C1.tscn`（继承 `BattleMap.tscn`，挂 A1C1 bootstrap + fog）
- `scripts/systems/FogSystem.gd`（迷雾逻辑，独立类）
- `scenes/chapter/Act1_Ch1_Opening.tscn` + `scripts/chapter/Opening_A1C1.gd`
- `scripts/chapter/Act1ChapterBriefs.gd`（正篇简报，对齐 `PrologueChapterBriefs` 模式）

### 章节系统改动

`GameState.gd`、`SaveSystem.gd`（存档兼容升级）、`Opening.gd`（act 分发）、`BattleBootstrap.gd`（global_chapter_id 分发）。

## 5. 测试策略

延续"改代码→跑回归→迭代"闭环，每块独立可测：

1. **章节系统重构**（`_test_chapter_act_structure`）：global_chapter_id 映射、存档兼容（旧→新）、序章别名分发回归。
2. **迷雾系统**（`_test_fog_of_war`，新套件）：视野半径、敌军显隐、危险区不计迷雾敌军、fog=false 序章行为不变。
3. **呓语森林章节**（`_test_act1_ch1_whispering_wood`，对齐序章 `_test_chapter_event_flow`）：地图完整性 + 可达路径（复用 `_path_exists_on_passable_grid`）、罗柏/詹姆生成、詹姆 min_hp=1、生擒流程触发推进、罗柏死亡→GameOver、开场 HUD 文案回归。
4. **地图视觉语言回归**：呓语森林纳入 `_test_map_visual_language_spec` 的出生点可通行/胜利格可通行/可达路径三项（规范第 6 节基础设施）。

所有新套件注册进 `run_tests.gd` 套件列表，`./scripts/test.sh` 自动跑。序章 41 套件 + 新增，全绿过关。

## 6. 风险与取舍

- **最高风险：迷雾与现有系统交互**。用方案 C（地形全知、单向迷雾）+ `fog_enabled` 开关隔离，把迷雾限定为呓语森林特性，序章零行为变化。若迷雾实现中与危险区预测/AI 交互出现回归，开关可临时关闭迷雾而不阻塞章节内容。
- **章节系统重构**触碰多个现有系统。用兼容别名让序章代码零改动，回归护栏保证 41 套件不退化。
- **立绘占位**：玩法不阻塞，但视觉体验打折。后补 imagegen 流程已在 `design/portraits/` 建立，可随时续。
- **YAGNI**：势力特性系统（凛冬意志/河流扼守）本稿不做，留待后续章节按需引入。

## 7. 不在本稿范围

- 第一幕第 2 章及后续（各走独立设计循环）
- 势力特性系统、血脉系统、龙机制（主线此阶段不激活）
- 罗柏/黑鱼正式立绘（占位，后补）
