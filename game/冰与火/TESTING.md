# 《冰与火之歌：战旗版》测试流程

本文档为接手此项目的开发者 / Agent 提供统一测试规范。

---

## 一键测试入口

项目根目录执行：

```bash
./scripts/test.sh
```

脚本会：

- 自动切换到 `game/冰与火`
- 在可写环境下设置 `HOME`
- 使用 Godot headless 运行 `tests/run_tests.gd`

如果只想做启动冒烟检查：

```bash
./scripts/smoke.sh
```

---

## 直接运行命令

```bash
cd game/冰与火
HOME=/private/tmp godot --headless --path . --script tests/run_tests.gd
```

> 在部分 macOS 环境下，Godot 可能打印：
>
> `get_system_ca_certificates ... Returning: ""`
>
> 这通常只是系统证书警告，不影响测试退出码与结果判定。

---

## 当前自动化覆盖范围

当前 `tests/run_tests.gd` 已覆盖：

1. UnitData 数据加载
2. BattleCalculator 战斗公式
3. BattleCalculator 边界值
4. 地形系统加成
5. 地形移动消耗
6. 地图完整性（按当前章节配置：Ch1/Ch2/Ch3/Ch4）
7. EnemyAI 距离计算
8. 对话 JSON 文件加载
9. 过场动画 JSON 加载
10. 战斗预测全流程
11. Unit 状态机
12. 路径查找 Dijkstra
13. 武器耐久系统
14. 道具系统
15. 武器三角加成
16. Boss 无敌底板
17. SaveSystem 存档读档
18. 守卫型 Boss 数据字段
19. 战斗动画 freed 节点防护
20. 回合结束防重入
21. 地形图块坐标合法性
22. 地图视觉风格统一回归（主战斗场景移除旧 TileMapLayer / 统一程序化暗色底图）
23. 字体初始化方法存在性
24. 关键场景与脚本冒烟加载

---

## 手动验收建议

自动化测试主要保证：

- 规则正确
- 数据正确
- 场景/脚本能加载
- 关键基础流程不被改坏

但以下内容仍建议手动验收：

### 序章一《风暴地》
场景：`scenes/Opening.tscn`

重点检查：
- [ ] 三段过场顺序播放（opening → mad_king → uprising）
- [ ] 战前对话正常显示
- [ ] 教学流程可执行
- [ ] 单位生成位置正确
- [ ] 奈德到达胜利格或敌军全灭后正常推进到第二章
- [ ] 主角阵亡时正确出现 Game Over

### 序章二～四
场景：
- `scenes/chapter/Ch2_Opening.tscn`
- `scenes/chapter/Ch3_Opening.tscn`
- `scenes/chapter/Ch4_Opening.tscn`

重点检查：
- [ ] 章节标题卡与开场过场正常播放
- [ ] 对应战斗场景可进入
- [ ] Ch2：雷加死亡触发过场
- [ ] Ch3：到达塔门触发后续过场
- [ ] Ch4：部署界面可用，指挥官死亡后兰军归降/移除

---

## 新增功能时的测试要求

### 规则 1：修改任何 GDScript 后
立即运行：

```bash
./scripts/test.sh
```

### 规则 2：新增规则/系统时
必须补 `tests/run_tests.gd`：

- 在 `_init()` 中添加新 suite
- 使用 `_assert()` / `_assert_eq()`
- 清理测试副作用（如存档文件）

### 规则 3：新增 JSON 内容时
同步补：

- 对话 JSON 路径检查
- 过场 JSON 路径检查
- 必要时补结构校验

### 规则 4：新增场景/入口时
至少补一项 smoke test：

- 场景存在
- 场景可加载
- 场景可实例化

---

## 提交前建议清单

```bash
./scripts/test.sh
git status
```

确认：

- 测试全绿
- 没有误提交临时文件
- 没有改到旧原型目录

---

*最后更新：2026-07-10*
