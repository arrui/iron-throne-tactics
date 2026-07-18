extends "res://scripts/ui/DeployScreen_Ch4.gd"

var recorded_scene_changes: Array[String] = []

func _apply_cjk_font_to_node(_node: Node) -> void:
	pass

func _record_scene_change(path: String) -> void:
	recorded_scene_changes.append(path)

func test_confirm() -> void:
	var selections: Array[String] = ["ned_stark.json"]
	var available_units: Array = _available_units()
	for idx: int in _selected:
		selections.append(str((available_units[idx] as Dictionary).get("file", "")))
	GameState.deploy_selection = selections
	_record_scene_change(BATTLE_SCENE)

func test_new_game() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).delete_save()
	_record_scene_change("res://scenes/Opening.tscn")
