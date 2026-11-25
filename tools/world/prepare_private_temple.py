"""Prepare a privately supplied Meshy temple for the RomanCity 44x46-m plot.

Run in Blender 4.x:
blender -b -t 2 --python-exit-code 1 --python tools/world/prepare_private_temple.py -- \
  --input /private/source/temple.glb --output /private/staging/roman-temple

The original signed Meshy download URL, private source mesh and textures never
enter the public repository. Blender produces actual game GLBs, LODs and a
size/topology manifest in an operator-controlled private build directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def triangles(objects) -> int:
    return sum(sum(len(face.vertices) - 2 for face in obj.data.polygons)
               for obj in objects if obj.type == "MESH")


def world_bounds(objects):
    points = [obj.matrix_world @ Vector(point) for obj in objects if obj.type == "MESH"
              for point in obj.bound_box]
    if not points:
        raise RuntimeError("The private temple GLB contains no actual 3D mesh.")
    lo = [min(pt[i] for pt in points) for i in range(3)]
    hi = [max(pt[i] for pt in points) for i in range(3)]
    return lo, hi, [hi[i] - lo[i] for i in range(3)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--plot-width-m", type=float, default=44.0)
    parser.add_argument("--plot-depth-m", type=float, default=46.0)
    parser.add_argument("--max-height-m", type=float, default=30.0)
    parser.add_argument("--source-task-id", default="629bd668-c5ed-4057-bd6d-c02322c80e4e")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = args.input.resolve(strict=True)
    if source.suffix.lower() != ".glb" or source.stat().st_size < 5000:
        raise ValueError("Expected an original textured Meshy GLB larger than 5 kB.")
    if min(args.plot_width_m, args.plot_depth_m, args.max_height_m) <= 0:
        raise ValueError("Metric plot dimensions must be positive.")
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.import_scene.gltf(filepath=str(source))
    if "FINISHED" not in imported:
        raise RuntimeError("Blender did not import the private temple GLB.")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("No actual temple geometry imported from private source.")
    bpy.context.view_layer.update()
    lo, hi, dimensions = world_bounds(meshes)
    if min(dimensions) < 0.02 or not all(math.isfinite(x) for x in dimensions):
        raise RuntimeError("Meshy temple is incomplete or contains invalid metric dimensions.")
    # Blender is Z-up; imported glTF Y-up transforms are already converted
    # by the official Blender glTF importer.
    x_limit = args.plot_width_m - 2.0
    y_limit = args.plot_depth_m - 2.0
    z_limit = args.max_height_m
    factor = min(x_limit / dimensions[0], y_limit / dimensions[1], z_limit / dimensions[2])
    if factor <= 0 or not math.isfinite(factor) or factor > 100:
        raise RuntimeError("Unreasonable scale factor; source needs manual art review.")
    # Group all actual imported roots under one transform, preserving authored
    # child transforms/material links before uniform metric scaling.
    anchor = bpy.data.objects.new("Temple_Origin_UniformScale", None)
    bpy.context.scene.collection.objects.link(anchor)
    for obj in list(bpy.context.scene.objects):
        if obj == anchor or obj.parent is not None:
            continue
        matrix = obj.matrix_world.copy()
        obj.parent = anchor
        obj.matrix_world = matrix
    anchor.scale = (factor,) * 3
    anchor.location = (-(lo[0] + hi[0]) * factor * 0.5,
                       -(lo[1] + hi[1]) * factor * 0.5,
                       -lo[2] * factor)
    bpy.context.view_layer.update()
    new_lo, new_hi, fitted = world_bounds(meshes)
    if fitted[0] > args.plot_width_m - 1.5 or fitted[1] > args.plot_depth_m - 1.5 or fitted[2] > args.max_height_m + .01:
        raise RuntimeError("Scaled original temple exceeds its reserved metric footprint.")
    if abs(new_lo[2]) > 0.01:
        raise RuntimeError("Actual imported temple is not grounded on the Roman street plane.")
    before = triangles(meshes)
    if before <= 100:
        raise RuntimeError("Temple mesh is too simple to claim architectural detail.")
    reported = []
    for level, reduction in enumerate((1.0, .66, .40)):
        if level > 0:
            # Apply only to actual non-skinned static architecture. If the
            # original Meshy model is rigged, refuse an unsafe decimation.
            for obj in meshes:
                if obj.find_armature() is not None:
                    raise RuntimeError("Rigged temple detected; manual topology and socket review required.")
                if obj.data.polygons and len(obj.data.polygons) > 40:
                    bpy.ops.object.select_all(action="DESELECT")
                    bpy.context.view_layer.objects.active = obj
                    obj.select_set(True)
                    modifier = obj.modifiers.new("TempleLOD%d" % level, "DECIMATE")
                    modifier.ratio = 0.66 if level == 1 else (.40 / .66)
                    bpy.ops.object.modifier_apply(modifier=modifier.name)
        glb = root / ("roman_meshy_temple_%d.glb" % level)
        bpy.ops.object.select_all(action="DESELECT")
        anchor.select_set(True)
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = anchor
        bpy.ops.export_scene.gltf(
            filepath=str(glb), export_format="GLB", use_selection=True,
            export_materials="EXPORT", export_animations=False,
            export_cameras=False, export_lights=False)
        if not glb.is_file() or glb.stat().st_size < 5000:
            raise RuntimeError("Missing or incomplete real temple GLB " + glb.name)
        polycount = triangles(meshes)
        reported.append({"level": level, "triangles": polycount, "bytes": glb.stat().st_size,
                         "sha256": sha256(glb), "uniform_scale": factor})
    if not (reported[0]["triangles"] >= reported[1]["triangles"] >= reported[2]["triangles"]):
        raise RuntimeError("Temple LODs did not decrease triangle complexity.")
    bpy.ops.wm.save_as_mainfile(filepath=str(root / "roman_temple_review.blend"), compress=True)
    report = {
        "format": "imperathen-private-temple-preflight", "source_task_id": args.source_task_id,
        "private_source_sha256": sha256(source), "source_meshes": len(meshes),
        "source_size_blender_m": dimensions, "scaled_size_m": fitted,
        "reserved_plot_m": [args.plot_width_m, args.plot_depth_m],
        "max_height_m": args.max_height_m, "source_triangles": before,
        "lods": reported, "blender": bpy.app.version_string,
        "visual_author_review": "required", "fold7_gpu_review": "not_run",
        "original_meshey_asset_committed_to_public_repo": False
    }
    (root / "temple_review.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("PRIVATE_TEMPLE_PREPARED " + json.dumps({"lod_triangles": [r["triangles"] for r in reported],
        "size_metres": fitted, "needs_visual_review": True}))


if __name__ == "__main__":
    main()
