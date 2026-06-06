# EnemyAI.gd
# 原型阶段最简AI：向最近的玩家单位移动并攻击
class_name EnemyAI

# 为单个敌方单位决策，返回行动指令
# 返回格式：{"move_to": Vector2i, "attack": Unit or null}
static func decide(enemy: Unit, player_units: Array,
		walkable: Array) -> Dictionary:
	# 找到最近的玩家单位
	var target: Unit = _find_nearest(enemy, player_units)
	if target == null:
		return {"move_to": enemy.grid_pos, "attack": null}

	# 找到攻击范围内且最接近目标的可移动格
	var best_pos := enemy.grid_pos
	var best_dist := _manhattan(enemy.grid_pos, target.grid_pos)

	for pos in walkable:
		# 该格必须没有其他单位占用
		var dist := _manhattan(pos, target.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best_pos  = pos

	# 判断移动后是否在攻击范围（近战=相邻1格）
	var can_attack := (_manhattan(best_pos, target.grid_pos) == 1)

	return {
		"move_to": best_pos,
		"attack":  target if can_attack else null,
	}

static func _find_nearest(enemy: Unit, players: Array) -> Unit:
	var nearest: Unit = null
	var min_dist := 999
	for p in players:
		var d := _manhattan(enemy.grid_pos, p.grid_pos)
		if d < min_dist:
			min_dist = d
			nearest  = p
	return nearest

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
