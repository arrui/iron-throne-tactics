# BattleBootstrap_A1C1.gd — 第一幕第一章《呓语森林之战》（22×16）
# 胜利条件：击溃并生擒詹姆·兰尼斯特（min_hp=1 → HP 触底触发捕获过场）
# 特殊机制：战争迷雾（夜袭，视野受限）；詹姆生擒（非击杀）
#
# 自包含结构（仿 BattleBootstrap_Ch3.gd）：直接继承 BattleMap，重声明所需常量与
# 辅助方法，不依赖序章 BattleBootstrap 的 _paint_from/_make_unit_r 等助手。
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const CUTSCENE_SCENE     := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"

const PRE_DIALOGUE_PATH  := "res://data/dialogues/act1_ch1_pre.json"
const POST_DIALOGUE_PATH := "res://data/dialogues/act1_ch1_post.json"
const CAPTURE_CUTSCENE_PATH := "res://data/cutscenes/act1_ch1_jaime_capture.json"

# A1C1 单位 → 地图精灵。玩家骑士复用 northern_knight 数据/精灵
# （简报中的 north_knight_robb 在数据层即 northern_knight，故直接映射）。
const UNIT_SPRITE_MAP := {
	"robb_stark.json":         "robb_stark_map.png",
	"brynden_tully.json":      "brynden_tully_map.png",
	"northern_knight.json":    "northern_knight_map.png",
	"jaime_lannister.json":    "jaime_lannister_map.png",
	"golden_lion_knight.json": "golden_lion_knight_map.png",
	"lannister_soldier.json":  "lannister_soldier_map.png",
}

# 0=平原 1=森林 3=峭壁(不可通行) 4=河流(不可通行)
# 22×16：南北峭壁封顶/封底，西侧河流（rows 6-12），中部森林为詹姆营地，
# 列 10-11 为贯穿南北的林间通路（罗柏南→詹姆北可达）。
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

# 瓦片图集坐标（与 Ch3 一致，供 _paint_tilemap 使用；场景无 TileLayer 时为空操作）
const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),
	1: Vector2i(6, 0),
	2: Vector2i(0, 2),
	3: Vector2i(1, 50),
	4: Vector2i(0, 13),
	5: Vector2i(1, 19),
	6: Vector2i(4, 2),
}

var _dialogue_box:   CanvasLayer    = null
var _dialogue_sys:   DialogueSystem = null
var _cutscene_node:  CutscenePlayer = null
var _robb_unit:      Unit = null
var _jaime_unit:     Unit = null
var _capture_triggered: bool = false

func _ready() -> void:
	fog_enabled = true
	_setup_act1_ch1()

# 显式 setup 入口（测试子类 override _ready 为空后直接调用本方法）。
func _setup_act1_ch1() -> void:
	fog_enabled = true
	map_width   = 22
	map_height  = 16
	victory_pos = Vector2i(11, 2)  # 詹姆初始位（生擒靠 min_hp 触底，不用抵达胜利）
	if is_instance_valid(_cam):
		_cam.limit_right  = map_width  * TILE_SIZE
		_cam.limit_bottom = map_height * TILE_SIZE
		_cam.position     = Vector2(640, 360)
	super._ready()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	_redraw_all()
	# 迷雾：单位生成后重算首回合视野/危险区（基类 _ready 不会主动调用）
	_recalc_fog()
	_set_status(Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY)
	await _play_dialogue(PRE_DIALOGUE_PATH)

# ── 地形 ─────────────────────────────────────────────────
func _paint_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null:
		return
	tilemap.clear()
	for y: int in TERRAIN_A1C1.size():
		var row: Array = TERRAIN_A1C1[y]
		for x: int in row.size():
			tilemap.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS.get(int(row[x]), Vector2i(0, 0)))

func _get_terrain_type(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= TERRAIN_A1C1.size():
		return TERRAIN_CLIFF
	var row: Array = TERRAIN_A1C1[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return TERRAIN_CLIFF
	return int(row[pos.x])

func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	var t: int = _get_terrain_type(pos)
	return t != TERRAIN_CLIFF and t != TERRAIN_RIVER

# ── 胜利条件（生擒詹姆）──────────────────────────────────
func _check_victory() -> void:
	if _battle_over or _capture_triggered:
		return
	if is_instance_valid(_jaime_unit) and not _jaime_unit.is_dead() \
			and _jaime_unit.data.hp <= _jaime_unit.data.min_hp:
		_capture_triggered = true
		_trigger_jaime_capture()
		return
	# 罗柏死亡 → 基类 _check_defeat 经 is_protagonist 处理 GameOver，此处不重写。

func _trigger_jaime_capture() -> void:
	_battle_over = true
	_deselect()
	await _play_cutscene(CAPTURE_CUTSCENE_PATH)
	await _play_dialogue(POST_DIALOGUE_PATH)
	_advance_to(2)  # 推进到 act1.ch2

# 推进到下一章。act1.ch2 场景尚未实现 → 保存进度后回主菜单（Opening）。
func _advance_to(_next_chapter: int) -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).save_chapter_complete(1, 1)
	GameState.set_act(1, 2)
	const OPENING_SCENE := "res://scenes/Opening.tscn"
	if ResourceLoader.exists(OPENING_SCENE):
		get_tree().change_scene_to_file(OPENING_SCENE)

# ── 辅助：对话/过场 ──────────────────────────────────────
func _play_cutscene(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	if _cutscene_node == null:
		_cutscene_node = CUTSCENE_SCENE.instantiate() as CutscenePlayer
		add_child(_cutscene_node)
	_cutscene_node.play(path)
	await _cutscene_node.cutscene_finished

func _play_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
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
	# 我方：南方林缘（rows 13-14）
	_robb_unit = _make_unit_ret("robb_stark.json", 0, Vector2i(10, 13))
	_make_unit("brynden_tully.json", 0, Vector2i(8, 14))
	_make_unit("northern_knight.json", 0, Vector2i(12, 14))
	_make_unit("northern_knight.json", 0, Vector2i(6, 13))

func _spawn_enemy_units() -> void:
	# 敌方：北方营地（rows 1-5），詹姆为本阵 Boss
	_jaime_unit = _make_unit_ret("jaime_lannister.json", 1, Vector2i(11, 2))
	_make_unit("golden_lion_knight.json", 1, Vector2i(8, 3))
	_make_unit("golden_lion_knight.json", 1, Vector2i(14, 3))
	_make_unit("lannister_soldier.json", 1, Vector2i(6, 5))
	_make_unit("lannister_soldier.json", 1, Vector2i(16, 5))
	_make_unit("lannister_soldier.json", 1, Vector2i(10, 4))

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	_make_unit_ret(filename, team, pos)

func _make_unit_ret(filename: String, team: int, pos: Vector2i) -> Unit:
	var path: String = DATA_PATH + filename
	if not FileAccess.file_exists(path):
		push_error("BattleBootstrap_A1C1: 找不到 " + path)
		return null
	var json := JSON.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or json.parse(file.get_as_text()) != OK:
		return null
	if file:
		file.close()
	var unit: Node2D = UNIT_SCENE.instantiate()
	unit.setup(UnitData.from_dict(json.data), team, pos)
	var sprite_file: String = UNIT_SPRITE_MAP.get(filename, "")
	if sprite_file != "":
		var tex := load(SPRITE_PATH + sprite_file) as Texture2D
		if tex != null:
			var sprite: Sprite2D = unit.get_node("Sprite")
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 32, 32)
	add_unit(unit)
	return unit as Unit
