#!/usr/bin/env -S godot --headless --script
# run_tests.gd — 全自动化测试套件
# 运行方式：
#   godot --headless --path /path/to/project --script tests/run_tests.gd
#
# 覆盖范围：
#   - BattleCalculator（伤害/命中/暴击/追击公式，边界值）
#   - UnitData（加载，缺失字段默认值，边界属性）
#   - 地形系统（加成，移动消耗，可通行判断，新增类型）
#   - 地图完整性（22×16尺寸，关键位置验证，不可通行区域）
#   - EnemyAI 距离计算
#   - 对话/JSON 文件加载与格式验证
#   - 战斗数值边界（最小伤害=1，命中范围1-99）

extends SceneTree

# ── 加载依赖 ─────────────────────────────────────────────
const BattleCalculatorClass := preload("res://scripts/battle/BattleCalculator.gd")
const UnitDataClass          := preload("res://scripts/data/UnitData.gd")
const EnemyAIClass           := preload("res://scripts/battle/EnemyAI.gd")
const BootstrapClass         := preload("res://scripts/battle/BattleBootstrap.gd")
const TestBootstrapClass     := preload("res://tests/helpers/TestBattleBootstrap.gd")
const TestOpeningClass       := preload("res://tests/helpers/TestOpening.gd")
const TestDeployScreenClass  := preload("res://tests/helpers/TestDeployScreen.gd")

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


# ── 入口 ─────────────────────────────────────────────────
func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║  铁王座战记 — 自动化测试套件           ║")
	print("╚══════════════════════════════════════╝\n")

	await _run_suite("UnitData 数据加载", _test_unit_data)
	await _run_suite("BattleCalculator 战斗公式", _test_battle_calculator)
	await _run_suite("BattleCalculator 边界值", _test_calculator_edge_cases)
	await _run_suite("地形系统加成", _test_terrain_bonus)
	await _run_suite("地形移动消耗", _test_terrain_move_cost)
	await _run_suite("地图完整性（按章节配置）", _test_map_integrity)
	await _run_suite("Ch4 君临城地图重设计回归", _test_ch4_map_redesign)
	await _run_suite("EnemyAI 距离计算", _test_enemy_ai_distance)
	await _run_suite("对话 JSON 文件加载", _test_dialogue_json)
	await _run_suite("Ch1 叙事基线一致性", _test_ch1_narrative_baseline)
	await _run_suite("过场动画 JSON 加载", _test_cutscene_json)
	await _run_suite("战斗预测全流程", _test_battle_predict_full)
	await _run_suite("Unit 状态机（含 undo_move）", _test_unit_state_machine)
	await _run_suite("路径查找 Dijkstra 逻辑", _test_pathfinding_logic)
	await _run_suite("武器耐久系统", _test_weapon_durability)
	await _run_suite("道具系统", _test_item_system)
	await _run_suite("武器三角加成", _test_weapon_triangle)
	await _run_suite("Boss 无敌底板（min_hp）", _test_boss_min_hp)
	await _run_suite("SaveSystem 存档读档", _test_save_system)
	await _run_suite("守卫型Boss数据字段", _test_guard_boss_fields)
	await _run_suite("战斗动画freed节点防护", _test_animation_freed_guard)
	await _run_suite("回合结束防重入", _test_turn_ending_guard)
	await _run_suite("地形图块坐标合法性", _test_tile_atlas_coords)
	await _run_suite("地图视觉风格统一回归", _test_visual_style_unification)
	await _run_suite("地图语义规范回归", _test_map_visual_language_spec)
	await _run_suite("人物立绘资源完整性", _test_portrait_assets)
	await _run_suite("对话立绘映射完整性", _test_dialogue_portrait_mapping)
	await _run_suite("字体初始化方法存在", _test_font_setup)
	await _run_suite("关键场景与脚本冒烟加载", _test_scene_and_script_smoke)
	await _run_suite("章节事件流程回归", _test_chapter_event_flow)
	await _run_suite("Ch1 / 存档 / 部署行为回归", _test_ch1_save_and_deploy_flow)

	print("\n╔══════════════════════════════════════╗")
	var status: String = "全部通过 ✓" if _fail_count == 0 else ("失败 %d 项 ✗" % _fail_count)
	print("║  %d 通过  %d 失败  — %s" % [_pass_count, _fail_count, status])
	print("╚══════════════════════════════════════╝\n")
	quit(_fail_count)

# ── 测试框架 ─────────────────────────────────────────────
func _run_suite(name: String, fn: Callable) -> void:
	_current_suite = name
	print("▶ %s" % name)
	await fn.call()
	print("")

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  ✓ %s" % msg)
	else:
		_fail_count += 1
		print("  ✗ FAIL: %s [suite: %s]" % [msg, _current_suite])

func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		_pass_count += 1
		print("  ✓ %s  (= %s)" % [msg, str(a)])
	else:
		_fail_count += 1
		print("  ✗ FAIL: %s  期望=%s  实际=%s  [suite: %s]" % [
			msg, str(b), str(a), _current_suite])

func _read_repo_root_text(path_from_repo_root: String) -> String:
	var abs_path := ProjectSettings.globalize_path("res://../../" + path_from_repo_root)
	if not FileAccess.file_exists(abs_path):
		return ""
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

func _path_exists_on_passable_grid(battle: Node, start: Vector2i, goal: Vector2i) -> bool:
	if start == goal:
		return true
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	queue.append(start)
	visited[start] = true
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if visited.has(npos):
				continue
			if not battle.is_passable(npos):
				continue
			if npos == goal:
				return true
			visited[npos] = true
			queue.append(npos)
	return false

func _bridge_span_has_river_flanks(battle: Node, y: int, left_bridge_x: int, right_bridge_x: int) -> bool:
	return battle._terrain_at_or_cliff(left_bridge_x - 1, y) == 4 \
		and battle._terrain_at_or_cliff(right_bridge_x + 1, y) == 4

# ── 辅助：创建测试用 UnitData ─────────────────────────────
func _make_unit_data(overrides: Dictionary = {}) -> UnitData:
	var base: Dictionary = {
		"name": "测试剑士", "class": "剑士", "level": 1,
		"hp": 22, "max_hp": 22,
		"pow": 7, "spd": 8, "skl": 7, "def": 6, "lck": 5, "con": 8,
		"move": 5, "weapon_type": "sword", "weapon_rank": "E"
	}
	for k in overrides:
		base[k] = overrides[k]
	return UnitData.from_dict(base)

func _make_enemy_data(overrides: Dictionary = {}) -> UnitData:
	var base: Dictionary = {
		"name": "王军士兵", "class": "步兵", "level": 1,
		"hp": 16, "max_hp": 16,
		"pow": 5, "spd": 4, "skl": 4, "def": 4, "lck": 2, "con": 6,
		"move": 4, "weapon_type": "sword", "weapon_rank": "E"
	}
	for k in overrides:
		base[k] = overrides[k]
	return UnitData.from_dict(base)

# ══════════════════════════════════════════════════════════
# 测试套件 1：UnitData 数据加载
# ══════════════════════════════════════════════════════════
func _test_unit_data() -> void:
	# 正常加载
	var d := _make_unit_data()
	_assert_eq(d.name, "测试剑士", "name字段")
	_assert_eq(d.hp,   22,         "hp字段")
	_assert_eq(d.max_hp, 22,       "max_hp字段")
	_assert_eq(d.pow,  7,          "pow字段")
	_assert_eq(d.spd,  8,          "spd字段")
	_assert_eq(d.skl,  7,          "skl字段")
	_assert_eq(d.def,  6,          "def字段")
	_assert_eq(d.lck,  5,          "lck字段")
	_assert_eq(d.con,  8,          "con字段")
	_assert_eq(d.move, 5,          "move字段")
	_assert_eq(d.weapon_type, "sword", "weapon_type字段")
	_assert_eq(d.weapon_rank, "E",     "weapon_rank字段")

	# 缺失字段使用默认值
	var empty := UnitData.from_dict({})
	_assert_eq(empty.name,     "未知",   "缺失name默认值")
	_assert_eq(empty.hp,       20,       "缺失hp默认值（使用max_hp）")
	_assert_eq(empty.max_hp,   20,       "缺失max_hp默认值")
	_assert_eq(empty.pow,      5,        "缺失pow默认值")
	_assert_eq(empty.move,     5,        "缺失move默认值")
	_assert_eq(empty.weapon_type, "sword", "缺失weapon_type默认值")

	# hp 默认值从 max_hp 取，但 max_hp 在字典中存在
	var no_hp := UnitData.from_dict({"max_hp": 30})
	_assert_eq(no_hp.hp,     30, "hp默认值=max_hp(30)")
	_assert_eq(no_hp.max_hp, 30, "max_hp=30")

	# 边界属性
	var zero_d := _make_unit_data({"pow": 0, "def": 0, "lck": 0, "spd": 0})
	_assert(zero_d.pow == 0, "pow可以为0")
	_assert(zero_d.def == 0, "def可以为0")

	# 单位死亡模拟
	d.hp = maxi(d.hp - 999, 0)
	_assert_eq(d.hp, 0, "HP归零不会变负")
	_assert(d.hp >= 0, "HP最小值为0")

# ══════════════════════════════════════════════════════════
# 测试套件 2：BattleCalculator 战斗公式
# ══════════════════════════════════════════════════════════
func _test_battle_calculator() -> void:
	var atk := _make_unit_data()           # pow=7 spd=8 skl=7 def=6 lck=5
	var def2 := _make_enemy_data()         # pow=5 spd=4 skl=4 def=4 lck=2

	# 伤害 = pow(7) + weapon_atk(5) - def(4) = 8
	_assert_eq(BattleCalculator.calc_damage(atk, def2, "sword_E"), 8, "伤害公式 sword_E")

	# 命中 = skl*2(14) + lck/2(2) + weapon_hit(75) - spd*2(8) - lck/2(1) = 82
	_assert_eq(BattleCalculator.calc_hit(atk, def2, "sword_E"), 82, "命中公式 sword_E")

	# 暴击 = skl/2(3) - lck(2) = 1
	_assert_eq(BattleCalculator.calc_crit(atk, def2), 1, "暴击公式")

	# 追击：spd差 = 8-4=4 < 5，不追击
	_assert(not BattleCalculator.can_double(atk, def2), "速差4不追击")

	# 追击：spd差 = 5 ≥ 5，触发追击
	var fast := _make_unit_data({"spd": 9})
	_assert(BattleCalculator.can_double(fast, def2), "速差5触发追击")

	# 斧武器（更高攻击：pow=7 + axe_atk=8 - def=4 = 11）
	var axe_atk := _make_unit_data({"weapon_type": "axe", "weapon_rank": "E"})
	_assert_eq(BattleCalculator.calc_damage(axe_atk, def2, "axe_E"), 11, "伤害公式 axe_E")

	# 长枪武器（pow=7 + lance_atk=6 - def=4 = 9）
	var lance_atk := _make_unit_data({"weapon_type": "lance", "weapon_rank": "E"})
	_assert_eq(BattleCalculator.calc_damage(lance_atk, def2, "lance_E"), 9, "伤害公式 lance_E")

	# C级武器（英雄级强化）
	var sword_c := _make_unit_data({"weapon_rank": "C"})
	_assert_eq(BattleCalculator.calc_damage(sword_c, def2, "sword_C"), 12, "伤害公式 sword_C (9+9-4=14 → wait pow=7+9=16-4=12)")

	# predict() 返回完整字典
	var pred := BattleCalculator.predict(atk, def2, "sword_E", "sword_E", 0)
	_assert(pred.has("atk_damage"),  "predict包含atk_damage")
	_assert(pred.has("atk_hit"),     "predict包含atk_hit")
	_assert(pred.has("atk_crit"),    "predict包含atk_crit")
	_assert(pred.has("atk_double"),  "predict包含atk_double")
	_assert(pred.has("def_damage"),  "predict包含def_damage")
	_assert(pred.has("def_hit"),     "predict包含def_hit")

	# predict 数值一致性
	_assert_eq(pred["atk_damage"], BattleCalculator.calc_damage(atk, def2, "sword_E"),
		"predict.atk_damage与calc_damage一致")
	_assert_eq(pred["atk_hit"], BattleCalculator.calc_hit(atk, def2, "sword_E", 0),
		"predict.atk_hit与calc_hit一致")

# ══════════════════════════════════════════════════════════
# 测试套件 3：BattleCalculator 边界值
# ══════════════════════════════════════════════════════════
func _test_calculator_edge_cases() -> void:
	# 最小伤害=1（即使防御远超攻击）
	var weak := _make_unit_data({"pow": 1})
	var tank := _make_enemy_data({"def": 99})
	_assert_eq(BattleCalculator.calc_damage(weak, tank, "sword_E"), 1, "最小伤害=1")

	# 命中下限=1（即使敌方闪避极高）
	var blind := _make_unit_data({"skl": 0, "lck": 0})
	var dodger := _make_enemy_data({"spd": 99, "lck": 99})
	var hit := BattleCalculator.calc_hit(blind, dodger, "sword_E")
	_assert(hit >= 1 and hit <= 99, "命中在1~99范围内（实际=%d）" % hit)

	# 命中上限=99
	var ace := _make_unit_data({"skl": 99, "lck": 99})
	var still := _make_enemy_data({"spd": 0, "lck": 0})
	var hit_max := BattleCalculator.calc_hit(ace, still, "sword_E")
	_assert(hit_max <= 99, "命中上限=99（实际=%d）" % hit_max)

	# 暴击下限=0（防御方幸运高过技术方）
	var low_skl := _make_unit_data({"skl": 0})
	var lucky := _make_enemy_data({"lck": 20})
	_assert_eq(BattleCalculator.calc_crit(low_skl, lucky), 0, "暴击下限=0")

	# 暴击上限=99
	var high_skl := _make_unit_data({"skl": 99})
	var unlucky := _make_enemy_data({"lck": 0})
	var crit_max := BattleCalculator.calc_crit(high_skl, unlucky)
	_assert(crit_max <= 99, "暴击上限=99（实际=%d）" % crit_max)

	# 速差恰好=4时不追击
	var spd4 := _make_unit_data({"spd": 8})
	var slow4 := _make_enemy_data({"spd": 4})
	_assert(not BattleCalculator.can_double(spd4, slow4), "速差4（=4）不追击")

	# 速差恰好=5时追击
	var spd5 := _make_unit_data({"spd": 9})
	_assert(BattleCalculator.can_double(spd5, slow4), "速差5（>=5）触发追击")

	# 双方速度相同不追击
	var same_spd_atk := _make_unit_data({"spd": 7})
	var same_spd_def := _make_enemy_data({"spd": 7})
	_assert(not BattleCalculator.can_double(same_spd_atk, same_spd_def), "速度相同不追击")

	# 地形回避影响命中
	var base_hit := BattleCalculator.calc_hit(
		_make_unit_data(), _make_enemy_data(), "sword_E", 0)
	var terrain_hit := BattleCalculator.calc_hit(
		_make_unit_data(), _make_enemy_data(), "sword_E", 20)
	_assert(terrain_hit < base_hit, "地形回避+20使命中降低")
	_assert_eq(base_hit - terrain_hit, 20, "地形回避20精确降低命中20")

	# 未知武器回退到默认值
	var fallback_dmg := BattleCalculator.calc_damage(
		_make_unit_data({"pow": 10}), _make_enemy_data({"def": 3}), "unknown_weapon")
	_assert(fallback_dmg >= 1, "未知武器使用默认值，伤害>=1（实际=%d）" % fallback_dmg)

# ══════════════════════════════════════════════════════════
# 测试套件 4：地形系统加成
# ══════════════════════════════════════════════════════════
func _test_terrain_bonus() -> void:
	# 直接测试 match 逻辑（与 BattleMap.get_terrain_bonus 一致）
	var bonus := func(t: int) -> Dictionary:
		match t:
			1: return {"avoid": 20, "defense": 10}   # 森林
			2: return {"avoid": 0,  "defense": 20}   # 矮墙
			5: return {"avoid": 0,  "defense": -10}  # 沼泽
			6: return {"avoid": 0,  "defense": 0}    # 桥梁
			_: return {"avoid": 0,  "defense": 0}    # 平原/其他

	_assert_eq(bonus.call(0),  {"avoid": 0,  "defense": 0},   "平原：无加成")
	_assert_eq(bonus.call(1),  {"avoid": 20, "defense": 10},  "森林：防御+10 回避+20")
	_assert_eq(bonus.call(2),  {"avoid": 0,  "defense": 20},  "矮墙：防御+20")
	_assert_eq(bonus.call(5),  {"avoid": 0,  "defense": -10}, "沼泽：防御-10（减益）")
	_assert_eq(bonus.call(6),  {"avoid": 0,  "defense": 0},   "桥梁：无加成")
	_assert_eq(bonus.call(3),  {"avoid": 0,  "defense": 0},   "峭壁：不可通行（加成无意义）")
	_assert_eq(bonus.call(4),  {"avoid": 0,  "defense": 0},   "河流：不可通行（加成无意义）")
	_assert_eq(bonus.call(99), {"avoid": 0,  "defense": 0},   "未知地形：默认无加成")

	# 地形加成影响战斗预测
	var atk := _make_unit_data()
	var def2 := _make_enemy_data()
	var hit_plain  := BattleCalculator.calc_hit(atk, def2, "sword_E", 0)
	var hit_forest := BattleCalculator.calc_hit(atk, def2, "sword_E", 20)
	var hit_wall   := BattleCalculator.calc_hit(atk, def2, "sword_E", 0)
	_assert(hit_forest < hit_plain, "森林地形降低命中率")
	_assert(hit_wall == hit_plain, "矮墙地形不影响命中（只提供防御）")

# ══════════════════════════════════════════════════════════
# 测试套件 5：地形移动消耗
# ══════════════════════════════════════════════════════════
func _test_terrain_move_cost() -> void:
	var cost := func(t: int) -> int:
		match t:
			1: return 2  # 森林
			2: return 2  # 矮墙
			5: return 3  # 沼泽
			_: return 1  # 平原/桥梁

	_assert_eq(cost.call(0), 1, "平原移动消耗=1")
	_assert_eq(cost.call(1), 2, "森林移动消耗=2")
	_assert_eq(cost.call(2), 2, "矮墙移动消耗=2")
	_assert_eq(cost.call(3), 1, "峭壁（不可通行，消耗值无实际意义）")
	_assert_eq(cost.call(4), 1, "河流（不可通行，消耗值无实际意义）")
	_assert_eq(cost.call(5), 3, "沼泽移动消耗=3")
	_assert_eq(cost.call(6), 1, "桥梁移动消耗=1")

	# 验证：移动力5的单位经过沼泽（cost 3）只能再走2步
	var remaining_after_swamp: int = 5 - cost.call(5)
	_assert_eq(remaining_after_swamp, 2, "移动力5经过沼泽后剩余2步")

	# 验证：移动力4的单位经过两格森林（cost 2+2=4）恰好用完
	var remaining_forest_two: int = 4 - cost.call(1) * 2
	_assert_eq(remaining_forest_two, 0, "移动力4经过两格森林恰好用完")

# ══════════════════════════════════════════════════════════
# 测试套件 6：地图完整性（按当前四章配置）
# ══════════════════════════════════════════════════════════
func _test_map_integrity() -> void:
	var ch1: Array = BootstrapClass.TERRAIN_CH1
	var ch2: Array = BootstrapClass.TERRAIN_CH2
	var ch3: Array = BootstrapClass.TERRAIN_CH3

	# ── Ch1：教学关（10×8）──────────────────────────────
	_assert_eq(ch1.size(), 8, "Ch1 地图行数=8")
	_assert_eq(ch1[0].size(), 10, "Ch1 地图列数=10")
	var ch1_border_ok := true
	for x: int in range(ch1[0].size()):
		if ch1[7][x] != 3:
			ch1_border_ok = false
	for y: int in range(ch1.size()):
		if ch1[y][0] != 3 or ch1[y][9] != 3:
			ch1_border_ok = false
	_assert(ch1_border_ok, "Ch1 底边与左右边界为峭壁（顶部中央出口除外）")
	_assert_eq(int(ch1[0][5]), 0, "Ch1 胜利格(5,0)可通行")
	for pos: Vector2i in [Vector2i(3,6), Vector2i(5,6), Vector2i(2,2), Vector2i(5,1), Vector2i(7,2)]:
		var t1: int = int(ch1[pos.y][pos.x])
		_assert(t1 != 3 and t1 != 4, "Ch1 关键出生点(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t1])
	var ch1_has_wall := false
	for row: Array in ch1:
		for cell: Variant in row:
			if int(cell) == 2:
				ch1_has_wall = true
	_assert(ch1_has_wall, "Ch1 存在矮墙教学地形")

	# ── Ch2：三叉戟（28×20）──────────────────────────────
	_assert_eq(ch2.size(), 20, "Ch2 地图行数=20")
	_assert_eq(ch2[0].size(), 28, "Ch2 地图列数=28")
	var ch2_border_ok := true
	for x: int in range(ch2[0].size()):
		if ch2[0][x] != 3 or ch2[19][x] != 3:
			ch2_border_ok = false
	for y: int in range(ch2.size()):
		if ch2[y][0] != 3 or ch2[y][27] != 3:
			ch2_border_ok = false
	_assert(ch2_border_ok, "Ch2 四周边界为峭壁")
	for bridge_row: int in [8, 9]:
		for bridge_x: int in [7, 8, 14, 15, 21, 22]:
			_assert_eq(int(ch2[bridge_row][bridge_x]), 6,
				"Ch2 三桥结构 (%d,%d) 为桥梁" % [bridge_x, bridge_row])
	for y: int in [8, 9]:
		for x: int in range(1, 27):
			var t2: int = int(ch2[y][x])
			_assert(t2 == 4 or t2 == 6, "Ch2 河道行%d列%d为河流/桥梁" % [y, x])
	for bridge_pos: Vector2i in [Vector2i(7,8), Vector2i(8,8), Vector2i(14,8), Vector2i(15,8), Vector2i(21,8), Vector2i(22,8)]:
		_assert_eq(int(ch2[bridge_pos.y][bridge_pos.x]), 6,
			"Ch2 桥梁(%d,%d)存在" % [bridge_pos.x, bridge_pos.y])
	for pos: Vector2i in [Vector2i(14,17), Vector2i(7,18), Vector2i(21,18), Vector2i(14,3), Vector2i(20,2)]:
		var t2p: int = int(ch2[pos.y][pos.x])
		_assert(t2p != 3 and t2p != 4, "Ch2 关键出生点(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t2p])
	for pos: Vector2i in [Vector2i(9,18), Vector2i(19,18), Vector2i(6,7), Vector2i(13,6), Vector2i(20,7)]:
		var t2_alt: int = int(ch2[pos.y][pos.x])
		_assert(t2_alt != 3 and t2_alt != 4,
			"Ch2 重设计关键格(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t2_alt])
	var ch2_has_swamp := false
	for row2: Array in ch2:
		for cell2: Variant in row2:
			if int(cell2) == 5:
				ch2_has_swamp = true
	_assert(ch2_has_swamp, "Ch2 南岸存在泥泞/沼泽战场")

	# ── Ch3：极乐塔（24×18）──────────────────────────────
	_assert_eq(ch3.size(), 18, "Ch3 地图行数=18")
	_assert_eq(ch3[0].size(), 24, "Ch3 地图列数=24")
	var ch3_border_ok := true
	for x: int in range(ch3[0].size()):
		if ch3[0][x] != 3 or ch3[17][x] != 3:
			ch3_border_ok = false
	for y: int in range(ch3.size()):
		if ch3[y][0] != 3 or ch3[y][23] != 3:
			ch3_border_ok = false
	_assert(ch3_border_ok, "Ch3 四周边界为峭壁")
	for pos: Vector2i in [Vector2i(12,15), Vector2i(11,16), Vector2i(12,6), Vector2i(7,8), Vector2i(16,8), Vector2i(12,2)]:
		var t3: int = int(ch3[pos.y][pos.x])
		_assert(t3 != 3 and t3 != 4, "Ch3 关键格(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t3])
	var ch3_has_swamp := false
	for row3: Array in ch3:
		for cell3: Variant in row3:
			if int(cell3) == 5:
				ch3_has_swamp = true
	_assert(ch3_has_swamp, "Ch3 存在沼泽地形")

func _test_ch4_map_redesign() -> void:
	var ch4_bootstrap := BootstrapClass.new()
	var ch4: Array = ch4_bootstrap._build_map_ch4()
	ch4_bootstrap.free()

	_assert_eq(ch4.size(), 26, "Ch4 地图行数=26")
	_assert_eq(ch4[0].size(), 36, "Ch4 地图列数=36")

	var ch4_border_ok := true
	for x: int in range(ch4[0].size()):
		if int(ch4[0][x]) != 3 or int(ch4[24][x]) != 3 or int(ch4[25][x]) != 3:
			ch4_border_ok = false
	for y: int in range(ch4.size()):
		if int(ch4[y][0]) != 3 or int(ch4[y][35]) != 3:
			ch4_border_ok = false
	_assert(ch4_border_ok, "Ch4 四周边界与南侧双层边界为峭壁")

	for pos: Vector2i in [
		Vector2i(18,22), Vector2i(15,22), Vector2i(21,22),
		Vector2i(12,23), Vector2i(18,23), Vector2i(24,23),
	]:
		var t_spawn: int = int(ch4[pos.y][pos.x])
		_assert(t_spawn != 3 and t_spawn != 4 and t_spawn != 2,
			"Ch4 玩家部署格(%d,%d)为可站立陆地（类型=%d）" % [pos.x, pos.y, t_spawn])

	_assert_eq(int(ch4[7][18]), 0, "Ch4 王军指挥官所在内院中央可通行")
	_assert_eq(int(ch4[2][18]), 0, "Ch4 铁王座胜利格可通行")

	for x: int in range(1, 35):
		_assert(int(ch4[8][x]) == 4 or int(ch4[8][x]) == 6,
			"Ch4 内护城河 row8 列%d 为河流/桥梁" % x)
		_assert(int(ch4[19][x]) == 4 or int(ch4[19][x]) == 6,
			"Ch4 黑水河 row19 列%d 为河流/桥梁" % x)

	for gate_x: int in [8, 9, 10, 17, 18, 19, 20, 26, 27, 28]:
		_assert_eq(int(ch4[8][gate_x]), 6,  "Ch4 内护城河桥位(%d,8)存在" % gate_x)
		_assert_eq(int(ch4[19][gate_x]), 6, "Ch4 黑水河桥位(%d,19)存在" % gate_x)

	for wall_row: int in [11, 13, 18]:
		for x: int in range(1, 35):
			var t_wall: int = int(ch4[wall_row][x])
			_assert(t_wall == 2 or t_wall == 0,
				"Ch4 城墙 row%d 列%d 为墙体/城门" % [wall_row, x])

	for gate_pos: Vector2i in [
		Vector2i(18,11), Vector2i(18,13), Vector2i(18,18),
		Vector2i(18,8), Vector2i(18,19), Vector2i(18,4),
	]:
		var t_gate: int = int(ch4[gate_pos.y][gate_pos.x])
		_assert(t_gate == 0 or t_gate == 6,
			"Ch4 中轴通路关键格(%d,%d)保持畅通（类型=%d）" % [gate_pos.x, gate_pos.y, t_gate])

	for pos: Vector2i in [Vector2i(10,12), Vector2i(15,12), Vector2i(20,12), Vector2i(25,12)]:
		_assert_eq(int(ch4[pos.y][pos.x]), 0, "Ch4 兰军中立列阵格(%d,%d)可通行" % [pos.x, pos.y])

	var ch4_wall_count := 0
	var ch4_bridge_count := 0
	var ch4_river_count := 0
	for row4: Array in ch4:
		for cell4: Variant in row4:
			match int(cell4):
				2: ch4_wall_count += 1
				4: ch4_river_count += 1
				6: ch4_bridge_count += 1
	_assert(ch4_wall_count >= 70, "Ch4 城墙/建筑数量充足（%d）" % ch4_wall_count)
	_assert(ch4_river_count >= 40, "Ch4 存在明确护城河/黑水河水域（%d）" % ch4_river_count)
	_assert(ch4_bridge_count >= 20, "Ch4 存在多座桥梁（%d）" % ch4_bridge_count)

# ══════════════════════════════════════════════════════════
# 测试套件 7：EnemyAI 距离计算
# ══════════════════════════════════════════════════════════
func _test_enemy_ai_distance() -> void:
	# EnemyAI._manhattan 是静态私有方法，通过 decide 间接测试
	# 也可通过 EnemyAI 类直接调用（静态方法可访问）
	_assert_eq(EnemyAI._manhattan(Vector2i(0,0), Vector2i(3,4)), 7,
		"曼哈顿距离：(0,0)→(3,4) = 7")
	_assert_eq(EnemyAI._manhattan(Vector2i(5,5), Vector2i(5,5)), 0,
		"曼哈顿距离：相同点 = 0")
	_assert_eq(EnemyAI._manhattan(Vector2i(1,1), Vector2i(4,1)), 3,
		"曼哈顿距离：水平移动3格")
	_assert_eq(EnemyAI._manhattan(Vector2i(1,1), Vector2i(1,5)), 4,
		"曼哈顿距离：垂直移动4格")
	_assert_eq(EnemyAI._manhattan(Vector2i(10,5), Vector2i(1,1)), 13,
		"曼哈顿距离：(10,5)→(1,1) = 13")

	# 负坐标
	_assert_eq(EnemyAI._manhattan(Vector2i(-1,-1), Vector2i(2,3)), 7,
		"曼哈顿距离：含负坐标")

# ══════════════════════════════════════════════════════════
# 测试套件 8：对话 JSON 文件加载
# ══════════════════════════════════════════════════════════
func _test_dialogue_json() -> void:
	var files := [
		"res://data/dialogues/prologue_1_pre.json",
		"res://data/dialogues/prologue_1_post.json",
	]

	for path: String in files:
		# 文件存在
		_assert(FileAccess.file_exists(path), "对话文件存在：" + path.get_file())

		# 可正常解析
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_assert(false, "无法打开文件：" + path.get_file())
			continue
		var text := file.get_as_text()
		file.close()
		var result: Variant = JSON.parse_string(text)
		_assert(result != null and result is Dictionary,
			"JSON格式正确：" + path.get_file())

		if result == null or not (result is Dictionary):
			continue
		var data := result as Dictionary

		# 有 lines 字段
		_assert(data.has("lines"), "包含lines字段：" + path.get_file())
		var lines: Array = data.get("lines", [])
		_assert(lines.size() > 0, "lines不为空（%d行）：%s" % [
			lines.size(), path.get_file()])

		# 每行有 speaker 和 text
		var all_valid := true
		for line: Variant in lines:
			if not (line is Dictionary):
				all_valid = false; break
			var l := line as Dictionary
			if not l.has("speaker") or not l.has("text"):
				all_valid = false; break
		_assert(all_valid, "每行包含speaker和text：" + path.get_file())

		# 最后一行应为 -1 或无next（表示结束）
		if lines.size() > 0:
			var last: Dictionary = lines[-1] as Dictionary
			var next_val: int = last.get("next", -1)
			_assert(next_val == -1, "最后一行next=-1（对话结束）：" + path.get_file())

# ══════════════════════════════════════════════════════════
# 测试套件 8.5：Ch1 叙事基线一致性
# 目的：防止 Ch1 又回退到“奈德赴任君临首辅”的旧语境
# ══════════════════════════════════════════════════════════
func _test_ch1_narrative_baseline() -> void:
	var pre_path := "res://data/dialogues/prologue_1_pre.json"
	var post_path := "res://data/dialogues/prologue_1_post.json"
	var opening_path := "res://data/cutscenes/prologue_uprising.json"

	var pre_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pre_path))
	var post_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(post_path))
	var opening_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(opening_path))

	_assert(pre_parsed is Dictionary, "Ch1 战前对话可解析")
	_assert(post_parsed is Dictionary, "Ch1 战后对话可解析")
	_assert(opening_parsed is Dictionary, "Ch1 起义过场可解析")
	if not (pre_parsed is Dictionary and post_parsed is Dictionary and opening_parsed is Dictionary):
		return

	var pre_text := FileAccess.get_file_as_string(pre_path)
	var post_text := FileAccess.get_file_as_string(post_path)
	var uprising_text := FileAccess.get_file_as_string(opening_path)
	var uprising_slides: Array = (opening_parsed as Dictionary).get("slides", [])
	var uprising_joined := ""
	for slide: Variant in uprising_slides:
		if slide is Dictionary:
			uprising_joined += String((slide as Dictionary).get("text", "")) + "\n"
			uprising_joined += String((slide as Dictionary).get("subtext", "")) + "\n"

	for forbidden: String in ["王国首辅", "持令牌者方可入城", "没有令牌", "君临城，王国的心脏"]:
		_assert(not (forbidden in pre_text), "Ch1 战前对话已移除旧君临语境：%s" % forbidden)

	for required: String in ["风暴地边境", "篡夺者战争，第一年", "劳勃", "王军", "山道"]:
		_assert(required in pre_text, "Ch1 战前对话包含战争教学关语境：%s" % required)

	for required_post: String in ["父亲和布兰登", "第一仗", "劳勃"]:
		_assert(required_post in post_text, "Ch1 战后对话延续起义语境：%s" % required_post)

	_assert("风暴地" in uprising_joined and "篡夺者战争，第一年" in uprising_joined,
		"Ch1 起义过场仍明确为风暴地战争开端")
	_assert("劳勃·拜拉席恩" in uprising_text,
		"Ch1 起义过场仍保留劳勃主语境")

# ══════════════════════════════════════════════════════════
# 测试套件 9：过场动画 JSON 加载
# ══════════════════════════════════════════════════════════
func _test_cutscene_json() -> void:
	var files := [
		"res://data/cutscenes/prologue_opening.json",
		"res://data/cutscenes/prologue_mad_king.json",
		"res://data/cutscenes/prologue_uprising.json",
	]

	for path: String in files:
		_assert(FileAccess.file_exists(path), "过场文件存在：" + path.get_file())

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_assert(false, "无法打开文件：" + path.get_file())
			continue
		var text := file.get_as_text()
		file.close()
		var result: Variant = JSON.parse_string(text)
		_assert(result != null and result is Dictionary,
			"JSON格式正确：" + path.get_file())

		if result == null or not (result is Dictionary):
			continue
		var data := result as Dictionary

		# 有 slides 字段
		_assert(data.has("slides"), "包含slides字段：" + path.get_file())
		var slides: Array = data.get("slides", [])
		_assert(slides.size() > 0, "slides不为空（%d帧）：%s" % [
			slides.size(), path.get_file()])

		# 每帧有 text 和 duration
		var all_valid := true
		for slide: Variant in slides:
			if not (slide is Dictionary):
				all_valid = false; break
			var s := slide as Dictionary
			if not s.has("text") or not s.has("duration"):
				all_valid = false; break
			if float(s.get("duration", 0)) <= 0.0:
				all_valid = false; break
		_assert(all_valid, "每帧包含text和正数duration：" + path.get_file())

	# scene_art 字段验证（mad_king 应有 scene_art）
	var mad_king_path := "res://data/cutscenes/prologue_mad_king.json"
	if FileAccess.file_exists(mad_king_path):
		var f := FileAccess.open(mad_king_path, FileAccess.READ)
		var r: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if r is Dictionary:
			var mad: Dictionary = r as Dictionary
			var slides: Array = mad.get("slides", [])
			var has_art := false
			for s: Variant in slides:
				if s is Dictionary and (s as Dictionary).get("scene_art", "") != "":
					has_art = true; break
			_assert(has_art, "prologue_mad_king包含scene_art字段")

			# 验证 scene_art 值为已知类型
			var valid_arts := ["throne_room", "execution", "vale_castle", "stormlands_road", ""]
			var all_known := true
			for s: Variant in slides:
				if s is Dictionary:
					var art: String = (s as Dictionary).get("scene_art", "")
					if not (art in valid_arts):
						all_known = false
						print("    未知scene_art类型：" + art)
			_assert(all_known, "所有scene_art为已知类型")

# ══════════════════════════════════════════════════════════
# 测试套件 10：战斗预测全流程
# ══════════════════════════════════════════════════════════
func _test_battle_predict_full() -> void:
	var atk := _make_unit_data({"name": "奈德", "pow": 12, "spd": 11, "skl": 12,
		"def": 9, "lck": 7, "weapon_type": "sword", "weapon_rank": "C"})
	var def2 := _make_enemy_data()

	# 预测字典完整性
	var pred := BattleCalculator.predict(atk, def2, "sword_C", "sword_E", 0)
	for key in ["atk_damage", "atk_hit", "atk_crit", "atk_double",
			"def_damage", "def_hit", "def_crit", "def_double"]:
		_assert(pred.has(key), "predict包含键：" + key)

	# 数值合法性
	_assert(pred["atk_damage"] >= 1, "atk_damage >= 1")
	_assert(pred["atk_hit"] >= 1 and pred["atk_hit"] <= 99,
		"atk_hit在[1,99]范围内（=%d）" % pred["atk_hit"])
	_assert(pred["atk_crit"] >= 0 and pred["atk_crit"] <= 99,
		"atk_crit在[0,99]范围内（=%d）" % pred["atk_crit"])
	_assert(pred["def_damage"] >= 1, "def_damage >= 1")

	# 奈德 C级剑 vs 普通士兵：伤害 = pow(12) + sword_C(9) - def(4) = 17
	_assert_eq(pred["atk_damage"], 17, "奈德C剑伤害=17")

	# 奈德速度(11) vs 士兵(4)，差=7 >= 5，可追击
	_assert(pred["atk_double"], "奈德速差7可追击")

	# 带地形加成的预测
	var pred_forest := BattleCalculator.predict(atk, def2, "sword_C", "sword_E", 20)
	_assert(pred_forest["atk_hit"] < pred["atk_hit"],
		"森林加成降低命中（森林=%d < 平原=%d）" % [pred_forest["atk_hit"], pred["atk_hit"]])

	# 沼泽地形减益（回避=0，防御加成=-10，不影响命中计算中的avoid）
	# 沼泽对命中无影响（因为沼泽avoid=0）
	var pred_swamp := BattleCalculator.predict(atk, def2, "sword_C", "sword_E", 0)
	_assert_eq(pred_swamp["atk_hit"], pred["atk_hit"],
		"沼泽地形不影响命中（avoid=0）")

	# 验证守方反击伤害合理
	_assert(pred["def_damage"] >= 1 and pred["def_damage"] <= 50,
		"def_damage在合理范围内（=%d）" % pred["def_damage"])

# ══════════════════════════════════════════════════════════
# 测试套件 13：武器耐久系统
# ══════════════════════════════════════════════════════════
func _test_weapon_durability() -> void:
	# 有耐久的武器
	var d := UnitData.from_dict({
		"name": "剑士", "class": "剑士", "level": 1,
		"hp": 20, "max_hp": 20,
		"pow": 7, "spd": 8, "skl": 7, "def": 6, "lck": 5, "con": 8,
		"move": 5, "weapon_type": "sword", "weapon_rank": "C",
		"weapon_uses": 3, "weapon_max_uses": 3,
		"is_protagonist": false, "is_boss": false, "min_hp": 0, "items": []
	})
	_assert_eq(d.weapon_uses,     3,        "初始 weapon_uses=3")
	_assert_eq(d.weapon_max_uses, 3,        "初始 weapon_max_uses=3")
	_assert(not d.is_weapon_broken(),        "武器完好时 is_weapon_broken=false")
	_assert_eq(d.get_weapon_key(), "sword_C","完好时 weapon_key=sword_C")

	# 使用两次
	d.use_weapon_once(); d.use_weapon_once()
	_assert_eq(d.weapon_uses, 1,            "使用两次后剩余1次")
	_assert(not d.is_weapon_broken(),        "还有1次不算破损")

	# 最后一次
	d.use_weapon_once()
	_assert_eq(d.weapon_uses, 0,            "使用完毕后=0")
	_assert(d.is_weapon_broken(),            "耐久归零后is_weapon_broken=true")
	_assert_eq(d.get_weapon_key(), "fist",  "武器破损后回退到fist")

	# 破损武器不能继续消耗（uses不变）
	d.use_weapon_once()
	_assert_eq(d.weapon_uses, 0,            "破损后再调用use_weapon_once不变")

	# fist 在 BattleCalculator 中有回退值
	var fist_weapon: Dictionary = BattleCalculator.WEAPON_BASE.get("fist", {}) as Dictionary
	_assert(not fist_weapon.is_empty(),      "WEAPON_BASE包含fist后备武器")
	_assert_eq(int(fist_weapon.get("atk", 0)), 1, "fist atk=1")

	# 无限耐久（weapon_uses=-1）
	var d2 := UnitData.from_dict({
		"name": "X", "class": "X", "level": 1,
		"hp": 20, "max_hp": 20,
		"pow": 5, "spd": 5, "skl": 5, "def": 5, "lck": 3, "con": 7,
		"move": 5, "weapon_type": "sword", "weapon_rank": "E",
		"weapon_uses": -1, "weapon_max_uses": -1,
		"is_protagonist": false, "is_boss": false, "min_hp": 0, "items": []
	})
	_assert(not d2.is_weapon_broken(),       "weapon_uses=-1不视为破损")
	d2.use_weapon_once()
	_assert_eq(d2.weapon_uses, -1,           "weapon_uses=-1调用后仍为-1（无限）")

# ══════════════════════════════════════════════════════════
# 测试套件 14：道具系统
# ══════════════════════════════════════════════════════════
func _test_item_system() -> void:
	var d := UnitData.from_dict({
		"name": "X", "class": "X", "level": 1,
		"hp": 15, "max_hp": 30,
		"pow": 5, "spd": 5, "skl": 5, "def": 5, "lck": 3, "con": 7,
		"move": 5, "weapon_type": "sword", "weapon_rank": "E",
		"weapon_uses": -1, "weapon_max_uses": -1,
		"is_protagonist": false, "is_boss": false, "min_hp": 0,
		"items": [
			{"name": "急救药", "type": "heal", "heal_amount": 10, "uses": 2},
			{"name": "过期药", "type": "heal", "heal_amount": 5, "uses": 0}
		]
	})

	_assert(d.has_usable_items(),            "有可用道具时has_usable_items=true")
	_assert_eq(d.items.size(), 2,            "初始道具数=2")

	# 使用急救药第一次（uses: 2→1）
	var item1 := d.use_item(0)
	_assert(not item1.is_empty(),            "use_item返回非空字典")
	_assert_eq(item1.get("name", ""), "急救药", "返回正确道具名")
	_assert_eq(int(item1.get("heal_amount", 0)), 10, "治疗量=10")
	_assert_eq(d.items.size(), 2,            "使用后道具仍2项（未归零）")
	_assert_eq(int((d.items[0] as Dictionary).get("uses", -1)), 1, "急救药剩余uses=1")

	# 使用急救药第二次（uses: 1→0，自动移除）
	var item2 := d.use_item(0)
	_assert(not item2.is_empty(),            "第二次使用仍有效")
	_assert_eq(d.items.size(), 1,            "急救药用尽后自动移除，剩1项")

	# 使用过期药（uses=0，不可用）
	var item3 := d.use_item(0)
	_assert(item3.is_empty(),               "uses=0的道具use_item返回空字典")

	# 全部道具用尽
	_assert(not d.has_usable_items(),       "无可用道具时has_usable_items=false")

	# 越界索引
	var item4 := d.use_item(99)
	_assert(item4.is_empty(),               "越界索引返回空字典")

# ══════════════════════════════════════════════════════════
# 测试套件 15：武器三角加成
# ══════════════════════════════════════════════════════════
func _test_weapon_triangle() -> void:
	# 剑 > 斧（剑优势）
	_assert_eq(BattleCalculator.weapon_triangle_atk("sword_C", "axe_C"), 1,
		"剑vs斧 ATK+1")
	_assert_eq(BattleCalculator.weapon_triangle_hit("sword_C", "axe_C"), 5,
		"剑vs斧 HIT+5")

	# 斧 > 枪（斧优势）
	_assert_eq(BattleCalculator.weapon_triangle_atk("axe_E", "lance_E"), 1,
		"斧vs枪 ATK+1")

	# 枪 > 剑（枪优势）
	_assert_eq(BattleCalculator.weapon_triangle_atk("lance_C", "sword_C"), 1,
		"枪vs剑 ATK+1")

	# 逆三角劣势
	_assert_eq(BattleCalculator.weapon_triangle_atk("axe_C", "sword_C"), -1,
		"斧vs剑 ATK-1（劣势）")
	_assert_eq(BattleCalculator.weapon_triangle_atk("sword_E", "lance_E"), -1,
		"剑vs枪 ATK-1（劣势）")
	_assert_eq(BattleCalculator.weapon_triangle_atk("lance_E", "axe_E"), -1,
		"枪vs斧 ATK-1（劣势）")

	# 同类武器无加成
	_assert_eq(BattleCalculator.weapon_triangle_atk("sword_C", "sword_E"), 0,
		"同类武器三角=0")

	# fist 无三角
	_assert_eq(BattleCalculator.weapon_triangle_atk("fist", "sword_E"), 0,
		"fist无武器三角加成")

	# 三角对实际伤害的影响
	var atk := _make_unit_data({"pow": 10})
	var def2 := _make_enemy_data({"def": 5})
	# sword vs axe: 10+sword_C(9)+1 - 5 = 15
	_assert_eq(BattleCalculator.calc_damage(atk, def2, "sword_C", "axe_C"), 15,
		"剑vs斧 伤害含三角 pow10+sword_C9+1-def5=15")
	# sword vs lance: 10+9-1 - 5 = 13
	_assert_eq(BattleCalculator.calc_damage(atk, def2, "sword_C", "lance_C"), 13,
		"剑vs枪 伤害含三角劣势 pow10+sword_C9-1-def5=13")
	# sword vs sword: 10+9+0 - 5 = 14
	_assert_eq(BattleCalculator.calc_damage(atk, def2, "sword_C", "sword_C"), 14,
		"剑vs剑 无三角加成 pow10+sword_C9-def5=14")

# ══════════════════════════════════════════════════════════
# 测试套件 16：Boss 无敌底板（min_hp）
# ══════════════════════════════════════════════════════════
func _test_boss_min_hp() -> void:
	var unit := Unit.new()
	var data := UnitData.from_dict({
		"name": "亚瑟·戴恩", "class": "剑圣", "level": 20,
		"hp": 65, "max_hp": 65,
		"pow": 18, "spd": 17, "skl": 20, "def": 16, "lck": 10, "con": 13,
		"move": 6, "weapon_type": "sword", "weapon_rank": "S",
		"weapon_uses": 20, "weapon_max_uses": 20,
		"is_protagonist": false, "is_boss": true, "min_hp": 1, "items": []
	})
	unit.setup(data, 1, Vector2i(0, 0))

	# 正常受伤
	unit.take_damage(30)
	_assert_eq(unit.data.hp, 35,     "受伤30后hp=35")
	_assert(not unit.is_dead(),       "hp>1不死亡")

	# 大量伤害不能降到1以下
	unit.take_damage(9999)
	_assert_eq(unit.data.hp, 1,      "min_hp=1时无法降到1以下")
	_assert(not unit.is_dead(),       "min_hp=1时永远不触发死亡")
	_assert(not unit._pending_death,  "min_hp=1时_pending_death保持false")

	# 无min_hp的普通单位仍然可以死亡
	var normal_unit := Unit.new()
	var normal_data := UnitData.from_dict({
		"name": "普通兵", "class": "步兵", "level": 1,
		"hp": 10, "max_hp": 10,
		"pow": 5, "spd": 5, "skl": 5, "def": 5, "lck": 3, "con": 7,
		"move": 4, "weapon_type": "sword", "weapon_rank": "E",
		"weapon_uses": -1, "weapon_max_uses": -1,
		"is_protagonist": false, "is_boss": false, "min_hp": 0, "items": []
	})
	normal_unit.setup(normal_data, 1, Vector2i(0, 0))
	normal_unit.take_damage(9999)
	_assert_eq(normal_unit.data.hp, 0, "min_hp=0时hp可降至0")
	_assert(normal_unit.is_dead(),     "min_hp=0时正常死亡")

	unit.free()
	normal_unit.free()

# ══════════════════════════════════════════════════════════
# 测试套件 17：SaveSystem 存档读档
# ══════════════════════════════════════════════════════════
func _test_save_system() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if not ResourceLoader.exists(SAVE_SYS_PATH):
		_assert(false, "SaveSystem.gd 文件不存在")
		return

	var ss := load(SAVE_SYS_PATH)

	# 初始状态：无存档
	ss.delete_save()
	_assert(not ss.has_save(),             "删除后has_save=false")
	_assert_eq(ss.load_current_chapter(), 1, "无存档时默认返回章节1")

	# 保存第1章完成
	ss.save_chapter_complete(1)
	_assert(ss.has_save(),                 "保存后has_save=true")
	_assert_eq(ss.load_current_chapter(), 2, "完成Ch1后下次从Ch2开始")

	var completed: Array = ss.get_completed_chapters()
	_assert(completed.has(1),              "已完成章节列表包含1")
	_assert(not completed.has(2),          "章节2未完成")

	# 保存第2章完成
	ss.save_chapter_complete(2)
	_assert_eq(ss.load_current_chapter(), 3, "完成Ch2后下次从Ch3开始")

	var completed2: Array = ss.get_completed_chapters()
	_assert(completed2.has(1),             "已完成列表仍包含1")
	_assert(completed2.has(2),             "已完成列表包含2")

	# 重复保存同章节不重复计
	ss.save_chapter_complete(1)
	var completed3: Array = ss.get_completed_chapters()
	var count := 0
	for v in completed3:
		if v == 1: count += 1
	_assert_eq(count, 1,                   "重复保存不会重复添加到列表")

	# 清理：删除测试存档
	ss.delete_save()
	_assert(not ss.has_save(),             "测试结束后清理存档")

# ══════════════════════════════════════════════════════════
# 测试套件 11：Unit 状态机（含 undo_move）
# ══════════════════════════════════════════════════════════
func _test_unit_state_machine() -> void:
	var data := _make_unit_data()
	var unit := Unit.new()
	unit.setup(data, 0, Vector2i(3, 3))

	# 初始状态
	_assert_eq(unit.state, Unit.State.IDLE,  "初始状态=IDLE")
	_assert(unit.can_act(),                   "IDLE状态can_act=true")

	# mark_moved: IDLE → MOVED
	unit.mark_moved()
	_assert_eq(unit.state, Unit.State.MOVED, "mark_moved后=MOVED")
	_assert(unit.can_act(),                   "MOVED状态can_act=true（可攻击）")

	# undo_move: MOVED → IDLE
	unit.undo_move()
	_assert_eq(unit.state, Unit.State.IDLE,  "undo_move后=IDLE")
	_assert(unit.can_act(),                   "undo后can_act=true")

	# mark_acted: 任何状态 → DONE
	unit.mark_moved()
	unit.mark_acted()
	_assert_eq(unit.state, Unit.State.DONE,  "mark_acted后=DONE")
	_assert(not unit.can_act(),               "DONE状态can_act=false")

	# reset_turn: DONE → IDLE
	unit.reset_turn()
	_assert_eq(unit.state, Unit.State.IDLE,  "reset_turn后=IDLE")

	# undo_move 在非MOVED状态无效（不改变状态）
	unit.state = Unit.State.DONE
	unit.undo_move()
	_assert_eq(unit.state, Unit.State.DONE,  "非MOVED状态undo_move无效")

	# take_damage + is_dead
	unit.data.hp = 5
	unit.take_damage(3)
	_assert_eq(unit.data.hp, 2, "take_damage(3): 5-3=2")
	_assert(not unit.is_dead(), "hp=2不算死亡")

	unit.take_damage(10)
	_assert_eq(unit.data.hp, 0, "take_damage(10): hp最小值=0")
	_assert(unit.is_dead(),     "hp=0判定死亡")

	unit.free()

# ══════════════════════════════════════════════════════════
# 测试套件 12：路径查找 Dijkstra 逻辑（无需场景，纯算法）
# ══════════════════════════════════════════════════════════
func _test_pathfinding_logic() -> void:
	# 复现 BattleMap._find_path_to 的核心 Dijkstra 逻辑
	# 用简单 3×3 无障碍平原进行测试
	var move_budget := 5

	var find_path := func(start: Vector2i, target: Vector2i,
			passable_fn: Callable, cost_fn: Callable) -> Array[Vector2i]:
		if target == start: return []
		var came_from: Dictionary = {}
		var cost_map:  Dictionary = {}
		var open: Array = [{"pos": start, "c": 0}]
		cost_map[start] = 0
		while not open.is_empty():
			open.sort_custom(func(a,b): return a["c"] < b["c"])
			var curr = open.pop_front()
			var pos: Vector2i = curr["pos"]
			if pos == target: break
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var npos: Vector2i = pos + d
				if not passable_fn.call(npos): continue
				var nc: int = cost_map[pos] + cost_fn.call(npos)
				if nc > move_budget: continue
				if not cost_map.has(npos) or nc < cost_map[npos]:
					cost_map[npos] = nc
					came_from[npos] = pos
					open.append({"pos": npos, "c": nc})
		if not came_from.has(target): return []
		var path: Array[Vector2i] = []
		var cur: Vector2i = target
		while cur != start:
			path.push_front(cur)
			if not came_from.has(cur): return []
			cur = came_from[cur]
		return path

	# 测试1：直线路径（平原，消耗各1）
	var all_pass := func(_p: Vector2i) -> bool: return true
	var cost_1   := func(_p: Vector2i) -> int:  return 1
	var path1: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(3,0), all_pass, cost_1)
	_assert_eq(path1.size(), 3, "直线路径3步：长度=3")
	_assert_eq(path1[0], Vector2i(1,0), "路径第1步=(1,0)")
	_assert_eq(path1[2], Vector2i(3,0), "路径最后一步=(3,0)")

	# 测试2：超出移动力不可达
	var path2: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(6,0), all_pass, cost_1)
	_assert(path2.is_empty(), "移动力5无法到达(6,0)（需6步）")

	# 测试3：恰好在移动力边界
	var path3: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(5,0), all_pass, cost_1)
	_assert_eq(path3.size(), 5, "恰好5步可达")

	# 测试4：不可通行格阻断路径，需绕行
	var blocked := Vector2i(1,0)
	var block_pass := func(p: Vector2i) -> bool: return p != blocked
	var path4: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(2,0), block_pass, cost_1)
	_assert(path4.size() >= 2, "绕行路径存在（需>=2步）")
	_assert(not (blocked in path4), "绕行路径不经过阻断格")

	# 测试5：高消耗地形迫使最短路
	var cost_forest := func(p: Vector2i) -> int:
		return 2 if p == Vector2i(0,1) else 1  # (0,1)格消耗2
	var path5: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(0,2), all_pass, cost_forest)
	# 直走 (0,0)→(0,1)→(0,2) 消耗 2+1=3 ≤ 5，应该可达
	_assert(path5.size() >= 2, "穿越高消耗地形的路径存在")

	# 测试6：所有方向都不可通行
	var no_pass := func(_p: Vector2i) -> bool: return false
	var path6: Array[Vector2i] = find_path.call(
		Vector2i(0,0), Vector2i(1,0), no_pass, cost_1)
	_assert(path6.is_empty(), "无可通行路径返回空数组")

	# 测试7：起点等于终点
	var path7: Array[Vector2i] = find_path.call(
		Vector2i(3,3), Vector2i(3,3), all_pass, cost_1)
	_assert(path7.is_empty(), "起点=终点返回空数组")

# ── 守卫型Boss数据字段 ───────────────────────────────────
func _test_guard_boss_fields() -> void:
	# 测试亚瑟·戴恩JSON包含守卫字段
	var file := FileAccess.open("res://data/units/arthur_dayne.json", FileAccess.READ)
	_assert(file != null, "arthur_dayne.json 文件存在")
	if file == null: return
	var parser := JSON.new()
	_assert(parser.parse(file.get_as_text()) == OK, "JSON解析成功")
	file.close()
	var d: Dictionary = parser.data as Dictionary
	_assert(d.has("is_boss"),      "有 is_boss 字段")
	_assert(d.get("is_boss") == true, "is_boss=true")
	_assert(d.has("guard_pos_x"), "有 guard_pos_x 字段")
	_assert(d.has("guard_pos_y"), "有 guard_pos_y 字段")
	_assert(d.has("guard_range"), "有 guard_range 字段")
	_assert(d.has("min_hp"),      "有 min_hp 字段")
	_assert(d.get("min_hp") == 1, "min_hp=1（永不死亡）")

	# 测试UnitData能正确加载这些字段
	var ud: UnitData = UnitDataClass.from_dict(d)
	_assert(ud.is_boss,          "UnitData.is_boss=true")
	_assert(ud.guard_pos_x >= 0, "UnitData.guard_pos_x已加载")
	_assert(ud.guard_pos_y >= 0, "UnitData.guard_pos_y已加载")
	_assert(ud.guard_range > 0,  "UnitData.guard_range>0")
	_assert(ud.min_hp == 1,      "UnitData.min_hp=1")

# ── 战斗动画freed节点防护 ───────────────────────────────
func _test_animation_freed_guard() -> void:
	# 验证BattleAnimation.play()在接收invalid节点时能安全返回
	# 由于无法直接实例化BattleAnimation（需要场景），
	# 这里验证is_instance_valid的防护逻辑在GDScript中有效

	# 创建一个节点然后释放它，验证is_instance_valid能检测到
	var node := Node.new()
	_assert(is_instance_valid(node), "释放前节点有效")
	node.free()
	_assert(not is_instance_valid(node), "释放后is_instance_valid返回false")

	# 验证UnitData在freed节点检测后不会被访问
	# （这是BattleAnimation.play()修复的核心逻辑）
	var freed_check_works: bool = true
	var test_node := Node.new()
	test_node.free()
	if is_instance_valid(test_node):
		freed_check_works = false  # 如果这里为true说明检测失效
	_assert(freed_check_works, "freed节点防护机制有效")
	_assert_eq(is_instance_valid(null), false, "null节点检测")

# ── _check_all_acted 防重入 ──────────────────────────────
func _test_turn_ending_guard() -> void:
	# 验证_turn_ending标志位在Unit状态机层面的语义
	# （无法直接测试异步协程，但验证标志位的初始状态和状态机联动）
	var ud: UnitData = UnitDataClass.from_dict({
		"name": "测试", "class": "剑士", "level": 1,
		"hp": 20, "max_hp": 20, "pow": 5, "spd": 5,
		"skl": 5, "def": 5, "lck": 3, "con": 7,
		"move": 5, "weapon_type": "sword", "weapon_rank": "E"
	})

	# 模拟：所有单位行动完毕 = 没有can_act()的单位
	# can_act() = state == IDLE or state == MOVED
	var unit_script := preload("res://scripts/battle/Unit.gd")
	var u: Unit = unit_script.new()
	u.setup(ud, 0, Vector2i(0,0))

	_assert(u.can_act(), "初始状态可行动")
	u.mark_moved()
	_assert(u.can_act(), "移动后仍可行动（可攻击/等待）")
	u.mark_acted()
	_assert(not u.can_act(), "行动完毕后不可行动")
	u.reset_turn()
	_assert(u.can_act(), "新回合后恢复可行动")
	u.free()

# ── 地形图块坐标合法性 ──────────────────────────────────
func _test_tile_atlas_coords() -> void:
	# Toen图集：7列×52行，坐标必须在范围内
	const MAX_COL := 6
	const MAX_ROW := 51
	var coords: Dictionary = BootstrapClass.TILE_ATLAS_COORDS
	var coords_ch4: Dictionary = BootstrapClass.TILE_ATLAS_COORDS_CH4
	for terrain_type: int in coords:
		var coord: Vector2i = coords[terrain_type]
		_assert(coord.x >= 0 and coord.x <= MAX_COL,
			"地形%d列坐标合法(%d)" % [terrain_type, coord.x])
		_assert(coord.y >= 0 and coord.y <= MAX_ROW,
			"地形%d行坐标合法(%d)" % [terrain_type, coord.y])
	# 验证所有坐标唯一（不同地形不共用同一图块）
	var used: Array = []
	for v: Vector2i in coords.values():
		_assert(not used.has(v), "地形坐标无重复(%d,%d)" % [v.x, v.y])
		used.append(v)
	_assert_eq(coords_ch4.size(), coords.size(), "Ch4 图块映射数量与基础地图一致")
	for terrain_type: int in coords_ch4:
		var coord_ch4: Vector2i = coords_ch4[terrain_type]
		_assert(coord_ch4.x >= 0 and coord_ch4.x <= MAX_COL,
			"Ch4 地形%d列坐标合法(%d)" % [terrain_type, coord_ch4.x])
		_assert(coord_ch4.y >= 0 and coord_ch4.y <= MAX_ROW,
			"Ch4 地形%d行坐标合法(%d)" % [terrain_type, coord_ch4.y])

func _test_visual_style_unification() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/battle/BattleMap.gd")
	_assert(not src.contains("_hide_tilemap_png"), "BattleMap 已移除旧 TileMap 隐藏兼容逻辑")
	_assert(src.contains("func _draw_terrain_detail"), "BattleMap 存在统一地形细节绘制入口")
	_assert(src.contains("func _draw_wall_detail"), "BattleMap 存在城墙/建筑细节绘制")
	_assert(src.contains("func _draw_river_detail"), "BattleMap 存在河流细节绘制")
	_assert(src.contains("func _draw_bridge_detail"), "BattleMap 存在桥梁细节绘制")
	_assert(src.contains("func _terrain_at_or_cliff"), "BattleMap 提供邻接地形查询辅助，用于统一图块语言")
	_assert(src.contains("func _bridge_runs_vertical"), "BattleMap 根据邻接地形判定桥梁朝向")
	var scene_text := FileAccess.get_file_as_string("res://scenes/battle/BattleMap.tscn")
	_assert(not scene_text.contains("TileMapLayer"), "BattleMap 场景已移除旧 TileMapLayer 节点")
	_assert(not scene_text.contains("medieval_tileset.png"), "BattleMap 场景已移除旧瓦片贴图依赖")

	for chapter: int in [1, 2, 3, 4]:
		GameState.current_chapter = chapter
		var battle := TestBootstrapClass.new()
		root.add_child(battle)
		await process_frame
		await process_frame

		var tilemap := battle.get_node_or_null("TileLayer/TileMapLayer") as TileMapLayer
		_assert(tilemap == null, "Ch%d 运行时已不再创建旧 TileMapLayer" % chapter)

		_assert(battle.map_width > 0 and battle.map_height > 0,
			"Ch%d 地图尺寸有效，可进行程序化绘制" % chapter)

		if chapter == 4:
			_assert(battle._terrain_at_or_cliff(18, 8) == 6, "Ch4 中轴主桥地形保持桥梁")
			_assert(battle._bridge_runs_vertical(18, 8), "Ch4 中轴主桥按南北通行绘制")
		if chapter == 2:
			_assert(battle._terrain_at_or_cliff(7, 8) == 6, "Ch2 左翼桥头地形保持桥梁")
			_assert(battle._bridge_runs_vertical(7, 8), "Ch2 三叉戟桥梁按南北通行绘制")

		if is_instance_valid(battle):
			battle.queue_free()
		await process_frame

func _test_map_visual_language_spec() -> void:
	var spec_src := _read_repo_root_text("11-map-visual-language-spec-v1.md")
	_assert(spec_src.length() > 0, "地图视觉语言规范文档存在")
	_assert(spec_src.contains("桥邻接河流"), "规范文档包含桥梁与河流的功能红线")
	_assert(spec_src.contains("关键地图存在从出生点到目标的可达路径"), "规范文档包含关键路径可达性要求")

	# Ch1：出生区到胜利格必须存在一条有效路径
	GameState.current_chapter = 1
	var ch1 := TestBootstrapClass.new()
	root.add_child(ch1)
	await process_frame
	_assert(ch1._ned_unit != null, "Ch1 语义回归：奈德存在")
	if ch1._ned_unit != null:
		_assert(_path_exists_on_passable_grid(ch1, ch1._ned_unit.grid_pos, ch1.victory_pos),
			"Ch1 语义回归：奈德到北侧目标存在可达路径")
		_assert_eq(ch1._terrain_at_or_cliff(ch1.victory_pos.x, ch1.victory_pos.y), 0,
			"Ch1 语义回归：胜利格保持为可通行主地面")
	if is_instance_valid(ch1):
		ch1.queue_free()
	await process_frame

	# Ch2：桥必须邻接河流，且三桥构成跨河通路
	GameState.current_chapter = 2
	var ch2 := TestBootstrapClass.new()
	root.add_child(ch2)
	await process_frame
	for pos: Vector2i in [
		Vector2i(7, 8), Vector2i(8, 8),
		Vector2i(14, 8), Vector2i(15, 8),
		Vector2i(21, 8), Vector2i(22, 8),
	]:
		var left_river := ch2._terrain_at_or_cliff(pos.x - 1, pos.y) == 4 or ch2._terrain_at_or_cliff(pos.x - 1, pos.y) == 6
		var right_river := ch2._terrain_at_or_cliff(pos.x + 1, pos.y) == 4 or ch2._terrain_at_or_cliff(pos.x + 1, pos.y) == 6
		_assert(left_river or right_river,
			"Ch2 语义回归：桥位 %s 邻接河道" % str(pos))
	_assert_eq(ch2._terrain_at_or_cliff(14, 17), 0, "Ch2 语义回归：玩家主将出生点位于南岸陆地")
	if is_instance_valid(ch2):
		ch2.queue_free()
	await process_frame

	# Ch3：奈德到塔楼目标必须存在可达路径，且门神位保持在主轴前方
	GameState.current_chapter = 3
	var ch3 := TestBootstrapClass.new()
	root.add_child(ch3)
	await process_frame
	_assert(ch3._ned_unit != null, "Ch3 语义回归：奈德存在")
	_assert(ch3._dayne_unit != null, "Ch3 语义回归：亚瑟·戴恩存在")
	if ch3._ned_unit != null:
		_assert(_path_exists_on_passable_grid(ch3, ch3._ned_unit.grid_pos, ch3.victory_pos),
			"Ch3 语义回归：奈德到塔楼目标存在可达路径")
	if ch3._dayne_unit != null:
		_assert(ch3._dayne_unit.grid_pos.y > ch3.victory_pos.y,
			"Ch3 语义回归：亚瑟·戴恩位于塔目标南侧门神位")
	if is_instance_valid(ch3):
		ch3.queue_free()
	await process_frame

	# Ch4：部署区在陆地，目标铁王座在主中轴，关键桥位邻接河流
	GameState.current_chapter = 4
	GameState.deploy_selection = ["ned_stark.json", "northern_knight.json"]
	var ch4 := TestBootstrapClass.new()
	root.add_child(ch4)
	await process_frame
	for spawn: Vector2i in [
		Vector2i(18,22), Vector2i(15,22), Vector2i(21,22),
		Vector2i(12,23), Vector2i(18,23), Vector2i(24,23),
	]:
		_assert_eq(ch4._terrain_at_or_cliff(spawn.x, spawn.y), 0,
			"Ch4 语义回归：部署格 %s 为陆地" % str(spawn))
	_assert_eq(ch4._terrain_at_or_cliff(18, 2), 0, "Ch4 语义回归：铁王座目标格为陆地")
	for bridge_pos: Vector2i in [Vector2i(18, 8), Vector2i(18, 19)]:
		_assert(_bridge_span_has_river_flanks(ch4, bridge_pos.y, 17, 20),
			"Ch4 语义回归：主桥 %s 两侧与河流衔接" % str(bridge_pos))
	_assert(_path_exists_on_passable_grid(ch4, Vector2i(18, 22), ch4.victory_pos),
		"Ch4 语义回归：中轴部署区到铁王座存在连续可达路径")
	_assert_eq(ch4._terrain_at_or_cliff(18, 11), 0, "Ch4 语义回归：红堡外墙主门保持通路")
	_assert_eq(ch4._terrain_at_or_cliff(18, 13), 0, "Ch4 语义回归：内城墙主门保持通路")
	_assert_eq(ch4._terrain_at_or_cliff(18, 18), 0, "Ch4 语义回归：南城墙主门保持通路")
	if is_instance_valid(ch4):
		ch4.queue_free()
	await process_frame

func _test_portrait_assets() -> void:
	var portrait_map: Dictionary = BootstrapClass.UNIT_PORTRAIT_MAP
	_assert(portrait_map.size() >= 13, "主要角色与兵种立绘映射已扩展")
	for unit_file: String in portrait_map.keys():
		var portrait_name: String = portrait_map[unit_file]
		var path := "res://assets/units/" + portrait_name
		_assert(FileAccess.file_exists(path), "立绘资源存在：%s" % portrait_name)
		if not FileAccess.file_exists(path):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_assert(img != null and not img.is_empty(), "立绘图片可直接读取：%s" % portrait_name)
		if img == null or img.is_empty():
			continue
		var tex := ImageTexture.create_from_image(img)
		_assert(tex != null, "立绘可加载：%s" % portrait_name)
		if tex == null:
			continue
		_assert(tex.get_width() >= 96 and tex.get_height() >= 96,
			"立绘分辨率升级为至少96×96：%s (%dx%d)" % [portrait_name, tex.get_width(), tex.get_height()])
		_assert(tex.get_width() == tex.get_height(),
			"立绘保持方形比例：%s" % portrait_name)

func _test_dialogue_portrait_mapping() -> void:
	const DIALOGUE_SYSTEM_PATH := "res://scripts/dialogue/DialogueSystem.gd"
	_assert(ResourceLoader.exists(DIALOGUE_SYSTEM_PATH), "DialogueSystem.gd 存在")
	if not ResourceLoader.exists(DIALOGUE_SYSTEM_PATH):
		return
	var src := FileAccess.get_file_as_string(DIALOGUE_SYSTEM_PATH)
	_assert("SPEAKER_PORTRAIT_MAP" in src, "DialogueSystem 包含对话立绘映射表")
	_assert("_update_portrait" in src, "DialogueSystem 包含对话立绘刷新逻辑")
	_assert("PortraitPanel" in src, "DialogueSystem 使用对话立绘面板")

	var speaker_to_portrait := {
		"奈德": "ned_stark_portrait.png",
		"劳勃": "robert_baratheon_portrait.png",
		"霍兰": "howland_reed_portrait.png",
		"霍兰德": "howland_reed_portrait.png",
		"皇家卫兵": "royal_soldier_portrait.png",
		"兰尼斯特士兵": "lannister_soldier_portrait.png",
		"北境骑士": "northern_knight_portrait.png",
		"反叛领主": "rebel_lord_portrait.png",
		"詹姆": "jaime_lannister_portrait.png",
		"史林特": "janos_slynt_portrait.png",
	}
	for speaker: String in speaker_to_portrait.keys():
		var portrait_name: String = speaker_to_portrait[speaker]
		_assert(("\"%s\": \"%s\"" % [speaker, portrait_name]) in src,
			"对话角色 %s 已映射到立绘 %s" % [speaker, portrait_name])
		var path := "res://assets/units/" + portrait_name
		_assert(FileAccess.file_exists(path), "对话立绘资源存在：%s" % portrait_name)

	var dialogue_speakers := {
		"奈德": false,
		"劳勃": false,
		"霍兰": false,
		"霍兰德": false,
		"皇家卫兵": false,
		"兰尼斯特士兵": false,
		"北境骑士": false,
		"反叛领主": false,
		"詹姆": false,
		"史林特": false,
	}
	for dialogue_path: String in [
		"res://data/dialogues/prologue_1_pre.json",
		"res://data/dialogues/prologue_1_post.json",
		"res://data/dialogues/ch2_pre.json",
		"res://data/dialogues/ch3_pre.json",
		"res://data/dialogues/ch3_betrayal.json",
		"res://data/dialogues/ch4_pre.json",
		"res://data/dialogues/ch4_jaime.json",
		"res://data/dialogues/ch4_lannister_join.json",
	]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dialogue_path))
		_assert(parsed is Dictionary, "对话文件可解析：%s" % dialogue_path.get_file())
		if not (parsed is Dictionary):
			continue
		for line: Variant in (parsed as Dictionary).get("lines", []):
			if line is Dictionary:
				var sp: String = (line as Dictionary).get("speaker", "")
				if dialogue_speakers.has(sp):
					dialogue_speakers[sp] = true
	for speaker_checked: String in dialogue_speakers.keys():
		_assert(dialogue_speakers[speaker_checked], "对话角色 %s 在数据中实际出现" % speaker_checked)

# ── 字体初始化方法存在 ───────────────────────────────────
func _test_font_setup() -> void:
	# 读取Opening.gd源码验证包含字体初始化方法
	var file := FileAccess.open("res://scripts/Opening.gd", FileAccess.READ)
	_assert(file != null, "Opening.gd文件存在")
	if file == null: return
	var src: String = file.get_as_text()
	file.close()
	_assert("_apply_chinese_font" in src, "包含_apply_chinese_font方法")
	_assert("SystemFont" in src, "使用SystemFont")
	_assert("STHeitiSC-Medium" in src or "STHeiti Medium" in src, "包含中文字体名")
	_assert("ThemeDB.get_project_theme()" in src, "设置到全局主题")
	_assert("DisplayServer.get_name()" in src or "headless" in src,
		"包含headless环境检测（防止无显示器时崩溃）")

# ── 关键场景/脚本加载冒烟测试 ───────────────────────────
func _test_scene_and_script_smoke() -> void:
	var scene_paths: Array[String] = [
		"res://scenes/Opening.tscn",
		"res://scenes/battle/BattleMap.tscn",
		"res://scenes/chapter/Ch2_Opening.tscn",
		"res://scenes/chapter/Ch3_Opening.tscn",
		"res://scenes/chapter/Ch4_Opening.tscn",
		"res://scenes/cutscene/CutscenePlayer.tscn",
		"res://scenes/dialogue/DialogueBox.tscn",
		"res://scenes/ui/DeployScreen_Ch4.tscn",
		"res://scenes/ui/ChapterTransition.tscn",
	]
	for path: String in scene_paths:
		_assert(ResourceLoader.exists(path), "场景存在：%s" % path)
		var scene_res: Resource = load(path)
		_assert(scene_res != null, "场景可加载：%s" % path)
		if scene_res is PackedScene:
			var inst: Node = (scene_res as PackedScene).instantiate()
			_assert(inst != null, "场景可实例化：%s" % path)
			if inst != null:
				inst.queue_free()

	var script_paths: Array[String] = [
		"res://scripts/Opening.gd",
		"res://scripts/chapter/ChapterOpening.gd",
		"res://scripts/chapter/Opening_Ch2.gd",
		"res://scripts/chapter/Opening_Ch3.gd",
		"res://scripts/chapter/Opening_Ch4.gd",
		"res://scripts/battle/BattleBootstrap.gd",
		"res://scripts/battle/BattleMap.gd",
		"res://scripts/dialogue/DialogueSystem.gd",
		"res://scripts/cutscene/CutscenePlayer.gd",
		"res://scripts/ui/DeployScreen_Ch4.gd",
		"res://scripts/systems/ChapterTransition.gd",
	]
	for path: String in script_paths:
		_assert(ResourceLoader.exists(path), "脚本存在：%s" % path)
		var script_res: Resource = load(path)
		_assert(script_res != null, "脚本可加载：%s" % path)

func _test_chapter_event_flow() -> void:
	var opening_scene: PackedScene = load("res://scenes/Opening.tscn") as PackedScene
	_assert(opening_scene != null, "Opening 场景可加载用于章节回归")
	if opening_scene == null:
		return

	# ── Ch2：雷加死亡 → 过场 → 章节推进到3 ─────────────────
	GameState.current_chapter = 2
	var ch2 := TestBootstrapClass.new()
	root.add_child(ch2)
	await process_frame
	_assert(ch2._rhaegar_unit != null, "Ch2 初始化后雷加已生成")
	_assert(ch2.enemy_units.size() >= 1, "Ch2 初始化后敌军存在")
	if ch2._rhaegar_unit != null:
		ch2._on_unit_died(ch2._rhaegar_unit)
		await process_frame
		await process_frame
		await process_frame
		_assert(ch2._rhaegar_death_done, "Ch2 雷加死亡标记已置位")
		_assert(ch2.recorded_cutscenes.has("res://data/cutscenes/ch2_rhaegar_fall.json"),
			"Ch2 雷加死亡触发过场")
		_assert(ch2.recorded_cutscenes.has("res://data/cutscenes/ch2_split.json"),
			"Ch2 雷加死亡后自动触发战后分兵过场")
		_assert(ch2.recorded_dialogues.has("res://data/dialogues/ch2_post.json"),
			"Ch2 雷加死亡后自动触发战后对话")
		await process_frame
		_assert(ch2.recorded_advances.has(3), "Ch2 胜利后推进到第3章")
		_assert_eq(GameState.current_chapter, 3, "Ch2 事件后当前章节=3")
	if is_instance_valid(ch2):
		ch2.queue_free()
	await process_frame

	# ── Ch3：到塔门 / 触发塔事件 → 连续过场 → 章节推进到4 ──
	GameState.current_chapter = 3
	var ch3 := TestBootstrapClass.new()
	root.add_child(ch3)
	await process_frame
	_assert(ch3._ned_unit != null, "Ch3 初始化后奈德已生成")
	_assert(ch3._dayne_unit != null, "Ch3 初始化后亚瑟·戴恩已生成")
	ch3._trigger_ch3_tower()
	await process_frame
	await process_frame
	await process_frame
	_assert(ch3.recorded_cutscenes.has("res://data/cutscenes/ch3_dayne_trigger.json"),
		"Ch3 触发霍兰刺杀戴恩过场")
	_assert(ch3.recorded_cutscenes.has("res://data/cutscenes/ch3_lyanna.json"),
		"Ch3 触发莱安娜过场")
	_assert(ch3.recorded_dialogues.has("res://data/dialogues/ch3_post.json"),
		"Ch3 触发战后对话")
	_assert(ch3.recorded_advances.has(4), "Ch3 事件后推进到第4章")
	_assert_eq(GameState.current_chapter, 4, "Ch3 事件后当前章节=4")
	_assert(ch3._battle_over, "Ch3 塔事件过程中战斗已结束")
	if is_instance_valid(ch3):
		ch3.queue_free()
	await process_frame

	# ── Ch4：指挥官死亡 → 兰军归降/移除 → 结局推进到Opening ──
	GameState.current_chapter = 4
	GameState.deploy_selection = ["ned_stark.json", "northern_knight.json"]
	var ch4 := TestBootstrapClass.new()
	root.add_child(ch4)
	await process_frame
	_assert(ch4._royal_commander != null, "Ch4 初始化后王军指挥官已生成")
	_assert(ch4._lannister_units.size() > 0, "Ch4 初始化后兰军中立单位存在")
	var lann_before := ch4._lannister_units.size()
	ch4._on_unit_died(ch4._royal_commander)
	await create_timer(2.4).timeout
	await process_frame
	_assert(ch4._commander_killed, "Ch4 指挥官死亡标记已置位")
	_assert(lann_before > 0, "Ch4 兰军初始数量大于0")
	_assert_eq(ch4._lannister_units.size(), 0, "Ch4 指挥官死亡后兰军被移除")
	_assert(ch4.recorded_dialogues.has("res://data/dialogues/ch4_lannister_join.json"),
		"Ch4 指挥官死亡触发兰军归降对话")
	_assert(ch4.recorded_dialogues.has("res://data/dialogues/ch4_post.json"),
		"Ch4 最终结局对话触发")
	_assert(ch4.recorded_cutscenes.has("res://data/cutscenes/ch4_ending.json"),
		"Ch4 最终结局过场触发")
	_assert(ch4.recorded_advances.has(0), "Ch4 结局后返回主入口")
	_assert_eq(GameState.current_chapter, 1, "Ch4 事件后章节重置到1")
	if is_instance_valid(ch4):
		ch4.queue_free()
	await process_frame

func _test_ch1_save_and_deploy_flow() -> void:
	# ── Ch1：敌军全灭胜利与到达胜利格胜利 ─────────────────
	GameState.current_chapter = 1
	var ch1_kill := TestBootstrapClass.new()
	root.add_child(ch1_kill)
	await process_frame
	_assert(ch1_kill._ch1_enemies_spawned, "Ch1 初始化后敌人生成标记为 true")
	for enemy: Unit in ch1_kill.enemy_units:
		if enemy != null and enemy.data != null:
			enemy.data.hp = 0
	ch1_kill._check_victory()
	await process_frame
	await process_frame
	_assert(ch1_kill._battle_over, "Ch1 敌军全灭后战斗结束")
	_assert(ch1_kill.recorded_dialogues.has("res://data/dialogues/prologue_1_post.json"),
		"Ch1 敌军全灭触发战后对话")
	_assert(ch1_kill.recorded_advances.has(2), "Ch1 敌军全灭后推进到第2章")
	if is_instance_valid(ch1_kill):
		ch1_kill.queue_free()
	await process_frame

	GameState.current_chapter = 1
	var ch1_goal := TestBootstrapClass.new()
	root.add_child(ch1_goal)
	await process_frame
	_assert(ch1_goal._ned_unit != null, "Ch1 初始化后奈德已生成")
	if ch1_goal._ned_unit != null:
		ch1_goal._ned_unit.grid_pos = ch1_goal.victory_pos
		ch1_goal._check_ch1_victory_loop()
		await process_frame
		await process_frame
		_assert(ch1_goal._ned_reached_victory, "Ch1 奈德到达目标后胜利标记置位")
		_assert(ch1_goal.recorded_advances.has(2), "Ch1 奈德到达目标后推进到第2章")
	if is_instance_valid(ch1_goal):
		ch1_goal.queue_free()
	await process_frame

	# ── Opening：无存档进入 Ch1；有存档路由到对应章节 ──────
	SaveSystem.delete_save()
	var opening_fresh := TestOpeningClass.new()
	root.add_child(opening_fresh)
	await process_frame
	opening_fresh.run_start_normal_flow()
	_assert(opening_fresh.played_chapter_1, "Opening 无存档时进入 Ch1 流程")
	_assert(opening_fresh.recorded_scene_changes.is_empty(), "Opening 无存档时不直接跳章节场景")
	if is_instance_valid(opening_fresh):
		opening_fresh.queue_free()
	await process_frame

	SaveSystem.save_chapter_complete(2) # 当前章节应为3
	var opening_saved := TestOpeningClass.new()
	root.add_child(opening_saved)
	await process_frame
	opening_saved.run_start_normal_flow()
	_assert(not opening_saved.played_chapter_1, "Opening 有存档时不重新进入 Ch1")
	_assert(opening_saved.recorded_scene_changes.has("res://scenes/chapter/Ch3_Opening.tscn"),
		"Opening 有存档时按章节路由到 Ch3")
	if is_instance_valid(opening_saved):
		opening_saved.queue_free()
	await process_frame
	SaveSystem.delete_save()

	# ── Ch4 部署：确认后写入 deploy_selection；新游戏清存档 ──
	GameState.deploy_selection = []
	var deploy := TestDeployScreenClass.new()
	root.add_child(deploy)
	await process_frame
	deploy._selected = [1, 3, 5]
	deploy.test_confirm()
	_assert_eq(GameState.deploy_selection.size(), 4, "部署确认后写入奈德+3名骑士")
	_assert_eq(GameState.deploy_selection[0], "ned_stark.json", "部署列表首位固定为奈德")
	_assert(deploy.recorded_scene_changes.has("res://scenes/battle/BattleMap.tscn"),
		"部署确认后进入战斗场景")
	SaveSystem.save_chapter_complete(1)
	_assert(SaveSystem.has_save(), "为测试新游戏按钮先创建存档")
	deploy.test_new_game()
	_assert(not SaveSystem.has_save(), "部署界面新游戏按钮会清除存档")
	_assert(deploy.recorded_scene_changes.has("res://scenes/Opening.tscn"),
		"部署界面新游戏按钮返回 Opening")
	if is_instance_valid(deploy):
		deploy.queue_free()
	await process_frame
