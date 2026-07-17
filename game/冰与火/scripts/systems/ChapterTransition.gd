class_name ChapterTransition
extends CanvasLayer

signal transition_finished

const BattleChromeTheme := preload("res://scripts/ui/BattleChromeTheme.gd")

@onready var _background:      ColorRect = $Background
@onready var _chapter_number:  Label     = $ChapterNumber
@onready var _chapter_title:   Label     = $ChapterTitle
@onready var _time_label:      Label     = $TimeLabel
@onready var _sub_label:       Label     = $SubLabel
@onready var _objective_label: Label     = $ObjectiveLabel

var _transition_id: int = 0

func _ready() -> void:
	# 为章节转场标签应用中文字体
	var font := _get_cjk_font()
	if font:
		for child in get_children():
			if child is Label:
				(child as Label).add_theme_font_override("font", font)
	_apply_dark_ui_theme()

func _get_cjk_font() -> Font:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED):
		var f := load(BUNDLED) as Font
		if f != null: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
	return sf

func show_chapter(number: String, title: String,
		time_label: String, sub_label: String = "", objective_label: String = "") -> void:
	_transition_id += 1
	var transition_id := _transition_id
	_chapter_number.text = number
	_chapter_title.text  = title
	_time_label.text     = time_label
	_sub_label.text      = sub_label
	_sub_label.visible   = sub_label != ""
	_objective_label.text = objective_label
	_objective_label.visible = objective_label != ""

	# CanvasLayer 没有 modulate，对所有子 CanvasItem 单独操作
	var items: Array[CanvasItem] = _get_canvas_items()
	for item: CanvasItem in items:
		item.modulate = Color(1, 1, 1, 0)
	visible = true

	# 淡入
	var tw_in := create_tween().set_parallel(true)
	for item: CanvasItem in items:
		tw_in.tween_method(func(alpha: float) -> void:
			if transition_id == _transition_id: item.modulate.a = alpha,
			0.0, 1.0, 0.8)
	await tw_in.finished
	if transition_id != _transition_id:
		return

	await get_tree().create_timer(2.5).timeout
	if transition_id != _transition_id:
		return

	# 淡出
	var tw_out := create_tween().set_parallel(true)
	for item: CanvasItem in items:
		tw_out.tween_method(func(alpha: float) -> void:
			if transition_id == _transition_id: item.modulate.a = alpha,
			1.0, 0.0, 0.8)
	await tw_out.finished
	if transition_id != _transition_id:
		return

	visible = false
	transition_finished.emit()

func _get_canvas_items() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	for child: Node in get_children():
		if child is CanvasItem:
			result.append(child as CanvasItem)
	return result

func _apply_dark_ui_theme() -> void:
	if _background != null:
		_background.color = BattleChromeTheme.BACKGROUND_COLOR
	if _chapter_number != null:
		_chapter_number.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
	if _chapter_title != null:
		_chapter_title.add_theme_color_override("font_color", BattleChromeTheme.TEXT_PRIMARY)
	if _time_label != null:
		_time_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_MUTED)
	if _sub_label != null:
		_sub_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_GUIDANCE)
	if _objective_label != null:
		_objective_label.add_theme_color_override("font_color", BattleChromeTheme.TEXT_OBJECTIVE)
