# Opening.gd — 序章·一完整开场流程
# 流程：总览旁白 → 疯王杀父兄过场 → 起义宣誓过场 → 进入战斗
extends Node

const CUTSCENE_SCENE := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const BATTLE_SCENE   := "res://scenes/battle/BattleMap.tscn"

const PROLOGUE_OPENING  := "res://data/cutscenes/prologue_opening.json"
const MAD_KING          := "res://data/cutscenes/prologue_mad_king.json"
const UPRISING          := "res://data/cutscenes/prologue_uprising.json"

var _cutscene: CutscenePlayer = null

func _ready() -> void:
	_cutscene = CUTSCENE_SCENE.instantiate() as CutscenePlayer
	add_child(_cutscene)
	_cutscene.cutscene_finished.connect(_on_cutscene_finished)
	_play_sequence()

var _sequence: Array = []
var _seq_index: int  = 0

func _play_sequence() -> void:
	_sequence  = [PROLOGUE_OPENING, MAD_KING, UPRISING]
	_seq_index = 0
	_play_next()

func _play_next() -> void:
	if _seq_index >= _sequence.size():
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	_cutscene.play(_sequence[_seq_index])

func _on_cutscene_finished() -> void:
	_seq_index += 1
	await get_tree().create_timer(0.3).timeout
	_play_next()
