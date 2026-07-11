#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "game/冰与火/assets/units"
SIZE = 96
SCALE = 4
W = SIZE * SCALE
H = SIZE * SCALE


@dataclass(frozen=True)
class PortraitSpec:
	bg_top: tuple[int, int, int]
	bg_bottom: tuple[int, int, int]
	halo: tuple[int, int, int]
	armor_main: tuple[int, int, int]
	armor_shadow: tuple[int, int, int]
	cloak: tuple[int, int, int]
	skin: tuple[int, int, int]
	hair: tuple[int, int, int]
	metal: tuple[int, int, int]
	eye: tuple[int, int, int]
	accent: tuple[int, int, int]
	hair_style: str = "short"
	beard: str = "none"
	headgear: str = "none"
	emblem: str = "diamond"


SPECS: dict[str, PortraitSpec] = {
	"ned_stark": PortraitSpec(
		bg_top=(34, 44, 62), bg_bottom=(12, 16, 24), halo=(120, 154, 190),
		armor_main=(92, 108, 132), armor_shadow=(52, 62, 82), cloak=(74, 86, 110),
		skin=(227, 195, 164), hair=(62, 46, 33), metal=(168, 178, 190),
		eye=(42, 54, 68), accent=(190, 210, 222), hair_style="medium", beard="full", emblem="wolf",
	),
	"robert_baratheon": PortraitSpec(
		bg_top=(70, 48, 12), bg_bottom=(24, 18, 8), halo=(224, 190, 76),
		armor_main=(150, 112, 28), armor_shadow=(82, 58, 14), cloak=(58, 32, 12),
		skin=(222, 185, 150), hair=(36, 24, 16), metal=(198, 166, 84),
		eye=(58, 42, 26), accent=(245, 214, 128), hair_style="wild", beard="full", emblem="stag",
	),
	"howland_reed": PortraitSpec(
		bg_top=(24, 46, 28), bg_bottom=(8, 18, 10), halo=(106, 146, 90),
		armor_main=(70, 96, 58), armor_shadow=(34, 48, 28), cloak=(48, 70, 38),
		skin=(214, 182, 148), hair=(34, 28, 18), metal=(142, 156, 130),
		eye=(38, 48, 22), accent=(176, 205, 144), hair_style="hood", beard="none", headgear="hood", emblem="reed",
	),
	"royal_soldier": PortraitSpec(
		bg_top=(86, 24, 20), bg_bottom=(24, 8, 8), halo=(206, 82, 72),
		armor_main=(160, 42, 34), armor_shadow=(90, 20, 16), cloak=(118, 22, 22),
		skin=(210, 176, 144), hair=(24, 18, 12), metal=(184, 162, 112),
		eye=(42, 24, 20), accent=(236, 192, 118), headgear="helmet", emblem="crown",
	),
	"arthur_dayne": PortraitSpec(
		bg_top=(64, 70, 90), bg_bottom=(18, 22, 34), halo=(206, 226, 255),
		armor_main=(192, 206, 224), armor_shadow=(110, 124, 148), cloak=(108, 118, 160),
		skin=(232, 202, 176), hair=(220, 200, 140), metal=(230, 238, 248),
		eye=(70, 84, 110), accent=(255, 248, 200), hair_style="long", beard="none", emblem="star",
	),
	"barristan_selmy": PortraitSpec(
		bg_top=(78, 84, 92), bg_bottom=(24, 26, 30), halo=(224, 226, 230),
		armor_main=(178, 182, 188), armor_shadow=(104, 108, 116), cloak=(206, 206, 210),
		skin=(220, 188, 162), hair=(214, 214, 214), metal=(236, 238, 242),
		eye=(64, 68, 72), accent=(255, 244, 216), hair_style="short", beard="short", emblem="shield",
	),
	"dorne_knight": PortraitSpec(
		bg_top=(120, 72, 26), bg_bottom=(36, 18, 8), halo=(240, 170, 90),
		armor_main=(176, 96, 34), armor_shadow=(102, 52, 16), cloak=(132, 56, 20),
		skin=(198, 150, 112), hair=(62, 36, 20), metal=(204, 160, 96),
		eye=(58, 34, 16), accent=(254, 214, 144), headgear="turban", emblem="sun",
	),
	"lannister_soldier": PortraitSpec(
		bg_top=(114, 20, 24), bg_bottom=(28, 8, 10), halo=(230, 172, 60),
		armor_main=(184, 40, 42), armor_shadow=(104, 18, 22), cloak=(148, 26, 32),
		skin=(220, 186, 154), hair=(88, 60, 32), metal=(210, 170, 80),
		eye=(60, 32, 22), accent=(255, 212, 120), headgear="helmet", emblem="lion",
	),
	"jaime_lannister": PortraitSpec(
		bg_top=(132, 26, 34), bg_bottom=(34, 10, 12), halo=(255, 196, 96),
		armor_main=(206, 62, 54), armor_shadow=(116, 24, 20), cloak=(170, 38, 42),
		skin=(234, 202, 172), hair=(212, 184, 104), metal=(238, 208, 126),
		eye=(84, 62, 34), accent=(255, 226, 152), hair_style="medium", beard="none", emblem="lion",
	),
	"janos_slynt": PortraitSpec(
		bg_top=(76, 58, 18), bg_bottom=(18, 14, 8), halo=(194, 154, 72),
		armor_main=(118, 98, 54), armor_shadow=(66, 54, 28), cloak=(44, 42, 30),
		skin=(206, 170, 138), hair=(28, 22, 16), metal=(180, 152, 88),
		eye=(54, 42, 26), accent=(224, 196, 122), beard="short", headgear="helmet", emblem="crown",
	),
	"northern_knight": PortraitSpec(
		bg_top=(46, 56, 76), bg_bottom=(14, 18, 30), halo=(152, 176, 216),
		armor_main=(108, 122, 152), armor_shadow=(54, 64, 88), cloak=(74, 84, 120),
		skin=(220, 190, 160), hair=(82, 58, 38), metal=(188, 198, 220),
		eye=(48, 56, 72), accent=(220, 230, 246), headgear="fur", emblem="wolf",
	),
	"rebel_lord": PortraitSpec(
		bg_top=(68, 56, 32), bg_bottom=(18, 16, 10), halo=(186, 146, 92),
		armor_main=(108, 96, 68), armor_shadow=(56, 48, 34), cloak=(108, 48, 36),
		skin=(224, 190, 150), hair=(82, 50, 26), metal=(176, 162, 118),
		eye=(64, 42, 24), accent=(230, 204, 144), beard="short", emblem="sword",
	),
	"rhaegar_targaryen": PortraitSpec(
		bg_top=(92, 28, 38), bg_bottom=(20, 10, 16), halo=(220, 88, 92),
		armor_main=(146, 32, 42), armor_shadow=(74, 16, 24), cloak=(58, 18, 22),
		skin=(230, 202, 182), hair=(212, 206, 222), metal=(196, 198, 214),
		eye=(80, 54, 68), accent=(255, 176, 182), hair_style="long", emblem="dragon",
	),
	"royal_guard_captain": PortraitSpec(
		bg_top=(98, 92, 48), bg_bottom=(26, 22, 8), halo=(242, 214, 136),
		armor_main=(206, 184, 124), armor_shadow=(126, 106, 62), cloak=(242, 238, 222),
		skin=(216, 180, 144), hair=(84, 60, 34), metal=(248, 240, 216),
		eye=(78, 62, 34), accent=(255, 252, 232), headgear="crest_helm", emblem="crown",
	),
	"targaryen_soldier": PortraitSpec(
		bg_top=(56, 18, 24), bg_bottom=(10, 6, 10), halo=(180, 76, 88),
		armor_main=(62, 62, 72), armor_shadow=(26, 26, 34), cloak=(122, 22, 32),
		skin=(216, 184, 154), hair=(34, 24, 20), metal=(164, 164, 176),
		eye=(54, 42, 44), accent=(230, 132, 140), headgear="helmet", emblem="dragon",
	),
}


def rgba(rgb: tuple[int, int, int], a: int = 255) -> tuple[int, int, int, int]:
	return rgb[0], rgb[1], rgb[2], a


def lerp(a: int, b: int, t: float) -> int:
	return int(a + (b - a) * t)


def gradient(base: Image.Image, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> None:
	d = ImageDraw.Draw(base)
	for y in range(H):
		t = y / max(H - 1, 1)
		col = (lerp(top[0], bottom[0], t), lerp(top[1], bottom[1], t), lerp(top[2], bottom[2], t), 255)
		d.line((0, y, W, y), fill=col)


def add_vignette(base: Image.Image, strength: int = 150) -> None:
	overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(overlay)
	for i in range(18):
		alpha = int(strength * (i / 18.0) ** 2)
		pad = i * 10
		d.rounded_rectangle((pad, pad, W - pad, H - pad), radius=60, outline=(0, 0, 0, alpha), width=18)
	base.alpha_composite(overlay)


def add_halo(base: Image.Image, color: tuple[int, int, int]) -> None:
	halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(halo)
	d.ellipse((90, 26, W - 90, H - 90), fill=rgba(color, 120))
	d.ellipse((126, 62, W - 126, H - 126), fill=rgba(color, 96))
	base.alpha_composite(halo.filter(ImageFilter.GaussianBlur(28)))


def poly(draw: ImageDraw.ImageDraw, pts: list[tuple[int, int]], fill: tuple[int, int, int, int], outline=None, width=1) -> None:
	draw.polygon(pts, fill=fill, outline=outline)
	if outline and width > 1:
		for i in range(len(pts)):
			p1 = pts[i]
			p2 = pts[(i + 1) % len(pts)]
			draw.line((p1, p2), fill=outline, width=width)


def draw_armor(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	poly(draw, [(88, 344), (150, 230), (242, 202), (W - 242, 202), (W - 150, 230), (W - 88, 344), (W - 88, H), (88, H)], rgba(spec.cloak, 255))
	poly(draw, [(132, H), (164, 248), (W - 164, 248), (W - 132, H)], rgba(spec.armor_main, 255), outline=rgba(spec.armor_shadow, 220), width=8)
	poly(draw, [(196, 238), (238, 212), (W - 238, 212), (W - 196, 238), (W - 202, H), (202, H)], rgba(spec.armor_shadow, 90))
	draw.ellipse((96, 238, 188, 324), fill=rgba(spec.armor_main, 255), outline=rgba(spec.metal, 180), width=6)
	draw.ellipse((W - 188, 238, W - 96, 324), fill=rgba(spec.armor_main, 255), outline=rgba(spec.metal, 180), width=6)
	draw.rounded_rectangle((170, 252, W - 170, 324), radius=18, fill=rgba(spec.metal, 64))
	draw.rectangle((W // 2 - 16, 196, W // 2 + 16, 244), fill=rgba(spec.skin, 255))


def draw_head(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	draw.ellipse((132, 68, W - 132, 250), fill=rgba(spec.skin, 255), outline=rgba((70, 44, 32), 120), width=5)
	draw.ellipse((156, 156, 178, 174), fill=rgba(spec.eye, 255))
	draw.ellipse((W - 178, 156, W - 156, 174), fill=rgba(spec.eye, 255))
	draw.line((152, 142, 184, 136), fill=rgba((54, 34, 24), 180), width=7)
	draw.line((W - 184, 136, W - 152, 142), fill=rgba((54, 34, 24), 180), width=7)
	draw.line((W // 2, 154, W // 2 - 8, 184), fill=rgba((120, 84, 64), 120), width=5)
	draw.arc((162, 176, W - 162, 222), 12, 168, fill=rgba((126, 68, 60), 180), width=6)
	draw.ellipse((170, 192, W - 170, 228), fill=rgba((255, 255, 255), 22))


def draw_hair(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	col = rgba(spec.hair, 255)
	shadow = rgba(tuple(max(c - 28, 0) for c in spec.hair), 220)
	if spec.hair_style == "hood":
		poly(draw, [(110, 62), (148, 36), (W - 148, 36), (W - 110, 62), (W - 126, 188), (W - 170, 138), (170, 138), (126, 188)], rgba(spec.cloak, 255), outline=rgba(spec.armor_shadow, 180), width=8)
		return
		
	if spec.hair_style == "long":
		poly(draw, [(124, 74), (160, 28), (W - 160, 28), (W - 124, 74), (W - 122, 228), (W - 156, 250), (W - 134, 132), (134, 132), (156, 250), (122, 228)], col)
	elif spec.hair_style == "medium":
		poly(draw, [(126, 72), (156, 34), (W - 156, 34), (W - 126, 72), (W - 138, 188), (W - 176, 138), (176, 138), (138, 188)], col)
	elif spec.hair_style == "wild":
		poly(draw, [(114, 86), (136, 28), (170, 48), (196, 24), (W // 2, 18), (W - 196, 24), (W - 170, 48), (W - 136, 28), (W - 114, 86), (W - 128, 180), (128, 180)], col)
	else:
		poly(draw, [(124, 76), (150, 40), (W - 150, 40), (W - 124, 76), (W - 138, 158), (138, 158)], col)
	draw.line((150, 86, W - 150, 86), fill=shadow, width=8)


def draw_beard(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	if spec.beard == "none":
		return
	col = rgba(tuple(max(c - 10, 0) for c in spec.hair), 240)
	if spec.beard == "short":
		poly(draw, [(164, 194), (188, 212), (W - 188, 212), (W - 164, 194), (W // 2, 244)], col)
	else:
		poly(draw, [(154, 186), (188, 212), (W - 188, 212), (W - 154, 186), (W // 2 + 18, 258), (W // 2, 248), (W // 2 - 18, 258)], col)
		draw.line((W // 2, 208, W // 2, 252), fill=rgba((28, 18, 12), 110), width=4)


def draw_headgear(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	if spec.headgear == "none" or spec.headgear == "hood":
		return
	metal = rgba(spec.metal, 255)
	shadow = rgba(spec.armor_shadow, 220)
	if spec.headgear == "helmet":
		poly(draw, [(128, 104), (146, 54), (W - 146, 54), (W - 128, 104), (W - 148, 176), (148, 176)], metal, outline=shadow, width=8)
		draw.rectangle((166, 112, W - 166, 126), fill=rgba((20, 22, 28), 210))
		draw.line((W // 2, 58, W // 2, 132), fill=rgba(spec.accent, 220), width=6)
	elif spec.headgear == "crest_helm":
		poly(draw, [(124, 112), (148, 44), (W - 148, 44), (W - 124, 112), (W - 150, 186), (150, 186)], metal, outline=shadow, width=8)
		draw.rectangle((166, 114, W - 166, 128), fill=rgba((18, 18, 18), 220))
		poly(draw, [(W // 2, 26), (W // 2 - 34, 74), (W // 2 - 10, 74), (W // 2 - 18, 104), (W // 2 + 18, 104), (W // 2 + 10, 74), (W // 2 + 34, 74)], rgba(spec.cloak, 255), outline=rgba(spec.accent, 180), width=6)
	elif spec.headgear == "turban":
		draw.ellipse((126, 56, W - 126, 154), fill=rgba(spec.cloak, 255), outline=shadow, width=8)
		draw.line((154, 94, W - 154, 94), fill=rgba(spec.accent, 120), width=8)
	elif spec.headgear == "fur":
		for x in range(126, W - 126, 22):
			draw.ellipse((x, 50, x + 44, 102), fill=rgba(spec.hair, 255))
		draw.rounded_rectangle((126, 78, W - 126, 122), radius=16, fill=rgba(spec.hair, 255), outline=rgba((20, 16, 12), 120), width=6)


def draw_emblem(draw: ImageDraw.ImageDraw, spec: PortraitSpec) -> None:
	cx, cy = W // 2, 288
	col = rgba(spec.accent, 250)
	outline = rgba((32, 24, 18), 110)
	if spec.emblem == "wolf":
		poly(draw, [(cx, cy - 22), (cx + 26, cy - 6), (cx + 16, cy + 26), (cx, cy + 16), (cx - 16, cy + 26), (cx - 26, cy - 6)], col, outline=outline, width=5)
	elif spec.emblem == "stag":
		draw.ellipse((cx - 18, cy - 8, cx + 18, cy + 22), fill=col, outline=outline, width=5)
		draw.line((cx - 10, cy - 8, cx - 24, cy - 30), fill=col, width=7)
		draw.line((cx + 10, cy - 8, cx + 24, cy - 30), fill=col, width=7)
		draw.line((cx - 24, cy - 30, cx - 34, cy - 18), fill=col, width=6)
		draw.line((cx + 24, cy - 30, cx + 34, cy - 18), fill=col, width=6)
	elif spec.emblem == "reed":
		for dx in (-12, 0, 12):
			draw.line((cx + dx, cy + 24, cx + dx, cy - 26), fill=col, width=6)
			draw.line((cx + dx, cy - 8, cx + dx + 12, cy - 22), fill=col, width=5)
	elif spec.emblem == "dragon":
		poly(draw, [(cx - 24, cy + 18), (cx - 10, cy - 18), (cx + 10, cy - 24), (cx + 24, cy), (cx + 8, cy + 24), (cx - 8, cy + 8)], col, outline=outline, width=5)
	elif spec.emblem == "lion":
		draw.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=col, outline=outline, width=5)
		draw.ellipse((cx - 12, cy - 8, cx + 12, cy + 14), fill=rgba(spec.bg_bottom, 180))
	elif spec.emblem == "crown":
		poly(draw, [(cx - 28, cy + 18), (cx - 22, cy - 18), (cx - 6, cy - 2), (cx, cy - 28), (cx + 6, cy - 2), (cx + 22, cy - 18), (cx + 28, cy + 18)], col, outline=outline, width=5)
	elif spec.emblem == "sun":
		draw.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), fill=col, outline=outline, width=5)
		for dx, dy in [(0, -30), (0, 30), (-30, 0), (30, 0), (-22, -22), (22, -22), (-22, 22), (22, 22)]:
			draw.line((cx, cy, cx + dx, cy + dy), fill=col, width=5)
	elif spec.emblem == "star":
		poly(draw, [(cx, cy - 28), (cx + 10, cy - 8), (cx + 30, cy - 8), (cx + 14, cy + 6), (cx + 22, cy + 28), (cx, cy + 14), (cx - 22, cy + 28), (cx - 14, cy + 6), (cx - 30, cy - 8), (cx - 10, cy - 8)], col, outline=outline, width=5)
	elif spec.emblem == "shield":
		poly(draw, [(cx - 24, cy - 24), (cx + 24, cy - 24), (cx + 18, cy + 10), (cx, cy + 28), (cx - 18, cy + 10)], col, outline=outline, width=5)
	elif spec.emblem == "sword":
		draw.line((cx, cy - 28, cx, cy + 24), fill=col, width=7)
		draw.line((cx - 18, cy - 8, cx + 18, cy - 8), fill=col, width=6)
		poly(draw, [(cx, cy - 36), (cx - 10, cy - 20), (cx + 10, cy - 20)], col)
	else:
		poly(draw, [(cx, cy - 24), (cx + 24, cy), (cx, cy + 24), (cx - 24, cy)], col, outline=outline, width=5)


def add_frame(base: Image.Image, spec: PortraitSpec) -> None:
	frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(frame)
	d.rounded_rectangle((10, 10, W - 10, H - 10), radius=42, outline=rgba(spec.accent, 210), width=10)
	d.rounded_rectangle((26, 26, W - 26, H - 26), radius=32, outline=rgba(spec.metal, 128), width=4)
	base.alpha_composite(frame)


def render(spec: PortraitSpec) -> Image.Image:
	base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	gradient(base, spec.bg_top, spec.bg_bottom)
	add_halo(base, spec.halo)
	draw = ImageDraw.Draw(base)
	draw_armor(draw, spec)
	draw_head(draw, spec)
	draw_hair(draw, spec)
	draw_beard(draw, spec)
	draw_headgear(draw, spec)
	draw_emblem(draw, spec)
	add_vignette(base)
	add_frame(base, spec)
	return base.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	for name, spec in SPECS.items():
		img = render(spec)
		out = OUT_DIR / f"{name}_portrait.png"
		img.save(out)
		print(f"generated {out.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
