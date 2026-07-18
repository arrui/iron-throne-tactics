# CutscenePlayer.gd — 升级版，支持像素背景图 + 代码绘制场景 + 文字
class_name CutscenePlayer
extends CanvasLayer

const CJKFontHelper := preload("res://scripts/ui/CJKFontHelper.gd")

signal cutscene_finished

const FADE_DURATION := 0.6
const TEXT_FADE_IN  := 0.4

const CAMERA_STYLE_PRESETS := {
	"steady": {
		"zoom": 1.0,
		"pan_x": 0.0,
		"pan_y": 0.0,
		"overlay": Color(1, 1, 1, 0),
	},
	"throne_push": {
		"zoom": 1.08,
		"pan_x": 0.0,
		"pan_y": -10.0,
		"overlay": Color(1.0, 0.84, 0.62, 0.05),
	},
	"execution_heat": {
		"zoom": 1.04,
		"pan_x": 0.0,
		"pan_y": 6.0,
		"overlay": Color(1.0, 0.34, 0.10, 0.08),
	},
	"battle_sway": {
		"zoom": 1.06,
		"pan_x": 10.0,
		"pan_y": 4.0,
		"overlay": Color(0.90, 0.94, 1.0, 0.03),
	},
	"fall_drift": {
		"zoom": 1.12,
		"pan_x": -8.0,
		"pan_y": 12.0,
		"overlay": Color(0.86, 0.14, 0.18, 0.08),
	},
	"desert_glide": {
		"zoom": 1.03,
		"pan_x": 14.0,
		"pan_y": -2.0,
		"overlay": Color(1.0, 0.88, 0.66, 0.04),
	},
	"candle_breath": {
		"zoom": 1.05,
		"pan_x": -3.0,
		"pan_y": -5.0,
		"overlay": Color(1.0, 0.90, 0.70, 0.05),
	},
	"snow_drift": {
		"zoom": 1.02,
		"pan_x": 8.0,
		"pan_y": -4.0,
		"overlay": Color(0.86, 0.92, 1.0, 0.04),
	},
	"sentence_glower": {
		"zoom": 1.10,
		"pan_x": 0.0,
		"pan_y": -14.0,
		"overlay": Color(1.0, 0.70, 0.42, 0.07),
	},
	"ember_descent": {
		"zoom": 1.14,
		"pan_x": -6.0,
		"pan_y": 16.0,
		"overlay": Color(0.94, 0.20, 0.10, 0.10),
	},
	"river_requiem": {
		"zoom": 1.10,
		"pan_x": 6.0,
		"pan_y": 10.0,
		"overlay": Color(0.82, 0.16, 0.20, 0.09),
	},
	"verdict_hold": {
		"zoom": 1.09,
		"pan_x": 12.0,
		"pan_y": -8.0,
		"overlay": Color(1.0, 0.84, 0.70, 0.06),
	},
}

const SCENE_ART_STYLE_DEFAULTS := {
	"throne_room": "throne_push",
	"mad_king_sentence": "sentence_glower",
	"execution": "execution_heat",
	"stark_execution_close": "ember_descent",
	"vale_castle": "steady",
	"stormlands_road": "battle_sway",
	"ruby_ford_duel": "battle_sway",
	"ruby_ford_fall": "fall_drift",
	"ruby_ford_aftermath": "river_requiem",
	"trident_muster": "battle_sway",
	"tower_of_joy_gate": "desert_glide",
	"tower_of_joy_fall": "fall_drift",
	"lyanna_chamber": "candle_breath",
	"kingslayer": "throne_push",
	"kingslayer_aftermath": "verdict_hold",
	"throne_room_crowned": "throne_push",
	"north_road": "snow_drift",
	"winterfell_gate": "snow_drift",
	"red_keep_breach": "battle_sway",
}

var _slides: Array = []
var _current_index: int = 0
var _is_playing: bool = false
var _skip_requested: bool = false
var _play_id: int = 0

@onready var _bg_rect:   ColorRect  = $Background
@onready var _bg_image:  TextureRect = $BGImage
@onready var _label:     Label      = $TextLabel
@onready var _sublabel:  Label      = $SubTextLabel
@onready var _vignette:  ColorRect  = $Vignette
@onready var _scene_art: CutsceneArt = $SceneArt

func _ready() -> void:
	# 为过场动画标签应用中文字体
	_apply_cjk_font()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _label:
		_label.modulate    = Color(1, 1, 1, 0)
	if _sublabel:
		_sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image:
		_bg_image.modulate = Color(1, 1, 1, 0)
	if _scene_art:
		_scene_art.alpha = 0.0
		_scene_art.modulate = Color(1, 1, 1, 0)
		_scene_art.process_mode = Node.PROCESS_MODE_ALWAYS
		_scene_art.set_process(true)

func _process(_delta: float) -> void:
	if _is_playing and _skip_requested and visible and not _slides.is_empty():
		_abort_current_playback()

func _apply_cjk_font() -> void:
	CJKFontHelper.apply_to_node_recursive(self)

func play(json_path: String) -> void:
	_play_id += 1
	var play_id := _play_id
	_is_playing = true
	var data: Dictionary = _load_json(json_path)
	if data.is_empty():
		_finish(play_id)
		return
	_slides = data.get("slides", [])
	if _slides.is_empty():
		_finish(play_id)
		return
	_current_index  = 0
	_skip_requested = false
	visible = true
	_play_slide(_current_index, play_id)

func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	var key_skip: bool = (event is InputEventKey) and \
		(event as InputEventKey).pressed and \
		not (event as InputEventKey).echo and \
		((event as InputEventKey).keycode == KEY_SPACE or
		 (event as InputEventKey).keycode == KEY_ENTER)
	var mouse_skip: bool = (event is InputEventMouseButton) and \
		(event as InputEventMouseButton).pressed and \
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if key_skip or mouse_skip:
		_skip_requested = true
		if visible and not _slides.is_empty():
			_abort_current_playback()
		get_viewport().set_input_as_handled()

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CutscenePlayer: 找不到 %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null or not (result is Dictionary):
		push_error("CutscenePlayer: JSON解析失败 %s" % path)
		return {}
	return result as Dictionary

func _play_slide(index: int, play_id: int) -> void:
	if play_id != _play_id:
		return
	if index >= _slides.size():
		_finish(play_id)
		return

	var slide: Dictionary  = _slides[index]
	var text: String       = slide.get("text", "")
	var subtext: String    = slide.get("subtext", "")
	var duration: float    = float(slide.get("duration", 3.5))
	var image_path: String = slide.get("image", "")
	var scene_art: String  = slide.get("scene_art", "")
	var camera_style: String = str(slide.get("camera_style", ""))
	if camera_style == "" and scene_art != "":
		camera_style = str(SCENE_ART_STYLE_DEFAULTS.get(scene_art, "steady"))

	# 优先：代码绘制场景（无需外部资源）
	if _scene_art != null:
		if scene_art != "":
			var scene_changed := _scene_art.scene_type != scene_art
			if scene_changed and _scene_art.alpha > 0.01:
				await _fade_scene_art(_scene_art.alpha, 0.0,
					FADE_DURATION * 0.35, play_id)
				if play_id != _play_id: return
			if scene_changed:
				_scene_art.reset_motion_state()
				_scene_art.scene_type = scene_art
			if camera_style == "":
				camera_style = "steady"
			_apply_camera_style(camera_style, duration, play_id)
			_scene_art.queue_redraw()
			if scene_changed:
				await _fade_scene_art(0.0, 1.0, FADE_DURATION * 0.8, play_id)
				if play_id != _play_id: return
			elif _scene_art.alpha < 0.99:
				await _fade_scene_art(_scene_art.alpha, 1.0,
					FADE_DURATION * 0.25, play_id)
				if play_id != _play_id: return
		else:
			# 确保上一张场景艺术已隐藏
			if _scene_art.alpha > 0.01:
				await _fade_scene_art(_scene_art.alpha, 0.0,
					FADE_DURATION * 0.5, play_id)
				if play_id != _play_id: return
			_scene_art.scene_type = ""
			_scene_art.reset_motion_state()
			_scene_art.queue_redraw()

	# 备选：外部图片（如果提供且存在）
	if _bg_image != null:
		if image_path != "" and ResourceLoader.exists(image_path):
			_bg_image.texture = load(image_path)
			await _fade_node(_bg_image, 0.0, 1.0, FADE_DURATION * 0.8, play_id)
			if play_id != _play_id: return
		else:
			_bg_image.modulate = Color(1, 1, 1, 0)
			_bg_image.texture  = null

	# 设置文字并淡入
	if _label:
		_label.text = text
	if _sublabel:
		_sublabel.text = subtext

	await _fade_texts(0.0, 1.0, TEXT_FADE_IN, play_id)
	if play_id != _play_id: return
	if _skip_requested:
		_finish(play_id)
		return

	await _wait_skippable(duration, play_id)
	if play_id != _play_id: return
	if _skip_requested:
		_finish(play_id)
		return

	# 淡出文字
	await _fade_texts(1.0, 0.0, FADE_DURATION, play_id)
	if play_id != _play_id: return

	# 淡出背景图
	if _bg_image and _bg_image.texture != null:
		await _fade_node(_bg_image, 1.0, 0.0, FADE_DURATION * 0.5, play_id)
		if play_id != _play_id: return

	# 若下一帧没有场景艺术，淡出当前
	var next_has_art: bool = false
	var next_idx: int = _current_index + 1
	if next_idx < _slides.size():
		next_has_art = _slides[next_idx].get("scene_art", "") != ""
	if not next_has_art and _scene_art != null and _scene_art.alpha > 0.01:
		await _fade_scene_art(_scene_art.alpha, 0.0,
			FADE_DURATION * 0.5, play_id)
		if play_id != _play_id: return
		_scene_art.scene_type = ""
		_scene_art.queue_redraw()

	if _skip_requested:
		_finish(play_id)
		return

	_current_index += 1
	_play_slide(_current_index, play_id)

func _fade_texts(from_a: float, to_a: float, duration: float, play_id: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	if _label:
		tween.tween_method(func(alpha: float) -> void:
			if play_id == _play_id: _label.modulate.a = alpha,
			from_a, to_a, duration)
	if _sublabel:
		tween.tween_method(func(alpha: float) -> void:
			if play_id == _play_id: _sublabel.modulate.a = alpha,
			from_a, to_a, duration * 0.9)
	await tween.finished

func _fade_node(node: CanvasItem, from_a: float, to_a: float, duration: float,
		play_id: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(alpha: float) -> void:
		if play_id == _play_id: node.modulate.a = alpha,
		from_a, to_a, duration)
	await tween.finished

func _fade_scene_art(from_a: float, to_a: float, duration: float, play_id: int) -> void:
	if _scene_art == null:
		return
	var tween := create_tween()
	tween.tween_method(
		func(a: float) -> void:
			if play_id == _play_id:
				_scene_art.alpha = a
				_scene_art.queue_redraw(),
		from_a, to_a, duration)
	await tween.finished

func _wait_skippable(duration: float, play_id: int) -> void:
	var elapsed := 0.0
	while elapsed < duration and not _skip_requested and play_id == _play_id:
		elapsed += get_process_delta_time()
		await get_tree().process_frame

func _finish(play_id: int) -> void:
	if play_id != _play_id or not _is_playing:
		return
	_is_playing = false
	if _label:    _label.modulate    = Color(1, 1, 1, 0)
	if _sublabel: _sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image: _bg_image.modulate = Color(1, 1, 1, 0)
	if _scene_art:
		_scene_art.alpha = 0.0
		_scene_art.scene_type = ""
		_scene_art.reset_motion_state()
		_scene_art.queue_redraw()
	visible = false
	cutscene_finished.emit()

func _abort_current_playback() -> void:
	if not _is_playing:
		return
	_play_id += 1
	_is_playing = false
	if _label:
		_label.modulate = Color(1, 1, 1, 0)
	if _sublabel:
		_sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image:
		_bg_image.modulate = Color(1, 1, 1, 0)
		_bg_image.texture = null
	if _scene_art:
		_scene_art.alpha = 0.0
		_scene_art.scene_type = ""
		_scene_art.reset_motion_state()
		_scene_art.queue_redraw()
	visible = false
	cutscene_finished.emit()

func _apply_camera_style(style_name: String, duration: float, play_id: int) -> void:
	if _scene_art == null:
		return
	var preset: Dictionary = CAMERA_STYLE_PRESETS.get(style_name, CAMERA_STYLE_PRESETS["steady"])
	var start_scale := _scene_art.scale
	var target_scale := Vector2.ONE * float(preset.get("zoom", 1.0))
	var start_position := _scene_art.position
	var target_position := Vector2(float(preset.get("pan_x", 0.0)), float(preset.get("pan_y", 0.0)))
	var start_overlay := _scene_art.overlay_tint
	var target_overlay := preset.get("overlay", Color(1, 1, 1, 0)) as Color
	var tween_duration := minf(duration * 0.7, 1.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(weight: float) -> void:
		if play_id != _play_id or _scene_art == null:
			return
		_scene_art.scale = start_scale.lerp(target_scale, weight),
		0.0, 1.0, tween_duration)
	tween.tween_method(func(weight: float) -> void:
		if play_id != _play_id or _scene_art == null:
			return
		_scene_art.position = start_position.lerp(target_position, weight),
		0.0, 1.0, tween_duration)
	tween.tween_method(func(weight: float) -> void:
		if play_id != _play_id or _scene_art == null:
			return
		_scene_art.overlay_tint = Color(
			lerpf(start_overlay.r, target_overlay.r, weight),
			lerpf(start_overlay.g, target_overlay.g, weight),
			lerpf(start_overlay.b, target_overlay.b, weight),
			lerpf(start_overlay.a, target_overlay.a, weight)
		)
		_scene_art.queue_redraw(), 0.0, 1.0, tween_duration)
