#!/usr/bin/env python3
"""Collect D-038 render evidence (Godot before/after, Blender reviews) into one JSON
plus small JPG sheets for the repository.

    python3 art/architecture/valdora_family/evidence.py --before <dir> --after <dir> \
        --blender art/architecture/valdora_family/review --out art/architecture/valdora_family/review
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def sheet(pairs, out, width=760, caption=None):
    rows = []
    for label, left, right in pairs:
        a = Image.open(left).convert("RGB")
        b = Image.open(right).convert("RGB")
        h = round(a.height * width / a.width)
        a, b = a.resize((width, h), Image.Resampling.LANCZOS), b.resize((width, h), Image.Resampling.LANCZOS)
        row = Image.new("RGB", (width * 2 + 6, h + 22), (22, 20, 18))
        row.paste(a, (0, 22))
        row.paste(b, (width + 6, 22))
        ImageDraw.Draw(row).text((6, 5), label, fill=(232, 222, 200))
        rows.append(row)
    total = Image.new("RGB", (rows[0].width, sum(r.height for r in rows) + (20 if caption else 0)), (0, 0, 0))
    y = 0
    if caption:
        ImageDraw.Draw(total).text((6, 4), caption, fill=(232, 222, 200))
        y = 20
    for r in rows:
        total.paste(r, (0, y))
        y += r.height
    total.save(out, quality=86)
    return {"file": out.name, "bytes": out.stat().st_size}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--blender", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "prototype/assets/architecture/valdora/valdora_family.json").read_text())
    evidence = {"schema": "imperathen.d038.evidence.v1", "subject": "Valdora house family and paving (directive points 1 and 2)",
                "godot": {}, "blender": manifest.get("blender_reviews", []), "sheets": []}
    for profile in ("balanced", "very_high"):
        b = args.before / f"before_{profile}.json"
        a = args.after / f"after_{profile}.json"
        if not (a.exists() and b.exists()):
            continue
        before, after = json.loads(b.read_text()), json.loads(a.read_text())
        shots = {}
        pairs = []
        for shot, info in after["shots"].items():
            if shot not in before["shots"]:
                continue
            old = before["shots"][shot]
            shots[shot] = {"camera": info["camera"], "before": {k: old[k] for k in ("draw_calls", "primitives", "objects", "render_cpu_ms", "render_gpu_ms", "wall_frame_ms")},
                           "after": {k: info[k] for k in ("draw_calls", "primitives", "objects", "render_cpu_ms", "render_gpu_ms", "wall_frame_ms")}}
            pairs.append((f"{shot}: vorher {before['source_commit']}  |  nachher {after['source_commit']}  ({profile})",
                          args.before / old["file"], args.after / info["file"]))
        evidence["godot"][profile] = {"before_commit": before["source_commit"], "after_commit": after["source_commit"],
                                      "renderer": after["renderer"], "adapter": after["adapter"], "api": after["api_version"],
                                      "resolution": after["resolution"], "msaa": after["msaa"], "lighting": after["lighting"],
                                      "memory_before": before["memory"], "memory_after": after["memory"],
                                      "models_before": before["models"], "models_after": after["models"], "shots": shots,
                                      "measurement_environment": after["measurement_environment"]}
        evidence["sheets"].append(sheet(pairs, args.out / f"godot_vergleich_{profile}.jpg",
                                        caption=f"Godot {after['renderer']} / {after['adapter']} - links vorher, rechts nachher, gleiche Kamera"))
    blender_pairs = []
    for shot in ("front", "close"):
        before_png = args.blender / f"blender_frontier_house_before_{shot}.png"
        after_png = args.blender / f"blender_valdora_t2_render_{shot}.png"
        if before_png.exists() and after_png.exists():
            blender_pairs.append((f"Blender Cycles {shot}: frontier_house.glb (vorher)  |  valdora_t2_render (nachher)", before_png, after_png))
    if blender_pairs:
        evidence["sheets"].append(sheet(blender_pairs, args.out / "blender_vergleich_t2_render.jpg"))
    lineup = sorted(args.blender.glob("blender_valdora_*_front.png"))
    if lineup:
        tiles = [Image.open(p).convert("RGB").resize((480, 270), Image.Resampling.LANCZOS) for p in lineup]
        cols = 3
        grid = Image.new("RGB", (480 * cols, 270 * ((len(tiles) + cols - 1) // cols) ), (0, 0, 0))
        for i, (tile, path) in enumerate(zip(tiles, lineup)):
            ImageDraw.Draw(tile).text((6, 6), path.stem.replace("blender_", "").replace("_front", ""), fill=(255, 255, 255))
            grid.paste(tile, ((i % cols) * 480, (i // cols) * 270))
        grid.save(args.out / "blender_familie.jpg", quality=86)
        evidence["sheets"].append({"file": "blender_familie.jpg", "bytes": (args.out / "blender_familie.jpg").stat().st_size})
    for item in evidence["sheets"]:
        path = args.out / item["file"]
        item["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    (args.out / "evidence.json").write_text(json.dumps(evidence, indent=1) + "\n", encoding="utf-8")
    print("EVIDENCE", args.out / "evidence.json")


if __name__ == "__main__":
    main()
