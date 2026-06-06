# BattleMap.gd
# 主战斗场景控制器：回合管理、输入处理、胜败判定
class_name BattleMap
extends Node2D

signal battle_won
signal battle_lost

const TILE_SIZE := 64  # 每格像素大小

enum Phase { PLAYER_TURN, ENEMY_TURN }

# 地图尺寸（第一章：15×10）
@export var map_width:  int = 15
@export var map_height: int = 10

# 胜利条件：占领目标格
@export var victory_pos: Vector2i = Vector2i(13, 4)

var current_phase: Phase = Phase.PLAYER_TURN
var player_units:  Array[Unit] = []
var enemy_units:   Array[Unit] = []

# 当前选中的单位
var selected_unit: Unit = null
# 可移动格缓存
var move_range: Array[Vector2i] = []

# 地形数据（0=平原 1=森林 2=矮墙 3=峭壁）
var terrain: Array = []

func _ready() -> void:
	_init_terrain()
	_spawn_units()

# ── 地形初始化 ──────────────────────────────────────────
func _init_terrain() -> void:
	# 按设计文档初始化15×10地形
	# 0=平原 1=森林 2=矮墙 3=峭壁（边界）
	terrain.resize(map_height)
	for y in map_height:
		terrain[y] = []
		for x in map_width:
			# 边界全是峭壁
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				terrain[y].append(3)
			else:
				terrain[y].append(0)  # 其余先全部平原，精细布局后续迭代

func get_terrain(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return 3  # 越界视为峭壁
	return terrain[pos.y][pos.x]

func is_passable(pos: Vector2i) -> bool:
	return get_terrain(pos) != 3

# ── 单位生成 ────────────────────────────────────────────
func _spawn_units() -> void:
	# 实际项目从JSON加载；原型阶段直接硬编码
	pass  # 由场景编辑器或外部调用 add_unit() 填充

func add_unit(unit: Unit) -> void:
	if unit.team == Unit.Team.PLAYER:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	add_child(unit)
	unit.position = grid_to_pixel(unit.grid_pos)
	unit.unit_died.connect(_on_unit_died)

# ── 坐标转换 ────────────────────────────────────────────
func grid_to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2,
				   pos.y * TILE_SIZE + TILE_SIZE / 2)

func pixel_to_grid(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / TILE_SIZE), int(px.y / TILE_SIZE))

# ── 输入处理 ────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if current_phase != Phase.PLAYER_TURN:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return

	var clicked := pixel_to_grid(get_global_mouse_position())

	if selected_unit == null:
		_try_select(clicked)
	else:
		if clicked in move_range:
			_try_move(selected_unit, clicked)
		else:
			_deselect()

func _try_select(pos: Vector2i) -> void:
	var unit := _unit_at(pos, Unit.Team.PLAYER)
	if unit != null and unit.can_act():
		selected_unit = unit
		move_range    = _calc_move_range(unit)
		# TODO: 高亮可移动格

func _deselect() -> void:
	selected_unit = null
	move_range    = []
	# TODO: 清除高亮

func _try_move(unit: Unit, target: Vector2i) -> void:
	unit.grid_pos = target
	unit.position = grid_to_pixel(target)
	unit.mark_moved()

	# 检查相邻是否有敌人可攻击
	var adjacent_enemy := _adjacent_enemy(target)
	if adjacent_enemy != null:
		_show_battle_prediction(unit, adjacent_enemy)
	else:
		unit.mark_acted()
		_deselect()
		_check_victory()
		_check_all_acted()

# ── 战斗预测（原型阶段：直接结算，不弹窗）──────────────
func _show_battle_prediction(attacker: Unit, defender: Unit) -> void:
	# TODO: 弹出预测UI；原型阶段直接执行战斗
	_execute_combat(attacker, defender)

func _execute_combat(attacker: Unit, defender: Unit) -> void:
	var prediction := BattleCalculator.predict(
		attacker.data, defender.data,
		attacker.weapon_key, defender.weapon_key
	)

	# 攻击方出手
	if _roll_hit(prediction["atk_hit"]):
		var dmg: int = prediction["atk_damage"]
		if _roll_hit(prediction["atk_crit"]):
			dmg *= 3
		defender.take_damage(dmg)

	# 防御方反击（若存活）
	if defender.data.hp > 0 and _roll_hit(prediction["def_hit"]):
		var dmg: int = prediction["def_damage"]
		if _roll_hit(prediction["def_crit"]):
			dmg *= 3
		attacker.take_damage(dmg)

	# 追击
	if defender.data.hp > 0 and prediction["atk_double"]:
		if _roll_hit(prediction["atk_hit"]):
			defender.take_damage(prediction["atk_damage"])

	attacker.mark_acted()
	_deselect()
	_check_victory()
	_check_all_acted()

func _roll_hit(rate: int) -> bool:
	return randi() % 100 < rate

# ── 胜败判定 ────────────────────────────────────────────
func _check_victory() -> void:
	# 胜利条件：任意玩家单位占据胜利格
	for u in player_units:
		if u.grid_pos == victory_pos and u.data.hp > 0:
			battle_won.emit()
			return

func _check_defeat() -> void:
	var alive := player_units.filter(func(u): return u.data.hp > 0)
	if alive.is_empty():
		battle_lost.emit()

# ── 回合切换 ────────────────────────────────────────────
func _check_all_acted() -> void:
	var can_still_act := player_units.any(
		func(u): return u.data.hp > 0 and u.can_act()
	)
	if not can_still_act:
		_start_enemy_turn()

func _start_enemy_turn() -> void:
	current_phase = Phase.ENEMY_TURN
	_deselect()
	# 逐个执行敌方AI
	for enemy in enemy_units:
		if enemy.data.hp <= 0:
			continue
		var walkable := _calc_move_range(enemy)
		var action   := EnemyAI.decide(enemy, player_units, walkable)
		enemy.grid_pos = action["move_to"]
		enemy.position = grid_to_pixel(action["move_to"])
		if action["attack"] != null:
			_execute_combat(enemy, action["attack"])
	_start_player_turn()

func _start_player_turn() -> void:
	for u in player_units:
		u.reset_turn()
	current_phase = Phase.PLAYER_TURN
	_check_defeat()

# ── 工具函数 ────────────────────────────────────────────
func _unit_at(pos: Vector2i, team: Unit.Team) -> Unit:
	var all := player_units + enemy_units
	for u in all:
		if u.grid_pos == pos and u.team == team and u.data.hp > 0:
			return u
	return null

func _adjacent_enemy(pos: Vector2i) -> Unit:
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var u := _unit_at(pos + d, Unit.Team.ENEMY)
		if u != null:
			return u
	return null

func _calc_move_range(unit: Unit) -> Array[Vector2i]:
	# BFS计算可移动格
	var result: Array[Vector2i] = []
	var visited := {}
	var queue: Array = [{"pos": unit.grid_pos, "remaining": unit.data.move}]
	visited[unit.grid_pos] = true

	while not queue.is_empty():
		var curr  = queue.pop_front()
		var pos:  Vector2i = curr["pos"]
		var rem:  int       = curr["remaining"]
		result.append(pos)

		if rem == 0:
			continue
		var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for d in dirs:
			var npos := pos + d
			if visited.has(npos):
				continue
			if not is_passable(npos):
				continue
			# 不能停在敌方单位上
			if _unit_at(npos, Unit.Team.ENEMY) != null:
				continue
			visited[npos] = true
			queue.append({"pos": npos, "remaining": rem - 1})

	return result

func _on_unit_died(unit: Unit) -> void:
	# 永久死亡：从数组中移除
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	_check_defeat()
