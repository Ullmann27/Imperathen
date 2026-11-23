"""Synthetic APK regressions for the complete authored childhood feature.

The ZIP fixtures are not executable packages and do not claim Android runtime QA.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("childhood_payload_validator", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ChildhoodPayloadGateTest(unittest.TestCase):
    def inspect(self, *, source_resources=(), archive_resources=(), dangling=None, empty=None):
        with tempfile.TemporaryDirectory(prefix="imperathen-childhood-payload-") as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            for resource in source_resources:
                marker = source / resource
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.write_text("synthetic source", encoding="utf-8")
            package = root / "synthetic.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                for index, resource in enumerate(archive_resources):
                    target = f".godot/exported/childhood-{index}.gdc"
                    archive.writestr("assets/" + resource + ".remap", f'[remap]\npath="res://{target}"\n')
                    if resource != dangling:
                        payload = b"" if resource == empty else ("compiled synthetic fixture: " + resource).encode()
                        archive.writestr("assets/" + target, payload)
                        expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks":[]}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            return {item["id"]:item for item in report["checks"]}, expected

    def test_current_childhood_source_rejects_a_complete_previous_village_apk(self):
        checks, _ = self.inspect(source_resources=[VALIDATOR.CHILDHOOD_SCRIPT],
                                 archive_resources=VALIDATOR.VILLAGE_LIFE_RESOURCES)
        self.assertEqual(checks["village_life_content"]["status"], "pass")
        self.assertEqual(checks["childhood_content"]["status"], "fail")
        self.assertEqual(checks["godot_project_content"]["status"], "fail")
        self.assertEqual(set(checks["childhood_content"]["evidence"]["missing_resources"]),
                         set(VALIDATOR.CHILDHOOD_RESOURCES))

    def test_all_five_actual_export_payloads_are_resolved_and_hashed(self):
        resources = VALIDATOR.CHILDHOOD_RESOURCES
        checks, expected = self.inspect(source_resources=resources, archive_resources=resources)
        self.assertEqual(checks["childhood_content"]["status"], "pass")
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        payloads = checks["childhood_content"]["evidence"]["resources"]
        self.assertEqual(len(payloads), 5)
        for item in payloads:
            self.assertEqual(item["sha256"], expected[item["source"]])
            self.assertGreater(item["size_bytes"], 0)
            self.assertEqual(item["mode"], "remapped")
            self.assertEqual(len(item["remap_sha256"]), 64)

    def test_dangling_trade_or_raider_payload_fails_without_source_checkout(self):
        for resource in ("scripts/domain/village_trade.gd", "scripts/world/childhood_raiders.gd"):
            checks, _ = self.inspect(archive_resources=VALIDATOR.CHILDHOOD_RESOURCES, dangling=resource)
            with self.subTest(resource=resource):
                self.assertEqual(checks["childhood_content"]["status"], "fail")
                self.assertEqual(checks["childhood_content"]["evidence"]["missing_resources"], [resource])

    def test_empty_neighborhood_payload_is_not_a_pass(self):
        resource = "scripts/world/village/childhood_neighborhood.gd"
        checks, _ = self.inspect(archive_resources=VALIDATOR.CHILDHOOD_RESOURCES, empty=resource)
        self.assertEqual(checks["childhood_content"]["status"], "fail")
        self.assertEqual(checks["childhood_content"]["evidence"]["missing_resources"], [resource])

    def test_intro_alone_still_requires_story_economy_and_world(self):
        checks, _ = self.inspect(archive_resources=["scripts/story/childhood_opening.gd"])
        self.assertEqual(checks["childhood_content"]["status"], "fail")
        self.assertIn(VALIDATOR.CHILDHOOD_SCRIPT, checks["childhood_content"]["evidence"]["missing_resources"])
        self.assertIn("scripts/domain/village_trade.gd", checks["childhood_content"]["evidence"]["missing_resources"])

    def test_only_broken_or_empty_declaration_cannot_disguise_a_new_apk_as_legacy(self):
        for failure in ("dangling", "empty"):
            resource = VALIDATOR.CHILDHOOD_SCRIPT
            checks, _ = self.inspect(archive_resources=[resource], **{failure:resource})
            with self.subTest(failure=failure):
                self.assertEqual(checks["childhood_content"]["status"], "fail")
                self.assertEqual(set(checks["childhood_content"]["evidence"]["missing_resources"]),
                                 set(VALIDATOR.CHILDHOOD_RESOURCES))

    def test_historical_source_and_apk_keep_the_previous_village_gate(self):
        checks, _ = self.inspect(source_resources=[VALIDATOR.VILLAGE_LIFE_SCRIPT],
                                 archive_resources=VALIDATOR.VILLAGE_LIFE_RESOURCES)
        self.assertNotIn("childhood_content", checks)
        self.assertEqual(checks["village_life_content"]["status"], "pass")
        self.assertEqual(checks["godot_project_content"]["status"], "pass")


if __name__ == "__main__":
    unittest.main()
