# BattleMap.gd
# 主战斗场景：回合管理、输入处理、地图渲染、胜败判定
class_name BattleMap
extends Node2D

signal battle_won
signal battle_lost

const TILE_SIZE := 48

enum Phase { PLAYER_TURN, ENEMY_TURN }

var map_width  := 15
var map_height := 10
var victory_pos := Vector2i(13, 4)

var current_phase: Phase = Phase.PLAYER_TURN
var player_units: Array = []
var enemy_units:  Array = []
var selected_unit: Node2D = null
var move_range: Array[Vector2i] = []
var terrain: Array = []

const TERRAIN_COLORS: Dictionary = {
	0: Color(0.35, 0.55, 0.25),
	1: Color(0.15, 0.35, 0.10),
	2: Color(0.55, 0.50, 0.40),
	3: Color(0.20, 0.20, 0.20),
}
const VICTORY_COLOR  := Color(1.0, 0.85, 0.1, 0.6)
const MOVEABLE_COLOR := Color(0.3, 0.6, 1.0, 0.45)
const SELECTED_COLOR := Color(1.0, 1.0, 0.3, 0.55)

var turn_label:   Label = null
var status_label: Label = null

func _ready() -> void:
	turn_label   = get_node_or_null("UI/TurnLabel") as Label
	status_label = get_node_or_null("UI/StatusLabel") as Label
	_init_terrain()
	_update_ui()

func _init_terrain() -> void:
	terrain.resize(map_height)
	for y in map_height:
		terrain[y] = []
		for x in map_width:
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				terrain[y].append(3)
			else:
				terrain[y].append(0)

func get_terrain(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return 3
	return terrain[pos.y][pos.x]

func is_passable(pos: Vector2i) -> bool:
	return get_terrain(pos) != 3

func _draw() -> void:
	for y in map_height:
		for x in map_width:
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, TERRAIN_COLORS[terrain[y][x]])
			draw_rect(rect, Color(0, 0, 0, 0.25), false)
	var vr := Rect2(victory_pos.x * TILE_SIZE, victory_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	draw_rect(vr, VICTORY_COLOR)
	for pos: Vector2i in move_range:
		var mr := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(mr, MOVEABLE_COLOR)
	if selected_unit != null:
		var sr := Rect2(selected_unit.grid_pos.x * TILE_SIZE, selected_unit.grid_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(sr, SELECTED_COLOR)

func add_unit(unit: Node2D) -> void:
	if unit.team == 0:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	get_node("UnitLayer").add_child(unit)
	unit.position = grid_to_pixel(unit.grid_pos)
	unit.unit_died.connect(_on_unit_died)
	var lbl: Label = unit.get_node_or_null("Label") as Label
	if lbl:
		lbl.text = unit.data.name.substr(0, 1)

func grid_to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5, pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func pixel_to_grid(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / TILE_SIZE), int(px.y / TILE_SIZE))

func _input(event: InputEvent) -> void:
	if current_phase != Phase.PLAYER_TURN:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var clicked := pixel_to_grid(get_global_mouse_position())
	if selected_unit == null:
		_try_select(clicked)
	elif clicked in move_range:
		_try_move(selected_unit, clicked)
	else:
		_deselect()

func _try_select(pos: Vector2i) -> void:
	var unit: Node2D = _unit_at(pos, 0)
	if unit != null and unit.can_act():
		selected_unit = unit
		move_range    = _calc_move_range(unit)
		queue_redraw()
		_set_status("%s 已选中（移动力%d）" % [unit.data.name, unit.data.move])

func _deselect() -> void:
	selected_unit = null
	move_range.clear()
	queue_redraw()
	_set_status("")

func _try_move(unit: Node2D, target: Vector2i) -> void:
	unit.grid_pos = target
	unit.position = grid_to_pixel(target)
	unit.mark_moved()
	_deselect()
	var adj: Node2D = _adjacent_enemy(target)
	if adj != null:
		_execute_combat(unit, adj)
	else:
		unit.mark_acted()
		_refresh_unit_color(unit)
		_check_victory()
		_check_all_acted()

func _execute_combat(attacker: Node2D, defender: Node2D) -> void:
	var pred: Dictionary = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key)
	_set_status("⚔ %s vs %s  命中%d%%  伤害%d" % [
		attacker.data.name, defender.data.name, pred["atk_hit"], pred["atk_damage"]])
	if _roll(pred["atk_hit"]):
		defender.take_damage(pred["atk_damage"] * (3 if _roll(pred["atk_crit"]) else 1))
	if defender.data.hp > 0 and _roll(pred["def_hit"]):
		attacker.take_damage(pred["def_damage"] * (3 if _roll(pred["def_crit"]) else 1))
	if defender.data.hp > 0 and pred["atk_double"]:
		if _roll(pred["atk_hit"]):
			defender.take_damage(pred["atk_damage"])
	attacker.mark_acted()
	_refresh_unit_color(attacker)
	_check_victory()
	_check_all_acted()

func _roll(rate: int) -> bool:
	return randi() % 100 < rate

func _refresh_unit_color(unit: Node2D) -> void:
	var s: ColorRect = unit.get_node_or_null("Sprite") as ColorRect
	if s and unit.state == 3:
		s.color = Color(s.color.r * 0.5, s.color.g * 0.5, s.color.b * 0.5, 1.0)

func _restore_unit_color(unit: Node2D) -> void:
	var s: ColorRect = unit.get_node_or_null("Sprite") as ColorRect
	if s:
		s.color = Color(0.2, 0.6, 1.0) if unit.team == 0 else Color(1.0, 0.3, 0.2)

func _check_victory() -> void:
	for u: Node2D in player_units:
		if u.grid_pos == victory_pos and u.data.hp > 0:
			_set_status("🏆 胜利！占领营地！")
			battle_won.emit()

func _check_defeat() -> void:
	var alive: Array = player_units.filter(func(u: Node2D) -> bool: return u.data.hp > 0)
	if alive.is_empty():
		_set_status("💀 全灭，战斗失败。")
		battle_lost.emit()

func _check_all_acted() -> void:
	var can_act: bool = player_units.any(func(u: Node2D) -> bool: return u.data.hp > 0 and u.can_act())
	if not can_act:
		await get_tree().create_timer(0.5).timeout
		_start_enemy_turn()

func _start_enemy_turn() -> void:
	current_phase = Phase.ENEMY_TURN
	_deselect()
	_update_ui()
	for enemy: Node2D in enemy_units:
		if enemy.data.hp <= 0:
			continue
		var action: Dictionary = EnemyAI.decide(enemy, player_units, _calc_move_range(enemy))
		enemy.grid_pos = action["move_to"]
		enemy.position = grid_to_pixel(action["move_to"])
		if action["attack"] != null:
			_execute_combat(enemy, action["attack"])
		await get_tree().create_timer(0.3).timeout
	_start_player_turn()

func _start_player_turn() -> void:
	for u: Node2D in player_units:
		u.reset_turn()
		_restore_unit_color(u)
	current_phase = Phase.PLAYER_TURN
	_update_ui()
	_check_defeat()

func _update_ui() -> void:
	if turn_label:
		turn_label.text = "我方回合" if current_phase == Phase.PLAYER_TURN else "敌方回合"
		turn_label.add_theme_color_override("font_color",
			Color(0.3, 0.7, 1.0) if current_phase == Phase.PLAYER_TURN else Color(1.0, 0.4, 0.3))

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _unit_at(pos: Vector2i, team: int) -> Node2D:
	for u: Node2D in (player_units + enemy_units):
		if u.grid_pos == pos and u.team == team and u.data.hp > 0:
			return u
	return null

func _adjacent_enemy(pos: Vector2i) -> Node2D:
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var u: Node2D = _unit_at(pos + d, 1)
		if u != null:
			return u
	return null

func _calc_move_range(unit: Node2D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [{"pos": unit.grid_pos, "rem": unit.data.move}]
	visited[unit.grid_pos] = true
	while not queue.is_empty():
		var curr: Dictionary = queue.pop_front()
		var pos: Vector2i = curr["pos"]
		var rem: int = curr["rem"]
		result.append(pos)
		if rem == 0:
			continue
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if visited.has(npos) or not is_passable(npos):
				continue
			if _unit_at(npos, 1) != null:
				continue
			visited[npos] = true
			queue.append({"pos": npos, "rem": rem - 1})
	return result

func _on_unit_died(unit: Node2D) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	queue_redraw()
	_check_defeat()
