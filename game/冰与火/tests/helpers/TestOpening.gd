extends "res://scripts/Opening.gd"

var recorded_scene_changes: Array[String] = []
var played_chapter_1: bool = false

func _ready() -> void:
	# 测试中避免真实进入调试菜单/字体初始化副作用
	pass

func _play_chapter_1() -> void:
	played_chapter_1 = true

func _record_scene_change(path: String) -> void:
	recorded_scene_changes.append(path)

func run_start_normal_flow() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		var ss := load(SAVE_SYS_PATH)
		if ss.has_save():
			var chapter: int = ss.load_current_chapter()
			if chapter > 1 and CHAPTER_SCENE_MAP.has(chapter):
				var scene_path: String = CHAPTER_SCENE_MAP[chapter] as String
				if ResourceLoader.exists(scene_path):
					_record_scene_change(scene_path)
					return
	_play_chapter_1()
