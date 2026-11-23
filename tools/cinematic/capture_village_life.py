"""Render the actual village journey with isolated saves and a real viewport.

Uses the production Main/UI/world integration scenario. Fixture teleports and
explicit elapsed-time stepping accelerate the journey; no gameplay result is
invented. Software-rendered captures do not establish Android frame rates.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from capture_opening import FAILURE, ROOT, load_display_helper


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit("Godot executable is missing.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-village-render-") as temporary:
        directory = Path(temporary)
        environment = os.environ.copy()
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            environment[f"XDG_{kind}_HOME"] = str(location)
        server = display_log = None
        try:
            server, display_log = load_display_helper().start_display(directory, environment)
            command = [engine, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                       "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1280x720", "--max-fps", "30", "--fixed-fps", "60",
                       "--script", "res://tests/village_experience_test.gd", "--",
                       "--capture-dir=" + str(output)]
            log_path = output / "runtime.log"
            try:
                with log_path.open("w", encoding="utf-8") as runtime_log:
                    result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                            stdout=runtime_log, stderr=subprocess.STDOUT,
                                            timeout=600)
            except subprocess.TimeoutExpired:
                print(json.dumps({"passed": False, "reason": "render timeout", "output": str(output)}))
                return 1
            captured = log_path.read_text(encoding="utf-8")
            report_path = output / "experience-report.json"
            passed = result.returncode == 0 and FAILURE.search(captured) is None
            passed = passed and "VILLAGE_EXPERIENCE_PASS" in captured and report_path.is_file()
            if report_path.is_file():
                report = json.loads(report_path.read_text(encoding="utf-8"))
                report["source_sha256"] = {
                    str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in sorted((ROOT / "prototype").rglob("*.gd"))
                    if ".godot" not in path.parts
                }
                report["artifact_sha256"] = {
                    path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in sorted(output.glob("*.png"))
                }
                report["renderer"] = "Godot OpenGL Compatibility, private Xorg, llvmpipe software rendering"
                report["android_device_test"] = False
                report["passed"] = passed
                report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(json.dumps({"passed": passed, "exit_code": result.returncode, "output": str(output)}))
            if not passed:
                print(captured[-6000:])
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
