# 《铁王座战记》— 标准化测试流程

本文档为所有接手此项目的 Agent/开发者提供可复用的测试执行规范。

---

## 快速验证（每次代码变更后必做）

```bash
# 项目根目录
cd /Users/yanrui/Desktop/iron-throne-tactics/game/冰与火

# 运行全量自动化测试（headless，无需开编辑器）
godot --headless --path . --script tests/run_tests.gd

# 期望输出：最后一行应为 "全部通过 ✓"，exit code = 0
```

---

## 测试套件覆盖范围（`tests/run_tests.gd`）

| 套件编号 | 名称 | 核心内容 |
|---------|------|---------|
| 1 | UnitData 数据加载 | 字段正确读取、缺失字段默认值、新字段(weapon_uses/is_protagonist/min_hp/items) |
| 2 | BattleCalculator 战斗公式 | 伤害/命中/暴击/追击/各武器类型 |
| 3 | BattleCalculator 边界值 | 最小伤害=1、命中[1,99]、速差临界值、地形修正 |
| 4 | 地形系统加成 | 全6种地形加成值、加成对命中的实际影响 |
| 5 | 地形移动消耗 | 全6种地形消耗值、移动力边界计算 |
| 6 | 地图完整性（22×16） | 边界峭壁、河流分布、桥梁存在、关键位置可通行 |
| 7 | EnemyAI 距离计算 | 曼哈顿距离、含负坐标、边界情况 |
| 8 | 对话 JSON 文件加载 | 文件存在、JSON格式、lines结构、next=-1终止 |
| 9 | 过场动画 JSON 加载 | 文件存在、slides结构、duration合法、scene_art类型 |
| 10 | 战斗预测全流程 | predict()完整字典、数值合法性、实际伤害计算 |
| 11 | Unit 状态机 | IDLE→MOVED→DONE→IDLE、undo_move、死亡判断 |
| 12 | 路径查找 Dijkstra | 直线、绕行、超出移动力、高消耗地形、无路可走 |
| 13 | 武器耐久系统 | uses递减、破损回退fist、无限耐久(-1)、破损后不再消耗 |
| 14 | 道具系统 | has_usable_items、use_item消耗、用尽自动移除、越界保护 |
| 15 | 武器三角加成 | 全6种胜负关系(±1 ATK/±5 HIT)、对实际伤害的影响 |
| 16 | Boss 无敌底板 | min_hp=1时HP不能降至底板以下、不触发死亡 |
| 17 | SaveSystem 存档读档 | 新游戏默认值、存档写入/读取、重复保存去重、删除存档 |

---

## 手动运行验证清单（在 Godot 编辑器中）

每次完整功能变更后，按顺序在编辑器中运行以下场景并验证：

### 序章·一《风暴地》
```
场景：scenes/Opening.tscn
```
- [ ] 三段过场动画顺序播放（opening → mad_king → uprising）
- [ ] mad_king 过场中 scene_art 绘制场景（throne_room/execution/vale_castle）出现
- [ ] 战前对话显示（劳勃/奈德各行对话）
- [ ] 单位在 22×16 地图上正确生成（奈德/劳勃/霍兰 在左侧）
- [ ] 方向键可滚动地图到右侧（看到敌军）
- [ ] 选中单位：蓝色高亮+亮边框清晰可见（不被地形遮挡）
- [ ] 悬停移动范围：路径预览箭头显示
- [ ] 移动后：「取消移动」按钮出现
- [ ] 取消移动：单位回到原位
- [ ] 使用道具：奈德/霍兰有急救药可用
- [ ] D键：危险区红色半透明切换显示
- [ ] 结束回合：提前跳到敌方回合
- [ ] 敌方回合：王军士兵有行走动画
- [ ] 战斗结算：命中/伤害/命中率正确（可对照预测界面验证）
- [ ] 武器耐久：攻击后武器使用次数减少（Debug 输出可见）
- [ ] 主角死亡：GameOver 弹窗出现（将奈德放在敌军旁边让其被打死）
- [ ] 非主角死亡：正常移除，无 GameOver
- [ ] 通关条件：占领 (17,8) 或消灭所有敌军 → 战后对话
- [ ] 战后对话后：若 Ch2 场景存在，则自动跳转；否则显示结果面板

### 序章·二～四（逐章验证）
```
场景：scenes/chapter/Ch2_Opening.tscn
        scenes/chapter/Ch3_Opening.tscn
        scenes/chapter/Ch4_Opening.tscn
```
- [ ] 章节标题卡淡入淡出（若 ChapterTransition.tscn 存在）
- [ ] 各章过场动画正常播放
- [ ] 对应战斗地图正确加载
- [ ] Ch2：雷加死亡触发全屏过场（ch2_rhaegar_fall.json）
- [ ] Ch3：奈德到达塔门触发霍兰刺杀过场 → 莱安娜过场
- [ ] Ch4：部署画面显示，单位可选择
- [ ] Ch4：王军指挥官死亡后，兰尼斯特士兵（move=0）被移除

### 存档系统
- [ ] 通关序章·一后刷新游戏 → 自动跳到序章·二
- [ ] Ch4 部署画面有「新游戏（清除存档）」按钮
- [ ] 存档文件位于 `user://save.json`（macOS: `~/Library/Application Support/Godot/app_userdata/冰与火/save.json`）

---

## 新增代码时的测试规范

### 规则 1：修改任何 GDScript 后
立即运行 headless 测试，确认 exit code = 0：
```bash
godot --headless --path game/冰与火 --script tests/run_tests.gd
```

### 规则 2：新增系统功能时
在 `tests/run_tests.gd` 中新增对应测试套件：
1. 在 `_init()` 的 `_run_suite()` 列表末尾添加调用
2. 实现测试方法，命名规范：`_test_<feature_name>()`
3. 使用 `_assert()` / `_assert_eq()` 方法
4. 最后一行清理测试副作用（如删除测试文件）
5. 重新运行确认全量通过

### 规则 3：新增章节或 JSON 内容时
在「过场动画 JSON 加载」或「对话 JSON 文件加载」测试套件中补充对应文件路径检查。

### 规则 4：提交前必做
```bash
# 1. 全量测试
godot --headless --path game/冰与火 --script tests/run_tests.gd
# exit code 必须为 0

# 2. 检查未暂存文件
git status

# 3. 提交（勿提交测试生成的临时存档）
git add <具体文件>
git commit -m "feat/fix: <描述>"
git push
```

---

## 常见错误排查

| 症状 | 可能原因 | 解决方案 |
|------|---------|---------|
| `Parse Error: Cannot infer type` | 使用 `:=` 推断类型时，右值为 Variant | 改为 `var x: TypeName = ...` 显式类型 |
| `SCRIPT ERROR: Identifier not found` | 类未注册或路径错误 | 检查 `class_name` 声明和 `preload` 路径 |
| `ResourceLoader.exists` 返回 false | .tscn/.gd 文件不存在 | 确认文件路径和大小写 |
| `@onready var _cam = $Camera2D` 为 null | 对应场景中无 Camera2D 子节点 | 检查继承的基础场景是否有该节点 |
| 武器三角数值不对 | weapon_key 格式错误（如 `sword_s` 而非 `sword_S`） | JSON 中 weapon_rank 字母大写 |
| SaveSystem 重复章节 | JSON 反序列化后数字为浮点型 | SaveSystem 内部已做 int() 转换 |

---

*最后更新：2026-06-09 | 测试套件版本：v3（220 个测试用例）*
