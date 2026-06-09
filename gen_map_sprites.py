from PIL import Image, ImageDraw
import os

OUTPUT_DIR = os.path.expanduser("~/Desktop/iron-throne-tactics/game/冰与火/assets/units/")
os.makedirs(OUTPUT_DIR, exist_ok=True)

T = (0, 0, 0, 0)
SKIN_L  = (255, 220, 170, 255)
SKIN_M  = (230, 185, 130, 255)
SKIN_D  = (195, 150, 100, 255)
EYE     = (55, 35, 15, 255)
OUTLINE = (18, 12, 8, 255)


def px(img, x, y, c):
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), c)


def fill_rect(img, x, y, w, h, c):
    for dy in range(h):
        for dx in range(w):
            px(img, x + dx, y + dy, c)


def outline_rect(img, x, y, w, h, c):
    for dx in range(w):
        px(img, x + dx, y,         c)
        px(img, x + dx, y + h - 1, c)
    for dy in range(h):
        px(img, x,         y + dy, c)
        px(img, x + w - 1, y + dy, c)


# =============================================================
# NED STARK  32x32  map sprite
# =============================================================
def draw_ned_32(img, ox, oy, walk=False):
    H   = (48, 38, 25, 255)
    HL  = (75, 60, 40, 255)
    A   = (88, 108, 138, 255)
    AL  = (118, 142, 172, 255)
    AD  = (58, 72,  98,  255)
    CL  = (65, 82, 108, 255)
    CLD = (45, 58,  80, 255)
    SW  = (195, 200, 215, 255)
    SWH = (235, 240, 255, 255)
    BT  = (48, 38, 30, 255)
    BTD = (30, 22, 15, 255)

    yo = 1 if walk else 0

    # ---- hair top ----
    for dx in range(5):
        px(img, ox+14+dx, oy+2, H)
    px(img, ox+13, oy+2, OUTLINE); px(img, ox+19, oy+2, OUTLINE)
    px(img, ox+13, oy+3, OUTLINE); px(img, ox+14, oy+3, H)
    px(img, ox+15, oy+3, HL); px(img, ox+16, oy+3, HL)
    px(img, ox+17, oy+3, H); px(img, ox+18, oy+3, H); px(img, ox+19, oy+3, OUTLINE)

    # ---- head ----
    for dx in range(7):
        px(img, ox+13+dx, oy+4, OUTLINE if dx==0 or dx==6 else (H if dx<2 else SKIN_L))
    # row 5
    px(img, ox+12, oy+5, OUTLINE)
    px(img, ox+13, oy+5, SKIN_L); px(img, ox+14, oy+5, SKIN_L)
    px(img, ox+15, oy+5, SKIN_L); px(img, ox+16, oy+5, SKIN_L)
    px(img, ox+17, oy+5, SKIN_M); px(img, ox+18, oy+5, SKIN_D)
    px(img, ox+19, oy+5, OUTLINE)
    # eyes row 6
    px(img, ox+12, oy+6, OUTLINE)
    px(img, ox+13, oy+6, SKIN_L); px(img, ox+14, oy+6, EYE)
    px(img, ox+15, oy+6, SKIN_L); px(img, ox+16, oy+6, SKIN_L)
    px(img, ox+17, oy+6, EYE);    px(img, ox+18, oy+6, SKIN_D)
    px(img, ox+19, oy+6, OUTLINE)
    # mouth row 7
    px(img, ox+12, oy+7, OUTLINE)
    px(img, ox+13, oy+7, SKIN_M); px(img, ox+14, oy+7, SKIN_D)
    px(img, ox+15, oy+7, SKIN_M); px(img, ox+16, oy+7, SKIN_M)
    px(img, ox+17, oy+7, SKIN_D); px(img, ox+18, oy+7, SKIN_D)
    px(img, ox+19, oy+7, OUTLINE)
    # neck row 8
    px(img, ox+14, oy+8, OUTLINE); px(img, ox+15, oy+8, SKIN_D)
    px(img, ox+16, oy+8, SKIN_D);  px(img, ox+17, oy+8, OUTLINE)

    # ---- shoulders / upper body ----
    # pauldrons row 9
    fill_rect(img, ox+10, oy+9, 2, 2, AL)
    px(img, ox+9,  oy+9,  OUTLINE); px(img, ox+12, oy+9, OUTLINE)
    px(img, ox+9,  oy+10, OUTLINE); px(img, ox+12, oy+10, OUTLINE)
    fill_rect(img, ox+19, oy+9, 2, 2, AD)
    px(img, ox+18, oy+9,  OUTLINE); px(img, ox+21, oy+9,  OUTLINE)
    px(img, ox+18, oy+10, OUTLINE); px(img, ox+21, oy+10, OUTLINE)
    # chest row 9-12
    px(img, ox+11, oy+9, OUTLINE)
    for dx in range(8):
        px(img, ox+12+dx, oy+9,  AL if dx<4 else A)
    px(img, ox+20, oy+9, OUTLINE)
    for dx in range(8):
        px(img, ox+12+dx, oy+10, AL if dx<3 else A)
    for dx in range(8):
        px(img, ox+12+dx, oy+11, A  if dx<3 else AD)
    for dx in range(8):
        px(img, ox+12+dx, oy+12, AD)
    px(img, ox+11, oy+10, CL); px(img, ox+11, oy+11, CL); px(img, ox+11, oy+12, CLD)
    px(img, ox+20, oy+10, CL); px(img, ox+20, oy+11, CLD); px(img, ox+20, oy+12, CLD)
    # outline sides
    for row in range(9, 13):
        px(img, ox+10, oy+row, OUTLINE); px(img, ox+21, oy+row, OUTLINE)

    # ---- cloak / waist ----
    for dx in range(10):
        px(img, ox+11+dx, oy+13, CL if dx<2 or dx>7 else AD)
    px(img, ox+10, oy+13, OUTLINE); px(img, ox+21, oy+13, OUTLINE)
    for dx in range(10):
        px(img, ox+11+dx, oy+14, CLD if dx<2 or dx>7 else AD)
    px(img, ox+10, oy+14, OUTLINE); px(img, ox+21, oy+14, OUTLINE)

    # ---- sword right side ----
    px(img, ox+22, oy+7, SWH); px(img, ox+23, oy+6, SWH)
    px(img, ox+22, oy+8, SW);  px(img, ox+23, oy+7, SWH)
    px(img, ox+23, oy+8, SW);  px(img, ox+24, oy+5, SWH)
    px(img, ox+24, oy+6, SW);  px(img, ox+25, oy+4, SWH)
    # guard
    px(img, ox+21, oy+9, A); px(img, ox+22, oy+9, AL)

    # ---- legs ----
    base = oy + 15 + yo
    # left leg
    for row in range(5):
        fill_rect(img, ox+12, base+row, 4, 1, AD if row < 3 else BT)
    px(img, ox+11, base, OUTLINE); px(img, ox+16, base, OUTLINE)
    px(img, ox+11, base+1, OUTLINE); px(img, ox+16, base+1, OUTLINE)
    px(img, ox+11, base+2, OUTLINE); px(img, ox+16, base+2, OUTLINE)
    # right leg
    for row in range(5):
        fill_rect(img, ox+17, base+row, 4, 1, CLD if row < 3 else BTD)
    px(img, ox+16, base, OUTLINE)
    px(img, ox+21, base, OUTLINE); px(img, ox+21, base+1, OUTLINE)
    px(img, ox+21, base+2, OUTLINE)
    # boots
    fill_rect(img, ox+12, base+3, 4, 2, BT)
    fill_rect(img, ox+17, base+3, 4, 2, BTD)
    px(img, ox+11, base+4, OUTLINE); px(img, ox+16, base+4, OUTLINE)
    px(img, ox+16, base+4, OUTLINE); px(img, ox+21, base+4, OUTLINE)


def make_ned_map():
    img = Image.new("RGBA", (96, 32), T)
    draw_ned_32(img,  0, 0, walk=False)
    draw_ned_32(img, 32, 0, walk=True)
    draw_ned_32(img, 64, 0, walk=False)
    return img


# =============================================================
# ROBERT BARATHEON  32x32  map sprite
# =============================================================
def draw_robert_32(img, ox, oy, walk=False):
    A   = (175, 135, 28, 255)
    AL  = (225, 190, 75, 255)
    AD  = (115, 85,  10, 255)
    HM  = (155, 115, 18, 255)
    HML = (205, 170, 58, 255)
    BD  = (42,  28,  12, 255)
    BT  = (35,  25,   8, 255)
    BTD = (22,  14,   4, 255)
    ANTLER = (210, 175, 60, 255)

    yo = 1 if walk else 0

    # ---- helm ----
    fill_rect(img, ox+12, oy+1, 8, 1, HML)
    px(img, ox+11, oy+1, OUTLINE); px(img, ox+20, oy+1, OUTLINE)
    fill_rect(img, ox+11, oy+2, 10, 1, HML)
    px(img, ox+10, oy+2, OUTLINE); px(img, ox+21, oy+2, OUTLINE)
    fill_rect(img, ox+11, oy+3, 10, 1, HM)
    px(img, ox+10, oy+3, OUTLINE); px(img, ox+21, oy+3, OUTLINE)
    # antlers on helm
    px(img, ox+9,  oy+1, ANTLER); px(img, ox+8,  oy+2, ANTLER)
    px(img, ox+9,  oy+2, ANTLER); px(img, ox+8,  oy+3, ANTLER)
    px(img, ox+22, oy+1, ANTLER); px(img, ox+23, oy+2, ANTLER)
    px(img, ox+22, oy+2, ANTLER); px(img, ox+23, oy+3, ANTLER)
    # ---- face row 4 ----
    px(img, ox+10, oy+4, OUTLINE)
    fill_rect(img, ox+11, oy+4, 2, 1, HM)
    fill_rect(img, ox+13, oy+4, 6, 1, SKIN_L)
    fill_rect(img, ox+19, oy+4, 2, 1, HM)
    px(img, ox+21, oy+4, OUTLINE)
    # eyes row 5
    px(img, ox+10, oy+5, OUTLINE)
    px(img, ox+11, oy+5, HM);      px(img, ox+12, oy+5, HM)
    px(img, ox+13, oy+5, EYE);     px(img, ox+14, oy+5, SKIN_L)
    px(img, ox+15, oy+5, SKIN_L);  px(img, ox+16, oy+5, SKIN_L)
    px(img, ox+17, oy+5, EYE);     px(img, ox+18, oy+5, SKIN_M)
    px(img, ox+19, oy+5, HM);      px(img, ox+20, oy+5, HML)
    px(img, ox+21, oy+5, OUTLINE)
    # beard row 6-7
    px(img, ox+10, oy+6, OUTLINE)
    for dx in range(10):
        px(img, ox+11+dx, oy+6, BD if dx<2 or dx>7 else SKIN_M)
    px(img, ox+21, oy+6, OUTLINE)
    px(img, ox+10, oy+7, OUTLINE)
    for dx in range(10):
        px(img, ox+11+dx, oy+7, BD)
    px(img, ox+21, oy+7, OUTLINE)

    # ---- wide shoulders / chest ----
    for row in range(8, 13):
        left  = 8  + (row - 8)
        right = 24 - (row - 8)
        fill_rect(img, ox+left, oy+row, right-left, 1, A)
        if row == 8:
            fill_rect(img, ox+left, oy+row, 4, 1, AL)
        px(img, ox+left-1,  oy+row, OUTLINE)
        px(img, ox+right, oy+row, OUTLINE)
    # chest detail
    fill_rect(img, ox+12, oy+9,  8, 1, AL)
    fill_rect(img, ox+12, oy+10, 6, 1, A)
    fill_rect(img, ox+18, oy+10, 2, 1, AD)
    fill_rect(img, ox+12, oy+11, 4, 1, AD)
    fill_rect(img, ox+16, oy+11, 4, 1, AD)
    # waist
    fill_rect(img, ox+11, oy+13, 10, 2, AD)
    px(img, ox+10, oy+13, OUTLINE); px(img, ox+21, oy+13, OUTLINE)
    px(img, ox+10, oy+14, OUTLINE); px(img, ox+21, oy+14, OUTLINE)

    # ---- legs (thick) ----
    base = oy + 15 + yo
    fill_rect(img, ox+11, base,   5, 5, AD)
    fill_rect(img, ox+17, base,   5, 5, AD)
    for row in range(5):
        px(img, ox+10,  base+row, OUTLINE)
        px(img, ox+16,  base+row, OUTLINE)
        px(img, ox+22,  base+row, OUTLINE)
    # boots
    fill_rect(img, ox+11, base+3, 5, 2, BT)
    fill_rect(img, ox+17, base+3, 5, 2, BTD)
    for row in range(3, 5):
        px(img, ox+10,  base+row, OUTLINE)
        px(img, ox+16,  base+row, OUTLINE)
        px(img, ox+22,  base+row, OUTLINE)


def make_robert_map():
    img = Image.new("RGBA", (96, 32), T)
    draw_robert_32(img,  0, 0, walk=False)
    draw_robert_32(img, 32, 0, walk=True)
    draw_robert_32(img, 64, 0, walk=False)
    return img


# =============================================================
# HOWLAND REED  32x32  map sprite
# =============================================================
def draw_howland_32(img, ox, oy, walk=False):
    H   = (58, 75, 38, 255)
    HL  = (85, 108, 58, 255)
    A   = (65, 95, 55, 255)
    AL  = (95, 128, 75, 255)
    AD  = (42, 62,  32, 255)
    CL  = (50, 75, 42, 255)
    CLD = (32, 50, 25, 255)
    LN  = (155, 135, 72, 255)
    LNH = (195, 175, 105, 255)
    LT  = (195, 200, 210, 255)
    BT  = (45, 35, 25, 255)

    yo = 1 if walk else 0

    # ---- hair / head ----
    fill_rect(img, ox+14, oy+2, 5, 1, H)
    px(img, ox+13, oy+2, OUTLINE); px(img, ox+19, oy+2, OUTLINE)
    px(img, ox+13, oy+3, OUTLINE)
    px(img, ox+14, oy+3, H); px(img, ox+15, oy+3, HL)
    px(img, ox+16, oy+3, HL); px(img, ox+17, oy+3, H); px(img, ox+18, oy+3, H)
    px(img, ox+19, oy+3, OUTLINE)

    px(img, ox+13, oy+4, OUTLINE)
    for dx in range(6):
        px(img, ox+14+dx, oy+4, SKIN_L if dx<4 else SKIN_M)
    px(img, ox+20, oy+4, OUTLINE)

    px(img, ox+13, oy+5, OUTLINE)
    px(img, ox+14, oy+5, SKIN_L); px(img, ox+15, oy+5, EYE)
    px(img, ox+16, oy+5, SKIN_L); px(img, ox+17, oy+5, SKIN_L)
    px(img, ox+18, oy+5, EYE);    px(img, ox+19, oy+5, SKIN_M)
    px(img, ox+20, oy+5, OUTLINE)

    px(img, ox+13, oy+6, OUTLINE)
    px(img, ox+14, oy+6, SKIN_M); px(img, ox+15, oy+6, SKIN_D)
    px(img, ox+16, oy+6, SKIN_M); px(img, ox+17, oy+6, SKIN_M)
    px(img, ox+18, oy+6, SKIN_D); px(img, ox+19, oy+6, SKIN_D)
    px(img, ox+20, oy+6, OUTLINE)

    px(img, ox+14, oy+7, OUTLINE); px(img, ox+15, oy+7, SKIN_D)
    px(img, ox+16, oy+7, SKIN_D);  px(img, ox+17, oy+7, OUTLINE)

    # ---- lean body ----
    for row in range(8, 13):
        px(img, ox+12, oy+row, OUTLINE)
        fill_rect(img, ox+13, oy+row, 7, 1, AL if row < 10 else A)
        fill_rect(img, ox+17, oy+row, 3, 1, AD)
        px(img, ox+11, oy+row, CL)
        px(img, ox+20, oy+row, CLD)
        px(img, ox+21, oy+row, OUTLINE)
    # waist/belt
    fill_rect(img, ox+12, oy+13, 9, 2, CLD)
    px(img, ox+11, oy+13, OUTLINE); px(img, ox+21, oy+13, OUTLINE)
    px(img, ox+11, oy+14, OUTLINE); px(img, ox+21, oy+14, OUTLINE)

    # ---- lance (right side, angled) ----
    px(img, ox+22, oy+1, LT); px(img, ox+23, oy+0, LT)
    px(img, ox+22, oy+2, LNH); px(img, ox+22, oy+3, LNH)
    for row in range(4, 15):
        px(img, ox+22, oy+row, LN)
    px(img, ox+22, oy+15, LN)

    # ---- legs ----
    base = oy + 15 + yo
    fill_rect(img, ox+13, base,   4, 5, AD)
    fill_rect(img, ox+18, base,   4, 5, CLD)
    for row in range(5):
        px(img, ox+12, base+row, OUTLINE)
        px(img, ox+17, base+row, OUTLINE)
        px(img, ox+22, base+row, OUTLINE)
    # boots
    fill_rect(img, ox+13, base+3, 4, 2, BT)
    fill_rect(img, ox+18, base+3, 4, 2, BT)
    for row in range(3, 5):
        px(img, ox+12, base+row, OUTLINE)
        px(img, ox+17, base+row, OUTLINE)
        px(img, ox+22, base+row, OUTLINE)


def make_howland_map():
    img = Image.new("RGBA", (96, 32), T)
    draw_howland_32(img,  0, 0, walk=False)
    draw_howland_32(img, 32, 0, walk=True)
    draw_howland_32(img, 64, 0, walk=False)
    return img


# =============================================================
# ROYAL SOLDIER  32x32  map sprite
# =============================================================
def draw_royal_32(img, ox, oy, walk=False):
    A   = (155, 45, 35, 255)
    AL  = (205, 75, 60, 255)
    AD  = (105, 25, 15, 255)
    HM  = (135, 35, 25, 255)
    HML = (185, 65, 50, 255)
    PLUME = (220, 30, 20, 255)
    SP  = (155, 135, 72, 255)
    SPT = (185, 190, 200, 255)
    BT  = (40, 30, 20, 255)

    yo = 1 if walk else 0

    # ---- plume ----
    for row in range(3):
        px(img, ox+15, oy+row, PLUME)
        px(img, ox+16, oy+row, PLUME)

    # ---- helm ----
    fill_rect(img, ox+12, oy+3, 8, 1, HML)
    px(img, ox+11, oy+3, OUTLINE); px(img, ox+20, oy+3, OUTLINE)
    fill_rect(img, ox+11, oy+4, 10, 2, HM)
    px(img, ox+10, oy+4, OUTLINE); px(img, ox+21, oy+4, OUTLINE)
    px(img, ox+10, oy+5, OUTLINE); px(img, ox+21, oy+5, OUTLINE)
    # visor slit row 5
    px(img, ox+13, oy+5, OUTLINE); px(img, ox+14, oy+5, OUTLINE)
    px(img, ox+17, oy+5, OUTLINE); px(img, ox+18, oy+5, OUTLINE)
    # chin guard row 6
    fill_rect(img, ox+12, oy+6, 8, 2, HM)
    px(img, ox+11, oy+6, OUTLINE); px(img, ox+20, oy+6, OUTLINE)
    px(img, ox+11, oy+7, OUTLINE); px(img, ox+20, oy+7, OUTLINE)

    # ---- chest ----
    for row in range(8, 13):
        px(img, ox+10, oy+row, OUTLINE)
        fill_rect(img, ox+11, oy+row, 4, 1, AL)
        fill_rect(img, ox+15, oy+row, 4, 1, A)
        fill_rect(img, ox+19, oy+row, 2, 1, AD)
        px(img, ox+21, oy+row, OUTLINE)
    # belt row 13-14
    fill_rect(img, ox+11, oy+13, 10, 2, AD)
    px(img, ox+10, oy+13, OUTLINE); px(img, ox+21, oy+13, OUTLINE)
    px(img, ox+10, oy+14, OUTLINE); px(img, ox+21, oy+14, OUTLINE)

    # ---- spear (left side) ----
    px(img, ox+8, oy+0, SPT); px(img, ox+9, oy+0, SPT)
    px(img, ox+8, oy+1, SP);  px(img, ox+9, oy+1, SP)
    for row in range(2, 16):
        px(img, ox+9, oy+row, SP)

    # ---- legs ----
    base = oy + 15 + yo
    fill_rect(img, ox+11, base,   5, 5, AD)
    fill_rect(img, ox+17, base,   5, 5, A)
    for row in range(5):
        px(img, ox+10, base+row, OUTLINE)
        px(img, ox+16, base+row, OUTLINE)
        px(img, ox+22, base+row, OUTLINE)
    # boots
    fill_rect(img, ox+11, base+3, 5, 2, BT)
    fill_rect(img, ox+17, base+3, 5, 2, BT)
    for row in range(3, 5):
        px(img, ox+10, base+row, OUTLINE)
        px(img, ox+16, base+row, OUTLINE)
        px(img, ox+22, base+row, OUTLINE)


def make_royal_map():
    img = Image.new("RGBA", (96, 32), T)
    draw_royal_32(img,  0, 0, walk=False)
    draw_royal_32(img, 32, 0, walk=True)
    draw_royal_32(img, 64, 0, walk=False)
    return img


# =============================================================
# PORTRAITS  48x48
# =============================================================

def draw_base_head(img, cx, top, hair_c, hair_h, has_helm=False, helm_c=None, helm_l=None):
    if has_helm:
        fill_rect(img, cx-6, top,    12, 3, helm_l)
        px(img, cx-7, top,   OUTLINE); px(img, cx+6, top,   OUTLINE)
        fill_rect(img, cx-7, top+3,  14, 5, helm_c)
        px(img, cx-8, top+3, OUTLINE); px(img, cx+7, top+3, OUTLINE)
        px(img, cx-8, top+4, OUTLINE); px(img, cx+7, top+4, OUTLINE)
        px(img, cx-8, top+5, OUTLINE); px(img, cx+7, top+5, OUTLINE)
        px(img, cx-8, top+6, OUTLINE); px(img, cx+7, top+6, OUTLINE)
        px(img, cx-8, top+7, OUTLINE); px(img, cx+7, top+7, OUTLINE)
    else:
        fill_rect(img, cx-5, top,    10, 2, hair_h)
        px(img, cx-6, top,   OUTLINE); px(img, cx+5, top,   OUTLINE)
        fill_rect(img, cx-6, top+2,  12, 1, hair_c)
        px(img, cx-7, top+2, OUTLINE); px(img, cx+6, top+2, OUTLINE)
        fill_rect(img, cx-7, top+3,  14, 5, SKIN_L)
        px(img, cx-8, top+3, OUTLINE); px(img, cx+7, top+3, OUTLINE)
        for row in range(3, 8):
            px(img, cx-8, top+row, OUTLINE)
            px(img, cx+7, top+row, OUTLINE)


def draw_eyes(img, cx, row):
    px(img, cx-4, row, EYE); px(img, cx-3, row, EYE)
    px(img, cx+2, row, EYE); px(img, cx+3, row, EYE)
    px(img, cx-5, row, SKIN_L); px(img, cx-2, row, SKIN_L)
    px(img, cx-1, row, SKIN_L); px(img, cx+0, row, SKIN_L)
    px(img, cx+1, row, SKIN_L); px(img, cx+4, row, SKIN_L)


def make_ned_portrait():
    img = Image.new("RGBA", (48, 48), T)
    H  = (48, 38, 25, 255)
    HL = (75, 60, 40, 255)
    A  = (88, 108, 138, 255)
    AL = (118, 142, 172, 255)
    AD = (58, 72, 98, 255)
    CL = (65, 82, 108, 255)
    SW = (195, 200, 215, 255)
    SWH= (235, 240, 255, 255)
    WP = (80, 60, 40, 255)
    EMBLEM = (200, 210, 220, 255)

    cx = 24

    # --- hair ---
    fill_rect(img, cx-7, 2, 14, 2, H)
    for dx in range(-6, 7): px(img, cx+dx, 2, HL if -3<=dx<=3 else H)
    px(img, cx-8, 2, OUTLINE); px(img, cx+7, 2, OUTLINE)
    px(img, cx-8, 3, OUTLINE); px(img, cx+7, 3, OUTLINE)

    # --- forehead ---
    fill_rect(img, cx-8, 4, 16, 3, SKIN_L)
    for row in range(4, 7):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)

    # --- eyes row 7 ---
    fill_rect(img, cx-8, 7, 16, 2, SKIN_L)
    px(img, cx-9, 7, OUTLINE); px(img, cx+8, 7, OUTLINE)
    px(img, cx-9, 8, OUTLINE); px(img, cx+8, 8, OUTLINE)
    draw_eyes(img, cx, 7)
    # brow
    px(img, cx-5, 6, H); px(img, cx-4, 6, H)
    px(img, cx+3, 6, H); px(img, cx+4, 6, H)

    # --- mid face ---
    fill_rect(img, cx-8, 9, 16, 3, SKIN_L)
    for row in range(9, 12):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    # nose
    px(img, cx-1, 10, SKIN_D); px(img, cx, 10, SKIN_D); px(img, cx+1, 10, SKIN_D)
    # mouth
    px(img, cx-3, 11, SKIN_M); px(img, cx-2, 11, (130,90,70,255))
    px(img, cx-1, 11, (130,90,70,255)); px(img, cx, 11, SKIN_M)
    px(img, cx+1, 11, (130,90,70,255)); px(img, cx+2, 11, SKIN_M)

    # --- chin/jaw ---
    fill_rect(img, cx-7, 12, 14, 2, SKIN_M)
    for row in range(12, 14):
        px(img, cx-8, row, OUTLINE); px(img, cx+7, row, OUTLINE)

    # --- neck ---
    fill_rect(img, cx-3, 14, 6, 2, SKIN_D)
    px(img, cx-4, 14, OUTLINE); px(img, cx+3, 14, OUTLINE)
    px(img, cx-4, 15, OUTLINE); px(img, cx+3, 15, OUTLINE)

    # --- pauldrons ---
    fill_rect(img, 0,    16, 12, 8, AL)
    fill_rect(img, 36,   16, 12, 8, AD)
    px(img, 0, 16, OUTLINE); px(img, 47, 16, OUTLINE)
    for row in range(16, 24):
        px(img, 0, row, OUTLINE); px(img, 47, row, OUTLINE)

    # --- chest ----
    fill_rect(img, 12,  16, 24, 8, A)
    fill_rect(img, 12,  16,  8, 4, AL)
    fill_rect(img, 28,  16,  8, 4, AD)
    # chest line
    for row in range(16, 24):
        px(img, 11, row, OUTLINE); px(img, 36, row, OUTLINE)

    # --- emblem (direwolf outline on chest) ---
    for dx in [-1,0,1]:
        px(img, cx+dx, 18, EMBLEM)
    px(img, cx-2, 19, EMBLEM); px(img, cx+2, 19, EMBLEM)
    px(img, cx-3, 20, EMBLEM); px(img, cx+3, 20, EMBLEM)
    px(img, cx-2, 21, EMBLEM); px(img, cx-1, 21, EMBLEM)
    px(img, cx+1, 21, EMBLEM); px(img, cx+2, 21, EMBLEM)

    # --- gorget / neck armor ---
    fill_rect(img, cx-5, 24, 10, 3, CL)
    for row in range(24, 27):
        px(img, cx-6, row, OUTLINE); px(img, cx+5, row, OUTLINE)

    # --- sword hilt (left side) ---
    fill_rect(img, 2, 22, 4, 2, WP)
    fill_rect(img, 0, 21, 8, 1, SW)
    fill_rect(img, 2, 23, 4, 10, SW)
    px(img, 3, 23, SWH); px(img, 3, 24, SWH)

    # --- lower body hint ---
    fill_rect(img, 10, 27, 28, 12, AD)
    fill_rect(img, 10, 27, 10, 12, AL)
    fill_rect(img, 28, 27, 10, 12, AD)
    for row in range(27, 39):
        px(img, 9, row, OUTLINE); px(img, 38, row, OUTLINE)
    # cloak sides
    fill_rect(img, 0, 27, 9, 21, CL)
    fill_rect(img, 39, 27, 9, 21, CL)
    for row in range(27, 48):
        px(img, 0, row, OUTLINE if row<48 else T)

    # --- hair long sides ---
    fill_rect(img, 0, 4, 3, 20, H)
    fill_rect(img, 45, 4, 3, 20, H)

    return img


def make_robert_portrait():
    img = Image.new("RGBA", (48, 48), T)
    A  = (175, 135, 28, 255)
    AL = (225, 190, 75, 255)
    AD = (115, 85, 10, 255)
    HM = (155, 115, 18, 255)
    HML= (205, 170, 58, 255)
    BD = (38, 24, 10, 255)
    BDL= (65, 45, 20, 255)
    ANG= (210, 175, 60, 255)

    cx = 24

    # --- helm top ---
    fill_rect(img, cx-5, 1, 10, 1, HML)
    px(img, cx-6, 1, OUTLINE); px(img, cx+5, 1, OUTLINE)
    fill_rect(img, cx-7, 2, 14, 2, HML)
    px(img, cx-8, 2, OUTLINE); px(img, cx+7, 2, OUTLINE)
    px(img, cx-8, 3, OUTLINE); px(img, cx+7, 3, OUTLINE)

    # antlers
    px(img, cx-9, 1, ANG); px(img, cx-10, 0, ANG); px(img, cx-10, 1, ANG)
    px(img, cx-11, 0, ANG); px(img, cx-9, 2, ANG)
    px(img, cx+9, 1, ANG); px(img, cx+10, 0, ANG); px(img, cx+10, 1, ANG)
    px(img, cx+11, 0, ANG); px(img, cx+9, 2, ANG)

    # --- helm main ---
    fill_rect(img, cx-8, 4, 16, 5, HM)
    for row in range(4, 9):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    # eye slot row 6
    for dx in range(-5, -2):
        px(img, cx+dx, 6, OUTLINE)
    for dx in range(2, 6):
        px(img, cx+dx, 6, OUTLINE)
    px(img, cx-2, 6, SKIN_M); px(img, cx-1, 6, EYE)
    px(img, cx,   6, EYE);   px(img, cx+1,  6, EYE)

    # --- cheeks / beard ---
    fill_rect(img, cx-8, 9, 16, 6, BD)
    for row in range(9, 15):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    # cheeks lighter
    fill_rect(img, cx-7, 9, 5, 3, BDL)
    fill_rect(img, cx+2, 9, 5, 3, BD)
    # mustache highlight
    px(img, cx-2, 10, BDL); px(img, cx-1, 10, BDL)
    px(img, cx, 10, BDL);   px(img, cx+1, 10, BDL)
    # chin
    fill_rect(img, cx-5, 14, 10, 2, BD)
    px(img, cx-6, 14, OUTLINE); px(img, cx+5, 14, OUTLINE)
    px(img, cx-6, 15, OUTLINE); px(img, cx+5, 15, OUTLINE)

    # --- neck ---
    fill_rect(img, cx-3, 16, 6, 2, SKIN_D)
    for row in range(16, 18):
        px(img, cx-4, row, OUTLINE); px(img, cx+3, row, OUTLINE)

    # --- massive pauldrons ---
    fill_rect(img, 0,   18, 14, 10, AL)
    fill_rect(img, 34,  18, 14, 10, AD)
    for row in range(18, 28):
        px(img, 0, row, OUTLINE); px(img, 47, row, OUTLINE)

    # --- chest ---
    fill_rect(img, 14, 18, 20, 10, A)
    fill_rect(img, 14, 18,  8,  5, AL)
    fill_rect(img, 30, 18,  4,  5, AD)
    for row in range(18, 28):
        px(img, 13, row, OUTLINE); px(img, 34, row, OUTLINE)

    # stag emblem
    px(img, cx-1, 21, ANG); px(img, cx, 21, ANG); px(img, cx+1, 21, ANG)
    px(img, cx-2, 22, ANG); px(img, cx+2, 22, ANG)
    px(img, cx-3, 23, ANG); px(img, cx+3, 23, ANG)
    px(img, cx-2, 24, ANG); px(img, cx, 24, ANG); px(img, cx+2, 24, ANG)

    # --- lower torso ---
    fill_rect(img, 10, 28, 28, 10, AD)
    fill_rect(img, 10, 28, 10,  5, A)
    for row in range(28, 38):
        px(img, 9, row, OUTLINE); px(img, 38, row, OUTLINE)
    # warhammer hint bottom left
    fill_rect(img, 0, 32, 8, 4, AD)
    fill_rect(img, 0, 30, 6, 2, (140, 100, 20, 255))
    for row in range(30, 36):
        px(img, 0, row, OUTLINE)

    # bottom fill
    fill_rect(img, 8, 38, 32, 10, AD)
    for row in range(38, 48):
        px(img, 7, row, OUTLINE); px(img, 40, row, OUTLINE)

    return img


def make_howland_portrait():
    img = Image.new("RGBA", (48, 48), T)
    H  = (55, 72, 35, 255)
    HL = (82, 105, 55, 255)
    A  = (62, 92, 52, 255)
    AL = (92, 125, 72, 255)
    AD = (40, 60, 30, 255)
    CL = (48, 72, 40, 255)
    LN = (152, 132, 70, 255)
    LNH= (192, 172, 102, 255)
    LT = (192, 198, 208, 255)
    FACE_M = (225, 180, 125, 255)

    cx = 24

    # --- hair ---
    fill_rect(img, cx-7, 1, 14, 3, H)
    for dx in range(-5, 6): px(img, cx+dx, 1, HL if -2<=dx<=2 else H)
    for row in range(1, 4):
        px(img, cx-8, row, OUTLINE); px(img, cx+7, row, OUTLINE)
    # hair sides long
    fill_rect(img, 0, 4, 4, 16, H)
    fill_rect(img, 44, 4, 4, 16, H)
    for row in range(4, 20):
        px(img, 0, row, OUTLINE); px(img, 47, row, OUTLINE)

    # --- forehead ---
    fill_rect(img, cx-8, 4, 16, 3, SKIN_L)
    for row in range(4, 7):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    # brow
    px(img, cx-5, 5, H); px(img, cx-4, 5, H)
    px(img, cx+3, 5, H); px(img, cx+4, 5, H)

    # --- eyes ---
    fill_rect(img, cx-8, 7, 16, 2, SKIN_L)
    for row in range(7, 9):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    draw_eyes(img, cx, 7)
    # war paint under eyes (reed style)
    px(img, cx-4, 9, (60, 80, 40, 200)); px(img, cx-3, 9, (60, 80, 40, 200))
    px(img, cx+2, 9, (60, 80, 40, 200)); px(img, cx+3, 9, (60, 80, 40, 200))

    # --- mid face ---
    fill_rect(img, cx-8, 9, 16, 4, SKIN_L)
    for row in range(9, 13):
        px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    px(img, cx, 10, SKIN_D); px(img, cx-1, 10, SKIN_D)
    px(img, cx-2, 12, (125, 85, 65, 255))
    px(img, cx-1, 12, (110, 70, 50, 255))
    px(img, cx+1, 12, (110, 70, 50, 255))
    px(img, cx+2, 12, (125, 85, 65, 255))

    # --- jaw ---
    fill_rect(img, cx-7, 13, 14, 3, SKIN_M)
    for row in range(13, 16):
        px(img, cx-8, row, OUTLINE); px(img, cx+7, row, OUTLINE)

    # --- neck ---
    fill_rect(img, cx-3, 16, 6, 2, SKIN_D)
    for row in range(16, 18): px(img, cx-4, row, OUTLINE); px(img, cx+3, row, OUTLINE)

    # --- leather pauldrons ---
    fill_rect(img, 0,   18, 12, 8, AL)
    fill_rect(img, 36,  18, 12, 8, AD)
    for row in range(18, 26):
        px(img, 0, row, OUTLINE); px(img, 47, row, OUTLINE)

    # --- chest leather ---
    fill_rect(img, 12, 18, 24, 10, A)
    fill_rect(img, 12, 18,  8,  5, AL)
    fill_rect(img, 28, 18,  6,  5, AD)
    for row in range(18, 28):
        px(img, 11, row, OUTLINE); px(img, 36, row, OUTLINE)
    # leather strap details
    for row in range(19, 28, 3):
        px(img, cx-3, row, AD); px(img, cx+2, row, AD)

    # --- waist / lower body ---
    fill_rect(img, 10, 28, 28, 10, AD)
    fill_rect(img, 10, 28, 8, 5, A)
    for row in range(28, 38):
        px(img, 9, row, OUTLINE); px(img, 38, row, OUTLINE)

    # --- lance (right side prominent) ---
    fill_rect(img, 40, 0, 3, 2, LT)
    fill_rect(img, 40, 2, 3, 3, LNH)
    for row in range(5, 48):
        px(img, 41, row, LN)
        if row < 20: px(img, 42, row, LNH)

    # --- lower fill ---
    fill_rect(img, 8, 38, 32, 10, CL)
    for row in range(38, 48):
        px(img, 7, row, OUTLINE); px(img, 40, row, OUTLINE)

    return img


def make_royal_portrait():
    img = Image.new("RGBA", (48, 48), T)
    A  = (155, 45, 35, 255)
    AL = (205, 75, 60, 255)
    AD = (105, 25, 15, 255)
    HM = (135, 35, 25, 255)
    HML= (185, 65, 50, 255)
    PL = (215, 28, 18, 255)
    SP = (152, 132, 70, 255)
    SPT= (182, 188, 198, 255)
    BT = (38, 28, 18, 255)

    cx = 24

    # --- plume ---
    fill_rect(img, cx-2, 0, 5, 4, PL)
    px(img, cx-3, 0, OUTLINE); px(img, cx+3, 0, OUTLINE)
    px(img, cx-3, 1, OUTLINE); px(img, cx+3, 1, OUTLINE)
    px(img, cx-3, 2, OUTLINE); px(img, cx+3, 2, OUTLINE)
    px(img, cx-3, 3, OUTLINE); px(img, cx+3, 3, OUTLINE)

    # --- helm top ---
    fill_rect(img, cx-7, 4, 14, 2, HML)
    for row in range(4, 6): px(img, cx-8, row, OUTLINE); px(img, cx+7, row, OUTLINE)
    # helm main
    fill_rect(img, cx-8, 6, 16, 6, HM)
    for row in range(6, 12): px(img, cx-9, row, OUTLINE); px(img, cx+8, row, OUTLINE)
    # visor row 8-9
    fill_rect(img, cx-6, 8, 12, 2, AD)
    px(img, cx-7, 8, OUTLINE); px(img, cx+6, 8, OUTLINE)
    px(img, cx-7, 9, OUTLINE); px(img, cx+6, 9, OUTLINE)
    # eye glow behind visor
    px(img, cx-4, 8, (80, 20, 10, 255)); px(img, cx-3, 8, (80, 20, 10, 255))
    px(img, cx+2, 8, (80, 20, 10, 255)); px(img, cx+3, 8, (80, 20, 10, 255))
    # chin guard
    fill_rect(img, cx-6, 12, 12, 3, HM)
    for row in range(12, 15): px(img, cx-7, row, OUTLINE); px(img, cx+6, row, OUTLINE)

    # --- gorget ---
    fill_rect(img, cx-5, 15, 10, 3, A)
    for row in range(15, 18): px(img, cx-6, row, OUTLINE); px(img, cx+5, row, OUTLINE)

    # --- massive pauldrons ---
    fill_rect(img, 0,   18, 13, 12, AL)
    fill_rect(img, 35,  18, 13, 12, AD)
    for row in range(18, 30):
        px(img, 0, row, OUTLINE); px(img, 47, row, OUTLINE)

    # --- chest plate ---
    fill_rect(img, 13, 18, 22, 12, A)
    fill_rect(img, 13, 18,  8,  6, AL)
    fill_rect(img, 29, 18,  6,  6, AD)
    for row in range(18, 30):
        px(img, 12, row, OUTLINE); px(img, 35, row, OUTLINE)
    # center line
    for row in range(18, 30): px(img, cx, row, AD)
    # rivets
    for row in range(20, 30, 3):
        px(img, cx-5, row, AL); px(img, cx+4, row, AL)

    # --- lower body ---
    fill_rect(img, 10, 30, 28, 8, AD)
    fill_rect(img, 10, 30, 10,  4, A)
    for row in range(30, 38):
        px(img, 9, row, OUTLINE); px(img, 38, row, OUTLINE)
    fill_rect(img, 8, 38, 32, 10, AD)
    for row in range(38, 48):
        px(img, 7, row, OUTLINE); px(img, 40, row, OUTLINE)

    # --- spear (left prominent) ---
    fill_rect(img, 2, 0, 3, 3, SPT)
    px(img, 1, 0, OUTLINE); px(img, 5, 0, OUTLINE)
    for row in range(3, 48): px(img, 3, row, SP); px(img, 4, row, SP)
    for row in range(3, 48): px(img, 2, row, OUTLINE); px(img, 5, row, OUTLINE)

    return img


# =============================================================
# MAIN
# =============================================================
ned_map = make_ned_map()
ned_map.save(os.path.join(OUTPUT_DIR, "ned_stark_map.png"))
print(f"生成: ned_stark_map.png  {ned_map.size}")

robert_map = make_robert_map()
robert_map.save(os.path.join(OUTPUT_DIR, "robert_baratheon_map.png"))
print(f"生成: robert_baratheon_map.png  {robert_map.size}")

howland_map = make_howland_map()
howland_map.save(os.path.join(OUTPUT_DIR, "howland_reed_map.png"))
print(f"生成: howland_reed_map.png  {howland_map.size}")

royal_map = make_royal_map()
royal_map.save(os.path.join(OUTPUT_DIR, "royal_soldier_map.png"))
print(f"生成: royal_soldier_map.png  {royal_map.size}")

ned_portrait = make_ned_portrait()
ned_portrait.save(os.path.join(OUTPUT_DIR, "ned_stark_portrait.png"))
print(f"生成: ned_stark_portrait.png  {ned_portrait.size}")

robert_portrait = make_robert_portrait()
robert_portrait.save(os.path.join(OUTPUT_DIR, "robert_baratheon_portrait.png"))
print(f"生成: robert_baratheon_portrait.png  {robert_portrait.size}")

howland_portrait = make_howland_portrait()
howland_portrait.save(os.path.join(OUTPUT_DIR, "howland_reed_portrait.png"))
print(f"生成: howland_reed_portrait.png  {howland_portrait.size}")

royal_portrait = make_royal_portrait()
royal_portrait.save(os.path.join(OUTPUT_DIR, "royal_soldier_portrait.png"))
print(f"生成: royal_soldier_portrait.png  {royal_portrait.size}")

print("\n全部图标生成完成！保存到:", OUTPUT_DIR)
print("地图精灵: 96x32 (3帧 32x32)")
print("战斗立绘: 48x48 (单帧)")
