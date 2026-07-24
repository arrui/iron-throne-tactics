# Opening_A1C1.gd — 第一幕第一章开场
extends "res://scripts/chapter/ChapterOpening.gd"

const Act1ChapterBriefs := preload("res://scripts/chapter/Act1ChapterBriefs.gd")

func _setup() -> void:
	_chapter_num   = "第一幕·一"
	_chapter_title = "呓语森林"
	_chapter_time  = "五王之战 · 第一年"
	_chapter_sub_label = "夜袭章节 / 视野受限"
	_chapter_objective = Act1ChapterBriefs.A1C1_OBJECTIVE_SUMMARY
	_battle_scene  = "res://scenes/battle/BattleMap_A1C1.tscn"
	_cutscene_files = ["res://data/cutscenes/act1_ch1_opening.json"]

func _load_battle() -> void:
	# 进入战斗前设置 GameState，让战斗系统知道这是 act1.ch1
	GameState.set_act(1, 1)
	super._load_battle()
