# CutscenePlayer.gd — 逐帧文字幻灯片播放器
# 读取 JSON 数据，每张幻灯片：黑屏白字淡入 → 停留 → 淡出
# 支持空格/回车/点击跳过整个动画
class_name CutscenePlayer
extends CanvasLayer

signal cutscene_finished

# 淡入/淡出时长（秒）
const FADE_DURATION := 0.8

var _slides: Array = []
var _current_index: int = 0
var _is_playing: bool = false
var _skip_requested: bool = false

# 子节点引用（由 tscn 提供）
@onready var _label: Label = $TextLabel

func _ready() -> void:
	# 初始透明
	if _label:
		_label.modulate = Color(1, 1, 1, 0)

# ── 公开接口 ─────────────────────────────────────────────
## 播放指定 JSON 路径的过场动画
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

# ── 输入：空格/回车/鼠标点击跳过 ───────────────────────
func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	var key_skip: bool = (event is InputEventKey) and (event as InputEventKey).pressed and (
		(event as InputEventKey).keycode == KEY_SPACE or
		(event as InputEventKey).keycode == KEY_ENTER)
	var mouse_skip: bool = (event is InputEventMouseButton) and \
		(event as InputEventMouseButton).pressed and \
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if key_skip or mouse_skip:
		_skip_requested = true
		get_viewport().set_input_as_handled()

# ── 内部流程 ─────────────────────────────────────────────
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CutscenePlayer: 找不到文件 %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CutscenePlayer: 无法读取文件 %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null or not (result is Dictionary):
		push_error("CutscenePlayer: JSON 解析失败 %s" % path)
		return {}
	return result as Dictionary

func _play_slide(index: int) -> void:
	if index >= _slides.size():
		_finish()
		return

	var slide: Dictionary = _slides[index]
	var text: String    = slide.get("text", "")
	var duration: float = float(slide.get("duration", 3.0))

	if _label:
		_label.text    = text
		_label.modulate = Color(1, 1, 1, 0)

	# 淡入
	await _fade_label(0.0, 1.0, FADE_DURATION)
	if _skip_requested:
		_finish()
		return

	# 停留（可被跳过）
	await _wait_skippable(duration)
	if _skip_requested:
		_finish()
		return

	# 淡出
	await _fade_label(1.0, 0.0, FADE_DURATION)
	if _skip_requested:
		_finish()
		return

	_current_index += 1
	_play_slide(_current_index)

## 用 Tween 平滑地修改 label 的 alpha
func _fade_label(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _label == null:
		await get_tree().create_timer(duration).timeout
		return
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", to_alpha, duration).from(from_alpha)
	await tween.finished

## 等待指定秒数，期间每帧检查跳过标志
func _wait_skippable(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and not _skip_requested:
		elapsed += get_process_delta_time()
		await get_tree().process_frame

func _finish() -> void:
	_is_playing = false
	if _label:
		_label.modulate = Color(1, 1, 1, 0)
	visible = false
	cutscene_finished.emit()
