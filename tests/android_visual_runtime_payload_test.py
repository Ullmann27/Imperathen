"""APK payload regressions: do not ship an invisible or empty visual system."""
from __future__ import annotations

import configparser
import fnmatch
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("visual_apk_validator", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
GROUP_IDS = ["village_look_content","city_architecture_content","city_market_data_content","city_crowd_data_content","city_catalog_content","weapon_catalog_content","android_static_vegetation_content"]
GROUPS = {key: paths for key, paths in VALIDATOR.FEATURE_RESOURCE_GROUPS if key in GROUP_IDS}
RESOURCES = {path for group in GROUPS.values() for path in group}
RAW_DATA = ["assets/story/chapter1_abilities.json","assets/story/investigation/valdora_raid.json","assets/village/look/look_values.json","assets/world/city_catalog.json","assets/world/city_crowd_layout.json","assets/city_detail/architecture/architecture_manifest.json","assets/city_detail/shops/city_market_anchors.json","assets/city_detail/characters/provenance.json","assets/interiors/kit_manifest.json","assets/interiors/shell_contract.json","assets/interiors/textures/manifest.json","assets/roman_material_lab/manifest.json","assets/roman_quarter/paving/metrics.json","assets/audio/sfx/sfx_manifest.json","assets/world/road_landmarks/old_quarry_asset.json","assets/world_expansion/manifest.json","assets/viva_country/manifest.json","assets/viva_country/hinterland_trees.json","assets/viva_country/scatter_0.json","assets/viva_country/scatter_1.json","assets/viva_country/scatter_2.json","data/weapons/weapon_catalog.v1.json"]

def inspect_fixture(exported, current=True):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "source"
        if current:
            for path in RESOURCES:
                target = source / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(path.encode())
        apk = root / "synthetic.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/project.binary", b"ECFG")
            for path in set(VALIDATOR.EXPECTED_RESOURCES) | set(exported):
                archive.writestr("assets/" + path, path.encode())
        report = {"checks": []}
        VALIDATOR.inspect_zip(apk, report, "arm64-v8a", source)
        return {item["id"]: item for item in report["checks"]}

class VisualRuntimePayloadTest(unittest.TestCase):
    def test_all_export_presets_include_runtime_data(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / "prototype/export_presets.cfg", encoding="utf-8")
        for section in ("preset.0", "preset.1", "preset.2"):
            patterns = config[section]["include_filter"].strip('"').split(",")
            excludes = config[section]["exclude_filter"].strip('"').split(",")
            for path in RAW_DATA:
                with self.subTest(preset=section, path=path):
                    self.assertTrue((ROOT / "prototype" / path).is_file(), path)
                    self.assertTrue(any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns), path)
                    self.assertFalse(any(fnmatch.fnmatchcase(path, pattern) for pattern in excludes), path)

    def test_every_visual_group_present_and_hashed(self):
        checks = inspect_fixture(RESOURCES)
        self.assertEqual(set(GROUPS), set(GROUP_IDS))
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        for identifier in GROUPS:
            self.assertEqual(checks[identifier]["status"], "pass")
            self.assertTrue(all(item.get("sha256") for item in checks[identifier]["evidence"]["resources"]))

    def test_missing_visual_or_data_resource_fails(self):
        for identifier, paths in GROUPS.items():
            for missing in paths:
                with self.subTest(group=identifier, missing=missing):
                    checks = inspect_fixture(RESOURCES - {missing})
                    self.assertEqual(checks[identifier]["status"], "fail")
                    self.assertIn(missing, checks[identifier]["evidence"]["missing_resources"])
                    self.assertEqual(checks["godot_project_content"]["status"], "fail")

    def test_old_snapshot_not_misidentified(self):
        checks = inspect_fixture(set(), current=False)
        self.assertFalse(set(GROUP_IDS) & checks.keys())

if __name__ == "__main__":
    unittest.main()
