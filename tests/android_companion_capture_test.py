"""Der Bildnachweis darf echte Quellenänderungen nicht als Import kaschieren."""
import base64
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "capture_companion_comparison", ROOT / "tools/capture_companion_comparison.py")
CAPTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CAPTURE)
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aH1kAAAAASUVORK5CYII=")


class CompanionCaptureGuardTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="companion-import-guard-")
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        self.asset = self.project / "assets" / "actor.glb"
        self.asset.parent.mkdir()
        self.script = self.project / "world.gd"
        self.script.write_text("extends Node3D\n", encoding="utf-8")
        self.texture = self.asset.with_name("actor_Skin.png")
        self.write_glb()
        self.before = CAPTURE.source_hashes(self.project)

    def write_glb(self, *, name="Skin", offset=0, mime="image/png", payload=PNG):
        document = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": len(payload)}],
                    "bufferViews": [{"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}],
                    "images": [{"name": name, "mimeType": mime, "bufferView": 0}]}
        metadata = json.dumps(document).encode("utf-8")
        metadata += b" " * (-len(metadata) % 4)
        binary = payload + b"\x00" * (-len(payload) % 4)
        total = 12 + 8 + len(metadata) + 8 + len(binary)
        self.asset.write_bytes(struct.pack("<4sII", b"glTF", 2, total)
                               + struct.pack("<I4s", len(metadata), b"JSON") + metadata
                               + struct.pack("<I4s", len(binary), b"BIN\x00") + binary)

    def check(self):
        return CAPTURE.check_import_sources(
            self.project, self.before, CAPTURE.source_hashes(self.project))

    def test_exact_embedded_png_is_recorded_with_provenance(self):
        self.texture.write_bytes(PNG)
        result = self.check()
        self.assertTrue(result["passed"], result)
        item, = result["generated_import_textures"]
        self.assertEqual(item["path"], "assets/actor_Skin.png")
        self.assertEqual(item["sha256"], CAPTURE.digest(self.texture))
        self.assertEqual(item["source_glb"], "assets/actor.glb")
        self.assertEqual(item["source_glb_sha256"], self.before["assets/actor.glb"])
        self.assertEqual(item["image_index"], 0)
        self.assertEqual(item["byte_length"], len(PNG))

    def test_exact_embedded_jpeg_is_supported(self):
        payload = b"\xff\xd8synthetic-jpeg-payload\xff\xd9"
        self.write_glb(mime="image/jpeg", payload=payload)
        self.before = CAPTURE.source_hashes(self.project)
        self.texture.with_suffix(".jpg").write_bytes(payload)
        self.assertTrue(self.check()["passed"])

    def test_unchanged_warm_import_needs_no_exception(self):
        self.texture.write_bytes(PNG)
        self.before = CAPTURE.source_hashes(self.project)
        result = self.check()
        self.assertTrue(result["passed"])
        self.assertEqual(result["generated_import_textures"], [])

    def test_existing_source_edit_is_rejected(self):
        self.texture.write_bytes(PNG)
        self.script.write_text("extends Node\n", encoding="utf-8")
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["existing_source_changes"], ["world.gd"])

    def test_existing_source_removal_is_rejected(self):
        self.script.unlink()
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["existing_source_changes"], ["world.gd"])

    def test_changed_embedded_image_cannot_be_blessed_by_changed_glb(self):
        self.write_glb(payload=PNG + b"changed")
        self.texture.write_bytes(PNG + b"changed")
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["existing_source_changes"], ["assets/actor.glb"])
        self.assertEqual(result["unexpected_added_paths"], ["assets/actor_Skin.png"])

    def test_new_glb_cannot_authorize_new_texture(self):
        del self.before["assets/actor.glb"]
        self.texture.write_bytes(PNG)
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["unexpected_added_paths"], ["assets/actor.glb", "assets/actor_Skin.png"])

    def test_matching_filename_with_changed_bytes_is_rejected(self):
        self.texture.write_bytes(PNG + b"changed")
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["unexpected_added_paths"], ["assets/actor_Skin.png"])

    def test_matching_bytes_at_wrong_path_are_rejected(self):
        wrong = self.asset.with_name("actor_Invented.png")
        wrong.write_bytes(PNG)
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["unexpected_added_paths"], ["assets/actor_Invented.png"])

    def test_new_source_is_rejected_even_beside_valid_extraction(self):
        self.texture.write_bytes(PNG)
        (self.project / "injected.gd").write_text("extends Node\n", encoding="utf-8")
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(result["unexpected_added_paths"], ["injected.gd"])

    def test_invalid_binary_bounds_do_not_authorize_image(self):
        self.write_glb(offset=10000)
        self.before = CAPTURE.source_hashes(self.project)
        self.texture.write_bytes(PNG)
        self.assertFalse(self.check()["passed"])

    def test_invalid_glb_is_reported_and_rejected(self):
        self.asset.write_bytes(b"invalid glb")
        self.before = CAPTURE.source_hashes(self.project)
        self.texture.write_bytes(PNG)
        result = self.check()
        self.assertFalse(result["passed"])
        self.assertEqual(len(result["provenance_errors"]), 1)

    def test_imported_texture_changes_are_strictly_rejected_during_capture(self):
        self.texture.write_bytes(PNG)
        self.assertTrue(self.check()["passed"])
        prepared = CAPTURE.source_hashes(self.project)
        self.texture.write_bytes(PNG + b"changed-during-render")
        self.assertEqual(CAPTURE.changed_sources(prepared, CAPTURE.source_hashes(self.project)),
                         ["assets/actor_Skin.png"])

    def test_capture_guard_catches_additions_and_removals(self):
        prepared = CAPTURE.source_hashes(self.project)
        self.script.unlink()
        self.texture.write_bytes(PNG)
        self.assertEqual(CAPTURE.changed_sources(prepared, CAPTURE.source_hashes(self.project)),
                         ["assets/actor_Skin.png", "world.gd"])


if __name__ == "__main__":
    unittest.main()
