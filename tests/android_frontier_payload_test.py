"""Reject old or incomplete deliveries using synthetic APK-content fixtures.

These fixtures isolate the payload gate. They are not executable Android builds.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("frontier_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class FrontierPayloadGateTest(unittest.TestCase):
    def inspect(self, *, current_source=True, include=True, dangling=None):
        with tempfile.TemporaryDirectory(prefix="imperathen-frontier-apk-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            if current_source:
                marker = source / VALIDATOR.FRONTIER_SCRIPT
                marker.parent.mkdir(parents=True)
                marker.write_text("extends RefCounted\n", encoding="utf-8")
            package = root / "synthetic.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                if include:
                    for index, resource in enumerate(VALIDATOR.FRONTIER_RESOURCES):
                        imported = f".godot/imported/frontier-fixture-{index}.scn"
                        suffix = ".import" if resource.endswith(".glb") else ".remap"
                        archive.writestr("assets/" + resource + suffix,
                                         f'[remap]\npath="res://{imported}"\n')
                        if resource != dangling:
                            payload = ("exported fixture: " + resource).encode()
                            archive.writestr("assets/" + imported, payload)
                            expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            content = next(item for item in report["checks"] if item["id"] == "godot_project_content")
            frontier = next((item for item in report["checks"] if item["id"] == "living_frontier_content"), None)
            return frontier, content, expected

    def test_current_source_rejects_old_apk(self):
        frontier, content, _ = self.inspect(include=False)
        self.assertEqual(frontier["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(set(frontier["evidence"]["missing_resources"]), set(VALIDATOR.FRONTIER_RESOURCES))

    def test_actual_import_payloads_are_required_and_hashed(self):
        frontier, content, expected = self.inspect()
        self.assertEqual(frontier["status"], "pass")
        self.assertEqual(content["status"], "pass")
        for entry in frontier["evidence"]["resources"]:
            self.assertEqual(entry["sha256"], expected[entry["source"]])
            self.assertEqual(entry["mode"], "remapped")
            self.assertGreater(entry["size_bytes"], 0)

    def test_dangling_archer_lod_import_fails(self):
        missing = "assets/characters/frontier_archer_3.glb"
        frontier, content, _ = self.inspect(dangling=missing)
        self.assertEqual(frontier["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(frontier["evidence"]["missing_resources"], [missing])

    def test_embedded_chapter_requires_whole_feature_without_source_tree(self):
        frontier, _, _ = self.inspect(current_source=False, dangling=VALIDATOR.FRONTIER_SCRIPT)
        self.assertEqual(frontier["status"], "fail")

    def test_historical_source_has_no_new_gate(self):
        frontier, content, _ = self.inspect(current_source=False, include=False)
        self.assertIsNone(frontier)
        self.assertEqual(content["status"], "pass")


if __name__ == "__main__":
    unittest.main()
