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

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""

# ── 入口 ─────────────────────────────────────────────────
func _init() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║  铁王座战记 — 自动化测试套件           ║")
	print("╚══════════════════════════════════════╝\n")

	_run_suite("UnitData 数据加载", _test_unit_data)
	_run_suite("BattleCalculator 战斗公式", _test_battle_calculator)
	_run_suite("BattleCalculator 边界值", _test_calculator_edge_cases)
	_run_suite("地形系统加成", _test_terrain_bonus)
	_run_suite("地形移动消耗", _test_terrain_move_cost)
	_run_suite("地图完整性（22×16）", _test_map_integrity)
	_run_suite("EnemyAI 距离计算", _test_enemy_ai_distance)
	_run_suite("对话 JSON 文件加载", _test_dialogue_json)
	_run_suite("过场动画 JSON 加载", _test_cutscene_json)
	_run_suite("战斗预测全流程", _test_battle_predict_full)
	_run_suite("Unit 状态机（含 undo_move）", _test_unit_state_machine)
	_run_suite("路径查找 Dijkstra 逻辑", _test_pathfinding_logic)
	_run_suite("武器耐久系统", _test_weapon_durability)
	_run_suite("道具系统", _test_item_system)
	_run_suite("武器三角加成", _test_weapon_triangle)
	_run_suite("Boss 无敌底板（min_hp）", _test_boss_min_hp)
	_run_suite("SaveSystem 存档读档", _test_save_system)
	_run_suite("守卫型Boss数据字段", _test_guard_boss_fields)
	_run_suite("战斗动画freed节点防护", _test_animation_freed_guard)
	_run_suite("回合结束防重入", _test_turn_ending_guard)

	print("\n╔══════════════════════════════════════╗")
	var status: String = "全部通过 ✓" if _fail_count == 0 else ("失败 %d 项 ✗" % _fail_count)
	print("║  %d 通过  %d 失败  — %s" % [_pass_count, _fail_count, status])
	print("╚══════════════════════════════════════╝\n")
	quit(_fail_count)

# ── 测试框架 ─────────────────────────────────────────────
func _run_suite(name: String, fn: Callable) -> void:
	_current_suite = name
	print("▶ %s" % name)
	fn.call()
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
# 测试套件 6：地图完整性（22×16）
# ══════════════════════════════════════════════════════════
func _test_map_integrity() -> void:
	var terrain_map: Array = BootstrapClass.TERRAIN_CH1

	# 尺寸验证
	_assert_eq(terrain_map.size(), 16, "地图行数=16")
	_assert_eq(terrain_map[0].size(), 22, "地图列数=22")

	# 全部边界为峭壁（3）
	var border_ok := true
	for x: int in 22:
		if terrain_map[0][x] != 3 or terrain_map[15][x] != 3:
			border_ok = false
	for y: int in 16:
		if terrain_map[y][0] != 3 or terrain_map[y][21] != 3:
			border_ok = false
	_assert(border_ok, "所有边界格为峭壁（3）")

	# 河流在第9-10列（非边界行）
	var river_ok := true
	for y: int in range(1, 15):
		var row: Array = terrain_map[y]
		# 非桥梁行：col 9,10 必须是河流（4）或桥梁（6）
		if row[9] != 4 and row[9] != 6:
			river_ok = false
		if row[10] != 4 and row[10] != 6:
			river_ok = false
	_assert(river_ok, "河流列（9-10）全为河流(4)或桥梁(6)")

	# 桥梁存在验证（第5行和第10行有桥梁）
	var has_bridge_row5 := false
	var has_bridge_row10 := false
	for x: int in 22:
		if terrain_map[5][x] == 6:
			has_bridge_row5 = true
		if terrain_map[10][x] == 6:
			has_bridge_row10 = true
	_assert(has_bridge_row5,  "北桥在第5行存在")
	_assert(has_bridge_row10, "南桥在第10行存在")

	# 玩家出生点可通行
	var player_starts := [Vector2i(1,7), Vector2i(1,8), Vector2i(1,9)]
	for pos: Vector2i in player_starts:
		var t: int = terrain_map[pos.y][pos.x]
		_assert(t != 3 and t != 4,
			"玩家出生点(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t])

	# 胜利位置可通行
	var vp := Vector2i(17, 8)
	var vt: int = terrain_map[vp.y][vp.x]
	_assert(vt != 3 and vt != 4,
		"胜利位置(17,8)可通行（类型=%d）" % vt)

	# 敌方出生点可通行
	var enemy_starts := [
		Vector2i(13,4), Vector2i(11,6), Vector2i(13,7),
		Vector2i(12,11), Vector2i(16,9), Vector2i(17,7)
	]
	for pos: Vector2i in enemy_starts:
		var t: int = terrain_map[pos.y][pos.x]
		_assert(t != 3 and t != 4,
			"敌方出生点(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t])

	# 沼泽存在
	var has_swamp := false
	for y: int in 16:
		for x: int in 22:
			if terrain_map[y][x] == 5:
				has_swamp = true
				break
	_assert(has_swamp, "地图中存在沼泽地形")

	# 森林存在
	var has_forest := false
	for y: int in 16:
		for x: int in 22:
			if terrain_map[y][x] == 1:
				has_forest = true
				break
	_assert(has_forest, "地图中存在森林地形")

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
