# BattleAnimation.gd — FE GBA 风格战斗动画面板 v2
# 修复：动画掷骰和结算使用同一套随机数
class_name BattleAnimation
extends Control

signal animation_finished(result: Dictionary)

const SLIDE_IN_DURATION  := 0.25
const SLIDE_OUT_DURATION := 0.25
const CHARGE_DURATION    := 0.18
const RETURN_DURATION    := 0.15
const CHARGE_OFFSET      := 60.0
const DAMAGE_FLOAT_RISE  := 40.0
const DAMAGE_FLOAT_DURATION := 0.7
const HIT_PAUSE          := 0.2
const ROUND_GAP          := 0.25

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

func play(attacker: Unit, defender: Unit, pred: Dictionary) -> void:
	visible = true
	_setup_sides(attacker, defender)
	await _slide_panel(_panel_shown_y)

	# ── 预先掷骰（动画和结算共用同一套随机数）──
	var atk_hit:  bool = _roll(pred.get("atk_hit",  0))
	var atk_crit: bool = atk_hit and _roll(pred.get("atk_crit", 0))
	var atk_base: int  = int(pred.get("atk_damage", 0))
	var atk_dmg:  int  = atk_base * (3 if atk_crit else 1) if atk_hit else 0

	# 判断防守方是否存活（用于决定是否反击）
	var def_hp_after_atk: int = maxi(defender.data.hp - atk_dmg, 0)

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

	# ── 播放动画（只显示，不修改实际数据）──
	await _do_attack_anim(_atk_icon, _def_icon, atk_hit, atk_dmg, atk_crit, false)
	await get_tree().create_timer(ROUND_GAP).timeout

	if def_hp_after_atk > 0:
		await _do_attack_anim(_def_icon, _atk_icon, def_hit, def_dmg, def_crit, true)
		await get_tree().create_timer(ROUND_GAP).timeout

	if pred.get("atk_double", false) and def_hp_after_atk > 0:
		await _do_attack_anim(_atk_icon, _def_icon, atk_double_hit, atk_double_dmg, atk_double_crit, false)
		await get_tree().create_timer(ROUND_GAP).timeout

	await _slide_panel(_panel_hidden_y)
	visible = false

	# ── 把已掷好的结果传给 BattleMap 执行实际结算 ──
	animation_finished.emit({
		"atk_hit":        atk_hit,
		"atk_damage":     atk_dmg,
		"def_hit":        def_hit,
		"def_damage":     def_dmg,
		"atk_double":     pred.get("atk_double", false),
		"double_hit":     atk_double_hit,
		"double_damage":  atk_double_dmg,
	})

func _setup_sides(attacker: Unit, defender: Unit) -> void:
	_fill_side(attacker, _atk_icon, _atk_name, _atk_hp_bar, _atk_hp_lbl)
	_fill_side(defender, _def_icon, _def_name, _def_hp_bar, _def_hp_lbl)

func _fill_side(unit: Unit, icon: Sprite2D, name_lbl: Label,
		hp_bar: ProgressBar, hp_lbl: Label) -> void:
	if icon:
		var sprite := unit.get_node_or_null("Sprite") as Sprite2D
		if sprite and sprite.texture:
			icon.texture = sprite.texture
	if name_lbl:
		name_lbl.text = unit.data.name
	var max_hp: int = unit.data.max_hp
	if hp_bar:
		hp_bar.max_value = float(max_hp)
		hp_bar.value     = float(unit.data.hp)
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [unit.data.hp, max_hp]

func _slide_panel(target_y: float) -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", target_y, SLIDE_IN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	await tween.finished

func _do_attack_anim(atk_icon: Sprite2D, def_icon: Sprite2D,
		hit: bool, damage: int, crit: bool, is_counter: bool) -> void:
	if atk_icon == null or def_icon == null:
		return
	var dir := 1.0 if not is_counter else -1.0
	var origin_x := atk_icon.position.x

	var tween_charge := create_tween()
	tween_charge.tween_property(atk_icon, "position:x",
		origin_x + CHARGE_OFFSET * dir, CHARGE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween_charge.finished

	if hit:
		await _show_damage_number(def_icon, damage, crit)
		await _flash_icon(def_icon)
	else:
		await _show_miss_label(def_icon)

	await get_tree().create_timer(HIT_PAUSE).timeout

	var tween_back := create_tween()
	tween_back.tween_property(atk_icon, "position:x", origin_x, RETURN_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween_back.finished

func _show_damage_number(near: Sprite2D, damage: int, crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = ("暴！%d" % damage) if crit else str(damage)
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.1) if crit else Color(1.0, 0.2, 0.2))
	lbl.add_theme_font_size_override("font_size", 20 if crit else 16)
	lbl.global_position = near.global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(lbl)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - DAMAGE_FLOAT_RISE, DAMAGE_FLOAT_DURATION)
	tween.tween_property(lbl, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)
	await tween.finished
	lbl.queue_free()

func _show_miss_label(near: Sprite2D) -> void:
	var lbl := Label.new()
	lbl.text = "MISS"
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.global_position = near.global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(lbl)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	await tween.finished
	lbl.queue_free()

func _flash_icon(icon: Sprite2D) -> void:
	var orig := icon.modulate
	var tween := create_tween()
	tween.tween_property(icon, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(icon, "modulate", orig, 0.1)
	await tween.finished

func _roll(rate: int) -> bool:
	return randi() % 100 < rate
