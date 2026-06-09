# Unit.gd — 单位节点（支持武器耐久、道具、Boss底板、主角死亡Game Over）
class_name Unit
extends Node2D

signal unit_died(unit)

enum Team  { PLAYER, ENEMY, NEUTRAL }
enum State { IDLE, MOVED, ACTED, DONE }

var data:     UnitData
var team:     int = Team.PLAYER
var state:    int = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO

# weapon_key 是计算属性，自动处理武器破损回退
var weapon_key: String:
	get: return data.get_weapon_key() if data != null else "sword_E"

var _pending_death: bool = false

func setup(unit_data: UnitData, unit_team: int, pos: Vector2i) -> void:
	data     = unit_data
	team     = unit_team
	grid_pos = pos

# ── 伤害（尊重 min_hp 底板）────────────────────────────────
func take_damage(amount: int) -> void:
	var floor_hp: int = maxi(data.min_hp, 0)
	data.hp = maxi(data.hp - amount, floor_hp)
	_refresh_hp_label()
	if data.hp == 0:
		_pending_death = true

func resolve_death() -> void:
	if _pending_death:
		unit_died.emit(self)

func is_dead() -> bool:
	return data.hp <= 0

# ── 状态机 ─────────────────────────────────────────────────
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
	if lbl: lbl.text = str(data.hp)
