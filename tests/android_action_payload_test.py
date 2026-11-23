"""Package regressions for combat scripts and the four native hand resources.

Synthetic ZIP fixtures exercise the payload gate, not Android execution.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("action_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ActionPayloadGateTest(unittest.TestCase):
    def inspect(self, *, current_source=True, include=True, missing=None):
        with tempfile.TemporaryDirectory(prefix="imperathen-action-apk-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            if current_source:
                marker = source / "scripts/domain/combat_actions.gd"
                marker.parent.mkdir(parents=True)
                marker.write_text("extends RefCounted\n", encoding="utf-8")
            package = root / "synthetic.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                if include:
                    for index, resource in enumerate(VALIDATOR.ACTION_COMBAT_RESOURCES):
                        exported = resource if resource.endswith(".res") else f".godot/exported/action-{index}.gdc"
                        if resource.endswith(".gd"):
                            archive.writestr("assets/" + resource + ".remap",
                                             f'[remap]\npath="res://{exported}"\n')
                        if resource != missing:
                            payload = ("exported fixture: " + resource).encode()
                            archive.writestr("assets/" + exported, payload)
                            expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            content = next(item for item in report["checks"] if item["id"] == "godot_project_content")
            action = next(item for item in report["checks"] if item["id"] == "action_combat_content")
            return action, content, expected

    def test_previous_apk_cannot_certify_new_combat_source(self):
        action, content, _ = self.inspect(include=False)
        self.assertEqual(action["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(set(action["evidence"]["missing_resources"]), set(VALIDATOR.ACTION_COMBAT_RESOURCES))

    def test_native_hands_and_remapped_scripts_are_all_hashed(self):
        action, content, expected = self.inspect()
        self.assertEqual(action["status"], "pass")
        self.assertEqual(content["status"], "pass")
        self.assertEqual(len(action["evidence"]["resources"]), 10)
        for entry in action["evidence"]["resources"]:
            self.assertEqual(entry["sha256"], expected[entry["source"]])
            self.assertGreater(entry["size_bytes"], 0)

    def test_each_missing_hand_lod_rejects_the_package(self):
        for lod in range(4):
            missing = f"assets/characters/hero_hand_grip_{lod}.res"
            with self.subTest(lod=lod):
                action, content, _ = self.inspect(missing=missing)
                self.assertEqual(action["status"], "fail")
                self.assertEqual(content["status"], "fail")
                self.assertEqual(action["evidence"]["missing_resources"], [missing])

    def test_partial_embedded_feature_cannot_pass_without_source_tree(self):
        missing = "scripts/world/player_action_world.gd"
        action, content, _ = self.inspect(current_source=False, missing=missing)
        self.assertEqual(action["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(action["evidence"]["missing_resources"], [missing])


if __name__ == "__main__":
    unittest.main()
