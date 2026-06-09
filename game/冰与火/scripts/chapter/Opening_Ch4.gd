extends "res://scripts/chapter/ChapterOpening.gd"

func _setup() -> void:
	_chapter_num   = "序章·四"
	_chapter_title = "铁王座"
	_chapter_time  = "君临陷落之日"
	_battle_scene  = "res://scenes/ui/DeployScreen_Ch4.tscn"
	_cutscene_files = [
		"res://data/cutscenes/ch4_opening.json",
	]

# Ch4 特殊：战斗前先进入部署画面
func _load_battle() -> void:
	const DEPLOY_SCENE := "res://scenes/ui/DeployScreen_Ch4.tscn"
	const BATTLE       := "res://scenes/battle/BattleMap_Ch4.tscn"
	if ResourceLoader.exists(DEPLOY_SCENE):
		get_tree().change_scene_to_file(DEPLOY_SCENE)
	elif ResourceLoader.exists(BATTLE):
		get_tree().change_scene_to_file(BATTLE)
