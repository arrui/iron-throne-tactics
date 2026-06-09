# BattleBootstrap_Ch2.gd — 序章·二《三叉戟》（28×20）
# 胜利条件：击败雷加及所有可击败敌军
# 特殊机制：雷加阵亡→全屏过场；巴里斯坦无敌（min_hp=1）；支援教学
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const CUTSCENE_SCENE     := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"

const PRE_DIALOGUE_PATH   := "res://data/dialogues/ch2_pre.json"
const POST_DIALOGUE_PATH  := "res://data/dialogues/ch2_post.json"

const UNIT_SPRITE_MAP := {
	"ned_stark.json":           "ned_stark_map.png",
	"robert_baratheon.json":    "robert_baratheon_map.png",
	"rhaegar_targaryen.json":   "ned_stark_map.png",       # 占位，待专用精灵
	"barristan_selmy.json":     "ned_stark_map.png",
	"rebel_lord.json":          "howland_reed_map.png",
	"targaryen_soldier.json":   "royal_soldier_map.png",
}

# 0=平原 1=森林 2=矮墙 3=峭壁 4=河流 5=沼泽 6=桥梁
const TERRAIN_MAP: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=0
	[3,0,0,1,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,1,1,0,3],  # y=1
	[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,1,0,0,3],  # y=2
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=3
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,2,0,0,0,0,0,0,0,0,0,3],  # y=4
	[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],  # y=5 ← 北桥
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],  # y=6
	[3,0,0,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,0,0,0,3],  # y=7
	[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,1,1,0,0,0,3],  # y=8
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=9
	[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=10 ← 中桥
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=11
	[3,0,0,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,1,0,0,0,0,0,3],  # y=12
	[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # y=13
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,2,0,0,0,0,0,0,0,0,0,3],  # y=14
	[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],  # y=15 ← 南桥
	[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],  # y=16
	[3,0,0,1,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,1,0,0,3],  # y=17
	[3,0,0,0,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,1,1,0,0,0,3],  # y=18
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # y=19
]

const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0), 1: Vector2i(2, 4), 2: Vector2i(1, 20),
	3: Vector2i(0, 12), 4: Vector2i(0, 8), 5: Vector2i(1, 9), 6: Vector2i(3, 2),
}

var _dialogue_box: CanvasLayer    = null
var _dialogue_sys: DialogueSystem = null
var _cutscene_node: CutscenePlayer = null
var _rhaegar_unit: Unit = null
var _rhaegar_death_triggered: bool = false

func _ready() -> void:
	map_width  = 28
	map_height = 20
	victory_pos = Vector2i(20, 9)  # 雷加附近占位，实际胜利用 _check_victory 覆盖
	if is_instance_valid(_cam):
		_cam.limit_right  = map_width  * TILE_SIZE
		_cam.limit_bottom = map_height * TILE_SIZE
		_cam.position     = Vector2(640, 360)
	super._ready()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	queue_redraw()
	await _play_dialogue(PRE_DIALOGUE_PATH)
	battle_won.connect(_on_battle_won_ch2, CONNECT_ONE_SHOT)

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

# ── 胜利条件（排除无敌单位）──────────────────────────────
func _check_victory() -> void:
	if _battle_over: return
	# 只统计可被击杀的敌军
	var mortal := enemy_units.filter(func(u: Unit) -> bool:
		return not u.is_dead() and u.data.min_hp == 0)
	if mortal.is_empty() and not enemy_units.is_empty():
		_end_battle(true)

# ── 雷加阵亡拦截（全屏过场）──────────────────────────────
func _on_unit_died(unit: Unit) -> void:
	if is_instance_valid(_rhaegar_unit) and unit == _rhaegar_unit \
			and not _rhaegar_death_triggered:
		_rhaegar_death_triggered = true
		# 先从敌军列表移除并释放节点
		enemy_units.erase(unit)
		unit.queue_free()
		queue_redraw()
		_play_rhaegar_sequence()
		return
	super._on_unit_died(unit)

func _play_rhaegar_sequence() -> void:
	_battle_over = true   # 暂时标记，防止其他逻辑干扰
	if _cutscene_node == null:
		_cutscene_node = CUTSCENE_SCENE.instantiate() as CutscenePlayer
		add_child(_cutscene_node)
	_cutscene_node.cutscene_finished.connect(_on_rhaegar_cutscene_done, CONNECT_ONE_SHOT)
	_cutscene_node.play("res://data/cutscenes/ch2_rhaegar_fall.json")

func _on_rhaegar_cutscene_done() -> void:
	_battle_over = false  # 恢复，让正常胜利逻辑继续
	_check_victory()

# ── 通关后过场 → 进入第三章 ──────────────────────────────
func _on_battle_won_ch2() -> void:
	if _result_panel != null:
		_result_panel.visible = false
	await _play_cutscene("res://data/cutscenes/ch2_split.json")
	await _play_dialogue(POST_DIALOGUE_PATH)
	await _advance_chapter()

func _advance_chapter() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).save_chapter_complete(2)
	const CH3_SCENE := "res://scenes/chapter/Ch3_Opening.tscn"
	if ResourceLoader.exists(CH3_SCENE):
		get_tree().change_scene_to_file(CH3_SCENE)
	else:
		if _result_panel != null:
			var vs := get_viewport().get_visible_rect().size
			_result_panel.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.5 - 80)
			_result_panel.visible  = true

# ── 辅助：播放过场 ────────────────────────────────────────
func _play_cutscene(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _cutscene_node == null:
		_cutscene_node = CUTSCENE_SCENE.instantiate() as CutscenePlayer
		add_child(_cutscene_node)
	_cutscene_node.play(path)
	await _cutscene_node.cutscene_finished

# ── 对话播放 ─────────────────────────────────────────────
func _play_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		add_child(_dialogue_box)
		await get_tree().process_frame
		_dialogue_sys = _dialogue_box as DialogueSystem
	set_process_input(false)
	_dialogue_sys.play(path)
	await _dialogue_sys.dialogue_finished
	set_process_input(true)

# ── 单位生成 ─────────────────────────────────────────────
func _spawn_player_units() -> void:
	_make_unit("robert_baratheon.json", 0, Vector2i(2, 9))   # 劳勃 — 主攻
	_make_unit("ned_stark.json",        0, Vector2i(2, 5))   # 奈德 — 北翼
	_make_unit("rebel_lord.json",       0, Vector2i(2, 13))  # 义军将领甲
	_make_unit("rebel_lord.json",       0, Vector2i(3, 10))  # 义军将领乙

func _spawn_enemy_units() -> void:
	var rhaegar := _make_unit_ret("rhaegar_targaryen.json", 1, Vector2i(20, 9))
	_rhaegar_unit = rhaegar
	_make_unit("barristan_selmy.json",   1, Vector2i(17, 5))
	_make_unit("targaryen_soldier.json", 1, Vector2i(14, 4))
	_make_unit("targaryen_soldier.json", 1, Vector2i(14, 8))
	_make_unit("targaryen_soldier.json", 1, Vector2i(14, 14))
	_make_unit("targaryen_soldier.json", 1, Vector2i(18, 4))
	_make_unit("targaryen_soldier.json", 1, Vector2i(22, 8))
	_make_unit("targaryen_soldier.json", 1, Vector2i(18, 14))

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	_make_unit_ret(filename, team, pos)

func _make_unit_ret(filename: String, team: int, pos: Vector2i) -> Unit:
	var path: String = DATA_PATH + filename
	if not FileAccess.file_exists(path):
		push_error("BattleBootstrap_Ch2: 找不到 " + path)
		return null
	var json := JSON.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or json.parse(file.get_as_text()) != OK:
		push_error("BattleBootstrap_Ch2: JSON 解析失败 " + filename)
		return null
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
