class_name SaveSystem

const SAVE_PATH := "user://save.json"

static func start_new_campaign() -> void:
	_write_json({
		"act": 0, "chapter": 1,
		"completed": [],
		"timestamp": Time.get_date_string_from_system(),
	})

# act=0 序章；记录完成并推进到下一章。序章内 chapter 连续递增。
# 不倒退：仅在算出的下一进度严格领先于当前存档进度时才推进，避免回顾旧章覆盖进度。
static func save_chapter_complete(act: int, chapter: int) -> void:
	var data := _read_json()
	_ensure_new_schema(data)
	var id := _id_of(act, chapter)
	var completed: Array = data.get("completed", [])
	if id not in completed:
		completed.append(id)
	data["completed"] = completed
	var next_act := act
	var next_ch := chapter + 1
	if act == 0 and next_ch > 4:
		next_act = 1
		next_ch = 1
	var cur_act := int(data.get("act", 0))
	var cur_ch := int(data.get("chapter", 1))
	# 序章完成态(chapter=5,act=0 旧存档)等价于已进入正篇，需识别为高进度。
	if _progress_key(next_act, next_ch) > _progress_key(cur_act, cur_ch):
		data["act"] = next_act
		data["chapter"] = next_ch
	data["timestamp"] = Time.get_date_string_from_system()
	_write_json(data)

static func load_progress() -> Dictionary:
	var data := _read_json()
	_ensure_new_schema(data)
	return {"act": int(data.get("act", 0)), "chapter": int(data.get("chapter", 1))}

static func get_completed_ids() -> Array[String]:
	var data := _read_json()
	_ensure_new_schema(data)
	var raw: Array = data.get("completed", [])
	if not raw is Array:
		raw = []
	var result: Array[String] = []
	for v in raw:
		result.append(String(v))
	return result

# ── 序章兼容别名（现有代码继续用）─────────────────────
# 序章代码（如 Opening.gd）用 `chapter > 4` 判定序章完成态；
# 因此当存档已进入正篇(act!=0)时返回 5 作为"序章已完成"哨兵，保持序章代码零改动。
static func load_current_chapter() -> int:
	var prog := load_progress()
	if prog["act"] == 0:
		return maxi(1, int(prog["chapter"]))
	return 5

static func get_completed_chapters() -> Array[int]:
	var ids := get_completed_ids()
	var result: Array[int] = []
	for id in ids:
		if id.begins_with("prologue."):
			result.append(int(id.substr(9)))
	return result

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

static func _id_of(act: int, chapter: int) -> String:
	return "prologue.%d" % chapter if act == 0 else "act%d.%d" % [act, chapter]

# 把 (act, chapter) 折算为可比较的进度键；act>=1 恒大于序章任意章(1-4)。
static func _progress_key(act: int, chapter: int) -> int:
	if act == 0:
		return chapter
	return 1000 + (act - 1) * 100 + chapter

# 旧 {chapter, completed_chapters} → 新 {act, chapter, completed}
static func _ensure_new_schema(data: Dictionary) -> void:
	if data.has("act"):
		if not data.has("completed"):
			data["completed"] = []
		elif not data["completed"] is Array:
			data["completed"] = []
		return
	# 旧存档推断
	var old_ch := int(data.get("chapter", 1))
	data["act"] = 0
	data["chapter"] = old_ch
	var raw_value: Variant = data.get("completed_chapters", [])
	var raw: Array = raw_value if raw_value is Array else []
	var completed: Array = []
	for v in raw:
		completed.append("prologue.%d" % int(v))
	data["completed"] = completed

static func _write_json_for_test(data: Dictionary) -> void:
	_write_json(data)

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
