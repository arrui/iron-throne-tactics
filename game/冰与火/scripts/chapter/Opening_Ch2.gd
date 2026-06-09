extends "res://scripts/chapter/ChapterOpening.gd"

func _setup() -> void:
	_chapter_num   = "序章·二"
	_chapter_title = "三叉戟"
	_chapter_time  = "篡夺者战争 · 第三年"
	_battle_scene  = "res://scenes/battle/BattleMap_Ch2.tscn"
	_cutscene_files = [
		"res://data/cutscenes/ch2_opening.json",
	]
