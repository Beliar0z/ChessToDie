# E:\ChessToDie\tools\art_pipeline\batch_render_cards.py
# Python / batch_render_cards.py / Python 3 + Pillow + SD Forge API / Chess to Die (Ag5)
"""
Batch render all 51 card illustrations (active_01..active_31, passive_01..passive_20)
via local SD Forge API (DreamshaperPixelart.safetensors) with safe GTX 1650 4GB VRAM
settings (512x384, steps=18, cfg_scale=7.5, DPM++ 2M, batch_size=1) and mandatory
Balatro pixel-art Pillow post-processing (68x52 base grid -> 18 crisp colors ->
2x NEAREST -> 136x104 RGBA opaque).

Supports resume by default (skips existing valid PNGs unless --force is passed).
NEVER touches frame_active.png, frame_passive.png, the_sun_back.png, the_moon_back.png.
"""

import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
QUEUE_PATH = Path(__file__).resolve().parent / "cards_queue.json"
SAMPLE_ART_PATH = ROOT / "assets" / "sprites" / "cards" / "sample_card_art.png"
OUT_ART_DIR = ROOT / "assets" / "sprites" / "cards" / "art"
MANIFEST_PATH = ROOT / "assets" / "manifest.json"

SD_TXT2IMG_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"
SD_OPTIONS_URL = "http://127.0.0.1:7860/sdapi/v1/options"


def verify_sample_target_size() -> Tuple[int, int, int, int]:
    """Read actual dimensions of sample_card_art.png to guarantee 100% fit."""
    if SAMPLE_ART_PATH.exists():
        with Image.open(SAMPLE_ART_PATH) as im:
            out_w, out_h = im.size
        base_w, base_h = out_w // 2, out_h // 2
        return base_w, base_h, out_w, out_h
    return 68, 52, 136, 104


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


def postprocess_card_art(
    raw_img: Image.Image,
    base_w: int,
    base_h: int,
    out_w: int,
    out_h: int,
    max_colors: int = 18,
    contrast_boost: float = 1.12,
) -> Image.Image:
    """Center-crop to base ratio -> contrast boost -> downscale BOX -> quantize 18 crisp colors -> 2x NEAREST."""
    cropped = center_crop_aspect(raw_img, base_w, base_h)
    if contrast_boost != 1.0:
        cropped = ImageEnhance.Contrast(cropped).enhance(contrast_boost)
    small = cropped.resize((base_w, base_h), Image.Resampling.BOX)
    quant = small.quantize(
        colors=max_colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    return quant.resize((out_w, out_h), Image.Resampling.NEAREST)


def call_sd_txt2img(
    prompt: str,
    negative_prompt: str,
    width: int,
    height: int,
    seed: int,
    steps: int,
    cfg_scale: float,
    sampler_name: str,
    checkpoint: str,
    retries: int = 3,
) -> Image.Image:
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "sampler_name": sampler_name,
        "batch_size": 1,
        "n_iter": 1,
        "seed": seed,
        "override_settings": {
            "sd_model_checkpoint": checkpoint,
        },
        "override_settings_restore_afterwards": False,
    }
    data = json.dumps(payload).encode("utf-8")
    last_err: Optional[Exception] = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            SD_TXT2IMG_URL,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            images = body.get("images")
            if not images:
                raise RuntimeError("SD Forge returned empty images list")
            raw = base64.b64decode(images[0].split(",", 1)[-1])
            return Image.open(io.BytesIO(raw)).convert("RGB")
        except (urllib.error.URLError, TimeoutError, RuntimeError, OSError) as exc:
            last_err = exc
            print(f"      [warn] attempt {attempt}/{retries} failed: {exc}", flush=True)
            if attempt < retries:
                time.sleep(2.0 * attempt)
    raise RuntimeError(f"SD Forge failed after {retries} attempts: {last_err}")


def is_valid_existing_png(path: Path, expected_w: int, expected_h: int) -> bool:
    if not path.exists() or path.stat().st_size == 0:
        return False
    try:
        with Image.open(path) as im:
            return im.size == (expected_w, expected_h)
    except Exception:
        return False


def atomic_save_png(img: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = dest.with_suffix(".tmp.png")
    with open(tmp_path, "wb") as f:
        img.save(f, format="PNG")
    os.replace(tmp_path, dest)


def update_manifest() -> Tuple[int, int]:
    """
    Update assets/manifest.json: keep existing entries and register/update
    - 24 chess piece PNGs (64x64)
    - 2 card front frames PNGs (148x206)
    - 2 Tarot card back PNGs (148x206)
    - 51 card art PNGs (136x104)
    """
    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    existing_assets: List[Dict] = manifest.get("assets", [])
    by_path: Dict[str, Dict] = {entry["path"]: entry for entry in existing_assets}
    ordered_paths: List[str] = [entry["path"] for entry in existing_assets]

    def upsert(res_path: str, asset_type: str, resolution: str, status: str = "ready") -> None:
        if res_path in by_path:
            by_path[res_path]["type"] = asset_type
            by_path[res_path]["resolution"] = resolution
            by_path[res_path]["status"] = status
        else:
            entry = {
                "path": res_path,
                "type": asset_type,
                "resolution": resolution,
                "status": status,
            }
            by_path[res_path] = entry
            ordered_paths.append(res_path)

    # 1. 24 chess piece PNGs
    pieces_dir = ROOT / "assets" / "sprites" / "pieces"
    for p in sorted(pieces_dir.glob("*.png")):
        with Image.open(p) as im:
            res = f"{im.size[0]}x{im.size[1]}"
        upsert(f"res://assets/sprites/pieces/{p.name}", "png", res)

    # 2. 2 front card frames
    for fname in ("frame_active.png", "frame_passive.png"):
        p = ROOT / "assets" / "ui" / "textures" / fname
        if p.exists():
            with Image.open(p) as im:
                res = f"{im.size[0]}x{im.size[1]}"
            upsert(f"res://assets/ui/textures/{fname}", "png", res)

    # 3. 2 Tarot card backs
    for fname in ("the_sun_back.png", "the_moon_back.png"):
        p = ROOT / "assets" / "sprites" / "cards" / fname
        if p.exists():
            with Image.open(p) as im:
                res = f"{im.size[0]}x{im.size[1]}"
            upsert(f"res://assets/sprites/cards/{fname}", "png", res)

    # 4. 51 card art PNGs
    for p in sorted(OUT_ART_DIR.glob("*.png")):
        if p.name.endswith(".tmp.png"):
            continue
        with Image.open(p) as im:
            res = f"{im.size[0]}x{im.size[1]}"
        upsert(f"res://assets/sprites/cards/art/{p.name}", "png", res)

    final_assets = [by_path[k] for k in ordered_paths]
    total = len(final_assets)
    completed = sum(1 for a in final_assets if a.get("status") == "ready")

    manifest["total_assets"] = total
    manifest["completed_assets"] = completed
    manifest["assets"] = final_assets

    tmp_manifest = MANIFEST_PATH.with_suffix(".tmp.json")
    with open(tmp_manifest, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_manifest, MANIFEST_PATH)
    return total, completed


def main() -> int:
    parser = argparse.ArgumentParser(description="Batch render 51 Chess to Die card arts via SD Forge.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing card art PNGs.")
    parser.add_argument("--only", type=str, default="", help="Comma-separated card_ids to render.")
    parser.add_argument("--manifest-only", action="store_true", help="Only update assets/manifest.json.")
    args = parser.parse_args()

    if args.manifest_only:
        total, completed = update_manifest()
        print(f"Updated {MANIFEST_PATH}: total_assets={total}, completed_assets={completed}")
        return 0

    with open(QUEUE_PATH, "r", encoding="utf-8") as f:
        queue = json.load(f)

    meta = queue["meta"]
    cards: List[Dict] = queue["cards"]

    base_w, base_h, out_w, out_h = verify_sample_target_size()
    print(f"Target card art size locked from sample_card_art.png: {out_w}x{out_h} (base grid {base_w}x{base_h})", flush=True)

    only_set = {c.strip().lower() for c in args.only.split(",") if c.strip()} if args.only else set()
    OUT_ART_DIR.mkdir(parents=True, exist_ok=True)

    total_cards = len(cards)
    rendered = 0
    skipped = 0
    t_all = time.time()

    for idx, card in enumerate(cards, start=1):
        cid = card["card_id"]
        if only_set and cid.lower() not in only_set:
            continue

        dest = ROOT / card["output_path"]
        if not args.force and is_valid_existing_png(dest, out_w, out_h):
            skipped += 1
            print(f"[{idx:02d}/{total_cards}] {cid} ({card['title']}) -> SKIP (already exists {out_w}x{out_h})", flush=True)
            continue

        is_active = card["card_type"].upper() == "ACTIVE"
        style_suffix = meta["style_active_suffix"] if is_active else meta["style_passive_suffix"]
        neg_prompt = meta["negative_prompt_active"] if is_active else meta["negative_prompt_passive"]
        full_prompt = f"{card['subject_prompt']}, {style_suffix}"

        t0 = time.time()
        raw_img = call_sd_txt2img(
            prompt=full_prompt,
            negative_prompt=neg_prompt,
            width=int(meta["sd_width"]),
            height=int(meta["sd_height"]),
            seed=int(card["seed"]),
            steps=int(meta["steps"]),
            cfg_scale=float(meta["cfg_scale"]),
            sampler_name=str(meta["sampler_name"]),
            checkpoint=str(meta["checkpoint"]),
        )
        final_img = postprocess_card_art(
            raw_img=raw_img,
            base_w=base_w,
            base_h=base_h,
            out_w=out_w,
            out_h=out_h,
            max_colors=int(meta.get("quantize_colors", 18)),
        )
        atomic_save_png(final_img, dest)
        dt = time.time() - t0
        rendered += 1
        kb = dest.stat().st_size / 1024.0
        print(f"[{idx:02d}/{total_cards}] {cid} ({card['title']}) -> OK ({out_w}x{out_h}, {kb:.1f} KB, {dt:.1f}s)", flush=True)

    elapsed = time.time() - t_all
    print(f"Batch render complete: rendered={rendered}, skipped={skipped}, elapsed={elapsed:.1f}s", flush=True)

    total, completed = update_manifest()
    print(f"Manifest updated: total_assets={total}, completed_assets={completed}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
