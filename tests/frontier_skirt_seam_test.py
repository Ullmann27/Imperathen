"""Regression for the frontier skirt seam (tools/characters/smooth_frontier_skirt_seam.py).

The JSON checks need only the standard library. The re-measurement poses the
committed GLBs on the CPU and needs NumPy; it is skipped, not faked, where
NumPy is unavailable. The engine measurement stays in the motion gate.
"""
from __future__ import annotations

import importlib.util
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ROOT / "prototype/assets/characters"
TOOL = ROOT / "tools/characters/smooth_frontier_skirt_seam.py"
MARKER = "imperathen_skirt_seam_smoothing"
# Exports whose exported skirt tore on its own clips (gate criterion).
SMOOTHED = sorted([f"frontier_{kind}_{lod}.glb" for kind in ("archer", "legionary", "officer", "spearman") for lod in (0, 1)]
                  + ["frontier_civilian_man_0.glb", "frontier_elder_0.glb"])


def skirt_mesh(path: Path) -> dict:
    data = path.read_bytes()
    size, _ = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + size])
    return next(mesh for mesh in document["meshes"] if mesh.get("name") == "HeroTunicSkirt")


class SkirtSeamJsonTest(unittest.TestCase):
    def test_only_tearing_skirts_are_smoothed(self):
        exports = sorted(path.name for path in CHARACTERS.glob("frontier_*.glb"))
        self.assertEqual(len(exports), 28)
        for name in exports:
            with self.subTest(glb=name):
                marker = skirt_mesh(CHARACTERS / name).get("extras", {}).get(MARKER)
                if name in SMOOTHED:
                    self.assertIsNotNone(marker)
                    self.assertGreater(marker["tearing_before"], 0)
                    self.assertEqual(marker["tearing_after"], 0)
                else:
                    self.assertIsNone(marker)


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exported skin")
class SkirtSeamMeasurementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("smooth_frontier_skirt_seam", TOOL)
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def test_smoothing_is_idempotent(self):
        report = self.tool.smooth(CHARACTERS / "frontier_legionary_1.glb", False)
        self.assertEqual(report.get("skipped"), "already smoothed")

    def test_untouched_lod_still_does_not_tear(self):
        report = self.tool.smooth(CHARACTERS / "frontier_legionary_3.glb", False)
        self.assertEqual(report.get("unchanged"), "skirt does not tear")
        self.assertEqual(report["before"]["tearing"], 0)


if __name__ == "__main__":
    unittest.main()
