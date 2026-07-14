# DialogueSystem.gd
class_name DialogueSystem
extends CanvasLayer

signal dialogue_finished

const BattleChromeTheme := preload("res://scripts/ui/BattleChromeTheme.gd")

const CHAR_DELAY := 0.05
const PORTRAIT_DIR := "res://assets/units/"
const SPEAKER_PORTRAIT_MAP := {
	"奈德": "ned_stark_portrait.png",
	"劳勃": "robert_baratheon_portrait.png",
	"霍兰": "howland_reed_portrait.png",
	"霍兰德": "howland_reed_portrait.png",
	"皇家卫兵": "royal_soldier_portrait.png",
	"王军": "royal_soldier_portrait.png",
	"兰尼斯特士兵": "lannister_soldier_portrait.png",
	"北境骑士": "northern_knight_portrait.png",
	"反叛领主": "rebel_lord_portrait.png",
	"詹姆": "jaime_lannister_portrait.png",
	"史林特": "janos_slynt_portrait.png",
	"旁白": "",
}

@onready var _speaker_label: Label = $SpeakerLabel
@onready var _text_label:    Label = $TextLabel
@onready var _prompt_icon:   Label = $PromptIcon
@onready var _background:    ColorRect = $Background
@onready var _portrait_panel: Control = $PortraitPanel
@onready var _portrait_frame: ColorRect = $PortraitPanel/PortraitFrame
@onready var _portrait_rect: TextureRect = $PortraitPanel/Portrait

var _lines:       Array  = []
var _current_idx: int    = 0
var _full_text:   String = ""
var _is_typing:   bool   = false
var _tween:       Tween  = null
var _active:      bool   = false
var _typing_token: int   = 0

func _ready() -> void:
	# 为对话系统标签应用中文字体
	var font: Font = null
	const BUNDLED_FONT := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED_FONT):
		font = load(BUNDLED_FONT) as Font
	if font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
		font = sf
	if font:
		for child in get_children():
			if child is Label:
				(child as Label).add_theme_font_override("font", font)
	_apply_dark_ui_theme()

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
	_update_portrait(_speaker_label.text)
	_typing_token += 1
	var token := _typing_token
	_is_typing = true
	call_deferred("_start_type_text", _full_text, token)

func _start_type_text(text: String, token: int) -> void:
	if token != _typing_token or not _active:
		return
	await get_tree().process_frame
	if token != _typing_token or not _active:
		return
	_type_text(text)

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
	_typing_token += 1
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
	_typing_token += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	if _portrait_rect:
		_portrait_rect.texture = null
	dialogue_finished.emit()

func _update_portrait(speaker: String) -> void:
	if _portrait_panel == null or _portrait_rect == null:
		return
	var portrait_name: String = SPEAKER_PORTRAIT_MAP.get(speaker, "")
	if portrait_name == "":
		_portrait_panel.visible = false
		_portrait_rect.texture = null
		return
	var tex := _load_portrait_texture(PORTRAIT_DIR + portrait_name)
	if tex == null:
		_portrait_panel.visible = false
		_portrait_rect.texture = null
		return
	_portrait_rect.texture = tex
	_portrait_panel.visible = true

func _load_portrait_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

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

func _apply_dark_ui_theme() -> void:
	if _background != null:
		_background.color = BattleChromeTheme.BACKGROUND_COLOR
	if _portrait_panel is Panel:
		(_portrait_panel as Panel).add_theme_stylebox_override("panel",
			BattleChromeTheme.make_panel_style(
				BattleChromeTheme.PANEL_HIGHLIGHT_BG,
				BattleChromeTheme.PANEL_HIGHLIGHT_BORDER,
				8,
				2,
				8
			)
		)
	if _portrait_frame != null:
		_portrait_frame.color = BattleChromeTheme.PANEL_STEEL_BG
	if _speaker_label != null:
		_speaker_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	if _text_label != null:
		_text_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)
	if _prompt_icon != null:
		_prompt_icon.add_theme_color_override("font_color", BattleChromeTheme.TEXT_ACCENT)
