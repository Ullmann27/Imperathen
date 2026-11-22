"""Run actual Godot prototype checks with disposable settings and save directories.

No packages or network services are required. The runner validates engine exits,
script errors, and success markers; Godot can log script errors with a zero exit.
Usage: python tools/check_prototype.py --godot godot --report docs/10_development/evidence
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "prototype"
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)


def run_check(engine, name, arguments, marker, environment, report):
    started = time.monotonic()
    try:
        result = subprocess.run([engine, "--headless", "--path", str(PROJECT), *arguments],
                                cwd=ROOT, env=environment, text=True, encoding="utf-8",
                                errors="replace", capture_output=True, timeout=120)
        combined = result.stdout + result.stderr
        success = result.returncode == 0 and FAILURE.search(combined) is None and (marker is None or marker in combined)
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        combined = f"TIMEOUT after 120 seconds: {exc}"
        success = False
        code = None
    report.mkdir(parents=True, exist_ok=True)
    (report / f"{name}.log").write_text(combined, encoding="utf-8")
    record = {"check": name, "passed": success, "exit_code": code,
              "elapsed_seconds": round(time.monotonic() - started, 3),
              "expected_marker": marker, "log": f"{name}.log",
              "warnings": [line for line in combined.splitlines() if "WARNING:" in line]}
    print(f"{'PASS' if success else 'FAIL'} {name}: exit={code}", flush=True)
    if not success:
        print(combined[-6000:], flush=True)
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--report", type=Path, default=ROOT / "docs/10_development/evidence")
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit(f"Godot not found: {args.godot}")
    report = args.report.resolve()
    version = subprocess.run([engine, "--version"], text=True, capture_output=True, check=True).stdout.strip()
    records = []
    with tempfile.TemporaryDirectory(prefix="imperathen-check-") as temporary:
        environment = os.environ.copy()
        for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            location = Path(temporary) / variable.lower()
            location.mkdir()
            environment[variable] = str(location)
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
        checks = [
            ("import", ["--import"], None),
            ("domain", ["--script", "res://tests/domain_test.gd"], "DOMAIN_TEST_PASS"),
            ("ui", ["--fixed-fps", "60", "--script", "res://scripts/ui/ui_smoke.gd"], "UI_SMOKE_PASS"),
            ("world", ["--fixed-fps", "60", "--script", "res://scripts/world/world_smoke.gd"], "WORLD_SMOKE_PASS"),
            ("integration", ["--fixed-fps", "60", "--script", "res://tests/integration_test.gd"], "INTEGRATION_PASS"),
            ("battle_rules", ["--script", "res://tests/battle_rules_test.gd"], "failures=0"),
            ("soldier_visuals", ["--script", "res://tests/soldier_visual_test.gd"], "0 failed"),
            ("soldier_gait", ["--fixed-fps", "60", "--script", "res://tests/soldier_gait_test.gd"], "failures=0"),
            ("atrium", ["--script", str(ROOT / "art/architecture/verify_atrium.gd")], "ATR_VISUAL errors []"),
            ("seasons", ["--script", "res://tests/season_campaign_test.gd"], "failures=0"),
            ("figure_gallery", ["--fixed-fps", "60", "--script", "res://tests/figure_gallery_test.gd"], "failures=0 real_textures=true"),
            ("landscape", ["--script", str(ROOT / "art/landscape/verify.gd")], None),
            ("main_scene", ["--fixed-fps", "60", "--quit-after", "420"], "IMPERATHEN_READY"),
        ]
        for name, arguments, marker in checks:
            record = run_check(engine, name, arguments, marker, environment, report)
            records.append(record)
            if not record["passed"]:
                break
    source_hashes = {}
    for path in sorted(PROJECT.rglob("*")):
        if path.is_file() and ".godot" not in path.parts and path.suffix in {".gd", ".tscn", ".godot", ".glb", ".wav", ".json", ".webp", ".jpg"}:
            source_hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    result = {"engine": version, "passed": len(records) == len(checks) and all(item["passed"] for item in records),
              "renderer": "headless/dummy; no graphical FPS or screenshot claim",
              "save_isolation": "Disposable XDG data/config/cache directories",
              "checks": records, "source_sha256": source_hashes}
    (report / "validation_report.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
