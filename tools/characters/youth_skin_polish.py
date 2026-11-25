"""Motion-driven repair of the exact youth's lower-tunic skin weights.

Keep all positions, topology, materials, bind matrices and original buffer
bytes. Repair only evidenced lower-body vertices pulled by arm weights.
The original source archive remains immutable.
"""
from __future__ import annotations
import copy
import numpy as np
from youth_anatomy import texture_colors, skin_color

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
        # Use atlas colors and actual hand distance to distinguish the
        # white tunic/waist leather from the nearby bare forearms and hands.
        colors=texture_colors(d,b,group[0],read_access)
        flesh=skin_color(colors)
        saturation=colors.max(1)-colors.min(1)
        cloth=(colors.mean(1)>.31)&(saturation<.28)
        wrist_dist=np.minimum(np.linalg.norm(v-target.pos("Hand_L"),axis=1),
                              np.linalg.norm(v-target.pos("Hand_R"),axis=1))
        central=(np.abs(v[:,0]-hip[0])<half_width+.13)
        lower=(v[:,1]>knee_y+.025)&(v[:,1]<hip[1]+.16)&(np.abs(v[:,2]-hip[2])<.25)
        protected=flesh&(wrist_dist<.14)&(body_weight<.5)
        eligible=lower&central&~protected&(arm_weight>.005)
        confidence=eligible&(cloth|(body_weight>.30)|(wrist_dist>.14))
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
        for mask in (confidence, eligible, selected|confidence, selected):
            if not mask.any():
                continue
            cj,cw = redistribute(j,w,v,mask,arm,pelvis,left,right,hip)
            trial = edge_extension(v,cj,cw,edges,matrices)
            # The old all-or-nothing local-edge condition rejected every
            # correction, including 939 actual candidates at LOD0. Accept
            # a coherent change only when total and peak deformation both
            # improve, without hiding remaining or newly damaged edges.
            if (trial.sum()+1e-6<after.sum() and trial.max(initial=0)<=before.max(initial=0)+.001
                    and (trial>.005).sum()<=(before>.005).sum()):
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
            "initial_candidate_vertices":int(seeds.sum()),"confident_garment_vertices":int(confidence.sum()),
            "remaining_arm_weight_on_confident_vertices":float((chosen_w*np.isin(chosen_j,list(arm))).sum(1)[confidence].max(initial=0)),
            "new_overstretched_edges":int(((before<=.005)&(after>.005)).sum())})
    report["status"] = "measured_no_large_edge_spikes" if report["remaining_overstretched_edges"]==0 else "unresolved_surface_deformation"
    return report


# The original Meshy youth is generated with both hands fused into the lower
# tunic (LOD 0: ~1000 edges join hand-weighted and pelvis/thigh-weighted
# vertices; up to 550 cm2 of tunic is bound to each hand). The mesh consists
# of thousands of separate UV islands, so the fusion is resolvable per island
# without touching topology: every island around the skirt that carries arm
# influence moves uniformly with the body, unless it lies on the hand itself.
HAND_ISLAND_RADIUS_M = .06       # median distance to the forearm/hand/finger chain
HAND_ISLAND_SEAM_FLIP = .5       # body island whose seams mostly join hand surface


def _islands(edges, count):
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    graph = coo_matrix((np.ones(len(edges)), (edges[:, 0], edges[:, 1])), shape=(count, count))
    return connected_components(graph, directed=False)[1]


def _segment_distance(points, a, b):
    ab = b-a
    t = np.clip(((points-a)@ab)/max(float(ab@ab), 1e-12), 0, 1)
    return np.linalg.norm(points-(a+t[:, None]*ab), axis=1)


def separate_hand_islands(target, read_access):
    """Measured per-island hand/body separation of the fused tunic."""
    d, b = target.d, target.b
    node = next(n for n in target.nodes if n.get("name") == "MeshyYouthBody")
    primitives = d["meshes"][node["mesh"]]["primitives"]
    inv = read_access(d, b, d["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    names = [target.nodes[i]["name"] for i in target.joints]
    arm = {i for i, name in enumerate(names) if name.startswith(ARM_PREFIXES)}
    pelvis, left, right = (names.index(name) for name in ("Pelvis", "Thigh_L", "Thigh_R"))
    hip = target.pos("Pelvis")
    knee_y = min(target.pos("Shin_L")[1], target.pos("Shin_R")[1])
    half_width = abs(target.pos("Thigh_L")[0]-target.pos("Thigh_R")[0])*.5
    matrices = []
    for name, (rotations, shifts) in target.review_poses.items():
        stride = 3 if name == "block" else 6
        for f in sorted(set(range(0, len(shifts), stride)) | {len(shifts)-1}):
            g, p = target.fk(rotations[f], shifts[f])
            matrices.append(np.stack([np.column_stack((g[i], p[i])) for i in target.joints]) @ inv)
    segments = []
    for side in ("L", "R"):
        hand = target.pos("Hand_"+side)
        segments.append((target.pos("Forearm_"+side), hand))
        for tip in ("Palm_", "FingerCurl_", "Thumb_"):
            if tip+side in target.ids:
                end = target.pos(tip+side)
                segments.append((hand, end+(end-hand)))   # include the finger tips
    report = {"pose_samples": len(matrices), "radius_m": HAND_ISLAND_RADIUS_M, "surfaces": [], "changed_vertices": 0}
    groups = {}
    for primitive in primitives:
        attr = primitive["attributes"]
        if {"POSITION", "JOINTS_0", "WEIGHTS_0"}.issubset(attr) and "indices" in primitive:
            groups.setdefault(tuple(attr[k] for k in ("POSITION", "JOINTS_0", "WEIGHTS_0")), []).append(primitive)
    for key, group in groups.items():
        v = read_access(d, b, key[0]).astype(float)
        j = read_access(d, b, key[1]).astype(np.int64)
        w = read_access(d, b, key[2]).astype(float)
        edges = triangles_to_edges(np.concatenate([read_access(d, b, p["indices"]).reshape(-1) for p in group]))
        label = _islands(edges, len(v))
        arm_weight = (w*np.isin(j, list(arm))).sum(1)
        hand_distance = np.min([_segment_distance(v, a, c) for a, c in segments], axis=0)
        to_body = np.zeros(len(v), bool)
        to_hand = np.zeros(len(v), bool)
        candidates = 0
        for island in np.unique(label[arm_weight > .05]):
            members = label == island
            centre = v[members].mean(0)
            if not (knee_y < centre[1] < hip[1]+.12 and abs(centre[0]-hip[0]) < half_width+.15):
                continue
            candidates += 1
            if float(np.median(hand_distance[members])) < HAND_ISLAND_RADIUS_M:
                to_hand |= members
            else:
                to_body |= members
        # A body island whose welded seams join mostly hand-moving surface would
        # be left floating beside the hip once the hand moves away.
        welded = np.unique(np.round(v, 5), axis=0, return_inverse=True)[1].reshape(-1)
        seams = {}
        order = np.argsort(welded, kind="stable")
        bounds = np.flatnonzero(np.diff(welded[order]))+1
        for chunk in np.split(order, bounds):
            islands = set(label[chunk].tolist())
            if len(islands) > 1:
                for x in islands:
                    for y in islands:
                        if x != y:
                            seams.setdefault(x, {}).setdefault(y, 0)
                            seams[x][y] += 1
        def moves_with_hand(island):
            members = label == island
            if to_hand[members].any():
                return True
            if to_body[members].any():
                return False
            return arm_weight[members].mean() > .5
        flipped = 0
        for _ in range(5):
            changed = 0
            for island in np.unique(label[to_body]):
                neighbours = seams.get(int(island), {})
                total = sum(neighbours.values())
                if total and sum(c for y, c in neighbours.items() if moves_with_hand(y))/total > HAND_ISLAND_SEAM_FLIP:
                    members = label == island
                    to_body[members] = False
                    to_hand[members] = True
                    changed += 1
            flipped += changed
            if not changed:
                break
        new_j, new_w = redistribute(j, w, v, to_body, arm, pelvis, left, right, hip)
        for i in np.flatnonzero(to_hand):
            keep = [(int(new_j[i, k]), float(new_w[i, k])) for k in range(4) if new_w[i, k] > 0 and int(new_j[i, k]) in arm]
            if not keep:
                continue
            total = sum(value for _, value in keep)
            new_j[i] = 0
            new_w[i] = 0
            for slot, (joint, value) in enumerate(keep):
                new_j[i, slot] = joint
                new_w[i, slot] = value/total
        before = edge_extension(v, j, w, edges, matrices)
        after = edge_extension(v, new_j, new_w, edges, matrices)
        accepted = bool((to_body | to_hand).any() and (after > .005).sum() < (before > .005).sum()
                        and after.max(initial=0) < before.max(initial=0))
        # Welded copies on different islands separate where hand and tunic part.
        opening = np.zeros(len(order))
        if accepted:
            points = np.column_stack((v, np.ones(len(v))))
            pairs = np.array([(c[0], x) for c in np.split(order, bounds) if len(c) > 1 for x in c[1:]])
            for transform in (matrices if len(pairs) else []):
                posed = (np.einsum("vkij,vj->vki", transform[new_j], points)*new_w[..., None]).sum(axis=1)
                opening[:len(pairs)] = np.maximum(opening[:len(pairs)], np.linalg.norm(posed[pairs[:, 0]]-posed[pairs[:, 1]], axis=1))
            joint_access = target.append(new_j, "VEC4", component_type=5123)
            weight_access = target.append(new_w, "VEC4")
            for primitive in group:
                primitive["attributes"]["JOINTS_0"] = joint_access
                primitive["attributes"]["WEIGHTS_0"] = weight_access
        changed_vertices = int(np.count_nonzero(np.any(np.abs(new_w-w) > 1e-7, axis=1) | np.any(new_j != j, axis=1))) if accepted else 0
        report["changed_vertices"] += changed_vertices
        report["surfaces"].append({"vertices": len(v), "islands": int(label.max()+1), "candidate_islands": candidates,
            "body_vertices": int(to_body.sum()), "hand_vertices": int(to_hand.sum()), "seam_flipped_islands": flipped,
            "before_edges": int((before > .005).sum()), "after_edges": int(((after if accepted else before) > .005).sum()),
            "trial_after_edges": int((after > .005).sum()), "before_max_excess_m": float(before.max(initial=0)),
            "after_max_excess_m": float((after if accepted else before).max(initial=0)),
            "seam_pairs_opening_over_20mm": int((opening > .02).sum()), "max_seam_opening_m": float(opening.max(initial=0)),
            "accepted": accepted})
    report["status"] = "accepted_requires_visual_review" if report["changed_vertices"] else "unchanged"
    return report
