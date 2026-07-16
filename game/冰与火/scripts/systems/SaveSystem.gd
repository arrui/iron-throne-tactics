class_name SaveSystem

const SAVE_PATH := "user://save.json"

static func start_new_campaign() -> void:
	_write_json({
		"chapter": 1,
		"completed_chapters": [],
		"timestamp": Time.get_date_string_from_system(),
	})

static func save_chapter_complete(chapter: int) -> void:
	var data := _read_json()
	# 转为 int 数组，避免 JSON 反序列化时浮点类型干扰 in 运算符
	var raw: Array = data.get("completed_chapters", [])
	var completed: Array[int] = []
	for v: Variant in raw:
		completed.append(int(v))
	if chapter not in completed:
		completed.append(chapter)
	data["completed_chapters"] = completed
	var current_progress := int(data.get("chapter", 1))
	data["chapter"] = maxi(current_progress, chapter + 1)
	data["timestamp"] = Time.get_date_string_from_system()
	_write_json(data)

static func load_current_chapter() -> int:
	var data := _read_json()
	return int(data.get("chapter", 1))

static func get_completed_chapters() -> Array[int]:
	var data := _read_json()
	var raw: Array = data.get("completed_chapters", [])
	var result: Array[int] = []
	for v in raw:
		result.append(int(v))
	return result

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

static func _write_json(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func _read_json() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
