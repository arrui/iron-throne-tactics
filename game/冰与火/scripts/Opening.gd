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
	# 设置中文字体（仅在有显示器时）
	if DisplayServer.get_name() != "headless":
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

	var _font := _get_cjk_font()

	var title := Label.new()
	title.text = "DEBUG — 选择章节"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_override("font", _font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "（仅在 DEBUG 构建中显示）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_override("font", _font)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# 章节按钮数据：[显示名, chapter_num]
	# chapter_num=1 → 直接启动ch1流程（不走存档路由）
	# chapter_num=2/3/4 → 跳转对应 Opening 场景
	var chapters: Array = [
		["序章·一《风暴地》  (10×8)",    1],
		["序章·二《三叉戟》  (28×20)",   2],
		["序章·三《极乐塔》  (24×18)",   3],
		["序章·四《铁王座》  (36×26)",   4],
	]
	var chapter_scene_map := {
		2: "res://scenes/chapter/Ch2_Opening.tscn",
		3: "res://scenes/chapter/Ch3_Opening.tscn",
		4: "res://scenes/chapter/Ch4_Opening.tscn",
	}

	for entry: Array in chapters:
		var label:   String = entry[0] as String
		var ch_num:  int    = entry[1] as int
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(320, 48)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_font_override("font", _font)
		btn.pressed.connect(func() -> void:
			canvas.queue_free()
			GameState.current_chapter = ch_num   # ← 必须先设置，BattleBootstrap 靠此分发
			if ch_num == 1:
				# 序章一：直接进入战斗场景，不走存档路由
				_play_chapter_1()
			else:
				var path: String = chapter_scene_map.get(ch_num, "") as String
				if path != "" and ResourceLoader.exists(path):
					get_tree().change_scene_to_file(path)
		)
		vbox.add_child(btn)

	# 清除存档按钮
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var clear_btn := Button.new()
	clear_btn.text = "↺  清除存档（从头开始）"
	clear_btn.custom_minimum_size = Vector2(320, 38)
	clear_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	clear_btn.add_theme_font_override("font", _font)
	clear_btn.pressed.connect(func() -> void:
		const SAVE_SYS_PATH := "res://scripts/systems/SaveSystem.gd"
		if ResourceLoader.exists(SAVE_SYS_PATH):
			load(SAVE_SYS_PATH).delete_save()
		canvas.queue_free()
		_start_normal_flow()
	)
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
func _get_cjk_font() -> Font:
	# 方案一：加载项目内置 Arial Unicode 字体（最可靠）
	const BUNDLED_FONT := "res://assets/fonts/ArialUnicode.ttf"
	if ResourceLoader.exists(BUNDLED_FONT):
		var ff := load(BUNDLED_FONT) as Font
		if ff != null:
			return ff
	# 方案二：直接加载系统字体文件（优先 .ttf 格式）
	var os_font_paths := [
		"/System/Library/Fonts/Supplemental/Arial Unicode.ttf",  # macOS，含全套CJK
		"/Library/Fonts/Arial Unicode.ttf",           # macOS 备选路径
		"/System/Library/Fonts/STHeiti Medium.ttc",   # macOS 简体中文黑体
		"/System/Library/Fonts/Hiragino Sans GB.ttc", # macOS 备选
		"C:/Windows/Fonts/msyh.ttc",                  # Windows 微软雅黑
		"C:/Windows/Fonts/simhei.ttf",                # Windows 黑体
		"/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",  # Linux
	]
	for path in os_font_paths:
		if FileAccess.file_exists(path):
			var ff := load(path) as Font
			if ff != null:
				return ff
	# 方案二：使用 SystemFont（名称匹配）
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Heiti SC",          # macOS 简体中文黑体
		"Hiragino Sans GB",  # macOS 备选
		"Arial Unicode MS",  # 通用 Unicode
		"Microsoft YaHei",   # Windows 微软雅黑
		"PingFang SC",       # macOS 苹方
		"STHeitiSC-Medium",  # macOS PostScript 名
		"WenQuanYi Micro Hei", # Linux
		"Noto Sans CJK SC",  # Linux/Android
	])
	return sf

func _apply_chinese_font() -> void:
	var font := _get_cjk_font()
	# 设置项目主题默认字体
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font = font
		theme.default_font_size = 14
	# 同时设置全局回退字体（确保即使没有项目主题也能显示中文）
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 14
