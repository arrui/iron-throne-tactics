class_name ChapterTransition
extends CanvasLayer

signal transition_finished

@onready var _background:      ColorRect = $Background
@onready var _chapter_number:  Label     = $ChapterNumber
@onready var _chapter_title:   Label     = $ChapterTitle
@onready var _time_label:      Label     = $TimeLabel
@onready var _sub_label:       Label     = $SubLabel

func _ready() -> void:
	# 为章节转场标签应用中文字体
	var font := _get_cjk_font()
	if font:
		for child in get_children():
			if child is Label:
				(child as Label).add_theme_font_override("font", font)

func _get_cjk_font() -> Font:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED):
		var f := load(BUNDLED) as Font
		if f != null: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei"])
	return sf

func show_chapter(number: String, title: String,
		time_label: String, sub_label: String = "") -> void:
	_chapter_number.text = number
	_chapter_title.text  = title
	_time_label.text     = time_label
	_sub_label.text      = sub_label
	_sub_label.visible   = sub_label != ""

	# CanvasLayer 没有 modulate，对所有子 CanvasItem 单独操作
	var items: Array[CanvasItem] = _get_canvas_items()
	for item: CanvasItem in items:
		item.modulate = Color(1, 1, 1, 0)
	visible = true

	# 淡入
	var tw_in := create_tween().set_parallel(true)
	for item: CanvasItem in items:
		tw_in.tween_property(item, "modulate:a", 1.0, 0.8)
	await tw_in.finished

	await get_tree().create_timer(2.5).timeout

	# 淡出
	var tw_out := create_tween().set_parallel(true)
	for item: CanvasItem in items:
		tw_out.tween_property(item, "modulate:a", 0.0, 0.8)
	await tw_out.finished

	visible = false
	transition_finished.emit()

func _get_canvas_items() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	for child: Node in get_children():
		if child is CanvasItem:
			result.append(child as CanvasItem)
	return result
