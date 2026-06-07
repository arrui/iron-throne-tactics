# BattleBootstrap.gd
# 序章·一《风暴地》初始化
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"
const PRE_DIALOGUE_PATH  := "res://data/dialogues/prologue_1_pre.json"
const POST_DIALOGUE_PATH := "res://data/dialogues/prologue_1_post.json"

const UNIT_SPRITE_MAP := {
	"ned_stark.json":        "ned_stark_map.png",
	"robert_baratheon.json": "robert_baratheon_map.png",
	"howland_reed.json":     "howland_reed_map.png",
	"royal_soldier.json":    "royal_soldier_map.png",
}

# 地形类型：0=平原 1=森林 2=矮墙 3=峭壁
# 序章·一《风暴地》地图设计：
#   - 边界全为峭壁
#   - 左侧两列各有一段森林（掩护出发位置）
#   - 中段有矮墙横列（战术要点）
#   - 右侧有森林包围营地
const TERRAIN_MAP: Array = [
# x: 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], # y=0
	[3, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3], # y=1
	[3, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 3], # y=2
	[3, 0, 1, 0, 0, 2, 2, 2, 0, 0, 0, 1, 1, 0, 3], # y=3
	[3, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 1, 0, 0, 3], # y=4 ← 胜利格(13,4)
	[3, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 1, 0, 0, 3], # y=5
	[3, 0, 1, 0, 0, 2, 2, 2, 0, 0, 0, 1, 1, 0, 3], # y=6
	[3, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 3], # y=7
	[3, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3], # y=8
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], # y=9
]

var _dialogue_box: CanvasLayer    = null
var _dialogue_sys: DialogueSystem = null

# Toen图块集Atlas坐标映射（列,行）→ 对应地形类型
# 图集7列×52行，每格16×16像素
# 0=平原 1=森林 2=矮墙 3=峭壁
const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),   # 平原：草地（第0列第0行）
	1: Vector2i(2, 4),   # 森林：树木（第2列第4行）
	2: Vector2i(1, 20),  # 矮墙：石墙（第1列第20行）
	3: Vector2i(0, 12),  # 峭壁：深灰石（第0列第12行）
}

func _ready() -> void:
	super._ready()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	queue_redraw()
	await _play_dialogue(PRE_DIALOGUE_PATH)
	battle_won.connect(_on_battle_won_for_dialogue, CONNECT_ONE_SHOT)

# ── 用代码填充TileMapLayer ──────────────────────────────
func _paint_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null:
		push_error("找不到TileMapLayer节点")
		return
	tilemap.clear()
	for y in TERRAIN_MAP.size():
		var row: Array = TERRAIN_MAP[y]
		for x in row.size():
			var t: int = int(row[x])
			var coords: Vector2i = TILE_ATLAS_COORDS.get(t, Vector2i(0, 0))
			tilemap.set_cell(Vector2i(x, y), 0, coords)

# ── 地形数据接口（供BattleMap.get_terrain_bonus调用）──
func _get_terrain_type(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= TERRAIN_MAP.size(): return 3
	var row: Array = TERRAIN_MAP[pos.y]
	if pos.x < 0 or pos.x >= row.size(): return 3
	return int(row[pos.x])

# 覆盖 is_passable，矮墙可通行但有防御加成，峭壁不可通行
func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	var t: int = _get_terrain_type(pos)
	return t != 3  # 只有峭壁不可通行

# ── 对话播放 ────────────────────────────────────────────
func _play_dialogue(path: String) -> void:
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		add_child(_dialogue_box)
		await get_tree().process_frame
		_dialogue_sys = _dialogue_box as DialogueSystem
	set_process_input(false)
	_dialogue_sys.play(path)
	await _dialogue_sys.dialogue_finished
	set_process_input(true)

func _on_battle_won_for_dialogue() -> void:
	if _result_panel != null:
		_result_panel.visible = false
	await _play_dialogue(POST_DIALOGUE_PATH)
	if _result_panel != null:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		_result_panel.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.5 - 80)
		_result_panel.visible  = true

# ── 单位生成 ────────────────────────────────────────────
func _spawn_player_units() -> void:
	_make_unit("ned_stark.json",        0, Vector2i(1, 4))
	_make_unit("robert_baratheon.json", 0, Vector2i(1, 5))
	_make_unit("howland_reed.json",     0, Vector2i(1, 6))

func _spawn_enemy_units() -> void:
	_make_unit("royal_soldier.json", 1, Vector2i(12, 3))
	_make_unit("royal_soldier.json", 1, Vector2i(13, 4))
	_make_unit("royal_soldier.json", 1, Vector2i(13, 5))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 6))
	_make_unit("royal_soldier.json", 1, Vector2i(11, 5))

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	var file := FileAccess.open(DATA_PATH + filename, FileAccess.READ)
	if file == null:
		push_error("找不到：" + DATA_PATH + filename)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("JSON解析失败：" + filename)
		return
	file.close()

	var unit: Node2D = UNIT_SCENE.instantiate()
	unit.setup(UnitData.from_dict(json.data), team, pos)

	var sprite_file: String = UNIT_SPRITE_MAP.get(filename, "")
	if sprite_file != "":
		var tex := load(SPRITE_PATH + sprite_file)
		if tex != null:
			var sprite: Sprite2D = unit.get_node("Sprite")
			sprite.texture        = tex
			sprite.region_enabled = true
			sprite.region_rect    = Rect2(0, 0, 16, 16)

	add_unit(unit)
