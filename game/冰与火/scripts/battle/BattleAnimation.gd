# BattleAnimation.gd — FE GBA 风格战斗动画面板 v2
# 修复：动画掷骰和结算使用同一套随机数
class_name BattleAnimation
extends Control

const BattleStageArtClass := preload("res://scripts/battle/BattleStageArt.gd")

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

const ANIM_STYLE_SWORD := "sword"
const ANIM_STYLE_AXE := "axe"
const ANIM_STYLE_LANCE := "lance"

const SHOWCASE_RUBY_FORD := "ruby_ford_showcase"
const SHOWCASE_DAWN_FALL := "dawnfall_showcase"
const SHOWCASE_KINGSLAYER := "kingslayer_showcase"

const SHOWCASE_BACKDROP_COLORS := {
	SHOWCASE_RUBY_FORD: Color(0.14, 0.07, 0.08, 0.98),
	SHOWCASE_DAWN_FALL: Color(0.34, 0.20, 0.10, 0.98),
	SHOWCASE_KINGSLAYER: Color(0.10, 0.05, 0.07, 0.98),
}

const SHOWCASE_FRAME_COLORS := {
	SHOWCASE_RUBY_FORD: Color(0.86, 0.18, 0.20, 0.92),
	SHOWCASE_DAWN_FALL: Color(0.96, 0.82, 0.40, 0.92),
	SHOWCASE_KINGSLAYER: Color(0.86, 0.72, 0.26, 0.92),
}

const SHOWCASE_VS_COLORS := {
	SHOWCASE_RUBY_FORD: Color(1.00, 0.72, 0.32, 1.0),
	SHOWCASE_DAWN_FALL: Color(0.98, 0.92, 0.56, 1.0),
	SHOWCASE_KINGSLAYER: Color(1.00, 0.82, 0.36, 1.0),
}

const SHOWCASE_CRITICAL_LABELS := {
	SHOWCASE_RUBY_FORD: "碎甲重锤！",
	SHOWCASE_DAWN_FALL: "晓光折断！",
	SHOWCASE_KINGSLAYER: "弑君一击！",
}

const SHOWCASE_BADGES := {
	SHOWCASE_RUBY_FORD: "红宝石滩",
	SHOWCASE_DAWN_FALL: "黎明陨落",
	SHOWCASE_KINGSLAYER: "弑君者",
}

const SHOWCASE_SIGNATURE_COLORS := {
	SHOWCASE_RUBY_FORD: Color(1.00, 0.32, 0.22, 0.92),
	SHOWCASE_DAWN_FALL: Color(1.00, 0.94, 0.72, 0.92),
	SHOWCASE_KINGSLAYER: Color(1.00, 0.80, 0.30, 0.92),
}

const SHOWCASE_STAGE_MODES := {
	SHOWCASE_RUBY_FORD: BattleStageArtClass.MODE_RUBY_FORD,
	SHOWCASE_DAWN_FALL: BattleStageArtClass.MODE_TOWER_OF_JOY,
	SHOWCASE_KINGSLAYER: BattleStageArtClass.MODE_THRONE_ROOM,
}

@onready var _atk_icon:   Sprite2D   = $Panel/AtkSide/Icon
@onready var _atk_name:   Label      = $Panel/AtkSide/Name
@onready var _atk_hp_bar: ProgressBar = $Panel/AtkSide/HPBar
@onready var _atk_hp_lbl: Label      = $Panel/AtkSide/HPLabel

@onready var _def_icon:   Sprite2D   = $Panel/DefSide/Icon
@onready var _def_name:   Label      = $Panel/DefSide/Name
@onready var _def_hp_bar: ProgressBar = $Panel/DefSide/HPBar
@onready var _def_hp_lbl: Label      = $Panel/DefSide/HPLabel

@onready var _panel: Control = $Panel
@onready var _stage_backdrop: ColorRect = $Panel/StageBackdrop
@onready var _stage_art: BattleStageArt = $Panel/StageArt
@onready var _stage_accent: ColorRect = $Panel/StageAccent
@onready var _bg_rect: ColorRect = $Panel/BG
@onready var _border: ColorRect = $Panel/Border
@onready var _vs_label: Label = $Panel/VSLabel
@onready var _impact_flash: ColorRect = $Panel/ImpactFlash
@onready var _slash_trail: Polygon2D = $Panel/SlashTrail
@onready var _critical_label: Label = $Panel/CriticalLabel
@onready var _showcase_label: Label = $Panel/ShowcaseLabel
@onready var _signature_burst: Polygon2D = $Panel/SignatureBurst

var _panel_hidden_y: float = 0.0
var _panel_shown_y:  float = 0.0
var _playing: bool = false
var _showcase_mode: String = ""

func _ready() -> void:
	visible = false
	var vs := get_viewport_rect().size
	_panel_hidden_y = vs.y
	_panel_shown_y  = 0.0
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

func play(attacker: Unit, defender: Unit, result: Dictionary) -> void:
	if _playing:
		return
	_playing = true
	# ── 在任何await之前提取所有需要的数据 ──────────────────
	# await期间节点可能被释放，必须在此之前把数据存成局部变量
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		_playing = false
		animation_finished.emit({"atk_hit": false, "atk_damage": 0,
			"def_hit": false, "def_damage": 0, "atk_double": false,
			"double_hit": false, "double_damage": 0})
		return

	var atk_hp_now: int = attacker.data.hp
	var def_hp_now: int = defender.data.hp

	visible = true
	_setup_sides(attacker, defender)
	_showcase_mode = _resolve_showcase_mode(attacker, defender)
	_apply_showcase_presentation(_showcase_mode)
	await _slide_panel(_panel_shown_y)
	if _showcase_mode != "":
		await _play_showcase_intro(attacker, defender)

	# 战斗地图已统一生成结果，动画只负责表现，开关不会改变随机结算。
	var atk_hit: bool = result.get("atk_hit", false)
	var atk_crit: bool = result.get("atk_crit", false)
	var atk_dmg: int = result.get("atk_damage", 0)
	var atk_profile := _animation_profile(_animation_style_for_unit(attacker))

	var def_hp_after_atk: int = maxi(def_hp_now - atk_dmg, 0)

	var def_hit: bool = result.get("def_hit", false)
	var def_crit: bool = result.get("def_crit", false)
	var def_dmg: int = result.get("def_damage", 0)
	var def_profile := _animation_profile(_animation_style_for_unit(defender))
	var atk_double_hit: bool = result.get("double_hit", false)
	var atk_double_crit: bool = result.get("double_crit", false)
	var atk_double_dmg: int = result.get("double_damage", 0)

	# ── 播放动画（使用本地变量，不再访问节点data）──
	await _do_attack_anim(_atk_icon, _def_icon, _def_hp_bar, _def_hp_lbl,
		atk_hit, atk_dmg, atk_crit, false, def_hp_now, atk_profile)
	await get_tree().create_timer(ROUND_GAP).timeout

	if def_hp_after_atk > 0:
		await _do_attack_anim(_def_icon, _atk_icon, _atk_hp_bar, _atk_hp_lbl,
			def_hit, def_dmg, def_crit, true, atk_hp_now, def_profile)
		await get_tree().create_timer(ROUND_GAP).timeout

	if result.get("atk_double", false) and def_hp_after_atk > 0:
		await _do_attack_anim(_atk_icon, _def_icon, _def_hp_bar, _def_hp_lbl,
			atk_double_hit, atk_double_dmg, atk_double_crit, false, def_hp_after_atk, atk_profile)
		await get_tree().create_timer(ROUND_GAP).timeout

	await _slide_panel(_panel_hidden_y)
	visible = false
	_showcase_mode = ""

	_playing = false
	animation_finished.emit(result)

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
			var tex := _load_portrait_texture(path)
			if tex != null:
				icon.texture        = tex
				icon.region_enabled = true
				icon.region_rect    = Rect2(0, 0, tex.get_width(), tex.get_height())
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

func _resolve_showcase_mode(attacker: Unit, defender: Unit) -> String:
	var atk_id := _unit_source_id(attacker)
	var def_id := _unit_source_id(defender)
	if _pair_matches(atk_id, def_id, "robert_baratheon.json", "rhaegar_targaryen.json"):
		return SHOWCASE_RUBY_FORD
	if _pair_matches(atk_id, def_id, "arthur_dayne.json", "howland_reed.json") \
			or _pair_matches(atk_id, def_id, "arthur_dayne.json", "ned_stark.json"):
		return SHOWCASE_DAWN_FALL
	if _pair_matches(atk_id, def_id, "jaime_lannister", "royal_guard_captain.json") \
			or _pair_matches(atk_id, def_id, "jaime_lannister", "royal_soldier.json"):
		return SHOWCASE_KINGSLAYER
	return ""

func _unit_source_id(unit: Unit) -> String:
	if unit == null or unit.data == null:
		return ""
	if unit.data.source_id != "":
		return unit.data.source_id
	return str(unit.get_meta("source_id", ""))

func _pair_matches(a: String, b: String, left: String, right: String) -> bool:
	return (a == left and b == right) or (a == right and b == left)

func _apply_showcase_presentation(mode: String) -> void:
	_showcase_mode = mode
	if _stage_backdrop:
		_stage_backdrop.color = SHOWCASE_BACKDROP_COLORS.get(mode, Color(0.035, 0.055, 0.08, 0.98))
	if _bg_rect:
		_bg_rect.color = _showcase_bg_color(mode)
	if _stage_art:
		_stage_art.stage_mode = SHOWCASE_STAGE_MODES.get(mode, "")
		_stage_art.accent_color = _stage_art_accent(mode)
		_stage_art.reset_state()
	if _stage_accent:
		_stage_accent.visible = mode != ""
		_stage_accent.color = Color(1, 1, 1, 0)
	if _border:
		_border.color = SHOWCASE_FRAME_COLORS.get(mode, Color(0.4, 0.6, 1.0, 0.8))
	if _vs_label:
		_vs_label.text = SHOWCASE_BADGES.get(mode, "VS")
		_vs_label.add_theme_color_override("font_color",
			SHOWCASE_VS_COLORS.get(mode, Color(1.0, 0.65, 0.1, 1.0)))
		_vs_label.add_theme_font_size_override("font_size", 24 if mode != "" else 32)
	if _critical_label:
		_critical_label.text = SHOWCASE_CRITICAL_LABELS.get(mode, "必杀！")
	if _showcase_label:
		_showcase_label.text = SHOWCASE_BADGES.get(mode, "")
		_showcase_label.visible = false
		_showcase_label.modulate.a = 0.0
	if _signature_burst:
		_signature_burst.visible = false
		_signature_burst.modulate.a = 0.0
		_signature_burst.polygon = _signature_polygon_for_showcase(mode)
		_signature_burst.color = SHOWCASE_SIGNATURE_COLORS.get(mode, Color(1.0, 0.8, 0.3, 0.0))

func _showcase_bg_color(mode: String) -> Color:
	match mode:
		SHOWCASE_RUBY_FORD:
			return Color(0.24, 0.10, 0.12, 0.78)
		SHOWCASE_DAWN_FALL:
			return Color(0.36, 0.24, 0.12, 0.76)
		SHOWCASE_KINGSLAYER:
			return Color(0.18, 0.08, 0.10, 0.78)
		_:
			return Color(0.10, 0.12, 0.16, 0.72)

func _stage_art_accent(mode: String) -> Color:
	match mode:
		SHOWCASE_RUBY_FORD:
			return Color(0.92, 0.18, 0.16, 0.08)
		SHOWCASE_DAWN_FALL:
			return Color(1.00, 0.92, 0.68, 0.07)
		SHOWCASE_KINGSLAYER:
			return Color(0.90, 0.24, 0.18, 0.06)
		_:
			return Color(1.0, 1.0, 1.0, 0.0)

func _signature_polygon_for_showcase(mode: String) -> PackedVector2Array:
	match mode:
		SHOWCASE_RUBY_FORD:
			return PackedVector2Array([
				Vector2(-92.0, 6.0), Vector2(-16.0, -34.0), Vector2(16.0, -14.0),
				Vector2(92.0, 2.0), Vector2(16.0, 18.0), Vector2(-8.0, 42.0),
			])
		SHOWCASE_DAWN_FALL:
			return PackedVector2Array([
				Vector2(-12.0, 58.0), Vector2(0.0, -72.0), Vector2(14.0, 54.0),
				Vector2(44.0, -4.0), Vector2(0.0, -32.0), Vector2(-42.0, -2.0),
			])
		SHOWCASE_KINGSLAYER:
			return PackedVector2Array([
				Vector2(-82.0, -8.0), Vector2(-10.0, -22.0), Vector2(6.0, -72.0),
				Vector2(20.0, -16.0), Vector2(84.0, 0.0), Vector2(18.0, 14.0),
				Vector2(4.0, 72.0), Vector2(-8.0, 18.0),
			])
		_:
			return PackedVector2Array([
				Vector2(-48.0, -10.0), Vector2(0.0, -40.0), Vector2(52.0, -8.0),
				Vector2(16.0, 6.0), Vector2(60.0, 34.0), Vector2(0.0, 18.0),
				Vector2(-56.0, 30.0), Vector2(-18.0, 4.0),
			])

func _load_portrait_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

func _animation_style_for_unit(unit: Unit) -> String:
	if unit == null or unit.data == null:
		return ANIM_STYLE_SWORD
	return _animation_style_from_data(unit.data.weapon_type, unit.data.animation_family)

func _animation_style_from_data(weapon_type: String, animation_family: String = "") -> String:
	var family := animation_family.to_lower()
	if family.contains("axe"):
		return ANIM_STYLE_AXE
	if family.contains("spear") or family.contains("lance"):
		return ANIM_STYLE_LANCE
	match weapon_type:
		"axe":
			return ANIM_STYLE_AXE
		"lance":
			return ANIM_STYLE_LANCE
		_:
			return ANIM_STYLE_SWORD

func _trail_polygon_for_style(style: String) -> PackedVector2Array:
	match style:
		ANIM_STYLE_AXE:
			return PackedVector2Array([
				-52.0, 34.0,
				-18.0, -38.0,
				26.0, -54.0,
				92.0, -6.0,
				36.0, 48.0,
			])
		ANIM_STYLE_LANCE:
			return PackedVector2Array([
				-112.0, -6.0,
				72.0, -6.0,
				110.0, 0.0,
				72.0, 6.0,
				-112.0, 6.0,
			])
		_:
			return PackedVector2Array([
				-72.0, 8.0,
				58.0, -18.0,
				76.0, -6.0,
				-58.0, 20.0,
			])

func _animation_profile(style: String) -> Dictionary:
	match style:
		ANIM_STYLE_AXE:
			return {
				"style": ANIM_STYLE_AXE,
				"windup_back": 20.0,
				"windup_y": -18.0,
				"windup_duration": 0.08,
				"charge_duration": 0.18,
				"return_duration": 0.24,
				"charge_offset": 70.0,
				"impact_alpha": 0.62,
				"impact_color": Color(1.00, 0.78, 0.48, 0.62),
				"trail_color": Color(1.00, 0.66, 0.18, 0.94),
				"trail_base_rotation": 0.56,
				"trail_start_scale": Vector2(0.22, 0.22),
				"trail_target_scale": Vector2(1.58, 1.58),
				"panel_kick": 18.0,
				"dodge_lift": 34.0,
				"shake_pattern": [-14.0, 18.0, -10.0, 6.0, 0.0],
				"defender_push": 8.0,
				"backdrop_impact_color": Color(0.08, 0.05, 0.04, 0.98),
			}
		ANIM_STYLE_LANCE:
			return {
				"style": ANIM_STYLE_LANCE,
				"windup_back": 12.0,
				"windup_y": 0.0,
				"windup_duration": 0.05,
				"charge_duration": 0.10,
				"return_duration": 0.16,
				"charge_offset": 116.0,
				"impact_alpha": 0.34,
				"impact_color": Color(0.82, 0.92, 1.00, 0.34),
				"trail_color": Color(0.82, 0.92, 1.00, 0.92),
				"trail_base_rotation": 0.02,
				"trail_start_scale": Vector2(0.18, 0.18),
				"trail_target_scale": Vector2(1.72, 1.05),
				"panel_kick": 8.0,
				"dodge_lift": 44.0,
				"shake_pattern": [-4.0, 8.0, -3.0, 0.0],
				"defender_push": 14.0,
				"backdrop_impact_color": Color(0.03, 0.07, 0.10, 0.98),
			}
		_:
			return {
				"style": ANIM_STYLE_SWORD,
				"windup_back": 10.0,
				"windup_y": -6.0,
				"windup_duration": 0.05,
				"charge_duration": 0.12,
				"return_duration": 0.18,
				"charge_offset": 82.0,
				"impact_alpha": 0.46,
				"impact_color": Color(1.00, 0.92, 0.62, 0.46),
				"trail_color": Color(1.00, 0.90, 0.42, 0.92),
				"trail_base_rotation": -0.20,
				"trail_start_scale": Vector2(0.25, 0.25),
				"trail_target_scale": Vector2(1.35, 1.35),
				"panel_kick": 12.0,
				"dodge_lift": 38.0,
				"shake_pattern": [-8.0, 10.0, -6.0, 4.0, 0.0],
				"defender_push": 4.0,
				"backdrop_impact_color": Color(0.05, 0.05, 0.08, 0.98),
			}

func _profile_with_showcase_modifiers(profile: Dictionary, critical: bool) -> Dictionary:
	var modded := profile.duplicate(true)
	match _showcase_mode:
		SHOWCASE_RUBY_FORD:
			modded["charge_offset"] = float(modded.get("charge_offset", CHARGE_OFFSET)) + 16.0
			modded["panel_kick"] = float(modded.get("panel_kick", 12.0)) + 8.0
			modded["impact_color"] = Color(1.00, 0.46, 0.22, 0.66 if critical else 0.54)
			modded["trail_color"] = Color(1.00, 0.70, 0.24, 0.96)
			modded["backdrop_impact_color"] = Color(0.18, 0.05, 0.05, 0.98)
		SHOWCASE_DAWN_FALL:
			modded["windup_duration"] = float(modded.get("windup_duration", 0.05)) * 0.85
			modded["charge_duration"] = float(modded.get("charge_duration", CHARGE_DURATION)) * 0.88
			modded["trail_color"] = Color(1.00, 0.98, 0.78, 0.96)
			modded["impact_color"] = Color(1.00, 0.94, 0.62, 0.58 if critical else 0.44)
			modded["dodge_lift"] = float(modded.get("dodge_lift", 38.0)) + 8.0
			modded["backdrop_impact_color"] = Color(0.16, 0.10, 0.04, 0.98)
		SHOWCASE_KINGSLAYER:
			modded["impact_color"] = Color(0.98, 0.26, 0.26, 0.62 if critical else 0.50)
			modded["trail_color"] = Color(1.00, 0.84, 0.36, 0.94)
			modded["panel_kick"] = float(modded.get("panel_kick", 12.0)) + 4.0
			modded["backdrop_impact_color"] = Color(0.12, 0.03, 0.06, 0.98)
	return modded

func _play_showcase_intro(attacker: Unit, defender: Unit) -> void:
	if _showcase_mode == "":
		return
	if _showcase_label:
		_showcase_label.visible = true
		_showcase_label.modulate.a = 0.0
	if _signature_burst:
		_signature_burst.visible = true
		_signature_burst.modulate.a = 0.0
		_signature_burst.scale = Vector2(0.4, 0.4)
		_signature_burst.position = _showcase_burst_center(attacker, defender)
	if _stage_accent:
		_stage_accent.visible = true
		_stage_accent.color = SHOWCASE_SIGNATURE_COLORS.get(_showcase_mode, Color(1, 1, 1, 0))
		_stage_accent.color.a = 0.0
	var tween := create_tween().set_parallel(true)
	if _showcase_label:
		tween.tween_property(_showcase_label, "modulate:a", 1.0, 0.12)
	if _signature_burst:
		tween.tween_property(_signature_burst, "modulate:a", 0.92, 0.08)
		tween.tween_property(_signature_burst, "scale", Vector2(1.18, 1.18), 0.12)
	if _stage_accent:
		tween.tween_property(_stage_accent, "color:a", 0.14, 0.08)
	await tween.finished
	await get_tree().create_timer(0.08).timeout
	var outro := create_tween().set_parallel(true)
	if _showcase_label:
		outro.tween_property(_showcase_label, "modulate:a", 0.0, 0.18)
	if _signature_burst:
		outro.tween_property(_signature_burst, "modulate:a", 0.0, 0.16)
		outro.tween_property(_signature_burst, "scale", Vector2(1.5, 1.5), 0.18)
	if _stage_accent:
		outro.tween_property(_stage_accent, "color:a", 0.0, 0.16)
	await outro.finished
	if _showcase_label:
		_showcase_label.visible = false
	if _signature_burst:
		_signature_burst.visible = false

func _showcase_burst_center(attacker: Unit, defender: Unit) -> Vector2:
	var atk_icon := _atk_icon
	var def_icon := _def_icon
	if _showcase_mode == SHOWCASE_KINGSLAYER:
		return _slash_center(atk_icon, def_icon) + Vector2(48.0, -24.0)
	if _showcase_mode == SHOWCASE_DAWN_FALL:
		return _slash_center(atk_icon, def_icon) + Vector2(0.0, -16.0)
	return _slash_center(atk_icon, def_icon)

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
		is_counter: bool, def_hp_before: int,
		attack_profile: Dictionary) -> void:

	if atk_icon == null or def_icon == null:
		return

	var dir := 1.0 if not is_counter else -1.0
	var origin := atk_icon.position
	var def_origin := def_icon.position
	if crit:
		await _play_critical_intro(atk_icon)
	var staged_profile := _profile_with_showcase_modifiers(attack_profile, crit)
	if _showcase_mode != "":
		await _play_signature_strike(atk_icon, def_icon, dir, crit, staged_profile)
	await _play_attack_windup(atk_icon, dir, staged_profile, origin)

	# 快冲：加速冲向目标
	var tween_charge := create_tween()
	tween_charge.tween_property(atk_icon, "position",
		origin + Vector2(float(staged_profile.get("charge_offset", CHARGE_OFFSET)) * dir, 0.0),
		float(staged_profile.get("charge_duration", CHARGE_DURATION)))\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween_charge.finished

	if hit:
		await _play_impact(atk_icon, def_icon, dir, crit, staged_profile)
		# 受击方抖动
		await _shake_icon(def_icon, dir, staged_profile)
		# 更新HP条
		var new_hp := maxi(def_hp_before - damage, 0)
		await _update_hp_bar(def_hp_bar, def_hp_lbl, def_hp_before, new_hp, def_hp_bar.max_value as int)
		# 伤害数字
		_spawn_damage_label(def_icon, damage, crit)
	else:
		var dodge := create_tween()
		dodge.tween_property(def_icon, "position:y",
			def_origin.y - float(staged_profile.get("dodge_lift", 38.0)), 0.09)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		dodge.tween_property(def_icon, "position", def_origin, 0.16)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await dodge.finished
		_spawn_miss_label(def_icon)

	await get_tree().create_timer(HIT_PAUSE).timeout

	# 慢退：减速回到原位
	var tween_back := create_tween()
	tween_back.tween_property(atk_icon, "position", origin,
		float(staged_profile.get("return_duration", RETURN_DURATION)))\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween_back.finished

func _play_attack_windup(icon: Sprite2D, dir: float, attack_profile: Dictionary, origin: Vector2) -> void:
	var windup_back := float(attack_profile.get("windup_back", 0.0))
	var windup_y := float(attack_profile.get("windup_y", 0.0))
	if is_zero_approx(windup_back) and is_zero_approx(windup_y):
		return
	var tween := create_tween()
	tween.tween_property(icon, "position",
		origin + Vector2(-windup_back * dir, windup_y),
		float(attack_profile.get("windup_duration", 0.05)))\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished

func _play_critical_intro(icon: Sprite2D) -> void:
	_critical_label.visible = true
	_critical_label.modulate.a = 0.0
	_stage_backdrop.color = Color(0.015, 0.012, 0.025, 1.0)
	var original_scale := icon.scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_critical_label, "modulate:a", 1.0, 0.08)
	tween.tween_property(icon, "scale", original_scale * 1.18, 0.12)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	await get_tree().create_timer(0.12).timeout
	icon.scale = original_scale
	_critical_label.visible = false
	_stage_backdrop.color = Color(0.035, 0.055, 0.08, 0.98)

func _play_impact(attacker: Sprite2D, defender: Sprite2D, dir: float, critical: bool,
		attack_profile: Dictionary) -> void:
	var style := str(attack_profile.get("style", ANIM_STYLE_SWORD))
	_slash_trail.position = _slash_center(attacker, defender)
	_slash_trail.polygon = _trail_polygon_for_style(style)
	_slash_trail.color = attack_profile.get("trail_color", Color(1, 0.9, 0.42, 0.92))
	_slash_trail.rotation = float(attack_profile.get("trail_base_rotation", -0.2)) * dir
	_slash_trail.scale = attack_profile.get("trail_start_scale", Vector2(0.25, 0.25))
	_slash_trail.modulate.a = 1.0
	_slash_trail.visible = true
	_impact_flash.visible = true
	var impact_color := attack_profile.get("impact_color", Color(1.0, 0.92, 0.62, 0.46)) as Color
	impact_color.a = minf(0.78, impact_color.a + (0.14 if critical else 0.0))
	_impact_flash.color = impact_color
	var base_backdrop := _stage_backdrop.color
	_stage_backdrop.color = attack_profile.get("backdrop_impact_color", base_backdrop)
	var panel_kick := float(attack_profile.get("panel_kick", 12.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_slash_trail, "scale",
		attack_profile.get("trail_target_scale", Vector2(1.35, 1.35)), 0.09)
	tween.tween_property(_slash_trail, "modulate:a", 0.0, 0.14)
	tween.tween_property(_impact_flash, "color:a", 0.0, 0.12)
	tween.tween_property(_stage_backdrop, "color", base_backdrop, 0.16)
	tween.tween_property(_panel, "position:x", panel_kick * dir, 0.04)
	tween.chain().tween_property(_panel, "position:x", 0.0, 0.06)
	await tween.finished
	_slash_trail.visible = false
	_impact_flash.visible = false

func _play_signature_strike(attacker: Sprite2D, defender: Sprite2D, dir: float,
		critical: bool, attack_profile: Dictionary) -> void:
	if _signature_burst == null or _showcase_mode == "":
		return
	_signature_burst.visible = true
	_signature_burst.position = _slash_center(attacker, defender)
	_signature_burst.rotation = _signature_rotation(dir)
	_signature_burst.scale = _signature_scale()
	var burst_color: Color = SHOWCASE_SIGNATURE_COLORS.get(_showcase_mode, Color(1.0, 0.8, 0.3, 0.92))
	burst_color.a = 1.0 if critical else 0.88
	_signature_burst.color = burst_color
	_signature_burst.modulate.a = 0.0
	if _stage_accent:
		_stage_accent.visible = true
		_stage_accent.color = burst_color
		_stage_accent.color.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_signature_burst, "modulate:a", 1.0, 0.04)
	tween.tween_property(_signature_burst, "scale", _signature_scale() * 1.22, 0.07)
	if _stage_accent:
		tween.tween_property(_stage_accent, "color:a", 0.20 if critical else 0.12, 0.04)
	await tween.finished
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_signature_burst, "modulate:a", 0.0, 0.12)
	fade.tween_property(_signature_burst, "scale", _signature_scale() * 1.42, 0.12)
	if _stage_accent:
		fade.tween_property(_stage_accent, "color:a", 0.0, 0.10)
	await fade.finished
	_signature_burst.visible = false

func _signature_scale() -> Vector2:
	match _showcase_mode:
		SHOWCASE_RUBY_FORD:
			return Vector2(1.3, 0.95)
		SHOWCASE_DAWN_FALL:
			return Vector2(0.92, 1.35)
		SHOWCASE_KINGSLAYER:
			return Vector2(1.08, 1.08)
		_:
			return Vector2.ONE

func _signature_rotation(dir: float) -> float:
	match _showcase_mode:
		SHOWCASE_RUBY_FORD:
			return 0.08 * dir
		SHOWCASE_DAWN_FALL:
			return -0.24 * dir
		SHOWCASE_KINGSLAYER:
			return -0.78 * dir
		_:
			return 0.0

func _slash_center(attacker: Sprite2D, defender: Sprite2D) -> Vector2:
	return (attacker.global_position + defender.global_position) * 0.5 - _panel.global_position

# ── 受击抖动（左右快速震动）──────────────────────────────
func _shake_icon(icon: Sprite2D, dir: float, attack_profile: Dictionary) -> void:
	var orig := icon.position
	var tween := create_tween()
	var push := float(attack_profile.get("defender_push", 0.0))
	if not is_zero_approx(push):
		tween.tween_property(icon, "position:x", orig.x + push * dir, 0.03)
	var pattern: Array = attack_profile.get("shake_pattern", [-8.0, 10.0, -6.0, 4.0, 0.0])
	for offset_v: Variant in pattern:
		tween.tween_property(icon, "position:x", orig.x + float(offset_v) * dir, 0.03)
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
