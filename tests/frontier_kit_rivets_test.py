"""Regression for the frontier kit rivets (tools/characters/rebind_frontier_kit_rivets.py).

The JSON checks need only the standard library; the re-measurement needs
NumPy and is skipped, not faked, where NumPy is unavailable.
"""
from __future__ import annotations

import importlib.util
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ROOT / "prototype/assets/characters"
TOOL = ROOT / "tools/characters/rebind_frontier_kit_rivets.py"
MARKER = "imperathen_kit_rivet_binding"
# Shoulder rivets on the Arm-bound guards (LOD 0-2; the archer has no guards).
REBOUND = sorted(f"frontier_{kind}_{lod}.glb" for kind in ("legionary", "officer", "spearman") for lod in (0, 1, 2))


def kit_mesh(path: Path) -> dict | None:
    data = path.read_bytes()
    size, _ = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + size])
    return next((mesh for mesh in document["meshes"] if mesh.get("name") == "FrontierRomanKit"), None)


class KitRivetJsonTest(unittest.TestCase):
    def test_rivets_sit_on_their_plates(self):
        military = sorted(path.name for kind in ("legionary", "officer", "spearman", "archer")
                          for path in CHARACTERS.glob(f"frontier_{kind}_*.glb"))
        self.assertEqual(len(military), 16)
        for name in military:
            with self.subTest(glb=name):
                marker = kit_mesh(CHARACTERS / name).get("extras", {}).get(MARKER)
                self.assertIsNotNone(marker)
                self.assertGreaterEqual(marker["snapped_islands"], 5)
                self.assertLessEqual(marker["max_gap_before_m"], .04)
                if name in REBOUND:
                    self.assertGreater(marker["rebound_islands"], 0)
                    self.assertGreater(marker["max_lift_before_m"], .01)
                    self.assertEqual(marker["max_lift_after_m"], 0.0)
                else:
                    self.assertEqual(marker["rebound_islands"], 0)


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exported skin")
class KitRivetMeasurementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("rebind_frontier_kit_rivets", TOOL)
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def test_rebinding_is_idempotent(self):
        self.assertEqual(self.tool.rebind(CHARACTERS / "frontier_officer_2.glb", False).get("skipped"), "already rebound")

    def test_civilians_have_no_kit(self):
        report = self.tool.rebind(CHARACTERS / "frontier_civilian_man_3.glb", False)
        self.assertEqual(report.get("unchanged"), "no military kit")


if __name__ == "__main__":
    unittest.main()
