# AI绘图提示词清单
> 用于周末生成游戏像素美术资源
> 工具推荐：Midjourney / Stable Diffusion / DALL-E 3

---

## 一、角色地图图标（16×16像素，GBA风格）

每个角色需要一张 **48×16** 的PNG（3帧横排：直立/右脚/左脚）
保存到：`game/冰与火/assets/units/`

### 通用参数
```
style: GBA Fire Emblem map sprite, 16x16 pixel art, top-down view,
clean pixel art, limited color palette (16 colors max),
transparent background, sprite sheet 3 frames horizontal
```

### 奈德·史塔克（ned_stark_map.png）
```
Prompt:
GBA Fire Emblem style map unit sprite, Ned Stark from Game of Thrones,
northern lord warrior, dark grey cloak, longsword at hip,
brown leather armor, dark hair, stern expression,
16x16 pixel art, top-down perspective, 3-frame walk cycle sprite sheet,
blue-grey color palette, transparent background

参考：FE6的Alen / FE7的Lowen（骑马前的步行剑士）
```

### 劳勃·拜拉席恩（robert_baratheon_map.png）
```
Prompt:
GBA Fire Emblem style map unit sprite, Robert Baratheon young warrior,
heavy black armor with stag antler crest, war hammer,
broad shouldered, dark beard, imposing figure,
16x16 pixel art, 3-frame walk cycle sprite sheet,
black and gold color palette, transparent background

参考：FE7的Oswin（重装兵）
```

### 霍兰·里德（howland_reed_map.png）
```
Prompt:
GBA Fire Emblem style map unit sprite, Howland Reed scout warrior,
crannogman, green-brown leather armor, trident or spear,
small frame, swamp ranger aesthetic,
16x16 pixel art, 3-frame walk cycle sprite sheet,
green-brown earth tones palette, transparent background

参考：FE7的Matthew（侦察兵体型）
```

### 王军士兵（royal_soldier_map.png）
```
Prompt:
GBA Fire Emblem style map unit sprite, Lannister soldier enemy,
crimson red armor, spear and shield, faceless helmet,
generic foot soldier, threatening posture,
16x16 pixel art, 3-frame walk cycle sprite sheet,
red and gold color palette, transparent background

参考：FE7的enemy soldier
```

---

## 二、角色立绘（对话框用，半身像）

每张图约 **80×96像素** 或 **160×192像素**（2倍）
保存到：`game/冰与火/assets/portraits/`

### 奈德·史塔克立绘
```
Prompt:
GBA Fire Emblem character portrait style, Ned Stark,
northern lord, dark grey fur-lined cloak, longsword hilt visible,
stern noble face, dark hair, strong jaw, honest eyes,
bust portrait facing slightly right, pixel art,
limited GBA color palette, dark background with subtle vignette,
160x192 pixel art portrait
```

### 劳勃·拜拉席恩立绘
```
Prompt:
GBA Fire Emblem character portrait style, young Robert Baratheon,
black plate armor, war hammer visible over shoulder,
broad face, dark beard, fierce blue eyes, charismatic grin,
bust portrait facing slightly left, pixel art,
GBA color palette, 160x192 pixel art portrait
```

---

## 三、过场动画画面（GBA像素场景）

保存到：`game/冰与火/assets/cutscenes/`
尺寸：**240×160像素**（GBA原生分辨率，可2x=480×320）

### mad_king_throne.png — 疯王宝座场景
```
Prompt:
GBA pixel art scene, Game of Thrones Iron Throne room,
Aerys II (Mad King) sitting on Iron Throne made of swords,
throne room with torches, dramatic shadows, red and dark color palette,
two bound prisoners kneeling before throne,
atmospheric medieval fantasy, 240x160 pixel art,
GBA Fire Emblem cutscene style
```

### mad_king_fire.png — 疯王焚刑场景
```
Prompt:
GBA pixel art cutscene scene, dramatic execution scene,
flames and fire in dark throne room, silhouette of figure burning,
wild king watching with mad glee, dark red orange palette,
tragic medieval scene, 240x160 pixel art,
GBA Fire Emblem cutscene style, heavy shadows
```

### storm_end.png — 风暴地战场
```
Prompt:
GBA pixel art scene, medieval battlefield at dawn,
storm coast castle in background, rebel army gathering,
banners with stag sigil (Baratheon), cloudy dramatic sky,
two heroes standing together looking at horizon,
240x160 pixel art, GBA Fire Emblem battle map intro style,
blue-grey stormy color palette
```

---

## 四、地图图块补充（可选）

如果Toen图块集不够用，可以生成：

### 补充图块
```
Prompt:
GBA Fire Emblem style tileset tiles, 16x16 pixel art,
medieval fantasy map tiles: [具体需要的地形类型],
seamless tiling, limited color palette,
top-down perspective, clean pixel art
```

---

## 使用说明

1. 用上面的提示词在AI工具生成图片
2. 用 **Aseprite** 或 Photoshop 裁剪到正确尺寸
3. 确保背景透明（PNG格式）
4. 放入对应目录
5. 告诉我，我来接入代码

## 周末优先级

1. 🔴 必做：4个角色地图图标（影响战斗视觉）
2. 🟡 重要：3张过场动画背景图（影响剧情体验）
3. 🟢 加分：2个角色立绘（对话框更生动）
