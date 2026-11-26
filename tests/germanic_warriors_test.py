"""Germanic warrior families: registry, uniqueness, rig/clip compatibility,
budgets, equipment sockets, measured clipping and build reproducibility.

Reads the exported GLB bytes directly (no Blender, no Godot). Run:
    python3 tests/germanic_warriors_test.py
"""
from __future__ import annotations

import hashlib
import itertools
import json
import math
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/germanic_warriors"
REGISTRY = json.loads((ART / "registry.json").read_text())
REFERENCE_RIG = ROOT / "prototype/assets/characters/frontier_spearman_0.glb"
COMPANY_BONES = {"Pelvis", "Spine", "Head", "Arm_L", "Forearm_L", "Hand_L", "Arm_R", "Forearm_R", "Hand_R",
                 "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"}
COMPANY_CLIPS = {"idle", "march", "run", "attack", "shoot", "block", "wall", "testudo", "hit", "retreat", "death"}
CORE_FAMILIES = {"skirmisher", "levy", "spear_shield", "swordsman", "retinue"}
# Clipping acceptance (measure.py, exported LOD 0): worst vertex of an inner
# layer outside the outer layer, and gear triangle intersections, per clip.
# 1 cm is the gate's own bound for unintended penetration of attached parts.
LAYER_LIMIT_M = {"idle": .01, "march": .01, "attack": .01}
GEAR_PAIRS_LIMIT = {"idle": 0, "march": 0, "attack": 0}


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and total == len(data), path
    size, kind = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + size])
    bin_size, _ = struct.unpack_from("<II", data, 20 + size)
    binary = data[28 + size:28 + size + bin_size]
    return document, binary


def accessor_max(document, binary, index):
    accessor = document["accessors"][index]
    return max(accessor.get("max", [0.0]))


def triangles(document):
    count = 0
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            if "indices" in primitive:
                count += document["accessors"][primitive["indices"]]["count"] // 3
            else:
                count += document["accessors"][primitive["attributes"]["POSITION"]]["count"] // 3
    return count


def skeleton(document):
    skin = document["skins"][0]
    result = {}
    for joint in skin["joints"]:
        node = document["nodes"][joint]
        result[node["name"]] = (tuple(node.get("translation", (0, 0, 0))), tuple(node.get("rotation", (0, 0, 0, 1))),
                                tuple(node.get("scale", (1, 1, 1))))
    return result


def clips(document, binary):
    result = {}
    for animation in document.get("animations", []):
        duration = max(accessor_max(document, binary, s["input"]) for s in animation["samplers"])
        result[animation["name"]] = (duration, animation)
    return result


def figure_paths(fid):
    return [ART / "export/figures" / f"germanic_{fid}_{lod}.glb" for lod in range(4)]


class Registry(unittest.TestCase):
    def test_two_groups_with_own_identity_and_core_families(self):
        groups = REGISTRY["groups"]
        self.assertGreaterEqual(len(groups), 2)
        identities = {g["shield_shape"] + g["shield_paint"] + g["shield_motif"] for g in groups.values()}
        self.assertEqual(len(identities), len(groups), "groups must differ in shield shape/paint/motif")
        for group in groups:
            families = {f["family"] for f in REGISTRY["figures"] if f["group"] == group}
            self.assertTrue(CORE_FAMILIES <= families, (group, CORE_FAMILIES - families))

    def test_every_choice_is_marked(self):
        levels = set(REGISTRY["attestation_levels"])
        for figure in REGISTRY["figures"]:
            self.assertTrue(figure["choices"], figure["id"])
            for name, (level, note) in figure["choices"].items():
                self.assertIn(level, levels, (figure["id"], name))
                self.assertTrue(note.strip())
        for group in REGISTRY["groups"].values():
            for name, (level, note) in group["attestation"].items():
                self.assertIn(level, levels, name)
        # Later sources must say so wherever they are cited.
        self.assertIn("AD 98", REGISTRY["sources"]["tacitus_germania"]["date"])

    def test_axe_and_shield_is_never_the_standard(self):
        items = {item["id"]: item for item in REGISTRY["equipment"]}
        for figure in REGISTRY["figures"]:
            kinds = {items[i]["kind"] for i in figure["loadout"].values()}
            self.assertNotIn("axe", kinds, figure["id"] + ": axe in a default loadout contradicts D-024")
        axe_tier = next(t for t in REGISTRY["tiers"] if t["id"] == "axe_fighter")
        self.assertIn("never the standard", axe_tier["note"])
        mounted = next(t for t in REGISTRY["tiers"] if t["id"] == "mounted")
        self.assertIn("not built", mounted["note"])

    def test_quality_follows_status(self):
        items = {item["id"]: item for item in REGISTRY["equipment"]}
        for figure in REGISTRY["figures"]:
            s = figure["status"]
            expected = min(3, round((s["wealth"] + max(s["trade"], s["craft"])) / 2 + s["experience"] / 3))
            best = max(items[i]["quality"] for i in figure["loadout"].values())
            self.assertLessEqual(abs(best - expected), 1, figure["id"])

    def test_no_two_figures_share_clothing_gear_or_face(self):
        def sig(value):
            return json.dumps(value, sort_keys=True)
        for a, b in itertools.combinations(REGISTRY["figures"], 2):
            self.assertNotEqual(sig(a["clothing"]), sig(b["clothing"]), (a["id"], b["id"], "clothing"))
            self.assertNotEqual(sig(a["loadout"]), sig(b["loadout"]), (a["id"], b["id"], "gear"))
            self.assertNotEqual(sig([a["face"], a["hair"], a["beard"], a["eyes"], a["skin"]]),
                                sig([b["face"], b["hair"], b["beard"], b["eyes"], b["skin"]]), (a["id"], b["id"], "face"))
            if a["family"] == b["family"]:
                self.assertNotEqual(a["group"], b["group"])
                self.assertNotEqual(a["clothing"].get("tunic", {}).get("colour"),
                                    b["clothing"].get("tunic", {}).get("colour") or "-", (a["id"], b["id"]))


class Exports(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference, ref_bin = read_glb(REFERENCE_RIG)
        cls.reference_skeleton = skeleton(reference)
        cls.reference_clips = {name: d for name, (d, _) in clips(reference, ref_bin).items()}

    def test_rig_and_clips_match_the_company_rig(self):
        for figure in REGISTRY["figures"]:
            for path in figure_paths(figure["id"]):
                document, binary = read_glb(path)
                bones = skeleton(document)
                self.assertEqual(set(bones), COMPANY_BONES, path.name)
                for name, (t, r, s) in bones.items():
                    rt, rr, rs = self.reference_skeleton[name]
                    self.assertTrue(all(math.isclose(x, y, abs_tol=1e-5) for x, y in zip(t, rt)), (path.name, name, t, rt))
                    self.assertTrue(all(math.isclose(x, y, abs_tol=1e-5) for x, y in zip(r, rr)), (path.name, name))
                found = clips(document, binary)
                self.assertEqual(set(found), COMPANY_CLIPS, path.name)
                for name, (duration, animation) in found.items():
                    self.assertAlmostEqual(duration, self.reference_clips[name], delta=.021, msg=(path.name, name))
                self.assertIn("imperathen_grounded_death", found["death"][1].get("extras", {}), path.name)

    def test_triangle_budgets_per_lod_and_profile(self):
        levels = {level["lod"]: level for level in REGISTRY["lod"]["levels"]}
        worst = {lod: 0 for lod in levels}
        for figure in REGISTRY["figures"]:
            previous = None
            for lod, path in enumerate(figure_paths(figure["id"])):
                document, _ = read_glb(path)
                count = triangles(document)
                self.assertLessEqual(count, levels[lod]["max_triangles"], path.name)
                if previous is not None:
                    self.assertLess(count, previous, path.name)
                previous = count
                worst[lod] = max(worst[lod], count)
                images = document.get("images", [])
                self.assertTrue(images, path.name)
                if lod >= 2:
                    self.assertFalse(any("targets" in p for m in document["meshes"] for p in m["primitives"]), path.name)
        rules = REGISTRY["lod"]["rules"]
        for name, profile in REGISTRY["lod"]["profiles"].items():
            lod0 = profile["lod0_max_actors"] * worst[0]
            rest = profile["animated_actors"] - profile["lod0_max_actors"] - profile["lod1_max_actors"] - profile["lod2_max_actors"]
            total = lod0 + profile["lod1_max_actors"] * worst[1] + profile["lod2_max_actors"] * worst[2] + max(0, rest) * worst[3]
            self.assertLessEqual(lod0, rules["lod0_share_max"] * profile["visible_primitives"], name)
            self.assertLessEqual(total, rules["all_actors_share_max"] * profile["visible_primitives"], name)

    def test_equipment_library_has_grip_sockets(self):
        for item in REGISTRY["equipment"]:
            counts = []
            for tier in (0, 1):
                path = ART / "export/equipment" / f"{item['id']}_{tier}.glb"
                document, _ = read_glb(path)
                roots = document["scenes"][document.get("scene", 0)]["nodes"]
                self.assertEqual(len(roots), 1, path.name)
                root = document["nodes"][roots[0]]
                self.assertIn("mesh", root, path.name)
                sockets = [document["nodes"][c] for c in root.get("children", [])
                           if document["nodes"][c]["name"].startswith("SOCKET_")]
                self.assertEqual(len(sockets), 1, path.name)
                self.assertFalse(any(k in sockets[0] for k in ("translation", "rotation", "scale", "matrix")), path.name)
                expected = {"R": "SOCKET_RIGHT_HAND", "L": "SOCKET_LEFT_HAND", "belt": "SOCKET_BELT_LEFT"}[item["hand"]]
                self.assertEqual(sockets[0]["name"], expected)
                counts.append(triangles(document))
            self.assertLess(counts[1], counts[0], item["id"])

    def test_build_report_matches_bytes(self):
        report = json.loads((ART / "build_report.json").read_text())
        for fid, info in report["figures"].items():
            for record in info["lods"]:
                path = ROOT / record["path"]
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"], path.name)
        for record in report.get("equipment", []):
            path = ROOT / record["path"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"], path.name)

    def test_measured_clipping_within_limits(self):
        measured = json.loads((ART / "measurements.json").read_text())
        for figure in REGISTRY["figures"]:
            record = measured["figures"][figure["id"]]
            lod0 = figure_paths(figure["id"])[0]
            self.assertEqual(record["lod0_sha256"], hashlib.sha256(lod0.read_bytes()).hexdigest(), "stale measurement")
            for clip, limit in LAYER_LIMIT_M.items():
                self.assertLessEqual(record["clips"][clip]["max_layer_penetration_m"], limit, (figure["id"], clip))
            for clip, limit in GEAR_PAIRS_LIMIT.items():
                self.assertLessEqual(record["clips"][clip]["gear_intersecting_triangle_pairs"], limit, (figure["id"], clip))


if __name__ == "__main__":
    unittest.main(verbosity=2)
