class_name SupportPopup
extends CanvasLayer

signal popup_closed

@onready var _content_label: Label = $Background/VBox/ContentLabel
@onready var _rank_label: Label = $Background/VBox/RankLabel
@onready var _close_btn: Button = $Background/VBox/CloseBtn

func show_support(unit_a: String, unit_b: String, rank: String, bonus: Dictionary) -> void:
	_content_label.text = "当两名单位相邻站立时，战场上的默契会转化为实际加成。\n支援等级越高，加成越强。序章目前仅支持 C 级支援。"
	var hit: int = bonus.get("hit", 0)
	var avoid: int = bonus.get("avoid", 0)
	_rank_label.text = unit_a + " \u2194 " + unit_b + "  [" + rank + "\u7ea7 +" + str(hit) + "%\u547d\u4e2d/" + str(avoid) + "%\u56de\u907f]"
	visible = true
	if not _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.connect(_on_close_pressed)

func _on_close_pressed() -> void:
	visible = false
	popup_closed.emit()
