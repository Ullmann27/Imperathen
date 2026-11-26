"""Unit test of tools/world/check_city_collision_match.py on synthetic GLB files.

A counter with a collider, a counter without one, an invisible collider and a
kerb below the body band: the tool must report exactly the two real problems.
"""
from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/world"))
import check_city_collision_match as match  # noqa: E402


def box(x0, y0, z0, x1, y1, z1):
    """Triangles (n, 3, 3) of an axis-aligned box in glTF space (Y up)."""
    p = np.array([[x, y, z] for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)], np.float32)
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return np.array([[p[a], p[b], p[c]] for q in quads for a, b, c in ((q[0], q[1], q[2]), (q[0], q[2], q[3]))])


def write_glb(path, nodes):
    """nodes: list of (name, triangles, translation, category)."""
    blob, views, accessors, meshes, out_nodes = b"", [], [], [], []
    for name, triangles, translation, category in nodes:
        data = triangles.astype(np.float32).reshape(-1, 3).tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": len(triangles) * 3, "type": "VEC3"})
        blob += data
        meshes.append({"primitives": [{"attributes": {"POSITION": len(accessors) - 1}}]})
        out_nodes.append({"name": name, "mesh": len(meshes) - 1, "translation": list(translation),
                          "extras": {"category": category}})
    document = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": list(range(len(out_nodes)))}],
                "nodes": out_nodes, "meshes": meshes, "accessors": accessors, "bufferViews": views,
                "buffers": [{"byteLength": len(blob)}]}
    text = json.dumps(document).encode()
    text += b" " * (-len(text) % 4)
    blob += b"\0" * (-len(blob) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    path.write_bytes(b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(text)) + b"JSON" + text
                     + struct.pack("<I", len(blob)) + b"BIN\0" + blob)


class CityCollisionMatchTest(unittest.TestCase):
    def audit(self, visual, collision):
        with tempfile.TemporaryDirectory() as folder:
            city, solid = Path(folder) / "city.glb", Path(folder) / "collision.glb"
            write_glb(city, visual)
            write_glb(solid, collision)
            return match.audit(city, solid)

    def test_matching_counter_passes(self):
        counter = box(-1.8, 0.0, -0.7, 1.8, 1.1, 0.7)
        report = self.audit([("Stall", counter, (10, 0, 5), "market_stall")],
                            [("Stall_collision", counter, (10, 0, 5), "")])
        self.assertTrue(report["passed"], report["failures"])
        self.assertGreater(report["categories"]["market_stall"]["visible_samples"], 100)
        self.assertEqual(report["categories"]["market_stall"]["walk_through_samples"], 0)

    def test_counter_without_collider_is_a_walk_through(self):
        counter = box(-1.8, 0.0, -0.7, 1.8, 1.1, 0.7)
        report = self.audit([("Stall", counter, (0, 0, 0), "market_stall")], [])
        self.assertFalse(report["passed"])
        self.assertEqual([(f["name"], f["problem"]) for f in report["failures"]], [("Stall", "walk_through")])
        self.assertEqual(report["failures"][0]["samples"], report["failures"][0]["of"])

    def test_collider_larger_than_the_visible_object_is_an_invisible_wall(self):
        report = self.audit([("Crate", box(-0.4, 0.0, -0.4, 0.4, 0.7, 0.4), (0, 0, 0), "street_detail")],
                            [("Crate_collision", box(-2.0, 0.0, -2.0, 2.0, 1.4, 2.0), (0, 0, 0), "")])
        self.assertEqual([(f["name"], f["problem"]) for f in report["failures"]], [("Crate", "invisible_collider")])

    def test_collider_without_any_visible_object_is_reported(self):
        report = self.audit([("Crate", box(-0.4, 0.0, -0.4, 0.4, 0.7, 0.4), (0, 0, 0), "street_detail")],
                            [("Crate_collision", box(-0.4, 0.0, -0.4, 0.4, 0.7, 0.4), (0, 0, 0), ""),
                             ("Ghost_collision", box(5, 0, 5, 6, 2, 6), (0, 0, 0), "")])
        self.assertFalse(report["passed"])
        self.assertEqual(report["colliders_without_visual_object"], ["Ghost_collision"])

    def test_trim_on_a_solid_wall_and_low_kerbs_do_not_count(self):
        wall = box(-3, 0, -0.2, 3, 3, 0.2)
        trim = box(-0.9, 0, 0.2, -0.8, 2.5, 0.27)          # door frame 7 cm proud of the wall
        kerb = box(-3, 0, 2.0, 3, 0.22, 2.65)              # below the 0.25 m step limit
        report = self.audit([("House", np.concatenate([wall, trim, kerb]), (0, 0, 0), "residential")],
                            [("House_collision", wall, (0, 0, 0), "")])
        self.assertTrue(report["passed"], report["failures"])

    def test_column_on_a_podium_without_its_own_collider_is_found(self):
        podium = box(-10, 0, -10, 10, 0.6, 10)
        column = box(-0.3, 0.6, -0.3, 0.3, 6, 0.3)
        report = self.audit([("Hall", np.concatenate([podium, column]), (0, 0, 0), "civic")],
                            [("Hall_collision", podium, (0, 0, 0), "")])
        self.assertEqual([(f["name"], f["problem"]) for f in report["failures"]], [("Hall", "walk_through")])

    def test_goods_inside_one_counter_box_and_an_open_table_underside_match(self):
        board = box(-1.8, 0.91, -0.7, 1.8, 1.09, 0.7)
        legs = [box(x - 0.07, 0, z - 0.07, x + 0.07, 0.98, z + 0.07) for x in (-1.5, 1.5) for z in (-0.5, 0.5)]
        goods = [box(x - 0.15, 1.09, -0.1, x + 0.15, 1.45, 0.2) for x in (-1.2, -0.4, 0.4, 1.2)]
        report = self.audit([("Stall", np.concatenate([board] + legs + goods), (0, 0, 0), "market_stall")],
                            [("Stall_collision", box(-1.8, 0, -0.7, 1.8, 1.45, 0.7), (0, 0, 0), "")])
        self.assertTrue(report["passed"], report["failures"])

    def test_instances_share_one_measurement_and_scale_is_applied(self):
        trunk = box(-0.2, 0, -0.2, 0.2, 4, 0.2)
        visual = [("Tree_%d" % i, trunk, (i * 5.0, 0, 0), "vegetation") for i in range(4)]
        solid = [("Tree_%d_collision" % i, trunk, (i * 5.0, 0, 0), "") for i in range(3)]
        report = self.audit(visual, solid)
        self.assertEqual([f["name"] for f in report["failures"]], ["Tree_3"])
        self.assertEqual(report["categories"]["vegetation"]["objects"], 4)


if __name__ == "__main__":
    unittest.main()
