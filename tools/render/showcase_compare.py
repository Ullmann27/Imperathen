#!/usr/bin/env python3
"""Before/after sheets over the shared showcase camera list (D-052, D-038).

Both inputs are output folders of
    tools/render/compare_renderers.py --showcase --steps village,city ...
run on two source states (e.g. the base commit and a graphics branch, or the
integration branch before and after a merge). Every pair shares shot, renderer,
profile and variant, so it is a same-camera comparison by construction; a pair
whose camera transform differs is reported and marked on the sheet.

Writes <out>/compare-<renderer>-<profile>-<variant>.jpg (rows: shots, columns:
before | after) and <out>/compare.json with the D-038 metadata of both sides
and the pixel difference. Images come from software renderers unless the
reports say otherwise; times are relative indicators only.

Usage: showcase_compare.py --before <dir> --after <dir> --out <dir>
           [--before-label base] [--after-label branch]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def load(folder: Path) -> dict:
    path = folder / "showcase.json"
    if not path.is_file():
        raise SystemExit(f"{path} is missing: run compare_renderers.py --showcase first")
    data = json.loads(path.read_text(encoding="utf-8"))
    return {(i["renderer"], i["profile"], i["variant"], i["shot"]): i for i in data["images"]}


def difference(a: Path, b: Path) -> dict | None:
    import numpy
    from PIL import Image
    if not a.is_file() or not b.is_file():
        return None
    x = numpy.asarray(Image.open(a).convert("RGB"), dtype=numpy.int16)
    y = numpy.asarray(Image.open(b).convert("RGB"), dtype=numpy.int16)
    if x.shape != y.shape:
        return {"error": f"size {x.shape} vs {y.shape}"}
    delta = numpy.abs(x - y)
    return {"mean_abs": round(float(delta.mean()), 3), "changed_fraction_gt8": round(float((delta.max(axis=2) > 8).mean()), 5),
            "mean_luma_delta": round(float(y.mean() - x.mean()), 3)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--before-label", default="vorher")
    parser.add_argument("--after-label", default="nachher")
    args = parser.parse_args()
    from PIL import Image, ImageDraw
    before, after = load(args.before), load(args.after)
    args.out.mkdir(parents=True, exist_ok=True)
    groups: dict[tuple, list] = {}
    for key in before:
        if key in after:
            groups.setdefault(key[:3], []).append(key[3])
    thumb = (640, 360)
    result = {"before": str(args.before), "after": str(args.after), "pairs": [], "sheets": [],
              "only_before": sorted("/".join(k) for k in before if k not in after),
              "only_after": sorted("/".join(k) for k in after if k not in before)}
    for (renderer, profile, variant), shots in groups.items():
        sheet = Image.new("RGB", (thumb[0] * 2, (thumb[1] + 22) * len(shots) + 24), (18, 18, 18))
        draw = ImageDraw.Draw(sheet)
        first = before[(renderer, profile, variant, shots[0])]
        software = bool(first["driver"].get("software_renderer"))
        draw.text((6, 5), f"{renderer} / {profile} / {variant} - {first['driver']['adapter']}"
                  + (" - software renderer, not device data" if software else ""), fill=(255, 210, 120))
        for row, shot in enumerate(shots):
            a, b = before[(renderer, profile, variant, shot)], after[(renderer, profile, variant, shot)]
            same_camera = (a.get("camera") or {}).get("transform") == (b.get("camera") or {}).get("transform")
            y = 24 + row * (thumb[1] + 22)
            draw.text((6, y + 4), f"{a['area']} - {shot} - {args.before_label} {str(a.get('source_commit'))[:7]}", fill=(230, 230, 230))
            draw.text((thumb[0] + 6, y + 4), f"{args.after_label} {str(b.get('source_commit'))[:7]}"
                      + ("" if same_camera else "  CAMERA DIFFERS"), fill=(230, 230, 230) if same_camera else (255, 90, 90))
            for column, (side, folder) in enumerate(((a, args.before), (b, args.after))):
                path = folder / side["image"]
                if path.is_file():
                    sheet.paste(Image.open(path).convert("RGB").resize(thumb, Image.LANCZOS), (column * thumb[0], y + 22))
            result["pairs"].append({"shot": shot, "renderer": renderer, "profile": profile, "variant": variant,
                                    "same_camera": same_camera, "pixels": difference(args.before / a["image"], args.after / b["image"]),
                                    "before": a, "after": b})
        name = f"compare-{renderer}-{profile}-{variant}.jpg"
        sheet.save(args.out / name, quality=90)
        result["sheets"].append(name)
    (args.out / "compare.json").write_text(json.dumps(result, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    different = [p for p in result["pairs"] if not p["same_camera"]]
    print("SHOWCASE_COMPARE", json.dumps({"pairs": len(result["pairs"]), "sheets": result["sheets"], "camera_differs": len(different)}))
    return 0 if result["pairs"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
