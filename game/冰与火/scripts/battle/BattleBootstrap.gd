# BattleBootstrap.gd — 序章·一《风暴地》（22×16）
# 通关后：存档 → 过渡至序章·二
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

const UNIT_PORTRAIT_MAP := {
	"ned_stark.json":        "ned_stark_portrait.png",
	"robert_baratheon.json": "robert_baratheon_portrait.png",
	"howland_reed.json":     "howland_reed_portrait.png",
	"royal_soldier.json":    "royal_soldier_portrait.png",
}

# ── 地形图：22列 × 16行 ───────────────────────────────────
# 0=平原  1=森林  2=矮墙  3=峭壁  4=河流  5=沼泽  6=桥梁
#
#  地图概览：
#  - 左侧（玩家出发区）：平原 + 部分森林/沼泽
#  - 中央：河流（第9-10列）将地图一分为二，两座桥（第5行、第10行）
#  - 右侧（敌方区域）：矮墙构成的阵地，东北/东南各有一处筑垒
#  - 胜利位置：(17,8) 敌方指挥营地（在矮墙围成的阵地内侧）
#
# 列: 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21
const TERRAIN_MAP: Array = [
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], # y=0  (全峭壁)
	[3, 0, 0, 1, 1, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 3], # y=1
	[3, 0, 1, 1, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 3], # y=2
	[3, 0, 1, 0, 0, 2, 0, 0, 0, 4, 4, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 3], # y=3
	[3, 0, 0, 0, 2, 0, 0, 2, 0, 4, 4, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 3], # y=4
	[3, 0, 0, 0, 2, 0, 0, 6, 6, 6, 6, 6, 2, 0, 0, 2, 0, 0, 0, 0, 0, 3], # y=5  ← 北桥
	[3, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3], # y=6
	[3, 0, 5, 5, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 3], # y=7
	[3, 0, 5, 0, 0, 1, 0, 0, 0, 4, 4, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 3], # y=8  ← 胜利位(17,8)
	[3, 0, 0, 0, 1, 1, 0, 0, 0, 4, 4, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 3], # y=9
	[3, 0, 0, 0, 1, 0, 0, 6, 6, 6, 6, 6, 0, 0, 0, 2, 0, 0, 0, 0, 0, 3], # y=10 ← 南桥
	[3, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 3], # y=11
	[3, 0, 0, 1, 0, 0, 2, 0, 0, 4, 4, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 3], # y=12
	[3, 0, 1, 1, 0, 0, 2, 0, 0, 4, 4, 0, 0, 2, 0, 0, 0, 0, 0, 1, 0, 3], # y=13
	[3, 0, 0, 1, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 3], # y=14
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3], # y=15 (全峭壁)
]

# Atlas 坐标映射（列,行）→ 对应地形类型
# 图集 7列×52行，每格 16×16 像素
const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),   # 平原：草地
	1: Vector2i(2, 4),   # 森林：树木
	2: Vector2i(1, 20),  # 矮墙：石墙
	3: Vector2i(0, 12),  # 峭壁：深灰石
	4: Vector2i(0, 8),   # 河流：蓝色水面（需根据实际图集调整）
	5: Vector2i(1, 9),   # 沼泽：暗绿泥地（需根据实际图集调整）
	6: Vector2i(3, 2),   # 桥梁：石桥板（需根据实际图集调整）
}

var _dialogue_box: CanvasLayer    = null
var _dialogue_sys: DialogueSystem = null

func _ready() -> void:
	super._ready()
	_paint_tilemap()
	_spawn_player_units()
	_spawn_enemy_units()
	queue_redraw()
	await _play_dialogue(PRE_DIALOGUE_PATH)
	battle_won.connect(_on_battle_won_for_dialogue, CONNECT_ONE_SHOT)

# ── 填充 TileMapLayer ──────────────────────────────────────
func _paint_tilemap() -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null:
		push_error("BattleBootstrap: 找不到TileMapLayer节点")
		return
	tilemap.clear()
	for y in TERRAIN_MAP.size():
		var row: Array = TERRAIN_MAP[y]
		for x in row.size():
			var t: int = int(row[x])
			var coords: Vector2i = TILE_ATLAS_COORDS.get(t, Vector2i(0, 0))
			tilemap.set_cell(Vector2i(x, y), 0, coords)

# ── 地形数据接口 ─────────────────────────────────────────
func _get_terrain_type(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= TERRAIN_MAP.size(): return TERRAIN_CLIFF
	var row: Array = TERRAIN_MAP[pos.y]
	if pos.x < 0 or pos.x >= row.size(): return TERRAIN_CLIFF
	return int(row[pos.x])

# 覆盖可通行判断：河流(4)和峭壁(3)不可通行，其余可通
func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	var t: int = _get_terrain_type(pos)
	return t != TERRAIN_CLIFF and t != TERRAIN_RIVER

# ── 对话播放 ─────────────────────────────────────────────
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
	await _advance_chapter()

# 序章·一通关 → 存档 → 进入序章·二
func _advance_chapter() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		var ss := load(SAVE_SYS_PATH)
		ss.save_chapter_complete(1)

	const CH2_SCENE := "res://scenes/chapter/Ch2_Opening.tscn"
	if ResourceLoader.exists(CH2_SCENE):
		get_tree().change_scene_to_file(CH2_SCENE)
	else:
		# 场景尚未创建时的回退——显示结果面板
		if _result_panel != null:
			var vs: Vector2 = get_viewport().get_visible_rect().size
			_result_panel.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.5 - 80)
			_result_panel.visible  = true

# ── 单位生成 ─────────────────────────────────────────────
func _spawn_player_units() -> void:
	_make_unit("ned_stark.json",        0, Vector2i(1, 7))
	_make_unit("robert_baratheon.json", 0, Vector2i(1, 8))
	_make_unit("howland_reed.json",     0, Vector2i(1, 9))

func _spawn_enemy_units() -> void:
	# 左侧浅渡位守卫（玩家过桥前会遭遇）
	_make_unit("royal_soldier.json", 1, Vector2i(13, 4))
	_make_unit("royal_soldier.json", 1, Vector2i(11, 6))
	# 右侧中央守备
	_make_unit("royal_soldier.json", 1, Vector2i(13, 7))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 11))
	# 内侧阵地（目标区域）
	_make_unit("royal_soldier.json", 1, Vector2i(16, 9))
	_make_unit("royal_soldier.json", 1, Vector2i(17, 7))  # 营地守卫（靠近胜利点）

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	var file := FileAccess.open(DATA_PATH + filename, FileAccess.READ)
	if file == null:
		push_error("BattleBootstrap: 找不到：" + DATA_PATH + filename)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("BattleBootstrap: JSON解析失败：" + filename)
		return
	file.close()

	var unit: Node2D = UNIT_SCENE.instantiate()
	unit.setup(UnitData.from_dict(json.data), team, pos)

	# 加载地图行走图（32×32）
	var sprite_file: String = UNIT_SPRITE_MAP.get(filename, "")
	if sprite_file != "":
		var tex := load(SPRITE_PATH + sprite_file)
		if tex != null:
			var sprite: Sprite2D = unit.get_node("Sprite")
			sprite.texture        = tex
			sprite.region_enabled = true
			sprite.region_rect    = Rect2(0, 0, 32, 32)

	# 存储立绘路径供战斗动画使用
	var portrait_file: String = UNIT_PORTRAIT_MAP.get(filename, "")
	if portrait_file != "":
		var portrait_path: String = SPRITE_PATH + portrait_file
		if ResourceLoader.exists(portrait_path):
			unit.set_meta("portrait_path", portrait_path)

	add_unit(unit)
