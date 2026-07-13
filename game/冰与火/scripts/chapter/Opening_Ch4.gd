extends "res://scripts/chapter/ChapterOpening.gd"

const PrologueChapterBriefs := preload("res://scripts/chapter/PrologueChapterBriefs.gd")

func _setup() -> void:
	_chapter_num   = "序章·四"
	_chapter_title = "铁王座"
	_chapter_time  = "君临陷落之日"
	_chapter_sub_label = "攻城终章 / 红堡突破"
	_chapter_objective = PrologueChapterBriefs.CH4_OBJECTIVE_SUMMARY
	_battle_scene  = "res://scenes/battle/BattleMap.tscn"
	_cutscene_files = [
		"res://data/cutscenes/ch4_opening.json",
	]

func _load_battle() -> void:
	GameState.current_chapter = 4
	const DEPLOY_SCENE := "res://scenes/ui/DeployScreen_Ch4.tscn"
	if ResourceLoader.exists(DEPLOY_SCENE):
		get_tree().change_scene_to_file(DEPLOY_SCENE)
	else:
		get_tree().change_scene_to_file("res://scenes/battle/BattleMap.tscn")
