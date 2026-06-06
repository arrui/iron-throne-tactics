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

func setup(unit_data: UnitData, unit_team: int, pos: Vector2i) -> void:
	data      = unit_data
	team      = unit_team
	grid_pos  = pos
	weapon_key = unit_data.weapon_type + "_" + unit_data.weapon_rank

func take_damage(amount: int) -> bool:
	data.hp = maxi(data.hp - amount, 0)
	if data.hp == 0:
		unit_died.emit(self)
		return true
	return false

func can_act() -> bool:
	return state == State.IDLE or state == State.MOVED

func mark_moved() -> void:
	if state == State.IDLE:
		state = State.MOVED

func mark_acted() -> void:
	state = State.DONE

func reset_turn() -> void:
	state = State.IDLE
