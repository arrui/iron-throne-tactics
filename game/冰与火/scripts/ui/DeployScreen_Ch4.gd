# DeployScreen_Ch4.gd — 序章·四部署画面
# 让玩家选择最多4名北境骑士参战（奈德自动参战）
extends CanvasLayer

const Ch4BattleBrief := preload("res://scripts/chapter/Ch4BattleBrief.gd")
const BattleChromeTheme := preload("res://scripts/ui/BattleChromeTheme.gd")
const CJKFontHelper := preload("res://scripts/ui/CJKFontHelper.gd")
const ClassCatalog := preload("res://scripts/data/ClassCatalog.gd")

const MAX_KNIGHTS := 4
const BATTLE_SCENE := "res://scenes/battle/BattleMap.tscn"
const DATA_PATH    := "res://data/units/"

var AVAILABLE_UNITS: Array = ClassCatalog.get_ch4_deploy_options()

const CHAPTER_PREMISE := Ch4BattleBrief.CHAPTER_PREMISE
const OBJECTIVE_SUMMARY := Ch4BattleBrief.OBJECTIVE_SUMMARY
const FACTION_SUMMARY := Ch4BattleBrief.FACTION_SUMMARY
const DEPLOY_SUMMARY := Ch4BattleBrief.DEPLOY_SUMMARY
const DEPLOY_ADVICE := Ch4BattleBrief.DEPLOY_ADVICE
const BATTLE_FLOW_STEPS := Ch4BattleBrief.BATTLE_FLOW_STEPS
var _selected: Array[int] = []  # 已选骑士的索引（不含奈德）
var _unit_cards: Array = []
var _confirm_btn: Button = null
var _count_label: Label = null

func _available_units() -> Array:
	if AVAILABLE_UNITS.is_empty():
		AVAILABLE_UNITS = ClassCatalog.get_ch4_deploy_options()
	return AVAILABLE_UNITS

func _apply_dark_ui_theme() -> void:
	BattleChromeTheme.apply_dark_chrome_recursive(self)
	var info_panel := get_node_or_null("LayoutRoot/ContentVBox/InfoPanel") as PanelContainer
	if info_panel != null:
		info_panel.add_theme_stylebox_override("panel", _make_section_style())
	var battle_flow_panel := get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel") as PanelContainer
	if battle_flow_panel != null:
		battle_flow_panel.add_theme_stylebox_override("panel", _make_section_style())
	var roster_panel := get_node_or_null("LayoutRoot/ContentVBox/RosterPanel") as PanelContainer
	if roster_panel != null:
		roster_panel.add_theme_stylebox_override("panel", _make_summary_style())
	var available_units := _available_units()
	for i: int in _unit_cards.size():
		if _unit_cards[i] is PanelContainer:
			_refresh_card_visual(_unit_cards[i] as PanelContainer, i, bool((available_units[i] as Dictionary).get("mandatory", false)))
	var flow_grid := get_node_or_null("LayoutRoot/ContentVBox/BattleFlowPanel/BattleFlowVBox/FlowGrid") as GridContainer
	if flow_grid != null:
		for child in flow_grid.get_children():
			if child is PanelContainer:
				(child as PanelContainer).add_theme_stylebox_override("panel", _make_flow_style())

func _make_section_style() -> StyleBoxFlat:
	return BattleChromeTheme.make_panel_style(
		BattleChromeTheme.PANEL_HIGHLIGHT_BG,
		BattleChromeTheme.PANEL_HIGHLIGHT_BORDER,
		10,
		2,
		14
	)

func _make_summary_style() -> StyleBoxFlat:
	return BattleChromeTheme.make_panel_style(
		BattleChromeTheme.PANEL_BG,
		BattleChromeTheme.PANEL_BORDER,
		10,
		2,
		14
	)

func _make_flow_style() -> StyleBoxFlat:
	return BattleChromeTheme.make_panel_style(
		BattleChromeTheme.PANEL_STEEL_BG,
		BattleChromeTheme.PANEL_BORDER,
		8,
		2,
		10
	)

func _style_section_header(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)

func _get_cjk_font() -> Font:
	return CJKFontHelper.get_font()

func _apply_cjk_font_to_node(node: Node) -> void:
	CJKFontHelper.apply_to_node_recursive(node, _get_cjk_font())

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

func _move_type_label(move_type: String) -> String:
	match move_type:
		"cavalry":
			return "骑乘"
		"guard":
			return "重装"
		_:
			return "步行"

func _armor_type_label(armor_type: String) -> String:
	match armor_type:
		"light":
			return "轻甲"
		"heavy":
			return "重甲"
		_:
			return "中甲"

func _weapon_matchup_hint(weapon_type: String) -> String:
	match weapon_type:
		"sword":
			return "兵刃：克斧 / 惧枪"
		"axe":
			return "兵刃：克枪 / 惧剑"
		"lance":
			return "兵刃：克剑 / 惧斧"
		_:
			return "兵刃：均势"

func _class_summary(preview: Dictionary) -> String:
	return "兵种：%s · %s · %s" % [
		str(preview.get("class_display", preview.get("class", "步兵"))),
		_move_type_label(str(preview.get("move_type", "foot"))),
		_armor_type_label(str(preview.get("armor_type", "medium"))),
	]

func _trait_summary(preview: Dictionary) -> String:
	var trait_name := str(preview.get("trait_name", ""))
	var trait_desc := str(preview.get("trait_desc", ""))
	if trait_name == "" and trait_desc == "":
		return "兵种特性：暂无"
	if trait_desc == "":
		return "兵种特性：%s" % trait_name
	return "兵种特性：%s · %s" % [trait_name, trait_desc]

func _load_unit_preview(idx: int, entry: Dictionary) -> Dictionary:
	var file_name := str(entry.get("file", ""))
	var source_file := str(entry.get("base_file", file_name))
	var file_path: String = DATA_PATH + source_file
	var preview := {
		"file": file_name,
		"base_file": source_file,
		"name": str(entry.get("name", "北境骑士")),
		"class": str(entry.get("class", "骑士")),
		"role": str(entry.get("role", "职责：机动支援")),
		"summary": "斧D · 移动4\nHP30 武11 速8 防9",
		"mandatory": bool(entry.get("mandatory", false)),
		"portrait_path": str(entry.get("portrait_path", "")),
		"class_id": str(entry.get("class_id", "")),
		"move_type": str(entry.get("move_type", "foot")),
		"armor_type": str(entry.get("armor_type", "medium")),
		"trait_name": str(entry.get("trait_name", "")),
		"trait_desc": str(entry.get("trait_desc", "")),
		"matchup_hint": "兵刃：均势",
	}
	if FileAccess.file_exists(file_path):
		var f := FileAccess.open(file_path, FileAccess.READ)
		var result: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if result is Dictionary:
			var d := result as Dictionary
			var inferred_meta := ClassCatalog.get_unit_defaults(file_name, d)
			preview["name"] = str(d.get("name", preview["name"]))
			preview["class"] = str(d.get("class", preview["class"]))
			preview["class_id"] = str(inferred_meta.get("class_id", preview["class_id"]))
			preview["move_type"] = str(inferred_meta.get("move_type", preview["move_type"]))
			preview["armor_type"] = str(inferred_meta.get("armor_type", preview["armor_type"]))
			preview["matchup_hint"] = _weapon_matchup_hint(str(d.get("weapon_type", "sword")))
			preview["summary"] = "%s%s · 移动%d\nHP%d 武%d 速%d 防%d" % [
				_weapon_type_label(str(d.get("weapon_type", ""))),
				str(d.get("weapon_rank", "E")),
				int(d.get("move", 5)),
				int(d.get("max_hp", 20)),
				int(d.get("pow", 5)),
				int(d.get("spd", 5)),
				int(d.get("def", 5)),
			]
	for key: String in ["name", "class", "role", "portrait_path", "class_id", "move_type", "armor_type"]:
		if entry.has(key):
			preview[key] = entry[key]
	if entry.has("weapon_type"):
		preview["summary"] = "%s%s · 移动%d\nHP%d 武%d 速%d 防%d" % [
			_weapon_type_label(str(entry.get("weapon_type", ""))),
			str(entry.get("weapon_rank", "E")),
			int(entry.get("move", 5)),
			int(entry.get("max_hp", 20)),
			int(entry.get("pow", 5)),
			int(entry.get("spd", 5)),
			int(entry.get("def", 5)),
		]
	preview["matchup_hint"] = _weapon_matchup_hint(str(entry.get("weapon_type", "sword")))
	var class_template := ClassCatalog.get_class_template(str(preview.get("class_id", "")))
	preview["class_display"] = str(class_template.get("display_name", preview.get("class", "步兵")))
	preview["trait_name"] = str(class_template.get("trait_name", preview.get("trait_name", "")))
	preview["trait_desc"] = str(class_template.get("trait_desc", preview.get("trait_desc", "")))
	return preview

func _make_card_style(is_selected: bool, is_mandatory: bool) -> StyleBoxFlat:
	if is_selected:
		return BattleChromeTheme.make_panel_style(
			BattleChromeTheme.PANEL_SELECTED_BG,
			BattleChromeTheme.PANEL_SELECTED_BORDER,
			10,
			2,
			10
		)
	elif is_mandatory:
		return BattleChromeTheme.make_panel_style(
			BattleChromeTheme.PANEL_STEEL_BG,
			BattleChromeTheme.TEXT_MANDATORY,
			10,
			2,
			10
		)
	return BattleChromeTheme.make_panel_style(
		BattleChromeTheme.PANEL_BG,
		BattleChromeTheme.PANEL_BORDER,
		10,
		2,
		10
	)

func _refresh_card_visual(card: PanelContainer, idx: int, is_mandatory: bool) -> void:
	var is_selected := _selected.has(idx)
	card.add_theme_stylebox_override("panel", _make_card_style(is_selected, is_mandatory))
	var status_label := card.get_node_or_null("VBox/StatusLabel") as Label
	if status_label != null:
		if is_mandatory:
			status_label.text = "状态：固定出战"
			status_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_MANDATORY)
		elif is_selected:
			status_label.text = "状态：已编入突击队"
			status_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_READY)
		else:
			status_label.text = "状态：待命"
			status_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_MUTED)
	var select_btn := card.get_node_or_null("VBox/SelectBtn") as Button
	if select_btn != null:
		select_btn.text = "已选中" if is_selected else "选择"

func _refresh_deploy_summary() -> void:
	if _count_label != null:
		var selected_count := _selected.size()
		var summary_suffix := " · 建议至少 3 人稳住中轴与两翼"
		var color := BattleChromeTheme.TEXT_SECONDARY
		if selected_count >= 4:
			summary_suffix = " · 编组完整，可直接出发"
			color = BattleChromeTheme.TEXT_READY
		elif selected_count >= 3:
			summary_suffix = " · 编组较稳，已具攻城基本强度"
			color = BattleChromeTheme.TEXT_GOOD
		elif selected_count <= 1:
			color = BattleChromeTheme.TEXT_GUIDANCE
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
	step_num.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
	vb.add_child(step_num)

	var title := Label.new()
	title.name = "StepTitle"
	title.text = str(step_data.get("title", "阶段"))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)
	vb.add_child(title)

	var desc := Label.new()
	desc.name = "StepDesc"
	desc.text = str(step_data.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", BattleChromeTheme.TEXT_SECONDARY)
	vb.add_child(desc)

	return panel

func _ready() -> void:
	layer = 40
	_build_ui()
	_apply_dark_ui_theme()
	# 为所有动态创建的UI控件应用中文字体
	call_deferred("_apply_cjk_font_to_node", self)

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = BattleChromeTheme.BACKGROUND_COLOR
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.name = "LayoutRoot"
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 48.0
	scroll.offset_top = 24.0
	scroll.offset_right = -48.0
	scroll.offset_bottom = -24.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.offset_left = 160.0
	vbox.offset_top = 12.0
	vbox.offset_right = -160.0
	vbox.offset_bottom = 12.0
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# 标题
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "序章·四《铁王座》— 战前部署"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "奈德·史塔克自动参战。选择最多 %d 名北境骑士随行。" % MAX_KNIGHTS
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", BattleChromeTheme.TEXT_SECONDARY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var info_panel := PanelContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.custom_minimum_size = Vector2(0, 132)
	info_panel.add_theme_stylebox_override("panel", _make_section_style())
	vbox.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)

	var info_header := Label.new()
	info_header.name = "InfoHeader"
	info_header.text = "目标：红堡攻坚态势"
	_style_section_header(info_header)
	info_vbox.add_child(info_header)

	var premise_lbl := Label.new()
	premise_lbl.name = "PremiseLabel"
	premise_lbl.text = CHAPTER_PREMISE
	premise_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premise_lbl.add_theme_font_size_override("font_size", 13)
	premise_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)
	info_vbox.add_child(premise_lbl)

	var objective_lbl := Label.new()
	objective_lbl.name = "ObjectiveSummaryLabel"
	objective_lbl.text = OBJECTIVE_SUMMARY
	objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_lbl.add_theme_font_size_override("font_size", 13)
	objective_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	info_vbox.add_child(objective_lbl)

	var phase_lbl := Label.new()
	phase_lbl.name = "PhaseBadgeLabel"
	phase_lbl.text = Ch4BattleBrief.get_stage_badge(1)
	phase_lbl.add_theme_font_size_override("font_size", 12)
	phase_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
	info_vbox.add_child(phase_lbl)

	var faction_lbl := Label.new()
	faction_lbl.name = "FactionSummaryLabel"
	faction_lbl.text = FACTION_SUMMARY
	faction_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_lbl.add_theme_font_size_override("font_size", 12)
	faction_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GUIDANCE)
	info_vbox.add_child(faction_lbl)

	var deploy_lbl := Label.new()
	deploy_lbl.name = "DeploySummaryLabel"
	deploy_lbl.text = DEPLOY_SUMMARY
	deploy_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deploy_lbl.add_theme_font_size_override("font_size", 12)
	deploy_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GOOD)
	info_vbox.add_child(deploy_lbl)

	var battle_flow_panel := PanelContainer.new()
	battle_flow_panel.name = "BattleFlowPanel"
	battle_flow_panel.custom_minimum_size = Vector2(0, 196)
	battle_flow_panel.add_theme_stylebox_override("panel", _make_section_style())
	vbox.add_child(battle_flow_panel)

	var battle_flow_vbox := VBoxContainer.new()
	battle_flow_vbox.name = "BattleFlowVBox"
	battle_flow_vbox.add_theme_constant_override("separation", 8)
	battle_flow_panel.add_child(battle_flow_vbox)

	var flow_title := Label.new()
	flow_title.name = "FlowTitle"
	flow_title.text = "作战分段简报"
	_style_section_header(flow_title)
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
	advice_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)
	battle_flow_vbox.add_child(advice_label)

	var roster_panel := PanelContainer.new()
	roster_panel.name = "RosterPanel"
	roster_panel.add_theme_stylebox_override("panel", _make_summary_style())
	vbox.add_child(roster_panel)

	var roster_vbox := VBoxContainer.new()
	roster_vbox.name = "RosterVBox"
	roster_vbox.add_theme_constant_override("separation", 8)
	roster_panel.add_child(roster_vbox)

	var roster_header := Label.new()
	roster_header.name = "RosterHeader"
	roster_header.text = "推进：突击队编组"
	_style_section_header(roster_header)
	roster_vbox.add_child(roster_header)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_vbox.add_child(_count_label)

	# 单位卡片列表
	var grid := GridContainer.new()
	grid.name = "UnitGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	roster_vbox.add_child(grid)

	var available_units := _available_units()
	for i: int in available_units.size():
		var entry: Dictionary = available_units[i]
		var card := _make_unit_card(i, entry)
		grid.add_child(card)
		_unit_cards.append(card)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	roster_vbox.add_child(btn_row)

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
		name_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	vb.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.name = "ClassLabel"
	class_lbl.text = _class_summary(preview)
	class_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(class_lbl)

	var role_lbl := Label.new()
	role_lbl.name = "RoleLabel"
	role_lbl.text = str(preview.get("role", "职责：机动支援"))
	role_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GUIDANCE)
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(role_lbl)

	var stats_lbl := Label.new()
	stats_lbl.name = "StatsLabel"
	var stats_lbl_text := str(preview.get("summary", ""))
	stats_lbl.text = stats_lbl_text
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_SECONDARY)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats_lbl)

	var matchup_lbl := Label.new()
	matchup_lbl.name = "MatchupLabel"
	matchup_lbl.text = str(preview.get("matchup_hint", "兵刃：均势"))
	matchup_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	matchup_lbl.add_theme_font_size_override("font_size", 11)
	matchup_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
	matchup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(matchup_lbl)

	var trait_lbl := Label.new()
	trait_lbl.name = "TraitLabel"
	trait_lbl.text = _trait_summary(preview)
	trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_lbl.add_theme_font_size_override("font_size", 10)
	trait_lbl.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GOOD)
	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(trait_lbl)

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
		tag.add_theme_color_override("font_color", BattleChromeTheme.TEXT_MANDATORY)
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
	var available_units := _available_units()
	if idx >= 0 and idx < _unit_cards.size() and _unit_cards[idx] is PanelContainer:
		_refresh_card_visual(_unit_cards[idx] as PanelContainer, idx, bool((available_units[idx] as Dictionary).get("mandatory", false)))
	_refresh_deploy_summary()

func _on_new_game() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		load(SAVE_SYS_PATH).delete_save()
	get_tree().change_scene_to_file("res://scenes/Opening.tscn")

func _on_confirm() -> void:
	# 保存部署选择到 BattleBootstrap_Ch4
	var selections: Array[String] = ["ned_stark.json"]
	var available_units := _available_units()
	for idx: int in _selected:
		selections.append(str((available_units[idx] as Dictionary).get("file", "")))
	GameState.deploy_selection = selections
	get_tree().change_scene_to_file(BATTLE_SCENE)
