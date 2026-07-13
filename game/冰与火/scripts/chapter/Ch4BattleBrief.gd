extends RefCounted

const CHAPTER_PREMISE := "君临已乱，兰尼斯特军（金色）暂持观望。你必须带着北境骑士穿过黑水桥、城墙与红堡中轴，尽快斩断残余王军指挥链。"
const OBJECTIVE_SUMMARY := "目标：沿中轴攻入红堡，击败王军指挥官后迫使兰军归降。"
const BATTLE_OBJECTIVE := "沿中轴攻入红堡，击败★王军指挥官；兰尼斯特军（金色）暂持观望态度。"
const FACTION_SUMMARY := "态势：兰军当前中立，不会主动支援你；王军指挥官一倒，金袍与兰军将放弃抵抗。"
const DEPLOY_SUMMARY := "编组：奈德固定出战，最多再带 4 名北境骑士。建议尽量带满，以降低攻城轴线断裂风险。"
const DEPLOY_ADVICE := "建议：前锋尽快过黑水桥，中轴直取南城门；两翼负责护桥与补位，别在兰军观望阵线前白白耗回合。"

const STAGE_1_TITLE := "第一段：黑水桥"
const STAGE_2_TITLE := "第二段：南城墙"
const STAGE_3_TITLE := "第三段：中央大道"
const STAGE_4_TITLE := "第四段：红堡内院"

const STAGE_1_DESC := "先夺桥头，保证中轴能完整越河。"
const STAGE_2_DESC := "穿过城门缺口，避免在墙外被拖成消耗战。"
const STAGE_3_DESC := "保持中轴推进，两翼负责护侧与补位。"
const STAGE_4_DESC := "击破王军指挥官后，兰军与金袍会放弃抵抗。"

const STAGE_TITLES := [
	STAGE_1_TITLE,
	STAGE_2_TITLE,
	STAGE_3_TITLE,
	STAGE_4_TITLE,
]

const STAGE_1_GUIDANCE := STAGE_1_TITLE + "——" + STAGE_1_DESC
const STAGE_2_GUIDANCE := STAGE_2_TITLE + "——穿过城门缺口，别在墙外拖成消耗战。"
const STAGE_3_GUIDANCE := STAGE_3_TITLE + "——" + STAGE_3_DESC
const STAGE_4_GUIDANCE := STAGE_4_TITLE + "——王军指挥官就在前方，击破他后兰军会放弃抵抗。"

const COMMANDER_REMAINS_STATUS := "王军已溃散！第四段：红堡内院已成终局——★ 王军指挥官仍在深处，击败他后兰军将归降！"
const LANNISTER_SURRENDER_STATUS := "第四段：红堡内院已破——兰尼斯特军已归降，道路已通！"

const BATTLE_FLOW_STEPS := [
	{
		"title": STAGE_1_TITLE,
		"desc": STAGE_1_DESC,
	},
	{
		"title": STAGE_2_TITLE,
		"desc": STAGE_2_DESC,
	},
	{
		"title": STAGE_3_TITLE,
		"desc": STAGE_3_DESC,
	},
	{
		"title": STAGE_4_TITLE,
		"desc": STAGE_4_DESC,
	},
]

static func get_stage_title(stage_idx: int) -> String:
	if stage_idx < 1 or stage_idx > STAGE_TITLES.size():
		return ""
	return str(STAGE_TITLES[stage_idx - 1])

static func get_stage_badge(stage_idx: int) -> String:
	var title := get_stage_title(stage_idx)
	return "" if title == "" else "阶段：%s" % title

static func get_stage_guidance(stage_idx: int) -> String:
	match stage_idx:
		1:
			return STAGE_1_GUIDANCE
		2:
			return STAGE_2_GUIDANCE
		3:
			return STAGE_3_GUIDANCE
		4:
			return STAGE_4_GUIDANCE
		_:
			return ""
