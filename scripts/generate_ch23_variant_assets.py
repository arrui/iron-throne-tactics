#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
UNIT_DIR = ROOT / "game/冰与火/assets/units"


def _alpha_tint(image: Image.Image, rgb: tuple[int, int, int], strength: float) -> Image.Image:
	base = image.convert("RGBA")
	overlay = Image.new("RGBA", base.size, rgb + (255,))
	blended = Image.blend(base, overlay, strength)
	blended.putalpha(base.getchannel("A"))
	return blended


def _replace_palette(image: Image.Image, replacements: dict[tuple[int, int, int, int], tuple[int, int, int, int]]) -> Image.Image:
	img = image.convert("RGBA")
	img.putdata([replacements.get(px, px) for px in img.getdata()])
	return img


def _soft_overlay(size: tuple[int, int], draw_fn) -> Image.Image:
	overlay = Image.new("RGBA", size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(overlay)
	draw_fn(draw)
	return overlay.filter(ImageFilter.GaussianBlur(0.8))


def _fur_collar(draw: ImageDraw.ImageDraw, fill: tuple[int, int, int, int], tip: tuple[int, int, int, int]) -> None:
	draw.polygon([
		(8, 92), (16, 74), (28, 70), (38, 78), (49, 72), (59, 80), (70, 74), (84, 92)
	], fill=fill)
	for px, py in [(17, 78), (31, 74), (46, 81), (62, 76), (74, 80)]:
		draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill=tip)


def _portrait_overlay(draw: ImageDraw.ImageDraw, role: str, accent_rgb: tuple[int, int, int]) -> None:
	accent = accent_rgb + (118,)
	deep = tuple(max(c - 48, 0) for c in accent_rgb) + (132,)
	light = tuple(min(c + 40, 255) for c in accent_rgb) + (112,)
	steel = (198, 206, 220, 108)
	fur = (108, 122, 142, 110)
	fur_tip = (176, 190, 210, 116)

	if role == "storm_vanguard":
		draw.polygon([(0, 96), (0, 48), (22, 38), (40, 58), (54, 96)], fill=accent)
		draw.line((80, 14, 80, 94), fill=(88, 66, 44, 182), width=4)
		draw.polygon([(76, 14), (94, 22), (82, 38), (70, 32)], fill=steel)
		draw.line((36, 24, 46, 34), fill=light, width=3)
	elif role == "vale_veteran":
		draw.polygon([(0, 96), (0, 46), (26, 36), (44, 58), (60, 96)], fill=accent)
		draw.line((79, 12, 79, 94), fill=(112, 90, 62, 180), width=3)
		draw.polygon([(75, 12), (83, 12), (79, 2)], fill=steel)
		draw.arc((16, 54, 42, 82), start=90, end=270, fill=steel, width=4)
		draw.line((46, 14, 46, 56), fill=light, width=3)
	elif role == "river_captain":
		draw.polygon([(0, 96), (0, 56), (20, 42), (42, 54), (58, 96)], fill=accent)
		_fur_collar(draw, fur, fur_tip)
		draw.line((82, 8, 82, 94), fill=(92, 78, 58, 182), width=4)
		draw.polygon([(82, 10), (96, 18), (96, 34), (82, 28)], fill=deep)
		draw.ellipse((52, 70, 66, 84), fill=light)
	elif role == "dragon_guard":
		draw.polygon([(58, 96), (72, 54), (96, 42), (96, 96)], fill=accent)
		draw.line((18, 72, 78, 42), fill=light, width=2)
		draw.line((18, 76, 78, 46), fill=deep, width=2)
	elif role == "ruby_lancer":
		draw.polygon([(56, 96), (72, 50), (96, 40), (96, 96)], fill=accent)
		draw.ellipse((70, 22, 84, 36), fill=light)
		draw.ellipse((78, 18, 92, 32), fill=accent)
	elif role == "crown_phalanx":
		draw.rectangle((0, 82, 96, 96), fill=deep)
		for cx in (36, 48, 60):
			draw.line((cx, 16, cx, 8), fill=light, width=2)
			draw.line((cx, 8, cx - 4, 14), fill=light, width=2)
			draw.line((cx, 8, cx + 4, 14), fill=light, width=2)
	elif role == "wolf_guard":
		draw.polygon([(0, 96), (0, 54), (26, 42), (44, 60), (58, 96)], fill=accent)
		_fur_collar(draw, fur, fur_tip)
		draw.line((81, 16, 88, 88), fill=steel, width=3)
		draw.line((75, 60, 88, 54), fill=light, width=3)
	elif role == "wolf_veteran":
		draw.polygon([(0, 96), (0, 56), (24, 44), (46, 60), (60, 96)], fill=accent)
		_fur_collar(draw, fur, fur_tip)
		draw.line((82, 8, 82, 94), fill=(102, 88, 62, 184), width=4)
		draw.polygon([(82, 10), (96, 18), (96, 34), (82, 28)], fill=accent)
	elif role == "sand_knight":
		draw.polygon([(0, 96), (0, 58), (26, 46), (48, 60), (62, 96)], fill=accent)
		draw.line((81, 12, 81, 94), fill=(130, 106, 68, 184), width=3)
		draw.polygon([(81, 12), (95, 20), (81, 28)], fill=light)
		draw.ellipse((12, 16, 32, 36), fill=deep)
	elif role == "goldcloak":
		draw.polygon([(0, 96), (0, 44), (24, 38), (44, 56), (60, 96)], fill=accent)
		draw.line((79, 16, 88, 88), fill=steel, width=3)
		draw.arc((18, 50, 42, 78), start=90, end=270, fill=light, width=4)


def _portrait_variant(base_name: str, output_name: str, tint_rgb: tuple[int, int, int],
		strength: float, accent_rgb: tuple[int, int, int], role: str) -> None:
	base = Image.open(UNIT_DIR / f"{base_name}_portrait.png").convert("RGBA")
	img = _alpha_tint(base, tint_rgb, strength)
	overlay = _soft_overlay(img.size, lambda d: _portrait_overlay(d, role, accent_rgb))
	Image.alpha_composite(img, overlay).save(UNIT_DIR / f"{output_name}_portrait.png")


def _map_variant(base_name: str, output_name: str,
		replacements: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
		marker: str, accent_rgb: tuple[int, int, int]) -> None:
	base = Image.open(UNIT_DIR / f"{base_name}_map.png").convert("RGBA")
	img = _replace_palette(base, replacements)
	overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(overlay)
	acc = accent_rgb + (220,)
	light = tuple(min(c + 36, 255) for c in accent_rgb) + (210,)
	steel = (214, 220, 228, 210)
	for off in (0, 32, 64):
		if marker == "flag":
			d.line((off + 24, 4, off + 24, 12), fill=(108, 84, 56, 220), width=1)
			d.polygon([(off + 24, 4), (off + 30, 6), (off + 24, 9)], fill=acc)
		elif marker == "spear":
			d.line((off + 24, 3, off + 24, 12), fill=(118, 96, 64, 220), width=1)
			d.polygon([(off + 22, 3), (off + 26, 3), (off + 24, 0)], fill=steel)
		elif marker == "diagonal":
			d.line((off + 21, 5, off + 27, 0), fill=steel, width=1)
		elif marker == "dragon":
			d.ellipse((off + 25, 4, off + 29, 8), fill=light)
		elif marker == "cloak":
			d.rectangle((off + 2, 12, off + 8, 19), fill=acc)
	img = Image.alpha_composite(img, overlay)
	img.save(UNIT_DIR / f"{output_name}_map.png")


def main() -> None:
	portrait_jobs = [
		("rebel_lord", "ch2_storm_vanguard", (110, 94, 76), 0.08, (168, 146, 64), "storm_vanguard"),
		("rebel_lord", "ch2_vale_veteran", (88, 110, 144), 0.12, (114, 144, 188), "vale_veteran"),
		("rebel_lord", "ch2_river_captain", (86, 118, 100), 0.10, (108, 142, 102), "river_captain"),
		("targaryen_soldier", "ch2_dragon_guard", (126, 52, 58), 0.10, (182, 68, 72), "dragon_guard"),
		("targaryen_soldier", "ch2_ruby_lancer", (146, 40, 52), 0.14, (210, 72, 90), "ruby_lancer"),
		("targaryen_soldier", "ch2_crown_phalanx", (78, 78, 86), 0.12, (194, 82, 84), "crown_phalanx"),
		("northern_knight", "ch3_frost_axe", (84, 104, 136), 0.14, (98, 126, 166), "wolf_guard"),
		("northern_knight", "ch3_white_blade", (70, 116, 98), 0.12, (74, 128, 108), "wolf_guard"),
		("northern_knight", "ch3_greymark_veteran", (92, 102, 120), 0.10, (120, 108, 88), "wolf_veteran"),
		("dorne_knight", "ch3_red_sand_lancer", (124, 84, 56), 0.12, (188, 122, 70), "sand_knight"),
		("dorne_knight", "ch3_sunfire_lancer", (154, 112, 46), 0.12, (230, 176, 74), "sand_knight"),
		("dorne_knight", "ch3_dune_guard", (118, 96, 72), 0.08, (174, 138, 94), "sand_knight"),
		("royal_soldier", "ch3_goldcloak_captain", (152, 118, 52), 0.14, (208, 168, 80), "goldcloak"),
		("royal_soldier", "ch3_gate_goldcloak", (142, 104, 48), 0.10, (188, 146, 72), "goldcloak"),
	]
	for job in portrait_jobs:
		_portrait_variant(*job)

	map_jobs = [
		("rebel_lord", "ch2_storm_vanguard", {
			(107, 68, 52, 255): (116, 96, 72, 255),
			(90, 57, 41, 255): (82, 70, 54, 255),
			(176, 121, 72, 255): (184, 166, 88, 255),
			(209, 162, 93, 255): (224, 206, 118, 255),
		}, "flag", (190, 166, 84)),
		("rebel_lord", "ch2_vale_veteran", {
			(107, 68, 52, 255): (88, 110, 144, 255),
			(90, 57, 41, 255): (60, 78, 106, 255),
			(176, 121, 72, 255): (150, 174, 208, 255),
			(209, 162, 93, 255): (200, 220, 238, 255),
		}, "spear", (112, 146, 190)),
		("rebel_lord", "ch2_river_captain", {
			(107, 68, 52, 255): (88, 116, 96, 255),
			(90, 57, 41, 255): (60, 82, 68, 255),
			(176, 121, 72, 255): (164, 182, 126, 255),
			(209, 162, 93, 255): (208, 220, 156, 255),
		}, "cloak", (108, 146, 104)),
		("targaryen_soldier", "ch2_dragon_guard", {
			(210, 162, 62, 255): (178, 62, 68, 255),
			(230, 189, 82, 255): (212, 96, 102, 255),
			(164, 44, 40, 255): (114, 34, 42, 255),
			(86, 39, 40, 255): (74, 24, 30, 255),
		}, "dragon", (212, 90, 98)),
		("targaryen_soldier", "ch2_ruby_lancer", {
			(210, 162, 62, 255): (214, 124, 98, 255),
			(230, 189, 82, 255): (236, 154, 132, 255),
			(164, 44, 40, 255): (146, 34, 48, 255),
			(86, 39, 40, 255): (88, 24, 34, 255),
		}, "spear", (214, 110, 106)),
		("targaryen_soldier", "ch2_crown_phalanx", {
			(210, 162, 62, 255): (188, 78, 80, 255),
			(230, 189, 82, 255): (218, 112, 110, 255),
			(164, 44, 40, 255): (64, 64, 72, 255),
			(86, 39, 40, 255): (42, 42, 48, 255),
		}, "flag", (196, 90, 92)),
		("northern_knight", "ch3_frost_axe", {
			(119, 127, 131, 255): (120, 146, 176, 255),
			(68, 72, 74, 255): (80, 100, 126, 255),
			(197, 170, 85, 255): (170, 190, 214, 255),
			(216, 189, 98, 255): (208, 224, 238, 255),
		}, "flag", (116, 146, 184)),
		("northern_knight", "ch3_white_blade", {
			(119, 127, 131, 255): (108, 140, 130, 255),
			(68, 72, 74, 255): (74, 104, 96, 255),
			(197, 170, 85, 255): (188, 208, 194, 255),
			(216, 189, 98, 255): (220, 234, 222, 255),
		}, "diagonal", (92, 148, 122)),
		("northern_knight", "ch3_greymark_veteran", {
			(119, 127, 131, 255): (122, 132, 146, 255),
			(68, 72, 74, 255): (84, 92, 106, 255),
			(197, 170, 85, 255): (176, 164, 138, 255),
			(216, 189, 98, 255): (208, 196, 172, 255),
		}, "cloak", (136, 116, 94)),
		("dorne_knight", "ch3_red_sand_lancer", {
			(184, 109, 43, 255): (166, 92, 58, 255),
			(227, 184, 79, 255): (216, 156, 92, 255),
			(240, 206, 103, 255): (236, 188, 126, 255),
			(208, 75, 47, 255): (188, 66, 60, 255),
		}, "spear", (196, 112, 84)),
		("dorne_knight", "ch3_sunfire_lancer", {
			(184, 109, 43, 255): (176, 134, 56, 255),
			(227, 184, 79, 255): (228, 186, 90, 255),
			(240, 206, 103, 255): (242, 214, 130, 255),
			(208, 75, 47, 255): (198, 120, 44, 255),
		}, "flag", (236, 184, 82)),
		("dorne_knight", "ch3_dune_guard", {
			(184, 109, 43, 255): (146, 118, 84, 255),
			(227, 184, 79, 255): (198, 166, 118, 255),
			(240, 206, 103, 255): (222, 194, 146, 255),
			(208, 75, 47, 255): (146, 100, 70, 255),
		}, "cloak", (178, 146, 102)),
		("royal_soldier", "ch3_goldcloak_captain", {
			(197, 170, 85, 255): (196, 158, 74, 255),
			(216, 189, 98, 255): (228, 196, 102, 255),
			(119, 127, 131, 255): (128, 120, 88, 255),
			(68, 72, 74, 255): (84, 72, 50, 255),
		}, "cloak", (220, 178, 84)),
		("royal_soldier", "ch3_gate_goldcloak", {
			(197, 170, 85, 255): (170, 144, 74, 255),
			(216, 189, 98, 255): (204, 176, 94, 255),
			(119, 127, 131, 255): (116, 102, 82, 255),
			(68, 72, 74, 255): (74, 60, 48, 255),
		}, "flag", (198, 162, 76)),
	]
	for job in map_jobs:
		_map_variant(*job)


if __name__ == "__main__":
	main()
