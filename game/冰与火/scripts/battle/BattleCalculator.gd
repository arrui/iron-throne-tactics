# BattleCalculator.gd
# 战斗数值计算，纯函数，无副作用，方便单元测试
class_name BattleCalculator

# 武器基础数据（原型阶段硬编码，后续移至JSON）
const WEAPON_BASE := {
	"sword_E": {"atk": 5, "hit": 75},
	"axe_E":   {"atk": 8, "hit": 65},
	"lance_E": {"atk": 6, "hit": 80},
}

# 计算攻击力
static func calc_attack(attacker: UnitData, weapon_key: String) -> int:
	var weapon := WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	return attacker.pow + weapon["atk"]

# 计算命中率（0~99）
static func calc_hit(attacker: UnitData, defender: UnitData,
		weapon_key: String, terrain_avoid: int = 0) -> int:
	var weapon := WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	var hit := attacker.skl * 2 + attacker.lck / 2 + weapon["hit"]
	var avoid := defender.spd * 2 + defender.lck / 2 + terrain_avoid
	return clampi(hit - avoid, 1, 99)

# 计算暴击率（0~99）
static func calc_crit(attacker: UnitData, defender: UnitData) -> int:
	var crit := attacker.skl / 2 - defender.lck
	return clampi(crit, 0, 99)

# 计算实际伤害（防御减免后）
static func calc_damage(attacker: UnitData, defender: UnitData,
		weapon_key: String) -> int:
	var raw := calc_attack(attacker, weapon_key) - defender.def
	return maxi(raw, 1)  # 最低1点伤害

# 判断是否追击（身法差≥5）
static func can_double(attacker: UnitData, defender: UnitData) -> bool:
	return attacker.spd - defender.spd >= 5

# 生成战斗预测数据（显示在预测弹窗中）
static func predict(attacker: UnitData, defender: UnitData,
		atk_weapon: String, def_weapon: String,
		terrain_avoid: int = 0) -> Dictionary:
	return {
		"atk_damage":  calc_damage(attacker, defender, atk_weapon),
		"atk_hit":     calc_hit(attacker, defender, atk_weapon, terrain_avoid),
		"atk_crit":    calc_crit(attacker, defender),
		"atk_double":  can_double(attacker, defender),
		"def_damage":  calc_damage(defender, attacker, def_weapon),
		"def_hit":     calc_hit(defender, attacker, def_weapon, 0),
		"def_crit":    calc_crit(defender, attacker),
		"def_double":  can_double(defender, attacker),
	}
