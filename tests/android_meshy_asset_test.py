from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
import sys


ROOT = Path(__file__).resolve().parents[1]
TOOLS_ART = ROOT / "tools/art"
if str(TOOLS_ART) not in sys.path:
    sys.path.insert(0, str(TOOLS_ART))
SPEC = importlib.util.spec_from_file_location("inspect_meshy_glb", TOOLS_ART / "inspect_meshy_glb.py")
INSPECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSPECTOR)
STAGE_SPEC = importlib.util.spec_from_file_location("stage_meshy_assets", TOOLS_ART / "stage_meshy_assets.py")
STAGER = importlib.util.module_from_spec(STAGE_SPEC)
STAGE_SPEC.loader.exec_module(STAGER)


def png_1x1() -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    def chunk(name: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + name + payload + struct.pack(">I", zlib.crc32(name + payload) & 0xFFFFFFFF)
    return signature + chunk(b"IHDR", ihdr_data) + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\xff")) + chunk(b"IEND", b"")


def write_glb(path: Path) -> None:
    positions = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
    normals = struct.pack("<9f", 0, 0, 1, 0, 0, 1, 0, 0, 1)
    uv = struct.pack("<6f", 0, 0, 1, 0, 0, 1)
    indices = struct.pack("<3H", 0, 1, 2)
    image = png_1x1()
    offsets = []
    blob = bytearray()
    for payload in (positions, normals, uv, indices, image):
        while len(blob) % 4:
            blob.append(0)
        offsets.append((len(blob), len(payload)))
        blob.extend(payload)
    while len(blob) % 4:
        blob.append(0)

    doc = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": off, "byteLength": length}
            for off, length in offsets
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]},
            {"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": 3, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123, "count": 3, "type": "SCALAR"},
        ],
        "images": [{"bufferView": 4, "mimeType": "image/png"}],
        "samplers": [{}],
        "textures": [{"source": 0, "sampler": 0}],
        "materials": [{
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.8,
            }
        }],
        "meshes": [{
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3,
                "material": 0,
            }]
        }],
        "nodes": [{"mesh": 0}],
        "scenes": [{"nodes": [0]}],
        "scene": 0,
    }
    json_bytes = json.dumps(doc, separators=(",", ":")).encode()
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(blob)
    with path.open("wb") as stream:
        stream.write(struct.pack("<4sII", b"glTF", 2, total))
        stream.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        stream.write(json_bytes)
        stream.write(struct.pack("<II", len(blob), 0x004E4942))
        stream.write(blob)


class MeshyGlbInspectorTest(unittest.TestCase):
    def test_minimal_self_contained_pbr_glb_passes_static_gate(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.glb"
            write_glb(path)
            report = INSPECTOR.inspect_glb(path)
            self.assertEqual(report["triangles"], 1)
            self.assertEqual(report["primitives"], 1)
            self.assertEqual(report["images"][0]["size"], [1, 1])
            self.assertTrue(report["self_contained"])
            self.assertTrue(report["static_binary_gate"])
            self.assertFalse(report["character_rig_gate"])

    def test_bad_magic_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "bad.glb"
            path.write_bytes(b"nope" + b"\x00" * 32)
            with self.assertRaises(INSPECTOR.GlbError):
                INSPECTOR.inspect_glb(path)

    def test_manifest_missing_files_are_reported_without_false_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({
                "assets": [{
                    "stable_id": "unit_test",
                    "category": "character",
                    "status": "ready_in_meshy",
                    "intended_source_path": "prototype/assets/meshy/source/character/unit_test.glb",
                }]
            }), encoding="utf-8")
            report, ok = INSPECTOR.inspect_manifest(manifest, root, require_all=False)
            self.assertTrue(ok)
            self.assertEqual(report["present"], 0)
            self.assertEqual(report["missing"], 1)
            _, strict_ok = INSPECTOR.inspect_manifest(manifest, root, require_all=True)
            self.assertFalse(strict_ok)


class MeshyStagingTest(unittest.TestCase):
    def test_valid_binary_is_copied_and_locked_without_runtime_claim(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "download.glb"
            write_glb(source)
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({
                "assets": [{
                    "stable_id": "weapon_test",
                    "category": "weapon",
                    "status": "ready_in_meshy",
                    "meshy_task_id": "task-final",
                    "meshy_preview_task_id": None,
                    "intended_source_path": "prototype/assets/meshy/source/weapon/weapon_test.glb",
                }]
            }), encoding="utf-8")
            lock = root / "prototype/assets/meshy/lock.json"
            report = STAGER.stage(
                manifest,
                root,
                {"weapon_test": source},
                lock,
            )
            destination = root / "prototype/assets/meshy/source/weapon/weapon_test.glb"
            self.assertTrue(destination.is_file())
            self.assertEqual(report["staged"], 1)
            record = json.loads(lock.read_text(encoding="utf-8"))["assets"]["weapon_test"]
            self.assertTrue(record["static_binary_gate"])
            self.assertFalse(record["runtime_ready"])
            self.assertEqual(record["sha256"], INSPECTOR.inspect_glb(source)["sha256"])

    def test_untextured_manifest_entry_requires_explicit_override(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "preview.glb"
            write_glb(source)
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({
                "assets": [{
                    "stable_id": "preview_test",
                    "category": "resource",
                    "status": "geometry_ready_untextured",
                    "meshy_task_id": None,
                    "meshy_preview_task_id": "preview-task",
                    "intended_source_path": "prototype/assets/meshy/source/resource/preview_test.glb",
                }]
            }), encoding="utf-8")
            with self.assertRaises(ValueError):
                STAGER.stage(manifest, root, {"preview_test": source}, root / "lock.json")
            report = STAGER.stage(
                manifest,
                root,
                {"preview_test": source},
                root / "lock.json",
                allow_untextured=True,
            )
            self.assertEqual(report["staged"], 1)


if __name__ == "__main__":
    unittest.main()
