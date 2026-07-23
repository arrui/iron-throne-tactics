extends RefCounted
class_name BattleChromeTheme

const BACKGROUND_COLOR := Color(0.05, 0.05, 0.08, 0.97)
const OVERLAY_DIM := Color(0.05, 0.05, 0.08, 0.82)

const PANEL_BG := Color(0.10, 0.09, 0.08, 0.96)
const PANEL_BORDER := Color(0.55, 0.46, 0.26, 1.00)
const PANEL_HIGHLIGHT_BG := Color(0.14, 0.12, 0.09, 0.98)
const PANEL_HIGHLIGHT_BORDER := Color(0.78, 0.66, 0.36, 1.00)
const PANEL_SELECTED_BG := Color(0.18, 0.15, 0.10, 0.99)
const PANEL_SELECTED_BORDER := Color(0.95, 0.80, 0.40, 1.00)
const PANEL_STEEL_BG := Color(0.11, 0.11, 0.10, 0.98)
const PANEL_STEEL_BORDER := Color(0.42, 0.42, 0.36, 1.00)
const PANEL_DANGER_BG := Color(0.18, 0.08, 0.07, 0.98)
const PANEL_DANGER_BORDER := Color(0.66, 0.25, 0.20, 1.00)

const BUTTON_NORMAL_BG := Color(0.16, 0.14, 0.10, 0.95)
const BUTTON_NORMAL_BORDER := Color(0.50, 0.42, 0.22, 1.00)
const BUTTON_HOVER_BG := Color(0.26, 0.22, 0.12, 0.98)
const BUTTON_HOVER_BORDER := Color(0.78, 0.66, 0.36, 1.00)
const BUTTON_PRESSED_BG := Color(0.36, 0.28, 0.14, 1.00)
const BUTTON_PRESSED_BORDER := Color(0.95, 0.80, 0.40, 1.00)
const BUTTON_DANGER_BG := Color(0.28, 0.11, 0.08, 0.98)
const BUTTON_DANGER_BORDER := Color(0.72, 0.34, 0.24, 1.00)
const BUTTON_SUPPORT_BG := Color(0.12, 0.18, 0.10, 0.98)
const BUTTON_SUPPORT_BORDER := Color(0.42, 0.58, 0.26, 1.00)
const BUTTON_MUTED_BG := Color(0.10, 0.11, 0.13, 0.96)
const BUTTON_MUTED_BORDER := Color(0.34, 0.38, 0.44, 1.00)

const TEXT_PRIMARY := Color(0.92, 0.88, 0.78, 1.00)
const TEXT_SECONDARY := Color(0.80, 0.82, 0.80, 1.00)
const TEXT_MUTED := Color(0.66, 0.70, 0.76, 1.00)
const TEXT_ACCENT := Color(0.95, 0.82, 0.38, 1.00)
const TEXT_OBJECTIVE := Color(0.95, 0.84, 0.45, 1.00)
const TEXT_GUIDANCE := Color(0.72, 0.86, 0.98, 1.00)
const TEXT_STATUS := Color(0.95, 0.76, 0.58, 1.00)
const TEXT_READY := Color(0.94, 0.84, 0.40, 1.00)
const TEXT_GOOD := Color(0.82, 0.88, 0.56, 1.00)
const TEXT_MANDATORY := Color(0.50, 0.90, 1.00, 1.00)

static func make_panel_style(
		bg_color: Color = PANEL_BG,
		border_color: Color = PANEL_BORDER,
		corner_radius: int = 8,
		border_width: int = 2,
		content_padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_padding
	style.content_margin_top = content_padding
	style.content_margin_right = content_padding
	style.content_margin_bottom = content_padding
	return style

static func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	return style

static func apply_button_palette(
		button: Button,
		normal_bg: Color,
		normal_border: Color,
		font_color: Color = TEXT_PRIMARY) -> void:
	var hover_bg := normal_bg.lightened(0.16)
	var hover_border := normal_border.lightened(0.16)
	var pressed_bg := normal_bg.lightened(0.26)
	var pressed_border := normal_border.lightened(0.26)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, normal_border, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, hover_border, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, pressed_border, 2))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_bg, hover_border, 1))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.16))
	button.add_theme_color_override("font_pressed_color", font_color.lightened(0.08))
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)

static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(BUTTON_NORMAL_BG, BUTTON_NORMAL_BORDER, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(BUTTON_HOVER_BG, BUTTON_HOVER_BORDER, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUTTON_PRESSED_BG, BUTTON_PRESSED_BORDER, 2))
	button.add_theme_stylebox_override("focus", _make_button_style(BUTTON_HOVER_BG, BUTTON_HOVER_BORDER, 1))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color(1.00, 0.96, 0.82, 1.00))
	button.add_theme_color_override("font_pressed_color", Color(1.00, 0.90, 0.50, 1.00))
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)

static func apply_dark_chrome_recursive(node: Node) -> void:
	if node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override("panel", make_panel_style())
	if node is Button:
		apply_button_theme(node as Button)
	if node is Label and node.get_parent() is PanelContainer:
		(node as Label).add_theme_color_override("font_color", TEXT_PRIMARY)
	for child in node.get_children():
		apply_dark_chrome_recursive(child)
