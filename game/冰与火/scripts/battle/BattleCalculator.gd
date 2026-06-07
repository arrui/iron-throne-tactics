# BattleCalculator.gd
class_name BattleCalculator

const WEAPON_BASE: Dictionary = {
	# E级
	"sword_E": {"atk": 5,  "hit": 75},
	"axe_E":   {"atk": 8,  "hit": 65},
	"lance_E": {"atk": 6,  "hit": 80},
	# C级（英雄级别）
	"sword_C": {"atk": 9,  "hit": 85},
	"axe_C":   {"atk": 12, "hit": 75},
	"lance_C": {"atk": 10, "hit": 90},
}

static func calc_attack(attacker: UnitData, weapon_key: String) -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	return attacker.pow + int(weapon["atk"])

static func calc_hit(attacker: UnitData, defender: UnitData,
		weapon_key: String, terrain_avoid: int = 0) -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	var hit: int   = attacker.skl * 2 + attacker.lck / 2 + int(weapon["hit"])
	var avoid: int = defender.spd * 2 + defender.lck / 2 + terrain_avoid
	return clampi(hit - avoid, 1, 99)

static func calc_crit(attacker: UnitData, defender: UnitData) -> int:
	return clampi(attacker.skl / 2 - defender.lck, 0, 99)

static func calc_damage(attacker: UnitData, defender: UnitData,
		weapon_key: String) -> int:
	return maxi(calc_attack(attacker, weapon_key) - defender.def, 1)

static func can_double(attacker: UnitData, defender: UnitData) -> bool:
	return attacker.spd - defender.spd >= 5

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
