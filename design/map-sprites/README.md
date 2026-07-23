# 地图精灵设计工作区

本目录是**地图精灵的唯一权威来源**。运行时使用的
`game/冰与火/assets/units/*_map.png` 全部由 `generate.py` 程序化生成，
生成过程完全确定（无随机源）。

这与 `design/portraits/` 保存立绘 master 的定位一致：源工件入库，
不依赖本地临时目录。

## 生成

```bash
python3 design/map-sprites/generate.py
```

依赖 Pillow。脚本会：

- 为 `P` 字典中每个单位生成一张 96×32 横向三帧待机动画图集
  （每帧 32×32），写入 `game/冰与火/assets/units/<name>_map.png`
- 生成一张放大 4 倍的 contact sheet 到 `review/map_sprites_contact_sheet.png`，
  便于在小尺寸下检视辨识度

## 修改精灵

修改精灵外观应**改 `generate.py` 后重新运行**，而不是手改 PNG。
改完跑 `./scripts/test.sh`，确认 `_test_map_sprite_assets_and_animation` 仍通过
（该套件校验：16 个单位一对一映射、96×32 三帧、各帧有可见像素、运行时动画切换）。

## 单位配置

每个单位在 `P` 字典里定义：调色板（skin/hair/armor/trim/cape/leg/accent）
与装备特征：

| 字段 | 含义 |
|---|---|
| `weapon` | `sword` / `greatsword` / `spear` / `sword_shield` / `spear_shield` / `hammer` / `axe` |
| `helmet` | 是否戴头盔（遮盖头发） |
| `plume` | 头盔羽饰颜色（御林铁卫 / 巴里斯坦 / 多恩骑士） |
| `antler` | 鹿角（劳勃·拜拉席恩） |
| `star` | 胸前星徽（亚瑟·戴恩·拂晓神剑） |
| `broad` | 加宽躯干（壮硕体型：劳勃、叛军领主） |
| `hair_long` | 长发披肩（雷加） |

阵营色彩语言（与 `design/portraits/` 立绘保持一致）：

- 史塔克 / 北方：钢灰甲 + 雾蓝镶边
- 坦格利安：黑甲 + 暗红镶边
- 兰尼斯特：暗红甲 + 金镶边
- 王室 / 御林铁卫：白甲 + 金镶边
- 多恩：橙铜甲 + 金镶边
- 君临都城守卫（杰诺斯·史林特）：黑金甲
