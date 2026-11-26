"""Run city and campaign regression scripts on the contents of the signed QA APK.

Godot desktop executes the Android package's scripts and imported resources.
This is a package-content test. Android lifecycle, GPU and driver compatibility
require a separate device run.
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
import zipfile

from build_android_prototype import QA_PACKAGE, file_sha256

ROOT = Path(__file__).resolve().parents[1]
CHECKS = {
    "city_market_bridge_test": "CITY_MARKET_BRIDGE_PASS",
    "city_campaign_trade_test": "CITY_CAMPAIGN_TRADE_PASS",
    "campaign_market_visit_test": "CAMPAIGN_MARKET_VISIT_PASS",
    "city_life_test": "CITY_LIFE_PASS",
    "political_reference_playthrough": "POLITICAL_REFERENCE_PLAYTHROUGH",
    "npc_behavior_ui_test": "NPC_BEHAVIOR_UI_PASS",
    "quarter_street_walk_test": "QUARTER_STREET_WALK_PASS",
}
FIXTURE = "tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
JSON_PATHS = (
    "assets/city/street_graph.json",
    "assets/city/activity_anchors/forum.json",
    "assets/city/activity_anchors/market_street.json",
    "assets/city/activity_anchors/residential.json",
    "assets/city/activity_anchors/roman_quarter.json",
    "assets/city/barks/city_barks.json",
    "assets/city/economy/city_economy.json",
    "assets/world/political_offices.json",
)


def committed(commit, relative):
    return subprocess.check_output(["git", "show", f"{commit}:prototype/{relative}"], cwd=ROOT)


def run(apk, output, engine):
    manifest = json.loads(apk.with_suffix(".build.json").read_text(encoding="utf-8"))
    digest = file_sha256(apk)
    if (not manifest["signature_verified"] or manifest["apk_sha256"] != digest
            or manifest["package"] != QA_PACKAGE):
        raise ValueError("APK stimmt mit dem signierten QA-Baubericht nicht überein.")
    commit = manifest["source_commit"]
    if not re.fullmatch(r"[a-f0-9]{40}", commit):
        raise ValueError("Der Baubericht enthält keinen vollständigen Quellcommit.")
    output.mkdir(parents=True, exist_ok=True)
    report = {"source_commit": commit, "apk_sha256": digest, "platform": "Desktop, headless",
              "engine": subprocess.check_output([engine, "--version"], text=True).strip(),
              "checks": {}, "packaged_data_sha256": {}}
    with tempfile.TemporaryDirectory(prefix="imperathen-city-qa-payload-") as name:
        folder = Path(name)
        pack = folder / "runtime.zip"
        fixture = committed(commit, FIXTURE)
        with zipfile.ZipFile(apk) as archive, zipfile.ZipFile(pack, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as bundle:
            for path in JSON_PATHS:
                data = archive.read("assets/" + path)
                if data != committed(commit, path):
                    raise ValueError(f"Abweichende Daten im Paket: {path}")
                report["packaged_data_sha256"][path] = hashlib.sha256(data).hexdigest()
            names = [n for n in archive.namelist() if n.startswith("assets/") and not n.endswith("/")]
            if "assets/project.binary" not in names or any(n.startswith("assets/tests/") for n in names):
                raise ValueError("Projekt fehlt oder Testdaten wurden mitexportiert.")
            report["unchanged_runtime_entries"] = len(names)
            for entry in names:
                with archive.open(entry) as src, bundle.open(entry.removeprefix("assets/"), "w") as dst:
                    shutil.copyfileobj(src, dst)
            bundle.writestr(FIXTURE, fixture)
        report["external_fixture_sha256"] = hashlib.sha256(fixture).hexdigest()
        for script, marker in CHECKS.items():
            probe = folder / (script + ".gd")
            probe.write_bytes(committed(commit, "tests/" + probe.name))
            environment = os.environ.copy()
            environment["IMPERATHEN_ISOLATED_TEST"] = "1"
            for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                environment[variable] = str(folder / script / variable)
            result = subprocess.run([engine, "--headless", "--main-pack", str(pack), "--fixed-fps", "60",
                                     "--script", str(probe)], cwd=folder, env=environment, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
            (output / (script + ".log")).write_text(result.stdout, encoding="utf-8")
            passed = (result.returncode == 0 and re.search(rf"^{marker}\b", result.stdout, re.M) is not None
                      and re.search(r"SCRIPT ERROR:|^ERROR:|^USER ERROR:", result.stdout, re.M) is None)
            report["checks"][script] = {"passed": passed, "exit_code": result.returncode,
                                       "external_script_sha256": hashlib.sha256(probe.read_bytes()).hexdigest()}
            print(f"{script}: {'PASS' if passed else 'FAIL'}", flush=True)
    report["passed"] = all(check["passed"] for check in report["checks"].values())
    (output / "payload.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report["passed"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    raise SystemExit(0 if run(args.apk, args.output, args.godot) else 1)
