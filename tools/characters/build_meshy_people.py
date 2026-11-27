#!/usr/bin/env python3
"""Build fitted, skinned mobile derivatives of the two usable Meshy people.

The canonical GLBs are kept byte-for-byte. This is a project-authored Blender
rig, not a claim that Meshy supplied an armature or that every generated pose is
riggable. Mounted composites and fixed equipment poses remain blocked in the
registry. Run with Blender 4.3+: blender -b -t 2 -P this_file -- --types all
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "prototype/assets/meshy/source/character"
OUT = ROOT / "prototype/assets/meshy/characters"
REPORT = ROOT / "docs/20_meshy_assets/character-build.json"
PROFILES = {
    # Owner's restored, visually inspected originals. Explicit candidate builds only.
    "unit_legacy_blacksmith": {"height": 1.76, "head": .84, "shoulder": .79, "hip": .52,
                                "elbow": .65, "wrist": .495, "hand_x": .188, "elbow_x": .157,
                                "shoulder_x": .115, "lower_arm_start": .128, "separated_downarms": True, "wrist_support": (.385,.410),
                                "sha256": "9f972cab24f3ea8dd896e7d19058dc2c83688942c2cfffd46357670c2aa947e0"},
    "unit_legacy_tunic_villager": {"height": 1.73, "head": .84, "shoulder": .80, "hip": .53,
                                "elbow": .66, "wrist": .54, "hand_x": .214, "elbow_x": .166,
                                "shoulder_x": .102, "lower_arm_start": .134, "separated_downarms": True, "wrist_support": (.370,.405),
                                "sha256": "a7b1bcbe364ae636d7571886401d298099f5472bec2a82f0df45401d6e7e9507"},
    "unit_roman_signifer": {"height": 1.85, "head": .79, "shoulder": .755, "hip": .51,
                            "elbow": .61, "wrist": .475, "hand_x": .145, "shoulder_x": .113,
                            "wrist_support": (.430, .465),
                            "sha256": "15b2afb0c22d187f45c37a84d272cb215ff39388ee4fde23c8cec668cb042370"},
    "unit_germanic_axe_fighter": {"height": 1.78, "head": .825, "shoulder": .785, "hip": .525,
                                 "elbow": .63, "wrist": .485, "hand_x": .165, "shoulder_x": .125,
                                 "wrist_support": (.465, .495),
                                 "sha256": "9c6cb7e4f57ce3b0c4178bb269cad830183bb0796ccd419d5c74ada31ba9bffc"},
}
TIERS = ((0, 28000, 2048), (1, 10000, 1024), (2, 3500, 512), (3, 1200, 256))
CLIPS = {"idle": 2.0, "march": 1.0, "run": .72, "talk": 1.35,
         "work": 1.6, "gather": 1.15, "train": .86, "attack": .8,
         "block": 1.2, "hit": .48, "death": 1.2}


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


soldier = module("meshy_motion_source", ROOT / "art/soldiers/build.py")
body_seam = module("meshy_body_seam", ROOT / "tools/characters/smooth_meshy_body_seam.py")
original_pose = soldier.pose


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smooth(a, b, value):
    t = clamp((value - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def separate_contact_fans(body):
    """Undo point/edge contacts between otherwise distinct surface fans.

    Coincident-vertex welding is needed for coherent LODs, but a hand touching
    a tunic must not weld both surfaces into a single skin. Preserve connected
    manifold face fans at every vertex, with their original per-corner UVs.
    """
    mesh = body.data
    edges = {}
    parents = [{} for _ in mesh.vertices]
    for face in mesh.polygons:
        vertices = list(face.vertices)
        for vertex in vertices:
            parents[vertex][face.index] = face.index
        for index, a in enumerate(vertices):
            b = vertices[(index + 1) % len(vertices)]
            edges.setdefault(tuple(sorted((a, b))), []).append(face.index)

    def root(parent, face):
        while parent[face] != face:
            parent[face] = parent[parent[face]]
            face = parent[face]
        return face

    for (a, b), faces in edges.items():
        if len(faces) == 2:
            for vertex in (a, b):
                parent = parents[vertex]
                parent[root(parent, faces[0])] = root(parent, faces[1])
    points, faces, mapping = [], [], {}
    for face in mesh.polygons:
        polygon = []
        for vertex in face.vertices:
            key = (vertex, root(parents[vertex], face.index))
            if key not in mapping:
                mapping[key] = len(points)
                points.append(mesh.vertices[vertex].co.copy())
            polygon.append(mapping[key])
        faces.append(polygon)
    split_count = len(points) - len(mesh.vertices)
    if split_count > 0:
        repaired = bpy.data.meshes.new(mesh.name + "_separated_contacts")
        repaired.from_pydata(points, [], faces)
        for material in mesh.materials:
            repaired.materials.append(material)
        for source, target in zip(mesh.polygons, repaired.polygons):
            target.material_index = source.material_index
            target.use_smooth = source.use_smooth
        for source_uv in mesh.uv_layers:
            target_uv = repaired.uv_layers.new(name=source_uv.name)
            for source, target in zip(source_uv.data, target_uv.data):
                target.uv = source.uv
        repaired.validate(clean_customdata=True)
        repaired.update()
        body.data = repaired
    print("MESHY_SEPARATED_CONTACT_VERTICES", split_count, flush=True)
    return split_count


def separate_signifer_hands(body, profile):
    """Separate the reviewed skin/tunic contacts in this canonical source.

    The signifer has actual UV-distinct hand/tunic triangles sharing vertices.
    Keeping those cloth vertices in the hand component lifts its skirt. Select
    the bounded bare-hand surface from its albedo and duplicate only the shared
    boundary vertices; no source faces or their UV coordinates are discarded.
    """
    mesh = body.data
    material = mesh.materials[0]
    principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    image = next(link.from_node.image for link in material.node_tree.links
                 if link.to_socket == principled.inputs["Base Color"])
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((height, width, 4))
    uv = mesh.uv_layers.active
    selected, candidates = [], []
    for face in mesh.polygons:
        point = face.center / profile["height"]
        delta = Vector((abs(point.x) - profile["hand_x"], point.y + .025, 0))
        candidate = .36 < point.z < .515 and delta.length < .085 and point.y < .025
        candidates.append(candidate)
        colors = []
        for loop in face.loop_indices:
            coord = uv.data[loop].uv
            colors.append(pixels[min(height - 1, int((coord.y % 1) * height)),
                                 min(width - 1, int((coord.x % 1) * width)), :3])
        r, g, b = np.median(colors, axis=0)
        selected.append(bool(candidate and g > .21 and 1.10 * g < r < 2.10 * g and .72 * g < b < 1.05 * g))
    del pixels
    # Tiny dark UV islands within a hand inherit their surrounding surface.
    # A cloth triangle touching only one fingertip cannot satisfy this rule.
    for _ in range(2):
        supported = set(vertex for face in mesh.polygons if selected[face.index] for vertex in face.vertices)
        selected = [value or (candidates[face.index] and all(vertex in supported for vertex in face.vertices))
                    for face, value in zip(mesh.polygons, selected)]
    points, polygons, mapping, labels = [], [], {}, []
    for face in mesh.polygons:
        polygon = []
        label = int(selected[face.index])
        for vertex in face.vertices:
            key = (vertex, label)
            if key not in mapping:
                mapping[key] = len(points)
                points.append(mesh.vertices[vertex].co.copy())
                labels.append(label)
            polygon.append(mapping[key])
        polygons.append(polygon)
    repaired = bpy.data.meshes.new(mesh.name + "_hand_surfaces")
    repaired.from_pydata(points, [], polygons)
    for material in mesh.materials:
        repaired.materials.append(material)
    for source, target in zip(mesh.polygons, repaired.polygons):
        target.material_index = source.material_index
        target.use_smooth = source.use_smooth
    for source_uv in mesh.uv_layers:
        target_uv = repaired.uv_layers.new(name=source_uv.name)
        for source, target in zip(source_uv.data, target_uv.data):
            target.uv = source.uv
    hand = repaired.attributes.new("reviewed_hand_surface", "INT", "POINT")
    for value, label in zip(hand.data, labels):
        value.value = label
    repaired.validate(clean_customdata=True)
    repaired.update()
    body.data = repaired
    record = {"faces": sum(selected), "boundary_vertices": len(points) - len(mesh.vertices)}
    print("MESHY_SEPARATED_HAND_SURFACES", record, flush=True)
    return record


def read_source(asset_id, profile):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = SOURCE / (asset_id + ".glb")
    if digest(path) != profile["sha256"]:
        raise ValueError("Source differs from the reviewed canonical model: " + asset_id)
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise ValueError("Source has no mesh: " + asset_id)
    if any(obj.find_armature() for obj in meshes):
        raise ValueError("Refuse to replace a source rig: " + asset_id)
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    lower = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    upper = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    span = upper - lower
    if span.z <= 0.0 or span.y > span.z * .45:
        raise ValueError("Source is not the reviewed standing biped: " + asset_id)
    scale = profile["height"] / span.z
    center = Vector(((lower.x + upper.x) / 2, (lower.y + upper.y) / 2, lower.z))
    for obj in meshes:
        transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        for vertex in obj.data.vertices:
            vertex.co = (transform @ vertex.co - center) * scale
        obj.data.update()
    for obj in list(bpy.context.scene.objects):
        if obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "MeshyBody"
    # Meshy exports split vertices at UV/normal seams. Weld coincident geometry
    # while keeping per-corner UVs, otherwise each disconnected triangle island
    # collapses independently and opens visible cracks in a distant tier.
    editable = bmesh.new()
    editable.from_mesh(body.data)
    bmesh.ops.remove_doubles(editable, verts=list(editable.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(editable, edges=list(editable.edges), dist=1e-7)
    editable.normal_update()
    editable.to_mesh(body.data)
    editable.free()
    body.data.validate(clean_customdata=True)
    body.data.update()
    separated_contacts = separate_contact_fans(body)
    separated_hands = separate_signifer_hands(body, profile) if asset_id == "unit_roman_signifer" else None
    for material in body.data.materials:
        material.name = "Meshy_" + asset_id
    return body, {"source_sha256": digest(path), "source_bytes": path.stat().st_size,
                  "source_import_bounds": [list(lower), list(upper)], "scale_applied": scale,
                  "separated_contact_vertices": separated_contacts,
                  "separated_hand_surfaces": separated_hands}


def skeleton(profile):
    h = profile["height"]
    shoulder = profile["shoulder"]
    hip = profile["hip"]
    joints = {
        "Pelvis": ((0, 0, hip), (0, 0, .58), None),
        "Spine": ((0, 0, .58), (0, 0, profile["head"]), "Pelvis"),
        "Head": ((0, -.012, profile["head"]), (0, -.012, .95), "Spine"),
    }
    for side, sign in (("L", 1), ("R", -1)):
        shoulder_x = sign * profile["shoulder_x"]
        elbow_x = sign * profile.get("elbow_x", profile["hand_x"] - .008)
        wrist_x = sign * profile["hand_x"]
        joints.update({
            "Arm_" + side: ((shoulder_x, 0, shoulder), (elbow_x, -.005, profile["elbow"]), "Spine"),
            "Forearm_" + side: ((elbow_x, -.005, profile["elbow"]), (wrist_x, -.020, profile["wrist"]), "Arm_" + side),
            "Hand_" + side: ((wrist_x, -.020, profile["wrist"]), (wrist_x, -.027, profile["wrist"] - .055), "Forearm_" + side),
            "Thigh_" + side: ((sign * .062, 0, hip), (sign * .067, -.008, .285), "Pelvis"),
            "Shin_" + side: ((sign * .067, -.008, .285), (sign * .068, .012, .058), "Thigh_" + side),
            "Foot_" + side: ((sign * .068, .012, .058), (sign * .068, -.080, .025), "Shin_" + side),
        })
    data = bpy.data.armatures.new("MeshyFittedSkeleton")
    arm = bpy.data.objects.new("MeshyRig", data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (start, end, parent) in joints.items():
        bone = data.edit_bones.new(name)
        bone.head = Vector(start) * h
        bone.tail = Vector(end) * h
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def mix(a, b, amount):
    result = {name: value * (1 - amount) for name, value in a.items()}
    for name, value in b.items():
        result[name] = result.get(name, 0.0) + value * amount
    return result


def weights(point, profile, skin_hand=False):
    """Fitted spatial weights with smooth joins, including hanging cloth.

    Only the two visually reviewed down-arm poses use this fitting. Capes keep
    torso/pelvis support rather than tearing into independently walking legs.
    """
    x, y, z = point / profile["height"]
    side = "L" if x >= 0 else "R"
    ax = abs(x)
    if z >= profile["head"] - .025:
        t = smooth(profile["head"] - .025, profile["head"] + .025, z)
        return {"Spine": 1 - t, "Head": t}
    torso = smooth(.52, .66, z)
    center = {"Pelvis": 1 - torso, "Spine": torso}
    arm_start = profile["shoulder_x"] - .018
    if "lower_arm_start" in profile:
        t = 1.0 - smooth(profile["elbow"], profile["shoulder"], z)
        arm_start += (profile["lower_arm_start"] - arm_start) * t
    arm_strength = smooth(arm_start, arm_start + (.018 if profile.get("separated_downarms") else .030), ax)
    arm_strength *= smooth(.35, .39, z) * (1 - smooth(profile["shoulder"] + .01, profile["shoulder"] + .05, z))
    arm_strength *= smooth(*profile["wrist_support"], z)
    # A topology-selected hand must follow the arm chain in full, including
    # its inner fingers. Distance-based mixing back into the pelvis stretched
    # those fingers. Blend into the original arm field only above the wrist.
    hand_support = (1 - smooth(profile["wrist"] + .015, profile["wrist"] + .10, z)) if skin_hand and not profile.get("separated_downarms") else 0.0
    arm_strength = max(arm_strength, hand_support)
    # The broad hanging cape is behind the elbows, not a third pair of arms.
    arm_strength *= 1 - smooth(.065, .10, y)
    if arm_strength > 0:
        elbow_blend = smooth(profile["elbow"] - .038, profile["elbow"] + .038, z)
        hand_blend = 1 - smooth(profile["wrist"] - .012, profile["wrist"] + .025, z)
        arm_weights = {"Arm_" + side: elbow_blend,
                       "Forearm_" + side: (1 - elbow_blend) * (1 - hand_blend),
                       "Hand_" + side: (1 - elbow_blend) * hand_blend}
        center = mix(center, arm_weights, arm_strength)
    if z < .48:
        knee = smooth(.255, .315, z)
        ankle = smooth(.045, .087, z)
        leg_left = {"Foot_L": 1 - ankle,
                    "Shin_L": ankle * (1 - knee), "Thigh_L": ankle * knee}
        leg_right = {"Foot_R": 1 - ankle,
                     "Shin_R": ankle * (1 - knee), "Thigh_R": ankle * knee}
        # A hanging garment can cross the midline below the tunic hem. Keep
        # this center seam continuous rather than switching all leg weights
        # abruptly when a vertex's x coordinate changes sign.
        leg = mix(leg_right, leg_left, smooth(-.025, .025, x))
        # Central tunic fabric follows both thighs near the hem. Outer legs and
        # boots retain independent knee and foot deformation.
        cloth = smooth(.29, .355, z) * (1 - smooth(.10, .145, ax))
        shared = {"Pelvis": .62, "Thigh_L": .19, "Thigh_R": .19}
        leg = mix(leg, shared, cloth)
        cape = smooth(.065, .115, y) * smooth(.19, .30, z)
        leg = mix(leg, {"Pelvis": .85, "Spine": .15}, cape)
        leg_strength = 1 - smooth(.43, .48, z)
        # Do not bind a relaxed hand beside the upper thigh to that thigh.
        leg_strength *= 1 - arm_strength
        center = mix(center, leg, leg_strength)
    chosen = sorted(((key, value) for key, value in center.items() if value > 1e-6), key=lambda item: item[1], reverse=True)[:4]
    total = sum(value for _, value in chosen)
    return {key: value / total for key, value in chosen}


def bind(body, arm, profile):
    # The inner fingers overlap the tunic silhouette in both source poses.
    # Source albedo distinguishes bare skin at this bounded wrist region from
    # cloth; it is never used as a general-purpose human segmentation claim.
    hand_skin = [False] * len(body.data.vertices)
    material = body.data.materials[0]
    principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    color_link = next((link for link in material.node_tree.links if link.to_socket == principled.inputs["Base Color"]), None)
    if color_link and color_link.from_node.type == "TEX_IMAGE":
        image = color_link.from_node.image
        width, height = image.size
        pixels = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape((height, width, 4))
        uv = body.data.uv_layers.active
        for loop in body.data.loops:
            point = body.data.vertices[loop.vertex_index].co / profile["height"]
            hand_delta = Vector((abs(point.x) - profile["hand_x"], point.y + .025, 0))
            if not (profile["wrist"] - .07 < point.z < profile["wrist"] and hand_delta.length < .035 and point.y < .012):
                continue
            coord = uv.data[loop.index].uv
            r, g, b = pixels[min(height - 1, int((coord.y % 1) * height)), min(width - 1, int((coord.x % 1) * width)), :3]
            if g > .025 and 1.35 * g < r < 2.9 * g and g > 1.08 * b:
                hand_skin[loop.vertex_index] = True
        del pixels
    # Extend the reliable front-skin seeds across the connected hand surface.
    # Dark nails/back faces need the same binding as the lit palm. Topological
    # reach prevents a nearby but separate tunic/cape panel from being selected.
    candidates = []
    for vertex in body.data.vertices:
        point = vertex.co / profile["height"]
        delta = Vector((abs(point.x) - profile["hand_x"], point.y + .025, 0))
        candidates.append(delta.length < .11 and profile["wrist"] - .15 < point.z < profile["wrist"] + .10)
    adjacent = [[] for _ in body.data.vertices]
    for edge in body.data.edges:
        a, b = edge.vertices
        if candidates[a] and candidates[b]:
            adjacent[a].append(b)
            adjacent[b].append(a)
    queue = [index for index, selected in enumerate(hand_skin) if selected and candidates[index]]
    cursor = 0
    while cursor < len(queue):
        index = queue[cursor]
        cursor += 1
        for neighbor in adjacent[index]:
            if not hand_skin[neighbor]:
                hand_skin[neighbor] = True
                queue.append(neighbor)
    reviewed_hand = body.data.attributes.get("reviewed_hand_surface")
    if reviewed_hand is not None:
        hand_skin = [bool(value.value) for value in reviewed_hand.data]
    for sign in (-1, 1):
        selected = [vertex.co for vertex in body.data.vertices if hand_skin[vertex.index] and vertex.co.x * sign > 0]
        if selected:
            print("MESHY_HAND_REGION", sign, len(selected),
                  [min(point[axis] for point in selected) for axis in range(3)],
                  [max(point[axis] for point in selected) for axis in range(3)], flush=True)
    influence_counts = {name: 0 for name in arm.data.bones.keys()}
    for vertex in body.data.vertices:
        record = weights(vertex.co, profile, hand_skin[vertex.index])
        if not record or not math.isclose(sum(record.values()), 1.0, abs_tol=1e-5):
            raise ValueError("Non-normalized skin weights")
        for name, value in record.items():
            group = body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
            group.add([vertex.index], value, "REPLACE")
            influence_counts[name] += 1
    if any(value == 0 for value in influence_counts.values()):
        raise ValueError("Unbound joint: " + str(influence_counts))
    body.parent = arm
    modifier = body.modifiers.new("Meshy fitted skin", "ARMATURE")
    modifier.object = arm
    return influence_counts


def animate(arm, pose_modifier=None):
    def pose(clip, t, role):
        if clip == "idle":
            # A complete, seam-free breathing/attention cycle remains visible
            # at gameplay distance without sliding the planted legs. The head
            # counters the small shoulder sway rather than moving as one block.
            wave = math.sin(t * math.tau)
            breath = math.sin(t * math.tau * 2)
            return {"Spine": (1.15 * breath, .7 * wave, 0),
                    "Head": (-.6 * breath, -.5 * wave, 2.5 * wave),
                    "Arm_L": (.7 * breath, 0, -.6 * wave),
                    "Arm_R": (-.7 * breath, 0, -.6 * wave),
                    "Forearm_L": (-1.2 * wave, 0, 0),
                    "Forearm_R": (1.2 * wave, 0, 0)}, 0
        if clip in ("march", "run"):
            running = clip == "run"
            stride, stance = (1.75, .40) if running else (1.30, .56)
            lift = -.035 - .012 * math.cos(4 * math.pi * t)
            angles = {}
            targets = {}
            for offset, side in ((0, "R"), (.5, "L")):
                u = (t + offset) % 1
                foot_lift = 0
                if u <= stance:
                    forward = stride * (u - stance / 2)
                else:
                    swing = (u - stance) / (1 - stance)
                    forward = stride * (stance / 2 + (1 - stance) * swing - swing * swing * (3 - 2 * swing))
                    foot_lift = (.12 if running else .075) * math.sin(math.pi * swing) ** 2
                thigh = arm.data.bones["Thigh_" + side]
                shin = arm.data.bones["Shin_" + side]
                foot = arm.data.bones["Foot_" + side]
                upper_rest = shin.head_local - thigh.head_local
                lower_rest = foot.head_local - shin.head_local
                # Rotations are sagittal: their link lengths are the YZ
                # projections, while the lateral offsets remain unchanged.
                upper = math.hypot(upper_rest.y, upper_rest.z)
                lower = math.hypot(lower_rest.y, lower_rest.z)
                horizontal = forward + foot.head_local.y - thigh.head_local.y
                maximum_height = math.sqrt(max(0.0, (upper + lower - .003) ** 2 - horizontal ** 2))
                # Both feet share one pelvis. Lower it before solving either
                # leg, so the authored ground target remains reachable. Merely
                # clamping reach lifted the stance foot by about 2 cm and the
                # runtime contact solver then anchored that airborne pose.
                lift = min(lift, foot.head_local.z + foot_lift + maximum_height - thigh.head_local.z)
                targets[side] = (u, foot_lift, horizontal, upper, lower, upper_rest, lower_rest)
            for side, target in targets.items():
                u, foot_lift, horizontal, upper, lower, upper_rest, lower_rest = target
                thigh = arm.data.bones["Thigh_" + side]
                foot = arm.data.bones["Foot_" + side]
                height = thigh.head_local.z + lift - foot.head_local.z - foot_lift
                reach = min(math.hypot(horizontal, height), upper + lower - .00001)
                hip = math.atan2(horizontal, height) - math.acos(clamp((upper * upper + reach * reach - lower * lower) / (2 * upper * reach), -1, 1))
                knee = math.pi - math.acos(clamp((upper * upper + lower * lower - reach * reach) / (2 * upper * lower), -1, 1))
                # The fitted rig's thighs/shins are not vertical at rest.
                # Remove those authored rest inclinations before applying
                # sagittal IK, otherwise planted ankles drift by about 3 cm.
                rest_a = math.atan2(upper_rest.y, -upper_rest.z)
                rest_b = math.atan2(lower_rest.y, -lower_rest.z)
                a = math.degrees(hip - rest_a)
                b = math.degrees(knee - (rest_b - rest_a))
                angles["Thigh_" + side] = (a, 0, 0)
                angles["Shin_" + side] = (b, 0, 0)
                angles["Foot_" + side] = (-a - b, 0, 0)
                counter = math.cos(math.tau * u)
                angles["Arm_" + side] = ((23 if running else 14) * counter, 0, 0)
                angles["Forearm_" + side] = (-12 - 7 * (1 - counter) if running else -5 - 3 * (1 - counter), 0, 0)
            angles["Spine"] = (3 if running else 1, 0, 1.5 * math.cos(math.tau * t))
            return angles, lift
        if clip in ("talk", "work", "gather"):
            movement = math.sin(math.pi * t) ** 2
            if clip == "talk":
                return {"Arm_L": (-12 * movement, 0, -6 * movement), "Forearm_L": (-25 * movement, 0, 0),
                        "Head": (2 * math.sin(t * math.tau), 0, 5 * movement)}, 0
            return {"Spine": (10 * movement, 0, 0), "Arm_R": (-28 * movement, 0, 0),
                    "Forearm_R": (-18 * movement, 0, 0), "Head": (4 * movement, 0, 0)}, 0
        return original_pose("attack" if clip == "train" else clip, t, role)

    def extended_pose(clip,t,role):
        angles,lift=pose(clip,t,role)
        return (pose_modifier(clip,t,angles) if pose_modifier else angles),lift
    soldier.pose = extended_pose
    soldier.LENGTHS = CLIPS
    soldier.animate(arm, "civilian")


def smooth_reduced_weights(body):
    """Regularize interpolated LOD weights across their actual mesh edges.

    A collapsed skinny wrist triangle can otherwise interpolate quite different
    source weights onto almost coincident vertices. Two mild topology-local
    passes keep that transition continuous without crossing separated cloth
    contacts. Preserve existing rigid foot bindings: smoothing a planted sole
    into its shin makes the visible foot move even when its ankle is locked.
    """
    count = len(body.data.vertices)
    values = np.zeros((count, len(body.vertex_groups)), dtype=np.float64)
    for vertex in body.data.vertices:
        for group in vertex.groups:
            values[vertex.index, group.group] = group.weight
    rigid_feet = np.zeros(count, dtype=bool)
    for name in ("Foot_L", "Foot_R"):
        group = body.vertex_groups.get(name)
        if group is not None:
            rigid_feet |= values[:, group.index] > 0.0
    rigid_feet &= np.count_nonzero(values, axis=1) == 1
    original_foot_weights = values[rigid_feet].copy()
    pairs = np.array([edge.vertices[:] for edge in body.data.edges], dtype=np.int32)
    points = np.array([vertex.co[:] for vertex in body.data.vertices])
    a, b = pairs[:, 0], pairs[:, 1]
    factors = 1 / np.maximum(np.linalg.norm(points[a] - points[b], axis=1), .01)
    total = np.zeros(count)
    np.add.at(total, a, factors)
    np.add.at(total, b, factors)
    for _ in range(2):
        neighbors = np.zeros_like(values)
        np.add.at(neighbors, a, values[b] * factors[:, None])
        np.add.at(neighbors, b, values[a] * factors[:, None])
        active = total > 0
        values[active] = .65 * values[active] + .35 * neighbors[active] / total[active, None]
    # Restore only assignments that were already rigid after decimation.
    # No position-based rebinding or changes to other smoothed vertices.
    values[rigid_feet] = original_foot_weights
    for vertex in body.data.vertices:
        chosen = sorted(enumerate(values[vertex.index]), key=lambda pair: pair[1], reverse=True)[:4]
        weight_total = sum(value for _, value in chosen)
        for group_index in [group.group for group in vertex.groups]:
            body.vertex_groups[group_index].remove([vertex.index])
        for group, value in chosen:
            if value > 1e-8:
                body.vertex_groups[group].add([vertex.index], value / weight_total, "REPLACE")
    return int(np.count_nonzero(rigid_feet))


def export_tiers(asset_id, body, arm):
    outputs = []
    source_mesh = body.data.copy()
    for level, triangles, texture_edge in TIERS:
        body.data = source_mesh.copy()
        body.data.calc_loop_triangles()
        before = len(body.data.loop_triangles)
        bpy.context.view_layer.objects.active = body
        if before > triangles:
            decimate = body.modifiers.new("Mobile tier", "DECIMATE")
            decimate.ratio = triangles / before
            decimate.use_collapse_triangulate = True
            # The skin is kept for export but must not be evaluated into the
            # geometry while an authoring reduction is applied.
            skin = next(modifier for modifier in body.modifiers if modifier.type == "ARMATURE")
            skin.show_viewport = False
            bpy.ops.object.modifier_apply(modifier=decimate.name)
            skin.show_viewport = True
        body.data.validate(clean_customdata=True)
        rigid_foot_vertices = smooth_reduced_weights(body)
        # Decimation interpolates source groups; enforce the same four-weight
        # normalized contract on the resulting vertices before glTF export.
        for vertex in body.data.vertices:
            chosen = sorted(((group.group, group.weight) for group in vertex.groups), key=lambda pair: pair[1], reverse=True)[:4]
            total = sum(value for _, value in chosen)
            for group_index in [group.group for group in vertex.groups]:
                body.vertex_groups[group_index].remove([vertex.index])
            for group, value in chosen:
                body.vertex_groups[group].add([vertex.index], value / total, "REPLACE")
        for image in bpy.data.images:
            if max(image.size) > texture_edge:
                factor = texture_edge / max(image.size)
                image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
                image.pack()
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        path = OUT / (asset_id + "_%d.glb" % level)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                                  export_frame_step=1, export_animations=True, export_morph=False,
                                  export_def_bones=False, export_image_format="JPEG", export_jpeg_quality=88)
        death_ground = soldier.death_ground.ground(path)
        seam = body_seam.smooth(path)
        body.data.calc_loop_triangles()
        outputs.append({"level": level, "path": str(path.relative_to(ROOT)),
                        "triangles": len(body.data.loop_triangles), "texture_edge": texture_edge,
                        "rigid_foot_vertices_preserved": rigid_foot_vertices,
                        "death_ground_contact": {key: death_ground[key] for key in ("before", "after", "maximum_floor_correction_m")},
                        "body_seam": {key: seam[key] for key in ("before", "after", "changed_vertices") if key in seam},
                        "sha256": digest(path), "size_bytes": path.stat().st_size})
    return outputs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--types", nargs="+", default=["all"])
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    requested = ["unit_roman_signifer", "unit_germanic_axe_fighter"] if args.types == ["all"] else args.types
    if any(asset_id not in PROFILES for asset_id in requested):
        raise ValueError("Only explicitly reviewed source poses may be processed")
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    records = []
    for asset_id in requested:
        body, record = read_source(asset_id, PROFILES[asset_id])
        arm = skeleton(PROFILES[asset_id])
        record["bound_vertices_per_joint"] = bind(body, arm, PROFILES[asset_id])
        animate(arm)
        record.update({"stable_id": asset_id, "lods": export_tiers(asset_id, body, arm),
                       "height_m": PROFILES[asset_id]["height"], "bones": len(arm.data.bones),
                       "clips": list(CLIPS), "facial_morphs": False})
        records.append(record)
    previous = json.loads(REPORT.read_text()).get("characters", []) if REPORT.exists() else []
    combined = [record for record in previous if record["stable_id"] not in requested] + records
    REPORT.write_text(json.dumps({"generator": str(Path(__file__).relative_to(ROOT)),
                                 "blender": bpy.app.version_string, "characters": combined,
                                 "limits": ["Fitted project-authored biped rigs, not Meshy rigging.",
                                            "No finger rig, facial morphs or simulated cloth.",
                                            "Source poses with mounted composites or fixed equipment remain blocked.",
                                            "Engine/Android visual checks are recorded separately."]}, indent=2) + "\n")
    print("MESHY_PEOPLE_BUILT", ",".join(requested), flush=True)


if __name__ == "__main__":
    main()
