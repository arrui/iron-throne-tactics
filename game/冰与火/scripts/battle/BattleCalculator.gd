# BattleCalculator.gd — 战斗公式（含武器三角、武器耐久回退）
class_name BattleCalculator

const WEAPON_BASE: Dictionary = {
	# E级
	"sword_E": {"atk": 5,  "hit": 75},
	"axe_E":   {"atk": 8,  "hit": 65},
	"lance_E": {"atk": 6,  "hit": 80},
	# D级
	"sword_D": {"atk": 7,  "hit": 80},
	"axe_D":   {"atk": 10, "hit": 70},
	"lance_D": {"atk": 8,  "hit": 85},
	# C级
	"sword_C": {"atk": 9,  "hit": 85},
	"axe_C":   {"atk": 12, "hit": 75},
	"lance_C": {"atk": 10, "hit": 90},
	# B级
	"sword_B": {"atk": 12, "hit": 90},
	"axe_B":   {"atk": 15, "hit": 80},
	"lance_B": {"atk": 13, "hit": 95},
	# A级（传奇）
	"sword_A": {"atk": 16, "hit": 95},
	"lance_A": {"atk": 17, "hit": 100},
	# S级（传说）
	"sword_S": {"atk": 20, "hit": 95},
	# 徒手（武器破损时的后备）
	"fist":    {"atk": 1,  "hit": 50},
}

# ── 武器三角（剑 > 斧 > 枪 > 剑）────────────────────────
# 返回攻击方ATK修正（+1 / 0 / -1）
static func weapon_triangle_atk(atk_key: String, def_key: String) -> int:
	var atk_t := _weapon_type(atk_key)
	var def_t := _weapon_type(def_key)
	if (atk_t == "sword" and def_t == "axe")  or \
	   (atk_t == "axe"   and def_t == "lance") or \
	   (atk_t == "lance" and def_t == "sword"):
		return 1
	if (atk_t == "axe"   and def_t == "sword")  or \
	   (atk_t == "lance" and def_t == "axe")  or \
	   (atk_t == "sword" and def_t == "lance"):
		return -1
	return 0

# 返回命中修正（+5 / 0 / -5）
static func weapon_triangle_hit(atk_key: String, def_key: String) -> int:
	return weapon_triangle_atk(atk_key, def_key) * 5

static func _weapon_type(key: String) -> String:
	var parts := key.split("_")
	return parts[0] if parts.size() > 0 else ""

# ── 核心公式 ──────────────────────────────────────────────
static func calc_attack(attacker: UnitData, weapon_key: String) -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	return attacker.pow + int(weapon["atk"])

static func calc_hit(attacker: UnitData, defender: UnitData,
		weapon_key: String, terrain_avoid: int = 0, def_weapon_key: String = "") -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	var hit:   int = attacker.skl * 2 + attacker.lck / 2 + int(weapon["hit"])
	var avoid: int = defender.spd * 2 + defender.lck / 2 + terrain_avoid
	var tri:   int = weapon_triangle_hit(weapon_key, def_weapon_key) if def_weapon_key != "" else 0
	return clampi(hit - avoid + tri, 1, 99)

static func calc_crit(attacker: UnitData, defender: UnitData) -> int:
	return clampi(attacker.skl / 2 - defender.lck, 0, 99)

static func calc_damage(attacker: UnitData, defender: UnitData,
		weapon_key: String, def_weapon_key: String = "") -> int:
	var tri: int = weapon_triangle_atk(weapon_key, def_weapon_key) if def_weapon_key != "" else 0
	return maxi(calc_attack(attacker, weapon_key) + tri - defender.def, 1)

static func can_double(attacker: UnitData, defender: UnitData) -> bool:
	return attacker.spd - defender.spd >= 5

# ── 完整预测（含武器三角）────────────────────────────────
static func predict(attacker: UnitData, defender: UnitData,
		atk_weapon: String, def_weapon: String,
		terrain_avoid: int = 0) -> Dictionary:
	# 武器破损时使用 "fist"
	var atk_key := "fist" if atk_weapon == "" else atk_weapon
	var def_key := "fist" if def_weapon == "" else def_weapon

	return {
		"atk_damage":  calc_damage(attacker, defender, atk_key, def_key),
		"atk_hit":     calc_hit(attacker, defender, atk_key, terrain_avoid, def_key),
		"atk_crit":    calc_crit(attacker, defender),
		"atk_double":  can_double(attacker, defender),
		"def_damage":  calc_damage(defender, attacker, def_key, atk_key),
		"def_hit":     calc_hit(defender, attacker, def_key, 0, atk_key),
		"def_crit":    calc_crit(defender, attacker),
		"def_double":  can_double(defender, attacker),
	}
