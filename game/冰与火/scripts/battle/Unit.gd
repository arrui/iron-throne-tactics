# Unit.gd
class_name Unit
extends Node2D

signal unit_died(unit)

enum Team { PLAYER, ENEMY }
enum State { IDLE, MOVED, ACTED, DONE }

var data: UnitData
var team: int = Team.PLAYER
var state: int = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO
var weapon_key: String = "sword_E"

# 标记：战斗结算中，延迟死亡处理
var _pending_death: bool = false

func setup(unit_data: UnitData, unit_team: int, pos: Vector2i) -> void:
	data       = unit_data
	team       = unit_team
	grid_pos   = pos
	weapon_key = unit_data.weapon_type + "_" + unit_data.weapon_rank

# 返回实际造成的伤害量，不立刻触发死亡信号
func take_damage(amount: int) -> void:
	data.hp = maxi(data.hp - amount, 0)
	# 更新HP显示
	_refresh_hp_label()
	if data.hp == 0:
		_pending_death = true

# 战斗结算完毕后调用，真正触发死亡
func resolve_death() -> void:
	if _pending_death:
		unit_died.emit(self)

func is_dead() -> bool:
	return data.hp <= 0

func can_act() -> bool:
	return state == State.IDLE or state == State.MOVED

func mark_moved() -> void:
	if state == State.IDLE:
		state = State.MOVED

func mark_acted() -> void:
	state = State.DONE

func undo_move() -> void:
	if state == State.MOVED:
		state = State.IDLE

func reset_turn() -> void:
	state = State.IDLE
	_pending_death = false

func _refresh_hp_label() -> void:
	var lbl: Label = get_node_or_null("HPLabel") as Label
	if lbl:
		lbl.text = str(data.hp)
