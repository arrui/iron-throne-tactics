# Opening.gd — 序章·一开场流程 + 存档路由 + Debug 章节选择器
extends Node

const CUTSCENE_SCENE := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const BATTLE_SCENE   := "res://scenes/battle/BattleMap.tscn"

const PROLOGUE_OPENING := "res://data/cutscenes/prologue_opening.json"
const MAD_KING         := "res://data/cutscenes/prologue_mad_king.json"
const UPRISING         := "res://data/cutscenes/prologue_uprising.json"

const CHAPTER_SCENE_MAP := {
	2: "res://scenes/chapter/Ch2_Opening.tscn",
	3: "res://scenes/chapter/Ch3_Opening.tscn",
	4: "res://scenes/chapter/Ch4_Opening.tscn",
}

var _cutscene: CutscenePlayer = null

func _ready() -> void:
	# ── 设置支持中文的系统字体（STHeitiSC = macOS黑体）──
	_apply_chinese_font()

	# DEBUG 模式：显示章节选择器
	if OS.is_debug_build():
		_show_debug_menu()
		return
	_start_normal_flow()

# ── 调试章节选择器 ────────────────────────────────────────
func _show_debug_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var bg := ColorRect.new()
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	canvas.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -180.0; vbox.offset_right  = 180.0
	vbox.offset_top    = -240.0; vbox.offset_bottom = 240.0
	vbox.add_theme_constant_override("separation", 14)
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG — 选择章节"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "（仅在 DEBUG 构建中显示）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# 章节按钮数据：[显示名, 场景路径或null（null=正常流程）]
	var chapters: Array = [
		["序章·一《风暴地》  (22×16)",   null],
		["序章·二《三叉戟》  (28×20)",   "res://scenes/chapter/Ch2_Opening.tscn"],
		["序章·三《极乐塔》  (24×18)",   "res://scenes/chapter/Ch3_Opening.tscn"],
		["序章·四《铁王座》  (36×26)",   "res://scenes/chapter/Ch4_Opening.tscn"],
	]

	for entry: Array in chapters:
		var label: String = entry[0] as String
		var scene          = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(320, 48)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func() -> void:
			canvas.queue_free()
			if scene == null:
				_start_normal_flow()
			else:
				var path: String = scene as String
				if ResourceLoader.exists(path):
					get_tree().change_scene_to_file(path))
		vbox.add_child(btn)

	# 清除存档按钮
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var clear_btn := Button.new()
	clear_btn.text = "↺  清除存档（从头开始）"
	clear_btn.custom_minimum_size = Vector2(320, 38)
	clear_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	clear_btn.pressed.connect(func() -> void:
		const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
		if ResourceLoader.exists(SAVE_SYS_PATH):
			load(SAVE_SYS_PATH).delete_save()
		canvas.queue_free()
		_start_normal_flow())
	vbox.add_child(clear_btn)

# ── 正常游戏流程（检查存档 → 章节路由）────────────────────
func _start_normal_flow() -> void:
	const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
	if ResourceLoader.exists(SAVE_SYS_PATH):
		var ss := load(SAVE_SYS_PATH)
		if ss.has_save():
			var chapter: int = ss.load_current_chapter()
			if chapter > 1 and CHAPTER_SCENE_MAP.has(chapter):
				var scene_path: String = CHAPTER_SCENE_MAP[chapter] as String
				if ResourceLoader.exists(scene_path):
					get_tree().change_scene_to_file(scene_path)
					return
	_play_chapter_1()

func _play_chapter_1() -> void:
	_cutscene = CUTSCENE_SCENE.instantiate() as CutscenePlayer
	add_child(_cutscene)
	_cutscene.cutscene_finished.connect(_on_cutscene_finished)
	_seq_index = 0
	_sequence  = [PROLOGUE_OPENING, MAD_KING, UPRISING]
	_play_next()

var _sequence: Array = []
var _seq_index: int  = 0

func _play_next() -> void:
	if _seq_index >= _sequence.size():
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	_cutscene.play(_sequence[_seq_index])

func _on_cutscene_finished() -> void:
	_seq_index += 1
	await get_tree().create_timer(0.3).timeout
	_play_next()

# ── 全局字体：使用系统黑体支持中文显示 ──────────────────
func _apply_chinese_font() -> void:
	var font := SystemFont.new()
	# macOS 优先，Windows/Linux 备用
	font.font_names = PackedStringArray([
		"STHeitiSC-Medium", "STHeiti Medium",
		"PingFang SC", "Microsoft YaHei",
		"WenQuanYi Micro Hei", "Noto Sans CJK SC"
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ThemeDB.get_project_theme().set_default_font(font)
	ThemeDB.get_project_theme().set_default_font_size(14)
