# AutopilotAI.gd — 玩家侧自动托管 AI
# 优先级：主角自救 > 攻击残血敌人 > 向最近敌人推进
class_name AutopilotAI

# HP 低于此比例时主角优先使用治疗道具
const HEAL_THRESHOLD := 0.50

# 为指定玩家单位做出行动决策
# 返回 {"move_to": Vector2i, "attack": Unit or null, "use_item": int(-1=不用)}
static func decide(
		unit: Unit,
		enemy_units: Array,
		walkable: Array) -> Dictionary:

	# ── 优先级 0：主角低血量时原地自救 ──────────────────────
	if unit.data.is_protagonist:
		var hp_ratio := float(unit.data.hp) / float(maxi(unit.data.max_hp, 1))
		if hp_ratio <= HEAL_THRESHOLD:
			var heal_idx := _find_heal_item(unit)
			if heal_idx >= 0:
				return {"move_to": unit.grid_pos, "attack": null, "use_item": heal_idx}

	# ── 优先级 1：攻击最低血量敌人 ──────────────────────────
	var enemies: Array = enemy_units.filter(
		func(e: Unit) -> bool: return is_instance_valid(e) and not e.is_dead())
	enemies.sort_custom(
		func(a: Unit, b: Unit) -> bool: return a.data.hp < b.data.hp)

	if enemies.is_empty():
		return {"move_to": unit.grid_pos, "attack": null, "use_item": -1}

	var best_pos   := unit.grid_pos
	var best_enemy: Unit = null
	var best_score := 999

	for pos: Vector2i in walkable:
		for enemy: Unit in enemies:
			if _manhattan(pos, enemy.grid_pos) == 1:
				if enemy.data.hp < best_score:
					best_score = enemy.data.hp
					best_pos   = pos
					best_enemy = enemy

	if best_enemy != null:
		return {"move_to": best_pos, "attack": best_enemy, "use_item": -1}

	# ── 优先级 2：向最近敌人推进 ─────────────────────────────
	var nearest: Unit = _find_nearest(unit, enemies)
	if nearest == null:
		return {"move_to": unit.grid_pos, "attack": null, "use_item": -1}

	var move_to  := unit.grid_pos
	var min_dist := _manhattan(unit.grid_pos, nearest.grid_pos)
	for pos: Vector2i in walkable:
		var d := _manhattan(pos, nearest.grid_pos)
		if d < min_dist:
			min_dist = d
			move_to  = pos

	return {"move_to": move_to, "attack": null, "use_item": -1}

# ── 找第一个可用的治疗道具索引（-1=无）────────────────────
static func _find_heal_item(unit: Unit) -> int:
	for i: int in unit.data.items.size():
		var item: Dictionary = unit.data.items[i] as Dictionary
		if item.get("type", "") == "heal" and int(item.get("uses", 0)) > 0:
			return i
	return -1

static func _find_nearest(unit: Unit, enemies: Array) -> Unit:
	var nearest: Unit = null
	var min_d := 999
	for e: Unit in enemies:
		var d := _manhattan(unit.grid_pos, e.grid_pos)
		if d < min_d:
			min_d   = d
			nearest = e
	return nearest

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
