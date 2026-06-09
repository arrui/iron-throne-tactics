# CutsceneArt.gd — 过场动画场景绘制（无外部资源，纯代码绘制）
# 支持场景类型：throne_room / execution / vale_castle / stormlands_road
class_name CutsceneArt
extends Node2D

var scene_type: String = ""
var alpha: float = 0.0   # 由外部 tween 控制淡入淡出

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

# ─── 工具：带 alpha 的颜色 ───────────────────────────────
func _c(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r, g, b, a * alpha)

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
