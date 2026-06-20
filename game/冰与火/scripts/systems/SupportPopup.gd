class_name SupportPopup
extends CanvasLayer

signal popup_closed

const AUTO_CLOSE_SEC := 4.0   # 无操作4秒自动关闭

@onready var _content_label: Label  = $Background/VBox/ContentLabel
@onready var _rank_label:    Label  = $Background/VBox/RankLabel
@onready var _close_btn:     Button = $Background/VBox/CloseBtn

var _auto_timer: SceneTreeTimer = null

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
	if node is Label:  (node as Label).add_theme_font_override("font", font)
	elif node is Button: (node as Button).add_theme_font_override("font", font)
	for child in node.get_children(): _apply_font_recursive(child, font)

func show_support(unit_a: String, unit_b: String, rank: String, bonus: Dictionary) -> void:
	_content_label.text = "两名单位长期相邻作战，默契转化为战场加成。\n序章目前仅支持 C 级支援。"
	var hit: int    = bonus.get("hit", 0)
	var avoid: int  = bonus.get("avoid", 0)
	_rank_label.text = "%s ↔ %s  [%s级 +%d%%命中/%d%%回避]" % [unit_a, unit_b, rank, hit, avoid]
	visible = true

	if not _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.connect(_on_close_pressed)

	# 自动关闭计时器
	_auto_timer = get_tree().create_timer(AUTO_CLOSE_SEC)
	_auto_timer.timeout.connect(_on_close_pressed)

# 点击任意位置关闭（包括弹窗外区域）
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if not visible: return   # 防止重复触发
	visible = false
	popup_closed.emit()
