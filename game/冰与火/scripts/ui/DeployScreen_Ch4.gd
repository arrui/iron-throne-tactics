# DeployScreen_Ch4.gd — 序章·四部署画面
# 让玩家选择最多4名北境骑士参战（奈德自动参战）
extends CanvasLayer

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

var _selected: Array[int] = []  # 已选骑士的索引（不含奈德）
var _unit_cards: Array = []
var _confirm_btn: Button = null
var _count_label: Label = null

const CHAPTER_PREMISE := "君临已乱，兰尼斯特军（金色）暂持观望。你必须带着北境骑士穿过黑水桥、城墙与红堡中轴，尽快斩断残余王军指挥链。"
const OBJECTIVE_SUMMARY := "目标：沿中轴攻入红堡，击败王军指挥官后迫使兰军归降。"
const FACTION_SUMMARY := "态势：兰军当前中立，不会主动支援你；王军指挥官一倒，金袍与兰军将放弃抵抗。"
const DEPLOY_SUMMARY := "编组：奈德固定出战，最多再带 4 名北境骑士。建议尽量带满，以降低攻城轴线断裂风险。"

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

func _ready() -> void:
	layer = 40
	_build_ui()
	# 为所有动态创建的UI控件应用中文字体
	call_deferred("_apply_cjk_font_to_node", self)

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.08, 0.97)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left  = -360.0; vbox.offset_right  = 360.0
	vbox.offset_top   = -300.0; vbox.offset_bottom = 300.0
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "序章·四《铁王座》— 战前部署"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "奈德·史塔克自动参战。选择最多 %d 名北境骑士随行。" % MAX_KNIGHTS
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 132)
	vbox.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
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

	_count_label = Label.new()
	_count_label.text = "已选骑士：0 / %d" % MAX_KNIGHTS
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_count_label)

	# 单位卡片列表
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(grid)

	for i: int in AVAILABLE_UNITS.size():
		var entry: Dictionary = AVAILABLE_UNITS[i]
		var card := _make_unit_card(i, entry)
		grid.add_child(card)
		_unit_cards.append(card)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var new_game_btn := Button.new()
	new_game_btn.text = "↺ 新游戏（清除存档）"
	new_game_btn.custom_minimum_size = Vector2(200, 40)
	new_game_btn.pressed.connect(_on_new_game)
	btn_row.add_child(new_game_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "⚔ 确认部署出发"
	_confirm_btn.custom_minimum_size = Vector2(220, 48)
	_confirm_btn.disabled = true
	_confirm_btn.add_theme_font_size_override("font_size", 16)
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

func _make_unit_card(idx: int, entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 160)
	var vb := VBoxContainer.new()
	panel.add_child(vb)

	# 读取单位数据
	var file_path: String = DATA_PATH + entry["file"]
	var unit_name := "北境骑士"
	var unit_stats := ""
	var is_mandatory: bool = entry.get("mandatory", false)
	if FileAccess.file_exists(file_path):
		var f := FileAccess.open(file_path, FileAccess.READ)
		var result: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if result is Dictionary:
			var d := result as Dictionary
			unit_name = d.get("name", unit_name)
			unit_stats = "HP:%d  武:%d\n速:%d  防:%d" % [
				d.get("max_hp", 20), d.get("pow", 5),
				d.get("spd", 5), d.get("def", 5)]

	var name_lbl := Label.new()
	name_lbl.text = unit_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_mandatory:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vb.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = unit_stats
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vb.add_child(stats_lbl)

	if is_mandatory:
		var tag := Label.new()
		tag.text = "【必须参战】"
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tag)
	else:
		var select_btn := Button.new()
		select_btn.text = "选择"
		select_btn.name = "SelectBtn"
		select_btn.toggle_mode = true
		var ci := idx
		select_btn.toggled.connect(func(pressed: bool) -> void:
			_on_card_toggled(ci, pressed, select_btn))
		vb.add_child(select_btn)

	return panel

func _on_card_toggled(idx: int, pressed: bool, btn: Button) -> void:
	if pressed:
		if _selected.size() >= MAX_KNIGHTS:
			btn.button_pressed = false
			return
		_selected.append(idx)
	else:
		_selected.erase(idx)
	_count_label.text = "已选骑士：%d / %d" % [_selected.size(), MAX_KNIGHTS]
	_confirm_btn.disabled = _selected.is_empty()

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
