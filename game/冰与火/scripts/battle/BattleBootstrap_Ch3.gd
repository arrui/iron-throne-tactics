# BattleBootstrap_Ch3.gd — 序章·三《极乐塔》（24×18）
# 胜利条件：奈德抵达塔楼入口（非歼灭）
# 特殊机制：亚瑟·戴恩无敌（min_hp=1）；到达触发霍兰刺杀剧情；莱安娜结局过场
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const CUTSCENE_SCENE     := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"

const PRE_DIALOGUE_PATH  := "res://data/dialogues/ch3_pre.json"
const POST_DIALOGUE_PATH := "res://data/dialogues/ch3_post.json"

const UNIT_SPRITE_MAP := {
	"ned_stark.json":       "ned_stark_map.png",
	"howland_reed.json":    "howland_reed_map.png",
	"arthur_dayne.json":    "arthur_dayne_map.png",
	"dorne_knight.json":    "dorne_knight_map.png",
	"northern_knight.json": "northern_knight_map.png",
	"royal_soldier.json":   "royal_soldier_map.png",
}

# 0=平原 1=植被/绿洲 2=礁岩（矮墙） 3=峭壁/不可通行 5=沙丘（沼泽机制）
const TERRAIN_MAP: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=0
	[3,0,0,5,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=1
	[3,0,5,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=2
	[3,0,0,5,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=3
	[3,0,0,0,2,0,0,2,0,0,0,0,0,0,0,0,0,0,2,2,0,0,0,3],  # y=4
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,2,0,0,3],  # y=5 塔外墙北
	[3,0,0,0,0,0,0,0,0,0,5,5,0,0,0,0,0,2,0,0,2,0,0,3],  # y=6
	[3,0,0,5,0,0,0,0,0,5,0,0,0,0,0,0,2,0,0,0,0,2,0,3],  # y=7
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,2,3],  # y=8
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=9 ← (19,9) 胜利塔门
	[3,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,2,0,3],  # y=10
	[3,0,0,0,5,5,0,0,0,0,0,0,0,0,0,0,2,0,0,0,2,0,0,3],  # y=11
	[3,0,2,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,3],  # y=12
	[3,0,2,0,0,0,0,0,0,0,5,5,0,0,0,2,0,0,0,0,0,0,0,3],  # y=13
	[3,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=14
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=15
	[3,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=16
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=17
]

const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),   # 平原：亮绿草地
	1: Vector2i(6, 0),   # 森林：深绿树木（有树形纹理）
	2: Vector2i(0, 2),   # 矮墙：浅石墙
	3: Vector2i(1, 50),  # 峭壁：极暗色（不可通行）
	4: Vector2i(0, 13),  # 河流：淡蓝水色
	5: Vector2i(1, 19),   # 沼泽：灰绿色（沼泽草地，区别于棕褐色桥梁）
	6: Vector2i(4, 2),    # 桥梁：浅蓝灰色（石桥跨河，区别于蓝色河流和绿色沼泽）
}

var _dialogue_box:   CanvasLayer    = null
var _dialogue_sys:   DialogueSystem = null
var _cutscene_node:  CutscenePlayer = null
var _dayne_unit:     Unit = null
var _tower_reached:  bool = false

# 背叛系统：黄金披风城卫（初始友军，第5回合变敌）
var _golden_cloak_units: Array = []
var _betrayal_triggered: bool  = false

func _ready() -> void:
	map_width   = 24
	map_height  = 18
	victory_pos = Vector2i(19, 9)  # 塔楼入口
	if is_instance_valid(_cam):
		_cam.limit_right  = map_width  * TILE_SIZE
		_cam.limit_bottom = map_height * TILE_SIZE
		_cam.position     = Vector2(640, 360)
	super._ready()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	_redraw_all()
	await _play_dialogue(PRE_DIALOGUE_PATH)

# ── 地形 ─────────────────────────────────────────────────
func _paint_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null: return
	tilemap.clear()
	for y: int in TERRAIN_MAP.size():
		var row: Array = TERRAIN_MAP[y]
		for x: int in row.size():
			tilemap.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS.get(int(row[x]), Vector2i(0,0)))

func _get_terrain_type(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= TERRAIN_MAP.size(): return TERRAIN_CLIFF
	var row: Array = TERRAIN_MAP[pos.y]
	if pos.x < 0 or pos.x >= row.size(): return TERRAIN_CLIFF
	return int(row[pos.x])

func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height: return false
	var t: int = _get_terrain_type(pos)
	return t != TERRAIN_CLIFF and t != TERRAIN_RIVER

# ── 胜利条件（奈德抵达塔门）─────────────────────────────
func _check_victory() -> void:
	if _battle_over or _tower_reached: return
	for u: Unit in player_units:
		if is_instance_valid(u) and not u.is_dead() and \
				u.data.name == "奈德" and u.grid_pos == victory_pos:
			_tower_reached = true
			_trigger_tower_sequence()
			return
	# 如果所有敌军都被歼灭（排除无敌）也算胜利
	var mortal := enemy_units.filter(func(e: Unit) -> bool:
		return not e.is_dead() and e.data.min_hp == 0)
	if mortal.is_empty() and not enemy_units.is_empty():
		_tower_reached = true
		_trigger_tower_sequence()

func _trigger_tower_sequence() -> void:
	_battle_over = true
	_hide_all_panels()
	# 霍兰刺杀戴恩过场
	await _play_cutscene("res://data/cutscenes/ch3_dayne_trigger.json")
	# 手动移除戴恩（霍兰的侧翼行动，非玩家操作）
	if is_instance_valid(_dayne_unit):
		enemy_units.erase(_dayne_unit)
		_dayne_unit.queue_free()
		_redraw_all()
	# 莱安娜结局过场
	await _play_cutscene("res://data/cutscenes/ch3_lyanna.json")
	# 战后对话
	await _play_dialogue(POST_DIALOGUE_PATH)
	# 进入第四章
	await _advance_chapter()

func _advance_chapter() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).save_chapter_complete(3)
	const CH4_SCENE := "res://scenes/chapter/Ch4_Opening.tscn"
	if ResourceLoader.exists(CH4_SCENE):
		get_tree().change_scene_to_file(CH4_SCENE)

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
	_make_unit("ned_stark.json",       0, Vector2i(1, 9))
	_make_unit("howland_reed.json",    0, Vector2i(1, 10))
	_make_unit("northern_knight.json", 0, Vector2i(1, 8))
	_make_unit("northern_knight.json", 0, Vector2i(2, 11))
	_make_unit("northern_knight.json", 0, Vector2i(2, 7))
	# 黄金披风城卫（初始友军，第5回合背叛）
	var cloak_positions := [Vector2i(8, 5), Vector2i(10, 5), Vector2i(8, 8), Vector2i(10, 8)]
	for pos: Vector2i in cloak_positions:
		var u := _make_unit_ret("royal_soldier.json", 0, pos)
		if u != null:
			_golden_cloak_units.append(u)

func _spawn_enemy_units() -> void:
	var dayne := _make_unit_ret("arthur_dayne.json", 1, Vector2i(17, 9))
	_dayne_unit = dayne
	_make_unit("dorne_knight.json", 1, Vector2i(13, 5))
	_make_unit("dorne_knight.json", 1, Vector2i(13, 11))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 7))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 9))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 13))

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	_make_unit_ret(filename, team, pos)

func _make_unit_ret(filename: String, team: int, pos: Vector2i) -> Unit:
	var path: String = DATA_PATH + filename
	if not FileAccess.file_exists(path):
		push_error("BattleBootstrap_Ch3: 找不到 " + path)
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

# ── 背叛系统：第5回合城卫军倒戈 ────────────────────────────
func _start_player_turn() -> void:
	super._start_player_turn()
	if _turn_count == 5 and not _betrayal_triggered:
		_betrayal_triggered = true
		await _trigger_betrayal()

func _trigger_betrayal() -> void:
	# 1. 播放背叛对话
	await _play_dialogue("res://data/dialogues/ch3_betrayal.json")

	# 2. 状态提示
	_set_status("⚠ 背叛！城卫军倒戈——重新评估战场！")

	# 3. 闪烁动画后变为敌方
	for u: Unit in _golden_cloak_units.duplicate():
		if not is_instance_valid(u) or u.is_dead(): continue
		var sprite := u.get_node_or_null("Sprite") as Sprite2D
		if sprite:
			for _i: int in 3:
				sprite.modulate = Color(1, 0.2, 0.2, 1)
				await get_tree().create_timer(0.2).timeout
				sprite.modulate = Color(1, 1, 1, 1)
				await get_tree().create_timer(0.2).timeout
		# 从友军转为敌方
		player_units.erase(u)
		u.team = 1
		enemy_units.append(u)
		if sprite:
			sprite.modulate = Color(1, 0.4, 0.4, 1)

	_golden_cloak_units.clear()
	_update_danger_zone()
	_redraw_all()
