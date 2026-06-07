# BattleBootstrap.gd
# 序章·一《风暴地》初始化：从JSON加载单位，按位置摆放
# 战斗前后播放对话，通过 dialogue_finished 信号衔接流程
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE        := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"
const PRE_DIALOGUE_PATH  := "res://data/dialogues/prologue_1_pre.json"
const POST_DIALOGUE_PATH := "res://data/dialogues/prologue_1_post.json"

# 角色数据文件 → 地图图标文件的映射
const UNIT_SPRITE_MAP := {
	"ned_stark.json":        "ned_stark_map.png",
	"robert_baratheon.json": "robert_baratheon_map.png",
	"howland_reed.json":     "howland_reed_map.png",
	"royal_soldier.json":    "royal_soldier_map.png",
}

var _dialogue_box: CanvasLayer  = null
var _dialogue_sys: DialogueSystem = null

func _ready() -> void:
	super._ready()
	_spawn_player_units()
	_spawn_enemy_units()
	queue_redraw()

	# 战斗开始前播放序章对话，等待完成后方可操作
	await _play_dialogue(PRE_DIALOGUE_PATH)

	# 监听胜利信号，胜利后播放战后对话再显示结算
	battle_won.connect(_on_battle_won_for_dialogue, CONNECT_ONE_SHOT)

# ── 对话播放 ──────────────────────────────────────────────

## 实例化或复用 DialogueBox，播放指定路径的对话，等待结束
func _play_dialogue(path: String) -> void:
	# 第一次调用时实例化场景
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		add_child(_dialogue_box)
		# 等一帧让@onready变量全部初始化完毕
		await get_tree().process_frame
		_dialogue_sys = _dialogue_box.get_node("DialogueSystem") as DialogueSystem

	# 禁用战斗输入，防止对话期间误操作
	set_process_input(false)

	_dialogue_sys.play(path)
	await _dialogue_sys.dialogue_finished

	# 恢复战斗输入
	set_process_input(true)

# ── 胜利后对话 ────────────────────────────────────────────

func _on_battle_won_for_dialogue() -> void:
	# 隐藏结算面板，等对话结束后再显示
	if _result_panel != null:
		_result_panel.visible = false

	await _play_dialogue(POST_DIALOGUE_PATH)

	# 对话结束，重新显示结算面板
	if _result_panel != null:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		_result_panel.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.5 - 80)
		_result_panel.visible  = true

# ── 单位生成 ──────────────────────────────────────────────

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

	# 加载对应角色的地图图标（spritesheet 48×16，含3帧）
	var sprite_file: String = UNIT_SPRITE_MAP.get(filename, "")
	if sprite_file != "":
		var tex := load(SPRITE_PATH + sprite_file)
		if tex != null:
			var sprite: Sprite2D = unit.get_node("Sprite")
			sprite.texture      = tex
			# 只显示第1帧（直立帧，x=0~15）
			sprite.region_enabled = true
			sprite.region_rect    = Rect2(0, 0, 16, 16)
		else:
			push_error("无法加载图标：" + SPRITE_PATH + sprite_file)

	add_unit(unit)
