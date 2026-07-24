# GameState.gd — 全局游戏状态（静态类，无节点）
class_name GameState

# 幕+章双字段。act=0 序章，act=1 第一幕(罗柏)...
static var act: int = 0
static var chapter: int = 1

# 序章兼容别名：序章代码读 current_chapter 不变；正篇返回 -1。
static var current_chapter: int = 1

static func set_prologue(chapter: int) -> void:
	act = 0
	GameState.chapter = chapter
	current_chapter = chapter

static func set_act(a: int, c: int) -> void:
	act = a
	chapter = c
	current_chapter = -1 if a != 0 else c

static func global_chapter_id() -> String:
	if act == 0:
		return "prologue.%d" % chapter
	return "act%d.%d" % [act, chapter]

# Ch4 部署选择（由 DeployScreen_Ch4 写入，BattleBootstrap_Ch4 读取）
static var deploy_selection: Array[String] = []
