"""Fingers, jaw and eyes for the adult frontier cast.

The adult bodies (`HeroBody` in art/frontier_people/*.blend) are the vendored
CC0 MakeHuman base mesh with its original vertex order, bound to the project's
fifteen locomotion joints. `art/hero_quality/source/default_weights.mhw`
(MakeHuman, CC0) still holds the authored weights of every finger phalanx and
of the jaw for exactly those vertices; build_hero.py folded them into `Hand_*`
and `Head`. This module unfolds them again:

* 15 finger joints per hand (`Thumb1..3_L`, `Index1..3_L`, `Middle1..3_L`,
  `Ring1..3_L`, `Pinky1..3_L`, same for `_R`) as children of `Hand_*`,
* `Jaw` as a child of `Head` (same name as the youth's jaw joint),
* `Eye_L` / `Eye_R` as children of `Head` for the eyeballs,
* ten lip, lid and brow shapes for phoneme lip sync (`FACE_SHAPES`).

The fifteen original joints keep their names, parents, rest poses and keys, so
locomotion, IK, sole contact and the motion-gate families are untouched. Joint
centres are MakeHuman's own joint helpers, carried into the actual rest mesh
with the local motion of the skin around them, so they follow every later fit
of the body. The jaw pivot is
solved from the existing `JawOpen` morph, so 12 degrees on `Jaw` reproduce
that morph.

`bake()` adds finger keys to every clip. Soldiers close each finger until it
touches the weapon or shield grip that is bound to that hand.

All four tiers carry the same joints and keys, because the runtime hands poses
from tier to tier joint by joint. The lip-sync shapes stay on the near tiers.
`release_runtime_joints()` removes the clip channels of jaw and eyes after the
export, so speech and gaze own them at runtime.
"""
from __future__ import annotations

import importlib.util
import json
import math
import struct
from collections import defaultdict
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
FINGERS = (("Thumb", 1), ("Index", 2), ("Middle", 3), ("Ring", 4), ("Pinky", 5))
JAW_SOURCES = ("jaw", "special04", "oris01", "oris07.L", "oris07.R", "tongue00", "tongue01", "tongue02",
               "tongue03", "tongue04", "tongue05.L", "tongue05.R", "tongue06.L", "tongue06.R",
               "tongue07.L", "tongue07.R")
JAW_MORPH_DEGREES = 12.0
# Flexion at full curl (degrees): knuckle, middle joint, end joint.
FLEX = (78.0, 98.0, 62.0)
THUMB_FLEX = (34.0, 36.0, 58.0)
# A resting hand is never flat: the little finger curls most.
RELAXED = {"Thumb": .30, "Index": .22, "Middle": .28, "Ring": .33, "Pinky": .38}

_HERO = None
_ANATOMY = None


def _hero():
    global _HERO
    if _HERO is None:
        spec = importlib.util.spec_from_file_location("adult_rig_hero_source", ROOT / "tools/characters/build_hero.py")
        _HERO = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_HERO)
    return _HERO


def _anatomy():
    global _ANATOMY
    if _ANATOMY is None:
        _ANATOMY = _hero().load_anatomy()
    return _ANATOMY


def base_indices(count):
    """HeroBody vertex -> base.obj vertex: the selection of build_hero.body()."""
    anatomy = _anatomy()
    joints = anatomy["joints"]
    hem = joints["Shin_L"][0].z + .11
    used = set()
    for i, group in enumerate(anatomy["groups"]):
        if group != "body":
            continue
        ids = anatomy["faces"][i]
        centre = anatomy["points"][0][ids].mean(axis=0)
        influence = defaultdict(float)
        for v in ids:
            for bone, w in anatomy["weights"][v].items():
                influence[bone] += w / len(ids)
        central = sum(influence.get(k, 0) for k in ("Pelvis", "Spine", "Thigh_L", "Thigh_R"))
        covered = hem + .008 < centre[2] < joints["Head"][0].z + .004 and central > .30
        for side in ("L", "R"):
            start, end, _ = joints["Arm_" + side]
            axis = (end - start).normalized()
            along = (Vector(centre) - start).dot(axis) / (end - start).length
            covered = covered or (influence.get("Arm_" + side, 0) > .25 and along < .54
                                  and centre[2] < joints["Head"][0].z + .004)
        if not covered:
            used.update(ids)
    used = sorted(used)
    if len(used) != count:
        raise ValueError("HeroBody has %d vertices, the anatomical source selects %d" % (count, len(used)))
    return used


def _raw_weights():
    raw = defaultdict(dict)
    for bone, entries in _anatomy()["facial_weights"].items():
        for index, weight in entries:
            if weight > 0:
                raw[index][bone] = raw[index].get(bone, 0.0) + weight
    return raw


def bone_name(finger, segment, side):
    return "%s%d_%s" % (finger, segment, side)


def finger_bones(side):
    return [bone_name(f, s, side) for f, _ in FINGERS for s in (1, 2, 3)]


def added_bones():
    return [n for side in ("L", "R") for n in finger_bones(side)] + ["Jaw", "Eye_L", "Eye_R"]


def _source(number, segment, side):
    return "finger%d-%d.%s" % (number, segment, side)


def _authored_joints(P, used):
    """MakeHuman's own joint helpers, carried into the rest mesh of this source.

    The helpers are given in the space of the hero's base mesh. Every later fit
    (adult proportions, civilian shapes, company skeleton) moved the skin, so
    each helper follows the local affine motion of the skin around it.
    """
    anatomy = _anatomy()
    raw = anatomy["raw_variants"][0]
    floor, scale = anatomy["scales"][0]
    points = np.column_stack((raw[:, 0] * scale, -raw[:, 2] * scale, (raw[:, 1] - floor) * scale))
    groups = anatomy["facegroups"]

    def helper(name):
        return Vector(points[list(groups["joint-" + name])].mean(axis=0))

    base = anatomy["points"][0][used]
    tree = KDTree(len(base))
    for i, p in enumerate(base):
        tree.insert(p, i)
    tree.balance()
    current = np.array([p[:] for p in P])

    def carried(point):
        near = [i for _, i, _ in tree.find_n(point, 40)]
        source = np.column_stack((base[near], np.ones(len(near))))
        solution, *_ = np.linalg.lstsq(source, current[near], rcond=None)
        return Vector(np.array([point.x, point.y, point.z, 1.0]) @ solution)

    result = {}
    for side, sign in (("L", 1), ("R", -1)):
        s = side.lower()
        pivot = helper(s + "-shoulder")
        lowered = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(18) * sign, 4, "Y") @ Matrix.Translation(-pivot)
        joints = {"wrist": carried(lowered @ helper(s + "-hand"))}
        for finger, number in FINGERS:
            joints[finger] = [carried(lowered @ helper("%s-finger-%d-%d" % (s, number, k))) for k in (1, 2, 3, 4)]
        result[side] = joints
    return result


def _measure_hand(side, P, used, raw, authored):
    """Joint centres, flexion axes and radii of one hand on the rest mesh."""
    palm_sources = ["wrist." + side] + ["metacarpal%d.%s" % (i, side) for i in (1, 2, 3, 4)]
    hand_sources = set(palm_sources) | {_source(n, s, side) for _, n in FINGERS for s in (1, 2, 3)}
    rows = []
    for i, s in enumerate(used):
        r = raw.get(s)
        if r and any(k in hand_sources for k in r):
            rows.append((P[i], r))
    chains = {}
    for finger, number in FINGERS:
        j1, j2, j3, tip = authored[finger]
        radius = []
        for a, b, k in ((j1, j2, 1), (j2, j3, 2), (j3, tip, 3)):
            name = _source(number, k, side)
            axis = (b - a).normalized()
            values = [((p - a) - axis * (p - a).dot(axis)).length for p, r in rows
                      if r.get(name, 0) > .6 and 0 < (p - a).dot(axis) < (b - a).length]
            radius.append(sum(values) / len(values) if values else .008)
        chains[finger] = {"joints": [j1, j2, j3, tip], "radius": radius}
    wrist = authored["wrist"]
    index, pinky, middle = (chains[n]["joints"] for n in ("Index", "Pinky", "Middle"))
    along = (middle[0] - wrist).normalized()
    across = pinky[0] - index[0]
    # Arms out, palms down: the palm normal is -(along x across) on the left
    # hand and +(along x across) on the right hand.
    normal = along.cross(across).normalized() * (-1.0 if side == "L" else 1.0)
    palm = (index[0] + pinky[0] + wrist * 2.0) / 4.0
    evidence = 0.0
    for finger, _ in FINGERS[1:]:
        j = chains[finger]["joints"]
        direction = (j[1] - j[0]).normalized()
        hinge = direction.cross(normal)
        hinge -= direction * hinge.dot(direction)
        hinge.normalize()
        chains[finger]["axes"] = [hinge, hinge, hinge]
        evidence += ((j[1] - j[0]).cross(j[2] - j[1]) + (j[2] - j[1]).cross(j[3] - j[2])).dot(hinge)
    # The thumb closes towards a handle held in the palm.
    grip = palm + along * .045 + normal * .030
    j = chains["Thumb"]["joints"]
    axes = []
    for a, b in ((j[0], j[1]), (j[1], j[2]), (j[2], j[3])):
        direction = (b - a).normalized()
        toward = grip - a
        toward -= direction * toward.dot(direction)
        axes.append(direction.cross(toward.normalized()).normalized())
    chains["Thumb"]["axes"] = axes
    radial = -(across - normal * across.dot(normal)).normalized()
    return {"chains": chains, "wrist": wrist, "normal": normal, "palm": palm, "along": along,
            "swing": radial.cross(normal).normalized(),
            "rest_curl_evidence": evidence, "hand_sources": hand_sources, "palm_sources": palm_sources}


def _solve_jaw(body, used, raw):
    """Pivot of the existing JawOpen morph and the chin it moves."""
    keys = body.data.shape_keys.key_blocks if body.data.shape_keys else None
    morph = keys.get("JawOpen") if keys else None
    if morph is None:
        raise ValueError("HeroBody has no JawOpen morph to take the jaw pivot from")
    basis = keys[0]
    angle = math.radians(JAW_MORPH_DEGREES)
    c, s = math.cos(angle) - 1.0, math.sin(angle)
    det = c * c + s * s
    ys, zs, chin, xs = [], [], None, []
    for i, source in enumerate(used):
        w = sum(raw.get(source, {}).get(n, 0) for n in JAW_SOURCES)
        if w < .8:
            continue
        v = basis.data[i].co
        d = (morph.data[i].co - v) / w
        # (R - I) q = d for q = v - pivot in the y/z plane; R rotates about +X.
        qy = (c * d.y + s * d.z) / det
        qz = (-s * d.y + c * d.z) / det
        ys.append(v.y - qy)
        zs.append(v.z - qz)
        xs.append(v.x)
        if chin is None or v.z < chin.z:
            chin = v.copy()
    if len(ys) < 20:
        raise ValueError("Too few fully jaw-weighted vertices: %d" % len(ys))
    ys.sort()
    zs.sort()
    centre_x = sum(xs) / len(xs)
    pivot = Vector((centre_x, ys[len(ys) // 2], zs[len(zs) // 2]))
    spread = max(ys[int(len(ys) * .9)] - ys[int(len(ys) * .1)], zs[int(len(zs) * .9)] - zs[int(len(zs) * .1)])
    return pivot, Vector((centre_x, chin.y, chin.z)), spread, len(ys)


def _finger_shares(body, used, raw, hands):
    """Per vertex: the part of its `Hand_*` weight that belongs to each finger joint."""
    names = {g.index: g.name for g in body.vertex_groups}
    result = {}
    for i, source in enumerate(used):
        r = raw.get(source)
        if not r:
            continue
        row = {}
        for g in body.data.vertices[i].groups:
            name = names[g.group]
            if name not in ("Hand_L", "Hand_R") or g.weight <= 1e-6:
                continue
            side = name[-1]
            hand = hands[side]
            total = sum(w for n, w in r.items() if n in hand["hand_sources"])
            if total <= 0:
                continue
            fingers = {}
            for finger, number in FINGERS:
                for segment in (1, 2, 3):
                    w = r.get(_source(number, segment, side), 0)
                    if w > 0:
                        fingers[bone_name(finger, segment, side)] = g.weight * w / total
            if fingers:
                row[name] = g.weight * sum(r.get(n, 0) for n in hand["palm_sources"]) / total
                row.update(fingers)
        if row:
            result[i] = row
    return result


# Lip, lid and brow shapes for phoneme lip sync. Names follow the ARKit set
# that docs/41_audio/FACIAL_RIG_PLAN.md (audio session) asks for.
FACE_SHAPES = ("mouthClose", "mouthFunnel", "mouthPucker", "mouthStretchLeft", "mouthStretchRight",
               "mouthRollLower", "mouthUpperUp", "eyeSquintLeft", "eyeSquintRight", "browInnerUp")


def _smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def add_face_shapes(body, used, raw):
    """Author the lip-sync shapes on the skin from MakeHuman's CC0 facial muscle weights.

    The muscle weights only serve as soft masks (upper lip, lower lip, lids,
    brows); the displacements are authored here in millimetres of the source
    head and scaled with the width of each mouth.
    """
    basis = body.data.shape_keys.key_blocks[0]
    rows = []
    for i, source in enumerate(used):
        r = raw.get(source)
        if not r:
            continue
        upper = min(1.0, r.get("oris05", 0) + r.get("oris03.L", 0) + r.get("oris03.R", 0))
        lower = min(1.0, r.get("oris01", 0) + r.get("oris07.L", 0) + r.get("oris07.R", 0))
        row = {"upper": upper, "lower": lower,
               "lid_L": min(1.0, r.get("orbicularis04.L", 0)), "lid_R": min(1.0, r.get("orbicularis04.R", 0)),
               "cheek_L": min(1.0, r.get("levator05.L", 0)), "cheek_R": min(1.0, r.get("levator05.R", 0)),
               "pull_L": min(1.0, r.get("risorius03.L", 0)), "pull_R": min(1.0, r.get("risorius03.R", 0)),
               "wing": min(1.0, r.get("levator06.L", 0) + r.get("levator06.R", 0)),
               "brow": min(1.0, r.get("oculi01.L", 0) + r.get("oculi01.R", 0))}
        if any(v > 0 for v in row.values()):
            rows.append((i, basis.data[i].co.copy(), row))
    lips = [(p, row) for _, p, row in rows if row["upper"] > .3 or row["lower"] > .3]
    if len(lips) < 40:
        raise ValueError("Too little lip skin for the lip-sync shapes: %d" % len(lips))
    up = [p for p, row in lips if row["upper"] > .5]
    low = [p for p, row in lips if row["lower"] > .5]
    line = (sum(p.z for p in up) / len(up) + sum(p.z for p in low) / len(low)) / 2
    centre = sum(p.x for p, _ in lips) / len(lips)
    half = max(abs(p.x - centre) for p, row in lips if row["upper"] > .3 and row["lower"] > .1 or
               row["lower"] > .3 and row["upper"] > .1)
    k = half / .025  # millimetre values below are for a 50 mm mouth
    deltas = {name: {} for name in FACE_SHAPES}
    for i, p, row in rows:
        u, l = row["upper"], row["lower"]
        lip = min(1.0, u + l)
        x = p.x - centre
        side = "L" if x > 0 else "R"
        mid = 1.0 - min(1.0, (x / half) ** 2)
        if lip > 0:
            deltas["mouthClose"][i] = Vector((0, .0008 * lip, -.0012 * u + .0018 * l)) * k
            deltas["mouthPucker"][i] = Vector((-x * .38 * lip, -.0060 * lip * (.35 + .65 * mid) * k,
                                               (line - p.z) * .15 * lip))
            deltas["mouthFunnel"][i] = Vector((-x * .25 * lip, -.0045 * lip * (.4 + .6 * mid) * k,
                                               (.0022 * u - .0030 * l) * k))
            corner = lip * _smooth(.2, 1.0, abs(x) / half)
            if corner > 0:
                sign = 1.0 if x > 0 else -1.0
                name = "mouthStretchLeft" if x > 0 else "mouthStretchRight"
                deltas[name][i] = Vector((sign * .0050 * corner, .0020 * corner, 0)) * k
        if l > 0:
            deltas["mouthRollLower"][i] = Vector((0, .0035 * l, .0020 * l)) * k
        if u > 0 or row["wing"] > 0:
            deltas["mouthUpperUp"][i] = Vector((0, 0, .0030 * u + .0008 * row["wing"] * (1 - u))) * k
        for s, name in (("L", "eyeSquintLeft"), ("R", "eyeSquintRight")):
            amount = .0018 * row["lid_" + s] + .0008 * row["cheek_" + s] * (1 - lip)
            pull = row["pull_" + s] * (1 - lip)
            if name.startswith("mouth"):
                continue
            if amount > 0:
                deltas[name][i] = Vector((0, 0, amount)) * k
            stretch = "mouthStretchLeft" if s == "L" else "mouthStretchRight"
            if pull > 0 and i not in deltas[stretch]:
                deltas[stretch][i] = Vector(((1.0 if s == "L" else -1.0) * .0015 * pull, 0, 0)) * k
        if row["brow"] > 0:
            inner = 1.0 - _smooth(.012 * k, .034 * k, abs(x))
            if inner > 0:
                deltas["browInnerUp"][i] = Vector((0, 0, .0035 * row["brow"] * inner)) * k
    for name in FACE_SHAPES:
        key = body.shape_key_add(name=name, from_mix=False)
        key.value = 0.0
        for i, delta in deltas[name].items():
            key.data[i].co = basis.data[i].co + delta
    return {"shapes": {name: len(deltas[name]) for name in FACE_SHAPES},
            "mouth_half_width_m": round(half, 5), "lip_line_z": round(line, 5)}, deltas


def _limit(weights):
    pairs = sorted(((n, w) for n, w in weights.items() if w > 1e-5), key=lambda p: p[1], reverse=True)[:4]
    total = sum(w for _, w in pairs)
    return {n: w / total for n, w in pairs}


def extend(arm):
    """Add finger, jaw and eye joints to the opened frontier source. Returns measurements."""
    body = bpy.data.objects["HeroBody"]
    eyes = bpy.data.objects.get("HeroEyes")
    used = base_indices(len(body.data.vertices))
    raw = _raw_weights()
    P = [v.co.copy() for v in body.data.vertices]
    authored = _authored_joints(P, used)
    hands = {side: _measure_hand(side, P, used, raw, authored[side]) for side in ("L", "R")}
    pivot, chin, pivot_spread, jaw_samples = _solve_jaw(body, used, raw)
    eye_centres = {}
    if eyes:
        for side, sign in (("L", 1), ("R", -1)):
            points = [v.co for v in eyes.data.vertices if v.co.x * sign > 0]
            lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
            hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
            centre = (lo + hi) / 2
            # The back of the ball is cut away: take the depth from the width.
            centre.y = lo.y + max(hi.x - lo.x, hi.z - lo.z) / 2
            eye_centres[side] = (centre, (hi - lo))

    spec = []
    for side in ("L", "R"):
        for finger, _ in FINGERS:
            j = hands[side]["chains"][finger]["joints"]
            for segment in (1, 2, 3):
                parent = "Hand_" + side if segment == 1 else bone_name(finger, segment - 1, side)
                spec.append((bone_name(finger, segment, side), parent, j[segment - 1], j[segment]))
    spec.append(("Jaw", "Head", pivot, chin))
    for side, (centre, _) in eye_centres.items():
        spec.append(("Eye_" + side, "Head", centre, centre + Vector((0, -.03, 0))))
    bpy.ops.object.select_all(action="DESELECT")
    arm.hide_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        for name, parent, head, tail in spec:
            if (tail - head).length < .004:
                raise ValueError("Degenerate joint " + name)
            bone = arm.data.edit_bones.new(name)
            bone.head, bone.tail = head, tail
            bone.parent = arm.data.edit_bones[parent]
            bone.use_connect = False
            bone.use_deform = True
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.pose.bones:
        bone.rotation_mode = "QUATERNION"

    names = {g.index: g.name for g in body.vertex_groups}
    groups = {g.name: g for g in body.vertex_groups}
    for name, *_ in spec:
        if name not in groups:
            groups[name] = body.vertex_groups.new(name=name)
    head_sources = {n for n in _anatomy()["facial_weights"] if _hero().reduced_joint(n) == "Head"}
    counts = defaultdict(int)
    jaw_share = {}
    shares = _finger_shares(body, used, raw, hands)
    for i, source in enumerate(used):
        r = raw.get(source)
        if not r:
            continue
        vertex = body.data.vertices[i]
        current = {names[g.group]: g.weight for g in vertex.groups if g.weight > 1e-6}
        changed = False
        if i in shares:
            current.update(shares[i])
            changed = True
        share = current.get("Head", 0.0)
        total = sum(w for n, w in r.items() if n in head_sources)
        jaw = sum(r.get(n, 0) for n in JAW_SOURCES)
        if share > 0 and total > 0 and jaw > 0:
            part = min(1.0, jaw / total)
            current["Head"] = share * (1 - part)
            current["Jaw"] = share * part
            jaw_share[i] = part
            changed = True
        if not changed:
            continue
        final = _limit(current)
        for g in list(vertex.groups):
            groups[names[g.group]].remove([i])
        for name, weight in final.items():
            groups[name].add([i], weight, "REPLACE")
            if weight > .01:
                counts[name] += 1
    if eyes:
        eye_groups = {side: eyes.vertex_groups.new(name="Eye_" + side) for side in eye_centres}
        head_group = eyes.vertex_groups.get("Head")
        for v in eyes.data.vertices:
            side = "L" if v.co.x > 0 else "R"
            if head_group:
                head_group.remove([v.index])
            eye_groups[side].add([v.index], 1.0, "REPLACE")
            counts["Eye_" + side] += 1
    face, face_deltas = add_face_shapes(body, used, raw)
    # A fitted beard is a copy of chin and cheek skin and has to open with the jaw.
    followers = {}
    tree = KDTree(len(P))
    for i, p in enumerate(P):
        tree.insert(p, i)
    tree.balance()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name != "IdentityBeard":
            continue
        head_group = obj.vertex_groups.get("Head")
        if not head_group:
            continue
        jaw_group = obj.vertex_groups.new(name="Jaw")
        basis = obj.data.shape_keys.key_blocks[0].data if obj.data.shape_keys else obj.data.vertices
        moved = 0
        for v in obj.data.vertices:
            _, nearest, _ = tree.find(basis[v.index].co)
            part = jaw_share.get(nearest, 0.0)
            if part <= 0:
                continue
            share = 0.0
            for g in v.groups:
                if g.group == head_group.index:
                    share = g.weight
            if share <= 0:
                continue
            head_group.add([v.index], share * (1 - part), "REPLACE")
            jaw_group.add([v.index], share * part, "REPLACE")
            moved += 1
        if obj.data.shape_keys:
            nearest = [tree.find(basis[v.index].co)[1] for v in obj.data.vertices]
            for name in FACE_SHAPES:
                key = obj.shape_key_add(name=name, from_mix=False)
                key.value = 0.0
                for index, source_index in enumerate(nearest):
                    delta = face_deltas[name].get(source_index)
                    if delta is not None:
                        key.data[index].co = basis[index].co + delta
        followers[obj.name] = moved
    missing = [name for name, *_ in spec if counts[name] < 4]
    if missing:
        raise ValueError("Added joints without skin: " + str(missing))
    arm["adult_rig"] = "fingers_jaw_eyes_v1"
    _STATE[arm.name] = {"hands": hands}
    report = {
        "joints": len(arm.data.bones), "added": [name for name, *_ in spec],
        "weighted_vertices_over_1pct": {name: counts[name] for name, *_ in spec},
        "maximum_vertex_influences": 4,
        "jaw": {"pivot": [round(c, 5) for c in pivot], "chin": [round(c, 5) for c in chin],
                "pivot_spread_m": round(pivot_spread, 5), "samples": jaw_samples,
                "open_axis": "+X (armature space), %g degrees equal the JawOpen morph" % JAW_MORPH_DEGREES},
        "eyes": {side: {"centre": [round(c, 5) for c in centre], "size": [round(c, 5) for c in size]}
                 for side, (centre, size) in eye_centres.items()},
        "hands": {side: {"rest_curl_evidence": round(hand["rest_curl_evidence"], 8),
                         "palm_normal": [round(c, 4) for c in hand["normal"]],
                         "finger_lengths_m": {f: [round((c["joints"][k + 1] - c["joints"][k]).length, 4) for k in range(3)]
                                              for f, c in hand["chains"].items()},
                         "finger_radius_m": {f: [round(x, 4) for x in c["radius"]] for f, c in hand["chains"].items()}}
                  for side, hand in hands.items()},
        "followers": followers, "face": face,
    }
    return report


_STATE = {}


def _pose(value):
    """A finger pose is (knuckle, middle joint, end joint[, thumb swing in degrees]) in curl units."""
    if isinstance(value, (int, float)):
        return (float(value),) * 3 + (0.0,)
    value = tuple(value)
    return value + (0.0,) * (4 - len(value))


def _posed_chain(chain, hand, finger, value, spread=0.0):
    """Forward kinematics of one finger: joints, local and world rotation per segment."""
    pose = _pose(value)
    table = THUMB_FLEX if finger == "Thumb" else FLEX
    j = chain["joints"]
    rotation = Quaternion()
    positions = [j[0].copy()]
    locals_, world = [], []
    for k in range(3):
        step = Quaternion(chain["axes"][k], math.radians(table[k] * pose[k]))
        if k == 0 and finger == "Thumb" and pose[3]:
            step = Quaternion(hand["swing"], math.radians(pose[3])) @ step
        elif k == 0 and spread:
            step = step @ Quaternion(hand["normal"], math.radians(spread))
        locals_.append(step)
        rotation = rotation @ step
        world.append(rotation.copy())
        positions.append(positions[-1] + rotation @ (j[k + 1] - j[k]))
    return positions, locals_, world


def _gaps(chain, hand, finger, value, tree):
    """Signed gap between each segment's surface and the held object (negative: inside)."""
    positions, _, _ = _posed_chain(chain, hand, finger, value)
    result = []
    for k in range(3):
        a, b = positions[k], positions[k + 1]
        best = math.inf
        for u in (.2, .4, .6, .8, 1.0):
            p = a.lerp(b, u)
            location, normal, _, distance = tree.find_nearest(p)
            if location is None:
                continue
            if (p - location).dot(normal) < 0:
                distance = -distance
            best = min(best, distance - chain["radius"][k])
        result.append(best)
    return result, positions


def _wrap_finger(chain, hand, finger, tree, touch=.0008):
    """Close knuckle, middle and end joint one after the other until each segment rests on the bar."""
    pose = [0.0, 0.0, 0.0]
    gaps, _ = _gaps(chain, hand, finger, pose, tree)
    if min(gaps) < 0:
        return None, gaps
    for joint in range(3):
        while pose[joint] < 1.0:
            trial = list(pose)
            trial[joint] = min(1.0, pose[joint] + .02)
            gaps, _ = _gaps(chain, hand, finger, trial, tree)
            if min(gaps[joint:]) < touch:
                break
            pose = trial
    gaps, _ = _gaps(chain, hand, finger, pose, tree)
    return tuple(pose), gaps


def _wrap_thumb(chain, hand, tree, index_positions, index_radius):
    """Swing the thumb around the bar and lay it over the index finger."""
    best = None
    target = index_positions[1].lerp(index_positions[2], .5)
    for swing in range(-30, 91, 6):
        for flex in range(0, 21):
            for bend in (0.0, .35, .7):
                pose = (flex / 20, flex / 20 * .8 + bend * .2, bend, float(swing))
                gaps, positions = _gaps(chain, hand, "Thumb", pose, tree)
                if min(gaps) < 0:
                    continue
                tip = positions[3]
                overlap = (tip - target).length - chain["radius"][2] - index_radius
                if overlap < -.002:
                    continue
                # Prefer a thumb that touches the bar and reaches the index finger.
                score = abs(overlap) + 1.5 * max(0.0, min(gaps)) + .5 * max(0.0, gaps[2])
                if best is None or score < best[0]:
                    best = (score, pose, gaps)
    return (best[1], best[2]) if best else (None, None)


def _held(kit, arm, side):
    """Kit vertices that travel with one hand (its own weight or a prop joint below it)."""
    carried = {"Hand_" + side}
    extra = set(added_bones())
    for bone in arm.data.bones["Hand_" + side].children_recursive:
        if bone.name not in extra:
            carried.add(bone.name)
    indices = {g.index for g in kit.vertex_groups if g.name in carried}
    held = set()
    for v in kit.data.vertices:
        if sum(g.weight for g in v.groups if g.group in indices) > .5:
            held.add(v.index)
    return held


def _fit_grips(arm, hands):
    """Close each finger onto the kit geometry bound to its hand (weapon, bow, shield)."""
    result = {}
    kit = bpy.data.objects.get("FrontierRomanKit")
    for side in ("L", "R"):
        hand = hands[side]
        fitted = None
        held = _held(kit, arm, side) if kit else set()
        if held and _handle(_surface_samples(kit, held), hand["wrist"]):
            polygons = [list(p.vertices) for p in kit.data.polygons if all(i in held for i in p.vertices)]
            tree = BVHTree.FromPolygons([v.co.copy() for v in kit.data.vertices], polygons)
            fitted = {}
            for finger, _ in FINGERS[1:]:
                pose, gaps = _wrap_finger(hand["chains"][finger], hand, finger, tree)
                fitted[finger] = {"pose": [round(c, 3) for c in pose] if pose else None,
                                  "gaps_m": [round(g, 4) for g in gaps]}
            index = fitted["Index"]["pose"] or _pose(FIST["Index"])[:3]
            positions, _, _ = _posed_chain(hand["chains"]["Index"], hand, "Index", index)
            pose, gaps = _wrap_thumb(hand["chains"]["Thumb"], hand, tree, positions, hand["chains"]["Index"]["radius"][1])
            fitted["Thumb"] = {"pose": [round(c, 3) for c in pose] if pose else None,
                               "gaps_m": [round(g, 4) for g in gaps] if gaps else None}
        result[side] = fitted
    return result


def fit_grips(arm):
    state = _STATE[arm.name]
    state["grips"] = _fit_grips(arm, state["hands"])
    return state["grips"]


def _grip_curls(state, side, fallback):
    grips = state.get("grips", {}).get(side)
    curls = {}
    for finger, _ in FINGERS:
        entry = grips.get(finger) if grips else None
        curls[finger] = _pose(entry["pose"]) if entry and entry["pose"] else _pose(fallback[finger])
    return curls


FIST = {"Thumb": (.70, .70, .70, 25.0), "Index": .82, "Middle": .86, "Ring": .88, "Pinky": .90}
WORK = {"Thumb": (.50, .50, .50, 12.0), "Index": .56, "Middle": .62, "Ring": .66, "Pinky": .70}


def _mix(a, b, t):
    return {f: tuple(x + (y - x) * t for x, y in zip(_pose(a[f]), _pose(b[f]))) for f in a}


def _add(pose, amount):
    return {f: tuple(min(1.0, c + amount) for c in _pose(v)[:3]) + (_pose(v)[3],) for f, v in pose.items()}


def finger_curls(clip, t, side, soldier_role, state):
    """Curl per finger (0 flat, 1 closed) and spread in degrees for one sample."""
    wave = math.sin(math.tau * t)
    pulse = math.sin(math.pi * t) ** 2
    relaxed = dict(RELAXED)
    spread = 2.0
    if soldier_role:
        grip = _grip_curls(state, side, FIST)
        if soldier_role == "archer" and side == "R":
            # Three-finger draw; the hand opens on release.
            draw = min(1, t / .42) if t < .74 else max(0, 1 - (t - .74) / .08)
            hook = {"Thumb": .35, "Index": (.35, .80, .70), "Middle": (.35, .82, .72), "Ring": (.38, .82, .72), "Pinky": .88}
            curls = _mix(relaxed, hook, draw) if clip == "shoot" else _mix(relaxed, FIST, .35)
            return curls, spread
        if clip == "death":
            return _mix(grip, _mix(grip, relaxed, .45), min(1, t / .6)), 0.0
        squeeze = .03 * pulse if clip in ("attack", "hit", "block", "wall", "testudo") else 0.0
        return _add(grip, squeeze), 0.0
    if clip in ("march", "run"):
        phase = t + (.5 if side == "L" else 0)
        swing = math.sin(math.tau * phase)
        base = _mix(relaxed, FIST, .12 if clip == "march" else .42)
        return _add(base, .035 * swing), spread
    if clip == "talk":
        # Open the hand with each gesture; the index finger leads.
        curls = {}
        for order, (finger, _) in enumerate(FINGERS):
            lead = math.sin(math.pi * min(1, max(0, t * 1.08 - .03 * order))) ** 2
            beat = .5 + .5 * math.sin(math.tau * (2 * t - .07 * order) + (0 if side == "R" else 1.3))
            curls[finger] = relaxed[finger] * (1 - .55 * lead * beat)
        return curls, 2.0 + 5.0 * pulse
    if clip in ("work", "gather"):
        return _mix(relaxed, WORK, .35 + .65 * pulse), 1.0
    if clip in ("train", "attack", "block"):
        target = FIST if side == "R" else WORK
        return _mix(_mix(relaxed, target, .85), target, pulse), 0.0
    if clip == "hit":
        return _mix(relaxed, FIST, .25 + .55 * pulse), 4.0 * pulse
    if clip == "death":
        limp = _add(relaxed, .08)
        return _mix(_mix(relaxed, FIST, .4 * math.sin(math.pi * min(1, t / .35))), limp, min(1, t / .8)), spread
    # idle: breathing reaches the fingers as a very small movement.
    return _add(relaxed, .018 * wave * (1 if side == "L" else -1)), spread


SPREAD_SHARE = {"Thumb": 0.0, "Index": -1.0, "Middle": -.25, "Ring": .5, "Pinky": 1.0}


def local_rotations(arm, side, curls, spread):
    """Pose-bone quaternions for one hand."""
    hand = _STATE[arm.name]["hands"][side]
    result = {}
    for finger, _ in FINGERS:
        chain = hand["chains"][finger]
        pose = _pose(curls[finger])
        _, steps, _ = _posed_chain(chain, hand, finger, pose,
                                   spread * SPREAD_SHARE[finger] * (1 - min(1.0, max(0.0, pose[0]))))
        for segment, step in zip((1, 2, 3), steps):
            name = bone_name(finger, segment, side)
            rest = arm.data.bones[name].matrix_local.to_quaternion()
            result[name] = rest.inverted() @ step @ rest
    return result


def bake(arm, soldier_role=None):
    """Key the finger joints in every clip of the opened source."""
    state = _STATE[arm.name]
    tracks = arm.animation_data.nla_tracks if arm.animation_data else []
    report = {}
    for track in tracks:
        clip = track.name
        for strip in track.strips:
            action = strip.action
            start, end = (int(round(x)) for x in action.frame_range)
            frames = list(range(start, end + 1))
            samples = defaultdict(list)
            for frame in frames:
                t = (frame - start) / max(1, end - start)
                for side in ("L", "R"):
                    curls, spread = finger_curls(clip, t, side, soldier_role, state)
                    for name, value in local_rotations(arm, side, curls, spread).items():
                        samples[name].append(value)
            for name, values in samples.items():
                # Keep the short rotation between neighbouring keys.
                for k in range(1, len(values)):
                    if values[k - 1].dot(values[k]) < 0:
                        values[k] = -values[k]
                path = 'pose.bones["%s"].rotation_quaternion' % name
                for index in range(4):
                    existing = action.fcurves.find(path, index=index)
                    if existing:
                        action.fcurves.remove(existing)
                    curve = action.fcurves.new(path, index=index, action_group=name)
                    curve.keyframe_points.add(len(frames))
                    for point, frame, value in zip(curve.keyframe_points, frames, values):
                        point.co = (frame, value[index])
                        point.interpolation = "LINEAR"
                    curve.update()
            report[clip] = len(frames)
    return report


def _hands_of(body):
    used = base_indices(len(body.data.vertices))
    raw = _raw_weights()
    P = [v.co.copy() for v in body.data.vertices]
    authored = _authored_joints(P, used)
    return used, raw, {side: _measure_hand(side, P, used, raw, authored[side]) for side in ("L", "R")}


def _reference_hand_ratio():
    """Hand length over forearm length of the anatomical source."""
    anatomy = _anatomy()
    raw = anatomy["raw_variants"][0]
    groups = anatomy["facegroups"]

    def helper(name):
        return Vector(raw[list(groups["joint-" + name])].mean(axis=0))

    chain = [helper("l-hand")] + [helper("l-finger-3-%d" % k) for k in (1, 2, 3, 4)]
    hand = sum((chain[k + 1] - chain[k]).length for k in range(4))
    return hand / (helper("l-hand") - helper("l-elbow")).length


def _surface_samples(kit, held, spacing=.008):
    """Area-weighted points on the held kit surface."""
    points, weights = [], []
    for polygon in kit.data.polygons:
        if not all(i in held for i in polygon.vertices):
            continue
        corners = [kit.data.vertices[i].co for i in polygon.vertices]
        for k in range(1, len(corners) - 1):
            a, b, c = corners[0], corners[k], corners[k + 1]
            area = (b - a).cross(c - a).length / 2
            if area <= 0:
                continue
            steps = max(1, int(max((b - a).length, (c - a).length, (c - b).length) / spacing))
            local = []
            for u in range(steps + 1):
                for v in range(steps + 1 - u):
                    local.append(a + (b - a) * (u / steps) + (c - a) * (v / steps))
            points.extend(local)
            weights.extend([area / len(local)] * len(local))
    return np.array([p[:] for p in points]), np.array(weights)


def _weighted_median(values, weights):
    order = np.argsort(values)
    total = np.cumsum(weights[order])
    return float(values[order][np.searchsorted(total, total[-1] / 2)])


def _handle(samples, wrist):
    """Axis, centre and radius of a bar that passes the hand; None for boards and free hands."""
    points, weights = samples
    if len(points) < 24:
        return None
    mean = np.average(points, axis=0, weights=weights)
    values, vectors = np.linalg.eigh(np.cov((points - mean).T, aweights=weights))
    if values[2] < 6.0 * values[1]:
        return None
    axis = vectors[:, 2] / np.linalg.norm(vectors[:, 2])
    w = np.array(wrist[:])
    along = (points - mean) @ axis
    window = (np.abs(along - (w - mean) @ axis) < .07) & (np.linalg.norm(points - w, axis=1) < .14)
    if window.sum() < 12:
        return None
    local, local_weights = points[window], weights[window]
    centre = np.average(local, axis=0, weights=local_weights)
    for _ in range(2):
        offset = local - centre
        radial = np.linalg.norm(offset - np.outer(offset @ axis, axis), axis=1)
        keep = radial <= 2.0 * _weighted_median(radial, local_weights)
        centre = np.average(local[keep], axis=0, weights=local_weights[keep])
    offset = local[keep] - centre
    radial = np.linalg.norm(offset - np.outer(offset @ axis, axis), axis=1)
    # The business end (blade, spear head) lies on the thumb side.
    far = points[np.argmax(np.abs(along))]
    if (far - centre) @ axis < 0:
        axis = -axis
    return Vector(axis), Vector(centre), _weighted_median(radial, local_weights[keep])


def refit_soldier_hands(arm):
    """Give the soldiers adult hands and put the held bar into the palm. All tiers.

    The company fit scaled every hand with the short company hand joint (to
    about two thirds of the source proportion) and left weapon and bow beside
    the fingers. Here each hand returns to the source's hand-to-forearm ratio,
    turns about its wrist so that the knuckle line follows the held bar, and
    the bar moves sideways into the palm. Boards (shields) only get the size.
    """
    body = bpy.data.objects["HeroBody"]
    kit = bpy.data.objects.get("FrontierRomanKit")
    used, raw, hands = _hands_of(body)
    names = {g.index: g.name for g in body.vertex_groups}
    ratio = _reference_hand_ratio()
    report = {}
    for side in ("L", "R"):
        hand = hands[side]
        wrist = hand["wrist"]
        middle = hand["chains"]["Middle"]["joints"]
        length = (middle[0] - wrist).length + sum((middle[k + 1] - middle[k]).length for k in range(3))
        scale = max(1.0, min(1.8, ratio * arm.data.bones["Forearm_" + side].length / length))
        rotation = Quaternion()
        entry = {"scale": round(scale, 4), "hand_length_before_m": round(length, 4)}
        held = _held(kit, arm, side) if kit else set()
        samples = _surface_samples(kit, held) if held else None
        bar = _handle(samples, wrist) if samples is not None else None
        if bar:
            axis, centre, radius = bar
            index, pinky = hand["chains"]["Index"]["joints"][0], hand["chains"]["Pinky"]["joints"][0]
            normal = hand["normal"]
            across = pinky - index
            across = (across - normal * across.dot(normal)).normalized()
            new_normal = (normal - axis * normal.dot(axis)).normalized()
            new_across = -axis
            before = Matrix((across, normal.cross(across), normal)).transposed()
            after = Matrix((new_across, new_normal.cross(new_across), new_normal)).transposed()
            rotation = (after @ before.inverted()).to_quaternion()
            # Where the bar has to lie: across the palm below the knuckles.
            base = wrist.lerp((index + pinky) / 2, .66)
            pad = hand["chains"]["Middle"]["radius"][0] * scale
            grip = wrist + rotation @ ((base - wrist) * scale) + new_normal * (radius + pad)
            shift = grip - centre
            shift -= axis * shift.dot(axis)
            # Slide along the bar until guard and pommel are clear of the fist.
            spans = [(wrist + rotation @ ((p - wrist) * scale) - centre).dot(axis) for p in (index, pinky)]
            reach = hand["chains"]["Index"]["radius"][0] * scale + .004
            low, high = min(spans) - reach, max(spans) + reach
            profile = defaultdict(float)
            for q in samples[0]:
                p = Vector(q)
                along = (p - centre).dot(axis)
                profile[round(along / .005)] = max(profile[round(along / .005)],
                                                   ((p - centre) - axis * along).length)
            slide = 0.0
            for step in sorted(range(-24, 25), key=abs):
                candidate = step * .005
                bins = range(int(math.floor((low - candidate) / .005)), int(math.ceil((high - candidate) / .005)) + 1)
                if all(profile.get(b, 0.0) <= radius * 1.3 + .003 for b in bins):
                    slide = candidate
                    break
            shift += axis * slide
            carried = [kit.data.vertices[i] for i in held]
            for v in carried:
                v.co += shift
            kit.data.update()
            entry.update({"bar_radius_m": round(radius, 4), "bar_shift_m": [round(c, 4) for c in shift],
                          "bar_slide_m": round(slide, 4),
                          "wrist_turn_degrees": round(math.degrees(rotation.angle), 1)})
        blocks = list(body.data.shape_keys.key_blocks) if body.data.shape_keys else []
        index_of = next(g.index for g in body.vertex_groups if g.name == "Hand_" + side)
        moved = 0
        for vertex in body.data.vertices:
            share = 0.0
            for g in vertex.groups:
                if g.group == index_of:
                    share = g.weight
            if share <= 0:
                continue
            moved += 1
            targets = [block.data[vertex.index] for block in blocks] or [vertex]
            for target in targets:
                fitted = wrist + rotation @ ((target.co - wrist) * scale)
                target.co = target.co.lerp(fitted, share)
            if blocks:
                vertex.co = blocks[0].data[vertex.index].co
        entry["vertices"] = moved
        report[side] = entry
    body.data.update()
    return report


def apply(arm, soldier_role=None):
    """Extend the opened source and key its clips."""
    report = extend(arm)
    if soldier_role:
        report["grips"] = fit_grips(arm)
    report["clips"] = bake(arm, soldier_role)
    return report


def prepare(arm, level, soldier_role=None):
    """Everything an export tier needs, on the freshly opened source before decimation.

    Every tier gets the same joints and finger keys: the runtime carries poses
    across a detail switch joint by joint, and the motion gate compares them.
    """
    report = {"level": level}
    if soldier_role:
        report["hand_refit"] = refit_soldier_hands(arm)
    report.update(apply(arm, soldier_role))
    return report


RUNTIME_JOINTS = ("Jaw", "Eye_L", "Eye_R")


def release_runtime_joints(path):
    """Drop the clip channels of jaw and eyes from an exported GLB.

    Speech, gaze and expression drive these joints at runtime. A clip that
    keyed them (the exporter writes a constant rest key for every joint) would
    reset them on every animation step. Only the JSON chunk changes.
    """
    data = Path(path).read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    document = json.loads(data[20:20 + length])
    rest = data[20 + length:]
    released = {i for i, node in enumerate(document.get("nodes", [])) if node.get("name") in RUNTIME_JOINTS}
    removed = 0
    for animation in document.get("animations", []):
        kept = [c for c in animation["channels"] if c["target"].get("node") not in released]
        removed += len(animation["channels"]) - len(kept)
        animation["channels"] = kept
    if not removed:
        return {"released_channels": 0}
    text = json.dumps(document, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    body = struct.pack("<I4s", len(text), b"JSON") + text + rest
    Path(path).write_bytes(data[:8] + struct.pack("<I", 12 + len(body)) + body)
    return {"released_channels": removed}
