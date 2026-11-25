"""Capture a real Godot test viewport with an isolated, authenticated X server.

Xorg and Godot must be children of this same process. Separate tool calls can
have different network namespaces even when their filesystem is shared.
This software-rendered review does not establish Android device frame rates.
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--script", default="res://tests/settlement_graphics_review.gd")
    parser.add_argument("--capture-flag", action="store_true",
                        help="Pass --capture-dir=OUTPUT to the test instead of a positional output path")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--resolution", default="1280x720")
    parser.add_argument("--quality", choices=("low", "balanced", "high", "very_high"), default="balanced")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit("Godot executable is missing")
    if re.fullmatch(r"[1-9][0-9]{2,3}x[1-9][0-9]{2,3}", args.resolution) is None:
        raise SystemExit("Resolution must be a width x height such as 854x480")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location("capture_display", ROOT / "tools/characters/capture_hero.py")
    if spec is None or spec.loader is None:
        raise SystemExit("The authenticated display helper is missing")
    display = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(display)
    with tempfile.TemporaryDirectory(prefix="imperathen-settlement-capture-") as temporary:
        directory = Path(temporary)
        environment = os.environ.copy()
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            environment[f"XDG_{kind}_HOME"] = str(location)
        server = display_log = None
        try:
            server, display_log = display.start_display(directory, environment)
            script_output = "--capture-dir=" + str(output) if args.capture_flag else str(output)
            command = [engine, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", args.resolution, "--max-fps", "30", "--script", args.script,
                       "--", script_output, "--quality=" + args.quality]
            log_path = output / "viewport.log"
            source_paths = sorted(path for path in (ROOT / "prototype").rglob("*")
                                  if path.is_file() and ".godot" not in path.parts
                                  and path.suffix in (".gd", ".gdshader", ".json", ".godot", ".tscn", ".glb", ".png", ".jpg", ".webp", ".import"))
            source_hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                             for path in source_paths}
            started_ns = time.time_ns()
            try:
                with log_path.open("w", encoding="utf-8") as runtime_log:
                    result = subprocess.run(command, cwd=ROOT, env=environment,
                                            stdout=runtime_log, stderr=subprocess.STDOUT, timeout=600)
            except subprocess.TimeoutExpired:
                print(json.dumps({"passed": False, "reason": "viewport capture timed out", "output": str(output)}))
                return 1
            captured = log_path.read_text(encoding="utf-8")
            images = sorted(path for path in output.glob("*.png") if path.stat().st_mtime_ns >= started_ns)
            changed_sources = [str(path.relative_to(ROOT)) for path in source_paths
                               if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()
                               != source_hashes[str(path.relative_to(ROOT))]]
            passed = result.returncode == 0 and "OpenGL API" in captured and FAILURE.search(captured) is None and bool(images) and not changed_sources
            receipt = {
                "passed": passed, "exit_code": result.returncode, "script": args.script,
                "requested_resolution": args.resolution, "requested_quality": args.quality,
                "renderer": "Godot OpenGL Compatibility with a private Xorg server and software Mesa",
                "android_device_test": False,
                "images": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in images},
                "source_sha256_before_capture": source_hashes,
                "sources_changed_during_capture": changed_sources,
            }
            (output / "capture-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(receipt, ensure_ascii=False))
            if not passed:
                print(captured[-5000:])
            return 0 if passed else 1
        finally:
            if server is not None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
            if display_log is not None:
                display_log.close()


if __name__ == "__main__":
    raise SystemExit(main())
