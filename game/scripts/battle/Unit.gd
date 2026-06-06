# Unit.gd
# 战场上的单位节点，管理状态和行动
class_name Unit
extends Node2D

signal unit_died(unit)
signal action_finished(unit)

enum Team { PLAYER, ENEMY, ALLY }
enum State { IDLE, MOVED, ACTED, DONE }

# 数据
var data: UnitData
var team: Team = Team.PLAYER
var state: State = State.IDLE

# 战场坐标（格坐标，非像素坐标）
var grid_pos: Vector2i = Vector2i.ZERO

# 当前武器键（原型阶段固定）
var weapon_key: String = "sword_E"

func setup(unit_data: UnitData, unit_team: Team, pos: Vector2i) -> void:
	data      = unit_data
	team      = unit_team
	grid_pos  = pos
	weapon_key = unit_data.weapon_type + "_" + unit_data.weapon_rank

# 承受伤害，返回是否死亡
func take_damage(amount: int) -> bool:
	data.hp = maxi(data.hp - amount, 0)
	if data.hp == 0:
		unit_died.emit(self)
		return true
	return false

# 判断当前回合是否还能行动
func can_act() -> bool:
	return state == State.IDLE or state == State.MOVED

# 标记已移动
func mark_moved() -> void:
	if state == State.IDLE:
		state = State.MOVED

# 标记已行动（攻击/等待）
func mark_acted() -> void:
	state = State.DONE
	action_finished.emit(self)

# 新回合重置
func reset_turn() -> void:
	state = State.IDLE
