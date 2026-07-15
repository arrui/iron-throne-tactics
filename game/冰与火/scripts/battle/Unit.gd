# Unit.gd — 单位节点（程序化六边形渲染 + 武器耐久/道具/主角死亡）
class_name Unit
extends Node2D

signal unit_died(unit)

enum Team  { PLAYER, ENEMY, NEUTRAL }
enum State { IDLE, MOVED, ACTED, DONE }

var data:     UnitData
var team:     int = Team.PLAYER
var state:    int = State.IDLE
var grid_pos: Vector2i = Vector2i.ZERO

var weapon_key: String:
	get: return data.get_weapon_key() if data != null else "sword_E"

var _pending_death: bool = false
var _idle_time: float = 0.0

# ── GDD 色盘（Banner Saga 暗色系）──────────────────────────
const _TS            := 72      # 与 BattleMap.TILE_SIZE 同步
const _HEX_R         := 0.42   # 六边形外径（加大，更易辨认）

# 玩家阵营（史塔克·冰蓝）
const _PLAYER_FILL   := Color(0.08, 0.20, 0.52, 0.96)
const _PLAYER_RIM    := Color(0.55, 0.85, 1.00, 1.00)
const _PLAYER_TEXT   := Color(0.90, 0.97, 1.00, 1.00)

# 敌方阵营（兰尼斯特·鲜红）—— 加大饱和度，在暗地图上清晰可见
const _ENEMY_FILL    := Color(0.72, 0.10, 0.06, 0.96)
const _ENEMY_RIM     := Color(1.00, 0.55, 0.30, 1.00)
const _ENEMY_TEXT    := Color(1.00, 0.88, 0.82, 1.00)

# 中立阵营（烛珀·金）
const _NEUTRAL_FILL  := Color(0.38, 0.28, 0.06, 0.96)
const _NEUTRAL_RIM   := Color(1.00, 0.85, 0.35, 1.00)
const _NEUTRAL_TEXT  := Color(1.00, 0.95, 0.72, 1.00)

const _SHADOW_COL    := Color(0.00, 0.00, 0.00, 0.60)
const _DONE_MIX      := 0.55   # 行动完毕灰化程度

# ── 初始化 ──────────────────────────────────────────────────
func _ready() -> void:
	# 专属像素精灵叠在阵营六边形之上；三帧图集用于轻微待机动画。
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite:
		sprite.visible = true
		sprite.hframes = 3
		sprite.frame = 0
	set_process(true)
	# 调整名字标签：居中、阵营色、加阴影
	var lbl := get_node_or_null("Label") as Label
	if lbl:
		var txt_col := _PLAYER_TEXT if team == 0 else \
			(_ENEMY_TEXT if team == 1 else Color(1.0, 0.95, 0.70))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", txt_col)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.offset_top    = -52.0
		lbl.offset_bottom = -32.0
		lbl.offset_left   = -18.0
		lbl.offset_right  =  18.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	# 隐藏旧 HP 数字标签（改用绘制 HP 条）
	var hp_lbl := get_node_or_null("HPLabel") as Label
	if hp_lbl:
		hp_lbl.visible = false

func _process(delta: float) -> void:
	_idle_time += delta
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite != null and sprite.hframes == 3:
		sprite.frame = int(_idle_time / 0.28) % 3

func setup(unit_data: UnitData, unit_team: int, pos: Vector2i) -> void:
	data     = unit_data
	team     = unit_team
	grid_pos = pos
	queue_redraw()  # 确保节点加入场景树后立即触发初次绘制

# ── 核心伤害逻辑 ──────────────────────────────────────────
func take_damage(amount: int) -> void:
	var floor_hp: int = maxi(data.min_hp, 0)
	data.hp = maxi(data.hp - amount, floor_hp)
	_refresh_hp_label()
	if data.hp == 0:
		_pending_death = true

func resolve_death() -> void:
	if _pending_death:
		unit_died.emit(self)

func is_dead() -> bool:
	return data.hp <= 0

# ── 状态机 ──────────────────────────────────────────────────
func can_act() -> bool:
	return state == State.IDLE or state == State.MOVED

func mark_moved() -> void:
	if state == State.IDLE:
		state = State.MOVED
		queue_redraw()

func mark_acted() -> void:
	state = State.DONE
	queue_redraw()

func undo_move() -> void:
	if state == State.MOVED:
		state = State.IDLE
		queue_redraw()

func reset_turn() -> void:
	state = State.IDLE
	_pending_death = false
	queue_redraw()

func _refresh_hp_label() -> void:
	var lbl: Label = get_node_or_null("HPLabel") as Label
	if lbl: lbl.text = str(data.hp)
	queue_redraw()   # 重绘 HP 条

# ════════════════════════════════════════════════════════════
# 程序化渲染
# ════════════════════════════════════════════════════════════
func _draw() -> void:
	if data == null: return
	_draw_shadow()
	_draw_hex_body()
	_draw_hp_bar()
	if is_dead():
		_draw_death_cross()

# ── 阴影（偏移2px）──────────────────────────────────────────
func _draw_shadow() -> void:
	var r   := _TS * _HEX_R
	var pts := _hex_points(r, Vector2(2.0, 3.0))
	var col := PackedColorArray(); col.resize(6); col.fill(_SHADOW_COL)
	draw_polygon(pts, col)

# ── 六边形主体 ───────────────────────────────────────────────
func _draw_hex_body() -> void:
	var r   := _TS * _HEX_R
	var pts := _hex_points(r, Vector2.ZERO)

	var fill := _fill_col()
	var rim  := _rim_col()

	# 主体
	var cols := PackedColorArray(); cols.resize(6); cols.fill(fill)
	draw_polygon(pts, cols)
	# 内发光（描边内侧一层淡色）
	var glow_r := r * 0.80
	var glow_pts := _hex_points(glow_r, Vector2.ZERO)
	var glow_col := rim; glow_col.a = 0.12
	var glow_cols := PackedColorArray(); glow_cols.resize(6); glow_cols.fill(glow_col)
	draw_polygon(glow_pts, glow_cols)
	# 外描边（加粗，提升辨识度）
	for i in 6:
		draw_line(pts[i], pts[(i+1)%6], rim, 3.5, true)

# ── HP 条（六边形正下方）──────────────────────────────────────
func _draw_hp_bar() -> void:
	var w     := _TS * 0.60
	var h     := 5.0
	var x     := -w * 0.5
	var y     := _TS * _HEX_R + 3.0
	var ratio := float(data.hp) / float(maxi(data.max_hp, 1))

	draw_rect(Rect2(x, y, w, h), Color(0.06, 0.06, 0.06, 0.92))
	var hp_col := Color(0.20, 0.82, 0.30) if ratio > 0.50 \
		else (Color(0.92, 0.74, 0.10) if ratio > 0.25 \
		else Color(0.92, 0.18, 0.12))
	draw_rect(Rect2(x, y, w * ratio, h), hp_col)
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 1.0), false, 1.0)

# ── 阵亡叉号 ────────────────────────────────────────────────
func _draw_death_cross() -> void:
	var r := _TS * _HEX_R * 0.55
	draw_line(Vector2(-r,-r), Vector2(r,r), Color(0.9,0.1,0.1,0.85), 3.5)
	draw_line(Vector2(r,-r),  Vector2(-r,r), Color(0.9,0.1,0.1,0.85), 3.5)

# ── 辅助：生成六边形顶点（尖顶向上，带偏移）──────────────────
func _hex_points(r: float, offset: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := (i * 60.0 - 90.0) * PI / 180.0
		pts.append(Vector2(cos(a), sin(a)) * r + offset)
	return pts

# ── 配色辅助 ────────────────────────────────────────────────
func _fill_col() -> Color:
	var c: Color
	match team:
		0: c = _PLAYER_FILL
		1: c = _ENEMY_FILL
		_: c = _NEUTRAL_FILL
	if state == State.DONE:
		c = c.lerp(Color(0.22, 0.22, 0.22, 0.85), _DONE_MIX)
	return c

func _rim_col() -> Color:
	var c: Color
	match team:
		0: c = _PLAYER_RIM
		1: c = _ENEMY_RIM
		_: c = _NEUTRAL_RIM
	if state == State.DONE:
		c = c.lerp(Color(0.40, 0.40, 0.40, 1.0), _DONE_MIX)
	return c
