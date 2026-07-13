extends RefCounted

const Ch4BattleBrief := preload("res://scripts/chapter/Ch4BattleBrief.gd")

const CH1_OBJECTIVE_SUMMARY := "目标：夺回北侧山道缺口，为劳勃后军打开通路。"
const CH1_BATTLE_OBJECTIVE := "夺回北侧山道缺口，为劳勃后军打开通路。"
const CH1_PROGRESS_MIDWAY := "第一段：山道缺口——敌军开始应对北侧缺口，继续向北推进，别被封锁线拖住。"
const CH1_BATTLE_RESOLUTION := "第一段：山道缺口已夺回——后军可以北上，奈德继续前进。"

const CH2_OBJECTIVE_SUMMARY := "目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。"
const CH2_BATTLE_OBJECTIVE := "争夺三桥并稳住两翼，从中桥突破雷加本阵。"
const CH2_PROGRESS_SOUTH_BANK := "第一段：南岸桥头——前方就是三桥战场，中桥最短，两翼负责牵制与分压。"
const CH2_PROGRESS_CENTER_BRIDGE := "第二段：中桥主攻——义军已踏上中桥，稳住两翼，别让主攻轴线断掉。"
const CH2_PROGRESS_NORTH_BANK := "第三段：北岸桥头——你已抢上北岸桥头，继续压向雷加本阵，别被两翼牵住。"
const CH2_BATTLE_RESOLUTION := "第三段：北岸桥头已定——雷加倒下，中桥决战结束，王家防线开始崩溃。"

const CH3_OBJECTIVE_SUMMARY := "目标：让奈德抵达欢乐塔，不必全歼守军。"
const CH3_BATTLE_OBJECTIVE := "让奈德抵达欢乐塔，不必全歼守军。"
const CH3_PROGRESS_SWAMP := "第一段：湿地区——湿地会拖慢推进，两翼绕开泥地，为奈德撕出塔前通路。"
const CH3_PROGRESS_TOWER := "第二段：塔前杀伤区——奈德已逼近欢乐塔，目标是进塔，不是清光所有守军。"
const CH3_BATTLE_RESOLUTION := "第二段：塔前杀伤区已破——奈德已抵达欢乐塔，亚瑟守线被撕开，真相就在塔内。"

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

static func get_progress_steps(chapter: int) -> Array[String]:
	match chapter:
		1:
			return [CH1_PROGRESS_MIDWAY]
		2:
			return [CH2_PROGRESS_SOUTH_BANK, CH2_PROGRESS_CENTER_BRIDGE, CH2_PROGRESS_NORTH_BANK]
		3:
			return [CH3_PROGRESS_SWAMP, CH3_PROGRESS_TOWER]
		4:
			return [
				Ch4BattleBrief.STAGE_1_GUIDANCE,
				Ch4BattleBrief.STAGE_2_GUIDANCE,
				Ch4BattleBrief.STAGE_3_GUIDANCE,
				Ch4BattleBrief.STAGE_4_GUIDANCE,
			]
		_:
			return []

static func get_progress_stage_title(chapter: int, stage_idx: int) -> String:
	var steps := get_progress_steps(chapter)
	if stage_idx < 1 or stage_idx > steps.size():
		return ""
	var step_text := str(steps[stage_idx - 1])
	var parts := step_text.split("——", false, 1)
	return parts[0] if not parts.is_empty() else step_text

static func get_progress_stage_badge(chapter: int, stage_idx: int) -> String:
	var title := get_progress_stage_title(chapter, stage_idx)
	return "" if title == "" else "阶段：%s" % title

static func get_battle_resolution(chapter: int) -> String:
	match chapter:
		1:
			return CH1_BATTLE_RESOLUTION
		2:
			return CH2_BATTLE_RESOLUTION
		3:
			return CH3_BATTLE_RESOLUTION
		4:
			return Ch4BattleBrief.THRONE_SECURED_STATUS
		_:
			return ""
