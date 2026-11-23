"""Capture the actual isolated Godot rider module using the existing private Xorg helper."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("hero_capture", ROOT / "tools/characters/capture_hero.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-mounted-review-") as temporary:
        directory = Path(temporary)
        environment = os.environ.copy()
        for name in ("DATA", "CONFIG", "CACHE"):
            child = directory / name.lower()
            child.mkdir()
            environment[f"XDG_{name}_HOME"] = str(child)
        server, log = helper.start_display(directory, environment)
        try:
            command = ["godot", "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1024x576", "--max-fps", "15", "--script",
                       "res://tests/childhood_raiders_review.gd", "--", str(output)]
            try:
                result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
            except subprocess.TimeoutExpired as error:
                transcript = error.stdout or ""
                if isinstance(transcript, bytes):
                    transcript = transcript.decode("utf-8", errors="replace")
                (output / "runtime.log").write_text(transcript + "\nTIMEOUT\n", encoding="utf-8")
                return 1
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = (result.returncode == 0 and helper.FAILURE.search(result.stdout) is None
                      and "CHILDHOOD_RAIDERS_REVIEW []" in result.stdout)
            files = [ROOT / "prototype/scripts/world/childhood_raiders.gd",
                     ROOT / "prototype/tests/childhood_raiders_review.gd"]
            receipt = {"passed":passed, "android_device_test":False,
                       "source_sha256":{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest()
                                        for path in files}}
            (output / "source-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            print(json.dumps({"passed":passed, "output":str(output), "android_device_test":False}))
            return 0 if passed else 1
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
            log.close()


if __name__ == "__main__":
    raise SystemExit(main())
