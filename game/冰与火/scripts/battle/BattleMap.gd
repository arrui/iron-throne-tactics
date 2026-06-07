# BattleMap.gd — 图块版 v3
class_name BattleMap
extends Node2D

signal battle_won
signal battle_lost

const TILE_SIZE := 48

# 战斗动画场景（懒加载）
const BATTLE_ANIM_SCENE := preload("res://scenes/battle/BattleAnimation.tscn")

enum Phase { PLAYER_TURN, ENEMY_TURN }
enum PlayerState { IDLE, UNIT_SELECTED, UNIT_MOVED, PREDICT }

var map_width  := 15
var map_height := 10
var victory_pos := Vector2i(13, 4)

var current_phase: Phase = Phase.PLAYER_TURN
var player_state: PlayerState = PlayerState.IDLE
var player_units: Array = []
var enemy_units:  Array = []

var selected_unit: Unit = null
var target_enemy:  Unit = null
var move_range:    Array[Vector2i] = []
var attack_tiles:  Array[Vector2i] = []
var _battle_over:      bool = false
var _animating_battle: bool = false  # 战斗动画进行中，屏蔽所有输入

# UI 节点引用
var _turn_label:    Label = null
var _status_label:  Label = null
var _action_menu:   PanelContainer = null
var _atk_btn:       Button = null
var _wait_btn:      Button = null
var _predict_panel: PanelContainer = null
var _atk_line:      Label = null
var _def_line:      Label = null
var _double_line:   Label = null
var _confirm_btn:   Button = null
var _cancel_btn:    Button = null
var _result_panel:  PanelContainer = null
var _result_title:  Label = null
var _result_msg:    Label = null
var _restart_btn:   Button = null

# 高亮颜色（绘制在TileMapLayer上方）
const MOVEABLE_COLOR := Color(0.25, 0.55, 1.0, 0.40)
const SELECTED_COLOR := Color(1.0, 1.0, 0.25, 0.55)
const ATTACK_COLOR   := Color(1.0, 0.25, 0.20, 0.45)
const MOVED_COLOR    := Color(0.25, 0.85, 0.55, 0.50)
const VICTORY_COLOR  := Color(1.0, 0.85, 0.1, 0.45)

func _ready() -> void:
	_bind_ui()
	_update_turn_label()

func _bind_ui() -> void:
	_turn_label    = get_node_or_null("UI/TurnLabel")    as Label
	_status_label  = get_node_or_null("UI/StatusLabel")  as Label
	_action_menu   = get_node_or_null("UI/ActionMenu")   as PanelContainer
	_predict_panel = get_node_or_null("UI/PredictPanel") as PanelContainer
	_result_panel  = get_node_or_null("UI/ResultPanel")  as PanelContainer

	if _action_menu:
		_atk_btn  = _action_menu.get_node_or_null("VBox/AttackBtn") as Button
		_wait_btn = _action_menu.get_node_or_null("VBox/WaitBtn")   as Button
		if _atk_btn  and not _atk_btn.pressed.is_connected(_on_attack_pressed):
			_atk_btn.pressed.connect(_on_attack_pressed)
		if _wait_btn and not _wait_btn.pressed.is_connected(_on_wait_pressed):
			_wait_btn.pressed.connect(_on_wait_pressed)

	if _predict_panel:
		_atk_line    = _predict_panel.get_node_or_null("VBox/AtkLine")            as Label
		_def_line    = _predict_panel.get_node_or_null("VBox/DefLine")            as Label
		_double_line = _predict_panel.get_node_or_null("VBox/DoubleLine")         as Label
		_confirm_btn = _predict_panel.get_node_or_null("VBox/Buttons/ConfirmBtn") as Button
		_cancel_btn  = _predict_panel.get_node_or_null("VBox/Buttons/CancelBtn")  as Button
		if _confirm_btn and not _confirm_btn.pressed.is_connected(_on_confirm_attack):
			_confirm_btn.pressed.connect(_on_confirm_attack)
		if _cancel_btn  and not _cancel_btn.pressed.is_connected(_on_cancel_attack):
			_cancel_btn.pressed.connect(_on_cancel_attack)

	if _result_panel:
		_result_title = _result_panel.get_node_or_null("VBox/ResultTitle") as Label
		_result_msg   = _result_panel.get_node_or_null("VBox/ResultMsg")   as Label
		_restart_btn  = _result_panel.get_node_or_null("VBox/RestartBtn")  as Button
		if _restart_btn and not _restart_btn.pressed.is_connected(_restart):
			_restart_btn.pressed.connect(_restart)

# ── 高亮绘制（覆盖在TileMapLayer之上）──────────────────
func _draw() -> void:
	_draw_tile_highlight(victory_pos, VICTORY_COLOR)
	for pos: Vector2i in move_range:
		_draw_tile_highlight(pos, MOVEABLE_COLOR)
	for pos: Vector2i in attack_tiles:
		_draw_tile_highlight(pos, ATTACK_COLOR)
	if player_state == PlayerState.UNIT_MOVED and selected_unit != null:
		_draw_tile_highlight(selected_unit.grid_pos, MOVED_COLOR)
	elif selected_unit != null:
		_draw_tile_highlight(selected_unit.grid_pos, SELECTED_COLOR)

func _draw_tile_highlight(pos: Vector2i, color: Color) -> void:
	var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	draw_rect(rect, color)

# ── 地形可通行判断 ──────────────────────────────────────
func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	if pos.x == 0 or pos.x == map_width - 1 or pos.y == 0 or pos.y == map_height - 1:
		return false
	return true

# ── 地形加成（供BattleCalculator使用）──────────────────
# 返回该格子的 {avoid, defense} 加成
func get_terrain_bonus(pos: Vector2i) -> Dictionary:
	# 子类（BattleBootstrap）通过 terrain_data 字典提供地形信息
	# 默认返回平原（无加成）
	if not has_method("_get_terrain_type"):
		return {"avoid": 0, "defense": 0}
	var t: int = call("_get_terrain_type", pos)
	match t:
		1: return {"avoid": 20, "defense": 10}   # 森林
		2: return {"avoid": 0,  "defense": 20}   # 矮墙
		3: return {"avoid": 0,  "defense": 0}    # 峭壁（不可通行）
		_: return {"avoid": 0,  "defense": 0}    # 平原

# ── 单位管理 ────────────────────────────────────────────
func add_unit(unit: Unit) -> void:
	if unit.team == 0:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	get_node("UnitLayer").add_child(unit)
	unit.position = _g2p(unit.grid_pos)
	unit.unit_died.connect(_on_unit_died)
	var lbl: Label = unit.get_node_or_null("Label") as Label
	if lbl: lbl.text = unit.data.name.substr(0, 1)
	var hp: Label = unit.get_node_or_null("HPLabel") as Label
	if hp: hp.text = str(unit.data.hp)

func _g2p(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5,
				   pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func _p2g(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / TILE_SIZE), int(px.y / TILE_SIZE))

# ── 输入 ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _battle_over or _animating_battle or current_phase != Phase.PLAYER_TURN:
		return
	if _action_menu   and _action_menu.visible:   return
	if _predict_panel and _predict_panel.visible: return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var clicked: Vector2i = _p2g(get_global_mouse_position())

	match player_state:
		PlayerState.IDLE:
			_try_select(clicked)
		PlayerState.UNIT_SELECTED:
			if clicked == selected_unit.grid_pos:
				_deselect()
			elif clicked in move_range:
				_do_move(selected_unit, clicked)
			else:
				var other: Unit = _unit_at(clicked, 0)
				if other != null and other.can_act():
					_deselect(); _try_select(clicked)
				else:
					_deselect()
		PlayerState.UNIT_MOVED:
			if clicked in attack_tiles:
				var enemy: Unit = _unit_at(clicked, 1)
				if enemy != null:
					_open_predict(selected_unit, enemy)

func _try_select(pos: Vector2i) -> void:
	var unit: Unit = _unit_at(pos, 0)
	if unit == null or not unit.can_act():
		return
	selected_unit = unit
	move_range    = _calc_move_range(unit)
	attack_tiles  = _calc_attack_tiles(move_range)
	player_state  = PlayerState.UNIT_SELECTED
	queue_redraw()
	_set_status("%s  HP:%d  移动:%d" % [unit.data.name, unit.data.hp, unit.data.move])

func _deselect() -> void:
	selected_unit = null
	target_enemy  = null
	move_range.clear()
	attack_tiles.clear()
	player_state = PlayerState.IDLE
	_hide_all_panels()
	queue_redraw()
	_set_status("")

func _do_move(unit: Unit, target: Vector2i) -> void:
	if _unit_at(target, 0) != null and _unit_at(target, 0) != unit:
		return
	unit.grid_pos = target
	unit.position = _g2p(target)
	unit.mark_moved()
	attack_tiles  = _adj_enemies(target)
	move_range.clear()
	player_state  = PlayerState.UNIT_MOVED
	queue_redraw()

	if attack_tiles.is_empty():
		_show_action_menu(target, false)
		_set_status("%s 已移动" % unit.data.name)
	else:
		_show_action_menu(target, true)

# ── 行动菜单 ────────────────────────────────────────────
func _show_action_menu(grid_pos: Vector2i, can_attack: bool) -> void:
	if _action_menu == null: return
	_action_menu.position = _g2p(grid_pos) + Vector2(TILE_SIZE * 0.6, -TILE_SIZE * 0.5)
	if _atk_btn: _atk_btn.visible = can_attack
	_action_menu.visible = true

func _on_attack_pressed() -> void:
	_hide_all_panels()
	if attack_tiles.size() == 1:
		var enemy: Unit = _unit_at(attack_tiles[0], 1)
		if enemy != null:
			_open_predict(selected_unit, enemy)
	else:
		player_state = PlayerState.UNIT_MOVED
		_set_status("点击红色格子选择攻击目标")

func _on_wait_pressed() -> void:
	_hide_all_panels()
	selected_unit.mark_acted()
	_refresh_unit_color(selected_unit)
	_deselect()
	_check_all_acted()

# ── 战斗预测弹窗 ────────────────────────────────────────
func _open_predict(attacker: Unit, defender: Unit) -> void:
	target_enemy = defender
	if _predict_panel == null: return

	# 获取防守方地形加成
	var bonus: Dictionary = get_terrain_bonus(defender.grid_pos)
	var pred: Dictionary  = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key,
		bonus.get("avoid", 0))

	if _atk_line:
		var crit_str: String = "  暴击%d%%" % pred["atk_crit"] if pred["atk_crit"] > 0 else ""
		_atk_line.text = "攻：%s  伤害%d  命中%d%%%s" % [
			attacker.data.name, pred["atk_damage"], pred["atk_hit"], crit_str]
	if _def_line:
		var terrain_str: String = ""
		if bonus.get("avoid", 0) > 0:
			terrain_str = "  [地形回避%d%%]" % bonus["avoid"]
		_def_line.text = "防：%s  伤害%d  命中%d%%%s" % [
			defender.data.name, pred["def_damage"], pred["def_hit"], terrain_str]
	if _double_line:
		_double_line.text = "⚡ 可追击！" if pred["atk_double"] else ""

	var vs: Vector2 = get_viewport().get_visible_rect().size
	_predict_panel.position = Vector2(vs.x * 0.5 - 140, vs.y * 0.5 - 90)
	_predict_panel.visible  = true
	player_state = PlayerState.PREDICT

func _on_confirm_attack() -> void:
	_hide_all_panels()
	if selected_unit != null and target_enemy != null:
		await _start_battle_with_animation(selected_unit, target_enemy)
	target_enemy = null

func _on_cancel_attack() -> void:
	_hide_all_panels()
	player_state = PlayerState.UNIT_MOVED
	attack_tiles = _adj_enemies(selected_unit.grid_pos)
	queue_redraw()
	_set_status("已取消，重新选择攻击目标")

func _hide_all_panels() -> void:
	if _action_menu:   _action_menu.visible   = false
	if _predict_panel: _predict_panel.visible = false

# ── 战斗动画 ────────────────────────────────────────────
func _start_battle_with_animation(attacker: Unit, defender: Unit) -> void:
	_animating_battle = true

	var bonus: Dictionary = get_terrain_bonus(defender.grid_pos)
	var pred: Dictionary = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key,
		bonus.get("avoid", 0))

	var anim_node: BattleAnimation = BATTLE_ANIM_SCENE.instantiate() as BattleAnimation
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer:
		ui_layer.add_child(anim_node)
	else:
		add_child(anim_node)

	anim_node.play(attacker, defender, pred)
	var result: Dictionary = await anim_node.animation_finished
	anim_node.queue_free()
	_execute_combat_from_result(attacker, defender, result)
	_animating_battle = false

# ── 战斗结算 ────────────────────────────────────────────
func _execute_combat(attacker: Unit, defender: Unit) -> void:
	var bonus: Dictionary = get_terrain_bonus(defender.grid_pos)
	var pred: Dictionary = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key,
		bonus.get("avoid", 0))

	var log: String = "⚔ %s vs %s" % [attacker.data.name, defender.data.name]

	if _roll(pred["atk_hit"]):
		var dmg: int = pred["atk_damage"] * (3 if _roll(pred["atk_crit"]) else 1)
		defender.take_damage(dmg)
		log += "  →%d伤" % dmg
	else:
		log += "  →未命中"

	if not defender.is_dead() and _roll(pred["def_hit"]):
		var dmg: int = pred["def_damage"] * (3 if _roll(pred["def_crit"]) else 1)
		attacker.take_damage(dmg)
		log += "  ←%d伤" % dmg

	if not defender.is_dead() and pred["atk_double"]:
		if _roll(pred["atk_hit"]):
			defender.take_damage(pred["atk_damage"])
			log += "  →%d追" % pred["atk_damage"]

	print(log)
	_set_status(log)

	attacker.resolve_death()
	defender.resolve_death()
	attacker.mark_acted()
	_refresh_unit_color(attacker)
	_deselect()
	queue_redraw()
	_check_victory()
	_check_all_acted()

func _execute_combat_from_result(attacker: Unit, defender: Unit,
		result: Dictionary) -> void:
	var log: String = "⚔ %s(HP:%d) vs %s(HP:%d)" % [
		attacker.data.name, attacker.data.hp,
		defender.data.name, defender.data.hp]

	if result.get("atk_hit", false):
		var dmg: int = result.get("atk_damage", 0)
		defender.take_damage(dmg)
		log += "  →%d伤" % dmg
	else:
		log += "  →未命中"

	if not defender.is_dead() and result.get("def_hit", false):
		var dmg: int = result.get("def_damage", 0)
		attacker.take_damage(dmg)
		log += "  ←%d伤" % dmg

	if not defender.is_dead() and result.get("atk_double", false):
		var double_dmg: int = result.get("double_damage", 0)
		if double_dmg > 0:
			defender.take_damage(double_dmg)
			log += "  →%d追" % double_dmg

	print(log)
	_set_status(log)

	attacker.resolve_death()
	defender.resolve_death()
	attacker.mark_acted()
	_refresh_unit_color(attacker)
	_deselect()
	target_enemy = null
	queue_redraw()
	_check_victory()
	_check_all_acted()

func _roll(rate: int) -> bool:
	return randi() % 100 < rate

# ── 颜色反馈 ────────────────────────────────────────────
func _refresh_unit_color(unit: Unit) -> void:
	var node := unit.get_node_or_null("Sprite")
	if node and unit.state == Unit.State.DONE:
		node.modulate = Color(0.5, 0.5, 0.5, 1.0)

func _restore_unit_color(unit: Unit) -> void:
	var node := unit.get_node_or_null("Sprite")
	if node:
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)

# ── 胜败 ────────────────────────────────────────────────
func _check_victory() -> void:
	if _battle_over: return
	var alive_enemies := enemy_units.filter(func(u: Unit) -> bool: return not u.is_dead())
	if alive_enemies.is_empty():
		_end_battle(true)
		return
	for u: Unit in player_units:
		if u.grid_pos == victory_pos and not u.is_dead():
			_end_battle(true)
			return

func _check_defeat() -> void:
	if _battle_over: return
	if player_units.filter(func(u: Unit) -> bool: return not u.is_dead()).is_empty():
		_end_battle(false)

func _end_battle(won: bool) -> void:
	_battle_over = true
	_hide_all_panels()
	_update_turn_label()

	if _result_panel == null:
		_set_status("🏆 胜利！按R重新开始。" if won else "💀 失败！按R重新开始。")
		return

	if _result_title:
		_result_title.text = "🏆 胜利！" if won else "💀 失败"
	if _result_msg:
		_result_msg.text = "成功占领营地！" if won else "全灭，战斗失败。"

	var vs: Vector2 = get_viewport().get_visible_rect().size
	_result_panel.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.5 - 80)
	_result_panel.visible  = true

	if won: battle_won.emit()
	else:   battle_lost.emit()

func _restart() -> void:
	get_tree().reload_current_scene()

# ── 回合 ────────────────────────────────────────────────
func _check_all_acted() -> void:
	if _battle_over: return
	if not player_units.any(func(u: Unit) -> bool: return not u.is_dead() and u.can_act()):
		await get_tree().create_timer(0.6).timeout
		_start_enemy_turn()

func _start_enemy_turn() -> void:
	if _battle_over: return
	current_phase = Phase.ENEMY_TURN
	_deselect()
	_update_turn_label()

	for enemy: Unit in enemy_units.duplicate():
		if enemy.is_dead(): continue
		var action: Dictionary = EnemyAI.decide(enemy, player_units, _calc_move_range(enemy))
		enemy.grid_pos = action["move_to"]
		enemy.position = _g2p(action["move_to"])
		queue_redraw()
		if action["attack"] != null:
			await _start_battle_with_animation(enemy, action["attack"] as Unit)
		await get_tree().create_timer(0.2).timeout

	if not _battle_over:
		_start_player_turn()

func _start_player_turn() -> void:
	for u: Unit in player_units:
		if not u.is_dead():
			u.reset_turn()
			_restore_unit_color(u)
	current_phase = Phase.PLAYER_TURN
	_update_turn_label()
	_check_defeat()
	queue_redraw()

func _update_turn_label() -> void:
	if not _turn_label: return
	if _battle_over:
		_turn_label.text = "战斗结束"
		_turn_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		return
	_turn_label.text = "我方回合" if current_phase == Phase.PLAYER_TURN else "敌方回合"
	_turn_label.add_theme_color_override("font_color",
		Color(0.3, 0.7, 1.0) if current_phase == Phase.PLAYER_TURN else Color(1.0, 0.4, 0.3))

func _set_status(msg: String) -> void:
	if _status_label: _status_label.text = msg

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()

# ── 工具 ────────────────────────────────────────────────
func _unit_at(pos: Vector2i, team: int) -> Unit:
	for u: Unit in (player_units + enemy_units):
		if u.grid_pos == pos and u.team == team and not u.is_dead():
			return u
	return null

func _adj_enemies(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		if _unit_at(pos + d, 1) != null:
			result.append(pos + d)
	return result

func _calc_attack_tiles(from_range: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for pos: Vector2i in from_range:
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var np: Vector2i = pos + d
			if seen.has(np): continue
			if _unit_at(np, 1) != null:
				seen[np] = true
				result.append(np)
	return result

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
		if rem == 0: continue
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if visited.has(npos) or not is_passable(npos): continue
			var blocker := _unit_at(npos, 0) if unit.team == 1 else _unit_at(npos, 1)
			if blocker != null: continue
			visited[npos] = true
			queue.append({"pos": npos, "rem": rem - 1})
	return result

func _on_unit_died(unit: Unit) -> void:
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	queue_redraw()
	_check_defeat()
