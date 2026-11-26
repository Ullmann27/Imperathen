"""Ground the shared company death fall on the floor (glTF post-export step).

The company death pose (art/soldiers/build.py, reused by the village, frontier
and Meshy exports) rotates the pelvis by -86 degrees and lowers it by a fixed
0.715 m. That fixed drop never looked at the skinned body: half-way through
the fall the soles sink up to 0.2 m into the floor and slide up to 1 m
forward. build_hero.py corrects the same defect for the hero inside Blender
(fit_death_ground_contact). This module applies the rule to an exported GLB,
so every company-skeleton export shares it without rebuilding its sources:

* every skinned primitive is posed on the CPU from the exported glTF itself
  (linear blend skinning, glTF LINEAR/STEP interpolation, quaternion slerp);
* vertically, the lowest posed surface stays on the floor of the standing
  first pose;
* horizontally, all surface points inside the motion gate's 2 cm contact band
  keep their ground position as closely as one rigid translation allows, so
  feet and body roll over the floor instead of sliding.

Only the death Pelvis translation sampler is replaced (240 Hz, LINEAR). Mesh,
skin, morph, material and all other animation bytes stay unchanged; the
original bytes are verified before writing. A marker in the animation extras
makes the step idempotent.

Godot's default keyframe optimizer (scene import, AnimationPlayer node) is
lossy enough to undo this: it kept 22 of 289 keys and lowered the Meshy
pelvis by 1.3 cm in mid-fall. The .import files of these exports therefore
disable it ("PATH:AnimationPlayer" -> "optimizer/enabled": false); the import
then keeps its 30 fps bake within 0.3 mm of the grounded curve.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

import numpy as np

# The motion gate samples clips at 60 Hz (motion_quality_measurement.gd).
SAMPLE_HZ = 60
# The engine samples between keys at its own frame times and the rigid offset
# is not linear in time. Measured over all 54 exports (60/120/180/240 Hz key
# grids, read back at the gate's 60 Hz), 240 Hz gives the lowest residual
# slip in every family for about 4.6 KB per file.
KEY_HZ = 240
# Same export clearance and curve as the hero (build_hero.py): it covers the
# difference between the 60 Hz translation keys and the coarser rotation keys
# between samples, and is zero at both ends of the clip.
EXPORT_CLEARANCE_M = .003
FOOT_WEIGHT = .5
# The motion gate's support band (motion_skin_measurement.gd: 2 cm).
CONTACT_BAND_M = .02
MARKER = "imperathen_grounded_death"

_COMPONENTS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path: Path):
        data = path.read_bytes()
        magic, version, _ = struct.unpack_from("<4sII", data, 0)
        if magic != b"glTF" or version != 2:
            raise ValueError(f"{path}: not a glTF 2 binary")
        json_size, json_kind = struct.unpack_from("<II", data, 12)
        if json_kind != 0x4E4F534A:
            raise ValueError(f"{path}: JSON chunk missing")
        self.document = json.loads(data[20:20 + json_size])
        at = 20 + json_size
        bin_size, bin_kind = struct.unpack_from("<II", data, at)
        if bin_kind != 0x004E4942 or len(self.document["buffers"]) != 1 or self.document["buffers"][0].get("uri"):
            raise ValueError(f"{path}: expected one embedded binary buffer")
        self.binary = bytearray(data[at + 8:at + 8 + bin_size])
        self.original_binary = bytes(self.binary)
        self.path = path

    def accessor(self, index: int) -> np.ndarray:
        accessor = self.document["accessors"][index]
        if "sparse" in accessor:
            raise ValueError("Sparse accessors are not used by these exports")
        view = self.document["bufferViews"][accessor["bufferView"]]
        kind = _COMPONENTS[accessor["componentType"]]
        width = _WIDTH[accessor["type"]]
        count = accessor["count"]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        item = np.dtype(kind).itemsize * width
        stride = view.get("byteStride", item)
        raw = np.frombuffer(bytes(self.binary[start:start + stride * (count - 1) + item]), dtype=np.uint8)
        if stride != item:
            rows = np.lib.stride_tricks.as_strided(raw, shape=(count, item), strides=(stride, 1))
            raw = np.ascontiguousarray(rows).reshape(-1)
        values = raw.view(kind).reshape(count, width).astype(np.float64)
        if accessor.get("normalized"):
            values /= float(np.iinfo(kind).max)
        return values

    def append_accessor(self, values: np.ndarray, kind: str) -> int:
        values = np.asarray(values, dtype=np.float32)
        self.binary.extend(b"\0" * (-len(self.binary) % 4))
        offset = len(self.binary)
        self.binary.extend(values.tobytes())
        view = len(self.document["bufferViews"])
        self.document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": values.nbytes})
        accessor = len(self.document["accessors"])
        rows = values.reshape(len(values), -1)
        self.document["accessors"].append({"bufferView": view, "componentType": 5126, "count": len(rows), "type": kind,
                                           "min": [float(x) for x in rows.min(axis=0)],
                                           "max": [float(x) for x in rows.max(axis=0)]})
        return accessor

    def write(self, path: Path) -> None:
        if bytes(self.binary[:len(self.original_binary)]) != self.original_binary:
            raise AssertionError("Original glTF bytes changed")
        self.binary.extend(b"\0" * (-len(self.binary) % 4))
        self.document["buffers"][0]["byteLength"] = len(self.binary)
        encoded = json.dumps(self.document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        encoded += b" " * (-len(encoded) % 4)
        total = 12 + 8 + len(encoded) + 8 + len(self.binary)
        path.write_bytes(struct.pack("<4sIIII", b"glTF", 2, total, len(encoded), 0x4E4F534A) + encoded
                         + struct.pack("<II", len(self.binary), 0x004E4942) + bytes(self.binary))


def _quat_matrix(q: np.ndarray) -> np.ndarray:
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _slerp(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
    dot = float(np.dot(a, b))
    if dot < 0:
        b, dot = -b, -dot
    if dot > .9995:
        out = a + t * (b - a)
        return out / np.linalg.norm(out)
    theta = math.acos(min(1., dot))
    return (math.sin((1 - t) * theta) * a + math.sin(t * theta) * b) / math.sin(theta)


class Rig:
    def __init__(self, glb: Glb):
        self.glb = glb
        doc = glb.document
        self.nodes = doc["nodes"]
        self.parent = {child: index for index, node in enumerate(self.nodes) for child in node.get("children", [])}
        self.rest = []
        for node in self.nodes:
            if "matrix" in node:
                raise ValueError("Matrix nodes are not used by these exports")
            self.rest.append((np.array(node.get("translation", [0, 0, 0]), float),
                              np.array(node.get("rotation", [0, 0, 0, 1]), float),
                              np.array(node.get("scale", [1, 1, 1]), float)))
        self.order = []
        seen = set()

        def visit(index):
            if index in seen:
                return
            if index in self.parent:
                visit(self.parent[index])
            seen.add(index)
            self.order.append(index)
        for index in range(len(self.nodes)):
            visit(index)
        self.primitives = []
        for index, node in enumerate(self.nodes):
            if "mesh" not in node or "skin" not in node:
                continue
            skin = doc["skins"][node["skin"]]
            joints = skin["joints"]
            ibm = glb.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
            for primitive in doc["meshes"][node["mesh"]]["primitives"]:
                attributes = primitive["attributes"]
                if "JOINTS_1" in attributes:
                    raise ValueError("More than four influences are not used by these exports")
                self.primitives.append({
                    "node": index, "name": node.get("name", ""), "joints": joints, "ibm": ibm,
                    "position": glb.accessor(attributes["POSITION"]),
                    "joint_index": glb.accessor(attributes["JOINTS_0"]).astype(np.int64),
                    "weight": glb.accessor(attributes["WEIGHTS_0"])})
        if not self.primitives:
            raise ValueError("No skinned primitive found")
        names = [self.nodes[j].get("name") for j in self.primitives[0]["joints"]]
        self.pelvis = next(i for i, node in enumerate(self.nodes) if node.get("name") == "Pelvis")
        self.foot_mask = []
        for primitive in self.primitives:
            joint_names = [self.nodes[j].get("name") for j in primitive["joints"]]
            mask = {}
            for side in "LR":
                wanted = [k for k, name in enumerate(joint_names) if name in ("Foot_" + side, "Toe_" + side)]
                amount = np.zeros(len(primitive["position"]))
                for slot in range(4):
                    amount += np.where(np.isin(primitive["joint_index"][:, slot], wanted), primitive["weight"][:, slot], 0.)
                mask[side] = amount >= FOOT_WEIGHT
            self.foot_mask.append(mask)
        if not any(mask["L"].any() for mask in self.foot_mask) or not any(mask["R"].any() for mask in self.foot_mask):
            raise ValueError("Both feet need skinned vertices: " + ",".join(n for n in names if n))
        descendants = set()
        stack = [self.pelvis]
        while stack:
            index = stack.pop()
            descendants.add(index)
            stack.extend(self.nodes[index].get("children", []))
        for primitive in self.primitives:
            used = {primitive["joints"][j] for j in np.unique(primitive["joint_index"][primitive["weight"] > 0])}
            if not used <= descendants:
                raise ValueError(primitive["name"] + " is skinned to joints outside the Pelvis hierarchy")

    def animation(self, name: str) -> dict:
        matches = [a for a in self.glb.document.get("animations", []) if a.get("name") == name]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {name!r} animation")
        animation = matches[0]
        tracks = {}
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            interpolation = sampler.get("interpolation", "LINEAR")
            if interpolation == "CUBICSPLINE":
                raise ValueError("Cubic spline death channels are not used by these exports")
            tracks[(channel["target"]["node"], channel["target"]["path"])] = (
                self.glb.accessor(sampler["input"])[:, 0], self.glb.accessor(sampler["output"]), interpolation)
        return {"animation": animation, "tracks": tracks,
                "duration": max(float(times[-1]) for times, _, _ in tracks.values())}

    @staticmethod
    def sample(track, time: float, path: str) -> np.ndarray:
        times, values, interpolation = track
        if time <= times[0]:
            return values[0].copy()
        if time >= times[-1]:
            return values[-1].copy()
        k = int(np.searchsorted(times, time, side="right")) - 1
        if interpolation == "STEP":
            return values[k].copy()
        u = (time - times[k]) / (times[k + 1] - times[k])
        if path == "rotation":
            return _slerp(values[k], values[k + 1], u)
        return values[k] + u * (values[k + 1] - values[k])

    def globals(self, clip: dict, time: float, pelvis_translation=None) -> list:
        local = []
        for index, (t, r, s) in enumerate(self.rest):
            values = {"translation": t, "rotation": r, "scale": s}
            for path in values:
                track = clip["tracks"].get((index, path))
                if track is not None:
                    values[path] = self.sample(track, time, path)
            if index == self.pelvis and pelvis_translation is not None:
                values["translation"] = pelvis_translation
            matrix = np.eye(4)
            matrix[:3, :3] = _quat_matrix(values["rotation"]) * values["scale"]
            matrix[:3, 3] = values["translation"]
            local.append(matrix)
        world = [None] * len(self.nodes)
        for index in self.order:
            parent = self.parent.get(index)
            world[index] = local[index] if parent is None else world[parent] @ local[index]
        return world

    def skin(self, world: list) -> list:
        posed = []
        for primitive in self.primitives:
            joints = np.stack([world[j] @ primitive["ibm"][k] for k, j in enumerate(primitive["joints"])])
            position = np.c_[primitive["position"], np.ones(len(primitive["position"]))]
            out = np.zeros((len(position), 3))
            for slot in range(4):
                matrices = joints[primitive["joint_index"][:, slot]]
                out += primitive["weight"][:, slot, None] * np.einsum("nij,nj->ni", matrices, position)[:, :3]
            posed.append(out)
        return posed


def key_count(duration: float) -> int:
    """Intervals of the exact KEY_HZ key grid.

    Exported durations are float32 (1.2 s is stored as 1.2000000477), so a
    plain ceil would add a 74th key and shift every key off the 60 Hz grid.
    """
    return max(2, math.ceil(duration * KEY_HZ - 1e-4))


def _enclosing_centre(points: np.ndarray, iterations: int = 400) -> np.ndarray:
    """Centre of the smallest circle around 2D points (Badoiu-Clarkson)."""
    centre = (points.min(axis=0) + points.max(axis=0)) / 2
    for step in range(1, iterations + 1):
        far = points[int(np.argmax(((points - centre) ** 2).sum(axis=1)))]
        centre = centre + (far - centre) / (step + 1)
    return centre


def solve(rig: Rig, clip: dict, track, to_parent: np.ndarray) -> np.ndarray:
    """Pelvis translation keys of the grounded fall at KEY_HZ.

    Vertical: the lowest posed surface stays on the standing floor.
    Horizontal: every surface point inside the contact band keeps its ground
    position as closely as one rigid body translation allows (the centre of
    the smallest circle around the required offsets). Without any carried
    contact the instantaneous support point is held (rolling contact).
    Limb rotations are never changed.
    """
    count = max(2, key_count(clip["duration"]))
    times = [clip["duration"] * frame / count for frame in range(count + 1)]
    frames = [np.concatenate(rig.skin(rig.globals(clip, time))) for time in times]
    feet = np.concatenate([mask["L"] | mask["R"] for mask in rig.foot_mask])
    floor = float(frames[0][feet, 1].min())
    if float(frames[0][:, 1].min()) < floor - 1e-4:
        raise ValueError(f"A non-foot surface is {floor - float(frames[0][:, 1].min()):.4f} m below the standing soles")
    keys = []
    horizontal = np.zeros(2)
    anchors = np.full((len(frames[0]), 2), np.nan)
    for frame, (time, posed) in enumerate(zip(times, frames)):
        lift = floor - float(posed[:, 1].min()) + EXPORT_CLEARANCE_M * math.sin(math.pi * frame / count) ** 2
        band = posed[:, 1] + lift <= floor + CONTACT_BAND_M
        carried = band & ~np.isnan(anchors[:, 0])
        if carried.any():
            horizontal = _enclosing_centre(anchors[carried] - posed[carried][:, [0, 2]])
        elif frame:
            support = int(np.argmin(posed[:, 1]))
            horizontal = horizontal + frames[frame - 1][support, [0, 2]] - posed[support, [0, 2]]
        fresh = band & np.isnan(anchors[:, 0])
        anchors[fresh] = posed[fresh][:, [0, 2]] + horizontal
        anchors[~band] = np.nan
        keys.append(rig.sample(track, time, "translation") + to_parent @ np.array([horizontal[0], lift, horizontal[1]]))
    return np.array(keys)


def measure(rig: Rig, clip: dict, pelvis_keys=None) -> dict:
    """Sole/hull penetration and contact slip of the posed clip at 60 Hz.

    Mirrors the motion gate's surface rule (motion_skin_measurement.gd and
    motion_quality_measurement.gd): foot vertices inside the 2 cm band are
    anchored while they stay inside it. The same rule over every skinned
    vertex is reported as contact slip of the whole body.
    """
    count = max(2, math.ceil(clip["duration"] * SAMPLE_HZ))  # same as motion_quality_measurement.gd: ceili(seconds*HZ)
    if pelvis_keys is not None:
        key_track = (np.linspace(0., clip["duration"], len(pelvis_keys)), np.asarray(pelvis_keys), "LINEAR")
    floor = None
    feet = np.concatenate([mask["L"] | mask["R"] for mask in rig.foot_mask])
    anchors = None
    result = {"max_sole_penetration_m": 0., "max_sole_slip_m": 0., "max_hull_penetration_m": 0., "max_contact_slip_m": 0.}
    for frame in range(count + 1):
        time = clip["duration"] * frame / count
        # The new keys are read back like the engine reads them: as a LINEAR
        # track on their own grid, sampled at the gate's own sample times.
        pelvis = None if pelvis_keys is None else rig.sample(key_track, time, "translation")
        posed = np.concatenate(rig.skin(rig.globals(clip, time, pelvis)))
        if floor is None:
            floor = float(posed[feet, 1].min())
            anchors = np.full((len(posed), 2), np.nan)
        result["max_sole_penetration_m"] = max(result["max_sole_penetration_m"], floor - float(posed[feet, 1].min()))
        result["max_hull_penetration_m"] = max(result["max_hull_penetration_m"], floor - float(posed[:, 1].min()))
        band = posed[:, 1] <= floor + CONTACT_BAND_M
        fresh = band & np.isnan(anchors[:, 0])
        anchors[fresh] = posed[fresh][:, [0, 2]]
        anchors[~band] = np.nan
        slip = np.where(band, np.hypot(*(posed[:, [0, 2]] - anchors).T), 0.)
        result["max_sole_slip_m"] = max(result["max_sole_slip_m"], float(slip[feet].max()))
        result["max_contact_slip_m"] = max(result["max_contact_slip_m"], float(slip.max()))
    return result


def ground(path: Path, output: Path | None = None) -> dict:
    glb = Glb(path)
    rig = Rig(glb)
    clip = rig.animation("death")
    if MARKER in clip["animation"].get("extras", {}):
        return {"path": str(path), "skipped": "already grounded",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "grounded": clip["animation"]["extras"][MARKER]}
    rest_world = rig.globals({"tracks": {}}, 0.)
    track = clip["tracks"].get((rig.pelvis, "translation"))
    if track is None or rig.pelvis in rig.parent and any(
            (rig.parent[rig.pelvis], path_name) in clip["tracks"] for path_name in ("translation", "rotation", "scale")):
        raise ValueError("Expected an animated root Pelvis translation under a static rig node")
    parent = rig.parent.get(rig.pelvis)
    parent_world = rest_world[parent] if parent is not None else np.eye(4)
    to_parent = np.linalg.inv(parent_world[:3, :3])
    count = max(2, key_count(clip["duration"]))
    before = measure(rig, clip)
    keys = solve(rig, clip, track, to_parent)
    raises = [float((to_parent.T @ (k - rig.sample(track, clip["duration"] * i / count, "translation")))[1])
              for i, k in enumerate(keys)]
    after = measure(rig, clip, keys)
    times = np.array([[clip["duration"] * frame / count] for frame in range(count + 1)])
    target = output or path
    report = {"path": str(path), "sha256_before": hashlib.sha256(path.read_bytes()).hexdigest(),
              "keys": count + 1, "key_hz": KEY_HZ, "measured_hz": SAMPLE_HZ, "duration_s": clip["duration"],
              "method": "CPU linear blend skinning of every exported skinned primitive; lowest posed surface on the "
                        "floor of the standing first pose; smallest-circle rigid offset of all 2 cm band contacts",
              "maximum_floor_correction_m": max(raises),
              "endpoint_translation_delta_m": float(np.linalg.norm(keys[-1] - rig.sample(track, clip["duration"], "translation"))),
              "before": before, "after": after}
    if output is not False:
        animation = clip["animation"]
        input_accessor = glb.append_accessor(times, "SCALAR")
        replaced = {}

        def replace(node: int, path_name: str, values: np.ndarray, kind: str) -> None:
            channel = next(c for c in animation["channels"]
                           if c["target"]["node"] == node and c["target"]["path"] == path_name)
            replaced[rig.nodes[node]["name"] + "/" + path_name] = int(animation["samplers"][channel["sampler"]]["output"])
            channel["sampler"] = len(animation["samplers"])
            animation["samplers"].append({"input": input_accessor, "output": glb.append_accessor(values, kind),
                                          "interpolation": "LINEAR"})
        replace(rig.pelvis, "translation", keys, "VEC3")
        animation.setdefault("extras", {})[MARKER] = {
            "tool": "tools/characters/ground_death_clip.py", "key_hz": KEY_HZ, "keys": count + 1,
            "replaced_sampler_output_accessors": replaced,
            "max_sole_penetration_m": round(after["max_sole_penetration_m"], 6),
            "max_sole_slip_m": round(after["max_sole_slip_m"], 6)}
        glb.write(target)
        report["sha256_after"] = hashlib.sha256(target.read_bytes()).hexdigest()
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("glb", nargs="+", type=Path)
    parser.add_argument("--check", action="store_true", help="measure only, do not write")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    reports = []
    for path in args.glb:
        report = ground(path, False if args.check else None)
        reports.append(report)
        if "skipped" in report:
            print(f"DEATH_GROUND {path} skipped: {report['skipped']}")
            continue
        b, a = report["before"], report["after"]
        print(f"DEATH_GROUND {path} penetration {b['max_sole_penetration_m']:.4f}->{a['max_sole_penetration_m']:.4f} "
              f"slip {b['max_sole_slip_m']:.4f}->{a['max_sole_slip_m']:.4f} hull {b['max_hull_penetration_m']:.4f}->"
              f"{a['max_hull_penetration_m']:.4f} contact slip {b['max_contact_slip_m']:.4f}->{a['max_contact_slip_m']:.4f} "
              f"raise {report['maximum_floor_correction_m']:.4f}")
    if args.report:
        args.report.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
