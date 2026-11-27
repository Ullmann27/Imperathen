#!/usr/bin/env python3
"""Measure and optionally repair exact hand-cut cap bindings of civilian youth.

This is an isolated candidate tool, not a production asset replacement.
Only existing cap joint/weight accessors can change. Ambiguous or noncoincident
seams are reported, never guessed. The original owner GLBs stay private.
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

CHARACTERS = Path(__file__).resolve().parents[1] / "characters"
MATCH_M = 0.00002
WEIGHT_EPS = 0.000001
GAP_LIMIT_M = 0.002
HZ = 60


def weight_signature(joints, weights):
    result = {}
    for joint, weight in zip(joints, weights):
        value = float(weight)
        if value > 0.0:
            key = int(joint)
            result[key] = result.get(key, 0.0) + value
    return result


def weight_delta(a, b):
    return sum(abs(a.get(j, 0.0) - b.get(j, 0.0)) for j in a.keys() | b.keys())


def match_vertices(shell_pos, shell_j, shell_w, cap_pos, cap_j, cap_w,
                   shell_used, cap_used):
    """Match only used cap vertices to a consistent coincident shell binding."""
    pairs, ambiguous, unmatched = [], [], []
    shell_used = np.asarray(shell_used, dtype=np.int64)
    cap_used = np.asarray(cap_used, dtype=np.int64)
    if not len(shell_used):
        return pairs, ambiguous, cap_used.tolist()
    tree = cKDTree(shell_pos[shell_used])
    for vertex in cap_used:
        candidates = tree.query_ball_point(cap_pos[vertex], MATCH_M)
        if not candidates:
            unmatched.append(int(vertex))
            continue
        choices = sorted(int(shell_used[i]) for i in candidates)
        best = min(choices, key=lambda i: (np.linalg.norm(shell_pos[i] - cap_pos[vertex]), i))
        sig = weight_signature(shell_j[best], shell_w[best])
        if any(weight_delta(sig, weight_signature(shell_j[i], shell_w[i])) > WEIGHT_EPS
               for i in choices):
            ambiguous.append(int(vertex))
            continue
        error = weight_delta(sig, weight_signature(cap_j[vertex], cap_w[vertex]))
        pairs.append((int(vertex), best, float(error)))
    return pairs, ambiguous, unmatched


def pose_subset(primitive, vertices, world):
    """Same linear blend skinning as the trusted Rig.skin, only selected rows."""
    ids = np.asarray(vertices, dtype=np.int64)
    matrices = np.stack([world[j] @ primitive["ibm"][k]
                         for k, j in enumerate(primitive["joints"])])
    p = np.c_[primitive["position"][ids], np.ones(len(ids))]
    result = np.zeros((len(ids), 3))
    for slot in range(4):
        transforms = matrices[primitive["joint_index"][ids, slot]]
        result += primitive["weight"][ids, slot, None] * np.einsum("nij,nj->ni", transforms, p)[:, :3]
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(rig, selections):
    maxima = {}
    worst = {"gap_m": 0.0}
    samples = 0
    rest_max = 0.0
    rest_world = rig.globals({"tracks": {}}, 0.0)
    for shell_idx, cap_idx, shell_vertices, cap_vertices in selections:
        a = pose_subset(rig.primitives[shell_idx], shell_vertices, rest_world)
        b = pose_subset(rig.primitives[cap_idx], cap_vertices, rest_world)
        rest_max = max(rest_max, float(np.linalg.norm(a-b, axis=1).max()))
    for animation in rig.glb.document.get("animations", []):
        name = animation["name"]
        clip = rig.animation(name)
        n = max(1, math.ceil(clip["duration"] * HZ))
        maximum = 0.0
        for frame in range(n + 1):
            t = clip["duration"] * frame / n
            world = rig.globals(clip, t)
            for shell_idx, cap_idx, shell_vertices, cap_vertices in selections:
                a = pose_subset(rig.primitives[shell_idx], shell_vertices, world)
                b = pose_subset(rig.primitives[cap_idx], cap_vertices, world)
                gaps = np.linalg.norm(a-b, axis=1)
                if not np.isfinite(gaps).all():
                    raise ValueError("Nonfinite posed cap gap")
                k = int(gaps.argmax())
                gap = float(gaps[k])
                samples += len(gaps)
                maximum = max(maximum, gap)
                if gap > worst["gap_m"]:
                    worst = {"gap_m":gap, "clip":name, "seconds":t,
                             "shell_vertex":int(shell_vertices[k]), "cap_vertex":int(cap_vertices[k]),
                             "cap_primitive":cap_idx}
        maxima[name] = maximum
    return {"sample_hz":HZ, "samples":samples, "rest_max_gap_m":rest_max,
            "worst":worst, "clips":maxima}


def audit(source, destination):
    # Load the repository's existing, source-pinned GLB and rig implementations.
    sys.path.insert(0, str(CHARACTERS))
    from build_youth_civil_outfit import Glb as Writer
    from ground_death_clip import Glb, Rig

    original = Glb(source)
    rig = Rig(original)
    doc = original.document
    body_node = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "MeshyYouthBody")
    primitives = doc["meshes"][doc["nodes"][body_node]["mesh"]]["primitives"]
    body_ids = [i for i, p in enumerate(rig.primitives) if p["node"] == body_node]
    if len(body_ids) != len(primitives):
        raise ValueError("Unexpected body primitive layout")
    material_names = [doc["materials"][p["material"]].get("name", "") for p in primitives]
    if "YouthCivilWool" not in material_names:
        raise ValueError("Actual civilian youth GLB required")
    shell = rig.primitives[body_ids[0]]
    shell_used = np.unique(original.accessor(primitives[0]["indices"]).astype(np.int64))
    writer = Writer(source.read_bytes())
    writable = writer.d["meshes"][writer.d["nodes"][body_node]["mesh"]]["primitives"]
    rows = []
    selections = []
    changed = 0
    for i, name in enumerate(material_names):
        if not name.casefold().startswith("youth hand cut repair"):
            continue
        if i == 0:
            raise ValueError("Cap unexpectedly replaced the main shell")
        cap = rig.primitives[body_ids[i]]
        if cap["joints"] != shell["joints"] or not np.array_equal(cap["ibm"], shell["ibm"]):
            raise ValueError("Cap uses different skin; cannot copy binding safely")
        used = np.unique(original.accessor(primitives[i]["indices"]).astype(np.int64))
        pairs, ambiguous, unmatched = match_vertices(
            shell["position"], shell["joint_index"], shell["weight"],
            cap["position"], cap["joint_index"], cap["weight"], shell_used, used)
        rows.append({"primitive":i, "material":name, "used_vertices":len(used),
                     "matched":len(pairs), "ambiguous":len(ambiguous),
                     "unmatched":len(unmatched),
                     "weight_mismatches":sum(e > WEIGHT_EPS for _,_,e in pairs),
                     "max_weight_l1":max((e for _,_,e in pairs), default=0.0)})
        if not pairs:
            continue
        selections.append((body_ids[0], body_ids[i],
                           np.array([s for _,s,_ in pairs]), np.array([c for c,_,_ in pairs])))
        j = cap["joint_index"].copy()
        w = cap["weight"].copy().astype(np.float32)
        for c, s, error in pairs:
            if error <= WEIGHT_EPS:
                continue
            j[c] = shell["joint_index"][s]
            w[c] = shell["weight"][s]
            changed += 1
        if rows[-1]["weight_mismatches"]:
            if not np.isfinite(w).all() or (w < 0).any() or np.max(np.abs(w.sum(1)-1)) > 0.002:
                raise ValueError("Candidate cap weights are invalid")
            if j.min() < 0 or j.max() >= len(shell["joints"]) or j.max() > 65535:
                raise ValueError("Candidate cap joint out of range")
            attrs = writable[i]["attributes"]
            attrs["JOINTS_0"] = writer.append(j, "VEC4", 5123, target=34962)
            attrs["WEIGHTS_0"] = writer.append(w, "VEC4", target=34962)
    baseline = measure(rig, selections)
    # No repack or geometry edit: all previous bytes/accessors remain intact.
    destination.write_bytes(writer.encode() if changed else source.read_bytes())
    revised = Rig(Glb(destination))
    if len(revised.primitives) != len(rig.primitives):
        raise ValueError("Primitive count changed")
    for a,b in zip(rig.primitives,revised.primitives):
        if not np.array_equal(a["position"],b["position"]) or a["joints"] != b["joints"] or not np.array_equal(a["ibm"],b["ibm"]):
            raise ValueError("Geometry or skeleton changed")
    after = measure(revised,selections)
    if baseline["samples"] != after["samples"]:
        raise ValueError("Mismatched A/B sampling")
    status = "REVIEW_PENDING" if selections else ("NO_RETAINED_CAP" if not rows else "NO_MEASURABLE_SEAM")
    if changed and (after["worst"]["gap_m"] > GAP_LIMIT_M or after["worst"]["gap_m"] > baseline["worst"]["gap_m"]+MATCH_M):
        status = "BLOCKED"
    return {"file":source.name,"source_sha256":digest(source),"candidate_sha256":digest(destination),
            "caps":rows,"changed_bindings":changed,"before":baseline,"after":after,"status":status}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("Output must be isolated from the input")
    args.output.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for lod in range(4):
        name = f"hero_meshy_italia_civil_{lod}.glb"
        source = args.input / name
        destination = args.output / name
        if destination.exists():
            raise ValueError("Refusing to overwrite an existing candidate")
        row = audit(source,destination)
        rows.append(row)
        print("YOUTH_CAP_BINDING", json.dumps(row), flush=True)
    report = {"match_m":MATCH_M,"provisional_gap_limit_m":GAP_LIMIT_M,"lods":rows,
              "scope":"Exact unambiguous retained cap seams only; no holes/texture/morph/visual/device acceptance"}
    args.report.write_text(json.dumps(report,indent=2)+"\n", encoding="utf-8")
    measured = sum(row["before"]["samples"] for row in rows)
    print("YOUTH_CAP_BINDING_RESULT",json.dumps({"measured_samples":measured,"changed_bindings":sum(row["changed_bindings"] for row in rows)}))
    return int(not measured or any(row["status"]=="BLOCKED" for row in rows))


if __name__ == "__main__":
    raise SystemExit(main())
