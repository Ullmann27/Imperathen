"""Regression for the Meshy body seam (tools/characters/smooth_meshy_body_seam.py).

The JSON checks need only the standard library. The re-measurement poses the
committed GLBs on the CPU and needs NumPy; it is skipped, not faked, where
NumPy is unavailable. The engine measurement stays in the motion gate.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ROOT / "prototype/assets/meshy/characters"
REPORT = ROOT / "docs/20_meshy_assets/character-build.json"
TOOL = ROOT / "tools/characters/smooth_meshy_body_seam.py"
MARKER = "imperathen_meshy_seam_smoothing"
# Only this export tore on its own clips (gate criterion): the cloak edge
# over the right forearm of the axe fighter at LOD 0.
SMOOTHED = {"unit_germanic_axe_fighter_0.glb": 76}


def document(path: Path) -> dict:
    data = path.read_bytes()
    size, _ = struct.unpack_from("<II", data, 12)
    return json.loads(data[20:20 + size])


class MeshyBodySeamJsonTest(unittest.TestCase):
    def test_only_the_tearing_export_is_smoothed(self):
        exports = sorted(path.name for path in CHARACTERS.glob("unit_*.glb"))
        self.assertEqual(len(exports), 8)
        for name in exports:
            with self.subTest(glb=name):
                markers = [mesh["extras"][MARKER] for mesh in document(CHARACTERS / name)["meshes"]
                           if MARKER in mesh.get("extras", {})]
                if name in SMOOTHED:
                    self.assertEqual(len(markers), 1)
                    self.assertGreater(markers[0]["tearing_before"], 0)
                    self.assertEqual(markers[0]["tearing_after"], 0)
                    self.assertEqual(markers[0]["changed_vertices"], SMOOTHED[name])
                else:
                    self.assertEqual(markers, [])

    def test_weights_are_rewritten_in_place(self):
        # One accessor each for JOINTS_0/WEIGHTS_0, still the original types:
        # the change must not carry a second copy of the body weights.
        doc = document(CHARACTERS / "unit_germanic_axe_fighter_0.glb")
        attributes = doc["meshes"][0]["primitives"][0]["attributes"]
        self.assertEqual(doc["accessors"][attributes["JOINTS_0"]]["componentType"], 5121)
        self.assertEqual(doc["accessors"][attributes["WEIGHTS_0"]]["componentType"], 5126)
        self.assertEqual(len(doc["accessors"]), len(document(CHARACTERS / "unit_germanic_axe_fighter_1.glb")["accessors"]))

    def test_build_report_matches_the_exports(self):
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        tiers = [tier for character in report["characters"] for tier in character["lods"]]
        self.assertEqual(len(tiers), 8)
        for tier in tiers:
            path = ROOT / tier["path"]
            with self.subTest(glb=path.name):
                self.assertEqual(tier["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
                self.assertEqual(tier["size_bytes"], path.stat().st_size)
                seam = tier["body_seam"]
                if path.name in SMOOTHED:
                    self.assertEqual(seam["after"]["tearing"], 0)
                    self.assertLessEqual(seam["after"]["neighbour_through_m"], seam["before"]["neighbour_through_m"] + .0005)
                    self.assertEqual(seam["changed_vertices"], SMOOTHED[path.name])
                else:
                    self.assertEqual(seam, {"before": {"tearing": 0}})


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exported skin")
class MeshyBodySeamMeasurementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("smooth_meshy_body_seam", TOOL)
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def test_smoothing_is_idempotent(self):
        report = self.tool.smooth(CHARACTERS / "unit_germanic_axe_fighter_0.glb", False)
        self.assertEqual(report.get("skipped"), "already smoothed")

    def test_untouched_lod_still_does_not_tear(self):
        report = self.tool.smooth(CHARACTERS / "unit_germanic_axe_fighter_1.glb", False)
        self.assertEqual(report.get("unchanged"), "body does not tear")
        self.assertEqual(report["before"]["tearing"], 0)


if __name__ == "__main__":
    unittest.main()
