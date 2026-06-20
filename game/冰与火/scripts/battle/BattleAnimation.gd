# BattleAnimation.gd — FE GBA 风格战斗动画面板 v2
# 修复：动画掷骰和结算使用同一套随机数
class_name BattleAnimation
extends Control

signal animation_finished(result: Dictionary)

const SLIDE_IN_DURATION  := 0.25
const SLIDE_OUT_DURATION := 0.25
const CHARGE_DURATION    := 0.14   # 快冲
const RETURN_DURATION    := 0.20   # 慢退
const CHARGE_OFFSET      := 80.0
const DAMAGE_FLOAT_RISE  := 40.0
const DAMAGE_FLOAT_DURATION := 0.7
const HIT_PAUSE          := 0.18
const ROUND_GAP          := 0.30

@onready var _atk_icon:   Sprite2D   = $Panel/AtkSide/Icon
@onready var _atk_name:   Label      = $Panel/AtkSide/Name
@onready var _atk_hp_bar: ProgressBar = $Panel/AtkSide/HPBar
@onready var _atk_hp_lbl: Label      = $Panel/AtkSide/HPLabel

@onready var _def_icon:   Sprite2D   = $Panel/DefSide/Icon
@onready var _def_name:   Label      = $Panel/DefSide/Name
@onready var _def_hp_bar: ProgressBar = $Panel/DefSide/HPBar
@onready var _def_hp_lbl: Label      = $Panel/DefSide/HPLabel

@onready var _panel: Control = $Panel

var _panel_hidden_y: float = 0.0
var _panel_shown_y:  float = 0.0

func _ready() -> void:
	visible = false
	var vs := get_viewport_rect().size
	_panel_hidden_y = vs.y
	_panel_shown_y  = vs.y - 200.0
	if _panel:
		_panel.position.y = _panel_hidden_y
	# 动态实例化后需主动应用 CJK 字体（不在初始 call_deferred 范围内）
	_apply_cjk_font_to_all()

func _get_cjk_font() -> Font:
	const BUNDLED := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED):
		var f := load(BUNDLED) as Font
		if f: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Heiti SC", "Arial Unicode MS",
		"Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"])
	return sf

func _apply_cjk_font_to_all() -> void:
	var font := _get_cjk_font()
	_apply_font_recursive(self, font)

func _apply_font_recursive(node: Node, font: Font) -> void:
	if node is Label:
		(node as Label).add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)

func play(attacker: Unit, defender: Unit, pred: Dictionary) -> void:
	# ── 在任何await之前提取所有需要的数据 ──────────────────
	# await期间节点可能被释放，必须在此之前把数据存成局部变量
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		animation_finished.emit({"atk_hit": false, "atk_damage": 0,
			"def_hit": false, "def_damage": 0, "atk_double": false,
			"double_hit": false, "double_damage": 0})
		return

	var atk_hp_now: int = attacker.data.hp
	var def_hp_now: int = defender.data.hp

	visible = true
	_setup_sides(attacker, defender)
	await _slide_panel(_panel_shown_y)

	# ── 预先掷骰（动画和结算共用同一套随机数）──
	var atk_hit:  bool = _roll(pred.get("atk_hit",  0))
	var atk_crit: bool = atk_hit and _roll(pred.get("atk_crit", 0))
	var atk_base: int  = int(pred.get("atk_damage", 0))
	var atk_dmg:  int  = atk_base * (3 if atk_crit else 1) if atk_hit else 0

	var def_hp_after_atk: int = maxi(def_hp_now - atk_dmg, 0)

	var def_hit:  bool = false
	var def_crit: bool = false
	var def_dmg:  int  = 0
	if def_hp_after_atk > 0:
		def_hit  = _roll(pred.get("def_hit",  0))
		def_crit = def_hit and _roll(pred.get("def_crit", 0))
		var def_base: int = int(pred.get("def_damage", 0))
		def_dmg = def_base * (3 if def_crit else 1) if def_hit else 0

	var atk_double_hit:  bool = false
	var atk_double_crit: bool = false
	var atk_double_dmg:  int  = 0
	if pred.get("atk_double", false) and def_hp_after_atk > 0:
		atk_double_hit  = _roll(pred.get("atk_hit",  0))
		atk_double_crit = atk_double_hit and _roll(pred.get("atk_crit", 0))
		var dbl_base: int = int(pred.get("atk_damage", 0))
		atk_double_dmg = dbl_base * (3 if atk_double_crit else 1) if atk_double_hit else 0

	# ── 播放动画（使用本地变量，不再访问节点data）──
	await _do_attack_anim(_atk_icon, _def_icon, _def_hp_bar, _def_hp_lbl,
		atk_hit, atk_dmg, atk_crit, false, def_hp_now)
	await get_tree().create_timer(ROUND_GAP).timeout

	if def_hp_after_atk > 0:
		await _do_attack_anim(_def_icon, _atk_icon, _atk_hp_bar, _atk_hp_lbl,
			def_hit, def_dmg, def_crit, true, atk_hp_now)
		await get_tree().create_timer(ROUND_GAP).timeout

	if pred.get("atk_double", false) and def_hp_after_atk > 0:
		await _do_attack_anim(_atk_icon, _def_icon, _def_hp_bar, _def_hp_lbl,
			atk_double_hit, atk_double_dmg, atk_double_crit, false, def_hp_after_atk)
		await get_tree().create_timer(ROUND_GAP).timeout

	await _slide_panel(_panel_hidden_y)
	visible = false

	animation_finished.emit({
		"atk_hit":       atk_hit,
		"atk_damage":    atk_dmg,
		"def_hit":       def_hit,
		"def_damage":    def_dmg,
		"atk_double":    pred.get("atk_double", false),
		"double_hit":    atk_double_hit,
		"double_damage": atk_double_dmg,
	})

# ── UI初始化 ────────────────────────────────────────────
func _setup_sides(attacker: Unit, defender: Unit) -> void:
	_fill_side(attacker, _atk_icon, _atk_name, _atk_hp_bar, _atk_hp_lbl)
	_fill_side(defender, _def_icon, _def_name, _def_hp_bar, _def_hp_lbl)

func _fill_side(unit: Unit, icon: Sprite2D, name_lbl: Label,
		hp_bar: ProgressBar, hp_lbl: Label) -> void:
	if icon:
		# 优先加载立绘（48×48），其次回退至地图行走图（32×32）
		var loaded_portrait := false
		if unit.has_meta("portrait_path"):
			var path: String = unit.get_meta("portrait_path") as String
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex != null:
					icon.texture        = tex
					icon.region_enabled = true
					icon.region_rect    = Rect2(0, 0, 48, 48)
					loaded_portrait     = true
		if not loaded_portrait:
			var sprite := unit.get_node_or_null("Sprite") as Sprite2D
			if sprite and sprite.texture:
				icon.texture        = sprite.texture
				icon.region_enabled = true
				icon.region_rect    = Rect2(0, 0, 32, 32)
	if name_lbl:
		name_lbl.text = unit.data.name
	var max_hp: int = unit.data.max_hp
	if hp_bar:
		hp_bar.max_value = float(max_hp)
		hp_bar.value     = float(unit.data.hp)
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [unit.data.hp, max_hp]

# ── 滑入/滑出面板 ────────────────────────────────────────
func _slide_panel(target_y: float) -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", target_y, SLIDE_IN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	await tween.finished

# ── 单次攻击动画（含HP条更新）────────────────────────────
func _do_attack_anim(
		atk_icon: Sprite2D, def_icon: Sprite2D,
		def_hp_bar: ProgressBar, def_hp_lbl: Label,
		hit: bool, damage: int, crit: bool,
		is_counter: bool, def_hp_before: int) -> void:

	if atk_icon == null or def_icon == null:
		return

	var dir := 1.0 if not is_counter else -1.0
	var origin_x := atk_icon.position.x

	# 快冲：加速冲向目标
	var tween_charge := create_tween()
	tween_charge.tween_property(atk_icon, "position:x",
		origin_x + CHARGE_OFFSET * dir, CHARGE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween_charge.finished

	if hit:
		# 受击方抖动
		await _shake_icon(def_icon)
		# 更新HP条
		var new_hp := maxi(def_hp_before - damage, 0)
		await _update_hp_bar(def_hp_bar, def_hp_lbl, def_hp_before, new_hp, def_hp_bar.max_value as int)
		# 伤害数字
		_spawn_damage_label(def_icon, damage, crit)
	else:
		_spawn_miss_label(def_icon)

	await get_tree().create_timer(HIT_PAUSE).timeout

	# 慢退：减速回到原位
	var tween_back := create_tween()
	tween_back.tween_property(atk_icon, "position:x", origin_x, RETURN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween_back.finished

# ── 受击抖动（左右快速震动）──────────────────────────────
func _shake_icon(icon: Sprite2D) -> void:
	var orig := icon.position
	var tween := create_tween()
	tween.tween_property(icon, "position:x", orig.x - 8.0, 0.04)
	tween.tween_property(icon, "position:x", orig.x + 10.0, 0.04)
	tween.tween_property(icon, "position:x", orig.x - 6.0, 0.04)
	tween.tween_property(icon, "position:x", orig.x + 4.0, 0.03)
	tween.tween_property(icon, "position:x", orig.x, 0.03)
	# 同时闪白
	tween.parallel().tween_property(icon, "modulate", Color(2.5, 2.5, 2.5, 1), 0.05)
	tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.12)
	await tween.finished

# ── HP条平滑更新 ─────────────────────────────────────────
func _update_hp_bar(bar: ProgressBar, lbl: Label,
		hp_from: int, hp_to: int, max_hp: int) -> void:
	if bar == null:
		return
	var tween := create_tween()
	tween.tween_property(bar, "value", float(hp_to), 0.3)\
		.set_ease(Tween.EASE_OUT)
	if lbl:
		tween.tween_callback(func() -> void:
			lbl.text = "%d/%d" % [hp_to, max_hp])
	await tween.finished

# ── 伤害数字浮字 ─────────────────────────────────────────
func _spawn_damage_label(near: Sprite2D, damage: int, crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = ("暴击！%d" % damage) if crit else str(damage)
	lbl.add_theme_font_override("font", _get_cjk_font())
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.1) if crit else Color(1.0, 0.25, 0.25))
	lbl.add_theme_font_size_override("font_size", 22 if crit else 18)
	lbl.global_position = near.global_position + Vector2(0, -50)
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - DAMAGE_FLOAT_RISE, DAMAGE_FLOAT_DURATION)
	tween.tween_property(lbl, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)
	tween.chain().tween_callback(lbl.queue_free)

func _spawn_miss_label(near: Sprite2D) -> void:
	var lbl := Label.new()
	lbl.text = "MISS"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.global_position = near.global_position + Vector2(0, -50)
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 24.0, 0.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(lbl.queue_free)

func _roll(rate: int) -> bool:
	return randi() % 100 < rate
