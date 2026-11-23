"""Capture the same production actor/camera before and after motion corrections."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from capture_hero import FAILURE, ROOT, start_display


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--motion", action="store_true")
    parser.add_argument("--metrics-only", action="store_true")
    parser.add_argument("--baseline-ref")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-motion-", dir="/dev/shm") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        server = log = None
        baseline_path = None
        baseline_hash = None
        try:
            server, log = start_display(directory, env)
            command = ["godot", "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1100x800", "--max-fps", "60", "--script",
                       "res://tests/character_motion_review.gd", "--", str(output)]
            if args.motion:
                command.append("--motion")
            if args.metrics_only:
                command.append("--metrics-only")
            if args.baseline_ref:
                old_source = subprocess.run(["git", "show", args.baseline_ref + ":prototype/scripts/visuals/village_person.gd"],
                                            cwd=ROOT, check=True, stdout=subprocess.PIPE).stdout
                handle = tempfile.NamedTemporaryFile(prefix="motion_baseline_", suffix=".gd", dir=ROOT / "prototype", delete=False)
                baseline_path = Path(handle.name)
                handle.write(old_source)
                handle.close()
                baseline_hash = hashlib.sha256(old_source).hexdigest()
                command.append("--actor-script=res://" + baseline_path.name)
            result = subprocess.run(command, env=env, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = result.returncode == 0 and not FAILURE.search(result.stdout) and "CHARACTER_MOTION_REVIEW_PASS" in result.stdout
            if not passed:
                print(result.stdout[-5000:])
                return 1
            receipt = output / "motion-review.json"
            review = json.loads(receipt.read_text())
            sources = ["prototype/scripts/visuals/village_person.gd", "prototype/tests/character_motion_review.gd",
                       "prototype/scripts/visuals/facial_motion.gd", "tools/characters/capture_motion.py"]
            if not baseline_hash:
                for name in ["character_motion.gd", "hand_pose.gd"]:
                    if (ROOT / "prototype/scripts/visuals" / name).is_file():
                        sources.append("prototype/scripts/visuals/" + name)
                sources.extend(str(path.relative_to(ROOT)) for path in sorted((ROOT / "prototype/assets/characters").glob("hero_hand_grip_*.res")))
            sources.extend(str(path.relative_to(ROOT)) for path in sorted((ROOT / "prototype/assets/characters").glob("hero_quality_*.glb")))
            review["source_sha256"] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
            if baseline_hash:
                review["baseline"] = {"commit": args.baseline_ref, "village_person_sha256": baseline_hash}
                review["source_sha256"]["prototype/scripts/visuals/village_person.gd"] = baseline_hash
            if args.motion:
                movie = output / "character-motion.mp4"
                subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                                "-i", str(output / "frames/frame-%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                                "-crf", "21", str(movie)], check=True)
                review["movie"] = {"file": movie.name, "frames": 240, "playback_fps": 30, "measured_fps": False,
                                   "scenario": "Deterministic production rig: 1.45 m/s walk, 3.8 m/s run, timed jab/hook/uppercut/highkick; studio actor remains centered"}
                shutil.rmtree(output / "frames")
            receipt.write_text(json.dumps(review, indent=2) + "\n")
            print(json.dumps({"passed": True, "output": str(output), "android_device_test": False}))
            return 0
        finally:
            if baseline_path:
                baseline_path.unlink(missing_ok=True)
                baseline_path.with_suffix(".gd.uid").unlink(missing_ok=True)
            if server:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
            if log:
                log.close()


if __name__ == "__main__":
    raise SystemExit(main())
