"""Run the runtime profiling harness over scenes x graphics profiles.

CPU pass (headless): the same scripts, physics and animation run as on a
device, without rasterisation. It is repeated and the median run is kept.
Render pass (xvfb + Mesa llvmpipe, optional): short, only for render
counters (draw calls, primitives, objects, video/texture memory).

Every number is a desktop or software-renderer measurement. It compares
source states relative to each other and is never an Android result.

Usage:
  python3 tools/perf/runtime_profile.py --godot <binary> --label before \
      --out docs/42_performance [--render] [--repeat 3]
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "prototype"
HARNESS = "res://tests/runtime_profile_harness.gd"
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:(?! Condition \"status < 0\")", re.MULTILINE)
SCENES = ["village", "city", "district", "valley"]
QUALITIES = ["low", "balanced", "high", "very_high"]


def run_once(engine, scene, quality, mode, frames, warmup, render, scratch):
    out = scratch / f"{scene}-{quality}-{mode}-{'render' if render else 'cpu'}-{time.monotonic_ns()}.json"
    env = os.environ.copy()
    env["IMPERATHEN_ISOLATED_TEST"] = "1"
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    with tempfile.TemporaryDirectory(prefix="imperathen-perf-") as home:
        for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[variable] = str(Path(home) / variable.lower())
        command = [engine]
        if render:
            command = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", engine]
        else:
            command.append("--headless")
        command += ["--path", str(PROJECT), "--fixed-fps", "60", "--script", HARNESS, "--",
                    f"--scene={scene}", f"--quality={quality}", f"--mode={mode}",
                    f"--frames={frames}", f"--warmup={warmup}", f"--out={out}"]
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True,
                                encoding="utf-8", errors="replace", timeout=3600)
    log = result.stdout + result.stderr
    errors = [line for line in log.splitlines() if FAILURE.search(line) and "audio_driver_alsa" not in line]
    # ALSA has no sound card in the container; its ERROR lines are not game errors.
    errors = [line for line in errors if "status < 0" not in line]
    if result.returncode != 0 or not out.exists():
        return {"failed": True, "exit_code": result.returncode, "errors": errors[:20], "log_tail": log[-3000:]}
    report = json.loads(out.read_text(encoding="utf-8"))
    report["script_errors"] = errors[:20]
    return report


def median_run(runs):
    ok = [r for r in runs if not r.get("failed")]
    if not ok:
        return runs[0]
    ok.sort(key=lambda r: r["summary"]["frame_ms"]["mean"])
    chosen = dict(ok[len(ok) // 2])
    chosen["repeat_frame_mean_ms"] = [r["summary"]["frame_ms"]["mean"] for r in ok]
    chosen["repeat_frame_p95_ms"] = [r["summary"]["frame_ms"]["p95"] for r in ok]
    # The fastest repeat is the least disturbed by other container load; it is
    # the robust cost estimate for comparing two source states.
    chosen["best_frame_mean_ms"] = min(chosen["repeat_frame_mean_ms"])
    chosen["best_frame_p95_ms"] = min(chosen["repeat_frame_p95_ms"])
    return chosen


def markdown(label, results, engine_version):
    lines = [f"# Laufzeitprofil `{label}`", "",
             f"Engine: {engine_version}. CPU-Teil headless (Skripte, Physik, Animation ohne Rasterung),",
             "Render-Zähler unter xvfb/Mesa llvmpipe. **Desktop-/Softwarerenderer-Werte, nur relativ "
             "vergleichbar, keine Android-Messung.**", "",
             "| Szene | Profil | Frame Ø ms | p95 | p99 | Wiederholungen Ø | Draw Calls | Primitive | Nodes |",
             "| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |"]
    for key in sorted(results):
        entry = results[key]
        cpu = entry.get("cpu") or entry.get("render", {})
        render = entry.get("render", {})
        if cpu.get("failed"):
            lines.append(f"| {key} | – | FEHLER | | | | | | |")
            continue
        frame = cpu["summary"]["frame_ms"]
        draws = render.get("summary", {}).get("draw_calls", {}).get("p50", "–") if render else "–"
        prims = render.get("summary", {}).get("primitives", {}).get("p50", "–") if render else "–"
        scene, quality = key.split("/")
        lines.append(f"| {scene} | {quality} | {frame['mean']:.3f} | {frame['p95']:.3f} | {frame['p99']:.3f} | "
                     f"{', '.join(f'{v:.2f}' for v in cpu.get('repeat_frame_mean_ms', []))} | {draws} | {prims} | "
                     f"{cpu['census'].get('nodes', '–')} |")
    lines += ["", "Skriptzuordnung (attributierter Lauf, ms je Frame, größte drei je Szene/Profil):", ""]
    for key in sorted(results):
        attributed = results[key].get("attributed", {})
        rows = (attributed.get("process_attribution", []) + attributed.get("physics_attribution", []))
        rows.sort(key=lambda r: -r["ms_per_frame"])
        text = "; ".join(f"{Path(r['script']).name} {r['ms_per_frame']:.3f}" for r in rows[:3])
        lines.append(f"- {key}: {text}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--label", required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "docs/42_performance")
    parser.add_argument("--scenes", nargs="+", default=SCENES, choices=SCENES)
    parser.add_argument("--qualities", nargs="+", default=QUALITIES, choices=QUALITIES)
    parser.add_argument("--frames", type=int, default=600)
    parser.add_argument("--warmup", type=int, default=180)
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--render", action="store_true", help="Also run a short xvfb render-counter pass.")
    parser.add_argument("--render-only", action="store_true", help="Run only the xvfb render-counter pass.")
    parser.add_argument("--render-frames", type=int, default=12)
    parser.add_argument("--render-warmup", type=int, default=12)
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit(f"Godot not found: {args.godot}")
    version = subprocess.run([engine, "--version"], text=True, capture_output=True, check=True).stdout.strip()
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT,
                                text=True, capture_output=True).stdout.strip())
    results = {}
    failed = False
    with tempfile.TemporaryDirectory(prefix="imperathen-perf-out-") as scratch_name:
        scratch = Path(scratch_name)
        for scene in args.scenes:
            for quality in args.qualities:
                key = f"{scene}/{quality}"
                entry = {}
                if not args.render_only:
                    runs = [run_once(engine, scene, quality, "natural", args.frames, args.warmup, False, scratch)
                            for _ in range(args.repeat)]
                    entry["cpu"] = median_run(runs)
                    entry["attributed"] = run_once(engine, scene, quality, "attributed", args.frames, args.warmup, False, scratch)
                if args.render or args.render_only:
                    entry["render"] = run_once(engine, scene, quality, "natural", args.render_frames,
                                               args.render_warmup, True, scratch)
                for part in entry.values():
                    if part.get("failed") or part.get("failures") or part.get("script_errors"):
                        failed = True
                results[key] = entry
                shown = entry.get("cpu") or entry.get("render")
                print(f"{key}: " + ("FAILED" if shown.get("failed") else
                      f"frame mean {shown['summary']['frame_ms']['mean']:.3f} ms p95 {shown['summary']['frame_ms']['p95']:.3f}"),
                      flush=True)
    args.out.mkdir(parents=True, exist_ok=True)
    document = {"label": args.label, "engine": version, "source_commit": commit, "working_tree_modified": dirty,
                "frames": args.frames, "warmup": args.warmup, "repeat": args.repeat, "fixed_fps": 60,
                "evidence_class": "desktop headless CPU and Mesa llvmpipe render counters; relative only; no Android device",
                "results": results}
    (args.out / f"profile-{args.label}.json").write_text(json.dumps(document, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    (args.out / f"profile-{args.label}.md").write_text(markdown(args.label, results, version), encoding="utf-8")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
