"""D-038 render evidence for the vegetation: counters table, asset checksums
and before/after contact sheets from two tests/vegetation_review.gd runs.

    python3 art/vegetation/evidence.py <before_dir> <after_dir> <out_dir> \
        --before-commit <sha> --after-commit <sha>

Writes <out_dir>/vegetation_evidence.md, contact sheets
compare-<profile>.jpg (every shot, before left, after right) and
assets_sha256.json. Needs Pillow.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "prototype/assets/vegetation"
SHOTS = ["path", "overview", "stream", "west_edge", "north_hills", "south_fields", "meadow"]
PROFILES = ["low", "balanced", "high", "very_high"]
LABELS = {"low": "Leicht", "balanced": "Ausgewogen", "high": "Hoch", "very_high": "Ultra"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sheet(before_dir, after_dir, profile, out, width=640):
    rows = []
    for shot in SHOTS:
        b = before_dir / f"before-{shot}-{profile}.png"
        a = after_dir / f"after-{shot}-{profile}.png"
        if b.exists() and a.exists():
            rows.append((shot, Image.open(b).convert("RGB"), Image.open(a).convert("RGB")))
    if not rows:
        return None
    h = int(width * rows[0][1].height / rows[0][1].width)
    canvas = Image.new("RGB", (width * 2 + 12, (h + 26) * len(rows)), (18, 18, 18))
    pen = ImageDraw.Draw(canvas)
    for i, (shot, b, a) in enumerate(rows):
        y = i * (h + 26)
        pen.text((6, y + 6), f"{shot} / {LABELS[profile]}: vorher (89e735d)", fill=(230, 230, 230))
        pen.text((width + 18, y + 6), f"{shot} / {LABELS[profile]}: nachher", fill=(230, 230, 230))
        canvas.paste(b.resize((width, h), Image.LANCZOS), (0, y + 24))
        canvas.paste(a.resize((width, h), Image.LANCZOS), (width + 12, y + 24))
    canvas.save(out, quality=88)
    return out


def merged(folder, label):
    """One report from the per-profile capture runs (<label>-vegetation-<profiles>.json)."""
    result = None
    for path in sorted(folder.glob(f"{label}-vegetation-*.json")):
        part = json.loads(path.read_text())
        if result is None:
            result = part
            result["load_ms"] = [part.get("load_ms")]
            continue
        for shot, by_profile in part["shots"].items():
            result["shots"].setdefault(shot, {}).update(by_profile)
        result["errors"] = result["errors"] + part["errors"]
        result["load_ms"].append(part.get("load_ms"))
        result["memory"]["static_mib"] = max(result["memory"]["static_mib"], part["memory"]["static_mib"])
    if result is None:
        raise SystemExit(f"No {label}-vegetation-*.json in {folder}")
    return result


def fmt(value):
    if isinstance(value, float):
        return f"{value:.1f}"
    return str(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--before-commit", default="89e735d")
    parser.add_argument("--after-commit", default="working tree")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    before = merged(args.before, "before")
    after = merged(args.after, "after")
    checksums = {str(p.relative_to(ROOT)): sha(p) for p in sorted(ASSETS.rglob("*")) if p.is_file() and p.suffix in (".glb", ".png", ".json")}
    (args.out / "assets_sha256.json").write_text(json.dumps(checksums, indent=1) + "\n")
    lines = ["# Vegetation Valdora: Rendernachweis (D-038)", "",
             f"- Quellcommit vorher: `{args.before_commit}`, nachher: `{args.after_commit}`",
             f"- Engine: {after['engine']}, Renderer `{after['renderer']}`, Treiber `{after['driver']}`, Adapter `{after['adapter']}` "
             f"({after.get('adapter_vendor', '')}; Software-Rasterizer, keine Gerätemessung)",
             f"- Auflösung {after['output_pixels'][0]} x {after['output_pixels'][1]}, {after['frames_per_measurement']} Messbilder je Aufnahme, Median",
             f"- Ladezeit Spielwelt (Hauptmenü bis Spiel, Software-Renderer): vorher {before.get('load_ms', '?')} ms, nachher {after.get('load_ms', '?')} ms",
             f"- Statischer Speicher (Godot, Prozess-Skript-Heap): vorher {before['memory']['static_mib']:.0f} MiB, nachher {after['memory']['static_mib']:.0f} MiB",
             f"- Fehler der Aufnahmeläufe: vorher {before['errors']}, nachher {after['errors']}",
             "- Kameras: identisch vorher/nachher (feste Augpunkte und Ziele in `tests/vegetation_review.gd`; `path` über das Spielkamera-Rig)", "",
             "Zeitwerte stammen aus llvmpipe/Software-Rendering und sind nur relative Hinweise zwischen den Aufnahmen, keine Fold7-Leistung.", "",
             "## Zähler je Aufnahme und Profil (vorher -> nachher)", "",
             "| Aufnahme | Profil | Draw Calls | Primitive | Objekte | Schatten-Primitive | Textur MiB | Bildzeit ms (llvmpipe) | Baum-Instanzen sichtbar (LOD0/1/2/3/Impostor) | Baum-Dreiecke | Kraut/Feld-Instanzen | Kraut/Feld-Dreiecke | Halmbüschel | Halm-Dreiecke |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for shot in SHOTS:
        for profile in PROFILES:
            sb = before["shots"].get(shot, {}).get(profile)
            sa = after["shots"].get(shot, {}).get(profile)
            if not sb or not sa:
                continue
            veg = sa.get("vegetation", {})
            levels = veg.get("visible_by_level", {})
            lods = "/".join(str(levels.get(k, 0)) for k in ("lod0", "lod1", "lod2", "lod3", "impostor"))
            lines.append(f"| {shot} | {LABELS[profile]} | {fmt(sb['draw_calls'])} -> {fmt(sa['draw_calls'])} | {fmt(sb['primitives'])} -> {fmt(sa['primitives'])} | "
                         f"{fmt(sb['objects'])} -> {fmt(sa['objects'])} | {fmt(sb['shadow_primitives'])} -> {fmt(sa['shadow_primitives'])} | "
                         f"{sb['texture_mib']:.0f} -> {sa['texture_mib']:.0f} | {sb['wall_ms_p50']:.0f} -> {sa['wall_ms_p50']:.0f} | {lods} | "
                         f"{veg.get('tree_triangles_submitted', '-')} | {veg.get('card_instances_visible', '-')} | {veg.get('card_triangles_submitted', '-')} | "
                         f"{veg.get('grass_tufts_visible', '-')} | {veg.get('grass_triangles_submitted', '-')} |")
    any_veg = next(iter(next(iter(after["shots"].values())).values())).get("vegetation", {})
    lines += ["", "## Platzierte Pflanzen (alle Profile gleich)", "", "```json", json.dumps(any_veg.get("placed", {}), indent=1, sort_keys=True), "```", "",
              "## Kontaktbögen", ""]
    for profile in PROFILES:
        path = sheet(args.before, args.after, profile, args.out / f"compare-{profile}.jpg")
        if path:
            lines.append(f"- {LABELS[profile]}: `{path.name}`")
    lines += ["", "## Geladene Vegetationsdateien", "",
              f"{len(checksums)} Dateien unter `prototype/assets/vegetation/`, SHA-256 in `assets_sha256.json`."]
    (args.out / "vegetation_evidence.md").write_text("\n".join(lines) + "\n")
    print("EVIDENCE", args.out / "vegetation_evidence.md")


if __name__ == "__main__":
    main()
