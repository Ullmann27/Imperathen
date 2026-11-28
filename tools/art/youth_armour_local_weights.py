#!/usr/bin/env python3
"""Isolated candidate for the measured armoured youth LOD0 edge, not a release."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree
from youth_cap_binding import pose_subset, weight_signature, weight_delta

CHARACTERS = Path(__file__).resolve().parents[1] / "characters"
NAMES = ("Shin_L", "Shin_R", "Thigh_L", "Thigh_R")
REST = np.array([[-.028654, .559037, .128714], [-.026529, .556183, .127301]])
EXPECTED = np.array([[.1335622221, .1693446189, .2946669757, .4024109244],
                     [.1917143464, .1208819747, .4306401014, .2567330301]])
REST_LENGTH = .0038287178613
POSITION_EPS = 2e-6
WEIGHT_EPS = 2e-6
SEAM_EPS = 2e-5
NUMERIC_EPS = 1e-6


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def topology(indices, count):
    if len(indices) % 3 or np.any(indices < 0) or np.any(indices >= count):
        raise ValueError("Invalid indexed triangle topology")
    tri = indices.reshape(-1, 3)
    return np.unique(np.sort(np.concatenate([tri[:, [0, 1]], tri[:, [1, 2]],
                                             tri[:, [2, 0]]]), axis=1), axis=0)


def locate(position, joints, weights, names, edges):
    """Match measured Godot vertex signatures, never assume importer index order."""
    if len(set(names)) != len(names) or not set(NAMES) <= set(names):
        raise ValueError("Missing or ambiguous named skin joints")
    named = [names.index(name) for name in NAMES]
    signatures = [dict(zip(named, row)) for row in EXPECTED]
    pairs = set()
    for z in (1, -1):
        wanted = REST * np.array([1., 1., z])
        groups = []
        for i in range(2):
            nearby = np.flatnonzero(np.linalg.norm(position - wanted[i], axis=1) <= POSITION_EPS)
            groups.append([int(v) for v in nearby
                           if weight_delta(weight_signature(joints[v], weights[v]), signatures[i]) <= WEIGHT_EPS])
        for a in groups[0]:
            for b in groups[1]:
                if abs(np.linalg.norm(position[a] - position[b]) - REST_LENGTH) <= POSITION_EPS and np.any(
                        np.all(edges == sorted((a, b)), axis=1)):
                    pairs.add((a, b))
    if len(pairs) != 1:
        raise ValueError(f"Expected one measured connected edge, found {len(pairs)}")
    return next(iter(pairs)), named


def candidate_weights(position, joints, weights, pair, named):
    """Only average the two measured bindings; preserve coincident split seams."""
    tree = cKDTree(position)
    original = [weight_signature(joints[i], weights[i]) for i in pair]
    mean = {j: (original[0][j] + original[1][j]) / 2 for j in named}
    total = sum(mean.values())
    mean = {j: w / total for j, w in mean.items()}
    revised = weights.copy()
    changed = set()
    seams = []
    for endpoint, signature in zip(pair, original):
        for vertex in tree.query_ball_point(position[endpoint], SEAM_EPS):
            if weight_delta(weight_signature(joints[vertex], weights[vertex]), signature) > WEIGHT_EPS:
                raise ValueError("Ambiguous coincident seam; do not repair blindly")
            if len(set(joints[vertex])) != 4 or set(joints[vertex]) != set(named):
                raise ValueError("Unexpected local joint layout")
            revised[vertex] = [mean[j] for j in joints[vertex]]
            changed.add(int(vertex))
            if vertex != endpoint:
                seams.append((endpoint, int(vertex)))
    if not np.isfinite(revised).all() or np.any(revised < 0) or np.max(abs(revised.sum(1) - 1)) > .002:
        raise ValueError("Invalid candidate weights")
    return revised, sorted(changed), seams


def no_edge_regression(before, after, limits):
    if not np.isfinite(before).all() or not np.isfinite(after).all():
        return False
    # No newly severe edge and no increase of existing severe excess.
    return bool(np.all((before > limits) | (after <= limits)) and
                np.all(np.maximum(after-limits, 0) <= np.maximum(before-limits, 0) + NUMERIC_EPS))


def measure_local(rig, prim, revised, edges, changed, seams):
    affected = edges[np.isin(edges, changed).any(axis=1)]
    if not len(affected):
        raise ValueError("No actual affected triangles")
    ids = np.unique(affected)
    local = np.searchsorted(ids, affected)
    limits = 7 * np.linalg.norm(prim["position"][affected[:, 0]] -
                                prim["position"][affected[:, 1]], axis=1) + .03
    candidate = dict(prim, weight=revised)
    seam_ids = np.searchsorted(ids, np.array(seams, dtype=int).reshape(-1, 2))
    if len(seams) and not np.isin(np.array(seams), ids).all():
        raise ValueError("Coincident seam includes unused vertex")
    report = {"affected_edges": len(affected), "samples": 0, "clips": {}}
    for clip in rig.glb.document.get("animations", []):
        name = clip["name"]
        animation = rig.animation(name)
        n = max(1, math.ceil(animation["duration"] * 60))
        maxima = [0., 0.]
        for frame in range(n + 1):
            world = rig.globals(animation, animation["duration"] * frame / n)
            a = pose_subset(prim, ids, world)
            b = pose_subset(candidate, ids, world)
            before = np.linalg.norm(a[local[:, 0]] - a[local[:, 1]], axis=1)
            after = np.linalg.norm(b[local[:, 0]] - b[local[:, 1]], axis=1)
            if not no_edge_regression(before, after, limits):
                raise ValueError(f"New or worsened severe local edge: {name} frame {frame}")
            if len(seams):
                gap0 = np.linalg.norm(a[seam_ids[:, 0]] - a[seam_ids[:, 1]], axis=1)
                gap1 = np.linalg.norm(b[seam_ids[:, 0]] - b[seam_ids[:, 1]], axis=1)
                if np.any(gap1 > gap0 + SEAM_EPS):
                    raise ValueError(f"Split seam gap regression: {name} frame {frame}")
            maxima[0] = max(maxima[0], float(np.maximum(before-limits, 0).max()))
            maxima[1] = max(maxima[1], float(np.maximum(after-limits, 0).max()))
            report["samples"] += len(affected)
        report["clips"][name] = {"before_excess_m": maxima[0], "after_excess_m": maxima[1]}
    if not report["samples"]:
        raise ValueError("No animation sample")
    return report


def build(source, destination, expected_sha):
    sys.path.insert(0, str(CHARACTERS))
    from ground_death_clip import Glb, Rig
    from build_youth_civil_outfit import Glb as Writer
    if source.resolve() == destination.resolve() or destination.exists() or sha(source) != expected_sha:
        raise ValueError("Source identity mismatch or destination already exists")
    glb = Glb(source)
    rig = Rig(glb)
    nodes = [i for i, n in enumerate(rig.nodes) if n.get("name") == "MeshyYouthBody"]
    if len(nodes) != 1:
        raise ValueError("Expected one MeshyYouthBody")
    node = nodes[0]
    mesh_id = rig.nodes[node]["mesh"]
    primitive = glb.document["meshes"][mesh_id]["primitives"][0]
    prim = next(p for p in rig.primitives if p["node"] == node)
    attrs = primitive["attributes"]
    if primitive.get("mode", 4) != 4 or "indices" not in primitive or "WEIGHTS_1" in attrs:
        raise ValueError("Unexpected body topology/influences")
    accessor = glb.document["accessors"][attrs["WEIGHTS_0"]]
    if accessor["componentType"] != 5126 or accessor.get("normalized") or accessor.get("sparse"):
        raise ValueError("Expected unquantized float skin weights")
    names = [rig.nodes[j].get("name") for j in prim["joints"]]
    edges = topology(glb.accessor(primitive["indices"]).astype(int).reshape(-1), len(prim["position"]))
    pair, named = locate(prim["position"], prim["joint_index"], prim["weight"], names, edges)
    revised, changed, seams = candidate_weights(prim["position"], prim["joint_index"], prim["weight"], pair, named)
    for other in rig.primitives:
        if other is prim:
            continue
        tree = cKDTree(other["position"])
        if any(tree.query_ball_point(prim["position"][v], SEAM_EPS) for v in changed):
            raise ValueError("Possible cross-primitive seam, requires manual review")
    measured = measure_local(rig, prim, revised, edges, changed, seams)
    writer = Writer(source.read_bytes())
    original_bytes = bytes(writer.b)
    new_weights = writer.append(revised.astype(np.float32), "VEC4", 5126, target=34962)
    writer.d["meshes"][mesh_id]["primitives"][0]["attributes"]["WEIGHTS_0"] = new_weights
    if bytes(writer.b[:len(original_bytes)]) != original_bytes:
        raise AssertionError("Original asset binary changed")
    destination.write_bytes(writer.encode())
    check = Glb(destination)
    expected = revised.astype(np.float32).astype(float)
    if not np.array_equal(check.accessor(new_weights), expected):
        raise AssertionError("Candidate round trip differs")
    untouched = np.ones(len(revised), dtype=bool)
    untouched[changed] = False
    if not np.array_equal(expected[untouched], prim["weight"][untouched]):
        raise AssertionError("Unrelated weights changed")
    return {"source_sha256": expected_sha, "candidate_sha256": sha(destination),
            "source_indices": list(pair), "changed_rows": changed, "split_seams": seams,
            "offline": measured, "status": "GODOT_REVIEW_REQUIRED"}


def read_result(path):
    lines = [line.split("YOUTH_OUTFIT_SKIN_RESULT ", 1)[1] for line in path.read_text().splitlines()
             if line.startswith("YOUTH_OUTFIT_SKIN_RESULT ")]
    if len(lines) != 1:
        raise ValueError("Expected one actual Godot skin result")
    return json.loads(lines[0])


def compare(before, after):
    if before["failures"] or after["failures"] or before["checks"] != after["checks"] or before["checks"] < 692:
        raise ValueError("Original Godot gate not preserved")
    a, b = before["result"], after["result"]
    if set(a) != {"armoured", "civil"} or set(a) != set(b):
        raise ValueError("Incomplete outfit coverage")
    for outfit in a:
        if set(a[outfit]) != {"lod0", "lod2"} or set(a[outfit]) != set(b[outfit]):
            raise ValueError("Incomplete LOD coverage")
        for lod in a[outfit]:
            old, new = a[outfit][lod], b[outfit][lod]
            if set(old["per_clip"]) != set(new["per_clip"]) or old["clips"] != 19 or new["clips"] != 19:
                raise ValueError("Incomplete clip coverage")
            for name, row in old["per_clip"].items():
                candidate = new["per_clip"][name]
                if not math.isfinite(candidate["lowest_sole_m"]) or abs(row["lowest_sole_m"] - candidate["lowest_sole_m"]) >= .0005:
                    raise ValueError(f"Sole regression {outfit}/{lod}/{name}")
                if candidate["skin_edge_violations"] != 0:
                    raise ValueError(f"Residual or new severe skin edge {outfit}/{lod}/{name}")
                if (outfit, lod) != ("armoured", "lod0") and row != candidate:
                    raise ValueError("Unmodified outfit or LOD report changed")
    if a["armoured"]["lod0"]["skin_edge_violations"] != 14:
        raise ValueError("Prior 14-edge baseline not reproduced")
    return {"status": "NUMERIC_REVIEW_PASSED", "before": 14, "after": 0,
            "checks_per_version": before["checks"], "visual_device_review": "pending"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("source", type=Path)
    b.add_argument("destination", type=Path)
    b.add_argument("--expected-sha", required=True)
    c = sub.add_parser("compare")
    c.add_argument("before", type=Path)
    c.add_argument("after", type=Path)
    args = parser.parse_args()
    result = build(args.source, args.destination, args.expected_sha) if args.command == "build" else compare(read_result(args.before), read_result(args.after))
    print("YOUTH_ARMOUR_LOCAL " + json.dumps(result, allow_nan=False))


if __name__ == "__main__":
    main()
