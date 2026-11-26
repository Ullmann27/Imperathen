"""Soften the torn weight seam of the Meshy body exports (glTF post-export step).

build_meshy_people.py binds the Meshy bodies with the project's own
point-based weights. The point classifier does not see topology: on the axe
fighter the right front edge of the cloak, which lies over the hanging right
forearm, changes from about 0.9 Forearm_R/Hand_R to about 0.1 within one row
of 6-7 cm triangles at hip height. In attack and train the arm lifts the
cloak; those triangles stretch from about 0.06 m to more than 0.5 m
(skin_edge_violations of the motion gate, 18 per runtime family).

Taking the forearm out of the cloak was measured and rejected: the arm lies
under the cloak in the bind pose, so without that influence it comes up to
0.14 m out through the cloak in attack, train and block. The cloak keeps its
arm binding; only the sharp weight step is softened:

* the tearing edges are found on the exported raw clips with the gate's own
  criterion (posed length > 7 * rest length + 3 cm, 60 Hz);
* their vertices and two rings of neighbours (UV-seam duplicates welded) get
  the neighbour blend of smooth_frontier_skirt_seam.py (two rings, four
  passes, 0.35, inverse edge length);
* the result is accepted only if no edge of the body tears any more and no
  neighbouring point comes further out through the softened surface than
  before.

Only the JOINTS_0/WEIGHTS_0 values of MeshyBody are rewritten, in place and
with their original component types; every other byte of the binary is
verified before writing and a marker in the mesh extras makes the step
idempotent. Exports that do not tear stay byte-identical.
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
import smooth_frontier_skirt_seam as seam  # noqa: E402

MARKER = "imperathen_meshy_seam_smoothing"
BODY = "MeshyBody"
# Two rings: with one ring the cloak's inner layer comes up to 0.9 mm further
# out through the softened outer layer (measured, rejected by the check below).
RINGS = 2
PASSES = 4
# Neighbour check: unchanged points within this distance of a softened
# vertex, compared with their own rest offset along the surface normal.
CLEARANCE_RADIUS_M = .05
CLEARANCE_TOLERANCE_M = .0005


def _nearest(reference: np.ndarray, points: np.ndarray, chunk: int = 2048) -> tuple[np.ndarray, np.ndarray]:
    index = np.empty(len(points), np.int64)
    distance = np.empty(len(points))
    for start in range(0, len(points), chunk):
        squared = ((points[start:start + chunk, None, :] - reference[None, :, :]) ** 2).sum(axis=2)
        index[start:start + chunk] = squared.argmin(axis=1)
        distance[start:start + chunk] = np.sqrt(squared.min(axis=1))
    return distance, index


def _region(rest: np.ndarray, triangles: np.ndarray, torn: list) -> np.ndarray:
    """Vertex mask of the region seam._smoothed blends: torn welded vertices plus RINGS rings."""
    _, welded = np.unique(np.round(rest / seam.WELD_M).astype(np.int64), axis=0, return_inverse=True)
    welded = welded.reshape(-1)
    edges = seam._edges(welded[triangles])
    region = np.zeros(int(welded.max()) + 1, bool)
    region[welded[torn]] = True
    for _ in range(RINGS):
        grown = region.copy()
        grown[edges[:, 0][region[edges[:, 1]]]] = True
        grown[edges[:, 1][region[edges[:, 0]]]] = True
        region = grown
    return region[welded]


def _tearing(body: dict, frames: list, weights: tuple, edges: np.ndarray, rest_length: np.ndarray) -> tuple[int, list]:
    count, torn = 0, set()
    for world in frames:
        posed = seam._pose(body, world, *weights)
        length = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
        bad = length > rest_length * seam.TEAR_FACTOR + seam.TEAR_SLACK_M
        count += int(bad.sum())
        torn.update(edges[bad].reshape(-1).tolist())
    return count, sorted(torn)


def _through(body: dict, frames: list, weights: tuple, triangles: np.ndarray, region: np.ndarray,
             near: np.ndarray, rest_offset: np.ndarray) -> float:
    """Largest distance an unchanged neighbour comes out through the softened surface beyond its rest offset."""
    deepest = 0.
    for world in frames:
        posed = seam._pose(body, world, *weights)
        unchanged = seam._pose(body, world, body["joint_index"], body["weight"])[near]
        normal = seam._normals(posed, triangles)[region]
        _, nearest = _nearest(posed[region], unchanged)
        out = ((unchanged - posed[region][nearest]) * normal[nearest]).sum(axis=1) - np.maximum(rest_offset, 0.)
        deepest = max(deepest, float(out.max()))
    return deepest


def smooth(path: Path, output: Path | None = None) -> dict:
    glb = Glb(path)
    rig = Rig(glb)
    doc = glb.document
    found = [p for p, primitive in enumerate(rig.primitives) if primitive["name"] == BODY]
    if len(found) != 1:
        raise ValueError(f"Expected one {BODY} primitive in {path}")
    b = found[0]
    body = rig.primitives[b]
    mesh = doc["meshes"][doc["nodes"][body["node"]]["mesh"]]
    if MARKER in mesh.get("extras", {}):
        return {"path": str(path), "skipped": "already smoothed", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    siblings = [p for p, primitive in enumerate(rig.primitives) if primitive["node"] == body["node"]]
    triangles = seam._triangles(glb, body["node"])[siblings.index(b)]
    rest = seam._pose(body, rig.globals({"tracks": {}}, 0.), body["joint_index"], body["weight"])
    edges = seam._edges(triangles)
    rest_length = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    frames = seam._frames(rig)
    report = {"path": str(path), "sha256_before": hashlib.sha256(path.read_bytes()).hexdigest(),
              "body_vertices": len(rest)}
    tearing, torn = _tearing(body, frames, (body["joint_index"], body["weight"]), edges, rest_length)
    report["before"] = {"tearing": tearing}
    if not torn:
        report["unchanged"] = "body does not tear"
        return report
    smoothed_index, smoothed_weight, region_size = seam._smoothed(body, rest, triangles, torn, RINGS, PASSES)
    # _smoothed re-sorts every vertex's slots; compare effective weights and
    # keep the original slots wherever nothing changed.
    count, joints = len(rest), len(body["joints"])
    dense_before, dense_after = np.zeros((count, joints)), np.zeros((count, joints))
    for slot in range(4):
        np.add.at(dense_before, (np.arange(count), body["joint_index"][:, slot]), body["weight"][:, slot])
        np.add.at(dense_after, (np.arange(count), smoothed_index[:, slot]), smoothed_weight[:, slot])
    # _smoothed also averages every welded UV-seam duplicate of the mesh;
    # only the softened region (torn vertices plus rings) is taken over.
    changed = np.flatnonzero(_region(rest, triangles, torn) & (np.abs(dense_after - dense_before).max(axis=1) > 1e-6))
    joint_index, weight = body["joint_index"].copy(), body["weight"].copy()
    joint_index[changed], weight[changed] = smoothed_index[changed], smoothed_weight[changed]
    unchanged = np.setdiff1d(np.arange(len(rest)), changed)
    distance, nearest = _nearest(rest[changed], rest[unchanged])
    near = unchanged[distance < CLEARANCE_RADIUS_M]
    normal = seam._normals(rest, triangles)[changed]
    rest_offset = ((rest[near] - rest[changed][nearest[distance < CLEARANCE_RADIUS_M]])
                   * normal[nearest[distance < CLEARANCE_RADIUS_M]]).sum(axis=1)
    through = lambda weights: _through(body, frames, weights, triangles, changed, near, rest_offset)
    report["before"]["neighbour_through_m"] = through((body["joint_index"], body["weight"]))
    tearing_after, _ = _tearing(body, frames, (joint_index, weight), edges, rest_length)
    report["after"] = {"tearing": tearing_after, "neighbour_through_m": through((joint_index, weight))}
    report.update(smoothed_welded_vertices=region_size, changed_vertices=int(len(changed)),
                  torn_vertices_before=len(torn), checked_neighbours=int(len(near)))
    if tearing_after or report["after"]["neighbour_through_m"] > report["before"]["neighbour_through_m"] + CLEARANCE_TOLERANCE_M:
        raise ValueError(f"Rejected body seam smoothing for {path}: {report}")
    if output is not False:
        # Same accessors, same component types: the 76-vertex change must not
        # carry a second copy of every body weight in the mobile asset.
        primitive = mesh["primitives"][siblings.index(b)]
        glb.overwrite_accessor(primitive["attributes"]["JOINTS_0"], joint_index)
        glb.overwrite_accessor(primitive["attributes"]["WEIGHTS_0"], weight.astype(np.float32))
        mesh.setdefault("extras", {})[MARKER] = {
            "tool": "tools/characters/smooth_meshy_body_seam.py", "passes": PASSES, "rings": RINGS,
            "blend": seam.BLEND, "tearing_before": tearing, "tearing_after": tearing_after,
            "changed_vertices": int(len(changed))}
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
            print(f"MESHY_BODY_SEAM {path} {report.get('skipped') or report.get('unchanged')}", flush=True)
            continue
        print(f"MESHY_BODY_SEAM {path} tearing {report['before']['tearing']}->{report['after']['tearing']} "
              f"neighbour through {report['before']['neighbour_through_m']:.4f}->"
              f"{report['after']['neighbour_through_m']:.4f} m, {report['changed_vertices']} vertices", flush=True)
    if args.report:
        args.report.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
