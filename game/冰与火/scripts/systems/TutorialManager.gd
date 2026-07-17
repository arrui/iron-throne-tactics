# TutorialManager.gd — 教学提示弹窗队列管理器
# 按顺序显示教学提示，支持点击关闭或3秒自动关闭
# 提供信号 all_steps_done 和 await 机制 wait_for_step(index)
class_name TutorialManager
extends CanvasLayer

signal all_steps_done
signal _step_done(index: int)

# ── 弹窗样式常量 ─────────────────────────────────────────
const BG_COLOR       := Color(0.0, 0.0, 0.0, 0.75)
const TEXT_COLOR     := Color(1.0, 1.0, 1.0, 1.0)
const PANEL_WIDTH    := 560.0
const PANEL_HEIGHT   := 96.0
const CORNER_RADIUS  := 12.0
const FONT_SIZE      := 16

# ── 内部状态 ──────────────────────────────────────────────
var _queue:          Array[String]  = []
var _current_index:  int            = 0
var _showing:        bool           = false
var _auto_timer:     SceneTreeTimer = null

# ── 弹窗节点引用 ──────────────────────────────────────────
var _panel:      PanelContainer = null
var _arrow_lbl:  Label          = null
var _text_lbl:   Label          = null

# ════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 10   # 确保在战斗 UI 之上
	_build_panel()
	_panel.visible = false

# ── 公开 API ──────────────────────────────────────────────

## 显示单条提示（加入队列末尾）
func show_step(text: String) -> void:
	_queue.append(text)
	if not _showing:
		_show_next()

## 显示多条提示序列（清空旧队列后批量加入）
func show_steps(steps: Array) -> void:
	_queue.clear()
	_current_index = 0
	for s: String in steps:
		_queue.append(s)
	if not _showing:
		_show_next()

## 等待指定步骤（0-based）完成后返回
## 用法：await tutorial_mgr.wait_for_step(2)
func wait_for_step(step_index: int) -> void:
	# 若该步骤已经完成，立即返回
	if _current_index > step_index:
		return
	await _step_done

# ════════════════════════════════════════════════════════
# 内部逻辑
# ════════════════════════════════════════════════════════

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		all_steps_done.emit()
		return

	_showing = true
	var text: String = _queue.pop_front()
	_display(text)

	# 3秒自动关闭
	_auto_timer = get_tree().create_timer(3.0)
	var step_timer := _auto_timer
	await step_timer.timeout
	if _showing and _auto_timer == step_timer:
		_close_current()

func _display(text: String) -> void:
	if _text_lbl:
		_text_lbl.text = text
	if _panel:
		_panel.visible = true
		# 定位到屏幕中偏下（约75%高度处）
		var vs := get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			(vs.x - PANEL_WIDTH) * 0.5,
			vs.y * 0.72
		)

func _close_current() -> void:
	_showing = false
	if _panel:
		_panel.visible = false
	var done_idx := _current_index
	_current_index += 1
	_step_done.emit(done_idx)
	# 稍微延迟后显示下一条，避免连续闪烁
	await get_tree().create_timer(0.18).timeout
	_show_next()

# ── 点击任意位置关闭 ──────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _showing: return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# 当前提示先关闭；下一条会换用新计时器，旧计时器将因身份不匹配而失效。
		_showing = false
		if _panel: _panel.visible = false
		var done_idx := _current_index
		_current_index += 1
		_step_done.emit(done_idx)
		get_viewport().set_input_as_handled()
		await get_tree().create_timer(0.18).timeout
		_show_next()

# ════════════════════════════════════════════════════════
# 弹窗构建（纯代码，无需 .tscn）
# ════════════════════════════════════════════════════════

func _get_cjk_font() -> Font:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED):
		var f := load(BUNDLED) as Font
		if f != null: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS", "Microsoft YaHei",
		"PingFang SC", "STHeitiSC-Medium", "Noto Sans CJK SC"])
	return sf

func _apply_font(lbl: Label, size: int) -> void:
	var f := _get_cjk_font()
	lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", size)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# 自定义样式：深色半透明圆角矩形
	var style := StyleBoxFlat.new()
	style.bg_color            = BG_COLOR
	style.corner_radius_top_left     = int(CORNER_RADIUS)
	style.corner_radius_top_right    = int(CORNER_RADIUS)
	style.corner_radius_bottom_left  = int(CORNER_RADIUS)
	style.corner_radius_bottom_right = int(CORNER_RADIUS)
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# 顶部箭头图标
	_arrow_lbl = Label.new()
	_arrow_lbl.text                = "▼"
	_arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 0.9))
	_apply_font(_arrow_lbl, 14)
	vbox.add_child(_arrow_lbl)

	# 提示文字
	_text_lbl = Label.new()
	_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_text_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	_apply_font(_text_lbl, FONT_SIZE)
	vbox.add_child(_text_lbl)

	# 点击提示（小字）
	var hint := Label.new()
	hint.text                = "（点击任意位置继续）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	_apply_font(hint, 12)
	vbox.add_child(hint)

	add_child(_panel)
