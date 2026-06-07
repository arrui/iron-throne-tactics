# DialogueSystem.gd
class_name DialogueSystem
extends CanvasLayer

signal dialogue_finished

const CHAR_DELAY := 0.05

@onready var _speaker_label: Label = $SpeakerLabel
@onready var _text_label:    Label = $TextLabel
@onready var _prompt_icon:   Label = $PromptIcon

var _lines:       Array  = []
var _current_idx: int    = 0
var _full_text:   String = ""
var _is_typing:   bool   = false
var _tween:       Tween  = null
var _active:      bool   = false

func play(dialogue_path: String) -> void:
	var data := _load_json(dialogue_path)
	if data.is_empty():
		dialogue_finished.emit()
		return

	_lines       = data.get("lines", [])
	_current_idx = 0
	_active      = true

	# 显示对话框
	visible = true
	_prompt_icon.visible = false
	_show_line(_current_idx)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueSystem: 找不到文件 " + path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("DialogueSystem: JSON解析失败 " + path)
		file.close()
		return {}
	file.close()
	var result: Variant = parser.data
	if result is Dictionary:
		return result as Dictionary
	return {}

func _show_line(idx: int) -> void:
	if idx < 0 or idx >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[idx]
	_speaker_label.text  = line.get("speaker", "")
	_full_text           = line.get("text", "")
	_text_label.text     = ""
	_prompt_icon.visible = false
	_type_text(_full_text)

func _type_text(text: String) -> void:
	_is_typing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var char_count := text.length()
	for i in range(char_count):
		var partial := text.substr(0, i + 1)
		_tween.tween_callback(func() -> void:
			_text_label.text = partial
		).set_delay(CHAR_DELAY)
	_tween.tween_callback(_on_typing_finished)

func _on_typing_finished() -> void:
	_is_typing = false
	_prompt_icon.visible = true
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt_icon, "modulate:a", 0.0, 0.5)
	blink.tween_property(_prompt_icon, "modulate:a", 1.0, 0.5)

func _skip_typing() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_text_label.text     = _full_text
	_is_typing           = false
	_prompt_icon.visible = true

func _advance() -> void:
	if not _active: return
	if _is_typing:
		_skip_typing()
		return
	var next_idx: int = _lines[_current_idx].get("next", -1)
	if next_idx == -1:
		_finish()
	else:
		_current_idx = next_idx
		_show_line(_current_idx)

func _finish() -> void:
	_active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	dialogue_finished.emit()

func _input(event: InputEvent) -> void:
	if not _active: return
	var triggered := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		triggered = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			triggered = true
	if triggered:
		get_viewport().set_input_as_handled()
		_advance()
