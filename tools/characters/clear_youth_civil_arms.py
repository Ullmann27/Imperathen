#!/usr/bin/env python3
"""Keep the arms of the civilian youth out of the wool in every clip (D-032).

The ACCAD clips were captured on an adult and retargeted to the stocky 1.50 m
youth; in several of them a hand or forearm passes through the trunk (run arm
swing, the guard arm of the punches, the balancing hand of the side kick).
On the armoured original that reads as contact with rigid gear; through a wool
tunic it is a visible hole. This step runs after retarget_accad_youth.py on the
civilian LODs only and adds the smallest shoulder rotation that clears it:

  * per key of the Arm_L / Arm_R rotation track, the forearm/hand points of
    that side are tested against the posed garment (sleeves excluded);
  * a penetrating arm is turned about the shoulder joint around the axis of
    the contact torque until the points are clear;
  * the corrections are smoothed in time (cyclic for closed gait cycles) and
    re-verified, then written to the same keys of all four LODs.

Only the two Arm rotation tracks change. Key times, every other joint, the
pelvis, legs and feet (stride, sole calibration, grounding) are untouched.
The armoured original is never processed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_youth_civil_outfit import BORDER_M, OUTSIDE_REST_M, border_vertices, vertex_normals  # noqa: E402
from ground_death_clip import Glb, Rig, _quat_matrix  # noqa: E402

CLEAR_M = 0.003          # target: no probe point deeper than this
REACH_M = 0.08           # probe points this close to the wool are judged
MAX_ANGLE = math.radians(40.0)
STEP = math.radians(1.5)
SMOOTH_S = 0.07          # temporal smoothing of the correction
PASSES = 8
LIMB_PREFIX = ("Forearm", "ForearmTwist", "Hand", "Palm", "FingerCurl", "Thumb")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rotation(vector: np.ndarray) -> np.ndarray:
    angle = float(np.linalg.norm(vector))
    if angle < 1e-12:
        return np.eye(3)
    x, y, z = vector / angle
    k = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + math.sin(angle) * k + (1 - math.cos(angle)) * (k @ k)


def quaternion(vector: np.ndarray) -> np.ndarray:
    angle = float(np.linalg.norm(vector))
    if angle < 1e-12:
        return np.array([0.0, 0.0, 0.0, 1.0])
    return np.r_[vector / angle * math.sin(angle / 2), math.cos(angle / 2)]


def multiply(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def pure_rotation(matrix: np.ndarray) -> np.ndarray:
    u, _, vt = np.linalg.svd(matrix[:3, :3])
    return u @ vt


class Subset:
    """Vertices of one primitive, skinned on demand."""

    def __init__(self, primitive: dict, select: np.ndarray):
        self.joints = primitive["joints"]
        self.ibm = primitive["ibm"]
        self.position = np.c_[primitive["position"][select], np.ones(len(select))]
        self.index = primitive["joint_index"][select]
        self.weight = primitive["weight"][select]

    def skin(self, world: list) -> np.ndarray:
        joints = np.stack([world[j] @ self.ibm[k] for k, j in enumerate(self.joints)])
        out = np.zeros((len(self.position), 3))
        for slot in range(4):
            out += self.weight[:, slot, None] * np.einsum("nij,nj->ni", joints[self.index[:, slot]], self.position)[:, :3]
        return out


class Model:
    def __init__(self, path: Path):
        self.glb = Glb(path)
        self.rig = Rig(self.glb)
        doc = self.glb.document
        self.node = {n.get("name"): i for i, n in enumerate(doc["nodes"]) if n.get("name")}
        body = self.node["MeshyYouthBody"]
        prims = doc["meshes"][doc["nodes"][body]["mesh"]]["primitives"]
        ids = [i for i, p in enumerate(self.rig.primitives) if p["node"] == body]
        materials = [doc["materials"][p["material"]].get("name", "") for p in prims]
        if "YouthCivilWool" not in materials:
            raise ValueError(f"{path}: not a civilian youth LOD")
        g = materials.index("YouthCivilWool")
        garment = self.rig.primitives[ids[g]]
        shell = self.rig.primitives[ids[0]]
        names = [doc["nodes"][j]["name"] for j in shell["joints"]]
        tri = self.glb.accessor(prims[g]["indices"])[:, 0].astype(np.int64).reshape(-1, 3)
        rest = self.rig.globals({"tracks": {}}, 0.0)
        g_rest = Subset(garment, np.arange(len(garment["position"]))).skin(rest)
        arm_joints = [k for k, n in enumerate(names) if n.startswith(("Arm_", "UpperArmTwist_"))]
        sleeve = (garment["weight"] * np.isin(garment["joint_index"], arm_joints)).sum(1) > 0.5
        border = border_vertices(g_rest, tri)
        near_border = cKDTree(g_rest[border]).query(g_rest)[0] <= BORDER_M
        # Target surface: the wool without the sleeves (they move with the arm).
        self.target = np.flatnonzero(~sleeve)
        self.target_judged = ~near_border[self.target]
        keep = np.isin(tri, self.target).all(1)
        remap = np.full(len(g_rest), -1)
        remap[self.target] = np.arange(len(self.target))
        self.tri = remap[tri[keep]]
        self.garment = Subset(garment, self.target)
        normal = vertex_normals(g_rest[self.target], self.tri)
        tree = cKDTree(g_rest[self.target])
        s_rest = Subset(shell, np.arange(len(shell["position"]))).skin(rest)
        d, idx = tree.query(s_rest)
        sd = ((s_rest - g_rest[self.target][idx]) * normal[idx]).sum(1)
        self.probe = {}
        self.arm = {}
        self.subtree = {}
        for side in "LR":
            limb = [k for k, n in enumerate(names) if n.startswith(LIMB_PREFIX) and n.endswith("_" + side)]
            weight = (shell["weight"] * np.isin(shell["joint_index"], limb)).sum(1)
            select = np.flatnonzero((weight > 0.5) & (sd > OUTSIDE_REST_M))
            self.probe[side] = Subset(shell, select)
            self.arm[side] = self.node["Arm_" + side]
            nodes, stack = [], [self.arm[side]]
            while stack:
                i = stack.pop()
                nodes.append(i)
                stack.extend(doc["nodes"][i].get("children", []))
            self.subtree[side] = nodes

    def turned(self, world: list, side: str, vector: np.ndarray) -> list:
        """World matrices with the arm of `side` turned by a world-space rotation vector about its shoulder."""
        if not np.any(vector):
            return world
        pivot = world[self.arm[side]][:3, 3]
        m = np.eye(4)
        m[:3, :3] = rotation(vector)
        m[:3, 3] = pivot - m[:3, :3] @ pivot
        out = list(world)
        for i in self.subtree[side]:
            out[i] = m @ world[i]
        return out


class Frame:
    def __init__(self, model: Model, world: list):
        self.model = model
        self.world = world
        self.points = model.garment.skin(world)
        self.normal = vertex_normals(self.points, model.tri)
        self.tree = cKDTree(self.points)

    def contact(self, side: str, vector: np.ndarray):
        model = self.model
        p = model.probe[side].skin(model.turned(self.world, side, vector))
        d, i = self.tree.query(p)
        sd = ((p - self.points[i]) * self.normal[i]).sum(1)
        depth = np.where((d < REACH_M) & (sd < 0) & model.target_judged[i], -sd, 0.0)
        return depth, p, self.normal[i]

    def depth(self, side: str, vector: np.ndarray) -> float:
        depth, _, _ = self.contact(side, vector)
        return float(depth.max()) if len(depth) else 0.0

    def solve(self, side: str, start: np.ndarray) -> np.ndarray:
        """Smallest extension of `start` (world rotation vector) that clears the arm."""
        vector = start.copy()
        best = (self.depth(side, vector), vector.copy())
        if best[0] <= CLEAR_M:
            return vector
        pivot = self.world[self.model.arm[side]][:3, 3]
        while np.linalg.norm(vector) < MAX_ANGLE:
            depth, p, n = self.contact(side, vector)
            bad = depth > 0
            if not bad.any():
                break
            torque = (depth[bad, None] * np.cross(p[bad] - pivot, n[bad])).sum(0)
            norm = np.linalg.norm(torque)
            if norm < 1e-12:
                break
            vector = vector + STEP * torque / norm
            now = self.depth(side, vector)
            if now < best[0]:
                best = (now, vector.copy())
            if now <= CLEAR_M:
                break
        return best[1]


def smooth(values: np.ndarray, sigma: float, cyclic: bool) -> np.ndarray:
    if sigma < 0.3 or len(values) < 3:
        return values.copy()
    span = max(1, int(math.ceil(3 * sigma)))
    k = np.exp(-0.5 * (np.arange(-span, span + 1) / sigma) ** 2)
    k /= k.sum()
    if cyclic:
        body = values[:-1]                      # the last key repeats the first
        n = len(body)
        out = np.array([sum(w * body[(i + o) % n] for o, w in zip(range(-span, span + 1), k)) for i in range(n)])
        return np.concatenate([out, out[:1]])
    pad = np.pad(values, ((span, span), (0, 0)), mode="edge")
    return np.array([np.tensordot(k, pad[i:i + len(k)], axes=(0, 0)) for i in range(len(values))])


def solve_clip(model: Model, name: str) -> dict:
    """World-space corrections per Arm key, converted to the parent frame."""
    rig = model.rig
    clip = rig.animation(name)
    out = {}
    for side in "LR":
        track = clip["tracks"].get((model.arm[side], "rotation"))
        if track is None:
            continue
        times, values, _ = track
        frames = [Frame(model, rig.globals(clip, float(t))) for t in times]
        before = np.array([f.depth(side, np.zeros(3)) for f in frames])
        if before.max() <= CLEAR_M:
            out[side] = {"keys": len(times), "before_m": float(before.max()), "after_m": float(before.max()),
                         "max_angle_deg": 0.0, "local": None}
            continue
        cyclic = len(times) > 3 and abs(float(np.dot(values[0], values[-1]))) > 0.99999
        dt = float(np.median(np.diff(times)))
        sigma = SMOOTH_S / dt
        # The engine interpolates between keys: the halfway poses are held clear too.
        between = [Frame(model, rig.globals(clip, float(0.5 * (a + b)))) for a, b in zip(times[:-1], times[1:])]
        need = np.array([f.solve(side, np.zeros(3)) for f in frames])
        final = need
        for _ in range(PASSES):
            final = smooth(need, sigma, cyclic)
            grown = False
            for k, f in enumerate(frames):
                if f.depth(side, final[k]) > CLEAR_M:
                    solved = f.solve(side, final[k])
                    # Ask for the solved vector plus the amount smoothing took away.
                    need[k] = need[k] + (solved - final[k]) * 1.25
                    grown = True
            for k, f in enumerate(between):
                middle = 0.5 * (final[k] + final[k + 1])
                if f.depth(side, middle) > CLEAR_M:
                    more = (f.solve(side, middle) - middle) * 1.25
                    need[k] = need[k] + more
                    need[k + 1] = need[k + 1] + more
                    grown = True
            if not grown:
                break
        after = np.array([f.depth(side, final[k]) for k, f in enumerate(frames)]
                         + [f.depth(side, 0.5 * (final[k] + final[k + 1])) for k, f in enumerate(between)])
        parent = rig.parent[model.arm[side]]
        local = np.array([pure_rotation(f.world[parent]).T @ final[k] for k, f in enumerate(frames)])
        out[side] = {"keys": len(times), "before_m": float(before.max()), "after_m": float(after.max()),
                     "max_angle_deg": float(np.degrees(np.linalg.norm(final, axis=1).max())),
                     "cyclic": bool(cyclic), "local": local}
    return out


def apply(path: Path, output: Path, corrections: dict) -> None:
    model_glb = Glb(path)
    doc = model_glb.document
    node = {n.get("name"): i for i, n in enumerate(doc["nodes"]) if n.get("name")}
    for animation in doc.get("animations", []):
        per_side = corrections.get(animation["name"], {})
        for side, entry in per_side.items():
            if entry["local"] is None:
                continue
            channels = [c for c in animation["channels"]
                        if c["target"]["node"] == node["Arm_" + side] and c["target"]["path"] == "rotation"]
            if len(channels) != 1:
                raise ValueError(f"{path}: {animation['name']} needs exactly one Arm_{side} rotation channel")
            sampler = animation["samplers"][channels[0]["sampler"]]
            values = model_glb.accessor(sampler["output"])
            if len(values) != len(entry["local"]):
                raise ValueError(f"{path}: {animation['name']} Arm_{side} key count differs between LODs")
            turned = np.array([multiply(quaternion(v), q) for v, q in zip(entry["local"], values)])
            turned /= np.linalg.norm(turned, axis=1, keepdims=True)
            sampler["output"] = model_glb.append_accessor(turned, "VEC4")
    output.parent.mkdir(parents=True, exist_ok=True)
    model_glb.write(output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--input", type=Path, required=True, help="directory with the retargeted civilian LODs")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    paths = [args.input / f"hero_meshy_italia_{i}.glb" for i in range(4)]
    model = Model(paths[0])
    corrections, report = {}, {"tool": "tools/characters/clear_youth_civil_arms.py", "clear_m": CLEAR_M,
                               "solved_on": paths[0].name, "clips": {}}
    for animation in model.glb.document.get("animations", []):
        name = animation["name"]
        corrections[name] = solve_clip(model, name)
        report["clips"][name] = {side: {k: v for k, v in entry.items() if k != "local"}
                                 for side, entry in corrections[name].items()}
        print("YOUTH_CIVIL_ARMS", name, json.dumps(report["clips"][name]), flush=True)
    report["outputs"] = []
    for path in paths:
        target = args.output / path.name
        apply(path, target, corrections)
        report["outputs"].append({"path": target.name, "sha256": digest(target)})
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("YOUTH_CIVIL_ARMS_CLEARED", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
