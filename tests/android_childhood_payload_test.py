"""Package regression: a successful older APK cannot certify the family chapter."""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("childhood_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ChildhoodPayloadGateTest(unittest.TestCase):
    def inspect(self, *, current_source=True, include=True, missing=None):
        with tempfile.TemporaryDirectory(prefix="imperathen-childhood-apk-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            if current_source:
                marker = source / "scripts/story/village_childhood.gd"
                marker.parent.mkdir(parents=True)
                marker.write_text("extends RefCounted\n", encoding="utf-8")
            package = root / "synthetic.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                if include:
                    for index, resource in enumerate(VALIDATOR.CHILDHOOD_RESOURCES):
                        exported = f".godot/exported/childhood-{index}.gdc"
                        archive.writestr("assets/" + resource + ".remap",
                                         f'[remap]\npath="res://{exported}"\n')
                        if resource != missing:
                            payload = ("exported fixture: " + resource).encode()
                            archive.writestr("assets/" + exported, payload)
                            expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            content = next(item for item in report["checks"] if item["id"] == "godot_project_content")
            feature = next(item for item in report["checks"] if item["id"] == "childhood_content")
            return feature, content, expected

    def test_old_village_apk_rejects_new_childhood_source(self):
        feature, content, _ = self.inspect(include=False)
        self.assertEqual(feature["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(set(feature["evidence"]["missing_resources"]), set(VALIDATOR.CHILDHOOD_RESOURCES))

    def test_all_exported_childhood_payloads_are_hashed(self):
        feature, content, expected = self.inspect()
        self.assertEqual(feature["status"], "pass")
        self.assertEqual(content["status"], "pass")
        self.assertEqual(len(feature["evidence"]["resources"]), 6)
        for entry in feature["evidence"]["resources"]:
            self.assertEqual(entry["sha256"], expected[entry["source"]])
            self.assertGreater(entry["size_bytes"], 0)

    def test_each_missing_module_rejects_the_combined_package(self):
        for missing in VALIDATOR.CHILDHOOD_RESOURCES:
            with self.subTest(resource=missing):
                feature, content, _ = self.inspect(missing=missing)
                self.assertEqual(feature["status"], "fail")
                self.assertEqual(content["status"], "fail")
                self.assertEqual(feature["evidence"]["missing_resources"], [missing])

    def test_partial_feature_fails_without_a_local_source_tree(self):
        missing = "scripts/world/village/settlement_dressing.gd"
        feature, content, _ = self.inspect(current_source=False, missing=missing)
        self.assertEqual(feature["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(feature["evidence"]["missing_resources"], [missing])


if __name__ == "__main__":
    unittest.main()
