extends RefCounted

const BUNDLED_FONT := "res://assets/fonts/ArialUnicode.ttf"
const SYSTEM_FONT_PATHS := [
	"/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
	"/Library/Fonts/Arial Unicode.ttf",
	"/System/Library/Fonts/STHeiti Medium.ttc",
	"/System/Library/Fonts/Hiragino Sans GB.ttc",
	"C:/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/simhei.ttf",
	"/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
]
const SYSTEM_FONT_NAMES := [
	"Heiti SC",
	"Hiragino Sans GB",
	"Arial Unicode MS",
	"Microsoft YaHei",
	"PingFang SC",
	"STHeitiSC-Medium",
	"WenQuanYi Micro Hei",
	"Noto Sans CJK SC",
]

static var _cached_font: Font = null

static func get_font() -> Font:
	if _cached_font != null:
		return _cached_font
	if ResourceLoader.exists(BUNDLED_FONT):
		var bundled_font := load(BUNDLED_FONT) as Font
		if bundled_font != null:
			_cached_font = bundled_font
			return _cached_font
	for path in SYSTEM_FONT_PATHS:
		if FileAccess.file_exists(path):
			var os_font := load(path) as Font
			if os_font != null:
				_cached_font = os_font
				return _cached_font
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(SYSTEM_FONT_NAMES)
	_cached_font = system_font
	return _cached_font

static func apply_global_theme(font_size: int = 14) -> Font:
	var font := get_font()
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font = font
		theme.default_font_size = font_size
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = font_size
	return font

static func apply_to_node_recursive(node: Node, font: Font = null) -> void:
	if node == null:
		return
	if font == null:
		font = get_font()
	if node is Label:
		(node as Label).add_theme_font_override("font", font)
	elif node is Button:
		(node as Button).add_theme_font_override("font", font)
	elif node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_override("normal_font", font)
	for child in node.get_children():
		apply_to_node_recursive(child, font)

static func apply_to_confirmation_dialog(dialog: ConfirmationDialog, font: Font = null) -> void:
	if dialog == null:
		return
	if font == null:
		font = get_font()
	dialog.add_theme_font_override("title_font", font)
	apply_to_node_recursive(dialog, font)
	var body_label := dialog.get_label()
	if body_label != null:
		body_label.add_theme_font_override("font", font)
	var ok_button := dialog.get_ok_button()
	if ok_button != null:
		ok_button.add_theme_font_override("font", font)
	var cancel_button := dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.add_theme_font_override("font", font)
