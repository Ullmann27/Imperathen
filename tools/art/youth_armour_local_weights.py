#!/usr/bin/env python3
"""Isolated candidate for the measured armoured youth LOD0 edge, not a release."""
from __future__ import annotations

import argparse
import hashlib
from itertools import permutations, product
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree
from scipy.optimize import minimize
from youth_cap_binding import pose_subset, weight_signature, weight_delta

CHARACTERS = Path(__file__).resolve().parents[1] / "characters"
NAMES = ("Shin_L", "Shin_R", "Thigh_L", "Thigh_R")
REST = np.array([[-.028654, .559037, .128714], [-.026529, .556183, .127301]])
EXPECTED = np.array([[.1335622221, .1693446189, .2946669757, .4024109244],
                     [.1917143464, .1208819747, .4306401014, .2567330301]])
EXPECTED_CODES = np.array([[8753, 11098, 19311, 26372],
                           [12564, 7922, 28222, 16825]], dtype=np.int64)
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


def godot_import_weight_codes(weights):
    """Exact four-influence float32 normalization and UINT16 packing.

    Godot 4.7.2-stable, ed1daf0bf001b61586d9930840f2f1394092c079:
    modules/gltf/gltf_document.cpp:1661-1682 normalizes in source-slot order.
    servers/rendering/rendering_server.cpp:839-854 truncates w*65535.
    Readback at 1649-1662 divides the stored integer by 65535.
    This is an encoding conversion, not a wider matching tolerance.
    """
    raw = np.asarray(weights, dtype=np.float32)
    if raw.ndim != 2 or raw.shape[1] != 4 or not np.isfinite(raw).all() or np.any(raw < 0):
        raise ValueError("Invalid source weights")
    total = np.zeros(len(raw), dtype=np.float32)
    for slot in range(4):
        total += raw[:, slot]
    normalized = np.zeros_like(raw)
    np.divide(raw, total[:, None], out=normalized, where=total[:, None] > 0)
    return np.clip(normalized * np.float32(65535), 0, 65535).astype(np.uint16).astype(np.int64)


def matching_edges(position, joints, weights, names, edges):
    """Match actual source topology and named skin bindings, not import indices.

    The engine may change vertex order, primitive order and coordinate axes.
    Enumerate only signed orthogonal axis permutations, with no free scale,
    translation, nearest-neighbor substitution, or tolerance increase.
    """
    if len(set(names)) != len(names) or not set(NAMES) <= set(names):
        raise ValueError("Missing or ambiguous named skin joints")
    if position.ndim != 2 or position.shape[1] != 3 or joints.shape != weights.shape or len(joints) != len(position) or joints.shape[1] != 4:
        raise ValueError("Unexpected four-influence vertex layout")
    if not np.isfinite(position).all() or not np.isfinite(weights).all() or np.any(weights < 0):
        raise ValueError("Nonfinite or negative source geometry/weights")
    named = [names.index(name) for name in NAMES]
    # Exactly the original L1 named-binding criterion; unrelated positive
    # influences contribute to the error and cannot be silently discarded.
    columns = np.stack([np.where(joints == j, weights, 0).sum(axis=1) for j in named], axis=1)
    unrelated = np.where(np.isin(joints, named), 0, weights).sum(axis=1)
    errors = [np.abs(columns - row).sum(axis=1) + unrelated for row in EXPECTED]
    codes = godot_import_weight_codes(weights)
    named_codes = np.stack([np.where(joints == j, codes, 0).sum(axis=1) for j in named], axis=1)
    unrelated_codes = np.where(np.isin(joints, named), 0, codes).sum(axis=1)
    code_errors = [np.abs(named_codes - row).sum(axis=1) + unrelated_codes for row in EXPECTED_CODES]
    # Require exact imported code equality and no positive unrelated raw
    # influence. The named source weights are retained for actual editing.
    groups = [set(map(int, np.flatnonzero((e == 0) & (unrelated == 0)))) for e in code_errors]
    transforms = [(axes, signs, REST[:, axes] * np.asarray(signs))
                  for axes in permutations(range(3))
                  for signs in product((-1., 1.), repeat=3)]
    result = {}
    connected = 0
    length_matches = 0
    min_position = math.inf
    min_length = math.inf
    for i, j in edges:
        i, j = int(i), int(j)
        for a, b in ((i, j), (j, i)):
            if a not in groups[0] or b not in groups[1]:
                continue
            connected += 1
            error = abs(float(np.linalg.norm(position[a] - position[b])) - REST_LENGTH)
            min_length = min(min_length, error)
            if error > POSITION_EPS:
                continue
            length_matches += 1
            points = position[[a, b]]
            for axes, signs, wanted in transforms:
                error = float(np.linalg.norm(points - wanted, axis=1).max())
                min_position = min(min_position, error)
                if error <= POSITION_EPS:
                    result.setdefault((a, b), []).append({
                        "axes": list(axes), "signs": list(signs),
                        "position_error_m": error})
    evidence = {"vertices": len(position),
                "weight_matches": [len(g) for g in groups],
                "minimum_binding_l1": [float(e.min()) if len(e) else None for e in errors],
                "minimum_import_code_l1": [int(e.min()) if len(e) else None for e in code_errors],
                "connected_weight_pairs": connected, "length_matches": length_matches,
                "minimum_length_error_m": min_length if math.isfinite(min_length) else None,
                "minimum_axis_position_error_m": min_position if math.isfinite(min_position) else None,
                "matched_pairs": len(result)}
    return result, named, evidence


def locate(position, joints, weights, names, edges):
    matches, named, evidence = matching_edges(position, joints, weights, names, edges)
    if len(matches) != 1:
        raise ValueError(f"Expected one measured connected edge, found {len(matches)}: {json.dumps(evidence, allow_nan=False)}")
    return next(iter(matches)), named

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


def solve_affine_weights(original, offsets, coefficients, bounds):
    """Minimize binding displacement under convex posed-edge constraints.

    Each edge is a 3D affine function of eight weights, four per endpoint.
    Add only currently violated constraints to the bounded active set, then
    independently re-evaluate every original sample. No relaxed constraints.
    """
    x0 = np.asarray(original, dtype=float).reshape(8)
    offsets = np.asarray(offsets, dtype=float)
    coefficients = np.asarray(coefficients, dtype=float)
    bounds = np.asarray(bounds, dtype=float)
    if (offsets.shape != (len(bounds), 3) or coefficients.shape != (len(bounds), 3, 8)
            or not len(bounds) or not np.isfinite(x0).all() or np.any(x0 < 0)
            or not np.isfinite(offsets).all() or not np.isfinite(coefficients).all()
            or not np.isfinite(bounds).all() or np.any(bounds <= 0)):
        raise ValueError("Invalid constrained skin problem")
    totals = x0.reshape(2, 4).sum(axis=1)
    if np.any(totals <= 0):
        raise ValueError("Empty source binding")
    x0 = (x0.reshape(2, 4) / totals[:, None]).reshape(8)
    # Dimensionless residuals keep short seam edges and metre-scale skin
    # edges comparably conditioned for the optimizer.
    offsets = offsets / bounds[:, None]
    coefficients = coefficients / bounds[:, None, None]
    equality = np.zeros((2, 8))
    equality[0, :4] = 1
    equality[1, 4:] = 1

    def residual(x, c, m):
        posed = c + np.einsum("mij,j->mi", m, x)
        return 1 - np.einsum("mi,mi->m", posed, posed)

    def objective(x):
        return .5 * float(np.dot(x-x0, x-x0))

    x = x0.copy()
    active = set()
    certified_nonconverged_steps = 0
    for iteration in range(32):
        values = residual(x, offsets, coefficients)
        if float(values.min()) >= 0.0:
            if np.max(abs(equality @ x - 1)) > 1e-8 or np.any(x < 0) or np.any(x > 1):
                raise ValueError("Constrained candidate outside weight simplex")
            return x.reshape(2, 4), {"constraints": len(bounds),
                    "active_constraints": len(active), "iterations": iteration,
                    "certified_nonconverged_steps": certified_nonconverged_steps,
                    "minimum_normalized_slack": float(values.min()),
                    "binding_displacement_l2": float(np.linalg.norm(x-x0))}
        worst = np.flatnonzero(values < 0.0)
        worst = worst[np.argsort(values[worst], kind="stable")]
        added = [int(i) for i in worst if int(i) not in active][:32]
        if not added:
            raise ValueError(f"Constrained skin did not satisfy active edges: slack {values.min():.9g}")
        active.update(added)
        ids = np.array(sorted(active), dtype=int)
        c, m = offsets[ids], coefficients[ids]
        constraints = [
            {"type": "eq", "fun": lambda w: equality @ w - 1,
             "jac": lambda w: equality},
            {"type": "ineq", "fun": lambda w: residual(w, c, m)-2e-6,
             "jac": lambda w: -2*np.einsum("mi,mij->mj",
                         c + np.einsum("mij,j->mi", m, w), m)}]
        result = minimize(objective, x, jac=lambda w: w-x0, method="SLSQP",
                          bounds=[(0., 1.)]*8, constraints=constraints,
                          options={"ftol": 1e-10, "maxiter": 300})
        # The optimizer status is not a feasibility certificate. SLSQP may
        # report a linesearch failure at a feasible numerical boundary.
        # The stricter internal margin above leaves room for arithmetic,
        # but the independent acceptance test never increases a bound.
        candidate = np.asarray(result.x, dtype=float)
        if (candidate.shape != (8,) or not np.isfinite(candidate).all()
                or np.any(candidate < 0) or np.any(candidate > 1)
                or np.max(abs(equality @ candidate-1)) > 1e-8
                or np.any(residual(candidate, c, m) < 0.0)):
            raise ValueError("No verified feasible local binding: " + str(result.message))
        if not result.success:
            certified_nonconverged_steps += 1
        x = candidate
    raise ValueError("Constrained skin exceeded bounded active-set iterations")


def constrained_candidate(rig, prim, edges, pair, named):
    """Keep both original endpoint identities and coincident seams locked."""
    _, changed, seams = candidate_weights(prim["position"], prim["joint_index"],
                                           prim["weight"], pair, named)
    groups = {pair[0]: 0, pair[1]: 1}
    for endpoint, vertex in seams:
        group = groups[endpoint]
        if vertex in groups and groups[vertex] != group:
            raise ValueError("Overlapping independent seam groups")
        groups[vertex] = group
    if set(groups) != set(changed):
        raise ValueError("Incomplete local seam mapping")
    affected = edges[np.isin(edges, changed).any(axis=1)]
    if not len(affected):
        raise ValueError("No actual affected triangles")
    ids = np.unique(affected)
    local = np.searchsorted(ids, affected)
    if any(v not in ids for v in changed):
        raise ValueError("Unused seam vertex")
    limits = 7*np.linalg.norm(prim["position"][affected[:, 0]] -
                             prim["position"][affected[:, 1]], axis=1)+.03
    # Every actual connecting edge between the two coincident endpoint
    # groups must meet the original threshold, not merely the worst frame.
    target = np.array([groups.get(int(a), -1) >= 0 and
                       groups.get(int(b), -1) >= 0 and groups[int(a)] != groups[int(b)]
                       for a, b in affected], dtype=bool)
    if not target.any():
        raise ValueError("Measured edge absent from affected topology")
    seam_local = np.searchsorted(ids, np.array(seams, dtype=int).reshape(-1, 2))
    original = np.array([[weight_signature(prim["joint_index"][v], prim["weight"][v])[j]
                          for j in named] for v in pair], dtype=float)
    offsets, coefficients, bounds = [], [], []
    positions = np.c_[prim["position"][ids], np.ones(len(ids))]
    for clip in rig.glb.document.get("animations", []):
        animation = rig.animation(clip["name"])
        count = max(1, math.ceil(animation["duration"]*60))
        for frame in range(count+1):
            world = rig.globals(animation, animation["duration"]*frame/count)
            baseline = pose_subset(prim, ids, world)
            constant = baseline.copy()
            affine = np.zeros((len(ids), 3, 8))
            matrices = np.stack([world[prim["joints"][j]] @ prim["ibm"][j] for j in named])
            for i, v in enumerate(ids):
                if int(v) not in groups:
                    continue
                group = groups[int(v)]
                constant[i] = 0
                affine[i, :, group*4:group*4+4] = (matrices @ positions[i])[:, :3].T
            before = np.linalg.norm(baseline[local[:, 0]]-baseline[local[:, 1]], axis=1)
            allowance = np.maximum(before, limits)
            # Strict target threshold plus a 0.15 mm numerical safety
            # margin for float32/UINT16 import, never increased tolerance.
            allowance[target] = limits[target]-.00015
            offsets.append(constant[local[:, 0]]-constant[local[:, 1]])
            coefficients.append(affine[local[:, 0]]-affine[local[:, 1]])
            bounds.append(allowance)
            if len(seams):
                gap = np.linalg.norm(baseline[seam_local[:, 0]]-baseline[seam_local[:, 1]], axis=1)
                offsets.append(constant[seam_local[:, 0]]-constant[seam_local[:, 1]])
                coefficients.append(affine[seam_local[:, 0]]-affine[seam_local[:, 1]])
                bounds.append(gap+SEAM_EPS*.5)
    solved, report = solve_affine_weights(original, np.concatenate(offsets),
                                          np.concatenate(coefficients), np.concatenate(bounds))
    revised = prim["weight"].copy()
    for v in changed:
        by_joint = dict(zip(named, solved[groups[v]]))
        revised[v] = [by_joint[j] for j in prim["joint_index"][v]]
    # Validate exactly the candidate that will be written, including
    # float32 conversion. The original Godot A/B remains mandatory.
    revised[changed] = revised[changed].astype(np.float32).astype(float)
    if not np.isfinite(revised).all() or np.any(revised < 0) or np.max(abs(revised.sum(1)-1)) > .002:
        raise ValueError("Invalid constrained weights")
    report["target_edges"] = int(target.sum())
    report["solved_named_weights"] = solved.tolist()
    print("YOUTH_ARMOUR_CONSTRAINTS " + json.dumps(report, allow_nan=False), flush=True)
    return revised, changed, seams, report


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
    primitives = glb.document["meshes"][mesh_id]["primitives"]
    body_primitives = [p for p in rig.primitives if p["node"] == node]
    if len(primitives) != len(body_primitives):
        raise ValueError("Source body primitive mapping differs")
    matches = []
    evidence = []
    for primitive_index, (primitive, prim) in enumerate(zip(primitives, body_primitives)):
        attrs = primitive["attributes"]
        if primitive.get("mode", 4) != 4 or "indices" not in primitive or "WEIGHTS_1" in attrs:
            raise ValueError("Unexpected body topology/influences")
        accessor = glb.document["accessors"][attrs["WEIGHTS_0"]]
        if accessor["componentType"] != 5126 or accessor.get("normalized") or accessor.get("sparse"):
            raise ValueError("Expected unquantized float skin weights")
        names = [rig.nodes[j].get("name") for j in prim["joints"]]
        edges = topology(glb.accessor(primitive["indices"]).astype(int).reshape(-1), len(prim["position"]))
        found, named, report = matching_edges(prim["position"], prim["joint_index"], prim["weight"], names, edges)
        evidence.append({"primitive": primitive_index, **report})
        for pair, transforms in found.items():
            matches.append((primitive_index, prim, edges, pair, named, transforms))
    print("YOUTH_ARMOUR_SOURCE_MAP " + json.dumps({"source_sha256": expected_sha, "primitives": evidence,
          "matching_edges": len(matches)}, allow_nan=False), flush=True)
    if len(matches) != 1:
        raise ValueError(f"Expected one measured connected edge across original body primitives, found {len(matches)}")
    primitive_index, prim, edges, pair, named, transforms = matches[0]
    revised, changed, seams, optimizer = constrained_candidate(rig, prim, edges, pair, named)
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
    writer.d["meshes"][mesh_id]["primitives"][primitive_index]["attributes"]["WEIGHTS_0"] = new_weights
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
            "source_primitive": primitive_index, "source_indices": list(pair), "source_axes": transforms,
            "changed_rows": changed, "split_seams": seams,
            "offline": measured, "optimizer": optimizer, "status": "GODOT_REVIEW_REQUIRED"}


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
