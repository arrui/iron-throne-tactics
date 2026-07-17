extends "res://scripts/battle/BattleBootstrap.gd"

var recorded_dialogues: Array[String] = []
var recorded_cutscenes: Array[String] = []
var recorded_advances: Array[int] = []
var recorded_statuses: Array[String] = []
var restart_requested: bool = false
var return_to_opening_requested: bool = false
var fixed_combat_result: Dictionary = {}
var recorded_enemy_turn_starts: int = 0
var intercept_enemy_turn_start: bool = false
var recorded_player_turn_starts: int = 0
var record_autopilot_range_calculations: bool = false
var recorded_autopilot_range_calculations: int = 0
var autopilot_walkable_overrides: Dictionary = {}
var recorded_move_result: Variant = null
var recorded_battle_completion: bool = false
var remove_unit_after_autopilot_move: bool = false
var removed_unit_after_autopilot_move: bool = false

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
		var top_panel := PanelContainer.new()
		top_panel.name = "TopInfoPanel"
		ui.add_child(top_panel)
		var top_margin := MarginContainer.new()
		top_margin.name = "TopInfoMargin"
		top_panel.add_child(top_margin)
		var top_vbox := VBoxContainer.new()
		top_vbox.name = "TopInfoVBox"
		top_margin.add_child(top_vbox)
		var turn := Label.new()
		turn.name = "TurnLabel"
		top_vbox.add_child(turn)
		var phase := Label.new()
		phase.name = "PhaseLabel"
		top_vbox.add_child(phase)
		var objective := Label.new()
		objective.name = "ObjectiveLabel"
		top_vbox.add_child(objective)
		var guidance := Label.new()
		guidance.name = "GuidanceLabel"
		top_vbox.add_child(guidance)
		var status := Label.new()
		status.name = "StatusLabel"
		top_vbox.add_child(status)

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

func _play_cutscene(path: String) -> void:
	recorded_cutscenes.append(path)

func _advance_to(next_chapter: int) -> void:
	recorded_advances.append(next_chapter)
	SaveSystem.save_chapter_complete(GameState.current_chapter)
	GameState.current_chapter = 1 if next_chapter <= 0 else next_chapter

func _set_status(msg: String) -> void:
	recorded_statuses.append(msg)
	var objective_label := get_node_or_null("UI/ObjectiveLabel") as Label
	if objective_label == null:
		objective_label = get_node_or_null("UI/TopInfoPanel/TopInfoMargin/TopInfoVBox/ObjectiveLabel") as Label
	if objective_label != null and (msg.begins_with("目标：") or msg.begins_with("战局：")):
		objective_label.text = msg
	var guidance_label := get_node_or_null("UI/GuidanceLabel") as Label
	if guidance_label == null:
		guidance_label = get_node_or_null("UI/TopInfoPanel/TopInfoMargin/TopInfoVBox/GuidanceLabel") as Label
	if guidance_label != null and msg.begins_with("推进："):
		guidance_label.text = msg
	var phase_label := get_node_or_null("UI/PhaseLabel") as Label
	if phase_label == null:
		phase_label = get_node_or_null("UI/TopInfoPanel/TopInfoMargin/TopInfoVBox/PhaseLabel") as Label
	if phase_label != null and msg.begins_with("阶段："):
		phase_label.text = msg
	if _status_label:
		_status_label.text = msg

func _restart() -> void:
	restart_requested = true

func _return_to_opening() -> void:
	return_to_opening_requested = true

func _start_enemy_turn() -> void:
	recorded_enemy_turn_starts += 1
	if not intercept_enemy_turn_start:
		await super._start_enemy_turn()

func _start_player_turn() -> void:
	recorded_player_turn_starts += 1
	super._start_player_turn()

func _calc_move_range(unit: Unit) -> Array[Vector2i]:
	if record_autopilot_range_calculations:
		recorded_autopilot_range_calculations += 1
		return [unit.grid_pos]
	var override: Variant = autopilot_walkable_overrides.get(unit.get_instance_id())
	if override is Array:
		var walkable: Array[Vector2i] = []
		walkable.assign(override)
		return walkable
	return super._calc_move_range(unit)

func _build_combat_result(pred: Dictionary, attacker_hp: int, defender_hp: int) -> Dictionary:
	if not fixed_combat_result.is_empty():
		return fixed_combat_result.duplicate(true)
	return super._build_combat_result(pred, attacker_hp, defender_hp)

func record_move_result(unit: Unit, target: Vector2i) -> void:
	recorded_move_result = await _do_move_animated(unit, target)

func _do_move_animated(unit: Unit, target: Vector2i) -> bool:
	var completed := await super._do_move_animated(unit, target)
	if completed and remove_unit_after_autopilot_move and is_instance_valid(unit):
		remove_unit_after_autopilot_move = false
		removed_unit_after_autopilot_move = true
		unit.queue_free()
	return completed

func record_battle_completion(attacker: Unit, defender: Unit) -> void:
	await _start_battle_with_animation(attacker, defender)
	recorded_battle_completion = true
