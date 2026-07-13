extends "res://scripts/chapter/ChapterOpening.gd"

func _setup() -> void:
	_chapter_num   = "序章·三"
	_chapter_title = "极乐塔"
	_chapter_time  = "多恩 · 三叉戟之战后数日"
	_chapter_sub_label = "追索真相 / 突破守门者"
	_chapter_objective = "目标：让奈德抵达欢乐塔，不必全歼守军。"
	_battle_scene  = "res://scenes/battle/BattleMap.tscn"
	_cutscene_files = [
		"res://data/cutscenes/ch3_opening.json",
	]

func _load_battle() -> void:
	GameState.current_chapter = 3
	get_tree().change_scene_to_file("res://scenes/battle/BattleMap.tscn")
