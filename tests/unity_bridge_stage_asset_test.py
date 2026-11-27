"""Offline regression for Unity-generated GLB contract using existing inspection API."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
import stage_asset

def metrics(**overrides):
    item = {
        "sha256": "a" * 64, "self_contained": True, "static_binary_gate": True,
        "triangles": 2000, "size_bytes": 3, "primitives": 1,
        "primitives_with_uv0": 1, "skins": 1, "animations": 11,
        "character_rig_gate": True, "materials": 1, "pbr_materials": 1,
        "images": [{}]
    }
    item.update(overrides)
    return item

class UnityAssetGateTest(unittest.TestCase):
    def test_strict_character_and_static_rules(self):
        with tempfile.TemporaryDirectory() as td:
            obj = Path(td) / "source.glb"
            obj.write_bytes(b"123")
            with patch.object(stage_asset, "inspect_glb", return_value=metrics()):
                value = stage_asset.inspect_for_godot(obj, "character", "a" * 64)
                self.assertFalse(value["runtime_ready"])
                self.assertEqual(value["animations"], 11)
            with patch.object(stage_asset, "inspect_glb", return_value=metrics(character_rig_gate=False, skins=0, animations=0)):
                with self.assertRaisesRegex(ValueError, "requires_skin"):
                    stage_asset.inspect_for_godot(obj, "character")
                self.assertEqual(stage_asset.inspect_for_godot(obj, "prop")["kind"], "prop")
            with patch.object(stage_asset, "inspect_glb", return_value=metrics(primitives_with_uv0=0)):
                with self.assertRaisesRegex(ValueError, "missing_texture_uv"):
                    stage_asset.inspect_for_godot(obj, "architecture")
            with patch.object(stage_asset, "inspect_glb", return_value=metrics()):
                with self.assertRaisesRegex(ValueError, "mismatch"):
                    stage_asset.inspect_for_godot(obj, "prop", "0" * 64)

    def test_review_stage_is_isolated_and_fails_closed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "source.glb"
            src.write_bytes(b"123")
            info = {"sha256": "a" * 64}
            target = stage_asset.stage_for_review(src, root, "roman_prop_01", info)
            self.assertEqual(target.read_bytes(), b"123")
            self.assertTrue(str(target).endswith("prototype/assets/unity/review/roman_prop_01.glb"))
            with self.assertRaisesRegex(ValueError, "invalid_asset_id"):
                stage_asset.stage_for_review(src, root, "../../escape", info)
            with patch.object(stage_asset, "inspect_glb", return_value=metrics(sha256="b" * 64)):
                with self.assertRaises(FileExistsError):
                    stage_asset.stage_for_review(src, root, "roman_prop_01", info)
