"""Capture the actual mobile HUD in main.tscn using the existing local renderer."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from capture_hero import FAILURE, ROOT, start_display


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-touch-hud-", dir="/dev/shm") as temporary:
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
            command = ["godot", "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1280x720", "--max-fps", "60", "--script",
                       "res://tests/touch_hud_review.gd", "--", str(output)]
            result = subprocess.run(command, env=env, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = result.returncode == 0 and not FAILURE.search(result.stdout) and "TOUCH_HUD_REVIEW_PASS" in result.stdout
            attempt = {"passed": passed, "returncode": result.returncode,
                       "signal": -result.returncode if result.returncode < 0 else None,
                       "completion_marker": "TOUCH_HUD_REVIEW_PASS" in result.stdout,
                       "script_error": bool(FAILURE.search(result.stdout))}
            (output / "capture-attempt.json").write_text(json.dumps(attempt, indent=2) + "\n", encoding="utf-8")
            if not passed:
                print(json.dumps(attempt))
                print(result.stdout[-7000:])
                return 1
            receipt = output / "touch-hud-review.json"
            review = json.loads(receipt.read_text())
            sources = ["prototype/scripts/ui/game_ui.gd", "prototype/scripts/ui/touch_pad.gd",
                       "prototype/scripts/ui/touch_action.gd", "prototype/scripts/ui/touch_look.gd",
                       "prototype/scripts/ui/touch_modal.gd", "prototype/scripts/ui/android_village_diagnostics.gd",
                       "prototype/tests/touch_hud_review.gd",
                       "prototype/scripts/main.gd", "prototype/scripts/world/game_world.gd"]
            review["source_sha256"] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
            receipt.write_text(json.dumps(review, indent=2) + "\n", encoding="utf-8")
            print(json.dumps({"passed": True, "output": str(output), "android_device_test": False}))
            return 0
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
