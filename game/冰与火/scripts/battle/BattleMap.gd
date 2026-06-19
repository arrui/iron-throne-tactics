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

# ── Camera2D ────────────────────────────────────────────
@onready var _cam: Camera2D = $Camera2D

# ── UI 节点引用 ──────────────────────────────────────────
var _turn_label:       Label         = null
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

# ════════════════════════════════════════════════════════
func _ready() -> void:
	# 确保战斗场景中的中文字体正确显示
	if DisplayServer.get_name() != "headless":
		_apply_battle_font()
	_bind_ui()
	_update_turn_label()
	_update_danger_zone()

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
	# 全局回退字体
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 14
	# 项目主题
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font = font
		theme.default_font_size = 14
	# 对场景中所有文字控件显式设置字体（最彻底的方案）
	call_deferred("_apply_font_to_controls", self)

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
func _bind_ui() -> void:
	_turn_label    = get_node_or_null("UI/TurnLabel")    as Label
	_status_label  = get_node_or_null("UI/StatusLabel")  as Label
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

# ── 高亮绘制（由 HighlightLayer 调用，保证在地形之上、单位之下）────
func _draw() -> void:
	pass  # BattleMap 本身不绘制，由 HighlightLayer._draw() → _draw_highlights() 处理

# HighlightLayer.gd 的 _draw() 回调此方法
func _draw_highlights(canvas: Node2D) -> void:
	# 1. 危险区（最底层）
	if _show_danger:
		for pos: Vector2i in _danger_tiles.keys():
			_draw_tile_highlight(canvas, pos, DANGER_COLOR)

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
					var tag := "我" if u.team == 0 else "敌"
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
		if key == KEY_ESCAPE:
			_handle_escape()
			get_viewport().set_input_as_handled()
			return

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
						_open_predict(selected_unit, enemy)

	elif me.button_index == MOUSE_BUTTON_RIGHT:
		match player_state:
			PlayerState.UNIT_SELECTED:
				# 右键 = 原地行动菜单
				_open_in_place_menu()
			PlayerState.IDLE, PlayerState.UNIT_MOVED:
				_deselect()

func _handle_escape() -> void:
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
	_redraw_all()
	_set_status("")

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

func _on_attack_pressed() -> void:
	_hide_all_panels()
	if attack_tiles.size() == 1:
		var enemy: Unit = _unit_at(attack_tiles[0], 1)
		if enemy != null:
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
	var node := unit.get_node_or_null("Sprite")
	if node and unit.state == Unit.State.DONE:
		node.modulate = Color(0.5, 0.5, 0.5, 1.0)

func _restore_unit_color(unit: Unit) -> void:
	var node := unit.get_node_or_null("Sprite")
	if node:
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
	if _status_label: _status_label.text = msg

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
			go.connect("quit_to_menu", _restart)
	else:
		_set_status("⚠ 主角 %s 阵亡——游戏结束" % unit.data.name)
		await get_tree().create_timer(2.0).timeout
		if not _battle_over:  # 避免重复触发
			_restart()

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
