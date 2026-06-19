class_name GameOver
extends CanvasLayer

signal restart_chapter
signal quit_to_menu

@onready var _message_label: Label = $Background/VBox/MessageLabel
@onready var _restart_btn: Button = $Background/VBox/RestartBtn
@onready var _quit_btn: Button = $Background/VBox/QuitBtn

func _ready() -> void:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	var font: Font = load(BUNDLED) as Font if ResourceLoader.exists(BUNDLED) else null
	if font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
		font = sf
	for child in get_children():
		_apply_font_recursive(child, font)

func _apply_font_recursive(node: Node, font: Font) -> void:
	if node is Label: (node as Label).add_theme_font_override("font", font)
	elif node is Button: (node as Button).add_theme_font_override("font", font)
	for child in node.get_children(): _apply_font_recursive(child, font)

func show_game_over(unit_name: String) -> void:
	_message_label.text = unit_name + " 阵亡于战场"
	visible = true
	if not _restart_btn.pressed.is_connected(_on_restart_pressed):
		_restart_btn.pressed.connect(_on_restart_pressed)
	if not _quit_btn.pressed.is_connected(_on_quit_pressed):
		_quit_btn.pressed.connect(_on_quit_pressed)

func _on_restart_pressed() -> void:
	visible = false
	restart_chapter.emit()

func _on_quit_pressed() -> void:
	visible = false
	quit_to_menu.emit()
