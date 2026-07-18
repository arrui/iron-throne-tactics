# CutsceneArt.gd — 过场动画场景绘制（无外部资源，纯代码绘制）
# 支持场景类型：
# throne_room / execution / vale_castle / stormlands_road
# ruby_ford_duel / ruby_ford_fall / trident_muster
# tower_of_joy_gate / tower_of_joy_fall / lyanna_chamber
# kingslayer / throne_room_crowned / north_road / winterfell_gate / red_keep_breach
class_name CutsceneArt
extends Node2D

var scene_type: String = ""
var alpha: float = 0.0   # 由外部 tween 控制淡入淡出
var time: float = 0.0
var overlay_tint: Color = Color(1, 1, 1, 0)

func _process(delta: float) -> void:
	if scene_type == "" or alpha <= 0.001:
		return
	time += delta
	queue_redraw()

func reset_motion_state() -> void:
	time = 0.0
	overlay_tint = Color(1, 1, 1, 0)
	position = Vector2.ZERO
	scale = Vector2.ONE
	queue_redraw()

func _draw() -> void:
	if scene_type == "" or alpha <= 0.001:
		return
	var vp := get_viewport_rect()
	var w := vp.size.x
	var h := vp.size.y
	match scene_type:
		"throne_room":    _draw_throne_room(w, h)
		"execution":      _draw_execution(w, h)
		"vale_castle":    _draw_vale_castle(w, h)
		"stormlands_road": _draw_stormlands_road(w, h)
		"ruby_ford_duel": _draw_ruby_ford_duel(w, h)
		"ruby_ford_fall": _draw_ruby_ford_fall(w, h)
		"trident_muster": _draw_trident_muster(w, h)
		"tower_of_joy_gate": _draw_tower_of_joy_gate(w, h)
		"tower_of_joy_fall": _draw_tower_of_joy_fall(w, h)
		"lyanna_chamber": _draw_lyanna_chamber(w, h)
		"kingslayer": _draw_kingslayer(w, h)
		"throne_room_crowned": _draw_throne_room_crowned(w, h)
		"north_road": _draw_north_road(w, h)
		"winterfell_gate": _draw_winterfell_gate(w, h)
		"red_keep_breach": _draw_red_keep_breach(w, h)
	_draw_scene_fx(w, h)
	if overlay_tint.a > 0.001:
		draw_rect(Rect2(0, 0, w, h), Color(
			overlay_tint.r,
			overlay_tint.g,
			overlay_tint.b,
			overlay_tint.a * alpha
		))

# ─── 工具：带 alpha 的颜色 ───────────────────────────────
func _c(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r, g, b, a * alpha)

func _pulse(seed: float, speed: float = 1.0, amplitude: float = 1.0) -> float:
	return (0.5 + 0.5 * sin(time * speed + seed)) * amplitude

func _soft_circle(center: Vector2, radius: float, color: Color, steps: int = 5) -> void:
	for i: int in range(steps, 0, -1):
		var t := float(i) / float(steps)
		var c := Color(color.r, color.g, color.b, color.a * t * t)
		draw_circle(center, radius * t, c)

func _draw_drifters(rect: Rect2, count: int, color: Color,
		size_range: Vector2, drift: Vector2, seed_scale: float = 1.0) -> void:
	for i: int in count:
		var phase := float(i) * (1.37 * seed_scale)
		var px := fposmod(rect.position.x + phase * 47.0 + time * drift.x * (1.0 + float(i % 4) * 0.12), rect.size.x + 80.0) - 40.0
		var py := fposmod(rect.position.y + phase * 29.0 + time * drift.y * (1.0 + float((i + 1) % 5) * 0.10), rect.size.y + 80.0) - 40.0
		var radius := lerpf(size_range.x, size_range.y, 0.5 + 0.5 * sin(phase * 1.9))
		draw_circle(Vector2(px, py), radius, color)

func _draw_scene_fx(w: float, h: float) -> void:
	match scene_type:
		"throne_room", "throne_room_crowned", "kingslayer":
			_draw_firelight_fx(w, h)
		"execution":
			_draw_execution_fx(w, h)
		"vale_castle":
			_draw_vale_mist_fx(w, h)
		"stormlands_road":
			_draw_stormlands_fx(w, h)
		"ruby_ford_duel", "ruby_ford_fall":
			_draw_ruby_ford_fx(w, h)
		"trident_muster":
			_draw_trident_muster_fx(w, h)
		"tower_of_joy_gate", "tower_of_joy_fall":
			_draw_tower_of_joy_fx(w, h)
		"lyanna_chamber":
			_draw_lyanna_chamber_fx(w, h)
		"north_road", "winterfell_gate":
			_draw_winter_fx(w, h)
		"red_keep_breach":
			_draw_red_keep_breach_fx(w, h)

func _draw_firelight_fx(w: float, h: float) -> void:
	for fx: float in [w * 0.18, w * 0.78]:
		var flicker := 16.0 + _pulse(fx * 0.01, 5.3, 10.0)
		_soft_circle(Vector2(fx, h * 0.71), 38.0 + flicker,
			_c(0.95, 0.38, 0.08, 0.10), 6)
		_soft_circle(Vector2(fx, h * 0.71), 18.0 + flicker * 0.3,
			_c(1.0, 0.72, 0.22, 0.18), 4)
	_draw_drifters(Rect2(0, h * 0.50, w, h * 0.24), 18,
		_c(1.0, 0.66, 0.22, 0.16), Vector2(1.2, 2.8), Vector2(18.0, -26.0), 0.7)

func _draw_execution_fx(w: float, h: float) -> void:
	for i: int in 6:
		var px := w * (0.30 + float(i) * 0.10)
		var flicker := 10.0 + _pulse(float(i) * 0.9, 6.4, 8.0)
		_soft_circle(Vector2(px, h * 0.77), 22.0 + flicker,
			_c(0.92, 0.28, 0.08, 0.14), 5)
		_soft_circle(Vector2(px, h * 0.75), 11.0 + flicker * 0.35,
			_c(1.0, 0.78, 0.32, 0.18), 4)
	_draw_drifters(Rect2(w * 0.30, h * 0.38, w * 0.36, h * 0.34), 22,
		_c(0.32, 0.32, 0.34, 0.10), Vector2(2.5, 6.0), Vector2(6.0, -22.0), 1.0)

func _draw_vale_mist_fx(w: float, h: float) -> void:
	for band: int in 3:
		var offset := fposmod(time * (12.0 + band * 4.0) + float(band) * 120.0, w + 220.0) - 110.0
		draw_rect(Rect2(offset - 60.0, h * (0.44 + band * 0.08), w * 0.36, h * 0.045),
			_c(0.82, 0.84, 0.90, 0.05))
	_draw_drifters(Rect2(0, h * 0.10, w, h * 0.36), 14,
		_c(0.88, 0.90, 0.96, 0.08), Vector2(1.0, 2.0), Vector2(10.0, 2.0), 0.8)

func _draw_stormlands_fx(w: float, h: float) -> void:
	for band: int in 4:
		var y := h * (0.18 + band * 0.10)
		var offset := sin(time * (0.8 + band * 0.1) + float(band)) * 22.0
		draw_rect(Rect2(-40.0 + offset, y, w + 80.0, h * 0.024), _c(0.72, 0.72, 0.78, 0.04))
	_draw_drifters(Rect2(0, h * 0.42, w, h * 0.22), 18,
		_c(0.76, 0.70, 0.62, 0.06), Vector2(1.0, 2.4), Vector2(22.0, -6.0), 0.9)

func _draw_ruby_ford_fx(w: float, h: float) -> void:
	for i: int in 8:
		var y := h * (0.68 + float(i) * 0.018)
		var offset := fposmod(time * (34.0 + i * 3.0) + float(i) * 54.0, w + 120.0) - 60.0
		draw_rect(Rect2(offset, y, w * 0.24, 2.0), _c(0.82, 0.90, 0.96, 0.05))
	for i: int in 9:
		var rx := fposmod(time * (16.0 + i * 1.5) + float(i) * 79.0, w + 100.0) - 50.0
		var ry := h * (0.63 + 0.05 * sin(float(i) * 1.7 + time * 0.8))
		_soft_circle(Vector2(rx, ry), 3.0 + _pulse(float(i), 3.0, 1.2), _c(0.88, 0.18, 0.24, 0.16), 3)

func _draw_trident_muster_fx(w: float, h: float) -> void:
	for band: int in 4:
		var y := h * (0.18 + band * 0.08)
		var offset := sin(time * (0.6 + band * 0.08) + float(band) * 0.7) * 28.0
		draw_rect(Rect2(-60.0 + offset, y, w + 120.0, h * 0.022), _c(0.76, 0.78, 0.84, 0.035))
	_draw_drifters(Rect2(0, h * 0.40, w, h * 0.16), 20,
		_c(0.74, 0.68, 0.58, 0.05), Vector2(1.0, 2.0), Vector2(14.0, -5.0), 0.82)

func _draw_tower_of_joy_fx(w: float, h: float) -> void:
	for band: int in 3:
		var y := h * (0.34 + band * 0.12)
		var offset := fposmod(time * (24.0 + band * 4.0) + float(band) * 130.0, w + 180.0) - 90.0
		draw_rect(Rect2(offset, y, w * 0.28, h * 0.028), _c(0.88, 0.72, 0.46, 0.04))
	_draw_drifters(Rect2(0, h * 0.26, w, h * 0.44), 22,
		_c(0.90, 0.78, 0.52, 0.08), Vector2(1.0, 1.8), Vector2(18.0, 7.0), 0.85)

func _draw_lyanna_chamber_fx(w: float, h: float) -> void:
	var candle_flicker := 10.0 + _pulse(1.6, 4.8, 8.0)
	_soft_circle(Vector2(w * 0.72, h * 0.34), 26.0 + candle_flicker,
		_c(1.0, 0.76, 0.34, 0.10), 6)
	_soft_circle(Vector2(w * 0.72, h * 0.34), 10.0 + candle_flicker * 0.25,
		_c(1.0, 0.92, 0.58, 0.18), 4)
	_draw_drifters(Rect2(w * 0.18, h * 0.18, w * 0.56, h * 0.42), 16,
		_c(0.92, 0.88, 0.76, 0.06), Vector2(0.8, 1.6), Vector2(6.0, -10.0), 0.95)

func _draw_winter_fx(w: float, h: float) -> void:
	_draw_drifters(Rect2(0, 0, w, h), 34,
		_c(0.92, 0.95, 1.0, 0.14), Vector2(1.0, 2.2), Vector2(-12.0, 16.0), 0.72)

func _draw_red_keep_breach_fx(w: float, h: float) -> void:
	for fx: float in [w * 0.22, w * 0.50, w * 0.74]:
		var flicker := 14.0 + _pulse(fx * 0.014, 5.8, 9.0)
		_soft_circle(Vector2(fx, h * 0.70), 30.0 + flicker,
			_c(0.92, 0.32, 0.08, 0.08), 5)
		_soft_circle(Vector2(fx, h * 0.70), 14.0 + flicker * 0.3,
			_c(1.0, 0.74, 0.30, 0.16), 4)
	_draw_drifters(Rect2(0, h * 0.26, w, h * 0.42), 24,
		_c(0.24, 0.22, 0.22, 0.10), Vector2(1.2, 2.5), Vector2(8.0, -20.0), 0.9)

# ─── 场景1：铁王座大厅 ───────────────────────────────────
func _draw_throne_room(w: float, h: float) -> void:
	# 地面：深石板色
	draw_rect(Rect2(0, h * 0.75, w, h * 0.25), _c(0.08, 0.07, 0.06))
	# 地面反光（来自火焰）
	draw_rect(Rect2(w * 0.25, h * 0.74, w * 0.5, h * 0.03),
		_c(0.55, 0.18, 0.02, 0.35))

	# 远处墙面：深褐石色
	draw_rect(Rect2(0, 0, w, h * 0.76), _c(0.07, 0.06, 0.05, 0.6))

	# 柱子（两侧）
	for cx: float in [w * 0.12, w * 0.22, w * 0.72, w * 0.82]:
		draw_rect(Rect2(cx - 10, 0, 20, h * 0.76), _c(0.10, 0.09, 0.08))
		# 柱子高光
		draw_rect(Rect2(cx - 10, 0, 4, h * 0.76), _c(0.16, 0.14, 0.12))

	# 地面火盆（两侧，橙红）
	for fx: float in [w * 0.18, w * 0.78]:
		draw_circle(Vector2(fx, h * 0.74), 22.0, _c(0.80, 0.28, 0.02, 0.5))
		draw_circle(Vector2(fx, h * 0.73), 14.0, _c(1.00, 0.55, 0.05, 0.7))
		draw_circle(Vector2(fx, h * 0.72), 7.0,  _c(1.00, 0.90, 0.30, 0.9))

	# 铁王座底座（宽梯形）
	var base := PackedVector2Array([
		Vector2(w * 0.36, h * 0.75),
		Vector2(w * 0.64, h * 0.75),
		Vector2(w * 0.60, h * 0.48),
		Vector2(w * 0.40, h * 0.48),
	])
	draw_polygon(base, [_c(0.12, 0.10, 0.09)])

	# 铁王座主体（用熔剑组成的椅背，多根尖刺向上）
	# 椅背中心矩形
	draw_rect(Rect2(w * 0.43, h * 0.22, w * 0.14, h * 0.27), _c(0.14, 0.12, 0.10))
	# 剑刃尖刺（参差不齐，向上延伸）
	var spike_data: Array = [
		[w * 0.40, h * 0.22, w * 0.045, h * 0.14],
		[w * 0.44, h * 0.22, w * 0.035, h * 0.19],
		[w * 0.48, h * 0.22, w * 0.04,  h * 0.22],
		[w * 0.52, h * 0.22, w * 0.04,  h * 0.20],
		[w * 0.56, h * 0.22, w * 0.035, h * 0.17],
		[w * 0.60, h * 0.22, w * 0.04,  h * 0.13],
	]
	for s: Array in spike_data:
		var sx: float = s[0]; var sy: float = s[1]
		var sw: float = s[2]; var sh: float = s[3]
		var spike := PackedVector2Array([
			Vector2(sx,        sy),
			Vector2(sx + sw,   sy),
			Vector2(sx + sw * 0.5, sy - sh),
		])
		draw_polygon(spike, [_c(0.17, 0.15, 0.13)])
		# 剑刃高光
		draw_line(Vector2(sx + sw * 0.5, sy - sh),
			Vector2(sx + sw * 0.5, sy), _c(0.28, 0.25, 0.22, 0.5), 1.5)

	# 疯王剪影（坐在王座上）
	# 身体
	draw_rect(Rect2(w * 0.46, h * 0.40, w * 0.08, h * 0.09), _c(0.08, 0.06, 0.05))
	# 头部
	draw_circle(Vector2(w * 0.50, h * 0.38), 14.0, _c(0.08, 0.06, 0.05))
	# 皇冠轮廓（三个小尖）
	for ci: int in 3:
		var cx2: float = w * 0.46 + (ci + 0.5) * (w * 0.08 / 3.0)
		draw_line(Vector2(cx2, h * 0.33), Vector2(cx2, h * 0.30),
			_c(0.45, 0.35, 0.08, 0.9), 3.0)

	# 从王座底部涌出的火焰光晕
	draw_rect(Rect2(w * 0.35, h * 0.72, w * 0.30, h * 0.04),
		_c(0.60, 0.20, 0.02, 0.4))
	draw_rect(Rect2(w * 0.40, h * 0.70, w * 0.20, h * 0.03),
		_c(0.80, 0.35, 0.04, 0.3))

# ─── 场景2：行刑室 ───────────────────────────────────────
func _draw_execution(w: float, h: float) -> void:
	# 地面
	draw_rect(Rect2(0, h * 0.80, w, h * 0.20), _c(0.06, 0.05, 0.05))
	# 墙面
	draw_rect(Rect2(0, 0, w, h * 0.81), _c(0.05, 0.04, 0.04, 0.6))

	# 石墙纹理（横缝）
	for ry: int in 8:
		draw_line(Vector2(0, h * 0.10 * ry),
			Vector2(w, h * 0.10 * ry), _c(0.09, 0.08, 0.08, 0.4), 1.0)

	# 右侧火炬
	var tx: float = w * 0.82
	var ty: float = h * 0.32
	draw_rect(Rect2(tx - 5, ty, 10, 40), _c(0.30, 0.20, 0.08))
	draw_circle(Vector2(tx, ty), 28.0, _c(0.65, 0.22, 0.02, 0.35))
	draw_circle(Vector2(tx, ty), 18.0, _c(0.90, 0.45, 0.04, 0.60))
	draw_circle(Vector2(tx, ty), 10.0, _c(1.00, 0.80, 0.20, 0.85))

	# 天花板横梁
	draw_rect(Rect2(w * 0.35, h * 0.04, w * 0.30, 14.0), _c(0.15, 0.12, 0.10))

	# 绞索（细绳从横梁垂下）
	draw_line(Vector2(w * 0.50, h * 0.06), Vector2(w * 0.50, h * 0.22),
		_c(0.35, 0.30, 0.22), 2.5)
	# 绞索圈
	draw_arc(Vector2(w * 0.50, h * 0.25), 14.0, 0, TAU,
		16, _c(0.35, 0.30, 0.22), 2.5)

	# 布兰登剪影（站立，双手被绑在颈后）
	var bx: float = w * 0.50
	var by: float = h * 0.32
	draw_circle(Vector2(bx, by), 13.0, _c(0.07, 0.06, 0.05))         # 头
	draw_rect(Rect2(bx - 12, by + 12, 24, 28), _c(0.07, 0.06, 0.05)) # 躯干
	# 两臂上举（挣扎姿势）
	draw_line(Vector2(bx - 12, by + 20), Vector2(bx - 28, by + 10),
		_c(0.07, 0.06, 0.05), 7.0)
	draw_line(Vector2(bx + 12, by + 20), Vector2(bx + 28, by + 10),
		_c(0.07, 0.06, 0.05), 7.0)
	draw_rect(Rect2(bx - 8, by + 40, 8, 22), _c(0.07, 0.06, 0.05))   # 左腿
	draw_rect(Rect2(bx,     by + 40, 8, 22), _c(0.07, 0.06, 0.05))   # 右腿

	# 瑞卡德剪影（跪地，重甲，在前方）
	var rx2: float = w * 0.42
	var ry2: float = h * 0.55
	# 宽肩盔甲躯干
	draw_rect(Rect2(rx2 - 22, ry2, 44, 30), _c(0.10, 0.09, 0.09))
	# 头盔
	draw_rect(Rect2(rx2 - 14, ry2 - 26, 28, 28), _c(0.12, 0.11, 0.10))
	draw_rect(Rect2(rx2 - 16, ry2 - 10, 32, 12), _c(0.08, 0.07, 0.07))
	# 跪地的腿
	draw_rect(Rect2(rx2 - 20, ry2 + 28, 18, 16), _c(0.10, 0.09, 0.09))
	draw_rect(Rect2(rx2 + 4,  ry2 + 28, 18, 16), _c(0.10, 0.09, 0.09))

	# 地面火光从下方蔓延（疯王的火焰斗士）
	for fi: int in 5:
		var fpx: float = w * (0.30 + fi * 0.10)
		draw_rect(Rect2(fpx - 18, h * 0.78, 36, 22), _c(0.70, 0.22, 0.02, 0.45))
		draw_rect(Rect2(fpx - 10, h * 0.75, 20, 14), _c(1.00, 0.50, 0.06, 0.60))
		draw_rect(Rect2(fpx - 5,  h * 0.73,  10, 8), _c(1.00, 0.85, 0.30, 0.80))

# ─── 场景3：鹰巢城（谷地）───────────────────────────────
func _draw_vale_castle(w: float, h: float) -> void:
	# 天空渐变（黎明前的深蓝紫）
	draw_rect(Rect2(0, 0, w, h), _c(0.04, 0.03, 0.08))
	for i: int in 12:
		var yy: float = h * i / 12.0
		var t: float  = float(i) / 12.0
		var sky := Color(
			lerp(0.04, 0.12, t),
			lerp(0.03, 0.06, t),
			lerp(0.08, 0.14, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 12.0 + 1.0), sky)

	# 远山剪影（锯齿状山峰）
	var peak_pts := PackedVector2Array([
		Vector2(0,        h * 0.85),
		Vector2(0,        h * 0.65),
		Vector2(w * 0.08, h * 0.45),
		Vector2(w * 0.15, h * 0.58),
		Vector2(w * 0.22, h * 0.38),
		Vector2(w * 0.28, h * 0.52),
		Vector2(w * 0.35, h * 0.30),
		Vector2(w * 0.42, h * 0.50),
		Vector2(w * 0.50, h * 0.28),
		Vector2(w * 0.58, h * 0.48),
		Vector2(w * 0.65, h * 0.32),
		Vector2(w * 0.72, h * 0.55),
		Vector2(w * 0.80, h * 0.40),
		Vector2(w * 0.88, h * 0.58),
		Vector2(w * 0.94, h * 0.42),
		Vector2(w,        h * 0.60),
		Vector2(w,        h * 0.85),
	])
	draw_polygon(peak_pts, [_c(0.08, 0.07, 0.10)])
	# 雪顶高光
	for pi: int in [2, 4, 6, 8, 10, 12, 14]:
		if pi < peak_pts.size():
			draw_circle(peak_pts[pi], 6.0, _c(0.85, 0.88, 0.95, 0.5))

	# 薄雾层
	draw_rect(Rect2(0, h * 0.60, w, h * 0.08), _c(0.70, 0.72, 0.80, 0.12))

	# 鹰巢城塔楼（极细高塔，耸入云端）
	var tower_data: Array = [
		[w * 0.42, h * 0.05, 28.0, h * 0.60],
		[w * 0.48, h * 0.02, 22.0, h * 0.63],
		[w * 0.54, h * 0.06, 26.0, h * 0.59],
		[w * 0.38, h * 0.18, 18.0, h * 0.50],
		[w * 0.60, h * 0.14, 18.0, h * 0.54],
	]
	for td: Array in tower_data:
		var ttx: float = td[0]; var tty: float = td[1]
		var ttw: float = td[2]; var tth: float = td[3]
		# 塔身
		draw_rect(Rect2(ttx - ttw * 0.5, tty, ttw, tth), _c(0.13, 0.12, 0.16))
		# 塔顶尖锥
		var cone := PackedVector2Array([
			Vector2(ttx - ttw * 0.5 - 4, tty),
			Vector2(ttx + ttw * 0.5 + 4, tty),
			Vector2(ttx, tty - 30),
		])
		draw_polygon(cone, [_c(0.18, 0.16, 0.22)])
		# 窗口亮光
		for wi: int in 3:
			draw_rect(Rect2(ttx - 4, tty + tth * 0.25 + wi * tth * 0.2,
				8, 10), _c(0.70, 0.60, 0.20, 0.5))

	# 城墙连接各塔
	draw_rect(Rect2(w * 0.36, h * 0.62, w * 0.28, 10.0), _c(0.13, 0.12, 0.16))
	# 城垛
	for mi: int in 7:
		draw_rect(Rect2(w * 0.365 + mi * (w * 0.28 / 7.0), h * 0.59, 14, 10),
			_c(0.15, 0.14, 0.18))

	# 琼恩·艾林剪影（站立在城墙前，面对来使）
	var lx: float = w * 0.48; var ly: float = h * 0.63
	draw_circle(Vector2(lx, ly - 18), 11.0, _c(0.06, 0.05, 0.08))
	draw_rect(Rect2(lx - 10, ly - 8, 20, 24), _c(0.06, 0.05, 0.08))
	# 长袍/披风
	var robe := PackedVector2Array([
		Vector2(lx - 10, ly - 8),
		Vector2(lx + 10, ly - 8),
		Vector2(lx + 16, ly + 28),
		Vector2(lx - 16, ly + 28),
	])
	draw_polygon(robe, [_c(0.06, 0.05, 0.08)])

# ─── 场景4：风暴地山道 ──────────────────────────────────
func _draw_stormlands_road(w: float, h: float) -> void:
	# 乌云密布的天空渐变
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float  = float(i) / 10.0
		var sky := Color(
			lerp(0.05, 0.12, t),
			lerp(0.05, 0.10, t),
			lerp(0.08, 0.13, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	# 远处山脊（连绵起伏）
	var ridge := PackedVector2Array([
		Vector2(0,        h * 0.70),
		Vector2(0,        h * 0.55),
		Vector2(w * 0.05, h * 0.48),
		Vector2(w * 0.12, h * 0.52),
		Vector2(w * 0.20, h * 0.44),
		Vector2(w * 0.28, h * 0.50),
		Vector2(w * 0.38, h * 0.42),
		Vector2(w * 0.50, h * 0.48),
		Vector2(w * 0.62, h * 0.40),
		Vector2(w * 0.72, h * 0.50),
		Vector2(w * 0.82, h * 0.44),
		Vector2(w * 0.90, h * 0.52),
		Vector2(w,        h * 0.46),
		Vector2(w,        h * 0.70),
	])
	draw_polygon(ridge, [_c(0.09, 0.09, 0.10)])

	# 近景地面（丘陵草地）
	draw_rect(Rect2(0, h * 0.68, w, h * 0.32), _c(0.10, 0.10, 0.08))
	# 地面起伏
	for gi: int in 5:
		var gpx: float = w * gi / 4.0
		var hill := PackedVector2Array([
			Vector2(gpx - w * 0.15, h),
			Vector2(gpx - w * 0.15, h * 0.78),
			Vector2(gpx,            h * 0.68),
			Vector2(gpx + w * 0.15, h * 0.78),
			Vector2(gpx + w * 0.15, h),
		])
		draw_polygon(hill, [_c(0.11, 0.11, 0.09)])

	# 道路（中央，向远方延伸）
	var road := PackedVector2Array([
		Vector2(w * 0.42, h * 0.68),
		Vector2(w * 0.58, h * 0.68),
		Vector2(w * 0.65, h),
		Vector2(w * 0.35, h),
	])
	draw_polygon(road, [_c(0.13, 0.12, 0.10)])

	# 乱云（深灰色团块）
	for ci: int in 6:
		var cpx: float = w * (0.08 + ci * 0.16)
		var cpy: float = h * (0.12 + (ci % 3) * 0.06)
		draw_circle(Vector2(cpx,        cpy), 55.0, _c(0.10, 0.10, 0.12, 0.8))
		draw_circle(Vector2(cpx + 35,   cpy - 8),  45.0, _c(0.12, 0.12, 0.14, 0.7))
		draw_circle(Vector2(cpx - 25,   cpy + 5),  40.0, _c(0.09, 0.09, 0.11, 0.7))

	# 劳勃剪影（左，体型高大，手持战锤）
	var rx3: float = w * 0.41; var ry3: float = h * 0.55
	draw_circle(Vector2(rx3, ry3 - 22), 14.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(rx3 - 14, ry3 - 8,  28, 32), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(rx3 - 6,  ry3 + 24, 10, 20), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(rx3 + 2,  ry3 + 24, 10, 20), _c(0.06, 0.05, 0.04))
	# 举起的战锤
	draw_line(Vector2(rx3 + 14, ry3 - 4), Vector2(rx3 + 32, ry3 - 22),
		_c(0.06, 0.05, 0.04), 7.0)
	draw_rect(Rect2(rx3 + 26, ry3 - 30, 18, 12), _c(0.08, 0.07, 0.06))

	# 奈德剪影（右，体型匀称，手持剑）
	var nx: float = w * 0.56; var ny: float = h * 0.56
	draw_circle(Vector2(nx, ny - 20), 12.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(nx - 11, ny - 8,  22, 28), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(nx - 5,  ny + 20, 9, 18), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(nx + 2,  ny + 20, 9, 18), _c(0.06, 0.05, 0.04))
	# 剑（垂直持握）
	draw_line(Vector2(nx + 11, ny - 2), Vector2(nx + 20, ny - 28),
		_c(0.06, 0.05, 0.04), 5.0)
	draw_line(Vector2(nx + 15, ny - 15), Vector2(nx + 28, ny - 10),
		_c(0.06, 0.05, 0.04), 3.5)  # 护手

	# 旗帜（两人身后，义军旗）
	draw_rect(Rect2(w * 0.47, h * 0.32, 5.0, h * 0.30), _c(0.16, 0.14, 0.12))
	# 旗面（飘动效果，两段矩形偏移）
	draw_rect(Rect2(w * 0.472, h * 0.32,  w * 0.07, h * 0.055),
		_c(0.52, 0.18, 0.10, 0.9))
	draw_rect(Rect2(w * 0.476, h * 0.375, w * 0.065, h * 0.050),
		_c(0.52, 0.18, 0.10, 0.85))
	draw_rect(Rect2(w * 0.474, h * 0.425, w * 0.060, h * 0.045),
		_c(0.45, 0.15, 0.08, 0.8))


# ─── 场景5：红宝石滩对决 ─────────────────────────────────
func _draw_ruby_ford_duel(w: float, h: float) -> void:
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(
			lerp(0.10, 0.18, t),
			lerp(0.11, 0.17, t),
			lerp(0.14, 0.19, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	var left_bank := PackedVector2Array([
		Vector2(0, h * 0.78),
		Vector2(0, h * 0.55),
		Vector2(w * 0.14, h * 0.58),
		Vector2(w * 0.26, h * 0.52),
		Vector2(w * 0.34, h * 0.58),
		Vector2(w * 0.44, h * 0.76),
		Vector2(w * 0.44, h),
		Vector2(0, h),
	])
	var right_bank := PackedVector2Array([
		Vector2(w, h * 0.80),
		Vector2(w, h * 0.54),
		Vector2(w * 0.90, h * 0.57),
		Vector2(w * 0.78, h * 0.51),
		Vector2(w * 0.68, h * 0.59),
		Vector2(w * 0.56, h * 0.78),
		Vector2(w * 0.56, h),
		Vector2(w, h),
	])
	draw_polygon(left_bank, [_c(0.18, 0.16, 0.11)])
	draw_polygon(right_bank, [_c(0.17, 0.14, 0.10)])

	draw_rect(Rect2(w * 0.40, h * 0.54, w * 0.20, h * 0.40), _c(0.14, 0.23, 0.30))
	for ri: int in 7:
		var ry: float = h * (0.58 + ri * 0.045)
		draw_line(Vector2(w * 0.40, ry), Vector2(w * 0.60, ry + 6.0),
			_c(0.32, 0.48, 0.58, 0.35), 2.0)

	for gem: Vector2 in [
		Vector2(w * 0.47, h * 0.63), Vector2(w * 0.51, h * 0.60),
		Vector2(w * 0.54, h * 0.66), Vector2(w * 0.49, h * 0.69)
	]:
		draw_circle(gem, 5.5, _c(0.82, 0.10, 0.14, 0.95))
		draw_circle(gem + Vector2(1.0, -1.0), 2.5, _c(1.0, 0.55, 0.60, 0.65))

	var robert_x := w * 0.34
	var robert_y := h * 0.54
	draw_circle(Vector2(robert_x, robert_y - 24.0), 16.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(robert_x - 18.0, robert_y - 10.0, 36.0, 40.0), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(robert_x - 10.0, robert_y + 28.0, 12.0, 22.0), _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(robert_x + 2.0, robert_y + 28.0, 12.0, 22.0), _c(0.06, 0.05, 0.04))
	draw_line(Vector2(robert_x + 15.0, robert_y - 2.0), Vector2(robert_x + 46.0, robert_y - 28.0),
		_c(0.06, 0.05, 0.04), 8.0)
	draw_rect(Rect2(robert_x + 36.0, robert_y - 38.0, 22.0, 16.0), _c(0.10, 0.09, 0.08))

	var rhaegar_x := w * 0.66
	var rhaegar_y := h * 0.55
	draw_circle(Vector2(rhaegar_x, rhaegar_y - 22.0), 14.0, _c(0.08, 0.06, 0.05))
	draw_rect(Rect2(rhaegar_x - 14.0, rhaegar_y - 8.0, 28.0, 34.0), _c(0.08, 0.06, 0.05))
	draw_line(Vector2(rhaegar_x - 10.0, rhaegar_y - 2.0), Vector2(rhaegar_x - 40.0, rhaegar_y - 18.0),
		_c(0.08, 0.06, 0.05), 5.0)
	draw_line(Vector2(rhaegar_x - 40.0, rhaegar_y - 18.0), Vector2(rhaegar_x - 54.0, rhaegar_y - 40.0),
		_c(0.12, 0.12, 0.12), 3.0)
	draw_polygon(PackedVector2Array([
		Vector2(rhaegar_x - 4.0, rhaegar_y - 38.0),
		Vector2(rhaegar_x + 4.0, rhaegar_y - 38.0),
		Vector2(rhaegar_x, rhaegar_y - 52.0),
	]), [_c(0.40, 0.12, 0.12)])

	draw_line(Vector2(w * 0.44, h * 0.48), Vector2(w * 0.56, h * 0.44), _c(0.80, 0.78, 0.72, 0.45), 3.0)
	draw_circle(Vector2(w * 0.50, h * 0.46), 10.0, _c(0.95, 0.90, 0.65, 0.18))


# ─── 场景6：红宝石滩坠落 ───────────────────────────────
func _draw_ruby_ford_fall(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h * 0.55), _c(0.11, 0.12, 0.16))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), _c(0.14, 0.24, 0.32))
	for ri: int in 8:
		var ry: float = h * (0.60 + ri * 0.04)
		draw_line(Vector2(w * 0.12, ry), Vector2(w * 0.88, ry + 8.0),
			_c(0.30, 0.48, 0.58, 0.32), 2.0)

	var body_x := w * 0.53
	var body_y := h * 0.66
	draw_circle(Vector2(body_x - 46.0, body_y - 26.0), 12.0, _c(0.10, 0.08, 0.07))
	draw_polygon(PackedVector2Array([
		Vector2(body_x - 30.0, body_y - 12.0),
		Vector2(body_x + 34.0, body_y - 24.0),
		Vector2(body_x + 54.0, body_y + 6.0),
		Vector2(body_x - 8.0, body_y + 18.0),
	]), [_c(0.12, 0.12, 0.13)])
	draw_line(Vector2(body_x + 18.0, body_y - 18.0), Vector2(body_x + 78.0, body_y - 46.0),
		_c(0.18, 0.18, 0.19), 4.0)

	for gem: Vector2 in [
		Vector2(body_x - 18.0, body_y - 10.0), Vector2(body_x + 2.0, body_y - 4.0),
		Vector2(body_x + 24.0, body_y + 6.0), Vector2(body_x - 4.0, body_y + 18.0),
		Vector2(body_x + 38.0, body_y - 16.0), Vector2(body_x - 30.0, body_y + 10.0)
	]:
		draw_circle(gem, 6.0, _c(0.84, 0.10, 0.15, 0.96))
		draw_circle(gem + Vector2(1.5, -1.5), 2.0, _c(1.0, 0.65, 0.70, 0.7))

	var robert_x := w * 0.28
	var robert_y := h * 0.56
	draw_circle(Vector2(robert_x, robert_y - 18.0), 13.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(robert_x - 14.0, robert_y - 4.0, 28.0, 30.0), _c(0.06, 0.05, 0.04))
	draw_line(Vector2(robert_x + 12.0, robert_y + 2.0), Vector2(robert_x + 38.0, robert_y - 4.0),
		_c(0.06, 0.05, 0.04), 6.0)
	draw_rect(Rect2(robert_x + 32.0, robert_y - 12.0, 16.0, 12.0), _c(0.10, 0.09, 0.08))


# ─── 场景6.5：三叉戟北岸集结 ───────────────────────────
func _draw_trident_muster(w: float, h: float) -> void:
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(
			lerp(0.14, 0.28, t),
			lerp(0.16, 0.24, t),
			lerp(0.18, 0.26, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	var north_bank := PackedVector2Array([
		Vector2(0, h * 0.74), Vector2(0, h * 0.52), Vector2(w * 0.16, h * 0.48),
		Vector2(w * 0.30, h * 0.54), Vector2(w * 0.46, h * 0.50), Vector2(w * 0.62, h * 0.58),
		Vector2(w * 0.78, h * 0.54), Vector2(w, h * 0.60), Vector2(w, h * 0.74),
	])
	var south_bank := PackedVector2Array([
		Vector2(0, h), Vector2(0, h * 0.78), Vector2(w * 0.18, h * 0.76),
		Vector2(w * 0.36, h * 0.82), Vector2(w * 0.58, h * 0.78), Vector2(w * 0.76, h * 0.84),
		Vector2(w, h * 0.80), Vector2(w, h),
	])
	draw_polygon(north_bank, [_c(0.26, 0.24, 0.18)])
	draw_rect(Rect2(0, h * 0.74, w, h * 0.10), _c(0.20, 0.30, 0.36))
	for ri: int in 6:
		var ry: float = h * (0.76 + ri * 0.012)
		draw_line(Vector2(0, ry), Vector2(w, ry + 4.0), _c(0.44, 0.56, 0.62, 0.24), 2.0)
	draw_polygon(south_bank, [_c(0.22, 0.18, 0.14)])

	for line: int in 3:
		var y := h * (0.60 + float(line) * 0.045)
		for rank: int in 11:
			var x := w * (0.14 + float(rank) * 0.055)
			draw_circle(Vector2(x, y - 10.0), 3.8, _c(0.10, 0.09, 0.08, 0.82))
			draw_rect(Rect2(x - 3.0, y - 6.0, 6.0, 10.0), _c(0.10, 0.09, 0.08, 0.82))

	for banner: Array in [
		[w * 0.22, h * 0.48, Color(0.72, 0.74, 0.78, 0.85)],
		[w * 0.42, h * 0.46, Color(0.82, 0.68, 0.12, 0.88)],
		[w * 0.64, h * 0.47, Color(0.36, 0.52, 0.78, 0.88)],
	]:
		var bx: float = banner[0]
		var by: float = banner[1]
		var col: Color = banner[2]
		draw_line(Vector2(bx, by), Vector2(bx, by + 74.0), _c(0.28, 0.22, 0.14, 0.9), 3.0)
		draw_polygon(PackedVector2Array([
			Vector2(bx, by), Vector2(bx + 34.0, by + 6.0),
			Vector2(bx + 28.0, by + 26.0), Vector2(bx, by + 20.0),
		]), [Color(col.r, col.g, col.b, col.a * alpha)])

	var robert_x := w * 0.38
	var robert_y := h * 0.58
	draw_circle(Vector2(robert_x, robert_y - 16.0), 11.0, _c(0.08, 0.07, 0.06, 0.95))
	draw_rect(Rect2(robert_x - 11.0, robert_y - 2.0, 22.0, 30.0), _c(0.08, 0.07, 0.06, 0.95))
	draw_line(Vector2(robert_x + 8.0, robert_y + 2.0), Vector2(robert_x + 34.0, robert_y - 16.0),
		_c(0.08, 0.07, 0.06, 0.95), 6.0)
	draw_rect(Rect2(robert_x + 28.0, robert_y - 24.0, 18.0, 12.0), _c(0.12, 0.10, 0.10, 0.92))

	var ned_x := w * 0.50
	draw_circle(Vector2(ned_x, robert_y - 14.0), 9.0, _c(0.08, 0.07, 0.06, 0.92))
	draw_rect(Rect2(ned_x - 9.0, robert_y - 1.0, 18.0, 24.0), _c(0.08, 0.07, 0.06, 0.92))
	draw_line(Vector2(ned_x + 8.0, robert_y + 2.0), Vector2(ned_x + 26.0, robert_y - 18.0),
		_c(0.70, 0.72, 0.76, 0.60), 2.5)

	var vale_x := w * 0.60
	draw_circle(Vector2(vale_x, robert_y - 13.0), 8.0, _c(0.08, 0.07, 0.06, 0.88))
	draw_rect(Rect2(vale_x - 8.0, robert_y, 16.0, 20.0), _c(0.08, 0.07, 0.06, 0.88))

	for pike: int in 7:
		var px := w * (0.70 + float(pike) * 0.03)
		draw_line(Vector2(px, h * 0.58), Vector2(px, h * 0.46), _c(0.26, 0.24, 0.22, 0.86), 2.0)
		draw_polygon(PackedVector2Array([
			Vector2(px - 3.0, h * 0.46), Vector2(px + 3.0, h * 0.46), Vector2(px, h * 0.44),
		]), [_c(0.66, 0.68, 0.72, 0.75)])


# ─── 场景7：极乐塔门前 ─────────────────────────────────
func _draw_tower_of_joy_gate(w: float, h: float) -> void:
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(
			lerp(0.34, 0.60, t),
			lerp(0.20, 0.44, t),
			lerp(0.14, 0.26, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), _c(0.50, 0.32, 0.18))
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.62, h * 0.72),
		Vector2(w * 0.72, h * 0.18),
		Vector2(w * 0.82, h * 0.18),
		Vector2(w * 0.88, h * 0.72),
	]), [_c(0.75, 0.70, 0.58)])
	draw_rect(Rect2(w * 0.70, h * 0.46, w * 0.10, h * 0.26), _c(0.58, 0.50, 0.38))
	draw_arc(Vector2(w * 0.75, h * 0.46), w * 0.05, PI, TAU, 20, _c(0.58, 0.50, 0.38), 10.0)
	draw_rect(Rect2(w * 0.73, h * 0.53, w * 0.04, h * 0.19), _c(0.12, 0.10, 0.08))

	for dune: Array in [
		[w * 0.14, h * 0.80, w * 0.22, h * 0.09],
		[w * 0.44, h * 0.82, w * 0.30, h * 0.07],
		[w * 0.84, h * 0.84, w * 0.24, h * 0.06],
	]:
		draw_circle(Vector2(dune[0], dune[1]), dune[2], _c(0.58, 0.38, 0.20, 0.16))

	var dayne_x := w * 0.54
	var base_y := h * 0.66
	draw_circle(Vector2(dayne_x, base_y - 22.0), 13.0, _c(0.07, 0.06, 0.05))
	draw_rect(Rect2(dayne_x - 12.0, base_y - 8.0, 24.0, 34.0), _c(0.07, 0.06, 0.05))
	draw_line(Vector2(dayne_x - 8.0, base_y - 4.0), Vector2(dayne_x - 38.0, base_y - 28.0),
		_c(0.07, 0.06, 0.05), 4.0)
	draw_line(Vector2(dayne_x + 10.0, base_y - 4.0), Vector2(dayne_x + 42.0, base_y - 28.0),
		_c(0.07, 0.06, 0.05), 4.0)

	var ned_x := w * 0.34
	draw_circle(Vector2(ned_x, base_y - 18.0), 12.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(ned_x - 11.0, base_y - 5.0, 22.0, 28.0), _c(0.06, 0.05, 0.04))
	draw_line(Vector2(ned_x + 10.0, base_y - 2.0), Vector2(ned_x + 30.0, base_y - 26.0),
		_c(0.06, 0.05, 0.04), 4.0)

	var howland_x := w * 0.25
	draw_circle(Vector2(howland_x, base_y - 14.0), 10.0, _c(0.06, 0.05, 0.04))
	draw_rect(Rect2(howland_x - 9.0, base_y - 2.0, 18.0, 22.0), _c(0.06, 0.05, 0.04))
	draw_line(Vector2(howland_x + 9.0, base_y + 6.0), Vector2(howland_x + 28.0, base_y - 8.0),
		_c(0.06, 0.05, 0.04), 3.0)


# ─── 场景8：极乐塔门前，晓光坠地 ─────────────────────
func _draw_tower_of_joy_fall(w: float, h: float) -> void:
	_draw_tower_of_joy_gate(w, h)
	var base_y := h * 0.70
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.50, base_y - 10.0),
		Vector2(w * 0.59, base_y - 16.0),
		Vector2(w * 0.63, base_y + 8.0),
		Vector2(w * 0.54, base_y + 18.0),
	]), [_c(0.11, 0.10, 0.09)])
	draw_circle(Vector2(w * 0.48, base_y - 12.0), 11.0, _c(0.09, 0.08, 0.07))
	draw_line(Vector2(w * 0.58, base_y - 18.0), Vector2(w * 0.71, base_y + 14.0),
		_c(0.82, 0.82, 0.84, 0.55), 4.0)
	draw_circle(Vector2(w * 0.43, base_y + 6.0), 5.0, _c(0.46, 0.10, 0.10, 0.8))


# ─── 场景9：莱安娜房间 ─────────────────────────────────
func _draw_lyanna_chamber(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), _c(0.05, 0.04, 0.05))
	for ry: int in 8:
		draw_line(Vector2(0, h * 0.12 * ry), Vector2(w, h * 0.12 * ry), _c(0.10, 0.09, 0.10, 0.35), 1.0)

	draw_rect(Rect2(w * 0.18, h * 0.48, w * 0.52, h * 0.18), _c(0.20, 0.14, 0.12))
	draw_rect(Rect2(w * 0.16, h * 0.44, w * 0.56, h * 0.06), _c(0.28, 0.18, 0.16))
	draw_rect(Rect2(w * 0.22, h * 0.40, w * 0.22, h * 0.10), _c(0.42, 0.34, 0.30))
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.32, h * 0.46),
		Vector2(w * 0.56, h * 0.48),
		Vector2(w * 0.64, h * 0.58),
		Vector2(w * 0.40, h * 0.60),
	]), [_c(0.62, 0.16, 0.18, 0.65)])

	draw_circle(Vector2(w * 0.32, h * 0.46), 14.0, _c(0.84, 0.80, 0.72, 0.55))
	draw_rect(Rect2(w * 0.34, h * 0.45, w * 0.16, h * 0.06), _c(0.82, 0.76, 0.70, 0.45))

	for candle: Vector2 in [Vector2(w * 0.76, h * 0.34), Vector2(w * 0.82, h * 0.42)]:
		draw_rect(Rect2(candle.x - 4.0, candle.y, 8.0, 28.0), _c(0.76, 0.72, 0.56))
		draw_circle(Vector2(candle.x, candle.y - 6.0), 10.0, _c(1.0, 0.74, 0.28, 0.32))
		draw_circle(Vector2(candle.x, candle.y - 6.0), 5.0, _c(1.0, 0.92, 0.46, 0.75))

	draw_rect(Rect2(w * 0.60, h * 0.58, w * 0.13, h * 0.07), _c(0.18, 0.14, 0.12))
	draw_circle(Vector2(w * 0.665, h * 0.56), 18.0, _c(0.38, 0.34, 0.28, 0.40))


# ─── 场景10：弑君者 ─────────────────────────────────────
func _draw_kingslayer(w: float, h: float) -> void:
	_draw_throne_room(w, h)
	draw_rect(Rect2(w * 0.38, h * 0.70, w * 0.24, h * 0.02), _c(0.50, 0.08, 0.08, 0.65))
	draw_rect(Rect2(w * 0.44, h * 0.63, w * 0.14, h * 0.02), _c(0.50, 0.08, 0.08, 0.60))

	var jaime_x := w * 0.58
	var jaime_y := h * 0.49
	draw_circle(Vector2(jaime_x, jaime_y - 20.0), 13.0, _c(0.88, 0.88, 0.84, 0.92))
	draw_rect(Rect2(jaime_x - 13.0, jaime_y - 6.0, 26.0, 34.0), _c(0.86, 0.86, 0.82, 0.90))
	draw_line(Vector2(jaime_x + 10.0, jaime_y - 2.0), Vector2(jaime_x + 34.0, jaime_y - 30.0),
		_c(0.88, 0.88, 0.84, 0.90), 4.0)
	draw_line(Vector2(jaime_x + 34.0, jaime_y - 30.0), Vector2(jaime_x + 54.0, jaime_y - 52.0),
		_c(0.70, 0.70, 0.72, 0.75), 3.0)

	var king_body := PackedVector2Array([
		Vector2(w * 0.46, h * 0.66),
		Vector2(w * 0.57, h * 0.64),
		Vector2(w * 0.60, h * 0.70),
		Vector2(w * 0.50, h * 0.72),
	])
	draw_polygon(king_body, [_c(0.36, 0.10, 0.12, 0.92)])
	draw_circle(Vector2(w * 0.44, h * 0.65), 11.0, _c(0.72, 0.62, 0.22, 0.75))
	for ci: int in 3:
		var cx: float = w * 0.435 + ci * 6.0
		draw_line(Vector2(cx, h * 0.63), Vector2(cx, h * 0.60), _c(0.72, 0.62, 0.22, 0.82), 2.0)


# ─── 场景11：劳勃登上铁王座 ───────────────────────────
func _draw_throne_room_crowned(w: float, h: float) -> void:
	_draw_throne_room(w, h)
	# 覆盖王座上的人物为更厚重的劳勃剪影
	draw_rect(Rect2(w * 0.445, h * 0.39, w * 0.11, h * 0.12), _c(0.09, 0.07, 0.06))
	draw_circle(Vector2(w * 0.50, h * 0.36), 16.0, _c(0.09, 0.07, 0.06))
	draw_line(Vector2(w * 0.45, h * 0.46), Vector2(w * 0.40, h * 0.56), _c(0.09, 0.07, 0.06), 8.0)
	draw_line(Vector2(w * 0.55, h * 0.46), Vector2(w * 0.60, h * 0.56), _c(0.09, 0.07, 0.06), 8.0)
	# 王座前一柄斜置战锤
	draw_line(Vector2(w * 0.58, h * 0.57), Vector2(w * 0.66, h * 0.70), _c(0.14, 0.12, 0.10), 5.0)
	draw_rect(Rect2(w * 0.64, h * 0.68, w * 0.03, h * 0.02), _c(0.20, 0.18, 0.16))
	# 奈德背影
	draw_circle(Vector2(w * 0.28, h * 0.60), 12.0, _c(0.07, 0.06, 0.05, 0.85))
	draw_rect(Rect2(w * 0.27, h * 0.61, w * 0.03, h * 0.10), _c(0.07, 0.06, 0.05, 0.85))


# ─── 场景12：北返之路 ─────────────────────────────────
func _draw_north_road(w: float, h: float) -> void:
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(
			lerp(0.10, 0.22, t),
			lerp(0.13, 0.20, t),
			lerp(0.16, 0.24, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	draw_polygon(PackedVector2Array([
		Vector2(0, h * 0.76), Vector2(0, h * 0.50), Vector2(w * 0.14, h * 0.38),
		Vector2(w * 0.28, h * 0.48), Vector2(w * 0.44, h * 0.34), Vector2(w * 0.62, h * 0.50),
		Vector2(w * 0.78, h * 0.36), Vector2(w, h * 0.52), Vector2(w, h * 0.76),
	]), [_c(0.16, 0.18, 0.20)])
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), _c(0.72, 0.76, 0.80))
	var road := PackedVector2Array([
		Vector2(w * 0.46, h * 0.62),
		Vector2(w * 0.56, h * 0.62),
		Vector2(w * 0.68, h),
		Vector2(w * 0.34, h),
	])
	draw_polygon(road, [_c(0.44, 0.40, 0.34)])
	for si: int in 4:
		draw_rect(Rect2(w * (0.12 + si * 0.18), h * (0.75 + (si % 2) * 0.03), w * 0.14, h * 0.02),
			_c(0.86, 0.88, 0.92, 0.45))

	var horse_x := w * 0.48
	var horse_y := h * 0.68
	draw_rect(Rect2(horse_x - 24.0, horse_y - 4.0, 48.0, 18.0), _c(0.09, 0.08, 0.07))
	draw_rect(Rect2(horse_x + 18.0, horse_y - 10.0, 14.0, 12.0), _c(0.09, 0.08, 0.07))
	draw_line(Vector2(horse_x - 16.0, horse_y + 14.0), Vector2(horse_x - 20.0, horse_y + 34.0), _c(0.09, 0.08, 0.07), 4.0)
	draw_line(Vector2(horse_x - 4.0, horse_y + 14.0), Vector2(horse_x - 8.0, horse_y + 34.0), _c(0.09, 0.08, 0.07), 4.0)
	draw_line(Vector2(horse_x + 10.0, horse_y + 14.0), Vector2(horse_x + 8.0, horse_y + 34.0), _c(0.09, 0.08, 0.07), 4.0)
	draw_line(Vector2(horse_x + 22.0, horse_y + 14.0), Vector2(horse_x + 20.0, horse_y + 34.0), _c(0.09, 0.08, 0.07), 4.0)
	draw_circle(Vector2(horse_x - 4.0, horse_y - 18.0), 10.0, _c(0.08, 0.07, 0.06))
	draw_rect(Rect2(horse_x - 14.0, horse_y - 10.0, 20.0, 10.0), _c(0.08, 0.07, 0.06))


# ─── 场景13：临冬城门前 ─────────────────────────────────
func _draw_winterfell_gate(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), _c(0.12, 0.14, 0.18))
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), _c(0.82, 0.84, 0.88))
	draw_rect(Rect2(w * 0.12, h * 0.26, w * 0.76, h * 0.34), _c(0.26, 0.28, 0.30))
	draw_rect(Rect2(w * 0.18, h * 0.18, w * 0.14, h * 0.42), _c(0.22, 0.24, 0.26))
	draw_rect(Rect2(w * 0.68, h * 0.18, w * 0.14, h * 0.42), _c(0.22, 0.24, 0.26))
	draw_rect(Rect2(w * 0.40, h * 0.34, w * 0.20, h * 0.26), _c(0.12, 0.10, 0.10))
	draw_arc(Vector2(w * 0.50, h * 0.34), w * 0.10, PI, TAU, 24, _c(0.12, 0.10, 0.10), 12.0)
	for pi: int in 8:
		draw_rect(Rect2(w * (0.16 + pi * 0.08), h * 0.22, w * 0.03, h * 0.04), _c(0.32, 0.34, 0.36))

	var rider_x := w * 0.30
	var rider_y := h * 0.70
	draw_rect(Rect2(rider_x - 22.0, rider_y - 4.0, 44.0, 16.0), _c(0.10, 0.09, 0.08))
	draw_rect(Rect2(rider_x + 14.0, rider_y - 10.0, 12.0, 10.0), _c(0.10, 0.09, 0.08))
	draw_circle(Vector2(rider_x - 2.0, rider_y - 18.0), 10.0, _c(0.08, 0.07, 0.06))
	draw_rect(Rect2(rider_x - 12.0, rider_y - 10.0, 18.0, 8.0), _c(0.08, 0.07, 0.06))

	for child: Array in [
		[w * 0.56, h * 0.72, 11.0],
		[w * 0.62, h * 0.76, 9.0],
	]:
		var cx: float = child[0]
		var cy: float = child[1]
		var r: float = child[2]
		draw_circle(Vector2(cx, cy - r - 6.0), r, _c(0.12, 0.10, 0.09))
		draw_rect(Rect2(cx - r, cy - 6.0, r * 2.0, r * 2.4), _c(0.12, 0.10, 0.09))

	for drift: Array in [
		[w * 0.10, h * 0.24, w * 0.18],
		[w * 0.70, h * 0.30, w * 0.14],
		[w * 0.42, h * 0.12, w * 0.20],
	]:
		draw_rect(Rect2(drift[0], drift[1], drift[2], h * 0.015), _c(0.92, 0.94, 0.98, 0.38))


# ─── 场景14：红堡破门 ─────────────────────────────────
func _draw_red_keep_breach(w: float, h: float) -> void:
	for i: int in 10:
		var yy: float = h * i / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(
			lerp(0.14, 0.38, t),
			lerp(0.08, 0.16, t),
			lerp(0.08, 0.14, t),
			alpha)
		draw_rect(Rect2(0, yy, w, h / 10.0 + 1.0), sky)

	draw_rect(Rect2(0, h * 0.70, w, h * 0.30), _c(0.18, 0.14, 0.10))
	draw_rect(Rect2(0, h * 0.20, w, h * 0.34), _c(0.44, 0.36, 0.32))
	for merlon: int in 10:
		draw_rect(Rect2(w * (0.04 + float(merlon) * 0.095), h * 0.12, w * 0.05, h * 0.08), _c(0.40, 0.32, 0.28))

	draw_rect(Rect2(w * 0.36, h * 0.28, w * 0.28, h * 0.42), _c(0.34, 0.24, 0.18))
	draw_arc(Vector2(w * 0.50, h * 0.28), w * 0.14, PI, TAU, 28, _c(0.34, 0.24, 0.18), 18.0)
	draw_rect(Rect2(w * 0.40, h * 0.38, w * 0.20, h * 0.32), _c(0.10, 0.08, 0.08))

	var breach := PackedVector2Array([
		Vector2(w * 0.43, h * 0.72), Vector2(w * 0.48, h * 0.56),
		Vector2(w * 0.52, h * 0.58), Vector2(w * 0.58, h * 0.72),
	])
	draw_polygon(breach, [_c(0.12, 0.10, 0.10)])

	for debris: Array in [
		[w * 0.28, h * 0.74, 46.0, 10.0], [w * 0.34, h * 0.78, 32.0, 8.0],
		[w * 0.66, h * 0.76, 40.0, 10.0], [w * 0.74, h * 0.80, 26.0, 8.0],
	]:
		draw_rect(Rect2(debris[0], debris[1], debris[2], debris[3]), _c(0.30, 0.22, 0.18))

	for flame: Array in [
		[w * 0.24, h * 0.72], [w * 0.50, h * 0.70], [w * 0.72, h * 0.73],
	]:
		var fx: float = flame[0]
		var fy: float = flame[1]
		draw_circle(Vector2(fx, fy), 12.0, _c(0.88, 0.28, 0.08, 0.42))
		draw_circle(Vector2(fx, fy - 2.0), 7.0, _c(1.0, 0.76, 0.28, 0.72))

	for unit: Array in [
		[w * 0.40, h * 0.72, 10.0], [w * 0.46, h * 0.70, 11.0],
		[w * 0.54, h * 0.71, 10.0], [w * 0.60, h * 0.73, 9.0],
	]:
		var ux: float = unit[0]
		var uy: float = unit[1]
		var hr: float = unit[2]
		draw_circle(Vector2(ux, uy - hr - 4.0), hr * 0.55, _c(0.08, 0.07, 0.06, 0.92))
		draw_rect(Rect2(ux - hr * 0.45, uy - 2.0, hr * 0.9, hr * 1.5), _c(0.08, 0.07, 0.06, 0.92))

	draw_line(Vector2(w * 0.30, h * 0.26), Vector2(w * 0.30, h * 0.46), _c(0.22, 0.18, 0.10, 0.92), 3.0)
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.30, h * 0.26), Vector2(w * 0.36, h * 0.28),
		Vector2(w * 0.34, h * 0.36), Vector2(w * 0.30, h * 0.34),
	]), [_c(0.76, 0.18, 0.16, 0.82)])
	draw_line(Vector2(w * 0.70, h * 0.24), Vector2(w * 0.70, h * 0.44), _c(0.22, 0.18, 0.10, 0.92), 3.0)
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.70, h * 0.24), Vector2(w * 0.76, h * 0.25),
		Vector2(w * 0.74, h * 0.33), Vector2(w * 0.70, h * 0.32),
	]), [_c(0.80, 0.68, 0.14, 0.82)])
