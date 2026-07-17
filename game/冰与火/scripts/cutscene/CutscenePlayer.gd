# CutscenePlayer.gd — 升级版，支持像素背景图 + 代码绘制场景 + 文字
class_name CutscenePlayer
extends CanvasLayer

signal cutscene_finished

const FADE_DURATION := 0.6
const TEXT_FADE_IN  := 0.4

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
	if _label:
		_label.modulate    = Color(1, 1, 1, 0)
	if _sublabel:
		_sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image:
		_bg_image.modulate = Color(1, 1, 1, 0)
	if _scene_art:
		_scene_art.alpha = 0.0
		_scene_art.modulate = Color(1, 1, 1, 0)

func _apply_cjk_font() -> void:
	# 直接加载内置 Arial Unicode 字体
	var font: Font = null
	const BUNDLED_FONT := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED_FONT):
		font = load(BUNDLED_FONT) as Font
	# 回退到系统字体
	if font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
		font = sf
	# 应用到所有标签
	if font:
		for child in get_children():
			if child is Label:
				(child as Label).add_theme_font_override("font", font)

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

	# 优先：代码绘制场景（无需外部资源）
	if _scene_art != null:
		if scene_art != "":
			_scene_art.scene_type = scene_art
			_scene_art.queue_redraw()
			await _fade_scene_art(0.0, 1.0, FADE_DURATION * 0.8, play_id)
			if play_id != _play_id: return
		else:
			# 确保上一张场景艺术已隐藏
			if _scene_art.alpha > 0.01:
				await _fade_scene_art(_scene_art.alpha, 0.0,
					FADE_DURATION * 0.5, play_id)
				if play_id != _play_id: return
			_scene_art.scene_type = ""
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
		_scene_art.queue_redraw()
	visible = false
	cutscene_finished.emit()
