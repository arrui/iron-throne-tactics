# UnitData.gd — 单位数据结构（支持武器耐久、道具栏、Boss底板、主角标记）
class_name UnitData

const ClassCatalog := preload("res://scripts/data/ClassCatalog.gd")

var name: String
var unit_class: String
var class_id: String
var level: int
var hp: int
var max_hp: int
var pow: int    # 武力
var spd: int    # 身法
var skl: int    # 武艺
var def: int    # 坚守
var lck: int    # 命运
var con: int    # 体魄
var move: int   # 移动力
var weapon_type: String
var weapon_rank: String
var move_type: String = "foot"
var armor_type: String = "medium"
var animation_family: String = ""
var trait_key: String = ""
var trait_name: String = ""
var trait_desc: String = ""
var source_id: String = ""

# ── 武器耐久（-1 = 无限）────────────────────────────────
var weapon_uses:     int = -1
var weapon_max_uses: int = -1

# ── 道具栏（格式：[{"name": "急救药", "type": "heal", "heal_amount": 10, "uses": 3}]）
var items: Array = []

# ── 特殊标记 ──────────────────────────────────────────────
var is_protagonist: bool = false   # true → 死亡触发 Game Over
var is_boss:        bool = false   # true → Boss 专属演出
var min_hp:         int  = 0       # HP 底板（无法降到此值以下；Boss无敌用）

# ── 守卫型Boss专属（配合EnemyAI守卫逻辑）────────────────
var guard_pos_x:  int = -1   # 守卫中心X（-1=不启用）
var guard_pos_y:  int = -1   # 守卫中心Y
var guard_range:  int = 3    # 守卫半径（格数）

# ── 武器有效性 ────────────────────────────────────────────
func is_weapon_broken() -> bool:
	return weapon_uses == 0

func use_weapon_once() -> void:
	if weapon_uses > 0:
		weapon_uses -= 1

# ── 当前武器 key（供 BattleCalculator 使用）──────────────
func get_weapon_key() -> String:
	if is_weapon_broken():
		return "fist"  # 徒手（破损武器后备）
	return weapon_type + "_" + weapon_rank

# ── 道具操作 ──────────────────────────────────────────────
func has_usable_items() -> bool:
	for item: Variant in items:
		if (item as Dictionary).get("uses", 0) > 0:
			return true
	return false

func use_item(idx: int) -> Dictionary:
	if idx < 0 or idx >= items.size(): return {}
	var item: Dictionary = items[idx] as Dictionary
	if item.get("uses", 0) <= 0: return {}
	item["uses"] = int(item["uses"]) - 1
	if int(item["uses"]) <= 0:
		items.remove_at(idx)
	return item

# ── 工厂方法 ──────────────────────────────────────────────
static func from_dict(d: Dictionary, source_id: String = "") -> UnitData:
	var data := UnitData.new()
	var resolved_source := source_id if source_id != "" else str(d.get("source_id", ""))
	var defaults := ClassCatalog.get_unit_defaults(resolved_source, d)
	data.name        = d.get("name",        "未知")
	data.unit_class  = d.get("class",       "步兵")
	data.class_id    = d.get("class_id",    str(defaults.get("class_id", "lord_blade")))
	data.level       = d.get("level",       1)
	data.max_hp      = d.get("max_hp",      20)
	data.hp          = d.get("hp",          data.max_hp)
	data.pow         = d.get("pow",         5)
	data.spd         = d.get("spd",         5)
	data.skl         = d.get("skl",         5)
	data.def         = d.get("def",         5)
	data.lck         = d.get("lck",         3)
	data.con         = d.get("con",         7)
	data.move        = d.get("move",        5)
	data.weapon_type = d.get("weapon_type", "sword")
	data.weapon_rank = d.get("weapon_rank", "E")
	data.move_type = d.get("move_type", str(defaults.get("move_type", "foot")))
	data.armor_type = d.get("armor_type", str(defaults.get("armor_type", "medium")))
	data.animation_family = d.get(
		"animation_family",
		str(defaults.get("animation_family", data.class_id))
	)
	data.trait_key = d.get("trait_key", str(defaults.get("trait_key", "")))
	data.trait_name = d.get("trait_name", str(defaults.get("trait_name", "")))
	data.trait_desc = d.get("trait_desc", str(defaults.get("trait_desc", "")))
	data.source_id = resolved_source
	data.weapon_uses     = d.get("weapon_uses",     -1)
	data.weapon_max_uses = d.get("weapon_max_uses", -1)
	data.is_protagonist  = d.get("is_protagonist",  false)
	data.is_boss         = d.get("is_boss",         false)
	data.min_hp          = d.get("min_hp",          0)
	data.guard_pos_x     = d.get("guard_pos_x",     -1)
	data.guard_pos_y     = d.get("guard_pos_y",     -1)
	data.guard_range     = d.get("guard_range",     3)
	data.items           = d.get("items",           []).duplicate(true)
	return data
