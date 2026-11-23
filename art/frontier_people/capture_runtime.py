"""Capture the actual Godot cast using the existing authenticated Xorg helper."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("capture_hero", ROOT / "tools/characters/capture_hero.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
output = ROOT / "art/frontier_people/runtime_review"
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="frontier-cast-review-") as temporary:
    directory = Path(temporary)
    env = os.environ.copy()
    env["IMPERATHEN_ISOLATED_TEST"] = "1"
    for kind in ("DATA", "CONFIG", "CACHE"):
        location = directory / kind.lower()
        location.mkdir()
        env[f"XDG_{kind}_HOME"] = str(location)
    server, log = helper.start_display(directory, env)
    try:
        command = ["godot", "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                   "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                   "--resolution", "1000x1000", "--max-fps", "30", "--script",
                   "res://tests/frontier_people_review.gd", "--", str(output)]
        result = subprocess.run(command, env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        (output / "runtime.log").write_text(result.stdout)
        passed = result.returncode == 0 and helper.FAILURE.search(result.stdout) is None and "FRONTIER_GRAPHICS_REVIEW []" in result.stdout
        if passed:
            receipt = output / "runtime-review.json"
            report = json.loads(receipt.read_text())
            sources = {"prototype/" + item["asset"].removeprefix("res://") for item in report["captures"]}
            sources.update(("prototype/scripts/visuals/village_person.gd", "prototype/tests/frontier_people_review.gd"))
            report["source_sha256"] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in sorted(sources)}
            receipt.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed": passed, "output": str(output), "android_device_test": False}))
        if not passed:
            print(result.stdout[-5000:])
    finally:
        server.terminate()
        server.wait(timeout=5)
        log.close()
raise SystemExit(0 if passed else 1)
