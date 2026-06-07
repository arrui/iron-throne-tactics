# BattleMap.gd
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
var selected_unit: Unit = null
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
const ATTACK_COLOR   := Color(1.0, 0.3, 0.2, 0.45)

var turn_label:   Label = null
var status_label: Label = null
var _battle_over: bool = false

func _ready() -> void:
	turn_label   = get_node_or_null("UI/TurnLabel") as Label
	status_label = get_node_or_null("UI/StatusLabel") as Label
	_init_terrain()
	_update_ui()

# ── 地形 ────────────────────────────────────────────────
func _init_terrain() -> void:
	terrain.resize(map_height)
	for y in map_height:
		terrain[y] = []
		for x in map_width:
			terrain[y].append(3 if (x == 0 or x == map_width-1 or y == 0 or y == map_height-1) else 0)

func get_terrain(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return 3
	return terrain[pos.y][pos.x]

func is_passable(pos: Vector2i) -> bool:
	return get_terrain(pos) != 3

# ── 渲染 ────────────────────────────────────────────────
func _draw() -> void:
	# 地形
	for y in map_height:
		for x in map_width:
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, TERRAIN_COLORS[terrain[y][x]])
			draw_rect(rect, Color(0, 0, 0, 0.2), false)

	# 胜利格
	draw_rect(Rect2(victory_pos.x * TILE_SIZE, victory_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), VICTORY_COLOR)

	# 可移动范围
	for pos: Vector2i in move_range:
		draw_rect(Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), MOVEABLE_COLOR)

	# 可攻击范围（移动范围相邻的敌方）
	if selected_unit != null:
		for pos: Vector2i in move_range:
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var ep: Vector2i = pos + d
				if _unit_at(ep, 1) != null:
					draw_rect(Rect2(ep.x * TILE_SIZE, ep.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), ATTACK_COLOR)

	# 选中格
	if selected_unit != null:
		draw_rect(Rect2(selected_unit.grid_pos.x * TILE_SIZE, selected_unit.grid_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), SELECTED_COLOR)

# ── 单位管理 ────────────────────────────────────────────
func add_unit(unit: Unit) -> void:
	if unit.team == 0:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	get_node("UnitLayer").add_child(unit)
	unit.position = grid_to_pixel(unit.grid_pos)
	unit.unit_died.connect(_on_unit_died)
	# 首字标签
	var lbl: Label = unit.get_node_or_null("Label") as Label
	if lbl:
		lbl.text = unit.data.name.substr(0, 1)

func grid_to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5, pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func pixel_to_grid(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / TILE_SIZE), int(px.y / TILE_SIZE))

# ── 输入 ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _battle_over or current_phase != Phase.PLAYER_TURN:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var clicked: Vector2i = pixel_to_grid(get_global_mouse_position())
	if selected_unit == null:
		_try_select(clicked)
	elif clicked in move_range:
		_try_move(selected_unit, clicked)
	else:
		# 点了别的我方单位，切换选中
		var other: Unit = _unit_at(clicked, 0)
		if other != null and other.can_act():
			_deselect()
			_try_select(clicked)
		else:
			_deselect()

func _try_select(pos: Vector2i) -> void:
	var unit: Unit = _unit_at(pos, 0)
	if unit != null and unit.can_act():
		selected_unit = unit
		move_range    = _calc_move_range(unit)
		queue_redraw()
		_set_status("%s（HP:%d  移动:%d）— 点击蓝格移动，红框攻击" % [
			unit.data.name, unit.data.hp, unit.data.move])

func _deselect() -> void:
	selected_unit = null
	move_range.clear()
	queue_redraw()
	_set_status("")

func _try_move(unit: Unit, target: Vector2i) -> void:
	# 不能移动到我方单位占据的格子
	if _unit_at(target, 0) != null and _unit_at(target, 0) != unit:
		return
	unit.grid_pos = target
	unit.position = grid_to_pixel(target)
	unit.mark_moved()
	_deselect()

	var adj: Unit = _adjacent_enemy(target)
	if adj != null:
		_execute_combat(unit, adj)
	else:
		unit.mark_acted()
		_refresh_unit_color(unit)
		_check_victory()
		_check_all_acted()

# ── 战斗结算（延迟死亡：全部结算完再清除） ──────────────
func _execute_combat(attacker: Unit, defender: Unit) -> void:
	var pred: Dictionary = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key)

	var log_text: String = "⚔ %s(HP:%d) vs %s(HP:%d)" % [
		attacker.data.name, attacker.data.hp,
		defender.data.name, defender.data.hp]

	# 攻击方出手
	if _roll(pred["atk_hit"]):
		var dmg: int = pred["atk_damage"] * (3 if _roll(pred["atk_crit"]) else 1)
		defender.take_damage(dmg)
		log_text += "  →%d伤" % dmg
	else:
		log_text += "  →未命中"

	# 防御方反击（未死亡才能反击）
	if not defender.is_dead() and _roll(pred["def_hit"]):
		var dmg: int = pred["def_damage"] * (3 if _roll(pred["def_crit"]) else 1)
		attacker.take_damage(dmg)
		log_text += "  ←%d伤" % dmg

	# 攻击方追击（防御方未死且速度差≥5）
	if not defender.is_dead() and pred["atk_double"]:
		if _roll(pred["atk_hit"]):
			var dmg: int = pred["atk_damage"]
			defender.take_damage(dmg)
			log_text += "  →%d追" % dmg

	_set_status(log_text)
	print(log_text)

	# 全部结算完毕，再处理死亡
	attacker.resolve_death()
	defender.resolve_death()

	attacker.mark_acted()
	_refresh_unit_color(attacker)
	queue_redraw()
	_check_victory()
	_check_all_acted()

func _roll(rate: int) -> bool:
	return randi() % 100 < rate

# ── 颜色反馈 ────────────────────────────────────────────
func _refresh_unit_color(unit: Unit) -> void:
	var s: ColorRect = unit.get_node_or_null("Sprite") as ColorRect
	if s and unit.state == Unit.State.DONE:
		s.color = Color(s.color.r * 0.55, s.color.g * 0.55, s.color.b * 0.55, 1.0)

func _restore_unit_color(unit: Unit) -> void:
	var s: ColorRect = unit.get_node_or_null("Sprite") as ColorRect
	if s:
		s.color = Color(0.2, 0.6, 1.0) if unit.team == 0 else Color(1.0, 0.3, 0.2)

# ── 胜败 ────────────────────────────────────────────────
func _check_victory() -> void:
	if _battle_over:
		return
	for u: Unit in player_units:
		if u.grid_pos == victory_pos and not u.is_dead():
			_battle_over = true
			_set_status("🏆 胜利！占领右侧营地！按 R 重新开始。")
			return

func _check_defeat() -> void:
	if _battle_over:
		return
	var alive: Array = player_units.filter(func(u: Unit) -> bool: return not u.is_dead())
	if alive.is_empty():
		_battle_over = true
		_set_status("💀 全灭，战斗失败。按 R 重新开始。")

func _check_all_acted() -> void:
	if _battle_over:
		return
	var can_act: bool = player_units.any(
		func(u: Unit) -> bool: return not u.is_dead() and u.can_act())
	if not can_act:
		await get_tree().create_timer(0.6).timeout
		_start_enemy_turn()

# ── 回合切换 ────────────────────────────────────────────
func _start_enemy_turn() -> void:
	if _battle_over:
		return
	current_phase = Phase.ENEMY_TURN
	_deselect()
	_update_ui()

	for enemy: Unit in enemy_units.duplicate():
		if enemy.is_dead():
			continue
		var action: Dictionary = EnemyAI.decide(enemy, player_units, _calc_move_range(enemy))
		enemy.grid_pos = action["move_to"]
		enemy.position = grid_to_pixel(action["move_to"])
		queue_redraw()
		if action["attack"] != null:
			_execute_combat(enemy, action["attack"] as Unit)
		await get_tree().create_timer(0.35).timeout

	if not _battle_over:
		_start_player_turn()

func _start_player_turn() -> void:
	for u: Unit in player_units:
		if not u.is_dead():
			u.reset_turn()
			_restore_unit_color(u)
	current_phase = Phase.PLAYER_TURN
	_update_ui()
	_check_defeat()
	queue_redraw()

# ── 重新开始 ────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

# ── UI ──────────────────────────────────────────────────
func _update_ui() -> void:
	if turn_label:
		if _battle_over:
			turn_label.text = "战斗结束"
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			turn_label.text = "我方回合" if current_phase == Phase.PLAYER_TURN else "敌方回合"
			turn_label.add_theme_color_override("font_color",
				Color(0.3, 0.7, 1.0) if current_phase == Phase.PLAYER_TURN else Color(1.0, 0.4, 0.3))

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

# ── 工具 ────────────────────────────────────────────────
func _unit_at(pos: Vector2i, team: int) -> Unit:
	for u: Unit in (player_units + enemy_units):
		if u.grid_pos == pos and u.team == team and not u.is_dead():
			return u
	return null

func _adjacent_enemy(pos: Vector2i) -> Unit:
	for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		var u: Unit = _unit_at(pos + d, 1)
		if u != null:
			return u
	return null

func _calc_move_range(unit: Unit) -> Array[Vector2i]:
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
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if visited.has(npos) or not is_passable(npos):
				continue
			if _unit_at(npos, 1) != null:
				continue
			visited[npos] = true
			queue.append({"pos": npos, "rem": rem - 1})
	return result

func _on_unit_died(unit: Unit) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	queue_redraw()
	_check_defeat()
