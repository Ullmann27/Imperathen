"""Build an original fist correction from the bundled CC0 anatomical finger rig.

Run with Blender: blender --background --python tools/characters/build_hand_grips.py
The existing GLBs and their fifteen runtime bones are unchanged. A small Godot
resource stores source-position keyed deltas and rotations for each actual LOD.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from build_hero import load_anatomy


def read_glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]

    def accessor(index):
        item = doc["accessors"][index]
        view = doc["bufferViews"][item["bufferView"]]
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[item["type"]]
        dtype = {5126: "<f4", 5123: "<u2", 5121: "u1", 5125: "<u4"}[item["componentType"]]
        return np.frombuffer(binary, dtype=dtype, count=item["count"] * count,
                             offset=view.get("byteOffset", 0) + item.get("byteOffset", 0)).reshape(-1, count)

    return doc, accessor


def main():
    anatomy = load_anatomy()
    points = anatomy["points"][0]
    raw_child = anatomy["raw_variants"][0]
    floor, scale = anatomy["scales"][0]
    original = np.column_stack((raw_child[:, 0] * scale, -raw_child[:, 2] * scale,
                                (raw_child[:, 1] - floor) * scale))
    groups = anatomy["facegroups"]
    deltas = np.zeros_like(points)
    rotations = np.tile(np.eye(3), (len(points), 1, 1))
    conversion = np.array(((1, 0, 0), (0, 0, 1), (0, -1, 0)), dtype=float)
    doc, access = read_glb(ROOT / "prototype/assets/characters/hero_quality_0.glb")
    skin = doc["skins"][0]
    binds = access(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    manifest = {"blender": bpy.app.version_string,
                "source": "Bundled MakeHuman CC0 finger joints and original skin weights; original pose authored here",
                "glbs_changed": False, "runtime_bones_added": 0, "finger_angles_degrees": {}, "lods": []}
    for side in ("L", "R"):
        lower = side.lower()
        shoulder = Vector(original[list(groups[f"joint-{lower}-shoulder"])].mean(axis=0))
        arm = Matrix.Translation(shoulder) @ Matrix.Rotation(math.radians(18) * (1 if side == "L" else -1), 4, "Y") @ Matrix.Translation(-shoulder)
        hand_bind = next(i for i, node in enumerate(skin["joints"]) if doc["nodes"][node]["name"] == "Hand_" + side)
        rest_hand = np.linalg.inv(binds[hand_bind])
        inward = Vector(conversion.T @ rest_hand[:3, 0] * (-1 if side == "L" else 1))
        for finger in range(1, 6):
            joints = [arm @ Vector(original[list(groups[f"joint-{lower}-finger-{finger}-{joint}"])].mean(axis=0)) for joint in range(1, 5)]
            angles = [65, 75, 45] if finger == 1 else [76, 92, 58]
            manifest["finger_angles_degrees"][f"{finger}.{side}"] = angles
            parent = Matrix.Identity(4)
            for segment, angle in enumerate(angles, 1):
                start, end = joints[segment - 1:segment + 1]
                direction = (end - start).normalized()
                axis = direction.cross(inward).normalized()
                transform = parent @ Matrix.Translation(start) @ Matrix.Rotation(math.radians(angle), 4, axis) @ Matrix.Translation(-start)
                parent = transform
                entries = anatomy["facial_weights"].get(f"finger{finger}-{segment}.{side}", [])
                if not entries:
                    raise RuntimeError("Missing original anatomical finger weights")
                matrix = np.array(transform)
                for index, weight in entries:
                    point = points[index]
                    deltas[index] += ((matrix[:3, :3] @ point + matrix[:3, 3]) - point) * weight
                    rotations[index] += (matrix[:3, :3] - np.eye(3)) * weight
    tree = KDTree(len(groups["body"]))
    for index in groups["body"]:
        tree.insert(Vector(points[index]), index)
    tree.balance()
    with tempfile.TemporaryDirectory(prefix="imperathen-hand-shapes-", dir="/dev/shm") as temporary:
        temporary = Path(temporary)
        payloads = []
        for level in range(4):
            path = ROOT / f"prototype/assets/characters/hero_quality_{level}.glb"
            document, accessor = read_glb(path)
            skin = document["skins"][0]
            hands = [i for i, node in enumerate(skin["joints"]) if document["nodes"][node]["name"] in ("Hand_L", "Hand_R")]
            body = next(mesh for mesh in document["meshes"] if mesh.get("name") == "HeroBody")
            records = []
            for primitive in body["primitives"]:
                attributes = primitive["attributes"]
                vertices = accessor(attributes["POSITION"])
                joints = accessor(attributes["JOINTS_0"])
                weights = accessor(attributes["WEIGHTS_0"])
                hand_weights = np.sum(weights * np.isin(joints, hands), axis=1)
                for point, weight in zip(vertices, hand_weights):
                    if weight < 0.03:
                        continue
                    source = conversion.T @ point
                    neighbors = tree.find_n(Vector(source), 3)
                    factors = np.array([1 / max(distance, 0.000001) ** 2 for _, _, distance in neighbors])
                    factors /= factors.sum()
                    delta = sum(deltas[index] * factor for (_, index, _), factor in zip(neighbors, factors))
                    rotation = sum(rotations[index] * factor for (_, index, _), factor in zip(neighbors, factors))
                    if np.linalg.norm(delta) < 0.000001:
                        continue
                    delta = conversion @ delta
                    rotation = conversion @ rotation @ conversion.T
                    quaternion = Matrix(rotation.tolist()).to_quaternion().normalized()
                    records.append([*map(float, point), *map(float, delta), quaternion.x, quaternion.y, quaternion.z, quaternion.w])
            destination = f"res://assets/characters/hero_hand_grip_{level}.res"
            payload = {"destination": destination, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "records": records}
            target = temporary / f"grip-{level}.json"
            target.write_text(json.dumps(payload))
            payloads.append(str(target))
            manifest["lods"].append({"lod": level, "records": len(records), "source_sha256": payload["source_sha256"], "resource": destination})
        result = subprocess.run(["godot", "--headless", "--path", str(ROOT / "prototype"), "--script",
                                 "res://tests/compile_hand_grips.gd", "--", *payloads], text=True, capture_output=True, timeout=60)
        print(result.stdout)
        if result.returncode or "SCRIPT ERROR" in result.stdout + result.stderr or "HAND_GRIPS_COMPILED" not in result.stdout:
            raise RuntimeError(result.stderr + result.stdout)
    output = ROOT / "docs/19_motion_combat/evidence/motion/hand-grip-build.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + "\n")
    print("HAND_GRIP_BUILD_COMPLETE", json.dumps(manifest))


if __name__ == "__main__":
    main()
