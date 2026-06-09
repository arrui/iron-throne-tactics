class_name ChapterTransition
extends CanvasLayer

signal transition_finished

@onready var _background: ColorRect = $Background
@onready var _chapter_number: Label = $ChapterNumber
@onready var _chapter_title: Label = $ChapterTitle
@onready var _time_label: Label = $TimeLabel
@onready var _sub_label: Label = $SubLabel

func show_chapter(number: String, title: String, time_label: String, sub_label: String = "") -> void:
	_chapter_number.text = number
	_chapter_title.text = title
	_time_label.text = time_label
	_sub_label.text = sub_label
	_sub_label.visible = sub_label != ""
	modulate = Color(1, 1, 1, 0)
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.8)
	await tween.finished
	visible = false
	transition_finished.emit()
