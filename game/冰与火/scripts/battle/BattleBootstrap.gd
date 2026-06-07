# BattleBootstrap.gd
# 序章·一《风暴地》初始化：从JSON加载单位，按位置摆放
extends "res://scripts/battle/BattleMap.gd"

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")
const DATA_PATH  := "res://data/units/"

func _ready() -> void:
	super._ready()
	_spawn_player_units()
	_spawn_enemy_units()
	queue_redraw()

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

	if team == 1:
		var sprite: ColorRect = unit.get_node("Sprite")
		sprite.color = Color(1.0, 0.3, 0.2)

	add_unit(unit)
