#!/usr/bin/env python3
"""地图精灵生成器 — 程序化像素艺术单位图集。

为每个可上场单位生成一张 96×32 横向三帧待机动画图集
（每帧 32×32），输出到运行时资源目录
``game/冰与火/assets/units/<name>_map.png``。

这是地图精灵的**唯一权威来源**：运行时使用的 ``*_map.png`` 全部由本脚本
生成，且生成过程完全确定（无随机源）。修改精灵外观应改本脚本后重新运行，
而不是手改 PNG。

用法::

    python3 design/map-sprites/generate.py

依赖 Pillow。生成后建议跑 ``./scripts/test.sh`` 确认
``_test_map_sprite_assets_and_animation`` 仍通过。
"""
from PIL import Image, ImageDraw
from pathlib import Path

# design/map-sprites/ -> repo root
ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / 'game/冰与火' / 'assets' / 'units'
REVIEW = Path(__file__).resolve().parent / 'review'
OUT.mkdir(parents=True, exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=True)

# Native 32px pixel-art profiles. Every unit has its own silhouette, palette and equipment.
P = {
 'ned_stark': dict(skin='#c9926d', hair='#302b2c', armor='#3e4a54', trim='#8fa2ad', cape='#27333b', leg='#25282c', weapon='greatsword', accent='#aab7bd'),
 'rhaegar_targaryen': dict(skin='#d8b0a1', hair='#ddd6d7', armor='#29262f', trim='#a72d32', cape='#7a1f28', leg='#211f29', weapon='sword', accent='#d7b55a', hair_long=True),
 'arthur_dayne': dict(skin='#cfa086', hair='#6d5849', armor='#c9d1d5', trim='#f0f3ef', cape='#e3e5df', leg='#7f8b91', weapon='greatsword', accent='#f0d887', star=True),
 'howland_reed': dict(skin='#b98362', hair='#493b2c', armor='#4d6044', trim='#83916a', cape='#344536', leg='#303b2d', weapon='spear', accent='#aeb878'),
 'jaime_lannister': dict(skin='#d5a27c', hair='#d4ad56', armor='#a7312d', trim='#d5a83e', cape='#8f2425', leg='#552728', weapon='sword', accent='#f0c95b'),
 'robert_baratheon': dict(skin='#a97859', hair='#17191c', armor='#303943', trim='#d5bd58', cape='#303238', leg='#22272b', weapon='hammer', accent='#e0c95f', broad=True, antler=True),
 'royal_guard_captain': dict(skin='#c59776', hair='#6b523d', armor='#d9ddda', trim='#d6b24c', cape='#f0eee5', leg='#7d8383', weapon='sword_shield', accent='#f3d56b', plume='#eee9dc'),
 'lannister_soldier': dict(skin='#b98565', hair='#51362a', armor='#a42c28', trim='#d2a23e', cape='#76201f', leg='#562728', weapon='spear_shield', accent='#e6bd52', helmet=True),
 'barristan_selmy': dict(skin='#c99a7d', hair='#d2d0c6', armor='#bfc8ca', trim='#e5e3d7', cape='#dedfd9', leg='#747d80', weapon='sword_shield', accent='#d8bd61', plume='#d9d7ce'),
 'janos_slynt': dict(skin='#bc8769', hair='#352b27', armor='#71532e', trim='#c9a33d', cape='#5b3d22', leg='#3b3128', weapon='spear', accent='#d8b34e', helmet=True),
 'dorne_knight': dict(skin='#9f6545', hair='#32211b', armor='#b86d2b', trim='#e3b84f', cape='#923d27', leg='#593128', weapon='spear_shield', accent='#f0ce67', plume='#d04b2f'),
 'northern_knight': dict(skin='#bd8969', hair='#433b36', armor='#52616a', trim='#8ca0a8', cape='#394952', leg='#30383d', weapon='sword_shield', accent='#b4c0c4', helmet=True),
 'rebel_lord': dict(skin='#bd8665', hair='#5a3929', armor='#6b4434', trim='#b07948', cape='#49352e', leg='#352b29', weapon='axe', accent='#d1a25d', broad=True),
 'royal_soldier': dict(skin='#ba8667', hair='#514032', armor='#777f83', trim='#c5aa55', cape='#5b3430', leg='#44484a', weapon='spear_shield', accent='#d8bd62', helmet=True),
 'targaryen_soldier': dict(skin='#b67f65', hair='#3a2c2d', armor='#302d35', trim='#9f2c32', cape='#70242b', leg='#24242a', weapon='spear_shield', accent='#c99f4e', helmet=True),
 'robb_stark': dict(skin='#c49068', hair='#5a3a2a', armor='#3e4a54', trim='#8fa2ad', cape='#27333b', leg='#25282c', weapon='sword', accent='#aab7bd', broad=False),
 'brynden_tully': dict(skin='#b8855f', hair='#88807a', armor='#4a5a4a', trim='#8a9a7a', cape='#33402f', leg='#2c3326', weapon='spear_shield', accent='#aeb878', plume='#c9d0a0'),
 'golden_lion_knight': dict(skin='#c4926d', hair='#4a3a2a', armor='#a7312d', trim='#d5a83e', cape='#8f2425', leg='#552728', weapon='spear_shield', accent='#f0c95b', helmet=True),
}

OUTLINE = '#17181b'
SHADOW = '#111217'

def rect(d, box, fill, outline=OUTLINE):
    d.rectangle(box, fill=fill, outline=outline)

def px(d, pts, fill):
    for x,y in pts: d.point((x,y), fill=fill)

def frame(cfg, phase):
    im = Image.new('RGBA',(32,32),(0,0,0,0)); d=ImageDraw.Draw(im)
    bob = 0 if phase != 1 else 1
    # soft pixel shadow
    d.ellipse((9,27,23,30), fill=(10,10,12,95))
    broad = 1 if cfg.get('broad') else 0
    # cape behind torso
    d.polygon([(11-broad,13+bob),(21+broad,13+bob),(23+broad,25+bob),(9-broad,25+bob)], fill=cfg['cape'], outline=OUTLINE)
    # legs animate left/neutral/right
    shift = (-1,0,1)[phase]
    rect(d,(11+shift,23+bob,14+shift,28),cfg['leg'])
    rect(d,(18-shift,23+bob,21-shift,28),cfg['leg'])
    d.line((10+shift,28,15+shift,28),fill=OUTLINE,width=2)
    d.line((17-shift,28,22-shift,28),fill=OUTLINE,width=2)
    # torso and belt
    d.polygon([(11-broad,13+bob),(21+broad,13+bob),(23+broad,22+bob),(9-broad,22+bob)], fill=cfg['armor'], outline=OUTLINE)
    d.line((10-broad,19+bob,22+broad,19+bob), fill=cfg['trim'], width=2)
    d.rectangle((15,19+bob,17,21+bob),fill=cfg['accent'])
    # arms
    arm = shift
    rect(d,(7-broad,14+bob+max(arm,0),10,21+bob+max(arm,0)),cfg['armor'])
    rect(d,(22,14+bob+max(-arm,0),25+broad,21+bob+max(-arm,0)),cfg['armor'])
    # head/hair
    if cfg.get('hair_long'):
        rect(d,(11,5+bob,21,14+bob),cfg['hair'])
    rect(d,(12,5+bob,20,13+bob),cfg['skin'])
    d.rectangle((11,5+bob,21,8+bob),fill=cfg['hair'])
    d.point((11,9+bob),fill=cfg['hair']); d.point((21,9+bob),fill=cfg['hair'])
    # helmet / captain plume
    if cfg.get('helmet') or cfg.get('plume'):
        d.polygon([(11,8+bob),(13,4+bob),(19,4+bob),(21,8+bob)], fill=cfg['trim'], outline=OUTLINE)
        d.line((16,5+bob,16,11+bob), fill=cfg['accent'])
    if cfg.get('plume'):
        d.line((16,4+bob,16,1+bob), fill=cfg['plume'], width=2)
        d.line((16,1+bob,20,3+bob), fill=cfg['plume'], width=2)
    if cfg.get('antler'):
        d.line((12,6+bob,9,2+bob),fill=cfg['accent'],width=1); d.line((9,3+bob,7,2+bob),fill=cfg['accent'])
        d.line((20,6+bob,23,2+bob),fill=cfg['accent'],width=1); d.line((23,3+bob,25,2+bob),fill=cfg['accent'])
    # face pixels
    d.point((14,10+bob),fill='#34231f'); d.point((18,10+bob),fill='#34231f')
    # heraldic accent / star
    d.rectangle((15,14+bob,17,17+bob),fill=cfg['accent'])
    if cfg.get('star'):
        px(d,[(16,13+bob),(14,15+bob),(18,15+bob),(16,17+bob)],cfg['accent'])
    # equipment silhouettes
    w=cfg['weapon']
    hand_y=18+bob
    if 'spear' in w:
        x=5 if phase!=2 else 6
        d.line((x,4,x,27),fill=OUTLINE,width=2); d.line((x,4,x,25),fill=cfg['trim'])
        d.polygon([(x,2),(x-2,6),(x+2,6)],fill=cfg['accent'],outline=OUTLINE)
    if w in ('sword','greatsword','sword_shield'):
        x=27 if phase!=0 else 26
        top=3 if w=='greatsword' else 7
        d.line((x,top,x-2,25),fill=OUTLINE,width=3); d.line((x,top,x-2,24),fill=cfg['trim'])
        d.line((x-3,20,x+1,21),fill=cfg['accent'],width=2)
    if w=='hammer':
        x=27; d.line((x-2,10,x-4,26),fill='#725039',width=2)
        rect(d,(22,7,30,12),cfg['accent'])
    if w=='axe':
        x=27; d.line((x-2,9,x-4,27),fill='#725039',width=2)
        d.polygon([(22,6),(29,8),(27,14),(22,12)],fill=cfg['trim'],outline=OUTLINE)
    if 'shield' in w:
        x=7
        d.polygon([(3,15+bob),(9,14+bob),(10,21+bob),(6,25+bob),(3,21+bob)],fill=cfg['armor'],outline=OUTLINE)
        d.line((4,17+bob,8,22+bob),fill=cfg['accent'],width=1)
        d.line((8,17+bob,4,22+bob),fill=cfg['accent'],width=1)
    return im

def build_sheet(cfg):
    sheet = Image.new('RGBA',(96,32),(0,0,0,0))
    for i in range(3): sheet.alpha_composite(frame(cfg,i),(i*32,0))
    return sheet

def build_contact_sheet():
    """5 列 × ceil(16/5) 行的放大预览，便于在小尺寸下检视辨识度。"""
    names = list(P.keys())
    cols = 5
    rows = (len(names) + cols - 1) // cols
    cell, scale = 96, 4  # 每格 96px(三帧) 放大 4 倍
    sheet = Image.new('RGBA', (cols * cell * scale, rows * 32 * scale), (20, 20, 24, 255))
    for idx, name in enumerate(names):
        unit_sheet = build_sheet(P[name])
        unit_sheet = unit_sheet.resize((cell * scale, 32 * scale), Image.NEAREST)
        cx = (idx % cols) * cell * scale
        cy = (idx // cols) * 32 * scale
        sheet.alpha_composite(unit_sheet, (cx, cy))
    return sheet

for name, cfg in P.items():
    build_sheet(cfg).save(OUT / f'{name}_map.png', optimize=True)

build_contact_sheet().save(REVIEW / 'map_sprites_contact_sheet.png')
print(f'wrote {len(P)} sprite sheets to {OUT}')
print(f'wrote contact sheet to {REVIEW / "map_sprites_contact_sheet.png"}')
