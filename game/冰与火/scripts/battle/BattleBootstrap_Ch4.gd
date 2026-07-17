# BattleBootstrap_Ch4.gd — 序章·四《铁王座》（36×26）
# 胜利条件：奈德抵达铁王座大厅（30,12）
# 特殊机制：兰尼斯特中立军 / 王军指挥官阵亡触发兰军归降 / 詹姆过场 / 结局过场
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const CUTSCENE_SCENE     := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"

const PRE_DIALOGUE_PATH  := "res://data/dialogues/ch4_pre.json"
const POST_DIALOGUE_PATH := "res://data/dialogues/ch4_post.json"

const UNIT_SPRITE_MAP := {
	"ned_stark.json":          "ned_stark_map.png",
	"northern_knight.json":    "northern_knight_map.png",
	"lannister_soldier.json":  "lannister_soldier_map.png",
	"royal_guard_captain.json":"royal_guard_captain_map.png",
	"royal_soldier.json":      "royal_soldier_map.png",
}

const TILE_ATLAS_COORDS := {
	# 第四章（铁王座·君临城）: 城市地图，道路是石板而非草地
	0: Vector2i(4, 1),   # 城市道路：灰褐色石板（君临城街道，而非草地）
	1: Vector2i(6, 0),   # 森林：深绿树木（有树形纹理）
	2: Vector2i(0, 2),   # 矮墙/城市建筑：城堡石砖纹理
	3: Vector2i(1, 50),  # 峭壁：极暗色（不可通行）
	4: Vector2i(0, 13),  # 河流：淡蓝水色
	5: Vector2i(1, 19),  # 沼泽：灰绿色（沼泽草地）
	6: Vector2i(4, 2),   # 桥梁：浅蓝灰色（石桥跨河）
}

# 部署选择（由 DeployScreen_Ch4 设置）
# deploy_selection 已移至 GameState.deploy_selection

var _terrain_cache: Array = []
var _dialogue_box:  CanvasLayer    = null
var _dialogue_sys:  DialogueSystem = null
var _cutscene_node: CutscenePlayer = null

var _lannister_units:         Array = []   # 中立兰尼斯特士兵
var _royal_commander:         Unit  = null
var _commander_killed:        bool  = false
var _jaime_scene_triggered:   bool  = false
var _ned_unit:                Unit  = null

# 胜利位置 = 铁王座大厅
const THRONE_TILE  := Vector2i(30, 12)
const JAIME_TILE   := Vector2i(25, 12)  # 进入红堡触发詹姆过场

func _ready() -> void:
	map_width   = 36
	map_height  = 26
	victory_pos = THRONE_TILE
	if is_instance_valid(_cam):
		_cam.limit_right  = map_width  * TILE_SIZE
		_cam.limit_bottom = map_height * TILE_SIZE
		_cam.position     = Vector2(640, 1152)  # 从玩家出生区开始
	super._ready()
	_terrain_cache = _build_map()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	_redraw_all()
	await _play_dialogue(PRE_DIALOGUE_PATH)

# ── 地形生成（程序化君临城街道）───────────────────────────
func _build_map() -> Array:
	const W := 36; const H := 26
	var m: Array = []
	for _y in H:
		var row: Array = []; for _x in W: row.append(0)
		m.append(row)

	# 边界
	for x in W: m[0][x] = 3; m[H-1][x] = 3
	for y in H: m[y][0] = 3; m[y][W-1] = 3

	# 城市街区（3×3 建筑群，每6格一组）
	for by: int in [2, 8, 14, 20]:
		for bx: int in [2, 8, 14, 20]:
			if by + 2 < H - 1 and bx + 2 < W - 1:
				for dy: int in 3:
					for dx: int in 3:
						if dy == 1 and dx == 1: continue  # 空心
						m[by + dy][bx + dx] = 2

	# 红堡外墙（cols 24-34，rows 7-18）
	for x in range(24, 35): m[7][x] = 2; m[18][x] = 2
	for y in range(7, 19): m[y][24] = 2; m[y][34] = 2
	# 西门（主入口）
	m[12][24] = 0

	# 红堡内墙（cols 27-33，rows 9-16）
	for x in range(27, 34): m[9][x] = 2; m[16][x] = 2
	for y in range(9, 17): m[y][27] = 2; m[y][33] = 2
	# 内门
	m[12][27] = 0; m[12][33] = 0

	# 兰尼斯特控制区（北部）加一些矮墙标记区域边界
	for x in range(1, 24): m[5][x] = 2  # 兰军控制区南界
	m[5][6] = 0; m[5][12] = 0; m[5][18] = 0  # 三处关卡通道

	return m

func _paint_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null: return
	tilemap.clear()
	for y: int in _terrain_cache.size():
		var row: Array = _terrain_cache[y]
		for x: int in row.size():
			tilemap.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS.get(int(row[x]), Vector2i(0,0)))

func _get_terrain_type(pos: Vector2i) -> int:
	if _terrain_cache.is_empty(): return 0
	if pos.y < 0 or pos.y >= _terrain_cache.size(): return 3
	var row: Array = _terrain_cache[pos.y]
	if pos.x < 0 or pos.x >= row.size(): return 3
	return int(row[pos.x])

func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height: return false
	return _get_terrain_type(pos) != 3

# ── 胜利条件（奈德抵达铁王座格）────────────────────────────
func _check_victory() -> void:
	if _battle_over: return
	# 奈德抵达铁王座
	if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
			and _ned_unit.grid_pos == THRONE_TILE:
		_trigger_throne_arrival()
		return
	# 或：击败所有非兰军、非无敌敌军
	var has_mortal_enemy := false
	var has_alive_non_lannister := false
	for candidate: Variant in enemy_units:
		if not is_instance_valid(candidate):
			continue
		var enemy := candidate as Unit
		if enemy == null or enemy.is_dead() or _lannister_units.has(enemy):
			continue
		has_alive_non_lannister = true
		if enemy.data.min_hp == 0:
			has_mortal_enemy = true
	if not has_mortal_enemy and not has_alive_non_lannister:
		pass  # 还有非兰军敌人存活，继续

# 詹姆过场触发（奈德接近红堡入口）
func _process(_delta: float) -> void:
	super._process(_delta)
	if _battle_over or _jaime_scene_triggered: return
	if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
			and _ned_unit.grid_pos == JAIME_TILE:
		_jaime_scene_triggered = true
		_trigger_jaime_scene()

# ── 王军指挥官阵亡 → 兰军归降 ──────────────────────────────
func _on_unit_died(unit: Unit) -> void:
	if is_instance_valid(_royal_commander) and unit == _royal_commander \
			and not _commander_killed:
		_commander_killed = true
		super._on_unit_died(unit)
		_trigger_lannister_join()
		return
	super._on_unit_died(unit)

func _trigger_lannister_join() -> void:
	await get_tree().create_timer(0.5).timeout
	# 兰军撤入红堡——从地图移除（叙事：他们"加入"了）
	for u: Unit in _lannister_units.duplicate():
		if is_instance_valid(u) and not u.is_dead():
			enemy_units.erase(u)
			u.queue_free()
	_lannister_units.clear()
	_redraw_all()
	_set_status("兰尼斯特军已归降，道路畅通——")

# ── 詹姆过场 ─────────────────────────────────────────────
func _trigger_jaime_scene() -> void:
	set_process_input(false)
	await _play_dialogue("res://data/dialogues/ch4_jaime.json")
	await _play_cutscene("res://data/cutscenes/ch4_jaime_scene.json")
	set_process_input(true)

# ── 奈德抵达铁王座 → 结局 ────────────────────────────────
func _trigger_throne_arrival() -> void:
	_battle_over = true
	_hide_all_panels()
	if _end_turn_btn: _end_turn_btn.disabled = true
	await _play_dialogue(POST_DIALOGUE_PATH)
	await _play_cutscene("res://data/cutscenes/ch4_ending.json")
	await _advance_chapter()

func _advance_chapter() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).save_chapter_complete(4)
	# 序章全部完成 — 返回主菜单（正篇未实现）
	get_tree().change_scene_to_file("res://scenes/Opening.tscn")

# ── 辅助 ─────────────────────────────────────────────────
func _play_cutscene(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _cutscene_node == null:
		_cutscene_node = CUTSCENE_SCENE.instantiate() as CutscenePlayer
		add_child(_cutscene_node)
	_cutscene_node.play(path)
	await _cutscene_node.cutscene_finished

func _play_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		add_child(_dialogue_box)
		await get_tree().process_frame
		_dialogue_sys = _dialogue_box as DialogueSystem
	_bind_dialogue_camera(_dialogue_sys)
	set_process_input(false)
	_dialogue_sys.play(path)
	await _dialogue_sys.dialogue_finished
	set_process_input(true)

# ── 单位生成 ─────────────────────────────────────────────
func _spawn_player_units() -> void:
	# 使用部署选择，默认奈德 + 2名骑士
	var selection := GameState.deploy_selection.duplicate()
	if selection.is_empty():
		selection = ["ned_stark.json", "northern_knight.json", "northern_knight.json"]

	# 部署位置（南方出发区）
	var spawn_positions: Array = [
		Vector2i(2, 22), Vector2i(3, 22), Vector2i(4, 22),
		Vector2i(2, 23), Vector2i(3, 23), Vector2i(4, 23),
	]
	for i: int in min(selection.size(), spawn_positions.size()):
		var unit := _make_unit_ret(selection[i], 0, spawn_positions[i])
		if unit != null and selection[i] == "ned_stark.json":
			_ned_unit = unit

func _spawn_enemy_units() -> void:
	# 兰尼斯特中立军（北部，移动力0——原地不动直到转化）
	var lann_positions := [
		Vector2i(4, 3), Vector2i(9, 3), Vector2i(15, 3), Vector2i(19, 3)
	]
	for pos: Vector2i in lann_positions:
		var u := _make_unit_ret("lannister_soldier.json", 1, pos)
		if u != null:
			u.data.move = 0  # 中立状态不移动
			_lannister_units.append(u)

	# 王军（街道守卫）
	_make_unit("royal_soldier.json", 1, Vector2i(6, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(6, 16))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 16))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 8))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 16))

	# 王军指挥官（中央）
	var cmd := _make_unit_ret("royal_guard_captain.json", 1, Vector2i(20, 12))
	_royal_commander = cmd

	# 红堡卫兵（已进城才会遇到）
	_make_unit("royal_soldier.json", 1, Vector2i(26, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(26, 14))
	_make_unit("royal_soldier.json", 1, Vector2i(29, 11))

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	_make_unit_ret(filename, team, pos)

func _make_unit_ret(filename: String, team: int, pos: Vector2i) -> Unit:
	var path: String = DATA_PATH + filename
	if not FileAccess.file_exists(path):
		push_error("BattleBootstrap_Ch4: 找不到 " + path)
		return null
	var json := JSON.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or json.parse(file.get_as_text()) != OK: return null
	if file: file.close()
	var unit: Node2D = UNIT_SCENE.instantiate()
	unit.setup(UnitData.from_dict(json.data), team, pos)
	var sprite_file: String = UNIT_SPRITE_MAP.get(filename, "")
	if sprite_file != "":
		var tex := load(SPRITE_PATH + sprite_file) as Texture2D
		if tex != null:
			var sprite: Sprite2D = unit.get_node("Sprite")
			sprite.texture = tex; sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 32, 32)
	add_unit(unit)
	return unit as Unit
