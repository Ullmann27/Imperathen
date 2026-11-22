"""Shared, deterministic Blender authoring helpers for IMPERATHEN's mobile art kit.

Run through Blender's bundled Python. No network or external asset dependencies.
Coordinates: metres, Z up, front -Y. glTF export converts to Y up, front +Z.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART_ROOT = ROOT / "art" / "visual_benchmark"
TEXTURE_ROOT = ART_ROOT / "materials"


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def material(name, color_tuple, roughness=0.8, metallic=0.0, texture=None):
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    rgba = tuple(color_tuple[:3]) + (color_tuple[3] if len(color_tuple) > 3 else 1.0,)
    mat.diffuse_color = rgba
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if texture:
        for suffix, socket in [("basecolor", "Base Color"), ("roughness", "Roughness"), ("normal", "Normal")]:
            path = TEXTURE_ROOT / f"{texture}_{suffix}.png"
            if not path.is_file():
                raise FileNotFoundError(f"Generate material maps first: {path}")
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(str(path), check_existing=True)
            tex.extension = "REPEAT"
            if suffix != "basecolor":
                tex.image.colorspace_settings.name = "Non-Color"
            if suffix == "normal":
                normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
                normal.inputs["Strength"].default_value = 0.65
                mat.node_tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
                mat.node_tree.links.new(normal.outputs["Normal"], bsdf.inputs[socket])
            elif suffix == "basecolor":
                # The glTF exporter recognises this exact Mix/Multiply pattern
                # as baseColorTexture + baseColorFactor. Keep factors in [0,1].
                bases = {"plaster": (.73,.69,.57), "limestone": (.46,.45,.39),
                         "oak": (.26,.17,.09), "terracotta": (.48,.23,.13),
                         "linen": (.60,.51,.35), "leather": (.20,.105,.054),
                         "bronze": (.48,.32,.12), "earth": (.29,.26,.19)}
                base = bases.get(texture, (1,1,1))
                factor = tuple(min(1.0, max(0.0, rgba[i] / base[i])) for i in range(3)) + (1.0,)
                mix = mat.node_tree.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs[0].default_value = 1.0
                mix.inputs[7].default_value = factor
                mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[6])
                mat.node_tree.links.new(mix.outputs[2], bsdf.inputs[socket])
            else:
                mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs[socket])
    return mat


def _project_uv(obj, overwrite=False):
    """Deterministic box mapping in metres; custom character UVs are preserved."""
    data = obj.data
    if data.uv_layers and not overwrite:
        return
    uv = data.uv_layers.active or data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        axis = max(range(3), key=lambda n: abs(poly.normal[n]))
        axes = ((1, 2), (0, 2), (0, 1))[axis]
        for li in poly.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            uv.data[li].uv = (co[axes[0]], co[axes[1]])


def mesh(name, vertices, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    if mat:
        data.materials.append(mat)
    for poly in data.polygons:
        poly.use_smooth = smooth
    _project_uv(obj)
    return obj


def box(name, location, dimensions, mat, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    _project_uv(obj, overwrite=True)
    if bevel > 0:
        mod = obj.modifiers.new("Light-catching edges", "BEVEL")
        mod.width = min(bevel, min(dimensions) * 0.2)
        mod.segments = 2
        mod.affect = "EDGES"
    return obj


def cylinder(name, location, radius, depth, mat, vertices=16, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                      end_fill_type="NGON", location=location)
    obj = bpy.context.object
    obj.name = name
    if rotation is not None:
        obj.rotation_euler = rotation
    if mat:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    _project_uv(obj, overwrite=True)
    return obj


def _bake_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    _project_uv(obj)
    triangulate = obj.modifiers.new("Export tangent-safe triangles", "TRIANGULATE")
    triangulate.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.select_set(False)


def export_asset(asset_id, objects, output_dir):
    """Bake bevels and batch geometry by material; keep portable self-contained GLB.

    Source geometry is saved before batching for editing. No collider is implied.
    Shared scene export uses only the supplied object's list, never lights/cameras.
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    source_path = output_dir / f"{asset_id}.blend"
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [obj for obj in objects if obj and obj.type == "MESH"]
    if not meshes:
        raise ValueError(f"Asset {asset_id} has no mesh objects")
    for obj in meshes:
        _bake_modifiers(obj)
    # Save the complete editable source with packed original material maps.
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path), compress=True)
    groups = {}
    for obj in meshes:
        key = tuple(slot.material.name if slot.material else "none" for slot in obj.material_slots)
        groups.setdefault(key, []).append(obj)
    batched = []
    for index, group in enumerate(groups.values()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = f"{asset_id}_{index:02d}"
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        batched.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    points = []
    triangles = 0
    for obj in batched:
        obj.select_set(True)
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum = [min(point[i] for point in points) for i in range(3)]
    maximum = [max(point[i] for point in points) for i in range(3)]
    path = output_dir / f"{asset_id}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_texcoords=True,
                              export_normals=True, export_tangents=True,
                              export_animations=False, export_draco_mesh_compression_enable=False)
    report = {
        "asset_id": asset_id, "source": source_path.name, "file": path.name,
        "source_blender_version": bpy.app.version_string, "unit": "metre",
        "gltf_up_axis": "Y", "gltf_front": "+Z", "triangles": triangles,
        "mesh_batches": len(batched), "bounds_blender_z_up": [minimum, maximum],
        "dimensions_blender_z_up": [maximum[i] - minimum[i] for i in range(3)],
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "bytes": path.stat().st_size,
        "provenance": "Original procedural geometry and texture maps authored for IMPERATHEN; no third-party model downloads.",
        "license": "Project owner rights; no public redistribution license asserted.",
        "rigged": False, "collision_tested": False,
    }
    (output_dir / f"{asset_id}.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("IMPERATHEN_ASSET " + json.dumps(report))
    return report
