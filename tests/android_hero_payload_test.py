"""Exercise the character-content gate using deliberately synthetic ZIP fixtures.

These files are not executable APKs and cannot pass the APK validator's other
checks. The tests isolate missing export remaps and exported-payload evidence.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("android_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class HeroPayloadGateTest(unittest.TestCase):
    def inspect(self, *, source_requires=True, include_face=True, missing_level=None,
                dangling_level=None, include_models=True):
        with tempfile.TemporaryDirectory(prefix="imperathen-hero-apk-check-") as temporary:
            folder = Path(temporary)
            source = folder / "source"
            source.mkdir()
            if source_requires:
                face = source / VALIDATOR.HERO_FACE_SCRIPT
                face.parent.mkdir(parents=True)
                face.write_text("extends RefCounted\n", encoding="utf-8")
            package = folder / "synthetic-content-fixture.apk"
            expected = {}
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("assets/project.binary", b"ECFG")
                for resource in VALIDATOR.EXPECTED_RESOURCES:
                    archive.writestr("assets/" + resource, "fixture: " + resource)
                if include_face:
                    # Exported scripts may use a remap into compiled GDScript.
                    face_entry = "assets/.godot/exported/facial_motion.gdc"
                    payload = b"fixture compiled facial motion"
                    archive.writestr("assets/" + VALIDATOR.HERO_FACE_SCRIPT + ".remap",
                                     '[remap]\npath="res://.godot/exported/facial_motion.gdc"\n')
                    archive.writestr(face_entry, payload)
                    expected[VALIDATOR.HERO_FACE_SCRIPT] = hashlib.sha256(payload).hexdigest()
                if include_models:
                    for level in range(4):
                        if level == missing_level:
                            continue
                        resource = f"assets/characters/hero_quality_{level}.glb"
                        imported = f".godot/imported/hero_quality_{level}.glb-unique{level}.scn"
                        archive.writestr("assets/" + resource + ".import",
                                         f'[remap]\npath="res://{imported}"\n')
                        if level != dangling_level:
                            payload = f"fixture imported hero LOD {level}".encode()
                            archive.writestr("assets/" + imported, payload)
                            expected[resource] = hashlib.sha256(payload).hexdigest()
            report = {"checks": []}
            VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
            content = next(item for item in report["checks"] if item["id"] == "godot_project_content")
            hero = next((item for item in report["checks"] if item["id"] == "hero_character_content"), None)
            return hero, content, expected

    def test_complete_export_records_transformed_payloads(self):
        hero, content, expected = self.inspect()
        self.assertEqual(hero["status"], "pass")
        self.assertEqual(content["status"], "pass")
        self.assertEqual(len(hero["evidence"]["resources"]), 5)
        for item in hero["evidence"]["resources"]:
            self.assertEqual(item["mode"], "remapped")
            self.assertEqual(item["sha256"], expected[item["source"]])
            self.assertGreater(item["size_bytes"], 0)
            self.assertEqual(len(item["remap_sha256"]), 64)

    def test_current_sources_reject_an_older_package_without_the_entire_hero(self):
        hero, content, _ = self.inspect(include_face=False, include_models=False)
        self.assertEqual(hero["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(set(hero["evidence"]["missing_resources"]), set(VALIDATOR.HERO_RESOURCES))

    def test_dangling_lod_remap_is_not_an_included_model(self):
        hero, content, _ = self.inspect(dangling_level=3)
        self.assertEqual(hero["status"], "fail")
        self.assertEqual(content["status"], "fail")
        self.assertEqual(hero["evidence"]["missing_resources"], ["assets/characters/hero_quality_3.glb"])

    def test_packaged_hero_also_requires_facial_motion_when_sources_are_unavailable(self):
        hero, _, _ = self.inspect(source_requires=False, include_face=False)
        self.assertEqual(hero["status"], "fail")
        self.assertIn(VALIDATOR.HERO_FACE_SCRIPT, hero["evidence"]["missing_resources"])

    def test_historical_source_and_package_do_not_invent_a_new_requirement(self):
        hero, content, _ = self.inspect(source_requires=False, include_face=False, include_models=False)
        self.assertIsNone(hero)
        self.assertEqual(content["status"], "pass")


if __name__ == "__main__":
    unittest.main()
