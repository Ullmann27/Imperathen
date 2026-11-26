#!/usr/bin/env python3
"""Offline motion check of the civilian youth outfit in every clip and LOD.

Poses the final runtime GLBs (after retarget_accad_youth.py) at 60 Hz in all
animations and measures, per LOD:
  * skin_edge_violations: the motion gate criterion (posed edge longer than
    7 x rest + 3 cm), on every primitive of the youth body;
  * body_through_garment_m: how far body points that lie under the wool at
    rest come out through it (beyond their rest offset), the "through"
    measure of smooth_frontier_skirt_seam.py / smooth_meshy_body_seam.py;
  * limb_into_garment_m: how deep visible hands/forearms/knees enter the
    wool from outside;
  * lowest_sole_m per clip, compared with the armoured original when given.
The garment is the primitive with material "YouthCivilWool". Points near the
garment's open borders (neckline, sleeve hems, skirt hem) are not judged by
the through/into measures, whose nearest-normal sign is undefined there.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ground_death_clip import Glb, Rig  # noqa: E402

TEAR_FACTOR = 7.0
TEAR_SLACK_M = 0.03
SAMPLE_HZ = 60
NEAR_M = 0.05           # judge only points this close to the posed wool
BORDER_M = 0.035        # ... and this far from its open borders
HIDDEN_REST_M = 0.004   # under the wool by at least this at rest
OUTSIDE_REST_M = 0.004  # outside the wool by at least this at rest
INTO_REACH_M = 0.08     # a limb point is judged while this close to the posed wool


def edges_of(triangles):
    t = triangles.reshape(-1, 3)
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    e.sort(axis=1)
    e = np.unique(e, axis=0)
    return e[e[:, 0] != e[:, 1]]


def vertex_normals(points, triangles):
    t = triangles.reshape(-1, 3)
    face = np.cross(points[t[:, 1]] - points[t[:, 0]], points[t[:, 2]] - points[t[:, 0]])
    normal = np.zeros_like(points)
    for corner in range(3):
        np.add.at(normal, t[:, corner], face)
    return normal / np.maximum(1e-12, np.linalg.norm(normal, axis=1))[:, None]


def border_vertices(points, triangles):
    _, weld = np.unique(np.round(points, 5), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    t = weld[triangles.reshape(-1, 3)]
    all_e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    all_e.sort(axis=1)
    keys, counts = np.unique(all_e, axis=0, return_counts=True)
    open_w = np.unique(keys[counts == 1].reshape(-1))
    return np.isin(weld, open_w)


def frames(rig):
    out = []
    for animation in rig.glb.document.get("animations", []):
        clip = rig.animation(animation["name"])
        count = max(2, math.ceil(clip["duration"] * SAMPLE_HZ))
        for k in range(count + 1):
            out.append((animation["name"], rig.globals(clip, clip["duration"] * k / count)))
    return out


def measure(path: Path, dump: Path | None = None, torso_proxy: bool = False) -> dict:
    glb = Glb(path)
    rig = Rig(glb)
    doc = glb.document
    body_node = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "MeshyYouthBody")
    prims = doc["meshes"][doc["nodes"][body_node]["mesh"]]["primitives"]
    triangles = [glb.accessor(p["indices"])[:, 0].astype(np.int64).reshape(-1, 3) for p in prims]
    materials = [doc["materials"][p["material"]].get("name", "") for p in prims]
    body_ids = [i for i, p in enumerate(rig.primitives) if p["node"] == body_node]
    skinned = [rig.primitives[i] for i in body_ids]
    if len(skinned) != len(prims):
        raise ValueError("Unexpected primitive layout")
    garment_ids = [i for i, m in enumerate(materials) if m == "YouthCivilWool"]
    rest_world = rig.globals({"tracks": {}}, 0.0)
    rest = rig.skin(rest_world)
    rest = [rest[i] for i in body_ids]
    edges = [edges_of(t.reshape(-1)) for t in triangles]
    rest_len = [np.linalg.norm(r[e[:, 0]] - r[e[:, 1]], axis=1) for r, e in zip(rest, edges)]
    joint_names = [doc["nodes"][j]["name"] for j in skinned[0]["joints"]]
    result = {"path": path.name, "materials": materials, "garment_primitives": garment_ids, "frames": 0,
              "skin_edge_violations": 0, "worst_edge": {}, "clips": {}}
    judge = bool(garment_ids) or torso_proxy
    g_select = None
    if judge:
        if garment_ids:
            g = garment_ids[0]
            g_tri = triangles[g]
        else:
            # Reference without a separate garment (the armoured original):
            # the trunk of the shell itself, i.e. the triangles skinned to the
            # trunk joints, stands in for the garment volume, so the same
            # limb probe measures how far the clips already drive the arms
            # and hands into the body before any outfit change.
            g = 0
            trunk = [k for k, n in enumerate(joint_names) if n in ("Pelvis", "Lumbar", "Spine", "Chest")]
            trunk_weight = (skinned[0]["weight"] * np.isin(skinned[0]["joint_index"], trunk)).sum(1)
            keep = (trunk_weight[triangles[0]] > 0.9).all(1)
            g_select, inverse = np.unique(triangles[0][keep], return_inverse=True)
            g_tri = inverse.reshape(-1, 3)
        g_rest = rest[g] if g_select is None else rest[g][g_select]
        border = border_vertices(g_rest, g_tri)
        border_tree = cKDTree(g_rest[border])
        g_norm = vertex_normals(g_rest, g_tri)
        tree = cKDTree(g_rest)
        body = 0
        b_rest = rest[body]
        d, idx = tree.query(b_rest)
        sd_rest = ((b_rest - g_rest[idx]) * g_norm[idx]).sum(1)
        far_border = border_tree.query(g_rest[idx])[0] > BORDER_M
        hidden = (d < NEAR_M) & (sd_rest < -HIDDEN_REST_M) & far_border
        if g_select is not None:
            hidden[:] = False
        weights = skinned[body]["weight"]
        limbs = [k for k, n in enumerate(joint_names) if n.startswith(("Forearm", "Hand", "Palm", "FingerCurl", "Thumb", "Shin", "Thigh"))]
        limb_weight = (weights * np.isin(skinned[body]["joint_index"], limbs)).sum(1)
        outside = (sd_rest > OUTSIDE_REST_M) & (limb_weight > 0.5) & (d < 0.25)
        if g_select is not None:
            outside[g_select] = False
        result.update(hidden_points=int(hidden.sum()), outside_limb_points=int(outside.sum()),
                      body_through_garment_m=0.0, limb_into_garment_m=0.0, worst_through={}, worst_into={})
        through_max = np.zeros(int(hidden.sum()))
        into_max = np.zeros(int(outside.sum()))
    for name, world in frames(rig):
        posed_all = rig.skin(world)
        posed = [posed_all[i] for i in body_ids]
        result["frames"] += 1
        clip = result["clips"].setdefault(name, {"frames": 0, "skin_edge_violations": 0, "lowest_sole_m": math.inf,
                                                  "body_through_garment_m": 0.0, "limb_into_garment_m": 0.0})
        clip["frames"] += 1
        for k, (p, e, r) in enumerate(zip(posed, edges, rest_len)):
            length = np.linalg.norm(p[e[:, 0]] - p[e[:, 1]], axis=1)
            excess = length - (r * TEAR_FACTOR + TEAR_SLACK_M)
            bad = excess > 0
            if bad.any():
                n = int(bad.sum())
                result["skin_edge_violations"] += n
                clip["skin_edge_violations"] += n
                worst = int(np.argmax(excess))
                if excess[worst] > result["worst_edge"].get("excess_m", 0):
                    result["worst_edge"] = {"clip": name, "primitive": k, "material": materials[k],
                                            "excess_m": float(excess[worst]), "rest_m": float(r[worst]),
                                            "vertices": e[worst].tolist()}
        for k, prim in enumerate(body_ids):
            feet = rig.foot_mask[prim]["L"] | rig.foot_mask[prim]["R"]
            if feet.any():
                clip["lowest_sole_m"] = min(clip["lowest_sole_m"], float(posed[k][feet, 1].min()))
        if judge:
            gp = posed[g] if g_select is None else posed[g][g_select]
            gn = vertex_normals(gp, g_tri)
            t = cKDTree(gp)
            bp = posed[0]
            if hidden.any():
                dd, ii = t.query(bp[hidden])
                sd = ((bp[hidden] - gp[ii]) * gn[ii]).sum(1)
                ok = dd < NEAR_M
                out = np.where(ok, sd, -1.0)
                through_max = np.maximum(through_max, out)
                m = int(np.argmax(out))
                if out[m] > clip["body_through_garment_m"]:
                    clip["body_through_garment_m"] = float(out[m])
                if out[m] > result["body_through_garment_m"]:
                    result["body_through_garment_m"] = float(out[m])
                    result["worst_through"] = {"clip": name, "vertex": int(np.flatnonzero(hidden)[m]),
                                               "rest": b_rest[np.flatnonzero(hidden)[m]].round(4).tolist()}
            if outside.any():
                dd, ii = t.query(bp[outside])
                sd = ((bp[outside] - gp[ii]) * gn[ii]).sum(1)
                near_border = border_tree.query(g_rest[ii])[0] <= BORDER_M
                depth = np.where((dd < INTO_REACH_M) & ~near_border & (sd < 0), -sd, 0.0)
                into_max = np.maximum(into_max, depth)
                m = int(np.argmax(depth))
                if depth[m] > clip["limb_into_garment_m"]:
                    clip["limb_into_garment_m"] = float(depth[m])
                if depth[m] > result["limb_into_garment_m"]:
                    result["limb_into_garment_m"] = float(depth[m])
                    result["worst_into"] = {"clip": name, "vertex": int(np.flatnonzero(outside)[m]),
                                            "rest": b_rest[np.flatnonzero(outside)[m]].round(4).tolist()}
    result["lowest_sole_m"] = min(c["lowest_sole_m"] for c in result["clips"].values())
    if judge and dump:
        # Per-point worst values in rest space, for locating a failure.
        np.savez(dump, hidden_rest=b_rest[hidden], through_max=through_max, outside_rest=b_rest[outside],
                 into_max=into_max, garment_rest=g_rest)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("glb", nargs="+", type=Path)
    parser.add_argument("--compare", nargs="*", type=Path, default=[], help="armoured GLBs in the same LOD order")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--max-through-m", type=float, default=0.01)
    parser.add_argument("--max-into-m", type=float, default=0.01)
    parser.add_argument("--dump", type=Path, help="write per-point worst values of the first GLB (npz)")
    args = parser.parse_args()
    report = {"criterion": {"tear": "posed > 7 x rest + 0.03 m", "sample_hz": SAMPLE_HZ,
                            "max_through_m": args.max_through_m, "max_into_m": args.max_into_m}, "lods": []}
    passed = True
    for k, path in enumerate(args.glb):
        r = measure(path, args.dump if k == 0 else None)
        if k < len(args.compare):
            base = measure(args.compare[k])
            r["armoured"] = {"skin_edge_violations": base["skin_edge_violations"], "lowest_sole_m": base["lowest_sole_m"],
                             "worst_edge": base["worst_edge"]}
            r["sole_delta_m"] = max(abs(r["clips"][c]["lowest_sole_m"] - base["clips"][c]["lowest_sole_m"]) for c in r["clips"])
            passed &= r["sole_delta_m"] < 1e-6
        passed &= r["skin_edge_violations"] == 0
        passed &= r.get("body_through_garment_m", 0) <= args.max_through_m and r.get("limb_into_garment_m", 0) <= args.max_into_m
        report["lods"].append(r)
        print("YOUTH_CIVIL_CHECK", path.name, json.dumps({x: r.get(x) for x in ("frames", "skin_edge_violations", "body_through_garment_m",
                                                                             "limb_into_garment_m", "lowest_sole_m", "sole_delta_m")}), flush=True)
    report["passed"] = bool(passed)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("YOUTH_CIVIL_CHECK_PASS" if passed else "YOUTH_CIVIL_CHECK_FAIL", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
