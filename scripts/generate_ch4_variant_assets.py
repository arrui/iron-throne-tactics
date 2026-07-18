#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
UNIT_DIR = ROOT / "game/冰与火/assets/units"


def _alpha_tint(image: Image.Image, rgb: tuple[int, int, int], strength: float) -> Image.Image:
	base = image.convert("RGBA")
	overlay = Image.new("RGBA", base.size, rgb + (255,))
	blended = Image.blend(base, overlay, strength)
	blended.putalpha(base.getchannel("A"))
	return blended


def _soft_overlay(size: tuple[int, int], draw_fn) -> Image.Image:
	overlay = Image.new("RGBA", size, (0, 0, 0, 0))
	draw = ImageDraw.Draw(overlay)
	draw_fn(draw)
	return overlay.filter(ImageFilter.GaussianBlur(0.7))


def _fur_collar(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
		fill: tuple[int, int, int, int], tip: tuple[int, int, int, int]) -> None:
	draw.polygon([
		(x0, y1),
		(x0 + 8, y0 + 6),
		(x0 + 18, y0 + 12),
		(x0 + 30, y0 + 4),
		(x0 + 44, y0 + 13),
		(x0 + 58, y0 + 5),
		(x1 - 16, y0 + 10),
		(x1, y1),
	], fill=fill)
	for px, py in [(x0 + 10, y0 + 12), (x0 + 26, y0 + 8), (x0 + 40, y0 + 14), (x1 - 18, y0 + 9)]:
		draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=tip)


def _portrait_variant(base_name: str, output_name: str, tint_rgb: tuple[int, int, int],
		strength: float, accent_rgb: tuple[int, int, int], role: str) -> None:
	base = Image.open(UNIT_DIR / f"{base_name}_portrait.png").convert("RGBA")
	img = _alpha_tint(base, tint_rgb, strength)

	overlay = _soft_overlay(img.size, lambda d: _draw_portrait_overlay(d, role, accent_rgb))
	img = Image.alpha_composite(img, overlay)
	img.save(UNIT_DIR / f"{output_name}_portrait.png")


def _draw_portrait_overlay(draw: ImageDraw.ImageDraw, role: str,
		accent_rgb: tuple[int, int, int]) -> None:
	accent = accent_rgb + (120,)
	deep = tuple(max(c - 42, 0) for c in accent_rgb) + (135,)
	steel = (190, 198, 212, 92)
	fur = (112, 124, 142, 118)
	fur_tip = (176, 186, 202, 128)

	if role == "axebreaker":
		draw.polygon([(0, 95), (0, 56), (22, 44), (38, 62), (48, 95)], fill=accent)
		_fur_collar(draw, 10, 66, 78, 95, fur, fur_tip)
		draw.line((80, 18, 80, 92), fill=(70, 48, 34, 185), width=4)
		draw.polygon([(76, 18), (94, 24), (84, 38), (72, 32)], fill=steel)
		draw.line((38, 29, 48, 34), fill=(150, 44, 44, 160), width=2)
	elif role == "spearwall":
		draw.polygon([(0, 95), (0, 58), (26, 46), (44, 60), (54, 95)], fill=accent)
		_fur_collar(draw, 12, 68, 80, 95, fur, fur_tip)
		draw.line((82, 10, 82, 94), fill=(132, 102, 66, 190), width=3)
		draw.polygon([(78, 10), (86, 10), (82, 2)], fill=steel)
		draw.arc((16, 54, 40, 82), start=90, end=270, fill=steel, width=4)
		draw.line((47, 16, 47, 58), fill=(208, 214, 224, 118), width=3)
	elif role == "swiftsword":
		draw.polygon([(0, 95), (0, 48), (20, 38), (42, 56), (58, 95)], fill=accent)
		_fur_collar(draw, 10, 67, 78, 95, fur, fur_tip)
		draw.line((81, 16, 88, 88), fill=(212, 218, 228, 170), width=3)
		draw.line((75, 60, 88, 54), fill=(215, 184, 96, 152), width=3)
		draw.polygon([(4, 14), (20, 6), (34, 18), (26, 36), (10, 32)], fill=deep)
	elif role == "rider":
		draw.polygon([(0, 95), (0, 54), (30, 42), (48, 60), (62, 95)], fill=accent)
		_fur_collar(draw, 8, 66, 80, 95, fur, fur_tip)
		draw.line((82, 12, 82, 94), fill=(140, 112, 76, 190), width=3)
		draw.polygon([(82, 12), (96, 20), (82, 28)], fill=accent)
		draw.arc((46, 62, 76, 94), start=200, end=340, fill=(72, 54, 44, 150), width=4)
	elif role == "veteran":
		draw.polygon([(0, 95), (0, 58), (24, 44), (46, 60), (60, 95)], fill=accent)
		_fur_collar(draw, 8, 66, 80, 95, fur, fur_tip)
		draw.line((82, 8, 82, 94), fill=(96, 80, 58, 190), width=4)
		draw.polygon([(82, 10), (96, 18), (96, 34), (82, 28)], fill=accent)
		draw.ellipse((52, 70, 66, 84), fill=(184, 156, 88, 110))


def _replace_palette(image: Image.Image, replacements: dict[tuple[int, int, int, int], tuple[int, int, int, int]]) -> Image.Image:
	img = image.convert("RGBA")
	pixels = []
	for px in img.getdata():
		pixels.append(replacements.get(px, px))
	img.putdata(pixels)
	return img


def _map_variant(base_name: str, output_name: str,
		replacements: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
		role: str) -> None:
	base = Image.open(UNIT_DIR / f"{base_name}_map.png").convert("RGBA")
	img = _replace_palette(base, replacements)
	overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(overlay)
	if role == "swiftsword":
		for off in (0, 32, 64):
			d.line((off + 21, 6, off + 26, 1), fill=(214, 220, 230, 180), width=1)
	elif role == "rider":
		for off in (0, 32, 64):
			d.polygon([(off + 23, 4), (off + 30, 8), (off + 23, 12)], fill=(110, 132, 168, 210))
	elif role == "veteran":
		for off in (0, 32, 64):
			d.rectangle((off + 24, 4, off + 28, 11), fill=(110, 90, 68, 210))
			d.polygon([(off + 28, 4), (off + 31, 6), (off + 31, 12), (off + 28, 10)], fill=(132, 118, 92, 180))
	img = Image.alpha_composite(img, overlay)
	img.save(UNIT_DIR / f"{output_name}_map.png")


def main() -> None:
	portrait_jobs = [
		("lannister_soldier", "north_axebreaker", (88, 108, 142), 0.16, (132, 70, 62), "axebreaker"),
		("royal_soldier", "north_spearwall", (78, 102, 138), 0.12, (86, 112, 154), "spearwall"),
		("northern_knight", "north_swiftsword", (74, 108, 96), 0.10, (62, 106, 88), "swiftsword"),
		("dorne_knight", "north_rider", (82, 112, 136), 0.18, (88, 118, 154), "rider"),
		("rebel_lord", "north_veteran", (88, 102, 118), 0.12, (118, 96, 72), "veteran"),
	]
	for job in portrait_jobs:
		_portrait_variant(*job)

	map_jobs = [
		(
			"lannister_soldier",
			"north_axebreaker",
			{
				(164, 44, 40, 255): (70, 90, 118, 255),
				(86, 39, 40, 255): (44, 58, 84, 255),
				(118, 32, 31, 255): (54, 70, 96, 255),
				(210, 162, 62, 255): (174, 190, 210, 255),
				(230, 189, 82, 255): (214, 226, 238, 255),
			},
			"axebreaker",
		),
		(
			"royal_soldier",
			"north_spearwall",
			{
				(197, 170, 85, 255): (92, 118, 156, 255),
				(216, 189, 98, 255): (122, 150, 188, 255),
				(119, 127, 131, 255): (174, 182, 194, 255),
				(68, 72, 74, 255): (96, 106, 120, 255),
			},
			"spearwall",
		),
		(
			"arthur_dayne",
			"north_swiftsword",
			{
				(201, 209, 213, 255): (132, 150, 168, 255),
				(240, 243, 239, 255): (204, 214, 222, 255),
				(240, 216, 135, 255): (78, 116, 96, 255),
				(127, 139, 145, 255): (82, 98, 112, 255),
				(227, 229, 223, 255): (168, 182, 194, 255),
			},
			"swiftsword",
		),
		(
			"dorne_knight",
			"north_rider",
			{
				(184, 109, 43, 255): (68, 96, 132, 255),
				(208, 75, 47, 255): (84, 116, 154, 255),
				(146, 61, 39, 255): (56, 82, 116, 255),
				(227, 184, 79, 255): (176, 190, 210, 255),
				(240, 206, 103, 255): (212, 222, 234, 255),
			},
			"rider",
		),
		(
			"rebel_lord",
			"north_veteran",
			{
				(107, 68, 52, 255): (84, 92, 104, 255),
				(90, 57, 41, 255): (62, 70, 82, 255),
				(176, 121, 72, 255): (144, 156, 174, 255),
				(114, 80, 57, 255): (92, 100, 114, 255),
				(209, 162, 93, 255): (196, 206, 222, 255),
			},
			"veteran",
		),
	]
	for job in map_jobs:
		_map_variant(*job)


if __name__ == "__main__":
	main()
