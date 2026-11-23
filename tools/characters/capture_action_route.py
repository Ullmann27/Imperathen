"""Run an actual continuous Main route in isolated storage; optionally capture it."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import tempfile

from capture_hero import FAILURE, ROOT, start_display


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--use-existing-display", action="store_true", help="Use an existing DISPLAY, such as xvfb-run in CI.")
    parser.add_argument("--quality", choices=("low", "balanced"), default="balanced")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = ["tools/characters/action_route_review.gd", "tools/characters/capture_action_route.py",
               "tools/characters/capture_hero.py", "prototype/project.godot", "prototype/main.tscn"]
    sources.extend(str(path.relative_to(ROOT)) for path in sorted((ROOT / "prototype/scripts").rglob("*.gd")))
    source_before = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
    commit_before = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()
    manifest = {"source_sha256": source_before, "source_commit": commit_before, "completed": False,
                "headless": args.headless, "quality": args.quality, "android_device_test": False}
    (output / "capture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    with tempfile.TemporaryDirectory(prefix="imperathen-route-", dir="/dev/shm") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = directory / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        server = log = None
        try:
            command = ["godot", "--audio-driver", "Dummy", "--path", str(ROOT / "prototype"),
                       "--resolution", "1280x720", "--max-fps", "60", "--script",
                       str(ROOT / "tools/characters/action_route_review.gd"), "--", str(output), "--quality=" + args.quality]
            if args.headless:
                command.insert(1, "--headless")
            else:
                if args.use_existing_display:
                    if not env.get("DISPLAY"):
                        raise RuntimeError("--use-existing-display requires DISPLAY.")
                else:
                    server, log = start_display(directory, env)
                # Keep every normal physics step and touch input. Render the
                # actual scene explicitly at stations; this is not an FPS run.
                command[1:1] = ["--display-driver", "x11", "--rendering-method", "gl_compatibility", "--disable-render-loop"]
            try:
                result = subprocess.run(command, env=env, cwd=ROOT, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
            except subprocess.TimeoutExpired as error:
                captured = error.stdout or ""
                if isinstance(captured, bytes):
                    captured = captured.decode("utf-8", errors="replace")
                (output / "runtime.log").write_text(captured + "\nTIMEOUT after 600 seconds\n", encoding="utf-8")
                print(json.dumps({"passed": False, "reason": "timeout", "output": str(output)}))
                return 1
            (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
            passed = result.returncode == 0 and not FAILURE.search(result.stdout) and "ACTION_ROUTE_REVIEW_PASS" in result.stdout
            manifest["engine_exit_code"] = result.returncode
            manifest["engine_signal"] = signal.Signals(-result.returncode).name if result.returncode < 0 else None
            manifest["child_peak_rss_kib"] = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
            receipt = output / "action-route-review.json"
            if receipt.exists():
                review = json.loads(receipt.read_text())
                source_after = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
                review["source_sha256"] = source_before
                review["source_unchanged_during_run"] = source_before == source_after
                review["source_changed_paths"] = [name for name in sources if source_before[name] != source_after[name]]
                review["source_commit"] = commit_before
                passed = passed and bool(review.get("completed")) and bool(review.get("passed")) and review["source_unchanged_during_run"]
                review["passed"] = bool(passed)
                review["engine_exit_code"] = result.returncode
                review["engine_signal"] = manifest["engine_signal"]
                receipt.write_text(json.dumps(review, indent=2) + "\n")
            else:
                passed = False
            manifest["completed"] = bool(passed)
            (output / "capture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            print(json.dumps({"passed": bool(passed), "engine_exit_code": result.returncode, "output": str(output), "android_device_test": False}))
            print(result.stdout[-6500:])
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
