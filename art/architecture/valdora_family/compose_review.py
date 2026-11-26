#!/usr/bin/env python3
"""Side-by-side before/after sheets from capture_valdora.gd output (identical cameras).

    python3 art/architecture/valdora_family/compose_review.py --before <dir> --after <dir> \
        --profile balanced --out art/architecture/valdora_family/review
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--profile", default="balanced")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--width", type=int, default=960)
    args = parser.parse_args()
    before = json.loads((args.before / f"before_{args.profile}.json").read_text())
    after = json.loads((args.after / f"after_{args.profile}.json").read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot, info in after["shots"].items():
        if shot not in before["shots"]:
            continue
        a = Image.open(args.before / before["shots"][shot]["file"]).convert("RGB")
        b = Image.open(args.after / info["file"]).convert("RGB")
        w = args.width
        h = round(a.height * w / a.width)
        a, b = a.resize((w, h), Image.Resampling.LANCZOS), b.resize((w, h), Image.Resampling.LANCZOS)
        row = Image.new("RGB", (w * 2 + 8, h + 26), (24, 22, 20))
        row.paste(a, (0, 26))
        row.paste(b, (w + 8, 26))
        d = ImageDraw.Draw(row)
        d.text((6, 6), f"{shot} | vorher {before['source_commit']} | {before['shots'][shot]['primitives']} Prim. {before['shots'][shot]['draw_calls']} DC", fill=(230, 220, 200))
        d.text((w + 14, 6), f"nachher {after['source_commit']} | {info['primitives']} Prim. {info['draw_calls']} DC | {args.profile}", fill=(230, 220, 200))
        rows.append(row)
        row.save(args.out / f"vergleich_{args.profile}_{shot}.jpg", quality=90)
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (0, 0, 0))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(args.out / f"vergleich_{args.profile}.jpg", quality=88)
    print("REVIEW_SHEET", args.out / f"vergleich_{args.profile}.jpg")


if __name__ == "__main__":
    main()
