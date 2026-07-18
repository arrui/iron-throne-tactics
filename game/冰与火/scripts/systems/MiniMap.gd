# MiniMap.gd — GBA FE 风格小地图（M 键切换）
# 显示地形概览、单位位置、摄像机视口框
class_name MiniMap
extends CanvasLayer

const CJKFontHelper := preload("res://scripts/ui/CJKFontHelper.gd")

# ── 尺寸与位置 ────────────────────────────────────────────
const MM_W   := 182   # 小地图像素宽（含1px内边距）
const MM_H   := 134   # 小地图像素高
const MARGIN := 10    # 距屏幕右下角距离
const CELL_W := 5     # 每格像素宽
const CELL_H := 5     # 每格像素高
const HDR_H  := 20    # 标题栏高度

# ── 颜色常量 ──────────────────────────────────────────────
const BG_COL       := Color(0.04, 0.04, 0.06, 0.90)
const BORDER_COL   := Color(0.60, 0.50, 0.28, 1.00)
const TITLE_COL    := Color(1.00, 0.90, 0.40, 1.00)
const VIEWPORT_COL := Color(1.00, 1.00, 1.00, 0.70)
const PLAYER_COL   := Color(0.25, 0.60, 1.00, 1.00)
const ENEMY_COL    := Color(1.00, 0.22, 0.12, 1.00)
const NEUTRAL_COL  := Color(1.00, 0.82, 0.28, 1.00)
const VICTORY_COL  := Color(1.00, 0.90, 0.10, 1.00)

# 地形色（与 BattleMap._terrain_draw_color 保持一致）
const TERRAIN_COL: Dictionary = {
	0: Color(0.28, 0.26, 0.20),
	1: Color(0.12, 0.22, 0.10),
	2: Color(0.38, 0.28, 0.16),
	3: Color(0.06, 0.06, 0.06),
	4: Color(0.10, 0.16, 0.35),
	5: Color(0.14, 0.20, 0.10),
	6: Color(0.36, 0.30, 0.20),
}

# ── 内部状态 ──────────────────────────────────────────────
var _bm:     BattleMap = null   # 明确声明为 BattleMap，避免类型推断错误
var _canvas: Control   = null

# ── 初始化 ───────────────────────────────────────────────
func setup(battle_map: BattleMap) -> void:
	_bm    = battle_map
	layer  = 25
	_build_canvas()
	visible = false

func _build_canvas() -> void:
	_canvas = Control.new()
	_canvas.anchor_left   = 1.0; _canvas.anchor_right  = 1.0
	_canvas.anchor_top    = 1.0; _canvas.anchor_bottom = 1.0
	_canvas.offset_left   = -(MM_W + MARGIN)
	_canvas.offset_right  = -MARGIN
	_canvas.offset_top    = -(MM_H + HDR_H + MARGIN)
	_canvas.offset_bottom = -MARGIN
	_canvas.draw.connect(_draw_minimap)
	add_child(_canvas)

func toggle() -> void:
	visible = not visible

func _process(_dt: float) -> void:
	if visible and is_instance_valid(_canvas):
		_canvas.queue_redraw()

# ════════════════════════════════════════════════════════════
# 绘制
# ════════════════════════════════════════════════════════════
func _draw_minimap() -> void:
	if _bm == null or not is_instance_valid(_bm): return
	var c: Control = _canvas
	var total_h: int = MM_H + HDR_H

	# 背景与边框
	c.draw_rect(Rect2(0, 0, MM_W, total_h), BG_COL)
	c.draw_rect(Rect2(0, 0, MM_W, total_h), BORDER_COL, false, 1.5)

	# 标题
	var font: Font = ThemeDB.fallback_font if ThemeDB.fallback_font != null else CJKFontHelper.get_font()
	if font:
		c.draw_string(font, Vector2(6, 14),
			"小地图  [M键关闭]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TITLE_COL)

	# 地图内容起始 Y
	var oy: int = HDR_H

	# ── 地形 ──────────────────────────────────────────────
	var mw: int = _bm.map_width
	var mh: int = _bm.map_height
	for row: int in mh:
		for col: int in mw:
			var t: int = _bm._get_terrain_type(Vector2i(col, row))
			var col_c: Color = TERRAIN_COL.get(t, TERRAIN_COL[0]) as Color
			c.draw_rect(
				Rect2(col * CELL_W + 1, row * CELL_H + oy + 1, CELL_W - 1, CELL_H - 1),
				col_c)

	# ── 胜利格 ──────────────────────────────────────────
	var vp: Vector2i = _bm.victory_pos
	c.draw_rect(
		Rect2(vp.x * CELL_W + 1, vp.y * CELL_H + oy + 1, CELL_W - 1, CELL_H - 1),
		VICTORY_COL)

	# ── 单位点 ──────────────────────────────────────────
	var dot: int = 3
	var all_units: Array = _bm.player_units + _bm.enemy_units
	for candidate: Variant in all_units:
		if not is_instance_valid(candidate):
			continue
		var u := candidate as Unit
		if u == null or u.is_dead():
			continue
		var uc: Color
		if   u.team == 0: uc = PLAYER_COL
		elif u.team == 2: uc = NEUTRAL_COL
		else:             uc = ENEMY_COL
		var px: int = u.grid_pos.x * CELL_W + (CELL_W - dot) / 2 + 1
		var py: int = u.grid_pos.y * CELL_H + (CELL_H - dot) / 2 + oy + 1
		c.draw_rect(Rect2(px, py, dot, dot), uc)

	# ── 摄像机视口框 ──────────────────────────────────
	# 通过 Camera2D 的世界坐标推算视口在地图中的位置
	var cam: Camera2D = _bm.get_node_or_null("Camera2D") as Camera2D
	if cam and is_instance_valid(cam):
		var vp_size: Vector2  = _bm.get_viewport().get_visible_rect().size
		var cam_pos: Vector2  = cam.get_screen_center_position()
		var ts: int           = _bm.TILE_SIZE
		# 视口左上角（世界坐标）
		var world_tl: Vector2 = cam_pos - vp_size * 0.5
		# 转换为小地图像素坐标
		var ml: float = clampf(world_tl.x / ts * CELL_W + 1.0, 1.0, float(MM_W - 2))
		var mt: float = clampf(world_tl.y / ts * CELL_H + 1.0 + oy, float(oy + 1), float(total_h - 2))
		var mw2: float = clampf(vp_size.x / ts * CELL_W, 4.0, float(MM_W - 2) - ml)
		var mh2: float = clampf(vp_size.y / ts * CELL_H, 4.0, float(total_h - 2) - mt)
		c.draw_rect(Rect2(ml, mt, mw2, mh2), VIEWPORT_COL, false, 1.5)

	# 地图区域边框
	c.draw_rect(
		Rect2(1, oy + 1, mw * CELL_W, mh * CELL_H),
		BORDER_COL, false, 1.0)
