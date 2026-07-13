extends RefCounted

const Ch4BattleBrief := preload("res://scripts/chapter/Ch4BattleBrief.gd")

const CH1_OBJECTIVE_SUMMARY := "目标：夺回北侧山道缺口，为劳勃后军打开通路。"
const CH1_BATTLE_OBJECTIVE := "夺回北侧山道缺口，为劳勃后军打开通路。"

const CH2_OBJECTIVE_SUMMARY := "目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。"
const CH2_BATTLE_OBJECTIVE := "争夺三桥并稳住两翼，从中桥突破雷加本阵。"

const CH3_OBJECTIVE_SUMMARY := "目标：让奈德抵达欢乐塔，不必全歼守军。"
const CH3_BATTLE_OBJECTIVE := "让奈德抵达欢乐塔，不必全歼守军。"

const CH4_OBJECTIVE_SUMMARY := Ch4BattleBrief.OBJECTIVE_SUMMARY
const CH4_BATTLE_OBJECTIVE := Ch4BattleBrief.BATTLE_OBJECTIVE

static func get_objective_summary(chapter: int) -> String:
	match chapter:
		1:
			return CH1_OBJECTIVE_SUMMARY
		2:
			return CH2_OBJECTIVE_SUMMARY
		3:
			return CH3_OBJECTIVE_SUMMARY
		4:
			return CH4_OBJECTIVE_SUMMARY
		_:
			return ""

static func get_battle_objective(chapter: int) -> String:
	match chapter:
		1:
			return CH1_BATTLE_OBJECTIVE
		2:
			return CH2_BATTLE_OBJECTIVE
		3:
			return CH3_BATTLE_OBJECTIVE
		4:
			return CH4_BATTLE_OBJECTIVE
		_:
			return ""
