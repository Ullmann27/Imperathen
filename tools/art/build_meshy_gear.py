#!/usr/bin/env python3
"""Build metric, socketed runtime GLBs with LODs from the staged Meshy sources.

No hosted generation, upload or paid conversion is performed. Sources stay
untouched under prototype/assets/meshy/source/ and must match lock.json.

    blender -b -t 1 -P tools/art/build_meshy_gear.py -- [--only id,id] [--list]

Profiles: prototype/assets/meshy/gear_profiles.json
Report:   docs/20_meshy_assets/gear-build.json (merged per asset)
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
MESHY = ROOT / "prototype/assets/meshy"
PROFILES = MESHY / "gear_profiles.json"
LOCK = MESHY / "lock.json"
REPORT = ROOT / "docs/20_meshy_assets/gear-build.json"
AXES = {"+x": Vector((1, 0, 0)), "-x": Vector((-1, 0, 0)), "+y": Vector((0, 1, 0)),
        "-y": Vector((0, -1, 0)), "+z": Vector((0, 0, 1)), "-z": Vector((0, 0, -1))}
HAND = {"blade": "SOCKET_RIGHT_HAND", "polearm": "SOCKET_RIGHT_HAND", "soft": "SOCKET_RIGHT_HAND",
        "shield": "SOCKET_LEFT_HAND"}


def digest(path: Path) -> str:
    block = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            block.update(chunk)
    return block.hexdigest()


def bounds(points):
    low = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    high = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return low, high


def components(mesh):
    remaining = set(mesh.verts)
    result = []
    while remaining:
        seed = remaining.pop()
        queue, part = [seed], [seed]
        while queue:
            vertex = queue.pop()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in remaining:
                    remaining.remove(other)
                    part.append(other)
                    queue.append(other)
        result.append(part)
    return result


def import_source(identity: str, lock: dict):
    entry = lock["assets"][identity]
    path = ROOT / entry["path"]
    if digest(path) != entry["sha256"]:
        raise ValueError("Source differs from lock.json: " + identity)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes or any(obj.find_armature() for obj in meshes):
        raise ValueError("Expected rigid source geometry: " + identity)
    for obj in meshes:
        transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        obj.data.transform(transform)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for other in list(bpy.context.scene.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)
    return obj, entry, path


def orient(obj, profile):
    up = AXES[profile.get("up", "+z")]
    front = AXES[profile.get("front", "-y")]
    y_axis = -front
    x_axis = y_axis.cross(up)
    rotation = Matrix((x_axis, y_axis, up)).to_4x4()
    obj.data.transform(rotation)


def extract_crossed_lance(obj):
    """The source holds two crossed lances in one file. Keep the one on the
    rising diagonal and stand it upright with the larger iron head on top."""
    editable = bmesh.new()
    editable.from_mesh(obj.data)
    bmesh.ops.remove_doubles(editable, verts=list(editable.verts), dist=1e-6)
    parts = components(editable)
    removed = 0
    for part in parts:
        moment = sum(vertex.co.x * vertex.co.z for vertex in part)
        if moment <= 0.0:
            removed += len(part)
            bmesh.ops.delete(editable, geom=part, context="VERTS")
    points = [vertex.co.copy() for vertex in editable.verts]
    centre = sum(points, Vector()) / len(points)
    sxx = sum((p.x - centre.x) ** 2 for p in points)
    szz = sum((p.z - centre.z) ** 2 for p in points)
    sxz = sum((p.x - centre.x) * (p.z - centre.z) for p in points)
    angle = .5 * math.atan2(2 * sxz, sxx - szz)
    axis = Vector((math.cos(angle), 0, math.sin(angle)))
    along = [(p - centre).dot(axis) for p in points]
    low, high = min(along), max(along)
    span = high - low
    top = sum(1 for value in along if value > high - .06 * span)
    bottom = sum(1 for value in along if value < low + .06 * span)
    if bottom > top:
        axis = -axis
    y_axis = Vector((0, 1, 0))
    x_axis = y_axis.cross(axis)
    rotation = Matrix((x_axis, y_axis, axis))
    for vertex in editable.verts:
        vertex.co = rotation @ (vertex.co - centre)
    editable.normal_update()
    editable.to_mesh(obj.data)
    editable.free()
    return {"removed_second_lance_vertices": removed, "kept_vertices": len(points)}


def oval_board(obj, profile):
    """The 'oval' cavalry shield arrives circular. Narrow the board to an oval
    while the boss and small fittings keep their round shape."""
    editable = bmesh.new()
    editable.from_mesh(obj.data)
    bmesh.ops.remove_doubles(editable, verts=list(editable.verts), dist=1e-6)
    low, high = bounds([vertex.co for vertex in editable.verts])
    factor = (profile["width"] / profile["length"]) * ((high.z - low.z) / (high.x - low.x))
    centre_x = (low.x + high.x) * .5
    limit = .35 * (high.z - low.z)
    kept_round = 0
    for part in components(editable):
        part_low, part_high = bounds([vertex.co for vertex in part])
        size = part_high - part_low
        # Only compact parts (boss, rivets) keep their shape; ring segments
        # and straps are elongated and must follow the board.
        if max(size.x, size.z) < limit and min(size.x, size.z) > .6 * max(size.x, size.z):
            kept_round += 1
            middle = (part_low.x + part_high.x) * .5
            shift = (middle - centre_x) * factor + centre_x - middle
            for vertex in part:
                vertex.co.x += shift
        else:
            for vertex in part:
                vertex.co.x = (vertex.co.x - centre_x) * factor + centre_x
    editable.normal_update()
    editable.to_mesh(obj.data)
    editable.free()
    return {"board_width_factor": factor, "round_fittings_kept": kept_round}


def remove_components(obj, spans):
    """Delete whole disconnected parts that lie inside a reviewed span of the
    length (t from butt). Used for generation artefacts such as a second
    cross-bar in the middle of a blade."""
    editable = bmesh.new()
    editable.from_mesh(obj.data)
    low, high = bounds([vertex.co for vertex in editable.verts])
    length = high.z - low.z
    removed = []
    for part in components(editable):
        part_low, part_high = bounds([vertex.co for vertex in part])
        t0, t1 = (part_low.z - low.z) / length, (part_high.z - low.z) / length
        if any(span[0] <= t0 and t1 <= span[1] for span in spans):
            removed.append({"vertices": len(part), "t": [round(t0, 4), round(t1, 4)]})
            bmesh.ops.delete(editable, geom=part, context="VERTS")
    editable.to_mesh(obj.data)
    editable.free()
    return removed


def piecewise(value, segments):
    for src0, src1, dst0, dst1 in segments:
        if value <= src1:
            return dst0 + (max(value, src0) - src0) / (src1 - src0) * (dst1 - dst0)
    return segments[-1][3]


def fit(obj, profile):
    """Scale to metres, apply the reviewed proportion corrections and move the
    grip (or ground contact) to the origin."""
    mesh = obj.data
    kind = profile["kind"]
    points = [vertex.co for vertex in mesh.vertices]
    low, high = bounds(points)
    size = high - low
    record = {"source_bounds": [list(low), list(high)]}
    if "length" in profile:
        source_length = size.z
        lateral = profile["length"] / (source_length * float(profile.get("lateral_ref", 1.0)))
        remap = profile.get("axial_remap")
        scales = profile.get("radial_scale", [])
        middle = Vector(((low.x + high.x) * .5, (low.y + high.y) * .5, 0))
        if kind in ("blade", "polearm"):
            # Centre the cross-section on the grip, not on a wide guard or head.
            grip_t = profile["grip_z"] / profile["length"]
            if remap:
                grip_t = next((s0 + (grip_t - d0) / (d1 - d0) * (s1 - s0) for s0, s1, d0, d1 in remap if d0 <= grip_t <= d1), grip_t)
            near = [p for p in points if abs((p.z - low.z) / source_length - grip_t) < .06]
            if near:
                near_low, near_high = bounds(near)
                middle = Vector(((near_low.x + near_high.x) * .5, (near_low.y + near_high.y) * .5, 0))
        for vertex in mesh.vertices:
            t = (vertex.co.z - low.z) / source_length
            sx = sy = 1.0
            for scale in scales:
                if scale["t"][0] <= t <= scale["t"][1]:
                    sx, sy = float(scale["x"]), float(scale["y"])
                    break
            z = (piecewise(t, remap) if remap else t) * profile["length"]
            vertex.co = Vector(((vertex.co.x - middle.x) * lateral * sx, (vertex.co.y - middle.y) * lateral * sy, z))
        record["uniform_scale"] = lateral
    else:
        scale = profile["max_dimension"] / max(size)
        middle = Vector(((low.x + high.x) * .5, (low.y + high.y) * .5, low.z))
        for vertex in mesh.vertices:
            vertex.co = (vertex.co - middle) * scale
        record["uniform_scale"] = scale
    mesh.update()
    points = [vertex.co for vertex in mesh.vertices]
    low, high = bounds(points)
    origin = Vector((0, 0, 0))
    if kind in ("blade", "polearm"):
        origin = Vector((0, 0, profile["grip_z"]))
    elif kind == "shield":
        # Hand grip behind the boss. Front is Blender -Y, so the back is +Y.
        origin = Vector(((low.x + high.x) * .5, float(profile.get("grip_depth", 0.0)), (low.z + high.z) * .5))
        if profile.get("special") == "oval_board":
            board_back = max(p.y for p in points if abs(p.x) > .25 * (high.x - low.x))
            origin.y = board_back + .012
    elif kind == "soft":
        top = [p for p in points if p.z > high.z - .05 * (high.z - low.z)]
        origin = sum(top, Vector()) / len(top)
    elif kind in ("mount", "prop"):
        origin = Vector(((low.x + high.x) * .5, (low.y + high.y) * .5, low.z))
    for vertex in mesh.vertices:
        vertex.co -= origin
    mesh.update()
    low, high = bounds([vertex.co for vertex in mesh.vertices])
    record["origin_shift"] = list(origin)
    record["bounds_blender"] = [list(low), list(high)]
    return record


def clean_normals(obj, angle_degrees):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError:
        pass
    if angle_degrees >= 180:
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle_degrees), keep_sharp_edges=False)


def flat_material(name, spec):
    material = bpy.data.materials.get(name)
    if material:
        return material
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*spec["base_color"], 1.0)
    shader.inputs["Metallic"].default_value = spec["metallic"]
    shader.inputs["Roughness"].default_value = spec["roughness"]
    return material


def make_accent(spec, materials, parent):
    """Small authored fittings. Blender Z is the weapon axis; 'z' is metres
    above the butt and is converted to the grip-centred frame by the caller."""
    kind = spec["kind"]
    mesh = bpy.data.meshes.new(spec["node"])
    editable = bmesh.new()
    rx, ry, height = float(spec["rx"]), float(spec["ry"]), float(spec["h"])
    if kind in ("plate", "rod"):
        segments = 12 if kind == "rod" else 28
        bmesh.ops.create_cone(editable, cap_ends=True, cap_tris=False, segments=segments,
                              radius1=1.0, radius2=1.0, depth=height)
        for vertex in editable.verts:
            vertex.co.x *= rx
            vertex.co.y *= ry
        if kind == "plate":
            edges = [edge for edge in editable.edges if abs(edge.verts[0].co.z - edge.verts[1].co.z) < 1e-7]
            bmesh.ops.bevel(editable, geom=edges, offset=min(height * .28, .0012), segments=2, affect="EDGES")
    elif kind == "pyramid":
        bmesh.ops.create_cone(editable, cap_ends=True, cap_tris=False, segments=4,
                              radius1=1.0, radius2=0.0, depth=height)
        for vertex in editable.verts:
            vertex.co.x *= rx
            vertex.co.y *= ry
            vertex.co.z += height * .5
        bmesh.ops.rotate(editable, verts=list(editable.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"))
    elif kind == "wrap":
        # A slanted, slightly irregular lashing of leather thong: one swept
        # diamond profile per turn. It reads as a field repair on the grip.
        turns = int(spec.get("turns", 5))
        thong = max(height / (turns * 2.0), .0011)
        segments = 20
        for turn in range(turns):
            offset = (turn - (turns - 1) * .5) * (height / turns)
            tilt = (.45 if turn % 2 else -.3) * thong
            rings = []
            for segment in range(segments):
                angle = math.tau * segment / segments
                centre = Vector((math.cos(angle) * (rx + thong * .55), math.sin(angle) * (ry + thong * .55),
                                 offset + math.sin(angle + turn) * tilt))
                outward = Vector((math.cos(angle), math.sin(angle), 0))
                rings.append([editable.verts.new(centre + outward * thong * .6),
                              editable.verts.new(centre + Vector((0, 0, thong * .75))),
                              editable.verts.new(centre - outward * thong * .6),
                              editable.verts.new(centre - Vector((0, 0, thong * .75)))])
            for segment in range(segments):
                first, second = rings[segment], rings[(segment + 1) % segments]
                for corner in range(4):
                    editable.faces.new((first[corner], first[(corner + 1) % 4], second[(corner + 1) % 4], second[corner]))
    else:
        raise ValueError("Unknown accent kind: " + kind)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(mesh)
    editable.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = kind in ("plate", "rod", "wrap")
    accent = bpy.data.objects.new(spec["node"], mesh)
    bpy.context.collection.objects.link(accent)
    mesh.materials.append(materials[spec["material"]])
    accent.parent = parent
    accent.location = Vector((0, 0, float(spec["z"])))
    if kind != "pyramid":
        bpy.ops.object.select_all(action="DESELECT")
        accent.select_set(True)
        bpy.context.view_layer.objects.active = accent
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40), keep_sharp_edges=False)
    return accent


def add_socket(name, parent, location):
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.parent = parent
    socket.location = Vector(location)
    return socket


def image_roles(obj):
    """0 = base colour, 1 = normal, 2 = metallic-roughness or anything else."""
    roles = {}
    links = [link for material in obj.data.materials if material and material.use_nodes for link in material.node_tree.links]
    for link in links:
        source = link.from_node
        if source.type != "TEX_IMAGE" or not source.image:
            continue
        if link.to_node.type == "BSDF_PRINCIPLED" and link.to_socket.name == "Base Color":
            roles[source.image.name] = 0
        elif link.to_node.type == "NORMAL_MAP":
            roles[source.image.name] = 1
    for link in links:
        source = link.from_node
        if source.type == "TEX_IMAGE" and source.image and source.image.name not in roles:
            roles[source.image.name] = 2
    return roles


def texel_density(mesh, edge):
    mesh.calc_loop_triangles()
    layer = mesh.uv_layers.active
    if not layer:
        return 0.0
    world = uv = 0.0
    for triangle in mesh.loop_triangles:
        world += triangle.area
        a, b, c = (layer.data[index].uv for index in triangle.loops)
        uv += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) * .5
    return math.sqrt(uv / world) * edge if world > 0 else 0.0


def collision_hull(obj, name):
    editable = bmesh.new()
    for vertex in obj.data.vertices:
        editable.verts.new(vertex.co)
    hull = bmesh.ops.convex_hull(editable, input=list(editable.verts))
    unused = list({item for item in hull["geom_interior"] + hull["geom_unused"] if isinstance(item, bmesh.types.BMVert)})
    bmesh.ops.delete(editable, geom=unused, context="VERTS")
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    mesh = bpy.data.meshes.new(name)
    editable.to_mesh(mesh)
    editable.free()
    collider = bpy.data.objects.new(name + "-convcolonly", mesh)
    bpy.context.collection.objects.link(collider)
    mesh.calc_loop_triangles()
    if len(mesh.loop_triangles) > 96:
        modifier = collider.modifiers.new("Hull budget", "DECIMATE")
        modifier.ratio = 96 / len(mesh.loop_triangles)
        bpy.ops.object.select_all(action="DESELECT")
        collider.select_set(True)
        bpy.context.view_layer.objects.active = collider
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    collider.parent = obj
    return collider


def build(identity, profile, catalog, lock):
    obj, lock_entry, source_path = import_source(identity, lock)
    record = {"stable_id": identity, "kind": profile["kind"], "source_path": lock_entry["path"],
              "source_sha256": lock_entry["sha256"], "source_bytes": lock_entry["size_bytes"],
              "source_triangles": lock_entry["triangles"]}
    if profile.get("special") == "extract_crossed_lance":
        record["repair"] = extract_crossed_lance(obj)
    else:
        orient(obj, profile)
    editable = bmesh.new()
    editable.from_mesh(obj.data)
    bmesh.ops.remove_doubles(editable, verts=list(editable.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(editable, edges=list(editable.edges), dist=1e-7)
    editable.normal_update()
    editable.to_mesh(obj.data)
    editable.free()
    if profile.get("special") == "oval_board":
        record["repair"] = oval_board(obj, profile)
    if profile.get("remove_components_within"):
        record["removed_artifacts"] = remove_components(obj, profile["remove_components_within"])
    record.update(fit(obj, profile))
    record["proportion_corrections"] = [{k: v for k, v in scale.items()} for scale in profile.get("radial_scale", [])]
    if profile.get("axial_remap"):
        record["axial_remap"] = profile["axial_remap"]
    obj.data.validate(clean_customdata=False)
    clean_normals(obj, float(profile.get("smooth_angle", 48)))
    obj.name = "MeshyGear_" + identity
    for material in obj.data.materials:
        if material:
            material.name = "MeshyGearMaterial_" + identity
    low, high = bounds([vertex.co for vertex in obj.data.vertices])
    kind = profile["kind"]
    grip_z = float(profile.get("grip_z", 0.0))
    sockets = []
    if kind in HAND:
        sockets.append(add_socket(HAND[kind], obj, (0, 0, 0)))
    for name, where in profile.get("sockets", {}).items():
        if where == "tip":
            location = (0, 0, high.z)
        elif where == "origin":
            location = (0, 0, 0)
        elif where == "front":
            location = (0, low.y, 0)
        else:
            location = (0, 0, float(where) - grip_z)
        sockets.append(add_socket(name, obj, location))
    if kind == "shield":
        sockets.append(add_socket("SOCKET_FOREARM", obj, (-.13, 0, 0)))
    if kind == "mount":
        length = high.y - low.y
        back = [v.co for v in obj.data.vertices if abs(v.co.x) < .08 and abs(v.co.y - (low.y + high.y) * .5 - .04 * length) < .09 * length]
        saddle_z = max(p.z for p in back)
        saddle_y = (low.y + high.y) * .5 + .04 * length
        sockets.append(add_socket("SOCKET_SADDLE", obj, (0, saddle_y, saddle_z)))
        sockets.append(add_socket("SOCKET_RIDER", obj, (0, saddle_y, saddle_z + .05)))
        head = [v.co for v in obj.data.vertices if v.co.y < low.y + .05 * length]
        centre = sum(head, Vector()) / len(head)
        sockets.append(add_socket("SOCKET_HEAD", obj, tuple(centre)))
        record["withers_or_back_height_m"] = saddle_z
    record["sockets"] = {socket.name: [round(value, 5) for value in socket.location] for socket in sockets}
    materials = {name: flat_material("MeshyGearAccent_" + name, spec) for name, spec in catalog["materials"].items()}
    accents = []
    for spec in profile.get("accents", []):
        adjusted = dict(spec)
        adjusted["z"] = float(spec["z"]) - grip_z
        accents.append(make_accent(adjusted, materials, obj))
    record["accents"] = [accent.name for accent in accents]
    collider = collision_hull(obj, "Collision") if profile.get("collision") == "hull" else None
    roles = image_roles(obj)
    original = obj.data.copy()
    out = MESHY / profile["out"]
    out.mkdir(parents=True, exist_ok=True)
    tiers = []
    for tier, budget in enumerate(profile["triangles"]):
        obj.data = original.copy()
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        bpy.context.view_layer.objects.active = obj
        reduced = False
        angles = profile.get("planar_angles")
        if angles and tier < len(angles) and float(angles[tier]) > 0.0 and triangles > budget:
            # Flat layered parts (board, straps, ring) keep their outlines when
            # coplanar faces are dissolved first; an edge collapse tears them.
            planar = obj.modifiers.new("Planar reduction", "DECIMATE")
            planar.decimate_type = "DISSOLVE"
            planar.angle_limit = math.radians(float(angles[tier]))
            planar.delimit = {"UV"}
            triangulate = obj.modifiers.new("Triangulate", "TRIANGULATE")
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.modifier_apply(modifier=planar.name)
            bpy.ops.object.modifier_apply(modifier=triangulate.name)
            obj.data.calc_loop_triangles()
            triangles = len(obj.data.loop_triangles)
            reduced = True
        if triangles > budget:
            modifier = obj.modifiers.new("Runtime reduction", "DECIMATE")
            modifier.ratio = budget / triangles
            modifier.use_collapse_triangulate = True
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            reduced = True
        if reduced:
            clean_normals(obj, float(profile.get("smooth_angle", 48)))
        edges = profile["textures"][tier]
        for image in bpy.data.images:
            if image.name not in roles or not image.size[0]:
                continue
            target = edges[roles[image.name]]
            if max(image.size) > target:
                factor = target / max(image.size)
                image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
                image.pack()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        for socket in sockets:
            socket.select_set(True)
        # Far tiers drop the small quality fittings; they are below a pixel there.
        shown = accents if tier < 2 else [accent for accent in accents if not accent.name.startswith("Q_")]
        for accent in shown:
            accent.select_set(True)
        if collider:
            collider.select_set(True)
        path = out / ("%s_%d.glb" % (identity, tier))
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_animations=False, export_skins=False, export_morph=False,
                                  export_apply=True, export_image_format="JPEG", export_jpeg_quality=88)
        obj.data.calc_loop_triangles()
        # Count actual triangles, not polygon_count * 2: capped rods and
        # pyramids contain triangles and n-gons as well as quads.
        for accent in shown:
            accent.data.calc_loop_triangles()
        accent_triangles = sum(len(accent.data.loop_triangles) for accent in shown)
        permanent_triangles = sum(len(accent.data.loop_triangles) for accent in shown
                                  if not accent.name.startswith("Q_"))
        low_t, high_t = bounds([vertex.co for vertex in obj.data.vertices])
        tiers.append({"tier": tier, "path": str(path.relative_to(ROOT)), "triangles": len(obj.data.loop_triangles),
                      "permanent_triangles": permanent_triangles,
                      "accent_triangles_max": accent_triangles, "texture_edges": {"base_color": edges[0], "normal": edges[1], "metallic_roughness": edges[2]},
                      "texel_density_px_per_m": round(texel_density(obj.data, edges[0]), 1),
                      "bounds_blender": [[round(v, 5) for v in low_t], [round(v, 5) for v in high_t]],
                      "size_bytes": path.stat().st_size, "sha256": digest(path)})
    record["tiers"] = tiers
    record["collision"] = "convex hull, at most 96 triangles (Godot -convcolonly)" if collider else "none: hand props use sockets and the combat sweep"
    return record


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    catalog = json.loads(PROFILES.read_text(encoding="utf-8"))
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    chosen = list(catalog["assets"])
    if "--list" in arguments:
        print("\n".join(chosen))
        return
    if "--only" in arguments:
        chosen = arguments[arguments.index("--only") + 1].split(",")
    report = json.loads(REPORT.read_text(encoding="utf-8")) if REPORT.exists() else {
        "generator": str(Path(__file__).relative_to(ROOT)), "new_generation_submitted": False, "gear": {}}
    report["blender"] = bpy.app.version_string
    for identity in chosen:
        report["gear"][identity] = build(identity, catalog["assets"][identity], catalog, lock)
        REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("MESHY_GEAR_BUILT", identity, sum(tier["size_bytes"] for tier in report["gear"][identity]["tiers"]), "bytes", flush=True)


if __name__ == "__main__":
    main()
