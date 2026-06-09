# ChapterOpening.gd — 章节开场基类
# 流程：章节标题卡 → 开场过场 → 战斗场景
extends Node

const CUTSCENE_SCENE   := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const TRANSITION_PATH  := "res://scenes/ui/ChapterTransition.tscn"

var _chapter_num:   String = "序章·一"
var _chapter_title: String = "标题"
var _chapter_time:  String = ""
var _battle_scene:  String = ""
var _cutscene_files: Array = []

var _cutscene:    CutscenePlayer = null
var _seq_index:   int = 0
var _transition:  Node = null

func _ready() -> void:
	_setup()
	_play_title_card()

# 子类覆盖此方法设置参数
func _setup() -> void:
	pass

func _play_title_card() -> void:
	if ResourceLoader.exists(TRANSITION_PATH):
		_transition = load(TRANSITION_PATH).instantiate()
		add_child(_transition)
		if _transition.has_method("show_chapter"):
			_transition.call("show_chapter",
				_chapter_num, _chapter_title, _chapter_time)
		if _transition.has_signal("transition_finished"):
			_transition.connect("transition_finished", _on_title_done)
		else:
			# 没有信号则等 4 秒
			await get_tree().create_timer(4.0).timeout
			_on_title_done()
	else:
		# 没有标题卡场景，直接播放过场
		_on_title_done()

func _on_title_done() -> void:
	if _transition:
		_transition.queue_free()
		_transition = null
	if _cutscene_files.is_empty():
		_load_battle()
		return
	_cutscene = CUTSCENE_SCENE.instantiate() as CutscenePlayer
	add_child(_cutscene)
	_cutscene.cutscene_finished.connect(_on_cutscene_finished)
	_seq_index = 0
	_play_next_cutscene()

func _play_next_cutscene() -> void:
	if _seq_index >= _cutscene_files.size():
		_load_battle()
		return
	_cutscene.play(_cutscene_files[_seq_index])

func _on_cutscene_finished() -> void:
	_seq_index += 1
	await get_tree().create_timer(0.3).timeout
	_play_next_cutscene()

func _load_battle() -> void:
	if _battle_scene != "" and ResourceLoader.exists(_battle_scene):
		get_tree().change_scene_to_file(_battle_scene)
