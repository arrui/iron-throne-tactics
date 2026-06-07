# Opening.gd — 序章开场场景脚本
# 播放开场动画，完成后切换到战斗地图
extends Node

func _ready() -> void:
	var player: CutscenePlayer = $CutscenePlayer as CutscenePlayer
	if player == null:
		push_error("Opening: 找不到 CutscenePlayer 子节点")
		_go_to_battle()
		return
	player.cutscene_finished.connect(_on_finished)
	player.play("res://data/cutscenes/prologue_opening.json")

func _on_finished() -> void:
	_go_to_battle()

func _go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/BattleMap.tscn")
