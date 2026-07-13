extends "res://scripts/battle/BattleBootstrap.gd"

var recorded_dialogues: Array[String] = []
var recorded_cutscenes: Array[String] = []
var recorded_advances: Array[int] = []
var recorded_statuses: Array[String] = []

func _enter_tree() -> void:
	if get_node_or_null("HighlightLayer") == null:
		var hl := Node2D.new()
		hl.name = "HighlightLayer"
		add_child(hl)
	if get_node_or_null("Camera2D") == null:
		var cam := Camera2D.new()
		cam.name = "Camera2D"
		add_child(cam)
	if get_node_or_null("UnitLayer") == null:
		var unit_layer := Node2D.new()
		unit_layer.name = "UnitLayer"
		add_child(unit_layer)
	if get_node_or_null("UI") == null:
		var ui := CanvasLayer.new()
		ui.name = "UI"
		add_child(ui)
		var objective := Label.new()
		objective.name = "ObjectiveLabel"
		ui.add_child(objective)
		var phase := Label.new()
		phase.name = "PhaseLabel"
		ui.add_child(phase)
		var guidance := Label.new()
		guidance.name = "GuidanceLabel"
		ui.add_child(guidance)
		var status := Label.new()
		status.name = "StatusLabel"
		ui.add_child(status)

func _apply_cam_limits() -> void:
	pass

func _paint_from(_terrain: Array) -> void:
	pass

func _paint_from_ch4(_terrain: Array) -> void:
	pass

func _run_ch1_tutorial() -> void:
	pass

func _setup_autopilot_ui() -> void:
	pass

func _setup_minimap() -> void:
	pass

func _play_dialogue(path: String) -> void:
	recorded_dialogues.append(path)
	await get_tree().process_frame

func _play_cutscene(path: String) -> void:
	recorded_cutscenes.append(path)
	await get_tree().process_frame

func _advance_to(next_chapter: int) -> void:
	recorded_advances.append(next_chapter)
	GameState.current_chapter = 1 if next_chapter <= 0 else next_chapter
	await get_tree().process_frame

func _set_status(msg: String) -> void:
	recorded_statuses.append(msg)
	var objective_label := get_node_or_null("UI/ObjectiveLabel") as Label
	if objective_label != null and (msg.begins_with("目标：") or msg.begins_with("战局：")):
		objective_label.text = msg
	var guidance_label := get_node_or_null("UI/GuidanceLabel") as Label
	if guidance_label != null and msg.begins_with("推进："):
		guidance_label.text = msg
	var phase_label := get_node_or_null("UI/PhaseLabel") as Label
	if phase_label != null and msg.begins_with("阶段："):
		phase_label.text = msg
	if _status_label:
		_status_label.text = msg
