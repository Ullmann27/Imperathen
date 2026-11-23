"""Capture reproducible childhood scene views using the existing private X server."""
from __future__ import annotations

import argparse
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
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--runtime", action="store_true", help="Capture the actual Main HUD and first Julia dialogue")
    args = parser.parse_args()
    if args.baseline and args.runtime:
        parser.error("--baseline and --runtime describe different scenarios")
    spec = importlib.util.spec_from_file_location("hero_capture", ROOT / "tools/characters/capture_hero.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-chat-b-render-") as scratch:
        directory = Path(scratch)
        environment = os.environ.copy()
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        for name in ("DATA", "CONFIG", "CACHE"):
            child = directory / name.lower()
            child.mkdir()
            environment[f"XDG_{name}_HOME"] = str(child)
        server, log = helper.start_display(directory, environment)
        try:
            script = "res://tests/childhood_ui_review.gd" if args.runtime else "res://tests/childhood_render_review.gd"
            command = ["godot", "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1280x720", "--max-fps", "15", "--script", script,
                       "--", "--capture-dir=" + str(output) if args.runtime else str(output)]
            if args.baseline:
                command.append("--baseline")
            try:
                result = subprocess.run(command, env=environment, cwd=ROOT, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=480)
            except subprocess.TimeoutExpired as error:
                message = error.stdout or b""
                if isinstance(message, bytes):
                    message = message.decode("utf-8", errors="replace")
                (output / "runtime.log").write_text(message + "\nTIMEOUT\n", encoding="utf-8")
                return 1
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = result.returncode == 0 and helper.FAILURE.search(result.stdout) is None
            marker = "CHILDHOOD_UI_REVIEW []" if args.runtime else "CHILDHOOD_RENDER_REVIEW []"
            passed = passed and marker in result.stdout
            receipt = {"passed": passed, "exit_code": result.returncode, "expected_marker": marker,
                       "output": str(output), "android_device_test": False}
            (output / "run-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(receipt))
            return 0 if passed else 1
        finally:
            server.terminate()
            server.wait(timeout=10)
            log.close()


if __name__ == "__main__":
    raise SystemExit(main())
