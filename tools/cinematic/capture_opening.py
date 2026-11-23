"""Capture the production opening with a real graphical Godot viewport.

Uses the existing private authenticated Xorg helper if no display is available.
The isolated user directory prevents changes to player saves and preferences.
A rendered video is a deterministic visual review, never a device FPS benchmark.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)


def load_display_helper():
    spec = importlib.util.spec_from_file_location("imperathen_capture_display", ROOT / "tools/characters/capture_hero.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("The existing capture display helper is missing.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--software-x11", action="store_true")
    parser.add_argument("--motion", action="store_true")
    parser.add_argument("--skip-stills", action="store_true", help="Reuse a completed still pass when recording a separate motion pass")
    parser.add_argument("--motion-fps", type=int, choices=range(12, 31), default=18)
    parser.add_argument("--motion-seconds-per-shot", type=float, default=0.0, help="0 captures the full opening; positive values capture an honest centered excerpt per shot")
    parser.add_argument("--motion-profile", choices=["low", "balanced", "high", "very_high"], default="very_high")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit("Godot executable is missing.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-opening-review-") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        server = log = None
        try:
            if args.software_x11 or not env.get("DISPLAY"):
                server, log = load_display_helper().start_display(directory, env)
            command = [engine, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1600x900", "--max-fps", "30", "--script",
                       "res://tests/opening_graphics_review.gd", "--", str(output)]
            if args.skip_stills:
                command += ["--skip-stills"]
            if args.motion:
                command += ["--motion", "--motion-fps", str(args.motion_fps), "--motion-seconds-per-shot", str(max(0.0, args.motion_seconds_per_shot)), "--motion-profile", args.motion_profile]
            log_path = output / "runtime.log"
            timed_out = False
            with log_path.open("w", encoding="utf-8") as runtime_log:
                process = subprocess.Popen(command, env=env, cwd=ROOT, text=True,
                                           stdout=runtime_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + (900 if args.motion else 600)
                read_offset = 0
                try:
                    while process.poll() is None:
                        with log_path.open("r", encoding="utf-8") as progress:
                            progress.seek(read_offset)
                            recent = progress.read()
                            read_offset = progress.tell()
                        timed_out = time.monotonic() >= deadline
                        if FAILURE.search(recent) or timed_out:
                            process.terminate()
                            try:
                                process.wait(timeout=5)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait()
                            break
                        time.sleep(0.25)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                result = subprocess.CompletedProcess(command, process.returncode)
            if timed_out:
                with log_path.open("a", encoding="utf-8") as runtime_log:
                    runtime_log.write("\nCAPTURE_TIMEOUT\n")
                print(json.dumps({"passed": False, "reason": "timeout", "output": str(output)}))
                return 1
            captured = log_path.read_text(encoding="utf-8")
            receipt = output / "runtime-review.json"
            passed = result.returncode == 0 and FAILURE.search(captured) is None
            passed = passed and "OPENING_GRAPHICS_REVIEW []" in captured and receipt.is_file()
            if passed:
                review = json.loads(receipt.read_text(encoding="utf-8"))
                sources = ["prototype/scripts/main.gd", "prototype/scripts/world/game_world.gd", "prototype/scripts/world/village/opening_props.gd",
                           "prototype/scripts/cinematic/opening_director.gd",
                           "prototype/scripts/ui/opening_overlay.gd",
                           "prototype/tests/opening_graphics_review.gd",
                           "prototype/assets/quality_profiles.json", "prototype/project.godot"]
                sources += [str(p.relative_to(ROOT)) for p in (ROOT / "prototype/scripts/story").glob("opening*.gd")]
                sources += [str(p.relative_to(ROOT)) for p in (ROOT / "prototype/scripts/world/village").glob("*well*.gd")]
                review["source_sha256"] = {source: hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
                                           for source in sorted(sources) if (ROOT / source).is_file()}
                review["artifact_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                             for p in sorted(output.glob("*.png"))}
                if args.motion:
                    motion = review.get("motion", {})
                    fps = int(motion.get("playback_fps", args.motion_fps))
                    ffmpeg = shutil.which("ffmpeg")
                    if ffmpeg is None:
                        raise RuntimeError("ffmpeg is required to encode the requested review video.")
                    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(fps),
                                    "-i", str(output / "motion/frame-%05d.png"), "-c:v", "libx264",
                                    "-frames:v", str(int(motion["frames"])), "-preset", "medium", "-threads", "2", "-crf", "25", "-pix_fmt", "yuv420p",
                                    "-movflags", "+faststart", str(output / "opening-runtime.mp4")], check=True)
                    movie = output / "opening-runtime.mp4"
                    review["artifact_sha256"][movie.name] = hashlib.sha256(movie.read_bytes()).hexdigest()
                receipt.write_text(json.dumps(review, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            print(json.dumps({"passed": passed, "exit_code": result.returncode, "output": str(output),
                              "android_device_test": False}))
            if not passed:
                print(captured[-6500:])
            return 0 if passed else 1
        finally:
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
