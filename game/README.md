# 《冰与火之歌：战旗版》Godot 项目

主项目目录：`game/冰与火`

冰与火之歌世界观 × 火焰纹章式战棋机制  
引擎：Godot 4.6.x | 语言：GDScript

## 当前状态

该目录已经是当前唯一主开发入口，不再是早期原型。

### 已实现的系统

- [x] `scripts/battle/BattleMap.gd`  
      战棋地图逻辑、回合流程、UI、高亮、危险区、路径预览
- [x] `scripts/battle/BattleBootstrap.gd`  
      序章一～四章节分发、地图生成、章节事件与胜利流程
- [x] `scripts/battle/Unit.gd`  
      单位状态机、伤害、HP、死亡、绘制
- [x] `scripts/battle/BattleCalculator.gd`  
      伤害/命中/暴击/追击/武器三角/预测公式
- [x] `scripts/battle/EnemyAI.gd`  
      敌军追击 AI 与守卫型 Boss AI
- [x] `scripts/systems/AutopilotAI.gd`  
      玩家自动托管 AI
- [x] `scripts/dialogue/DialogueSystem.gd`  
      JSON 驱动对话系统
- [x] `scripts/cutscene/CutscenePlayer.gd`  
      JSON 驱动过场播放
- [x] `scripts/systems/SaveSystem.gd`  
      存档、读档、章节推进
- [x] `scripts/ui/DeployScreen_Ch4.gd`  
      第四章部署界面
- [x] `tests/run_tests.gd`  
      Headless 自动化测试主入口

### 已有内容资源

- [x] 序章一～四相关场景 `.tscn`
- [x] 单位数据 `data/units/*.json`
- [x] 对话数据 `data/dialogues/*.json`
- [x] 过场数据 `data/cutscenes/*.json`
- [x] 占位地图精灵 / 立绘 / 字体 / 瓦片资源
- [x] 全章节统一战场底图风格（程序化暗色庄重渲染，取消第四章独立 Q 版视觉）

## 开发命令

### 全量自动化测试

```bash
cd /Users/arrui/Desktop/iron-throne-tactics
./scripts/test.sh
```

### Headless 冒烟启动

```bash
cd /Users/arrui/Desktop/iron-throne-tactics
./scripts/smoke.sh
```

## 注意事项

- 当前主项目是 `game/冰与火`
- 仓库根目录下 `game/scripts`、`game/data` 属于早期原型残留，请勿作为当前开发入口
- 修改任何 GDScript 或章节配置后，优先运行自动化测试

## 下一步建议

1. 继续补章节行为级测试
2. 继续讨论并细化统一风格下的地图图块设计
3. 打磨序章四的战斗与结局体验
4. 替换占位资源并开始数值平衡
