#!/usr/bin/env python3
"""Fit existing Meshy equipment to metre-sized, grip-centred mobile GLBs.

No hosted generation, upload or paid conversion is performed. Canonical source
files remain unchanged. Run: blender -b -t 2 -P this_file
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "prototype/assets/meshy/source"
OUT = ROOT / "prototype/assets/meshy/equipment"
REPORT = ROOT / "docs/20_meshy_assets/equipment-build.json"
PROFILES = {
    "weap_germanic_hand_axe": {"category": "weapon", "height": .62, "grip_height": .12,
        "cross_scale": .52, "triangles": (1200, 350),
        "source_sha256": "6c665a3e0c5d929031c64632e2159ba60e0d75f7ccc3b1cf0856f9d4778af87c"},
    "gear_germanic_round_shield": {"category": "equipment", "height": .66,
        "cross_scale": 1.0, "triangles": (1800, 450),
        "source_sha256": "e0ca7bd76079567cff1b3f91425e9534af978358dc11dd4498af18fd04c78be0"},
    "gear_roman_signum": {"category": "equipment", "height": 2.10, "grip_height": .70,
        "cross_scale": 1.20, "triangles": (1400, 450),
        "source_sha256": "ec927a279e63e395de29f8a8bb7bd3c1e16ed26dc3a7df0c9aa7dfe5e5bacbd7"},
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bounds(points):
    return (Vector(tuple(min(point[index] for point in points) for index in range(3))),
            Vector(tuple(max(point[index] for point in points) for index in range(3))))


def connected_components(mesh):
    remaining = set(mesh.verts)
    result = []
    while remaining:
        seed = remaining.pop()
        queue, component = [seed], {seed}
        while queue:
            vertex = queue.pop()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in remaining:
                    remaining.remove(other)
                    component.add(other)
                    queue.append(other)
        result.append(component)
    return result


def source_object(identity, profile):
    path = SOURCE / profile["category"] / (identity + ".glb")
    if digest(path) != profile["source_sha256"]:
        raise ValueError("Unreviewed source; geometric fitting must be reviewed again: " + identity)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1 or meshes[0].find_armature():
        raise ValueError("Expected the reviewed single rigid prop: " + identity)
    obj = meshes[0]
    transform = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    for vertex in obj.data.vertices:
        vertex.co = transform @ vertex.co
    for node in list(bpy.context.scene.objects):
        if node != obj:
            bpy.data.objects.remove(node, do_unlink=True)
    original_bounds = bounds([vertex.co for vertex in obj.data.vertices])
    editable = bmesh.new()
    editable.from_mesh(obj.data)
    bmesh.ops.remove_doubles(editable, verts=list(editable.verts), dist=1e-6)
    removed = 0
    if identity == "weap_germanic_hand_axe":
        # Source inspection identifies three disconnected components. The
        # horizontal duplicate wooden handle is not part of the axe head or
        # its continuous vertical shaft; delete only that complete component.
        extras = []
        components = connected_components(editable)
        if len(components) != 3:
            raise ValueError("Axe component topology changed")
        for component in components:
            low, high = bounds([vertex.co for vertex in component])
            if low.x < -.40 and high.z < .18 and low.z > -.18:
                extras.append(component)
        if len(extras) != 1:
            raise ValueError("Cannot isolate the reviewed duplicate axe handle")
        removed = len(extras[0])
        bmesh.ops.delete(editable, geom=list(extras[0]), context="VERTS")
    bmesh.ops.dissolve_degenerate(editable, edges=list(editable.edges), dist=1e-7)
    editable.normal_update()
    editable.to_mesh(obj.data)
    editable.free()
    obj.data.validate(clean_customdata=True)
    points = [vertex.co.copy() for vertex in obj.data.vertices]
    low, high = bounds(points)
    scale = profile["height"] / (high.z - low.z)
    if identity == "gear_germanic_round_shield":
        # The back grip is behind the boss. Put that centre at the hand origin;
        # the front surface then faces Blender -Y / Godot +Z.
        origin = Vector(((low.x + high.x) * .5, high.y * .80, (low.z + high.z) * .5))
    else:
        shaft = [point for point in points if low.z + .08 < point.z < low.z + .32]
        shaft_low, shaft_high = bounds(shaft)
        origin = Vector(((shaft_low.x + shaft_high.x) * .5, (shaft_low.y + shaft_high.y) * .5,
                         low.z + profile["grip_height"] / scale))
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co - origin) * scale
        vertex.co.x *= profile["cross_scale"]
        vertex.co.y *= profile["cross_scale"]
    obj.data.update()
    obj.name = "MeshyEquipment_" + identity
    for material in obj.data.materials:
        material.name = "MeshyEquipmentMaterial_" + identity
    return obj, {"stable_id": identity, "source_path": str(path.relative_to(ROOT)),
                 "source_sha256": digest(path), "source_bytes": path.stat().st_size,
                 "source_bounds_blender": [list(value) for value in original_bounds],
                 "removed_duplicate_handle_vertices": removed, "uniform_scale": scale,
                 "cross_section_scale": profile["cross_scale"], "source_grip_origin": list(origin),
                 "height_m": profile["height"]}


def export_tiers(identity, obj, profile):
    original = obj.data.copy()
    result = []
    for tier, texture_edge in ((0, 512), (1, 256)):
        obj.data = original.copy()
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        bpy.context.view_layer.objects.active = obj
        budget = profile["triangles"][tier]
        if triangles > budget:
            modifier = obj.modifiers.new("Mobile equipment reduction", "DECIMATE")
            modifier.ratio = budget / triangles
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.validate(clean_customdata=True)
        for image in bpy.data.images:
            if max(image.size) > texture_edge:
                factor = texture_edge / max(image.size)
                image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
                image.pack()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        path = OUT / (identity + "_%d.glb" % tier)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_animations=False, export_skins=False, export_morph=False,
                                  export_image_format="JPEG", export_jpeg_quality=87)
        obj.data.calc_loop_triangles()
        low, high = bounds([vertex.co for vertex in obj.data.vertices])
        result.append({"tier": tier, "path": str(path.relative_to(ROOT)),
                       "triangles": len(obj.data.loop_triangles), "texture_edge": texture_edge,
                       "bounds_blender": [list(low), list(high)], "size_bytes": path.stat().st_size,
                       "sha256": digest(path)})
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for identity, profile in PROFILES.items():
        obj, record = source_object(identity, profile)
        record["tiers"] = export_tiers(identity, obj, profile)
        records.append(record)
    REPORT.write_text(json.dumps({"generator": str(Path(__file__).relative_to(ROOT)),
        "blender": bpy.app.version_string, "equipment": records,
        "new_generation_submitted": False,
        "limits": ["Cosmetic existing NPC equipment only; no inventory or combat authority.",
                   "Historical acceptance remains a separate review.",
                   "Grip and animation evidence is captured in the actual Godot actor."]}, indent=2) + "\n")
    print("MESHY_EQUIPMENT_BUILT", sum(tier["size_bytes"] for record in records for tier in record["tiers"]), "bytes")


if __name__ == "__main__":
    main()
