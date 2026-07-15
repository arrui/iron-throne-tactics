# BattleMap.gd — v5（FE GBA 核心操作：行走动画/取消移动/危险区/路径预览/Camera2D）
class_name BattleMap
extends Node2D

signal battle_won
signal battle_lost

const TILE_SIZE := 72
const CAM_SPEED := 520.0

const BATTLE_ANIM_SCENE  := preload("res://scenes/battle/BattleAnimation.tscn")
const GAME_OVER_PATH     := "res://scenes/ui/GameOver.tscn"
const SUPPORT_POPUP_PATH := "res://scenes/ui/SupportPopup.tscn"
const BattleChromeTheme := preload("res://scripts/ui/BattleChromeTheme.gd")

# 专用高亮层（在 TileLayer 之上、UnitLayer 之下）
@onready var _hl: Node2D = $HighlightLayer

enum Phase { PLAYER_TURN, ENEMY_TURN }
enum PlayerState { IDLE, UNIT_SELECTED, UNIT_MOVED, PREDICT }

# 地形类型常量
const TERRAIN_PLAIN  := 0
const TERRAIN_FOREST := 1
const TERRAIN_WALL   := 2
const TERRAIN_CLIFF  := 3
const TERRAIN_RIVER  := 4
const TERRAIN_SWAMP  := 5
const TERRAIN_BRIDGE := 6

var map_width  := 22
var map_height := 16
var victory_pos := Vector2i(17, 8)

var current_phase: Phase = Phase.PLAYER_TURN
var player_state: PlayerState = PlayerState.IDLE
var player_units: Array = []
var enemy_units:  Array = []

var selected_unit: Unit  = null
var target_enemy:  Unit  = null
var move_range:    Array[Vector2i] = []
var attack_tiles:  Array[Vector2i] = []

var _battle_over:      bool = false
var _animating_battle: bool = false
var _turn_ending:      bool = false  # 防止_check_all_acted重复进入

# ── FE GBA 新增状态 ─────────────────────────────────────
var _pre_move_pos:  Vector2i = Vector2i(-1, -1)  # 取消移动用
var _path_preview:  Array[Vector2i] = []          # 路径预览
var _last_hover:    Vector2i = Vector2i(-1, -1)   # 悬停跟踪
var _danger_tiles:  Dictionary = {}               # 敌方威胁格
var _show_danger:   bool = false                  # 危险区开关
var _turn_count:    int  = 1                      # 回合计数

# ── 敌方单位安全距离预览（点击敌方单位时显示）────────────
var _preview_enemy:        Unit             = null   # 当前被预览的敌方单位
var _preview_move_range:   Array[Vector2i] = []      # 其移动范围（橙色）
var _preview_attack_tiles: Array[Vector2i] = []      # 其攻击覆盖（红色）

# ── 自动托管（A 键切换，随时可中止）─────────────────────
var _autopilot:         bool  = false   # 是否启用自动托管
var _autopilot_running: bool  = false   # 协程正在运行中
var _autopilot_label:   Label = null    # UI 状态提示标签

# ── 小地图（M 键切换）────────────────────────────────────
var _minimap: MiniMap = null

# ── Camera2D ────────────────────────────────────────────
@onready var _cam: Camera2D = $Camera2D

# ── UI 节点引用 ──────────────────────────────────────────
var _turn_label:       Label         = null
var _phase_label:      Label         = null
var _objective_label:  Label         = null
var _guidance_label:   Label         = null
var _status_label:     Label         = null
var _terrain_label:    Label         = null
var _action_menu:      PanelContainer = null
var _atk_btn:          Button        = null
var _wait_btn:         Button        = null
var _cancel_move_btn:  Button        = null
var _predict_panel:    PanelContainer = null
var _atk_line:         Label         = null
var _def_line:         Label         = null
var _double_line:      Label         = null
var _confirm_btn:      Button        = null
var _cancel_btn:       Button        = null
var _result_panel:     PanelContainer = null
var _result_title:     Label         = null
var _result_msg:       Label         = null
var _restart_btn:      Button        = null
var _end_turn_btn:     Button        = null
var _items_btn:        Button        = null

# ── 道具面板（动态创建）──────────────────────────────────
var _active_items_panel: Control = null

# ── 支援追踪 ──────────────────────────────────────────────
const SUPPORT_C_THRESHOLD := 5
var _support_data:  Dictionary = {}   # key → adjacency count
var _support_popup_shown: Dictionary = {} # key → bool（弹窗只显示一次）

# ── 高亮颜色 ─────────────────────────────────────────────
const MOVEABLE_COLOR := Color(0.20, 0.50, 1.00, 0.26)  # 降低填充 alpha，让路径箭头更清晰
const SELECTED_COLOR := Color(1.00, 1.00, 0.20, 0.55)
const ATTACK_COLOR   := Color(1.00, 0.22, 0.16, 0.48)
const MOVED_COLOR    := Color(0.20, 0.90, 0.55, 0.52)
const VICTORY_COLOR  := Color(1.00, 0.85, 0.10, 0.48)
const DANGER_COLOR   := Color(1.00, 0.18, 0.08, 0.22)
const PATH_COLOR     := Color(1.00, 0.95, 0.15, 0.90)
# 敌方安全距离预览专用色
const ENEMY_MOVE_COLOR   := Color(0.92, 0.52, 0.10, 0.24)  # 橙色：敌方可移动格
const ENEMY_THREAT_COLOR := Color(1.00, 0.15, 0.10, 0.42)  # 深红：敌方攻击覆盖

# ════════════════════════════════════════════════════════
func _ready() -> void:
	# 确保战斗场景中的中文字体正确显示
	if DisplayServer.get_name() != "headless":
		_apply_battle_font()
	_bind_ui()
	_update_turn_label()
	_update_danger_zone()
	# 统一后的地图完全依赖程序化地形渲染，已不再需要旧 TileMap 贴图层。

var _cjk_font: Font = null

func _get_cjk_font() -> Font:
	if _cjk_font != null:
		return _cjk_font
	# 方案一：加载项目内置 Arial Unicode 字体（最可靠）
	const BUNDLED_FONT := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED_FONT):
		var ff := load(BUNDLED_FONT) as Font
		if ff != null:
			_cjk_font = ff
			return _cjk_font
	# 方案二：直接加载系统字体文件（优先 .ttf 格式）
	var os_font_paths := [
		"/System/Library/Fonts/Supplemental/Arial Unicode.ttf",  # macOS，含全套CJK
		"/Library/Fonts/Arial Unicode.ttf",           # macOS 备选路径
		"/System/Library/Fonts/STHeiti Medium.ttc",   # macOS 简体中文黑体
		"/System/Library/Fonts/Hiragino Sans GB.ttc", # macOS 备选
		"C:/Windows/Fonts/msyh.ttc",                  # Windows 微软雅黑
		"C:/Windows/Fonts/simhei.ttf",                # Windows 黑体
		"/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",  # Linux
	]
	for path in os_font_paths:
		if FileAccess.file_exists(path):
			var ff := load(path) as Font
			if ff != null:
				_cjk_font = ff
				return _cjk_font
	# 方案二：使用 SystemFont（名称匹配）
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Heiti SC",          # macOS 简体中文黑体（fc-list 确认名称）
		"Hiragino Sans GB",  # macOS 备选中文字体
		"Arial Unicode MS",  # 通用 Unicode 字体（含 CJK）
		"Microsoft YaHei",   # Windows 微软雅黑
		"PingFang SC",       # macOS 苹方（新版）
		"STHeitiSC-Medium",  # macOS 华文黑体（PostScript 名）
		"WenQuanYi Micro Hei", # Linux 文泉驿
		"Noto Sans CJK SC",  # Linux/Android Noto
	])
	_cjk_font = sf
	return _cjk_font

# 递归给所有 Label/Button 节点设置中文字体（最可靠的方案）
func _apply_font_to_controls(node: Node) -> void:
	if node is Label:
		(node as Label).add_theme_font_override("font", _get_cjk_font())
	elif node is Button:
		(node as Button).add_theme_font_override("font", _get_cjk_font())
	for child in node.get_children():
		_apply_font_to_controls(child)

func _apply_battle_font() -> void:
	var font := _get_cjk_font()
	ThemeDB.fallback_font      = font
	ThemeDB.fallback_font_size = 14
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font      = font
		theme.default_font_size = 14
	call_deferred("_apply_font_to_controls", self)
	call_deferred("_apply_dark_ui_theme")
	# 深色全局背景（GDD色盘：接近黑）
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.05))

# 深色 UI 主题（GDD色盘：铁灰 + 烛珀高亮）
func _apply_dark_ui_theme() -> void:
	BattleChromeTheme.apply_dark_chrome_recursive(self)
	var action_menu := get_node_or_null("UI/ActionMenu") as PanelContainer
	if action_menu != null:
		action_menu.add_theme_stylebox_override("panel",
			BattleChromeTheme.make_panel_style(
				BattleChromeTheme.PANEL_HIGHLIGHT_BG,
				BattleChromeTheme.PANEL_HIGHLIGHT_BORDER,
				6,
				1,
				8
			)
		)
		var attack_btn := action_menu.get_node_or_null("VBox/AttackBtn") as Button
		var items_btn := action_menu.get_node_or_null("VBox/ItemsBtn") as Button
		var cancel_move_btn := action_menu.get_node_or_null("VBox/CancelMoveBtn") as Button
		if attack_btn != null:
			BattleChromeTheme.apply_button_palette(
				attack_btn,
				BattleChromeTheme.BUTTON_DANGER_BG,
				BattleChromeTheme.BUTTON_DANGER_BORDER,
				BattleChromeTheme.TEXT_STATUS
			)
		if items_btn != null:
			BattleChromeTheme.apply_button_palette(
				items_btn,
				BattleChromeTheme.BUTTON_SUPPORT_BG,
				BattleChromeTheme.BUTTON_SUPPORT_BORDER,
				BattleChromeTheme.TEXT_GOOD
			)
		if cancel_move_btn != null:
			BattleChromeTheme.apply_button_palette(
				cancel_move_btn,
				BattleChromeTheme.BUTTON_MUTED_BG,
				BattleChromeTheme.BUTTON_MUTED_BORDER,
				BattleChromeTheme.TEXT_MUTED
			)
	var predict_panel := get_node_or_null("UI/PredictPanel") as PanelContainer
	if predict_panel != null:
		predict_panel.add_theme_stylebox_override("panel",
			BattleChromeTheme.make_panel_style(
				BattleChromeTheme.PANEL_STEEL_BG,
				BattleChromeTheme.PANEL_STEEL_BORDER,
				6,
				2,
				12
			)
		)
		var predict_title := predict_panel.get_node_or_null("VBox/Title") as Label
		var predict_atk_line := predict_panel.get_node_or_null("VBox/AtkLine") as Label
		var predict_def_line := predict_panel.get_node_or_null("VBox/DefLine") as Label
		var predict_double_line := predict_panel.get_node_or_null("VBox/DoubleLine") as Label
		var predict_confirm_btn := predict_panel.get_node_or_null("VBox/Buttons/ConfirmBtn") as Button
		if predict_title != null:
			predict_title.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
		if predict_atk_line != null:
			predict_atk_line.add_theme_color_override("font_color", BattleChromeTheme.TEXT_STATUS)
		if predict_def_line != null:
			predict_def_line.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GUIDANCE)
		if predict_double_line != null:
			predict_double_line.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
		if predict_confirm_btn != null:
			BattleChromeTheme.apply_button_palette(
				predict_confirm_btn,
				BattleChromeTheme.BUTTON_DANGER_BG,
				BattleChromeTheme.BUTTON_DANGER_BORDER,
				BattleChromeTheme.TEXT_STATUS
			)
	var result_state_won := true
	var result_title := get_node_or_null("UI/ResultPanel/VBox/ResultTitle") as Label
	if result_title != null and result_title.text == "败北":
		result_state_won = false
	_apply_result_state_theme(result_state_won)
	var top_info_panel := get_node_or_null("UI/TopInfoPanel") as PanelContainer
	if top_info_panel != null:
		top_info_panel.add_theme_stylebox_override("panel",
			BattleChromeTheme.make_panel_style(
				BattleChromeTheme.PANEL_HIGHLIGHT_BG,
				BattleChromeTheme.PANEL_HIGHLIGHT_BORDER,
				6,
				1,
				10
			)
		)

func _apply_result_state_theme(won: bool) -> void:
	var result_panel := get_node_or_null("UI/ResultPanel") as PanelContainer
	if result_panel == null:
		return
	var panel_bg := BattleChromeTheme.PANEL_HIGHLIGHT_BG if won else BattleChromeTheme.PANEL_DANGER_BG
	var panel_border := BattleChromeTheme.PANEL_HIGHLIGHT_BORDER if won else BattleChromeTheme.PANEL_DANGER_BORDER
	result_panel.add_theme_stylebox_override("panel",
		BattleChromeTheme.make_panel_style(panel_bg, panel_border, 8, 2, 14)
	)
	var result_title := result_panel.get_node_or_null("VBox/ResultTitle") as Label
	var result_msg := result_panel.get_node_or_null("VBox/ResultMsg") as Label
	if result_title != null:
		result_title.add_theme_color_override("font_color",
			BattleChromeTheme.TEXT_ACCENT if won else BattleChromeTheme.TEXT_STATUS)
	if result_msg != null:
		result_msg.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)

func _apply_dark_style_recursive(
		node: Node,
		panel_s: StyleBoxFlat, btn_n: StyleBoxFlat,
		btn_h: StyleBoxFlat,   btn_p: StyleBoxFlat) -> void:
	if node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override("panel", panel_s)
	if node is Button:
		var b := node as Button
		b.add_theme_stylebox_override("normal",   btn_n)
		b.add_theme_stylebox_override("hover",    btn_h)
		b.add_theme_stylebox_override("pressed",  btn_p)
		b.add_theme_stylebox_override("focus",    btn_h)
		b.add_theme_color_override("font_color",          Color(0.92, 0.88, 0.76))
		b.add_theme_color_override("font_hover_color",    Color(1.00, 0.96, 0.82))
		b.add_theme_color_override("font_pressed_color",  Color(1.00, 0.90, 0.50))
	if node is Label and node.get_parent() is PanelContainer:
		(node as Label).add_theme_color_override("font_color", Color(0.90, 0.88, 0.78))
	for child in node.get_children():
		_apply_dark_style_recursive(child, panel_s, btn_n, btn_h, btn_p)

# 每次触发重绘时同步刷新高亮层
func _redraw_all() -> void:
	queue_redraw()
	if is_instance_valid(_hl):
		_hl.queue_redraw()

# ── 每帧：摄像机滚动 + 悬停更新 ─────────────────────────
func _process(delta: float) -> void:
	if not _battle_over:
		_handle_cam_scroll(delta)
	_update_hover()

# ── 摄像机（方向键控制）──────────────────────────────────
func _handle_cam_scroll(delta: float) -> void:
	if not is_instance_valid(_cam): return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):  dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_UP):    dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN):  dir.y += 1
	if dir != Vector2.ZERO:
		_cam.position += dir.normalized() * CAM_SPEED * delta

func _scroll_to_show(grid_pos: Vector2i) -> void:
	if not is_instance_valid(_cam): return
	var tween := create_tween()
	tween.tween_property(_cam, "position", _g2p(grid_pos), 0.22)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ── 坐标转换：地图格 → 屏幕位置（供 CanvasLayer 用）──────
func _tile_to_screen(grid_pos: Vector2i) -> Vector2:
	return get_viewport().get_canvas_transform() * to_global(_g2p(grid_pos))

# ── UI 绑定 ──────────────────────────────────────────────
func _find_ui_node(node_name: String) -> Node:
	var ui := get_node_or_null("UI")
	if ui == null:
		return null
	return ui.find_child(node_name, true, false)

func _bind_ui() -> void:
	_turn_label    = _find_ui_node("TurnLabel") as Label
	_phase_label   = _find_ui_node("PhaseLabel") as Label
	_objective_label = _find_ui_node("ObjectiveLabel") as Label
	_guidance_label = _find_ui_node("GuidanceLabel") as Label
	_status_label  = _find_ui_node("StatusLabel") as Label
	_terrain_label = get_node_or_null("UI/TerrainLabel") as Label
	_action_menu   = get_node_or_null("UI/ActionMenu")   as PanelContainer
	_predict_panel = get_node_or_null("UI/PredictPanel") as PanelContainer
	_result_panel  = get_node_or_null("UI/ResultPanel")  as PanelContainer
	_end_turn_btn  = get_node_or_null("UI/EndTurnBtn")   as Button

	if _action_menu:
		_atk_btn         = _action_menu.get_node_or_null("VBox/AttackBtn")    as Button
		_wait_btn        = _action_menu.get_node_or_null("VBox/WaitBtn")      as Button
		_cancel_move_btn = _action_menu.get_node_or_null("VBox/CancelMoveBtn") as Button
		if _atk_btn and not _atk_btn.pressed.is_connected(_on_attack_pressed):
			_atk_btn.pressed.connect(_on_attack_pressed)
		if _wait_btn and not _wait_btn.pressed.is_connected(_on_wait_pressed):
			_wait_btn.pressed.connect(_on_wait_pressed)
		if _cancel_move_btn and not _cancel_move_btn.pressed.is_connected(_on_cancel_move_pressed):
			_cancel_move_btn.pressed.connect(_on_cancel_move_pressed)
		_items_btn = _action_menu.get_node_or_null("VBox/ItemsBtn") as Button
		if _items_btn and not _items_btn.pressed.is_connected(_on_items_pressed):
			_items_btn.pressed.connect(_on_items_pressed)

	if _predict_panel:
		_atk_line    = _predict_panel.get_node_or_null("VBox/AtkLine")             as Label
		_def_line    = _predict_panel.get_node_or_null("VBox/DefLine")             as Label
		_double_line = _predict_panel.get_node_or_null("VBox/DoubleLine")          as Label
		_confirm_btn = _predict_panel.get_node_or_null("VBox/Buttons/ConfirmBtn")  as Button
		_cancel_btn  = _predict_panel.get_node_or_null("VBox/Buttons/CancelBtn")   as Button
		if _confirm_btn and not _confirm_btn.pressed.is_connected(_on_confirm_attack):
			_confirm_btn.pressed.connect(_on_confirm_attack)
		if _cancel_btn and not _cancel_btn.pressed.is_connected(_on_cancel_attack):
			_cancel_btn.pressed.connect(_on_cancel_attack)

	if _result_panel:
		_result_title = _result_panel.get_node_or_null("VBox/ResultTitle") as Label
		_result_msg   = _result_panel.get_node_or_null("VBox/ResultMsg")   as Label
		_restart_btn  = _result_panel.get_node_or_null("VBox/RestartBtn")  as Button
		if _restart_btn and not _restart_btn.pressed.is_connected(_restart):
			_restart_btn.pressed.connect(_restart)

	if _end_turn_btn and not _end_turn_btn.pressed.is_connected(_on_end_turn_pressed):
		_end_turn_btn.pressed.connect(_on_end_turn_pressed)

	# 自动托管状态标签（右下角，EndTurnBtn旁）
	call_deferred("_setup_autopilot_ui")
	call_deferred("_setup_minimap")

func _setup_minimap() -> void:
	_minimap = MiniMap.new()
	add_child(_minimap)
	_minimap.setup(self)

func _setup_autopilot_ui() -> void:
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer == null: return
	_autopilot_label = Label.new()
	_autopilot_label.text = ""
	_autopilot_label.add_theme_font_size_override("font_size", 13)
	_autopilot_label.add_theme_font_override("font", _get_cjk_font())
	_autopilot_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.55))
	# 定位：右上角，EndTurnBtn 正下方
	_autopilot_label.anchor_left   = 1.0; _autopilot_label.anchor_right  = 1.0
	_autopilot_label.offset_left   = -168.0; _autopilot_label.offset_right  = -6.0
	_autopilot_label.offset_top    = 44.0;   _autopilot_label.offset_bottom = 64.0
	_autopilot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_layer.add_child(_autopilot_label)

# ── 程序化地形背景渲染（GDD暗色系，替代Q版PNG瓦片）─────────
func _draw() -> void:
	_draw_terrain_bg()

func _draw_terrain_bg() -> void:
	if map_width <= 0 or map_height <= 0: return
	var guidance_path: Array[Vector2i] = _find_objective_guidance_path()
	# 全图深色底（覆盖摄像机滚动区域边缘）
	draw_rect(Rect2(-TILE_SIZE * 2, -TILE_SIZE * 2,
		(map_width + 4) * TILE_SIZE, (map_height + 4) * TILE_SIZE),
		Color(0.05, 0.05, 0.05))
	# 逐格绘制地形色块
	for y: int in map_height:
		for x: int in map_width:
			var pos  := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var terrain := _get_terrain_type(pos)
			var col  := _terrain_draw_color(terrain)
			# 棋盘微变色——增加视觉深度
			if (x + y) % 2 == 1:
				col = col.darkened(0.07)
			draw_rect(rect, col)
			_draw_terrain_detail(rect, terrain, x, y)
			_draw_main_axis_guidance(rect, pos, guidance_path)
			_draw_objective_guidance(rect, pos)
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.25), false, 1.0)  # 格线
	# 地图边框（烛珀色）
	draw_rect(Rect2(0, 0, map_width * TILE_SIZE, map_height * TILE_SIZE),
		Color(0.60, 0.50, 0.28, 0.75), false, 2.5)

func _terrain_draw_color(terrain: int) -> Color:
	match terrain:
		TERRAIN_PLAIN:  return Color(0.22, 0.20, 0.16)  # 暗石板路
		TERRAIN_FOREST: return Color(0.10, 0.18, 0.08)  # 深绿树林
		TERRAIN_WALL:   return Color(0.30, 0.24, 0.14)  # 石砖城墙
		TERRAIN_CLIFF:  return Color(0.08, 0.08, 0.08)  # 近黑峭壁
		TERRAIN_RIVER:  return Color(0.08, 0.12, 0.28)  # 深蓝河流
		TERRAIN_SWAMP:  return Color(0.12, 0.16, 0.08)  # 沼泽暗绿
		TERRAIN_BRIDGE: return Color(0.30, 0.24, 0.16)  # 石桥
		_:              return Color(0.16, 0.16, 0.14)

func _draw_terrain_detail(rect: Rect2, terrain: int, x: int, y: int) -> void:
	match terrain:
		TERRAIN_PLAIN:
			_draw_plain_detail(rect, x, y)
		TERRAIN_FOREST:
			_draw_forest_detail(rect, x, y)
		TERRAIN_WALL:
			_draw_wall_detail(rect, x, y)
		TERRAIN_CLIFF:
			_draw_cliff_detail(rect, x, y)
		TERRAIN_RIVER:
			_draw_river_detail(rect, x, y)
		TERRAIN_SWAMP:
			_draw_swamp_detail(rect, x, y)
		TERRAIN_BRIDGE:
			_draw_bridge_detail(rect, x, y)

func _terrain_at_or_cliff(x: int, y: int) -> int:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return TERRAIN_CLIFF
	return _get_terrain_type(Vector2i(x, y))

func _adjacent_terrain_count(x: int, y: int, terrain: int) -> int:
	var count := 0
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if _terrain_at_or_cliff(x + d.x, y + d.y) == terrain:
			count += 1
	return count

func _bridge_runs_vertical(x: int, y: int) -> bool:
	var side_river := 0
	var vertical_river := 0
	if _terrain_at_or_cliff(x - 1, y) == TERRAIN_RIVER:
		side_river += 1
	if _terrain_at_or_cliff(x + 1, y) == TERRAIN_RIVER:
		side_river += 1
	if _terrain_at_or_cliff(x, y - 1) == TERRAIN_RIVER:
		vertical_river += 1
	if _terrain_at_or_cliff(x, y + 1) == TERRAIN_RIVER:
		vertical_river += 1
	return side_river >= vertical_river

func _bridge_end_mask(x: int, y: int) -> Dictionary:
	return {
		"north": _terrain_at_or_cliff(x, y - 1) != TERRAIN_RIVER and _terrain_at_or_cliff(x, y - 1) != TERRAIN_BRIDGE,
		"south": _terrain_at_or_cliff(x, y + 1) != TERRAIN_RIVER and _terrain_at_or_cliff(x, y + 1) != TERRAIN_BRIDGE,
		"west": _terrain_at_or_cliff(x - 1, y) != TERRAIN_RIVER and _terrain_at_or_cliff(x - 1, y) != TERRAIN_BRIDGE,
		"east": _terrain_at_or_cliff(x + 1, y) != TERRAIN_RIVER and _terrain_at_or_cliff(x + 1, y) != TERRAIN_BRIDGE,
	}

func _find_guidance_anchor_start() -> Vector2i:
	if map_width <= 0 or map_height <= 0:
		return victory_pos
	var clamped_goal_x := clampi(victory_pos.x, 0, map_width - 1)
	for y: int in range(map_height - 2, -1, -1):
		for offset: int in range(0, map_width):
			var left_x := clamped_goal_x - offset
			if left_x >= 0:
				var left := Vector2i(left_x, y)
				if is_passable(left):
					return left
			if offset == 0:
				continue
			var right_x := clamped_goal_x + offset
			if right_x < map_width:
				var right := Vector2i(right_x, y)
				if is_passable(right):
					return right
	return victory_pos

func _guidance_step_cost(pos: Vector2i) -> int:
	match _get_terrain_type(pos):
		TERRAIN_BRIDGE:
			return 1
		TERRAIN_PLAIN:
			return 1
		TERRAIN_FOREST:
			return 2
		TERRAIN_SWAMP:
			return 4
		TERRAIN_WALL:
			return 8
		_:
			return 1

func _find_objective_guidance_path() -> Array[Vector2i]:
	if map_width <= 0 or map_height <= 0:
		return []
	if not is_passable(victory_pos):
		return []
	var start := _find_guidance_anchor_start()
	if start == victory_pos:
		return [victory_pos]
	var came_from: Dictionary = {}
	var cost_map: Dictionary = {}
	var open: Array = [{"pos": start, "c": 0}]
	cost_map[start] = 0
	while not open.is_empty():
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["c"] < b["c"])
		var curr: Dictionary = open.pop_front()
		var pos: Vector2i = curr["pos"]
		if pos == victory_pos:
			break
		for d: Vector2i in [Vector2i(0,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,1)]:
			var npos: Vector2i = pos + d
			if not is_passable(npos):
				continue
			var step_cost := _guidance_step_cost(npos) * 10 + absi(npos.x - victory_pos.x) * 40
			var nc: int = int(cost_map[pos]) + step_cost
			if not cost_map.has(npos) or nc < int(cost_map[npos]):
				cost_map[npos] = nc
				came_from[npos] = pos
				open.append({"pos": npos, "c": nc})
	if not came_from.has(victory_pos):
		return []
	var path: Array[Vector2i] = []
	var cur: Vector2i = victory_pos
	path.push_front(cur)
	while cur != start:
		if not came_from.has(cur):
			return []
		cur = came_from[cur]
		path.push_front(cur)
	if not path.is_empty() and path[0] == start:
		path.remove_at(0)
	return path

func _draw_main_axis_guidance(rect: Rect2, pos: Vector2i, guidance_path: Array[Vector2i]) -> void:
	var idx := guidance_path.find(pos)
	if idx == -1:
		return
	var center := rect.get_center()
	var path_glow := Color(0.90, 0.76, 0.46, 0.08)
	var path_line := Color(0.94, 0.82, 0.56, 0.18)
	draw_circle(center, 10.0, path_glow)
	var inner := rect.grow(-18)
	draw_rect(inner, Color(0.88, 0.74, 0.48, 0.04))
	for neighbor_idx: int in [idx - 1, idx + 1]:
		if neighbor_idx < 0 or neighbor_idx >= guidance_path.size():
			continue
		var neighbor: Vector2i = guidance_path[neighbor_idx]
		var dir := neighbor - pos
		var end := center + Vector2(dir.x, dir.y) * (TILE_SIZE * 0.36)
		draw_line(center, end, path_line, 6.0, true)

func _draw_objective_guidance(rect: Rect2, pos: Vector2i) -> void:
	if pos != victory_pos:
		return
	var center := rect.get_center()
	var fill := Color(0.96, 0.86, 0.52, 0.08)
	var border := Color(0.98, 0.88, 0.60, 0.34)
	var inner := rect.grow(-10)
	draw_rect(inner, fill)
	draw_rect(inner, border, false, 2.0)
	draw_circle(center, 10.0, Color(0.98, 0.88, 0.60, 0.10))
	draw_line(Vector2(center.x, rect.position.y + 14), Vector2(center.x, rect.position.y + rect.size.y - 14), border, 2.0, true)
	draw_line(Vector2(rect.position.x + 14, center.y), Vector2(rect.position.x + rect.size.x - 14, center.y), border, 2.0, true)

func _nearest_wall_distance(x: int, y: int, dir: Vector2i, max_steps: int = 4) -> int:
	for step: int in range(1, max_steps + 1):
		var terrain := _terrain_at_or_cliff(x + dir.x * step, y + dir.y * step)
		if terrain == TERRAIN_WALL:
			return step
		if terrain == TERRAIN_CLIFF or terrain == TERRAIN_RIVER or terrain == TERRAIN_BRIDGE:
			return -1
	return -1

func _gate_runs_vertical(x: int, y: int) -> bool:
	var terrain := _terrain_at_or_cliff(x, y)
	if terrain == TERRAIN_WALL or terrain == TERRAIN_CLIFF or terrain == TERRAIN_RIVER or terrain == TERRAIN_BRIDGE:
		return false
	var north_terrain := _terrain_at_or_cliff(x, y - 1)
	var south_terrain := _terrain_at_or_cliff(x, y + 1)
	if north_terrain == TERRAIN_WALL or north_terrain == TERRAIN_CLIFF or north_terrain == TERRAIN_RIVER:
		return false
	if south_terrain == TERRAIN_WALL or south_terrain == TERRAIN_CLIFF or south_terrain == TERRAIN_RIVER:
		return false
	var left_wall_dist := _nearest_wall_distance(x, y, Vector2i(-1, 0))
	var right_wall_dist := _nearest_wall_distance(x, y, Vector2i(1, 0))
	return left_wall_dist > 0 and right_wall_dist > 0 and left_wall_dist + right_wall_dist <= 5

func _gate_runs_horizontal(x: int, y: int) -> bool:
	var terrain := _terrain_at_or_cliff(x, y)
	if terrain == TERRAIN_WALL or terrain == TERRAIN_CLIFF or terrain == TERRAIN_RIVER or terrain == TERRAIN_BRIDGE:
		return false
	var west_terrain := _terrain_at_or_cliff(x - 1, y)
	var east_terrain := _terrain_at_or_cliff(x + 1, y)
	if west_terrain == TERRAIN_WALL or west_terrain == TERRAIN_CLIFF or west_terrain == TERRAIN_RIVER:
		return false
	if east_terrain == TERRAIN_WALL or east_terrain == TERRAIN_CLIFF or east_terrain == TERRAIN_RIVER:
		return false
	var north_wall_dist := _nearest_wall_distance(x, y, Vector2i(0, -1))
	var south_wall_dist := _nearest_wall_distance(x, y, Vector2i(0, 1))
	return north_wall_dist > 0 and south_wall_dist > 0 and north_wall_dist + south_wall_dist <= 5

func _terrain_edge_mask(x: int, y: int, terrain: int) -> Dictionary:
	return {
		"north": _terrain_at_or_cliff(x, y - 1) != terrain,
		"south": _terrain_at_or_cliff(x, y + 1) != terrain,
		"west": _terrain_at_or_cliff(x - 1, y) != terrain,
		"east": _terrain_at_or_cliff(x + 1, y) != terrain,
	}

func _terrain_corner_mask(x: int, y: int, terrain: int) -> Dictionary:
	var edges := _terrain_edge_mask(x, y, terrain)
	return {
		"nw": bool(edges.get("north", false)) and bool(edges.get("west", false)),
		"ne": bool(edges.get("north", false)) and bool(edges.get("east", false)),
		"sw": bool(edges.get("south", false)) and bool(edges.get("west", false)),
		"se": bool(edges.get("south", false)) and bool(edges.get("east", false)),
	}

func _river_bank_mask(x: int, y: int) -> Dictionary:
	return {
		"north": _terrain_at_or_cliff(x, y - 1) != TERRAIN_RIVER and _terrain_at_or_cliff(x, y - 1) != TERRAIN_BRIDGE,
		"south": _terrain_at_or_cliff(x, y + 1) != TERRAIN_RIVER and _terrain_at_or_cliff(x, y + 1) != TERRAIN_BRIDGE,
		"west": _terrain_at_or_cliff(x - 1, y) != TERRAIN_RIVER and _terrain_at_or_cliff(x - 1, y) != TERRAIN_BRIDGE,
		"east": _terrain_at_or_cliff(x + 1, y) != TERRAIN_RIVER and _terrain_at_or_cliff(x + 1, y) != TERRAIN_BRIDGE,
	}

func _plain_wall_contact_mask(x: int, y: int) -> Dictionary:
	return {
		"north": _terrain_at_or_cliff(x, y - 1) == TERRAIN_WALL,
		"south": _terrain_at_or_cliff(x, y + 1) == TERRAIN_WALL,
		"west": _terrain_at_or_cliff(x - 1, y) == TERRAIN_WALL,
		"east": _terrain_at_or_cliff(x + 1, y) == TERRAIN_WALL,
	}

func _plain_wet_edge_mask(x: int, y: int) -> Dictionary:
	var mask := {}
	for spec: Array in [
		["north", Vector2i(0, -1)],
		["south", Vector2i(0, 1)],
		["west", Vector2i(-1, 0)],
		["east", Vector2i(1, 0)],
	]:
		var dir_name: String = spec[0]
		var delta: Vector2i = spec[1]
		var terrain := _terrain_at_or_cliff(x + delta.x, y + delta.y)
		if terrain == TERRAIN_RIVER or terrain == TERRAIN_SWAMP:
			mask[dir_name] = terrain
	return mask

func _draw_plain_detail(rect: Rect2, x: int, y: int) -> void:
	var wall_neighbors := _adjacent_terrain_count(x, y, TERRAIN_WALL)
	var river_neighbors := _adjacent_terrain_count(x, y, TERRAIN_RIVER)
	var swamp_neighbors := _adjacent_terrain_count(x, y, TERRAIN_SWAMP)
	var bridge_neighbors := _adjacent_terrain_count(x, y, TERRAIN_BRIDGE)
	var gate_vertical := bridge_neighbors == 0 and river_neighbors == 0 and _gate_runs_vertical(x, y)
	var gate_horizontal := bridge_neighbors == 0 and river_neighbors == 0 and _gate_runs_horizontal(x, y)
	var wall_contact := _plain_wall_contact_mask(x, y)
	var wet_edges := _plain_wet_edge_mask(x, y)
	var inset := 8.0
	var inner := rect.grow(-inset)
	var shade := 0.04 if (x + y) % 3 == 0 else 0.02
	draw_rect(inner, Color(0.28, 0.25, 0.20, shade))
	if wall_contact.get("north", false) and not gate_vertical:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, rect.size.x - 16, 8),
			Color(0.12, 0.10, 0.08, 0.18))
	if wall_contact.get("south", false) and not gate_vertical:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 16, rect.size.x - 16, 8),
			Color(0.10, 0.08, 0.06, 0.20))
	if wall_contact.get("west", false) and not gate_horizontal:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, 8, rect.size.y - 16),
			Color(0.12, 0.10, 0.08, 0.14))
	if wall_contact.get("east", false) and not gate_horizontal:
		draw_rect(Rect2(rect.position.x + rect.size.x - 16, rect.position.y + 8, 8, rect.size.y - 16),
			Color(0.10, 0.08, 0.06, 0.14))
	if wet_edges.get("north", -1) == TERRAIN_RIVER:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, rect.size.x - 16, 10),
			Color(0.10, 0.14, 0.20, 0.18))
	if wet_edges.get("south", -1) == TERRAIN_RIVER:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 18, rect.size.x - 16, 10),
			Color(0.08, 0.12, 0.18, 0.18))
	if wet_edges.get("north", -1) == TERRAIN_SWAMP:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, rect.size.x - 16, 10),
			Color(0.16, 0.18, 0.10, 0.18))
	if wet_edges.get("south", -1) == TERRAIN_SWAMP:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 18, rect.size.x - 16, 10),
			Color(0.14, 0.12, 0.08, 0.20))
	if wet_edges.get("west", -1) == TERRAIN_RIVER:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, 10, rect.size.y - 16),
			Color(0.10, 0.14, 0.20, 0.16))
	if wet_edges.get("east", -1) == TERRAIN_RIVER:
		draw_rect(Rect2(rect.position.x + rect.size.x - 18, rect.position.y + 8, 10, rect.size.y - 16),
			Color(0.08, 0.12, 0.18, 0.16))
	if wet_edges.get("west", -1) == TERRAIN_SWAMP:
		draw_rect(Rect2(rect.position.x + 8, rect.position.y + 8, 10, rect.size.y - 16),
			Color(0.16, 0.18, 0.10, 0.16))
	if wet_edges.get("east", -1) == TERRAIN_SWAMP:
		draw_rect(Rect2(rect.position.x + rect.size.x - 18, rect.position.y + 8, 10, rect.size.y - 16),
			Color(0.14, 0.12, 0.08, 0.16))
	if wall_neighbors >= 2:
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6,
			rect.size.x - 12, rect.size.y - 12), Color(0.42, 0.38, 0.32, 0.12))
		for i: int in 3:
			var yy := rect.position.y + 18 + i * 14
			draw_line(Vector2(rect.position.x + 10, yy), Vector2(rect.position.x + rect.size.x - 10, yy),
				Color(0.60, 0.56, 0.50, 0.12), 2.0, true)
		for i: int in 2:
			var xx := rect.position.x + 24 + i * 22
			draw_line(Vector2(xx, rect.position.y + 10), Vector2(xx, rect.position.y + rect.size.y - 10),
				Color(0.24, 0.22, 0.18, 0.10), 1.0, true)
	elif river_neighbors + swamp_neighbors > 0:
		draw_line(Vector2(rect.position.x + 10, rect.position.y + rect.size.y - 16),
			Vector2(rect.position.x + rect.size.x - 10, rect.position.y + rect.size.y - 22),
			Color(0.32, 0.26, 0.18, 0.22), 3.0, true)
		for i: int in 3:
			var rx := rect.position.x + 14 + i * 16 + float((x + i + y) % 5)
			draw_line(Vector2(rx, rect.position.y + 48), Vector2(rx + 1, rect.position.y + 32),
				Color(0.44, 0.46, 0.24, 0.30), 2.0, true)
	elif (x + y) % 2 == 0:
		draw_line(Vector2(rect.position.x + 12, rect.position.y + 18),
			Vector2(rect.position.x + rect.size.x - 12, rect.position.y + rect.size.y - 18),
			Color(0.42, 0.36, 0.28, 0.18), 2.0, true)
	else:
		draw_line(Vector2(rect.position.x + 16, rect.position.y + rect.size.y * 0.5),
			Vector2(rect.position.x + rect.size.x - 16, rect.position.y + rect.size.y * 0.5),
			Color(0.44, 0.38, 0.30, 0.15), 2.0, true)
	if bridge_neighbors > 0 and wall_neighbors == 0:
		draw_line(Vector2(rect.position.x + 12, rect.position.y + rect.size.y * 0.5),
			Vector2(rect.position.x + rect.size.x - 12, rect.position.y + rect.size.y * 0.5),
			Color(0.70, 0.60, 0.40, 0.10), 4.0, true)
	if bridge_neighbors > 0 and river_neighbors == 0:
		var bridge_vertical := false
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if _terrain_at_or_cliff(x + d.x, y + d.y) == TERRAIN_BRIDGE:
				bridge_vertical = _bridge_runs_vertical(x + d.x, y + d.y)
				break
		if bridge_vertical:
			if _terrain_at_or_cliff(x, y - 1) == TERRAIN_BRIDGE:
				draw_rect(Rect2(rect.position.x + 18, rect.position.y + 4, rect.size.x - 36, 10),
					Color(0.36, 0.30, 0.20, 0.20))
			if _terrain_at_or_cliff(x, y + 1) == TERRAIN_BRIDGE:
				draw_rect(Rect2(rect.position.x + 18, rect.position.y + rect.size.y - 14, rect.size.x - 36, 10),
					Color(0.18, 0.14, 0.10, 0.22))
		else:
			if _terrain_at_or_cliff(x - 1, y) == TERRAIN_BRIDGE:
				draw_rect(Rect2(rect.position.x + 4, rect.position.y + 18, 10, rect.size.y - 36),
					Color(0.36, 0.30, 0.20, 0.18))
			if _terrain_at_or_cliff(x + 1, y) == TERRAIN_BRIDGE:
				draw_rect(Rect2(rect.position.x + rect.size.x - 14, rect.position.y + 18, 10, rect.size.y - 36),
					Color(0.18, 0.14, 0.10, 0.20))
	if bridge_neighbors > 0 and wall_neighbors == 0 and river_neighbors == 0:
		var bridge_vertical := false
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if _terrain_at_or_cliff(x + d.x, y + d.y) == TERRAIN_BRIDGE:
				bridge_vertical = _bridge_runs_vertical(x + d.x, y + d.y)
				break
		if bridge_vertical:
			var center_x := rect.position.x + rect.size.x * 0.5
			draw_line(Vector2(center_x, rect.position.y + 10),
				Vector2(center_x, rect.position.y + rect.size.y - 10),
				Color(0.84, 0.74, 0.54, 0.22), 3.0, true)
			draw_line(Vector2(center_x - 10, rect.position.y + 16),
				Vector2(center_x - 10, rect.position.y + rect.size.y - 16),
				Color(0.54, 0.46, 0.30, 0.12), 2.0, true)
			draw_line(Vector2(center_x + 10, rect.position.y + 16),
				Vector2(center_x + 10, rect.position.y + rect.size.y - 16),
				Color(0.54, 0.46, 0.30, 0.12), 2.0, true)
		else:
			var center_y := rect.position.y + rect.size.y * 0.5
			draw_line(Vector2(rect.position.x + 10, center_y),
				Vector2(rect.position.x + rect.size.x - 10, center_y),
				Color(0.84, 0.74, 0.54, 0.22), 3.0, true)
			draw_line(Vector2(rect.position.x + 16, center_y - 10),
				Vector2(rect.position.x + rect.size.x - 16, center_y - 10),
				Color(0.54, 0.46, 0.30, 0.12), 2.0, true)
			draw_line(Vector2(rect.position.x + 16, center_y + 10),
				Vector2(rect.position.x + rect.size.x - 16, center_y + 10),
				Color(0.54, 0.46, 0.30, 0.12), 2.0, true)
	if gate_vertical:
		var threshold_y := rect.position.y + rect.size.y * 0.5
		draw_rect(Rect2(rect.position.x + 18, rect.position.y + 6, rect.size.x - 36, 6),
			Color(0.44, 0.36, 0.24, 0.18))
		draw_rect(Rect2(rect.position.x + 18, rect.position.y + rect.size.y - 12, rect.size.x - 36, 6),
			Color(0.12, 0.09, 0.06, 0.18))
		if wall_contact.get("north", false):
			draw_rect(Rect2(rect.position.x + 12, rect.position.y + 8, rect.size.x - 24, 6),
				Color(0.18, 0.14, 0.10, 0.18))
		if wall_contact.get("south", false):
			draw_rect(Rect2(rect.position.x + 12, rect.position.y + rect.size.y - 14, rect.size.x - 24, 6),
				Color(0.14, 0.10, 0.06, 0.16))
		if gate_vertical and wall_contact.get("west", false):
			draw_rect(Rect2(rect.position.x + 8, rect.position.y + 10, 8, rect.size.y - 20),
				Color(0.28, 0.22, 0.14, 0.22))
			draw_line(Vector2(rect.position.x + 15, rect.position.y + 12),
				Vector2(rect.position.x + 15, rect.position.y + rect.size.y - 12),
				Color(0.60, 0.50, 0.32, 0.16), 2.0, true)
		if gate_vertical and wall_contact.get("east", false):
			draw_rect(Rect2(rect.position.x + rect.size.x - 16, rect.position.y + 10, 8, rect.size.y - 20),
				Color(0.16, 0.12, 0.08, 0.24))
		draw_rect(Rect2(rect.position.x + 8, threshold_y - 5, rect.size.x - 16, 10),
			Color(0.12, 0.09, 0.06, 0.24))
		draw_line(Vector2(rect.position.x + 10, threshold_y - 2),
			Vector2(rect.position.x + rect.size.x - 10, threshold_y - 2),
			Color(0.74, 0.64, 0.44, 0.24), 2.0, true)
		draw_line(Vector2(rect.position.x + 10, threshold_y + 2),
			Vector2(rect.position.x + rect.size.x - 10, threshold_y + 2),
			Color(0.10, 0.08, 0.06, 0.20), 2.0, true)
		draw_line(Vector2(rect.position.x + 12, rect.position.y + 14),
			Vector2(rect.position.x + 12, rect.position.y + rect.size.y - 14),
			Color(0.16, 0.12, 0.08, 0.18), 2.0, true)
		draw_line(Vector2(rect.position.x + rect.size.x - 12, rect.position.y + 14),
			Vector2(rect.position.x + rect.size.x - 12, rect.position.y + rect.size.y - 14),
			Color(0.16, 0.12, 0.08, 0.18), 2.0, true)
	if gate_horizontal:
		var threshold_x := rect.position.x + rect.size.x * 0.5
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 18, 6, rect.size.y - 36),
			Color(0.44, 0.36, 0.24, 0.16))
		draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 18, 6, rect.size.y - 36),
			Color(0.12, 0.09, 0.06, 0.18))
		if wall_contact.get("west", false):
			draw_rect(Rect2(rect.position.x + 8, rect.position.y + 12, 6, rect.size.y - 24),
				Color(0.18, 0.14, 0.10, 0.16))
		if wall_contact.get("east", false):
			draw_rect(Rect2(rect.position.x + rect.size.x - 14, rect.position.y + 12, 6, rect.size.y - 24),
				Color(0.14, 0.10, 0.06, 0.16))
		if gate_horizontal and wall_contact.get("north", false):
			draw_rect(Rect2(rect.position.x + 10, rect.position.y + 8, rect.size.x - 20, 8),
				Color(0.28, 0.22, 0.14, 0.20))
			draw_line(Vector2(rect.position.x + 12, rect.position.y + 15),
				Vector2(rect.position.x + rect.size.x - 12, rect.position.y + 15),
				Color(0.60, 0.50, 0.32, 0.14), 2.0, true)
		if gate_horizontal and wall_contact.get("south", false):
			draw_rect(Rect2(rect.position.x + 10, rect.position.y + rect.size.y - 16, rect.size.x - 20, 8),
				Color(0.16, 0.12, 0.08, 0.22))
		draw_rect(Rect2(threshold_x - 5, rect.position.y + 8, 10, rect.size.y - 16),
			Color(0.12, 0.09, 0.06, 0.24))
		draw_line(Vector2(threshold_x - 2, rect.position.y + 10),
			Vector2(threshold_x - 2, rect.position.y + rect.size.y - 10),
			Color(0.74, 0.64, 0.44, 0.24), 2.0, true)
		draw_line(Vector2(threshold_x + 2, rect.position.y + 10),
			Vector2(threshold_x + 2, rect.position.y + rect.size.y - 10),
			Color(0.10, 0.08, 0.06, 0.20), 2.0, true)
		draw_line(Vector2(rect.position.x + 14, rect.position.y + 12),
			Vector2(rect.position.x + rect.size.x - 14, rect.position.y + 12),
			Color(0.16, 0.12, 0.08, 0.18), 2.0, true)
		draw_line(Vector2(rect.position.x + 14, rect.position.y + rect.size.y - 12),
			Vector2(rect.position.x + rect.size.x - 14, rect.position.y + rect.size.y - 12),
			Color(0.16, 0.12, 0.08, 0.18), 2.0, true)

func _draw_forest_detail(rect: Rect2, x: int, y: int) -> void:
	var tree_col := Color(0.16, 0.28, 0.14, 0.50)
	var trunk_col := Color(0.20, 0.14, 0.08, 0.35)
	var edges := _terrain_edge_mask(x, y, TERRAIN_FOREST)
	var corners := _terrain_corner_mask(x, y, TERRAIN_FOREST)
	draw_rect(Rect2(rect.position.x + 6, rect.position.y + 8, rect.size.x - 12, rect.size.y - 16),
		Color(0.06, 0.10, 0.05, 0.20))
	if edges.get("north", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, 12),
			Color(0.04, 0.08, 0.04, 0.22))
	if edges.get("south", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 18, rect.size.x - 12, 12),
			Color(0.05, 0.09, 0.04, 0.20))
	if edges.get("west", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 8, 12, rect.size.y - 16),
			Color(0.05, 0.09, 0.04, 0.18))
	if edges.get("east", false):
		draw_rect(Rect2(rect.position.x + rect.size.x - 18, rect.position.y + 8, 12, rect.size.y - 16),
			Color(0.05, 0.09, 0.04, 0.18))
	if corners.get("nw", false):
		draw_circle(rect.position + Vector2(12, 12), 9.0, Color(0.04, 0.08, 0.04, 0.24))
	if corners.get("ne", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, 12), 9.0, Color(0.04, 0.08, 0.04, 0.24))
	if corners.get("sw", false):
		draw_circle(rect.position + Vector2(12, rect.size.y - 12), 9.0, Color(0.04, 0.08, 0.04, 0.22))
	if corners.get("se", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), 9.0, Color(0.04, 0.08, 0.04, 0.22))
	var centers := [
		Vector2(rect.position.x + 20, rect.position.y + 22),
		Vector2(rect.position.x + 38 + float((x + y) % 6), rect.position.y + 30),
		Vector2(rect.position.x + 52, rect.position.y + 18 + float((x * 3 + y) % 10)),
	]
	for c: Vector2 in centers:
		draw_circle(c, 10.0, tree_col)
		draw_line(c + Vector2(0, 8), c + Vector2(0, 18), trunk_col, 2.0, true)

func _wall_corner_mask(x: int, y: int) -> Dictionary:
	var north_open := _terrain_at_or_cliff(x, y - 1) != TERRAIN_WALL
	var south_open := _terrain_at_or_cliff(x, y + 1) != TERRAIN_WALL
	var west_open := _terrain_at_or_cliff(x - 1, y) != TERRAIN_WALL
	var east_open := _terrain_at_or_cliff(x + 1, y) != TERRAIN_WALL
	return {
		"nw": north_open and west_open,
		"ne": north_open and east_open,
		"sw": south_open and west_open,
		"se": south_open and east_open,
	}

func _draw_wall_detail(rect: Rect2, x: int, y: int) -> void:
	var north_open := _terrain_at_or_cliff(x, y - 1) != TERRAIN_WALL
	var south_open := _terrain_at_or_cliff(x, y + 1) != TERRAIN_WALL
	var west_open := _terrain_at_or_cliff(x - 1, y) != TERRAIN_WALL
	var east_open := _terrain_at_or_cliff(x + 1, y) != TERRAIN_WALL
	var wall_run_horizontal := not west_open and not east_open
	var wall_run_vertical := not north_open and not south_open
	var corner_mask := _wall_corner_mask(x, y)
	var crenel_offset := float((x + y) % 2) * 4.0
	var top_band := Rect2(rect.position.x + 4, rect.position.y + 6, rect.size.x - 8, 12)
	var body := Rect2(rect.position.x + 4, rect.position.y + 18, rect.size.x - 8, rect.size.y - 24)
	draw_rect(body, Color(0.38, 0.31, 0.19, 0.35))
	draw_rect(top_band, Color(0.52, 0.44, 0.28, 0.45))
	if wall_run_horizontal:
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6 + crenel_offset, rect.size.x - 12, 4),
			Color(0.72, 0.64, 0.46, 0.18))
	if wall_run_vertical:
		draw_rect(Rect2(rect.position.x + 6 + crenel_offset, rect.position.y + 22, 4, rect.size.y - 30),
			Color(0.22, 0.18, 0.12, 0.12))
	if north_open:
		draw_line(Vector2(rect.position.x + 6, rect.position.y + 18), Vector2(rect.position.x + rect.size.x - 6, rect.position.y + 18),
			Color(0.82, 0.76, 0.60, 0.22), 2.0, true)
	if south_open:
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 12, rect.size.x - 12, 6),
			Color(0.08, 0.06, 0.04, 0.28))
	if west_open:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 20, 5, rect.size.y - 28),
			Color(0.18, 0.14, 0.10, 0.22))
	if east_open:
		draw_rect(Rect2(rect.position.x + rect.size.x - 9, rect.position.y + 20, 5, rect.size.y - 28),
			Color(0.10, 0.08, 0.06, 0.26))
	if corner_mask.get("nw", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 20, 10, 10), Color(0.72, 0.64, 0.46, 0.20))
	if corner_mask.get("ne", false):
		draw_rect(Rect2(rect.position.x + rect.size.x - 16, rect.position.y + 20, 10, 10), Color(0.70, 0.62, 0.44, 0.18))
	if corner_mask.get("sw", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 18, 10, 10), Color(0.18, 0.14, 0.10, 0.18))
	if corner_mask.get("se", false):
		draw_rect(Rect2(rect.position.x + rect.size.x - 16, rect.position.y + rect.size.y - 18, 10, 10), Color(0.10, 0.08, 0.06, 0.22))
	for i: int in 4:
		var bx := rect.position.x + 8 + i * 15
		draw_rect(Rect2(bx, rect.position.y + 8, 8, 8), Color(0.62, 0.56, 0.40, 0.75))
	for row_i: int in 2:
		for col_i: int in 3:
			var brick := Rect2(rect.position.x + 10 + col_i * 18 + float((row_i % 2) * 6), rect.position.y + 26 + row_i * 16, 14, 8)
			var brick_tint := 0.12 + float((x + row_i + col_i) % 3) * 0.03
			draw_rect(brick, Color(0.62, 0.54, 0.38, brick_tint))

func _cliff_corner_mask(x: int, y: int) -> Dictionary:
	var north_open := _terrain_at_or_cliff(x, y - 1) != TERRAIN_CLIFF
	var south_open := _terrain_at_or_cliff(x, y + 1) != TERRAIN_CLIFF
	var west_open := _terrain_at_or_cliff(x - 1, y) != TERRAIN_CLIFF
	var east_open := _terrain_at_or_cliff(x + 1, y) != TERRAIN_CLIFF
	return {
		"nw": north_open and west_open,
		"ne": north_open and east_open,
		"sw": south_open and west_open,
		"se": south_open and east_open,
	}

func _draw_cliff_detail(rect: Rect2, x: int, y: int) -> void:
	var shade := Color(0.18, 0.18, 0.18, 0.35)
	var corner_mask := _cliff_corner_mask(x, y)
	if _terrain_at_or_cliff(x, y - 1) != TERRAIN_CLIFF:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, rect.size.x - 8, 10),
			Color(0.42, 0.42, 0.38, 0.18))
		draw_line(Vector2(rect.position.x + 6, rect.position.y + 10),
			Vector2(rect.position.x + rect.size.x - 6, rect.position.y + 10),
			Color(0.72, 0.72, 0.66, 0.22), 2.0, true)
	if _terrain_at_or_cliff(x, y + 1) != TERRAIN_CLIFF:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + rect.size.y - 12, rect.size.x - 8, 8),
			Color(0.06, 0.06, 0.06, 0.26))
	if _terrain_at_or_cliff(x - 1, y) != TERRAIN_CLIFF:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 16, 8, rect.size.y - 20),
			Color(0.12, 0.12, 0.12, 0.24))
	if _terrain_at_or_cliff(x + 1, y) != TERRAIN_CLIFF:
		draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 16, 8, rect.size.y - 20),
			Color(0.08, 0.08, 0.08, 0.24))
	if corner_mask.get("nw", false):
		draw_circle(rect.position + Vector2(12, 12), 9.0, Color(0.32, 0.32, 0.30, 0.16))
	if corner_mask.get("ne", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, 12), 9.0, Color(0.30, 0.30, 0.28, 0.16))
	if corner_mask.get("sw", false):
		draw_circle(rect.position + Vector2(12, rect.size.y - 12), 9.0, Color(0.12, 0.12, 0.12, 0.18))
	if corner_mask.get("se", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), 9.0, Color(0.08, 0.08, 0.08, 0.22))
	for i: int in 4:
		var sx := rect.position.x + 10 + i * 14 + float((y + i) % 4)
		draw_line(Vector2(sx, rect.position.y + 8), Vector2(sx - 6, rect.position.y + rect.size.y - 8), shade, 2.0, true)

func _draw_river_detail(rect: Rect2, x: int, y: int) -> void:
	var horizontal_flow := _adjacent_terrain_count(x, y, TERRAIN_RIVER) >= 1 and _bridge_runs_vertical(x, y)
	var bridge_neighbors := _adjacent_terrain_count(x, y, TERRAIN_BRIDGE)
	var banks := _river_bank_mask(x, y)
	if horizontal_flow:
		for i: int in 3:
			var yy := rect.position.y + 18 + i * 14 + float((x + i * 2) % 6)
			draw_line(Vector2(rect.position.x + 8, yy), Vector2(rect.position.x + rect.size.x - 8, yy),
				Color(0.34, 0.52, 0.86, 0.26), 2.0, true)
	else:
		for i: int in 3:
			var xx := rect.position.x + 18 + i * 14 + float((y + i * 2) % 6)
			draw_line(Vector2(xx, rect.position.y + 8), Vector2(xx, rect.position.y + rect.size.y - 8),
				Color(0.34, 0.52, 0.86, 0.26), 2.0, true)
	if banks.get("north", false) and bridge_neighbors == 0:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, rect.size.x - 8, 8),
			Color(0.22, 0.18, 0.10, 0.16))
		draw_line(Vector2(rect.position.x + 4, rect.position.y + 6), Vector2(rect.position.x + rect.size.x - 4, rect.position.y + 6),
			Color(0.46, 0.36, 0.20, 0.28), 2.0, true)
	elif banks.get("north", false):
		draw_line(Vector2(rect.position.x + 4, rect.position.y + 6), Vector2(rect.position.x + rect.size.x - 4, rect.position.y + 6),
			Color(0.46, 0.36, 0.20, 0.24), 2.0, true)
	if banks.get("south", false) and bridge_neighbors == 0:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + rect.size.y - 12, rect.size.x - 8, 8),
			Color(0.10, 0.08, 0.06, 0.20))
		draw_line(Vector2(rect.position.x + 4, rect.position.y + rect.size.y - 6), Vector2(rect.position.x + rect.size.x - 4, rect.position.y + rect.size.y - 6),
			Color(0.18, 0.14, 0.08, 0.28), 2.0, true)
	elif banks.get("south", false):
		draw_line(Vector2(rect.position.x + 4, rect.position.y + rect.size.y - 6), Vector2(rect.position.x + rect.size.x - 4, rect.position.y + rect.size.y - 6),
			Color(0.18, 0.14, 0.08, 0.24), 2.0, true)
	if banks.get("west", false) and bridge_neighbors == 0:
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, 8, rect.size.y - 8),
			Color(0.18, 0.14, 0.08, 0.14))
		draw_line(Vector2(rect.position.x + 6, rect.position.y + 4), Vector2(rect.position.x + 6, rect.position.y + rect.size.y - 4),
			Color(0.38, 0.30, 0.16, 0.22), 2.0, true)
	elif banks.get("west", false):
		draw_line(Vector2(rect.position.x + 6, rect.position.y + 4), Vector2(rect.position.x + 6, rect.position.y + rect.size.y - 4),
			Color(0.38, 0.30, 0.16, 0.18), 2.0, true)
	if banks.get("east", false) and bridge_neighbors == 0:
		draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 4, 8, rect.size.y - 8),
			Color(0.10, 0.08, 0.06, 0.14))
		draw_line(Vector2(rect.position.x + rect.size.x - 6, rect.position.y + 4), Vector2(rect.position.x + rect.size.x - 6, rect.position.y + rect.size.y - 4),
			Color(0.16, 0.12, 0.08, 0.22), 2.0, true)
	elif banks.get("east", false):
		draw_line(Vector2(rect.position.x + rect.size.x - 6, rect.position.y + 4), Vector2(rect.position.x + rect.size.x - 6, rect.position.y + rect.size.y - 4),
			Color(0.16, 0.12, 0.08, 0.18), 2.0, true)
	if bridge_neighbors > 0 and horizontal_flow and banks.get("north", false):
		draw_rect(Rect2(rect.position.x + 12, rect.position.y + 4, rect.size.x - 24, 8),
			Color(0.28, 0.22, 0.14, 0.18))
	if bridge_neighbors > 0 and horizontal_flow and banks.get("south", false):
		draw_rect(Rect2(rect.position.x + 12, rect.position.y + rect.size.y - 12, rect.size.x - 24, 8),
			Color(0.14, 0.10, 0.06, 0.20))
	if bridge_neighbors > 0 and not horizontal_flow and banks.get("west", false):
		draw_rect(Rect2(rect.position.x + 4, rect.position.y + 12, 8, rect.size.y - 24),
			Color(0.28, 0.22, 0.14, 0.18))
	if bridge_neighbors > 0 and not horizontal_flow and banks.get("east", false):
		draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 12, 8, rect.size.y - 24),
			Color(0.14, 0.10, 0.06, 0.20))
	if bridge_neighbors > 0 and horizontal_flow:
		if _terrain_at_or_cliff(x - 1, y) == TERRAIN_BRIDGE:
			draw_rect(Rect2(rect.position.x + 2, rect.position.y + 8, 8, rect.size.y - 16),
				Color(0.04, 0.08, 0.16, 0.26))
			draw_line(Vector2(rect.position.x + 10, rect.position.y + 10),
				Vector2(rect.position.x + 10, rect.position.y + rect.size.y - 10),
				Color(0.64, 0.76, 0.96, 0.20), 2.0, true)
		if _terrain_at_or_cliff(x + 1, y) == TERRAIN_BRIDGE:
			draw_rect(Rect2(rect.position.x + rect.size.x - 10, rect.position.y + 8, 8, rect.size.y - 16),
				Color(0.04, 0.08, 0.16, 0.26))
			draw_line(Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 10),
				Vector2(rect.position.x + rect.size.x - 10, rect.position.y + rect.size.y - 10),
				Color(0.64, 0.76, 0.96, 0.20), 2.0, true)
	if bridge_neighbors > 0 and not horizontal_flow:
		if _terrain_at_or_cliff(x, y - 1) == TERRAIN_BRIDGE:
			draw_rect(Rect2(rect.position.x + 8, rect.position.y + 2, rect.size.x - 16, 8),
				Color(0.04, 0.08, 0.16, 0.26))
			draw_line(Vector2(rect.position.x + 10, rect.position.y + 10),
				Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 10),
				Color(0.64, 0.76, 0.96, 0.20), 2.0, true)
		if _terrain_at_or_cliff(x, y + 1) == TERRAIN_BRIDGE:
			draw_rect(Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 10, rect.size.x - 16, 8),
				Color(0.04, 0.08, 0.16, 0.26))
			draw_line(Vector2(rect.position.x + 10, rect.position.y + rect.size.y - 10),
				Vector2(rect.position.x + rect.size.x - 10, rect.position.y + rect.size.y - 10),
				Color(0.64, 0.76, 0.96, 0.20), 2.0, true)
	if (x + y) % 2 == 0:
		draw_arc(rect.get_center(), 18.0, 0.2, 1.7, 10, Color(0.62, 0.74, 0.96, 0.14), 2.0, true)

func _draw_swamp_detail(rect: Rect2, x: int, y: int) -> void:
	var puddle := Color(0.24, 0.30, 0.16, 0.35)
	var edges := _terrain_edge_mask(x, y, TERRAIN_SWAMP)
	var corners := _terrain_corner_mask(x, y, TERRAIN_SWAMP)
	if edges.get("north", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, 12),
			Color(0.16, 0.18, 0.10, 0.20))
	if edges.get("south", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 18, rect.size.x - 12, 12),
			Color(0.12, 0.10, 0.06, 0.26))
	if edges.get("west", false):
		draw_rect(Rect2(rect.position.x + 6, rect.position.y + 8, 12, rect.size.y - 16),
			Color(0.14, 0.12, 0.08, 0.18))
	if edges.get("east", false):
		draw_rect(Rect2(rect.position.x + rect.size.x - 18, rect.position.y + 8, 12, rect.size.y - 16),
			Color(0.14, 0.12, 0.08, 0.18))
	if corners.get("nw", false):
		draw_circle(rect.position + Vector2(12, 12), 10.0, Color(0.16, 0.18, 0.10, 0.18))
	if corners.get("ne", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, 12), 10.0, Color(0.16, 0.18, 0.10, 0.18))
	if corners.get("sw", false):
		draw_circle(rect.position + Vector2(12, rect.size.y - 12), 10.0, Color(0.12, 0.10, 0.06, 0.24))
	if corners.get("se", false):
		draw_circle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), 10.0, Color(0.12, 0.10, 0.06, 0.24))
	_draw_ellipse(Rect2(rect.position.x + 10, rect.position.y + 16, 24, 16), puddle)
	_draw_ellipse(Rect2(rect.position.x + 30, rect.position.y + 34, 26, 14), puddle.darkened(0.1))
	for i: int in 3:
		var rx := rect.position.x + 16 + i * 14 + float((x + y + i) % 4)
		draw_line(Vector2(rx, rect.position.y + 46), Vector2(rx + 2, rect.position.y + 26),
			Color(0.42, 0.50, 0.24, 0.30), 2.0, true)

func _draw_bridge_detail(rect: Rect2, x: int, y: int) -> void:
	var board_col := Color(0.56, 0.46, 0.30, 0.42)
	var rail_col := Color(0.74, 0.64, 0.42, 0.34)
	var center_col := Color(0.88, 0.78, 0.56, 0.22)
	var cap_col := Color(0.64, 0.58, 0.44, 0.28)
	var cap_shadow := Color(0.12, 0.08, 0.06, 0.18)
	var vertical_bridge := _bridge_runs_vertical(x, y)
	var bridge_ends := _bridge_end_mask(x, y)
	draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, rect.size.y - 12),
		Color(0.16, 0.10, 0.06, 0.12))
	if vertical_bridge:
		var center_x := rect.position.x + rect.size.x * 0.5
		for i: int in 4:
			var yy := rect.position.y + 10 + i * 14
			draw_line(Vector2(rect.position.x + 8, yy), Vector2(rect.position.x + rect.size.x - 8, yy), board_col, 3.0, true)
		draw_line(Vector2(rect.position.x + 10, rect.position.y + 8), Vector2(rect.position.x + 10, rect.position.y + rect.size.y - 8), rail_col, 2.0, true)
		draw_line(Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 8), Vector2(rect.position.x + rect.size.x - 10, rect.position.y + rect.size.y - 8), rail_col, 2.0, true)
		draw_line(Vector2(center_x, rect.position.y + 10), Vector2(center_x, rect.position.y + rect.size.y - 10), center_col, 2.0, true)
		if vertical_bridge and bridge_ends.get("north", false):
			draw_rect(Rect2(rect.position.x + 14, rect.position.y + 4, rect.size.x - 28, 8), cap_col)
			draw_line(Vector2(rect.position.x + 16, rect.position.y + 10),
				Vector2(rect.position.x + rect.size.x - 16, rect.position.y + 10),
				Color(0.82, 0.76, 0.62, 0.22), 2.0, true)
		if vertical_bridge and bridge_ends.get("south", false):
			draw_rect(Rect2(rect.position.x + 14, rect.position.y + rect.size.y - 12, rect.size.x - 28, 8), cap_shadow)
			draw_line(Vector2(rect.position.x + 16, rect.position.y + rect.size.y - 10),
				Vector2(rect.position.x + rect.size.x - 16, rect.position.y + rect.size.y - 10),
				Color(0.08, 0.06, 0.04, 0.22), 2.0, true)
	else:
		var center_y := rect.position.y + rect.size.y * 0.5
		for i: int in 4:
			var xx := rect.position.x + 10 + i * 14
			draw_line(Vector2(xx, rect.position.y + 8), Vector2(xx, rect.position.y + rect.size.y - 8), board_col, 3.0, true)
		draw_line(Vector2(rect.position.x + 8, rect.position.y + 10), Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 10), rail_col, 2.0, true)
		draw_line(Vector2(rect.position.x + 8, rect.position.y + rect.size.y - 10), Vector2(rect.position.x + rect.size.x - 8, rect.position.y + rect.size.y - 10), rail_col, 2.0, true)
		draw_line(Vector2(rect.position.x + 10, center_y), Vector2(rect.position.x + rect.size.x - 10, center_y), center_col, 2.0, true)
		if not vertical_bridge and bridge_ends.get("west", false):
			draw_rect(Rect2(rect.position.x + 4, rect.position.y + 14, 8, rect.size.y - 28), cap_col)
			draw_line(Vector2(rect.position.x + 10, rect.position.y + 16),
				Vector2(rect.position.x + 10, rect.position.y + rect.size.y - 16),
				Color(0.82, 0.76, 0.62, 0.22), 2.0, true)
		if not vertical_bridge and bridge_ends.get("east", false):
			draw_rect(Rect2(rect.position.x + rect.size.x - 12, rect.position.y + 14, 8, rect.size.y - 28), cap_shadow)
			draw_line(Vector2(rect.position.x + rect.size.x - 10, rect.position.y + 16),
				Vector2(rect.position.x + rect.size.x - 10, rect.position.y + rect.size.y - 16),
				Color(0.08, 0.06, 0.04, 0.22), 2.0, true)

func _draw_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var center := rect.get_center()
	points.append(center)
	colors.append(color)
	for i: int in 24:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(
			center.x + cos(angle) * rect.size.x * 0.5,
			center.y + sin(angle) * rect.size.y * 0.5
		))
		colors.append(color)
	draw_polygon(points, colors)

# ── 高亮绘制（由 HighlightLayer 调用，保证在地形之上、单位之下）────

# HighlightLayer.gd 的 _draw() 回调此方法
func _draw_highlights(canvas: Node2D) -> void:
	# 1. 危险区（最底层）
	if _show_danger:
		for pos: Vector2i in _danger_tiles.keys():
			_draw_tile_highlight(canvas, pos, DANGER_COLOR)

	# 1.5 敌方单位安全距离预览（点击敌方单位时显示）
	if _preview_enemy != null and is_instance_valid(_preview_enemy):
		# 攻击覆盖（深红，画在移动范围下方）
		for pos: Vector2i in _preview_attack_tiles:
			_draw_tile_highlight(canvas, pos, ENEMY_THREAT_COLOR)
		# 移动范围（橙色，画在攻击覆盖上方）
		for pos: Vector2i in _preview_move_range:
			_draw_tile_highlight(canvas, pos, ENEMY_MOVE_COLOR)
		# 单位所在格加亮边框标记
		_draw_tile_highlight(canvas, _preview_enemy.grid_pos,
			Color(ENEMY_MOVE_COLOR.r, ENEMY_MOVE_COLOR.g, ENEMY_MOVE_COLOR.b, 0.65))

	# 2. 胜利格
	_draw_tile_highlight(canvas, victory_pos, VICTORY_COLOR)

	# 3. 移动范围
	for pos: Vector2i in move_range:
		_draw_tile_highlight(canvas, pos, MOVEABLE_COLOR)

	# 4. 攻击范围
	for pos: Vector2i in attack_tiles:
		_draw_tile_highlight(canvas, pos, ATTACK_COLOR)

	# 5. 选中/已移动高亮
	if player_state == PlayerState.UNIT_MOVED and selected_unit != null:
		_draw_tile_highlight(canvas, selected_unit.grid_pos, MOVED_COLOR)
	elif selected_unit != null:
		_draw_tile_highlight(canvas, selected_unit.grid_pos, SELECTED_COLOR)

	# 6. 路径预览
	if not _path_preview.is_empty() and \
			player_state == PlayerState.UNIT_SELECTED and selected_unit != null:
		var from_pos := selected_unit.grid_pos
		for i: int in _path_preview.size():
			_draw_path_segment(canvas, from_pos, _path_preview[i],
				i == _path_preview.size() - 1)
			from_pos = _path_preview[i]

func _draw_tile_highlight(canvas: Node2D, pos: Vector2i, color: Color) -> void:
	var rect := Rect2(pos.x * TILE_SIZE, pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	canvas.draw_rect(rect, color)
	var bc := Color(color.r, color.g, color.b, minf(color.a * 3.0, 1.0))
	canvas.draw_rect(rect, bc, false, 2.5)

func _draw_path_segment(canvas: Node2D, from_pos: Vector2i, to_pos: Vector2i,
		is_last: bool) -> void:
	var fp := _g2p(from_pos)
	var tp := _g2p(to_pos)
	const SHADOW := Color(0.0, 0.0, 0.0, 0.75)
	canvas.draw_line(fp, tp, SHADOW,     10.0, true)
	canvas.draw_line(fp, tp, PATH_COLOR,  6.0, true)
	if is_last:
		var dir  := (tp - fp).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var tip  := tp + dir * 16.0
		var b1   := tp - dir * 6.0 + perp * 11.0
		var b2   := tp - dir * 6.0 - perp * 11.0
		canvas.draw_polygon(PackedVector2Array([
				tip + dir * 3.0, b1 + perp * 3.0, b2 - perp * 3.0]),
			PackedColorArray([SHADOW, SHADOW, SHADOW]))
		canvas.draw_polygon(PackedVector2Array([tip, b1, b2]),
			PackedColorArray([PATH_COLOR, PATH_COLOR, PATH_COLOR]))

# ── 地形系统 ─────────────────────────────────────────────
func _get_terrain_type(_pos: Vector2i) -> int:
	return TERRAIN_PLAIN

func is_passable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	var t: int = _get_terrain_type(pos)
	return t != TERRAIN_CLIFF and t != TERRAIN_RIVER

func get_terrain_move_cost(pos: Vector2i) -> int:
	match _get_terrain_type(pos):
		TERRAIN_FOREST: return 2
		TERRAIN_WALL:   return 2
		TERRAIN_SWAMP:  return 3
		_:              return 1

func get_terrain_bonus(pos: Vector2i) -> Dictionary:
	match _get_terrain_type(pos):
		TERRAIN_FOREST: return {"avoid": 20, "defense": 10}
		TERRAIN_WALL:   return {"avoid": 0,  "defense": 20}
		TERRAIN_SWAMP:  return {"avoid": 0,  "defense": -10}
		_:              return {"avoid": 0,  "defense": 0}

func get_terrain_name(pos: Vector2i) -> String:
	match _get_terrain_type(pos):
		TERRAIN_PLAIN:  return "平原"
		TERRAIN_FOREST: return "森林"
		TERRAIN_WALL:   return "矮墙"
		TERRAIN_CLIFF:  return "峭壁"
		TERRAIN_RIVER:  return "河流"
		TERRAIN_SWAMP:  return "沼泽"
		TERRAIN_BRIDGE: return "桥梁"
		_:              return "?"

# ── 危险区 ───────────────────────────────────────────────
func _update_danger_zone() -> void:
	_danger_tiles.clear()
	for enemy: Unit in enemy_units:
		if not is_instance_valid(enemy) or enemy.is_dead(): continue
		if enemy.team == 2: continue   # 跳过中立单位（不产生危险区）
		for pos: Vector2i in _calc_move_range(enemy):
			for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var ap: Vector2i = pos + d
				if is_passable(ap):
					_danger_tiles[ap] = true

# ── 悬停跟踪（路径预览 + 地形信息）─────────────────────
func _update_hover() -> void:
	if _animating_battle: return
	var hovered := _p2g(to_local(get_global_mouse_position()))
	if hovered == _last_hover: return
	_last_hover = hovered

	var in_bounds: bool = hovered.x >= 0 and hovered.x < map_width and \
		hovered.y >= 0 and hovered.y < map_height
	var panels_vis: bool = (_action_menu != null and _action_menu.visible) or \
		(_predict_panel != null and _predict_panel.visible)

	# 地形信息（底部标签，IDLE 状态）
	if not panels_vis and player_state == PlayerState.IDLE and \
			current_phase == Phase.PLAYER_TURN:
		if in_bounds:
			var t_name := get_terrain_name(hovered)
			var bonus  := get_terrain_bonus(hovered)
			var info   := "[%s]" % t_name
			if bonus["defense"] != 0:
				info += "  防御%+d%%" % bonus["defense"]
			if bonus["avoid"] != 0:
				info += "  回避+%d%%" % bonus["avoid"]
			for u: Unit in (player_units + enemy_units):
				if is_instance_valid(u) and u.grid_pos == hovered and not u.is_dead():
					var tag := "我" if u.team == 0 else ("中立" if u.team == 2 else "敌")
					info = "[%s] %s  HP:%d/%d    %s" % [
						tag, u.data.name, u.data.hp, u.data.max_hp, info]
					break
			_set_terrain_info(info)
		else:
			_set_terrain_info("")

	# 路径预览（UNIT_SELECTED 状态）
	if player_state == PlayerState.UNIT_SELECTED and selected_unit != null and in_bounds:
		if hovered in move_range:
			var new_path := _find_path_to(selected_unit, hovered)
			if new_path != _path_preview:
				_path_preview = new_path
				_redraw_all()
		else:
			if not _path_preview.is_empty():
				_path_preview.clear()
				_redraw_all()
	elif not _path_preview.is_empty():
		_path_preview.clear()
		_redraw_all()

# ── 路径查找（Dijkstra，考虑地形消耗）──────────────────
func _find_path_to(unit: Unit, target: Vector2i) -> Array[Vector2i]:
	if target == unit.grid_pos: return []
	var came_from: Dictionary = {}
	var cost_map:  Dictionary = {}
	var open: Array = [{"pos": unit.grid_pos, "c": 0}]
	cost_map[unit.grid_pos] = 0

	while not open.is_empty():
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["c"] < b["c"])
		var curr: Dictionary = open.pop_front()
		var pos: Vector2i = curr["pos"]
		if pos == target: break
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if not is_passable(npos): continue
			var blocker: Unit = _unit_at(npos, 0) if unit.team == 1 else _unit_at(npos, 1)
			if blocker != null: continue
			var nc: int = cost_map[pos] + get_terrain_move_cost(npos)
			if nc > unit.data.move: continue
			if not cost_map.has(npos) or nc < cost_map[npos]:
				cost_map[npos] = nc
				came_from[npos] = pos
				open.append({"pos": npos, "c": nc})

	if not came_from.has(target): return []
	var path: Array[Vector2i] = []
	var cur: Vector2i = target
	while cur != unit.grid_pos:
		path.push_front(cur)
		if not came_from.has(cur): return []
		cur = came_from[cur]
	return path

# ── 单位管理 ─────────────────────────────────────────────
func add_unit(unit: Unit) -> void:
	if unit.team == 0:
		player_units.append(unit)
	else:
		enemy_units.append(unit)
	get_node("UnitLayer").add_child(unit)
	unit.position = _g2p(unit.grid_pos)
	unit.unit_died.connect(_on_unit_died)
	var _font := _get_cjk_font()
	var lbl: Label = unit.get_node_or_null("Label") as Label
	if lbl:
		lbl.add_theme_font_override("font", _font)
		lbl.text = unit.data.name.substr(0, 1)
	var hp: Label = unit.get_node_or_null("HPLabel") as Label
	if hp:
		hp.add_theme_font_override("font", _font)
		hp.text = str(unit.data.hp)

func _g2p(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5,
				   pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func _p2g(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / TILE_SIZE), int(px.y / TILE_SIZE))

# ── 精灵朝向 ─────────────────────────────────────────────
func _set_unit_facing(unit: Unit, dir: Vector2i) -> void:
	if dir.x == 0: return
	var sprite := unit.get_node_or_null("Sprite") as Sprite2D
	if sprite == null: return
	# 我方默认朝右，敌方默认朝左
	sprite.flip_h = (unit.team == 0) == (dir.x < 0)

# ── 行走动画 ─────────────────────────────────────────────
func _do_move_animated(unit: Unit, target: Vector2i) -> void:
	# 安全检查：目标格被友方占据时拒绝移动
	var occupant: Unit = _unit_at(target, unit.team)
	if occupant != null and occupant != unit:
		return
	_pre_move_pos  = unit.grid_pos
	var path       := _find_path_to(unit, target)
	_animating_battle = true
	unit.mark_moved()
	move_range.clear()
	_path_preview.clear()
	_redraw_all()

	var prev_pos := _pre_move_pos
	for step: Vector2i in path:
		if not is_instance_valid(unit): break
		_set_unit_facing(unit, step - prev_pos)
		prev_pos = step
		unit.grid_pos = step
		var tw := create_tween()
		tw.tween_property(unit, "position", _g2p(step), 0.09)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		if is_instance_valid(unit): _redraw_all()

	_animating_battle = false
	attack_tiles = _adj_enemies(target)
	player_state = PlayerState.UNIT_MOVED
	_redraw_all()

	if attack_tiles.is_empty():
		_show_action_menu(target, false)
		var t_name := get_terrain_name(target)
		_set_status("%s 已移动  [%s]" % [unit.data.name, t_name])
	else:
		_show_action_menu(target, true)
	_on_player_unit_action_position_updated(unit)

# ── 输入 ─────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# D键：危险区切换
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_D:
			_show_danger = not _show_danger
			_redraw_all()
			_set_status("危险区 %s（D 键切换）" % ("已显示" if _show_danger else "已隐藏"))
			get_viewport().set_input_as_handled()
			return
		if key == KEY_M:
			if _minimap != null: _minimap.toggle()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_A:
			_toggle_autopilot()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE:
			# ESC 同时关闭自动托管
			if _autopilot:
				_autopilot = false
				_autopilot_running = false
				_update_autopilot_label()
				_set_status("自动托管已中止（ESC）")
				get_viewport().set_input_as_handled()
				return
			_handle_escape()
			get_viewport().set_input_as_handled()
			return

	# ── 敌方单位安全距离预览（任意回合均可点击查看）──────────
	# 放在回合检查之前，使敌方回合也能查看
	if not _battle_over and not _animating_battle:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if not (_action_menu and _action_menu.visible) \
					and not (_predict_panel and _predict_panel.visible):
				var clicked_ev := _p2g(to_local(get_global_mouse_position()))
				var enemy_ev   := _unit_at(clicked_ev, 1)
				if enemy_ev != null and not enemy_ev.is_dead():
					# 再次点击同一敌方单位 → 关闭预览
					if _preview_enemy == enemy_ev:
						_clear_enemy_preview(); _redraw_all(); _set_status("")
					else:
						_show_enemy_preview(enemy_ev)
					get_viewport().set_input_as_handled()
					return
				elif _preview_enemy != null:
					# 点击到非敌方格子 → 关闭预览（不 return，让后续逻辑继续）
					_clear_enemy_preview()
					_redraw_all()

	if _battle_over or _animating_battle or current_phase != Phase.PLAYER_TURN:
		return
	if _action_menu   and _action_menu.visible:   return
	if _predict_panel and _predict_panel.visible: return

	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var me := event as InputEventMouseButton
	var clicked: Vector2i = _p2g(to_local(get_global_mouse_position()))

	if me.button_index == MOUSE_BUTTON_LEFT:
		match player_state:
			PlayerState.IDLE:
				_try_select(clicked)
			PlayerState.UNIT_SELECTED:
				if clicked == selected_unit.grid_pos:
					# 左键点击已选单位格 = 原地行动菜单
					_open_in_place_menu()
				elif clicked in move_range:
					_do_move_animated(selected_unit, clicked)
				else:
					var other: Unit = _unit_at(clicked, 0)
					if other != null and other.can_act():
						_deselect(); _try_select(clicked)
					else:
						_deselect()
			PlayerState.UNIT_MOVED:
				if clicked in attack_tiles:
					var enemy: Unit = _unit_at(clicked, 1)
					if enemy != null:
						if not _honor_check_attack(selected_unit, enemy): return
						_open_predict(selected_unit, enemy)

	elif me.button_index == MOUSE_BUTTON_RIGHT:
		match player_state:
			PlayerState.UNIT_SELECTED:
				# 右键 = 原地行动菜单
				_open_in_place_menu()
			PlayerState.IDLE, PlayerState.UNIT_MOVED:
				_deselect()

func _handle_escape() -> void:
	# ESC 同时关闭敌方预览
	if _preview_enemy != null:
		_clear_enemy_preview(); _redraw_all(); _set_status("")
		return
	if _predict_panel and _predict_panel.visible:
		_on_cancel_attack()
		return
	if _action_menu and _action_menu.visible:
		# ESC + 有移动记录 = 取消移动
		if _pre_move_pos != Vector2i(-1, -1):
			_on_cancel_move_pressed()
		else:
			_hide_all_panels()
			player_state = PlayerState.IDLE if selected_unit == null else PlayerState.UNIT_SELECTED
		return
	if player_state == PlayerState.UNIT_SELECTED or player_state == PlayerState.UNIT_MOVED:
		if _pre_move_pos != Vector2i(-1, -1):
			_on_cancel_move_pressed()
		else:
			_deselect()

# 原地行动菜单（未移动时也可等待/攻击）
func _open_in_place_menu() -> void:
	if selected_unit == null: return
	attack_tiles = _adj_enemies(selected_unit.grid_pos)
	move_range.clear()
	_path_preview.clear()
	_pre_move_pos = Vector2i(-1, -1)   # 没有实际移动，无需取消
	player_state  = PlayerState.UNIT_MOVED
	_redraw_all()
	_show_action_menu(selected_unit.grid_pos, not attack_tiles.is_empty())

func _try_select(pos: Vector2i) -> void:
	var unit: Unit = _unit_at(pos, 0)
	if unit == null or not unit.can_act():
		return
	_clear_enemy_preview()   # 选中我方单位时关闭敌方预览
	selected_unit = unit
	move_range    = _calc_move_range(unit)
	attack_tiles  = _calc_attack_tiles(move_range)
	player_state  = PlayerState.UNIT_SELECTED
	_path_preview.clear()
	_redraw_all()
	var t_name := get_terrain_name(pos)
	_set_status("%s  HP:%d/%d  移动:%d  [%s]" % [
		unit.data.name, unit.data.hp, unit.data.max_hp, unit.data.move, t_name])
	_scroll_to_show(pos)

func _deselect() -> void:
	selected_unit = null
	target_enemy  = null
	_pre_move_pos = Vector2i(-1, -1)
	move_range.clear()
	attack_tiles.clear()
	_path_preview.clear()
	player_state = PlayerState.IDLE
	_hide_all_panels()
	_clear_enemy_preview()
	_redraw_all()
	_set_status("")

# ── 敌方安全距离预览 ─────────────────────────────────────
func _show_enemy_preview(unit: Unit) -> void:
	if not is_instance_valid(unit) or unit.is_dead(): return
	_preview_enemy = unit
	_preview_move_range   = _calc_move_range(unit)
	_preview_attack_tiles = _calc_attack_tiles(_preview_move_range)
	_redraw_all()
	# 底部状态栏显示提示
	var t_name := get_terrain_name(unit.grid_pos)
	_set_status("【%s】HP:%d/%d  移动:%d  攻击覆盖:%d格  [%s]（点击其他位置关闭）" % [
		unit.data.name, unit.data.hp, unit.data.max_hp,
		unit.data.move, _preview_attack_tiles.size(), t_name])

func _clear_enemy_preview() -> void:
	if _preview_enemy == null: return
	_preview_enemy = null
	_preview_move_range.clear()
	_preview_attack_tiles.clear()

# ── 行动菜单 ─────────────────────────────────────────────
func _show_action_menu(grid_pos: Vector2i, can_attack: bool) -> void:
	if _action_menu == null: return
	var screen_pos := _tile_to_screen(grid_pos)
	var vs := get_viewport().get_visible_rect().size
	var mp := screen_pos + Vector2(TILE_SIZE * 0.65, -TILE_SIZE * 0.55)
	# 防止菜单超出视口
	mp.x = clampf(mp.x, 4.0, vs.x - 168.0)
	mp.y = clampf(mp.y, 4.0, vs.y - 140.0)
	_action_menu.position = mp
	if _atk_btn:         _atk_btn.visible = can_attack
	if _cancel_move_btn: _cancel_move_btn.visible = (_pre_move_pos != Vector2i(-1, -1))
	if _items_btn:
		_items_btn.visible = selected_unit != null and selected_unit.data.has_usable_items()
	_action_menu.visible = true

# 荣耀系统：奈德不攻击低血量（投降）的敌人
func _honor_check_attack(attacker: Unit, defender: Unit) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(defender): return true
	# 只约束奈德（主角）
	if not attacker.data.is_protagonist: return true
	# 荣耀系统：只保护被关卡设计者明确标记为「不可击杀」的单位（min_hp > 0）
	# 例如：亚瑟·戴恩（min_hp=1，他撤退而非死亡，符合原著）
	# 教学关普通士兵 min_hp=0，不受此保护，可以正常攻击
	if defender.data.min_hp > 0 and defender.data.hp <= defender.data.min_hp:
		_set_status("%s 已无力再战，奈德放弃攻击。" % defender.data.name)
		return false
	return true

func _on_attack_pressed() -> void:
	_hide_all_panels()
	if attack_tiles.size() == 1:
		var enemy: Unit = _unit_at(attack_tiles[0], 1)
		if enemy != null:
			if not _honor_check_attack(selected_unit, enemy): return
			_open_predict(selected_unit, enemy)
	else:
		player_state = PlayerState.UNIT_MOVED
		_set_status("点击红色格子选择攻击目标")

func _on_wait_pressed() -> void:
	_hide_all_panels()
	_pre_move_pos = Vector2i(-1, -1)
	selected_unit.mark_acted()
	_refresh_unit_color(selected_unit)
	_deselect()
	_check_all_acted()

func _on_cancel_move_pressed() -> void:
	if selected_unit == null: return
	if _pre_move_pos != Vector2i(-1, -1):
		selected_unit.undo_move()
		selected_unit.grid_pos = _pre_move_pos
		selected_unit.position = _g2p(_pre_move_pos)
		_pre_move_pos = Vector2i(-1, -1)
	_hide_all_panels()
	move_range   = _calc_move_range(selected_unit)
	attack_tiles = _calc_attack_tiles(move_range)
	_path_preview.clear()
	player_state = PlayerState.UNIT_SELECTED
	_redraw_all()
	_set_status("%s 取消移动" % selected_unit.data.name)

func _on_end_turn_pressed() -> void:
	if _battle_over or current_phase != Phase.PLAYER_TURN or _animating_battle: return
	_deselect()
	if _end_turn_btn: _end_turn_btn.disabled = true
	_start_enemy_turn()

# ── 战斗预测弹窗 ─────────────────────────────────────────
func _open_predict(attacker: Unit, defender: Unit) -> void:
	target_enemy = defender
	if _predict_panel == null: return

	var bonus: Dictionary = get_terrain_bonus(defender.grid_pos)
	var pred: Dictionary  = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key,
		bonus.get("avoid", 0))

	if _atk_line:
		var crit_str := "  暴击%d%%" % pred["atk_crit"] if pred["atk_crit"] > 0 else ""
		_atk_line.text = "攻：%s  伤害%d  命中%d%%%s" % [
			attacker.data.name, pred["atk_damage"], pred["atk_hit"], crit_str]
	if _def_line:
		var t_name := get_terrain_name(defender.grid_pos)
		var def_val: int = bonus.get("defense", 0)
		var terrain_str := ""
		if bonus.get("avoid", 0) != 0 or def_val != 0:
			terrain_str = "  [%s 防%+d 回%+d]" % [t_name, def_val, bonus.get("avoid", 0)]
		_def_line.text = "防：%s  伤害%d  命中%d%%%s" % [
			defender.data.name, pred["def_damage"], pred["def_hit"], terrain_str]
	if _double_line:
		_double_line.text = "⚡ 可追击！" if pred["atk_double"] else ""

	var vs := get_viewport().get_visible_rect().size
	_predict_panel.position = Vector2(vs.x * 0.5 - 140.0, vs.y * 0.5 - 90.0)
	_predict_panel.visible  = true
	player_state = PlayerState.PREDICT

func _on_confirm_attack() -> void:
	_hide_all_panels()
	if selected_unit != null and target_enemy != null:
		# 二次荣耀检查：防止快速点击绕过
		if not _honor_check_attack(selected_unit, target_enemy):
			target_enemy = null
			return
		await _start_battle_with_animation(selected_unit, target_enemy)
	target_enemy  = null
	_pre_move_pos = Vector2i(-1, -1)

func _on_cancel_attack() -> void:
	_hide_all_panels()
	player_state = PlayerState.UNIT_MOVED
	attack_tiles = _adj_enemies(selected_unit.grid_pos)
	_redraw_all()
	_set_status("已取消，重新选择攻击目标")

func _hide_all_panels() -> void:
	if _action_menu:   _action_menu.visible   = false
	if _predict_panel: _predict_panel.visible = false

# ── 战斗动画 ─────────────────────────────────────────────
func _start_battle_with_animation(attacker: Unit, defender: Unit) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		_animating_battle = false
		return
	_animating_battle = true

	var bonus: Dictionary = get_terrain_bonus(defender.grid_pos)
	var pred: Dictionary = BattleCalculator.predict(
		attacker.data, defender.data, attacker.weapon_key, defender.weapon_key,
		bonus.get("avoid", 0))

	var anim_node: BattleAnimation = BATTLE_ANIM_SCENE.instantiate() as BattleAnimation
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer:
		ui_layer.add_child(anim_node)
	else:
		add_child(anim_node)

	anim_node.play(attacker, defender, pred)
	var result: Dictionary = await anim_node.animation_finished
	anim_node.queue_free()

	if is_instance_valid(attacker) and is_instance_valid(defender):
		_execute_combat_from_result(attacker, defender, result)
	elif is_instance_valid(attacker):
		attacker.mark_acted()
		_refresh_unit_color(attacker)
		_deselect()
		_redraw_all()
		_check_victory()
		_check_all_acted()
	_animating_battle = false

# ── 战斗结算 ─────────────────────────────────────────────
func _execute_combat_from_result(attacker: Unit, defender: Unit,
		result: Dictionary) -> void:
	var log := "⚔ %s(HP:%d) vs %s(HP:%d)" % [
		attacker.data.name, attacker.data.hp, defender.data.name, defender.data.hp]

	if result.get("atk_hit", false):
		var dmg: int = result.get("atk_damage", 0)
		defender.take_damage(dmg)
		log += "  →%d伤" % dmg
	else:
		log += "  →未命中"

	if not defender.is_dead() and result.get("def_hit", false):
		var dmg: int = result.get("def_damage", 0)
		attacker.take_damage(dmg)
		log += "  ←%d伤" % dmg

	if not defender.is_dead() and result.get("atk_double", false):
		var ddmg: int = result.get("double_damage", 0)
		if ddmg > 0:
			defender.take_damage(ddmg)
			log += "  →%d追" % ddmg

	# print(log)  # 已改为Godot内部日志，避免macOS终端Unicode报错
	_set_status(log)

	# 武器耐久消耗
	attacker.data.use_weapon_once()
	if not defender.is_dead():
		defender.data.use_weapon_once()

	attacker.resolve_death()
	defender.resolve_death()
	attacker.mark_acted()
	_refresh_unit_color(attacker)
	_deselect()
	target_enemy  = null
	_pre_move_pos = Vector2i(-1, -1)
	_redraw_all()
	_check_victory()
	_check_all_acted()

func _roll(rate: int) -> bool:
	return randi() % 100 < rate

# ── 颜色反馈 ─────────────────────────────────────────────
func _refresh_unit_color(unit: Unit) -> void:
	# 精灵已隐藏，改用程序化渲染——触发重绘即可（_draw()内_fill_col处理DONE灰化）
	if is_instance_valid(unit):
		unit.queue_redraw()

func _restore_unit_color(unit: Unit) -> void:
	if is_instance_valid(unit):
		unit.queue_redraw()

# ── 胜败 ─────────────────────────────────────────────────
func _check_victory() -> void:
	if _battle_over: return
	if enemy_units.filter(func(u: Unit) -> bool: return not u.is_dead()).is_empty():
		_end_battle(true); return
	for u: Unit in player_units:
		if u.grid_pos == victory_pos and not u.is_dead():
			_end_battle(true); return

func _check_defeat() -> void:
	if _battle_over: return
	if player_units.filter(func(u: Unit) -> bool: return not u.is_dead()).is_empty():
		_end_battle(false)

func _end_battle(won: bool) -> void:
	_battle_over = true
	_hide_all_panels()
	_update_turn_label()
	if _end_turn_btn: _end_turn_btn.disabled = true

	if _result_panel == null:
		_set_status("胜利！" if won else "失败！")
		return

	if _result_title: _result_title.text = "胜利！" if won else "败北"
	if _result_msg:
		_result_msg.text = "攻占敌营，风暴地已落入义军之手。" if won else "全军覆没，战斗失败。"
	_apply_result_state_theme(won)

	var vs := get_viewport().get_visible_rect().size
	_result_panel.position = Vector2(vs.x * 0.5 - 160.0, vs.y * 0.5 - 80.0)
	_result_panel.visible  = true

	if won: battle_won.emit()
	else:   battle_lost.emit()

func _restart() -> void:
	get_tree().reload_current_scene()

# ── 回合 ─────────────────────────────────────────────────
func _check_all_acted() -> void:
	# 只在我方回合且没有正在进行的回合切换时才检查
	if _battle_over or _turn_ending: return
	if current_phase != Phase.PLAYER_TURN: return   # ← 关键：敌方回合绝不重入
	if not player_units.any(func(u: Unit) -> bool: return not u.is_dead() and u.can_act()):
		_turn_ending = true
		_update_support_adjacency()   # 回合结束时统计支援相邻
		await get_tree().create_timer(0.5).timeout
		_turn_ending = false
		if _battle_over: return        # await 期间战斗可能结束
		_start_enemy_turn()

func _start_enemy_turn() -> void:
	if _battle_over: return
	current_phase = Phase.ENEMY_TURN
	_deselect()
	_update_turn_label()

	var enemies_this_turn: Array = enemy_units.duplicate()

	for i in enemies_this_turn.size():
		if _battle_over: break
		var enemy: Unit = enemies_this_turn[i]
		if not is_instance_valid(enemy) or enemy.is_dead(): continue
		if enemy.team == 2: continue   # 中立单位不参与敌方回合

		var action: Dictionary = EnemyAI.decide(enemy, player_units, _calc_move_range(enemy))
		if not is_instance_valid(enemy): continue

		# 敌方行走动画
		var path := _find_path_to(enemy, action["move_to"])
		_animating_battle = true
		var prev := enemy.grid_pos
		for step: Vector2i in path:
			if not is_instance_valid(enemy): break
			_set_unit_facing(enemy, step - prev)
			prev = step
			enemy.grid_pos = step
			var tw := create_tween()
			tw.tween_property(enemy, "position", _g2p(step), 0.09)
			await tw.finished
			if is_instance_valid(enemy): _redraw_all()
		if path.is_empty() and is_instance_valid(enemy):
			enemy.grid_pos = action["move_to"]
			enemy.position = _g2p(action["move_to"])
		_animating_battle = false

		if action["attack"] != null and is_instance_valid(enemy):
			var target: Unit = action["attack"] as Unit
			if is_instance_valid(target) and not target.is_dead():
				await _start_battle_with_animation(enemy, target)
			# await 后再次确认 enemy 仍然有效（可能被反击击杀）
			if not is_instance_valid(enemy): continue

		await get_tree().create_timer(0.15).timeout

	if not _battle_over:
		_start_player_turn()

func _start_player_turn() -> void:
	_turn_ending = false
	_turn_count += 1
	for u: Unit in player_units:
		if is_instance_valid(u) and not u.is_dead():
			u.reset_turn()
			_restore_unit_color(u)
	current_phase = Phase.PLAYER_TURN
	_update_turn_label()
	_update_danger_zone()
	_check_defeat()
	_redraw_all()
	# 自动托管：若启用则接管本回合所有玩家单位行动
	if _autopilot and not _battle_over:
		_run_autopilot_turn()

# ════════════════════════════════════════════════════════
# 自动托管系统（A 键切换，ESC 随时中止）
# ════════════════════════════════════════════════════════

func _toggle_autopilot() -> void:
	_autopilot = not _autopilot
	_update_autopilot_label()
	if _autopilot:
		_set_status("⚡ 自动托管已启动（A 键或 ESC 可随时中止）")
		# 若当前正是玩家回合且没有在运行，立即开始
		if current_phase == Phase.PLAYER_TURN and not _autopilot_running and not _battle_over:
			_run_autopilot_turn()
	else:
		_autopilot_running = false
		_set_status("⏸ 自动托管已暂停（A 键重新启动）")

func _update_autopilot_label() -> void:
	if _autopilot_label == null: return
	if _autopilot:
		_autopilot_label.text = "⚡ AUTO"
		_autopilot_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.55))
	else:
		_autopilot_label.text = ""

func _run_autopilot_turn() -> void:
	if _autopilot_running: return   # 防止重入
	_autopilot_running = true

	# 短暂延迟，让玩家看清画面
	await get_tree().create_timer(0.3).timeout

	# 逐一处理所有可行动的玩家单位
	while _autopilot and not _battle_over and current_phase == Phase.PLAYER_TURN:
		if not is_inside_tree(): break

		# 找下一个还能行动的单位
		var acting: Unit = null
		for u: Unit in player_units:
			if is_instance_valid(u) and not u.is_dead() and u.can_act():
				acting = u
				break

		if acting == null:
			break   # 所有单位已行动，结束回合

		# 计算决策
		var walkable := _calc_move_range(acting)
		var action   := AutopilotAI.decide(acting, enemy_units, walkable)

		# ── 优先：自救道具（主角 HP 不足时原地使用）────────────
		var use_item_idx: int = int(action.get("use_item", -1))
		if use_item_idx >= 0:
			var item := acting.data.use_item(use_item_idx)
			if not item.is_empty() and item.get("type", "") == "heal":
				var amount: int = int(item.get("heal_amount", 10))
				acting.data.hp = mini(acting.data.hp + amount, acting.data.max_hp)
				acting._refresh_hp_label()
				_set_status("⚕ %s 使用【%s】自救，恢复 %d HP（当前 %d/%d）" % [
					acting.data.name, item.get("name", "急救药"),
					amount, acting.data.hp, acting.data.max_hp])
			acting.mark_acted()
			_refresh_unit_color(acting)
			_deselect()
			_redraw_all()
			await get_tree().create_timer(0.40).timeout
			if not is_inside_tree() or not _autopilot: break
			continue   # 直接找下一个可行动单位

		# ── 执行移动动画 ──────────────────────────────────────
		var target_pos: Vector2i = action["move_to"]
		if target_pos != acting.grid_pos:
			await _do_move_animated(acting, target_pos)
			if not is_inside_tree() or not _autopilot: break
			await get_tree().create_timer(0.15).timeout

		# ── 执行攻击 ──────────────────────────────────────────
		var attack_target: Unit = action.get("attack") as Unit
		if attack_target != null and is_instance_valid(attack_target) \
				and not attack_target.is_dead():
			if _honor_check_attack(acting, attack_target):
				await _start_battle_with_animation(acting, attack_target)
				if not is_inside_tree() or not _autopilot: break
				await get_tree().create_timer(0.2).timeout
			else:
				# 荣耀保护：等待
				acting.mark_acted()
				_refresh_unit_color(acting)
		else:
			# 无法攻击：等待
			acting.mark_acted()
			_refresh_unit_color(acting)

		_deselect()
		_check_victory()
		if _battle_over: break
		await get_tree().create_timer(0.2).timeout

	# 回合结束
	_autopilot_running = false
	if _autopilot and not _battle_over and current_phase == Phase.PLAYER_TURN:
		await get_tree().create_timer(0.3).timeout
		if _autopilot and not _battle_over:
			_on_end_turn_pressed()

func _update_turn_label() -> void:
	if not _turn_label: return
	if _battle_over:
		_turn_label.text = "战斗结束"
		_turn_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		if _end_turn_btn: _end_turn_btn.disabled = true
		return
	if current_phase == Phase.PLAYER_TURN:
		_turn_label.text = "我方回合 [%d]" % _turn_count
		_turn_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		if _end_turn_btn: _end_turn_btn.disabled = false
	else:
		_turn_label.text = "敌方回合 [%d]" % _turn_count
		_turn_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		if _end_turn_btn: _end_turn_btn.disabled = true

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
	if _objective_label != null:
		if msg.begins_with("目标："):
			_objective_label.text = msg
		elif msg.begins_with("战局："):
			_objective_label.text = msg
	if _guidance_label != null and msg.begins_with("推进："):
		_guidance_label.text = msg

func _set_phase_badge(msg: String) -> void:
	if _phase_label != null:
		_phase_label.text = msg

func _on_player_unit_action_position_updated(_unit: Unit) -> void:
	pass

func _set_terrain_info(msg: String) -> void:
	if _terrain_label: _terrain_label.text = msg

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()

# ── 工具 ─────────────────────────────────────────────────
func _unit_at(pos: Vector2i, team: int) -> Unit:
	for u: Unit in (player_units + enemy_units):
		if u.grid_pos == pos and u.team == team and not u.is_dead():
			return u
	return null

func _adj_enemies(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if _unit_at(pos + d, 1) != null:
			result.append(pos + d)
	return result

func _calc_attack_tiles(from_range: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for pos: Vector2i in from_range:
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var np: Vector2i = pos + d
			if seen.has(np): continue
			if _unit_at(np, 1) != null:
				seen[np] = true
				result.append(np)
	return result

func _calc_move_range(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [{"pos": unit.grid_pos, "rem": unit.data.move}]
	visited[unit.grid_pos] = true
	while not queue.is_empty():
		var curr: Dictionary = queue.pop_front()
		var pos: Vector2i = curr["pos"]
		var rem: int = curr["rem"]
		# 只有无友方占据（或自身出发格）的格子才能作为停留目标
		var friendly_at_pos: Unit = _unit_at(pos, unit.team)
		if pos == unit.grid_pos or friendly_at_pos == null:
			result.append(pos)
		if rem == 0: continue
		for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var npos: Vector2i = pos + d
			if visited.has(npos) or not is_passable(npos): continue
			# 敌方单位阻断穿越；友方单位可穿越但不能停留（已在 result 加入时处理）
			var enemy_blocker: Unit = _unit_at(npos, 0) if unit.team == 1 else _unit_at(npos, 1)
			if enemy_blocker != null: continue
			var cost: int = get_terrain_move_cost(npos)
			if rem - cost < 0: continue
			visited[npos] = true
			queue.append({"pos": npos, "rem": rem - cost})
	return result

func _on_unit_died(unit: Unit) -> void:
	# 主角阵亡 → Game Over（不进行普通死亡处理）
	if unit.data.is_protagonist:
		_trigger_game_over(unit)
		return
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	_redraw_all()
	_check_defeat()

# ── Game Over（主角阵亡）────────────────────────────────
func _trigger_game_over(unit: Unit) -> void:
	_battle_over = true
	_hide_all_panels()
	if _end_turn_btn: _end_turn_btn.disabled = true
	if ResourceLoader.exists(GAME_OVER_PATH):
		var go: Node = load(GAME_OVER_PATH).instantiate()
		var ui_layer := get_node_or_null("UI") as CanvasLayer
		if ui_layer: ui_layer.add_child(go)
		else: add_child(go)
		if go.has_method("show_game_over"):
			go.call("show_game_over", unit.data.name)
		if go.has_signal("restart_chapter"):
			go.connect("restart_chapter", _restart)
		if go.has_signal("quit_to_menu"):
			go.connect("quit_to_menu", _return_to_opening)
	else:
		_set_status("⚠ 主角 %s 阵亡——游戏结束" % unit.data.name)
		await get_tree().create_timer(2.0).timeout
		if not _battle_over:  # 避免重复触发
			_restart()

func _return_to_opening() -> void:
	GameState.current_chapter = 1
	get_tree().change_scene_to_file("res://scenes/Opening.tscn")

# ── 道具系统 ─────────────────────────────────────────────
func _on_items_pressed() -> void:
	_hide_all_panels()
	if selected_unit == null: return
	_show_items_panel(selected_unit)

func _show_items_panel(unit: Unit) -> void:
	if _active_items_panel != null:
		_active_items_panel.queue_free()
	var panel := PanelContainer.new()
	var vbox  := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "使用道具"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_font_override("font", _get_cjk_font())
	vbox.add_child(title)
	var has_items := false
	for i: int in unit.data.items.size():
		var item: Dictionary = unit.data.items[i] as Dictionary
		if item.get("uses", 0) <= 0: continue
		has_items = true
		var btn := Button.new()
		btn.text = "%s  ×%d" % [item.get("name", "?"), item.get("uses", 0)]
		btn.custom_minimum_size = Vector2(180, 32)
		btn.add_theme_font_override("font", _get_cjk_font())
		var ci := i
		btn.pressed.connect(func() -> void: _on_item_used(unit, ci))
		vbox.add_child(btn)
	if not has_items:
		var lbl := Label.new()
		lbl.text = "（无可用道具）"
		lbl.add_theme_font_override("font", _get_cjk_font())
		vbox.add_child(lbl)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(180, 30)
	cancel.add_theme_font_override("font", _get_cjk_font())
	cancel.pressed.connect(func() -> void:
		if _active_items_panel: _active_items_panel.queue_free(); _active_items_panel = null
		_show_action_menu(unit.grid_pos, not _adj_enemies(unit.grid_pos).is_empty()))
	vbox.add_child(cancel)
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer: ui_layer.add_child(panel)
	else:        add_child(panel)
	var vs := get_viewport().get_visible_rect().size
	panel.position = Vector2(vs.x * 0.5 - 90.0, vs.y * 0.5 - 100.0)
	_active_items_panel = panel

func _on_item_used(unit: Unit, item_idx: int) -> void:
	if _active_items_panel:
		_active_items_panel.queue_free()
		_active_items_panel = null
	var item := unit.data.use_item(item_idx)
	if item.is_empty(): return
	match item.get("type", ""):
		"heal":
			var amount: int = int(item.get("heal_amount", 10))
			unit.data.hp = mini(unit.data.hp + amount, unit.data.max_hp)
			unit._refresh_hp_label()
			_set_status("%s 使用【%s】，恢复 %d HP" % [unit.data.name, item.get("name", "道具"), amount])
		"offensive":
			var burn_dmg: int = int(item.get("burn_damage", 5))
			for enemy: Unit in enemy_units:
				if _manhattan_dist(unit.grid_pos, enemy.grid_pos) == 1:
					enemy.take_damage(burn_dmg)
					enemy.resolve_death()
					_set_status("%s 使用【%s】，对周围敌人造成 %d 伤" % [
						unit.data.name, item.get("name", "道具"), burn_dmg])
					break
		_:
			_set_status("%s 使用了 %s" % [unit.data.name, item.get("name", "道具")])
	_hide_all_panels()
	unit.mark_acted()
	_refresh_unit_color(unit)
	_deselect()
	_redraw_all()
	_check_victory()
	_check_all_acted()

# ── 支援系统 ──────────────────────────────────────────────
func _update_support_adjacency() -> void:
	for i: int in player_units.size():
		for j: int in range(i + 1, player_units.size()):
			var ua: Unit = player_units[i]
			var ub: Unit = player_units[j]
			if not is_instance_valid(ua) or not is_instance_valid(ub): continue
			if ua.is_dead() or ub.is_dead(): continue
			if _manhattan_dist(ua.grid_pos, ub.grid_pos) == 1:
				var key := _support_key(ua.data.name, ub.data.name)
				_support_data[key] = int(_support_data.get(key, 0)) + 1
				if int(_support_data[key]) == SUPPORT_C_THRESHOLD and \
						not _support_popup_shown.get(key, false):
					_support_popup_shown[key] = true
					_show_support_popup(ua.data.name, ub.data.name)

func _show_support_popup(name_a: String, name_b: String) -> void:
	if not ResourceLoader.exists(SUPPORT_POPUP_PATH): return
	var popup: Node = load(SUPPORT_POPUP_PATH).instantiate()
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer: ui_layer.add_child(popup)
	else:        add_child(popup)
	if popup.has_method("show_support"):
		popup.call("show_support", name_a, name_b, "C", {"hit": 5, "avoid": 5})
	if popup.has_signal("popup_closed"):
		popup.connect("popup_closed", popup.queue_free)

func get_support_hit_bonus(attacker: Unit, ally: Unit) -> int:
	if attacker.team != 0 or ally.team != 0: return 0
	if _manhattan_dist(attacker.grid_pos, ally.grid_pos) > 3: return 0
	var key := _support_key(attacker.data.name, ally.data.name)
	var pts: int = int(_support_data.get(key, 0))
	if pts >= SUPPORT_C_THRESHOLD: return 5
	return 0

func _support_key(a: String, b: String) -> String:
	var parts := [a, b]
	parts.sort()
	return "_".join(parts)

func _manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
