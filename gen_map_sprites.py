"""
生成FE GBA风格地图行走图标（16x16像素，3帧横排，共48x16）
参考Fire Emblem GBA系列地图sprite风格：
- 头部：较大，有头发颜色
- 身体：小巧，有服装颜色
- 像素艺术剪影风格
"""
from PIL import Image
import os

OUTPUT_DIR = os.path.expanduser("~/Desktop/iron-throne-tactics/game/冰与火/assets/units/")

# 透明色
T = (0, 0, 0, 0)

# ----- 通用调色板颜色 -----
# 皮肤色
SKIN_L = (255, 220, 170, 255)   # 亮肤色
SKIN_D = (200, 160, 110, 255)   # 暗肤色
# 眼睛
EYE = (60, 40, 20, 255)
# 头发描边
HAIR_OUTLINE = (30, 20, 10, 255)

def draw_sprite(pixels, frame_x, frame_w, frame_h, data):
    """在像素列表上绘制一帧sprite。data是[(x,y,color)]列表"""
    for (x, y, c) in data:
        ax = frame_x * frame_w + x
        if 0 <= ax < frame_w * 3 and 0 <= y < frame_h:
            pixels[y][ax] = c

def make_spritesheet(frames_data, w=16, h=16):
    """frames_data: 3帧的像素数据列表，每帧是[(x,y,color)]"""
    img = Image.new("RGBA", (w * 3, h), (0, 0, 0, 0))
    pixels = [[T] * (w * 3) for _ in range(h)]

    for frame_idx, frame in enumerate(frames_data):
        draw_sprite(pixels, frame_idx, w, h, frame)

    for y in range(h):
        for x in range(w * 3):
            img.putpixel((x, y), pixels[y][x])

    return img

# =========================================
# 奈德·史塔克 —— 剑士/领主 (蓝灰色调)
# =========================================
def ned_frame(offset_y=0):
    """offset_y: 0=直立, 1=稍低(行走帧)"""
    # 颜色
    HAIR = (50, 40, 30, 255)         # 深棕黑发
    HAIR_H = (80, 65, 45, 255)       # 发高光
    ARMOR = (90, 110, 140, 255)      # 史塔克灰蓝盔甲
    ARMOR_L = (120, 145, 175, 255)   # 盔甲亮面
    ARMOR_D = (60, 75, 100, 255)     # 盔甲暗面
    CLOAK = (70, 85, 110, 255)       # 深蓝披风
    SWORD = (200, 200, 210, 255)     # 剑
    SWORD_H = (240, 240, 255, 255)   # 剑刃高光
    BOOT = (50, 40, 35, 255)         # 靴子深棕
    OUTLINE = (20, 15, 10, 255)      # 轮廓黑

    oy = offset_y
    # 格式: (x, y, color)
    return [
        # === 头部（行中上方） ===
        # 头发顶部
        (7, 1+oy, OUTLINE), (8, 1+oy, OUTLINE),
        (6, 2+oy, OUTLINE), (7, 2+oy, HAIR), (8, 2+oy, HAIR_H), (9, 2+oy, OUTLINE),
        # 头部
        (6, 3+oy, OUTLINE), (7, 3+oy, HAIR), (8, 3+oy, SKIN_L), (9, 3+oy, OUTLINE),
        (5, 4+oy, OUTLINE), (6, 4+oy, SKIN_L), (7, 4+oy, SKIN_L), (8, 4+oy, SKIN_L), (9, 4+oy, SKIN_D), (10, 4+oy, OUTLINE),
        # 眼睛
        (5, 5+oy, OUTLINE), (6, 5+oy, SKIN_L), (7, 5+oy, EYE), (8, 5+oy, SKIN_L), (9, 5+oy, EYE), (10, 5+oy, OUTLINE),
        # 下脸/颈
        (6, 6+oy, OUTLINE), (7, 6+oy, SKIN_D), (8, 6+oy, SKIN_D), (9, 6+oy, OUTLINE),

        # === 身体（盔甲） ===
        (5, 7+oy, OUTLINE), (6, 7+oy, ARMOR_L), (7, 7+oy, ARMOR_L), (8, 7+oy, ARMOR), (9, 7+oy, ARMOR_D), (10, 7+oy, OUTLINE),
        (4, 8+oy, OUTLINE), (5, 8+oy, CLOAK), (6, 8+oy, ARMOR_L), (7, 8+oy, ARMOR), (8, 8+oy, ARMOR), (9, 8+oy, ARMOR_D), (10, 8+oy, CLOAK), (11, 8+oy, OUTLINE),
        (4, 9+oy, OUTLINE), (5, 9+oy, CLOAK), (6, 9+oy, ARMOR), (7, 9+oy, ARMOR), (8, 9+oy, ARMOR_D), (9, 9+oy, ARMOR_D), (10, 9+oy, CLOAK), (11, 9+oy, OUTLINE),

        # === 剑（右侧斜举） ===
        (11, 7+oy, SWORD_H), (12, 6+oy, SWORD_H), (12, 7+oy, SWORD), (13, 5+oy, SWORD_H),

        # === 腿部 ===
        (5, 10+oy, OUTLINE), (6, 10+oy, ARMOR_D), (7, 10+oy, ARMOR_D), (8, 10+oy, CLOAK), (9, 10+oy, CLOAK), (10, 10+oy, OUTLINE),
        (5, 11+oy, OUTLINE), (6, 11+oy, BOOT), (7, 11+oy, BOOT), (8, 11+oy, BOOT), (9, 11+oy, BOOT), (10, 11+oy, OUTLINE),
        (6, 12+oy, OUTLINE), (7, 12+oy, BOOT), (8, 12+oy, BOOT), (9, 12+oy, OUTLINE),
    ]

# 3帧：直立、行走低、直立
ned_frames = [
    ned_frame(0),   # 帧1：直立
    ned_frame(1),   # 帧2：行走（稍低）
    ned_frame(0),   # 帧3：直立（回来）
]
ned_img = make_spritesheet(ned_frames)
ned_img.save(os.path.join(OUTPUT_DIR, "ned_stark_map.png"))
print("生成: ned_stark_map.png")


# =========================================
# 劳勃·拜拉席恩 —— 重装骑士 (黄黑色调)
# =========================================
def robert_frame(offset_y=0):
    HAIR = (50, 35, 20, 255)          # 黑发
    BEARD = (45, 30, 15, 255)         # 黑胡须
    ARMOR = (180, 140, 30, 255)       # 金色盔甲
    ARMOR_L = (230, 195, 80, 255)     # 盔甲亮面
    ARMOR_D = (120, 90, 10, 255)      # 盔甲暗面
    HELM = (160, 120, 20, 255)        # 头盔
    HELM_L = (210, 175, 60, 255)      # 头盔高光
    OUTLINE = (20, 15, 5, 255)

    oy = offset_y
    return [
        # 头盔
        (6, 1+oy, OUTLINE), (7, 1+oy, HELM_L), (8, 1+oy, HELM_L), (9, 1+oy, OUTLINE),
        (5, 2+oy, OUTLINE), (6, 2+oy, HELM_L), (7, 2+oy, HELM_L), (8, 2+oy, HELM), (9, 2+oy, HELM), (10, 2+oy, OUTLINE),
        (5, 3+oy, OUTLINE), (6, 3+oy, HELM), (7, 3+oy, SKIN_L), (8, 3+oy, SKIN_L), (9, 3+oy, HELM), (10, 3+oy, OUTLINE),
        # 眼缝/脸
        (5, 4+oy, OUTLINE), (6, 4+oy, HELM_L), (7, 4+oy, EYE), (8, 4+oy, SKIN_L), (9, 4+oy, EYE), (10, 4+oy, HELM_L), (5, 4+oy, OUTLINE), (10, 4+oy, OUTLINE),
        (5, 5+oy, OUTLINE), (6, 5+oy, SKIN_D), (7, 5+oy, BEARD), (8, 5+oy, BEARD), (9, 5+oy, SKIN_D), (10, 5+oy, OUTLINE),

        # 宽肩重甲身体
        (3, 6+oy, OUTLINE), (4, 6+oy, ARMOR_L), (5, 6+oy, ARMOR_L), (6, 6+oy, ARMOR_L), (7, 6+oy, ARMOR_L), (8, 6+oy, ARMOR), (9, 6+oy, ARMOR_D), (10, 6+oy, ARMOR_D), (11, 6+oy, ARMOR_D), (12, 6+oy, OUTLINE),
        (3, 7+oy, OUTLINE), (4, 7+oy, ARMOR_L), (5, 7+oy, ARMOR_L), (6, 7+oy, ARMOR), (7, 7+oy, ARMOR), (8, 7+oy, ARMOR), (9, 7+oy, ARMOR_D), (10, 7+oy, ARMOR_D), (11, 7+oy, ARMOR_D), (12, 7+oy, OUTLINE),
        (3, 8+oy, OUTLINE), (4, 8+oy, ARMOR), (5, 8+oy, ARMOR), (6, 8+oy, ARMOR), (7, 8+oy, ARMOR), (8, 8+oy, ARMOR_D), (9, 8+oy, ARMOR_D), (10, 8+oy, ARMOR_D), (11, 8+oy, OUTLINE),
        (4, 9+oy, OUTLINE), (5, 9+oy, ARMOR_D), (6, 9+oy, ARMOR_D), (7, 9+oy, ARMOR_D), (8, 9+oy, ARMOR_D), (9, 9+oy, ARMOR_D), (10, 9+oy, OUTLINE),

        # 腿（粗壮）
        (4, 10+oy, OUTLINE), (5, 10+oy, ARMOR_D), (6, 10+oy, ARMOR_D), (7, 10+oy, ARMOR_D), (8, 10+oy, ARMOR_D), (9, 10+oy, OUTLINE),
        (4, 11+oy, OUTLINE), (5, 11+oy, ARMOR_D), (6, 11+oy, ARMOR_D), (7, 11+oy, ARMOR_D), (8, 11+oy, ARMOR_D), (9, 11+oy, OUTLINE),
        (5, 12+oy, OUTLINE), (6, 12+oy, ARMOR_D), (7, 12+oy, ARMOR_D), (8, 12+oy, OUTLINE),
    ]

robert_frames = [
    robert_frame(0),
    robert_frame(1),
    robert_frame(0),
]
robert_img = make_spritesheet(robert_frames)
robert_img.save(os.path.join(OUTPUT_DIR, "robert_baratheon_map.png"))
print("生成: robert_baratheon_map.png")


# =========================================
# 豪兰·里德 —— 长枪兵/侦察兵 (绿色调)
# =========================================
def howland_frame(offset_y=0):
    HAIR = (60, 80, 40, 255)          # 暗绿棕发
    ARMOR = (70, 100, 60, 255)        # 沼泽绿皮革甲
    ARMOR_L = (100, 135, 80, 255)     # 亮面
    ARMOR_D = (45, 65, 35, 255)       # 暗面
    CLOAK = (55, 80, 45, 255)         # 深绿披风
    LANCE = (160, 140, 80, 255)       # 枪杆木色
    LANCE_H = (200, 180, 110, 255)    # 枪杆高光
    LANCE_TIP = (200, 205, 215, 255)  # 枪尖金属
    OUTLINE = (20, 25, 10, 255)

    oy = offset_y
    return [
        # 头部
        (7, 2+oy, OUTLINE), (8, 2+oy, OUTLINE),
        (6, 3+oy, OUTLINE), (7, 3+oy, HAIR), (8, 3+oy, HAIR), (9, 3+oy, OUTLINE),
        (6, 4+oy, OUTLINE), (7, 4+oy, SKIN_L), (8, 4+oy, SKIN_L), (9, 4+oy, SKIN_D), (10, 4+oy, OUTLINE),
        (6, 5+oy, OUTLINE), (7, 5+oy, EYE), (8, 5+oy, SKIN_L), (9, 5+oy, EYE), (10, 5+oy, OUTLINE),
        (7, 6+oy, OUTLINE), (8, 6+oy, SKIN_D), (9, 6+oy, OUTLINE),

        # 身体（精瘦）
        (5, 7+oy, OUTLINE), (6, 7+oy, ARMOR_L), (7, 7+oy, ARMOR_L), (8, 7+oy, ARMOR), (9, 7+oy, ARMOR_D), (10, 7+oy, OUTLINE),
        (5, 8+oy, OUTLINE), (6, 8+oy, CLOAK), (7, 8+oy, ARMOR), (8, 8+oy, ARMOR_D), (9, 8+oy, CLOAK), (10, 8+oy, OUTLINE),
        (5, 9+oy, OUTLINE), (6, 9+oy, CLOAK), (7, 9+oy, ARMOR_D), (8, 9+oy, ARMOR_D), (9, 9+oy, CLOAK), (10, 9+oy, OUTLINE),

        # 长枪（从右侧举起）
        (11, 2+oy, LANCE_TIP),
        (11, 3+oy, LANCE_H), (11, 4+oy, LANCE_H),
        (11, 5+oy, LANCE), (11, 6+oy, LANCE), (11, 7+oy, LANCE), (11, 8+oy, LANCE),
        (11, 9+oy, LANCE), (11, 10+oy, LANCE),

        # 腿
        (6, 10+oy, OUTLINE), (7, 10+oy, ARMOR_D), (8, 10+oy, ARMOR_D), (9, 10+oy, OUTLINE),
        (6, 11+oy, OUTLINE), (7, 11+oy, ARMOR_D), (8, 11+oy, ARMOR_D), (9, 11+oy, OUTLINE),
        (6, 12+oy, OUTLINE), (7, 12+oy, ARMOR_D), (8, 12+oy, OUTLINE),
    ]

howland_frames = [
    howland_frame(0),
    howland_frame(1),
    howland_frame(0),
]
howland_img = make_spritesheet(howland_frames)
howland_img.save(os.path.join(OUTPUT_DIR, "howland_reed_map.png"))
print("生成: howland_reed_map.png")


# =========================================
# 王军士兵 —— 步兵 (红棕色调，敌方)
# =========================================
def royal_soldier_frame(offset_y=0):
    HAIR = (50, 30, 20, 255)
    ARMOR = (160, 50, 40, 255)        # 红色盔甲（兰尼斯特风格）
    ARMOR_L = (210, 80, 65, 255)      # 亮红面
    ARMOR_D = (110, 30, 20, 255)      # 暗红面
    HELM = (140, 40, 30, 255)         # 头盔红
    HELM_L = (190, 70, 55, 255)       # 头盔高光
    SPEAR = (160, 140, 80, 255)       # 矛杆
    SPEAR_TIP = (190, 195, 205, 255)  # 矛尖
    OUTLINE = (25, 10, 5, 255)

    oy = offset_y
    return [
        # 头盔（有盔缨）
        (8, 0+oy, ARMOR_L), (8, 0+oy, ARMOR_L),
        (7, 1+oy, HELM_L), (8, 1+oy, HELM_L), (9, 1+oy, HELM_L),
        (6, 2+oy, OUTLINE), (7, 2+oy, HELM_L), (8, 2+oy, HELM_L), (9, 2+oy, HELM), (10, 2+oy, OUTLINE),
        (5, 3+oy, OUTLINE), (6, 3+oy, HELM), (7, 3+oy, SKIN_L), (8, 3+oy, SKIN_L), (9, 3+oy, SKIN_D), (10, 3+oy, HELM), (11, 3+oy, OUTLINE),
        # 脸缝
        (5, 4+oy, OUTLINE), (6, 4+oy, HELM), (7, 4+oy, EYE), (8, 4+oy, SKIN_L), (9, 4+oy, EYE), (10, 4+oy, HELM_L), (11, 4+oy, OUTLINE),
        (6, 5+oy, OUTLINE), (7, 5+oy, SKIN_D), (8, 5+oy, SKIN_D), (9, 5+oy, HELM), (10, 5+oy, OUTLINE),

        # 身体
        (5, 6+oy, OUTLINE), (6, 6+oy, ARMOR_L), (7, 6+oy, ARMOR_L), (8, 6+oy, ARMOR), (9, 6+oy, ARMOR_D), (10, 6+oy, ARMOR_D), (11, 6+oy, OUTLINE),
        (5, 7+oy, OUTLINE), (6, 7+oy, ARMOR_L), (7, 7+oy, ARMOR), (8, 7+oy, ARMOR), (9, 7+oy, ARMOR_D), (10, 7+oy, ARMOR_D), (11, 7+oy, OUTLINE),
        (5, 8+oy, OUTLINE), (6, 8+oy, ARMOR), (7, 8+oy, ARMOR), (8, 8+oy, ARMOR_D), (9, 8+oy, ARMOR_D), (10, 8+oy, OUTLINE),
        (5, 9+oy, OUTLINE), (6, 9+oy, ARMOR_D), (7, 9+oy, ARMOR_D), (8, 9+oy, ARMOR_D), (9, 9+oy, ARMOR_D), (10, 9+oy, OUTLINE),

        # 矛（左侧竖举）
        (4, 1+oy, SPEAR_TIP),
        (4, 2+oy, SPEAR), (4, 3+oy, SPEAR), (4, 4+oy, SPEAR),
        (4, 5+oy, SPEAR), (4, 6+oy, SPEAR), (4, 7+oy, SPEAR),
        (4, 8+oy, SPEAR), (4, 9+oy, SPEAR), (4, 10+oy, SPEAR),

        # 腿
        (5, 10+oy, OUTLINE), (6, 10+oy, ARMOR_D), (7, 10+oy, ARMOR_D), (8, 10+oy, ARMOR_D), (9, 10+oy, OUTLINE),
        (5, 11+oy, OUTLINE), (6, 11+oy, ARMOR_D), (7, 11+oy, ARMOR_D), (8, 11+oy, ARMOR_D), (9, 11+oy, OUTLINE),
        (6, 12+oy, OUTLINE), (7, 12+oy, ARMOR_D), (8, 12+oy, OUTLINE),
    ]

royal_frames = [
    royal_soldier_frame(0),
    royal_soldier_frame(1),
    royal_soldier_frame(0),
]
royal_img = make_spritesheet(royal_frames)
royal_img.save(os.path.join(OUTPUT_DIR, "royal_soldier_map.png"))
print("生成: royal_soldier_map.png")

print("\n全部图标生成完成！保存到:", OUTPUT_DIR)
print("每个文件：48x16像素，含3帧（直立/行走/直立）")
