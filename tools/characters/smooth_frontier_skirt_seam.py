"""Close the torn skirt seam of the frontier exports (glTF post-export step).

build_frontier_people.py copies the hero's skirt into every frontier
identity. The exported frontier skirts still carry the hero's older generic
point classifier: a few neighbouring centre-seam vertices are bound entirely
to opposite thighs. In marching, running, shooting and shield poses those
edges stretch from millimetres to more than 0.1 m (skin_edge_violations in
the motion gate, e.g. 637 in frontier_legionary_0 across its clips).

The hero's own correction (build_hero.fit_skirt_weights) was measured on the
frontier skirts and rejected: its 0.45 thigh share lets the knees and thighs
come up to 0.11 m through the hem. Smoothing the whole tunic
(fit_tunic_joint_weights) removes tunic tearing but lets the body show
through the sleeves more often; the tunic is left unchanged.

This step therefore only touches the skirt and only where it tears:

* the tearing edges are found on the exported raw clips with the gate's own
  criterion (posed length > 7 * rest length + 3 cm, 60 Hz);
* their vertices and one ring of neighbours (UV-seam duplicates welded) get
  four passes of the hero's neighbour blend (0.35, inverse edge length);
* the result is accepted only if no skirt edge tears any more and no leg or
  body point comes further through the skirt than before.

Only JOINTS_0/WEIGHTS_0 of HeroTunicSkirt are replaced; the original binary
is verified before writing and a marker in the mesh extras makes the step
idempotent. Exports whose skirt does not tear stay byte-identical.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ground_death_clip import Glb, Rig  # noqa: E402

MARKER = "imperathen_skirt_seam_smoothing"
SKIRT = "HeroTunicSkirt"
BODY = "HeroBody"
# Gate tearing criterion (motion_skin_measurement.gd).
TEAR_FACTOR = 7.
TEAR_SLACK_M = .03
SAMPLE_HZ = 60
# build_hero.fit_tunic_joint_weights neighbour blend, applied locally.
BLEND = .35
PASSES = 4
RINGS = 1
WELD_M = 1e-5
# Clearance check: body points within this distance of the skirt, compared
# with their own rest clearance along the skirt normal.
CLEARANCE_RADIUS_M = .05
CLEARANCE_TOLERANCE_M = .0005


def _triangles(glb: Glb, node: int) -> list:
    doc = glb.document
    return [glb.accessor(primitive["indices"])[:, 0].astype(np.int64)
            for primitive in doc["meshes"][doc["nodes"][node]["mesh"]]["primitives"]]


def _edges(triangles: np.ndarray) -> np.ndarray:
    t = triangles.reshape(-1, 3)
    edges = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    edges.sort(axis=1)
    edges = np.unique(edges, axis=0)
    return edges[edges[:, 0] != edges[:, 1]]


def _pose(primitive: dict, world: list, joint_index: np.ndarray, weight: np.ndarray) -> np.ndarray:
    matrices = np.stack([world[j] @ primitive["ibm"][k] for k, j in enumerate(primitive["joints"])])
    position = np.c_[primitive["position"], np.ones(len(primitive["position"]))]
    posed = np.zeros((len(position), 3))
    for slot in range(4):
        posed += weight[:, slot, None] * np.einsum("nij,nj->ni", matrices[joint_index[:, slot]], position)[:, :3]
    return posed


def _normals(points: np.ndarray, triangles: np.ndarray) -> np.ndarray:
    t = triangles.reshape(-1, 3)
    face = np.cross(points[t[:, 1]] - points[t[:, 0]], points[t[:, 2]] - points[t[:, 0]])
    normal = np.zeros_like(points)
    for corner in range(3):
        np.add.at(normal, t[:, corner], face)
    return normal / np.maximum(1e-12, np.linalg.norm(normal, axis=1))[:, None]


def _frames(rig: Rig) -> list:
    frames = []
    for animation in rig.glb.document.get("animations", []):
        clip = rig.animation(animation["name"])
        count = max(2, math.ceil(clip["duration"] * SAMPLE_HZ))
        frames.extend(rig.globals(clip, clip["duration"] * frame / count) for frame in range(count + 1))
    return frames


def _measure(skirt: dict, body: dict, frames: list, weights: tuple, edges: np.ndarray, rest_length: np.ndarray,
             triangles: np.ndarray, near: np.ndarray, rest_clearance: np.ndarray) -> dict:
    tearing, torn, deepest = 0, set(), 0.
    for world in frames:
        posed = _pose(skirt, world, *weights)
        length = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
        bad = length > rest_length * TEAR_FACTOR + TEAR_SLACK_M
        tearing += int(bad.sum())
        torn.update(edges[bad].reshape(-1).tolist())
        if len(near):
            points = _pose(body, world, body["joint_index"], body["weight"])[near]
            nearest = np.argmin(((points[:, None, :] - posed[None, :, :]) ** 2).sum(axis=2), axis=1)
            normal = _normals(posed, triangles)
            out = ((points - posed[nearest]) * normal[nearest]).sum(axis=1) - np.maximum(rest_clearance, 0.)
            deepest = max(deepest, float(out.max()))
    return {"tearing": tearing, "torn_vertices": sorted(torn), "body_through_skirt_m": deepest}


def _smoothed(skirt: dict, rest: np.ndarray, triangles: np.ndarray, torn: list,
              rings: int = RINGS, passes: int = PASSES) -> tuple[np.ndarray, np.ndarray, int]:
    count, joints = len(rest), len(skirt["joints"])
    values = np.zeros((count, joints))
    for slot in range(4):
        np.add.at(values, (np.arange(count), skirt["joint_index"][:, slot]), skirt["weight"][:, slot])
    _, welded = np.unique(np.round(rest / WELD_M).astype(np.int64), axis=0, return_inverse=True)
    welded = welded.reshape(-1)
    size = int(welded.max()) + 1
    shared, members = np.zeros((size, joints)), np.zeros(size)
    np.add.at(shared, welded, values)
    np.add.at(members, welded, 1.)
    shared /= members[:, None]
    points = np.zeros((size, 3))
    np.add.at(points, welded, rest)
    points /= members[:, None]
    edges = _edges(welded[triangles])
    first, last = edges[:, 0], edges[:, 1]
    region = np.zeros(size, bool)
    region[welded[torn]] = True
    for _ in range(rings):
        grown = region.copy()
        grown[first[region[last]]] = True
        grown[last[region[first]]] = True
        region = grown
    influence = 1. / np.maximum(.003, np.linalg.norm(points[first] - points[last], axis=1))
    totals = np.zeros(size)
    np.add.at(totals, first, influence)
    np.add.at(totals, last, influence)
    active = region & (totals > 0.)
    for _ in range(passes):
        neighbours = np.zeros_like(shared)
        np.add.at(neighbours, first, shared[last] * influence[:, None])
        np.add.at(neighbours, last, shared[first] * influence[:, None])
        shared[active] = (1. - BLEND) * shared[active] + BLEND * neighbours[active] / totals[active, None]
    values = shared[welded]
    chosen = np.argsort(values, axis=1)[:, -4:]
    weight = np.take_along_axis(values, chosen, axis=1)
    weight /= weight.sum(axis=1, keepdims=True)
    return chosen.astype(np.int64), weight, int(region.sum())


def _append_joints(glb: Glb, joint_index: np.ndarray) -> int:
    """Append a VEC4 UNSIGNED_SHORT JOINTS_0 accessor (glTF allows u8/u16 only)."""
    packed = np.ascontiguousarray(joint_index, dtype=np.uint16)
    glb.binary.extend(b"\0" * (-len(glb.binary) % 4))
    offset = len(glb.binary)
    glb.binary.extend(packed.tobytes())
    doc = glb.document
    doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": packed.nbytes})
    doc["accessors"].append({"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5123, "count": len(packed),
                             "type": "VEC4", "min": [int(v) for v in packed.min(axis=0)],
                             "max": [int(v) for v in packed.max(axis=0)]})
    return len(doc["accessors"]) - 1


def smooth(path: Path, output: Path | None = None) -> dict:
    glb = Glb(path)
    rig = Rig(glb)
    doc = glb.document
    found = [p for p, primitive in enumerate(rig.primitives) if primitive["name"] == SKIRT]
    if len(found) != 1:
        raise ValueError(f"Expected one {SKIRT} primitive in {path}")
    s = found[0]
    skirt = rig.primitives[s]
    mesh = doc["meshes"][doc["nodes"][skirt["node"]]["mesh"]]
    if MARKER in mesh.get("extras", {}):
        return {"path": str(path), "skipped": "already smoothed", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    body = next(primitive for primitive in rig.primitives if primitive["name"] == BODY)
    siblings = [p for p, primitive in enumerate(rig.primitives) if primitive["node"] == skirt["node"]]
    triangles = _triangles(glb, skirt["node"])[siblings.index(s)]
    rest_world = rig.globals({"tracks": {}}, 0.)
    rest = _pose(skirt, rest_world, skirt["joint_index"], skirt["weight"])
    rest_body = _pose(body, rest_world, body["joint_index"], body["weight"])
    distance = np.sqrt(((rest_body[:, None, :] - rest[None, :, :]) ** 2).sum(axis=2))
    near = np.flatnonzero(distance.min(axis=1) < CLEARANCE_RADIUS_M)
    normal = _normals(rest, triangles)
    nearest = distance[near].argmin(axis=1)
    rest_clearance = ((rest_body[near] - rest[nearest]) * normal[nearest]).sum(axis=1)
    edges = _edges(triangles)
    rest_length = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    frames = _frames(rig)
    measure = lambda weights: _measure(skirt, body, frames, weights, edges, rest_length, triangles, near, rest_clearance)
    before = measure((skirt["joint_index"], skirt["weight"]))
    report = {"path": str(path), "sha256_before": hashlib.sha256(path.read_bytes()).hexdigest(),
              "skirt_vertices": len(rest),
              "before": {key: before[key] for key in ("tearing", "body_through_skirt_m")}}
    if not before["torn_vertices"]:
        report["unchanged"] = "skirt does not tear"
        return report
    joint_index, weight, region = _smoothed(skirt, rest, triangles, before["torn_vertices"])
    after = measure((joint_index, weight))
    report.update(after={key: after[key] for key in ("tearing", "body_through_skirt_m")},
                  smoothed_welded_vertices=region, torn_vertices_before=len(before["torn_vertices"]))
    if after["tearing"] or after["body_through_skirt_m"] > before["body_through_skirt_m"] + CLEARANCE_TOLERANCE_M:
        raise ValueError(f"Rejected seam smoothing for {path}: {report}")
    if output is not False:
        primitive = mesh["primitives"][siblings.index(s)]
        primitive["attributes"]["JOINTS_0"] = _append_joints(glb, joint_index)
        primitive["attributes"]["WEIGHTS_0"] = glb.append_accessor(weight.astype(np.float32), "VEC4")
        mesh.setdefault("extras", {})[MARKER] = {
            "tool": "tools/characters/smooth_frontier_skirt_seam.py", "passes": PASSES, "rings": RINGS,
            "blend": BLEND, "tearing_before": before["tearing"], "tearing_after": after["tearing"]}
        target = output or path
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
        report = smooth(path, False if args.check else None)
        reports.append(report)
        if "skipped" in report or "unchanged" in report:
            print(f"SKIRT_SEAM {path} {report.get('skipped') or report.get('unchanged')}", flush=True)
            continue
        print(f"SKIRT_SEAM {path} tearing {report['before']['tearing']}->{report['after']['tearing']} "
              f"body through skirt {report['before']['body_through_skirt_m']:.4f}->"
              f"{report['after']['body_through_skirt_m']:.4f} m, {report['smoothed_welded_vertices']} vertices",
              flush=True)
    if args.report:
        args.report.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
