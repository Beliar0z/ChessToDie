# E:\ChessToDie\tools\art_pipeline\generate_card_frames.py
# Python / generate_card_frames.py / Python 3 + Pillow / Chess to Die (Ag5)
"""
Generate Golden Standard V2 pixel-art front card frames for Chess to Die.
Inspired by tasks/samplecard.jfif and locked to design/art_bible.md.

Base pixel grid: 74x103 -> 2x NEAREST upscale -> 148x206 RGBA.
Art window bounding box on base grid: x=3..71 (68px), y=14..66 (52px)
-> 136x104 at 2x output, with organic top-left badge, top-right swirl,
and bottom swirling mist border overlapping the edges. The interior art
window is 100% transparent (alpha == 0).

Outputs:
  - assets/ui/textures/frame_active.png  (148x206 RGBA)
  - assets/ui/textures/frame_passive.png (148x206 RGBA)
"""

from pathlib import Path
from typing import Dict, List, Tuple
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "ui" / "textures"

BASE_W = 74
BASE_H = 103
SCALE = 2

# Art window bounding box on 74x103 base grid (68x52 -> 136x104 at 2x)
ART_X0, ART_Y0 = 3, 14
ART_X1, ART_Y1 = 71, 66  # exclusive

RGBA = Tuple[int, int, int, int]


def hex_rgba(code: str, alpha: int = 255) -> RGBA:
    c = code.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), alpha)


COMMON: Dict[str, RGBA] = {
    "transparent": (0, 0, 0, 0),
    "paper": hex_rgba("#F5EFE6"),
    "paper_shadow": hex_rgba("#D9CEBE"),
    "paper_hi": hex_rgba("#FFFDF8"),
}

THEMES: Dict[str, Dict[str, object]] = {
    "frame_active.png": {
        "kind": "active",
        "ink": hex_rgba("#121014"),
        "dark": hex_rgba("#2E0F15"),
        "shade": hex_rgba("#A83B1B"),
        "mid": hex_rgba("#F4A236"),
        "hi": hex_rgba("#FFF0C2"),
        "tint": hex_rgba("#EAD3B8"),
    },
    "frame_passive.png": {
        "kind": "passive",
        "ink": hex_rgba("#081121"),
        "dark": hex_rgba("#0B3D91"),
        "shade": hex_rgba("#1D62C2"),
        "mid": hex_rgba("#64B5F6"),
        "hi": hex_rgba("#E3F2FD"),
        "tint": hex_rgba("#D5E5F5"),
    },
}


def set_px(px, x: int, y: int, color: RGBA) -> None:
    if 0 <= x < BASE_W and 0 <= y < BASE_H:
        px[x, y] = color


def fill_rect(px, x0: int, y0: int, x1: int, y1: int, color: RGBA) -> None:
    for y in range(max(0, y0), min(BASE_H, y1)):
        for x in range(max(0, x0), min(BASE_W, x1)):
            px[x, y] = color


def draw_circle(px, cx: int, cy: int, r: int, color: RGBA) -> None:
    r2 = r * r
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r2:
                set_px(px, cx + dx, cy + dy, color)


def draw_top_left_badge(px, theme: Dict[str, object]) -> None:
    """Ornate circular/shield badge at top-left overlapping title & art corner."""
    cx, cy = 8, 9
    ink: RGBA = theme["ink"]  # type: ignore[assignment]
    dark: RGBA = theme["dark"]  # type: ignore[assignment]
    shade: RGBA = theme["shade"]  # type: ignore[assignment]
    mid: RGBA = theme["mid"]  # type: ignore[assignment]
    hi: RGBA = theme["hi"]  # type: ignore[assignment]
    kind: str = theme["kind"]  # type: ignore[assignment]

    # Subtle cream/hi halo arc on bottom-right edge (like samplecard.jfif)
    draw_circle(px, cx + 1, cy + 1, 6, hi)
    # Thick ink ring
    draw_circle(px, cx, cy, 6, ink)
    # Outer metallic/colored ring
    draw_circle(px, cx, cy, 5, dark)
    draw_circle(px, cx, cy, 4, mid)
    # Inner bevel shading
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            if dx * dx + dy * dy <= 16:
                if dx + dy <= -3:
                    set_px(px, cx + dx, cy + dy, hi)
                elif dx + dy >= 3:
                    set_px(px, cx + dx, cy + dy, shade)

    # Inner dark medallion core for icon contrast
    draw_circle(px, cx, cy, 3, dark)

    if kind == "active":
        # Crisp pixel sun / flame emblem
        sun_hi = [
            (0, -2), (0, -1), (0, 0), (0, 1), (0, 2),
            (-2, 0), (-1, 0), (1, 0), (2, 0),
        ]
        sun_mid = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for dx, dy in sun_mid:
            set_px(px, cx + dx, cy + dy, mid)
        for dx, dy in sun_hi:
            set_px(px, cx + dx, cy + dy, hi)
    else:
        # Crisp pixel crescent moon emblem
        moon_pts = [
            (0, -2), (1, -2),
            (-1, -1), (0, -1),
            (-1, 0), (0, 0),
            (-1, 1), (0, 1),
            (0, 2), (1, 2),
        ]
        for dx, dy in moon_pts:
            set_px(px, cx + dx, cy + dy, hi if dx <= 0 else mid)
        # Small star glint in the crescent hollow
        set_px(px, cx + 2, cy, hi)


def draw_top_right_swirl(px, theme: Dict[str, object]) -> None:
    """Ornamental pixel cloud/swirl at top-right draping into art corner."""
    ink: RGBA = theme["ink"]  # type: ignore[assignment]
    dark: RGBA = theme["dark"]  # type: ignore[assignment]
    mid: RGBA = theme["mid"]  # type: ignore[assignment]
    hi: RGBA = theme["hi"]  # type: ignore[assignment]
    paper = COMMON["paper"]

    # Colored cloud/scroll cluster at top-right (x=57..70, y=4..16)
    puffs = [
        (68, 6, 3, mid),
        (64, 5, 2, mid),
        (69, 10, 3, dark),
        (65, 9, 2, mid),
        (61, 10, 2, mid),
        (68, 13, 2, mid),
        (63, 13, 1, hi),
        (59, 12, 1, dark),
    ]
    for cx, cy, r, _ in puffs:
        draw_circle(px, cx, cy, r + 1, ink)
    for cx, cy, r, col in puffs:
        draw_circle(px, cx, cy, r, col)

    # Crisp highlight spirals & paper foam curls
    swirl_hi = [
        (67, 5), (68, 6), (69, 6),
        (64, 8), (65, 8), (66, 9),
        (68, 12), (69, 13), (62, 11),
        (60, 10), (61, 9),
    ]
    for sx, sy in swirl_hi:
        set_px(px, sx, sy, hi)
    for sx, sy in [(65, 5), (66, 6), (67, 11), (63, 10)]:
        set_px(px, sx, sy, paper)


def draw_swirling_mist_divider(px, theme: Dict[str, object]) -> None:
    """
    Organic swirling mist / cloud scrollwork transitioning from the art window
    down into the bottom parchment box (signature motif from samplecard.jfif).
    """
    ink: RGBA = theme["ink"]  # type: ignore[assignment]
    dark: RGBA = theme["dark"]  # type: ignore[assignment]
    shade: RGBA = theme["shade"]  # type: ignore[assignment]
    mid: RGBA = theme["mid"]  # type: ignore[assignment]
    hi: RGBA = theme["hi"]  # type: ignore[assignment]
    tint: RGBA = theme["tint"]  # type: ignore[assignment]
    paper = COMMON["paper"]
    paper_shadow = COMMON["paper_shadow"]

    # Base organic wave height across x=3..70 (higher at flanks, lower in middle)
    # Keeps y=16..57 completely open in the center while rising organically on sides.
    wave_y: List[int] = [62] * BASE_W
    for x in range(3, 71):
        t = abs(x - 36.5) / 33.5  # 0 at center, 1 at edges
        # Gentle bowl curve + pixel cloud undulations
        base = 63 - int(round((t ** 1.8) * 6))
        bump = ((x * 5) % 11) // 4 - 1  # -1..1
        if x in (5, 6, 7, 12, 13, 21, 22, 36, 37, 51, 52, 60, 61, 66, 67, 68):
            bump -= 1
        wave_y[x] = max(55, min(64, base + bump))

    # 1. Fill parchment & tinted mist below the wave down to y=99
    for x in range(3, 71):
        wy = wave_y[x]
        # Top dark ink contour wisps (1px)
        set_px(px, x, wy - 1, ink)
        # Colored swirl crest (2-3px)
        set_px(px, x, wy, mid if (x % 3 != 0) else hi)
        set_px(px, x, wy + 1, shade if (x % 4 == 0) else mid)
        set_px(px, x, wy + 2, hi if (x % 2 == 0) else tint)
        set_px(px, x, wy + 3, tint if (x % 3 == 0) else paper)
        # Clean parchment below
        for y in range(wy + 4, 100):
            px[x, y] = paper

    # 2. Sculpted pixel cloud puffs & flame/mist curls rising into art bottom
    puffs = [
        # (cx, cy, r, fill_col)
        (6, 56, 3, mid),
        (11, 59, 3, hi),
        (17, 61, 2, mid),
        (24, 62, 2, hi),
        (31, 63, 2, paper),
        (37, 62, 2, hi),
        (43, 63, 2, paper),
        (50, 62, 2, hi),
        (57, 61, 2, mid),
        (63, 59, 3, hi),
        (68, 56, 3, mid),
    ]
    # Ink upper silhouette for puffs
    for cx, cy, r, _ in puffs:
        for dy in range(-r - 1, 1):
            for dx in range(-r - 1, r + 2):
                if dx * dx + dy * dy <= (r + 1) * (r + 1):
                    tx, ty = cx + dx, cy + dy
                    if 3 <= tx < 71 and ty < wave_y[tx]:
                        set_px(px, tx, ty, ink)
    # Colored & cream puff bodies
    for cx, cy, r, col in puffs:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    tx, ty = cx + dx, cy + dy
                    if 3 <= tx < 71:
                        if dy <= -r + 1:
                            set_px(px, tx, ty, col)
                        elif dy <= 0:
                            set_px(px, tx, ty, hi if col != paper else paper)
                        else:
                            set_px(px, tx, ty, paper)

    # 3. Crisp side mist tendrils hugging left & right edges of parchment box
    left_mist = [
        (4, 65), (5, 66), (4, 67), (5, 68), (4, 70), (5, 71),
        (4, 73), (4, 75), (5, 76), (4, 79), (4, 82), (5, 83),
    ]
    right_mist = [
        (69, 65), (68, 66), (69, 67), (68, 68), (69, 70), (68, 71),
        (69, 73), (69, 75), (68, 76), (69, 79), (69, 82), (68, 83),
    ]
    for mx, my in left_mist + right_mist:
        set_px(px, mx, my, mid if my % 2 == 0 else tint)
        set_px(px, mx + (1 if mx < 10 else -1), my, paper_shadow)

    # 4. Accent scroll curls inside the mist transition (dark ink micro-curls)
    curls = [
        (7, 58), (8, 57), (9, 58),
        (66, 58), (65, 57), (64, 58),
        (14, 62), (15, 61),
        (59, 62), (58, 61),
        (36, 63), (37, 63),
    ]
    for cx, cy in curls:
        set_px(px, cx, cy, dark)


def draw_bottom_ornaments(px, theme: Dict[str, object]) -> None:
    """
    Bottom-left mini emblem, bottom-right classic spiral swirl, and thin
    colored bottom accent strip (inspired by samplecard.jfif).
    """
    ink: RGBA = theme["ink"]  # type: ignore[assignment]
    dark: RGBA = theme["dark"]  # type: ignore[assignment]
    shade: RGBA = theme["shade"]  # type: ignore[assignment]
    mid: RGBA = theme["mid"]  # type: ignore[assignment]
    hi: RGBA = theme["hi"]  # type: ignore[assignment]
    tint: RGBA = theme["tint"]  # type: ignore[assignment]
    paper = COMMON["paper"]
    paper_shadow = COMMON["paper_shadow"]

    # 1. Thin bottom accent bar (y=96..99, x=13..60)
    fill_rect(px, 13, 95, 60, 96, paper_shadow)
    fill_rect(px, 13, 96, 60, 99, mid)
    fill_rect(px, 13, 96, 60, 97, tint)
    for x in range(15, 58):
        if x % 4 == 0:
            set_px(px, x, 97, shade)
    # Center tiny diamond pip on bottom strip
    set_px(px, 36, 97, dark)
    set_px(px, 37, 97, dark)
    set_px(px, 36, 96, hi)
    set_px(px, 37, 96, hi)

    # 2. Bottom-left mini emblem (centered at x=7, y=94)
    bx, by = 7, 94
    draw_circle(px, bx, by, 4, ink)
    draw_circle(px, bx, by, 3, dark)
    draw_circle(px, bx, by, 2, mid)
    set_px(px, bx, by, hi)
    set_px(px, bx - 1, by, hi)
    set_px(px, bx, by - 1, hi)
    # Corner ink wing bridging into bottom border
    fill_rect(px, 3, 96, 12, 100, ink)
    draw_circle(px, bx, by, 3, dark)
    draw_circle(px, bx, by, 2, mid)
    set_px(px, bx, by, hi)

    # 3. Bottom-right ornamental gothic spiral swirl (x=60..70, y=89..99)
    # Dark ink base corner mass
    for y in range(90, 100):
        for x in range(60, 71):
            dx = x - 66
            dy = y - 95
            if dx * dx + dy * dy <= 25 or (x >= 65 and y >= 94):
                set_px(px, x, y, ink)

    # Crisp ivory/highlight spiral curve curling inward (signature samplecard.jfif swirl)
    spiral_hi = [
        (61, 97), (61, 96), (61, 95), (62, 94), (62, 93),
        (63, 92), (64, 91), (65, 91), (66, 91), (67, 92),
        (68, 93), (68, 94), (68, 95), (67, 96), (66, 97),
        (65, 97), (64, 96), (64, 95), (65, 94), (66, 94),
    ]
    for sx, sy in spiral_hi:
        set_px(px, sx, sy, paper)
    # Colored accent dot at spiral heart & outer flourish
    set_px(px, 65, 95, mid)
    set_px(px, 66, 95, hi)
    set_px(px, 69, 91, mid)
    set_px(px, 68, 90, hi)
    set_px(px, 60, 98, dark)


def build_frame(theme: Dict[str, object]) -> Image.Image:
    img = Image.new("RGBA", (BASE_W, BASE_H), COMMON["transparent"])
    px = img.load()

    ink: RGBA = theme["ink"]  # type: ignore[assignment]
    paper = COMMON["paper"]
    paper_hi = COMMON["paper_hi"]
    paper_shadow = COMMON["paper_shadow"]

    # 1. Thick outer black border (#121014 / #081121): 3px on base = 6px on 148x206
    fill_rect(px, 0, 0, BASE_W, BASE_H, ink)

    # 2. Clear interior art window completely transparent (x=3..71, y=14..66)
    fill_rect(px, ART_X0, ART_Y0, ART_X1, ART_Y1, COMMON["transparent"])

    # 3. Top title parchment bar (x=3..71, y=3..14)
    fill_rect(px, 3, 3, 71, 14, paper)
    # Crisp parchment bevel on title bar
    for x in range(3, 71):
        set_px(px, x, 3, paper_hi)
        set_px(px, x, 13, paper_shadow)
        set_px(px, x, 14, ink)  # 1px crisp dark underside separating title & art

    # 4. Swirling mist / cloud divider & bottom parchment box
    draw_swirling_mist_divider(px, theme)

    # 5. Bottom ornaments (left mini badge, right spiral swirl, bottom accent bar)
    draw_bottom_ornaments(px, theme)

    # 6. Top ornaments (left circular emblem + right cloud swirl draping into art)
    draw_top_left_badge(px, theme)
    draw_top_right_swirl(px, theme)

    # 7. Reinforce outer 3px black border so ornaments never bleed outside frame
    for x in range(BASE_W):
        for y in (0, 1, 2, BASE_H - 3, BASE_H - 2, BASE_H - 1):
            px[x, y] = ink
    for y in range(BASE_H):
        for x in (0, 1, 2, BASE_W - 3, BASE_W - 2, BASE_W - 1):
            px[x, y] = ink

    # 8. Hard pixel-rounded outer corners (radius 4px on base grid, alpha=0 outside)
    corner_cut = [
        (0, 0), (1, 0), (2, 0), (3, 0),
        (0, 1), (1, 1),
        (0, 2),
        (0, 3),
    ]
    corner_ink = [
        (3, 1), (2, 1), (1, 2), (2, 2), (1, 3), (3, 2), (2, 3), (3, 3),
    ]
    for cx, cy in corner_cut:
        px[cx, cy] = COMMON["transparent"]
        px[BASE_W - 1 - cx, cy] = COMMON["transparent"]
        px[cx, BASE_H - 1 - cy] = COMMON["transparent"]
        px[BASE_W - 1 - cx, BASE_H - 1 - cy] = COMMON["transparent"]
    for ix, iy in corner_ink:
        px[ix, iy] = ink
        px[BASE_W - 1 - ix, iy] = ink
        px[ix, BASE_H - 1 - iy] = ink
        px[BASE_W - 1 - ix, BASE_H - 1 - iy] = ink

    # Upscale 2x using NEAREST for razor-sharp pixel blocks
    return img.resize((BASE_W * SCALE, BASE_H * SCALE), Image.Resampling.NEAREST)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, theme in THEMES.items():
        out_path = OUT_DIR / filename
        frame = build_frame(theme)
        frame.save(out_path, format="PNG")
        print(f"Wrote {out_path} ({frame.size[0]}x{frame.size[1]}, mode={frame.mode})")


if __name__ == "__main__":
    main()
