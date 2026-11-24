"""Reject APKs that leave the new story, NPC or Meshy data in the source tree.

Synthetic ZIPs isolate the content gate; these are not executable packages.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("living_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class LivingVillagePayloadTest(unittest.TestCase):
    def inspect(self, groups, omitted=()):
        with tempfile.TemporaryDirectory(prefix="imperathen-living-payload-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            package = root / "synthetic.apk"
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                for _, resources in groups:
                    marker = source / resources[0]
                    marker.parent.mkdir(parents=True, exist_ok=True)
                    marker.write_text("extends RefCounted\n", encoding="utf-8")
                    for resource in resources:
                        if resource not in omitted:
                            archive.writestr("assets/" + resource, "fixture: " + resource)
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            return {item["id"]: item for item in report["checks"]}

    def test_campaign_script_alone_cannot_pass_without_its_authored_json(self):
        checks = self.inspect([("campaign_bible_content", VALIDATOR.CAMPAIGN_BIBLE_RESOURCES)],
                              ["assets/story/campaign_arc.json"])
        self.assertEqual(checks["campaign_bible_content"]["status"], "fail")
        self.assertEqual(checks["godot_project_content"]["status"], "fail")

    def test_each_meshy_registry_file_is_required(self):
        for missing in VALIDATOR.MESHY_REGISTRY_RESOURCES:
            with self.subTest(missing=missing):
                checks = self.inspect([("meshy_registry_content", VALIDATOR.MESHY_REGISTRY_RESOURCES)], [missing])
                self.assertEqual(checks["meshy_registry_content"]["status"], "fail")
                self.assertEqual(checks["meshy_registry_content"]["evidence"]["missing_resources"], [missing])

    def test_old_package_rejects_missing_npc_logic(self):
        checks = self.inspect([("npc_behavior_content", VALIDATOR.NPC_BEHAVIOR_RESOURCES)],
                              VALIDATOR.NPC_BEHAVIOR_RESOURCES)
        self.assertEqual(checks["npc_behavior_content"]["status"], "fail")

    def test_each_rigged_character_lod_must_be_in_the_apk(self):
        for missing in VALIDATOR.MESHY_CHARACTER_RESOURCES[1:]:
            with self.subTest(missing=missing):
                checks = self.inspect([("meshy_character_content", VALIDATOR.MESHY_CHARACTER_RESOURCES)], [missing])
                self.assertEqual(checks["meshy_character_content"]["status"], "fail")
                self.assertEqual(checks["meshy_character_content"]["evidence"]["missing_resources"], [missing])

    def test_present_new_content_is_hashed_in_the_archive(self):
        groups = [("campaign_bible_content", VALIDATOR.CAMPAIGN_BIBLE_RESOURCES),
                  ("meshy_registry_content", VALIDATOR.MESHY_REGISTRY_RESOURCES),
                  ("npc_behavior_content", VALIDATOR.NPC_BEHAVIOR_RESOURCES),
                  ("meshy_character_content", VALIDATOR.MESHY_CHARACTER_RESOURCES),
                  ("meshy_equipment_content", VALIDATOR.MESHY_EQUIPMENT_RESOURCES)]
        checks = self.inspect(groups)
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        for name, resources in groups:
            self.assertEqual(checks[name]["status"], "pass")
            self.assertEqual(len(checks[name]["evidence"]["resources"]), len(resources))
            for entry in checks[name]["evidence"]["resources"]:
                self.assertEqual(len(entry["sha256"]), 64)
                self.assertGreater(entry["size_bytes"], 0)

    def test_each_equipment_model_and_attachment_script_must_be_in_the_apk(self):
        for missing in VALIDATOR.MESHY_EQUIPMENT_RESOURCES:
            with self.subTest(missing=missing):
                checks = self.inspect([("meshy_equipment_content", VALIDATOR.MESHY_EQUIPMENT_RESOURCES)], [missing])
                self.assertEqual(checks["meshy_equipment_content"]["status"], "fail")
                self.assertEqual(checks["meshy_equipment_content"]["evidence"]["missing_resources"], [missing])


if __name__ == "__main__":
    unittest.main()
