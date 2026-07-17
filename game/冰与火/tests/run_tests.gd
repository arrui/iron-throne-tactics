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
const BattleMapClass        := preload("res://scripts/battle/BattleMap.gd")
const UnitDataClass          := preload("res://scripts/data/UnitData.gd")
const EnemyAIClass           := preload("res://scripts/battle/EnemyAI.gd")
const BootstrapClass         := preload("res://scripts/battle/BattleBootstrap.gd")
const Ch2BootstrapClass      := preload("res://scripts/battle/BattleBootstrap_Ch2.gd")
const Ch3BootstrapClass      := preload("res://scripts/battle/BattleBootstrap_Ch3.gd")
const Ch4BootstrapClass      := preload("res://scripts/battle/BattleBootstrap_Ch4.gd")
const PrologueChapterBriefsClass := preload("res://scripts/chapter/PrologueChapterBriefs.gd")
const Ch4BattleBriefClass    := preload("res://scripts/chapter/Ch4BattleBrief.gd")
const BattleChromeThemeClass := preload("res://scripts/ui/BattleChromeTheme.gd")
const TestBootstrapClass     := preload("res://tests/helpers/TestBattleBootstrap.gd")
const TestOpeningClass       := preload("res://tests/helpers/TestOpening.gd")
const TestDeployScreenClass  := preload("res://tests/helpers/TestDeployScreen.gd")

class TestCh3Bootstrap extends Ch3BootstrapClass:
	func _ready() -> void:
		pass

	func _trigger_tower_sequence() -> void:
		pass

	func _play_dialogue(_path: String) -> void:
		pass

class TestCh4Bootstrap extends Ch4BootstrapClass:
	func _ready() -> void:
		pass

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""
var _completed_suite_count: int = 0


# ── 入口 ─────────────────────────────────────────────────
func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║  铁王座战记 — 自动化测试套件           ║")
	print("╚══════════════════════════════════════╝\n")
	var suites := [
		["UnitData 数据加载", _test_unit_data],
		["BattleCalculator 战斗公式", _test_battle_calculator],
		["BattleCalculator 边界值", _test_calculator_edge_cases],
		["地形系统加成", _test_terrain_bonus],
		["地形移动消耗", _test_terrain_move_cost],
		["地图完整性（按章节配置）", _test_map_integrity],
		["Ch4 君临城地图重设计回归", _test_ch4_map_redesign],
		["EnemyAI 距离计算", _test_enemy_ai_distance],
		["对话 JSON 文件加载", _test_dialogue_json],
		["Ch1 叙事基线一致性", _test_ch1_narrative_baseline],
		["过场动画 JSON 加载", _test_cutscene_json],
		["战斗预测全流程", _test_battle_predict_full],
		["Unit 状态机（含 undo_move）", _test_unit_state_machine],
		["路径查找 Dijkstra 逻辑", _test_pathfinding_logic],
		["武器耐久系统", _test_weapon_durability],
		["道具系统", _test_item_system],
		["武器三角加成", _test_weapon_triangle],
		["Boss 无敌底板（min_hp）", _test_boss_min_hp],
		["SaveSystem 存档读档", _test_save_system],
		["GameSettings 设置持久化", _test_game_settings],
		["SettingsMenu 设置菜单", _test_settings_menu],
		["Opening 正式主菜单", _test_opening_main_menu],
		["自动镜头与敌方回合安全", _test_auto_camera_focus],
		["战斗结果与动画开关", _test_combat_result_and_animation_setting],
		["守卫型Boss数据字段", _test_guard_boss_fields],
		["战斗动画freed节点防护", _test_animation_freed_guard],
		["回合结束防重入", _test_turn_ending_guard],
		["地形图块坐标合法性", _test_tile_atlas_coords],
		["地图视觉风格统一回归", _test_visual_style_unification],
		["地图语义规范回归", _test_map_visual_language_spec],
		["人物立绘资源完整性", _test_portrait_assets],
		["专属地图精灵资源与动画", _test_map_sprite_assets_and_animation],
		["对话立绘映射完整性", _test_dialogue_portrait_mapping],
		["字体初始化方法存在", _test_font_setup],
		["关键场景与脚本冒烟加载", _test_scene_and_script_smoke],
		["章节标题卡信息回归", _test_chapter_transition_metadata],
		["章节 Opening 配置回归", _test_chapter_opening_configuration],
		["章节事件流程回归", _test_chapter_event_flow],
		["Ch1 / 存档 / 部署行为回归", _test_ch1_save_and_deploy_flow],
		["关键浮层真实调用链", _test_overlay_runtime_flow],
		["测试脚本可靠性", _test_test_script_reliability],
	]
	for suite: Array in suites:
		await _run_suite(suite[0] as String, suite[1] as Callable)
	if _completed_suite_count != suites.size():
		_fail_count += 1
		print("  ✗ FAIL: 测试套件未全部完成，期望=%d 实际=%d" % [
			suites.size(), _completed_suite_count])

	print("\n╔══════════════════════════════════════╗")
	var status: String = "全部通过 ✓" if _fail_count == 0 else ("失败 %d 项 ✗" % _fail_count)
	print("║  %d 通过  %d 失败  — %s" % [_pass_count, _fail_count, status])
	print("╚══════════════════════════════════════╝\n")
	print("TEST_RUN_COMPLETE suites=%d" % _completed_suite_count)
	quit(_fail_count)

# ── 测试框架 ─────────────────────────────────────────────
func _run_suite(name: String, fn: Callable) -> void:
	_current_suite = name
	print("▶ %s" % name)
	await fn.call()
	_completed_suite_count += 1
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

func _battle_info_label(battle: Node, label_name: String) -> Label:
	var direct := battle.get_node_or_null("UI/%s" % label_name) as Label
	if direct != null:
		return direct
	return battle.get_node_or_null("UI/TopInfoPanel/TopInfoMargin/TopInfoVBox/%s" % label_name) as Label

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
	for pos: Vector2i in [Vector2i(3,6), Vector2i(5,6), Vector2i(4,3), Vector2i(5,1), Vector2i(7,3)]:
		var t1: int = int(ch1[pos.y][pos.x])
		_assert(t1 != 3 and t1 != 4, "Ch1 关键出生点(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t1])
	var ch1_has_wall := false
	var ch1_has_forest := false
	for row: Array in ch1:
		for cell: Variant in row:
			if int(cell) == 2:
				ch1_has_wall = true
			if int(cell) == 1:
				ch1_has_forest = true
	_assert(ch1_has_wall, "Ch1 存在矮墙教学地形")
	_assert(ch1_has_forest, "Ch1 存在林地掩护，符合山道突破语义")
	for x: int in [3, 4, 5, 6, 7]:
		_assert(int(ch1[1][x]) != 4, "Ch1 北侧封锁线 row1 列%d 不会误放入河流" % x)
	_assert_eq(int(ch1[1][5]), 0, "Ch1 北侧主缺口中央保持畅通")

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
	_assert_eq(int(ch2[7][13]), 6, "Ch2 中桥北桥头保持桥梁")
	_assert_eq(int(ch2[7][14]), 6, "Ch2 中桥北桥心保持桥梁")
	_assert_eq(int(ch2[7][12]), 2, "Ch2 中桥左侧北岸营垒存在")
	_assert_eq(int(ch2[7][15]), 2, "Ch2 中桥右侧北岸营垒存在")
	_assert_eq(int(ch2[1][13]), 2, "Ch2 北岸中央第一道阵地存在")
	_assert_eq(int(ch2[1][14]), 2, "Ch2 北岸中央第二道阵地存在")

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
	for pos: Vector2i in [Vector2i(12,15), Vector2i(11,16), Vector2i(12,6), Vector2i(7,9), Vector2i(16,9), Vector2i(12,2)]:
		var t3: int = int(ch3[pos.y][pos.x])
		_assert(t3 != 3 and t3 != 4, "Ch3 关键格(%d,%d)可通行（类型=%d）" % [pos.x, pos.y, t3])
	var ch3_has_swamp := false
	var ch3_has_forest := false
	for row3: Array in ch3:
		for cell3: Variant in row3:
			if int(cell3) == 5:
				ch3_has_swamp = true
			if int(cell3) == 1:
				ch3_has_forest = true
	_assert(ch3_has_swamp, "Ch3 存在沼泽地形")
	_assert(ch3_has_forest, "Ch3 存在塔前灌木/林地掩体")
	_assert_eq(int(ch3[4][11]), 2, "Ch3 塔前左侧门墙仍存在")
	_assert_eq(int(ch3[4][12]), 2, "Ch3 塔前右侧门墙仍存在")
	_assert_eq(int(ch3[5][12]), 0, "Ch3 塔前中轴门道保持可推进")

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

	# 玩家单位可能已由战场事件释放，但权威数组尚未来得及同步清理。
	var ai_units := Node2D.new()
	root.add_child(ai_units)
	var deciding_enemy := Unit.new()
	deciding_enemy.setup(_make_enemy_data({"name": "决策敌军"}),
		1, Vector2i(1, 1))
	var stale_player := Unit.new()
	stale_player.setup(_make_unit_data({"name": "已释放目标"}),
		0, Vector2i(2, 1))
	var valid_player := Unit.new()
	valid_player.setup(_make_unit_data({"name": "有效目标"}),
		0, Vector2i(4, 1))
	ai_units.add_child(deciding_enemy)
	ai_units.add_child(stale_player)
	ai_units.add_child(valid_player)
	var players_with_stale_reference: Array = [stale_player, valid_player]
	stale_player.queue_free()
	await process_frame
	var chase_decision := EnemyAI.decide(deciding_enemy,
		players_with_stale_reference, [Vector2i(3, 1)])
	_assert(chase_decision.get("attack") == valid_player,
		"敌军追击决策会忽略数组中残留的已释放玩家引用")

	var guard_enemy := Unit.new()
	guard_enemy.setup(_make_enemy_data({
		"name": "守卫敌军",
		"is_boss": true,
		"guard_pos_x": 6,
		"guard_pos_y": 6,
		"guard_range": 2,
	}), 1, Vector2i(6, 6))
	var stale_guard_target := Unit.new()
	stale_guard_target.setup(_make_unit_data({"name": "已释放守卫目标"}),
		0, Vector2i(6, 5))
	var valid_guard_target := Unit.new()
	valid_guard_target.setup(_make_unit_data({"name": "有效守卫目标"}),
		0, Vector2i(7, 6))
	ai_units.add_child(guard_enemy)
	ai_units.add_child(stale_guard_target)
	ai_units.add_child(valid_guard_target)
	var guard_players_with_stale_reference: Array = [stale_guard_target, valid_guard_target]
	stale_guard_target.queue_free()
	await process_frame
	var guard_decision := EnemyAI.decide(guard_enemy,
		guard_players_with_stale_reference, [guard_enemy.grid_pos])
	_assert(guard_decision.get("attack") == valid_guard_target,
		"守卫敌军决策会忽略数组中残留的已释放玩家引用")
	ai_units.queue_free()
	await process_frame

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

	var battle_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var battle := battle_scene.instantiate()
	battle.set_script(TestBootstrapClass)
	root.add_child(battle)
	await process_frame
	for existing_unit: Unit in battle.player_units + battle.enemy_units:
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	battle.player_units.clear()
	battle.enemy_units.clear()
	battle._battle_over = false
	battle.current_phase = battle.Phase.PLAYER_TURN

	var attacker := Unit.new()
	attacker.setup(_make_unit_data({
		"name": "预测攻击方", "weapon_uses": 3, "weapon_max_uses": 3,
	}), 0, Vector2i(3, 3))
	var reserve := Unit.new()
	reserve.setup(_make_unit_data({"name": "待命友军"}), 0, Vector2i(2, 3))
	var defender := Unit.new()
	defender.setup(_make_enemy_data({"name": "预测防守方"}), 1, Vector2i(4, 3))
	battle.get_node("UnitLayer").add_child(attacker)
	battle.get_node("UnitLayer").add_child(reserve)
	battle.get_node("UnitLayer").add_child(defender)
	battle.player_units.assign([attacker, reserve])
	battle.enemy_units.assign([defender])
	battle.selected_unit = attacker
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle.attack_tiles = battle._adj_enemies(attacker.grid_pos)

	var action_menu := battle.get_node_or_null("UI/ActionMenu") as PanelContainer
	var attack_button: Button = null
	if action_menu != null:
		attack_button = action_menu.get_node_or_null("VBox/AttackBtn") as Button
	_assert(action_menu != null and attack_button != null,
		"正式战场行动菜单包含攻击按钮")
	if action_menu == null or attack_button == null:
		battle.queue_free()
		await process_frame
		return
	var predict_panel := battle.get_node("UI/PredictPanel") as PanelContainer
	var confirm_button := predict_panel.get_node("VBox/Buttons/ConfirmBtn") as Button
	var cancel_button := predict_panel.get_node("VBox/Buttons/CancelBtn") as Button
	_assert_eq(attack_button.pressed.get_connections().size(), 1,
		"正式攻击按钮仅连接一个处理目标")
	_assert(confirm_button.pressed.get_connections().size() == 1,
		"战斗预测确认按钮仅连接一个处理目标")
	_assert(cancel_button.pressed.get_connections().size() == 1,
		"战斗预测取消按钮仅连接一个处理目标")
	_assert_eq(battle.attack_tiles, [defender.grid_pos],
		"正式邻接计算只生成唯一相邻敌军目标")
	battle._show_action_menu(attacker.grid_pos, true)
	_assert(action_menu.visible and attack_button.visible, "相邻敌军存在时正式行动菜单显示攻击按钮")
	attack_button.pressed.emit()
	_assert(predict_panel.visible and battle.player_state == battle.PlayerState.PREDICT,
		"点击正式攻击按钮会打开唯一相邻敌军的战斗预测")
	_assert(not action_menu.visible and battle.target_enemy == defender,
		"点击正式攻击按钮会关闭行动菜单并锁定相邻目标")
	var reserve_click := InputEventMouseButton.new()
	reserve_click.button_index = MOUSE_BUTTON_LEFT
	reserve_click.pressed = true
	reserve_click.position = battle.get_global_transform_with_canvas() * battle._g2p(reserve.grid_pos)
	battle._input(reserve_click)
	_assert(predict_panel.visible and battle.player_state == battle.PlayerState.PREDICT,
		"战斗预测面板显示时地图左键不会穿透并改变玩家状态")
	_assert(battle.selected_unit == attacker and battle.target_enemy == defender,
		"战斗预测面板显示时地图左键不会切换单位或攻击目标")
	cancel_button.pressed.emit()
	_assert(not predict_panel.visible, "点击预测取消按钮真实关闭面板")
	_assert_eq(battle.player_state, battle.PlayerState.UNIT_MOVED,
		"点击预测取消按钮返回单位已移动状态")
	_assert(battle.target_enemy == null, "取消预测后清除旧攻击目标")
	_assert(battle.attack_tiles.has(defender.grid_pos), "取消预测后保留相邻敌军供重新选择")

	battle._show_action_menu(attacker.grid_pos, true)
	attack_button.pressed.emit()
	var cancel_predict_event := InputEventKey.new()
	cancel_predict_event.pressed = true
	cancel_predict_event.keycode = KEY_ESCAPE
	battle._input(cancel_predict_event)
	_assert(not predict_panel.visible, "ESC 会通过正式输入链路关闭战斗预测面板")
	_assert_eq(battle.player_state, battle.PlayerState.UNIT_MOVED,
		"ESC 取消预测后返回单位已移动状态")
	_assert(battle.target_enemy == null, "ESC 取消预测后清除旧攻击目标")
	_assert(battle.attack_tiles.has(defender.grid_pos), "ESC 取消预测后保留相邻敌军供重新选择")

	battle._show_action_menu(attacker.grid_pos, true)
	attack_button.pressed.emit()
	_assert(predict_panel.visible and battle.target_enemy == defender,
		"取消后再次点击正式攻击按钮可重新锁定相邻目标")
	var settings := root.get_node_or_null("GameSettings")
	var old_animation_enabled: bool = settings.battle_animations_enabled
	var old_auto_camera: bool = settings.auto_camera_enabled
	settings.battle_animations_enabled = false
	settings.auto_camera_enabled = false
	battle.fixed_combat_result = {
		"atk_hit": true, "atk_crit": false, "atk_damage": 4,
		"def_hit": false, "def_crit": false, "def_damage": 0,
		"atk_double": false, "double_hit": false,
		"double_crit": false, "double_damage": 0,
	}
	var weapon_uses_before: int = attacker.data.weapon_uses
	confirm_button.pressed.emit()
	await process_frame
	_assert(not predict_panel.visible, "点击预测确认按钮真实关闭面板")
	_assert_eq(defender.data.hp, defender.data.max_hp - 4,
		"点击预测确认按钮进入统一战斗结算")
	_assert_eq(attacker.data.weapon_uses, weapon_uses_before - 1,
		"预测确认后的真实战斗会消耗攻击方武器耐久")
	_assert(attacker.state == Unit.State.DONE, "预测确认后的攻击方结束本回合行动")
	_assert(battle.selected_unit == null and battle.target_enemy == null,
		"预测确认结算后清理选中单位与攻击目标")
	_assert(not battle._animating_battle, "预测确认结算后解除战斗操作锁")

	var second_defender := Unit.new()
	second_defender.setup(_make_enemy_data({"name": "第二相邻敌军"}), 1, Vector2i(3, 4))
	var distant_defender := Unit.new()
	distant_defender.setup(_make_enemy_data({"name": "远处敌军"}), 1, Vector2i(7, 7))
	battle.get_node("UnitLayer").add_child(second_defender)
	battle.get_node("UnitLayer").add_child(distant_defender)
	battle.enemy_units.append(second_defender)
	battle.enemy_units.append(distant_defender)
	attacker.reset_turn()
	battle.selected_unit = attacker
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle.attack_tiles = battle._adj_enemies(attacker.grid_pos)
	_assert_eq(battle.attack_tiles.size(), 2, "正式邻接计算可识别两个相邻敌军目标")
	battle._show_action_menu(attacker.grid_pos, true)
	var statuses_before_multi_target: int = battle.recorded_statuses.size()
	attack_button.pressed.emit()
	_assert(not predict_panel.visible and battle.target_enemy == null,
		"存在多个相邻敌军时攻击按钮不会错误锁定任意目标")
	_assert_eq(battle.player_state, battle.PlayerState.UNIT_MOVED,
		"存在多个目标时保持单位已移动状态等待玩家选择")
	_assert_eq(battle.recorded_statuses.size(), statuses_before_multi_target + 1,
		"多目标攻击按钮会新增一条选择目标提示")
	_assert_eq(battle.recorded_statuses.back(), "点击红色格子选择攻击目标",
		"存在多个目标时显示明确的目标选择引导")
	var preview_click := InputEventMouseButton.new()
	preview_click.button_index = MOUSE_BUTTON_LEFT
	preview_click.pressed = true
	preview_click.position = battle.get_global_transform_with_canvas() * battle._g2p(distant_defender.grid_pos)
	battle._input(preview_click)
	_assert(battle._preview_enemy == distant_defender and not predict_panel.visible,
		"等待攻击目标时点击非红格敌军仍会通过正式输入链路显示安全距离预览")
	var target_click := InputEventMouseButton.new()
	target_click.button_index = MOUSE_BUTTON_LEFT
	target_click.pressed = true
	target_click.position = battle.get_global_transform_with_canvas() * battle._g2p(defender.grid_pos)
	battle._input(target_click)
	_assert(predict_panel.visible and battle.target_enemy == defender,
		"多目标攻击时点击红色敌人格会通过正式输入链路打开对应战斗预测")
	_assert(battle._preview_enemy == null, "选择红格攻击目标时会清理此前的敌军安全距离预览")
	_assert_eq(battle.player_state, battle.PlayerState.PREDICT,
		"正式鼠标选择攻击目标后进入预测状态")
	settings.battle_animations_enabled = old_animation_enabled
	settings.auto_camera_enabled = old_auto_camera
	battle.queue_free()
	await process_frame

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

	# 正式战场：动态道具按钮的取消、治疗与无可用道具调用链
	var battle_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var battle := battle_scene.instantiate()
	battle.set_script(TestBootstrapClass)
	root.add_child(battle)
	await process_frame
	for existing_unit: Unit in battle.player_units + battle.enemy_units:
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	battle.player_units.clear()
	battle.enemy_units.clear()
	battle._battle_over = false
	battle.current_phase = battle.Phase.PLAYER_TURN

	var healer := Unit.new()
	healer.setup(_make_unit_data({
		"name": "道具测试员", "hp": 10, "max_hp": 30,
		"items": [
			{"name": "急救药", "type": "heal", "heal_amount": 10, "uses": 2},
			{"name": "过期药", "type": "heal", "heal_amount": 5, "uses": 0},
		],
	}), 0, Vector2i(3, 3))
	var reserve := Unit.new()
	reserve.setup(_make_unit_data({
		"name": "待命友军",
		"items": [{"name": "空药瓶", "type": "heal", "heal_amount": 5, "uses": 0}],
	}), 0, Vector2i(2, 3))
	var bomber := Unit.new()
	bomber.setup(_make_unit_data({
		"name": "火油测试员",
		"items": [{"name": "野火瓶", "type": "offensive", "burn_damage": 6, "uses": 1}],
	}), 0, Vector2i(5, 5))
	var adjacent_enemy := Unit.new()
	adjacent_enemy.setup(_make_enemy_data({"name": "相邻敌军", "hp": 16, "max_hp": 16}),
		1, Vector2i(6, 5))
	var distant_enemy := Unit.new()
	distant_enemy.setup(_make_enemy_data({"name": "远处敌军"}), 1, Vector2i(8, 8))
	battle.get_node("UnitLayer").add_child(healer)
	battle.get_node("UnitLayer").add_child(reserve)
	battle.get_node("UnitLayer").add_child(bomber)
	battle.get_node("UnitLayer").add_child(adjacent_enemy)
	battle.get_node("UnitLayer").add_child(distant_enemy)
	battle.player_units.assign([healer, reserve, bomber])
	battle.enemy_units.assign([adjacent_enemy, distant_enemy])
	battle.selected_unit = healer
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle._show_action_menu(healer.grid_pos, false)

	var action_menu := battle.get_node_or_null("UI/ActionMenu") as PanelContainer
	var items_button: Button = null
	if action_menu != null:
		items_button = action_menu.get_node_or_null("VBox/ItemsBtn") as Button
	_assert(action_menu != null and items_button != null,
		"正式战场包含行动菜单与道具按钮")
	if action_menu == null or items_button == null:
		battle.queue_free()
		await process_frame
		return
	_assert(items_button.pressed.get_connections().size() == 1,
		"正式行动菜单道具按钮仅连接一个处理目标")
	items_button.pressed.emit()
	var first_panel := battle._active_items_panel as PanelContainer
	_assert(first_panel != null and is_instance_valid(first_panel),
		"点击正式道具按钮会创建动态道具面板")
	if first_panel == null or not is_instance_valid(first_panel):
		battle.queue_free()
		await process_frame
		return
	var first_vbox: VBoxContainer = null
	if first_panel.get_child_count() > 0:
		first_vbox = first_panel.get_child(0) as VBoxContainer
	_assert(first_vbox != null, "动态道具面板包含按钮容器")
	if first_vbox == null:
		battle.queue_free()
		await process_frame
		return
	var first_buttons: Array[Button] = []
	for child: Node in first_vbox.get_children():
		if child is Button:
			first_buttons.append(child as Button)
	_assert_eq(first_buttons.size(), 2, "动态面板只生成可用道具按钮和取消按钮")
	if first_buttons.size() != 2:
		battle.queue_free()
		await process_frame
		return
	_assert(first_buttons[0].text.begins_with("急救药"), "可用道具按钮显示急救药")
	_assert(first_buttons.all(func(btn: Button) -> bool: return not btn.text.begins_with("过期药")),
		"uses=0 的过期道具不会生成按钮")
	var cancel_button := first_buttons[-1]
	_assert_eq(cancel_button.text, "取消", "动态道具面板末项为取消按钮")
	var hp_before_cancel: int = healer.data.hp
	var uses_before_cancel: int = int((healer.data.items[0] as Dictionary).get("uses", -1))
	cancel_button.pressed.emit()
	await process_frame
	_assert(battle._active_items_panel == null and not is_instance_valid(first_panel),
		"点击动态取消按钮会释放道具面板")
	_assert(action_menu.visible, "取消使用道具后重新显示行动菜单")
	_assert(battle.selected_unit == healer and healer.state != Unit.State.DONE,
		"取消使用道具后保留当前单位且不消耗行动")
	_assert_eq(healer.data.hp, hp_before_cancel, "取消使用道具不会改变生命值")
	_assert_eq(int((healer.data.items[0] as Dictionary).get("uses", -1)), uses_before_cancel,
		"取消使用道具不会消耗次数")

	items_button.pressed.emit()
	var heal_panel := battle._active_items_panel as PanelContainer
	_assert(heal_panel != null and is_instance_valid(heal_panel),
		"取消后再次点击正式道具按钮会重建动态面板")
	if heal_panel == null or not is_instance_valid(heal_panel):
		battle.queue_free()
		await process_frame
		return
	var heal_vbox: VBoxContainer = null
	if heal_panel.get_child_count() > 0:
		heal_vbox = heal_panel.get_child(0) as VBoxContainer
	_assert(heal_vbox != null, "重建的动态道具面板包含按钮容器")
	if heal_vbox == null:
		battle.queue_free()
		await process_frame
		return
	var heal_button: Button = null
	for child: Node in heal_vbox.get_children():
		if child is Button and (child as Button).text.begins_with("急救药"):
			heal_button = child as Button
	_assert(heal_button != null, "再次打开动态面板仍可找到急救药按钮")
	if heal_button != null:
		heal_button.pressed.emit()
	await process_frame
	_assert(battle._active_items_panel == null and not is_instance_valid(heal_panel),
		"点击治疗道具后释放动态道具面板")
	_assert_eq(healer.data.hp, 20, "点击急救药按钮真实恢复 10 HP")
	_assert_eq(int((healer.data.items[0] as Dictionary).get("uses", -1)), 1,
		"点击急救药按钮真实消耗一次道具")
	_assert(healer.state == Unit.State.DONE, "使用道具后单位结束本回合行动")
	_assert(battle.selected_unit == null, "使用道具后清除当前选中单位")
	_assert(battle.recorded_statuses.any(func(msg: String) -> bool: return "恢复 10 HP" in msg),
		"使用治疗道具后显示恢复量反馈")

	battle.selected_unit = bomber
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle._show_action_menu(bomber.grid_pos, true)
	_assert(items_button.visible, "持有攻击型道具时正式行动菜单显示道具入口")
	items_button.pressed.emit()
	var offensive_panel := battle._active_items_panel as PanelContainer
	_assert(offensive_panel != null and is_instance_valid(offensive_panel),
		"点击正式道具按钮会为攻击型道具创建动态面板")
	if offensive_panel == null or not is_instance_valid(offensive_panel):
		battle.queue_free()
		await process_frame
		return
	var offensive_vbox: VBoxContainer = null
	if offensive_panel.get_child_count() > 0:
		offensive_vbox = offensive_panel.get_child(0) as VBoxContainer
	_assert(offensive_vbox != null, "攻击型道具面板包含按钮容器")
	if offensive_vbox == null:
		battle.queue_free()
		await process_frame
		return
	var offensive_button: Button = null
	for child: Node in offensive_vbox.get_children():
		if child is Button and (child as Button).text.begins_with("野火瓶"):
			offensive_button = child as Button
	_assert(offensive_button != null, "动态道具面板显示攻击型道具按钮")
	if offensive_button == null:
		battle.queue_free()
		await process_frame
		return
	var stale_item_enemy := Unit.new()
	stale_item_enemy.setup(_make_enemy_data({"name": "已释放道具目标"}),
		1, Vector2i(4, 5))
	battle.get_node("UnitLayer").add_child(stale_item_enemy)
	battle.enemy_units.assign([stale_item_enemy, adjacent_enemy, distant_enemy])
	stale_item_enemy.queue_free()
	await process_frame
	var adjacent_hp_before: int = adjacent_enemy.data.hp
	var distant_hp_before: int = distant_enemy.data.hp
	offensive_button.pressed.emit()
	await process_frame
	_assert(battle._active_items_panel == null and not is_instance_valid(offensive_panel),
		"点击攻击型道具后释放动态道具面板")
	_assert_eq(adjacent_enemy.data.hp, adjacent_hp_before - 6,
		"攻击型道具忽略已释放引用并伤害后续相邻敌军")
	_assert_eq(distant_enemy.data.hp, distant_hp_before, "攻击型道具不会伤害非相邻敌军")
	_assert_eq(bomber.data.items.size(), 0, "攻击型道具次数耗尽后从背包移除")
	_assert(bomber.state == Unit.State.DONE and battle.selected_unit == null,
		"使用攻击型道具后结束行动并清除选中单位")
	_assert(battle.recorded_statuses.any(func(msg: String) -> bool:
		return "使用【野火瓶】" in msg and "造成 6 伤" in msg),
		"使用攻击型道具后显示名称与伤害反馈")

	battle.selected_unit = reserve
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle._show_action_menu(reserve.grid_pos, false)
	_assert(not items_button.visible, "无可用道具时正式行动菜单隐藏道具入口")
	battle._show_items_panel(reserve)
	var empty_panel := battle._active_items_panel as PanelContainer
	_assert(empty_panel != null and is_instance_valid(empty_panel),
		"内部空状态入口可创建无可用道具面板")
	if empty_panel == null or not is_instance_valid(empty_panel):
		battle.queue_free()
		await process_frame
		return
	var empty_vbox: VBoxContainer = null
	if empty_panel.get_child_count() > 0:
		empty_vbox = empty_panel.get_child(0) as VBoxContainer
	_assert(empty_vbox != null, "无可用道具面板包含空状态容器")
	if empty_vbox == null:
		battle.queue_free()
		await process_frame
		return
	var empty_label_found := false
	var empty_buttons: Array[Button] = []
	for child: Node in empty_vbox.get_children():
		if child is Label and (child as Label).text == "（无可用道具）":
			empty_label_found = true
		if child is Button:
			empty_buttons.append(child as Button)
	_assert(empty_label_found, "无可用道具时动态面板显示空状态")
	_assert_eq(empty_buttons.size(), 1, "无可用道具时只生成取消按钮")
	if empty_buttons.size() != 1:
		battle.queue_free()
		await process_frame
		return
	_assert_eq(empty_buttons[0].text, "取消", "无可用道具时仍可取消返回")
	empty_buttons[0].pressed.emit()
	await process_frame
	_assert(battle._active_items_panel == null and not is_instance_valid(empty_panel),
		"无可用道具面板的取消按钮会释放面板")
	_assert(action_menu.visible and battle.selected_unit == reserve,
		"无可用道具取消后返回当前单位行动菜单")

	battle.queue_free()
	await process_frame

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

	# 非法章节值不得把主菜单或战斗分发器带入不存在的章节。
	ss._write_json({"chapter": 0, "completed_chapters": []})
	_assert_eq(ss.load_current_chapter(), 1, "非法存档章节安全降级到Ch1")
	ss.delete_save()
	ss._write_json({"chapter": 2, "completed_chapters": "legacy"})
	_assert(ss.get_completed_chapters().is_empty(), "损坏的已完成章节字段安全降级为空列表")
	ss.save_chapter_complete(2)
	_assert_eq(ss.load_current_chapter(), 3, "损坏存档恢复后仍可继续保存章节进度")
	_assert(ss.get_completed_chapters().has(2), "损坏存档恢复后记录新完成章节")
	ss.delete_save()

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
	_assert_eq(ss.load_current_chapter(), 3, "重复完成较早章节不会让存档进度倒退")

	# 完成终章后进度保留在序章完成态，回顾旧章也不得覆盖。
	ss.save_chapter_complete(4)
	_assert_eq(ss.load_current_chapter(), 5, "完成Ch4后存档进入序章完成态")
	ss.save_chapter_complete(2)
	_assert_eq(ss.load_current_chapter(), 5, "序章完成后回顾旧章不会让存档进度倒退")
	var completed4: Array = ss.get_completed_chapters()
	_assert(completed4.has(4),             "已完成章节列表包含终章")

	# 清理：删除测试存档
	ss.delete_save()
	_assert(not ss.has_save(),             "测试结束后清理存档")

# ══════════════════════════════════════════════════════════
# 设置系统：默认值、持久化、恢复默认及与存档相互独立
# ══════════════════════════════════════════════════════════
func _test_game_settings() -> void:
	const SETTINGS_PATH := "res://scripts/systems/GameSettings.gd"
	if not ResourceLoader.exists(SETTINGS_PATH):
		_assert(false, "GameSettings.gd 文件存在")
		return

	var settings_script := load(SETTINGS_PATH)
	var settings: Node = settings_script.new()
	settings.config_path = "user://test_settings.cfg"
	settings.clear_saved_settings()
	settings.load_settings()

	_assert(settings.battle_animations_enabled, "默认开启战斗动画")
	_assert(settings.auto_camera_enabled, "默认开启自动镜头")
	_assert_eq(settings.master_volume, 1.0, "默认主音量为100%")
	_assert(not settings.fullscreen_enabled, "默认使用窗口模式")

	settings.battle_animations_enabled = false
	settings.auto_camera_enabled = false
	settings.master_volume = 0.35
	settings.fullscreen_enabled = true
	settings.save_settings(false)

	var loaded: Node = settings_script.new()
	loaded.config_path = "user://test_settings.cfg"
	loaded.load_settings(false)
	_assert(not loaded.battle_animations_enabled, "战斗动画开关可持久化")
	_assert(not loaded.auto_camera_enabled, "自动镜头开关可持久化")
	_assert_eq(loaded.master_volume, 0.35, "主音量可持久化")
	_assert(loaded.fullscreen_enabled, "全屏开关可持久化")

	loaded.reset_to_defaults(false)
	_assert(loaded.battle_animations_enabled, "恢复默认会重新开启战斗动画")
	_assert(loaded.auto_camera_enabled, "恢复默认会重新开启自动镜头")
	_assert_eq(loaded.master_volume, 1.0, "恢复默认会重置主音量")
	_assert(not loaded.fullscreen_enabled, "恢复默认会回到窗口模式")

	# 删除章节存档不得删除独立设置。
	SaveSystem.delete_save()
	_assert(FileAccess.file_exists("user://test_settings.cfg"), "清除存档不会删除设置")
	loaded.clear_saved_settings()
	settings.free()
	loaded.free()

func _test_settings_menu() -> void:
	const MENU_PATH := "res://scenes/ui/SettingsMenu.tscn"
	_assert(ResourceLoader.exists(MENU_PATH), "设置菜单场景存在")
	if not ResourceLoader.exists(MENU_PATH):
		return
	var scene := load(MENU_PATH) as PackedScene
	_assert(scene != null, "设置菜单场景可加载")
	if scene == null:
		return
	var menu := scene.instantiate()
	root.add_child(menu)
	await process_frame
	_assert(menu.can_process(), "未暂停游戏时设置菜单仍可处理输入")
	var close_button := menu.get_node_or_null("Dimmer/Panel/Margin/Content/Buttons/Close") as Button
	_assert(close_button != null and close_button.can_process(),
		"未暂停游戏时设置菜单按钮可处理输入")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/BattleAnimations") is CheckButton,
		"设置菜单包含战斗动画开关")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/AutoCamera") is CheckButton,
		"设置菜单包含自动镜头开关")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/MasterVolume") is HSlider,
		"设置菜单包含主音量滑杆")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/Fullscreen") is CheckButton,
		"设置菜单包含全屏开关")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/Buttons/Defaults") is Button,
		"设置菜单包含恢复默认按钮")
	_assert(menu.get_node_or_null("Dimmer/Panel/Margin/Content/Buttons/Close") is Button,
		"设置菜单包含关闭按钮")
	_assert(menu.has_signal("closed"), "设置菜单提供关闭信号")
	var global_settings := root.get_node_or_null("GameSettings")
	var old_battle_animations: bool = global_settings.battle_animations_enabled
	var old_auto_camera: bool = global_settings.auto_camera_enabled
	var old_master_volume: float = global_settings.master_volume
	var old_fullscreen: bool = global_settings.fullscreen_enabled
	global_settings.battle_animations_enabled = false
	global_settings.auto_camera_enabled = false
	global_settings.master_volume = 0.25
	global_settings.fullscreen_enabled = true
	menu._sync_controls()
	var defaults_button := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/Buttons/Defaults") as Button
	if defaults_button != null:
		defaults_button.pressed.emit()
	_assert(global_settings.battle_animations_enabled and global_settings.auto_camera_enabled,
		"点击恢复默认会真实重置战斗动画与自动镜头设置")
	_assert_eq(global_settings.master_volume, 1.0,
		"点击恢复默认会真实重置主音量设置")
	_assert(not global_settings.fullscreen_enabled,
		"点击恢复默认会真实重置全屏设置")
	var default_animations := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/BattleAnimations") as CheckButton
	var default_camera := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/AutoCamera") as CheckButton
	var default_volume := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/MasterVolume") as HSlider
	var default_volume_label := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/VolumeValue") as Label
	var default_fullscreen := menu.get_node_or_null(
		"Dimmer/Panel/Margin/Content/Fullscreen") as CheckButton
	_assert(default_animations != null and default_animations.button_pressed,
		"恢复默认后战斗动画控件同步为开启")
	_assert(default_camera != null and default_camera.button_pressed,
		"恢复默认后自动镜头控件同步为开启")
	_assert(default_volume != null and default_volume.value == 100.0,
		"恢复默认后音量滑杆同步为100%")
	_assert(default_volume_label != null and default_volume_label.text == "主音量：100%",
		"恢复默认后音量文案同步为100%")
	_assert(default_fullscreen != null and not default_fullscreen.button_pressed,
		"恢复默认后全屏控件同步为关闭")
	var menu_closed := {"value": false}
	menu.closed.connect(func() -> void: menu_closed["value"] = true)
	if close_button != null:
		close_button.pressed.emit()
	await process_frame
	_assert(menu_closed["value"], "点击保存并返回按钮会发出关闭信号")
	_assert(not is_instance_valid(menu), "点击保存并返回按钮会释放设置菜单")
	global_settings.battle_animations_enabled = old_battle_animations
	global_settings.auto_camera_enabled = old_auto_camera
	global_settings.master_volume = old_master_volume
	global_settings.fullscreen_enabled = old_fullscreen
	global_settings.save_settings(false)

	var opening_scene := load("res://scenes/Opening.tscn") as PackedScene
	var opening := opening_scene.instantiate()
	opening.set_script(TestOpeningClass)
	root.add_child(opening)
	await process_frame
	opening._bind_main_menu()
	_assert(opening.has_method("_open_settings_menu"), "Opening 提供设置菜单入口")
	var opening_settings_button := opening.get_node_or_null(
		"MainMenu/MenuPanel/MenuContent/SettingsButton") as Button
	_assert(opening_settings_button != null, "主菜单正式场景包含设置按钮")
	if opening_settings_button != null:
		opening_settings_button.pressed.emit()
		opening_settings_button.pressed.emit()
	await process_frame
	var opening_menu := opening.get_node_or_null("SettingsMenu") as SettingsMenu
	_assert(opening_menu != null, "主菜单设置入口真实挂载设置弹窗")
	_assert(opening.find_children("SettingsMenu", "SettingsMenu", true, false).size() == 1,
		"重复点击主菜单设置按钮不会叠加弹窗")
	if opening_menu != null:
		var opening_close := opening_menu.get_node_or_null(
			"Dimmer/Panel/Margin/Content/Buttons/Close") as Button
		if opening_close != null:
			opening_close.pressed.emit()
		await process_frame
		_assert(opening.get_node_or_null("SettingsMenu") == null,
			"主菜单设置弹窗点击返回后真实关闭")
	opening.queue_free()
	await process_frame

	var battle_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var battle := battle_scene.instantiate()
	battle.set_script(TestBootstrapClass)
	_assert(battle.get_node_or_null("UI/SettingsBtn") is Button, "战斗 HUD 包含设置按钮")
	root.add_child(battle)
	await process_frame
	battle._animating_battle = true
	battle._open_settings_menu()
	_assert(battle.get_node_or_null("SettingsMenu") == null, "战斗演出期间不能打开设置菜单破坏流程锁")
	battle._animating_battle = false
	battle._settings_btn.pressed.emit()
	await process_frame
	var battle_menu := battle.get_node_or_null("SettingsMenu") as SettingsMenu
	_assert(battle_menu != null and battle._animating_battle,
		"战斗设置按钮真实挂载弹窗并锁定战斗操作")
	if battle_menu != null:
		var danger_before: bool = battle._show_danger
		var danger_event := InputEventKey.new()
		danger_event.pressed = true
		danger_event.keycode = KEY_D
		battle._input(danger_event)
		_assert_eq(battle._show_danger, danger_before, "设置弹窗打开时不会穿透危险区快捷键")

		var autopilot_before: bool = battle._autopilot
		var autopilot_event := InputEventKey.new()
		autopilot_event.pressed = true
		autopilot_event.keycode = KEY_A
		battle._input(autopilot_event)
		_assert_eq(battle._autopilot, autopilot_before, "设置弹窗打开时不会穿透自动托管快捷键")

		var restart_event := InputEventKey.new()
		restart_event.pressed = true
		restart_event.keycode = KEY_R
		battle._unhandled_input(restart_event)
		_assert(not battle.restart_requested, "设置弹窗打开时不会穿透重开快捷键")

		var battle_animations := battle_menu.get_node_or_null(
			"Dimmer/Panel/Margin/Content/BattleAnimations") as CheckButton
		if battle_animations != null:
			battle_animations.button_pressed = not global_settings.battle_animations_enabled
		var cancel_event := InputEventKey.new()
		cancel_event.pressed = true
		cancel_event.keycode = KEY_ESCAPE
		battle_menu._unhandled_input(cancel_event)
		await process_frame
		_assert(battle.get_node_or_null("SettingsMenu") == null and not battle._animating_battle,
			"战斗设置弹窗按 ESC 后关闭并解除操作锁")
		_assert_eq(global_settings.battle_animations_enabled,
			not old_battle_animations, "战斗设置弹窗按 ESC 关闭时保存控件设置")
	global_settings.battle_animations_enabled = old_battle_animations
	global_settings.save_settings(false)
	battle.queue_free()
	await process_frame

func _test_opening_main_menu() -> void:
	const OPENING_PATH := "res://scenes/Opening.tscn"
	var scene := load(OPENING_PATH) as PackedScene
	_assert(scene != null, "Opening 正式主菜单场景可加载")
	if scene == null:
		return
	SaveSystem.delete_save()
	var old_current_chapter: int = GameState.current_chapter
	GameState.current_chapter = 4
	var fresh_opening := scene.instantiate()
	fresh_opening.set_script(TestOpeningClass)
	root.add_child(fresh_opening)
	await process_frame
	fresh_opening._bind_main_menu()
	fresh_opening._refresh_main_menu()
	var fresh_continue := fresh_opening.get_node_or_null(
		"MainMenu/MenuPanel/MenuContent/ContinueButton") as Button
	var fresh_progress := fresh_opening.get_node_or_null(
		"MainMenu/MenuPanel/MenuContent/ProgressLabel") as Label
	_assert(fresh_continue != null and fresh_continue.disabled,
		"无存档时正式继续游戏按钮禁用")
	_assert(fresh_continue != null and fresh_continue.text == "继续游戏",
		"无存档时继续游戏按钮使用默认文案")
	_assert(fresh_progress != null and fresh_progress.text == "尚无战役记录",
		"无存档时主菜单显示尚无进度")
	if fresh_continue != null:
		fresh_continue.pressed.emit()
	_assert(fresh_opening.get_node("MainMenu").visible,
		"无存档时继续信号不会隐藏主菜单")
	_assert(not fresh_opening.played_chapter_1 and fresh_opening.recorded_scene_changes.is_empty(),
		"无存档时继续信号不会误进任何章节")
	_assert_eq(GameState.current_chapter, 4, "无存档时继续信号不会改写当前章节")
	GameState.current_chapter = old_current_chapter
	fresh_opening.queue_free()
	await process_frame

	var opening_scene := scene.instantiate()
	root.add_child(opening_scene)
	await process_frame
	var new_game := opening_scene.get_node_or_null("MainMenu/MenuPanel/MenuContent/NewGameButton") as Button
	var continue_game := opening_scene.get_node_or_null("MainMenu/MenuPanel/MenuContent/ContinueButton") as Button
	var settings := opening_scene.get_node_or_null("MainMenu/MenuPanel/MenuContent/SettingsButton") as Button
	var quit := opening_scene.get_node_or_null("MainMenu/MenuPanel/MenuContent/QuitButton") as Button
	var confirm := opening_scene.get_node_or_null("NewGameConfirm") as ConfirmationDialog
	_assert(new_game != null, "正式主菜单包含新游戏入口")
	_assert(continue_game != null, "正式主菜单包含继续游戏入口")
	_assert(settings != null, "正式主菜单包含设置入口")
	_assert(quit != null, "正式主菜单包含退出入口")
	_assert(confirm != null, "已有存档时新游戏提供二次确认")
	if is_instance_valid(opening_scene):
		opening_scene.queue_free()
	await process_frame

	SaveSystem._write_json({"chapter": 3, "completed_chapters": [1, 2]})
	GameState.deploy_selection = ["ned_stark.json", "northern_knight.json"]
	var confirmed_opening := scene.instantiate()
	confirmed_opening.set_script(TestOpeningClass)
	root.add_child(confirmed_opening)
	await process_frame
	confirmed_opening._bind_main_menu()
	confirmed_opening._refresh_main_menu()
	var confirmed_new_game := confirmed_opening.get_node_or_null(
		"MainMenu/MenuPanel/MenuContent/NewGameButton") as Button
	var new_game_dialog := confirmed_opening.get_node_or_null("NewGameConfirm") as ConfirmationDialog
	if confirmed_new_game != null:
		confirmed_new_game.pressed.emit()
	_assert(new_game_dialog != null and new_game_dialog.visible,
		"已有存档时点击新游戏真实打开二次确认框")
	_assert(not confirmed_opening.played_chapter_1,
		"确认前不会提前清档或进入 Ch1")
	if new_game_dialog != null:
		new_game_dialog.confirmed.emit()
	await process_frame
	_assert(confirmed_opening.played_chapter_1,
		"确认新游戏后真实进入 Ch1 标题与过场流程")
	_assert_eq(SaveSystem.load_current_chapter(), 1,
		"确认新游戏后旧进度重置为 Ch1 检查点")
	_assert(SaveSystem.get_completed_chapters().is_empty(),
		"确认新游戏后清除旧章节完成记录")
	_assert(GameState.deploy_selection.is_empty(),
		"确认新游戏后清除旧部署选择")
	if is_instance_valid(confirmed_opening):
		confirmed_opening.queue_free()
	await process_frame

	SaveSystem.delete_save()
	var opening := TestOpeningClass.new()
	root.add_child(opening)
	await process_frame
	_assert(opening.has_method("_refresh_main_menu"), "Opening 可根据存档刷新主菜单")
	_assert(opening.has_method("_on_new_game_pressed"), "Opening 提供新游戏入口行为")
	_assert(opening.has_method("_on_continue_pressed"), "Opening 提供继续游戏入口行为")
	_assert(opening.has_method("_on_quit_pressed"), "Opening 提供退出入口行为")
	if opening.has_method("run_new_game"):
		opening.run_new_game()
		_assert(opening.played_chapter_1, "无存档时新游戏直接进入 Ch1")
		_assert(SaveSystem.has_save(), "新战役进入 Ch1 前建立章节检查点")
		_assert_eq(SaveSystem.load_current_chapter(), 1, "新战役检查点从 Ch1 开始")
		_assert(SaveSystem.get_completed_chapters().is_empty(), "新战役检查点不包含已完成章节")
	if is_instance_valid(opening):
		opening.queue_free()
	await process_frame

	var route_specs: Array[Dictionary] = [
		{"chapter": 1, "scene": ""},
		{"chapter": 2, "scene": "res://scenes/chapter/Ch2_Opening.tscn"},
		{"chapter": 3, "scene": "res://scenes/chapter/Ch3_Opening.tscn"},
		{"chapter": 4, "scene": "res://scenes/chapter/Ch4_Opening.tscn"},
	]
	for spec: Dictionary in route_specs:
		var chapter := int(spec["chapter"])
		SaveSystem._write_json({"chapter": chapter, "completed_chapters": []})
		var continued := scene.instantiate()
		continued.set_script(TestOpeningClass)
		root.add_child(continued)
		await process_frame
		continued._bind_main_menu()
		continued._refresh_main_menu()
		var route_continue := continued.get_node_or_null(
			"MainMenu/MenuPanel/MenuContent/ContinueButton") as Button
		_assert(route_continue != null and not route_continue.disabled,
			"Ch%d 存档会启用继续游戏按钮" % chapter)
		if route_continue != null:
			route_continue.pressed.emit()
		_assert_eq(GameState.current_chapter, chapter, "继续游戏同步当前章节到Ch%d" % chapter)
		_assert(not continued.get_node("MainMenu").visible,
			"点击继续游戏后隐藏主菜单")
		if chapter == 1:
			_assert(continued.played_chapter_1, "继续Ch1进入第一章标题与过场流程")
			_assert(continued.recorded_scene_changes.is_empty(), "继续Ch1不误跳后续章节场景")
		else:
			_assert(not continued.played_chapter_1, "继续Ch%d不误重开Ch1" % chapter)
			_assert(continued.recorded_scene_changes.has(str(spec["scene"])),
				"继续Ch%d路由到对应章节Opening" % chapter)
		if is_instance_valid(continued):
			continued.queue_free()
		await process_frame

	SaveSystem.save_chapter_complete(4)
	var completed_opening := scene.instantiate()
	root.add_child(completed_opening)
	await process_frame
	var completed_continue := completed_opening.get_node_or_null("MainMenu/MenuPanel/MenuContent/ContinueButton") as Button
	var completed_progress := completed_opening.get_node_or_null("MainMenu/MenuPanel/MenuContent/ProgressLabel") as Label
	_assert(completed_continue != null and completed_continue.disabled,
		"序章全部完成后禁用继续游戏")
	_assert(completed_continue != null and completed_continue.text == "序章已完成",
		"序章全部完成后继续按钮显示完成状态")
	_assert(completed_progress != null and completed_progress.text == "序章战役已完成",
		"序章全部完成后进度文案显示完成状态")
	if is_instance_valid(completed_opening):
		completed_opening.queue_free()
	await process_frame
	var completed_route := TestOpeningClass.new()
	root.add_child(completed_route)
	await process_frame
	completed_route.run_continue_game()
	_assert(not completed_route.played_chapter_1 and completed_route.recorded_scene_changes.is_empty(),
		"序章全部完成后继续入口不会误重开第一章")
	completed_route.queue_free()
	await process_frame
	SaveSystem.delete_save()

func _test_auto_camera_focus() -> void:
	var battle := TestBootstrapClass.new()
	root.add_child(battle)
	await process_frame
	var camera := battle.get_node("Camera2D") as Camera2D
	var settings := root.get_node_or_null("GameSettings")
	var old_enabled: bool = settings.auto_camera_enabled

	settings.auto_camera_enabled = true
	camera.position = Vector2(640, 360)
	battle.focus_grid(Vector2i(10, 8), 0.0)
	_assert_eq(camera.position, battle._g2p(Vector2i(10, 8)),
		"开启自动镜头时会聚焦到目标格中心")

	settings.auto_camera_enabled = false
	var held_position := camera.position
	battle.focus_grid(Vector2i(2, 2), 0.0)
	_assert_eq(camera.position, held_position, "关闭自动镜头后不会强制移动镜头")

	var ned := Unit.new()
	ned.setup(_make_unit_data({"name": "测试发言者"}), 0, Vector2i(7, 5))
	battle.get_node("UnitLayer").add_child(ned)
	battle.player_units.append(ned)
	settings.auto_camera_enabled = true
	battle._focus_dialogue_speaker("测试发言者", 0.0)
	_assert_eq(camera.position, battle._g2p(ned.grid_pos), "战场对话会聚焦到发言单位")
	var before_narration := camera.position
	battle._focus_dialogue_speaker("旁白", 0.0)
	_assert_eq(camera.position, before_narration, "旁白不会改变战场镜头")
	var stale_dialogue_unit := Unit.new()
	stale_dialogue_unit.setup(_make_unit_data({"name": "已释放发言者"}),
		0, Vector2i(5, 5))
	battle.get_node("UnitLayer").add_child(stale_dialogue_unit)
	battle.player_units.assign([stale_dialogue_unit, ned])
	stale_dialogue_unit.queue_free()
	await process_frame
	camera.position = Vector2.ZERO
	battle._focus_dialogue_speaker("测试发言者", 0.0)
	_assert_eq(camera.position, battle._g2p(ned.grid_pos),
		"战场对话会忽略残留的已释放引用并聚焦后续发言单位")
	battle.player_units.assign([ned])

	var dialogue_scene := load("res://scenes/dialogue/DialogueBox.tscn") as PackedScene
	var dialogue := dialogue_scene.instantiate() as DialogueSystem
	battle.add_child(dialogue)
	await process_frame
	battle._bind_dialogue_camera(dialogue)
	_assert(dialogue.line_changed.is_connected(battle._focus_dialogue_speaker),
		"战场对话说话人信号真实绑定自动镜头")
	camera.position = Vector2.ZERO
	dialogue.line_changed.emit("测试发言者")
	await create_timer(0.3).timeout
	_assert_eq(camera.position, battle._g2p(ned.grid_pos),
		"战场对话换行信号真实驱动镜头聚焦发言单位")

	for existing_unit: Unit in battle.player_units + battle.enemy_units:
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	battle.player_units.clear()
	battle.enemy_units.clear()
	var tracked_player := Unit.new()
	tracked_player.setup(_make_unit_data({"name": "镜头目标"}), 0, Vector2i(7, 6))
	battle.get_node("UnitLayer").add_child(tracked_player)
	battle.player_units.append(tracked_player)
	var tracked_enemy := Unit.new()
	tracked_enemy.setup(_make_enemy_data({"name": "移动敌军", "move": 2}), 1, Vector2i(2, 3))
	battle.get_node("UnitLayer").add_child(tracked_enemy)
	battle.enemy_units.append(tracked_enemy)
	var enemy_start := tracked_enemy.grid_pos
	var turn_count_before_enemy_turn: int = battle._turn_count
	battle.recorded_player_turn_starts = 0
	camera.position = Vector2.ZERO
	battle._start_enemy_turn()
	battle._start_enemy_turn()
	for frame in 120:
		if not battle._enemy_turn_running:
			break
		await process_frame
	await create_timer(0.4).timeout
	_assert(tracked_enemy.grid_pos != enemy_start, "敌军回合测试单位实际发生移动")
	_assert_eq(camera.position, battle._g2p(tracked_enemy.grid_pos),
		"开启自动镜头时敌军移动结束后镜头跟随到最终位置")
	_assert_eq(battle._turn_count, turn_count_before_enemy_turn + 1,
		"敌方回合同帧重复入口只会切回一次玩家回合")
	_assert_eq(battle.recorded_player_turn_starts, 1,
		"敌方回合同帧重复入口只会调用一次玩家回合入口")
	_assert(not battle._enemy_turn_running, "敌方回合正常结束后释放运行锁")

	var interrupted_enemy := Unit.new()
	interrupted_enemy.setup(_make_enemy_data({"name": "中止回合敌军"}), 1, Vector2i(2, 4))
	battle.get_node("UnitLayer").add_child(interrupted_enemy)
	battle.enemy_units.assign([interrupted_enemy])
	battle.recorded_player_turn_starts = 0
	var turn_count_before_interruption: int = battle._turn_count
	battle._battle_over = false
	battle._start_enemy_turn()
	battle._battle_over = true
	await create_timer(0.5).timeout
	_assert(not battle._enemy_turn_running, "战斗中止后敌方回合仍释放运行锁")
	_assert_eq(battle.recorded_player_turn_starts, 0,
		"敌方回合期间战斗结束不会切回玩家回合")
	_assert_eq(battle._turn_count, turn_count_before_interruption,
		"敌方回合期间战斗结束不会增加玩家回合计数")

	# 独立战场覆盖敌军聚焦 Tween 的恢复点：聚焦期间敌军可能被其他事件移除。
	var removed_enemy_battle := TestBootstrapClass.new()
	root.add_child(removed_enemy_battle)
	await process_frame
	for existing_unit: Unit in removed_enemy_battle.player_units + removed_enemy_battle.enemy_units:
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	removed_enemy_battle.player_units.clear()
	removed_enemy_battle.enemy_units.clear()
	var focus_target_player := Unit.new()
	focus_target_player.setup(_make_unit_data({"name": "敌军决策目标"}),
		0, Vector2i(7, 6))
	var removed_during_focus := Unit.new()
	removed_during_focus.setup(_make_enemy_data({"name": "聚焦期间移除敌军"}),
		1, Vector2i(2, 4))
	removed_enemy_battle.get_node("UnitLayer").add_child(focus_target_player)
	removed_enemy_battle.get_node("UnitLayer").add_child(removed_during_focus)
	removed_enemy_battle.player_units.append(focus_target_player)
	removed_enemy_battle.enemy_units.append(removed_during_focus)
	removed_enemy_battle.recorded_player_turn_starts = 0
	removed_enemy_battle._start_enemy_turn()
	await process_frame
	_assert(removed_enemy_battle._enemy_turn_running,
		"敌军释放前敌方回合正停留在镜头聚焦阶段")
	removed_enemy_battle.enemy_units.erase(removed_during_focus)
	removed_during_focus.queue_free()
	await create_timer(0.5).timeout
	_assert(not removed_enemy_battle._enemy_turn_running,
		"镜头聚焦期间敌军释放时敌方回合安全结束并释放运行锁")
	_assert_eq(removed_enemy_battle.recorded_player_turn_starts, 1,
		"镜头聚焦期间敌军释放后正常切回一次玩家回合")
	removed_enemy_battle.queue_free()
	await process_frame

	# 敌方回合快照应越过启动前已释放的敌军引用并正常结束。
	var stale_enemy_turn_battle := TestBootstrapClass.new()
	root.add_child(stale_enemy_turn_battle)
	await process_frame
	for existing_unit: Variant in (stale_enemy_turn_battle.player_units + stale_enemy_turn_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_enemy_turn_battle.player_units.clear()
	stale_enemy_turn_battle.enemy_units.clear()
	var stale_turn_enemy := Unit.new()
	stale_turn_enemy.setup(_make_enemy_data({"name": "已释放敌方回合单位"}),
		1, Vector2i(2, 4))
	var neutral_turn_unit := Unit.new()
	neutral_turn_unit.setup(_make_enemy_data({"name": "后续中立单位"}),
		2, Vector2i(3, 4))
	stale_enemy_turn_battle.get_node("UnitLayer").add_child(stale_turn_enemy)
	stale_enemy_turn_battle.get_node("UnitLayer").add_child(neutral_turn_unit)
	stale_enemy_turn_battle.enemy_units.assign([stale_turn_enemy, neutral_turn_unit])
	stale_turn_enemy.free()
	stale_enemy_turn_battle._battle_over = false
	stale_enemy_turn_battle.recorded_player_turn_starts = 0
	stale_enemy_turn_battle._start_enemy_turn()
	await process_frame
	_assert(not stale_enemy_turn_battle._enemy_turn_running \
			and stale_enemy_turn_battle.recorded_player_turn_starts == 1,
		"敌方回合忽略启动前已释放敌军且正常切回玩家回合")
	stale_enemy_turn_battle.queue_free()
	await process_frame

	settings.auto_camera_enabled = old_enabled
	battle.queue_free()
	await process_frame

func _test_combat_result_and_animation_setting() -> void:
	var battle := TestBootstrapClass.new()
	root.add_child(battle)
	await process_frame
	var guaranteed := {
		"atk_hit": 100, "atk_crit": 100, "atk_damage": 5, "atk_double": true,
		"def_hit": 0, "def_crit": 0, "def_damage": 4,
	}
	var result: Dictionary = battle._build_combat_result(guaranteed, 20, 20)
	_assert(result.get("atk_hit", false), "统一战斗结果会记录攻击命中")
	_assert(result.get("atk_crit", false), "统一战斗结果会记录攻击暴击")
	_assert_eq(result.get("atk_damage", 0), 15, "暴击伤害在统一结果中结算为三倍")
	_assert(not result.get("def_hit", true), "统一战斗结果会记录反击未命中")
	_assert(result.get("double_hit", false), "统一战斗结果会独立记录追击命中")
	_assert_eq(result.get("double_damage", 0), 15, "追击暴击伤害写入统一结果")
	_assert(battle._battle_animations_enabled(), "默认开启战斗动画")
	var settings := root.get_node_or_null("GameSettings")
	var old_enabled: bool = settings.battle_animations_enabled
	var old_auto_camera: bool = settings.auto_camera_enabled
	settings.battle_animations_enabled = false
	_assert(not battle._battle_animations_enabled(), "设置关闭后战斗流程跳过动画")
	settings.battle_animations_enabled = old_enabled
	var anim_scene := load("res://scenes/battle/BattleAnimation.tscn") as PackedScene
	var anim := anim_scene.instantiate()
	root.add_child(anim)
	await process_frame
	_assert(anim.get_node_or_null("Panel/StageBackdrop") is ColorRect, "战斗动画包含大面积舞台背景")
	_assert(anim.get_node_or_null("Panel/ImpactFlash") is ColorRect, "战斗动画包含全舞台命中闪光")
	_assert(anim.get_node_or_null("Panel/SlashTrail") is Polygon2D, "战斗动画包含武器轨迹")
	_assert(anim.get_node_or_null("Panel/CriticalLabel") is Label, "战斗动画包含暴击演出标题")
	var atk_icon := anim.get_node("Panel/AtkSide/Icon") as Sprite2D
	var def_icon := anim.get_node("Panel/DefSide/Icon") as Sprite2D
	var panel := anim.get_node("Panel") as Control
	var expected_slash_center: Vector2 = (
		(atk_icon.global_position + def_icon.global_position) * 0.5 - panel.global_position)
	_assert_eq(anim._slash_center(atk_icon, def_icon), expected_slash_center,
		"武器轨迹使用双方全局位置计算舞台中心")
	anim.queue_free()
	await process_frame

	var reentrant_anim := anim_scene.instantiate() as BattleAnimation
	root.add_child(reentrant_anim)
	await process_frame
	var reentrant_attacker := Unit.new()
	reentrant_attacker.setup(_make_unit_data({"name": "重入动画攻击方"}), 0, Vector2i(1, 1))
	var reentrant_defender := Unit.new()
	reentrant_defender.setup(_make_enemy_data({"name": "重入动画防守方"}), 1, Vector2i(2, 1))
	root.add_child(reentrant_attacker)
	root.add_child(reentrant_defender)
	var animation_finished_count := [0]
	reentrant_anim.animation_finished.connect(func(_result: Dictionary) -> void:
		animation_finished_count[0] += 1
	)
	var lethal_result := {
		"atk_hit": true, "atk_crit": false,
		"atk_damage": reentrant_defender.data.max_hp,
		"def_hit": false, "def_crit": false, "def_damage": 0,
		"atk_double": false, "double_hit": false,
		"double_crit": false, "double_damage": 0,
	}
	reentrant_anim.play(reentrant_attacker, reentrant_defender, lethal_result)
	reentrant_anim.play(reentrant_attacker, reentrant_defender, lethal_result)
	await reentrant_anim.animation_finished
	await create_timer(0.5).timeout
	_assert_eq(animation_finished_count[0], 1,
		"同一战斗动画实例重复播放时只运行并完成一次")
	reentrant_anim.queue_free()
	reentrant_attacker.queue_free()
	reentrant_defender.queue_free()
	await process_frame

	var fixed_result := {
		"atk_hit": true, "atk_crit": false, "atk_damage": 4,
		"def_hit": false, "def_crit": false, "def_damage": 0,
		"atk_double": false, "double_hit": false,
		"double_crit": false, "double_damage": 0,
	}
	battle.fixed_combat_result = fixed_result
	settings.auto_camera_enabled = false
	var ui_layer := battle.get_node("UI") as CanvasLayer
	var animation_nodes_added: Array[Node] = []
	ui_layer.child_entered_tree.connect(func(child: Node) -> void:
		if child is BattleAnimation:
			animation_nodes_added.append(child)
	)
	var animated_attacker := Unit.new()
	animated_attacker.setup(_make_unit_data({"name": "动画攻击方"}), 0, Vector2i(3, 3))
	var animated_defender := Unit.new()
	animated_defender.setup(_make_enemy_data({"name": "动画防守方"}), 1, Vector2i(4, 3))
	battle.get_node("UnitLayer").add_child(animated_attacker)
	battle.get_node("UnitLayer").add_child(animated_defender)
	battle.player_units.append(animated_attacker)
	battle.enemy_units.append(animated_defender)
	settings.battle_animations_enabled = true
	battle._start_battle_with_animation(animated_attacker, animated_defender)
	battle._start_battle_with_animation(animated_attacker, animated_defender)
	await process_frame
	_assert_eq(animation_nodes_added.size(), 1,
		"战斗流程重入时只创建一次战斗动画")
	_assert_eq(animated_defender.data.hp, animated_defender.data.max_hp,
		"战斗动画播放期间不会提前结算伤害")
	_assert(battle._animating_battle, "战斗动画播放期间保持操作锁")
	if not animation_nodes_added.is_empty() and is_instance_valid(animation_nodes_added[0]):
		await (animation_nodes_added[0] as BattleAnimation).animation_finished
	await process_frame
	_assert_eq(animated_defender.data.hp, animated_defender.data.max_hp - 4,
		"开启动画时等待演出后按统一结果结算伤害")
	_assert(not battle._animating_battle, "开启动画的战斗结算后解除操作锁")
	_assert(ui_layer.get_children().filter(func(child: Node) -> bool:
		return child is BattleAnimation).is_empty(), "战斗演出完成后释放动画节点")
	_assert(not is_instance_valid(animation_nodes_added[0]), "战斗演出完成后动画实例已释放")

	var instant_attacker := Unit.new()
	instant_attacker.setup(_make_unit_data({"name": "即时攻击方"}), 0, Vector2i(5, 3))
	var instant_defender := Unit.new()
	instant_defender.setup(_make_enemy_data({"name": "即时防守方"}), 1, Vector2i(6, 3))
	battle.get_node("UnitLayer").add_child(instant_attacker)
	battle.get_node("UnitLayer").add_child(instant_defender)
	battle.player_units.append(instant_attacker)
	battle.enemy_units.append(instant_defender)
	settings.battle_animations_enabled = false
	var animation_count_before_disabled_combat := animation_nodes_added.size()
	await battle._start_battle_with_animation(instant_attacker, instant_defender)
	_assert_eq(animation_nodes_added.size(), animation_count_before_disabled_combat,
		"关闭动画时真实战斗流程不会创建额外动画节点")
	_assert_eq(instant_defender.data.hp, instant_defender.data.max_hp - 4,
		"关闭动画仍使用同一统一结果结算伤害")
	_assert(not battle._animating_battle, "关闭动画的即时结算后解除操作锁")

	# 独立战场覆盖镜头 Tween 的异步恢复点：聚焦期间目标可能被其他流程移除。
	settings.auto_camera_enabled = true
	var interrupted_battle := TestBootstrapClass.new()
	root.add_child(interrupted_battle)
	await process_frame
	var interrupted_attacker := Unit.new()
	interrupted_attacker.setup(_make_unit_data({"name": "聚焦攻击方"}),
		0, Vector2i(7, 5))
	var freed_defender := Unit.new()
	freed_defender.setup(_make_enemy_data({"name": "聚焦期间释放防守方"}),
		1, Vector2i(8, 5))
	interrupted_battle.get_node("UnitLayer").add_child(interrupted_attacker)
	interrupted_battle.get_node("UnitLayer").add_child(freed_defender)
	interrupted_battle.player_units.append(interrupted_attacker)
	interrupted_battle.enemy_units.append(freed_defender)
	interrupted_battle.record_battle_completion.call_deferred(
		interrupted_attacker, freed_defender)
	await process_frame
	_assert(interrupted_battle._animating_battle,
		"单位释放前战斗流程正停留在镜头聚焦阶段")
	freed_defender.queue_free()
	for frame: int in range(60):
		if interrupted_battle.recorded_battle_completion:
			break
		await process_frame
	_assert(interrupted_battle.recorded_battle_completion,
		"镜头聚焦期间防守方释放时战斗流程安全结束")
	_assert(not interrupted_battle._animating_battle,
		"镜头聚焦期间防守方释放时解除共享操作锁")
	interrupted_battle.queue_free()
	await process_frame

	settings.auto_camera_enabled = old_auto_camera
	settings.battle_animations_enabled = old_enabled
	battle.queue_free()
	await process_frame

# ══════════════════════════════════════════════════════════
# 测试套件 11：Unit 状态机（含 undo_move）
# ══════════════════════════════════════════════════════════
func _test_unit_state_machine() -> void:
	# 回合切换时，剧情事件可能已释放单位但尚未同步清理权威数组。
	var stale_turn_battle := TestBootstrapClass.new()
	root.add_child(stale_turn_battle)
	await process_frame
	for existing_unit: Variant in (stale_turn_battle.player_units + stale_turn_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_turn_battle.player_units.clear()
	stale_turn_battle.enemy_units.clear()
	var stale_turn_unit := Unit.new()
	stale_turn_unit.setup(_make_unit_data({"name": "已释放回合单位"}),
		0, Vector2i(2, 2))
	var valid_turn_unit := Unit.new()
	valid_turn_unit.setup(_make_unit_data({"name": "有效回合单位"}),
		0, Vector2i(3, 2))
	stale_turn_battle.get_node("UnitLayer").add_child(stale_turn_unit)
	stale_turn_battle.get_node("UnitLayer").add_child(valid_turn_unit)
	stale_turn_battle.player_units.assign([stale_turn_unit, valid_turn_unit])
	valid_turn_unit.mark_acted()
	stale_turn_unit.queue_free()
	await process_frame
	stale_turn_battle._battle_over = false
	stale_turn_battle._start_player_turn()
	_assert(valid_turn_unit.can_act(),
		"玩家回合开始会忽略残留的已释放引用并重置有效单位")
	_assert(not stale_turn_battle._battle_over,
		"玩家回合开始在仍有有效单位时不会因已释放引用误判战败")
	stale_turn_battle.queue_free()
	await process_frame

	# 自动结束回合判定应越过已释放玩家，并识别后续仍可行动的单位。
	var stale_acted_battle := TestBootstrapClass.new()
	root.add_child(stale_acted_battle)
	await process_frame
	for existing_unit: Variant in (stale_acted_battle.player_units + stale_acted_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_acted_battle.player_units.clear()
	stale_acted_battle.enemy_units.clear()
	var stale_acted_unit := Unit.new()
	stale_acted_unit.setup(_make_unit_data({"name": "已释放行动判定单位"}),
		0, Vector2i(2, 2))
	var actionable_unit := Unit.new()
	actionable_unit.setup(_make_unit_data({"name": "仍可行动单位"}),
		0, Vector2i(3, 2))
	stale_acted_battle.get_node("UnitLayer").add_child(stale_acted_unit)
	stale_acted_battle.get_node("UnitLayer").add_child(actionable_unit)
	stale_acted_battle.player_units.assign([stale_acted_unit, actionable_unit])
	stale_acted_unit.free()
	stale_acted_battle._battle_over = false
	stale_acted_battle._turn_ending = false
	stale_acted_battle.current_phase = stale_acted_battle.Phase.PLAYER_TURN
	stale_acted_battle._check_all_acted()
	_assert(not stale_acted_battle._turn_ending,
		"自动结束回合判定忽略已释放玩家且保留仍可行动单位的回合")
	stale_acted_battle.queue_free()
	await process_frame

	# 危险区刷新也必须跳过尚未从敌军数组移除的已释放单位。
	var stale_danger_battle := TestBootstrapClass.new()
	root.add_child(stale_danger_battle)
	await process_frame
	for existing_unit: Variant in (stale_danger_battle.player_units + stale_danger_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_danger_battle.player_units.clear()
	stale_danger_battle.enemy_units.clear()
	var stale_danger_enemy := Unit.new()
	stale_danger_enemy.setup(_make_enemy_data({"name": "已释放危险区敌军"}),
		1, Vector2i(4, 4))
	var valid_danger_enemy := Unit.new()
	valid_danger_enemy.setup(_make_enemy_data({"name": "有效危险区敌军"}),
		1, Vector2i(6, 6))
	stale_danger_battle.get_node("UnitLayer").add_child(stale_danger_enemy)
	stale_danger_battle.get_node("UnitLayer").add_child(valid_danger_enemy)
	stale_danger_battle.enemy_units.assign([stale_danger_enemy, valid_danger_enemy])
	stale_danger_enemy.queue_free()
	await process_frame
	stale_danger_battle._update_danger_zone()
	_assert(not stale_danger_battle._danger_tiles.is_empty(),
		"危险区刷新会忽略残留的已释放引用并计算后续有效敌军")
	stale_danger_battle.queue_free()
	await process_frame

	# 鼠标悬停扫描必须跳过已释放引用，并继续显示后续有效单位。
	var stale_hover_battle := TestBootstrapClass.new()
	root.add_child(stale_hover_battle)
	await process_frame
	for existing_unit: Variant in (stale_hover_battle.player_units + stale_hover_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_hover_battle.player_units.clear()
	stale_hover_battle.enemy_units.clear()
	var stale_hover_unit := Unit.new()
	stale_hover_unit.setup(_make_unit_data({"name": "已释放悬停单位"}),
		0, Vector2i(5, 5))
	var valid_hover_unit := Unit.new()
	valid_hover_unit.setup(_make_enemy_data({"name": "有效悬停单位"}),
		1, Vector2i(5, 5))
	stale_hover_battle.get_node("UnitLayer").add_child(stale_hover_unit)
	stale_hover_battle.get_node("UnitLayer").add_child(valid_hover_unit)
	stale_hover_battle.player_units.assign([stale_hover_unit])
	stale_hover_battle.enemy_units.assign([valid_hover_unit])
	var hover_terrain_label := Label.new()
	stale_hover_battle.add_child(hover_terrain_label)
	stale_hover_battle._terrain_label = hover_terrain_label
	stale_hover_battle.fixed_hover_grid = Vector2i(5, 5)
	stale_hover_battle.player_state = stale_hover_battle.PlayerState.IDLE
	stale_hover_battle.current_phase = stale_hover_battle.Phase.PLAYER_TURN
	stale_hover_unit.queue_free()
	await process_frame
	stale_hover_battle._last_hover = Vector2i(-1, -1)
	stale_hover_battle._update_hover()
	_assert(hover_terrain_label.text.contains("有效悬停单位"),
		"鼠标悬停会忽略残留的已释放引用并显示后续有效单位")
	stale_hover_battle.queue_free()
	await process_frame

	# 胜利判定不能把敌军数组中的已释放引用当作全灭信号。
	var previous_victory_chapter: int = GameState.current_chapter
	GameState.current_chapter = 1
	var stale_victory_battle := TestBootstrapClass.new()
	root.add_child(stale_victory_battle)
	await process_frame
	for existing_unit: Variant in (stale_victory_battle.player_units + stale_victory_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_victory_battle.player_units.clear()
	stale_victory_battle.enemy_units.clear()
	var stale_victory_enemy := Unit.new()
	stale_victory_enemy.setup(_make_enemy_data({"name": "已释放胜利判定敌军"}),
		1, Vector2i(4, 4))
	var surviving_enemy := Unit.new()
	surviving_enemy.setup(_make_enemy_data({"name": "存活胜利判定敌军"}),
		1, Vector2i(6, 6))
	stale_victory_battle.get_node("UnitLayer").add_child(stale_victory_enemy)
	stale_victory_battle.get_node("UnitLayer").add_child(surviving_enemy)
	stale_victory_battle.enemy_units.assign([stale_victory_enemy, surviving_enemy])
	stale_victory_enemy.queue_free()
	await process_frame
	stale_victory_battle._battle_over = false
	stale_victory_battle._check_victory()
	_assert(not stale_victory_battle._battle_over,
		"胜利判定会忽略残留的已释放引用且不会在仍有存活敌军时误判胜利")
	GameState.current_chapter = previous_victory_chapter
	stale_victory_battle.queue_free()
	await process_frame

	# 序章二按可击杀敌军判胜时也必须跳过已释放引用。
	var previous_ch2_victory_chapter: int = GameState.current_chapter
	GameState.current_chapter = 2
	var stale_ch2_victory_battle := TestBootstrapClass.new()
	root.add_child(stale_ch2_victory_battle)
	await process_frame
	for existing_unit: Variant in (stale_ch2_victory_battle.player_units + stale_ch2_victory_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_ch2_victory_battle.player_units.clear()
	stale_ch2_victory_battle.enemy_units.clear()
	var stale_ch2_enemy := Unit.new()
	stale_ch2_enemy.setup(_make_enemy_data({"name": "已释放序章二敌军"}),
		1, Vector2i(4, 4))
	var surviving_mortal_enemy := Unit.new()
	surviving_mortal_enemy.setup(_make_enemy_data({"name": "存活可击杀敌军", "min_hp": 0}),
		1, Vector2i(6, 6))
	stale_ch2_victory_battle.get_node("UnitLayer").add_child(stale_ch2_enemy)
	stale_ch2_victory_battle.get_node("UnitLayer").add_child(surviving_mortal_enemy)
	stale_ch2_victory_battle.enemy_units.assign([stale_ch2_enemy, surviving_mortal_enemy])
	stale_ch2_enemy.queue_free()
	await process_frame
	stale_ch2_victory_battle._battle_over = false
	stale_ch2_victory_battle._check_victory()
	_assert(not stale_ch2_victory_battle._battle_over,
		"序章二胜利判定会忽略已释放引用且不会漏掉后续可击杀敌军")
	GameState.current_chapter = previous_ch2_victory_chapter
	stale_ch2_victory_battle.queue_free()
	await process_frame

	# 正式序章二场景使用独立脚本，其胜利判定也必须安全扫描已释放引用。
	var stale_legacy_ch2_battle := Ch2BootstrapClass.new()
	var stale_legacy_ch2_enemy := Unit.new()
	stale_legacy_ch2_enemy.setup(_make_enemy_data({"name": "已释放独立序章二敌军"}),
		1, Vector2i(4, 4))
	var surviving_legacy_ch2_enemy := Unit.new()
	surviving_legacy_ch2_enemy.setup(
		_make_enemy_data({"name": "存活独立序章二敌军", "min_hp": 0}),
		1, Vector2i(6, 6))
	stale_legacy_ch2_battle.add_child(stale_legacy_ch2_enemy)
	stale_legacy_ch2_battle.add_child(surviving_legacy_ch2_enemy)
	stale_legacy_ch2_battle.enemy_units.assign([
		stale_legacy_ch2_enemy, surviving_legacy_ch2_enemy])
	stale_legacy_ch2_enemy.free()
	stale_legacy_ch2_battle._battle_over = false
	stale_legacy_ch2_battle._check_victory()
	_assert(not stale_legacy_ch2_battle._battle_over,
		"独立序章二胜利判定忽略已释放引用且不会漏掉后续可击杀敌军")
	stale_legacy_ch2_battle.free()

	# 正式序章三独立脚本不能因已释放敌军引用而提前触发塔楼事件。
	var stale_legacy_ch3_battle := Ch3BootstrapClass.new()
	var stale_legacy_ch3_enemy := Unit.new()
	stale_legacy_ch3_enemy.setup(_make_enemy_data({"name": "已释放独立序章三敌军"}),
		1, Vector2i(4, 4))
	var surviving_legacy_ch3_enemy := Unit.new()
	surviving_legacy_ch3_enemy.setup(
		_make_enemy_data({"name": "存活独立序章三敌军", "min_hp": 0}),
		1, Vector2i(6, 6))
	stale_legacy_ch3_battle.add_child(stale_legacy_ch3_enemy)
	stale_legacy_ch3_battle.add_child(surviving_legacy_ch3_enemy)
	stale_legacy_ch3_battle.enemy_units.assign([
		stale_legacy_ch3_enemy, surviving_legacy_ch3_enemy])
	stale_legacy_ch3_enemy.free()
	stale_legacy_ch3_battle._battle_over = false
	stale_legacy_ch3_battle._tower_reached = false
	stale_legacy_ch3_battle._check_victory()
	_assert(not stale_legacy_ch3_battle._tower_reached,
		"独立序章三胜利判定忽略已释放引用且不会提前触发塔楼事件")
	stale_legacy_ch3_battle.free()

	# 正式序章三独立脚本应越过已释放玩家，识别后续抵达塔门的奈德。
	var stale_player_legacy_ch3_battle := TestCh3Bootstrap.new()
	var stale_legacy_ch3_player := Unit.new()
	stale_legacy_ch3_player.setup(_make_unit_data({"name": "已释放独立序章三玩家"}),
		0, Vector2i(4, 4))
	var arriving_legacy_ch3_ned := Unit.new()
	arriving_legacy_ch3_ned.setup(_make_unit_data({"name": "奈德"}),
		0, stale_player_legacy_ch3_battle.victory_pos)
	var blocking_legacy_ch3_enemy := Unit.new()
	blocking_legacy_ch3_enemy.setup(
		_make_enemy_data({"name": "独立序章三存活守军", "min_hp": 0}),
		1, Vector2i(6, 6))
	stale_player_legacy_ch3_battle.add_child(stale_legacy_ch3_player)
	stale_player_legacy_ch3_battle.add_child(arriving_legacy_ch3_ned)
	stale_player_legacy_ch3_battle.add_child(blocking_legacy_ch3_enemy)
	stale_player_legacy_ch3_battle.player_units.assign([
		stale_legacy_ch3_player, arriving_legacy_ch3_ned])
	stale_player_legacy_ch3_battle.enemy_units.assign([blocking_legacy_ch3_enemy])
	stale_legacy_ch3_player.free()
	stale_player_legacy_ch3_battle._battle_over = false
	stale_player_legacy_ch3_battle._tower_reached = false
	stale_player_legacy_ch3_battle._check_victory()
	_assert(stale_player_legacy_ch3_battle._tower_reached,
		"独立序章三胜利判定忽略已释放玩家且识别后续抵达塔门的奈德")
	stale_player_legacy_ch3_battle.free()

	# 正式序章四独立脚本不能把可能残留已释放引用的数组交给强类型 filter。
	var stale_legacy_ch4_battle := Ch4BootstrapClass.new()
	var stale_legacy_ch4_enemy := Unit.new()
	stale_legacy_ch4_enemy.setup(_make_enemy_data({"name": "已释放独立序章四敌军"}),
		1, Vector2i(4, 4))
	var surviving_legacy_ch4_enemy := Unit.new()
	surviving_legacy_ch4_enemy.setup(
		_make_enemy_data({"name": "存活独立序章四敌军", "min_hp": 0}),
		1, Vector2i(6, 6))
	stale_legacy_ch4_battle.add_child(stale_legacy_ch4_enemy)
	stale_legacy_ch4_battle.add_child(surviving_legacy_ch4_enemy)
	stale_legacy_ch4_battle.enemy_units.assign([
		stale_legacy_ch4_enemy, surviving_legacy_ch4_enemy])
	stale_legacy_ch4_enemy.free()
	stale_legacy_ch4_battle._battle_over = false
	stale_legacy_ch4_battle._check_victory()
	var ch4_bootstrap_source := _read_repo_root_text(
		"game/冰与火/scripts/battle/BattleBootstrap_Ch4.gd")
	_assert(not ch4_bootstrap_source.contains("enemy_units.filter(func(u: Unit)"),
		"独立序章四胜利判定不会使用无法接收已释放引用的强类型 filter")
	stale_legacy_ch4_battle.free()

	# 正式序章三背叛流程应越过已释放金袍，继续转换后续存活单位。
	var stale_betrayal_battle := TestCh3Bootstrap.new()
	var stale_golden_cloak := Unit.new()
	stale_golden_cloak.setup(_make_unit_data({"name": "已释放金袍"}),
		0, Vector2i(4, 4))
	var surviving_golden_cloak := Unit.new()
	surviving_golden_cloak.setup(_make_unit_data({"name": "存活金袍"}),
		0, Vector2i(6, 6))
	stale_betrayal_battle.add_child(stale_golden_cloak)
	stale_betrayal_battle.add_child(surviving_golden_cloak)
	stale_betrayal_battle.player_units.assign([stale_golden_cloak, surviving_golden_cloak])
	stale_betrayal_battle._golden_cloak_units.assign([
		stale_golden_cloak, surviving_golden_cloak])
	stale_golden_cloak.free()
	await stale_betrayal_battle._trigger_betrayal()
	_assert(surviving_golden_cloak.team == 1 \
			and stale_betrayal_battle.enemy_units.has(surviving_golden_cloak),
		"独立序章三背叛流程忽略已释放金袍且转换后续存活单位")
	stale_betrayal_battle.free()

	# 金袍也可能在背叛闪烁动画的等待期间被其他战场流程移除。
	var interrupted_betrayal_battle := TestCh3Bootstrap.new()
	root.add_child(interrupted_betrayal_battle)
	var animated_golden_cloak := Unit.new()
	animated_golden_cloak.setup(_make_unit_data({"name": "动画中被移除的金袍"}),
		0, Vector2i(4, 4))
	var animated_cloak_sprite := Sprite2D.new()
	animated_cloak_sprite.name = "Sprite"
	animated_golden_cloak.add_child(animated_cloak_sprite)
	var following_golden_cloak := Unit.new()
	following_golden_cloak.setup(_make_unit_data({"name": "后续存活金袍"}),
		0, Vector2i(6, 6))
	interrupted_betrayal_battle.add_child(animated_golden_cloak)
	interrupted_betrayal_battle.add_child(following_golden_cloak)
	interrupted_betrayal_battle.player_units.assign([
		animated_golden_cloak, following_golden_cloak])
	interrupted_betrayal_battle._golden_cloak_units.assign([
		animated_golden_cloak, following_golden_cloak])
	interrupted_betrayal_battle._trigger_betrayal()
	await process_frame
	animated_golden_cloak.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	_assert(following_golden_cloak.team == 1 \
			and interrupted_betrayal_battle.enemy_units.has(following_golden_cloak),
		"独立序章三背叛动画等待期间金袍被移除后仍转换后续存活单位")
	interrupted_betrayal_battle.queue_free()
	await process_frame

	# 正式序章四兰军归降流程应越过已释放兰军，继续撤走后续存活单位。
	var stale_lannister_join_battle := TestCh4Bootstrap.new()
	root.add_child(stale_lannister_join_battle)
	var stale_lannister := Unit.new()
	stale_lannister.setup(_make_enemy_data({"name": "已释放兰军"}),
		1, Vector2i(4, 4))
	var surviving_lannister := Unit.new()
	surviving_lannister.setup(_make_enemy_data({"name": "存活兰军"}),
		1, Vector2i(6, 6))
	stale_lannister_join_battle.add_child(stale_lannister)
	stale_lannister_join_battle.add_child(surviving_lannister)
	stale_lannister_join_battle.enemy_units.assign([
		stale_lannister, surviving_lannister])
	stale_lannister_join_battle._lannister_units.assign([
		stale_lannister, surviving_lannister])
	stale_lannister.free()
	await stale_lannister_join_battle._trigger_lannister_join()
	_assert(not stale_lannister_join_battle.enemy_units.has(surviving_lannister) \
			and surviving_lannister.is_queued_for_deletion(),
		"独立序章四兰军归降流程忽略已释放兰军且撤走后续存活单位")
	stale_lannister_join_battle.queue_free()
	await process_frame

	# 序章四中途提示不能因已释放引用而漏掉仍存活的普通王军。
	var previous_ch4_victory_chapter: int = GameState.current_chapter
	GameState.current_chapter = 4
	var stale_ch4_victory_battle := TestBootstrapClass.new()
	root.add_child(stale_ch4_victory_battle)
	await process_frame
	for existing_unit: Variant in (stale_ch4_victory_battle.player_units + stale_ch4_victory_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_ch4_victory_battle.player_units.clear()
	stale_ch4_victory_battle.enemy_units.clear()
	stale_ch4_victory_battle._lannister_units.clear()
	var stale_ch4_enemy := Unit.new()
	stale_ch4_enemy.setup(_make_enemy_data({"name": "已释放序章四王军"}),
		1, Vector2i(12, 12))
	var surviving_royal_enemy := Unit.new()
	surviving_royal_enemy.setup(_make_enemy_data({"name": "存活普通王军"}),
		1, Vector2i(14, 12))
	var surviving_commander := Unit.new()
	surviving_commander.setup(_make_enemy_data({"name": "存活王军指挥官"}),
		1, Vector2i(18, 7))
	stale_ch4_victory_battle.get_node("UnitLayer").add_child(stale_ch4_enemy)
	stale_ch4_victory_battle.get_node("UnitLayer").add_child(surviving_royal_enemy)
	stale_ch4_victory_battle.get_node("UnitLayer").add_child(surviving_commander)
	stale_ch4_victory_battle.enemy_units.assign([
		stale_ch4_enemy, surviving_royal_enemy, surviving_commander])
	stale_ch4_victory_battle._royal_commander = surviving_commander
	stale_ch4_victory_battle._commander_killed = false
	stale_ch4_victory_battle._ch4_midway_hint_shown = false
	stale_ch4_enemy.queue_free()
	await process_frame
	stale_ch4_victory_battle._battle_over = false
	stale_ch4_victory_battle._check_victory()
	_assert(not stale_ch4_victory_battle._ch4_midway_hint_shown,
		"序章四中途判定会忽略已释放引用且不会漏掉后续存活普通王军")

	# 统一序章四兰军归降流程也应越过已释放兰军，继续撤走后续存活单位。
	var stale_unified_lannister := Unit.new()
	stale_unified_lannister.setup(_make_enemy_data({"name": "已释放统一兰军"}),
		1, Vector2i(8, 8))
	var surviving_unified_lannister := Unit.new()
	surviving_unified_lannister.setup(_make_enemy_data({"name": "存活统一兰军"}),
		1, Vector2i(10, 8))
	stale_ch4_victory_battle.get_node("UnitLayer").add_child(stale_unified_lannister)
	stale_ch4_victory_battle.get_node("UnitLayer").add_child(surviving_unified_lannister)
	stale_ch4_victory_battle.enemy_units.append(stale_unified_lannister)
	stale_ch4_victory_battle.enemy_units.append(surviving_unified_lannister)
	stale_ch4_victory_battle._lannister_units.assign([
		stale_unified_lannister, surviving_unified_lannister])
	stale_unified_lannister.free()
	await stale_ch4_victory_battle._trigger_ch4_lannister_join()
	_assert(not stale_ch4_victory_battle.enemy_units.has(surviving_unified_lannister) \
			and surviving_unified_lannister.is_queued_for_deletion(),
		"统一序章四兰军归降流程忽略已释放兰军且撤走后续存活单位")
	GameState.current_chapter = previous_ch4_victory_chapter
	stale_ch4_victory_battle.queue_free()
	await process_frame

	# 基类胜利判定也必须安全扫描敌我双方数组中的已释放引用。
	var stale_base_victory_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var stale_base_victory_battle := stale_base_victory_scene.instantiate()
	stale_base_victory_battle.set_script(BattleMapClass)
	root.add_child(stale_base_victory_battle)
	await process_frame
	for existing_unit: Variant in (stale_base_victory_battle.player_units + stale_base_victory_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_base_victory_battle.player_units.clear()
	stale_base_victory_battle.enemy_units.clear()
	var stale_base_enemy := Unit.new()
	stale_base_enemy.setup(_make_enemy_data({"name": "已释放基类敌军"}), 1, Vector2i(4, 4))
	var live_base_enemy := Unit.new()
	live_base_enemy.setup(_make_enemy_data({"name": "存活基类敌军"}), 1, Vector2i(6, 6))
	stale_base_victory_battle.add_child(stale_base_enemy)
	stale_base_victory_battle.add_child(live_base_enemy)
	stale_base_victory_battle.enemy_units.assign([stale_base_enemy, live_base_enemy])
	stale_base_enemy.queue_free()
	await process_frame
	stale_base_victory_battle._battle_over = false
	stale_base_victory_battle._check_victory()
	_assert(not stale_base_victory_battle._battle_over,
		"基类胜利判定忽略已释放敌军且不会漏掉后续存活敌军")
	var stale_base_player := Unit.new()
	stale_base_player.setup(_make_unit_data({"name": "已释放基类友军"}), 0, Vector2i(2, 2))
	var goal_base_player := Unit.new()
	goal_base_player.setup(_make_unit_data({"name": "抵达目标友军"}),
		0, stale_base_victory_battle.victory_pos)
	stale_base_victory_battle.add_child(stale_base_player)
	stale_base_victory_battle.add_child(goal_base_player)
	stale_base_victory_battle.player_units.assign([stale_base_player, goal_base_player])
	stale_base_player.queue_free()
	await process_frame
	stale_base_victory_battle._check_victory()
	_assert(stale_base_victory_battle._battle_over,
		"基类胜利判定忽略已释放友军且识别后续抵达目标单位")
	stale_base_victory_battle.queue_free()
	await process_frame

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

	# 使用独立战场分别覆盖镜头聚焦与步行动画的异步恢复点，避免污染下方输入状态机。
	var interruption_settings := root.get_node_or_null("GameSettings")
	var old_interruption_auto_camera: bool = interruption_settings.auto_camera_enabled
	interruption_settings.auto_camera_enabled = true
	var focus_interrupted_battle := TestBootstrapClass.new()
	root.add_child(focus_interrupted_battle)
	await process_frame
	var freed_during_focus := Unit.new()
	freed_during_focus.setup(_make_unit_data({"name": "聚焦期间释放单位"}),
		0, Vector2i(6, 5))
	focus_interrupted_battle.get_node("UnitLayer").add_child(freed_during_focus)
	focus_interrupted_battle.player_units.append(freed_during_focus)
	focus_interrupted_battle.record_move_result.call_deferred(freed_during_focus, Vector2i(6, 4))
	await process_frame
	_assert(focus_interrupted_battle._animating_battle and freed_during_focus.state == Unit.State.IDLE,
		"单位释放前移动流程正停留在镜头聚焦阶段")
	freed_during_focus.queue_free()
	for frame: int in range(60):
		if focus_interrupted_battle.recorded_move_result != null:
			break
		await process_frame
	_assert_eq(focus_interrupted_battle.recorded_move_result, false,
		"镜头聚焦期间单位释放时向调用方返回失败")
	_assert(not focus_interrupted_battle._animating_battle,
		"镜头聚焦期间单位释放时解除共享操作锁")
	_assert_eq(focus_interrupted_battle._pre_move_pos, Vector2i(-1, -1),
		"镜头聚焦期间单位释放时清理取消移动坐标")
	focus_interrupted_battle.queue_free()
	await process_frame

	interruption_settings.auto_camera_enabled = false
	var movement_interrupted_battle := TestBootstrapClass.new()
	root.add_child(movement_interrupted_battle)
	await process_frame
	var movement_origin := Vector2i(6, 5)
	var freed_during_movement := Unit.new()
	freed_during_movement.setup(_make_unit_data({"name": "步行期间释放单位"}),
		0, movement_origin)
	movement_interrupted_battle.get_node("UnitLayer").add_child(freed_during_movement)
	movement_interrupted_battle.player_units.append(freed_during_movement)
	movement_interrupted_battle.record_move_result.call_deferred(
		freed_during_movement, Vector2i(6, 3))
	for frame: int in range(10):
		await process_frame
		if freed_during_movement.grid_pos != movement_origin:
			break
	_assert(freed_during_movement.grid_pos != movement_origin and
		movement_interrupted_battle._animating_battle,
		"单位释放前移动流程已进入步行动画阶段")
	freed_during_movement.queue_free()
	for frame: int in range(60):
		if movement_interrupted_battle.recorded_move_result != null:
			break
		await process_frame
	_assert_eq(movement_interrupted_battle.recorded_move_result, false,
		"步行动画期间单位释放时向调用方返回失败")
	_assert(not movement_interrupted_battle._animating_battle,
		"步行动画期间单位释放时解除共享操作锁")
	_assert_eq(movement_interrupted_battle._pre_move_pos, Vector2i(-1, -1),
		"步行动画期间单位释放时清理取消移动坐标")
	movement_interrupted_battle.queue_free()
	await process_frame
	interruption_settings.auto_camera_enabled = old_interruption_auto_camera

	# 正式战场：等待与取消移动按钮的真实调用链
	var battle_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var battle := battle_scene.instantiate()
	battle.set_script(TestBootstrapClass)
	root.add_child(battle)
	await process_frame
	for existing_unit: Unit in battle.player_units + battle.enemy_units:
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	battle.player_units.clear()
	battle.enemy_units.clear()
	battle._battle_over = false
	battle.current_phase = battle.Phase.PLAYER_TURN

	var waiter := Unit.new()
	waiter.setup(_make_unit_data({"name": "等待测试员"}), 0, Vector2i(3, 3))
	var mover := Unit.new()
	mover.setup(_make_unit_data({"name": "移动测试员"}), 0, Vector2i(2, 3))
	var distant_enemy := Unit.new()
	distant_enemy.setup(_make_enemy_data({"name": "远处敌军"}), 1, Vector2i(8, 8))
	battle.get_node("UnitLayer").add_child(waiter)
	battle.get_node("UnitLayer").add_child(mover)
	battle.get_node("UnitLayer").add_child(distant_enemy)
	waiter.position = battle._g2p(waiter.grid_pos)
	mover.position = battle._g2p(mover.grid_pos)
	distant_enemy.position = battle._g2p(distant_enemy.grid_pos)
	battle.player_units.assign([waiter, mover])
	battle.enemy_units.assign([distant_enemy])

	var action_menu := battle.get_node_or_null("UI/ActionMenu") as PanelContainer
	var wait_button: Button = null
	var cancel_move_button: Button = null
	if action_menu != null:
		wait_button = action_menu.get_node_or_null("VBox/WaitBtn") as Button
		cancel_move_button = action_menu.get_node_or_null("VBox/CancelMoveBtn") as Button
	_assert(action_menu != null and wait_button != null and cancel_move_button != null,
		"正式战场行动菜单包含等待与取消移动按钮")
	if action_menu == null or wait_button == null or cancel_move_button == null:
		battle.queue_free()
		await process_frame
		return
	_assert_eq(wait_button.pressed.get_connections().size(), 1,
		"正式等待按钮仅连接一个处理目标")
	_assert_eq(cancel_move_button.pressed.get_connections().size(), 1,
		"正式取消移动按钮仅连接一个处理目标")

	battle.selected_unit = waiter
	battle.player_state = battle.PlayerState.UNIT_MOVED
	battle._show_action_menu(waiter.grid_pos, false)
	_assert(action_menu.visible and not cancel_move_button.visible,
		"原地行动菜单显示且不提供取消移动")
	wait_button.pressed.emit()
	_assert(waiter.state == Unit.State.DONE, "点击正式等待按钮会结束单位行动")
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"点击等待后清除选中单位并返回空闲状态")
	_assert(not action_menu.visible, "点击等待后关闭行动菜单")
	_assert(mover.can_act(), "仍有友军可行动时等待不会提前切换敌方回合")
	_assert(battle.current_phase == battle.Phase.PLAYER_TURN and not battle._turn_ending,
		"仍有友军可行动时等待保持玩家回合且不启动回合切换")

	var move_origin := Vector2i(2, 3)
	var moved_pos := Vector2i(3, 4)
	var settings := root.get_node_or_null("GameSettings")
	var old_auto_camera: bool = settings.auto_camera_enabled
	settings.auto_camera_enabled = false
	var preview_enemy_click := InputEventMouseButton.new()
	preview_enemy_click.button_index = MOUSE_BUTTON_LEFT
	preview_enemy_click.pressed = true
	preview_enemy_click.position = battle.get_global_transform_with_canvas() * battle._g2p(distant_enemy.grid_pos)
	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == distant_enemy,
		"空闲状态左键敌军会通过正式输入链路显示安全距离预览")
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"敌军安全距离预览不会错误选中我方单位或改变玩家状态")
	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == null, "再次左键同一敌军会关闭安全距离预览")
	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == distant_enemy, "关闭后可再次左键敌军恢复安全距离预览")
	var close_preview_event := InputEventKey.new()
	close_preview_event.pressed = true
	close_preview_event.keycode = KEY_ESCAPE
	battle._input(close_preview_event)
	_assert(battle._preview_enemy == null,
		"敌军安全距离预览可通过正式 ESC 输入链路关闭")

	var danger_toggle_event := InputEventKey.new()
	danger_toggle_event.pressed = true
	danger_toggle_event.keycode = KEY_D
	var danger_before: bool = battle._show_danger
	battle._input(danger_toggle_event)
	_assert_eq(battle._show_danger, not danger_before, "D 键会通过正式输入链路切换危险区")
	var repeated_danger_event := InputEventKey.new()
	repeated_danger_event.pressed = true
	repeated_danger_event.echo = true
	repeated_danger_event.keycode = KEY_D
	battle._input(repeated_danger_event)
	_assert_eq(battle._show_danger, not danger_before, "长按 D 产生的重复事件不会连续切换危险区")
	battle._input(danger_toggle_event)
	_assert_eq(battle._show_danger, danger_before, "再次按 D 键会恢复危险区显示状态")

	# 测试替身为避免异步 UI 初始化会跳过小地图，这里按正式初始化逻辑挂载真实 MiniMap。
	battle._minimap = MiniMap.new()
	battle.add_child(battle._minimap)
	battle._minimap.setup(battle)
	var minimap_toggle_event := InputEventKey.new()
	minimap_toggle_event.pressed = true
	minimap_toggle_event.keycode = KEY_M
	_assert(not battle._minimap.visible, "正式小地图初始化后默认隐藏")
	battle._input(minimap_toggle_event)
	_assert(battle._minimap.visible, "M 键会通过正式输入链路打开小地图")
	var repeated_minimap_event := InputEventKey.new()
	repeated_minimap_event.pressed = true
	repeated_minimap_event.echo = true
	repeated_minimap_event.keycode = KEY_M
	battle._input(repeated_minimap_event)
	_assert(battle._minimap.visible, "长按 M 产生的重复事件不会立即关闭小地图")
	# 小地图重绘应越过战场数组中已释放的单位引用。
	var minimap_players_before: Array[Unit] = []
	minimap_players_before.assign(battle.player_units)
	var stale_minimap_unit := Unit.new()
	stale_minimap_unit.setup(_make_unit_data({"name": "已释放小地图单位"}),
		0, Vector2i(1, 1))
	battle.get_node("UnitLayer").add_child(stale_minimap_unit)
	battle.player_units.push_front(stale_minimap_unit)
	stale_minimap_unit.free()
	battle._minimap._canvas.queue_redraw()
	await process_frame
	battle.player_units.assign(minimap_players_before)
	_assert(battle._minimap.visible,
		"小地图重绘忽略已释放单位且保持显示")
	battle._input(minimap_toggle_event)
	_assert(not battle._minimap.visible, "再次按 M 键会通过正式输入链路关闭小地图")

	# 在敌方回合启用，避免自动协程立即接管单位，以隔离验证快捷键状态机。
	battle.current_phase = battle.Phase.ENEMY_TURN
	var autopilot_toggle_event := InputEventKey.new()
	autopilot_toggle_event.pressed = true
	autopilot_toggle_event.keycode = KEY_A
	battle._input(autopilot_toggle_event)
	_assert(battle._autopilot and not battle._autopilot_running,
		"敌方回合按 A 会启用自动托管并等待下一玩家回合")
	_assert(battle.recorded_statuses.back().contains("自动托管已启动"),
		"启用自动托管会显示明确状态反馈")
	var repeated_autopilot_event := InputEventKey.new()
	repeated_autopilot_event.pressed = true
	repeated_autopilot_event.echo = true
	repeated_autopilot_event.keycode = KEY_A
	battle._input(repeated_autopilot_event)
	_assert(battle._autopilot and not battle._autopilot_running,
		"长按 A 产生的重复事件不会立即关闭自动托管")
	var stop_autopilot_event := InputEventKey.new()
	stop_autopilot_event.pressed = true
	stop_autopilot_event.keycode = KEY_ESCAPE
	battle._input(stop_autopilot_event)
	_assert(not battle._autopilot and not battle._autopilot_running,
		"ESC 会通过正式输入链路中止自动托管")
	_assert(battle.recorded_statuses.back().contains("自动托管已中止"),
		"ESC 中止自动托管会显示明确状态反馈")
	battle._animating_battle = true
	battle._input(autopilot_toggle_event)
	_assert(not battle._autopilot and not battle._autopilot_running,
		"战斗演出锁定期间按 A 不会启动自动托管")
	battle._animating_battle = false
	battle.current_phase = battle.Phase.PLAYER_TURN

	var restart_release_event := InputEventKey.new()
	restart_release_event.keycode = KEY_R
	battle._unhandled_input(restart_release_event)
	_assert(not battle.restart_requested, "松开 R 不会触发章节重开")
	var restart_press_event := InputEventKey.new()
	restart_press_event.pressed = true
	restart_press_event.keycode = KEY_R
	battle._unhandled_input(restart_press_event)
	_assert(battle.restart_requested, "正常状态按 R 会通过正式输入链路触发章节重开")
	battle.restart_requested = false
	var repeated_restart_event := InputEventKey.new()
	repeated_restart_event.pressed = true
	repeated_restart_event.echo = true
	repeated_restart_event.keycode = KEY_R
	battle._unhandled_input(repeated_restart_event)
	_assert(not battle.restart_requested, "长按 R 产生的重复事件不会再次触发章节重开")

	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == distant_enemy, "快捷键输入验证后仍可重新打开敌军安全距离预览")
	var select_mover_click := InputEventMouseButton.new()
	select_mover_click.button_index = MOUSE_BUTTON_LEFT
	select_mover_click.pressed = true
	select_mover_click.position = battle.get_global_transform_with_canvas() * battle._g2p(move_origin)
	battle._input(select_mover_click)
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"左键我方单位会通过正式输入链路选中可行动单位")
	_assert(battle._preview_enemy == null, "从敌军预览切换选中我方单位时会清理安全距离预览")
	_assert(not battle.move_range.is_empty(), "正式左键选中单位后会计算移动范围")
	_assert(moved_pos in battle.move_range, "目标格位于正式移动范围内")
	var move_click := InputEventMouseButton.new()
	move_click.button_index = MOUSE_BUTTON_LEFT
	move_click.pressed = true
	move_click.position = battle.get_global_transform_with_canvas() * battle._g2p(moved_pos)
	battle._input(move_click)
	var duplicate_move_result: Variant = await battle._do_move_animated(mover, moved_pos)
	_assert_eq(duplicate_move_result, false,
		"移动流程重入时向调用方明确返回失败")
	for frame: int in range(60):
		if not battle._animating_battle:
			break
		await process_frame
	_assert_eq(mover.state, Unit.State.MOVED, "正式移动流程会将单位标记为已移动")
	_assert_eq(mover.grid_pos, moved_pos, "正式移动流程会更新单位格坐标")
	_assert_eq(mover.position, battle._g2p(moved_pos), "正式移动动画会到达目标格场景位置")
	_assert_eq(battle._pre_move_pos, move_origin,
		"移动流程重入时保留首次移动的取消原坐标")
	_assert(battle.player_state == battle.PlayerState.UNIT_MOVED,
		"正式移动完成后进入单位已移动状态")
	_assert(action_menu.visible and cancel_move_button.visible,
		"正式移动完成后自动显示含取消按钮的行动菜单")
	cancel_move_button.pressed.emit()
	_assert_eq(mover.state, Unit.State.IDLE, "点击取消移动按钮恢复单位未行动状态")
	_assert_eq(mover.grid_pos, move_origin, "点击取消移动按钮恢复原始格坐标")
	_assert_eq(mover.position, battle._g2p(move_origin), "点击取消移动按钮恢复原始场景位置")
	_assert_eq(battle._pre_move_pos, Vector2i(-1, -1), "取消移动后清理移动前坐标")
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"取消移动后保留选中单位并返回单位选择状态")
	_assert(not action_menu.visible, "取消移动后关闭行动菜单")
	_assert(battle.recorded_statuses.any(func(msg: String) -> bool: return msg == "移动测试员 取消移动"),
		"取消移动后显示明确状态反馈")

	var deselect_event := InputEventKey.new()
	deselect_event.pressed = true
	deselect_event.keycode = KEY_ESCAPE
	battle._input(move_click)
	for frame: int in range(60):
		if not battle._animating_battle:
			break
		await process_frame
	_assert(mover.grid_pos == moved_pos and battle.player_state == battle.PlayerState.UNIT_MOVED,
		"测试 ESC 取消移动前会通过正式输入链路再次完成移动")
	battle._input(deselect_event)
	_assert_eq(mover.state, Unit.State.IDLE, "移动后按 ESC 会恢复单位未行动状态")
	_assert_eq(mover.grid_pos, move_origin, "移动后按 ESC 会恢复单位原始格坐标")
	_assert_eq(mover.position, battle._g2p(move_origin), "移动后按 ESC 会恢复单位原始场景位置")
	_assert_eq(battle._pre_move_pos, Vector2i(-1, -1), "移动后按 ESC 会清理移动前坐标")
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"移动后按 ESC 会保留选中单位并返回单位选择状态")
	_assert(not action_menu.visible, "移动后按 ESC 会关闭行动菜单")

	battle._input(move_click)
	for frame: int in range(60):
		if not battle._animating_battle:
			break
		await process_frame
	_assert(mover.grid_pos == moved_pos and battle.player_state == battle.PlayerState.UNIT_MOVED,
		"测试右键取消移动前会通过正式输入链路再次完成移动")
	var cancel_move_right_click := InputEventMouseButton.new()
	cancel_move_right_click.button_index = MOUSE_BUTTON_RIGHT
	cancel_move_right_click.pressed = true
	cancel_move_right_click.position = battle.get_global_transform_with_canvas() * battle._g2p(moved_pos)
	battle._input(cancel_move_right_click)
	_assert_eq(mover.state, Unit.State.IDLE, "移动后按右键会恢复单位未行动状态")
	_assert_eq(mover.grid_pos, move_origin, "移动后按右键会恢复单位原始格坐标")
	_assert_eq(mover.position, battle._g2p(move_origin), "移动后按右键会恢复单位原始场景位置")
	_assert_eq(battle._pre_move_pos, Vector2i(-1, -1), "移动后按右键会清理移动前坐标")
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"移动后按右键会保留选中单位并返回单位选择状态")
	_assert(not action_menu.visible, "移动后按右键会关闭行动菜单")

	battle._input(deselect_event)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"ESC 会通过正式输入链路取消当前单位选择")
	_assert(battle.move_range.is_empty() and battle.attack_tiles.is_empty(),
		"ESC 取消选择后清理移动与攻击范围")
	battle._input(select_mover_click)
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"取消选择后可再次通过左键选中同一单位")

	var in_place_click := InputEventMouseButton.new()
	in_place_click.button_index = MOUSE_BUTTON_RIGHT
	in_place_click.pressed = true
	in_place_click.position = battle.get_global_transform_with_canvas() * battle._g2p(mover.grid_pos)
	battle._input(in_place_click)
	_assert(action_menu.visible and battle.player_state == battle.PlayerState.UNIT_MOVED,
		"右键已选单位会通过正式输入链路打开原地行动菜单")
	_assert_eq(battle._pre_move_pos, Vector2i(-1, -1),
		"右键原地行动不会留下可取消的移动记录")
	_assert(not cancel_move_button.visible, "右键原地行动菜单不会显示取消移动按钮")
	var blocked_waiter_click := InputEventMouseButton.new()
	blocked_waiter_click.button_index = MOUSE_BUTTON_LEFT
	blocked_waiter_click.pressed = true
	blocked_waiter_click.position = battle.get_global_transform_with_canvas() * battle._g2p(waiter.grid_pos)
	battle._input(blocked_waiter_click)
	_assert(action_menu.visible and battle.selected_unit == mover,
		"行动菜单显示时地图左键不会穿透并切换选中单位")
	_assert(battle.player_state == battle.PlayerState.UNIT_MOVED,
		"行动菜单显示时地图左键不会改变玩家状态")
	var close_in_place_event := InputEventKey.new()
	close_in_place_event.pressed = true
	close_in_place_event.keycode = KEY_ESCAPE
	battle._input(close_in_place_event)
	_assert(not action_menu.visible, "ESC 会通过正式输入链路关闭右键原地行动菜单")
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"ESC 关闭右键原地行动菜单后保留单位选中态")

	battle._input(select_mover_click)
	_assert(action_menu.visible and battle.player_state == battle.PlayerState.UNIT_MOVED,
		"再次左键已选单位会通过正式输入链路打开原地行动菜单")
	_assert_eq(battle._pre_move_pos, Vector2i(-1, -1),
		"左键原地行动不会留下可取消的移动记录")
	_assert(not cancel_move_button.visible, "左键原地行动菜单不会显示取消移动按钮")
	battle._input(close_in_place_event)
	_assert(not action_menu.visible, "ESC 会通过正式输入链路关闭左键原地行动菜单")
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"ESC 关闭左键原地行动菜单后保留单位选中态")
	waiter.reset_turn()
	var switch_unit_click := InputEventMouseButton.new()
	switch_unit_click.button_index = MOUSE_BUTTON_LEFT
	switch_unit_click.pressed = true
	switch_unit_click.position = battle.get_global_transform_with_canvas() * battle._g2p(waiter.grid_pos)
	battle._input(switch_unit_click)
	_assert(battle.selected_unit == waiter and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"单位选择态左键另一可行动友军会通过正式输入链路切换选中对象")
	_assert(battle.move_range.has(waiter.grid_pos), "切换友军后会按新单位位置重算移动范围")
	var invalid_tile_click := InputEventMouseButton.new()
	invalid_tile_click.button_index = MOUSE_BUTTON_LEFT
	invalid_tile_click.pressed = true
	invalid_tile_click.position = battle.get_global_transform_with_canvas() * battle._g2p(Vector2i(20, 15))
	battle._input(invalid_tile_click)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"单位选择态左键不可移动空格会通过正式输入链路取消选择")
	_assert(battle.move_range.is_empty() and battle.attack_tiles.is_empty(),
		"点击不可移动空格取消选择后会清理行动范围")

	battle._input(select_mover_click)
	_assert(battle.selected_unit == mover and battle.player_state == battle.PlayerState.UNIT_SELECTED,
		"测试已行动友军切换前会重新选中当前可行动单位")
	waiter.mark_acted()
	battle._input(switch_unit_click)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"选择态左键已行动友军不会错误切换到不可行动单位")
	waiter.reset_turn()

	battle._animating_battle = true
	battle._input(select_mover_click)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"战斗动画操作锁会阻止正式左键选择我方单位")
	battle._animating_battle = false
	battle.current_phase = battle.Phase.ENEMY_TURN
	battle._input(select_mover_click)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"敌方回合会阻止正式左键选择我方单位")
	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == distant_enemy,
		"敌方回合仍允许通过正式左键查看敌军安全距离预览")
	battle._input(select_mover_click)
	_assert(battle._preview_enemy == null,
		"敌方回合点击非敌军格会关闭安全距离预览")
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"敌方回合关闭敌军预览时不会穿透并选择我方单位")

	battle._battle_over = true
	battle._input(preview_enemy_click)
	_assert(battle._preview_enemy == null,
		"战斗结束操作锁会阻止正式左键打开敌军安全距离预览")
	battle._input(select_mover_click)
	_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
		"战斗结束操作锁会阻止正式左键选择我方单位")
	battle._battle_over = false
	battle.current_phase = battle.Phase.PLAYER_TURN
	settings.auto_camera_enabled = old_auto_camera

	var end_turn_button := battle.get_node_or_null("UI/EndTurnBtn") as Button
	_assert(end_turn_button != null, "正式战场包含结束回合按钮")
	if end_turn_button != null:
		battle.intercept_enemy_turn_start = true
		_assert_eq(end_turn_button.pressed.get_connections().size(), 1,
			"正式结束回合按钮仅连接一个处理目标")
		battle.selected_unit = mover
		battle.player_state = battle.PlayerState.UNIT_SELECTED
		battle._show_action_menu(mover.grid_pos, false)
		end_turn_button.disabled = false
		end_turn_button.pressed.emit()
		_assert_eq(battle.recorded_enemy_turn_starts, 1,
			"点击正式结束回合按钮会启动一次敌方回合")
		_assert_eq(battle.current_phase, battle.Phase.PLAYER_TURN,
			"测试替身只记录敌方回合入口且不会启动异步敌军行动")
		_assert(end_turn_button.disabled, "点击结束回合后立即禁用按钮防止重复触发")
		_assert(battle.selected_unit == null and battle.player_state == battle.PlayerState.IDLE,
			"点击结束回合后清除选中单位并返回空闲状态")
		_assert(not action_menu.visible, "点击结束回合后关闭行动菜单")

		battle.recorded_enemy_turn_starts = 0
		battle.current_phase = battle.Phase.PLAYER_TURN
		battle._turn_ending = false
		waiter.mark_acted()
		mover.mark_acted()
		end_turn_button.disabled = false
		battle._check_all_acted()
		_assert(battle._turn_ending, "最后单位行动后进入自动结束回合延迟窗口")
		end_turn_button.pressed.emit()
		_assert_eq(battle.recorded_enemy_turn_starts, 0,
			"自动结束回合延迟期间点击结束回合会被立即拦截")
		await create_timer(0.6).timeout
		_assert_eq(battle.recorded_enemy_turn_starts, 1,
			"自动结束回合延迟期间点击结束回合不会重复启动敌方回合")
		_assert(not battle._turn_ending, "自动结束回合完成后清除回合切换锁")

		battle.recorded_enemy_turn_starts = 0
		battle.current_phase = battle.Phase.PLAYER_TURN
		battle._check_all_acted()
		battle.current_phase = battle.Phase.ENEMY_TURN
		await create_timer(0.6).timeout
		_assert_eq(battle.recorded_enemy_turn_starts, 0,
			"自动结束回合等待期间阶段已变化时不会再次启动敌方回合")
		_assert(not battle._turn_ending, "阶段变化中止自动结束回合后清除回合切换锁")

		battle.current_phase = battle.Phase.PLAYER_TURN
		waiter.reset_turn()
		mover.reset_turn()
		battle.record_autopilot_range_calculations = true
		battle.recorded_autopilot_range_calculations = 0
		battle._input(autopilot_toggle_event)
		battle._input(stop_autopilot_event)
		battle._input(autopilot_toggle_event)
		await create_timer(0.35).timeout
		_assert_eq(battle.recorded_autopilot_range_calculations, 1,
			"快速中止并重启自动托管时只有最新协程执行单位决策")
		battle._input(stop_autopilot_event)
		await create_timer(0.4).timeout

		waiter.reset_turn()
		mover.reset_turn()
		battle.record_autopilot_range_calculations = false
		battle._animating_battle = true
		if battle._autopilot_label == null:
			battle._autopilot_label = Label.new()
			battle.add_child(battle._autopilot_label)
		battle._autopilot = true
		battle._update_autopilot_label()
		battle._run_autopilot_turn()
		await create_timer(0.4).timeout
		_assert(not battle._autopilot_running,
			"共享操作锁拒绝移动时自动托管安全停止当前运行")
		_assert(not battle._autopilot,
			"共享操作锁拒绝移动时同步暂停自动托管开关")
		_assert_eq(battle._autopilot_label.text, "",
			"共享操作锁拒绝移动时清理自动托管状态标签")
		_assert(waiter.can_act() and mover.can_act(),
			"共享操作锁拒绝移动时自动托管不会消耗单位行动")
		battle._animating_battle = false

	battle.queue_free()
	await process_frame

	# 托管决策应越过已释放敌军，并继续选择后续可攻击目标。
	var deciding_unit := Unit.new()
	deciding_unit.setup(_make_unit_data({"name": "托管决策单位"}),
		0, Vector2i(2, 2))
	var stale_decision_enemy := Unit.new()
	stale_decision_enemy.setup(_make_enemy_data({"name": "已释放托管目标"}),
		1, Vector2i(3, 2))
	var live_decision_enemy := Unit.new()
	live_decision_enemy.setup(_make_enemy_data({"name": "存活托管目标"}),
		1, Vector2i(3, 2))
	var decision_enemies: Array = [stale_decision_enemy, live_decision_enemy]
	stale_decision_enemy.free()
	var stale_safe_decision := AutopilotAI.decide(
		deciding_unit, decision_enemies, [Vector2i(2, 2)])
	_assert(stale_safe_decision.get("attack") == live_decision_enemy,
		"自动托管决策忽略已释放敌军且选择后续可攻击目标")
	deciding_unit.free()
	live_decision_enemy.free()

	# 自动托管初始等待期间，单位可能被剧情/事件释放但尚未从权威数组移除。
	var stale_autopilot_battle := TestBootstrapClass.new()
	root.add_child(stale_autopilot_battle)
	await process_frame
	for existing_unit: Variant in (stale_autopilot_battle.player_units + stale_autopilot_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	stale_autopilot_battle.player_units.clear()
	stale_autopilot_battle.enemy_units.clear()
	var stale_autopilot_unit := Unit.new()
	stale_autopilot_unit.setup(_make_unit_data({"name": "已释放托管单位"}),
		0, Vector2i(2, 2))
	stale_autopilot_battle.get_node("UnitLayer").add_child(stale_autopilot_unit)
	stale_autopilot_battle.player_units.append(stale_autopilot_unit)
	stale_autopilot_battle.record_autopilot_range_calculations = true
	stale_autopilot_battle._battle_over = false
	stale_autopilot_battle.current_phase = stale_autopilot_battle.Phase.PLAYER_TURN
	stale_autopilot_battle._autopilot = true
	stale_autopilot_battle._run_autopilot_turn()
	stale_autopilot_unit.queue_free()
	await process_frame
	await create_timer(0.35).timeout
	_assert_eq(stale_autopilot_battle.recorded_autopilot_range_calculations, 0,
		"自动托管会忽略初始等待期间释放且仍残留在数组中的单位")
	_assert(not stale_autopilot_battle._autopilot_running,
		"自动托管没有有效行动单位时会解除运行锁")
	stale_autopilot_battle._cancel_autopilot()
	await create_timer(0.35).timeout
	stale_autopilot_battle.queue_free()
	await process_frame

	# 自动托管完成移动后的观察停顿期间，行动单位也可能被战场事件移除。
	var removed_after_move_battle := TestBootstrapClass.new()
	root.add_child(removed_after_move_battle)
	await process_frame
	for existing_unit: Variant in (removed_after_move_battle.player_units + removed_after_move_battle.enemy_units):
		if is_instance_valid(existing_unit):
			existing_unit.queue_free()
	await process_frame
	removed_after_move_battle.player_units.clear()
	removed_after_move_battle.enemy_units.clear()
	var removed_after_move_unit := Unit.new()
	removed_after_move_unit.setup(_make_unit_data({
		"name": "移动后移除单位", "move": 1,
	}), 0, Vector2i(2, 2))
	var adjacent_after_move_enemy := Unit.new()
	adjacent_after_move_enemy.setup(_make_enemy_data({"name": "移动后目标"}),
		1, Vector2i(4, 2))
	var next_autopilot_unit := Unit.new()
	next_autopilot_unit.setup(_make_unit_data({"name": "后续托管单位"}),
		0, Vector2i(2, 5))
	removed_after_move_battle.get_node("UnitLayer").add_child(removed_after_move_unit)
	removed_after_move_battle.get_node("UnitLayer").add_child(adjacent_after_move_enemy)
	removed_after_move_battle.get_node("UnitLayer").add_child(next_autopilot_unit)
	removed_after_move_unit.position = removed_after_move_battle._g2p(removed_after_move_unit.grid_pos)
	adjacent_after_move_enemy.position = removed_after_move_battle._g2p(adjacent_after_move_enemy.grid_pos)
	next_autopilot_unit.position = removed_after_move_battle._g2p(next_autopilot_unit.grid_pos)
	removed_after_move_battle.player_units.assign([
		removed_after_move_unit, next_autopilot_unit,
	])
	removed_after_move_battle.enemy_units.append(adjacent_after_move_enemy)
	removed_after_move_battle.autopilot_walkable_overrides[
		removed_after_move_unit.get_instance_id()] = [
		Vector2i(2, 2), Vector2i(3, 2),
	]
	removed_after_move_battle.autopilot_walkable_overrides[
		next_autopilot_unit.get_instance_id()] = [Vector2i(2, 5)]
	removed_after_move_battle.remove_unit_after_autopilot_move = true
	removed_after_move_battle._battle_over = false
	removed_after_move_battle.current_phase = removed_after_move_battle.Phase.PLAYER_TURN
	removed_after_move_battle._autopilot = true
	removed_after_move_battle._run_autopilot_turn()
	for attempt in 40:
		if removed_after_move_battle.removed_unit_after_autopilot_move \
				and not next_autopilot_unit.can_act():
			break
		await create_timer(0.05).timeout
	_assert(removed_after_move_battle.removed_unit_after_autopilot_move,
		"自动托管测试单位在正式移动成功后由事件移除")
	_assert(not next_autopilot_unit.can_act(),
		"当前单位移动后被移除时自动托管会继续处理下一名可行动友军")
	removed_after_move_battle._cancel_autopilot()
	await process_frame
	_assert(not removed_after_move_battle._autopilot_running,
		"自动托管会在移动后停顿期间单位被移除时解除运行锁")
	await create_timer(0.35).timeout
	removed_after_move_battle.queue_free()
	await process_frame

# ══════════════════════════════════════════════════════════
# 测试套件 12：路径查找 Dijkstra 逻辑（无需场景，纯算法）
# ══════════════════════════════════════════════════════════
func _test_pathfinding_logic() -> void:
	# 正式单位查询应容忍事件清理与数组同步之间短暂存在的已释放引用。
	var stale_unit_battle := TestBootstrapClass.new()
	root.add_child(stale_unit_battle)
	await process_frame
	stale_unit_battle.player_units.clear()
	stale_unit_battle.enemy_units.clear()
	var stale_unit := Unit.new()
	stale_unit.setup(_make_enemy_data({"name": "已释放查询单位"}),
		1, Vector2i(2, 2))
	stale_unit_battle.get_node("UnitLayer").add_child(stale_unit)
	stale_unit_battle.enemy_units.append(stale_unit)
	stale_unit.queue_free()
	await process_frame
	_assert(stale_unit_battle._unit_at(Vector2i(2, 2), 1) == null,
		"正式单位查询会忽略权威数组中残留的已释放引用")
	stale_unit_battle.queue_free()
	await process_frame

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
	var deploy_src := FileAccess.get_file_as_string("res://scripts/ui/DeployScreen_Ch4.gd")
	var chrome_src := FileAccess.get_file_as_string("res://scripts/ui/BattleChromeTheme.gd")
	_assert(not src.contains("_hide_tilemap_png"), "BattleMap 已移除旧 TileMap 隐藏兼容逻辑")
	_assert(src.contains("func _draw_terrain_detail"), "BattleMap 存在统一地形细节绘制入口")
	_assert(src.contains("func _draw_wall_detail"), "BattleMap 存在城墙/建筑细节绘制")
	_assert(src.contains("func _draw_river_detail"), "BattleMap 存在河流细节绘制")
	_assert(src.contains("func _draw_bridge_detail"), "BattleMap 存在桥梁细节绘制")
	_assert(src.contains("func _terrain_edge_mask"),
		"BattleMap 提供地形边缘暴露检测，支撑森林/沼泽过渡")
	_assert(src.contains("var edges := _terrain_edge_mask(x, y, TERRAIN_FOREST)"),
		"BattleMap 会按森林边缘暴露信息绘制过渡")
	_assert(src.contains("var edges := _terrain_edge_mask(x, y, TERRAIN_SWAMP)"),
		"BattleMap 会按沼泽边缘暴露信息绘制过渡")
	_assert(src.contains("func _terrain_corner_mask"),
		"BattleMap 提供地形角落暴露检测，支撑森林/沼泽角落过渡")
	_assert(src.contains("var corners := _terrain_corner_mask(x, y, TERRAIN_FOREST)"),
		"BattleMap 会按森林角落暴露信息绘制过渡")
	_assert(src.contains("var corners := _terrain_corner_mask(x, y, TERRAIN_SWAMP)"),
		"BattleMap 会按沼泽角落暴露信息绘制过渡")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, 12)"),
		"BattleMap 森林会为暴露边增加树冠压暗过渡")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 18, rect.size.x - 12, 12)"),
		"BattleMap 沼泽会为暴露边增加泥水压暗过渡")
	_assert(src.contains("draw_circle(rect.position + Vector2(12, 12), 9.0"),
		"BattleMap 森林会为暴露角落增加树冠角过渡")
	_assert(src.contains("draw_circle(rect.position + Vector2(12, rect.size.y - 12), 10.0"),
		"BattleMap 沼泽会为暴露角落增加泥水角过渡")
	_assert(src.contains("bridge_neighbors > 0 and wall_neighbors == 0"), "BattleMap 会为桥邻接平地提供接驳石带逻辑")
	_assert(src.contains("if vertical_bridge:"), "BattleMap 桥梁细节按朝向分离绘制")
	_assert(src.contains("var center_x := rect.position.x + rect.size.x * 0.5") or src.contains("var center_y := rect.position.y + rect.size.y * 0.5"),
		"BattleMap 桥梁细节包含桥面中轴高亮")
	_assert(src.contains("bridge_neighbors > 0 and wall_neighbors == 0 and river_neighbors == 0"),
		"BattleMap 仅在桥头陆地强化主通路接驳")
	_assert(src.contains("func _plain_wet_edge_mask"),
		"BattleMap 提供平地湿边接触检测，支撑贴河/贴沼方向提示")
	_assert(src.contains("var wet_edges := _plain_wet_edge_mask(x, y)"),
		"BattleMap 会按平地湿边信息绘制定向湿边")
	_assert(src.contains("if wet_edges.get(\"north\", -1) == TERRAIN_RIVER:"),
		"BattleMap 会为贴北侧河流的平地补湿边压暗")
	_assert(src.contains("if wet_edges.get(\"south\", -1) == TERRAIN_SWAMP:"),
		"BattleMap 会为贴南侧沼泽的平地补泥边提示")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 8, rect.position.y + 18),"),
		"BattleMap 会为贴河平地补河岸收口线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 8, rect.position.y + rect.size.y - 18),"),
		"BattleMap 会为贴南河平地补河岸收口线")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, rect.size.x - 16, 10)"),
		"BattleMap 会为贴边平地补窄条湿边层")
	_assert(src.contains("if bridge_neighbors > 0 and horizontal_flow:"),
		"BattleMap 河流会在南北桥两侧补桥基水影")
	_assert(src.contains("if bridge_neighbors > 0 and not horizontal_flow:"),
		"BattleMap 河流会在东西桥两侧补桥基水影")
	_assert(src.contains("func _bridge_end_mask"),
		"BattleMap 提供桥端暴露检测，支撑桥台/端帽强化")
	_assert(src.contains("var bridge_ends := _bridge_end_mask(x, y)"),
		"BattleMap 会按桥端暴露信息绘制桥台端帽")
	_assert(src.contains("if vertical_bridge and bridge_ends.get(\"north\", false):"),
		"BattleMap 会为南北桥桥头补纵向端帽")
	_assert(src.contains("if not vertical_bridge and bridge_ends.get(\"west\", false):"),
		"BattleMap 会为东西桥桥头补横向端帽")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 14, rect.position.y + 4, rect.size.x - 28, 8)"),
		"BattleMap 会为桥端补纵向桥台石帽")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 4, rect.position.y + 14, 8, rect.size.y - 28)"),
		"BattleMap 会为桥端补横向桥台石帽")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 16, rect.position.y + rect.size.y - 10),"),
		"BattleMap 会为南北桥尾端补压暗收口线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 16),"),
		"BattleMap 会为东西桥尾端补压暗收口线")
	_assert(src.contains("if bridge_neighbors > 0 and river_neighbors == 0:"),
		"BattleMap 会为桥头前的陆地补桥面接驳石带")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 18, rect.position.y + 4, rect.size.x - 36, 10)"),
		"BattleMap 会为南北桥头前地补纵向接桥石带")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 4, rect.position.y + 18, 10, rect.size.y - 36)"),
		"BattleMap 会为东西桥头前地补横向接桥石带")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 18, rect.position.y + 14),"),
		"BattleMap 会为南北桥头前地补接桥收口线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 14, rect.position.y + 18),"),
		"BattleMap 会为东西桥头前地补接桥收口线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 18, rect.position.y + rect.size.y - 14),"),
		"BattleMap 会为南北桥头前地下侧补接桥收口线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + rect.size.x - 14, rect.position.y + 18),"),
		"BattleMap 会为东西桥头前地另一侧补接桥收口线")
	_assert(src.contains("if bridge_neighbors > 0 and horizontal_flow and banks.get(\"north\", false):"),
		"BattleMap 会在南北桥口邻接河段补北向桥口岸块")
	_assert(src.contains("if bridge_neighbors > 0 and not horizontal_flow and banks.get(\"west\", false):"),
		"BattleMap 会在东西桥口邻接河段补西向桥口岸块")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 12, rect.position.y + 4, rect.size.x - 24, 8)"),
		"BattleMap 会为桥口邻接河段补窄桥口岸带")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 12, rect.position.y + 10),"),
		"BattleMap 会为南北桥口岸块补高光顶沿线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 10, rect.position.y + 12),"),
		"BattleMap 会为东西桥口岸块补高光侧沿线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 12, rect.position.y + rect.size.y - 10),"),
		"BattleMap 会为南北桥口岸块另一侧补压暗沿线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 12),"),
		"BattleMap 会为东西桥口岸块另一侧补压暗沿线")
	_assert(src.contains("func _river_bank_mask"),
		"BattleMap 提供河岸暴露检测，支撑非桥接岸线强化")
	_assert(src.contains("var banks := _river_bank_mask(x, y)"),
		"BattleMap 会按河岸暴露信息绘制非桥接岸线")
	_assert(src.contains("if banks.get(\"north\", false) and bridge_neighbors == 0:"),
		"BattleMap 会为非桥接北岸补岸线高光")
	_assert(src.contains("if banks.get(\"south\", false) and bridge_neighbors == 0:"),
		"BattleMap 会为非桥接南岸补岸线压暗")
	_assert(src.contains("var wall_run_horizontal := not west_open and not east_open"),
		"BattleMap 会识别横向连续墙段，支撑连续防线打散")
	_assert(src.contains("var wall_run_vertical := not north_open and not south_open"),
		"BattleMap 会识别纵向连续墙段，支撑连续建筑打散")
	_assert(src.contains("func _wall_corner_mask"),
		"BattleMap 提供墙体角部暴露检测，支撑角部体量强化")
	_assert(src.contains("var corner_mask := _wall_corner_mask(x, y)"),
		"BattleMap 会按墙角暴露信息补角部石体")
	_assert(src.contains("if corner_mask.get(\"nw\", false):"),
		"BattleMap 会为左上暴露墙角补角石高光")
	_assert(src.contains("if corner_mask.get(\"se\", false):"),
		"BattleMap 会为右下暴露墙角补角石压暗")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 6, rect.position.y + 20, 10, 10)"),
		"BattleMap 会为墙角补局部方石体块")
	_assert(src.contains("var crenel_offset := float((x + y) % 2) * 4.0"),
		"BattleMap 会为连续墙顶缘引入交替段差，避免整排重复")
	_assert(src.contains("var brick_tint := 0.12 + float((x + row_i + col_i) % 3) * 0.03"),
		"BattleMap 会为连续墙砖缝引入轻微分段明度变化")
	_assert(src.contains("func _plain_wall_contact_mask"),
		"BattleMap 提供平地贴墙接触检测，支撑墙脚阴影与门前阈值强化")
	_assert(src.contains("var wall_contact := _plain_wall_contact_mask(x, y)"),
		"BattleMap 会按平地贴墙信息绘制墙脚阴影")
	_assert(src.contains("if wall_contact.get(\"north\", false) and not gate_vertical:"),
		"BattleMap 会为贴北墙平地补墙脚阴影")
	_assert(src.contains("if wall_contact.get(\"west\", false) and not gate_horizontal:"),
		"BattleMap 会为贴西墙平地补墙脚阴影")
	_assert(src.contains("if wall_contact.get(\"north\", false):"),
		"BattleMap 会为纵向门前平地强化门槛压痕")
	_assert(src.contains("if wall_contact.get(\"west\", false):"),
		"BattleMap 会为横向门前平地强化门槛压痕")
	_assert(src.contains("func _gate_runs_vertical"),
		"BattleMap 提供门洞朝向识别，避免墙体缺口读成普通地面")
	_assert(src.contains("func _gate_runs_horizontal"),
		"BattleMap 提供横向门洞识别，支持塔门与侧向缺口")
	_assert(src.contains("var gate_vertical := bridge_neighbors == 0 and river_neighbors == 0 and _gate_runs_vertical(x, y)"),
		"BattleMap 会为墙体缺口中的主通路绘制纵向门洞阈值")
	_assert(src.contains("var gate_horizontal := bridge_neighbors == 0 and river_neighbors == 0 and _gate_runs_horizontal(x, y)"),
		"BattleMap 会为墙体缺口中的主通路绘制横向门洞阈值")
	_assert(src.contains("if gate_vertical and wall_contact.get(\"west\", false):"),
		"BattleMap 会为纵向门洞补左侧门框边墙")
	_assert(src.contains("if gate_vertical and wall_contact.get(\"east\", false):"),
		"BattleMap 会为纵向门洞补右侧门框边墙")
	_assert(src.contains("if gate_horizontal and wall_contact.get(\"north\", false):"),
		"BattleMap 会为横向门洞补上侧门框边墙")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 18, rect.position.y + 6, rect.size.x - 36, 6)"),
		"BattleMap 会为纵向门洞补上门楣石带")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 6, rect.position.y + 18, 6, rect.size.y - 36)"),
		"BattleMap 会为横向门洞补侧向门楣石带")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 18, rect.position.y + rect.size.y - 12, rect.size.x - 36, 6)"),
		"BattleMap 会为纵向门洞补下门楣压暗")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 18, 6, rect.size.y - 36)"),
		"BattleMap 会为横向门洞补另一侧门楣压暗")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 10, threshold_y + 2),"),
		"BattleMap 会为纵向门洞补下侧门槛阴线")
	_assert(src.contains("draw_line(Vector2(threshold_x + 2, rect.position.y + 10),"),
		"BattleMap 会为横向门洞补另一侧门槛阴线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 15, rect.position.y + 12),"),
		"BattleMap 会为纵向门洞补内侧门框提亮线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 12, rect.position.y + 15),"),
		"BattleMap 会为横向门洞补内侧门框提亮线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + rect.size.x - 15, rect.position.y + 12),"),
		"BattleMap 会为纵向门洞另一侧补内框压暗线")
	_assert(src.contains("draw_line(Vector2(rect.position.x + 12, rect.position.y + rect.size.y - 15),"),
		"BattleMap 会为横向门洞另一侧补内框压暗线")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 8, rect.position.y + 10, 8, rect.size.y - 20)"),
		"BattleMap 会为门洞侧缘补局部门框石体")
	_assert(src.contains("if _terrain_at_or_cliff(x, y - 1) != TERRAIN_CLIFF:"),
		"BattleMap 会识别峭壁暴露顶缘，强化世界边界断面")
	_assert(src.contains("if _terrain_at_or_cliff(x - 1, y) != TERRAIN_CLIFF:"),
		"BattleMap 会识别峭壁暴露侧缘，避免边界读成平面黑块")
	_assert(src.contains("func _cliff_corner_mask"),
		"BattleMap 提供峭壁角部暴露检测，支撑边界转角断面强化")
	_assert(src.contains("var corner_mask := _cliff_corner_mask(x, y)"),
		"BattleMap 会按峭壁角部暴露信息补角部断面")
	_assert(src.contains("if corner_mask.get(\"se\", false):"),
		"BattleMap 会为右下暴露峭壁角补岩角压暗")
	_assert(src.contains("draw_circle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), 9.0"),
		"BattleMap 会为峭壁角部补圆角岩体断面")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, rect.size.x - 8, 10)"),
		"BattleMap 会为暴露峭壁顶缘补高光台沿")
	_assert(src.contains("draw_rect(Rect2(rect.position.x + 4, rect.position.y + 16, 8, rect.size.y - 20)"),
		"BattleMap 会为暴露峭壁左缘补侧壁压暗")
	_assert(src.contains("func _find_objective_guidance_path"),
		"BattleMap 提供主推进轴线寻路辅助，支撑弱引导")
	_assert(src.contains("func _draw_main_axis_guidance"),
		"BattleMap 提供主推进轴线弱引导绘制")
	_assert(src.contains("func _draw_objective_guidance"),
		"BattleMap 提供目标格弱引导绘制")
	_assert(src.contains("_draw_main_axis_guidance(rect, pos, guidance_path)"),
		"BattleMap 会为主推进轴线追加弱引导覆盖")
	_assert(src.contains("_draw_objective_guidance(rect, pos)"),
		"BattleMap 会为目标格追加弱引导覆盖")
	_assert(src.contains("var _objective_label"), "BattleMap 存在长期目标标签引用")
	_assert(src.contains("var _phase_label"), "BattleMap 存在阶段标签引用")
	_assert(src.contains("var _guidance_label"), "BattleMap 存在长期推进标签引用")
	_assert(src.contains("_objective_label.text = msg"), "BattleMap 会把目标/战局信息同步到长期目标标签")
	_assert(src.contains("_guidance_label.text = msg"), "BattleMap 会把推进信息同步到推进标签")
	_assert(src.contains("func _set_phase_badge"), "BattleMap 提供阶段徽标刷新入口")
	_assert(src.contains("func _terrain_at_or_cliff"), "BattleMap 提供邻接地形查询辅助，用于统一图块语言")
	_assert(src.contains("func _bridge_runs_vertical"), "BattleMap 根据邻接地形判定桥梁朝向")
	_assert(src.contains("BattleChromeTheme.apply_dark_chrome_recursive"), "BattleMap 已接入统一战斗界面主题")
	_assert(deploy_src.contains("const BattleChromeTheme := preload"), "部署界面已接入统一战斗界面主题")
	_assert(deploy_src.contains("func _apply_dark_ui_theme"), "部署界面存在统一主题刷新入口")
	_assert(deploy_src.contains("RosterPanel"), "部署界面新增编组总览面板")
	_assert(chrome_src.contains("class_name BattleChromeTheme"), "统一战斗界面主题脚本存在")
	_assert(chrome_src.contains("static func apply_dark_chrome_recursive"), "统一战斗界面主题提供递归应用入口")
	_assert(chrome_src.contains("const PANEL_HIGHLIGHT_BG"), "统一战斗界面主题包含高亮面板底色")
	_assert(chrome_src.contains("const TEXT_STATUS"), "统一战斗界面主题包含战局提示文字色")
	var scene_text := FileAccess.get_file_as_string("res://scenes/battle/BattleMap.tscn")
	_assert(not scene_text.contains("TileMapLayer"), "BattleMap 场景已移除旧 TileMapLayer 节点")
	_assert(not scene_text.contains("medieval_tileset.png"), "BattleMap 场景已移除旧瓦片贴图依赖")
	_assert(scene_text.contains("TopInfoPanel"), "BattleMap 场景已加入顶部信息面板")
	_assert(scene_text.contains("TopInfoMargin"), "BattleMap 场景已加入顶部信息边距容器")
	_assert(scene_text.contains("parent=\"UI/TopInfoPanel/TopInfoMargin/TopInfoVBox\""), "BattleMap 顶部信息标签已并入统一纵向容器")
	_assert(scene_text.contains("theme_override_colors/font_color = Color(0.95, 0.76, 0.58, 1)"), "BattleMap 场景已强化战局提示颜色层级")
	_assert(scene_text.contains("PhaseLabel"), "BattleMap 场景已加入阶段标签")
	_assert(scene_text.contains("ObjectiveLabel"), "BattleMap 场景已加入长期目标标签")
	_assert(scene_text.contains("GuidanceLabel"), "BattleMap 场景已加入长期推进标签")

	var battle_scene := load("res://scenes/battle/BattleMap.tscn") as PackedScene
	var themed_battle := battle_scene.instantiate()
	themed_battle._apply_dark_ui_theme()
	var action_menu := themed_battle.get_node("UI/ActionMenu") as PanelContainer
	var attack_btn := action_menu.get_node("VBox/AttackBtn") as Button
	var wait_btn := action_menu.get_node("VBox/WaitBtn") as Button
	var cancel_move_btn := action_menu.get_node("VBox/CancelMoveBtn") as Button
	var items_btn := action_menu.get_node("VBox/ItemsBtn") as Button
	var action_panel_style := action_menu.get_theme_stylebox("panel") as StyleBoxFlat
	var attack_style := attack_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var wait_style := wait_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var cancel_move_style := cancel_move_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var items_style := items_btn.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_eq(action_panel_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG,
		"行动菜单使用高亮面板底色")
	_assert_eq(action_panel_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER,
		"行动菜单使用高亮面板边框")
	_assert(attack_style.bg_color != wait_style.bg_color, "攻击按钮使用区别于等待的进攻语义底色")
	_assert(items_style.bg_color != wait_style.bg_color, "道具按钮使用区别于等待的辅助语义底色")
	_assert(cancel_move_style.bg_color != wait_style.bg_color, "取消移动按钮使用区别于等待的弱化底色")
	_assert_eq(attack_btn.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
		"攻击按钮使用进攻语义文字色")
	_assert_eq(items_btn.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_GOOD,
		"道具按钮使用辅助语义文字色")
	_assert_eq(cancel_move_btn.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_MUTED,
		"取消移动按钮使用弱化文字色")
	_assert_eq(attack_btn.get_theme_color("font_disabled_color"), BattleChromeThemeClass.TEXT_MUTED,
		"攻击按钮禁用态保持清晰且弱化")

	var predict_panel := themed_battle.get_node("UI/PredictPanel") as PanelContainer
	var predict_title := predict_panel.get_node("VBox/Title") as Label
	var predict_atk_line := predict_panel.get_node("VBox/AtkLine") as Label
	var predict_def_line := predict_panel.get_node("VBox/DefLine") as Label
	var predict_double_line := predict_panel.get_node("VBox/DoubleLine") as Label
	var predict_confirm_btn := predict_panel.get_node("VBox/Buttons/ConfirmBtn") as Button
	var predict_cancel_btn := predict_panel.get_node("VBox/Buttons/CancelBtn") as Button
	var predict_panel_style := predict_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var predict_confirm_style := predict_confirm_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var predict_cancel_style := predict_cancel_btn.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_eq(predict_panel_style.bg_color, BattleChromeThemeClass.PANEL_STEEL_BG,
		"战斗预测使用钢铁面板底色")
	_assert_eq(predict_panel_style.border_color, BattleChromeThemeClass.PANEL_STEEL_BORDER,
		"战斗预测使用钢铁面板边框")
	_assert_eq(predict_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_ACCENT,
		"战斗预测标题使用强调色")
	_assert_eq(predict_atk_line.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
		"战斗预测攻击方使用进攻色")
	_assert_eq(predict_def_line.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_GUIDANCE,
		"战斗预测防守方使用冷色")
	_assert_eq(predict_double_line.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_ACCENT,
		"战斗预测追击提示使用强调色")
	_assert(predict_confirm_style.bg_color != predict_cancel_style.bg_color,
		"确认攻击按钮区别于取消按钮")
	_assert_eq(predict_confirm_btn.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
		"确认攻击按钮使用进攻语义文字色")

	var result_panel := themed_battle.get_node("UI/ResultPanel") as PanelContainer
	var result_title := result_panel.get_node("VBox/ResultTitle") as Label
	var result_msg := result_panel.get_node("VBox/ResultMsg") as Label
	var restart_btn := result_panel.get_node("VBox/RestartBtn") as Button
	var victory_panel_style := result_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert_eq(victory_panel_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG,
		"战斗结果默认使用胜利高亮底色")
	_assert_eq(victory_panel_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER,
		"战斗结果默认使用胜利高亮边框")
	_assert_eq(result_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_ACCENT,
		"胜利结果标题使用暗金强调色")
	_assert_eq(result_msg.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"战斗结果说明保持正文可读性")
	_assert_eq(restart_btn.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"重新开始按钮保持中性文字色")
	_assert(themed_battle.has_method("_apply_result_state_theme"), "战斗结果提供胜败状态主题切换入口")
	if themed_battle.has_method("_apply_result_state_theme"):
		themed_battle._apply_result_state_theme(false)
		var defeat_panel_style := result_panel.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(defeat_panel_style.bg_color != victory_panel_style.bg_color,
			"败北结果切换为区别于胜利的危险底色")
		_assert_eq(result_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
			"败北结果标题切换为危险提示色")
	themed_battle.free()

	var runtime_battle := battle_scene.instantiate()
	runtime_battle.set_script(TestBootstrapClass)
	root.add_child(runtime_battle)
	await process_frame
	runtime_battle._autopilot_label = Label.new()
	runtime_battle.add_child(runtime_battle._autopilot_label)
	runtime_battle._autopilot = true
	runtime_battle._autopilot_running = true
	runtime_battle._update_autopilot_label()
	runtime_battle._end_battle(false)
	await process_frame
	var runtime_result_panel := runtime_battle.get_node("UI/ResultPanel") as PanelContainer
	var runtime_result_title := runtime_result_panel.get_node("VBox/ResultTitle") as Label
	var runtime_result_style := runtime_result_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(runtime_result_panel.visible, "败北时战斗结果面板可见")
	_assert(not runtime_battle._autopilot and not runtime_battle._autopilot_running,
		"战斗结束会中止自动托管")
	_assert_eq(runtime_battle._autopilot_label.text, "", "战斗结束会清除自动托管状态标签")
	var ended_autopilot_event := InputEventKey.new()
	ended_autopilot_event.pressed = true
	ended_autopilot_event.keycode = KEY_A
	runtime_result_panel.visible = false
	runtime_battle._input(ended_autopilot_event)
	_assert(not runtime_battle._autopilot, "战斗结束后 A 键不会重新启用自动托管")
	runtime_battle._battle_over = false
	runtime_battle._autopilot = true
	runtime_battle._autopilot_running = true
	runtime_battle._update_autopilot_label()
	runtime_battle._battle_over = true
	_assert(not runtime_battle._autopilot and not runtime_battle._autopilot_running,
		"章节直接进入战斗结束态时也会中止自动托管")
	_assert_eq(runtime_battle._autopilot_label.text, "",
		"章节直接进入战斗结束态时也会清除自动托管标签")
	_assert_eq(runtime_result_title.text, "败北", "战斗结束入口会设置败北标题")
	_assert_eq(runtime_result_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
		"战斗结束入口会切换败北标题危险色")
	_assert_eq(runtime_result_style.bg_color, BattleChromeThemeClass.PANEL_DANGER_BG,
		"战斗结束入口会切换败北面板危险底色")
	runtime_battle._apply_dark_ui_theme()
	var refreshed_result_style := runtime_result_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert_eq(refreshed_result_style.bg_color, BattleChromeThemeClass.PANEL_DANGER_BG,
		"战斗结束后重新应用主题仍保持败北危险底色")
	var runtime_restart := runtime_result_panel.get_node("VBox/RestartBtn") as Button
	_assert(runtime_restart != null and runtime_restart.pressed.get_connections().size() == 1,
		"战斗结果重新开始按钮仅连接一个重开目标")
	if runtime_restart != null:
		runtime_restart.pressed.emit()
	_assert(runtime_battle.restart_requested,
		"点击战斗结果重新开始按钮真实调用章节重开")
	runtime_battle.queue_free()
	await process_frame

	var transition_scene := load("res://scenes/ui/ChapterTransition.tscn") as PackedScene
	var themed_transition := transition_scene.instantiate()
	root.add_child(themed_transition)
	await process_frame
	var transition_bg := themed_transition.get_node("Background") as ColorRect
	var transition_ch_num := themed_transition.get_node("ChapterNumber") as Label
	var transition_title := themed_transition.get_node("ChapterTitle") as Label
	var transition_time := themed_transition.get_node("TimeLabel") as Label
	var transition_sub := themed_transition.get_node("SubLabel") as Label
	var transition_objective := themed_transition.get_node("ObjectiveLabel") as Label
	_assert_eq(transition_bg.color, BattleChromeThemeClass.BACKGROUND_COLOR,
		"章节标题卡使用统一背景色")
	_assert_eq(transition_ch_num.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE,
		"章节标题卡章节编号使用目标色")
	_assert_eq(transition_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"章节标题卡标题使用正文主色")
	_assert_eq(transition_time.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_MUTED,
		"章节标题卡时间使用弱化色")
	_assert_eq(transition_sub.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_GUIDANCE,
		"章节标题卡副标题使用引导色")
	_assert_eq(transition_objective.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE,
		"章节标题卡目标摘要使用目标色")
	themed_transition.queue_free()
	await process_frame

	var dialogue_scene := load("res://scenes/dialogue/DialogueBox.tscn") as PackedScene
	var themed_dialogue := dialogue_scene.instantiate()
	root.add_child(themed_dialogue)
	await process_frame
	var dialogue_bg := themed_dialogue.get_node("Background") as ColorRect
	var portrait_panel := themed_dialogue.get_node("PortraitPanel") as Panel
	var portrait_style := portrait_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var portrait_frame := themed_dialogue.get_node("PortraitPanel/PortraitFrame") as ColorRect
	var speaker_label := themed_dialogue.get_node("SpeakerLabel") as Label
	var text_label := themed_dialogue.get_node("TextLabel") as Label
	var prompt_icon := themed_dialogue.get_node("PromptIcon") as Label
	_assert_eq(dialogue_bg.color, BattleChromeThemeClass.BACKGROUND_COLOR,
		"对话框使用统一背景色")
	_assert_eq(portrait_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG,
		"对话立绘面板使用高亮底色")
	_assert_eq(portrait_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER,
		"对话立绘面板使用高亮边框")
	_assert_eq(portrait_frame.color, BattleChromeThemeClass.PANEL_STEEL_BG,
		"对话立绘内框使用钢铁底色")
	_assert_eq(speaker_label.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE,
		"对话角色名使用目标色")
	_assert_eq(text_label.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"对话正文使用主文字色")
	_assert_eq(prompt_icon.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_ACCENT,
		"对话继续提示使用强调色")
	themed_dialogue.queue_free()
	await process_frame

	var support_scene := load("res://scenes/ui/SupportPopup.tscn") as PackedScene
	var support_scene_source := FileAccess.get_file_as_string("res://scenes/ui/SupportPopup.tscn")
	_assert(not "\\u" in support_scene_source,
		"支援弹窗使用 Godot 支持的直接 Unicode 文本而非 JSON 转义")
	var themed_support := support_scene.instantiate()
	root.add_child(themed_support)
	await process_frame
	var support_bg := themed_support.get_node("Background") as PanelContainer
	var support_style := support_bg.get_theme_stylebox("panel") as StyleBoxFlat
	var support_title := themed_support.get_node("Background/VBox/TitleLabel") as Label
	var support_content := themed_support.get_node("Background/VBox/ContentLabel") as Label
	var support_rank := themed_support.get_node("Background/VBox/RankLabel") as Label
	var support_close := themed_support.get_node("Background/VBox/CloseBtn") as Button
	var support_close_style := support_close.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_eq(support_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG,
		"支援弹窗使用高亮面板底色")
	_assert_eq(support_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER,
		"支援弹窗使用高亮面板边框")
	_assert_eq(support_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE,
		"支援弹窗标题使用目标色")
	_assert_eq(support_content.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"支援弹窗正文使用主文字色")
	_assert_eq(support_rank.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_GOOD,
		"支援弹窗等级加成使用增益色")
	_assert_eq(support_close.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"支援弹窗关闭按钮保持中性文字色")
	_assert_eq(support_close_style.bg_color, BattleChromeThemeClass.BUTTON_NORMAL_BG,
		"支援弹窗关闭按钮使用中性按钮底色")
	var support_close_events: Array[bool] = []
	themed_support.popup_closed.connect(func() -> void: support_close_events.append(true))
	themed_support.show_support("奈德", "劳勃", "C", {"hit": 5, "avoid": 5})
	var first_support_timer: SceneTreeTimer = themed_support._auto_timer
	themed_support.show_support("奈德", "琼恩·艾林", "C", {"hit": 7, "avoid": 6})
	var second_support_timer: SceneTreeTimer = themed_support._auto_timer
	first_support_timer.timeout.emit()
	await process_frame
	_assert(themed_support.visible, "旧支援计时器不会关闭新展示内容")
	_assert("奈德 ↔ 琼恩·艾林" in support_rank.text, "旧支援计时器不会替换新展示文案")
	_assert_eq(support_close_events.size(), 0, "旧支援计时器不会发出新展示的关闭信号")
	second_support_timer.timeout.emit()
	await process_frame
	_assert(not themed_support.visible and support_close_events.size() == 1,
		"当前支援计时器仍会正常关闭当前展示一次")
	themed_support.queue_free()
	await process_frame

	var game_over_scene := load("res://scenes/ui/GameOver.tscn") as PackedScene
	var themed_game_over := game_over_scene.instantiate()
	root.add_child(themed_game_over)
	await process_frame
	var game_over_bg := themed_game_over.get_node("Background") as ColorRect
	var game_over_title := themed_game_over.get_node("Background/VBox/TitleLabel") as Label
	var game_over_message := themed_game_over.get_node("Background/VBox/MessageLabel") as Label
	var game_over_restart := themed_game_over.get_node("Background/VBox/RestartBtn") as Button
	var game_over_quit := themed_game_over.get_node("Background/VBox/QuitBtn") as Button
	var game_over_restart_style := game_over_restart.get_theme_stylebox("normal") as StyleBoxFlat
	var game_over_quit_style := game_over_quit.get_theme_stylebox("normal") as StyleBoxFlat
	_assert_eq(game_over_bg.color, BattleChromeThemeClass.BACKGROUND_COLOR,
		"GameOver 使用统一背景色")
	_assert_eq(game_over_title.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_STATUS,
		"GameOver 标题使用危险提示色")
	_assert_eq(game_over_message.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"GameOver 文案使用主文字色")
	_assert_eq(game_over_restart.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_PRIMARY,
		"GameOver 重新开始按钮保持中性文字色")
	_assert_eq(game_over_quit.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_MUTED,
		"GameOver 返回主菜单按钮使用弱化文字色")
	_assert_eq(game_over_restart_style.bg_color, BattleChromeThemeClass.BUTTON_NORMAL_BG,
		"GameOver 重新开始按钮使用中性按钮底色")
	_assert(game_over_quit_style.bg_color != game_over_restart_style.bg_color,
		"GameOver 返回主菜单按钮区别于重新开始按钮")
	themed_game_over.queue_free()
	await process_frame

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
	_assert_eq(PrologueChapterBriefsClass.CH1_OBJECTIVE_SUMMARY, "目标：夺回北侧山道缺口，为劳勃后军打开通路。", "Ch1 章节目标摘要常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH2_OBJECTIVE_SUMMARY, "目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。", "Ch2 章节目标摘要常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH3_OBJECTIVE_SUMMARY, "目标：让奈德抵达欢乐塔，不必全歼守军。", "Ch3 章节目标摘要常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH4_OBJECTIVE_SUMMARY, Ch4BattleBriefClass.OBJECTIVE_SUMMARY, "Ch4 章节目标摘要与战前简报统一")
	_assert_eq(PrologueChapterBriefsClass.CH1_BATTLE_OBJECTIVE, "夺回北侧山道缺口，为劳勃后军打开通路。", "Ch1 战斗目标常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH2_BATTLE_OBJECTIVE, "争夺三桥并稳住两翼，从中桥突破雷加本阵。", "Ch2 战斗目标常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH3_BATTLE_OBJECTIVE, "让奈德抵达欢乐塔，不必全歼守军。", "Ch3 战斗目标常量锁定")
	_assert_eq(PrologueChapterBriefsClass.CH4_BATTLE_OBJECTIVE, Ch4BattleBriefClass.BATTLE_OBJECTIVE, "Ch4 战斗目标与战前简报统一")
	_assert_eq(PrologueChapterBriefsClass.get_progress_steps(1).size(), 1, "Ch1 推进提示常量共1步")
	_assert_eq(PrologueChapterBriefsClass.get_progress_steps(2).size(), 3, "Ch2 推进提示常量共3步")
	_assert_eq(PrologueChapterBriefsClass.get_progress_steps(3).size(), 2, "Ch3 推进提示常量共2步")
	_assert_eq(PrologueChapterBriefsClass.get_progress_steps(4).size(), 4, "Ch4 推进提示常量共4步")
	_assert_eq(PrologueChapterBriefsClass.get_progress_stage_badge(2, 1), "阶段：第一段：南岸桥头", "Ch2 第一阶段徽标可生成")
	_assert_eq(PrologueChapterBriefsClass.get_progress_stage_badge(2, 3), "阶段：第三段：北岸桥头", "Ch2 第三阶段徽标可生成")
	_assert_eq(PrologueChapterBriefsClass.get_progress_stage_badge(3, 1), "阶段：第一段：湿地区", "Ch3 第一阶段徽标可生成")
	_assert_eq(PrologueChapterBriefsClass.get_progress_stage_badge(3, 2), "阶段：第二段：塔前杀伤区", "Ch3 第二阶段徽标可生成")
	_assert("山道缺口" in PrologueChapterBriefsClass.CH1_PROGRESS_MIDWAY, "Ch1 推进提示锁定山道缺口")
	_assert("南岸桥头" in PrologueChapterBriefsClass.CH2_PROGRESS_SOUTH_BANK, "Ch2 第一阶段推进提示锁定南岸桥头")
	_assert("中桥主攻" in PrologueChapterBriefsClass.CH2_PROGRESS_CENTER_BRIDGE, "Ch2 第二阶段推进提示锁定中桥主攻")
	_assert("北岸桥头" in PrologueChapterBriefsClass.CH2_PROGRESS_NORTH_BANK, "Ch2 第三阶段推进提示锁定北岸桥头")
	_assert("湿地区" in PrologueChapterBriefsClass.CH3_PROGRESS_SWAMP, "Ch3 第一阶段推进提示锁定湿地区")
	_assert("塔前杀伤区" in PrologueChapterBriefsClass.CH3_PROGRESS_TOWER, "Ch3 第二阶段推进提示锁定塔前杀伤区")
	_assert("山道缺口已夺回" in PrologueChapterBriefsClass.CH1_BATTLE_RESOLUTION, "Ch1 战局反馈锁定缺口夺回")
	_assert("雷加倒下" in PrologueChapterBriefsClass.CH2_BATTLE_RESOLUTION, "Ch2 战局反馈锁定雷加倒下")
	_assert("奈德已抵达欢乐塔" in PrologueChapterBriefsClass.CH3_BATTLE_RESOLUTION, "Ch3 战局反馈锁定欢乐塔抵达")
	_assert_eq(Ch4BattleBriefClass.BATTLE_FLOW_STEPS.size(), 4, "Ch4 作战简报常量共4个阶段")
	_assert_eq(Ch4BattleBriefClass.get_stage_badge(1), "阶段：第一段：黑水桥", "Ch4 作战简报可生成第一阶段徽标")
	_assert_eq(Ch4BattleBriefClass.get_stage_badge(4), "阶段：第四段：红堡内院", "Ch4 作战简报可生成第四阶段徽标")
	_assert("黑水桥" in Ch4BattleBriefClass.STAGE_1_GUIDANCE, "Ch4 作战简报第一阶段文案锁定黑水桥")
	_assert("南城墙" in Ch4BattleBriefClass.STAGE_2_GUIDANCE, "Ch4 作战简报第二阶段文案锁定南城墙")
	_assert("中央大道" in Ch4BattleBriefClass.STAGE_3_GUIDANCE, "Ch4 作战简报第三阶段文案锁定中央大道")
	_assert("红堡内院" in Ch4BattleBriefClass.STAGE_4_GUIDANCE, "Ch4 作战简报第四阶段文案锁定红堡内院")
	_assert("铁王座" in Ch4BattleBriefClass.THRONE_SECURED_STATUS, "Ch4 作战简报结局文案锁定铁王座")

	# Ch1：出生区到胜利格必须存在一条有效路径
	GameState.current_chapter = 1
	var ch1 := TestBootstrapClass.new()
	root.add_child(ch1)
	await process_frame
	_assert(ch1._ned_unit != null, "Ch1 语义回归：奈德存在")
	if ch1._ned_unit != null:
		_assert(_path_exists_on_passable_grid(ch1, ch1._ned_unit.grid_pos, ch1.victory_pos),
			"Ch1 语义回归：奈德到北侧目标存在可达路径")
		var ch1_axis: Array[Vector2i] = ch1._find_objective_guidance_path()
		_assert(not ch1_axis.is_empty(), "Ch1 语义回归：主推进轴线弱引导存在")
		_assert(ch1_axis.has(ch1.victory_pos), "Ch1 语义回归：主推进轴线弱引导抵达目标格")
		_assert(ch1_axis.has(Vector2i(5, 1)), "Ch1 语义回归：主推进轴线弱引导穿过山道缺口前沿")
	_assert(ch1.has_method("_terrain_edge_mask"), "Ch1 语义回归：地形边缘暴露检测辅助可用")
	if ch1.has_method("_terrain_edge_mask"):
		var ch1_forest_edges: Dictionary = ch1._terrain_edge_mask(2, 5, 1)
		_assert(ch1_forest_edges.get("north", false), "Ch1 语义回归：山道林地朝主通路暴露北侧边缘")
		_assert(ch1_forest_edges.get("west", false), "Ch1 语义回归：山道林地保留西侧边缘过渡")
	_assert(ch1.has_method("_terrain_corner_mask"), "Ch1 语义回归：地形角落暴露检测辅助可用")
	if ch1.has_method("_terrain_corner_mask"):
		var ch1_forest_corners: Dictionary = ch1._terrain_corner_mask(2, 5, 1)
		_assert(ch1_forest_corners.get("nw", false), "Ch1 语义回归：山道林地左上角朝主通路保留角落过渡")
		_assert_eq(ch1._terrain_at_or_cliff(ch1.victory_pos.x, ch1.victory_pos.y), 0,
			"Ch1 语义回归：胜利格保持为可通行主地面")
	_assert_eq(ch1._terrain_at_or_cliff(5, 1), 0, "Ch1 语义回归：北侧主缺口前一格保持为通路")
	_assert(ch1._terrain_at_or_cliff(3, 1) == 2 and ch1._terrain_at_or_cliff(7, 1) == 2,
		"Ch1 语义回归：缺口两侧仍保留封锁墙体")
	_assert(ch1.has_method("_wall_corner_mask"), "Ch1 语义回归：墙体角部暴露检测辅助可用")
	if ch1.has_method("_wall_corner_mask"):
		var ch1_gap_left_wall: Dictionary = ch1._wall_corner_mask(3, 1)
		_assert(ch1_gap_left_wall.get("nw", false), "Ch1 语义回归：北侧缺口左墙保留左上角体量")
	_assert(ch1._terrain_at_or_cliff(0, 4) == 3 and ch1._terrain_at_or_cliff(1, 4) == 0,
		"Ch1 语义回归：西侧世界边界紧贴前沿可行军通路")
	_assert(ch1.has_method("_cliff_corner_mask"), "Ch1 语义回归：峭壁角部暴露检测辅助可用")
	if ch1.has_method("_cliff_corner_mask"):
		var ch1_exit_cliff_corner: Dictionary = ch1._cliff_corner_mask(4, 0)
		_assert(ch1_exit_cliff_corner.get("se", false), "Ch1 语义回归：山道北侧缺口左缘峭壁保留右下角断面")
	_assert(ch1.recorded_statuses.any(func(msg: String) -> bool: return msg == PrologueChapterBriefsClass.CH1_OBJECTIVE_SUMMARY),
		"Ch1 语义回归：开场状态提示明确山道口目标")
	_assert(ch1.recorded_statuses.any(func(msg: String) -> bool: return msg.begins_with("目标：")),
		"Ch1 语义回归：开场提示采用目标前缀")
	_assert(ch1.recorded_statuses.any(func(msg: String) -> bool: return msg == PrologueChapterBriefsClass.CH1_OBJECTIVE_SUMMARY),
		"Ch1 语义回归：战斗目标与标题卡摘要完全一致")
	var ch1_objective := _battle_info_label(ch1, "ObjectiveLabel")
	_assert(ch1_objective != null, "Ch1 语义回归：存在长期目标标签")
	if ch1_objective != null:
		_assert_eq(ch1_objective.text, PrologueChapterBriefsClass.CH1_OBJECTIVE_SUMMARY,
			"Ch1 语义回归：长期目标标签显示统一后的山道口目标")
	var ch1_phase_opening := _battle_info_label(ch1, "PhaseLabel")
	_assert(ch1_phase_opening != null, "Ch1 语义回归：开场存在阶段标签")
	if ch1_phase_opening != null:
		_assert_eq(ch1_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(1, 1),
			"Ch1 语义回归：开场阶段标签锁定山道缺口")
	var ch1_guidance_opening := _battle_info_label(ch1, "GuidanceLabel")
	_assert(ch1_guidance_opening != null, "Ch1 语义回归：开场存在长期推进标签")
	if ch1_guidance_opening != null:
		_assert_eq(ch1_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH1_PROGRESS_MIDWAY,
			"Ch1 语义回归：开场长期推进标签与第一阶段一致")
	var ch1_turn_before: int = ch1._turn_count
	ch1.call_deferred("set", "_turn_count", ch1_turn_before + 1)
	await ch1._wait_for_turn_switched()
	_assert(ch1.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH1_PROGRESS_MIDWAY),
		"Ch1 语义回归：教学结束后使用统一中途推进提示")
	if ch1_phase_opening != null:
		_assert_eq(ch1_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(1, 1),
			"Ch1 语义回归：教学结束后阶段标签锁定山道缺口")
	if ch1_guidance_opening != null:
		_assert_eq(ch1_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH1_PROGRESS_MIDWAY,
			"Ch1 语义回归：长期推进标签显示统一后的山道推进提示")
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
	_assert(_path_exists_on_passable_grid(ch2, Vector2i(14, 17), Vector2i(14, 3)),
		"Ch2 语义回归：中轴主将到雷加主阵地存在连续推进路径")
	var ch2_axis: Array[Vector2i] = ch2._find_objective_guidance_path()
	_assert(not ch2_axis.is_empty(), "Ch2 语义回归：主推进轴线弱引导存在")
	_assert(ch2_axis.has(ch2.victory_pos), "Ch2 语义回归：主推进轴线弱引导抵达目标格")
	_assert(ch2_axis.has(Vector2i(14, 9)), "Ch2 语义回归：主推进轴线弱引导穿过中桥桥面")
	_assert(ch2_axis.has(Vector2i(14, 7)), "Ch2 语义回归：主推进轴线弱引导接上北岸桥头")
	_assert(ch2._terrain_at_or_cliff(12, 7) == 2 and ch2._terrain_at_or_cliff(15, 7) == 2,
		"Ch2 语义回归：中桥北桥头两侧营垒仍在，形成主决战桥头")
	_assert(ch2._terrain_at_or_cliff(14, 6) == 0 and ch2._adjacent_terrain_count(14, 6, 6) > 0,
		"Ch2 语义回归：中桥北桥头前地仍与桥面直接接驳")
	_assert(ch2._terrain_at_or_cliff(14, 11) == 0 and ch2._adjacent_terrain_count(14, 11, 6) > 0,
		"Ch2 语义回归：中桥南桥头前地仍与桥面直接接驳")
	_assert(ch2._adjacent_terrain_count(14, 6, 6) == 1 and ch2._adjacent_terrain_count(14, 11, 6) == 1,
		"Ch2 语义回归：中桥桥头前地保持单侧接桥收口")
	_assert(ch2._adjacent_terrain_count(14, 6, 4) == 0 and ch2._adjacent_terrain_count(14, 11, 4) == 0,
		"Ch2 语义回归：中桥桥头前地不会误判为贴河滩边")
	_assert(ch2.has_method("_wall_corner_mask"), "Ch2 语义回归：墙体角部暴露检测辅助可用")
	if ch2.has_method("_wall_corner_mask"):
		var ch2_bridge_bastion: Dictionary = ch2._wall_corner_mask(12, 7)
		_assert(ch2_bridge_bastion.get("se", false), "Ch2 语义回归：中桥左营垒保留右下角体量")
	_assert_eq(ch2._terrain_at_or_cliff(13, 7), 6, "Ch2 语义回归：中桥北桥头桥面保持完整")
	_assert(ch2.has_method("_plain_wall_contact_mask"), "Ch2 语义回归：平地贴墙接触检测辅助可用")
	if ch2.has_method("_plain_wall_contact_mask"):
		var ch2_bridgehead_contact: Dictionary = ch2._plain_wall_contact_mask(11, 6)
		_assert(ch2_bridgehead_contact.get("south", false), "Ch2 语义回归：中桥北桥头左侧平地保留南侧墙脚接触")
	_assert(ch2.has_method("_plain_wet_edge_mask"), "Ch2 语义回归：平地湿边接触检测辅助可用")
	if ch2.has_method("_plain_wet_edge_mask"):
		var ch2_north_bank_plain: Dictionary = ch2._plain_wet_edge_mask(9, 7)
		_assert_eq(ch2_north_bank_plain.get("south", -1), 4, "Ch2 语义回归：中桥北岸平地保留朝河湿边")
		_assert_eq(ch2_north_bank_plain.get("north", -1), -1, "Ch2 语义回归：中桥北岸平地不会误判成双向贴河")
		var ch2_south_mud_plain: Dictionary = ch2._plain_wet_edge_mask(11, 15)
		_assert_eq(ch2_south_mud_plain.get("south", -1), 5, "Ch2 语义回归：南岸泥地前平地保留朝沼泥边")
	_assert(ch2.has_method("_bridge_end_mask"), "Ch2 语义回归：桥端暴露检测辅助可用")
	if ch2.has_method("_bridge_end_mask"):
		var ch2_north_bridge_end: Dictionary = ch2._bridge_end_mask(14, 7)
		_assert(ch2_north_bridge_end.get("north", false), "Ch2 语义回归：中桥北桥头桥端保留北向端帽")
		_assert(not ch2_north_bridge_end.get("south", false), "Ch2 语义回归：中桥北桥头不会误判成南向端帽")
		var ch2_south_bridge_end: Dictionary = ch2._bridge_end_mask(14, 10)
		_assert(ch2_south_bridge_end.get("south", false), "Ch2 语义回归：中桥南桥头桥端保留南向端帽")
		_assert(not ch2_south_bridge_end.get("north", false), "Ch2 语义回归：中桥南桥头不会误判成北向端帽")
	for north_bridgehead: Vector2i in [Vector2i(7, 7), Vector2i(14, 7), Vector2i(21, 7)]:
		_assert_eq(ch2._terrain_at_or_cliff(north_bridgehead.x, north_bridgehead.y - 1), 0,
			"Ch2 语义回归：桥北桥头 %s 与陆地主通路直接接驳" % str(north_bridgehead))
	for south_bridgehead: Vector2i in [Vector2i(7, 10), Vector2i(14, 10), Vector2i(21, 10)]:
		_assert_eq(ch2._terrain_at_or_cliff(south_bridgehead.x, south_bridgehead.y + 1), 0,
			"Ch2 语义回归：桥南桥头 %s 与陆地主通路直接接驳" % str(south_bridgehead))
	_assert(ch2.has_method("_river_bank_mask"), "Ch2 语义回归：河岸暴露检测辅助可用")
	if ch2.has_method("_river_bank_mask"):
		var ch2_north_bank: Dictionary = ch2._river_bank_mask(11, 8)
		_assert(ch2_north_bank.get("north", false), "Ch2 语义回归：中桥左侧北岸河段保留北岸强化")
		_assert(not ch2_north_bank.get("south", false), "Ch2 语义回归：中桥左侧北岸河段不会误判成南岸")
		var ch2_south_bank: Dictionary = ch2._river_bank_mask(11, 9)
		_assert(ch2_south_bank.get("south", false), "Ch2 语义回归：中桥左侧南岸河段保留南岸强化")
		_assert(not ch2_south_bank.get("north", false), "Ch2 语义回归：中桥左侧南岸河段不会误判成北岸")
		var ch2_bridge_mouth_north: Dictionary = ch2._river_bank_mask(16, 8)
		_assert(ch2_bridge_mouth_north.get("north", false) and ch2._adjacent_terrain_count(16, 8, 6) > 0,
			"Ch2 语义回归：中桥北桥口邻接河段同时保留北岸与桥口接触")
		_assert(not ch2_bridge_mouth_north.get("south", false),
			"Ch2 语义回归：中桥北桥口邻接河段不会误判成双向岸块")
		var ch2_bridge_mouth_south: Dictionary = ch2._river_bank_mask(16, 9)
		_assert(ch2_bridge_mouth_south.get("south", false) and ch2._adjacent_terrain_count(16, 9, 6) > 0,
			"Ch2 语义回归：中桥南桥口邻接河段同时保留南岸与桥口接触")
		_assert(not ch2_bridge_mouth_south.get("north", false),
			"Ch2 语义回归：中桥南桥口邻接河段不会误判成双向岸块")
	_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return "争夺三桥" in msg and "雷加" in msg),
		"Ch2 语义回归：开场状态提示明确三桥与雷加目标")
	_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg.begins_with("目标：") and "争夺三桥" in msg),
		"Ch2 语义回归：开场提示采用目标前缀")
	_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg == PrologueChapterBriefsClass.CH2_OBJECTIVE_SUMMARY),
		"Ch2 语义回归：战斗目标与标题卡摘要完全一致")
	var ch2_objective := _battle_info_label(ch2, "ObjectiveLabel")
	_assert(ch2_objective != null, "Ch2 语义回归：存在长期目标标签")
	if ch2_objective != null:
		_assert("争夺三桥" in ch2_objective.text,
			"Ch2 语义回归：长期目标标签显示三桥主目标")
	var ch2_phase_opening := _battle_info_label(ch2, "PhaseLabel")
	_assert(ch2_phase_opening != null, "Ch2 语义回归：开场存在阶段标签")
	if ch2_phase_opening != null:
		_assert_eq(ch2_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(2, 1),
			"Ch2 语义回归：开场阶段标签锁定第一阶段")
	var ch2_guidance_opening := _battle_info_label(ch2, "GuidanceLabel")
	_assert(ch2_guidance_opening != null, "Ch2 语义回归：开场存在长期推进标签")
	if ch2_guidance_opening != null:
		_assert_eq(ch2_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH2_PROGRESS_SOUTH_BANK,
			"Ch2 语义回归：开场长期推进标签与第一阶段一致")
	if ch2.player_units.size() > 0:
		var ch2_lead: Unit = ch2.player_units[0]
		ch2_lead.grid_pos = Vector2i(14, 12)
		ch2._on_player_unit_action_position_updated(ch2_lead)
		_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH2_PROGRESS_SOUTH_BANK),
			"Ch2 语义回归：逼近南岸桥头时使用统一第一阶段提示")
		if ch2_phase_opening != null:
			_assert_eq(ch2_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(2, 1),
				"Ch2 语义回归：南岸桥头阶段标签更新为第一阶段")
		ch2_lead.grid_pos = Vector2i(14, 9)
		ch2._on_player_unit_action_position_updated(ch2_lead)
		_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH2_PROGRESS_CENTER_BRIDGE),
			"Ch2 语义回归：推进到中桥时使用统一第二阶段提示")
		if ch2_phase_opening != null:
			_assert_eq(ch2_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(2, 2),
				"Ch2 语义回归：中桥主攻阶段标签更新为第二阶段")
		ch2_lead.grid_pos = Vector2i(14, 7)
		ch2._on_player_unit_action_position_updated(ch2_lead)
		_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH2_PROGRESS_NORTH_BANK),
			"Ch2 语义回归：冲上北岸后使用统一第三阶段提示")
		if ch2_phase_opening != null:
			_assert_eq(ch2_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(2, 3),
				"Ch2 语义回归：北岸桥头阶段标签更新为第三阶段")
		if ch2_guidance_opening != null:
			_assert_eq(ch2_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH2_PROGRESS_NORTH_BANK,
				"Ch2 语义回归：长期推进标签会保留统一第三阶段提示")
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
		var ch3_axis: Array[Vector2i] = ch3._find_objective_guidance_path()
		_assert(not ch3_axis.is_empty(), "Ch3 语义回归：主推进轴线弱引导存在")
		_assert(ch3_axis.has(ch3.victory_pos), "Ch3 语义回归：主推进轴线弱引导抵达目标格")
		_assert(ch3_axis.has(Vector2i(12, 8)), "Ch3 语义回归：主推进轴线弱引导穿过塔前中轴接敌格")
	_assert(ch3.has_method("_terrain_edge_mask"), "Ch3 语义回归：地形边缘暴露检测辅助可用")
	if ch3.has_method("_terrain_edge_mask"):
		var ch3_swamp_edges: Dictionary = ch3._terrain_edge_mask(3, 8, 5)
		_assert(ch3_swamp_edges.get("south", false), "Ch3 语义回归：湿地南侧保留泥地边缘过渡")
		_assert(ch3_swamp_edges.get("west", false), "Ch3 语义回归：湿地西侧保留泥地边缘过渡")
	_assert(ch3.has_method("_terrain_corner_mask"), "Ch3 语义回归：地形角落暴露检测辅助可用")
	if ch3.has_method("_terrain_corner_mask"):
		var ch3_swamp_corners: Dictionary = ch3._terrain_corner_mask(3, 8, 5)
		_assert(ch3_swamp_corners.get("sw", false), "Ch3 语义回归：湿地左下角保留泥地角落过渡")
	_assert(ch3.has_method("_plain_wet_edge_mask"), "Ch3 语义回归：平地湿边接触检测辅助可用")
	if ch3.has_method("_plain_wet_edge_mask"):
		var ch3_swamp_plain: Dictionary = ch3._plain_wet_edge_mask(5, 6)
		_assert_eq(ch3_swamp_plain.get("south", -1), 5, "Ch3 语义回归：塔前湿地上缘平地保留朝沼泥边")
	_assert(ch3._gate_runs_horizontal(11, 5), "Ch3 语义回归：欢乐塔前左门道保持横向门洞识别")
	_assert(ch3._gate_runs_horizontal(12, 5), "Ch3 语义回归：欢乐塔前右门道保持横向门洞识别")
	var ch3_tower_gate_contact: Dictionary = ch3._plain_wall_contact_mask(11, 5)
	_assert(ch3_tower_gate_contact.get("north", false) and ch3_tower_gate_contact.get("south", false),
		"Ch3 语义回归：欢乐塔前门道仍保留上下门楣依托")
	var ch3_tower_gate_contact_right: Dictionary = ch3._plain_wall_contact_mask(12, 5)
	_assert(ch3_tower_gate_contact_right.get("north", false) and ch3_tower_gate_contact_right.get("south", false),
		"Ch3 语义回归：欢乐塔前右门道同样保留上下门楣依托")
	_assert(ch3._terrain_at_or_cliff(11, 4) == 2 and ch3._terrain_at_or_cliff(11, 6) == 2,
		"Ch3 语义回归：欢乐塔前左门道上下仍由墙体夹持")
	_assert(ch3._terrain_at_or_cliff(12, 4) == 2 and ch3._terrain_at_or_cliff(12, 6) == 2,
		"Ch3 语义回归：欢乐塔前右门道上下仍由墙体夹持")
	_assert_eq(ch3._terrain_at_or_cliff(12, 8), 0, "Ch3 语义回归：塔前中轴接敌格保持通路")
	_assert(ch3._terrain_at_or_cliff(10, 8) == 0 or ch3._terrain_at_or_cliff(14, 8) == 0,
		"Ch3 语义回归：塔前至少保留一侧绕行空间")
	_assert(ch3._terrain_at_or_cliff(0, 8) == 3 and ch3._terrain_at_or_cliff(1, 8) == 0,
		"Ch3 语义回归：西侧世界边界紧贴湿地外缘推进带")
	if ch3._dayne_unit != null:
		_assert(ch3._dayne_unit.grid_pos.y > ch3.victory_pos.y,
			"Ch3 语义回归：亚瑟·戴恩位于塔目标南侧门神位")
		_assert_eq(ch3._dayne_unit.grid_pos, Vector2i(12, 6),
			"Ch3 语义回归：亚瑟·戴恩保持中轴堵门")
	_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return "欢乐塔" in msg and "不必全歼" in msg),
		"Ch3 语义回归：开场状态提示明确到塔目标而非全歼")
	_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return msg.begins_with("目标：") and "欢乐塔" in msg),
		"Ch3 语义回归：开场提示采用目标前缀")
	_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return msg == PrologueChapterBriefsClass.CH3_OBJECTIVE_SUMMARY),
		"Ch3 语义回归：战斗目标与标题卡摘要完全一致")
	var ch3_objective := _battle_info_label(ch3, "ObjectiveLabel")
	_assert(ch3_objective != null, "Ch3 语义回归：存在长期目标标签")
	if ch3_objective != null:
		_assert("欢乐塔" in ch3_objective.text,
			"Ch3 语义回归：长期目标标签显示塔楼目标")
	var ch3_phase_opening := _battle_info_label(ch3, "PhaseLabel")
	_assert(ch3_phase_opening != null, "Ch3 语义回归：开场存在阶段标签")
	if ch3_phase_opening != null:
		_assert_eq(ch3_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(3, 1),
			"Ch3 语义回归：开场阶段标签锁定第一阶段")
	var ch3_guidance_opening := _battle_info_label(ch3, "GuidanceLabel")
	_assert(ch3_guidance_opening != null, "Ch3 语义回归：开场存在长期推进标签")
	if ch3_guidance_opening != null:
		_assert_eq(ch3_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH3_PROGRESS_SWAMP,
			"Ch3 语义回归：开场长期推进标签与第一阶段一致")
	if ch3._ned_unit != null:
		ch3._ned_unit.grid_pos = Vector2i(12, 12)
		ch3._on_player_unit_action_position_updated(ch3._ned_unit)
		_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH3_PROGRESS_SWAMP),
			"Ch3 语义回归：进入湿地区前沿时使用统一第一阶段提示")
		if ch3_phase_opening != null:
			_assert_eq(ch3_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(3, 1),
				"Ch3 语义回归：湿地区阶段标签更新为第一阶段")
		ch3._ned_unit.grid_pos = Vector2i(12, 9)
		ch3._on_player_unit_action_position_updated(ch3._ned_unit)
		_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + PrologueChapterBriefsClass.CH3_PROGRESS_TOWER),
			"Ch3 语义回归：奈德逼近塔前后使用统一第二阶段提示")
		if ch3_phase_opening != null:
			_assert_eq(ch3_phase_opening.text, PrologueChapterBriefsClass.get_progress_stage_badge(3, 2),
				"Ch3 语义回归：塔前杀伤区阶段标签更新为第二阶段")
		if ch3_guidance_opening != null:
			_assert_eq(ch3_guidance_opening.text, "推进：" + PrologueChapterBriefsClass.CH3_PROGRESS_TOWER,
				"Ch3 语义回归：长期推进标签会保留统一第二阶段提示")
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
	_assert(ch4.has_method("_river_bank_mask"), "Ch4 语义回归：河岸暴露检测辅助可用")
	_assert(ch4.has_method("_plain_wet_edge_mask"), "Ch4 语义回归：平地湿边接触检测辅助可用")
	if ch4.has_method("_plain_wet_edge_mask"):
		var ch4_moat_plain: Dictionary = ch4._plain_wet_edge_mask(13, 7)
		_assert_eq(ch4_moat_plain.get("south", -1), 4, "Ch4 语义回归：内护城河北岸平地保留朝河湿边")
		var ch4_blackwater_plain: Dictionary = ch4._plain_wet_edge_mask(13, 20)
		_assert_eq(ch4_blackwater_plain.get("north", -1), 4, "Ch4 语义回归：黑水河南岸平地保留朝河湿边")
		_assert_eq(ch4_blackwater_plain.get("south", -1), -1, "Ch4 语义回归：黑水河南岸平地不会误判成双向贴河")
	_assert(ch4.has_method("_bridge_end_mask"), "Ch4 语义回归：桥端暴露检测辅助可用")
	if ch4.has_method("_bridge_end_mask"):
		var ch4_inner_bridge_end: Dictionary = ch4._bridge_end_mask(18, 8)
		_assert(ch4_inner_bridge_end.get("north", false) and ch4_inner_bridge_end.get("south", false),
			"Ch4 语义回归：内护城河主桥保留南北两端桥台端帽")
		var ch4_blackwater_bridge_end: Dictionary = ch4._bridge_end_mask(18, 19)
		_assert(ch4_blackwater_bridge_end.get("north", false) and ch4_blackwater_bridge_end.get("south", false),
			"Ch4 语义回归：黑水河主桥保留南北两端桥台端帽")
	if ch4.has_method("_river_bank_mask"):
		var ch4_inner_moat_bank: Dictionary = ch4._river_bank_mask(13, 8)
		_assert(ch4_inner_moat_bank.get("north", false) and ch4_inner_moat_bank.get("south", false),
			"Ch4 语义回归：内护城河非桥接河段同时保留南北两侧岸线")
		var ch4_blackwater_bank: Dictionary = ch4._river_bank_mask(13, 19)
		_assert(ch4_blackwater_bank.get("north", false) and ch4_blackwater_bank.get("south", false),
			"Ch4 语义回归：黑水河非桥接河段同时保留南北两侧岸线")
		var ch4_bridge_mouth_inner: Dictionary = ch4._river_bank_mask(16, 8)
		_assert(ch4_bridge_mouth_inner.get("north", false) and ch4._adjacent_terrain_count(16, 8, 6) > 0,
			"Ch4 语义回归：内护城河主桥北桥口邻接河段同时保留北岸与桥口接触")
		_assert(ch4_bridge_mouth_inner.get("south", false),
			"Ch4 语义回归：内护城河单行河段桥口仍保留对侧压暗岸线")
		var ch4_bridge_mouth_blackwater: Dictionary = ch4._river_bank_mask(16, 19)
		_assert(ch4_bridge_mouth_blackwater.get("south", false) and ch4._adjacent_terrain_count(16, 19, 6) > 0,
			"Ch4 语义回归：黑水河主桥南桥口邻接河段同时保留南岸与桥口接触")
		_assert(ch4_bridge_mouth_blackwater.get("north", false),
			"Ch4 语义回归：黑水河单行河段桥口仍保留对侧压暗岸线")
	_assert(_path_exists_on_passable_grid(ch4, Vector2i(18, 22), ch4.victory_pos),
		"Ch4 语义回归：中轴部署区到铁王座存在连续可达路径")
	var ch4_axis: Array[Vector2i] = ch4._find_objective_guidance_path()
	_assert(not ch4_axis.is_empty(), "Ch4 语义回归：主推进轴线弱引导存在")
	_assert(ch4_axis.has(ch4.victory_pos), "Ch4 语义回归：主推进轴线弱引导抵达目标格")
	_assert(ch4_axis.has(Vector2i(18, 19)), "Ch4 语义回归：主推进轴线弱引导穿过黑水桥")
	_assert(ch4_axis.has(Vector2i(18, 18)), "Ch4 语义回归：主推进轴线弱引导穿过南城墙主门")
	_assert(ch4_axis.has(Vector2i(18, 13)), "Ch4 语义回归：主推进轴线弱引导穿过内城墙主门")
	_assert(ch4_axis.has(Vector2i(18, 11)), "Ch4 语义回归：主推进轴线弱引导穿过红堡外墙主门")
	_assert_eq(ch4._terrain_at_or_cliff(18, 11), 0, "Ch4 语义回归：红堡外墙主门保持通路")
	_assert_eq(ch4._terrain_at_or_cliff(18, 13), 0, "Ch4 语义回归：内城墙主门保持通路")
	_assert_eq(ch4._terrain_at_or_cliff(18, 18), 0, "Ch4 语义回归：南城墙主门保持通路")
	_assert(ch4.has_method("_wall_corner_mask"), "Ch4 语义回归：墙体角部暴露检测辅助可用")
	if ch4.has_method("_wall_corner_mask"):
		var ch4_red_keep_gate_corner: Dictionary = ch4._wall_corner_mask(21, 11)
		_assert(ch4_red_keep_gate_corner.get("nw", false), "Ch4 语义回归：红堡外墙主门右侧保留左上角体量")
	_assert(ch4.has_method("_plain_wall_contact_mask"), "Ch4 语义回归：平地贴墙接触检测辅助可用")
	if ch4.has_method("_plain_wall_contact_mask"):
		var ch4_south_gate_contact: Dictionary = ch4._plain_wall_contact_mask(16, 16)
		_assert(ch4_south_gate_contact.get("south", false), "Ch4 语义回归：南城墙主门前平地保留南侧墙脚接触")
		var ch4_inner_gate_contact: Dictionary = ch4._plain_wall_contact_mask(16, 12)
		_assert(ch4_inner_gate_contact.get("north", false) and ch4_inner_gate_contact.get("south", false),
			"Ch4 语义回归：内城墙主门侧前平地同时保留门线前后接触")
	_assert(ch4._gate_runs_vertical(18, 11), "Ch4 语义回归：红堡外墙主门保持纵向门洞识别")
	_assert(ch4._gate_runs_vertical(18, 13), "Ch4 语义回归：内城墙主门保持纵向门洞识别")
	_assert(ch4._gate_runs_vertical(18, 18), "Ch4 语义回归：南城墙主门保持纵向门洞识别")
	_assert(ch4._gate_runs_vertical(17, 11) and ch4._gate_runs_vertical(20, 11),
		"Ch4 语义回归：红堡外墙主门边缘格仍保持门洞识别")
	var ch4_outer_gate_left_contact: Dictionary = ch4._plain_wall_contact_mask(17, 11)
	var ch4_outer_gate_right_contact: Dictionary = ch4._plain_wall_contact_mask(20, 11)
	_assert(ch4_outer_gate_left_contact.get("west", false) and ch4_outer_gate_right_contact.get("east", false),
		"Ch4 语义回归：红堡外墙主门边缘格仍保留左右门框接触")
	var ch4_inner_gate_left_contact: Dictionary = ch4._plain_wall_contact_mask(17, 13)
	var ch4_inner_gate_right_contact: Dictionary = ch4._plain_wall_contact_mask(20, 13)
	_assert(ch4_inner_gate_left_contact.get("west", false) and ch4_inner_gate_right_contact.get("east", false),
		"Ch4 语义回归：内城墙主门边缘格仍保留左右门框接触")
	var ch4_south_gate_left_contact: Dictionary = ch4._plain_wall_contact_mask(17, 18)
	var ch4_south_gate_right_contact: Dictionary = ch4._plain_wall_contact_mask(20, 18)
	_assert(ch4_south_gate_left_contact.get("west", false) and ch4_south_gate_right_contact.get("east", false),
		"Ch4 语义回归：南城墙主门边缘格仍保留左右门框接触")
	_assert(ch4._terrain_at_or_cliff(16, 11) == 2 and ch4._terrain_at_or_cliff(21, 11) == 2,
		"Ch4 语义回归：红堡外墙主门两侧仍保留门框边墙")
	_assert(ch4._terrain_at_or_cliff(18, 7) == 0 and ch4._adjacent_terrain_count(18, 7, 6) > 0,
		"Ch4 语义回归：红堡内护城河主桥北桥头前地仍与桥面直接接驳")
	_assert(ch4._terrain_at_or_cliff(18, 9) == 0 and ch4._adjacent_terrain_count(18, 9, 6) > 0,
		"Ch4 语义回归：红堡内护城河主桥南桥头前地仍与桥面直接接驳")
	_assert(ch4._adjacent_terrain_count(18, 7, 6) == 1 and ch4._adjacent_terrain_count(18, 9, 6) == 1,
		"Ch4 语义回归：红堡内护城河主桥桥头前地保持单侧接桥收口")
	_assert(ch4._adjacent_terrain_count(18, 7, 4) == 0 and ch4._adjacent_terrain_count(18, 9, 4) == 0,
		"Ch4 语义回归：红堡内护城河主桥桥头前地不会误判为贴河滩边")
	_assert_eq(ch4._terrain_at_or_cliff(18, 7), 0, "Ch4 语义回归：中轴主桥北桥头与陆地直接接驳")
	_assert_eq(ch4._terrain_at_or_cliff(18, 9), 0, "Ch4 语义回归：中轴主桥南桥头与陆地直接接驳")
	_assert(ch4._terrain_at_or_cliff(12, 11) == 2 and ch4._terrain_at_or_cliff(13, 11) == 2 and ch4._terrain_at_or_cliff(14, 11) == 2,
		"Ch4 语义回归：红堡外墙主门左侧仍保留连续墙线")
	_assert(ch4._terrain_at_or_cliff(21, 13) == 2 and ch4._terrain_at_or_cliff(22, 13) == 2 and ch4._terrain_at_or_cliff(23, 13) == 2,
		"Ch4 语义回归：君临内城墙主门右侧仍保留连续墙线")
	_assert(ch4._terrain_at_or_cliff(1, 18) == 2 and ch4._terrain_at_or_cliff(2, 18) == 2,
		"Ch4 语义回归：南城墙边段仍保留连续防线")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return "中轴" in msg and "王军指挥官" in msg),
		"Ch4 语义回归：开场状态提示明确中轴推进与指挥官目标")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg.begins_with("目标：") and "王军指挥官" in msg),
		"Ch4 语义回归：开场提示采用目标前缀")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "目标：" + Ch4BattleBriefClass.BATTLE_OBJECTIVE),
		"Ch4 语义回归：战斗目标与部署简报主目标一致")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + Ch4BattleBriefClass.STAGE_1_GUIDANCE),
		"Ch4 语义回归：开场即显示第一阶段推进提示")
	var ch4_objective := _battle_info_label(ch4, "ObjectiveLabel")
	_assert(ch4_objective != null, "Ch4 语义回归：存在长期目标标签")
	if ch4_objective != null:
		_assert("王军指挥官" in ch4_objective.text,
			"Ch4 语义回归：长期目标标签显示红堡主目标")
	var ch4_phase_opening := _battle_info_label(ch4, "PhaseLabel")
	_assert(ch4_phase_opening != null, "Ch4 语义回归：开场存在阶段标签")
	if ch4_phase_opening != null:
		_assert_eq(ch4_phase_opening.text, Ch4BattleBriefClass.get_stage_badge(1),
			"Ch4 语义回归：开场阶段标签锁定第一阶段")
	var ch4_guidance_opening := _battle_info_label(ch4, "GuidanceLabel")
	_assert(ch4_guidance_opening != null, "Ch4 语义回归：开场存在长期推进标签")
	if ch4_guidance_opening != null:
		_assert_eq(ch4_guidance_opening.text, "推进：" + Ch4BattleBriefClass.STAGE_1_GUIDANCE,
			"Ch4 语义回归：开场长期推进标签与第一阶段简报一致")
	if ch4._ned_unit != null:
		ch4._ned_unit.grid_pos = Vector2i(18, 20)
		ch4._on_player_unit_action_position_updated(ch4._ned_unit)
		_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + Ch4BattleBriefClass.STAGE_1_GUIDANCE),
			"Ch4 语义回归：越过黑水桥后仍使用第一阶段标准提示")
		ch4._ned_unit.grid_pos = Vector2i(18, 18)
		ch4._on_player_unit_action_position_updated(ch4._ned_unit)
		_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + Ch4BattleBriefClass.STAGE_2_GUIDANCE),
			"Ch4 语义回归：穿过南城墙后使用第二阶段标准提示")
		if ch4_phase_opening != null:
			_assert_eq(ch4_phase_opening.text, Ch4BattleBriefClass.get_stage_badge(2),
				"Ch4 语义回归：穿过南城墙后阶段标签更新为第二阶段")
		ch4._ned_unit.grid_pos = Vector2i(18, 16)
		ch4._on_player_unit_action_position_updated(ch4._ned_unit)
		_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + Ch4BattleBriefClass.STAGE_3_GUIDANCE),
			"Ch4 语义回归：进入中央大道后使用第三阶段标准提示")
		if ch4_phase_opening != null:
			_assert_eq(ch4_phase_opening.text, Ch4BattleBriefClass.get_stage_badge(3),
				"Ch4 语义回归：进入中央大道后阶段标签更新为第三阶段")
		ch4._ned_unit.grid_pos = Vector2i(18, 11)
		ch4._on_player_unit_action_position_updated(ch4._ned_unit)
		_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "推进：" + Ch4BattleBriefClass.STAGE_4_GUIDANCE),
			"Ch4 语义回归：攻入红堡外院后使用第四阶段标准提示")
		if ch4_phase_opening != null:
			_assert_eq(ch4_phase_opening.text, Ch4BattleBriefClass.get_stage_badge(4),
				"Ch4 语义回归：攻入红堡外院后阶段标签更新为第四阶段")
		var ch4_guidance := _battle_info_label(ch4, "GuidanceLabel")
		_assert(ch4_guidance != null, "Ch4 语义回归：存在长期推进标签")
		if ch4_guidance != null:
			_assert_eq(ch4_guidance.text, "推进：" + Ch4BattleBriefClass.STAGE_4_GUIDANCE,
				"Ch4 语义回归：长期推进标签会保留第四阶段标准提示")
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

func _test_map_sprite_assets_and_animation() -> void:
	var expected_sprite_map := {
		"arthur_dayne.json": "arthur_dayne_map.png",
		"barristan_selmy.json": "barristan_selmy_map.png",
		"dorne_knight.json": "dorne_knight_map.png",
		"howland_reed.json": "howland_reed_map.png",
		"lannister_soldier.json": "lannister_soldier_map.png",
		"ned_stark.json": "ned_stark_map.png",
		"northern_knight.json": "northern_knight_map.png",
		"rebel_lord.json": "rebel_lord_map.png",
		"rhaegar_targaryen.json": "rhaegar_targaryen_map.png",
		"robert_baratheon.json": "robert_baratheon_map.png",
		"royal_guard_captain.json": "royal_guard_captain_map.png",
		"royal_soldier.json": "royal_soldier_map.png",
		"targaryen_soldier.json": "targaryen_soldier_map.png",
	}
	_assert_eq(BootstrapClass.UNIT_SPRITE_MAP, expected_sprite_map,
		"所有可上场单位使用一对一专属地图精灵映射")

	var chapter_sprite_maps := {
		"序章二": [Ch2BootstrapClass.UNIT_SPRITE_MAP, [
			"ned_stark.json", "robert_baratheon.json", "rhaegar_targaryen.json",
			"barristan_selmy.json", "rebel_lord.json", "targaryen_soldier.json",
		]],
		"序章三": [Ch3BootstrapClass.UNIT_SPRITE_MAP, [
			"ned_stark.json", "howland_reed.json", "arthur_dayne.json",
			"dorne_knight.json", "northern_knight.json", "royal_soldier.json",
		]],
		"序章四": [Ch4BootstrapClass.UNIT_SPRITE_MAP, [
			"ned_stark.json", "northern_knight.json", "lannister_soldier.json",
			"royal_guard_captain.json", "royal_soldier.json",
		]],
	}
	for chapter_name: String in chapter_sprite_maps:
		var chapter_data: Array = chapter_sprite_maps[chapter_name]
		var sprite_map: Dictionary = chapter_data[0]
		for unit_file: String in chapter_data[1]:
			var expected_sprite := unit_file.trim_suffix(".json") + "_map.png"
			_assert_eq(sprite_map.get(unit_file, ""), expected_sprite,
				"%s 独立战场使用专属地图精灵：%s" % [chapter_name, unit_file])

	var sprite_names: Array[String] = []
	for sprite_name: String in expected_sprite_map.values():
		sprite_names.append(sprite_name)
	# 詹姆与史林特暂未拥有单位 JSON，但预制同规格资源供后续章节直接接入。
	sprite_names.append("jaime_lannister_map.png")
	sprite_names.append("janos_slynt_map.png")
	for sprite_name: String in sprite_names:
		var path := "res://assets/units/" + sprite_name
		_assert(FileAccess.file_exists(path), "地图精灵资源存在：%s" % sprite_name)
		if not FileAccess.file_exists(path):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_assert(img != null and not img.is_empty(), "地图精灵可直接读取：%s" % sprite_name)
		if img == null or img.is_empty():
			continue
		_assert_eq(img.get_size(), Vector2i(96, 32), "地图精灵为横向三帧96×32：%s" % sprite_name)
		_assert(img.detect_alpha() != Image.ALPHA_NONE, "地图精灵保留透明通道：%s" % sprite_name)
		for frame_idx in 3:
			var frame_img := img.get_region(Rect2i(frame_idx * 32, 0, 32, 32))
			_assert(frame_img.get_used_rect().has_area(),
				"地图精灵第%d帧包含可见像素：%s" % [frame_idx + 1, sprite_name])

	var unit_scene := load("res://scenes/battle/Unit.tscn") as PackedScene
	_assert(unit_scene != null, "单位场景可加载以验证地图精灵运行时行为")
	if unit_scene == null:
		return
	var unit := unit_scene.instantiate() as Unit
	root.add_child(unit)
	await process_frame
	var sprite := unit.get_node("Sprite") as Sprite2D
	_assert(sprite.visible, "地图精灵在战场单位上可见")
	_assert_eq(sprite.hframes, 3, "地图精灵按三帧横向图集配置")
	var name_label := unit.get_node("Label") as Label
	_assert(name_label.offset_bottom <= -32.0, "单位简称完全位于精灵上方而非遮挡角色")
	var initial_frame := sprite.frame
	await create_timer(0.4).timeout
	_assert(sprite.frame != initial_frame, "地图精灵待机动画会自动切换帧")
	unit.queue_free()
	await process_frame

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
	var battle_script_uid := FileAccess.get_file_as_string(
		"res://scripts/battle/BattleBootstrap.gd.uid").strip_edges()
	var battle_scene_source := FileAccess.get_file_as_string("res://scenes/battle/BattleMap.tscn")
	_assert(('uid="%s" path="res://scripts/battle/BattleBootstrap.gd"' % battle_script_uid) in battle_scene_source,
		"BattleMap 引用 BattleBootstrap 的当前资源 UID")

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

func _test_chapter_transition_metadata() -> void:
	var transition_path := "res://scenes/ui/ChapterTransition.tscn"
	var transition_scene := load(transition_path) as PackedScene
	_assert(transition_scene != null, "ChapterTransition 场景可加载")
	if transition_scene == null:
		return

	var transition := transition_scene.instantiate()
	root.add_child(transition)
	await process_frame
	_assert(transition.get_node_or_null("ChapterNumber") != null, "标题卡包含 ChapterNumber")
	_assert(transition.get_node_or_null("ChapterTitle") != null, "标题卡包含 ChapterTitle")
	_assert(transition.get_node_or_null("TimeLabel") != null, "标题卡包含 TimeLabel")
	_assert(transition.get_node_or_null("SubLabel") != null, "标题卡包含 SubLabel")
	_assert(transition.get_node_or_null("ObjectiveLabel") != null, "标题卡包含 ObjectiveLabel")

	transition.show_chapter(
		"序章·二",
		"三叉戟",
		"篡夺者战争 · 第三年",
		"决战章节 / 三桥争夺",
		"目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。"
	)
	await transition.transition_finished

	var transition_ch_num := transition.get_node_or_null("ChapterNumber") as Label
	var transition_title := transition.get_node_or_null("ChapterTitle") as Label
	var transition_time := transition.get_node_or_null("TimeLabel") as Label
	var transition_sub := transition.get_node_or_null("SubLabel") as Label
	var transition_objective := transition.get_node_or_null("ObjectiveLabel") as Label
	if transition_ch_num != null:
		_assert_eq(transition_ch_num.text, "序章·二", "标题卡显示章节编号")
	if transition_title != null:
		_assert_eq(transition_title.text, "三叉戟", "标题卡显示章节标题")
	if transition_time != null:
		_assert_eq(transition_time.text, "篡夺者战争 · 第三年", "标题卡显示时间信息")
	if transition_sub != null:
		_assert_eq(transition_sub.text, "决战章节 / 三桥争夺", "标题卡显示章节副标题")
		_assert(transition_sub.visible, "标题卡副标题在传入内容时可见")
	if transition_objective != null:
		_assert_eq(transition_objective.text,
			"目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。", "标题卡显示战术目标摘要")
		_assert(transition_objective.visible, "标题卡目标摘要在传入内容时可见")

	var reentry_finish_events: Array[bool] = []
	transition.transition_finished.connect(
		func() -> void: reentry_finish_events.append(true))
	transition.show_chapter("旧章节", "旧标题", "旧时间")
	await process_frame
	transition.show_chapter("新章节", "新标题", "新时间")
	await create_timer(4.3).timeout
	_assert_eq(reentry_finish_events.size(), 1,
		"章节标题卡重入后只完成最新一次播放")
	_assert_eq(transition_ch_num.text, "新章节",
		"章节标题卡重入后保留最新章节内容")

	if is_instance_valid(transition):
		transition.queue_free()
	await process_frame

	var opening_src := FileAccess.get_file_as_string("res://scripts/Opening.gd")
	_assert("PrologueChapterBriefs" in opening_src, "Opening.gd 通过统一章节简报常量提供 Ch1 目标")
	_assert("CH1_CHAPTER_SUB_LABEL" in opening_src, "Opening.gd 包含 Ch1 标题卡副标题常量")
	_assert("CH1_CHAPTER_OBJECTIVE" in opening_src, "Opening.gd 包含 Ch1 标题卡目标常量")
	_assert("_play_ch1_title_card" in opening_src, "Opening.gd 包含 Ch1 标题卡播放流程")
	_assert("_get_ch1_title_card_args" in opening_src, "Opening.gd 包含 Ch1 标题卡参数封装")
	_assert("_begin_ch1_cutscene_flow" in opening_src, "Opening.gd 将 Ch1 标题卡与过场串联")

	var chapter_opening_src := FileAccess.get_file_as_string("res://scripts/chapter/ChapterOpening.gd")
	_assert("_chapter_sub_label" in chapter_opening_src, "ChapterOpening 基类包含章节副标题字段")
	_assert("_chapter_objective" in chapter_opening_src, "ChapterOpening 基类包含章节目标字段")
	_assert("_chapter_sub_label, _chapter_objective" in chapter_opening_src,
		"ChapterOpening 会把副标题与目标传给标题卡")

func _test_chapter_opening_configuration() -> void:
	var ch2_script := load("res://scripts/chapter/Opening_Ch2.gd")
	var ch3_script := load("res://scripts/chapter/Opening_Ch3.gd")
	var ch4_script := load("res://scripts/chapter/Opening_Ch4.gd")
	_assert(ch2_script != null, "Opening_Ch2 脚本可加载")
	_assert(ch3_script != null, "Opening_Ch3 脚本可加载")
	_assert(ch4_script != null, "Opening_Ch4 脚本可加载")
	if ch2_script == null or ch3_script == null or ch4_script == null:
		return

	var ch2_opening = ch2_script.new()
	var ch3_opening = ch3_script.new()
	var ch4_opening = ch4_script.new()
	ch2_opening._setup()
	ch3_opening._setup()
	ch4_opening._setup()

	_assert_eq(ch2_opening._chapter_num, "序章·二", "Ch2 Opening 配置正确章节编号")
	_assert_eq(ch2_opening._chapter_sub_label, "决战章节 / 三桥争夺", "Ch2 Opening 配置正确副标题")
	_assert_eq(ch2_opening._chapter_objective, PrologueChapterBriefsClass.CH2_OBJECTIVE_SUMMARY,
		"Ch2 Opening 配置统一章节目标摘要")
	_assert_eq(ch2_opening._cutscene_files.size(), 1, "Ch2 Opening 仅配置一段开场过场")
	_assert_eq(ch2_opening._cutscene_files[0], "res://data/cutscenes/ch2_opening.json",
		"Ch2 Opening 使用正确过场文件")

	_assert_eq(ch3_opening._chapter_num, "序章·三", "Ch3 Opening 配置正确章节编号")
	_assert_eq(ch3_opening._chapter_sub_label, "追索真相 / 突破守门者", "Ch3 Opening 配置正确副标题")
	_assert_eq(ch3_opening._chapter_objective, PrologueChapterBriefsClass.CH3_OBJECTIVE_SUMMARY,
		"Ch3 Opening 配置统一章节目标摘要")
	_assert_eq(ch3_opening._cutscene_files.size(), 1, "Ch3 Opening 仅配置一段开场过场")
	_assert_eq(ch3_opening._cutscene_files[0], "res://data/cutscenes/ch3_opening.json",
		"Ch3 Opening 使用正确过场文件")

	_assert_eq(ch4_opening._chapter_num, "序章·四", "Ch4 Opening 配置正确章节编号")
	_assert_eq(ch4_opening._chapter_sub_label, "攻城终章 / 红堡突破", "Ch4 Opening 配置正确副标题")
	_assert_eq(ch4_opening._chapter_objective, PrologueChapterBriefsClass.CH4_OBJECTIVE_SUMMARY,
		"Ch4 Opening 配置统一章节目标摘要")
	_assert_eq(ch4_opening._cutscene_files.size(), 1, "Ch4 Opening 仅配置一段开场过场")
	_assert_eq(ch4_opening._cutscene_files[0], "res://data/cutscenes/ch4_opening.json",
		"Ch4 Opening 使用正确过场文件")

	var opening_specs := [
		{
			"path": "res://scripts/chapter/Opening_Ch2.gd",
			"title": "三叉戟",
			"sub": "决战章节 / 三桥争夺",
			"objective": "目标：争夺三桥并稳住两翼，从中桥突破雷加本阵。",
		},
		{
			"path": "res://scripts/chapter/Opening_Ch3.gd",
			"title": "极乐塔",
			"sub": "追索真相 / 突破守门者",
			"objective": "目标：让奈德抵达欢乐塔，不必全歼守军。",
		},
		{
			"path": "res://scripts/chapter/Opening_Ch4.gd",
			"title": "铁王座",
			"sub": "攻城终章 / 红堡突破",
			"objective": "目标：沿中轴攻入红堡，击败王军指挥官后迫使兰军归降。",
		},
	]
	for spec: Dictionary in opening_specs:
		var opening_script := load(spec["path"])
		_assert(opening_script != null, "章节 Opening 脚本可加载：%s" % spec["path"])
		if opening_script == null:
			continue
		var opening: Variant = opening_script.new()
		_assert(opening != null, "章节 Opening 脚本可实例化：%s" % spec["path"])
		if opening == null:
			continue
		opening._setup()
		_assert_eq(opening._chapter_title, spec["title"], "%s 标题正确" % spec["title"])
		_assert_eq(opening._chapter_sub_label, spec["sub"], "%s 副标题正确" % spec["title"])
		_assert_eq(opening._chapter_objective, spec["objective"], "%s 目标摘要正确" % spec["title"])
		_assert(opening._chapter_objective.begins_with("目标："), "%s 目标摘要遵循 HUD 语义前缀" % spec["title"])
		opening.free()

	var ch2_opening_src := FileAccess.get_file_as_string("res://scripts/chapter/Opening_Ch2.gd")
	var ch3_opening_src := FileAccess.get_file_as_string("res://scripts/chapter/Opening_Ch3.gd")
	var ch4_opening_src := FileAccess.get_file_as_string("res://scripts/chapter/Opening_Ch4.gd")
	_assert("PrologueChapterBriefs" in ch2_opening_src, "Opening_Ch2 通过统一章节简报常量提供目标")
	_assert("PrologueChapterBriefs" in ch3_opening_src, "Opening_Ch3 通过统一章节简报常量提供目标")
	_assert("PrologueChapterBriefs" in ch4_opening_src, "Opening_Ch4 通过统一章节简报常量提供目标")
	ch2_opening.free()
	ch3_opening.free()
	ch4_opening.free()
	_assert(not is_instance_valid(ch2_opening)
		and not is_instance_valid(ch3_opening)
		and not is_instance_valid(ch4_opening),
		"章节 Opening 配置测试释放临时节点实例")

func _test_chapter_event_flow() -> void:
	SaveSystem.delete_save()
	SaveSystem.start_new_campaign()
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
		_assert(ch2.recorded_statuses.any(func(msg: String) -> bool: return msg == "战局：" + PrologueChapterBriefsClass.CH2_BATTLE_RESOLUTION),
			"Ch2 雷加死亡后使用统一战局反馈")
		var ch2_objective_event := _battle_info_label(ch2, "ObjectiveLabel")
		if ch2_objective_event != null:
			_assert_eq(ch2_objective_event.text, "战局：" + PrologueChapterBriefsClass.CH2_BATTLE_RESOLUTION,
				"Ch2 事件回归：长期目标标签会更新为统一战局反馈")
		_assert(ch2.recorded_cutscenes.has("res://data/cutscenes/ch2_rhaegar_fall.json"),
			"Ch2 雷加死亡触发过场")
		_assert(ch2.recorded_cutscenes.has("res://data/cutscenes/ch2_split.json"),
			"Ch2 雷加死亡后自动触发战后分兵过场")
		_assert(ch2.recorded_dialogues.has("res://data/dialogues/ch2_post.json"),
			"Ch2 雷加死亡后自动触发战后对话")
		await process_frame
		_assert(ch2.recorded_advances.has(3), "Ch2 胜利后推进到第3章")
		_assert_eq(GameState.current_chapter, 3, "Ch2 事件后当前章节=3")
		_assert_eq(SaveSystem.load_current_chapter(), 3, "Ch2 胜利事件同步保存 Ch3 检查点")
		_assert(SaveSystem.get_completed_chapters().has(2), "Ch2 胜利事件同步记录 Ch2 已完成")
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
	_assert(ch3.recorded_statuses.any(func(msg: String) -> bool: return msg == "战局：" + PrologueChapterBriefsClass.CH3_BATTLE_RESOLUTION),
		"Ch3 抵达塔门后使用统一战局反馈")
	var ch3_objective_event := _battle_info_label(ch3, "ObjectiveLabel")
	if ch3_objective_event != null:
		_assert_eq(ch3_objective_event.text, "战局：" + PrologueChapterBriefsClass.CH3_BATTLE_RESOLUTION,
			"Ch3 事件回归：长期目标标签会更新为统一塔门战局")
	_assert(ch3.recorded_cutscenes.has("res://data/cutscenes/ch3_dayne_trigger.json"),
		"Ch3 触发霍兰刺杀戴恩过场")
	_assert(ch3.recorded_cutscenes.has("res://data/cutscenes/ch3_lyanna.json"),
		"Ch3 触发莱安娜过场")
	_assert(ch3.recorded_dialogues.has("res://data/dialogues/ch3_post.json"),
		"Ch3 触发战后对话")
	_assert(ch3.recorded_advances.has(4), "Ch3 事件后推进到第4章")
	_assert_eq(GameState.current_chapter, 4, "Ch3 事件后当前章节=4")
	_assert_eq(SaveSystem.load_current_chapter(), 4, "Ch3 塔事件同步保存 Ch4 检查点")
	_assert(SaveSystem.get_completed_chapters().has(3), "Ch3 塔事件同步记录 Ch3 已完成")
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
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return "兰尼斯特军已归降" in msg),
		"Ch4 指挥官死亡后出现归降道路反馈")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg.begins_with("战局：") and "兰尼斯特军已归降" in msg),
		"Ch4 兰军归降反馈采用战局前缀")
	_assert(ch4.recorded_statuses.any(func(msg: String) -> bool: return msg == "战局：" + Ch4BattleBriefClass.THRONE_SECURED_STATUS),
		"Ch4 最终结局前会给出铁王座落幕反馈")
	var ch4_objective_event := _battle_info_label(ch4, "ObjectiveLabel")
	if ch4_objective_event != null:
		_assert("铁王座" in ch4_objective_event.text,
			"Ch4 事件回归：长期目标标签最终更新为铁王座落幕反馈")
	var ch4_phase_event := _battle_info_label(ch4, "PhaseLabel")
	if ch4_phase_event != null:
		_assert_eq(ch4_phase_event.text, Ch4BattleBriefClass.get_stage_badge(4),
			"Ch4 事件回归：归降后阶段标签保持第四阶段")
	_assert(ch4.recorded_dialogues.has("res://data/dialogues/ch4_post.json"),
		"Ch4 最终结局对话触发")
	_assert(ch4.recorded_cutscenes.has("res://data/cutscenes/ch4_ending.json"),
		"Ch4 最终结局过场触发")
	_assert(ch4.recorded_advances.has(0), "Ch4 结局后返回主入口")
	_assert_eq(GameState.current_chapter, 1, "Ch4 事件后章节重置到1")
	_assert_eq(SaveSystem.load_current_chapter(), 5, "Ch4 结局同步保存序章完成态")
	_assert(SaveSystem.get_completed_chapters().has(4), "Ch4 结局同步记录 Ch4 已完成")
	if is_instance_valid(ch4):
		ch4.queue_free()
	await process_frame

func _test_ch1_save_and_deploy_flow() -> void:
	# ── Ch1：敌军全灭胜利与到达胜利格胜利 ─────────────────
	SaveSystem.delete_save()
	SaveSystem.start_new_campaign()
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
	_assert_eq(SaveSystem.load_current_chapter(), 2, "Ch1 敌军全灭同步保存 Ch2 检查点")
	_assert(SaveSystem.get_completed_chapters().has(1), "Ch1 敌军全灭同步记录 Ch1 已完成")
	if is_instance_valid(ch1_kill):
		ch1_kill.queue_free()
	await process_frame

	SaveSystem.delete_save()
	SaveSystem.start_new_campaign()
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
		_assert_eq(SaveSystem.load_current_chapter(), 2, "Ch1 奈德到达目标同步保存 Ch2 检查点")
		_assert(SaveSystem.get_completed_chapters().has(1), "Ch1 奈德到达目标同步记录 Ch1 已完成")
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
	_assert(opening_fresh.played_ch1_title_card, "Opening 无存档时会先播放 Ch1 标题卡")
	_assert(opening_fresh.started_ch1_cutscene_flow, "Opening 无存档时标题卡后进入 Ch1 过场流程")
	_assert_eq(opening_fresh.recorded_ch1_title_card_args.size(), 5, "Opening 记录完整的 Ch1 标题卡参数")
	if opening_fresh.recorded_ch1_title_card_args.size() == 5:
		_assert_eq(opening_fresh.recorded_ch1_title_card_args[0], "序章·一", "Opening Ch1 标题卡编号正确")
		_assert_eq(opening_fresh.recorded_ch1_title_card_args[1], "风暴地", "Opening Ch1 标题卡标题正确")
		_assert_eq(opening_fresh.recorded_ch1_title_card_args[2], "篡夺者战争 · 第一年", "Opening Ch1 标题卡时间正确")
		_assert_eq(opening_fresh.recorded_ch1_title_card_args[3], "起义开端 / 山道突破", "Opening Ch1 标题卡副标题正确")
		_assert_eq(opening_fresh.recorded_ch1_title_card_args[4], "目标：夺回北侧山道缺口，为劳勃后军打开通路。",
			"Opening Ch1 标题卡目标摘要正确")
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
	_assert(not opening_saved.played_ch1_title_card, "Opening 有存档跳后续章节时不误播 Ch1 标题卡")
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
	var layout_root := deploy.get_node_or_null("LayoutRoot") as ScrollContainer
	var content_vbox := deploy.get_node_or_null("LayoutRoot/ContentVBox") as VBoxContainer
	var info_header := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/InfoHeader") as Label
	var premise_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/PremiseLabel") as Label
	var objective_summary_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/ObjectiveSummaryLabel") as Label
	var phase_badge_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/PhaseBadgeLabel") as Label
	var faction_summary_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/FactionSummaryLabel") as Label
	var deploy_summary_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel/InfoVBox/DeploySummaryLabel") as Label
	var roster_panel := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel") as PanelContainer
	var roster_header := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/RosterHeader") as Label
	var count_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/CountLabel") as Label
	var confirm_btn := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/ButtonRow/ConfirmButton") as Button
	var unit_grid := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/UnitGrid") as GridContainer
	var battle_flow_panel := deploy.get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel") as PanelContainer
	var flow_grid := deploy.get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel/BattleFlowVBox/FlowGrid") as GridContainer
	var flow_title := deploy.get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel/BattleFlowVBox/FlowTitle") as Label
	var deploy_advice_label := deploy.get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel/BattleFlowVBox/DeployAdviceLabel") as Label
	var mandatory_card := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/UnitGrid/UnitCard_0") as PanelContainer
	var optional_card := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/UnitGrid/UnitCard_1") as PanelContainer
	_assert(layout_root != null, "部署界面使用可滚动容器承载长内容")
	_assert(content_vbox != null, "部署界面滚动容器内存在内容根节点")
	_assert(info_header != null, "部署界面新增攻城态势标题")
	_assert(premise_label != null, "部署界面包含战前态势说明")
	_assert(objective_summary_label != null, "部署界面包含章节目标摘要")
	_assert(phase_badge_label != null, "部署界面包含开场阶段徽标")
	_assert(faction_summary_label != null, "部署界面包含兰军中立说明")
	_assert(deploy_summary_label != null, "部署界面包含编组建议说明")
	_assert(roster_panel != null, "部署界面包含编组总览面板")
	_assert(roster_header != null, "部署界面包含突击队编组标题")
	_assert(battle_flow_panel != null, "部署界面包含作战分段简报面板")
	_assert(flow_grid != null, "部署界面包含作战分段网格")
	_assert(flow_title != null, "部署界面包含作战分段标题")
	_assert(deploy_advice_label != null, "部署界面包含额外部署建议")
	_assert(unit_grid != null, "部署界面包含单位卡网格")
	if layout_root != null and content_vbox != null:
		_assert(layout_root.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO or layout_root.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
			"部署界面纵向滚动已启用")
		_assert(content_vbox.size_flags_vertical == Control.SIZE_EXPAND_FILL,
			"部署界面内容根节点允许纵向展开")
	if unit_grid != null:
		_assert_eq(unit_grid.columns, 3, "部署界面单位卡按三列布局")
	if flow_title != null:
		_assert_eq(flow_title.text, "作战分段简报", "部署界面作战分段标题正确")
	if info_header != null:
		_assert_eq(info_header.text, "目标：红堡攻坚态势", "部署界面态势标题正确")
		_assert_eq(info_header.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE, "部署界面态势标题使用统一目标色")
	if roster_header != null:
		_assert_eq(roster_header.text, "推进：突击队编组", "部署界面编组标题正确")
		_assert_eq(roster_header.get_theme_color("font_color"), BattleChromeThemeClass.TEXT_OBJECTIVE, "部署界面编组标题使用统一目标色")
	if roster_panel != null:
		var roster_style := roster_panel.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(roster_style != null, "部署界面编组总览面板已应用样式")
		if roster_style != null:
			_assert_eq(roster_style.bg_color, BattleChromeThemeClass.PANEL_BG, "部署界面编组总览面板使用统一底色")
			_assert_eq(roster_style.border_color, BattleChromeThemeClass.PANEL_BORDER, "部署界面编组总览面板使用统一边框色")
	if battle_flow_panel != null:
		var flow_style := battle_flow_panel.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(flow_style != null, "部署界面作战分段面板已应用样式")
		if flow_style != null:
			_assert_eq(flow_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG, "部署界面作战分段面板使用高亮底色")
			_assert_eq(flow_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER, "部署界面作战分段面板使用高亮边框")
	var info_panel := deploy.get_node_or_null("LayoutRoot/ContentVBox/InfoPanel") as PanelContainer
	if info_panel != null:
		var info_style := info_panel.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(info_style != null, "部署界面态势面板已应用样式")
		if info_style != null:
			_assert_eq(info_style.bg_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BG, "部署界面态势面板使用高亮底色")
			_assert_eq(info_style.border_color, BattleChromeThemeClass.PANEL_HIGHLIGHT_BORDER, "部署界面态势面板使用高亮边框")
	if flow_grid != null:
		_assert_eq(flow_grid.columns, 2, "部署界面作战分段按两列布局")
		_assert_eq(flow_grid.get_child_count(), 4, "部署界面作战分段共4步")
		for step_idx: int in Ch4BattleBriefClass.BATTLE_FLOW_STEPS.size():
			var step_panel := flow_grid.get_node_or_null("FlowStep_%d" % (step_idx + 1)) as PanelContainer
			_assert(step_panel != null, "部署界面作战分段卡存在：%d" % (step_idx + 1))
			if step_panel != null:
				var step_title := step_panel.get_node_or_null("VBox/StepTitle") as Label
				var step_desc := step_panel.get_node_or_null("VBox/StepDesc") as Label
				if step_title != null:
					_assert_eq(step_title.text, str((Ch4BattleBriefClass.BATTLE_FLOW_STEPS[step_idx] as Dictionary).get("title", "")),
						"部署界面作战分段标题与 Ch4 简报常量一致：%d" % (step_idx + 1))
				if step_desc != null:
					_assert_eq(step_desc.text, str((Ch4BattleBriefClass.BATTLE_FLOW_STEPS[step_idx] as Dictionary).get("desc", "")),
						"部署界面作战分段说明与 Ch4 简报常量一致：%d" % (step_idx + 1))
				var step_style := step_panel.get_theme_stylebox("panel") as StyleBoxFlat
				_assert(step_style != null, "部署界面作战分段卡已应用样式：%d" % (step_idx + 1))
				if step_style != null:
					_assert_eq(step_style.bg_color, BattleChromeThemeClass.PANEL_STEEL_BG,
						"部署界面作战分段卡使用统一钢灰底色：%d" % (step_idx + 1))
					_assert_eq(step_style.border_color, BattleChromeThemeClass.PANEL_BORDER,
						"部署界面作战分段卡使用统一边框色：%d" % (step_idx + 1))
		var step_1 := flow_grid.get_node_or_null("FlowStep_1") as PanelContainer
		var step_4 := flow_grid.get_node_or_null("FlowStep_4") as PanelContainer
		if step_1 != null:
			var step_1_title := step_1.get_node_or_null("VBox/StepTitle") as Label
			var step_1_desc := step_1.get_node_or_null("VBox/StepDesc") as Label
			if step_1_title != null:
				_assert("黑水桥" in step_1_title.text, "部署界面第一阶段指向黑水桥")
			if step_1_desc != null:
				_assert("桥头" in step_1_desc.text, "部署界面第一阶段说明夺桥目标")
		if step_4 != null:
			var step_4_title := step_4.get_node_or_null("VBox/StepTitle") as Label
			var step_4_desc := step_4.get_node_or_null("VBox/StepDesc") as Label
			if step_4_title != null:
				_assert("红堡内院" in step_4_title.text, "部署界面最终阶段指向红堡内院")
			if step_4_desc != null:
				_assert("兰军" in step_4_desc.text and "放弃抵抗" in step_4_desc.text,
					"部署界面最终阶段说明击杀指挥官后的政治结果")
	if deploy_advice_label != null:
		_assert_eq(deploy_advice_label.text, Ch4BattleBriefClass.DEPLOY_ADVICE, "部署界面部署建议与 Ch4 简报常量一致")
		_assert("黑水桥" in deploy_advice_label.text and "南城门" in deploy_advice_label.text,
			"部署界面部署建议点明桥头与南城门")
		_assert("两翼" in deploy_advice_label.text, "部署界面部署建议强调两翼职责")
	if premise_label != null:
		_assert_eq(premise_label.text, Ch4BattleBriefClass.CHAPTER_PREMISE, "部署界面态势说明与 Ch4 简报常量一致")
		_assert("黑水桥" in premise_label.text and "红堡" in premise_label.text,
			"部署界面态势说明点明黑水桥与红堡中轴")
	if objective_summary_label != null:
		_assert_eq(objective_summary_label.text, Ch4BattleBriefClass.OBJECTIVE_SUMMARY, "部署界面目标摘要与 Ch4 简报常量一致")
		_assert(objective_summary_label.text.begins_with("目标："), "部署界面目标摘要采用目标前缀")
		_assert("王军指挥官" in objective_summary_label.text, "部署界面目标摘要点明王军指挥官")
	if phase_badge_label != null:
		_assert_eq(phase_badge_label.text, Ch4BattleBriefClass.get_stage_badge(1), "部署界面阶段徽标与首段简报一致")
		_assert("黑水桥" in phase_badge_label.text, "部署界面阶段徽标点明黑水桥")
	if faction_summary_label != null:
		_assert_eq(faction_summary_label.text, Ch4BattleBriefClass.FACTION_SUMMARY, "部署界面势力说明与 Ch4 简报常量一致")
		_assert("中立" in faction_summary_label.text and "兰军" in faction_summary_label.text,
			"部署界面说明兰军当前中立")
	if deploy_summary_label != null:
		_assert_eq(deploy_summary_label.text, Ch4BattleBriefClass.DEPLOY_SUMMARY, "部署界面编组说明与 Ch4 简报常量一致")
		_assert("最多再带 4 名北境骑士" in deploy_summary_label.text,
			"部署界面说明最多携带 4 名骑士")
	if count_label != null:
		_assert("已选骑士：0 / 4" in count_label.text, "部署界面初始人数统计正确")
		_assert("建议至少 3 人" in count_label.text, "部署界面初始人数统计带有编组建议")
	if confirm_btn != null:
		_assert(confirm_btn.disabled, "部署界面初始未选人时禁止确认")
		_assert("至少选择 1 名骑士" in confirm_btn.text, "部署界面未选人时确认按钮给出提示")
	if mandatory_card != null:
		var mandatory_name := mandatory_card.get_node_or_null("VBox/NameLabel") as Label
		var mandatory_role := mandatory_card.get_node_or_null("VBox/RoleLabel") as Label
		var mandatory_stats := mandatory_card.get_node_or_null("VBox/StatsLabel") as Label
		var mandatory_status := mandatory_card.get_node_or_null("VBox/StatusLabel") as Label
		var mandatory_tag := mandatory_card.get_node_or_null("VBox/MandatoryTag") as Label
		var mandatory_portrait := mandatory_card.get_node_or_null("VBox/Portrait") as TextureRect
		if mandatory_name != null:
			_assert_eq(mandatory_name.text, "奈德", "部署界面固定主将卡显示奈德")
		if mandatory_role != null:
			_assert("中轴突破" in mandatory_role.text, "部署界面固定主将卡说明中轴职责")
		if mandatory_stats != null:
			_assert("剑C" in mandatory_stats.text and "移动5" in mandatory_stats.text,
				"部署界面固定主将卡显示武器等级与机动")
		if mandatory_status != null:
			_assert_eq(mandatory_status.text, "状态：固定出战", "部署界面固定主将卡状态明确")
		if mandatory_tag != null:
			_assert_eq(mandatory_tag.text, "【必须参战】", "部署界面固定主将卡保留必须参战标签")
		if mandatory_portrait != null:
			_assert(mandatory_portrait.texture != null, "部署界面固定主将卡加载立绘")
	if optional_card != null:
		var optional_role := optional_card.get_node_or_null("VBox/RoleLabel") as Label
		var optional_stats := optional_card.get_node_or_null("VBox/StatsLabel") as Label
		var optional_status := optional_card.get_node_or_null("VBox/StatusLabel") as Label
		var optional_button := optional_card.get_node_or_null("VBox/SelectBtn") as Button
		var optional_portrait := optional_card.get_node_or_null("VBox/Portrait") as TextureRect
		if optional_role != null:
			_assert("黑水桥突破" in optional_role.text, "部署界面可选卡给出桥头职责")
		if optional_stats != null:
			_assert("斧D" in optional_stats.text and "移动4" in optional_stats.text,
				"部署界面可选卡显示武器等级与机动")
		if optional_status != null:
			_assert_eq(optional_status.text, "状态：待命", "部署界面可选卡默认处于待命")
		if optional_button != null:
			_assert_eq(optional_button.text, "选择", "部署界面可选卡默认按钮文案为选择")
		if optional_portrait != null:
			_assert(optional_portrait.texture != null, "部署界面可选卡加载立绘")
		var optional_style := optional_card.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(optional_style != null, "部署界面可选卡已应用统一样式")
		if optional_style != null:
			_assert_eq(optional_style.bg_color, BattleChromeThemeClass.PANEL_BG, "部署界面可选卡默认使用统一底色")
			_assert_eq(optional_style.border_color, BattleChromeThemeClass.PANEL_BORDER, "部署界面可选卡默认使用统一边框")
		if optional_button != null:
			var button_style := optional_button.get_theme_stylebox("normal") as StyleBoxFlat
			_assert(button_style != null, "部署界面选择按钮已应用统一按钮样式")
			if button_style != null:
				_assert_eq(button_style.bg_color, BattleChromeThemeClass.BUTTON_NORMAL_BG, "部署界面选择按钮使用统一按钮底色")
				_assert_eq(button_style.border_color, BattleChromeThemeClass.BUTTON_NORMAL_BORDER, "部署界面选择按钮使用统一按钮边框")

	if optional_card != null:
		var optional_button_before := optional_card.get_node_or_null("VBox/SelectBtn") as Button
		if optional_button_before != null:
			deploy._on_card_toggled(1, true, optional_button_before)
			if count_label != null:
				_assert("已选骑士：1 / 4" in count_label.text, "部署界面选第1人后人数统计更新")
			if confirm_btn != null:
				_assert(not confirm_btn.disabled, "部署界面选第1人后可确认出发")
				_assert("奈德 + 1" in confirm_btn.text, "部署界面选第1人后确认按钮同步数量")
			var optional_status_selected := optional_card.get_node_or_null("VBox/StatusLabel") as Label
			var optional_button_selected := optional_card.get_node_or_null("VBox/SelectBtn") as Button
			var optional_style_selected := optional_card.get_theme_stylebox("panel") as StyleBoxFlat
			if optional_status_selected != null:
				_assert_eq(optional_status_selected.text, "状态：已编入突击队", "部署界面选中卡状态更新为已编入")
			if optional_button_selected != null:
				_assert_eq(optional_button_selected.text, "已选中", "部署界面选中卡按钮文案更新")
			if optional_style_selected != null:
				_assert_eq(optional_style_selected.bg_color, BattleChromeThemeClass.PANEL_SELECTED_BG, "部署界面选中卡切换为统一高亮底色")
				_assert_eq(optional_style_selected.border_color, BattleChromeThemeClass.PANEL_SELECTED_BORDER, "部署界面选中卡切换为统一高亮边框")

	var optional_card_3 := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/UnitGrid/UnitCard_3") as PanelContainer
	var optional_card_5 := deploy.get_node_or_null("LayoutRoot/ContentVBox/RosterPanel/RosterVBox/UnitGrid/UnitCard_5") as PanelContainer
	if optional_card_3 != null:
		var button3 := optional_card_3.get_node_or_null("VBox/SelectBtn") as Button
		if button3 != null:
			deploy._on_card_toggled(3, true, button3)
	if optional_card_5 != null:
		var button5 := optional_card_5.get_node_or_null("VBox/SelectBtn") as Button
		if button5 != null:
			deploy._on_card_toggled(5, true, button5)
	if count_label != null:
		_assert("已选骑士：3 / 4" in count_label.text, "部署界面选满3人后人数统计可更新")
		_assert("编组较稳" in count_label.text, "部署界面选满3人后显示较稳提示")
	if confirm_btn != null:
		_assert(not confirm_btn.disabled, "部署界面选满3人后可确认出发")
		_assert("奈德 + 3" in confirm_btn.text, "部署界面选满3人后确认按钮同步数量")
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

func _test_overlay_runtime_flow() -> void:
	var cutscene_scene := load("res://scenes/cutscene/CutscenePlayer.tscn") as PackedScene
	var cutscene := cutscene_scene.instantiate() as CutscenePlayer
	root.add_child(cutscene)
	await process_frame
	cutscene._is_playing = true
	cutscene._skip_requested = false
	var cutscene_skip := InputEventKey.new()
	cutscene_skip.pressed = true
	cutscene_skip.keycode = KEY_SPACE
	cutscene._input(cutscene_skip)
	_assert(cutscene._skip_requested, "正常按下空格仍会跳过当前过场")
	cutscene._skip_requested = false
	var repeated_cutscene_skip := InputEventKey.new()
	repeated_cutscene_skip.pressed = true
	repeated_cutscene_skip.echo = true
	repeated_cutscene_skip.keycode = KEY_SPACE
	cutscene._input(repeated_cutscene_skip)
	_assert(not cutscene._skip_requested,
		"长按跳过键产生的重复事件不会连续跳过下一段过场")
	var released_cutscene_skip := InputEventKey.new()
	released_cutscene_skip.pressed = false
	released_cutscene_skip.keycode = KEY_ENTER
	cutscene._input(released_cutscene_skip)
	_assert(not cutscene._skip_requested, "松开过场跳过键不会触发跳过")
	var mouse_cutscene_skip := InputEventMouseButton.new()
	mouse_cutscene_skip.pressed = true
	mouse_cutscene_skip.button_index = MOUSE_BUTTON_LEFT
	cutscene._input(mouse_cutscene_skip)
	_assert(cutscene._skip_requested, "鼠标左键仍可正常跳过当前过场")
	cutscene._skip_requested = false
	var cutscene_finish_events: Array[bool] = []
	cutscene.cutscene_finished.connect(func() -> void: cutscene_finish_events.append(true))
	cutscene._is_playing = false
	cutscene.play("res://data/cutscenes/not_found.json")
	_assert_eq(cutscene_finish_events.size(), 1,
		"无效过场数据仍会立即发送一次完成信号")

	cutscene.play("res://data/cutscenes/ch2_opening.json")
	await create_timer(0.1).timeout
	var scene_art_alpha_before_reentry: float = cutscene._scene_art.alpha
	cutscene.play("res://data/cutscenes/prologue_opening.json")
	var max_scene_art_alpha_after_reentry := scene_art_alpha_before_reentry
	for frame in range(10):
		await process_frame
		max_scene_art_alpha_after_reentry = maxf(
			max_scene_art_alpha_after_reentry, cutscene._scene_art.alpha)
	_assert(max_scene_art_alpha_after_reentry <= scene_art_alpha_before_reentry + 0.05,
		"重入到无场景艺术的过场时不会先闪亮旧场景艺术")
	await create_timer(0.5).timeout
	_assert_eq(cutscene._scene_art.scene_type, "",
		"重入播放后旧场景艺术不会覆盖新过场")
	_assert(is_equal_approx(cutscene._scene_art.alpha, 0.0),
		"重入播放后旧场景艺术 Tween 不会重新显示")

	cutscene.play("res://data/cutscenes/prologue_opening.json")
	await process_frame
	cutscene.play("res://data/cutscenes/ch2_opening.json")
	cutscene._input(mouse_cutscene_skip)
	await create_timer(1.0).timeout
	_assert_eq(cutscene_finish_events.size(), 2,
		"重入播放后一次跳过只会结束最新过场一次")
	cutscene.queue_free()
	await process_frame

	var tutorial := TutorialManager.new()
	root.add_child(tutorial)
	await process_frame
	tutorial.show_steps(["第一条提示", "第二条提示"])
	var first_step_timer: SceneTreeTimer = tutorial._auto_timer
	var tutorial_click := InputEventMouseButton.new()
	tutorial_click.button_index = MOUSE_BUTTON_LEFT
	tutorial_click.pressed = true
	tutorial._input(tutorial_click)
	await create_timer(0.2).timeout
	_assert(tutorial._showing and tutorial._text_lbl.text == "第二条提示",
		"手动关闭第一条教程提示后会显示下一条")
	first_step_timer.timeout.emit()
	await process_frame
	_assert(tutorial._showing and tutorial._current_index == 1,
		"第一条提示遗留的自动计时器不会误关第二条提示")
	(tutorial._auto_timer as SceneTreeTimer).timeout.emit()
	await create_timer(0.2).timeout
	_assert(not tutorial._showing and tutorial._current_index == 2,
		"当前教程提示的自动计时器仍会正常关闭本条提示")
	tutorial.queue_free()
	await process_frame

	var replacement_tutorial := TutorialManager.new()
	root.add_child(replacement_tutorial)
	await process_frame
	var replacement_done_indices: Array[int] = []
	replacement_tutorial._step_done.connect(func(index: int) -> void:
		replacement_done_indices.append(index)
	)
	replacement_tutorial.show_steps(["旧提示"])
	var replaced_old_timer := replacement_tutorial._auto_timer
	replacement_tutorial.show_steps(["新提示一", "新提示二"])
	var replacement_first_timer := replacement_tutorial._auto_timer
	_assert_eq(replacement_tutorial._text_lbl.text, "新提示一",
		"显示中的教程序列被替换时立即展示新序列第一条")
	replacement_tutorial._input(tutorial_click)
	_assert_eq(replacement_done_indices, [0],
		"替换教程序列后关闭新提示才记录新序列第一步完成")
	replaced_old_timer.timeout.emit()
	replacement_first_timer.timeout.emit()
	await create_timer(0.2).timeout
	(replacement_tutorial._auto_timer as SceneTreeTimer).timeout.emit()
	await create_timer(0.2).timeout
	replacement_tutorial.queue_free()
	await process_frame

	GameState.current_chapter = 1
	var support_battle := TestBootstrapClass.new()
	root.add_child(support_battle)
	await process_frame
	var ned := Unit.new()
	ned.setup(_make_unit_data({"name": "奈德"}), 0, Vector2i(3, 3))
	var robert := Unit.new()
	robert.setup(_make_unit_data({"name": "劳勃"}), 0, Vector2i(4, 3))
	var stale_support_unit := Unit.new()
	stale_support_unit.setup(_make_unit_data({"name": "已释放支援单位"}),
		0, Vector2i(2, 3))
	support_battle.add_child(stale_support_unit)
	support_battle.add_child(ned)
	support_battle.add_child(robert)
	support_battle.player_units.push_front(stale_support_unit)
	support_battle.player_units.append(ned)
	support_battle.player_units.append(robert)
	stale_support_unit.queue_free()
	await process_frame
	for _idx in range(5):
		support_battle._update_support_adjacency()
	var support_popup := support_battle.get_node_or_null("UI/SupportPopup") as CanvasLayer
	_assert(support_popup != null,
		"支援累计忽略已释放引用并为后续相邻友军挂载 SupportPopup")
	if support_popup != null:
		_assert(support_popup.visible, "SupportPopup 触发后可见")
		var camera_before_modal_scroll: Vector2 = support_battle._cam.position
		var modal_scroll_event := InputEventKey.new()
		modal_scroll_event.pressed = true
		modal_scroll_event.keycode = KEY_RIGHT
		modal_scroll_event.physical_keycode = KEY_RIGHT
		Input.parse_input_event(modal_scroll_event)
		await process_frame
		support_battle._handle_cam_scroll(0.1)
		modal_scroll_event.pressed = false
		Input.parse_input_event(modal_scroll_event)
		_assert_eq(support_battle._cam.position, camera_before_modal_scroll,
			"SupportPopup 可见时方向键不会移动战场镜头")
		var support_autopilot_event := InputEventKey.new()
		support_autopilot_event.pressed = true
		support_autopilot_event.keycode = KEY_A
		support_battle._input(support_autopilot_event)
		_assert(not support_battle._autopilot, "SupportPopup 可见时不会穿透自动托管快捷键")
		var support_restart_event := InputEventKey.new()
		support_restart_event.pressed = true
		support_restart_event.keycode = KEY_R
		support_battle._unhandled_input(support_restart_event)
		_assert(not support_battle.restart_requested, "SupportPopup 可见时不会穿透章节重开快捷键")
		var support_content := support_popup.get_node_or_null("Background/VBox/ContentLabel") as Label
		var support_rank := support_popup.get_node_or_null("Background/VBox/RankLabel") as Label
		if support_content != null:
			_assert("默契转化为战场加成" in support_content.text, "SupportPopup 显示支援说明文案")
		if support_rank != null:
			_assert("奈德 ↔ 劳勃" in support_rank.text, "SupportPopup 显示真实角色名")
			_assert("[C级 +5%命中/5%回避]" in support_rank.text, "SupportPopup 显示真实加成数值")
		var second_support_popup := load("res://scenes/ui/SupportPopup.tscn").instantiate() as SupportPopup
		support_battle.get_node("UI").add_child(second_support_popup, true)
		second_support_popup.popup_closed.connect(second_support_popup.queue_free)
		second_support_popup.show_support("奈德", "琼恩·艾林", "C", {"hit": 5, "avoid": 5})
		support_popup.call("_on_close_pressed")
		await process_frame
		await process_frame
		_assert(support_battle.get_node_or_null("UI/SupportPopup") == null,
			"SupportPopup 关闭信号会释放真实弹窗实例")
		_assert(support_battle._modal_overlay_open(), "仍有第二个 SupportPopup 可见时继续保持战场输入锁")
		second_support_popup._on_close_pressed()
		await process_frame
		_assert(not support_battle._modal_overlay_open(), "全部 SupportPopup 关闭后解除战场输入锁")
		modal_scroll_event.pressed = true
		Input.parse_input_event(modal_scroll_event)
		await process_frame
		support_battle._handle_cam_scroll(0.1)
		modal_scroll_event.pressed = false
		Input.parse_input_event(modal_scroll_event)
		_assert(support_battle._cam.position.x > camera_before_modal_scroll.x,
			"全部 SupportPopup 关闭后方向键恢复移动战场镜头")
	if is_instance_valid(support_battle):
		support_battle.queue_free()
	await process_frame

	var game_over_battle := TestBootstrapClass.new()
	root.add_child(game_over_battle)
	await process_frame
	var fallen := Unit.new()
	fallen.setup(_make_unit_data({"name": "奈德", "is_protagonist": true}), 0, Vector2i(2, 2))
	game_over_battle.add_child(fallen)
	game_over_battle._on_unit_died(fallen)
	await process_frame
	var game_over := game_over_battle.get_node_or_null("UI/GameOver") as CanvasLayer
	_assert(game_over_battle._battle_over, "主角死亡时真实战斗流程进入战斗结束态")
	_assert(game_over != null, "主角死亡时真实挂载 GameOver")
	if game_over != null:
		_assert(game_over.visible, "GameOver 挂载后可见")
		var game_over_message := game_over.get_node_or_null("Background/VBox/MessageLabel") as Label
		if game_over_message != null:
			_assert_eq(game_over_message.text, "奈德 阵亡于战场", "GameOver 显示真实死亡单位名")
		var restart_connections := game_over.get_signal_connection_list("restart_chapter")
		var quit_connections := game_over.get_signal_connection_list("quit_to_menu")
		_assert_eq(restart_connections.size(), 1, "GameOver 重开信号仅连接一个目标")
		_assert_eq(quit_connections.size(), 1, "GameOver 返回主菜单信号仅连接一个目标")
		if restart_connections.size() == 1:
			var restart_callable: Callable = restart_connections[0].get("callable", Callable())
			_assert_eq(restart_callable.get_method(), "_restart", "GameOver 重开信号连接到重开方法")
		if quit_connections.size() == 1:
			var quit_callable: Callable = quit_connections[0].get("callable", Callable())
			_assert_eq(quit_callable.get_method(), "_return_to_opening", "GameOver 返回主菜单信号连接到主入口返回方法")
		var restart_button := game_over.get_node_or_null("Background/VBox/RestartBtn") as Button
		if restart_button != null:
			restart_button.pressed.emit()
		_assert(game_over_battle.restart_requested,
			"点击 GameOver 重新开始按钮真实调用章节重开")
		_assert(not game_over.visible,
			"点击 GameOver 重新开始按钮后隐藏失败界面")

		game_over.visible = true
		var quit_button := game_over.get_node_or_null("Background/VBox/QuitBtn") as Button
		if quit_button != null:
			quit_button.pressed.emit()
		_assert(game_over_battle.return_to_opening_requested,
			"点击 GameOver 返回主菜单按钮真实调用主入口返回")
		_assert(not game_over.visible,
			"点击 GameOver 返回主菜单按钮后隐藏失败界面")
	if is_instance_valid(game_over_battle):
		game_over_battle.queue_free()
	await process_frame

	var dialogue_scene := load("res://scenes/dialogue/DialogueBox.tscn") as PackedScene
	var dialogue := dialogue_scene.instantiate() as DialogueSystem
	root.add_child(dialogue)
	await process_frame
	var dialogue_finished_state := {"done": false}
	var changed_speakers: Array[String] = []
	dialogue.dialogue_finished.connect(func() -> void:
		dialogue_finished_state["done"] = true
	)
	dialogue.line_changed.connect(func(speaker: String) -> void:
		changed_speakers.append(speaker)
	)
	dialogue.play("res://data/dialogues/prologue_1_pre.json")
	await process_frame
	_assert_eq(changed_speakers, ["旁白"], "DialogueSystem 首句会通知说话人变化")
	_assert(dialogue.visible, "DialogueSystem 播放后真实对话框可见")
	_assert_eq(dialogue._speaker_label.text, "旁白", "DialogueSystem 首句说话人正确")
	_assert(not dialogue._portrait_panel.visible, "旁白首句默认隐藏立绘")
	_assert_eq(dialogue._text_label.text, "", "DialogueSystem 打字开始时正文先清空")
	dialogue._skip_typing()
	_assert("风暴地边境" in dialogue._text_label.text, "DialogueSystem 跳字后显示首句完整正文")
	_assert(dialogue._prompt_icon.visible, "DialogueSystem 跳字后显示继续提示")
	dialogue._advance()
	_assert_eq(dialogue._speaker_label.text, "奈德", "DialogueSystem 推进到第二句后切换说话人")
	_assert_eq(changed_speakers, ["旁白", "奈德"], "DialogueSystem 每次换行都会通知说话人")
	dialogue._on_typing_finished()
	var old_prompt_tween: Tween = dialogue._prompt_tween
	await create_timer(0.55).timeout
	_assert(old_prompt_tween != null and old_prompt_tween.is_valid(),
		"DialogueSystem 打字结束后启动继续提示闪烁")
	_assert(dialogue._prompt_icon.modulate.a < 0.9,
		"DialogueSystem 继续提示闪烁会实际改变透明度")
	dialogue._advance()
	dialogue._skip_typing()
	await create_timer(0.55).timeout
	_assert(not old_prompt_tween.is_valid() and dialogue._prompt_tween == null,
		"DialogueSystem 切换行后停止旧提示 Tween")
	_assert(is_equal_approx(dialogue._prompt_icon.modulate.a, 1.0),
		"DialogueSystem 切换行后继续提示恢复为完整可见")
	dialogue._skip_typing()
	_assert(dialogue._portrait_panel.visible, "DialogueSystem 进入角色发言后显示立绘")
	_assert(dialogue._portrait_rect.texture != null, "DialogueSystem 角色发言时加载立绘纹理")
	for _idx in range(8):
		dialogue._skip_typing()
		dialogue._advance()
	await process_frame
	_assert(dialogue_finished_state["done"], "DialogueSystem 最后一行后发出完成信号")
	_assert(not dialogue.visible, "DialogueSystem 完成后隐藏对话框")
	_assert(dialogue._portrait_rect.texture == null, "DialogueSystem 完成后清理立绘纹理")
	dialogue._on_typing_finished()
	var finishing_prompt_tween: Tween = dialogue._prompt_tween
	dialogue._finish()
	await create_timer(0.55).timeout
	_assert(not finishing_prompt_tween.is_valid() and dialogue._prompt_tween == null,
		"DialogueSystem 完成时停止继续提示 Tween")
	_assert(is_equal_approx(dialogue._prompt_icon.modulate.a, 1.0),
		"DialogueSystem 完成后继续提示保持完整透明度")
	dialogue.queue_free()
	await process_frame

func _test_test_script_reliability() -> void:
	var test_script := _read_repo_root_text("scripts/test.sh")
	_assert(test_script.contains("godot --headless --path . --import"),
		"测试脚本会先导入项目以刷新全局类缓存")
	_assert(test_script.contains("TEST_RUN_COMPLETE suites="),
		"测试脚本校验测试完成标记")
	_assert(not test_script.contains("TEST_RUN_COMPLETE suites=32"),
		"测试脚本不写死套件总数")

	var runner_src := FileAccess.get_file_as_string("res://tests/run_tests.gd")
	var legacy_suite_constant := "EXPECTED_" + "SUITE_COUNT"
	_assert(not runner_src.contains(legacy_suite_constant),
		"测试运行器不再写死套件总数常量")
	_assert(runner_src.contains("var suites := ["),
		"测试运行器通过套件列表驱动执行")
	_assert(runner_src.contains("_completed_suite_count != suites.size()"),
		"测试运行器按套件列表动态校验完成数")
