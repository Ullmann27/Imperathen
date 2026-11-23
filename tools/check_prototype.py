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
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
        checks = [
            ("import", ["--import"], None),
            ("domain", ["--script", "res://tests/domain_test.gd"], "DOMAIN_TEST_PASS"),
            ("village_economy", ["--script", "res://tests/village_economy_test.gd"], "VILLAGE_ECONOMY_PASS"),
            ("village_life", ["--script", "res://tests/village_life_test.gd"], "VILLAGE_LIFE_PASS"),
            ("village_model", ["--script", "res://tests/village_model_test.gd"], "VILLAGE_MODEL_PASS"),
            ("childhood_story", ["--script", "res://tests/childhood_story_test.gd"], "0 failures"),
            ("childhood_merge_migration", ["--script", "res://tests/childhood_merge_migration_test.gd"], "CHILDHOOD_MERGE_MIGRATION_PASS"),
            ("village_trade", ["--script", "res://tests/village_trade_test.gd"], '"failures":[]'),
            ("village_trade_model", ["--script", "res://tests/village_trade_model_test.gd"], '"failures":[]'),
            ("childhood_raiders", ["--fixed-fps", "60", "--script", "res://tests/childhood_raiders_test.gd"], '"failures":[]'),
            ("childhood_neighborhood", ["--fixed-fps", "60", "--script", "res://tests/childhood_neighborhood_test.gd"], "failures=0"),
            ("childhood_resident_identity", ["--fixed-fps", "60", "--script", "res://tests/childhood_resident_identity_test.gd"], "failures=0"),
            ("childhood_escort_physics", ["--fixed-fps", "60", "--script", "res://tests/childhood_escort_physics_test.gd"], "failures=0"),
            ("childhood_equipment_visual", ["--fixed-fps", "60", "--script", "res://tests/childhood_equipment_visual_test.gd"], "failures=0"),
            ("childhood_experience", ["--fixed-fps", "60", "--script", "res://tests/childhood_experience_test.gd"], "CHILDHOOD_EXPERIENCE_PASS"),
            ("childhood_night_integration", ["--fixed-fps", "60", "--script", "res://tests/childhood_night_integration_test.gd"], "CHILDHOOD_NIGHT_INTEGRATION_PASS"),
            ("village_childhood", ["--script", "res://tests/village_childhood_test.gd"], "VILLAGE_CHILDHOOD_PASS"),
            ("unarmed_combat", ["--script", "res://tests/unarmed_combat_test.gd"], "UNARMED_COMBAT_PASS"),
            ("childhood_integration", ["--fixed-fps", "60", "--script", "res://tests/childhood_integration_test.gd"], "CHILDHOOD_INTEGRATION_PASS"),
            ("world_stream_plan", ["--script", "res://tests/world_stream_plan_test.gd"], "failures=0"),
            ("regional_terrain", ["--fixed-fps", "60", "--script", "res://tests/regional_terrain_test.gd"], "failures=0"),
            ("frontier_story", ["--script", "res://tests/frontier_story_test.gd"], "FRONTIER_STORY_PASS"),
            ("frontier_people", ["--fixed-fps", "60", "--script", "res://tests/frontier_people_test.gd"], "FRONTIER_PEOPLE_PASS"),
            ("frontier_population", ["--fixed-fps", "60", "--script", "res://tests/frontier_population_test.gd"], "FRONTIER_POPULATION_OK"),
            ("settlement_geometry", ["--fixed-fps", "60", "--script", "res://tests/settlement_geometry_test.gd"], "SETTLEMENT_GEOMETRY_PASS"),
            ("village_collision", ["--fixed-fps", "60", "--script", "res://tests/village_collision_test.gd"], "VILLAGE_COLLISION_PASS"),
            ("frontier_integration", ["--fixed-fps", "60", "--script", "res://tests/frontier_integration_test.gd"], "FRONTIER_INTEGRATION_PASS"),
            ("village_experience", ["--fixed-fps", "60", "--script", "res://tests/village_experience_test.gd"], "VILLAGE_EXPERIENCE_PASS"),
            ("village_panels", ["--fixed-fps", "60", "--script", "res://tests/village_panel_test.gd"], "VILLAGE_PANEL_PASS"),
            ("village_nameplates", ["--fixed-fps", "60", "--script", "res://tests/village_nameplates_test.gd"], "VILLAGE_NAMEPLATES_PASS"),
            ("opening_story", ["--script", "res://tests/opening_story_test.gd"], "OPENING_STORY_PASS"),
            ("opening_props", ["--script", "res://tests/opening_props_test.gd"], "failures=0"),
            ("opening_director", ["--script", "res://tests/opening_director_test.gd"], "checks []"),
            ("opening_overlay", ["--fixed-fps", "60", "--script", "res://tests/opening_overlay_test.gd"], "failures=0"),
            ("opening_flow", ["--fixed-fps", "60", "--script", "res://tests/opening_flow_test.gd"], "OPENING_FLOW_PASS"),
            ("ui", ["--fixed-fps", "60", "--script", "res://scripts/ui/ui_smoke.gd"], "UI_SMOKE_PASS"),
            ("world", ["--fixed-fps", "60", "--script", "res://scripts/world/world_smoke.gd"], "WORLD_SMOKE_PASS"),
            ("integration", ["--fixed-fps", "60", "--script", "res://tests/integration_test.gd"], "INTEGRATION_PASS"),
            ("battle_rules", ["--script", "res://tests/battle_rules_test.gd"], "failures=0"),
            ("soldier_visuals", ["--script", "res://tests/soldier_visual_test.gd"], "0 failed"),
            ("soldier_gait", ["--fixed-fps", "60", "--script", "res://tests/soldier_gait_test.gd"], "failures=0"),
            ("village_people", ["--fixed-fps", "60", "--script", "res://tests/village_person_test.gd"], "checks, 0 failed"),
            ("natural_motion", ["--fixed-fps", "60", "--script", "res://tests/natural_motion_test.gd"], "checks, 0 failed"),
            ("village_static_art", ["--script", "res://tests/village_static_art_test.gd"], "checks, 0 failed"),
            ("hero_faces", ["--fixed-fps", "60", "--script", "res://tests/hero_face_test.gd"], "checks, 0 failed"),
            ("village_scenery", ["--script", str(ROOT / "art/village/verify.gd")], "VILLAGE_SCENERY errors []"),
            ("atrium", ["--script", str(ROOT / "art/architecture/verify_atrium.gd")], "ATR_VISUAL errors []"),
            ("seasons", ["--script", "res://tests/season_campaign_test.gd"], "failures=0"),
            ("figure_gallery", ["--fixed-fps", "60", "--script", "res://tests/figure_gallery_test.gd"], "failures=0 real_textures=true"),
            ("landscape", ["--script", str(ROOT / "art/landscape/verify.gd")], None),
            ("main_scene", ["--fixed-fps", "60", "--quit-after", "420"], "IMPERATHEN_READY"),
        ]
        for name, arguments, marker in checks:
            # Each executable scenario starts with its own account state. A
            # completed opening test must not become another test's Continue.
            for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                location = Path(temporary) / name / variable.lower()
                location.mkdir(parents=True)
                environment[variable] = str(location)
            record = run_check(engine, name, arguments, marker, environment, report)
            records.append(record)
            if not record["passed"]:
                break
    source_hashes = {}
    for path in sorted(PROJECT.rglob("*")):
        if path.is_file() and ".godot" not in path.parts and path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".godot", ".glb", ".wav", ".json", ".webp", ".jpg"}:
            source_hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    result = {"engine": version, "passed": len(records) == len(checks) and all(item["passed"] for item in records),
              "renderer": "headless/dummy; no graphical FPS or screenshot claim",
              "save_isolation": "Separate disposable XDG data/config/cache directories for every check",
              "checks": records, "source_sha256": source_hashes}
    (report / "validation_report.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
