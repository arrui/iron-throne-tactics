# 《冰与火之歌：战旗版》项目索引

> 冰与火之歌世界观 × 火焰纹章式战棋机制  
> 个人粉丝向项目 | Godot 4.6.x | GDScript

## 当前状态

这个仓库已经不是纯设计文档阶段，而是进入了**可玩原型 / 序章纵切片**阶段：

- 已有 Godot 主项目：`game/冰与火`
- 已实现序章一～四的章节入口与战斗分发
- 已实现核心战棋循环：移动、攻击、回合、AI、战斗预测、地形、路径查找
- 已实现对话系统、过场系统、部署界面、存档系统
- 已建立 headless 自动化测试体系与一键脚本
- 战场底图风格已统一为程序化暗色庄重风格，第四章不再单独使用 Q 版瓦片观感

## 仓库结构

### 1. 设计文档

| 文件 | 内容 |
|------|------|
| [01-project-blueprint.md](./01-project-blueprint.md) | 项目总蓝图：阶段、里程碑、团队、风险 |
| [02-core-systems.md](./02-core-systems.md) | 核心系统：属性、公式、地形、兵种、武器 |
| [03-factions-and-classes.md](./03-factions-and-classes.md) | 势力与兵种：八大势力特性、转职树 |
| [04-special-mechanics.md](./04-special-mechanics.md) | 特殊机制：血脉系统、龙与驯服、绿先知、龙火地形 |
| [05-narrative-structure.md](./05-narrative-structure.md) | 叙事结构：整体框架、双主线设计、全角色名单 |
| [06-chapter-prologue-1-design.md](./06-chapter-prologue-1-design.md) | 序章·一《风暴地》完整设计文档 |
| [07-future-works.md](./07-future-works.md) | 后续篇章与扩展方向 |
| [08-prologue-vertical-slice-baseline.md](./08-prologue-vertical-slice-baseline.md) | 当前序章纵切片的有效设计基线 |
| [09-prologue-baseline-delta-log.md](./09-prologue-baseline-delta-log.md) | 旧规划 / 创意稿 与当前实现的差异清单 |
| [10-prologue-acceptance-checklist.md](./10-prologue-acceptance-checklist.md) | 序章纵切片的验收清单、优先级与执行计划 |
| [GDD-prologue-v2.md](./GDD-prologue-v2.md) | 序章重设计稿 / 创意设计文档 |

### 2. 可运行游戏项目（主开发入口）

- **主项目目录：[`game/冰与火`](./game/冰与火)**
- Godot 配置：`game/冰与火/project.godot`
- 主入口场景：`res://scenes/Opening.tscn`

> 接手开发时，请默认以 `game/冰与火` 为唯一主线工程。

### 3. 旧原型目录

仓库中仍保留少量早期原型文件，例如：

- `game/scripts/`
- `game/data/`

这些目录**不应再作为当前开发入口**，主要用于历史参考，避免误改。

## 快速开始

### 运行自动化测试

```bash
./scripts/test.sh
```

### 运行 headless 启动冒烟检查

```bash
./scripts/smoke.sh
```

### 手动打开 Godot 项目

```bash
cd game/冰与火
# 用 Godot 编辑器打开当前目录
```

## 当前工程进度

### 已完成

- [x] 核心战斗公式（伤害 / 命中 / 暴击 / 追击）
- [x] 地形系统（森林 / 矮墙 / 沼泽 / 河流 / 桥梁）
- [x] 武器三角
- [x] 武器耐久与徒手回退
- [x] 道具系统
- [x] 敌方 AI / 守卫型 Boss AI
- [x] 自动托管 AI（玩家侧）
- [x] 对话 JSON 驱动
- [x] 过场 JSON 驱动
- [x] 序章一～四章节入口
- [x] 存档 / 读档系统
- [x] Headless 自动化测试（当前已全绿）
- [x] 序章 1～4 战场视觉风格统一（统一暗色地形底图 + 细节渲染）

### 进行中

- [ ] 序章 1～4 的手动演出与体验打磨
- [ ] 章节行为级回归测试继续补充
- [ ] 角色立绘 / 地图精灵占位资源替换
- [ ] 数值平衡与角色成长率深化
- [ ] 支援、部署等系统的体验完善

## 自动化测试现状

当前测试入口：

- `game/冰与火/tests/run_tests.gd`
- `./scripts/test.sh`

覆盖内容包括：

- UnitData 数据加载
- BattleCalculator 公式与边界值
- 地形与移动消耗
- 各章节地图完整性
- 地图视觉风格统一回归（移除旧 TileMapLayer / 程序化地形细节）
- EnemyAI 曼哈顿距离
- 对话 / 过场 JSON 校验
- 战斗预测流程
- Unit 状态机
- 路径查找
- 武器耐久 / 道具 / 武器三角
- Boss 底血机制
- SaveSystem 存档读档
- 场景 / 脚本冒烟加载

## CI

已提供 GitHub Actions 工作流：

- `.github/workflows/godot-tests.yml`

提交或 PR 时会自动执行 headless 测试。

## 接手建议

如果继续推进这个项目，建议顺序为：

1. 持续保持 `./scripts/test.sh` 全绿
2. 优先完善序章一～四的可玩闭环
3. 再继续扩剧情、角色、美术与系统深度
