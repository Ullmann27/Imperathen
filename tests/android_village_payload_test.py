"""Reject partial or stale village exports using explicitly synthetic ZIPs."""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("village_apk_validator", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class VillagePayloadGateTest(unittest.TestCase):
    def inspect(self, *, source_resources=(), archive_resources=(), dangling=None):
        with tempfile.TemporaryDirectory(prefix="imperathen-village-payload-") as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            for resource in source_resources:
                marker = source / resource
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.write_text("source fixture", encoding="utf-8")
            package = root / "synthetic.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                for index, resource in enumerate(archive_resources):
                    target = f".godot/exported/village-{index}.gdc"
                    archive.writestr("assets/" + resource + ".remap", f'[remap]\npath="res://{target}"\n')
                    if resource != dangling:
                        payload = ("compiled fixture: " + resource).encode()
                        archive.writestr("assets/" + target, payload)
                        expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            return {entry["id"]: entry for entry in report["checks"]}, expected

    def test_current_sources_reject_an_old_apk_without_village_life(self):
        checks, _ = self.inspect(source_resources=[VALIDATOR.VILLAGE_LIFE_SCRIPT])
        self.assertEqual(checks["village_life_content"]["status"], "fail")
        self.assertEqual(checks["godot_project_content"]["status"], "fail")
        self.assertEqual(set(checks["village_life_content"]["evidence"]["missing_resources"]),
                         set(VALIDATOR.VILLAGE_LIFE_RESOURCES))

    def test_all_exported_scripts_are_resolved_and_hashed(self):
        resources = VALIDATOR.OPENING_RESOURCES + VALIDATOR.VILLAGE_LIFE_RESOURCES
        checks, expected = self.inspect(source_resources=resources, archive_resources=resources)
        for name in ("cinematic_opening_content", "village_life_content"):
            self.assertEqual(checks[name]["status"], "pass")
            for resource in checks[name]["evidence"]["resources"]:
                self.assertEqual(resource["sha256"], expected[resource["source"]])
                self.assertEqual(resource["mode"], "remapped")
                self.assertEqual(len(resource["remap_sha256"]), 64)

    def test_dangling_economy_script_prevents_a_false_pass(self):
        missing = "scripts/domain/village_economy.gd"
        checks, _ = self.inspect(archive_resources=VALIDATOR.VILLAGE_LIFE_RESOURCES, dangling=missing)
        self.assertEqual(checks["village_life_content"]["status"], "fail")
        self.assertEqual(checks["village_life_content"]["evidence"]["missing_resources"], [missing])

    def test_packaged_ui_alone_requires_the_actual_village_rules(self):
        checks, _ = self.inspect(archive_resources=["scripts/ui/village_life_panel.gd"])
        self.assertEqual(checks["village_life_content"]["status"], "fail")
        self.assertIn(VALIDATOR.VILLAGE_LIFE_SCRIPT, checks["village_life_content"]["evidence"]["missing_resources"])

    def test_opening_requires_checkpoint_and_overlay(self):
        checks, _ = self.inspect(archive_resources=[VALIDATOR.OPENING_SCRIPT])
        self.assertEqual(checks["cinematic_opening_content"]["status"], "fail")
        self.assertIn("scripts/cinematic/opening_checkpoint.gd", checks["cinematic_opening_content"]["evidence"]["missing_resources"])

    def test_historical_sources_do_not_invent_new_requirements(self):
        checks, _ = self.inspect()
        self.assertNotIn("village_life_content", checks)
        self.assertNotIn("cinematic_opening_content", checks)
        self.assertEqual(checks["godot_project_content"]["status"], "pass")


if __name__ == "__main__":
    unittest.main()
