# Opening.gd — 序章·一开场流程 + 存档路由
# 流程：检查存档 → 旁白过场 → 疯王杀父兄 → 起义 → 进入战斗
extends Node

const CUTSCENE_SCENE := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const BATTLE_SCENE   := "res://scenes/battle/BattleMap.tscn"

const PROLOGUE_OPENING := "res://data/cutscenes/prologue_opening.json"
const MAD_KING         := "res://data/cutscenes/prologue_mad_king.json"
const UPRISING         := "res://data/cutscenes/prologue_uprising.json"

# 章节路由表（存档章节 → 对应 Opening 场景）
const CHAPTER_SCENE_MAP := {
	2: "res://scenes/chapter/Ch2_Opening.tscn",
	3: "res://scenes/chapter/Ch3_Opening.tscn",
	4: "res://scenes/chapter/Ch4_Opening.tscn",
}

var _cutscene: CutscenePlayer = null

func _ready() -> void:
	# 检查存档，若指向更高章节则直接跳转
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		var ss := load(SAVE_SYS_PATH)
		if ss.has_save():
			var chapter: int = ss.load_current_chapter()
			if chapter > 1 and CHAPTER_SCENE_MAP.has(chapter):
				var scene_path: String = CHAPTER_SCENE_MAP[chapter] as String
				if ResourceLoader.exists(scene_path):
					get_tree().change_scene_to_file(scene_path)
					return

	# 默认：播放序章·一过场
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
