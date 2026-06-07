# DialogueSystem.gd
# 对话系统：读取JSON文件，逐行显示对话
# 支持点击/空格/Enter推进；对话结束后发出 dialogue_finished 信号
class_name DialogueSystem
extends Node

signal dialogue_finished

# 每个字符显示间隔（秒）
const CHAR_DELAY := 0.05

# 节点引用（由 DialogueBox 场景提供）
@onready var _speaker_label: Label = $SpeakerLabel
@onready var _text_label:    Label = $TextLabel
@onready var _prompt_icon:   Label = $PromptIcon

var _lines:        Array    = []
var _current_idx:  int      = 0
var _full_text:    String   = ""
var _is_typing:    bool     = false
var _tween:        Tween    = null
var _active:       bool     = false

# ── 公开接口 ──────────────────────────────────────────────

## 加载并播放指定对话文件（res:// 路径）
func play(dialogue_path: String) -> void:
	var data := _load_json(dialogue_path)
	if data.is_empty():
		dialogue_finished.emit()
		return

	_lines       = data.get("lines", [])
	_current_idx = 0
	_active      = true
	visible      = true
	_prompt_icon.visible = false
	_show_line(_current_idx)

# ── 内部逻辑 ──────────────────────────────────────────────

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
	var result = parser.data
	if result is Dictionary:
		return result
	return {}

func _show_line(idx: int) -> void:
	if idx < 0 or idx >= _lines.size():
		_finish()
		return

	var line: Dictionary = _lines[idx]
	_speaker_label.text = line.get("speaker", "")
	_full_text          = line.get("text", "")
	_text_label.text    = ""
	_prompt_icon.visible = false
	_type_text(_full_text)

## 逐字显示效果（使用 Tween 按字符数量步进）
func _type_text(text: String) -> void:
	_is_typing = true

	# 终止之前可能残留的 Tween
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
	_start_prompt_blink()

## ▶ 图标闪烁（循环 Tween）
func _start_prompt_blink() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt_icon, "modulate:a", 0.0, 0.5)
	blink.tween_property(_prompt_icon, "modulate:a", 1.0, 0.5)

## 立即显示完整文本（跳过逐字动画）
func _skip_typing() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_text_label.text = _full_text
	_is_typing       = false
	_prompt_icon.visible = true

func _advance() -> void:
	if not _active:
		return
	if _is_typing:
		_skip_typing()
		return
	# 已显示完，进入下一行
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

# ── 输入处理 ──────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active:
		return
	var advance_triggered := false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance_triggered = true
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				advance_triggered = true
	if advance_triggered:
		get_viewport().set_input_as_handled()
		_advance()
