# UnitData.gd
# 单位数据结构定义，从JSON加载后填充此类
class_name UnitData

var name: String
var unit_class: String
var level: int
var hp: int
var max_hp: int
var pow: int   # 武力
var spd: int   # 身法
var skl: int   # 武艺
var def: int   # 坚守
var lck: int   # 命运
var con: int   # 体魄
var move: int  # 移动力
var weapon_type: String
var weapon_rank: String

static func from_dict(d: Dictionary) -> UnitData:
	var data := UnitData.new()
	data.name        = d.get("name", "未知")
	data.unit_class  = d.get("class", "步兵")
	data.level       = d.get("level", 1)
	data.max_hp      = d.get("max_hp", 20)
	data.hp          = d.get("hp", data.max_hp)
	data.pow         = d.get("pow", 5)
	data.spd         = d.get("spd", 5)
	data.skl         = d.get("skl", 5)
	data.def         = d.get("def", 5)
	data.lck         = d.get("lck", 3)
	data.con         = d.get("con", 7)
	data.move        = d.get("move", 5)
	data.weapon_type = d.get("weapon_type", "sword")
	data.weapon_rank = d.get("weapon_rank", "E")
	return data
