"""Regression for the grounded company death fall (tools/characters/ground_death_clip.py).

The JSON checks need only the standard library. The re-measurement poses the
committed GLBs on the CPU and needs NumPy (python3-numpy in the Fold7
workflows); it is skipped, not faked, where NumPy is unavailable. The engine
measurement of the same clips stays in motion_quality_measurement.gd and the
motion gate.
"""
from __future__ import annotations

import importlib.util
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "prototype/assets"
TOOL = ROOT / "tools/characters/ground_death_clip.py"
MARKER = "imperathen_grounded_death"
COMPANY_EXPORTS = sorted(
    [*ASSETS.glob("characters/frontier_*.glb"), *ASSETS.glob("meshy/characters/unit_*.glb"),
     *ASSETS.glob("soldiers/*_near.glb"), *ASSETS.glob("soldiers/*_mid.glb"),
     *ASSETS.glob("village_characters/*.glb")])
# Gate bounds (tools/motion_quality_gate.py) and the measured result of the
# rigid correction: penetration is removed everywhere; slip stays within the
# gate bound for the frontier and Meshy exports. Company soldiers (<= 2.1 cm)
# and village exports (<= 3.9 cm) keep a residual: the authored knee bend
# drags one sole against the other and the supporting sole rolls on its
# heel, which no rigid translation can remove. The bound guards that residual.
PENETRATION_M = .01
GATE_SLIP_M = .015
RESIDUAL_SLIP_M = .045
GATE_SLIP_FAMILIES = ("characters/frontier_", "meshy/characters/")


def document(path: Path) -> dict:
    data = path.read_bytes()
    size, kind = struct.unpack_from("<II", data, 12)
    if data[:4] != b"glTF" or kind != 0x4E4F534A:
        raise AssertionError(f"{path} is not a binary glTF")
    return json.loads(data[20:20 + size])


def death(path: Path) -> dict:
    return next(animation for animation in document(path)["animations"] if animation["name"] == "death")


class GroundedDeathJsonTest(unittest.TestCase):
    def test_every_company_export_is_grounded(self):
        self.assertEqual(len(COMPANY_EXPORTS), 54)
        for path in COMPANY_EXPORTS:
            with self.subTest(glb=str(path.relative_to(ASSETS))):
                marker = death(path).get("extras", {}).get(MARKER)
                self.assertIsNotNone(marker)
                self.assertEqual(marker["key_hz"], 240)
                self.assertEqual(list(marker["replaced_sampler_output_accessors"]), ["Pelvis/translation"])
                self.assertLessEqual(marker["max_sole_penetration_m"], PENETRATION_M)

    def test_only_the_pelvis_translation_points_to_a_new_sampler(self):
        for path in COMPANY_EXPORTS:
            with self.subTest(glb=str(path.relative_to(ASSETS))):
                doc = document(path)
                animation = death(path)
                original = len(animation["samplers"]) - 1
                moved = [(doc["nodes"][c["target"]["node"]]["name"], c["target"]["path"])
                         for c in animation["channels"] if c["sampler"] >= original]
                self.assertEqual(moved, [("Pelvis", "translation")])
                sampler = animation["samplers"][-1]
                self.assertEqual(sampler["interpolation"], "LINEAR")
                times = doc["accessors"][sampler["input"]]
                self.assertEqual(times["count"], 289)
                self.assertAlmostEqual(times["max"][0], 1.2, places=5)

    def test_hero_keeps_its_own_blender_grounding(self):
        for path in sorted(ASSETS.glob("characters/hero_quality_*.glb")):
            with self.subTest(glb=path.name):
                self.assertNotIn(MARKER, death(path).get("extras", {}))


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exported skin")
class GroundedDeathMeasurementTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("ground_death_clip", TOOL)
        cls.tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.tool)

    def measure(self, relative: str) -> dict:
        rig = self.tool.Rig(self.tool.Glb(ASSETS / relative))
        return self.tool.measure(rig, rig.animation("death"))

    def test_representative_exports_stay_on_the_floor(self):
        for relative in ("characters/frontier_legionary_0.glb", "characters/frontier_civilian_woman_3.glb",
                         "meshy/characters/unit_roman_signifer_3.glb", "soldiers/heavy_mid.glb",
                         "village_characters/heavy_3.glb", "village_characters/villager_3.glb"):
            with self.subTest(glb=relative):
                result = self.measure(relative)
                self.assertLessEqual(result["max_sole_penetration_m"], PENETRATION_M)
                self.assertLessEqual(result["max_hull_penetration_m"], PENETRATION_M)
                bound = GATE_SLIP_M if relative.startswith(GATE_SLIP_FAMILIES) else RESIDUAL_SLIP_M
                self.assertLessEqual(result["max_sole_slip_m"], bound)
                self.assertLessEqual(result["max_contact_slip_m"], bound)

    def test_grounding_is_idempotent(self):
        report = self.tool.ground(ASSETS / "soldiers/heavy_mid.glb", False)
        self.assertEqual(report.get("skipped"), "already grounded")


if __name__ == "__main__":
    unittest.main()
