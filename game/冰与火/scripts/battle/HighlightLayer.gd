# HighlightLayer.gd — 专用高亮绘制层
# 位于 TileLayer 之后、UnitLayer 之前，确保高亮显示在地形之上、单位之下
extends Node2D

func _draw() -> void:
	var bm: BattleMap = get_parent() as BattleMap
	if bm:
		bm._draw_highlights(self)
