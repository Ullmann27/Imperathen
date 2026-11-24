"""Record source-bound production movement for a later human/agent visual review.

Capturing is not approving. No entry in motion_reviews.json is generated here.
Desktop software rendering is not evidence of Android frame rate or thermals.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from capture_hero import FAILURE, ROOT, start_display

sys.path.insert(0, str(ROOT / "tools"))
from motion_quality_gate import capture_errors, digest, json_read, source_commit, source_fingerprint


def run_logged(command: list[str], destination: Path, name: str, timeout: float,
               environment: dict | None = None) -> subprocess.CompletedProcess:
    """Keep the real exit status and partial output even when a renderer dies."""
    record = {"command": command, "timeout_seconds": timeout, "timed_out": False}
    stdout = stderr = ""
    try:
        result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                                text=True, check=False, timeout=timeout)
        record["exit_code"] = result.returncode
        stdout, stderr = result.stdout, result.stderr
        return result
    except subprocess.TimeoutExpired as error:
        record["timed_out"] = True
        record["exit_code"] = None
        stdout, stderr = error.stdout or "", error.stderr or ""
        raise
    except OSError as error:
        record.update(exit_code=None, error=str(error))
        raise
    finally:
        # TimeoutExpired may carry bytes even when text=True was requested.
        stdout = stdout.decode("utf-8", errors="replace") if isinstance(stdout, bytes) else stdout
        stderr = stderr.decode("utf-8", errors="replace") if isinstance(stderr, bytes) else stderr
        (destination / (name + ".log")).write_text(stdout + stderr, encoding="utf-8")
        (destination / (name + "-process.json")).write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def batches(contract: dict, requested: set[str]) -> list[dict]:
    result = []
    families = {item["id"]: item for item in contract["families"]}
    unknown = requested - families.keys()
    if unknown:
        raise ValueError("Unknown movement families: " + ", ".join(sorted(unknown)))
    for key, family in families.items():
        if family["status"] != "active" or (requested and key not in requested):
            continue
        resources = family["resources"]
        if key in {"village_navigation", "raid_motion", "cinematic_people", "distant_ranks"}:
            result.append({"id": key, "family": key, "kind": key, "subjects": resources or ["family:" + key],
                           "actor_paths": [], "requested_scenarios": family["review_scope"]})
            continue
        if key == "service_gear":
            result.append({"id": key, "family": key, "kind": "service", "subjects": resources,
                           "actor_paths": families["hero"]["resources"], "requested_scenarios": family["review_scope"]})
            continue
        if key == "meshy_gear":
            for actor in ("unit_germanic_axe_fighter", "unit_roman_signifer"):
                props = [path for path in resources if ("signum" in path) == ("signifer" in actor)]
                result.append({"id": key + "-" + actor, "family": key, "kind": "person", "subjects": props,
                               "actor_paths": [path for path in families["meshy_people"]["resources"] if actor in path],
                               "requested_scenarios": family["review_scope"]})
            continue
        if key == "regional_workers":
            result.append({"id": key, "family": key, "kind": "regional", "subjects": resources,
                           "actor_paths": resources, "requested_scenarios": family["review_scope"]})
            continue
        groups = {}
        for path in resources:
            stem = re.sub(r"_(?:[0-3]|near|mid)\.glb$", "", Path(path).name)
            groups.setdefault(stem, []).append(path)
        for stem, paths in groups.items():
            result.append({"id": key + "-" + stem, "family": key, "kind": "person", "subjects": paths,
                           "actor_paths": paths, "requested_scenarios": family["review_scope"]})
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/19_motion_combat/evidence/motion-quality")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--families", nargs="*", default=[])
    parser.add_argument("--batch", help="Record one exact batch ID from --list")
    parser.add_argument("--list", action="store_true", help="Print capture batches without rendering")
    parser.add_argument("--limit-seconds", type=float, default=0,
                        help="Explicitly partial smoke capture; unrendered scenarios are never claimed")
    parser.add_argument("--timeout", type=int, default=900, help="Per-batch rendering timeout")
    args = parser.parse_args()
    if not math.isfinite(args.limit_seconds) or args.limit_seconds < 0 or args.timeout <= 0:
        parser.error("Duration limit must be nonnegative and timeout positive")
    selected = batches(json_read(ROOT / "quality/motion_contract.json"), set(args.families))
    if args.batch:
        selected = [batch for batch in selected if batch["id"] == args.batch]
        if not selected:
            parser.error("Unknown or excluded batch ID")
    if not selected:
        parser.error("No active movement families selected")
    if args.list:
        print(json.dumps(selected, ensure_ascii=False, indent=2))
        return 0
    engine, encoder = shutil.which(args.godot), shutil.which("ffmpeg")
    if not engine or not encoder or not shutil.which("ffprobe"):
        raise SystemExit("Godot, ffmpeg and ffprobe are required for actual graphical movement captures")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before, revision = source_fingerprint(ROOT), source_commit(ROOT)
    manifest = {"schema_version": 1, "status": "captured_unreviewed", "source_fingerprint": before,
                "source_commit": revision, "android_device_test": False, "measured_fps": False,
                "rendering": "Godot Compatibility; authenticated private software X11 display",
                "simulation_hz": 60, "playback_fps": 30, "partial": args.limit_seconds > 0,
                "batches": [], "errors": []}
    with tempfile.TemporaryDirectory(prefix="imperathen-quality-capture-") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        server = log = None
        try:
            server, log = start_display(directory, env)
            for batch in selected:
                destination = output / batch["id"]
                destination.mkdir(exist_ok=False)
                plan = {**batch, "output": str(destination), "source_fingerprint": before,
                        "limit_seconds": args.limit_seconds, "resolution": [1280, 720]}
                plan_path = destination / "capture-plan.json"
                plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
                command = [engine, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                           "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                           "--resolution", "1280x720", "--fixed-fps", "30", "--script",
                           "res://tests/motion_quality_review.gd", "--", str(plan_path)]
                print("MOTION_CAPTURE_BEGIN", batch["id"], flush=True)
                try:
                    result = run_logged(command, destination, "runtime", args.timeout, env)
                    if result.returncode or FAILURE.search(result.stdout + result.stderr) or "MOTION_CAPTURE_RECORDED" not in result.stdout:
                        raise RuntimeError(f"Actual Godot capture failed (exit {result.returncode}); inspect runtime.log and runtime-process.json")
                    receipt = json_read(destination / "rendered.json")
                    frames = sorted((destination / "frames").glob("frame-*.jpg"))
                    if receipt.get("source_fingerprint") != before or receipt.get("frame_count") != len(frames) or len(frames) < 2:
                        raise RuntimeError("Capture receipt and actual rendered frames differ")
                    movie = destination / (batch["id"] + ".mp4")
                    encoded = run_logged([encoder, "-hide_banner", "-loglevel", "error", "-framerate", "30",
                                          "-i", str(destination / "frames/frame-%06d.jpg"), "-frames:v", str(len(frames)),
                                          "-c:v", "libx264", "-threads", "2", "-pix_fmt", "yuv420p", "-crf", "18", str(movie)],
                                         destination, "encoding", 180)
                    if encoded.returncode:
                        raise RuntimeError(f"Capture encoding failed (exit {encoded.returncode}); inspect encoding.log")
                    errors = capture_errors(movie)
                    if errors:
                        raise RuntimeError("Encoded capture rejected: " + "; ".join(errors))
                    receipt.update(file=str(movie.relative_to(output)), sha256=digest(movie),
                                   status="captured_unreviewed", playback_fps=30, measured_fps=False)
                    (destination / "rendered.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
                    manifest["batches"].append(receipt)
                    shutil.rmtree(destination / "frames")
                    print("MOTION_CAPTURE_SAVED", movie, flush=True)
                except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                    manifest["errors"].append({"batch": batch["id"], "error": str(error)})
                    print("MOTION_CAPTURE_FAILED", batch["id"], str(error), flush=True)
                    break
        finally:
            if server:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill(); server.wait()
            if log:
                log.close()
    manifest["source_unchanged"] = source_fingerprint(ROOT) == before and source_commit(ROOT) == revision
    if not manifest["source_unchanged"]:
        manifest["errors"].append({"error": "Source changed during capture; these frames are exploratory only"})
    if manifest["errors"]:
        manifest["status"] = "capture_incomplete_or_stale"
    manifest["capture_completed"] = not manifest["errors"] and len(manifest["batches"]) == len(selected)
    (output / "capture-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"capture_completed": manifest["capture_completed"], "status": manifest["status"],
                      "batches": len(manifest["batches"]), "output": str(output)}))
    return 0 if manifest["capture_completed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
