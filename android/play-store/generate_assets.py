#!/usr/bin/env python3
"""Deterministic Play graphics following tools/generate-app-icon.swift palette/layout.

Generated raster graphics are listing artwork, not screenshots; screenshots must be
captured from the running Android app. Uses only Pillow.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent / "generated"
OUT.mkdir(parents=True, exist_ok=True)
BG = (11, 18, 29)
FRAME = (27, 44, 64)
TEAL = (110, 223, 216)
CORAL = (255, 174, 134)

def line(d, points, fill, w):
    d.line(points, fill=fill, width=w, joint="curve")

def draw_icon(side=1024):
    img = Image.new("RGB", (side, side), BG)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((61, 61, 963, 963), radius=150, fill=(19, 36, 52))
    d.rounded_rectangle((118, 118, 906, 906), radius=78, fill=FRAME, outline=(67, 93, 110), width=8)
    gap, inset = 17, 29
    tile = (788 - inset * 2 - gap * 2) // 3
    bounds = {}
    for index in range(9):
        x = 118 + inset + (index % 3) * (tile + gap)
        y = 118 + inset + (index // 3) * (tile + gap)
        bounds[index] = (x, y, x + tile, y + tile)
        d.rounded_rectangle(bounds[index], radius=29, fill=(44, 89, 96) if index == 4 else (41, 57, 73),
                            outline=TEAL if index == 4 else (66, 83, 99), width=7 if index == 4 else 3)
        for split in (1, 2):
            off = split * tile / 3
            line(d, ((x + off, y + 16), (x + off, y + tile - 16)), (77, 98, 111), 4)
            line(d, ((x + 16, y + off), (x + tile - 16, y + off)), (77, 98, 111), 4)
    for index, symbol, length in ((4, "X", 145), (2, "O", 122), (0, "X", 85), (8, "O", 85)):
        x0, y0, x1, y1 = bounds[index]
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        r = length / 2
        color = TEAL if symbol == "X" else CORAL
        thick = max(7, int(length * 0.19))
        if symbol == "X":
            line(d, ((cx-r, cy-r), (cx+r, cy+r)), color, thick)
            line(d, ((cx+r, cy-r), (cx-r, cy+r)), color, thick)
        else:
            d.ellipse((cx-r, cy-r, cx+r, cy+r), outline=color, width=thick)
    return img

icon = draw_icon()
icon.resize((512,512), Image.Resampling.LANCZOS).save(OUT / "play-icon-512.png", optimize=True)
icon.save(OUT / "play-icon-source-1024.png", optimize=True)

# Google Play feature graphic: 1024x500, RGB (no alpha), minimal text.
feature = Image.new("RGB", (1024, 500), BG)
d = ImageDraw.Draw(feature)
d.rounded_rectangle((20, 20, 1004, 480), radius=46, fill=(18, 34, 49), outline=(43, 68, 80), width=2)
small_icon = icon.resize((388,388), Image.Resampling.LANCZOS)
feature.paste(small_icon, (602, 56))
font_paths = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
]
regular_paths = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
]
def load_font(paths, size):
    for path in paths:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()
bold80 = load_font(font_paths, 68)
bold42 = load_font(font_paths, 44)
small = load_font(regular_paths, 29)
d.text((65, 116), "ULTIMATE", font=bold42, fill=TEAL)
d.text((65, 194), "Tic/Tac/Toe", font=bold80, fill=(245, 249, 249))
d.line(((66, 312), (522, 312)), fill=(67, 102, 111), width=3)
d.text((66, 353), "Nine boards. One big win.", font=small, fill=(215, 231, 233))
feature.save(OUT / "feature-graphic-1024x500.png", optimize=True)
print("Generated", sorted(p.name for p in OUT.glob("*.png")))
