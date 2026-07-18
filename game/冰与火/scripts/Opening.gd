# Opening.gd — 正式主菜单 + 序章·一开场流程 + 存档路由
extends Node

const PrologueChapterBriefs := preload("res://scripts/chapter/PrologueChapterBriefs.gd")
const CJKFontHelper := preload("res://scripts/ui/CJKFontHelper.gd")

const CUTSCENE_SCENE := preload("res://scenes/cutscene/CutscenePlayer.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/SettingsMenu.tscn")
const BATTLE_SCENE   := "res://scenes/battle/BattleMap.tscn"
const TRANSITION_PATH := "res://scenes/ui/ChapterTransition.tscn"

const PROLOGUE_OPENING := "res://data/cutscenes/prologue_opening.json"
const MAD_KING         := "res://data/cutscenes/prologue_mad_king.json"
const UPRISING         := "res://data/cutscenes/prologue_uprising.json"

const CH1_CHAPTER_NUMBER    := "序章·一"
const CH1_CHAPTER_TITLE     := "风暴地"
const CH1_CHAPTER_TIME      := "篡夺者战争 · 第一年"
const CH1_CHAPTER_SUB_LABEL := "起义开端 / 山道突破"
const CH1_CHAPTER_OBJECTIVE := PrologueChapterBriefs.CH1_OBJECTIVE_SUMMARY

const CHAPTER_SCENE_MAP := {
	2: "res://scenes/chapter/Ch2_Opening.tscn",
	3: "res://scenes/chapter/Ch3_Opening.tscn",
	4: "res://scenes/chapter/Ch4_Opening.tscn",
}

var _cutscene: CutscenePlayer = null
var _transition: Node = null

@onready var _main_menu: CanvasLayer = get_node_or_null("MainMenu") as CanvasLayer
@onready var _progress_label: Label = get_node_or_null("MainMenu/MenuPanel/MenuContent/ProgressLabel") as Label
@onready var _continue_button: Button = get_node_or_null("MainMenu/MenuPanel/MenuContent/ContinueButton") as Button
@onready var _debug_section: Control = get_node_or_null("MainMenu/MenuPanel/MenuContent/DebugSection") as Control
@onready var _new_game_confirm: ConfirmationDialog = get_node_or_null("NewGameConfirm") as ConfirmationDialog

func _ready() -> void:
	# 设置中文字体（仅在有显示器时）
	if DisplayServer.get_name() != "headless":
		_apply_chinese_font()

	_bind_main_menu()
	_refresh_main_menu()

func _bind_main_menu() -> void:
	var content := get_node_or_null("MainMenu/MenuPanel/MenuContent")
	if content == null:
		return
	(content.get_node("NewGameButton") as Button).pressed.connect(_on_new_game_pressed)
	(content.get_node("ContinueButton") as Button).pressed.connect(_on_continue_pressed)
	(content.get_node("SettingsButton") as Button).pressed.connect(_open_settings_menu)
	(content.get_node("QuitButton") as Button).pressed.connect(_on_quit_pressed)
	var debug_buttons := content.get_node("DebugSection/DebugChapters")
	for chapter in range(1, 5):
		var button := debug_buttons.get_node("DebugChapter%dButton" % chapter) as Button
		button.pressed.connect(_open_debug_chapter.bind(chapter))
	if _new_game_confirm != null:
		_new_game_confirm.confirmed.connect(_start_new_game)

func _refresh_main_menu() -> void:
	if _debug_section != null:
		_debug_section.visible = OS.is_debug_build()
	if _continue_button == null or _progress_label == null:
		return
	var has_save := SaveSystem.has_save()
	_continue_button.disabled = not has_save
	if not has_save:
		_continue_button.text = "继续游戏"
		_progress_label.text = "尚无战役记录"
		return
	var chapter := SaveSystem.load_current_chapter()
	if chapter > 4:
		_continue_button.disabled = true
		_continue_button.text = "序章已完成"
		_progress_label.text = "序章战役已完成"
		return
	_continue_button.text = "继续游戏 · %s" % _chapter_display_name(chapter)
	_progress_label.text = "当前进度：%s" % _chapter_display_name(chapter)

func _chapter_display_name(chapter: int) -> String:
	const NAMES := {1: "序章一 · 风暴地", 2: "序章二 · 三叉戟", 3: "序章三 · 极乐塔", 4: "序章四 · 铁王座"}
	return NAMES.get(chapter, NAMES[1]) as String

func _on_new_game_pressed() -> void:
	if SaveSystem.has_save() and _new_game_confirm != null:
		_show_new_game_confirm()
		return
	_start_new_game()

func _show_new_game_confirm() -> void:
	if _new_game_confirm == null:
		return
	_refresh_new_game_confirm_font()
	_new_game_confirm.popup_centered()
	call_deferred("_refresh_new_game_confirm_font")
	call_deferred("_refresh_new_game_confirm_font_after_popup")

func _start_new_game() -> void:
	SaveSystem.delete_save()
	SaveSystem.start_new_campaign()
	GameState.current_chapter = 1
	GameState.deploy_selection = []
	_hide_main_menu()
	_play_chapter_1()

func _on_continue_pressed() -> void:
	if not SaveSystem.has_save():
		return
	_continue_game()

func _continue_game() -> void:
	var chapter := SaveSystem.load_current_chapter()
	if chapter > 4:
		return
	GameState.current_chapter = chapter
	_hide_main_menu()
	if chapter <= 1 or not CHAPTER_SCENE_MAP.has(chapter):
		GameState.current_chapter = 1
		_play_chapter_1()
		return
	_change_scene(CHAPTER_SCENE_MAP[chapter] as String)

func _open_debug_chapter(chapter: int) -> void:
	GameState.current_chapter = chapter
	GameState.deploy_selection = []
	_hide_main_menu()
	if chapter == 1:
		_play_chapter_1()
	elif CHAPTER_SCENE_MAP.has(chapter):
		_change_scene(CHAPTER_SCENE_MAP[chapter] as String)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _hide_main_menu() -> void:
	if _main_menu != null:
		_main_menu.hide()

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _open_settings_menu() -> void:
	var existing := get_node_or_null("SettingsMenu")
	if existing != null:
		return
	var menu := SETTINGS_SCENE.instantiate()
	add_child(menu)

# ── 正常游戏流程（检查存档 → 章节路由）────────────────────
func _start_normal_flow() -> void:
	if SaveSystem.has_save():
		_continue_game()
	else:
		_start_new_game()

func _play_chapter_1() -> void:
	_play_ch1_title_card()

func _get_ch1_title_card_args() -> Array[String]:
	return [
		CH1_CHAPTER_NUMBER,
		CH1_CHAPTER_TITLE,
		CH1_CHAPTER_TIME,
		CH1_CHAPTER_SUB_LABEL,
		CH1_CHAPTER_OBJECTIVE,
	]

func _play_ch1_title_card() -> void:
	if ResourceLoader.exists(TRANSITION_PATH):
		_transition = load(TRANSITION_PATH).instantiate()
		add_child(_transition)
		if _transition.has_method("show_chapter"):
			var chapter_args := _get_ch1_title_card_args()
			_transition.call("show_chapter",
				chapter_args[0], chapter_args[1], chapter_args[2], chapter_args[3], chapter_args[4])
		if _transition.has_signal("transition_finished"):
			_transition.connect("transition_finished", _on_ch1_title_done)
		else:
			await get_tree().create_timer(4.0).timeout
			_on_ch1_title_done()
	else:
		_on_ch1_title_done()

func _on_ch1_title_done() -> void:
	if _transition != null:
		_transition.queue_free()
		_transition = null
	_begin_ch1_cutscene_flow()

func _begin_ch1_cutscene_flow() -> void:
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
		_change_scene(BATTLE_SCENE)
		return
	_cutscene.play(_sequence[_seq_index])

func _on_cutscene_finished() -> void:
	_seq_index += 1
	await get_tree().create_timer(0.3).timeout
	_play_next()

# ── 全局字体：使用系统黑体支持中文显示 ──────────────────
func _get_cjk_font() -> Font:
	return CJKFontHelper.get_font()

func _apply_chinese_font() -> void:
	var font := CJKFontHelper.apply_global_theme(14)
	# 主菜单场景在启动时已经完成实例化，单纯依赖 fallback_font
	# 在部分 Godot 4.6/macOS 环境下不会立刻刷新到现有控件，
	# 会导致中文显示为方框。这里递归给当前场景内文本控件显式覆写字体。
	CJKFontHelper.apply_to_node_recursive(self, font)
	call_deferred("_apply_font_to_controls", self, font)
	call_deferred("_refresh_new_game_confirm_font")

func _apply_font_to_controls(node: Node, font: Font = null) -> void:
	CJKFontHelper.apply_to_node_recursive(node, font)

func _refresh_new_game_confirm_font() -> void:
	if _new_game_confirm == null:
		return
	var font := _get_cjk_font()
	CJKFontHelper.apply_to_confirmation_dialog(_new_game_confirm, font)

func _refresh_new_game_confirm_font_after_popup() -> void:
	await get_tree().process_frame
	_refresh_new_game_confirm_font()
