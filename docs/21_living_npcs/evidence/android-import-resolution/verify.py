"""Replay CI72's loaded-actor observation against existing local Godot imports.

The in-memory ZIP is an asset-layout fixture, not an executable APK. No engine,
emulator, network access, scene import or application-state mutation is used.
"""
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import android_runtime_smoke as smoke


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


native = json.loads((OUT / "ci72-runtime.json").read_text())
observed = next(check["detail"] for check in native["checks"] if check["name"] == "meshy_severus_loaded")
snapshot = {"meshy_runtime": observed}
paths = [observed["severus"]["model_path"], observed["severus"]["equipment"][0]["model_path"]]
inputs = {}
for resource in paths:
    source = resource.removeprefix("res://")
    remap = source + ".import"
    contents = (ROOT / "prototype" / remap).read_bytes()
    target = re.search(r'^path="res://([^"\r\n]+)"', contents.decode(), re.MULTILINE).group(1)
    inputs["assets/" + remap] = contents
    inputs["assets/" + target] = (ROOT / "prototype" / target).read_bytes()

fixture = io.BytesIO()
with zipfile.ZipFile(fixture, "w") as archive:
    for path, contents in inputs.items():
        archive.writestr(path, contents)
with zipfile.ZipFile(fixture) as archive:
    passed, evidence = smoke.meshy_runtime_package_check(snapshot, archive)
    names = set(archive.namelist())
    old_gate = all(path in names or path + ".remap" in names for path in evidence["packaged_models"])

commands = [[sys.executable, "-m", "unittest", "tests.android_runtime_smoke_test"],
            [sys.executable, "tools/android_runtime_smoke.py", "--help"]]
checks = []
for label, command in zip(("unit-tests", "cli-import"), commands):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    (OUT / (label + ".log")).write_text(output)
    check = {"name": label, "command": command, "exit_code": result.returncode,
             "passed": result.returncode == 0, "log": label + ".log"}
    if label == "unit-tests":
        match = re.search(r"Ran (\d+) tests", output)
        check["test_count"] = int(match.group(1)) if match else None
    checks.append(check)

report = {"passed": passed and not old_gate and all(check["passed"] for check in checks),
          "scope": "CI72 observation replay against an in-memory ZIP of existing local Godot imports; not a new Android runtime pass.",
          "ci72": {"run_id": 45344763960, "job_id": 138276543995, "runtime_artifact_id": 14898111555,
                   "source_commit": native["source_commit"], "apk_sha256": native["apk_sha256"],
                   "runtime_report_sha256": digest(OUT / "ci72-runtime.json"),
                   "original_status": native["status"], "first_failed_check": "meshy_severus_loaded"},
          "old_literal_path_gate_passed": old_gate, "resolved_payload_gate_passed": passed,
          "local_import_evidence": evidence, "checks": checks,
          "checked_source_sha256": {name: digest(ROOT / name) for name in (
              "tools/android_runtime_smoke.py", "tools/validate_android_apk.py", "tests/android_runtime_smoke_test.py")}}
(OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
raise SystemExit(0 if report["passed"] else 1)
