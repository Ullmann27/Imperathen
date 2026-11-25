"""Motion-driven repair of the exact youth's lower-tunic skin weights.

Keep all positions, topology, materials, bind matrices and original buffer
bytes. Repair only evidenced lower-body vertices pulled by arm weights.
The original source archive remains immutable.
"""
from __future__ import annotations
import copy
import numpy as np

ARM_PREFIXES = ("Arm_", "Forearm_", "Hand_", "Clavicle_", "UpperArmTwist_",
                "ForearmTwist_", "Palm_", "FingerCurl_", "Thumb_")

def unchanged_geometry(document):
    result = copy.deepcopy({k: document.get(k) for k in
                            ("meshes", "nodes", "skins", "materials", "textures", "images")})
    for mesh in result["meshes"]:
        for primitive in mesh["primitives"]:
            for name in ("JOINTS_0", "WEIGHTS_0"):
                primitive.get("attributes", {}).pop(name, None)
    return result

def triangles_to_edges(indices):
    tris = np.asarray(indices, dtype=np.int64).reshape(-1, 3)
    pairs = tris[:, [[0, 1], [1, 2], [2, 0]]].reshape(-1, 2)
    return np.unique(np.sort(pairs, axis=1), axis=0)

def edge_extension(vertices, joints, weights, edges, matrices):
    points = np.column_stack((vertices, np.ones(len(vertices))))
    rest = np.linalg.norm(vertices[edges[:, 0]] - vertices[edges[:, 1]], axis=1)
    # A large absolute extension is necessary; tiny triangles alone do not
    # identify a visible garment spike.
    limits = np.maximum(rest * 4.0, rest + .045)
    worst = np.zeros(len(edges))
    for transform in matrices:
        posed = (np.einsum("vkij,vj->vki", transform[joints], points)
                 * weights[..., None]).sum(axis=1)
        if not np.isfinite(posed).all():
            raise ValueError("Nonfinite original youth skin deformation")
        lengths = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
        worst = np.maximum(worst, np.maximum(lengths - limits, 0.0))
    return worst

def redistribute(joints, weights, vertices, selected, arm, pelvis, left, right, hip):
    new_j, new_w = joints.copy(), weights.copy()
    for index in np.flatnonzero(selected):
        w = {}
        transfer = 0.0
        for joint, amount in zip(joints[index], weights[index]):
            if int(joint) in arm:
                transfer += float(amount)
            else:
                w[int(joint)] = w.get(int(joint), 0.0) + float(amount)
        if transfer <= 0.0:
            continue
        # Blend waistband to pelvis, lower skirt to the adjacent thighs.
        leg = float(np.clip((hip[1] - vertices[index, 1] - .025) / .23, 0, 1))
        leg = .85 * leg * leg * (3.0 - 2.0 * leg)
        side = float(np.clip((vertices[index, 0] - hip[0]) / .12 + .5, 0, 1))
        for joint, value in ((pelvis, transfer*(1-leg)), (left, transfer*leg*side),
                             (right, transfer*leg*(1-side))):
            w[joint] = w.get(joint, 0.0) + value
        top = sorted(((k, v) for k, v in w.items() if v > 1e-8),
                     key=lambda pair: -pair[1])[:4]
        total = sum(value for _, value in top)
        new_j[index] = 0
        new_w[index] = 0
        for slot, (joint, value) in enumerate(top):
            new_j[index, slot] = joint
            new_w[index, slot] = value/total
    return new_j, new_w

def repair(target, read_access):
    d, b = target.d, target.b
    node = next(n for n in target.nodes if n.get("name") == "MeshyYouthBody")
    primitives = d["meshes"][node["mesh"]]["primitives"]
    inv = read_access(d,b,d["skins"][0]["inverseBindMatrices"]).reshape(-1,4,4).transpose(0,2,1)
    joint_names = [target.nodes[i]["name"] for i in target.joints]
    arm = {i for i, name in enumerate(joint_names) if name.startswith(ARM_PREFIXES)}
    pelvis, left, right = (joint_names.index(name) for name in ("Pelvis","Thigh_L","Thigh_R"))
    hip = target.pos("Pelvis")
    knee_y = min(target.pos("Shin_L")[1],target.pos("Shin_R")[1])
    half_width = abs(target.pos("Thigh_L")[0]-target.pos("Thigh_R")[0])*.5
    # Review every action, including the photographed high block, across
    # its actual captured time range. Sample endpoints and peak as well.
    matrices = []
    for name, (rotations, shifts) in target.review_poses.items():
        stride = 3 if name == "block" else 6
        frames = sorted(set(range(0,len(shifts),stride)) | {len(shifts)-1})
        for f in frames:
            g,p = target.fk(rotations[f], shifts[f])
            transforms = np.stack([np.column_stack((g[i],p[i])) for i in target.joints])
            matrices.append(transforms @ inv)
    groups = {}
    for primitive in primitives:
        attr = primitive["attributes"]
        if not {"POSITION","JOINTS_0","WEIGHTS_0"}.issubset(attr):
            continue
        key = tuple(attr[k] for k in ("POSITION","JOINTS_0","WEIGHTS_0"))
        groups.setdefault(key, []).append(primitive)
    report = {"pose_samples":len(matrices),"surfaces":[],"changed_vertices":0,
              "remaining_overstretched_edges":0}
    if not groups or not matrices:
        raise ValueError("Original youth skin review has no geometry or poses")
    for key, group in groups.items():
        v = read_access(d,b,key[0])
        j = read_access(d,b,key[1]).astype(np.int64)
        w = read_access(d,b,key[2]).astype(float)
        if j.shape != w.shape or j.shape != (len(v),4):
            raise ValueError("Unexpected original skin influence layout")
        if not np.isfinite(w).all() or np.any(w < 0) or np.any(j<0) or np.any(j>=len(joint_names)) or not np.allclose(w.sum(1),1,atol=.002):
            raise ValueError("Invalid original skin weights")
        indices = []
        for primitive in group:
            if primitive.get("mode",4) != 4:
                raise ValueError("Unexpected nontriangle youth mesh")
            indices.append(read_access(d,b,primitive["indices"]).reshape(-1) if "indices" in primitive else np.arange(len(v)))
        edges = triangles_to_edges(np.concatenate(indices))
        before = edge_extension(v,j,w,edges,matrices)
        arm_weight = (w*np.isin(j,list(arm))).sum(1)
        body_weight = (w*np.isin(j,[pelvis,left,right])).sum(1)
        # Restrict candidates to the central lower garment. Never change
        # shoulder, forearm, hand, face, knees or sole weights wholesale.
        eligible = ((v[:,1]>knee_y+.025)&(v[:,1]<hip[1]+.12)&
                    (np.abs(v[:,0]-hip[0])<half_width+.075)&
                    (np.abs(v[:,2]-hip[2])<.24)&(arm_weight>.025))
        core = body_weight >= .60
        a,c = edges[:,0],edges[:,1]
        seeds = np.zeros(len(v), dtype=bool)
        bad = before>.005
        seeds[a[bad & eligible[a] & core[c]]] = True
        seeds[c[bad & eligible[c] & core[a]]] = True
        selected = seeds.copy()
        for _ in range(3):
            expanded = selected.copy()
            expanded[a[selected[c]&eligible[a]]] = True
            expanded[c[selected[a]&eligible[c]]] = True
            selected = expanded
        chosen_j,chosen_w,after = j,w,before
        changed = 0
        # Compare candidate correction to the exact same original poses.
        # Reject a repair that creates another severe deformation.
        for mask in (seeds, selected):
            if not mask.any():
                continue
            cj,cw = redistribute(j,w,v,mask,arm,pelvis,left,right,hip)
            trial = edge_extension(v,cj,cw,edges,matrices)
            new_damage = (before<=.005)&(trial>.02)
            if (trial.sum()+1e-6<after.sum() and trial.max(initial=0)<=before.max(initial=0)+.001
                    and not new_damage.any() and (trial>.005).sum()<=(before>.005).sum()):
                chosen_j,chosen_w,after=cj,cw,trial
                changed=int(np.count_nonzero(mask))
        if changed:
            if not np.allclose(chosen_w.sum(1),1,atol=1e-6):
                raise ValueError("Repaired weights are not normalized")
            joint_access = target.append(chosen_j,"VEC4",component_type=5123)
            weight_access = target.append(chosen_w,"VEC4")
            for primitive in group:
                primitive["attributes"]["JOINTS_0"] = joint_access
                primitive["attributes"]["WEIGHTS_0"] = weight_access
        remaining = int((after>.005).sum())
        report["changed_vertices"] += changed
        report["remaining_overstretched_edges"] += remaining
        report["surfaces"].append({"vertices":len(v),"edges":len(edges),
            "changed_vertices":changed,"before_edges":int((before>.005).sum()),
            "after_edges":remaining,"before_max_excess_m":float(before.max(initial=0)),
            "after_max_excess_m":float(after.max(initial=0)),
            "initial_candidate_vertices":int(seeds.sum())})
    report["status"] = "measured_no_large_edge_spikes" if report["remaining_overstretched_edges"]==0 else "unresolved_surface_deformation"
    return report
