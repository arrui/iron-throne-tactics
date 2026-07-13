# DeployScreen_Ch4.gd — 序章·四部署画面
# 让玩家选择最多4名北境骑士参战（奈德自动参战）
extends CanvasLayer

const Ch4BattleBrief := preload("res://scripts/chapter/Ch4BattleBrief.gd")

const MAX_KNIGHTS := 4
const BATTLE_SCENE := "res://scenes/battle/BattleMap.tscn"
const DATA_PATH    := "res://data/units/"

const AVAILABLE_UNITS := [
	{"file": "ned_stark.json",       "mandatory": true},
	{"file": "northern_knight.json", "mandatory": false},
	{"file": "northern_knight.json", "mandatory": false},
	{"file": "northern_knight.json", "mandatory": false},
	{"file": "northern_knight.json", "mandatory": false},
	{"file": "northern_knight.json", "mandatory": false},
]

const CHAPTER_PREMISE := Ch4BattleBrief.CHAPTER_PREMISE
const OBJECTIVE_SUMMARY := Ch4BattleBrief.OBJECTIVE_SUMMARY
const FACTION_SUMMARY := Ch4BattleBrief.FACTION_SUMMARY
const DEPLOY_SUMMARY := Ch4BattleBrief.DEPLOY_SUMMARY
const DEPLOY_ADVICE := Ch4BattleBrief.DEPLOY_ADVICE
const BATTLE_FLOW_STEPS := Ch4BattleBrief.BATTLE_FLOW_STEPS
const PORTRAIT_PATH_MAP := {
	"ned_stark.json": "res://assets/units/ned_stark_portrait.png",
	"northern_knight.json": "res://assets/units/northern_knight_portrait.png",
}
const SLOT_ROLE_HINTS := {
	0: "职责：主将 / 中轴突破",
	1: "职责：前锋 / 黑水桥突破",
	2: "职责：左翼 / 护桥牵制",
	3: "职责：右翼 / 护桥牵制",
	4: "职责：前压 / 城门冲击",
	5: "职责：预备 / 红堡补位",
}

var _selected: Array[int] = []  # 已选骑士的索引（不含奈德）
var _unit_cards: Array = []
var _confirm_btn: Button = null
var _count_label: Label = null

func _get_cjk_font() -> Font:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED):
		var f := load(BUNDLED) as Font
		if f != null: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
	return sf

func _apply_cjk_font_to_node(node: Node) -> void:
	var font := _get_cjk_font()
	if node is Label:
		(node as Label).add_theme_font_override("font", font)
	elif node is Button:
		(node as Button).add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_cjk_font_to_node(child)

func _load_portrait_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _weapon_type_label(weapon_type: String) -> String:
	match weapon_type:
		"sword":
			return "剑"
		"axe":
			return "斧"
		"lance":
			return "枪"
		_:
			return weapon_type

func _load_unit_preview(idx: int, entry: Dictionary) -> Dictionary:
	var file_name := str(entry.get("file", ""))
	var file_path: String = DATA_PATH + file_name
	var preview := {
		"file": file_name,
		"name": "北境骑士",
		"class": "骑士",
		"role": str(SLOT_ROLE_HINTS.get(idx, "职责：机动支援")),
		"summary": "斧D · 移动4\nHP30 武11 速8 防9",
		"mandatory": bool(entry.get("mandatory", false)),
		"portrait_path": str(PORTRAIT_PATH_MAP.get(file_name, "")),
	}
	if FileAccess.file_exists(file_path):
		var f := FileAccess.open(file_path, FileAccess.READ)
		var result: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if result is Dictionary:
			var d := result as Dictionary
			preview["name"] = str(d.get("name", preview["name"]))
			preview["class"] = str(d.get("class", preview["class"]))
			preview["summary"] = "%s%s · 移动%d\nHP%d 武%d 速%d 防%d" % [
				_weapon_type_label(str(d.get("weapon_type", ""))),
				str(d.get("weapon_rank", "E")),
				int(d.get("move", 5)),
				int(d.get("max_hp", 20)),
				int(d.get("pow", 5)),
				int(d.get("spd", 5)),
				int(d.get("def", 5)),
			]
	return preview

func _make_card_style(is_selected: bool, is_mandatory: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	if is_selected:
		style.bg_color = Color(0.12, 0.16, 0.14, 0.98)
		style.border_color = Color(0.96, 0.82, 0.35, 1.0)
	elif is_mandatory:
		style.bg_color = Color(0.11, 0.12, 0.16, 0.98)
		style.border_color = Color(0.48, 0.82, 1.0, 1.0)
	else:
		style.bg_color = Color(0.09, 0.09, 0.12, 0.98)
		style.border_color = Color(0.24, 0.24, 0.3, 1.0)
	return style

func _refresh_card_visual(card: PanelContainer, idx: int, is_mandatory: bool) -> void:
	var is_selected := _selected.has(idx)
	card.add_theme_stylebox_override("panel", _make_card_style(is_selected, is_mandatory))
	var status_label := card.get_node_or_null("VBox/StatusLabel") as Label
	if status_label != null:
		if is_mandatory:
			status_label.text = "状态：固定出战"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		elif is_selected:
			status_label.text = "状态：已编入突击队"
			status_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.42))
		else:
			status_label.text = "状态：待命"
			status_label.add_theme_color_override("font_color", Color(0.66, 0.7, 0.76))
	var select_btn := card.get_node_or_null("VBox/SelectBtn") as Button
	if select_btn != null:
		select_btn.text = "已选中" if is_selected else "选择"

func _refresh_deploy_summary() -> void:
	if _count_label != null:
		var selected_count := _selected.size()
		var summary_suffix := " · 建议至少 3 人稳住中轴与两翼"
		var color := Color(0.7, 0.82, 0.74)
		if selected_count >= 4:
			summary_suffix = " · 编组完整，可直接出发"
			color = Color(0.94, 0.84, 0.4)
		elif selected_count >= 3:
			summary_suffix = " · 编组较稳，已具攻城基本强度"
			color = Color(0.82, 0.88, 0.56)
		elif selected_count <= 1:
			color = Color(0.78, 0.88, 0.86)
		_count_label.text = "已选骑士：%d / %d%s" % [selected_count, MAX_KNIGHTS, summary_suffix]
		_count_label.add_theme_color_override("font_color", color)
	if _confirm_btn != null:
		_confirm_btn.disabled = _selected.is_empty()
		if _selected.is_empty():
			_confirm_btn.text = "⚔ 至少选择 1 名骑士"
		else:
			_confirm_btn.text = "⚔ 确认部署出发（奈德 + %d）" % _selected.size()

func _make_flow_card(step_idx: int, step_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "FlowStep_%d" % (step_idx + 1)
	panel.custom_minimum_size = Vector2(0, 86)
	panel.add_theme_stylebox_override("panel", _make_card_style(false, false))

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var step_num := Label.new()
	step_num.name = "StepNumber"
	step_num.text = "阶段 %d" % (step_idx + 1)
	step_num.add_theme_font_size_override("font_size", 10)
	step_num.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38))
	vb.add_child(step_num)

	var title := Label.new()
	title.name = "StepTitle"
	title.text = str(step_data.get("title", "阶段"))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.94))
	vb.add_child(title)

	var desc := Label.new()
	desc.name = "StepDesc"
	desc.text = str(step_data.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	vb.add_child(desc)

	return panel

func _ready() -> void:
	layer = 40
	_build_ui()
	# 为所有动态创建的UI控件应用中文字体
	call_deferred("_apply_cjk_font_to_node", self)

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.08, 0.97)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "LayoutRoot"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -360.0
	vbox.offset_right = 360.0
	vbox.offset_top = -300.0
	vbox.offset_bottom = 300.0
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# 标题
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "序章·四《铁王座》— 战前部署"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "奈德·史塔克自动参战。选择最多 %d 名北境骑士随行。" % MAX_KNIGHTS
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var info_panel := PanelContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.custom_minimum_size = Vector2(0, 132)
	vbox.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)

	var premise_lbl := Label.new()
	premise_lbl.name = "PremiseLabel"
	premise_lbl.text = CHAPTER_PREMISE
	premise_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premise_lbl.add_theme_font_size_override("font_size", 13)
	premise_lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9))
	info_vbox.add_child(premise_lbl)

	var objective_lbl := Label.new()
	objective_lbl.name = "ObjectiveSummaryLabel"
	objective_lbl.text = OBJECTIVE_SUMMARY
	objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_lbl.add_theme_font_size_override("font_size", 13)
	objective_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45))
	info_vbox.add_child(objective_lbl)

	var faction_lbl := Label.new()
	faction_lbl.name = "FactionSummaryLabel"
	faction_lbl.text = FACTION_SUMMARY
	faction_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_lbl.add_theme_font_size_override("font_size", 12)
	faction_lbl.add_theme_color_override("font_color", Color(0.74, 0.82, 0.9))
	info_vbox.add_child(faction_lbl)

	var deploy_lbl := Label.new()
	deploy_lbl.name = "DeploySummaryLabel"
	deploy_lbl.text = DEPLOY_SUMMARY
	deploy_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deploy_lbl.add_theme_font_size_override("font_size", 12)
	deploy_lbl.add_theme_color_override("font_color", Color(0.72, 0.9, 0.74))
	info_vbox.add_child(deploy_lbl)

	var battle_flow_panel := PanelContainer.new()
	battle_flow_panel.name = "BattleFlowPanel"
	battle_flow_panel.custom_minimum_size = Vector2(0, 196)
	vbox.add_child(battle_flow_panel)

	var battle_flow_vbox := VBoxContainer.new()
	battle_flow_vbox.name = "BattleFlowVBox"
	battle_flow_vbox.add_theme_constant_override("separation", 8)
	battle_flow_panel.add_child(battle_flow_vbox)

	var flow_title := Label.new()
	flow_title.name = "FlowTitle"
	flow_title.text = "作战分段简报"
	flow_title.add_theme_font_size_override("font_size", 15)
	flow_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.46))
	battle_flow_vbox.add_child(flow_title)

	var flow_grid := GridContainer.new()
	flow_grid.name = "FlowGrid"
	flow_grid.columns = 2
	flow_grid.add_theme_constant_override("h_separation", 10)
	flow_grid.add_theme_constant_override("v_separation", 10)
	battle_flow_vbox.add_child(flow_grid)

	for step_idx: int in BATTLE_FLOW_STEPS.size():
		flow_grid.add_child(_make_flow_card(step_idx, BATTLE_FLOW_STEPS[step_idx]))

	var advice_label := Label.new()
	advice_label.name = "DeployAdviceLabel"
	advice_label.text = DEPLOY_ADVICE
	advice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advice_label.add_theme_font_size_override("font_size", 12)
	advice_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.78))
	battle_flow_vbox.add_child(advice_label)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_count_label)

	# 单位卡片列表
	var grid := GridContainer.new()
	grid.name = "UnitGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	vbox.add_child(grid)

	for i: int in AVAILABLE_UNITS.size():
		var entry: Dictionary = AVAILABLE_UNITS[i]
		var card := _make_unit_card(i, entry)
		grid.add_child(card)
		_unit_cards.append(card)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var new_game_btn := Button.new()
	new_game_btn.name = "NewGameButton"
	new_game_btn.text = "↺ 新游戏（清除存档）"
	new_game_btn.custom_minimum_size = Vector2(200, 40)
	new_game_btn.pressed.connect(_on_new_game)
	btn_row.add_child(new_game_btn)

	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmButton"
	_confirm_btn.custom_minimum_size = Vector2(260, 48)
	_confirm_btn.add_theme_font_size_override("font_size", 16)
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	_refresh_deploy_summary()

func _make_unit_card(idx: int, entry: Dictionary) -> PanelContainer:
	var preview := _load_unit_preview(idx, entry)
	var is_mandatory: bool = bool(entry.get("mandatory", false))

	var panel := PanelContainer.new()
	panel.name = "UnitCard_%d" % idx
	panel.custom_minimum_size = Vector2(210, 220)
	panel.add_theme_stylebox_override("panel", _make_card_style(false, is_mandatory))

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(86, 86)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture = _load_portrait_texture(str(preview.get("portrait_path", "")))
	vb.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = str(preview.get("name", "北境骑士"))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_mandatory:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vb.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.name = "RoleLabel"
	role_lbl.text = str(preview.get("role", "职责：机动支援"))
	role_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 0.9))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(role_lbl)

	var stats_lbl := Label.new()
	stats_lbl.name = "StatsLabel"
	var stats_lbl_text := str(preview.get("summary", ""))
	stats_lbl.text = stats_lbl_text
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats_lbl)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(status_lbl)

	if is_mandatory:
		var tag := Label.new()
		tag.name = "MandatoryTag"
		tag.text = "【必须参战】"
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tag)
	else:
		var select_btn := Button.new()
		select_btn.name = "SelectBtn"
		select_btn.text = "选择"
		select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_btn.toggle_mode = true
		var ci := idx
		select_btn.toggled.connect(func(pressed: bool) -> void:
			_on_card_toggled(ci, pressed, select_btn))
		vb.add_child(select_btn)

	_refresh_card_visual(panel, idx, is_mandatory)
	return panel

func _on_card_toggled(idx: int, pressed: bool, btn: Button) -> void:
	if pressed:
		if _selected.size() >= MAX_KNIGHTS:
			btn.button_pressed = false
			return
		_selected.append(idx)
	else:
		_selected.erase(idx)
	if idx >= 0 and idx < _unit_cards.size() and _unit_cards[idx] is PanelContainer:
		_refresh_card_visual(_unit_cards[idx] as PanelContainer, idx, bool(AVAILABLE_UNITS[idx].get("mandatory", false)))
	_refresh_deploy_summary()

func _on_new_game() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).delete_save()
	get_tree().change_scene_to_file("res://scenes/Opening.tscn")

func _on_confirm() -> void:
	# 保存部署选择到 BattleBootstrap_Ch4
	var selections: Array[String] = ["ned_stark.json"]
	for idx: int in _selected:
		selections.append(AVAILABLE_UNITS[idx]["file"])
	GameState.deploy_selection = selections
	get_tree().change_scene_to_file(BATTLE_SCENE)
