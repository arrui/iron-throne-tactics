# CutscenePlayer.gd — 升级版，支持像素背景图 + 主标题 + 副标题
class_name CutscenePlayer
extends CanvasLayer

signal cutscene_finished

const FADE_DURATION := 0.6
const TEXT_FADE_IN  := 0.4

var _slides: Array = []
var _current_index: int = 0
var _is_playing: bool = false
var _skip_requested: bool = false

@onready var _bg_rect:   ColorRect = $Background
@onready var _bg_image:  TextureRect = $BGImage
@onready var _label:     Label = $TextLabel
@onready var _sublabel:  Label = $SubTextLabel
@onready var _vignette:  ColorRect = $Vignette

func _ready() -> void:
	if _label:
		_label.modulate    = Color(1, 1, 1, 0)
	if _sublabel:
		_sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image:
		_bg_image.modulate = Color(1, 1, 1, 0)

func play(json_path: String) -> void:
	var data: Dictionary = _load_json(json_path)
	if data.is_empty():
		cutscene_finished.emit()
		return
	_slides = data.get("slides", [])
	if _slides.is_empty():
		cutscene_finished.emit()
		return
	_current_index  = 0
	_is_playing     = true
	_skip_requested = false
	visible = true
	_play_slide(_current_index)

func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	var key_skip: bool = (event is InputEventKey) and \
		(event as InputEventKey).pressed and \
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

func _play_slide(index: int) -> void:
	if index >= _slides.size():
		_finish()
		return

	var slide: Dictionary  = _slides[index]
	var text: String       = slide.get("text", "")
	var subtext: String    = slide.get("subtext", "")
	var duration: float    = float(slide.get("duration", 3.5))
	var image_path: String = slide.get("image", "")

	# 加载背景图（如果有）
	if _bg_image:
		if image_path != "" and ResourceLoader.exists(image_path):
			_bg_image.texture = load(image_path)
			await _fade_node(_bg_image, 0.0, 1.0, FADE_DURATION * 0.8)
		else:
			_bg_image.modulate = Color(1, 1, 1, 0)
			_bg_image.texture  = null

	# 设置文字并淡入
	if _label:
		_label.text = text
	if _sublabel:
		_sublabel.text = subtext

	await _fade_texts(0.0, 1.0, TEXT_FADE_IN)
	if _skip_requested:
		_finish()
		return

	await _wait_skippable(duration)
	if _skip_requested:
		_finish()
		return

	# 淡出文字
	await _fade_texts(1.0, 0.0, FADE_DURATION)
	if _bg_image and _bg_image.texture != null:
		await _fade_node(_bg_image, 1.0, 0.0, FADE_DURATION * 0.5)
	if _skip_requested:
		_finish()
		return

	_current_index += 1
	_play_slide(_current_index)

func _fade_texts(from_a: float, to_a: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	if _label:
		tween.tween_property(_label,    "modulate:a", to_a, duration).from(from_a)
	if _sublabel:
		tween.tween_property(_sublabel, "modulate:a", to_a, duration * 0.9).from(from_a)
	await tween.finished

func _fade_node(node: CanvasItem, from_a: float, to_a: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", to_a, duration).from(from_a)
	await tween.finished

func _wait_skippable(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and not _skip_requested:
		elapsed += get_process_delta_time()
		await get_tree().process_frame

func _finish() -> void:
	_is_playing = false
	if _label:    _label.modulate    = Color(1, 1, 1, 0)
	if _sublabel: _sublabel.modulate = Color(1, 1, 1, 0)
	if _bg_image: _bg_image.modulate = Color(1, 1, 1, 0)
	visible = false
	cutscene_finished.emit()
