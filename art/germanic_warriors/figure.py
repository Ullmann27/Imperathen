"""Anatomical base, rig fit, grip, body build and face variants (Blender).

The body is the complete vendored CC0 MakeHuman base mesh (adult target as in
the hero build), fitted onto the unchanged fifteen-bone company skeleton of
art/soldiers/build.py exactly as the frontier soldiers are. Covered skin is
removed later by the tailoring step, after the garments exist.
"""
from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
HERO_BLEND = ROOT / "art/hero_quality/hero.blend"
MALE_SKIN = ROOT / "art/hero_quality/source/system_assets/skins/young_caucasian_male/young_lightskinned_male_diffuse.png"


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


hero = _module("germanic_hero_source", ROOT / "tools/characters/build_hero.py")
frontier = _module("germanic_frontier_source", ROOT / "tools/characters/build_frontier_people.py")
soldier = frontier.soldier


class Anatomy:
    """Loaded once per Blender session; every figure starts from these arrays."""
    _cache = None

    @classmethod
    def get(cls):
        if cls._cache is None:
            data = hero.load_anatomy()
            faces = data["faces"]
            used = sorted({v for i, g in enumerate(data["groups"]) if g == "body" for v in faces[i]})
            data["used"] = used
            data["index"] = {v: i for i, v in enumerate(used)}
            cls._cache = data
        return cls._cache


def _bake_mature():
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.data.shape_keys:
            continue
        keys = obj.data.shape_keys.key_blocks
        mature = keys.get("Mature")
        if mature:
            basis = keys[0]
            deltas = [mature.data[i].co - basis.data[i].co for i in range(len(obj.data.vertices))]
            for key in keys:
                key.value = 0
                for i, v in enumerate(key.data):
                    v.co += deltas[i]
            for i, v in enumerate(obj.data.vertices):
                v.co = basis.data[i].co
            obj.shape_key_remove(mature)
        companion = obj.data.shape_keys.key_blocks.get("Companion") if obj.data.shape_keys else None
        if companion:
            obj.shape_key_remove(companion)


def landmark_points(anatomy):
    """Anatomical joint helpers of the adult body (hero rig space)."""
    p = anatomy["points"][1]
    groups = anatomy["facegroups"]

    def mean(name):
        return Vector(p[list(groups[name])].mean(axis=0))

    marks = {}
    for side in ("l", "r"):
        s = side.upper()
        marks["wrist_" + s] = mean(f"joint-{side}-hand")
        marks["ankle_" + s] = mean(f"joint-{side}-ankle")
        marks["eye_" + s] = mean(f"joint-{side}-eye")
        for finger in range(1, 6):
            for joint in range(1, 5):
                marks[f"finger_{s}_{finger}_{joint}"] = mean(f"joint-{side}-finger-{finger}-{joint}")
    marks["mouth"] = mean("joint-mouth")
    marks["jaw"] = mean("joint-jaw")
    marks["neck"] = mean("joint-neck")
    marks["head"] = mean("joint-head")
    marks["head_top"] = mean("joint-head-2")
    return marks


def open_base(anatomy, name="GermanicRig"):
    """Hero eyes and skin material, complete adult body, fitted company rig."""
    bpy.ops.wm.open_mainfile(filepath=str(HERO_BLEND))
    keep = {"HeroRig", "HeroEyes", "HeroBody"}
    for obj in list(bpy.context.scene.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(bpy.data.objects["HeroBody"], do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    arm = bpy.data.objects["HeroRig"]
    arm.animation_data_clear()
    for bone in arm.pose.bones:
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bpy.context.scene.frame_set(0)
    skin = bpy.data.materials["HeroSkin"]
    # hero.body() removes faces a tunic covers. All faces are needed here: the
    # warriors' own garments decide what is covered.
    joints = dict(anatomy["joints"])
    head = joints["Head"]
    joints["Head"] = (Vector((0, 0, -10)), head[1], head[2])
    view = dict(anatomy)
    view["joints"] = joints
    body, _ = hero.body(view, arm, skin)
    if len(body.data.vertices) != len(anatomy["used"]):
        raise RuntimeError("Complete anatomical body expected")
    body.name = "GermanicBody"
    body.data.name = "GermanicBody"
    # Landmarks travel through the rig fit as a hidden helper mesh.
    marks = landmark_points(anatomy)
    names = sorted(marks)
    tree = KDTree(len(body.data.vertices))
    for v in body.data.vertices:
        tree.insert(v.co, v.index)
    tree.balance()
    weights = []
    mature = body.data.shape_keys.key_blocks["Mature"]
    mature_tree = KDTree(len(mature.data))
    for i, v in enumerate(mature.data):
        mature_tree.insert(v.co, i)
    mature_tree.balance()
    for key in names:
        _, index, _ = mature_tree.find(marks[key])
        row = {}
        for g in body.data.vertices[index].groups:
            row[body.vertex_groups[g.group].name] = g.weight
        weights.append(row)
    helper = hero.mesh_object("GermanicLandmarks", [marks[k] for k in names], [])
    hero.bind(helper, arm, weights)
    helper["names"] = names
    _bake_mature()
    frontier.neutral_eyes()
    target = soldier.skeleton("spear")
    fit_rig(arm, target)
    target.name = name
    target.data.name = name
    positions = {k: helper.data.vertices[i].co.copy() for i, k in enumerate(names)}
    bpy.data.objects.remove(helper, do_unlink=True)
    return target, body, bpy.data.objects["HeroEyes"], positions


# The youth-height adult body is about 1.17 times smaller than the company
# skeleton (head top 1.49 m against 1.78 m). frontier.fit_to_company scales
# each bone uniformly by its length ratio, which inflates the pelvis by 52 %,
# the upper arm by 33 % and shrinks the hands to 68 %. Here limbs stretch only
# along their bone; girth follows one global factor.
GIRTH = 1.17
HAND = 1.10


def fit_rig(source_arm, target_arm):
    transforms = {}
    for name in source_arm.data.bones.keys():
        src, dst = source_arm.data.bones[name], target_arm.data.bones[name]
        a, b = src.head_local, src.tail_local
        if name == "Head":
            linear = Matrix.Scale(GIRTH, 3)
            rotation = Matrix.Identity(3)
        elif name.startswith("Hand"):
            rotation = (b - a).rotation_difference(dst.tail_local - dst.head_local).to_matrix()
            linear = Matrix.Scale(HAND, 3)
        else:
            d = (b - a).normalized()
            along = dst.length / src.length
            outer = Matrix(((d.x * d.x, d.x * d.y, d.x * d.z), (d.y * d.x, d.y * d.y, d.y * d.z), (d.z * d.x, d.z * d.y, d.z * d.z)))
            linear = Matrix.Scale(GIRTH, 3)
            for r in range(3):
                for c in range(3):
                    linear[r][c] += (along - GIRTH) * outer[r][c]
            rotation = (b - a).rotation_difference(dst.tail_local - dst.head_local).to_matrix()
        m = (rotation @ linear).to_4x4()
        transforms[name] = Matrix.Translation(dst.head_local) @ m @ Matrix.Translation(-a)
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        weights = []
        for vertex in obj.data.vertices:
            row = [(obj.vertex_groups[g.group].name, g.weight) for g in vertex.groups if obj.vertex_groups[g.group].name in transforms]
            total = sum(w for _, w in row)
            weights.append([(n, w / total) for n, w in row] if total else [("Spine", 1.0)])
        blocks = list(obj.data.shape_keys.key_blocks) if obj.data.shape_keys else []
        if blocks:
            for block in blocks:
                for i, vertex in enumerate(block.data):
                    vertex.co = sum(((transforms[n] @ vertex.co) * w for n, w in weights[i]), Vector())
            for i, vertex in enumerate(obj.data.vertices):
                vertex.co = blocks[0].data[i].co
        else:
            for i, vertex in enumerate(obj.data.vertices):
                vertex.co = sum(((transforms[n] @ vertex.co) * w for n, w in weights[i]), Vector())
        obj.parent = target_arm
        obj.matrix_parent_inverse = Matrix.Identity(4)
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = target_arm
    bpy.data.objects.remove(source_arm, do_unlink=True)


def apply_to_mesh(obj, function, mask=None):
    """Move basis and every shape key with the same per-vertex function."""
    keys = obj.data.shape_keys.key_blocks if obj.data.shape_keys else []
    if keys:
        basis = [v.co.copy() for v in keys[0].data]
        new_basis = [function(i, p.copy()) if (mask is None or mask[i]) else p for i, p in enumerate(basis)]
        for key in keys:
            for i, v in enumerate(key.data):
                v.co = v.co + (new_basis[i] - basis[i])
        for i, v in enumerate(obj.data.vertices):
            v.co = keys[0].data[i].co
    else:
        for v in obj.data.vertices:
            if mask is None or mask[v.index]:
                v.co = function(v.index, v.co.copy())
    obj.data.update()


def vertex_weights(obj):
    names = [g.name for g in obj.vertex_groups]
    rows = []
    for v in obj.data.vertices:
        rows.append({names[g.group]: g.weight for g in v.groups if g.weight > 0})
    return rows


def bone_weight(rows, i, *bones):
    return sum(rows[i].get(b, 0.0) for b in bones)


def ground_feet(body, eyes, arm):
    """Put the fitted soles on the floor without moving any bone.

    The fitted foot is shorter below the ankle than the company foot, so the
    sole floats about 3 cm. Lower foot and lower shin, blending to zero at
    mid-shin; the ankle bone height and every clip stay unchanged.
    """
    rows = vertex_weights(body)
    foot = [v.co.z for v in body.data.vertices if bone_weight(rows, v.index, "Foot_L", "Foot_R") > .5]
    lift = min(foot)
    top = .30

    def move(i, p):
        legs = bone_weight(rows, i, "Foot_L", "Foot_R", "Shin_L", "Shin_R")
        if legs <= 0 or p.z >= top:
            return p
        t = min(1.0, max(0.0, (top - p.z) / (top - .12)))
        t = t * t * (3 - 2 * t)
        p.z -= lift * t * min(1.0, legs)
        return p

    apply_to_mesh(body, move)
    low = min(v.co.z for v in body.data.vertices)
    return {"fitted_sole_height_m": lift, "grounded_lowest_vertex_m": low}


def grip_hands(body, marks, styles):
    """Bake a closed grip around a vertical shaft into the rest mesh.

    The wrist turns the hand forward (thumb up) and the fingers close with the
    anatomical finger-segment weights, so a vertical spear, sword or the
    vertical shield handle passes through the fist as the company equipment
    expects. Returns the grip frame of each hand (centre and shaft axis).
    """
    anatomy = Anatomy.get()
    index = anatomy["index"]
    facial = anatomy["facial_weights"]
    frames = {}
    for side in ("L", "R"):
        style = styles.get(side, "fist")
        if style == "open":
            continue
        wrist = marks["wrist_" + side]
        # Turn about the lateral axis until the knuckle line stands vertical:
        # a vertical shaft then passes straight through the closed fingers.
        line = marks[f"finger_{side}_2_1"] - marks[f"finger_{side}_5_1"]
        flat_now = Vector((0, line.y, line.z)).normalized()
        target = Vector((0, 0, 1)) if flat_now.y <= 0 else Vector((0, 0, -1))
        angle = math.atan2(flat_now.cross(target).x, flat_now.dot(target))
        turn_x = Matrix.Rotation(angle, 4, "X")
        # Then remove the sideways lean of the knuckle line (radial deviation),
        # so a long shaft stands upright instead of leaning over the head.
        turned = (turn_x.to_3x3() @ line)
        if turned.z < 0:
            turned = -turned
        lean = math.atan2(turned.x, turned.z)
        turn_y = Matrix.Rotation(-lean, 4, "Y")
        wrist_turn = Matrix.Translation(wrist) @ turn_y @ turn_x @ Matrix.Translation(-wrist)
        hand_rows = {}
        for bone, entries in facial.items():
            if not bone.endswith("." + side):
                continue
            if not bone.startswith(("wrist", "finger", "metacarpal")):
                continue
            for vertex, weight in entries:
                if vertex in index:
                    hand_rows[index[vertex]] = hand_rows.get(index[vertex], 0.0) + weight
        # Segment transforms, in the original (pre-turn) space.
        transforms = {}
        joints_after = {}
        palm = Vector((-1.0 if side == "L" else 1.0, 0, 0))
        for finger in range(1, 6):
            joints = [marks[f"finger_{side}_{finger}_{j}"] for j in range(1, 5)]
            angles = (40, 55, 35) if finger == 1 else (80, 95, 60)
            if style == "loose":
                angles = tuple(a * .55 for a in angles)
            parent = Matrix.Identity(4)
            across = (marks[f"finger_{side}_5_1"] - marks[f"finger_{side}_2_1"]).normalized()
            for segment, amount in enumerate(angles, 1):
                start, end = joints[segment - 1], joints[segment]
                axis = across if finger > 1 else (end - start).cross(palm).normalized()
                trial = Matrix.Rotation(math.radians(amount), 4, axis)
                tip = end - start
                if (trial @ tip).dot(palm) < tip.dot(palm):
                    axis = -axis
                transform = parent @ Matrix.Translation(start) @ Matrix.Rotation(math.radians(amount), 4, axis) @ Matrix.Translation(-start)
                transforms[(finger, segment)] = transform
                parent = transform
        segment_rows = {}
        for (finger, segment) in transforms:
            for vertex, weight in facial.get(f"finger{finger}-{segment}.{side}", []):
                if vertex in index:
                    segment_rows.setdefault(index[vertex], []).append(((finger, segment), weight))

        def move(i, p):
            q = p.copy()
            if i in segment_rows:
                delta = Vector()
                for key, weight in segment_rows[i]:
                    delta += (transforms[key] @ p - p) * weight
                q = p + delta
            amount = min(1.0, hand_rows.get(i, 0.0))
            if amount > 0:
                q = q.lerp(wrist_turn @ q, amount)
            return q

        mask = [i in hand_rows or i in segment_rows for i in range(len(body.data.vertices))]
        apply_to_mesh(body, move, mask)
        # Grip centre: inside the closed fingers, between knuckles and palm.
        mids = []
        for finger in range(2, 6):
            joints = [marks[f"finger_{side}_{finger}_{j}"] for j in range(1, 5)]
            moved = transforms[(finger, 1)] @ joints[1]
            mids.append(wrist_turn @ moved)
        knuckles = [wrist_turn @ marks[f"finger_{side}_{finger}_1"] for finger in range(2, 6)]
        centre = sum(((a + b) * .5 for a, b in zip(mids, knuckles)), Vector()) / 4
        axis = (knuckles[0] - knuckles[-1]).normalized()
        if axis.z < 0:
            axis = -axis
        frames[side] = {"centre": centre, "axis": axis, "wrist_turn_degrees": math.degrees(angle),
                        "wrist_lean_degrees": math.degrees(lean)}
    return frames


BUILDS = {
    # Radial scale about each bone axis; anisotropic torso widths; belly depth.
    "lean_young": {"Arm": .93, "Forearm": .95, "Thigh": .94, "Shin": .96, "Spine": (.95, .95), "Pelvis": (.95, .96), "neck": .94, "belly": 0.0},
    "athletic": {"Arm": 1.07, "Forearm": 1.05, "Thigh": 1.04, "Shin": 1.02, "Spine": (1.04, 1.02), "Pelvis": (1.0, 1.0), "neck": 1.04, "belly": 0.0},
    "broad": {"Arm": 1.09, "Forearm": 1.07, "Thigh": 1.06, "Shin": 1.04, "Spine": (1.08, 1.05), "Pelvis": (1.04, 1.04), "neck": 1.08, "belly": .010},
    "stocky": {"Arm": 1.08, "Forearm": 1.05, "Thigh": 1.08, "Shin": 1.05, "Spine": (1.09, 1.12), "Pelvis": (1.07, 1.08), "neck": 1.10, "belly": .028},
    "wiry": {"Arm": .97, "Forearm": 1.0, "Thigh": .97, "Shin": .98, "Spine": (.98, .96), "Pelvis": (.97, .97), "neck": .97, "belly": 0.0},
    "veteran": {"Arm": 1.06, "Forearm": 1.06, "Thigh": 1.03, "Shin": 1.02, "Spine": (1.05, 1.07), "Pelvis": (1.03, 1.05), "neck": 1.06, "belly": .016},
}


def _segment(arm, bone):
    b = arm.data.bones[bone]
    return b.head_local.copy(), b.tail_local.copy()


def shape_body(body, arm, build):
    """Body build as radial changes about the fixed bones (no bone moves)."""
    spec = BUILDS[build]
    rows = vertex_weights(body)
    segments = {name: _segment(arm, name) for name in arm.data.bones.keys()}

    def radial(p, bone, factor):
        a, b = segments[bone]
        axis = b - a
        t = max(0.0, min(1.0, (p - a).dot(axis) / axis.length_squared))
        closest = a + axis * t
        return (p - closest) * (factor - 1)

    def move(i, p):
        delta = Vector()
        for bone, w in rows[i].items():
            if bone in ("Head", "Hand_L", "Hand_R", "Foot_L", "Foot_R"):
                continue
            kind = bone.split("_")[0]
            if kind in ("Spine", "Pelvis"):
                sx, sy = spec[kind]
                centre = Vector((0, -.01, p.z))
                d = p - centre
                if kind == "Spine" and p.z > 1.42:
                    k = spec["neck"]
                    delta += Vector((d.x * (k - 1), d.y * (k - 1), 0)) * w
                else:
                    delta += Vector((d.x * (sx - 1), d.y * (sy - 1), 0)) * w
            elif kind in spec:
                delta += radial(p, bone, spec[kind]) * w
        if spec["belly"] and p.y < -.02:
            z = math.exp(-((p.z - 1.00) / .10) ** 2)
            front = min(1.0, (-.02 - p.y) / .06)
            centre = math.exp(-(p.x / .14) ** 2)
            delta.y -= spec["belly"] * z * front * centre
        return p + delta

    apply_to_mesh(body, move)


def head_frame(marks):
    eye = (marks["eye_L"] + marks["eye_R"]) * .5
    return eye


def shape_face(body, marks, face):
    """Individual facial structure from landmark-relative displacements."""
    eye = head_frame(marks)
    mouth = marks["mouth"]
    rows = vertex_weights(body)
    jaw_w = face.get("jaw_width", 0.0)
    chin_fwd = face.get("chin_forward", 0.0)
    chin_len = face.get("chin_length", 0.0)
    brow = face.get("brow_ridge", 0.0)
    nose_len = face.get("nose_length", 0.0)
    nose_bridge = face.get("nose_bridge", 0.0)
    nose_width = face.get("nose_width", 0.0)
    cheek = face.get("cheekbones", 0.0)
    face_len = face.get("face_length", 0.0)
    eye_depth = face.get("eye_depth", 0.0)
    lips = face.get("lips", 0.0)
    cranium = face.get("cranium", 0.0)

    def g(value, centre, width):
        return math.exp(-((value - centre) / width) ** 2)

    def move(i, p):
        if rows[i].get("Head", 0.0) < .5:
            return p
        x, y, z = p.x, p.y - eye.y, p.z - eye.z
        front = max(0.0, min(1.0, (.05 - y) / .05))
        q = p.copy()
        lower = max(0.0, min(1.0, (-.03 - z) / .06))
        # Jaw width and lower-face length.
        q.x += x * jaw_w * lower
        q.z -= face_len * lower * (1 if z < -.03 else 0)
        # Chin.
        c = g(x, 0, .025) * g(z, mouth.z - eye.z - .045, .022) * front
        q.y -= chin_fwd * c
        q.z -= chin_len * c
        # Brow ridge.
        b = g(z, .018, .012) * g(abs(x), .03, .03) * front
        q.y -= brow * b
        # Eye sockets.
        e = g(z, 0, .012) * g(abs(x), .032, .016) * front
        q.y += eye_depth * e
        # Nose: bridge, length and width.
        n = g(x, 0, .012) * g(z, -.018, .02) * front
        q.y -= nose_bridge * n
        tip = g(x, 0, .015) * g(z, -.040, .012) * front
        q.z -= nose_len * tip
        q.y -= .3 * nose_len * tip
        wing = g(abs(x), .016, .010) * g(z, -.045, .010) * front
        q.x += math.copysign(nose_width * wing, x)
        # Cheekbones.
        k = g(abs(x), .052, .016) * g(z, -.022, .016) * front
        q.x += math.copysign(cheek * k, x)
        q.y -= .5 * cheek * k
        # Lips.
        l = g(x, 0, .022) * g(z, mouth.z - eye.z, .012) * front
        q.y -= lips * l
        # Skull: a little longer or rounder vault.
        if z > .03:
            top = min(1.0, (z - .03) / .08)
            q.y += cranium * top * (1 if y > 0 else .4)
        return q

    apply_to_mesh(body, move)
