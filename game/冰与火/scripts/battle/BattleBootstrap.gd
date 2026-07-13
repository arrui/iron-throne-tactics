# BattleBootstrap.gd — 全章节分发器（序章·一～四）
# 根据 GameState.current_chapter 决定运行哪个章节的地图/单位/事件逻辑
extends "res://scripts/battle/BattleMap.gd"

const PrologueChapterBriefs := preload("res://scripts/chapter/PrologueChapterBriefs.gd")
const Ch4BattleBrief := preload("res://scripts/chapter/Ch4BattleBrief.gd")

const UNIT_SCENE         := preload("res://scenes/battle/Unit.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/dialogue/DialogueBox.tscn")
const CUTSCENE_SCENE     := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const DATA_PATH          := "res://data/units/"
const SPRITE_PATH        := "res://assets/units/"

# ── 单位精灵映射表（所有章节通用）─────────────────────────
const UNIT_SPRITE_MAP := {
	"ned_stark.json":           "ned_stark_map.png",
	"robert_baratheon.json":    "robert_baratheon_map.png",
	"howland_reed.json":        "howland_reed_map.png",
	"royal_soldier.json":       "royal_soldier_map.png",
	"rhaegar_targaryen.json":   "ned_stark_map.png",
	"barristan_selmy.json":     "ned_stark_map.png",
	"rebel_lord.json":          "howland_reed_map.png",
	"targaryen_soldier.json":   "royal_soldier_map.png",
	"arthur_dayne.json":        "ned_stark_map.png",
	"dorne_knight.json":        "royal_soldier_map.png",
	"northern_knight.json":     "howland_reed_map.png",
	"lannister_soldier.json":   "royal_soldier_map.png",
	"royal_guard_captain.json": "royal_soldier_map.png",
}
const UNIT_PORTRAIT_MAP := {
	"arthur_dayne.json":        "arthur_dayne_portrait.png",
	"barristan_selmy.json":     "barristan_selmy_portrait.png",
	"dorne_knight.json":        "dorne_knight_portrait.png",
	"howland_reed.json":        "howland_reed_portrait.png",
	"lannister_soldier.json":   "lannister_soldier_portrait.png",
	"ned_stark.json":           "ned_stark_portrait.png",
	"northern_knight.json":     "northern_knight_portrait.png",
	"rebel_lord.json":          "rebel_lord_portrait.png",
	"rhaegar_targaryen.json":   "rhaegar_targaryen_portrait.png",
	"robert_baratheon.json":    "robert_baratheon_portrait.png",
	"royal_guard_captain.json": "royal_guard_captain_portrait.png",
	"royal_soldier.json":       "royal_soldier_portrait.png",
	"targaryen_soldier.json":   "targaryen_soldier_portrait.png",
}

# ── 共享状态 ──────────────────────────────────────────────
var _dialogue_box:  CanvasLayer    = null
var _dialogue_sys:  DialogueSystem = null
var _cutscene_node: CutscenePlayer = null

# ── 地形图（各章节）──────────────────────────────────────
# 0=平原 1=森林 2=矮墙 3=峭壁 4=河流 5=沼泽 6=桥梁

# 序章一：10×8 山道突破教学关
# 南侧：奈德与霍兰从风暴地山道入口推进
# 中部：碎石道 + 林地掩护 + 破损路障
# 北侧：王军临时封锁线，中央缺口通往山道高地出口
const TERRAIN_CH1: Array = [
	[3, 3, 3, 3, 3, 0, 3, 3, 3, 3],  # row 0：北侧高地出口，中央缺口通往后军
	[3, 3, 3, 2, 0, 0, 0, 2, 3, 3],  # row 1：王军临时封锁线，仅中轴三格可穿过
	[3, 3, 1, 2, 0, 2, 0, 2, 1, 3],  # row 2：山道两侧灌木与木栅，逼出突破路线
	[3, 1, 0, 0, 0, 0, 0, 0, 1, 3],  # row 3：山道口主交战区
	[3, 0, 0, 2, 0, 2, 0, 0, 0, 3],  # row 4：破损路障与前沿掩体
	[3, 0, 1, 0, 0, 0, 0, 1, 0, 3],  # row 5：南侧接敌前的低矮林地
	[3, 0, 0, 0, 0, 0, 0, 0, 0, 3],  # row 6：玩家出生区（南方集结）
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3],  # row 7：底部边界
]

const TERRAIN_CH2: Array = [
	# 28列×20行：北岸王家防线 / 三叉戟三桥 / 南岸义军泥泞集结地
	# 结构目标：南岸散兵集结 → 三桥形成三路压迫 → 中桥为主决战轴 → 北岸王家主阵地
	# 0=平原 1=森林 2=营垒/堤坝 3=峭壁 4=河流 5=泥泞 6=桥梁
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
	[3,0,0,1,1,0,0,2,2,0,0,0,2,2,2,2,0,0,2,2,0,0,0,1,1,0,0,3],
	[3,0,1,1,0,0,0,2,0,0,0,0,0,2,2,0,0,0,0,0,0,2,0,0,1,1,0,3],
	[3,0,0,0,0,2,0,0,0,0,1,0,2,0,0,2,0,1,0,0,0,0,2,0,0,0,0,3],
	[3,0,0,0,2,0,0,1,1,0,0,2,0,0,0,0,2,0,0,1,1,0,0,2,0,0,0,3],
	[3,0,0,1,0,0,0,0,2,0,0,0,0,2,2,0,0,0,2,0,0,0,0,0,1,0,0,3],
	[3,0,2,0,0,0,0,0,0,0,2,0,2,0,0,2,0,2,0,0,0,0,0,0,0,2,0,3],
	[3,0,0,0,0,1,6,6,2,0,0,2,2,6,6,2,2,0,0,2,6,6,1,0,0,0,0,3],
	[3,4,4,4,4,4,4,6,6,4,4,4,4,4,6,6,4,4,4,4,4,6,6,4,4,4,4,3],
	[3,4,4,4,4,4,4,6,6,4,4,4,4,4,6,6,4,4,4,4,4,6,6,4,4,4,4,3],
	[3,0,0,5,5,0,6,6,0,0,0,0,2,6,6,2,0,0,0,0,6,6,0,5,5,0,0,3],
	[3,0,5,5,0,0,0,0,2,0,0,1,0,0,0,0,1,0,0,2,0,0,0,0,5,5,0,3],
	[3,0,0,1,0,0,0,2,0,0,0,0,0,2,2,0,0,0,0,0,2,0,0,0,1,0,0,3],
	[3,0,0,0,0,2,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,2,0,0,0,0,3],
	[3,0,1,1,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,1,1,0,3],
	[3,0,0,0,2,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,2,0,0,0,0,3],
	[3,0,0,0,0,0,1,0,0,0,0,5,5,0,0,5,5,0,0,0,0,1,0,0,0,0,0,3],
	[3,0,0,0,0,0,0,0,0,0,5,5,0,0,0,0,5,5,0,0,0,0,0,0,0,0,0,3],
	[3,0,0,0,0,0,0,0,0,5,5,0,0,0,0,0,0,5,5,0,0,0,0,0,0,0,0,3],
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
]
const TERRAIN_CH3: Array = [
	# 24列×18行，南北纵向：欢乐塔在北（rows 0-3），奈德从南方出发（rows 14-16）
	# 结构目标：南侧开阔集结 → 中部湿地压迫与两翼绕行 → 北侧塔前杀伤区 → 戴恩门神位
	# 0=平原 1=森林 2=矮墙 3=峭壁 4=河流 5=沼泽 6=桥梁
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # row 0：北方边界
	[3,0,0,2,2,0,0,2,2,0,0,2,2,0,0,2,2,0,0,2,2,0,0,3],  # row 1：塔外壁
	[3,0,2,0,0,0,2,0,0,0,2,0,0,0,2,0,0,0,2,0,0,2,0,3],  # row 2：塔内部（欢乐塔大厅）
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # row 3：欢乐塔大厅（可通行）
	[3,0,0,2,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,2,0,0,3],  # row 4：塔前外壁与中央门道
	[3,0,0,0,2,0,0,0,1,1,0,0,0,0,1,1,0,0,0,2,0,0,0,3],  # row 5：塔前碎石坡与两翼灌木
	[3,0,0,0,0,0,0,2,0,0,0,2,2,0,0,0,2,0,0,0,0,0,0,3],  # row 6：亚瑟·戴恩守卫区（中轴门前）
	[3,0,0,0,0,5,5,5,0,0,0,0,0,0,0,0,5,5,5,0,0,0,0,3],  # row 7：中部北侧湿地带
	[3,0,0,5,5,5,0,0,0,1,0,0,0,0,1,0,0,0,5,5,5,0,0,3],  # row 8：迫使玩家选择中轴或两翼绕行
	[3,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,3],  # row 9：塔前第二道阻拦
	[3,0,0,0,1,0,2,0,0,5,0,0,0,0,5,0,0,2,0,1,0,0,0,3],  # row 10：两翼掩体与中部减速泥地
	[3,0,5,0,0,0,0,0,1,5,0,0,0,0,5,1,0,0,0,0,0,5,0,3],  # row 11：纵深压迫区
	[3,0,0,0,2,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,2,0,0,3],  # row 12：南侧前沿掩体
	[3,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,3],  # row 13：集结后上推的最后整理区
	[3,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,3],  # row 14：奈德北上的第一道泥地提示
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # row 15：奈德出发区
	[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],  # row 16
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],  # row 17：南方边界
]

# 地形图块坐标（Toen Medieval Strategy 16x16图集，7列x52行）
const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),   # 平原
	1: Vector2i(6, 0),   # 森林
	2: Vector2i(0, 2),   # 矮墙
	3: Vector2i(1, 50),  # 峭壁（不可通行）
	4: Vector2i(0, 13),  # 河流
	5: Vector2i(1, 19),  # 沼泽
	6: Vector2i(4, 2),   # 桥梁
}

# 第四章（铁王座·君临城）专用瓦片坐标
const TILE_ATLAS_COORDS_CH4 := {
	0: Vector2i(0, 0),
	1: Vector2i(6, 0),
	2: Vector2i(0, 2),
	3: Vector2i(1, 50),
	4: Vector2i(0, 13),
	5: Vector2i(1, 19),
	6: Vector2i(4, 2),
}

# ── 章节专属状态 ──────────────────────────────────────────
var _rhaegar_unit:         Unit = null
var _rhaegar_death_done:   bool = false
var _ch2_victory_started:  bool = false
var _dayne_unit:           Unit = null
var _tower_reached:        bool = false
var _ned_unit:             Unit = null
var _royal_commander:          Unit = null
var _commander_killed:         bool = false
var _jaime_triggered:          bool = false
var _lannister_units:          Array = []
var _terrain_cache_ch4:        Array = []
var _ch4_midway_hint_shown:    bool = false   # 王军被清除后的中途提示
var _ch2_south_bank_hint_shown: bool = false
var _ch2_bridge_hint_shown:    bool = false
var _ch2_north_bank_hint_shown: bool = false
var _ch3_swamp_hint_shown:     bool = false
var _ch3_tower_hint_shown:     bool = false
var _ch4_blackwater_hint_shown: bool = false
var _ch4_gate_hint_shown:      bool = false
var _ch4_avenue_hint_shown:    bool = false
var _ch4_red_keep_hint_shown:  bool = false
var _ch4_current_stage:        int = 0

# ── 序章一专属状态 ────────────────────────────────────────
var _tutorial_mgr:         TutorialManager = null
var _ned_reached_victory:  bool = false
var _ch1_enemies_spawned:  bool = false  # 敌人已生成标记（防止unit死亡后数组清空导致胜利检查失败）

func _set_objective_status(msg: String) -> void:
	_set_status("目标：%s" % msg)

func _set_progress_status(msg: String) -> void:
	_set_status("推进：%s" % msg)

func _set_battle_status(msg: String) -> void:
	_set_status("战局：%s" % msg)

func _set_ch4_stage(stage_idx: int) -> void:
	if GameState.current_chapter != 4:
		return
	if stage_idx < 1 or stage_idx > 4:
		return
	if _ch4_current_stage != stage_idx:
		_ch4_current_stage = stage_idx
	_set_phase_badge(Ch4BattleBrief.get_stage_badge(stage_idx))
	_set_progress_status(Ch4BattleBrief.get_stage_guidance(stage_idx))

# ══════════════════════════════════════════════════════════
func _ready() -> void:
	match GameState.current_chapter:
		2: _setup_ch2()
		3: _setup_ch3()
		4: _setup_ch4()
		_: _setup_ch1()

# ══════════════════════════════════════════════════════════
# 序章·一《风暴地》教学关（10×8）
# ══════════════════════════════════════════════════════════
func _setup_ch1() -> void:
	map_width   = 10;  map_height = 8
	victory_pos = Vector2i(5, 0)  # 山道北侧缺口（为后军打开通路）
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH1)
	# 玩家单位：奈德 + 霍兰德（南方出发）
	_ned_unit = _make_unit_r("ned_stark.json",    0, Vector2i(3, 6))
	_make_unit("howland_reed.json", 0, Vector2i(5, 6))
	# 敌方：3名皇家卫兵（封锁山道的前锋、门卫与侧翼）
	var e1 := _make_unit_r("royal_soldier.json", 1, Vector2i(4, 3))
	var e2 := _make_unit_r("royal_soldier.json", 1, Vector2i(5, 1))
	var e3 := _make_unit_r("royal_soldier.json", 1, Vector2i(7, 3))
	_override_enemy_stats(e1); _override_enemy_stats(e2); _override_enemy_stats(e3)
	_ch1_enemies_spawned = true  # 标记已生成，供胜利检查使用
	_redraw_all()
	_set_objective_status(PrologueChapterBriefs.CH1_BATTLE_OBJECTIVE)
	_run_ch1_tutorial()

func _override_enemy_stats(unit: Unit) -> void:
	if unit == null: return
	unit.data.hp     = 16
	unit.data.max_hp = 16
	unit.data.def    = 4
	unit._refresh_hp_label()

# ── 安全帧等待（场景切换后 get_tree() 为 null，必须guard）──
# 返回 true=继续, false=节点已离开场景树，调用方应立即 return
func _safe_frame() -> bool:
	if not is_inside_tree(): return false
	await get_tree().process_frame
	return is_inside_tree()

# ── 序章一教学流程 ────────────────────────────────────────
func _run_ch1_tutorial() -> void:
	await _play_dialogue("res://data/dialogues/prologue_1_pre.json")
	if not await _safe_frame(): return

	_tutorial_mgr = TutorialManager.new()
	add_child(_tutorial_mgr)

	_tutorial_mgr.show_step("点击您的单位选中它。蓝色格子是移动范围。")
	await _tutorial_mgr.wait_for_step(0)
	if not is_inside_tree(): return

	await _wait_for_unit_selected()
	if not is_inside_tree(): return
	_tutorial_mgr.show_step("将奈德移动到蓝色格子上。")
	await _tutorial_mgr.wait_for_step(1)
	if not is_inside_tree(): return

	await _wait_for_unit_moved()
	if not is_inside_tree(): return
	_tutorial_mgr.show_step("红色格子里有敌人。点击红格发动攻击。")
	await _tutorial_mgr.wait_for_step(2)
	if not is_inside_tree(): return

	await _wait_for_predict_opened()
	if not is_inside_tree(): return
	_tutorial_mgr.show_step("这是战斗预测。确认后发动攻击。")
	await _tutorial_mgr.wait_for_step(3)
	if not is_inside_tree(): return

	await _wait_for_battle_resolved()
	if not is_inside_tree(): return
	_tutorial_mgr.show_step("干得好。点击【结束回合】，等待敌方行动。")
	await _tutorial_mgr.wait_for_step(4)
	if not is_inside_tree(): return

	await _wait_for_turn_switched()
	if not is_inside_tree(): return
	_tutorial_mgr.show_step("⭐ 北侧星形是山道缺口。突破封锁，把奈德带到那里。")

	_check_ch1_victory_loop()

# ── 教学等待辅助（全部加 is_inside_tree 守卫防止场景切换崩溃）──

func _wait_for_unit_selected() -> void:
	while player_state != PlayerState.UNIT_SELECTED:
		if not await _safe_frame(): return

func _wait_for_unit_moved() -> void:
	while player_state == PlayerState.UNIT_SELECTED or player_state == PlayerState.IDLE:
		if not await _safe_frame(): return
		if player_state == PlayerState.UNIT_MOVED: break

func _wait_for_predict_opened() -> void:
	while player_state != PlayerState.PREDICT:
		if not await _safe_frame(): return

func _wait_for_battle_resolved() -> void:
	while not _animating_battle:
		if not await _safe_frame(): return
	while _animating_battle:
		if not await _safe_frame(): return

func _wait_for_turn_switched() -> void:
	var initial_turn := _turn_count
	while _turn_count == initial_turn:
		if not await _safe_frame(): return
	if not _battle_over:
		_set_progress_status("敌军开始应对山道缺口——继续向北推进，别被封锁线拖住。")

# ── 序章一胜利检测 ────────────────────────────────────────
func _check_ch1_victory_loop() -> void:
	while not _ned_reached_victory and not _battle_over:
		if not await _safe_frame(): return
		if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
				and _ned_unit.grid_pos == victory_pos:
			_ned_reached_victory = true
			_on_won_ch1()
			return

func _on_won_ch1() -> void:
	if _battle_over: return   # 防止敌全灭 + 到达胜利格 双重触发
	_battle_over = true
	_hide_all_panels()
	if _result_panel: _result_panel.visible = false
	_set_battle_status("山道已打开！后军可以北上——奈德继续前进。")
	await _play_dialogue("res://data/dialogues/prologue_1_post.json")
	if not is_inside_tree(): return
	await _advance_to(2)

# ── 序章一胜利条件覆盖 ───────────────────────────────────
func _check_victory() -> void:
	if _battle_over: return
	match GameState.current_chapter:
		1:
			# 双胜利条件：敌全灭 OR 奈德到达胜利格（由_check_ch1_victory_loop处理）
			# 注意：enemy_units在单位死亡后会erase，不能用is_empty()判断"曾生成过"
			var alive_enemies := enemy_units.filter(func(u: Unit) -> bool: return not u.is_dead())
			if alive_enemies.is_empty() and _ch1_enemies_spawned:
				_on_won_ch1()
		2:
			var mortal := enemy_units.filter(func(u: Unit) -> bool:
				return not u.is_dead() and u.data.min_hp == 0)
			if mortal.is_empty():
				_on_won_ch2()
		3:
			if _tower_reached: return
			if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
					and _ned_unit.grid_pos == victory_pos:
				_tower_reached = true
				_trigger_ch3_tower()
		4:
			# 中途提示：普通王军全灭但指挥官仍在
			if not _ch4_midway_hint_shown and not _commander_killed:
				var royal_alive := enemy_units.filter(func(u: Unit) -> bool:
					return not u.is_dead() and u.team == 1 \
						and u != _royal_commander and not _lannister_units.has(u))
				if royal_alive.is_empty() and is_instance_valid(_royal_commander) \
						and not _royal_commander.is_dead():
					_ch4_midway_hint_shown = true
					_set_phase_badge(Ch4BattleBrief.get_stage_badge(4))
					_set_battle_status(Ch4BattleBrief.COMMANDER_REMAINS_STATUS)
			# 胜利：奈德抵达铁王座
			if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
					and _ned_unit.grid_pos == victory_pos:
				_trigger_ch4_throne()
		_:
			super._check_victory()

func _on_player_unit_action_position_updated(unit: Unit) -> void:
	if unit == null or unit.team != 0 or _battle_over:
		return
	match GameState.current_chapter:
		2:
			if not _ch2_south_bank_hint_shown \
					and unit.grid_pos.y <= 12 \
					and unit.grid_pos.x >= 12 and unit.grid_pos.x <= 16:
				_ch2_south_bank_hint_shown = true
				_set_progress_status("前方就是三桥战场——中桥最短，两翼负责牵制与分压。")
			elif not _ch2_bridge_hint_shown \
					and unit.grid_pos.y >= 8 and unit.grid_pos.y <= 10 \
					and unit.grid_pos.x >= 13 and unit.grid_pos.x <= 15:
				_ch2_bridge_hint_shown = true
				_set_progress_status("义军已踏上中桥——稳住两翼，别让主攻轴线断掉。")
			elif not _ch2_north_bank_hint_shown \
					and unit.grid_pos.y <= 7 \
					and unit.grid_pos.x >= 12 and unit.grid_pos.x <= 16:
				_ch2_north_bank_hint_shown = true
				_set_progress_status("你已抢上北岸桥头——继续压向雷加本阵，别被两翼牵住。")
		3:
			if not _ch3_swamp_hint_shown and unit.grid_pos.y <= 12:
				_ch3_swamp_hint_shown = true
				_set_progress_status("湿地会拖慢推进——两翼绕开泥地，为奈德撕出塔前通路。")
			elif not _ch3_tower_hint_shown and unit == _ned_unit and unit.grid_pos.y <= 9:
				_ch3_tower_hint_shown = true
				_set_progress_status("奈德已逼近欢乐塔——目标是进塔，不是清光所有守军。")
		4:
			if not _ch4_blackwater_hint_shown \
					and unit.grid_pos.y <= 20 \
					and unit.grid_pos.x >= 17 and unit.grid_pos.x <= 20:
				_ch4_blackwater_hint_shown = true
				_set_ch4_stage(1)
			elif not _ch4_gate_hint_shown \
					and unit.grid_pos.y <= 18 \
					and unit.grid_pos.x >= 17 and unit.grid_pos.x <= 20:
				_ch4_gate_hint_shown = true
				_set_ch4_stage(2)
			elif not _ch4_avenue_hint_shown \
					and unit.grid_pos.y <= 16 \
					and unit.grid_pos.x >= 17 and unit.grid_pos.x <= 20:
				_ch4_avenue_hint_shown = true
				_set_ch4_stage(3)
			elif not _ch4_red_keep_hint_shown \
					and unit.grid_pos.y <= 11 \
					and unit.grid_pos.x >= 17 and unit.grid_pos.x <= 20:
				_ch4_red_keep_hint_shown = true
				_set_ch4_stage(4)

# ══════════════════════════════════════════════════════════
# 序章·二《三叉戟》
# ══════════════════════════════════════════════════════════
func _setup_ch2() -> void:
	map_width   = 28;  map_height = 20
	victory_pos = Vector2i(14, 1)  # 击败雷加自动触发，北方中央
	_ch2_victory_started = false
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH2)
	# 玩家方（南方，rows 17-18）
	_make_unit("robert_baratheon.json",  0, Vector2i(14, 17))  # 中央南
	_make_unit("rebel_lord.json",        0, Vector2i(9,  18))
	_make_unit("rebel_lord.json",        0, Vector2i(19, 18))
	_make_unit("rebel_lord.json",        0, Vector2i(14, 18))
	# 敌方（北方，rows 2-6）
	_rhaegar_unit = _make_unit_r("rhaegar_targaryen.json", 1, Vector2i(14, 3))  # 中央北
	_make_unit("barristan_selmy.json",    1, Vector2i(18, 4))
	_make_unit("targaryen_soldier.json",  1, Vector2i(6,  7))
	_make_unit("targaryen_soldier.json",  1, Vector2i(13, 6))
	_make_unit("targaryen_soldier.json",  1, Vector2i(10, 6))
	_make_unit("targaryen_soldier.json",  1, Vector2i(18, 6))
	_make_unit("targaryen_soldier.json",  1, Vector2i(22, 6))
	_make_unit("targaryen_soldier.json",  1, Vector2i(20, 7))
	_redraw_all()
	_set_objective_status(PrologueChapterBriefs.CH2_BATTLE_OBJECTIVE)
	await _play_dialogue("res://data/dialogues/ch2_pre.json")

func _on_won_ch2() -> void:
	if _ch2_victory_started:
		return
	_ch2_victory_started = true
	_battle_over = true
	_hide_all_panels()
	if _end_turn_btn:
		_end_turn_btn.disabled = true
	if _result_panel: _result_panel.visible = false
	await _play_cutscene("res://data/cutscenes/ch2_split.json")
	if not is_inside_tree(): return
	await _play_dialogue("res://data/dialogues/ch2_post.json")
	if not is_inside_tree(): return
	await _advance_to(3)

# ══════════════════════════════════════════════════════════
# 序章·三《极乐塔》
# ══════════════════════════════════════════════════════════
func _setup_ch3() -> void:
	map_width   = 24;  map_height = 18
	victory_pos = Vector2i(12, 2)  # 欢乐塔内部（北方）
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH3)
	# 玩家方（南方，rows 14-16）
	_ned_unit  = _make_unit_r("ned_stark.json",       0, Vector2i(12, 15))  # 中央南
	_make_unit("howland_reed.json",    0, Vector2i(11, 16))
	_make_unit("northern_knight.json", 0, Vector2i(8,  15))
	_make_unit("northern_knight.json", 0, Vector2i(16, 15))
	_make_unit("northern_knight.json", 0, Vector2i(12, 16))
	# 敌方（北方）
	_dayne_unit = _make_unit_r("arthur_dayne.json", 1, Vector2i(12, 6))  # 守塔入口
	if _dayne_unit != null:
		_dayne_unit.data.move = 0   # 亚瑟·戴恩原地守卫
	_make_unit("dorne_knight.json", 1, Vector2i(7,  9))
	_make_unit("dorne_knight.json", 1, Vector2i(16, 9))
	_make_unit("dorne_knight.json", 1, Vector2i(9,  11))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 11))
	_make_unit("dorne_knight.json", 1, Vector2i(12, 8))
	_redraw_all()
	_set_objective_status(PrologueChapterBriefs.CH3_BATTLE_OBJECTIVE)
	await _play_dialogue("res://data/dialogues/ch3_pre.json")

# ══════════════════════════════════════════════════════════
# 序章·四《铁王座》
# ══════════════════════════════════════════════════════════
func _setup_ch4() -> void:
	map_width   = 36;  map_height = 26
	victory_pos = Vector2i(18, 2)  # 铁王座大厅中央（北方）
	_ch4_current_stage = 0
	_terrain_cache_ch4 = _build_map_ch4()
	_apply_cam_limits()
	if is_instance_valid(_cam):
		_cam.position = Vector2(1296, 1584)  # 指向玩家出生区（18*72, 22*72）
	super._ready()
	_paint_from_ch4(_terrain_cache_ch4)
	var selection := GameState.deploy_selection.duplicate()
	if selection.is_empty():
		selection = ["ned_stark.json", "northern_knight.json", "northern_knight.json"]
	var spawns: Array = [
		Vector2i(18,22), Vector2i(15,22), Vector2i(21,22),
		Vector2i(12,23), Vector2i(18,23), Vector2i(24,23),
	]
	for i: int in min(selection.size(), spawns.size()):
		var u := _make_unit_r(selection[i], 0, spawns[i])
		if u != null and selection[i] == "ned_stark.json":
			_ned_unit = u
	# 兰尼斯特中立军（team=2，row 12，持观望态度——不攻击，不可被攻击）
	for pos: Vector2i in [Vector2i(10,12), Vector2i(15,12), Vector2i(20,12), Vector2i(25,12)]:
		var u := _make_unit_r("lannister_soldier.json", 2, pos)
		if u != null:
			u.data.move   = 0    # 原地不动
			u.data.min_hp = 1    # 不可击杀（名义上）
			u.data.name   = "兰军（中立）"
			_lannister_units.append(u)

	# 王军（君临城街道，rows 14-18）
	_make_unit("royal_soldier.json", 1, Vector2i(10, 15))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 15))
	_make_unit("royal_soldier.json", 1, Vector2i(26, 15))
	_make_unit("royal_soldier.json", 1, Vector2i(10, 17))
	_make_unit("royal_soldier.json", 1, Vector2i(26, 17))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 17))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 14))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 18))

	# 王军指挥官（铁王座内院 row 7，不可移动，关键击杀目标）
	_royal_commander = _make_unit_r("royal_guard_captain.json", 1, Vector2i(18, 7))
	if _royal_commander != null:
		_royal_commander.data.name = "★ 王军指挥官"   # 加星号标记是关键目标
		_royal_commander.data.move = 0               # 守卫铁王座，原地不动

	_redraw_all()
	# 开场提示：说明兰军是中立，指挥官是目标，中轴是主推进方向
	_set_objective_status(Ch4BattleBrief.BATTLE_OBJECTIVE)
	_set_ch4_stage(1)
	await _play_dialogue("res://data/dialogues/ch4_pre.json")

func _build_map_ch4() -> Array:
	const W := 36; const H := 26
	var m: Array = []
	for _y: int in H:
		var row: Array = []
		for _x: int in W:
			row.append(0)
		m.append(row)
	_ch4_paint(m, W, H)
	return m

# ────────────────────────────────────────────────────────────
# 序章四（铁王座·君临城）地形绘制——红堡 / 城墙 / 护城河 / 桥梁
# 布局（从北 row 0 到南 row 25）：
#   row 0：北方峭壁边界
#   rows 1-3：铁王座大厅
#   row 4：王座厅南墙（三道门）
#   rows 5-7：红堡内院
#   row 8：红堡内护城河（三桥）
#   rows 9-10：红堡外院
#   row 11：红堡外墙（三门）
#   row 12：兰尼斯特中立军列阵区
#   row 13：君临内城墙（三门）
#   rows 14-17：城内街区与中央大道
#   row 18：君临南城墙（三门）
#   row 19：黑水河/外护城河（三桥）
#   rows 20-23：城南集结区（玩家部署）
#   rows 24-25：南方边界峭壁
# 0=石板路  1=花园  2=城墙/建筑  3=峭壁  4=河流  5=沼泽  6=桥梁
# ────────────────────────────────────────────────────────────
func _ch4_paint(m: Array, W: int, H: int) -> void:
	const WEST_GATE_A := 8
	const WEST_GATE_B := 10
	const MAIN_GATE_A := 17
	const MAIN_GATE_B := 20
	const EAST_GATE_A := 26
	const EAST_GATE_B := 28

	# ── 边界峭壁 ─────────────────────────────────────────────
	for x: int in W:
		m[0][x] = 3
		m[H - 1][x] = 3
		m[H - 2][x] = 3
	for y: int in H:
		m[y][0] = 3
		m[y][W - 1] = 3

	# ── 铁王座大厅（rows 1-4）─────────────────────────────
	for x: int in range(6, 30):
		m[1][x] = 2
		m[4][x] = 2
	for y: int in range(1, 5):
		m[y][6] = 2
		m[y][29] = 2
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[4][x] = 0
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[4][x] = 0
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[4][x] = 0
	for y: int in range(2, 4):
		m[y][10] = 2
		m[y][11] = 2
		m[y][24] = 2
		m[y][25] = 2
	# 铁王座 (18,2) 附近保留完全可通行
	for pos: Vector2i in [Vector2i(17, 2), Vector2i(18, 2), Vector2i(19, 2), Vector2i(18, 3)]:
		m[pos.y][pos.x] = 0

	# ── 红堡内院（rows 5-7）───────────────────────────────
	for y: int in range(5, 8):
		for x: int in range(7, 11):
			m[y][x] = 1
		for x: int in range(25, 29):
			m[y][x] = 1
	for pos: Vector2i in [
		Vector2i(11, 5), Vector2i(24, 5),
		Vector2i(11, 7), Vector2i(24, 7),
		Vector2i(14, 6), Vector2i(22, 6),
	]:
		m[pos.y][pos.x] = 2

	# ── 红堡内护城河（row 8）─────────────────────────────
	for x: int in range(1, W - 1):
		m[8][x] = 4
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[8][x] = 6
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[8][x] = 6
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[8][x] = 6

	# ── 红堡外院（rows 9-10）──────────────────────────────
	for pos: Vector2i in [
		Vector2i(4, 9), Vector2i(5, 9), Vector2i(30, 9), Vector2i(31, 9),
		Vector2i(5, 10), Vector2i(6, 10), Vector2i(29, 10), Vector2i(30, 10),
		Vector2i(13, 10), Vector2i(23, 10),
	]:
		m[pos.y][pos.x] = 2

	# ── 红堡外墙（row 11）────────────────────────────────
	for x: int in range(1, W - 1):
		m[11][x] = 2
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[11][x] = 0
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[11][x] = 0
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[11][x] = 0

	# row 12：兰尼斯特中立军列阵区（保持开阔）

	# ── 君临内城墙（row 13）──────────────────────────────
	for x: int in range(1, W - 1):
		m[13][x] = 2
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[13][x] = 0
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[13][x] = 0
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[13][x] = 0

	# ── 城内街区（rows 14-17）─────────────────────────────
	for pos: Vector2i in [
		# 西城区
		Vector2i(3, 14), Vector2i(4, 14), Vector2i(6, 14), Vector2i(7, 14),
		Vector2i(3, 15), Vector2i(4, 15), Vector2i(10, 15), Vector2i(11, 15),
		Vector2i(4, 16), Vector2i(5, 16), Vector2i(7, 16), Vector2i(10, 16),
		Vector2i(3, 17), Vector2i(4, 17), Vector2i(9, 17), Vector2i(10, 17),
		# 东城区
		Vector2i(28, 14), Vector2i(29, 14), Vector2i(31, 14), Vector2i(32, 14),
		Vector2i(24, 15), Vector2i(25, 15), Vector2i(31, 15), Vector2i(32, 15),
		Vector2i(25, 16), Vector2i(28, 16), Vector2i(30, 16), Vector2i(31, 16),
		Vector2i(25, 17), Vector2i(26, 17), Vector2i(31, 17), Vector2i(32, 17),
		# 城门塔楼
		Vector2i(6, 17), Vector2i(11, 17), Vector2i(16, 17),
		Vector2i(21, 17), Vector2i(26, 17), Vector2i(30, 17),
	]:
		m[pos.y][pos.x] = 2
	for y: int in range(14, 17):
		m[y][14] = 1
		m[y][15] = 1
		m[y][21] = 1
		m[y][22] = 1
	# 17~20 列保留中央大道，方便南北推进

	# ── 君临南城墙（row 18）──────────────────────────────
	for x: int in range(1, W - 1):
		m[18][x] = 2
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[18][x] = 0
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[18][x] = 0
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[18][x] = 0

	# ── 黑水河 / 外护城河（row 19）────────────────────────
	for x: int in range(1, W - 1):
		m[19][x] = 4
	for x: int in range(WEST_GATE_A, WEST_GATE_B + 1):
		m[19][x] = 6
	for x: int in range(MAIN_GATE_A, MAIN_GATE_B + 1):
		m[19][x] = 6
	for x: int in range(EAST_GATE_A, EAST_GATE_B + 1):
		m[19][x] = 6

	# ── 城南集结区（rows 20-23）──────────────────────────
	for pos: Vector2i in [
		Vector2i(4, 20), Vector2i(5, 20), Vector2i(30, 20), Vector2i(31, 20),
		Vector2i(3, 21), Vector2i(4, 21), Vector2i(5, 21),
		Vector2i(30, 21), Vector2i(31, 21), Vector2i(32, 21),
		Vector2i(4, 22), Vector2i(31, 22),
	]:
		m[pos.y][pos.x] = 2
	for x: int in range(15, 22):
		m[20][x] = 0
		m[21][x] = 0
		m[22][x] = 0
		m[23][x] = 0

# ══════════════════════════════════════════════════════════
# 地形系统覆盖
# ══════════════════════════════════════════════════════════
func _get_terrain_type(pos: Vector2i) -> int:
	var ch := GameState.current_chapter
	var terrain: Array
	match ch:
		2: terrain = TERRAIN_CH2
		3: terrain = TERRAIN_CH3
		4: terrain = _terrain_cache_ch4
		_: terrain = TERRAIN_CH1
	if pos.y < 0 or pos.y >= terrain.size(): return TERRAIN_CLIFF
	var row: Array = terrain[pos.y]
	if pos.x < 0 or pos.x >= row.size(): return TERRAIN_CLIFF
	return int(row[pos.x])

func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height: return false
	var t: int = _get_terrain_type(pos)
	return t != TERRAIN_CLIFF and t != TERRAIN_RIVER

# ══════════════════════════════════════════════════════════
# 死亡拦截覆盖（Ch2 雷加演出；Ch4 指挥官触发兰军归降）
# ══════════════════════════════════════════════════════════
func _on_unit_died(unit: Unit) -> void:
	match GameState.current_chapter:
		2:
			if is_instance_valid(_rhaegar_unit) and unit == _rhaegar_unit \
					and not _rhaegar_death_done:
				_rhaegar_death_done = true
				enemy_units.erase(unit)
				unit.queue_free()
				_redraw_all()
				_trigger_ch2_rhaegar()
				return
		4:
			if is_instance_valid(_royal_commander) and unit == _royal_commander \
					and not _commander_killed:
				_commander_killed = true
				super._on_unit_died(unit)
				_trigger_ch4_lannister_join()
				return
	super._on_unit_died(unit)

func _trigger_ch2_rhaegar() -> void:
	_battle_over = true
	_set_battle_status("雷加倒下了！中桥决战结束，王家防线开始崩溃。")
	await _play_cutscene("res://data/cutscenes/ch2_rhaegar_fall.json")
	if not is_inside_tree(): return
	await _on_won_ch2()

func _trigger_ch3_tower() -> void:
	_battle_over = true
	_set_battle_status("奈德已抵达欢乐塔——亚瑟守线被撕开，真相就在塔内。")
	await _play_cutscene("res://data/cutscenes/ch3_dayne_trigger.json")
	if is_instance_valid(_dayne_unit):
		enemy_units.erase(_dayne_unit); _dayne_unit.queue_free(); _redraw_all()
	await _play_cutscene("res://data/cutscenes/ch3_lyanna.json")
	await _play_dialogue("res://data/dialogues/ch3_post.json")
	await _advance_to(4)

func _trigger_ch4_lannister_join() -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or _battle_over: return

	# 播放归降对话
	var join_dialogue := "res://data/dialogues/ch4_lannister_join.json"
	if FileAccess.file_exists(join_dialogue):
		await _play_dialogue(join_dialogue)
	if not is_inside_tree() or _battle_over: return

	# 兰军单位从地图上消失
	for u: Unit in _lannister_units.duplicate():
		if is_instance_valid(u) and not u.is_dead():
			enemy_units.erase(u)
			u.queue_free()
	_lannister_units.clear()
	_redraw_all()

	# ── 关键：兰军消失后，所有战斗目标已完成，直接触发结局 ──
	# （等待玩家手动走到铁王座是反高潮设计，此处直接流向叙事结局）
	if is_instance_valid(_ned_unit) and not _ned_unit.is_dead():
		_set_phase_badge(Ch4BattleBrief.get_stage_badge(4))
		_set_battle_status(Ch4BattleBrief.LANNISTER_SURRENDER_STATUS)
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or _battle_over: return
		_trigger_ch4_throne()
	else:
		# 奈德阵亡的边缘情况（理论上不应发生）
		_set_battle_status("兰尼斯特军已归降，然而……")

func _trigger_ch4_throne() -> void:
	if _battle_over: return   # 防止重复触发
	_battle_over = true
	_hide_all_panels()
	if _end_turn_btn: _end_turn_btn.disabled = true
	_set_phase_badge(Ch4BattleBrief.get_stage_badge(4))
	_set_battle_status(Ch4BattleBrief.THRONE_SECURED_STATUS)
	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree(): return
	# 詹姆对话：仅在尚未通过 (25,12) 触发过时才播放，避免重复
	if not _jaime_triggered:
		_jaime_triggered = true
		await _play_dialogue("res://data/dialogues/ch4_jaime.json")
		if not is_inside_tree(): return
		await _play_cutscene("res://data/cutscenes/ch4_jaime_scene.json")
		if not is_inside_tree(): return
	# 最终结局序列
	await _play_dialogue("res://data/dialogues/ch4_post.json")
	if not is_inside_tree(): return
	await _play_cutscene("res://data/cutscenes/ch4_ending.json")
	if not is_inside_tree(): return
	await _advance_to(0)

func _process(delta: float) -> void:
	super._process(delta)
	if GameState.current_chapter == 4 and not _jaime_triggered \
			and not _battle_over:
		if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
				and _ned_unit.grid_pos == Vector2i(18, 9):  # 红堡外院詹姆触发格
			_jaime_triggered = true
			set_process_input(false)
			await _play_dialogue("res://data/dialogues/ch4_jaime.json")
			await _play_cutscene("res://data/cutscenes/ch4_jaime_scene.json")
			set_process_input(true)

# ══════════════════════════════════════════════════════════
# 章节推进
# ══════════════════════════════════════════════════════════
func _advance_to(next_chapter: int) -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	var current := GameState.current_chapter
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).save_chapter_complete(current)
	if next_chapter <= 0:
		GameState.current_chapter = 1
		get_tree().change_scene_to_file("res://scenes/Opening.tscn")
		return
	GameState.current_chapter = next_chapter
	var scene_map := {
		2: "res://scenes/chapter/Ch2_Opening.tscn",
		3: "res://scenes/chapter/Ch3_Opening.tscn",
		4: "res://scenes/chapter/Ch4_Opening.tscn",
	}
	if scene_map.has(next_chapter) and ResourceLoader.exists(scene_map[next_chapter]):
		get_tree().change_scene_to_file(scene_map[next_chapter])
	else:
		if _result_panel:
			var vs := get_viewport().get_visible_rect().size
			_result_panel.position = Vector2(vs.x*0.5-160, vs.y*0.5-80)
			_result_panel.visible  = true

# ══════════════════════════════════════════════════════════
# 辅助工具
# ══════════════════════════════════════════════════════════
func _apply_cam_limits() -> void:
	if not is_instance_valid(_cam): return
	_cam.limit_right  = map_width  * TILE_SIZE
	_cam.limit_bottom = map_height * TILE_SIZE
	_cam.position     = Vector2(640, 360)

func _paint_from(terrain: Array) -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null: return
	tilemap.clear()
	for y: int in terrain.size():
		var row: Array = terrain[y]
		for x: int in row.size():
			tilemap.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS.get(int(row[x]), Vector2i(0,0)))

func _paint_from_ch4(terrain: Array) -> void:
	var tilemap: TileMapLayer = get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
	if tilemap == null: return
	tilemap.clear()
	for y: int in terrain.size():
		var row: Array = terrain[y]
		for x: int in row.size():
			tilemap.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS_CH4.get(int(row[x]), Vector2i(0,0)))

func _play_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as CanvasLayer
		add_child(_dialogue_box)
		await get_tree().process_frame
		_dialogue_sys = _dialogue_box as DialogueSystem
	set_process_input(false)
	_dialogue_sys.play(path)
	await _dialogue_sys.dialogue_finished
	set_process_input(true)

func _play_cutscene(path: String) -> void:
	if not FileAccess.file_exists(path): return
	if _cutscene_node == null:
		_cutscene_node = CUTSCENE_SCENE.instantiate() as CutscenePlayer
		add_child(_cutscene_node)
	_cutscene_node.play(path)
	await _cutscene_node.cutscene_finished

func _make_unit(filename: String, team: int, pos: Vector2i) -> void:
	_make_unit_r(filename, team, pos)

func _make_unit_r(filename: String, team: int, pos: Vector2i) -> Unit:
	var path: String = DATA_PATH + filename
	if not FileAccess.file_exists(path): return null
	var json := JSON.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or json.parse(file.get_as_text()) != OK: return null
	if file: file.close()
	var unit: Node2D = UNIT_SCENE.instantiate()
	unit.setup(UnitData.from_dict(json.data), team, pos)
	var sf: String = UNIT_SPRITE_MAP.get(filename, "")
	if sf != "":
		var tex := load(SPRITE_PATH + sf) as Texture2D
		if tex != null:
			var sp: Sprite2D = unit.get_node("Sprite")
			sp.texture = tex; sp.region_enabled = true; sp.region_rect = Rect2(0,0,32,32)
	var pf: String = UNIT_PORTRAIT_MAP.get(filename, "")
	if pf != "":
		var pp: String = SPRITE_PATH + pf
		if FileAccess.file_exists(pp): unit.set_meta("portrait_path", pp)
	add_unit(unit)
	return unit as Unit
