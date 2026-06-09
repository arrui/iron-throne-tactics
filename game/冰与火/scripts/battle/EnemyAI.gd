# EnemyAI.gd
# 敌方AI：普通单位追击，守卫型Boss（is_boss+guard_pos）只在守卫范围内行动
class_name EnemyAI

static func decide(enemy: Unit, player_units: Array,
		walkable: Array) -> Dictionary:

	# ── 守卫型Boss：只在守卫范围内移动和攻击 ──────────────
	if enemy.data.get("is_boss", false) and enemy.data.has("guard_pos_x"):
		return _decide_guard(enemy, player_units, walkable)

	# ── 普通单位：向最近玩家移动并攻击 ────────────────────
	return _decide_chase(enemy, player_units, walkable)

# 守卫AI：守在guard_pos附近guard_range格内
static func _decide_guard(enemy: Unit, player_units: Array,
		walkable: Array) -> Dictionary:
	var guard_pos := Vector2i(
		int(enemy.data.get("guard_pos_x", enemy.grid_pos.x)),
		int(enemy.data.get("guard_pos_y", enemy.grid_pos.y))
	)
	var guard_range: int = int(enemy.data.get("guard_range", 3))

	# 找守卫范围内最近的玩家
	var nearest_in_range: Unit = null
	var min_dist := 999
	for p: Unit in player_units:
		if p.is_dead(): continue
		var d := _manhattan(guard_pos, p.grid_pos)
		if d <= guard_range + 1:  # 稍微宽松，允许追到边缘外一格
			var pd := _manhattan(enemy.grid_pos, p.grid_pos)
			if pd < min_dist:
				min_dist = pd
				nearest_in_range = p

	# 范围内没有玩家：回到守卫位置附近（如果已经偏离）
	if nearest_in_range == null:
		# 如果已经在守卫位附近则原地待命
		if _manhattan(enemy.grid_pos, guard_pos) <= 1:
			return {"move_to": enemy.grid_pos, "attack": null}
		# 否则走回去
		var best_pos := enemy.grid_pos
		var best_dist := _manhattan(enemy.grid_pos, guard_pos)
		for pos: Vector2i in walkable:
			# 回守位时也不能离开guard_range范围太远
			if _manhattan(pos, guard_pos) > guard_range:
				continue
			var d := _manhattan(pos, guard_pos)
			if d < best_dist:
				best_dist = d
				best_pos = pos
		return {"move_to": best_pos, "attack": null}

	# 范围内有玩家：移向玩家，但不离开守卫范围
	var best_pos := enemy.grid_pos
	var best_dist := _manhattan(enemy.grid_pos, nearest_in_range.grid_pos)

	for pos: Vector2i in walkable:
		# 守卫不能离开守卫范围
		if _manhattan(pos, guard_pos) > guard_range:
			continue
		var d := _manhattan(pos, nearest_in_range.grid_pos)
		if d < best_dist:
			best_dist = d
			best_pos = pos

	var can_attack := (_manhattan(best_pos, nearest_in_range.grid_pos) == 1)
	return {
		"move_to": best_pos,
		"attack":  nearest_in_range if can_attack else null,
	}

# 普通追击AI
static func _decide_chase(enemy: Unit, player_units: Array,
		walkable: Array) -> Dictionary:
	var target: Unit = _find_nearest(enemy, player_units)
	if target == null:
		return {"move_to": enemy.grid_pos, "attack": null}

	var best_pos := enemy.grid_pos
	var best_dist := _manhattan(enemy.grid_pos, target.grid_pos)

	for pos: Vector2i in walkable:
		var dist := _manhattan(pos, target.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best_pos  = pos

	var can_attack := (_manhattan(best_pos, target.grid_pos) == 1)
	return {
		"move_to": best_pos,
		"attack":  target if can_attack else null,
	}

static func _find_nearest(enemy: Unit, players: Array) -> Unit:
	var nearest: Unit = null
	var min_dist := 999
	for p: Unit in players:
		if p.is_dead(): continue
		var d := _manhattan(enemy.grid_pos, p.grid_pos)
		if d < min_dist:
			min_dist = d
			nearest  = p
	return nearest

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
