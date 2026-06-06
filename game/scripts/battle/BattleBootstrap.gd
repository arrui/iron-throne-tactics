# BattleBootstrap.gd
# 序章·一《风暴地》场景初始化
# 挂载到BattleMap.tscn的根节点，_ready()里调用
# 负责从JSON加载单位数据并按初始位置摆放
extends BattleMap

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")

# 单位数据文件路径
const DATA_PATH := "res://data/units/"

func _ready() -> void:
	super._ready()  # 先初始化地图
	_spawn_player_units()
	_spawn_enemy_units()

# ── 我方单位 ────────────────────────────────────────────
func _spawn_player_units() -> void:
	_create_unit("ned_stark.json",      Unit.Team.PLAYER, Vector2i(1, 4))
	_create_unit("robert_baratheon.json", Unit.Team.PLAYER, Vector2i(1, 5))
	_create_unit("howland_reed.json",   Unit.Team.PLAYER, Vector2i(1, 6))

# ── 敌方单位 ────────────────────────────────────────────
func _spawn_enemy_units() -> void:
	_create_unit("royal_soldier.json", Unit.Team.ENEMY, Vector2i(12, 3))
	_create_unit("royal_soldier.json", Unit.Team.ENEMY, Vector2i(13, 4))
	_create_unit("royal_soldier.json", Unit.Team.ENEMY, Vector2i(13, 5))
	_create_unit("royal_soldier.json", Unit.Team.ENEMY, Vector2i(12, 6))
	_create_unit("royal_soldier.json", Unit.Team.ENEMY, Vector2i(13, 4))  # 队长（同数据，后续换）

# ── 工具：从JSON创建单位 ────────────────────────────────
func _create_unit(filename: String, team: Unit.Team, pos: Vector2i) -> void:
	var path := DATA_PATH + filename
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("找不到单位数据：" + path)
		return

	var json   := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		push_error("JSON解析失败：" + path)
		return

	var data := UnitData.from_dict(json.data)
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, team, pos)
	add_unit(unit)
