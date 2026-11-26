"""Put the frontier kit's rivets on the plates they belong to (glTF post-export step).

build_frontier_people.py adds rivets to the military kit and binds them
rigidly to the Spine. Several of them sit on the Arm-bound shoulder guards
(1.2-2.2 cm from the guard, 3.6-9.3 cm from the nearest Spine plate). When
the arm rises (shooting, shield poses) the guard moves away and the rivets
stay hanging in the air, up to 8 cm from any plate; this is visible in the
engine frames of the shooting legionary.

This step finds small decoration islands of FrontierRomanKit (bounding
diagonal <= 3 cm) that are rigidly bound to one joint but sit within 2.5 cm
of a plate (diagonal >= 8 cm) of another joint, while every plate of their
own joint is at least 1.5 times farther away. Each such island takes the
complete skin weights of the plate vertex nearest to its centre, so it moves
rigidly with that plate. An island is rebound only if its largest lift-off
from the plates over all exported clips does not grow.

The chest rivets are bound to the Spine like their breastplate but were
placed at a fixed depth: they hover 0.8-3.3 cm in front of the curved plate
already in the bind pose. Every rigid decoration that hovers 1 mm to 4 cm
off a plate of its own joint is moved along the shortest way onto that plate
(0.5 mm embedded); only its POSITION values change.

The original binary is verified before writing and a marker in the mesh
extras makes the step idempotent. Exports without such islands stay
byte-identical.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ground_death_clip import Glb, Rig  # noqa: E402
from smooth_frontier_skirt_seam import _append_joints, _frames, _pose, _triangles  # noqa: E402

MARKER = "imperathen_kit_rivet_binding"
KIT = "FrontierRomanKit"
DECORATION_M = .03
PLATE_M = .08
NEAR_M = .025
OWN_RATIO = 1.5
WELD_M = 1e-5
# Rigid decorations hovering 1 mm .. 4 cm off a plate of their own joint are
# moved onto it, 0.5 mm embedded.
SNAP_MIN_M = .001
SNAP_MAX_M = .04
SNAP_EMBED_M = .0005


def _islands(rest: np.ndarray, triangles: np.ndarray) -> list:
    _, welded = np.unique(np.round(rest / WELD_M).astype(np.int64), axis=0, return_inverse=True)
    welded = welded.reshape(-1)
    parent = np.arange(int(welded.max()) + 1)

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for triangle in welded[triangles.reshape(-1, 3)]:
        for a, b in ((triangle[0], triangle[1]), (triangle[1], triangle[2])):
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
    groups = {}
    for vertex, w in enumerate(welded):
        groups.setdefault(find(w), []).append(vertex)
    return [np.array(vertices) for vertices in groups.values()]


def _nearest(points: np.ndarray, target: np.ndarray) -> tuple[float, int]:
    distance = np.linalg.norm(points - target, axis=1)
    index = int(distance.argmin())
    return float(distance[index]), index


def _closest_on_triangles(p: np.ndarray, a: np.ndarray, b: np.ndarray, c: np.ndarray) -> np.ndarray:
    """Closest point to p on each triangle (Ericson, Real-Time Collision Detection 5.1.5)."""
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = (ab * ap).sum(1), (ac * ap).sum(1)
    bp = p - b
    d3, d4 = (ab * bp).sum(1), (ac * bp).sum(1)
    cp = p - c
    d5, d6 = (ab * cp).sum(1), (ac * cp).sum(1)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    out = np.empty_like(a)
    done = np.zeros(len(a), bool)

    def take(mask, value):
        nonlocal done
        mask = mask & ~done
        out[mask] = value[mask] if value.ndim == 2 else value
        done |= mask
    take((d1 <= 0) & (d2 <= 0), a)
    take((d3 >= 0) & (d4 <= d3), b)
    with np.errstate(divide="ignore", invalid="ignore"):
        v = d1 / (d1 - d3)
        take((vc <= 0) & (d1 >= 0) & (d3 <= 0), a + v[:, None] * ab)
        take((d6 >= 0) & (d5 <= d6), c)
        w = d2 / (d2 - d6)
        take((vb <= 0) & (d2 >= 0) & (d6 <= 0), a + w[:, None] * ac)
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        take((va <= 0) & ((d4 - d3) >= 0) & ((d5 - d6) >= 0), b + w[:, None] * (c - b))
        denominator = 1. / (va + vb + vc)
        v, w = vb * denominator, vc * denominator
        take(np.ones(len(a), bool), a + ab * v[:, None] + ac * w[:, None])
    return out


def rebind(path: Path, output: Path | None = None) -> dict:
    glb = Glb(path)
    rig = Rig(glb)
    doc = glb.document
    found = [p for p, primitive in enumerate(rig.primitives) if primitive["name"] == KIT]
    if not found:
        return {"path": str(path), "unchanged": "no military kit"}
    k = found[0]
    kit = rig.primitives[k]
    mesh = doc["meshes"][doc["nodes"][kit["node"]]["mesh"]]
    if MARKER in mesh.get("extras", {}):
        return {"path": str(path), "skipped": "already rebound", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    siblings = [p for p, primitive in enumerate(rig.primitives) if primitive["node"] == kit["node"]]
    triangles = _triangles(glb, kit["node"])[siblings.index(k)]
    rest = _pose(kit, rig.globals({"tracks": {}}, 0.), kit["joint_index"], kit["weight"])
    parts = _islands(rest, triangles)
    diagonal = [float(np.linalg.norm(rest[p].max(axis=0) - rest[p].min(axis=0))) for p in parts]
    plates = [p for p, d in zip(parts, diagonal) if d >= PLATE_M]
    report = {"path": str(path), "sha256_before": hashlib.sha256(path.read_bytes()).hexdigest(), "islands": []}
    if not plates:
        report["unchanged"] = "no kit plates at this level of detail"
        return report
    plate_vertices = np.concatenate(plates)
    weights = np.zeros((len(rest), len(kit["joints"])))
    for slot in range(4):
        np.add.at(weights, (np.arange(len(rest)), kit["joint_index"][:, slot]), kit["weight"][:, slot])
    dominant = weights.argmax(axis=1)
    names = [rig.nodes[j]["name"] for j in kit["joints"]]
    candidates = []
    for part, size in zip(parts, diagonal):
        if size > DECORATION_M or len(set(dominant[part].tolist())) != 1 or weights[part].max(axis=1).min() < .999:
            continue
        own = int(dominant[part[0]])
        centre = rest[part].mean(axis=0)
        distance, index = _nearest(rest[plate_vertices], centre)
        plate = int(plate_vertices[index])
        if dominant[plate] == own or distance > NEAR_M:
            continue
        same = plate_vertices[dominant[plate_vertices] == own]
        own_distance = _nearest(rest[same], centre)[0] if len(same) else float("inf")
        if own_distance < OWN_RATIO * distance:
            continue
        candidates.append((part, plate, distance, own_distance))
    frames = _frames(rig) if candidates else []
    joint_index, weight = kit["joint_index"].copy(), kit["weight"].copy()
    for part, plate, distance, own_distance in candidates:
        centre_rest = rest[part].mean(axis=0)
        gap_rest = _nearest(rest[plate_vertices], centre_rest)[0]
        trial_j, trial_w = kit["joint_index"].copy(), kit["weight"].copy()
        trial_j[part], trial_w[part] = kit["joint_index"][plate], kit["weight"][plate]
        lift_before = lift_after = 0.
        for world in frames:
            posed_plates = _pose(kit, world, kit["joint_index"], kit["weight"])[plate_vertices]
            before = _pose(kit, world, kit["joint_index"], kit["weight"])[part].mean(axis=0)
            after = _pose(kit, world, trial_j, trial_w)[part].mean(axis=0)
            lift_before = max(lift_before, _nearest(posed_plates, before)[0] - gap_rest)
            lift_after = max(lift_after, _nearest(posed_plates, after)[0] - gap_rest)
        entry = {"vertices": len(part), "centre": [round(float(v), 4) for v in centre_rest],
                 "from": names[int(dominant[part[0]])], "to": names[int(dominant[plate])],
                 "plate_distance_m": round(distance, 4), "own_plate_distance_m": round(own_distance, 4),
                 "lift_before_m": round(lift_before, 4), "lift_after_m": round(lift_after, 4)}
        entry["applied"] = lift_after <= lift_before
        if entry["applied"]:
            joint_index[part], weight[part] = kit["joint_index"][plate], kit["weight"][plate]
        report["islands"].append(entry)
    # Snap rigid decorations onto the surface of a plate that follows the same
    # joint, so they neither hover in front of it nor drift away from it.
    final = np.zeros_like(weights)
    for slot in range(4):
        np.add.at(final, (np.arange(len(rest)), joint_index[:, slot]), weight[:, slot])
    final_dominant = final.argmax(axis=1)
    plate_triangles = triangles.reshape(-1, 3)
    on_plate = np.zeros(len(rest), bool)
    on_plate[plate_vertices] = True
    plate_triangles = plate_triangles[on_plate[plate_triangles].all(axis=1)]
    positions = kit["position"].copy()
    snapped = []
    for part, size in zip(parts, diagonal):
        if size > DECORATION_M or len(set(final_dominant[part].tolist())) != 1 or final[part].max(axis=1).min() < .999:
            continue
        joint = int(final_dominant[part[0]])
        same = plate_triangles[(final_dominant[plate_triangles] == joint).all(axis=1)]
        if not len(same):
            continue
        a, b, c = rest[same[:, 0]], rest[same[:, 1]], rest[same[:, 2]]
        best = None
        for vertex in part:
            closest = _closest_on_triangles(rest[vertex], a, b, c)
            distance = np.linalg.norm(closest - rest[vertex], axis=1)
            index = int(distance.argmin())
            if best is None or distance[index] < best[0]:
                best = (float(distance[index]), int(vertex), closest[index])
        gap, vertex, target = best
        if gap <= SNAP_MIN_M or gap > SNAP_MAX_M:
            continue
        shift = (target - rest[vertex]) * (gap - SNAP_EMBED_M) / gap
        bind = rig.globals({"tracks": {}}, 0.)[kit["joints"][joint]] @ kit["ibm"][joint]
        positions[part] += np.linalg.inv(bind[:3, :3]) @ shift
        snapped.append({"vertices": len(part), "centre": [round(float(v), 4) for v in rest[part].mean(axis=0)],
                        "joint": names[joint], "gap_before_m": round(gap, 4), "gap_after_m": SNAP_EMBED_M})
    report["snapped"] = snapped
    rebound = [entry for entry in report["islands"] if entry["applied"]]
    if not rebound and not snapped:
        report["unchanged"] = "no rivet hovers or sits on a plate of another joint"
        return report
    if output is not False:
        primitive = mesh["primitives"][siblings.index(k)]
        if rebound:
            primitive["attributes"]["JOINTS_0"] = _append_joints(glb, joint_index)
            primitive["attributes"]["WEIGHTS_0"] = glb.append_accessor(weight.astype(np.float32), "VEC4")
        if snapped:
            primitive["attributes"]["POSITION"] = glb.append_accessor(positions.astype(np.float32), "VEC3")
        mesh.setdefault("extras", {})[MARKER] = {
            "tool": "tools/characters/rebind_frontier_kit_rivets.py",
            "rebound_islands": len(rebound),
            "max_lift_before_m": max((entry["lift_before_m"] for entry in rebound), default=0.),
            "max_lift_after_m": max((entry["lift_after_m"] for entry in rebound), default=0.),
            "snapped_islands": len(snapped),
            "max_gap_before_m": max((entry["gap_before_m"] for entry in snapped), default=0.)}
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
        report = rebind(path, False if args.check else None)
        reports.append(report)
        if "skipped" in report or "unchanged" in report:
            print(f"KIT_RIVETS {path} {report.get('skipped') or report.get('unchanged')}", flush=True)
            continue
        applied = [e for e in report["islands"] if e["applied"]]
        print(f"KIT_RIVETS {path} rebound {len(applied)} (lift "
              f"{max((e['lift_before_m'] for e in applied), default=0.):.4f} -> "
              f"{max((e['lift_after_m'] for e in applied), default=0.):.4f} m), snapped {len(report['snapped'])} "
              f"(gap up to {max((e['gap_before_m'] for e in report['snapped']), default=0.):.4f} m)", flush=True)
    if args.report:
        args.report.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
