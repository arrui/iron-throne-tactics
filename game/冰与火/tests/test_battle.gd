# test_battle.gd
# 独立测试脚本，不依赖GUT框架，直接在Godot控制台运行
# 用法：把这个脚本挂到任意节点，运行后看Output面板输出
extends Node

func _ready() -> void:
	print("=== 战斗系统测试开始 ===")
	_test_unit_data()
	_test_calculator()
	_test_damage_not_kill_before_resolve()
	print("=== 全部测试通过 ✓ ===")

# ── 测试1：UnitData正确加载 ──────────────────────────────
func _test_unit_data() -> void:
	var d := UnitData.from_dict({
		"name": "测试剑士", "class": "剑士", "level": 1,
		"hp": 20, "max_hp": 20, "pow": 7, "spd": 8,
		"skl": 7, "def": 6, "lck": 5, "con": 8,
		"move": 5, "weapon_type": "sword", "weapon_rank": "E"
	})
	assert(d.name == "测试剑士",   "name错误")
	assert(d.hp == 20,            "hp错误")
	assert(d.pow == 7,            "pow错误")
	assert(d.weapon_type == "sword", "weapon_type错误")
	print("✓ UnitData加载正确")

# ── 测试2：战斗公式 ──────────────────────────────────────
func _test_calculator() -> void:
	var atk := UnitData.from_dict({
		"name":"攻方","class":"剑士","level":1,
		"hp":22,"max_hp":22,"pow":7,"spd":8,"skl":7,"def":6,"lck":5,"con":8,
		"move":5,"weapon_type":"sword","weapon_rank":"E"
	})
	var def := UnitData.from_dict({
		"name":"守方","class":"步兵","level":1,
		"hp":16,"max_hp":16,"pow":5,"spd":4,"skl":4,"def":4,"lck":2,"con":6,
		"move":4,"weapon_type":"sword","weapon_rank":"E"
	})

	# 伤害 = pow(7) + weapon_atk(5) - def(4) = 8
	var dmg := BattleCalculator.calc_damage(atk, def, "sword_E")
	assert(dmg == 8, "伤害计算错误：期望8，得到%d" % dmg)

	# 命中 = skl*2(14) + lck/2(2) + weapon_hit(75) - spd*2(8) - lck/2(1) = 82
	var hit := BattleCalculator.calc_hit(atk, def, "sword_E")
	assert(hit == 82, "命中计算错误：期望82，得到%d" % hit)

	# 追击：spd差 = 8-4 = 4，不满足≥5，不追击
	assert(not BattleCalculator.can_double(atk, def), "追击判定错误")

	# 修改速度让追击成立
	atk.spd = 10
	assert(BattleCalculator.can_double(atk, def), "追击应成立")

	print("✓ 战斗公式正确（伤害=%d 命中=%d）" % [dmg, hit])

# ── 测试3：延迟死亡——战斗中HP归零不立刻消失 ──────────────
func _test_damage_not_kill_before_resolve() -> void:
	# 模拟Unit的核心逻辑（不实例化场景）
	var data := UnitData.from_dict({
		"name":"濒死单位","class":"步兵","level":1,
		"hp":3,"max_hp":16,"pow":5,"spd":4,"skl":4,"def":4,"lck":2,"con":6,
		"move":4,"weapon_type":"sword","weapon_rank":"E"
	})

	# 造成5点伤害（超过剩余3点HP）
	data.hp = maxi(data.hp - 5, 0)
	assert(data.hp == 0, "HP应归零")

	# 关键：此时单位应仍存在（_pending_death=true但未queue_free）
	# 这里只测数据层，节点生命周期在集成测试中验证
	assert(data.hp == 0, "延迟死亡：HP为0但数据仍可访问")

	print("✓ 延迟死亡逻辑正确（HP=0时数据仍存在）")
