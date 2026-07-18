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

static func _trait_rule(attacker: UnitData, defender: UnitData, initiating: bool) -> Dictionary:
	var bonus := {
		"damage": 0,
		"hit": 0,
		"crit": 0,
		"label": "",
	}
	if attacker == null or defender == null:
		return bonus
	match attacker.trait_key:
		"armor_breaker":
			if defender.armor_type == "heavy":
				bonus["damage"] = 2
				bonus["label"] = "破甲触发：对重甲伤害+2"
		"charge":
			if initiating:
				bonus["damage"] = 2
				bonus["label"] = "冲锋触发：先手伤害+2"
		"first_strike":
			if initiating:
				bonus["hit"] = 8
				bonus["crit"] = 6
				bonus["label"] = "先手触发：命中+8 / 暴击+6"
		"dawn_blade":
			if initiating:
				bonus["crit"] = 12
				bonus["label"] = "黎明之刃：先手暴击+12"
		"harrier":
			if defender.armor_type == "light":
				bonus["hit"] = 10
				bonus["label"] = "游猎侦袭：对轻甲命中+10"
		"battle_command":
			if not initiating:
				bonus["hit"] = 8
				bonus["label"] = "督战触发：反击命中+8"
	return bonus

static func _guard_rule(defender: UnitData, initiating: bool) -> Dictionary:
	var bonus := {
		"damage_reduction": 0,
		"label": "",
	}
	if defender == null:
		return bonus
	match defender.trait_key:
		"spear_wall":
			if initiating:
				bonus["damage_reduction"] = 2
				bonus["label"] = "枪墙触发：先手承伤-2"
		"bulwark":
			if initiating:
				bonus["damage_reduction"] = 3
				bonus["label"] = "坚垒触发：先手承伤-3"
	return bonus

static func _combine_effect_labels(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> String:
	var labels: Array[String] = []
	var atk_label := str(attacker_bonus.get("label", ""))
	var def_label := str(defender_bonus.get("label", ""))
	if atk_label != "":
		labels.append(atk_label)
	if def_label != "":
		labels.append(def_label)
	return " / ".join(labels)

static func get_trait_effect(attacker: UnitData, defender: UnitData, initiating: bool = true) -> Dictionary:
	var attacker_bonus := _trait_rule(attacker, defender, initiating)
	var defender_bonus := _guard_rule(defender, initiating)
	return {
		"damage_bonus": int(attacker_bonus.get("damage", 0)),
		"hit_bonus": int(attacker_bonus.get("hit", 0)),
		"crit_bonus": int(attacker_bonus.get("crit", 0)),
		"damage_reduction": int(defender_bonus.get("damage_reduction", 0)),
		"summary": _combine_effect_labels(attacker_bonus, defender_bonus),
	}

# ── 核心公式 ──────────────────────────────────────────────
static func calc_attack(attacker: UnitData, weapon_key: String, defender: UnitData = null,
		initiating: bool = true) -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	var trait_effect := get_trait_effect(attacker, defender, initiating)
	return attacker.pow + int(weapon["atk"]) + int(trait_effect.get("damage_bonus", 0))

static func calc_hit(attacker: UnitData, defender: UnitData,
		weapon_key: String, terrain_avoid: int = 0, def_weapon_key: String = "",
		initiating: bool = true) -> int:
	var weapon: Dictionary = WEAPON_BASE.get(weapon_key, {"atk": 5, "hit": 75})
	var trait_effect := get_trait_effect(attacker, defender, initiating)
	var hit:   int = attacker.skl * 2 + attacker.lck / 2 + int(weapon["hit"])
	var avoid: int = defender.spd * 2 + defender.lck / 2 + terrain_avoid
	var tri:   int = weapon_triangle_hit(weapon_key, def_weapon_key) if def_weapon_key != "" else 0
	return clampi(hit - avoid + tri + int(trait_effect.get("hit_bonus", 0)), 1, 99)

static func calc_crit(attacker: UnitData, defender: UnitData, initiating: bool = true) -> int:
	var trait_effect := get_trait_effect(attacker, defender, initiating)
	return clampi(attacker.skl / 2 - defender.lck + int(trait_effect.get("crit_bonus", 0)), 0, 99)

static func calc_damage(attacker: UnitData, defender: UnitData,
		weapon_key: String, def_weapon_key: String = "", initiating: bool = true) -> int:
	var tri: int = weapon_triangle_atk(weapon_key, def_weapon_key) if def_weapon_key != "" else 0
	var trait_effect := get_trait_effect(attacker, defender, initiating)
	var reduction := int(trait_effect.get("damage_reduction", 0))
	return maxi(calc_attack(attacker, weapon_key, defender, initiating) + tri - defender.def - reduction, 1)

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
		"atk_damage":  calc_damage(attacker, defender, atk_key, def_key, true),
		"atk_hit":     calc_hit(attacker, defender, atk_key, terrain_avoid, def_key, true),
		"atk_crit":    calc_crit(attacker, defender, true),
		"atk_double":  can_double(attacker, defender),
		"def_damage":  calc_damage(defender, attacker, def_key, atk_key, false),
		"def_hit":     calc_hit(defender, attacker, def_key, 0, atk_key, false),
		"def_crit":    calc_crit(defender, attacker, false),
		"def_double":  can_double(defender, attacker),
		"atk_trait_summary": str(get_trait_effect(attacker, defender, true).get("summary", "")),
		"def_trait_summary": str(get_trait_effect(defender, attacker, false).get("summary", "")),
	}
