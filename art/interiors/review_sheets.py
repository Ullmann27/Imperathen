#!/usr/bin/env python3
"""Before/after comparison sheets and a cost table from interior_stage_capture.gd output.

    python3 art/interiors/review_sheets.py <before_dir> <after_dir> <out_dir>

Per house: one 1920x1080 sheet (rows: entry and back view at 1280x720;
columns: before/after in balanced and very_high) and one portrait sheet
(1384x1536 entry view, same four columns). Writes costs.json with draw calls
and primitives per view and profile, before and after.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

LANDSCAPE = "1280x720"
PORTRAIT = "1384x1536"
COLUMNS = [("before", "balanced"), ("after", "balanced"), ("before", "very_high"), ("after", "very_high")]


def load(folder: Path, label: str, size: str) -> dict:
    path = folder / f"{label}_{size}.json"
    return json.loads(path.read_text())["houses"] if path.exists() else {}


def tile(folder: Path, label: str, house: str, view: str, profile: str, size: str, box) -> Image.Image:
    path = folder / f"{label}_{house}_{view}_{profile}_{size}.jpg"
    if not path.exists():
        image = Image.new("RGB", box, (40, 40, 40))
        ImageDraw.Draw(image).text((10, 10), "missing", fill=(220, 80, 80))
        return image
    return Image.open(path).convert("RGB").resize(box, Image.Resampling.LANCZOS)


def main():
    before, after, out = (Path(a) for a in sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    stats = {"before": {s: load(before, "before", s) for s in (LANDSCAPE, PORTRAIT)},
             "after": {s: load(after, "after", s) for s in (LANDSCAPE, PORTRAIT)}}
    houses = sorted({key.split("/")[0] for key in stats["after"][LANDSCAPE]})
    costs = {}
    for house in houses:
        sheet = Image.new("RGB", (1920, 1080), (18, 18, 18))
        draw = ImageDraw.Draw(sheet)
        for row, view in enumerate(("entry", "back")):
            for col, (label, profile) in enumerate(COLUMNS):
                folder = before if label == "before" else after
                sheet.paste(tile(folder, label, house, view, profile, LANDSCAPE, (480, 270)), (col * 480, 270 + row * 405))
                info = stats[label][LANDSCAPE].get(f"{house}/{view}/{profile}", {})
                draw.text((col * 480 + 6, 245 + row * 405), f"{label} {profile} {view}: {info.get('draw_calls', '?')} calls, "
                          f"{info.get('primitives', '?')} prims", fill=(235, 225, 200))
                costs.setdefault(house, {}).setdefault(view, {})[f"{label}/{profile}"] = info
        draw.text((8, 8), f"{house} - Valdora interior, Godot 4.7.2 Compatibility (llvmpipe), 1280x720 tiles", fill=(255, 255, 255))
        sheet.save(out / f"{house}_1280x720.jpg", quality=82)
        portrait = Image.new("RGB", (4 * 346, 384 + 24), (18, 18, 18))
        draw = ImageDraw.Draw(portrait)
        for col, (label, profile) in enumerate(COLUMNS):
            folder = before if label == "before" else after
            portrait.paste(tile(folder, label, house, "entry", profile, PORTRAIT, (346, 384)), (col * 346, 24))
            draw.text((col * 346 + 4, 6), f"{label} {profile}", fill=(235, 225, 200))
            costs[house].setdefault("entry_portrait", {})[f"{label}/{profile}"] = stats[label][PORTRAIT].get(f"{house}/entry/{profile}", {})
        portrait.save(out / f"{house}_1384x1536.jpg", quality=82)
    (out / "costs.json").write_text(json.dumps(costs, indent=1, sort_keys=True) + "\n")
    print("sheets", len(houses))


if __name__ == "__main__":
    main()
