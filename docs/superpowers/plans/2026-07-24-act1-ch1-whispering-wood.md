# 第一幕第一章《呓语森林之战》Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现第一幕第一章《呓语森林之战》——罗柏夜袭生擒詹姆，引入 act 幕结构重构与战争迷雾系统。

**Architecture:** 章节系统从单整数 `current_chapter`(1-4) 重构为 `act/chapter` 双字段，序章用兼容别名零改动。呓语森林用自包含 `BattleBootstrap_A1C1.gd` + `BattleMap_A1C1.tscn`（由其 Opening 直接加载，不碰基类 match 分发）。战争迷雾为独立 `FogSystem.gd`，由 `fog_enabled` 开关隔离，序章默认关。胜利条件：詹姆 HP 触底(min_hp=1)→生擒过场→推进。

**Tech Stack:** Godot 4.6 / GDScript；测试 `tests/run_tests.gd` headless 套件；地图精灵 `design/map-sprites/generate.py`(Pillow)。

## Global Constraints

- 序章 1-4 现有 41 套件必须全部保持绿（硬约束，每轮 `./scripts/test.sh` 验证）。
- 主工程根：`game/冰与火`。测试命令：`cd /Users/yanrui/Desktop/iron-throne-tactics && ./scripts/test.sh`。
- 地形常量在 `scripts/battle/BattleMap.gd:24-30`：`TERRAIN_PLAIN=0, FOREST=1, WALL=2, CLIFF=3, RIVER=4, SWAMP=5, BRIDGE=6`。
- `UnitData.from_dict(d)` 字段：`name/class/level/hp/max_hp/pow/spd/skl/def/lck/con/move/weapon_type/weapon_rank/weapon_uses/weapon_max_uses/is_protagonist/is_boss/min_hp/items`。`items` 元素如 `{"name":"急救药","type":"heal","heal_amount":10,"uses":2}`。
- LIVE 游戏所有章节加载 `scenes/battle/BattleMap.tscn`（基类 `BattleBootstrap.gd`），由 `_ready()` 的 `match current_chapter` 分发到 `_setup_chN`。`BattleBootstrap_ChN.gd`/`BattleMap_ChN.tscn` 仅测试用。
- 提交信息结尾附 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- 立绘占位：罗柏/黑鱼不生成正式立绘。地图精灵本章做（改 `design/map-sprites/generate.py`）。

---

## File Structure

**新建：**
- `scripts/systems/FogSystem.gd` — 迷雾逻辑（视野、敌军显隐），独立 class，被 BattleMap 持有。
- `scripts/battle/BattleBootstrap_A1C1.gd` — 呓语森林 bootstrap，`extends "res://scripts/battle/BattleMap.gd"`。
- `scenes/battle/BattleMap_A1C1.tscn` — 继承 `BattleMap.tscn`，挂 A1C1 bootstrap。
- `scripts/chapter/Opening_A1C1.gd` — `extends ChapterOpening`，设置 A1C1 参数。
- `scenes/chapter/Act1_Ch1_Opening.tscn` — 挂 Opening_A1C1。
- `scripts/chapter/Act1ChapterBriefs.gd` — 正篇简报常量，对齐 `PrologueChapterBriefs` 模式。
- `data/units/robb_stark.json` / `brynden_tully.json` / `jaime_lannister.json` / `golden_lion_knight.json`。
- `data/dialogues/act1_ch1_pre.json` / `act1_ch1_post.json`。
- `data/cutscenes/act1_ch1_opening.json` / `act1_ch1_jaime_capture.json`。

**修改：**
- `scripts/GameState.gd` — 加 `act/chapter` 双字段 + `global_chapter_id()`。
- `scripts/systems/SaveSystem.gd` — 存档结构升级 + 旧存档兼容。
- `scripts/Opening.gd` — act 分发 + Debug 按钮。
- `scripts/battle/BattleMap.gd` — 加 `fog_enabled` 开关 + 持有 `FogSystem` + 危险区/敌军预览受迷雾过滤。
- `scripts/battle/BattleBootstrap.gd` — `_advance_to` 兼容 act 推进。
- `design/map-sprites/generate.py` — `P` 字典新增罗柏/黑鱼/金狮骑士。
- `tests/run_tests.gd` — 新增 3 套件 + preload。

---

## Task 1: 章节系统 act 幕结构重构

**Files:**
- Modify: `scripts/GameState.gd`
- Modify: `scripts/systems/SaveSystem.gd`
- Test: `tests/run_tests.gd`（新增 `_test_chapter_act_structure` 套件）

**Interfaces:**
- Produces: `GameState.act: int`, `GameState.chapter: int`, `GameState.current_chapter: int`（兼容别名，序章读取不变）, `GameState.global_chapter_id() -> String`, `GameState.set_prologue(chapter: int)`, `GameState.set_act(act: int, chapter: int)`。
- Produces: `SaveSystem.save_chapter_complete(act: int, chapter: int)`, `SaveSystem.load_progress() -> {act, chapter}`, `SaveSystem.get_completed_ids() -> Array[String]`。保留旧 `load_current_chapter() -> int` / `get_completed_chapters() -> Array[int]` 兼容序章。

- [ ] **Step 1: 写失败测试**

在 `tests/run_tests.gd` 套件列表（约 134 行 `]` 前）加一行：

```gdscript
		["章节幕结构(act)与存档兼容", _test_chapter_act_structure],
```

在文件末尾（`_test_test_script_reliability` 之前）加套件函数：

```gdscript
func _test_chapter_act_structure() -> void:
	# global_chapter_id 映射
	GameState.set_prologue(3)
	_assert_eq(GameState.act, 0, "set_prologue 设置 act=0")
	_assert_eq(GameState.chapter, 3, "set_prologue 设置 chapter")
	_assert_eq(GameState.current_chapter, 3, "序章兼容别名 current_chapter 正常")
	_assert_eq(GameState.global_chapter_id(), "prologue.3", "序章 global_chapter_id")
	GameState.set_act(1, 1)
	_assert_eq(GameState.act, 1, "set_act 设置 act")
	_assert_eq(GameState.chapter, 1, "set_act 设置 chapter")
	_assert_eq(GameState.global_chapter_id(), "act1.1", "正篇 global_chapter_id")
	# 存档兼容：旧 {chapter:N} 能读
	SaveSystem.delete_save()
	SaveSystem._write_json_for_test({"chapter": 3, "completed_chapters": [1, 2]})
	var prog := SaveSystem.load_progress()
	_assert_eq(prog["act"], 0, "旧存档兼容读出 act=0")
	_assert_eq(prog["chapter"], 3, "旧存档兼容读出 chapter=3")
	var completed := SaveSystem.get_completed_ids()
	_assert(completed.has("prologue.1") and completed.has("prologue.2"),
		"旧 completed_chapters 映射为 prologue.N")
	# 新存档写读
	SaveSystem.delete_save()
	SaveSystem.save_chapter_complete(0, 2)
	prog = SaveSystem.load_progress()
	_assert_eq(prog["act"], 0, "新存档写读 act")
	_assert_eq(int(prog["chapter"]), 3, "save_chapter_complete 推进到下一章")
	# 序章别名不破坏现有读取
	_assert_eq(SaveSystem.load_current_chapter(), 3, "load_current_chapter 兼容保留")
	GameState.set_prologue(1)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/yanrui/Desktop/iron-throne-tactics && ./scripts/test.sh 2>&1 | grep -E "act_structure|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: FAIL（`set_prologue`/`load_progress`/`_write_json_for_test` 未定义）。

- [ ] **Step 3: 重写 GameState.gd**

```gdscript
# GameState.gd — 全局游戏状态（静态类，无节点）
class_name GameState

# 幕+章双字段。act=0 序章，act=1 第一幕(罗柏)...
static var act: int = 0
static var chapter: int = 1

# 序章兼容别名：序章代码读 current_chapter 不变；正篇返回 -1。
static var current_chapter: int = 1

static func set_prologue(chapter: int) -> void:
	act = 0
	self.chapter = chapter
	current_chapter = chapter

static func set_act(a: int, c: int) -> void:
	act = a
	chapter = c
	current_chapter = -1 if a != 0 else c

static func global_chapter_id() -> String:
	if act == 0:
		return "prologue.%d" % chapter
	return "act%d.%d" % [act, chapter]

# Ch4 部署选择（由 DeployScreen_Ch4 写入，BattleBootstrap_Ch4 读取）
static var deploy_selection: Array[String] = []
```

- [ ] **Step 4: 重写 SaveSystem.gd 关键函数**

替换 `start_new_campaign`/`save_chapter_complete`/`load_current_chapter`/`get_completed_chapters`，新增 `load_progress`/`get_completed_ids`/`_write_json_for_test`。保留旧函数签名兼容。完整新文件：

```gdscript
class_name SaveSystem

const SAVE_PATH := "user://save.json"

static func start_new_campaign() -> void:
	_write_json({
		"act": 0, "chapter": 1,
		"completed": [],
		"timestamp": Time.get_date_string_from_system(),
	})

# act=0 序章；记录完成并推进到下一章。序章内 chapter 连续递增。
static func save_chapter_complete(act: int, chapter: int) -> void:
	var data := _read_json()
	_ensure_new_schema(data)
	var id := _id_of(act, chapter)
	var completed: Array = data.get("completed", [])
	if id not in completed:
		completed.append(id)
	data["completed"] = completed
	var next_act := act
	var next_ch := chapter + 1
	if act == 0 and next_ch > 4:
		next_act = 1
		next_ch = 1
	data["act"] = next_act
	data["chapter"] = next_ch
	data["timestamp"] = Time.get_date_string_from_system()
	_write_json(data)

static func load_progress() -> Dictionary:
	var data := _read_json()
	_ensure_new_schema(data)
	return {"act": int(data.get("act", 0)), "chapter": int(data.get("chapter", 1))}

static func get_completed_ids() -> Array[String]:
	var data := _read_json()
	_ensure_new_schema(data)
	var raw: Array = data.get("completed", [])
	var result: Array[String] = []
	for v in raw:
		result.append(String(v))
	return result

# ── 序章兼容别名（现有代码继续用）─────────────────────
static func load_current_chapter() -> int:
	var prog := load_progress()
	if prog["act"] == 0:
		return maxi(1, int(prog["chapter"]))
	return -1

static func get_completed_chapters() -> Array[int]:
	var ids := get_completed_ids()
	var result: Array[int] = []
	for id in ids:
		if id.begins_with("prologue."):
			result.append(int(id.substr(9)))
	return result

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

static func _id_of(act: int, chapter: int) -> String:
	return "prologue.%d" % chapter if act == 0 else "act%d.%d" % [act, chapter]

# 旧 {chapter, completed_chapters} → 新 {act, chapter, completed}
static func _ensure_new_schema(data: Dictionary) -> void:
	if data.has("act"):
		if not data.has("completed"):
			data["completed"] = []
		return
	# 旧存档推断
	var old_ch := int(data.get("chapter", 1))
	data["act"] = 0
	data["chapter"] = old_ch
	var raw: Array = data.get("completed_chapters", [])
	var completed: Array = []
	for v in raw:
		completed.append("prologue.%d" % int(v))
	data["completed"] = completed

static func _write_json_for_test(data: Dictionary) -> void:
	_write_json(data)

static func _write_json(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func _read_json() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
```

- [ ] **Step 5: 修复序章代码中 save_chapter_complete 的调用点**

序章 Bootstrap 用 `load(SAVE_SYS_PATH).save_chapter_complete(current)`（单参数旧签名）。搜索并改为双参数。Run:

```bash
cd /Users/yanrui/Desktop/iron-throne-tactics/game/冰与火
grep -rn "save_chapter_complete" scripts/
```

预期命中 `BattleBootstrap.gd` 的 `_advance_to`。将 `save_chapter_complete(current)` 改为 `save_chapter_complete(0, current)`（序章 act=0）。同理检查 `Opening.gd` 的 `start_new_campaign` 调用（无需改）。同时 `_advance_to` 中 `GameState.current_chapter = next_chapter` 保持（序章专用路径，act=0）。

- [ ] **Step 6: 跑测试确认通过 + 序章回归**

Run: `cd /Users/yanrui/Desktop/iron-throne-tactics && ./scripts/test.sh 2>&1 | grep -E "act_structure|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: 全绿（42 套件，新套件通过，序章不退化）。若序章套件失败，检查 `save_chapter_complete` 调用点是否漏改。

- [ ] **Step 7: 提交**

```bash
git add scripts/GameState.gd scripts/systems/SaveSystem.gd scripts/battle/BattleBootstrap.gd tests/run_tests.gd
git commit -m "feat: 章节系统重构为 act 幕结构（序章零改动兼容）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: FogSystem 核心逻辑

**Files:**
- Create: `scripts/systems/FogSystem.gd`
- Test: `tests/run_tests.gd`（新增 `_test_fog_system` 套件）

**Interfaces:**
- Produces: `FogSystem` class，方法 `compute_visibility(player_units: Array, map_size: Vector2i, vision_override: Dictionary) -> void`、`is_tile_visible(pos: Vector2i) -> bool`、`is_tile_explored(pos: Vector2i) -> bool`、`is_enemy_visible(enemy: Unit) -> bool`、`get_visible_enemies(enemy_units: Array) -> Array`、`reset() -> void`。视野半径默认 `unit.data.move + 2`。

- [ ] **Step 1: 写失败测试**

套件列表加：

```gdscript
		["战争迷雾系统", _test_fog_system],
```

preload 加：

```gdscript
const FogSystemClass := preload("res://scripts/systems/FogSystem.gd")
```

套件函数（用 TestBootstrap 已有设施造单位；若造单位复杂，改用纯坐标 mock——FogSystem 只需单位的 grid_pos 和 data.move）：

```gdscript
func _test_fog_system() -> void:
	var fog := FogSystemClass.new()
	# 视野计算：单位在 (5,5)，move=5 → vision=7，切比雪夫距离≤7 可见
	fog.compute_visibility([_mock_fog_unit(Vector2i(5,5), 5)], Vector2i(20,20), {})
	_assert(fog.is_tile_visible(Vector2i(5,5)), "单位自身格可见")
	_assert(fog.is_tile_visible(Vector2i(12,5)), "视野半径内格可见(距离7)")
	_assert(not fog.is_tile_visible(Vector2i(13,5)), "视野半径外格不可见(距离8)")
	_assert(fog.is_tile_explored(Vector2i(12,5)), "可见格同时标记已探索")
	# 多单位视野合并
	fog.compute_visibility([_mock_fog_unit(Vector2i(5,5),5), _mock_fog_unit(Vector2i(15,15),5)], Vector2i(20,20), {})
	_assert(fog.is_tile_visible(Vector2i(15,15)), "第二单位视野合并")
	# 视野加成 override
	fog.compute_visibility([_mock_fog_unit(Vector2i(5,5),5)], Vector2i(20,20), {Vector2i(5,5): 10})
	_assert(fog.is_tile_visible(Vector2i(15,5)), "视野加成 override 生效(距离10)")
	# 敌军显隐
	var visible_enemy := _mock_fog_unit(Vector2i(6,6), 5)
	var hidden_enemy := _mock_fog_unit(Vector2i(18,18), 5)
	fog.compute_visibility([_mock_fog_unit(Vector2i(5,5),5)], Vector2i(20,20), {})
	_assert(fog.is_enemy_visible(visible_enemy), "视野内敌军可见")
	_assert(not fog.is_enemy_visible(hidden_enemy), "视野外敌军不可见")
	var vis := fog.get_visible_enemies([visible_enemy, hidden_enemy])
	_assert_eq(vis.size(), 1, "get_visible_enemies 仅返回可见敌军")
	# reset
	fog.reset()
	_assert(not fog.is_tile_visible(Vector2i(5,5)), "reset 清空可见格")

# 构造仅含 grid_pos 与 data.move 的最小 Unit mock
func _mock_fog_unit(pos: Vector2i, mv: int) -> Unit:
	var u := Unit.new()
	u.grid_pos = pos
	u.data = UnitDataClass.new()
	u.data.move = mv
	return u
```

> 注：先确认 `Unit` 与 `UnitData` 可 `new()` 且 `grid_pos` 可写。若 `Unit` 依赖节点树无法裸 new，则改 FogSystem 接口为接受 `pos: Vector2i` 与 `vision: int` 数组而非 Unit 对象——在 Step 3 据实调整接口，测试同步改用坐标数组。**优先尝试 Unit 裸 new；不可行则切换坐标数组接口。**

- [ ] **Step 2: 跑测试确认失败**

Run: `./scripts/test.sh 2>&1 | grep -E "fog_system|通过.*失败" | tail -3`
Expected: FAIL（FogSystemClass 预加载失败，文件不存在）。

- [ ] **Step 3: 实现 FogSystem.gd**

```gdscript
# FogSystem.gd — 战争迷雾（方案 C：地形全知、敌军显隐、单向）
# 由 BattleMap 持有，fog_enabled=true 时启用。
class_name FogSystem

var _visible_tiles: Dictionary = {}    # 本回合可见 Vector2i -> true
var _explored_tiles: Dictionary = {}   # 累计已探索
var _map_size: Vector2i = Vector2i.ZERO

func reset() -> void:
	_visible_tiles.clear()
	_explored_tiles.clear()

func compute_visibility(player_units: Array, map_size: Vector2i, vision_override: Dictionary) -> void:
	_map_size = map_size
	_visible_tiles.clear()
	for unit in player_units:
		if not is_instance_valid(unit):
			continue
		var center: Vector2i = unit.grid_pos
		var vision: int = int(vision_override.get(center, unit.data.move + 2))
		for dx in range(-vision, vision + 1):
			for dy in range(-vision, vision + 1):
				if maxi(absi(dx), absi(dy)) > vision:
					continue
				var t := Vector2i(center.x + dx, center.y + dy)
				if t.x < 0 or t.y < 0 or t.x >= map_size.x or t.y >= map_size.y:
					continue
				_visible_tiles[t] = true
				_explored_tiles[t] = true

func is_tile_visible(pos: Vector2i) -> bool:
	return _visible_tiles.has(pos)

func is_tile_explored(pos: Vector2i) -> bool:
	return _explored_tiles.has(pos)

func is_enemy_visible(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	return is_tile_visible(enemy.grid_pos)

func get_visible_enemies(enemy_units: Array) -> Array:
	var result: Array = []
	for e in enemy_units:
		if is_enemy_visible(e):
			result.append(e)
	return result
```

- [ ] **Step 4: 跑测试确认通过**

Run: `./scripts/test.sh 2>&1 | grep -E "战争迷雾|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: 迷雾套件通过，全绿。若 Unit 裸 new 失败，按 Step 1 注切换坐标数组接口。

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/FogSystem.gd tests/run_tests.gd
git commit -m "feat: 战争迷雾系统核心（视野/敌军显隐）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 迷雾接入 BattleMap（危险区/敌军预览/遮罩）

**Files:**
- Modify: `scripts/battle/BattleMap.gd`
- Test: `tests/run_tests.gd`（扩展 `_test_fog_system` 加集成断言）

**Interfaces:**
- Consumes: `FogSystem`（Task 2）。
- Produces: BattleMap 新成员 `fog_enabled: bool = false`、`_fog: FogSystem`、`_recalc_fog()`、`_filter_enemies_by_fog(enemies: Array) -> Array`。序章 `fog_enabled=false` 时 `_filter_enemies_by_fog` 原样返回（零行为变化）。

- [ ] **Step 1: 写失败测试（集成断言）**

在 `_test_fog_system` 末尾追加（用 TestBootstrap 实例化真实战斗，验证序章 fog=false 不影响危险区）：

```gdscript
	# 序章 fog_enabled=false 时危险区不迷雾过滤（回归保护）
	var prologue_battle := TestBootstrapClass.new()
	root.add_child(prologue_battle)
	await process_frame
	prologue_battle.set_script(TestBootstrapClass)  # 确保用测试 bootstrap
	_assert(not prologue_battle.fog_enabled, "序章默认 fog_enabled=false")
	# _filter_enemies_by_fog 在 fog 关闭时原样返回全部敌军
	var all_enemies := prologue_battle.enemy_units.duplicate()
	var filtered := prologue_battle._filter_enemies_by_fog(all_enemies)
	_assert_eq(filtered.size(), all_enemies.size(),
		"序章 fog 关闭时敌军不被迷雾过滤")
	prologue_battle.queue_free()
	await process_frame
```

- [ ] **Step 2: 跑测试确认失败**

Run: `./scripts/test.sh 2>&1 | grep -E "fog 关闭时|通过.*失败" | tail -2`
Expected: FAIL（`fog_enabled`/`_filter_enemies_by_fog` 未定义）。

- [ ] **Step 3: 改 BattleMap.gd**

在 `BattleMap.gd` 成员区（约 60 行 `_danger_tiles` 附近）加：

```gdscript
var fog_enabled: bool = false
var _fog: FogSystem = null
```

在顶部 preload 区加：

```gdscript
const FogSystemClass := preload("res://scripts/systems/FogSystem.gd")
```

在 `_ready`（或初始化处）末尾加：

```gdscript
	if fog_enabled:
		_fog = FogSystemClass.new()
```

新增方法（放在 `_update_danger_zone` 附近）：

```gdscript
func _recalc_fog() -> void:
	if not fog_enabled or _fog == null:
		return
	var vis_override := {}
	# 主角/副将视野加成 +1（罗柏/黑鱼）
	for u in player_units:
		if is_instance_valid(u) and u.data.is_protagonist:
			vis_override[u.grid_pos] = u.data.move + 3
	_fog.compute_visibility(player_units, Vector2i(map_width, map_height), vis_override)
	queue_redraw()

func _filter_enemies_by_fog(enemies: Array) -> Array:
	if not fog_enabled or _fog == null:
		return enemies
	return _fog.get_visible_enemies(enemies)
```

修改 `_update_danger_zone`（`BattleMap.gd:1443`）：把遍历 `enemy_units` 改为遍历 `_filter_enemies_by_fog(enemy_units)`：

```gdscript
func _update_danger_zone() -> void:
	_danger_tiles.clear()
	for enemy in _filter_enemies_by_fog(enemy_units):
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		for pos in _calc_move_range(enemy):
			for ap in _calc_attack_tiles([pos]):
				_danger_tiles[ap] = true
```

> 实现时对照原 `_update_danger_zone` 1444-1454 行的实际循环结构，仅替换遍历源为过滤后的敌军，保留原有 attack-tiles 逻辑。

修改 `_show_enemy_preview`（1822 行）与攻击锁定逻辑：可锁定攻击的敌军 = `_filter_enemies_by_fog(_adj_enemies(...))`。在 `_show_enemy_preview` 开头若 `_fog` 且目标不可见则 return。

在玩家回合开始处（搜索回合切换逻辑，`_begin_player_turn` 或等价）调用 `_recalc_fog()`；敌军回合结束后也调用。**搜索 `func _start_player_turn` / `func _end_enemy_turn` 等实际函数名后插入调用。**

- [ ] **Step 4: 跑测试确认通过 + 序章回归**

Run: `./scripts/test.sh 2>&1 | grep -E "fog 关闭时|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: 全绿。序章危险区测试（`_test_battle_predict_full` 等）不退化。

- [ ] **Step 5: 提交**

```bash
git add scripts/battle/BattleMap.gd tests/run_tests.gd
git commit -m "feat: 迷雾接入 BattleMap 危险区与敌军预览（fog_enabled 隔离）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 单位数据与地图精灵

**Files:**
- Create: `data/units/robb_stark.json`, `brynden_tully.json`, `jaime_lannister.json`, `golden_lion_knight.json`
- Modify: `design/map-sprites/generate.py`
- Test: `tests/run_tests.gd`（`_test_map_sprite_assets_and_animation` 已覆盖精灵，确认新增精灵被纳入）

**Interfaces:**
- Produces: 4 个单位 json（UnitData.from_dict 可读）；3 张新地图精灵 `robb_stark_map.png`/`brynden_tully_map.png`/`golden_lion_knight_map.png`（96×32 三帧）。

- [ ] **Step 1: 写单位 json**

`data/units/robb_stark.json`：

```json
{
  "name": "罗柏", "class": "剑骑士", "level": 1,
  "hp": 32, "max_hp": 32, "pow": 12, "spd": 11, "skl": 12, "def": 8, "lck": 8, "con": 9, "move": 6,
  "weapon_type": "sword", "weapon_rank": "C", "weapon_uses": 35, "weapon_max_uses": 35,
  "weapon_stats": {"might": 8, "hit": 85, "weight": 6},
  "is_protagonist": true, "is_boss": false, "min_hp": 0,
  "items": [{"name": "急救药", "type": "heal", "heal_amount": 10, "uses": 2}]
}
```

`data/units/brynden_tully.json`（黑鱼，枪/重装）：

```json
{
  "name": "黑鱼", "class": "枪骑士", "level": 3,
  "hp": 38, "max_hp": 38, "pow": 13, "spd": 9, "skl": 11, "def": 12, "lck": 6, "con": 11, "move": 5,
  "weapon_type": "lance", "weapon_rank": "C", "weapon_uses": 30, "weapon_max_uses": 30,
  "weapon_stats": {"might": 10, "hit": 80, "weight": 8},
  "is_protagonist": false, "is_boss": false, "min_hp": 0,
  "items": []
}
```

`data/units/jaime_lannister.json`（Boss，min_hp=1）：

```json
{
  "name": "詹姆", "class": "剑骑士", "level": 7,
  "hp": 44, "max_hp": 44, "pow": 15, "spd": 14, "skl": 14, "def": 11, "lck": 7, "con": 10, "move": 6,
  "weapon_type": "sword", "weapon_rank": "B", "weapon_uses": 40, "weapon_max_uses": 40,
  "weapon_stats": {"might": 11, "hit": 90, "weight": 7},
  "is_protagonist": false, "is_boss": true, "min_hp": 1,
  "items": []
}
```

`data/units/golden_lion_knight.json`（金狮骑士）：

```json
{
  "name": "金狮骑士", "class": "重枪兵", "level": 4,
  "hp": 30, "max_hp": 30, "pow": 12, "spd": 7, "skl": 9, "def": 13, "lck": 4, "con": 12, "move": 4,
  "weapon_type": "lance", "weapon_rank": "C", "weapon_uses": 30, "weapon_max_uses": 30,
  "weapon_stats": {"might": 10, "hit": 75, "weight": 9},
  "is_protagonist": false, "is_boss": false, "min_hp": 0,
  "items": []
}
```

> 验证 `weapon_type` 合法值：检查 `BattleCalculator.gd` 的武器三角（序章已知 `sword/axe/lance`，三角为 剑>斧>枪>剑）。若 `lance` 不是现有 key，改用现有合法 key。

- [ ] **Step 2: 改 generate.py 加精灵条目**

在 `design/map-sprites/generate.py` 的 `P` 字典末尾（`targaryen_soldier` 行后）加：

```python
 'robb_stark': dict(skin='#c49068', hair='#5a3a2a', armor='#3e4a54', trim='#8fa2ad', cape='#27333b', leg='#25282c', weapon='sword', accent='#aab7bd', broad=False),
 'brynden_tully': dict(skin='#b8855f', hair='#88807a', armor='#4a5a4a', trim='#8a9a7a', cape='#33402f', leg='#2c3326', weapon='spear_shield', accent='#aeb878', plume='#c9d0a0'),
 'golden_lion_knight': dict(skin='#c4926d', hair='#4a3a2a', armor='#a7312d', trim='#d5a83e', cape='#8f2425', leg='#552728', weapon='spear_shield', accent='#f0c95b', helmet=True),
```

- [ ] **Step 3: 重生成精灵 + 验证确定性**

Run:
```bash
cd /Users/yanrui/Desktop/iron-throne-tactics
python3 design/map-sprites/generate.py
```
确认输出含 18 张图集（原 15 + 新 3）。新精灵出现在 `game/冰与火/assets/units/`。

- [ ] **Step 4: 更新精灵资源测试的期望列表**

`tests/run_tests.gd` 的 `_test_map_sprite_assets_and_animation` 中 `expected_sprite_map` 与 `sprite_names` 需纳入新精灵。在 `sprite_names` 末尾（`janos_slynt_map.png` 后）加：

```gdscript
	sprite_names.append("robb_stark_map.png")
	sprite_names.append("brynden_tully_map.png")
	sprite_names.append("golden_lion_knight_map.png")
```

- [ ] **Step 5: 跑测试确认通过**

Run: `./scripts/test.sh 2>&1 | grep -E "地图精灵|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: 全绿（新精灵 96×32 三帧验证通过）。

- [ ] **Step 6: 提交**

```bash
git add data/units/robb_stark.json data/units/brynden_tully.json data/units/jaime_lannister.json data/units/golden_lion_knight.json design/map-sprites/generate.py "game/冰与火/assets/units/robb_stark_map.png" "game/冰与火/assets/units/brynden_tully_map.png" "game/冰与火/assets/units/golden_lion_knight_map.png" design/map-sprites/review/map_sprites_contact_sheet.png tests/run_tests.gd
git commit -m "feat: 罗柏线单位数据与地图精灵（罗柏/黑鱼/詹姆/金狮骑士）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 章节简报与对话/过场数据

**Files:**
- Create: `scripts/chapter/Act1ChapterBriefs.gd`
- Create: `data/dialogues/act1_ch1_pre.json`, `data/dialogues/act1_ch1_post.json`
- Create: `data/cutscenes/act1_ch1_opening.json`, `data/cutscenes/act1_ch1_jaime_capture.json`
- Test: `tests/run_tests.gd`（`_test_dialogue_json`/`_test_cutscene_json` 自动加载所有 data 文件，确认新文件格式合法）

**Interfaces:**
- Produces: `Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY` / `A1C1_BATTLE_OBJECTIVE` / `A1C1_PROGRESS_*` / `A1C1_BATTLE_RESOLUTION` 常量。

- [ ] **Step 1: 写 Act1ChapterBriefs.gd**

```gdscript
# Act1ChapterBriefs.gd — 第一幕（罗柏线）章节简报常量
class_name Act1ChapterBriefs

const A1C1_OBJECTIVE_SUMMARY := "目标：夜袭呓语森林，击溃并生擒詹姆·兰尼斯特。"
const A1C1_BATTLE_OBJECTIVE := "夜袭呓语森林，击溃并生擒詹姆·兰尼斯特。"
const A1C1_PROGRESS_WOOD_EDGE := "第一段：林缘集结——敌军营火就在林中，靠推进揭开视野，别让伏击在暗处瓦解。"
const A1C1_PROGRESS_CAMP := "第二段：詹姆本阵——已逼近营地，压向詹姆，把他逼到投降。"
const A1C1_BATTLE_RESOLUTION := "第二段：詹姆本阵已破——詹姆被生擒，呓语森林夜袭告捷。"
```

- [ ] **Step 2: 写对话 JSON**

`data/dialogues/act1_ch1_pre.json`：

```json
{
  "id": "act1_ch1_pre",
  "lines": [
    {"speaker": "黑鱼", "text": "林子很黑。火把一熄，他们就看不见我们。", "next": 1},
    {"speaker": "罗柏", "text": "可我们也看不见他们。", "next": 2},
    {"speaker": "黑鱼", "text": "所以我们先动。詹姆的人还在睡梦里数战利品。", "next": 3},
    {"speaker": "凯特琳", "text": "罗柏——把你的人带回来。", "next": 4},
    {"speaker": "罗柏", "text": "我会的，母亲。", "next": 5}
  ]
}
```

`data/dialogues/act1_ch1_post.json`：

```json
{
  "id": "act1_ch1_post",
  "lines": [
    {"speaker": "黑鱼", "text": "詹姆·兰尼斯特。活捉的。", "next": 1},
    {"speaker": "罗柏", "text": "杀了他就再没筹码了。", "next": 2},
    {"speaker": "詹姆", "text": "……你以为关得住我？", "next": 3},
    {"speaker": "黑鱼", "text": "第一仗，调度得不错，小子。", "next": 4}
  ]
}
```

- [ ] **Step 3: 写过场 JSON**

`data/cutscenes/act1_ch1_opening.json`：

```json
{
  "id": "act1_ch1_opening",
  "slides": [
    {"text": "奔流城外，军帐。", "subtext": "篡夺者战争之后十五年。\n罗柏·史塔克，十五岁。", "duration": 4.0, "scene_art": ""},
    {"text": "詹姆·兰尼斯特的军队扎营于呓语森林，", "subtext": "三倍于罗柏的兵力，\n围困奔流城。", "duration": 5.0, "scene_art": ""},
    {"text": "凯特琳与黑鱼劝他稳守。", "subtext": "罗柏看着地图，\n手指停在那片密林上。", "duration": 5.0, "scene_art": ""},
    {"text": "“今夜，我们进林子。”", "subtext": "这是他第一次独自下注。", "duration": 4.0, "scene_art": ""}
  ]
}
```

`data/cutscenes/act1_ch1_jaime_capture.json`：

```json
{
  "id": "act1_ch1_jaime_capture",
  "slides": [
    {"text": "詹姆的剑被挑飞，跪倒在泥里。", "subtext": "周围是他自己的金狮骑士，\n已无人能站起。", "duration": 4.0, "scene_art": ""},
    {"text": "“杀了我，”詹姆冷笑，“你就再无筹码。”", "subtext": "", "duration": 4.5, "scene_art": ""},
    {"text": "罗柏没有杀他。", "subtext": "他收剑入鞘，\n命人将詹姆捆起。", "duration": 4.0, "scene_art": ""}
  ]
}
```

- [ ] **Step 4: 跑测试确认新 JSON 合法**

Run: `./scripts/test.sh 2>&1 | grep -E "对话 JSON|过场|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: 全绿（`_test_dialogue_json`/`_test_cutscene_json` 自动加载新文件并通过格式校验）。

- [ ] **Step 5: 提交**

```bash
git add scripts/chapter/Act1ChapterBriefs.gd data/dialogues/act1_ch1_pre.json data/dialogues/act1_ch1_post.json data/cutscenes/act1_ch1_opening.json data/cutscenes/act1_ch1_jaime_capture.json
git commit -m "feat: A1C1 章节简报与对话/过场数据

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: BattleBootstrap_A1C1 + 战斗场景

**Files:**
- Create: `scripts/battle/BattleBootstrap_A1C1.gd`
- Create: `scenes/battle/BattleMap_A1C1.tscn`
- Test: `tests/run_tests.gd`（新增 `_test_act1_ch1_whispering_wood` 套件，本任务先加地图/单位/生擒核心断言，Task 8 补流程）

**Interfaces:**
- Consumes: `FogSystem`(Task2/3)、4 单位 json(Task4)、简报/数据(Task5)。
- Produces: `BattleBootstrap_A1C1` class，`extends "res://scripts/battle/BattleMap.gd"`，成员 `_jaime_unit: Unit`、`_capture_triggered: bool`、`fog_enabled = true`（在 `_ready` 前设）。地图 22×16，`victory_pos` 为詹姆初始位。`UNIT_SPRITE_MAP` 含 4 新单位。

- [ ] **Step 1: 写失败测试（地图+单位+生擒核心）**

preload 加：

```gdscript
const A1C1BootstrapClass := preload("res://scripts/battle/BattleBootstrap_A1C1.gd")
const Act1ChapterBriefsClass := preload("res://scripts/chapter/Act1ChapterBriefs.gd")
```

测试用子类（override 阻断过场/对话，仿 `TestCh3Bootstrap`）：

```gdscript
class TestA1C1Bootstrap extends A1C1BootstrapClass:
	func _ready() -> void:
		pass
	func _play_dialogue(_p: String) -> void:
		pass
	func _play_cutscene(_p: String) -> void:
		pass
	func _advance_to(_n: int) -> void:
		pass
	var recorded_cutscenes: Array = []
	var recorded_advances: Array = []
```

> 实际 override 需对照 `BattleBootstrap_Ch3.gd` 的 `_trigger_ch3_tower`/`_advance_chapter` 等被调方法名，在 A1C1 里定义等价 `_trigger_jaime_capture`/`_advance_to`，测试子类 override 之并记录调用。

套件列表加：

```gdscript
		["A1C1 呓语森林之战", _test_act1_ch1_whispering_wood],
```

套件函数：

```gdscript
func _test_act1_ch1_whispering_wood() -> void:
	var battle := TestA1C1Bootstrap.new()
	root.add_child(battle)
	battle.fog_enabled = true
	await process_frame
	battle._setup_act1_ch1()  # 显式调用 setup（_ready 被 override 跳过）
	await process_frame
	# 地图尺寸
	_assert_eq(battle.map_width, 22, "A1C1 地图宽 22")
	_assert_eq(battle.map_height, 16, "A1C1 地图高 16")
	# 迷雾启用
	_assert(battle.fog_enabled and battle._fog != null, "A1C1 启用战争迷雾")
	# 罗柏与詹姆生成
	_assert(battle._robb_unit != null and not battle._robb_unit.is_dead(), "罗柏已生成")
	_assert(battle._jaime_unit != null, "詹姆已生成")
	_assert_eq(battle._jaime_unit.data.min_hp, 1, "詹姆 min_hp=1（生擒底板）")
	_assert(battle._robb_unit.data.is_protagonist, "罗柏为主角")
	# 可达路径：罗柏到詹姆位存在通路
	_assert(_path_exists_on_passable_grid(battle, battle._robb_unit.grid_pos, battle._jaime_unit.grid_pos),
		"A1C1 罗柏到詹姆存在可达路径")
	# 生擒流程：詹姆 HP 触底 → 触发捕获 → 不再重复
	battle._jaime_unit.data.hp = 1
	battle._check_victory()
	_assert(battle._capture_triggered, "詹姆 HP 触底触发生擒")
	_assert(battle.recorded_cutscenes.has("res://data/cutscenes/act1_ch1_jaime_capture.json"),
		"生擒触发捕获过场")
	# 罗柏死亡 → GameOver（通过 is_protagonist，基类已处理，仅断言不崩）
	battle.queue_free()
	await process_frame
```

> `_robb_unit`/`_jaime_unit`/`_setup_act1_ch1`/`_capture_triggered` 为 A1C1 待定义成员。`_path_exists_on_passable_grid` 已存在（180 行）。

- [ ] **Step 2: 跑测试确认失败**

Run: `./scripts/test.sh 2>&1 | grep -E "呓语森林|通过.*失败" | tail -2`
Expected: FAIL（A1C1BootstrapClass 预加载失败）。

- [ ] **Step 3: 写 BattleBootstrap_A1C1.gd**

```gdscript
# BattleBootstrap_A1C1.gd — 第一幕第一章《呓语森林之战》（22×16）
# 胜利条件：击溃詹姆（min_hp=1）→ 生擒过场 → 推进
# 特殊机制：战争迷雾（夜袭）；詹姆生擒
extends "res://scripts/battle/BattleMap.gd"

const Act1ChapterBriefs := preload("res://scripts/chapter/Act1ChapterBriefs.gd")

const UNIT_SPRITE_MAP := {
	"robb_stark.json":          "robb_stark_map.png",
	"brynden_tully.json":       "brynden_tully_map.png",
	"north_knight_robb.json":   "northern_knight_map.png",
	"jaime_lannister.json":     "jaime_lannister_map.png",
	"golden_lion_knight.json":  "golden_lion_knight_map.png",
	"lannister_soldier.json":   "lannister_soldier_map.png",
}
# 立绘占位：罗柏/黑鱼暂无立绘映射；詹姆复用现有
const UNIT_PORTRAIT_MAP := {
	"jaime_lannister.json": "jaime_lannister_portrait.png",
}

const TERRAIN_A1C1: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=0  峭壁封顶
	[3,0,0,0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,3],  # y=1  詹姆营地北
	[3,0,0,0,1,1,1,1,1,1,0,1,1,1,1,0,0,0,0,0,0,3],  # y=2  营地+篝火(plain)
	[3,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,3],  # y=3
	[3,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,3],  # y=4
	[3,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,3],  # y=5
	[3,4,4,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,3],  # y=6  西侧河流起
	[3,4,4,4,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,3],  # y=7
	[3,4,4,4,4,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,3],  # y=8
	[3,4,4,4,4,4,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,3],  # y=9  河流/林地交界
	[3,4,4,4,4,4,4,0,0,1,1,0,0,0,0,0,0,0,0,0,0,3],  # y=10
	[3,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=11  西侧浅滩带
	[3,0,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=12
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=13  玩家集结林缘南
	[3,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,0,3],  # y=14
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=15 峭壁封底
]

var _robb_unit: Unit = null
var _jaime_unit: Unit = null
var _capture_triggered: bool = false

func _ready() -> void:
	fog_enabled = true
	_setup_act1_ch1()

func _setup_act1_ch1() -> void:
	map_width = 22
	map_height = 16
	_jaime_unit = null  # 将在生成时赋值
	# victory_pos = 詹姆初始位（11,2）；生擒靠 min_hp 触底，不用抵达胜利
	victory_pos = Vector2i(11, 2)
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_A1C1)
	# 我方（南方林缘，rows 13-14）
	_robb_unit = _make_unit_r("robb_stark.json", 0, Vector2i(10, 13))
	_make_unit("brynden_tully.json", 0, Vector2i(8, 14))
	_make_unit("north_knight_robb.json", 0, Vector2i(12, 14))
	_make_unit("north_knight_robb.json", 0, Vector2i(6, 13))
	# 敌方（北方营地，rows 1-5）
	_jaime_unit = _make_unit_r("jaime_lannister.json", 1, Vector2i(11, 2))
	_make_unit("golden_lion_knight.json", 1, Vector2i(8, 3))
	_make_unit("golden_lion_knight.json", 1, Vector2i(14, 3))
	_make_unit("lannister_soldier.json", 1, Vector2i(6, 5))
	_make_unit("lannister_soldier.json", 1, Vector2i(16, 5))
	_make_unit("lannister_soldier.json", 1, Vector2i(10, 4))
	_redraw_all()
	_recalc_fog()
	await _play_opening_hud_sequence_a1c1()
	await _play_dialogue("res://data/dialogues/act1_ch1_pre.json")

func _play_opening_hud_sequence_a1c1() -> void:
	# 复用基类开场 HUD 序列；若无 act 版本，调用基类带 act 参数
	# 对照基类 _play_opening_hud_sequence(chapter, objective) 签名调整
	_set_objective_status(Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY)
	_set_battle_status("夜袭 · 视野受限，敌军藏于林中")

func _check_victory() -> void:
	if _battle_over or _capture_triggered:
		return
	if is_instance_valid(_jaime_unit) and not _jaime_unit.is_dead() \
			and _jaime_unit.data.hp <= _jaime_unit.data.min_hp:
		_capture_triggered = true
		_trigger_jaime_capture()
	# 罗柏死亡 → 基类 GameOver（is_protagonist 已处理），此处不重写

func _trigger_jaime_capture() -> void:
	_battle_over = true
	await _play_cutscene("res://data/cutscenes/act1_ch1_jaime_capture.json")
	await _play_dialogue("res://data/dialogues/act1_ch1_post.json")
	_advance_to_act1_ch2()

func _advance_to_act1_ch2() -> void:
	# 推进到 act1.ch2（占位：暂回 Opening，待后续章节实现）
	var SaveSys = load("res://scripts/systems/SaveSystem.gd")
	SaveSys.save_chapter_complete(1, 1)
	GameState.set_act(1, 2)
	# act1.ch2 场景未实现 → 回主菜单
	get_tree().change_scene_to_file("res://scenes/Opening.tscn")
```

> 实现时核对基类 `_play_opening_hud_sequence`/`_set_objective_status`/`_set_battle_status`/`_paint_from`/`_make_unit_r`/`_redraw_all`/`_apply_cam_limits` 的真实签名与可见性（private 前缀 `_` 在 GDScript 不强制私有，子类可调）。若 `_play_opening_hud_sequence` 需要 chapter int，A1C1 传一个 act 内序号或新建 act 版本。

- [ ] **Step 4: 创建 BattleMap_A1C1.tscn**

复制 `scenes/battle/BattleMap_Ch3.tscn` 为 `BattleMap_A1C1.tscn`，将 `path="res://scripts/battle/BattleBootstrap_Ch3.gd"` 改为 `res://scripts/battle/BattleBootstrap_A1C1.gd`，节点名保持。确保继承的 `HighlightLayer` 等子节点保留。

> 若 `BattleMap_Ch3.tscn` 结构特殊，改以 `BattleMap.tscn`（基类场景）为蓝本复制，仅换脚本。

- [ ] **Step 5: 跑测试确认通过**

Run: `./scripts/test.sh 2>&1 | grep -E "呓语森林|通过.*失败|TEST_RUN_COMPLETE" | tail -3`
Expected: A1C1 套件通过，全绿。若 `_setup_act1_ch1` 中 `super._ready()` 因 `fog_enabled` 时机问题报错，调整 `_ready` 先设 `fog_enabled` 再 `super._ready()`（已在 Step 3 处理）。

- [ ] **Step 6: 提交**

```bash
git add scripts/battle/BattleBootstrap_A1C1.gd scenes/battle/BattleMap_A1C1.tscn tests/run_tests.gd
git commit -m "feat: A1C1 呓语森林之战 bootstrap（迷雾+生擒詹姆）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Opening_A1C1 + 主菜单 act 分发接入

**Files:**
- Create: `scripts/chapter/Opening_A1C1.gd`, `scenes/chapter/Act1_Ch1_Opening.tscn`
- Modify: `scripts/Opening.gd`（act 分发 + Debug 按钮）
- Test: `tests/run_tests.gd`（`_test_opening_main_menu` 扩展或新增断言）

**Interfaces:**
- Consumes: Task 6 场景、Task 1 act 系统。
- Produces: 序章完成后 → `Opening` 读取存档 `load_progress`，若 `act>=1` 跳 `Act1_Ch1_Opening.tscn`；Debug 按钮可直跳 A1C1。

- [ ] **Step 1: 写失败测试**

在 `_test_opening_main_menu` 末尾加（或新增 `_test_act1_opening_dispatch`）：

```gdscript
	# 序章完成后继续游戏应进入 act1
	SaveSystem.delete_save()
	SaveSystem.save_chapter_complete(0, 4)  # 序章四章全完成 → 推进 act1.ch1
	var prog := SaveSystem.load_progress()
	_assert_eq(int(prog["act"]), 1, "序章全完成推进到 act1")
	_assert_eq(int(prog["chapter"]), 1, "act1.ch1")
	# Opening 继续游戏路径会读 load_progress；验证 _continue 目标场景
	# （Opening._on_continue_pressed 内部读 load_progress 分发）
	SaveSystem.delete_save()
	GameState.set_prologue(1)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `./scripts/test.sh 2>&1 | grep -E "推进到 act1|通过.*失败" | tail -2`
Expected: 可能 PASS（save_chapter_complete 已实现）——若 PASS 说明存档推进已对，仅需改 Opening 分发。重点验证 Step 4 的 Opening 改动不破坏 `_test_opening_main_menu`。

- [ ] **Step 3: 写 Opening_A1C1.gd**

```gdscript
# Opening_A1C1.gd — 第一幕第一章开场
extends "res://scripts/chapter/ChapterOpening.gd"

const Act1ChapterBriefs := preload("res://scripts/chapter/Act1ChapterBriefs.gd")

func _setup() -> void:
	_chapter_num   = "第一幕·一"
	_chapter_title = "呓语森林"
	_chapter_time  = "五王之战 · 第一年"
	_chapter_sub_label = "夜袭章节 / 视野受限"
	_chapter_objective = Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY
	_battle_scene  = "res://scenes/battle/BattleMap_A1C1.tscn"
	_cutscene_files = ["res://data/cutscenes/act1_ch1_opening.json"]

func _load_battle() -> void:
	# 进入战斗前设置 GameState
	GameState.set_act(1, 1)
	super._load_battle()
```

- [ ] **Step 4: 创建 Act1_Ch1_Opening.tscn**

以 `scenes/chapter/Ch3_Opening.tscn` 为蓝本复制为 `Act1_Ch1_Opening.tscn`，脚本路径改 `res://scripts/chapter/Opening_A1C1.gd`。

- [ ] **Step 5: 改 Opening.gd act 分发**

在 `Opening.gd` 的"继续游戏"逻辑（`_on_continue_pressed`，约 103 行）中，`load_current_chapter()` 改用 `load_progress()`：

```gdscript
func _on_continue_pressed() -> void:
	var prog := SaveSystem.load_progress()
	var act := int(prog["act"])
	var ch := int(prog["chapter"])
	if act == 0:
		# 序章：沿用旧路径
		if ch <= 1:
			GameState.set_prologue(1)
			_play_chapter_1()
		else:
			GameState.set_prologue(ch)
			_change_scene(CHAPTER_SCENE_MAP.get(ch, CHAPTER_SCENE_MAP[1]))
	else:
		# 正篇：act1.ch1 → Act1_Ch1_Opening
		_change_scene("res://scenes/chapter/Act1_Ch1_Opening.tscn")
```

> 对照原 `_on_continue_pressed` 实际结构改，保留 `_new_game_confirm` 等逻辑。

Debug 按钮：在 `_open_debug_chapter` 旁加 `_open_debug_act1_ch1`，绑到新 Debug 按钮 `DebugAct1Ch1Button`（在 `Opening.tscn` 的 DebugSection 加一个按钮）。或简化：扩展现有 `range(1,5)` 为可点击 act1 入口。

- [ ] **Step 6: 跑测试确认通过 + 序章回归**

Run: `./scripts/test.sh 2>&1 | grep -E "Opening|主菜单|通过.*失败|TEST_RUN_COMPLETE" | tail -4`
Expected: 全绿。`_test_opening_main_menu`/`_test_chapter_opening_configuration` 不退化。

- [ ] **Step 7: 提交**

```bash
git add scripts/chapter/Opening_A1C1.gd scenes/chapter/Act1_Ch1_Opening.tscn scripts/Opening.gd scenes/Opening.tscn tests/run_tests.gd
git commit -m "feat: A1C1 开场与主菜单 act 分发接入

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 章节流程回归 + 地图规范回归

**Files:**
- Modify: `tests/run_tests.gd`（`_test_act1_ch1_whispering_wood` 补全 + `_test_map_visual_language_spec` 纳入 A1C1）

**Interfaces:**
- Consumes: 全部前序任务。

- [ ] **Step 1: 扩展 A1C1 套件补全流程断言**

在 `_test_act1_ch1_whispering_wood` 中补充：
- 詹姆在迷雾中时不可被锁定（`_filter_enemies_by_fog` 过滤）；罗柏推进揭开后可锁定。
- 生擒触发后 `recorded_advances` 记录推进（若 `_advance_to_act1_ch2` 被 override 记录）。
- 开场 HUD 文案含 `Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY`（对照序章 HUD 文案回归模式）。

```gdscript
	# 迷雾：詹姆初始在北方营地，罗柏在南，詹姆不可见
	var jaime_visible := battle._fog.is_enemy_visible(battle._jaime_unit)
	_assert(not jaime_visible, "开局詹姆在迷雾中不可见（夜袭）")
	# 罗柏死亡路径不崩（基类 GameOver）
	battle.queue_free()
	await process_frame
```

- [ ] **Step 2: 地图规范回归纳入 A1C1**

在 `_test_map_visual_language_spec` 中，对 A1C1 复用出生点可通行/胜利格可通行/可达路径三项。实例化 `TestA1C1Bootstrap`，断言：

```gdscript
	# A1C1 呓语森林纳入地图视觉规范回归
	var a1c1 := TestA1C1Bootstrap.new()
	root.add_child(a1c1)
	a1c1.fog_enabled = true
	await process_frame
	a1c1._setup_act1_ch1()
	await process_frame
	_assert(_path_exists_on_passable_grid(a1c1, a1c1._robb_unit.grid_pos, a1c1.victory_pos),
		"A1C1 规范回归：罗柏到胜利格存在可达路径")
	_assert(a1c1.is_passable(a1c1._robb_unit.grid_pos), "A1C1 规范回归：出生点可通行")
	a1c1.queue_free()
	await process_frame
```

- [ ] **Step 3: 跑全量测试**

Run: `cd /Users/yanrui/Desktop/iron-throne-tactics && ./scripts/test.sh 2>&1 | tail -6`
Expected: 全绿，套件数 = 41（序章）+ 3（act结构/迷雾/A1C1）= 44（或视合并）。`TEST_RUN_COMPLETE suites=N`，0 失败。

- [ ] **Step 4: 更新 handoff**

在 `AGENT_HANDOFF_2026-07-23.md` 末尾加一节"第一幕第一章（已实现）"，记录 A1C1 可玩、迷雾系统、act 结构。提交。

```bash
git add tests/run_tests.gd AGENT_HANDOFF_2026-07-23.md
git commit -m "test: A1C1 章节流程与地图规范回归；更新 handoff

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review（已执行）

**Spec coverage：**
- act 幕结构 → Task 1 ✓
- 迷雾方案 C（视野/敌军显隐/单向/fog_enabled）→ Task 2+3 ✓
- 地图/敌我/胜负（詹姆 min_hp=1 生擒）→ Task 6 ✓
- 资产（单位 json、精灵做、立绘占位）→ Task 4 ✓
- 简报/对话/过场 → Task 5 ✓
- 章节接入（Opening 分发）→ Task 7 ✓
- 测试（act结构/迷雾/章节流程/地图规范）→ Task 1/2/3/6/8 ✓

**Placeholder scan：** 无 TBD/TODO；Task 6/7 含"对照实际签名调整"的指引属实现期必要的现场核对（因 GDScript 私有方法可见性需运行时确认），非占位。

**Type consistency：** `fog_enabled`/`_fog`/`_recalc_fog`/`_filter_enemies_by_fog` 在 Task 2/3/6 一致；`_robb_unit`/`_jaime_unit`/`_capture_triggered`/`_setup_act1_ch1` 在 Task 6/8 一致；`set_prologue`/`set_act`/`global_chapter_id`/`load_progress`/`get_completed_ids`/`save_chapter_complete(act,chapter)` 在 Task 1/5/6/7 一致。
