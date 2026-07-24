class_name BattleStageArt
extends Control

const MODE_RUBY_FORD := "ruby_ford"
const MODE_TOWER_OF_JOY := "tower_of_joy"
const MODE_THRONE_ROOM := "throne_room"

var stage_mode: String = ""
var time: float = 0.0
var accent_color: Color = Color(1.0, 1.0, 1.0, 0.10)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	if stage_mode == "":
		return
	time += delta
	queue_redraw()

func reset_state() -> void:
	time = 0.0
	queue_redraw()

func _draw() -> void:
	if stage_mode == "":
		return
	var rect := get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	match stage_mode:
		MODE_RUBY_FORD:
			_draw_ruby_ford_stage(w, h)
		MODE_TOWER_OF_JOY:
			_draw_tower_of_joy_stage(w, h)
		MODE_THRONE_ROOM:
			_draw_throne_room_stage(w, h)
	if accent_color.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, rect.size), accent_color)

func _c(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r, g, b, a)

func _pulse(seed: float, speed: float = 1.0, amplitude: float = 1.0) -> float:
	return (0.5 + 0.5 * sin(time * speed + seed)) * amplitude

func _soft_circle(center: Vector2, radius: float, color: Color, steps: int = 5) -> void:
	for i: int in range(steps, 0, -1):
		var t: float = float(i) / float(steps)
		var c := Color(color.r, color.g, color.b, color.a * t * t)
		draw_circle(center, radius * t, c)

func _draw_rank_line(start_x: float, y: float, count: int, step: float,
		body_color: Color, spear_color: Color, scale: float = 1.0) -> void:
	for idx: int in range(count):
		var x: float = start_x + float(idx) * step
		draw_circle(Vector2(x, y - 8.0 * scale), 4.0 * scale, body_color)
		draw_rect(Rect2(x - 3.0 * scale, y - 4.0 * scale, 6.0 * scale, 11.0 * scale), body_color)
		draw_line(Vector2(x + 3.0 * scale, y - 2.0 * scale), Vector2(x + 3.0 * scale, y - 20.0 * scale), spear_color, maxf(1.0, 1.5 * scale))
		draw_polygon(PackedVector2Array([
			Vector2(x + 1.0 * scale, y - 20.0 * scale),
			Vector2(x + 5.0 * scale, y - 20.0 * scale),
			Vector2(x + 3.0 * scale, y - 24.0 * scale),
		]), [spear_color])

func _draw_duel_silhouette(center: Vector2, scale: float, facing: float, body_color: Color,
		weapon_color: Color, blade_tilt: float) -> void:
	draw_circle(center + Vector2(0.0, -18.0 * scale), 7.0 * scale, body_color)
	draw_rect(Rect2(center.x - 6.0 * scale, center.y - 10.0 * scale, 12.0 * scale, 20.0 * scale), body_color)
	draw_line(center + Vector2(-4.0 * scale, 8.0 * scale), center + Vector2(-10.0 * scale, 24.0 * scale), body_color, 2.0 * scale)
	draw_line(center + Vector2(4.0 * scale, 8.0 * scale), center + Vector2(10.0 * scale, 24.0 * scale), body_color, 2.0 * scale)
	draw_line(center + Vector2(4.0 * scale * facing, -2.0 * scale), center + Vector2(22.0 * scale * facing, -18.0 * scale + blade_tilt), body_color, 2.4 * scale)
	draw_line(center + Vector2(22.0 * scale * facing, -18.0 * scale + blade_tilt), center + Vector2(42.0 * scale * facing, -34.0 * scale + blade_tilt), weapon_color, 1.6 * scale)

func _draw_blood_streak(from: Vector2, to: Vector2, color: Color, width: float = 4.0) -> void:
	draw_line(from, to, color, width)
	_soft_circle(to, width * 1.4, color, 4)

func _draw_warhammer_duel(center: Vector2, scale: float) -> void:
	var robert := center + Vector2(-42.0 * scale, 14.0 * scale)
	draw_circle(robert + Vector2(0.0, -30.0 * scale), 10.0 * scale, _c(0.10, 0.08, 0.06, 0.90))
	draw_rect(Rect2(robert.x - 10.0 * scale, robert.y - 24.0 * scale, 20.0 * scale, 34.0 * scale), _c(0.10, 0.08, 0.06, 0.90))
	draw_line(robert + Vector2(-6.0 * scale, 10.0 * scale), robert + Vector2(-14.0 * scale, 34.0 * scale), _c(0.10, 0.08, 0.06, 0.90), 3.0 * scale)
	draw_line(robert + Vector2(8.0 * scale, 10.0 * scale), robert + Vector2(16.0 * scale, 34.0 * scale), _c(0.10, 0.08, 0.06, 0.90), 3.0 * scale)
	draw_line(robert + Vector2(8.0 * scale, -8.0 * scale), robert + Vector2(42.0 * scale, -34.0 * scale), _c(0.10, 0.08, 0.06, 0.90), 4.0 * scale)
	draw_rect(Rect2(robert.x + 30.0 * scale, robert.y - 46.0 * scale, 22.0 * scale, 16.0 * scale), _c(0.22, 0.18, 0.16, 0.86))

	var rhaegar := center + Vector2(42.0 * scale, 4.0 * scale)
	draw_circle(rhaegar + Vector2(0.0, -28.0 * scale), 9.0 * scale, _c(0.12, 0.08, 0.08, 0.82))
	draw_rect(Rect2(rhaegar.x - 9.0 * scale, rhaegar.y - 22.0 * scale, 18.0 * scale, 30.0 * scale), _c(0.12, 0.08, 0.08, 0.82))
	draw_line(rhaegar + Vector2(-6.0 * scale, 8.0 * scale), rhaegar + Vector2(-12.0 * scale, 30.0 * scale), _c(0.12, 0.08, 0.08, 0.82), 2.4 * scale)
	draw_line(rhaegar + Vector2(6.0 * scale, 8.0 * scale), rhaegar + Vector2(12.0 * scale, 30.0 * scale), _c(0.12, 0.08, 0.08, 0.82), 2.4 * scale)
	draw_line(rhaegar + Vector2(-4.0 * scale, -12.0 * scale), rhaegar + Vector2(-48.0 * scale, -26.0 * scale), _c(0.86, 0.86, 0.90, 0.72), 2.4 * scale)
	draw_polygon(PackedVector2Array([
		Vector2(rhaegar.x - 4.0 * scale, rhaegar.y - 42.0 * scale),
		Vector2(rhaegar.x + 4.0 * scale, rhaegar.y - 42.0 * scale),
		Vector2(rhaegar.x, rhaegar.y - 54.0 * scale),
	]), [_c(0.76, 0.20, 0.20, 0.78)])

	draw_line(center + Vector2(-12.0 * scale, -22.0 * scale), center + Vector2(24.0 * scale, -40.0 * scale), _c(1.0, 0.92, 0.72, 0.28), 4.0 * scale)
	draw_line(center + Vector2(-4.0 * scale, -12.0 * scale), center + Vector2(10.0 * scale, -4.0 * scale), _c(1.0, 0.98, 0.82, 0.20), 3.0 * scale)
	_soft_circle(center + Vector2(4.0 * scale, -18.0 * scale), 16.0 * scale, _c(1.0, 0.90, 0.70, 0.12), 5)

func _draw_dayne_stand(center: Vector2, scale: float) -> void:
	var dayne := center
	draw_circle(dayne + Vector2(0.0, -34.0 * scale), 10.0 * scale, _c(0.10, 0.09, 0.08, 0.92))
	draw_rect(Rect2(dayne.x - 11.0 * scale, dayne.y - 28.0 * scale, 22.0 * scale, 40.0 * scale), _c(0.10, 0.09, 0.08, 0.92))
	draw_line(dayne + Vector2(-6.0 * scale, 12.0 * scale), dayne + Vector2(-16.0 * scale, 40.0 * scale), _c(0.10, 0.09, 0.08, 0.92), 3.0 * scale)
	draw_line(dayne + Vector2(6.0 * scale, 12.0 * scale), dayne + Vector2(16.0 * scale, 40.0 * scale), _c(0.10, 0.09, 0.08, 0.92), 3.0 * scale)
	draw_line(dayne + Vector2(-8.0 * scale, -12.0 * scale), dayne + Vector2(-42.0 * scale, -44.0 * scale), _c(0.98, 0.98, 0.96, 0.72), 2.4 * scale)
	draw_line(dayne + Vector2(8.0 * scale, -12.0 * scale), dayne + Vector2(42.0 * scale, -44.0 * scale), _c(0.98, 0.98, 0.96, 0.72), 2.4 * scale)
	_soft_circle(dayne + Vector2(0.0, -38.0 * scale), 18.0 * scale, _c(1.0, 0.98, 0.92, 0.08), 5)

	var ned := center + Vector2(-74.0 * scale, 22.0 * scale)
	draw_circle(ned + Vector2(0.0, -22.0 * scale), 8.0 * scale, _c(0.10, 0.08, 0.06, 0.72))
	draw_rect(Rect2(ned.x - 8.0 * scale, ned.y - 16.0 * scale, 16.0 * scale, 24.0 * scale), _c(0.10, 0.08, 0.06, 0.72))
	draw_line(ned + Vector2(6.0 * scale, -6.0 * scale), ned + Vector2(34.0 * scale, -30.0 * scale), _c(0.78, 0.80, 0.84, 0.46), 2.0 * scale)

	var howland := center + Vector2(-108.0 * scale, 34.0 * scale)
	draw_circle(howland + Vector2(0.0, -18.0 * scale), 7.0 * scale, _c(0.08, 0.08, 0.06, 0.64))
	draw_rect(Rect2(howland.x - 7.0 * scale, howland.y - 12.0 * scale, 14.0 * scale, 20.0 * scale), _c(0.08, 0.08, 0.06, 0.64))
	draw_line(howland + Vector2(6.0 * scale, -2.0 * scale), howland + Vector2(26.0 * scale, -16.0 * scale), _c(0.72, 0.76, 0.80, 0.38), 1.8 * scale)

	for arc_i: int in range(2):
		var ox: float = -8.0 + float(arc_i) * 20.0
		draw_arc(center + Vector2(ox * scale, -28.0 * scale), 32.0 * scale, -1.8, -0.6, 18, _c(1.0, 0.98, 0.86, 0.16), 2.0 * scale)

func _draw_kingslayer_tableau(center: Vector2, scale: float) -> void:
	var jaime := center + Vector2(42.0 * scale, -2.0 * scale)
	draw_circle(jaime + Vector2(0.0, -28.0 * scale), 9.0 * scale, _c(0.86, 0.84, 0.80, 0.86))
	draw_rect(Rect2(jaime.x - 9.0 * scale, jaime.y - 22.0 * scale, 18.0 * scale, 32.0 * scale), _c(0.86, 0.84, 0.80, 0.86))
	draw_line(jaime + Vector2(6.0 * scale, -8.0 * scale), jaime + Vector2(24.0 * scale, -30.0 * scale), _c(0.86, 0.84, 0.80, 0.86), 3.0 * scale)
	draw_line(jaime + Vector2(24.0 * scale, -30.0 * scale), jaime + Vector2(44.0 * scale, -56.0 * scale), _c(0.82, 0.82, 0.84, 0.72), 2.0 * scale)

	var king := center + Vector2(-30.0 * scale, 28.0 * scale)
	draw_polygon(PackedVector2Array([
		Vector2(king.x - 28.0 * scale, king.y - 10.0 * scale),
		Vector2(king.x + 18.0 * scale, king.y - 18.0 * scale),
		Vector2(king.x + 34.0 * scale, king.y + 10.0 * scale),
		Vector2(king.x - 8.0 * scale, king.y + 20.0 * scale),
	]), [_c(0.54, 0.14, 0.16, 0.90)])
	draw_circle(king + Vector2(-34.0 * scale, -10.0 * scale), 10.0 * scale, _c(0.78, 0.68, 0.24, 0.72))
	for spike_i: int in range(3):
		var sx: float = king.x - 38.0 * scale + float(spike_i) * 6.0 * scale
		draw_line(Vector2(sx, king.y - 16.0 * scale), Vector2(sx, king.y - 22.0 * scale), _c(0.78, 0.68, 0.24, 0.76), 2.0 * scale)

	_draw_blood_streak(center + Vector2(-16.0 * scale, 20.0 * scale), center + Vector2(36.0 * scale, 54.0 * scale), _c(0.70, 0.10, 0.10, 0.34), 6.0 * scale)
	_soft_circle(center + Vector2(-4.0 * scale, 18.0 * scale), 20.0 * scale, _c(0.68, 0.10, 0.10, 0.14), 5)

func _draw_ruby_ford_foreground(w: float, h: float) -> void:
	var robert := Vector2(w * 0.18, h * 0.92)
	draw_polygon(PackedVector2Array([
		Vector2(robert.x - 74.0, robert.y), Vector2(robert.x - 34.0, robert.y - 104.0),
		Vector2(robert.x + 34.0, robert.y - 104.0), Vector2(robert.x + 82.0, robert.y),
	]), [_c(0.20, 0.16, 0.12, 0.48)])
	draw_rect(Rect2(robert.x - 38.0, robert.y - 112.0, 76.0, 96.0), _c(0.26, 0.22, 0.18, 0.54))
	draw_circle(Vector2(robert.x + 2.0, robert.y - 132.0), 24.0, _c(0.12, 0.10, 0.08, 0.60))
	draw_rect(Rect2(robert.x - 20.0, robert.y - 118.0, 48.0, 62.0), _c(0.16, 0.22, 0.42, 0.34))
	draw_rect(Rect2(robert.x - 12.0, robert.y - 106.0, 32.0, 20.0), _c(0.82, 0.70, 0.24, 0.26))
	draw_polygon(PackedVector2Array([
		Vector2(robert.x - 26.0, robert.y - 94.0), Vector2(robert.x - 40.0, robert.y - 20.0),
		Vector2(robert.x - 6.0, robert.y - 24.0), Vector2(robert.x + 4.0, robert.y - 98.0),
	]), [_c(0.22, 0.18, 0.12, 0.24)])
	draw_rect(Rect2(robert.x - 16.0, robert.y - 120.0, 22.0, 16.0), _c(0.82, 0.70, 0.28, 0.26))
	draw_rect(Rect2(robert.x + 8.0, robert.y - 108.0, 18.0, 58.0), _c(0.80, 0.74, 0.70, 0.26))
	draw_line(Vector2(robert.x + 14.0, robert.y - 56.0), Vector2(robert.x + 82.0, robert.y - 120.0), _c(0.18, 0.14, 0.10, 0.54), 8.0)
	draw_rect(Rect2(robert.x + 74.0, robert.y - 136.0, 32.0, 22.0), _c(0.34, 0.28, 0.24, 0.56))

	var rhaegar := Vector2(w * 0.82, h * 0.92)
	draw_polygon(PackedVector2Array([
		Vector2(rhaegar.x - 88.0, rhaegar.y), Vector2(rhaegar.x - 26.0, rhaegar.y - 112.0),
		Vector2(rhaegar.x + 36.0, rhaegar.y - 112.0), Vector2(rhaegar.x + 76.0, rhaegar.y),
	]), [_c(0.40, 0.12, 0.14, 0.42)])
	draw_polygon(PackedVector2Array([
		Vector2(rhaegar.x - 44.0, rhaegar.y - 110.0), Vector2(rhaegar.x - 8.0, rhaegar.y - 62.0),
		Vector2(rhaegar.x + 20.0, rhaegar.y - 64.0), Vector2(rhaegar.x + 46.0, rhaegar.y - 110.0),
	]), [_c(0.72, 0.14, 0.18, 0.28)])
	draw_rect(Rect2(rhaegar.x - 34.0, rhaegar.y - 114.0, 68.0, 96.0), _c(0.82, 0.78, 0.72, 0.34))
	draw_circle(Vector2(rhaegar.x, rhaegar.y - 134.0), 22.0, _c(0.88, 0.84, 0.78, 0.44))
	draw_rect(Rect2(rhaegar.x - 16.0, rhaegar.y - 112.0, 34.0, 54.0), _c(0.80, 0.80, 0.84, 0.24))
	draw_rect(Rect2(rhaegar.x - 10.0, rhaegar.y - 90.0, 24.0, 20.0), _c(0.72, 0.14, 0.18, 0.26))
	draw_circle(Vector2(rhaegar.x - 4.0, rhaegar.y - 138.0), 8.0, _c(0.90, 0.88, 0.70, 0.20))
	for spike_i: int in range(3):
		var sx: float = rhaegar.x - 10.0 + float(spike_i) * 10.0
		draw_line(Vector2(sx, rhaegar.y - 154.0), Vector2(sx, rhaegar.y - 164.0), _c(0.80, 0.66, 0.26, 0.44), 2.0)
	draw_line(Vector2(rhaegar.x - 8.0, rhaegar.y - 96.0), Vector2(rhaegar.x - 108.0, rhaegar.y - 138.0), _c(0.86, 0.86, 0.90, 0.44), 4.0)

	for gem_i: int in range(6):
		var t: float = float(gem_i) / 5.0
		var gx: float = lerpf(w * 0.44, w * 0.60, t)
		var gy: float = lerpf(h * 0.58, h * 0.76, t) + sin(time * 2.8 + float(gem_i)) * 4.0
		draw_circle(Vector2(gx, gy), 5.0 + 2.0 * sin(time * 3.2 + float(gem_i)), _c(0.92, 0.18, 0.22, 0.28))

	_soft_circle(Vector2(w * 0.52, h * 0.62), 28.0, _c(1.0, 0.92, 0.74, 0.08), 6)

func _draw_tower_of_joy_foreground(w: float, h: float) -> void:
	var dayne := Vector2(w * 0.56, h * 0.88)
	draw_polygon(PackedVector2Array([
		Vector2(dayne.x - 64.0, dayne.y), Vector2(dayne.x - 24.0, dayne.y - 132.0),
		Vector2(dayne.x + 26.0, dayne.y - 132.0), Vector2(dayne.x + 66.0, dayne.y),
	]), [_c(0.82, 0.80, 0.74, 0.34)])
	draw_polygon(PackedVector2Array([
		Vector2(dayne.x - 52.0, dayne.y - 130.0), Vector2(dayne.x - 16.0, dayne.y - 84.0),
		Vector2(dayne.x + 18.0, dayne.y - 84.0), Vector2(dayne.x + 48.0, dayne.y - 130.0),
	]), [_c(0.94, 0.94, 0.90, 0.18)])
	draw_rect(Rect2(dayne.x - 26.0, dayne.y - 138.0, 52.0, 102.0), _c(0.90, 0.88, 0.82, 0.28))
	draw_circle(Vector2(dayne.x, dayne.y - 156.0), 22.0, _c(0.12, 0.10, 0.08, 0.60))
	draw_rect(Rect2(dayne.x - 18.0, dayne.y - 138.0, 38.0, 62.0), _c(0.92, 0.92, 0.90, 0.24))
	draw_rect(Rect2(dayne.x - 10.0, dayne.y - 112.0, 22.0, 16.0), _c(0.60, 0.68, 0.86, 0.16))
	draw_line(Vector2(dayne.x - 8.0, dayne.y - 118.0), Vector2(dayne.x - 54.0, dayne.y - 172.0), _c(1.0, 0.98, 0.92, 0.44), 3.0)
	draw_line(Vector2(dayne.x + 8.0, dayne.y - 118.0), Vector2(dayne.x + 54.0, dayne.y - 172.0), _c(1.0, 0.98, 0.92, 0.44), 3.0)
	_soft_circle(Vector2(dayne.x, dayne.y - 164.0), 24.0, _c(1.0, 0.98, 0.90, 0.08), 6)

	var ned := Vector2(w * 0.18, h * 0.94)
	draw_polygon(PackedVector2Array([
		Vector2(ned.x - 60.0, ned.y), Vector2(ned.x - 18.0, ned.y - 100.0),
		Vector2(ned.x + 24.0, ned.y - 100.0), Vector2(ned.x + 54.0, ned.y),
	]), [_c(0.18, 0.20, 0.22, 0.44)])
	draw_polygon(PackedVector2Array([
		Vector2(ned.x - 34.0, ned.y - 100.0), Vector2(ned.x - 8.0, ned.y - 62.0),
		Vector2(ned.x + 20.0, ned.y - 60.0), Vector2(ned.x + 44.0, ned.y - 96.0),
	]), [_c(0.20, 0.24, 0.30, 0.22)])
	draw_circle(Vector2(ned.x, ned.y - 118.0), 18.0, _c(0.18, 0.14, 0.12, 0.52))
	draw_rect(Rect2(ned.x - 10.0, ned.y - 108.0, 22.0, 14.0), _c(0.54, 0.54, 0.58, 0.18))
	draw_line(Vector2(ned.x + 14.0, ned.y - 96.0), Vector2(ned.x + 64.0, ned.y - 144.0), _c(0.76, 0.80, 0.84, 0.34), 3.0)

	var howland := Vector2(w * 0.06, h * 0.97)
	draw_polygon(PackedVector2Array([
		Vector2(howland.x - 34.0, howland.y), Vector2(howland.x - 8.0, howland.y - 68.0),
		Vector2(howland.x + 18.0, howland.y - 68.0), Vector2(howland.x + 42.0, howland.y),
	]), [_c(0.18, 0.30, 0.20, 0.34)])
	draw_polygon(PackedVector2Array([
		Vector2(howland.x - 22.0, howland.y - 68.0), Vector2(howland.x + 2.0, howland.y - 38.0),
		Vector2(howland.x + 24.0, howland.y - 40.0), Vector2(howland.x + 36.0, howland.y - 68.0),
	]), [_c(0.18, 0.40, 0.22, 0.18)])
	draw_circle(Vector2(howland.x + 4.0, howland.y - 82.0), 14.0, _c(0.16, 0.14, 0.10, 0.40))

	for flare_i: int in range(3):
		var fx: float = w * (0.42 + float(flare_i) * 0.05)
		draw_arc(Vector2(fx, h * 0.58), 32.0 + 8.0 * float(flare_i), -2.0, -0.7, 18, _c(1.0, 0.98, 0.84, 0.12), 2.0)

func _draw_throne_room_foreground(w: float, h: float) -> void:
	var jaime := Vector2(w * 0.82, h * 0.94)
	draw_polygon(PackedVector2Array([
		Vector2(jaime.x - 70.0, jaime.y), Vector2(jaime.x - 24.0, jaime.y - 124.0),
		Vector2(jaime.x + 26.0, jaime.y - 124.0), Vector2(jaime.x + 76.0, jaime.y),
	]), [_c(0.86, 0.80, 0.72, 0.30)])
	draw_polygon(PackedVector2Array([
		Vector2(jaime.x - 46.0, jaime.y - 124.0), Vector2(jaime.x - 10.0, jaime.y - 86.0),
		Vector2(jaime.x + 24.0, jaime.y - 84.0), Vector2(jaime.x + 52.0, jaime.y - 118.0),
	]), [_c(0.92, 0.26, 0.20, 0.16)])
	draw_rect(Rect2(jaime.x - 28.0, jaime.y - 126.0, 56.0, 100.0), _c(0.88, 0.84, 0.78, 0.28))
	draw_rect(Rect2(jaime.x - 18.0, jaime.y - 126.0, 38.0, 62.0), _c(0.90, 0.88, 0.84, 0.22))
	draw_rect(Rect2(jaime.x - 10.0, jaime.y - 102.0, 28.0, 20.0), _c(0.78, 0.64, 0.20, 0.18))
	draw_circle(Vector2(jaime.x, jaime.y - 144.0), 20.0, _c(0.96, 0.88, 0.62, 0.34))
	for hair_i: int in range(3):
		var hx: float = jaime.x - 8.0 + float(hair_i) * 8.0
		draw_line(Vector2(hx, jaime.y - 148.0), Vector2(hx + 8.0, jaime.y - 132.0), _c(0.96, 0.84, 0.34, 0.28), 2.0)
	draw_line(Vector2(jaime.x + 6.0, jaime.y - 108.0), Vector2(jaime.x + 32.0, jaime.y - 138.0), _c(0.90, 0.84, 0.78, 0.34), 3.0)
	draw_line(Vector2(jaime.x + 32.0, jaime.y - 138.0), Vector2(jaime.x + 56.0, jaime.y - 182.0), _c(0.82, 0.82, 0.86, 0.40), 2.4)

	var king := Vector2(w * 0.18, h * 0.96)
	draw_polygon(PackedVector2Array([
		Vector2(king.x - 88.0, king.y), Vector2(king.x - 20.0, king.y - 72.0),
		Vector2(king.x + 34.0, king.y - 90.0), Vector2(king.x + 90.0, king.y),
	]), [_c(0.50, 0.12, 0.16, 0.30)])
	draw_polygon(PackedVector2Array([
		Vector2(king.x - 40.0, king.y - 86.0), Vector2(king.x - 4.0, king.y - 62.0),
		Vector2(king.x + 20.0, king.y - 64.0), Vector2(king.x + 48.0, king.y - 92.0),
	]), [_c(0.72, 0.14, 0.18, 0.16)])
	draw_circle(Vector2(king.x - 26.0, king.y - 92.0), 16.0, _c(0.74, 0.64, 0.24, 0.34))
	draw_rect(Rect2(king.x - 16.0, king.y - 84.0, 30.0, 18.0), _c(0.80, 0.64, 0.20, 0.14))
	for spike_i: int in range(3):
		var sx: float = king.x - 32.0 + float(spike_i) * 7.0
		draw_line(Vector2(sx, king.y - 98.0), Vector2(sx, king.y - 108.0), _c(0.78, 0.68, 0.24, 0.36), 2.0)
	_draw_blood_streak(Vector2(w * 0.28, h * 0.84), Vector2(w * 0.50, h * 0.98), _c(0.72, 0.10, 0.10, 0.24), 7.0)
	_soft_circle(Vector2(w * 0.36, h * 0.86), 24.0, _c(0.72, 0.10, 0.10, 0.08), 5)

func _draw_ruby_ford_stage(w: float, h: float) -> void:
	for i: int in range(10):
		var yy: float = h * float(i) / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(0.12 + 0.12 * t, 0.07 + 0.06 * t, 0.08 + 0.10 * t, 1.0)
		draw_rect(Rect2(0.0, yy, w, h / 10.0 + 2.0), sky)

	var far_bank := PackedVector2Array([
		Vector2(0.0, h * 0.58), Vector2(w * 0.14, h * 0.52), Vector2(w * 0.30, h * 0.56),
		Vector2(w * 0.48, h * 0.50), Vector2(w * 0.66, h * 0.57), Vector2(w * 0.82, h * 0.53),
		Vector2(w, h * 0.57), Vector2(w, h * 0.64), Vector2(0.0, h * 0.64),
	])
	draw_polygon(far_bank, [_c(0.20, 0.15, 0.12)])

	draw_rect(Rect2(0.0, h * 0.64, w, h * 0.18), _c(0.18, 0.26, 0.34))
	for ri: int in range(9):
		var ry: float = h * (0.66 + float(ri) * 0.015)
		var wave_offset: float = sin(time * (1.2 + float(ri) * 0.12) + float(ri)) * 12.0
		draw_line(Vector2(-20.0 + wave_offset, ry), Vector2(w + 20.0 + wave_offset, ry + 3.0),
			_c(0.36, 0.48, 0.56, 0.24), 2.0)

	var near_bank := PackedVector2Array([
		Vector2(0.0, h), Vector2(0.0, h * 0.82), Vector2(w * 0.16, h * 0.78),
		Vector2(w * 0.34, h * 0.84), Vector2(w * 0.56, h * 0.80), Vector2(w * 0.78, h * 0.86),
		Vector2(w, h * 0.82), Vector2(w, h),
	])
	draw_polygon(near_bank, [_c(0.26, 0.18, 0.14)])

	for banner_x: float in [w * 0.16, w * 0.26, w * 0.78]:
		draw_line(Vector2(banner_x, h * 0.42), Vector2(banner_x, h * 0.62), _c(0.22, 0.18, 0.12), 3.0)
		draw_polygon(PackedVector2Array([
			Vector2(banner_x, h * 0.42), Vector2(banner_x + 40.0, h * 0.45),
			Vector2(banner_x + 32.0, h * 0.53), Vector2(banner_x, h * 0.50),
		]), [_c(0.74, 0.14, 0.14, 0.84)])

	for gem_i: int in range(8):
		var gx: float = fposmod(time * (18.0 + float(gem_i)) + float(gem_i) * 96.0, w + 60.0) - 30.0
		var gy: float = h * (0.69 + 0.04 * sin(float(gem_i) * 1.3 + time * 1.8))
		draw_circle(Vector2(gx, gy), 4.0 + _pulse(float(gem_i), 2.4, 1.6), _c(0.90, 0.18, 0.22, 0.30))

	_draw_rank_line(w * 0.10, h * 0.61, 8, w * 0.036, _c(0.08, 0.07, 0.06, 0.72), _c(0.54, 0.54, 0.56, 0.54), 0.88)
	_draw_rank_line(w * 0.70, h * 0.60, 6, w * 0.032, _c(0.10, 0.08, 0.08, 0.74), _c(0.60, 0.58, 0.58, 0.58), 0.82)
	_draw_warhammer_duel(Vector2(w * 0.50, h * 0.72), 1.0)
	_draw_ruby_ford_foreground(w, h)

	for spray_i: int in range(7):
		var sx: float = w * (0.40 + float(spray_i) * 0.035)
		var sy: float = h * (0.69 - 0.012 * float(spray_i % 3))
		_soft_circle(Vector2(sx, sy), 8.0 + _pulse(float(spray_i), 3.4, 4.0), _c(0.80, 0.90, 0.98, 0.06), 4)

	var hammer_center := Vector2(w * 0.22, h * 0.73)
	draw_line(hammer_center + Vector2(-20.0, 8.0), hammer_center + Vector2(40.0, -20.0), _c(0.18, 0.14, 0.10), 7.0)
	draw_rect(Rect2(hammer_center.x + 28.0, hammer_center.y - 34.0, 26.0, 18.0), _c(0.28, 0.24, 0.22))
	_draw_blood_streak(Vector2(w * 0.60, h * 0.77), Vector2(w * 0.68, h * 0.80), _c(0.72, 0.12, 0.12, 0.30), 5.0)

func _draw_tower_of_joy_stage(w: float, h: float) -> void:
	for i: int in range(10):
		var yy: float = h * float(i) / 10.0
		var t: float = float(i) / 10.0
		var sky := Color(0.40 + 0.18 * t, 0.24 + 0.16 * t, 0.12 + 0.10 * t, 1.0)
		draw_rect(Rect2(0.0, yy, w, h / 10.0 + 2.0), sky)

	var sun_pos := Vector2(w * 0.20, h * 0.18)
	for ring: int in range(5, 0, -1):
		var rr: float = 18.0 + float(ring) * 18.0
		draw_circle(sun_pos, rr, _c(1.0, 0.92, 0.62, 0.03 * float(ring)))

	for band: int in range(4):
		var offset: float = fposmod(time * (26.0 + float(band) * 4.0) + float(band) * 140.0, w + 200.0) - 100.0
		draw_rect(Rect2(offset, h * (0.24 + float(band) * 0.12), w * 0.32, h * 0.026), _c(0.90, 0.76, 0.50, 0.05))

	draw_rect(Rect2(0.0, h * 0.72, w, h * 0.28), _c(0.56, 0.34, 0.18))
	for dune: Array in [
		[0.12, 0.80, 0.22], [0.34, 0.85, 0.30], [0.62, 0.82, 0.28], [0.86, 0.86, 0.20],
	]:
		var cx: float = w * float(dune[0])
		var cy: float = h * float(dune[1])
		var radius: float = w * float(dune[2])
		draw_circle(Vector2(cx, cy), radius, _c(0.72, 0.50, 0.26, 0.22))

	var tower := PackedVector2Array([
		Vector2(w * 0.64, h * 0.72), Vector2(w * 0.72, h * 0.22),
		Vector2(w * 0.82, h * 0.22), Vector2(w * 0.88, h * 0.72),
	])
	draw_polygon(tower, [_c(0.80, 0.72, 0.58)])
	draw_rect(Rect2(w * 0.72, h * 0.48, w * 0.10, h * 0.24), _c(0.62, 0.54, 0.42))
	draw_arc(Vector2(w * 0.77, h * 0.48), w * 0.05, PI, TAU, 20, _c(0.62, 0.54, 0.42), 10.0)

	for sand_i: int in range(18):
		var sx: float = fposmod(time * (24.0 + float(sand_i) * 0.8) + float(sand_i) * 52.0, w + 100.0) - 50.0
		var sy: float = h * (0.32 + 0.36 * fposmod(float(sand_i) * 0.17, 1.0))
		draw_circle(Vector2(sx, sy), 1.4 + float(sand_i % 3), _c(0.94, 0.82, 0.56, 0.12))

	for gust_i: int in range(3):
		var gy: float = h * (0.42 + float(gust_i) * 0.12)
		var goffset: float = sin(time * (0.8 + float(gust_i) * 0.16) + float(gust_i)) * 18.0
		draw_rect(Rect2(-40.0 + goffset, gy, w + 80.0, h * 0.016), _c(0.92, 0.78, 0.50, 0.05))

	var fallen_blade := PackedVector2Array([
		Vector2(w * 0.44, h * 0.76), Vector2(w * 0.60, h * 0.66),
		Vector2(w * 0.62, h * 0.69), Vector2(w * 0.46, h * 0.80),
	])
	draw_polygon(fallen_blade, [_c(0.88, 0.88, 0.92, 0.72)])
	_draw_dayne_stand(Vector2(w * 0.54, h * 0.70), 1.0)
	_draw_tower_of_joy_foreground(w, h)

	draw_line(Vector2(w * 0.46, h * 0.60), Vector2(w * 0.58, h * 0.52), _c(1.0, 0.96, 0.84, 0.22), 3.0)
	draw_line(Vector2(w * 0.50, h * 0.58), Vector2(w * 0.40, h * 0.50), _c(1.0, 0.94, 0.76, 0.18), 2.0)

func _draw_throne_room_stage(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, h * 0.76), _c(0.08, 0.06, 0.06))
	draw_rect(Rect2(0.0, h * 0.76, w, h * 0.24), _c(0.10, 0.08, 0.08))

	for col_x: float in [w * 0.12, w * 0.24, w * 0.76, w * 0.88]:
		draw_rect(Rect2(col_x - 16.0, 0.0, 32.0, h * 0.76), _c(0.14, 0.12, 0.11))
		draw_rect(Rect2(col_x - 16.0, 0.0, 6.0, h * 0.76), _c(0.22, 0.18, 0.16))

	for fx: float in [w * 0.18, w * 0.82]:
		var flicker: float = 12.0 + _pulse(fx * 0.01, 5.2, 10.0)
		draw_circle(Vector2(fx, h * 0.68), 18.0 + flicker, _c(0.92, 0.30, 0.08, 0.12))
		draw_circle(Vector2(fx, h * 0.68), 9.0 + flicker * 0.35, _c(1.0, 0.80, 0.34, 0.24))

	var throne := PackedVector2Array([
		Vector2(w * 0.40, h * 0.74), Vector2(w * 0.60, h * 0.74),
		Vector2(w * 0.58, h * 0.40), Vector2(w * 0.42, h * 0.40),
	])
	draw_polygon(throne, [_c(0.16, 0.13, 0.12)])
	for spike: int in range(7):
		var sx: float = w * (0.40 + float(spike) * 0.032)
		var tip_y: float = h * (0.18 + 0.03 * float(spike % 3))
		draw_polygon(PackedVector2Array([
			Vector2(sx, h * 0.40), Vector2(sx + 18.0, h * 0.40), Vector2(sx + 9.0, tip_y),
		]), [_c(0.22, 0.19, 0.17)])

	draw_rect(Rect2(w * 0.32, h * 0.78, w * 0.36, h * 0.018), _c(0.58, 0.10, 0.10, 0.56))
	draw_rect(Rect2(w * 0.40, h * 0.70, w * 0.22, h * 0.014), _c(0.58, 0.10, 0.10, 0.42))

	var sword := PackedVector2Array([
		Vector2(w * 0.54, h * 0.64), Vector2(w * 0.60, h * 0.52),
		Vector2(w * 0.61, h * 0.54), Vector2(w * 0.55, h * 0.66),
	])
	draw_polygon(sword, [_c(0.84, 0.82, 0.76, 0.72)])
	_draw_kingslayer_tableau(Vector2(w * 0.50, h * 0.70), 1.0)
	_draw_throne_room_foreground(w, h)

	for ember_i: int in range(14):
		var ex: float = fposmod(float(ember_i) * 78.0 + time * (18.0 + float(ember_i)), w + 80.0) - 40.0
		var ey: float = h * (0.46 + 0.20 * fposmod(float(ember_i) * 0.11, 1.0)) - time * 5.0
		draw_circle(Vector2(ex, ey), 2.0 + float(ember_i % 3), _c(1.0, 0.68, 0.24, 0.14))
