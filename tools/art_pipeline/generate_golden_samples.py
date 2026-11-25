# E:\ChessToDie\tools\art_pipeline\generate_golden_samples.py
# Python / generate_golden_samples.py / Python 3 + Pillow + SD Forge API / Chess to Die (Ag5)
"""
Generate Golden Standard V2 Tarot card backs, sample card art, and a fully
composed sample card for Game Designer approval.

- Card backs use original Pillow silhouette/sketch guides (NO cropping from
  tasks/thamkhao.jpg) fed into SD Forge img2img so the expressions are 100%
  original, razor-sharp, and never drift into human figures:
    * THE SUN: squinting mischievous curved eyes (^ ^) + wide gleaming toothy grin
    * THE MOON: laughing crescent moon ("haha" wide-open mouth with crisp white teeth)
- Mandatory Pillow pixel-snap (74x103 -> 2x NEAREST -> 148x206) with locked
  8-color Balatro palettes, crisp Tarot pixel border, corner flourishes, and
  pixel banner text (`* THE SUN *` / `* THE MOON *`).
- Supports `--backs-only` to regenerate only the 2 card backs without touching
  sample_card_art.png or sample_card_composed.png.

Outputs:
  - assets/sprites/cards/the_sun_back.png         (148x206 RGBA)
  - assets/sprites/cards/the_moon_back.png        (148x206 RGBA)
  - assets/sprites/cards/sample_card_art.png      (136x104 RGBA)
  - assets/sprites/cards/sample_card_composed.png (148x206 RGBA)
"""

import argparse
import base64
import colorsys
import io
import json
import math
import os
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Dict, List, Tuple
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
FRAME_ACTIVE_PATH = ROOT / "assets" / "ui" / "textures" / "frame_active.png"
REF_THAMKHAO_PATH = ROOT / "tasks" / "thamkhao.jpg"
REF_MOON_PATH = ROOT / "tasks" / "images.jfif"
OUT_DIR = ROOT / "assets" / "sprites" / "cards"

SD_TXT2IMG_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"
SD_IMG2IMG_URL = "http://127.0.0.1:7860/sdapi/v1/img2img"
CHECKPOINT = "DreamshaperPixelart.safetensors"

RGB = Tuple[int, int, int]
RGBA = Tuple[int, int, int, int]


def hex_rgb(code: str) -> RGB:
    c = code.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16))


# Locked 8-color Balatro palettes from design/art_bible.md & sd_art_spec.md
SUN_PALETTE: List[RGB] = [
    hex_rgb("#121014"),  # ink black
    hex_rgb("#2E0F15"),  # deep crimson bg
    hex_rgb("#5E1D1A"),  # dark maroon
    hex_rgb("#A83B1B"),  # burnt crimson-orange
    hex_rgb("#D96B27"),  # ember orange
    hex_rgb("#F4A236"),  # primary sun gold-orange
    hex_rgb("#FFD166"),  # bright gold
    hex_rgb("#FFF0C2"),  # cream highlight / teeth
]

MOON_PALETTE: List[RGB] = [
    hex_rgb("#081121"),  # ink midnight
    hex_rgb("#0B224D"),  # abyss blue
    hex_rgb("#0B3D91"),  # primary deep ocean blue
    hex_rgb("#195EC2"),  # cobalt mid
    hex_rgb("#3B86E8"),  # azure
    hex_rgb("#64B5F6"),  # primary bright moon blue
    hex_rgb("#A6D8FA"),  # pale ice blue
    hex_rgb("#E3F2FD"),  # ice white highlight / teeth
]

# Crisp 3x5 pixel bitmap font for Tarot banners & card text
FONT_3X5: Dict[str, List[str]] = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "111", "001"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"],
    "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "110"],
    ".": ["000", "000", "000", "000", "010"],
    ",": ["000", "000", "000", "010", "100"],
    "/": ["001", "001", "010", "100", "100"],
    "-": ["000", "000", "111", "000", "000"],
    ":": ["000", "010", "000", "010", "000"],
    "*": ["000", "010", "111", "010", "000"],  # bullet dot/diamond
    " ": ["00", "00", "00", "00", "00"],
}


def measure_pixel_text(text: str, spacing: int = 1) -> int:
    total = 0
    for i, ch in enumerate(text.upper()):
        glyph = FONT_3X5.get(ch, FONT_3X5[" "])
        total += len(glyph[0])
        if i < len(text) - 1:
            total += spacing
    return total


def draw_pixel_text(
    px,
    w: int,
    h: int,
    text: str,
    x0: int,
    y0: int,
    color: RGBA,
    spacing: int = 1,
) -> None:
    cx = x0
    for ch in text.upper():
        glyph = FONT_3X5.get(ch, FONT_3X5[" "])
        gw = len(glyph[0])
        for ry, row in enumerate(glyph):
            for rx, bit in enumerate(row):
                if bit == "1":
                    tx, ty = cx + rx, y0 + ry
                    if 0 <= tx < w and 0 <= ty < h:
                        px[tx, ty] = color
        cx += gw + spacing


def img_to_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def call_sd_txt2img(
    prompt: str,
    negative_prompt: str,
    width: int,
    height: int,
    seed: int,
    steps: int = 24,
    cfg_scale: float = 7.5,
) -> Image.Image:
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "sampler_name": "DPM++ 2M",
        "batch_size": 1,
        "n_iter": 1,
        "seed": seed,
        "override_settings": {
            "sd_model_checkpoint": CHECKPOINT,
        },
        "override_settings_restore_afterwards": False,
    }
    return _post_sd(SD_TXT2IMG_URL, payload)


def call_sd_img2img(
    init_img: Image.Image,
    prompt: str,
    negative_prompt: str,
    width: int,
    height: int,
    seed: int,
    denoising_strength: float = 0.54,
    steps: int = 24,
    cfg_scale: float = 7.5,
) -> Image.Image:
    payload = {
        "init_images": [img_to_b64(init_img)],
        "resize_mode": 0,
        "denoising_strength": denoising_strength,
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "sampler_name": "DPM++ 2M",
        "batch_size": 1,
        "n_iter": 1,
        "seed": seed,
        "override_settings": {
            "sd_model_checkpoint": CHECKPOINT,
        },
        "override_settings_restore_afterwards": False,
    }
    return _post_sd(SD_IMG2IMG_URL, payload)


def _post_sd(url: str, payload: dict) -> Image.Image:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    images = body.get("images")
    if not images:
        raise RuntimeError(f"SD Forge returned no images from {url}")
    raw = base64.b64decode(images[0].split(",", 1)[-1])
    return Image.open(io.BytesIO(raw)).convert("RGB")


def _draw_star(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r_outer: float,
    r_inner: float,
    points: int,
    fill: RGB,
    outline: RGB,
    rot_deg: float = -90.0,
) -> None:
    verts = []
    for i in range(points * 2):
        ang = math.radians(rot_deg + i * (180.0 / points))
        r = r_outer if i % 2 == 0 else r_inner
        verts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw.polygon(verts, fill=fill, outline=outline)


def _draw_cloud_cluster(
    draw: ImageDraw.ImageDraw,
    circles: List[Tuple[int, int, int]],
    fill: RGB,
    hi: RGB,
    outline: RGB,
) -> None:
    for cx, cy, r in circles:
        draw.ellipse((cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4), fill=outline)
    for cx, cy, r in circles:
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)
    for cx, cy, r in circles:
        hr = max(6, int(r * 0.55))
        draw.ellipse((cx - hr, cy - r + 4, cx + hr, cy - r + 4 + hr), fill=hi)


def build_sun_sketch_guide() -> Image.Image:
    """
    Original 512x704 silhouette/sketch guide for THE SUN (NO thamkhao.jpg):
    - Blazing round sun disk with 2-tier spiky flame rays
    - Celestial astronomical ring + 4/8-point stars + corner ember clouds
    - Mischievous squinting curved eyes (^ ^) + wide gleaming toothy grin (#FFF0C2 on #121014)
    """
    ink = hex_rgb("#121014")
    bg = hex_rgb("#2E0F15")
    maroon = hex_rgb("#5E1D1A")
    burnt = hex_rgb("#A83B1B")
    ember = hex_rgb("#D96B27")
    gold = hex_rgb("#F4A236")
    bright = hex_rgb("#FFD166")
    cream = hex_rgb("#FFF0C2")

    img = Image.new("RGB", (512, 704), bg)
    draw = ImageDraw.Draw(img)

    cx, cy = 256, 312

    # 1. Subtle radial dark-maroon aura & celestial astronomical ring
    draw.ellipse((cx - 235, cy - 235, cx + 235, cy + 235), fill=maroon)
    draw.ellipse((cx - 210, cy - 210, cx + 210, cy + 210), outline=ember, width=5)
    draw.ellipse((cx - 196, cy - 196, cx + 196, cy + 196), outline=gold, width=3)

    # Cardinal & diagonal diamonds on celestial ring
    for deg in range(0, 360, 45):
        rad = math.radians(deg)
        rx = cx + math.cos(rad) * 203
        ry = cy + math.sin(rad) * 203
        _draw_star(draw, rx, ry, 14 if deg % 90 == 0 else 9, 4, 4, cream, ink)

    # 2. Corner ember clouds/flames (top corners & lower sides above banner)
    _draw_cloud_cluster(
        draw,
        [(62, 545, 42), (110, 560, 46), (160, 575, 36), (450, 545, 42), (402, 560, 46), (352, 575, 36)],
        fill=burnt,
        hi=ember,
        outline=ink,
    )
    _draw_cloud_cluster(
        draw,
        [(58, 92, 34), (102, 78, 28), (454, 92, 34), (410, 78, 28)],
        fill=maroon,
        hi=burnt,
        outline=ink,
    )

    # 3. Two-tier spiky blazing sun rays (16 long outer + 16 shorter fiery inner)
    for i in range(16):
        ang = math.radians(i * 22.5 - 90.0)
        left = math.radians(i * 22.5 - 90.0 - 9.0)
        right = math.radians(i * 22.5 - 90.0 + 9.0)
        tip_r = 228 if i % 2 == 0 else 192
        base_r = 112
        # Slight wavy bend on alternating rays
        bend = math.radians(i * 22.5 - 90.0 + (4.5 if i % 2 == 0 else -4.5))
        pts = [
            (cx + math.cos(left) * base_r, cy + math.sin(left) * base_r),
            (cx + math.cos(bend) * (tip_r * 0.78), cy + math.sin(bend) * (tip_r * 0.78)),
            (cx + math.cos(ang) * tip_r, cy + math.sin(ang) * tip_r),
            (cx + math.cos(right) * base_r, cy + math.sin(right) * base_r),
        ]
        fill_col = gold if i % 2 == 0 else ember
        draw.polygon(pts, fill=fill_col, outline=ink)
        # Inner bright highlight ridge along each major ray
        if i % 2 == 0:
            inner_pts = [
                (cx + math.cos(left * 0.5 + ang * 0.5) * (base_r + 12), cy + math.sin(left * 0.5 + ang * 0.5) * (base_r + 12)),
                (cx + math.cos(ang) * (tip_r - 18), cy + math.sin(ang) * (tip_r - 18)),
                (cx + math.cos(right * 0.5 + ang * 0.5) * (base_r + 12), cy + math.sin(right * 0.5 + ang * 0.5) * (base_r + 12)),
            ]
            draw.polygon(inner_pts, fill=bright)

    # 4. Crisp 4-point and 8-point stars in corners
    _draw_star(draw, 82, 148, 28, 8, 8, cream, ink)
    _draw_star(draw, 430, 148, 28, 8, 8, cream, ink)
    _draw_star(draw, 95, 470, 22, 6, 4, bright, ink)
    _draw_star(draw, 417, 470, 22, 6, 4, bright, ink)
    _draw_star(draw, 256, 62, 24, 7, 4, cream, ink)

    # 5. Central Sun Disk with bold ink outline + warm cel-shaded rim
    r_sun = 122
    draw.ellipse((cx - r_sun - 8, cy - r_sun - 8, cx + r_sun + 8, cy + r_sun + 8), fill=ink)
    draw.ellipse((cx - r_sun, cy - r_sun, cx + r_sun, cy + r_sun), fill=gold)
    draw.ellipse((cx - r_sun + 12, cy - r_sun + 10, cx + r_sun - 12, cy + r_sun - 14), fill=bright)
    # Warm shading around cheeks & chin
    draw.arc((cx - r_sun + 4, cy - r_sun + 4, cx + r_sun - 4, cy + r_sun - 4), 15, 165, fill=ember, width=14)

    # 6. Mischievous squinting curved eyes (^ ^) — bold ink arches on clean gold face (NO eyeballs!)
    for side in (-1, 1):
        ex = cx + side * 46
        ey = cy - 22
        # Subtle raised sly brow
        brow_pts = [
            (ex - 26, ey - 24 + (6 if side == -1 else -4)),
            (ex, ey - 34),
            (ex + 26, ey - 24 + (-4 if side == -1 else 6)),
        ]
        draw.line(brow_pts, fill=ember, width=6)
        # Clean thick "^" closed squinting laughing eye (no white circle underneath so SD never draws eyeballs)
        eye_pts = [
            (ex - 32, ey + 14),
            (ex - 16, ey - 10),
            (ex, ey - 18),
            (ex + 16, ey - 10),
            (ex + 32, ey + 14),
        ]
        draw.line(eye_pts, fill=ink, width=18, joint="curve")
        # Outer laugh crinkle tick
        outer_x = ex + side * 34
        draw.line([(outer_x, ey + 10), (outer_x + side * 12, ey + 4)], fill=ink, width=6)

    # Small stylized sun nose
    draw.polygon([(cx, cy - 6), (cx - 8, cy + 12), (cx + 8, cy + 12)], fill=ember, outline=ink)

    # 7. Wide wicked toothy grin (#FFF0C2 teeth gleaming inside #121014 mouth cavity)
    mouth_outer = [
        (cx - 86, cy + 20),
        (cx - 52, cy + 30),
        (cx, cy + 36),
        (cx + 52, cy + 30),
        (cx + 86, cy + 20),
        (cx + 74, cy + 68),
        (cx + 42, cy + 92),
        (cx, cy + 100),
        (cx - 42, cy + 92),
        (cx - 74, cy + 68),
    ]
    draw.polygon(mouth_outer, fill=ink, outline=ink)

    # Gleaming cream teeth band filling the grin
    teeth_poly = [
        (cx - 74, cy + 28),
        (cx - 44, cy + 37),
        (cx, cy + 42),
        (cx + 44, cy + 37),
        (cx + 74, cy + 28),
        (cx + 64, cy + 62),
        (cx + 34, cy + 80),
        (cx, cy + 86),
        (cx - 34, cy + 80),
        (cx - 64, cy + 62),
    ]
    draw.polygon(teeth_poly, fill=cream, outline=ink)

    # Crisp dark ink tooth divider lines (horizontal bite line + vertical teeth)
    draw.line(
        [(cx - 68, cy + 48), (cx - 34, cy + 57), (cx, cy + 61), (cx + 34, cy + 57), (cx + 68, cy + 48)],
        fill=ink,
        width=5,
    )
    for tx in (-50, -30, -10, 10, 30, 50):
        draw.line([(cx + tx, cy + 31), (cx + tx, cy + 83)], fill=ink, width=5)

    # Keep bottom banner zone clean dark crimson
    draw.rectangle((0, 600, 512, 704), fill=bg)
    return img


def _grid_to_512(gx: float, gy: float) -> Tuple[float, float]:
    """Map a 74x103 base-grid coordinate to the 512x704 SD canvas (accounting for 74:103 center crop)."""
    return (3.0 + gx * (506.0 / 74.0), gy * (704.0 / 103.0))


# Shared C-crescent geometry in 74x103 base-grid coordinates (opens RIGHT, NO nose)
MOON_OUTER_CX, MOON_OUTER_CY, MOON_OUTER_R = 39.0, 45.0, 26.0
MOON_INNER_CX, MOON_INNER_CY, MOON_INNER_R = 50.0, 39.0, 19.5
MOON_EYE_CX, MOON_EYE_CY = 24, 44


def build_moon_c_sketch_guide() -> Image.Image:
    """
    Original 512x704 Tarot sketch guide for THE MOON:
    - C-shaped crescent opening to the RIGHT (curved spine on LEFT, 2 sharp tips pointing RIGHT).
    - Completely smooth inner crescent curve — ABSOLUTELY NO NOSE.
    - Large eerie black-sclera (#081121) eye with glowing ice-white (#E3F2FD) iris,
      tiny #081121 pupil dot, and short spooky lashes/flares around the rim.
    - Wide curved toothy grin sweeping along the lower crescent toward the right horn.
    - Deep ocean-blue celestial astronomical ring, swirling clouds, and 4/8-point stars
      matching the_sun_back.png.
    """
    ink = hex_rgb("#081121")
    abyss = hex_rgb("#0B224D")
    ocean = hex_rgb("#0B3D91")
    cobalt = hex_rgb("#195EC2")
    azure = hex_rgb("#3B86E8")
    sky = hex_rgb("#64B5F6")
    pale = hex_rgb("#A6D8FA")
    ice = hex_rgb("#E3F2FD")

    canvas = Image.new("RGB", (512, 704), abyss)
    draw = ImageDraw.Draw(canvas)

    # 1. Celestial astronomical ring backdrop (matching the_sun_back.png)
    rcx, rcy = 256, 308
    draw.ellipse((rcx - 234, rcy - 234, rcx + 234, rcy + 234), fill=ocean)
    draw.ellipse((rcx - 216, rcy - 216, rcx + 216, rcy + 216), fill=abyss)
    draw.ellipse((rcx - 210, rcy - 210, rcx + 210, rcy + 210), outline=cobalt, width=6)
    draw.ellipse((rcx - 194, rcy - 194, rcx + 194, rcy + 194), outline=azure, width=3)
    draw.ellipse((rcx - 166, rcy - 166, rcx + 166, rcy + 166), outline=ocean, width=3)

    for deg in range(0, 360, 30):
        rad = math.radians(deg)
        x1 = rcx + math.cos(rad) * 166
        y1 = rcy + math.sin(rad) * 166
        x2 = rcx + math.cos(rad) * 210
        y2 = rcy + math.sin(rad) * 210
        draw.line([(x1, y1), (x2, y2)], fill=cobalt if deg % 90 != 0 else azure, width=3)
    for deg in range(0, 360, 45):
        rad = math.radians(deg)
        rx = rcx + math.cos(rad) * 202
        ry = rcy + math.sin(rad) * 202
        _draw_star(draw, rx, ry, 14 if deg % 90 == 0 else 9, 4, 4, ice if deg % 90 == 0 else pale, ink)

    # 2. Mystical swirling clouds at bottom & top corners (matching the_sun_back.png)
    _draw_cloud_cluster(
        draw,
        [(56, 548, 44), (110, 560, 48), (168, 574, 38), (456, 548, 44), (402, 560, 48), (344, 574, 38)],
        fill=cobalt,
        hi=sky,
        outline=ink,
    )
    _draw_cloud_cluster(
        draw,
        [(56, 92, 34), (104, 78, 28), (456, 92, 34), (408, 78, 28)],
        fill=ocean,
        hi=azure,
        outline=ink,
    )

    # 3. Clean C-shaped crescent (opens RIGHT, smooth inner curve, ZERO nose)
    ox, oy = _grid_to_512(MOON_OUTER_CX, MOON_OUTER_CY)
    ix, iy = _grid_to_512(MOON_INNER_CX, MOON_INNER_CY)
    scale = 506.0 / 74.0
    r_out = MOON_OUTER_R * scale
    r_in = MOON_INNER_R * scale

    px = canvas.load()
    for y in range(60, 580):
        for x in range(40, 480):
            do = math.hypot(x - ox, y - oy)
            di = math.hypot(x - ix, y - iy)
            if do <= r_out + 7.0 and di >= r_in - 7.0:
                if do > r_out or di < r_in:
                    px[x, y] = ink
                else:
                    # Cel-shaded bright moon blue with paler inner glow & azure outer rim
                    if do > r_out - 14.0:
                        px[x, y] = azure
                    elif di < r_in + 18.0:
                        px[x, y] = pale
                    else:
                        px[x, y] = sky

    # 4. Eerie black-sclera eye with bright white iris, tiny black pupil & spooky lashes
    ecx, ecy = _grid_to_512(MOON_EYE_CX, MOON_EYE_CY)
    r_eye = 4.6 * scale
    # Spooky spiky/wavy lashes around the eye rim
    for i in range(12):
        ang = math.radians(i * 30.0 + 10.0)
        sx = ecx + math.cos(ang) * (r_eye - 2.0)
        sy = ecy + math.sin(ang) * (r_eye - 2.0)
        ex = ecx + math.cos(ang) * (r_eye + (16.0 if i % 2 == 0 else 11.0))
        ey = ecy + math.sin(ang) * (r_eye + (16.0 if i % 2 == 0 else 11.0))
        # Only draw lash if it stays inside the crescent body
        if math.hypot(ex - ix, ey - iy) > r_in + 4.0:
            draw.line([(sx, sy), (ex, ey)], fill=ocean, width=6)
            draw.line([(sx, sy), (ex, ey)], fill=ink, width=3)

    # Whole eyeball filled with deep ink black (#081121)
    draw.ellipse((ecx - r_eye, ecy - r_eye, ecx + r_eye, ecy + r_eye), fill=ink)
    # Bright glowing white iris (#E3F2FD) slightly offset up-right like images.jfif
    icx, icy = ecx + 3.5, ecy - 2.0
    r_iris = 2.1 * scale
    draw.ellipse((icx - r_iris, icy - r_iris, icx + r_iris, icy + r_iris), fill=ice)
    # Tiny dark pupil dot (#081121) at center of white iris
    r_pupil = 0.65 * scale
    draw.ellipse((icx - r_pupil, icy - r_pupil, icx + r_pupil, icy + r_pupil), fill=ink)

    # 5. Wide curved toothy grin sweeping along the lower crescent toward the right horn
    top_pts = []
    bot_pts = []
    for gx in range(20, 58, 2):
        u = (gx - 38.0) / 18.0  # -1..1
        ty = 58.6 - 2.2 * (u * u) - (1.8 if gx > 44 else 0.0) * max(0.0, (gx - 44.0) / 14.0)
        by = 66.2 - 7.8 * (u * u)
        if by < ty + 2.2:
            by = ty + 2.2
        top_pts.append(_grid_to_512(gx, ty))
        bot_pts.append(_grid_to_512(gx, by))

    mouth_poly = top_pts + list(reversed(bot_pts))
    draw.polygon(mouth_poly, fill=ice, outline=ink)
    # Bold ink lip outline
    draw.line(top_pts, fill=ink, width=7)
    draw.line(bot_pts, fill=ink, width=7)
    # Curved horizontal bite line
    bite_pts = [((t[0] + b[0]) * 0.5, (t[1] + b[1]) * 0.5) for t, b in zip(top_pts, bot_pts)]
    draw.line(bite_pts, fill=ink, width=5)
    # Vertical tooth dividers
    for idx in range(2, len(top_pts) - 1, 2):
        draw.line([top_pts[idx], bot_pts[idx]], fill=ink, width=5)

    # 6. Crisp 4-point and 8-point stars framing the crescent
    _draw_star(draw, 84, 146, 26, 7, 8, ice, ink)
    _draw_star(draw, 430, 146, 28, 8, 8, ice, ink)
    _draw_star(draw, 92, 466, 20, 6, 4, pale, ink)
    _draw_star(draw, 422, 466, 20, 6, 4, pale, ink)
    _draw_star(draw, 256, 58, 22, 6, 4, ice, ink)

    # Keep bottom banner zone clean abyss blue
    draw.rectangle((0, 600, 512, 704), fill=abyss)
    return canvas


def center_crop_aspect(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    w, h = img.size
    target_ratio = target_w / target_h
    src_ratio = w / h
    if src_ratio > target_ratio:
        new_w = int(round(h * target_ratio))
        x0 = (w - new_w) // 2
        return img.crop((x0, 0, x0 + new_w, h))
    new_h = int(round(w / target_ratio))
    y0 = (h - new_h) // 2
    return img.crop((0, y0, w, y0 + new_h))


def build_palette_image(colors: List[RGB]) -> Image.Image:
    pal_img = Image.new("P", (1, 1))
    flat: List[int] = []
    for r, g, b in colors:
        flat.extend([r, g, b])
    while len(flat) < 768:
        flat.extend(colors[0])
    pal_img.putpalette(flat[:768])
    return pal_img


def quantize_to_fixed_palette(img_rgb: Image.Image, colors: List[RGB]) -> Image.Image:
    pal_img = build_palette_image(colors)
    q = img_rgb.quantize(palette=pal_img, dither=Image.Dither.NONE)
    return q.convert("RGBA")


def quantize_adaptive(img_rgb: Image.Image, max_colors: int = 18) -> Image.Image:
    q = img_rgb.quantize(
        colors=max_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    return q.convert("RGBA")


def apply_tarot_card_frame_and_banner(
    img_rgba: Image.Image,
    label: str,
    ink_rgb: RGB,
    dark_rgb: RGB,
    mid_rgb: RGB,
    hi_rgb: RGB,
) -> Image.Image:
    """
    Apply crisp 74x103 pixel Tarot border, 4 ornate corner flourishes, and a
    sharp pixel-art bottom banner (`* THE SUN *` / `* THE MOON *`).
    """
    w, h = img_rgba.size
    px = img_rgba.load()
    ink = (*ink_rgb, 255)
    dark = (*dark_rgb, 255)
    mid = (*mid_rgb, 255)
    hi = (*hi_rgb, 255)
    trans = (0, 0, 0, 0)

    # 1. Outer 2px ink border
    for x in range(w):
        for dy in (0, 1, h - 2, h - 1):
            px[x, dy] = ink
    for y in range(h):
        for dx in (0, 1, w - 2, w - 1):
            px[dx, y] = ink

    # 2. Inner Tarot ornamental frame at inset 2 (colored) & inset 3 (ink)
    for x in range(3, w - 3):
        px[x, 2] = hi if x % 3 == 0 else mid
        px[x, h - 3] = hi if x % 3 == 0 else mid
        px[x, 3] = ink
        px[x, h - 4] = ink
    for y in range(3, h - 3):
        px[2, y] = hi if y % 3 == 0 else mid
        px[w - 3, y] = hi if y % 3 == 0 else mid
        px[3, y] = ink
        px[w - 4, y] = ink

    # 3. Four ornate Tarot corner brackets (inside the frame)
    corner_pts = [
        (4, 4, hi), (5, 4, mid), (6, 4, mid), (7, 4, ink),
        (4, 5, mid), (5, 5, dark), (6, 5, ink),
        (4, 6, mid), (5, 6, ink),
        (4, 7, ink),
    ]
    for cx, cy, col in corner_pts:
        px[cx, cy] = col
        px[w - 1 - cx, cy] = col
        px[cx, h - 1 - cy] = col
        px[w - 1 - cx, h - 1 - cy] = col

    # 4. Crisp bottom Tarot name banner (y=88..98, x=4..70)
    for y in range(88, 99):
        for x in range(4, w - 4):
            px[x, y] = dark
    for x in range(4, w - 4):
        px[x, 88] = ink
        px[x, 89] = mid if x % 2 == 0 else hi
        px[x, 90] = ink
        px[x, 98] = ink
    # Side diamonds inside banner
    px[5, 94] = hi
    px[w - 6, 94] = hi

    # Draw centered pixel label (`* THE SUN *` / `* THE MOON *`)
    tw = measure_pixel_text(label, spacing=1)
    tx = (w - tw) // 2
    ty = 92
    # 1px dark drop shadow for crispness
    draw_pixel_text(px, w, h, label, tx, ty + 1, ink, spacing=1)
    draw_pixel_text(px, w, h, label, tx, ty, hi, spacing=1)

    # 5. Hard pixel-rounded outer corners (matching generate_card_frames.py)
    corner_cut = [
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1),
        (0, 2),
        (0, 3),
    ]
    corner_ink = [
        (3, 1), (2, 1), (1, 2), (2, 2), (1, 3),
    ]
    for cx, cy in corner_cut:
        px[cx, cy] = trans
        px[w - 1 - cx, cy] = trans
        px[cx, h - 1 - cy] = trans
        px[w - 1 - cx, h - 1 - cy] = trans
    for ix, iy in corner_ink:
        px[ix, iy] = ink
        px[w - 1 - ix, iy] = ink
        px[ix, h - 1 - iy] = ink
        px[w - 1 - ix, h - 1 - iy] = ink

    return img_rgba


def _stamp_pixel_star(px, w: int, h: int, cx: int, cy: int, size: int, hi: RGBA, mid: RGBA) -> None:
    """Stamp a razor-sharp 4-point or 8-point pixel sparkle star onto 74x103 grid."""
    if 0 <= cx < w and 0 <= cy < h:
        px[cx, cy] = hi
    for d in range(1, size + 1):
        col = hi if d <= max(1, size - 1) else mid
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            tx, ty = cx + dx, cy + dy
            if 0 <= tx < w and 0 <= ty < h:
                px[tx, ty] = col
    if size >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            tx, ty = cx + dx, cy + dy
            if 0 <= tx < w and 0 <= ty < h:
                px[tx, ty] = mid


def refine_sun_face_74x103(img_rgba: Image.Image) -> None:
    """
    Pixel-crisp refinement on the 74x103 grid for THE SUN:
    - Sinister narrow squinting eyes (^ ^) in #121014 (no round/wide eyes)
    - Wide sinister toothy grin stretching across the lower disk with crisp
      individual #FFF0C2 teeth separated by 1px #121014 ink dividers.
    """
    px = img_rgba.load()
    w, h = img_rgba.size

    ink = (*hex_rgb("#121014"), 255)
    burnt = (*hex_rgb("#A83B1B"), 255)
    ember = (*hex_rgb("#D96B27"), 255)
    gold = (*hex_rgb("#F4A236"), 255)
    bright = (*hex_rgb("#FFD166"), 255)
    cream = (*hex_rgb("#FFF0C2"), 255)

    def put(x: int, y: int, col: RGBA) -> None:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = col

    # 1. Clean the eye & brow zones back to bright golden sun face
    for y in range(37, 47):
        for x in range(24, 51):
            # Preserve circular face perimeter shading near outer edges
            dx = x - 37
            dy = y - 45
            dist = math.hypot(dx, dy)
            if dist <= 13.5:
                put(x, y, cream if dist <= 10.5 else bright)

    # Subtle stylized nose bridge at center
    for y in range(43, 47):
        put(37, y, gold)
    put(36, 46, ember)
    put(38, 46, ember)
    put(37, 46, burnt)

    # 2. Stamp razor-sharp sinister squinting curved eyes (^ ^)
    # Left eye (x=25..34, y=38..44) & mirrored right eye (x=40..49)
    left_brow = [(25, 39), (26, 38), (27, 38), (28, 38), (29, 38), (30, 38), (31, 39), (32, 39), (33, 40)]
    left_slit_main = [
        (25, 43), (26, 42), (27, 41), (28, 40), (29, 40), (30, 40), (31, 40), (32, 41), (33, 42), (34, 43),
    ]
    left_slit_thick = [(27, 42), (28, 41), (29, 41), (30, 41), (31, 41), (32, 42)]
    left_squint_crease = [(26, 44), (27, 43), (28, 43), (29, 43), (30, 43), (31, 43), (32, 43), (33, 44)]
    left_flick = [(24, 42)]

    for side in (-1, 1):
        def mx(x: int) -> int:
            return x if side == -1 else (74 - x)

        for x, y in left_brow:
            put(mx(x), y, ember)
        for x, y in left_squint_crease:
            put(mx(x), y, gold)
        for x, y in left_slit_thick:
            put(mx(x), y, burnt)
        for x, y in left_slit_main:
            put(mx(x), y, ink)
        for x, y in left_flick:
            put(mx(x), y, ink)

    # 3. Clean lower face & stamp wide sinister toothy grin (x=23..51, y=47..58)
    for y in range(47, 59):
        for x in range(23, 52):
            dx = x - 37
            dy = y - 45
            dist = math.hypot(dx, dy)
            if dist <= 14.5:
                put(x, y, bright if dist <= 12.2 else gold)

    # Define wide upturned smile top & bottom y-bounds per x in [24..50]
    # Center is x=37; corners pull sharply upward at x=24 and x=50
    top_y = {}
    bot_y = {}
    for x in range(24, 51):
        u = (x - 37) / 13.0  # -1..1
        # Top lip dips slightly in center, sweeps up at corners
        ty = int(round(50.6 - 2.6 * (u * u)))
        # Bottom lip curves deeply downward in center, meets top at corners
        by = int(round(57.4 - 7.8 * (u * u)))
        if by < ty + 1:
            by = ty + 1
        top_y[x] = ty
        bot_y[x] = by

    # Fill mouth interior with #121014 ink + 1px dark outline
    for x in range(24, 51):
        for y in range(top_y[x], bot_y[x] + 1):
            put(x, y, ink)
    # Sharp upturned corner ticks & cheek creases
    for sx in (23, 51):
        put(sx, 47, ink)
        put(sx, 48, ink)
        put(sx, 49, ember)
    put(24, 47, ember)
    put(50, 47, ember)

    # Fill individual gleaming #FFF0C2 teeth with razor-sharp 1px #121014 dividers
    # Vertical tooth seams at x = 28, 31, 34, 37, 40, 43, 46 (2px wide teeth!)
    tooth_seams = {28, 31, 34, 37, 40, 43, 46}
    for x in range(25, 50):
        if x in tooth_seams:
            continue
        ty = top_y[x]
        by = bot_y[x]
        # Horizontal curved bite line separating upper & lower teeth rows
        u = (x - 37) / 13.0
        bite_y = int(round(54.0 - 4.8 * (u * u)))
        for y in range(ty + 1, by):
            if y == bite_y and (by - ty) >= 5:
                put(x, y, ink)
            else:
                put(x, y, cream)


def refine_moon_face_74x103(img_rgba: Image.Image) -> None:
    """
    Pixel-crisp 74x103 polish for THE MOON (C-crescent opening RIGHT, NO nose):
    1. Strictly cleans the inner crescent cavity so the inner curve is 100% smooth
       with ZERO nose protrusion, and crisps the 1px #081121 ink outline of the C-crescent.
    2. Stamps the eerie black-sclera (#081121) eye at (25, 44) with a blazing ice-white
       (#E3F2FD) iris, 1px #081121 center pupil dot, and short spooky lashes/spikes.
    3. Stamps the wide curved 2-row toothy grin (#E3F2FD teeth, 1px #081121 dividers
       and curved bite line) sweeping up along the lower crescent toward the right horn.
    """
    px = img_rgba.load()
    w, h = img_rgba.size

    ink = (*hex_rgb("#081121"), 255)
    abyss = (*hex_rgb("#0B224D"), 255)
    ocean = (*hex_rgb("#0B3D91"), 255)
    cobalt = (*hex_rgb("#195EC2"), 255)
    azure = (*hex_rgb("#3B86E8"), 255)
    sky = (*hex_rgb("#64B5F6"), 255)
    pale = (*hex_rgb("#A6D8FA"), 255)
    ice = (*hex_rgb("#E3F2FD"), 255)

    def put(x: int, y: int, col: RGBA) -> None:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = col

    # 1. Enforce smooth nose-free C-crescent inner arc & crisp 1px #081121 outline
    ox, oy, r_out = MOON_OUTER_CX, MOON_OUTER_CY, MOON_OUTER_R
    ix, iy, r_in = MOON_INNER_CX, MOON_INNER_CY, MOON_INNER_R
    bright_moon_cols = {sky, pale, ice, azure}

    for y in range(16, 75):
        for x in range(10, 68):
            do = math.hypot(x - ox, y - oy)
            di = math.hypot(x - ix, y - iy)

            # Inside the inner crescent cutout cavity -> strip any stray nose pixels back to night sky
            if di < r_in - 0.6 and do <= r_out + 2.0:
                if px[x, y] in bright_moon_cols:
                    # Keep subtle celestial ring tone if near ring radius (~28..31 from center 37,45)
                    dr = math.hypot(x - 37.0, y - 45.0)
                    put(x, y, ocean if 24.0 <= dr <= 29.0 else abyss)
                continue

            # Inside crescent body
            if do <= r_out and di >= r_in:
                # Crisp 1px ink outline on outer & inner crescent curves
                if do >= r_out - 1.1 or di <= r_in + 1.1:
                    put(x, y, ink)
                else:
                    # Ensure clean bright moon cel-shading on inner rim & cheek
                    if di <= r_in + 2.6 and px[x, y] in (ink, abyss, ocean):
                        put(x, y, pale)
                    elif px[x, y] in (abyss, ocean):
                        put(x, y, sky)

    # 2. Stamp eerie black-sclera (#081121) eye with glowing #E3F2FD iris & 1px #081121 pupil
    ecx, ecy = MOON_EYE_CX, MOON_EYE_CY
    # Clean cheek around eye socket first so lashes & rim pop cleanly
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            tx, ty = ecx + dx, ecy + dy
            do = math.hypot(tx - ox, ty - oy)
            di = math.hypot(tx - ix, ty - iy)
            d_eye = math.hypot(dx, dy)
            if d_eye <= 7.2 and do < r_out - 1.4 and di > r_in + 1.4:
                put(tx, ty, pale if di < r_in + 3.6 else sky)

    # Connected short spooky lashes/flares radiating from eye rim (no detached dotted ring)
    lash_rays = [
        [(-5, -2), (-6, -3)],
        [(-5, 0), (-6, 0)],
        [(-5, 2), (-6, 3)],
        [(-4, 4), (-5, 5)],
        [(-2, 5), (-2, 6)],
        [(0, 5), (0, 6)],
        [(2, 5), (2, 6)],
        [(4, 4), (5, 5)],
        [(5, 2), (6, 2)],
        [(5, -2), (6, -3)],
        [(4, -4), (5, -5)],
        [(2, -5), (2, -6)],
        [(0, -5), (0, -6)],
        [(-2, -5), (-2, -6)],
        [(-4, -4), (-5, -5)],
    ]
    for ray in lash_rays:
        for idx, (ldx, ldy) in enumerate(ray):
            lx, ly = ecx + ldx, ecy + ldy
            if math.hypot(lx - ix, ly - iy) > r_in + 1.3 and math.hypot(lx - ox, ly - oy) < r_out - 1.3:
                put(lx, ly, ocean if idx == 0 else cobalt)
        # Sharp dark tip on alternating longer spikes
        tx, ty = ecx + ray[0][0], ecy + ray[0][1]
        if math.hypot(tx - ix, ty - iy) > r_in + 1.4 and math.hypot(tx - ox, ty - oy) < r_out - 1.3:
            put(tx, ty, ink)

    # Large solid black eyeball (#081121, radius 4.4 -> ~9px diameter)
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            if math.hypot(dx, dy) <= 4.35:
                put(ecx + dx, ecy + dy, ink)

    # Glowing round white iris (#E3F2FD) slightly offset +1x, -0y inside the black eyeball
    icx, icy = ecx + 1, ecy
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if math.hypot(dx, dy) <= 2.05:
                put(icx + dx, icy + dy, ice)
    # 1px crisp dark pupil dot (#081121) right at the center of the white iris
    put(icx, icy, ink)

    # 3. Stamp wide curved 2-row toothy grin sweeping up toward the right horn
    top_y: Dict[int, int] = {}
    bot_y: Dict[int, int] = {}
    for x in range(19, 57):
        dx_out = x - ox
        if abs(dx_out) >= r_out - 1.5:
            continue
        y_out_max = oy + math.sqrt((r_out - 1.5) ** 2 - dx_out * dx_out)

        dx_in = x - ix
        if abs(dx_in) < r_in + 1.3:
            y_in_min = iy + math.sqrt((r_in + 1.3) ** 2 - dx_in * dx_in)
        else:
            y_in_min = 52.0

        u = (x - 37.5) / 18.5  # -1..1
        ty_raw = 58.6 - 2.6 * (u * u)
        if x > 44:
            ty_raw -= 2.0 * ((x - 44.0) / 12.0) ** 1.15
        by_raw = 66.8 - 8.4 * (u * u)

        ty = int(round(max(ty_raw, y_in_min + 0.5)))
        by = int(round(min(by_raw, y_out_max - 0.8)))
        if by < ty + 2:
            continue
        top_y[x] = ty
        bot_y[x] = by

    xs = sorted(top_y.keys())
    if xs:
        x_min, x_max = xs[0], xs[-1]
        # Fill outer ink lip border & mouth cavity (#081121)
        for x in xs:
            for y in range(top_y[x], bot_y[x] + 1):
                put(x, y, ink)
        # Sharp upturned grin corner ticks
        put(x_min - 1, top_y[x_min] - 1, ink)
        put(x_min - 1, top_y[x_min], ink)
        put(x_max + 1, top_y[x_max] - 1, ink)
        put(x_max + 1, top_y[x_max], ink)

        # Fill gleaming #E3F2FD teeth with crisp 1px #081121 vertical seams & smooth curved bite line
        seams = {24, 28, 32, 36, 40, 44, 48, 52}
        for x in xs[1:-1]:
            if x in seams:
                continue
            ty = top_y[x]
            by = bot_y[x]
            span = by - ty
            u = (x - 37.5) / 18.5
            bite_y = int(round(62.8 - 5.0 * (u * u)))
            for y in range(ty + 1, by):
                if span >= 5 and y == bite_y and ty + 1 < bite_y < by - 1:
                    put(x, y, ink)
                else:
                    put(x, y, ice if (y < by - 1 or span <= 4) else pale)


def _classify_moon_ref_pixel(r: int, g: int, b: int, x: int, y: int, w: int, h: int) -> str:
    """
    Smart color-grading classifier for tasks/images.jfif -> locked 8-color MOON_PALETTE.
    Preserves 100% of the hand-drawn Moon silhouette, black-sclera white-iris eye,
    fiery eye-lashes, and curved grinning teeth without redrawing any geometry.
    """
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    hue, sat, val = colorsys.rgb_to_hsv(rf, gf, bf)

    # 1. Strip the cropped cyan star at top-right (x > 74%, y < 22%) so Tarot stars shine cleanly
    if x > int(w * 0.74) and y < int(h * 0.22):
        return "bg"

    # 2. Strip the clipped orange flame wisp at far bottom-left outside the crescent
    if x < int(w * 0.21) and y > int(h * 0.72):
        if not (0.11 <= hue <= 0.22 and val > 0.72):
            return "bg"

    # 3. Deep black ink outlines, black sclera, tiny pupil dot, tooth dividers
    if val < 0.25 or (val < 0.34 and sat < 0.42):
        return "ink"

    # 4. Purple swirl cloud at bottom-right (x > 66%, y > 64%): map cloud & its beige rim to ocean/cobalt/azure (never white ice)
    if x > int(w * 0.66) and y > int(h * 0.64):
        if 0.56 <= hue <= 0.74 and val < 0.48:
            return "bg"
        if (0.62 <= hue <= 0.92) or (sat < 0.35 and val < 0.85):
            if val >= 0.68:
                return "azure"
            if val >= 0.52:
                return "cobalt"
            return "ocean"

    # 5. Crisp white teeth & glowing white iris
    if sat < 0.24 and val >= 0.66:
        return "ice"
    if sat < 0.28 and val >= 0.46:
        if 0.52 <= hue <= 0.78 and val < 0.60:
            return "bg"
        return "pale"

    # 6. Dark indigo/blue-purple night sky background & soft glow halo around the moon
    if 0.54 <= hue <= 0.73 and val < 0.52:
        return "bg"

    # 7. Bright yellow moon body -> bright moon blue (#64B5F6) / azure (#3B86E8)
    if 0.11 <= hue <= 0.24 and val >= 0.55:
        if val >= 0.83 and hue >= 0.135:
            return "sky"
        return "azure"

    # 8. Orange shading, crescent bottom rim, craters, fiery lashes around the eye -> #195EC2 / #0B3D91
    if (hue < 0.11 or hue > 0.92) and sat >= 0.30:
        if val >= 0.62:
            return "cobalt"
        return "ocean"

    # 9. Remaining purple/indigo halo transitions -> bg if low val, else ocean
    if 0.50 <= hue <= 0.88:
        if val < 0.56:
            return "bg"
        return "ocean"

    return "sky" if val > 0.65 else "cobalt"


def _strip_bg_connected_components(grid: List[List[str]], w: int, h: int) -> None:
    """
    Flood-fill from the 4 corners through background/halo pixels so the night sky
    is cleanly transparent while keeping dark ink inside the moon (eye, teeth, outline)
    100% intact. Also cleans tiny isolated specks in the sky.
    """
    visited = [[False] * w for _ in range(h)]
    stack: List[Tuple[int, int]] = []
    for x in range(w):
        for y in (0, h - 1):
            if grid[y][x] == "bg":
                visited[y][x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if grid[y][x] == "bg" and not visited[y][x]:
                visited[y][x] = True
                stack.append((x, y))

    while stack:
        cx, cy = stack.pop()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                if grid[ny][nx] == "bg":
                    visited[ny][nx] = True
                    stack.append((nx, ny))

    # Any non-border 'bg' pixel enclosed inside the moon (e.g. inside shaded teeth/eye)
    # should NOT become transparent sky — convert it back to dark ocean/ink.
    for y in range(h):
        for x in range(w):
            if grid[y][x] == "bg" and not visited[y][x]:
                grid[y][x] = "ocean"


def build_moon_from_reference_74x103(ref_path: Path) -> Image.Image:
    """
    Build the 74x103 Tarot 'THE MOON' card back directly from tasks/images.jfif:
    1. Smart color-grading of tasks/images.jfif into the locked 8-color ocean-blue
       MOON_PALETTE (preserving 100% of the hand-drawn crescent, black-sclera eye,
       fiery lashes, and curved toothy grin — ZERO geometric face redraw).
    2. Ink-preserving pixel-art downscale onto the 74x103 Tarot grid.
    3. Layered over a subtle Tarot celestial astronomical ring, swirling bottom/corner
       clouds, and sparkling 4-point ice-white stars (strictly in background/frame,
       NEVER overlapping the moon face).
    4. Framed with the identical Tarot dotted border, 4 corner flourishes, and
       `* THE MOON *` banner matching the_sun_back.png.
    """
    if not ref_path.exists():
        raise FileNotFoundError(f"Missing Moon reference image: {ref_path}")

    palette_map: Dict[str, RGBA] = {
        "ink": (*hex_rgb("#081121"), 255),
        "abyss": (*hex_rgb("#0B224D"), 255),
        "ocean": (*hex_rgb("#0B3D91"), 255),
        "cobalt": (*hex_rgb("#195EC2"), 255),
        "azure": (*hex_rgb("#3B86E8"), 255),
        "sky": (*hex_rgb("#64B5F6"), 255),
        "pale": (*hex_rgb("#A6D8FA"), 255),
        "ice": (*hex_rgb("#E3F2FD"), 255),
    }

    # --- Step 1: Load & classify images.jfif at full resolution ---
    ref_img = Image.open(ref_path).convert("RGB")
    rw, rh = ref_img.size
    rpx = ref_img.load()

    ref_grid: List[List[str]] = [
        [_classify_moon_ref_pixel(*rpx[x, y], x, y, rw, rh) for x in range(rw)]
        for y in range(rh)
    ]
    _strip_bg_connected_components(ref_grid, rw, rh)

    # --- Step 2: Paint Tarot night sky + subtle celestial astronomical ring on 74x103 ---
    w, h = 74, 103
    canvas = Image.new("RGBA", (w, h), palette_map["abyss"])
    px = canvas.load()

    # Subtle outer vignette & faint astronomical ring centered behind the moon
    rcx, rcy = 37.0, 45.0
    for y in range(4, 88):
        for x in range(4, w - 4):
            dist = math.hypot(x - rcx, y - rcy)
            # Outer vignette corners -> deep ink midnight
            if dist > 36.5:
                px[x, y] = palette_map["ink"]
            # Faint outer & inner celestial rings (never overpowering the bright moon)
            elif 28.6 <= dist <= 30.2:
                px[x, y] = palette_map["cobalt"] if (x + y) % 3 == 0 else palette_map["ocean"]
            elif 25.0 <= dist <= 26.2:
                px[x, y] = palette_map["ocean"]
            elif 26.2 < dist < 28.6:
                ang = math.degrees(math.atan2(y - rcy, x - rcx)) % 30.0
                if ang < 2.4 or ang > 27.6:
                    px[x, y] = palette_map["ocean"]

    # Subtle top-corner night clouds behind the ring (matching the_sun_back.png balance)
    top_clouds = [
        (11, 13, 6.2), (16, 11, 4.8), (8, 16, 4.2),
        (63, 13, 6.2), (58, 11, 4.8), (66, 16, 4.2),
    ]
    for ccx, ccy, cr in top_clouds:
        for y in range(4, 24):
            for x in range(4, w - 4):
                d = math.hypot(x - ccx, y - ccy)
                if d <= cr:
                    px[x, y] = palette_map["ocean"] if d > cr * 0.55 else palette_map["cobalt"]

    # --- Step 3: Ink-preserving pixel-art downscale of images.jfif onto center of 74x103 ---
    # Place the 447x447 moon at x=6..69, y=13..76 (64x64) so right swirl cloud meets the frame seamlessly
    box_x0, box_y0 = 6, 13
    box_w, box_h = 64, 64
    moon_mask = [[False] * w for _ in range(h)]

    for gy in range(box_h):
        sy0 = int(gy * rh / box_h)
        sy1 = max(sy0 + 1, int((gy + 1) * rh / box_h))
        for gx in range(box_w):
            sx0 = int(gx * rw / box_w)
            sx1 = max(sx0 + 1, int((gx + 1) * rw / box_w))

            counts: Counter = Counter()
            total = 0
            for sy in range(sy0, sy1):
                row = ref_grid[sy]
                for sx in range(sx0, sx1):
                    counts[row[sx]] += 1
                    total += 1

            bg_frac = counts["bg"] / total
            ink_frac = counts["ink"] / total
            ice_frac = counts["ice"] / total

            # Transparent sky if mostly background and not an ink outline
            if bg_frac > 0.58 and ink_frac < 0.20:
                continue

            tx, ty = box_x0 + gx, box_y0 + gy
            if not (4 <= tx < w - 4 and 4 <= ty < 88):
                continue

            # Priority vote preserving crisp 1px hand-drawn ink outlines, pupil, and vertical tooth seams
            if ink_frac >= 0.26 or (ice_frac >= 0.22 and ink_frac >= 0.16):
                chosen = "ink"
            elif ice_frac >= 0.34:
                chosen = "ice"
            else:
                fg_counts = {k: v for k, v in counts.items() if k != "bg"}
                if not fg_counts:
                    continue
                # Slight weight boost for fiery eye-lashes / shading (cobalt) so they stay crisp
                if "cobalt" in fg_counts and fg_counts["cobalt"] / total >= 0.22:
                    chosen = "cobalt"
                else:
                    chosen = max(fg_counts.items(), key=lambda kv: kv[1])[0]

            px[tx, ty] = palette_map[chosen]
            moon_mask[ty][tx] = True

    # --- Step 4: Swirling pixel clouds hugging the bottom above `* THE MOON *` banner ---
    # Drawn ONLY where they don't cover the moon's grin/body (y=74..87)
    bot_clouds = [
        # Left bank (wavy organic billow)
        (8, 83, 6.2), (14, 79, 5.4), (20, 82, 5.0), (26, 85, 4.4), (31, 87, 3.2),
        # Right bank (flows naturally beneath the swirl cloud of images.jfif)
        (65, 83, 6.2), (59, 79, 5.4), (53, 82, 5.0), (47, 85, 4.4), (42, 87, 3.2),
    ]
    for y in range(73, 88):
        for x in range(4, w - 4):
            if moon_mask[y][x]:
                continue
            min_norm = 99.0
            top_hi = False
            for ccx, ccy, cr in bot_clouds:
                d = math.hypot((x - ccx) * 0.92, (y - ccy) * 1.15)
                norm = d / cr
                if norm < min_norm:
                    min_norm = norm
                    top_hi = (y < ccy - cr * 0.20)
            if min_norm <= 1.0:
                if min_norm > 0.87:
                    px[x, y] = palette_map["ink"]
                elif top_hi and min_norm < 0.78:
                    px[x, y] = palette_map["sky"] if min_norm < 0.55 else palette_map["azure"]
                elif min_norm < 0.66:
                    px[x, y] = palette_map["cobalt"]
                else:
                    px[x, y] = palette_map["ocean"]

    # --- Step 5: Crisp 4-point sparkling `#E3F2FD` stars in open sky (never on moon) ---
    stars = [
        (11, 13, 3), (62, 13, 3), (37, 9, 2),
        (56, 21, 2), (10, 72, 2), (63, 71, 2),
        (19, 18, 1), (48, 29, 1), (59, 34, 1),
    ]
    for sx, sy, ssz in stars:
        if not moon_mask[sy][sx]:
            _stamp_pixel_star(px, w, h, sx, sy, ssz, palette_map["ice"], palette_map["sky"])

    # --- Step 6: Identical Tarot dotted border, 4 corner flourishes & `* THE MOON *` banner ---
    framed = apply_tarot_card_frame_and_banner(
        canvas,
        label="* THE MOON *",
        ink_rgb=hex_rgb("#081121"),
        dark_rgb=hex_rgb("#0B224D"),
        mid_rgb=hex_rgb("#64B5F6"),
        hi_rgb=hex_rgb("#E3F2FD"),
    )
    return framed.resize((148, 206), Image.Resampling.NEAREST)


def postprocess_card_back(
    raw_img: Image.Image,
    palette: List[RGB],
    label: str,
    ink_rgb: RGB,
    dark_rgb: RGB,
    mid_rgb: RGB,
    hi_rgb: RGB,
    stars: List[Tuple[int, int, int]] = (),
    contrast_boost: float = 1.18,
    pixel_refine_fn=None,
) -> Image.Image:
    cropped = center_crop_aspect(raw_img, 74, 103)
    if contrast_boost != 1.0:
        cropped = ImageEnhance.Contrast(cropped).enhance(contrast_boost)
    small = cropped.resize((74, 103), Image.Resampling.BOX)
    quant = quantize_to_fixed_palette(small, palette)
    if pixel_refine_fn is not None:
        pixel_refine_fn(quant)
    if stars:
        px = quant.load()
        w, h = quant.size
        hi_a = (*hi_rgb, 255)
        mid_a = (*mid_rgb, 255)
        for sx, sy, ssz in stars:
            _stamp_pixel_star(px, w, h, sx, sy, ssz, hi_a, mid_a)
    framed = apply_tarot_card_frame_and_banner(
        quant,
        label=label,
        ink_rgb=ink_rgb,
        dark_rgb=dark_rgb,
        mid_rgb=mid_rgb,
        hi_rgb=hi_rgb,
    )
    return framed.resize((148, 206), Image.Resampling.NEAREST)


def postprocess_card_art(raw_img: Image.Image) -> Image.Image:
    """Snap to 68x52 base grid -> 18 crisp colors -> 2x NEAREST -> 136x104."""
    cropped = center_crop_aspect(raw_img, 68, 52)
    small = cropped.resize((68, 52), Image.Resampling.BOX)
    quant = quantize_adaptive(small, max_colors=18)
    return quant.resize((136, 104), Image.Resampling.NEAREST)


def compose_sample_card(art_img: Image.Image, frame_path: Path) -> Image.Image:
    """
    Composite sample_card_art.png + frame_active.png + dark pixel text (#1A1A1D)
    so Game Designer can inspect a complete finished card immediately.
    """
    frame = Image.open(frame_path).convert("RGBA")
    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    # Art window starts at (3, 14) on 74x103 -> (6, 28) on 148x206
    canvas.paste(art_img, (6, 28))
    composed = Image.alpha_composite(canvas, frame)

    # Render crisp dark #1A1A1D pixel text directly at 148x206
    px = composed.load()
    w, h = composed.size
    text_dark = (*hex_rgb("#1A1A1D"), 255)

    # Title on top parchment strip (avoiding top-left badge & top-right swirl)
    title = "VONG LUA SINH TU"
    # Draw title at 1.0x crisp 3x5 (each char 3px + 1px spacing -> ~63px wide)
    # Place centered in the clear parchment zone x=30..118, y=13..18
    tw = measure_pixel_text(title, spacing=1)
    tx = 30 + (88 - tw) // 2
    draw_pixel_text(px, w, h, title, tx, 14, text_dark, spacing=1)

    # Description lines on bottom parchment box (y=138..184, x=18..130)
    desc_lines = [
        "TAO VONG LUA 3X3.",
        "QUAN DUNG NGOAI VONG",
        "MAT 1 DIEM / LUOT.",
    ]
    start_y = 144
    line_step = 11
    for idx, line in enumerate(desc_lines):
        lw = measure_pixel_text(line, spacing=1)
        lx = (w - lw) // 2
        ly = start_y + idx * line_step
        draw_pixel_text(px, w, h, line, lx, ly, text_dark, spacing=1)

    return composed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Chess to Die Golden Standard Tarot backs and optional sample card."
    )
    parser.add_argument(
        "--backs-only",
        action="store_true",
        help="Regenerate only the_sun_back.png and the_moon_back.png (keep sample card untouched).",
    )
    parser.add_argument(
        "--moon-only",
        action="store_true",
        help="Regenerate ONLY the_moon_back.png (NEVER touch the_sun_back.png or sample cards).",
    )
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.moon_only:
        total_steps = 1
    elif args.backs_only:
        total_steps = 2
    else:
        total_steps = 4

    neg_back = (
        "human, girl, boy, woman, man, person, body, hair, anime character, portrait, "
        "hands, neck, shoulders, clothing, realistic, photograph, 3d render, "
        "blurry, anti-aliasing, smooth gradient, watermark, signature, messy text, letters, low contrast"
    )

    # 1. Active card back: Original Tarot "The Sun" via Pillow sketch guide + SD Forge img2img
    if not args.moon_only:
        print(f"[1/{total_steps}] Generating the_sun_back.png via original sketch + SD Forge img2img (512x704)...")
        sun_init = build_sun_sketch_guide()
        sun_prompt = (
            "pixel art tarot card emblem, blazing golden sun disk with happy mischievous CLOSED squinting eyes "
            "curved upside-down U arcs shut eyes with no eyeballs, huge wide toothy grin showing gleaming cream teeth "
            "inside dark black mouth, two-layer spiky fiery solar rays, ornate celestial astronomical ring, "
            "swirling crimson ember clouds in corners, dark crimson background, bold black ink outlines, "
            "Balatro high contrast 16-bit pixel art style, warm gold orange cream crimson palette, "
            "celestial symbol only, no human, no body"
        )
        raw_sun = call_sd_img2img(
            init_img=sun_init,
            prompt=sun_prompt,
            negative_prompt=neg_back + ", open eyes, eyeballs, pupils, irises, glowing eyes, blue, cyan, teal, green, cold colors",
            width=512,
            height=704,
            seed=71089,
            denoising_strength=0.62,
            steps=24,
            cfg_scale=7.5,
        )
        sun_final = postprocess_card_back(
            raw_sun,
            palette=SUN_PALETTE,
            label="* THE SUN *",
            ink_rgb=hex_rgb("#121014"),
            dark_rgb=hex_rgb("#2E0F15"),
            mid_rgb=hex_rgb("#F4A236"),
            hi_rgb=hex_rgb("#FFF0C2"),
            stars=[(11, 14, 3), (62, 14, 3), (10, 72, 2), (63, 72, 2), (37, 9, 2), (18, 22, 1), (55, 22, 1)],
            contrast_boost=1.20,
            pixel_refine_fn=refine_sun_face_74x103,
        )
        sun_path = OUT_DIR / "the_sun_back.png"
        sun_final.save(sun_path, format="PNG")
        print(f"      Saved {sun_path} ({sun_final.size[0]}x{sun_final.size[1]})")

    # 2. Passive card back: Tarot "The Moon" directly color-graded from tasks/images.jfif
    step_idx = 1 if args.moon_only else 2
    print(f"[{step_idx}/{total_steps}] Generating the_moon_back.png directly from tasks/images.jfif (color-graded 74x103 -> 148x206)...")
    moon_final = build_moon_from_reference_74x103(REF_MOON_PATH)
    moon_path = OUT_DIR / "the_moon_back.png"
    tmp_path = OUT_DIR / "the_moon_back.tmp.png"
    with open(tmp_path, "wb") as f:
        moon_final.save(f, format="PNG")
    os.replace(tmp_path, moon_path)
    print(f"      Saved {moon_path} ({moon_final.size[0]}x{moon_final.size[1]})")

    if args.moon_only:
        print("Done (--moon-only: ONLY the_moon_back.png updated; the_sun_back.png untouched).")
        return

    if args.backs_only:
        print("Done (--backs-only: frames & sample card left untouched).")
        return

    # 3. Sample card illustration: Ring of Death (Vong Lua Sinh Tu) 136x104
    print(f"[3/{total_steps}] Generating sample_card_art.png via SD Forge txt2img (512x384)...")
    art_prompt = (
        "pixel art, Balatro dark fantasy game card illustration, carved obsidian chess piece statue "
        "standing in the center of a dark checkered chessboard, encircled by a blazing circular ring "
        "of orange and gold hellfire flames, dramatic high contrast dark fantasy lighting, "
        "bold black ink outlines, limited color palette, crisp 16-bit pixel art, object focus"
    )
    neg_art = (
        "human, man, woman, person, face, portrait, warrior, beard, character, head, "
        "blurry, anti-aliasing, smooth gradient, 3d render, photograph, realistic, "
        "text, letters, watermark, signature, white background, frame border"
    )
    raw_art = call_sd_txt2img(
        prompt=art_prompt,
        negative_prompt=neg_art,
        width=512,
        height=384,
        seed=31042,
        steps=24,
        cfg_scale=7.5,
    )
    art_final = postprocess_card_art(raw_art)
    art_path = OUT_DIR / "sample_card_art.png"
    art_final.save(art_path, format="PNG")
    print(f"      Saved {art_path} ({art_final.size[0]}x{art_final.size[1]})")

    # 4. Composed complete sample card (art + frame_active.png + crisp pixel text)
    print(f"[4/{total_steps}] Composing sample_card_composed.png (148x206)...")
    if not FRAME_ACTIVE_PATH.exists():
        raise FileNotFoundError(
            f"Missing {FRAME_ACTIVE_PATH}. Run generate_card_frames.py first."
        )
    composed = compose_sample_card(art_final, FRAME_ACTIVE_PATH)
    composed_path = OUT_DIR / "sample_card_composed.png"
    composed.save(composed_path, format="PNG")
    print(f"      Saved {composed_path} ({composed.size[0]}x{composed.size[1]})")


if __name__ == "__main__":
    main()
