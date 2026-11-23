"""Synthetic release-gate fixtures; no executable APK or publication is implied."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("childhood_publish", ROOT / "tools/publish_village_download.py")
PUBLISH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUBLISH)
SOURCE = "a" * 40


class ChildhoodPublicationGateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="childhood-publication-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self, childhood=True):
        android, runtime = self.root / "android", self.root / "runtime"
        android.mkdir(); runtime.mkdir()
        prefix = "IMPERATHEN-" + SOURCE[:8]
        groups = {"hero_character_content": PUBLISH.HERO_RESOURCES,
                  "living_frontier_content": PUBLISH.FRONTIER_RESOURCES,
                  "cinematic_opening_content": PUBLISH.OPENING_RESOURCES,
                  "village_life_content": PUBLISH.VILLAGE_LIFE_RESOURCES}
        if childhood:
            groups["childhood_content"] = PUBLISH.CHILDHOOD_RESOURCES
        resources = {}
        apk = android / (prefix + "-arm64.apk")
        with zipfile.ZipFile(apk, "w") as archive:
            for name in sorted({name for names in groups.values() for name in names}):
                data = ("synthetic resource: " + name).encode()
                entry = "assets/" + name
                archive.writestr(entry, data)
                resources[name] = {"source": name, "entry": entry, "size_bytes": len(data),
                                   "sha256": hashlib.sha256(data).hexdigest()}
        checksum = PUBLISH.digest(apk)
        build = {"source_commit": SOURCE, "apk": apk.name, "apk_sha256": checksum,
                 "apk_size_bytes": apk.stat().st_size, "abi": "arm64-v8a", "package": PUBLISH.PACKAGE,
                 "status": "verified_debug_apk", "godot_version": "synthetic", "requested_renderer": "gl_compatibility"}
        self.write(android / (prefix + "-arm64.build.json"), build)
        (android / "source-commit.txt").write_text(SOURCE)
        (android / (apk.name + ".sha256")).write_text(checksum + "  " + apk.name)
        checks = [{"id": name, "status": "pass", "required": True}
                  for name in ("apk_file", "zip_structure", "zip_crc", "godot_native_library",
                               "godot_project_content", "manifest_metadata", "package_identity",
                               "signature_verification", "apk_unchanged")]
        for name, members in groups.items():
            checks.append({"id": name, "status": "pass", "required": True,
                           "evidence": {"required_by_source": True, "missing_resources": [],
                                        "resources": [resources[member] for member in members]}})
        validation = {"passed": True, "overall_status": "pass", "apk": {"sha256": checksum, "size_bytes": apk.stat().st_size},
                      "manifest": {"package": PUBLISH.PACKAGE, "version_code": "4" if childhood else "3",
                                   "version_name": "0.4.0-childhood" if childhood else "0.3.0-village"},
                      "expected_abi": "arm64-v8a", "available_abis": ["arm64-v8a"], "checks": checks}
        validation_path = android / (prefix + "-arm64.validation.json")
        self.write(validation_path, validation)
        engine_names = {"frontier_story", "frontier_population", "frontier_people", "frontier_integration",
                        "village_economy", "village_life", "village_model", "village_experience", "opening_flow"}
        if childhood:
            engine_names |= PUBLISH.CHILDHOOD_ENGINE_CHECKS
        engine_path = android / "engine-checks/validation_report.json"
        self.write(engine_path, {"passed": True, "checks": [{"check": name, "passed": True} for name in sorted(engine_names)]})
        emulator = android / (prefix + "-emulator.apk")
        emulator.write_bytes(b"synthetic emulator archive")
        emulator_hash = PUBLISH.digest(emulator)
        self.write(android / (prefix + "-emulator.build.json"),
                   {"source_commit": SOURCE, "apk_sha256": emulator_hash, "abi": "x86_64", "status": "verified_debug_apk"})
        runtime_names = {"opening_before_gameplay", "objective_hands_over_control"}
        runtime_names |= (PUBLISH.CHILDHOOD_RUNTIME_CHECKS if childhood else
                          {"village_actual_population", "village_touch_meets_decimus", "village_touch_work_permission",
                           "village_actual_worker_assignment", "village_decisions_survive_restart"})
        runtime_path = runtime / "runtime-report.json"
        self.write(runtime_path, {"status": "passed", "source_commit": SOURCE, "test_harness_commit": SOURCE,
                                 "errors": [], "checks": [{"name": name, "passed": True} for name in sorted(runtime_names)],
                                 "arm64_package": {"sha256": checksum, "name": apk.name},
                                 "apk_file": emulator.name, "apk_sha256": emulator_hash})
        return android, runtime, validation_path, engine_path, runtime_path

    @staticmethod
    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))

    def stage(self, fixture, branch=PUBLISH.CHILDHOOD_BRANCH):
        return PUBLISH.verify_and_stage(fixture[0], fixture[1], self.root / "public", SOURCE, "123", branch)

    def test_complete_childhood_evidence_stages_only_public_allowlist(self):
        fixture = self.fixture()
        (fixture[0] / "private.keystore").write_text("synthetic private fixture; must not be staged")
        proof = self.stage(fixture)
        self.assertEqual(proof["apk"], "IMPERATHEN-aaaaaaaa-arm64.apk")
        self.assertEqual(len(list((self.root / "public").iterdir())), 7)
        self.assertFalse((self.root / "public/private.keystore").exists())

    def test_native_touch_proof_is_required(self):
        fixture = self.fixture()
        report = json.loads(fixture[4].read_text())
        report["checks"] = [c for c in report["checks"] if c["name"] != "childhood_native_touch_moves_player"]
        self.write(fixture[4], report)
        with self.assertRaisesRegex(RuntimeError, "journey was not exercised"):
            self.stage(fixture)
        self.assertFalse((self.root / "public").exists())

    def test_both_night_paths_must_have_an_engine_check(self):
        fixture = self.fixture()
        report = json.loads(fixture[3].read_text())
        report["checks"] = [c for c in report["checks"] if c["check"] != "childhood_night_integration"]
        self.write(fixture[3], report)
        with self.assertRaisesRegex(RuntimeError, "Merged childhood"):
            self.stage(fixture)

    def test_exported_childhood_modules_are_mandatory(self):
        fixture = self.fixture()
        report = json.loads(fixture[2].read_text())
        report["checks"] = [c for c in report["checks"] if c["id"] != "childhood_content"]
        self.write(fixture[2], report)
        with self.assertRaisesRegex(RuntimeError, "required APK proof"):
            self.stage(fixture)

    def test_real_exported_resource_hash_must_match(self):
        fixture = self.fixture()
        report = json.loads(fixture[2].read_text())
        next(c for c in report["checks"] if c["id"] == "childhood_content")["evidence"]["resources"][0]["sha256"] = "0" * 64
        self.write(fixture[2], report)
        with self.assertRaisesRegex(RuntimeError, "Resource bytes differ"):
            self.stage(fixture)

    def test_old_version_cannot_be_published_as_childhood(self):
        with self.assertRaisesRegex(RuntimeError, "Package or ABI mismatch"):
            self.stage(self.fixture(childhood=False))

    def test_older_village_publication_contract_still_passes(self):
        self.assertTrue(self.stage(self.fixture(childhood=False), PUBLISH.BRANCH)["sha256"])

    def test_unapproved_branch_is_rejected_before_file_access(self):
        with self.assertRaisesRegex(RuntimeError, "Unapproved publication branch"):
            self.stage((self.root, self.root), "main")

    def test_runtime_from_another_source_is_rejected(self):
        fixture = self.fixture()
        report = json.loads(fixture[4].read_text())
        report["source_commit"] = "b" * 40
        self.write(fixture[4], report)
        with self.assertRaisesRegex(RuntimeError, "another source"):
            self.stage(fixture)

    def test_failed_build_predecessor_prevents_publication(self):
        run = {"head_sha": SOURCE, "head_branch": PUBLISH.CHILDHOOD_BRANCH,
               "path": ".github/workflows/android-prototype.yml", "id": 123, "run_number": 27,
               "repository": {"full_name": PUBLISH.REPO}, "event": "push"}
        with patch.object(PUBLISH, "api", side_effect=[run, {"jobs": [{"name": "build-and-check", "status": "completed", "conclusion": "failure"}]}]):
            with self.assertRaisesRegex(RuntimeError, "has not passed"):
                PUBLISH.verify_run(SOURCE, "123", "27", PUBLISH.CHILDHOOD_BRANCH)


if __name__ == "__main__":
    unittest.main()
