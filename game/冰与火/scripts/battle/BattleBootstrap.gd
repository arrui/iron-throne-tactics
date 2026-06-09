# BattleBootstrap.gd — 全章节分发器（序章·一～四）
# 根据 GameState.current_chapter 决定运行哪个章节的地图/单位/事件逻辑
extends "res://scripts/battle/BattleMap.gd"

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
	"ned_stark.json":        "ned_stark_portrait.png",
	"robert_baratheon.json": "robert_baratheon_portrait.png",
	"howland_reed.json":     "howland_reed_portrait.png",
	"royal_soldier.json":    "royal_soldier_portrait.png",
}

# ── 部署选择（Ch4，由 DeployScreen_Ch4 设置）───────────────
# deploy_selection 已移至 GameState.deploy_selection

# ── 共享状态 ──────────────────────────────────────────────
var _dialogue_box:  CanvasLayer    = null
var _dialogue_sys:  DialogueSystem = null
var _cutscene_node: CutscenePlayer = null

# ── 地形图（各章节）──────────────────────────────────────
# 0=平原 1=森林 2=矮墙 3=峭壁 4=河流 5=沼泽 6=桥梁
const TERRAIN_CH1: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],[3,0,0,1,1,0,0,0,0,4,4,0,0,0,0,0,0,0,1,1,0,3],[3,0,1,1,0,0,0,0,0,4,4,0,0,0,0,0,0,1,1,0,0,3],[3,0,1,0,0,2,0,0,0,4,4,0,0,0,2,2,0,0,0,0,0,3],[3,0,0,0,2,0,0,2,0,4,4,0,2,0,0,2,0,0,0,0,0,3],[3,0,0,0,2,0,0,6,6,6,6,6,2,0,0,2,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,3],[3,0,5,5,0,0,0,0,0,4,4,0,0,0,0,2,2,0,0,0,0,3],[3,0,5,0,0,1,0,0,0,4,4,0,0,0,0,2,0,0,0,0,0,3],[3,0,0,0,1,1,0,0,0,4,4,0,0,0,0,2,0,0,0,0,0,3],[3,0,0,0,1,0,0,6,6,6,6,6,0,0,0,2,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,2,2,0,0,0,3],[3,0,0,1,0,0,2,0,0,4,4,0,0,2,0,0,0,2,0,0,0,3],[3,0,1,1,0,0,2,0,0,4,4,0,0,2,0,0,0,0,0,1,0,3],[3,0,0,1,0,0,0,0,0,4,4,0,0,0,0,0,0,0,1,1,0,3],[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
]
const TERRAIN_CH2: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],[3,0,0,1,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,1,1,0,3],[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,1,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,2,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,0,0,0,3],[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,1,1,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,1,0,0,0,0,0,3],[3,0,1,1,0,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,2,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,6,6,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,1,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,1,1,0,0,3],[3,0,0,0,1,0,0,0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,1,1,0,0,0,3],[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
]
const TERRAIN_CH3: Array = [
	[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],[3,0,0,5,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,5,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,5,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,2,0,0,2,0,0,0,0,0,0,0,0,0,0,2,2,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,2,0,0,3],[3,0,0,0,0,0,0,0,0,0,5,5,0,0,0,0,0,2,0,0,2,0,0,3],[3,0,0,5,0,0,0,0,0,5,0,0,0,0,0,0,2,0,0,0,0,2,0,3],[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,2,3],[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,2,0,3],[3,0,0,0,5,5,0,0,0,0,0,0,0,0,0,0,2,0,0,0,2,0,0,3],[3,0,2,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,3],[3,0,2,0,0,0,0,0,0,0,5,5,0,0,0,2,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3],[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
]

const TILE_ATLAS_COORDS := {
	0: Vector2i(0, 0),  1: Vector2i(2, 4),  2: Vector2i(1, 20),
	3: Vector2i(0, 12), 4: Vector2i(0, 8),  5: Vector2i(1, 9),
	6: Vector2i(3, 2),
}

# ── 章节专属状态 ──────────────────────────────────────────
var _rhaegar_unit:         Unit = null
var _rhaegar_death_done:   bool = false
var _dayne_unit:           Unit = null
var _tower_reached:        bool = false
var _ned_unit:             Unit = null
var _royal_commander:      Unit = null
var _commander_killed:     bool = false
var _jaime_triggered:      bool = false
var _lannister_units:      Array = []
var _terrain_cache_ch4:    Array = []

# ══════════════════════════════════════════════════════════
func _ready() -> void:
	match GameState.current_chapter:
		2: _setup_ch2()
		3: _setup_ch3()
		4: _setup_ch4()
		_: _setup_ch1()

# ══════════════════════════════════════════════════════════
# 序章·一《风暴地》
# ══════════════════════════════════════════════════════════
func _setup_ch1() -> void:
	map_width   = 22;  map_height = 16
	victory_pos = Vector2i(17, 8)
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH1)
	_make_unit("ned_stark.json",        0, Vector2i(1, 7))
	_make_unit("robert_baratheon.json", 0, Vector2i(1, 8))
	_make_unit("howland_reed.json",     0, Vector2i(1, 9))
	_make_unit("royal_soldier.json",    1, Vector2i(13, 4))
	_make_unit("royal_soldier.json",    1, Vector2i(11, 6))
	_make_unit("royal_soldier.json",    1, Vector2i(13, 7))
	_make_unit("royal_soldier.json",    1, Vector2i(12, 11))
	_make_unit("royal_soldier.json",    1, Vector2i(16, 9))
	_make_unit("royal_soldier.json",    1, Vector2i(17, 7))
	_redraw_all()
	await _play_dialogue("res://data/dialogues/prologue_1_pre.json")
	battle_won.connect(_on_won_ch1, CONNECT_ONE_SHOT)

func _on_won_ch1() -> void:
	if _result_panel: _result_panel.visible = false
	await _play_dialogue("res://data/dialogues/prologue_1_post.json")
	await _advance_to(2)

# ══════════════════════════════════════════════════════════
# 序章·二《三叉戟》
# ══════════════════════════════════════════════════════════
func _setup_ch2() -> void:
	map_width   = 28;  map_height = 20
	victory_pos = Vector2i(20, 9)
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH2)
	_make_unit("robert_baratheon.json",  0, Vector2i(2, 9))
	# 奈德在极乐塔线，三叉戟不出场
	_make_unit("rebel_lord.json",        0, Vector2i(2, 5))
	_make_unit("rebel_lord.json",        0, Vector2i(2, 13))
	_make_unit("rebel_lord.json",        0, Vector2i(3, 10))
	_rhaegar_unit = _make_unit_r("rhaegar_targaryen.json", 1, Vector2i(20, 9))
	_make_unit("barristan_selmy.json",    1, Vector2i(17, 5))
	_make_unit("targaryen_soldier.json",  1, Vector2i(14, 4))
	_make_unit("targaryen_soldier.json",  1, Vector2i(14, 8))
	_make_unit("targaryen_soldier.json",  1, Vector2i(14, 14))
	_make_unit("targaryen_soldier.json",  1, Vector2i(18, 4))
	_make_unit("targaryen_soldier.json",  1, Vector2i(22, 8))
	_make_unit("targaryen_soldier.json",  1, Vector2i(18, 14))
	_redraw_all()
	await _play_dialogue("res://data/dialogues/ch2_pre.json")
	battle_won.connect(_on_won_ch2, CONNECT_ONE_SHOT)

func _on_won_ch2() -> void:
	if _result_panel: _result_panel.visible = false
	await _play_cutscene("res://data/cutscenes/ch2_split.json")
	await _play_dialogue("res://data/dialogues/ch2_post.json")
	await _advance_to(3)

# ══════════════════════════════════════════════════════════
# 序章·三《极乐塔》
# ══════════════════════════════════════════════════════════
func _setup_ch3() -> void:
	map_width   = 24;  map_height = 18
	victory_pos = Vector2i(19, 9)
	_apply_cam_limits()
	super._ready()
	_paint_from(TERRAIN_CH3)
	_ned_unit  = _make_unit_r("ned_stark.json",       0, Vector2i(1, 9))
	_make_unit("howland_reed.json",    0, Vector2i(1, 10))
	_make_unit("northern_knight.json", 0, Vector2i(1, 8))
	_make_unit("northern_knight.json", 0, Vector2i(2, 11))
	_make_unit("northern_knight.json", 0, Vector2i(2, 7))
	_dayne_unit = _make_unit_r("arthur_dayne.json", 1, Vector2i(17, 9))
	_make_unit("dorne_knight.json", 1, Vector2i(13, 5))
	_make_unit("dorne_knight.json", 1, Vector2i(13, 11))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 7))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 9))
	_make_unit("dorne_knight.json", 1, Vector2i(15, 13))
	_redraw_all()
	await _play_dialogue("res://data/dialogues/ch3_pre.json")

# ══════════════════════════════════════════════════════════
# 序章·四《铁王座》
# ══════════════════════════════════════════════════════════
func _setup_ch4() -> void:
	map_width   = 36;  map_height = 26
	victory_pos = Vector2i(30, 12)
	_terrain_cache_ch4 = _build_map_ch4()
	_apply_cam_limits()
	if is_instance_valid(_cam):
		_cam.position = Vector2(640, 1152)
	super._ready()
	_paint_from(_terrain_cache_ch4)
	# 玩家单位（部署选择）
	var selection := GameState.deploy_selection.duplicate()
	if selection.is_empty():
		selection = ["ned_stark.json", "northern_knight.json", "northern_knight.json"]
	var spawns: Array = [Vector2i(2,22),Vector2i(3,22),Vector2i(4,22),
		Vector2i(2,23),Vector2i(3,23),Vector2i(4,23)]
	for i: int in min(selection.size(), spawns.size()):
		var u := _make_unit_r(selection[i], 0, spawns[i])
		if u != null and selection[i] == "ned_stark.json":
			_ned_unit = u
	# 兰尼斯特中立军
	for pos: Vector2i in [Vector2i(4,3),Vector2i(9,3),Vector2i(15,3),Vector2i(19,3)]:
		var u := _make_unit_r("lannister_soldier.json", 1, pos)
		if u != null:
			u.data.move = 0
			_lannister_units.append(u)
	# 王军
	_make_unit("royal_soldier.json", 1, Vector2i(6, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(6, 16))
	_make_unit("royal_soldier.json", 1, Vector2i(12, 16))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 8))
	_make_unit("royal_soldier.json", 1, Vector2i(18, 16))
	_royal_commander = _make_unit_r("royal_guard_captain.json", 1, Vector2i(20, 12))
	_make_unit("royal_soldier.json", 1, Vector2i(26, 10))
	_make_unit("royal_soldier.json", 1, Vector2i(26, 14))
	_make_unit("royal_soldier.json", 1, Vector2i(29, 11))
	_redraw_all()
	await _play_dialogue("res://data/dialogues/ch4_pre.json")

func _build_map_ch4() -> Array:
	const W := 36; const H := 26
	var m: Array = []
	for _y: int in H:
		var row: Array = []; for _x: int in W: row.append(0); m.append(row)
	for x: int in W: m[0][x] = 3; m[H-1][x] = 3
	for y: int in H: m[y][0] = 3; m[y][W-1] = 3
	for by: int in [2, 8, 14, 20]:
		for bx: int in [2, 8, 14, 20]:
			if by+2 < H-1 and bx+2 < W-1:
				for dy: int in 3:
					for dx: int in 3:
						if dy == 1 and dx == 1: continue
						m[by+dy][bx+dx] = 2
	for x: int in range(24, 35): m[7][x] = 2; m[18][x] = 2
	for y: int in range(7, 19):  m[y][24] = 2; m[y][34] = 2
	m[12][24] = 0
	for x: int in range(27, 34): m[9][x] = 2; m[16][x] = 2
	for y: int in range(9, 17):  m[y][27] = 2; m[y][33] = 2
	m[12][27] = 0; m[12][33] = 0
	for x: int in range(1, 24): m[5][x] = 2
	m[5][6] = 0; m[5][12] = 0; m[5][18] = 0
	return m

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
# 胜利条件覆盖（Ch2/3/4 使用非标准条件）
# ══════════════════════════════════════════════════════════
func _check_victory() -> void:
	if _battle_over: return
	match GameState.current_chapter:
		2:
			# 击败所有可击杀敌军（排除无敌单位 min_hp>0）
			var mortal := enemy_units.filter(func(u: Unit) -> bool:
				return not u.is_dead() and u.data.min_hp == 0)
			if mortal.is_empty() and not enemy_units.is_empty():
				_end_battle(true)
		3:
			# 奈德到达塔门
			if _tower_reached: return
			if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
					and _ned_unit.grid_pos == victory_pos:
				_tower_reached = true
				_trigger_ch3_tower()
		4:
			# 奈德到达铁王座
			if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
					and _ned_unit.grid_pos == victory_pos:
				_trigger_ch4_throne()
		_:
			super._check_victory()

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

# ── Ch2：雷加之死演出 ─────────────────────────────────────
func _trigger_ch2_rhaegar() -> void:
	_battle_over = true
	await _play_cutscene("res://data/cutscenes/ch2_rhaegar_fall.json")
	_battle_over = false
	_check_victory()

# ── Ch3：塔楼序列 ────────────────────────────────────────
func _trigger_ch3_tower() -> void:
	_battle_over = true
	await _play_cutscene("res://data/cutscenes/ch3_dayne_trigger.json")
	if is_instance_valid(_dayne_unit):
		enemy_units.erase(_dayne_unit); _dayne_unit.queue_free(); _redraw_all()
	await _play_cutscene("res://data/cutscenes/ch3_lyanna.json")
	await _play_dialogue("res://data/dialogues/ch3_post.json")
	await _advance_to(4)

# ── Ch4：兰军归降 ────────────────────────────────────────
func _trigger_ch4_lannister_join() -> void:
	await get_tree().create_timer(0.5).timeout
	for u: Unit in _lannister_units.duplicate():
		if is_instance_valid(u) and not u.is_dead():
			enemy_units.erase(u); u.queue_free()
	_lannister_units.clear()
	_redraw_all()
	_set_status("兰尼斯特军归降——道路畅通")

# ── Ch4：铁王座到达（詹姆过场+结局）────────────────────
func _trigger_ch4_throne() -> void:
	_battle_over = true
	_hide_all_panels()
	await _play_dialogue("res://data/dialogues/ch4_jaime.json")
	await _play_cutscene("res://data/cutscenes/ch4_jaime_scene.json")
	await _play_dialogue("res://data/dialogues/ch4_post.json")
	await _play_cutscene("res://data/cutscenes/ch4_ending.json")
	await _advance_to(0)  # 序章结束

# ── Ch4：_process 检测奈德接近红堡 ─────────────────────
func _process(delta: float) -> void:
	super._process(delta)
	if GameState.current_chapter == 4 and not _jaime_triggered \
			and not _battle_over:
		if is_instance_valid(_ned_unit) and not _ned_unit.is_dead() \
				and _ned_unit.grid_pos == Vector2i(25, 12):
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
		# 序章全部完成，返回开始界面
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
		if ResourceLoader.exists(pp): unit.set_meta("portrait_path", pp)
	add_unit(unit)
	return unit as Unit
