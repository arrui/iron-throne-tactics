class_name SupportSystem

const C_RANK_POINTS := 5
const B_RANK_POINTS := 15
const A_RANK_POINTS := 30

var _support_data: Dictionary = {}

func register_pair(unit_a_name: String, unit_b_name: String) -> void:
	var key := _make_key(unit_a_name, unit_b_name)
	if not _support_data.has(key):
		_support_data[key] = {"points": 0, "rank": "none"}

func add_adjacent_point(unit_a_name: String, unit_b_name: String) -> bool:
	var key := _make_key(unit_a_name, unit_b_name)
	if not _support_data.has(key):
		register_pair(unit_a_name, unit_b_name)
	var entry: Dictionary = _support_data[key]
	entry["points"] = entry["points"] + 1
	var old_rank: String = entry["rank"]
	var new_rank := _compute_rank(entry["points"])
	entry["rank"] = new_rank
	return new_rank != old_rank

func get_rank(unit_a_name: String, unit_b_name: String) -> String:
	var key := _make_key(unit_a_name, unit_b_name)
	if not _support_data.has(key):
		return "none"
	return _support_data[key]["rank"]

func get_combat_bonus(unit_a_name: String, unit_b_name: String) -> Dictionary:
	var rank := get_rank(unit_a_name, unit_b_name)
	match rank:
		"C":
			return {"hit": 5, "avoid": 5}
		"B":
			return {"hit": 10, "avoid": 10}
		"A":
			return {"hit": 15, "avoid": 15}
	return {"hit": 0, "avoid": 0}

func get_points(unit_a_name: String, unit_b_name: String) -> int:
	var key := _make_key(unit_a_name, unit_b_name)
	if not _support_data.has(key):
		return 0
	return _support_data[key]["points"]

func _make_key(a: String, b: String) -> String:
	var parts := [a, b]
	parts.sort()
	return "_".join(parts)

func _compute_rank(points: int) -> String:
	if points >= A_RANK_POINTS:
		return "A"
	if points >= B_RANK_POINTS:
		return "B"
	if points >= C_RANK_POINTS:
		return "C"
	return "none"

func reset() -> void:
	_support_data.clear()

func serialize() -> Dictionary:
	return _support_data.duplicate(true)

func deserialize(data: Dictionary) -> void:
	_support_data = data.duplicate(true)
