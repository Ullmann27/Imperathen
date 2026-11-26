#!/usr/bin/env python3
"""Run the renderer comparison (D-033) and the profile measurement (D-034).

Runs tests/render_feature_probe.gd and tests/render_comparison.gd once per
renderer with identical scenes, cameras and resolution:

  compatibility  --rendering-method gl_compatibility --rendering-driver opengl3
                 (Xvfb + Mesa llvmpipe, software OpenGL)
  mobile         --rendering-method mobile --rendering-driver vulkan
  forward_plus   --rendering-method forward_plus --rendering-driver vulkan
                 (Xvfb + Mesa lavapipe, software Vulkan)

and then measures pixel differences, relative costs and contact sheets.
Everything this machine measures is a SOFTWARE renderer on a shared CPU:
images and feature presence are valid, timings are relative indicators only,
never mobile-GPU or Fold7 performance.

Usage:
  python3 tools/render/compare_renderers.py --godot GODOT --out DIR [--lock FILE]
      [--renderers compatibility,mobile,forward_plus] [--steps probe,village,city]
  python3 tools/render/compare_renderers.py --out DIR --analyze-only
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "prototype"
RENDERERS = {
    "compatibility": {"method": "gl_compatibility", "driver": "opengl3", "vulkan": False},
    "mobile": {"method": "mobile", "driver": "vulkan", "vulkan": True},
    "forward_plus": {"method": "forward_plus", "driver": "vulkan", "vulkan": True},
}
LAVAPIPE_ICD = "/opt/lavapipe/lvp_icd.json"
PROFILES = ["low", "balanced", "high", "very_high"]


def environment(renderer: dict, out: Path) -> dict:
    env = os.environ.copy()
    env["IMPERATHEN_ISOLATED_TEST"] = "1"
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    xdg = out / "xdg"
    for key, sub in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        (xdg / sub).mkdir(parents=True, exist_ok=True)
        env[key] = str(xdg / sub)
    env["IMPERATHEN_SOURCE_COMMIT"] = git("rev-parse", "HEAD")
    if renderer["vulkan"]:
        # Same switches as /opt/lavapipe/use-lavapipe.sh, without its browser flags.
        env.pop("VK_DRIVER_FILES", None)
        env["VK_ICD_FILENAMES"] = LAVAPIPE_ICD
        env["GALLIVM_PERF"] = "no_aos_sampling"
        env["LP_PERF"] = "no_rast_linear"
        env.setdefault("MESA_SHADER_CACHE_DIR", str(xdg / "cache" / "mesa"))
    else:
        env.pop("VK_ICD_FILENAMES", None)
    return env


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], text=True, capture_output=True).stdout.strip()


def run_step(godot: str, name: str, renderer_id: str, script: str, user_args: list[str], out: Path,
             size: tuple[int, int], timeout: int, texture_tier: str = "") -> dict:
    renderer = RENDERERS[renderer_id]
    command = ["xvfb-run", "-a", "-s", f"-screen 0 {size[0]}x{size[1]}x24", godot, "--path", str(PROJECT),
               "--rendering-method", renderer["method"], "--rendering-driver", renderer["driver"],
               "--resolution", f"{size[0]}x{size[1]}", "--script", script, "++", *user_args]
    started = time.monotonic()
    load_before = os.getloadavg()
    env = environment(renderer, out)
    if texture_tier:
        env["IMPERATHEN_TEXTURE_TIER"] = texture_tier
    try:
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, encoding="utf-8",
                                errors="replace", capture_output=True, timeout=timeout)
        log = result.stdout + result.stderr
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        log = f"TIMEOUT {name}: {exc}\n" + ((exc.stdout or b"").decode(errors="replace") if isinstance(exc.stdout, bytes) else str(exc.stdout or ""))
        code = None
    (out / f"{name}.log").write_text(log, encoding="utf-8")
    record = {"step": name, "renderer": renderer_id, "texture_tier": texture_tier or "base", "exit_code": code, "elapsed_s": round(time.monotonic() - started, 1),
              "load_average_before": load_before, "load_average_after": os.getloadavg(),
              "command": command, "log": f"{name}.log",
              "script_errors": [line for line in log.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")][:40]}
    print(f"{'DONE' if code == 0 else 'FAIL'} {name} exit={code} {record['elapsed_s']} s", flush=True)
    return record


# ---------------------------------------------------------------- analysis

def load_rgb(path: Path):
    from PIL import Image
    import numpy
    return numpy.asarray(Image.open(path).convert("RGB"), dtype=numpy.int16)


def difference(a: Path, b: Path) -> dict | None:
    import numpy
    if not a.is_file() or not b.is_file():
        return None
    x, y = load_rgb(a), load_rgb(b)
    if x.shape != y.shape:
        return {"error": f"size {x.shape} vs {y.shape}"}
    delta = numpy.abs(x - y)
    per_pixel = delta.max(axis=2)
    return {"mean_abs": round(float(delta.mean()), 3), "changed_fraction_gt8": round(float((per_pixel > 8).mean()), 5),
            "changed_fraction_gt24": round(float((per_pixel > 24).mean()), 5),
            "mean_luma_delta": round(float((y.mean() - x.mean())), 3)}


def analyze_features(out: Path) -> dict:
    result = {}
    for renderer in RENDERERS:
        report_path = out / f"probe-{renderer}" / f"probe-{renderer}-features.json"
        if not report_path.is_file():
            continue
        report = json.loads(report_path.read_text())
        folder = report_path.parent
        views = {}
        for view, data in report.get("views", {}).items():
            base = folder / data["base"]["image"]
            noise = difference(base, folder / data["base_repeat"]["image"]) if "base_repeat" in data else None
            views[view] = {"base": data["base"], "noise": noise}
        rows = {}
        for feature in report.get("features", []):
            view = views.get(feature["view"], {})
            base_stats = view.get("base", {})
            diff = difference(folder / base_stats.get("image", ""), folder / feature["stats"]["image"])
            noise = (view.get("noise") or {}).get("mean_abs", 0.0)
            visible = bool(diff and "mean_abs" in diff and diff["mean_abs"] > max(3.0 * noise, 0.15)
                           and diff["changed_fraction_gt8"] > 0.002)
            base_wall = base_stats.get("wall_ms_p50") or 0.0
            wall = feature["stats"].get("wall_ms_p50") or 0.0
            base_gpu = base_stats.get("render_gpu_ms_p50")
            gpu = feature["stats"].get("render_gpu_ms_p50")
            rows[feature["id"]] = {"view": feature["view"], "documented_support": feature.get("documented_support"),
                                   "pixels": diff, "noise_floor_mean_abs": noise, "visible_change": visible,
                                   "wall_ms_p50": wall, "wall_ratio": round(wall / base_wall, 3) if base_wall else None,
                                   "gpu_ms_p50": gpu, "gpu_ratio": round(gpu / base_gpu, 3) if gpu and base_gpu else None,
                                   "draw_calls": feature["stats"].get("draw_calls"),
                                   "video_mib": feature["stats"].get("video_mib"),
                                   "setup_ms": feature["stats"].get("setup_ms"),
                                   "image": str((folder / feature["stats"]["image"]).relative_to(out))}
        result[renderer] = {"renderer": report.get("renderer"), "views": views, "features": rows,
                            "errors": report.get("errors")}
    return result


def analyze_views(out: Path, scene: str) -> dict:
    result = {"per_renderer": {}, "cross_renderer": {}, "profile_steps": {}}
    reports = {}
    for renderer in RENDERERS:
        path = out / f"{scene}-{renderer}" / f"{scene}-{renderer}-report.json"
        if path.is_file():
            reports[renderer] = (path.parent, json.loads(path.read_text()))
    for renderer, (folder, report) in reports.items():
        result["per_renderer"][renderer] = {"renderer": report.get("renderer"), "errors": report.get("errors"),
                                            "loaded_assets": (report.get("loaded_assets") or {}).get("count"),
                                            "shots": report.get("shots")}
        steps = {}
        for view, by_profile in report.get("shots", {}).items():
            for a, b in zip(PROFILES, PROFILES[1:]):
                if a in by_profile and b in by_profile and "base" in by_profile[a] and "base" in by_profile[b]:
                    steps[f"{view}:{a}->{b}"] = difference(folder / by_profile[a]["base"]["image"], folder / by_profile[b]["base"]["image"])
            for profile, variants in by_profile.items():
                if "base" in variants and "fx" in variants:
                    steps[f"{view}:{profile}:base->fx"] = difference(folder / variants["base"]["image"], folder / variants["fx"]["image"])
        result["profile_steps"][renderer] = steps
    names = list(reports)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            pairs = {}
            for view, by_profile in reports[a][1].get("shots", {}).items():
                for profile, variants in by_profile.items():
                    other = reports[b][1].get("shots", {}).get(view, {}).get(profile, {})
                    for variant in ("base",):
                        if variant in variants and variant in other:
                            pairs[f"{view}:{profile}"] = difference(reports[a][0] / variants[variant]["image"],
                                                                    reports[b][0] / other[variant]["image"])
            result["cross_renderer"][f"{a}~{b}"] = pairs
    return result


def contact_sheets(out: Path, scene: str) -> list[str]:
    from PIL import Image, ImageDraw
    sheets = []
    reports = {}
    for renderer in RENDERERS:
        path = out / f"{scene}-{renderer}" / f"{scene}-{renderer}-report.json"
        if path.is_file():
            reports[renderer] = (path.parent, json.loads(path.read_text()))
    if not reports:
        return sheets
    views = []
    for _, (_, report) in reports.items():
        for view in report.get("shots", {}):
            if view not in views:
                views.append(view)
    thumb = (480, 270)
    for view in views:
        columns = [(p, "base") for p in PROFILES] + [("balanced", "fx")]
        sheet = Image.new("RGB", (thumb[0] * len(columns), (thumb[1] + 22) * len(reports) + 22), (18, 18, 18))
        draw = ImageDraw.Draw(sheet)
        for c, (profile, variant) in enumerate(columns):
            draw.text((c * thumb[0] + 6, 4), f"{profile} / {variant}", fill=(230, 230, 230))
        for r, (renderer, (folder, report)) in enumerate(reports.items()):
            y = 22 + r * (thumb[1] + 22)
            draw.text((6, y + 3), f"{renderer} ({report['renderer']['adapter']}) - software renderer", fill=(255, 210, 120))
            for c, (profile, variant) in enumerate(columns):
                shot = report.get("shots", {}).get(view, {}).get(profile, {}).get(variant)
                if not shot:
                    continue
                image = Image.open(folder / shot["image"]).convert("RGB").resize(thumb, Image.LANCZOS)
                sheet.paste(image, (c * thumb[0], y + 20))
        target = out / f"sheet-{scene}-{view}.jpg"
        sheet.save(target, quality=88)
        sheets.append(target.name)
    return sheets


def feature_sheet(out: Path, features: dict, ids: list[str], name: str) -> str | None:
    from PIL import Image, ImageDraw
    renderers = [r for r in RENDERERS if r in features]
    if not renderers:
        return None
    thumb = (384, 216)
    sheet = Image.new("RGB", (thumb[0] * (len(ids) + 1), (thumb[1] + 20) * len(renderers) + 20), (18, 18, 18))
    draw = ImageDraw.Draw(sheet)
    for c, fid in enumerate(["base"] + ids):
        draw.text((c * thumb[0] + 6, 4), fid, fill=(230, 230, 230))
    for r, renderer in enumerate(renderers):
        y = 20 + r * (thumb[1] + 20)
        draw.text((6, y + 2), renderer, fill=(255, 210, 120))
        data = features[renderer]
        for c, fid in enumerate(["base"] + ids):
            if fid == "base":
                view = data["features"].get(ids[0], {}).get("view", "village_lane")
                image_name = data["views"].get(view, {}).get("base", {}).get("image")
                path = out / f"probe-{renderer}" / image_name if image_name else None
            else:
                row = data["features"].get(fid)
                path = out / row["image"] if row else None
            if path and path.is_file():
                sheet.paste(Image.open(path).convert("RGB").resize(thumb, Image.LANCZOS), (c * thumb[0], y + 18))
    target = out / f"sheet-features-{name}.jpg"
    sheet.save(target, quality=88)
    return target.name


def analyze_texture_tiers(out: Path) -> dict:
    """Texture packages against the imported originals: same renderer, view and profile."""
    result = {}
    for scene in ("village", "city"):
        base_path = out / f"{scene}-compatibility" / f"{scene}-compatibility-report.json"
        if not base_path.is_file():
            continue
        base = json.loads(base_path.read_text())
        for tier in ("vram", "half"):
            label = f"{scene}-compatibility-tex_{tier}"
            path = out / label / f"{label}-report.json"
            if not path.is_file():
                continue
            other = json.loads(path.read_text())
            rows = {}
            for view, by_profile in other.get("shots", {}).items():
                for profile, variants in by_profile.items():
                    a = base.get("shots", {}).get(view, {}).get(profile, {}).get("base")
                    b = variants.get("base")
                    if not a or not b:
                        continue
                    rows[f"{view}:{profile}"] = {
                        "texture_mib": [round(a["texture_mib"], 1), round(b["texture_mib"], 1)],
                        "video_mib": [round(a["video_mib"], 1), round(b["video_mib"], 1)],
                        "wall_ms_p50": [a["wall_ms_p50"], b["wall_ms_p50"]],
                        "pixels": difference(base_path.parent / a["image"], path.parent / b["image"])}
            result[f"{scene}:{tier}"] = {"package": other.get("texture_package"), "rows": rows, "errors": other.get("errors")}
    return result


def analyze(out: Path, records: list[dict]) -> dict:
    features = analyze_features(out)
    summary = {"schema": "imperathen-renderer-comparison-1", "source_commit": git("rev-parse", "HEAD"),
               "worktree_clean": git("status", "--porcelain", "--untracked-files=no") == "",
               "machine": {"cpus": os.cpu_count(), "load_average_now": os.getloadavg(),
                           "note": "Shared cloud machine with many concurrent agents; frame times are noisy relative indicators of software rendering."},
               "runs": records, "features": features,
               "village": analyze_views(out, "village"), "city": analyze_views(out, "city"),
               "texture_packages": analyze_texture_tiers(out),
               "sheets": contact_sheets(out, "village") + contact_sheets(out, "city")}
    for name, ids in {"gi": ["ssao", "ssil", "sdfgi", "voxel_gi", "ssr", "volumetric_fog"],
                      "post": ["glow", "tonemap_agx", "tonemap_aces", "depth_of_field", "auto_exposure", "fog_sun_scatter"],
                      "aa": ["msaa_off", "msaa_4x", "fxaa", "smaa", "taa", "fsr2_67"],
                      "shadow": ["shadow_filter_hard", "shadow_filter_soft_high", "shadow_atlas_8192", "shadow_4_splits", "directional_pcss", "decal"],
                      "night": ["positional_shadows_off", "positional_filter_soft_high", "positional_pcss", "light_budget_low", "volumetric_fog_night", "glow_night"]}.items():
        sheet = feature_sheet(out, features, ids, name)
        if sheet:
            summary["sheets"].append(sheet)
    (out / "summary.json").write_text(json.dumps(summary, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    write_markdown(out, summary)
    return summary


def fmt(value, digits=1):
    if value is None:
        return "–"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def write_markdown(out: Path, summary: dict) -> None:
    """Tables for docs/39_rendering, regenerated from measured data only."""
    lines = ["# Renderer comparison – measured tables", "",
             f"Source commit `{summary['source_commit']}`. All renderers are SOFTWARE renderers on a shared cloud CPU "
             "(Compatibility: Mesa llvmpipe; Mobile/Forward+: Mesa lavapipe). Pixel changes are valid; times are relative indicators only.", ""]
    features = summary.get("features", {})
    renderers = [r for r in RENDERERS if r in features]
    if renderers:
        lines += ["## Feature probe (Ausgewogen base, change vs. base image)", "",
                  "Cell: visible change yes/no · mean abs pixel delta (0-255) · frame time ratio vs. base. Noise floor per renderer in the last rows.", "",
                  "| Feature | View | " + " | ".join(renderers) + " |", "|---|---|" + "---|" * len(renderers)]
        ids = []
        for renderer in renderers:
            for fid in features[renderer]["features"]:
                if fid not in ids:
                    ids.append(fid)
        for fid in ids:
            cells = []
            view = ""
            for renderer in renderers:
                row = features[renderer]["features"].get(fid)
                if not row:
                    cells.append("–")
                    continue
                view = row["view"]
                mean = (row.get("pixels") or {}).get("mean_abs")
                cells.append(f"{'**ja**' if row['visible_change'] else 'nein'} · {fmt(mean, 2)} · ×{fmt(row.get('wall_ratio'), 2)}")
            lines.append(f"| {fid} | {view} | " + " | ".join(cells) + " |")
        for view in ("village_lane", "night_torch"):
            noise = [fmt(((features[r]["views"].get(view) or {}).get("noise") or {}).get("mean_abs"), 3) for r in renderers]
            base = [fmt(((features[r]["views"].get(view) or {}).get("base") or {}).get("wall_ms_p50"), 0) + " ms" for r in renderers]
            lines.append(f"| noise floor | {view} | " + " | ".join(noise) + " |")
            lines.append(f"| base frame p50 | {view} | " + " | ".join(base) + " |")
        lines.append("")
    for scene in ("village", "city"):
        data = summary.get(scene, {}).get("per_renderer", {})
        if not data:
            continue
        lines += [f"## {scene}: per view, profile and renderer (base variant)", "",
                  "| View | Profile | Renderer | Frame p50 ms | GPU p50 ms | Draw calls | Primitives | Shadow draws | Texture MiB | Video MiB | RSS MiB |",
                  "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
        views = []
        for renderer, rows in data.items():
            for view in (rows.get("shots") or {}):
                if view not in views:
                    views.append(view)
        for view in views:
            for profile in PROFILES:
                for renderer, rows in data.items():
                    shot = ((rows.get("shots") or {}).get(view) or {}).get(profile, {}).get("base")
                    if not shot:
                        continue
                    lines.append(f"| {view} | {profile} | {renderer} | {fmt(shot['wall_ms_p50'], 0)} | {fmt(shot.get('render_gpu_ms_p50'), 1)} | "
                                 f"{fmt(shot['draw_calls'], 0)} | {fmt(shot['primitives'], 0)} | {fmt(shot['shadow_draw_calls'], 0)} | "
                                 f"{fmt(shot['texture_mib'])} | {fmt(shot['video_mib'])} | {fmt(shot.get('rss_mib'))} |")
        lines.append("")
        cross = summary.get(scene, {}).get("cross_renderer", {})
        if cross:
            lines += [f"## {scene}: image difference between renderers (same camera, profile, base)", "",
                      "| Pair | View:profile | mean abs | changed >8 | luma delta |", "|---|---|---:|---:|---:|"]
            for pair, rows in cross.items():
                for key, diff in rows.items():
                    if diff and "mean_abs" in diff:
                        lines.append(f"| {pair} | {key} | {fmt(diff['mean_abs'], 2)} | {fmt(diff['changed_fraction_gt8'], 3)} | {fmt(diff['mean_luma_delta'], 2)} |")
            lines.append("")
        steps = summary.get(scene, {}).get("profile_steps", {})
        if steps:
            lines += [f"## {scene}: image difference between neighbouring profiles and base→fx", "",
                      "| Renderer | Step | mean abs | changed >8 |", "|---|---|---:|---:|"]
            for renderer, rows in steps.items():
                for key, diff in rows.items():
                    if diff and "mean_abs" in diff:
                        lines.append(f"| {renderer} | {key} | {fmt(diff['mean_abs'], 2)} | {fmt(diff['changed_fraction_gt8'], 3)} |")
            lines.append("")
    tiers = summary.get("texture_packages", {})
    if tiers:
        lines += ["## Texture packages vs. imported originals (Compatibility)", "",
                  "| Scene:tier | View:profile | Texture MiB base→package | Video MiB base→package | mean abs pixel delta |", "|---|---|---|---|---:|"]
        for key, data in tiers.items():
            for row_key, row in data["rows"].items():
                lines.append(f"| {key} | {row_key} | {row['texture_mib'][0]} → {row['texture_mib'][1]} | {row['video_mib'][0]} → {row['video_mib'][1]} | "
                             f"{fmt((row.get('pixels') or {}).get('mean_abs'), 2)} |")
        lines.append("")
    (out / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--renderers", default=",".join(RENDERERS))
    parser.add_argument("--steps", default="probe,village,city")
    parser.add_argument("--profiles", default=",".join(PROFILES))
    parser.add_argument("--fx-profiles", default="balanced")
    parser.add_argument("--views", default="", help="Comma separated subset of views (default: all of the scene)")
    parser.add_argument("--features", default="", help="Comma separated subset of probe features")
    parser.add_argument("--frames", type=int, default=5)
    parser.add_argument("--size", default="1280x720")
    parser.add_argument("--lock", type=Path, help="Shared heavy-work lock, held for the whole batch")
    parser.add_argument("--timeout", type=int, default=3600, help="Per step, seconds")
    parser.add_argument("--analyze-only", action="store_true")
    parser.add_argument("--tag", default="", help="Suffix for step labels, e.g. tex_half")
    parser.add_argument("--texture-tier", default="", help="Mount this texture package in the harness (IMPERATHEN_TEXTURE_TIER)")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    records_path = out / "runs.json"
    records = json.loads(records_path.read_text()) if records_path.is_file() else []
    if not args.analyze_only:
        godot = shutil.which(args.godot) or args.godot
        size = tuple(int(v) for v in args.size.split("x"))
        lock = None
        if args.lock:
            lock = open(args.lock, "a+")
            print("waiting for lock", args.lock, flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
            print("lock acquired", flush=True)
        try:
            for renderer in args.renderers.split(","):
                for step in args.steps.split(","):
                    label = f"{step}-{renderer}" + (f"-{args.tag}" if args.tag else "")
                    folder = out / label
                    folder.mkdir(parents=True, exist_ok=True)
                    if step == "probe":
                        script, user = "res://tests/render_feature_probe.gd", [str(folder), label, str(args.frames), args.features]
                    else:
                        script = "res://tests/render_comparison.gd"
                        user = [str(folder), step, label, args.profiles, "base,fx", str(args.frames), args.fx_profiles, args.views]
                    record = run_step(godot, label, renderer, script, user, out, size, args.timeout, args.texture_tier)
                    records = [r for r in records if r["step"] != label] + [record]
                    records_path.write_text(json.dumps(records, indent=1) + "\n")
        finally:
            if lock:
                fcntl.flock(lock, fcntl.LOCK_UN)
                lock.close()
    summary = analyze(out, records)
    failed = [r["step"] for r in records if r.get("exit_code") != 0]
    print("RENDER_COMPARISON_SUMMARY", json.dumps({"runs": len(records), "failed": failed, "sheets": summary["sheets"]}))
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
