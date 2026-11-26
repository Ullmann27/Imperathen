"""Regression for the planted company attack and train clips (tools/characters/plant_company_attack.py).

The JSON checks need only the standard library. The re-measurement poses the
committed GLBs on the CPU with the motion gate's 2 cm surface rule and needs
NumPy; it is skipped, not faked, where NumPy is unavailable. The engine
measurement of the same clips stays in motion_quality_measurement.gd.
"""
from __future__ import annotations

import importlib.util
import json
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "prototype/assets"
MARKER = "imperathen_planted_attack"
GATE_SLIP_M = .015
COMPANY_EXPORTS = sorted(
    [*ASSETS.glob("characters/frontier_*.glb"), *ASSETS.glob("meshy/characters/unit_*.glb"),
     *ASSETS.glob("soldiers/*_near.glb"), *ASSETS.glob("soldiers/*_mid.glb"),
     *ASSETS.glob("village_characters/*.glb")])


def gltf(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    size, kind = struct.unpack_from("<II", data, 12)
    if data[:4] != b"glTF" or kind != 0x4E4F534A:
        raise AssertionError(f"{path} is not a binary glTF")
    return json.loads(data[20:20 + size]), data[28 + size:]


class PlantedAttackJsonTest(unittest.TestCase):
    def test_every_company_attack_keeps_its_lead_thigh_planted(self):
        self.assertEqual(len(COMPANY_EXPORTS), 54)
        for path in COMPANY_EXPORTS:
            with self.subTest(glb=str(path.relative_to(ASSETS))):
                document, binary = gltf(path)
                thigh = next(i for i, node in enumerate(document["nodes"]) if node.get("name") == "Thigh_L")
                for clip in [a for a in document["animations"] if a["name"] in ("attack", "train")]:
                    channel = next(c for c in clip["channels"]
                                   if c["target"]["node"] == thigh and c["target"]["path"] == "rotation")
                    accessor = document["accessors"][clip["samplers"][channel["sampler"]]["output"]]
                    view = document["bufferViews"][accessor["bufferView"]]
                    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                    keys = struct.unpack_from("<%df" % (4 * accessor["count"]), binary, start)
                    self.assertEqual(len(set(zip(*[iter(keys)] * 4))), 1, clip["name"])
                    marker = clip.get("extras", {}).get(MARKER)
                    if clip["name"] == "attack" or marker is not None:
                        self.assertIsNotNone(marker, clip["name"])
                        self.assertLessEqual(marker["max_sole_slip_m"], GATE_SLIP_M)

    def test_source_pose_no_longer_sweeps_the_lead_leg(self):
        source = (ROOT / "art/soldiers/build.py").read_text(encoding="utf-8")
        attack = source[source.index('elif clip=="attack":'):source.index('elif clip=="shoot":')]
        self.assertIsNone(re.search(r'"Thigh_[LR]"\s*:', attack))


@unittest.skipUnless(importlib.util.find_spec("numpy"), "NumPy is required to pose the exports")
class PlantedAttackMeasurementTest(unittest.TestCase):
    def test_measured_attack_sole_slip_is_within_the_gate(self):
        spec = importlib.util.spec_from_file_location("ground_death_clip", ROOT / "tools/characters/ground_death_clip.py")
        grounding = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(grounding)
        for path in COMPANY_EXPORTS[::9]:
            with self.subTest(glb=str(path.relative_to(ASSETS))):
                rig = grounding.Rig(grounding.Glb(path))
                names = {a["name"] for a in rig.glb.document["animations"]}
                for clip in ("attack", "train"):
                    if clip not in names:
                        continue
                    measured = grounding.measure(rig, rig.animation(clip))
                    self.assertLessEqual(measured["max_sole_slip_m"], GATE_SLIP_M, clip)
                    self.assertLessEqual(measured["max_sole_penetration_m"], .01, clip)


if __name__ == "__main__":
    unittest.main()
