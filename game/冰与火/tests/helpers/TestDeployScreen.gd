extends "res://scripts/ui/DeployScreen_Ch4.gd"

var recorded_scene_changes: Array[String] = []

func _build_ui() -> void:
	# 仅构建需要验证的核心提示标签与关键按钮引用
	var premise := Label.new()
	premise.name = "PremiseLabel"
	premise.text = CHAPTER_PREMISE
	add_child(premise)

	var objective := Label.new()
	objective.name = "ObjectiveSummaryLabel"
	objective.text = OBJECTIVE_SUMMARY
	add_child(objective)

	var faction := Label.new()
	faction.name = "FactionSummaryLabel"
	faction.text = FACTION_SUMMARY
	add_child(faction)

	var deploy := Label.new()
	deploy.name = "DeploySummaryLabel"
	deploy.text = DEPLOY_SUMMARY
	add_child(deploy)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.text = "已选骑士：0 / %d" % MAX_KNIGHTS
	add_child(_count_label)

	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmBtn"
	_confirm_btn.disabled = true
	add_child(_confirm_btn)

func _ready() -> void:
	_build_ui()

func _record_scene_change(path: String) -> void:
	recorded_scene_changes.append(path)

func test_confirm() -> void:
	var selections: Array[String] = ["ned_stark.json"]
	for idx: int in _selected:
		selections.append(AVAILABLE_UNITS[idx]["file"])
	GameState.deploy_selection = selections
	_record_scene_change(BATTLE_SCENE)

func test_new_game() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).delete_save()
	_record_scene_change("res://scenes/Opening.tscn")
