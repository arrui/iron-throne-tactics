# FogSystem.gd — 战争迷雾（方案 C：地形全知、敌军显隐、单向）
# 由 BattleMap 持有，fog_enabled=true 时启用。
# 纯逻辑（extends RefCounted），不依赖节点树。
#
# 接口为坐标 + 视野驱动：
#   observer = {"pos": Vector2i, "vision": int}
# 调用方（BattleMap）负责从 unit.grid_pos 与 unit.data.move + 2 提取上述字段，
# 这样 FogSystem 与 Unit 节点解耦，可独立测试。
class_name FogSystem
extends RefCounted

var _visible_tiles: Dictionary = {}    # 本回合可见 Vector2i -> true
var _explored_tiles: Dictionary = {}   # 累计已探索
var _map_size: Vector2i = Vector2i.ZERO


func reset() -> void:
	_visible_tiles.clear()
	_explored_tiles.clear()


# observers: Array of {"pos": Vector2i, "vision": int}
# vision_override: Dictionary[Vector2i, int] — key 为 observer pos，覆盖其 vision
func compute_visibility(observers: Array, map_size: Vector2i, vision_override: Dictionary) -> void:
	_map_size = map_size
	_visible_tiles.clear()
	for obs in observers:
		if obs == null:
			continue
		var center: Vector2i = obs.get("pos", Vector2i.ZERO)
		var base_vision: int = int(obs.get("vision", 0))
		var vision: int = int(vision_override.get(center, base_vision))
		if vision < 0:
			vision = 0
		for dx in range(-vision, vision + 1):
			for dy in range(-vision, vision + 1):
				if maxi(absi(dx), absi(dy)) > vision:
					continue
				var t := Vector2i(center.x + dx, center.y + dy)
				if t.x < 0 or t.y < 0 or t.x >= map_size.x or t.y >= map_size.y:
					continue
				_visible_tiles[t] = true
				_explored_tiles[t] = true


func is_tile_visible(pos: Vector2i) -> bool:
	return _visible_tiles.has(pos)


func is_tile_explored(pos: Vector2i) -> bool:
	return _explored_tiles.has(pos)


func is_enemy_visible(enemy_pos: Vector2i) -> bool:
	return is_tile_visible(enemy_pos)


func get_visible_enemy_positions(enemy_positions: Array) -> Array:
	var result: Array = []
	for ep in enemy_positions:
		if is_enemy_visible(ep):
			result.append(ep)
	return result
