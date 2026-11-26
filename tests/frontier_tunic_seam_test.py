"""Regression for the frontier tunic armpit seam (smooth_frontier_skirt_seam.py --cloth HeroTunic).

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
MARKER = "imperathen_tunic_seam_smoothing"


def tunic_mesh(path: Path) -> dict:
    data = path.read_bytes()
    size, _ = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + size])
    return next(mesh for mesh in document["meshes"] if mesh.get("name") == "HeroTunic")


class TunicSeamJsonTest(unittest.TestCase):
    def test_smoothed_tunics_no_longer_tear(self):
        exports = sorted(path.name for path in CHARACTERS.glob("frontier_*.glb"))
        self.assertEqual(len(exports), 28)
        smoothed = 0
        for name in exports:
            with self.subTest(glb=name):
                marker = tunic_mesh(CHARACTERS / name).get("extras", {}).get(MARKER)
                if marker is not None:
                    smoothed += 1
                    self.assertGreater(marker["tearing_before"], 0)
                    self.assertEqual(marker["tearing_after"], 0)
        self.assertGreater(smoothed, 0)


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exported skin")
class TunicSeamMeasurementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("smooth_frontier_skirt_seam", TOOL)
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def test_every_tunic_is_smoothed_or_does_not_tear(self):
        for path in sorted(CHARACTERS.glob("frontier_*_3.glb"))[:3] + [CHARACTERS / "frontier_legionary_2.glb"]:
            with self.subTest(glb=path.name):
                report = self.tool.smooth(path, False, "HeroTunic")
                self.assertIn(report.get("skipped") or report.get("unchanged"), ("already smoothed", "tunic does not tear"))


if __name__ == "__main__":
    unittest.main()
