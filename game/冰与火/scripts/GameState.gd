# GameState.gd — 全局游戏状态（静态类，无节点）
class_name GameState

# 当前章节（1-4），由各章节 Opening 脚本设置，BattleBootstrap 读取分发
static var current_chapter: int = 1

# Ch4 部署选择（由 DeployScreen_Ch4 写入，BattleBootstrap_Ch4 读取）
static var deploy_selection: Array[String] = []
