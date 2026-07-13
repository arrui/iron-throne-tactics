extends "res://scripts/Opening.gd"

var recorded_scene_changes: Array[String] = []
var played_chapter_1: bool = false
var played_ch1_title_card: bool = false
var started_ch1_cutscene_flow: bool = false
var recorded_ch1_title_card_args: Array[String] = []

func _ready() -> void:
	# 测试中避免真实进入调试菜单/字体初始化副作用
	pass

func _play_chapter_1() -> void:
	played_chapter_1 = true
	_play_ch1_title_card()

func _play_ch1_title_card() -> void:
	played_ch1_title_card = true
	recorded_ch1_title_card_args = _get_ch1_title_card_args()
	_on_ch1_title_done()

func _begin_ch1_cutscene_flow() -> void:
	started_ch1_cutscene_flow = true

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
