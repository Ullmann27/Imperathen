#!/usr/bin/env python3
"""Bake vegetation distance atlases from the exact shipped source meshes.

This deliberately avoids the glTF *exporter* API, which changed between the
original Blender 4.3 authoring environment and the Ubuntu 4.0 build runner.
The original geometry, UVs, material identities, and all four LODs are kept.
Only missing albedo/normal atlases and the manifest metadata are generated.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build as authored  # noqa: E402


def complete(name, meta):
    return bool(meta.get("impostor")) and all(
        (authored.TEX / f"impostor_{name}_{mode}.png").is_file()
        for mode in ("albedo", "normal")
    )


def bake(name, meta):
    path = authored.OUT / f"{name}.glb"
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    authored.clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    mesh_objects = [
        obj for obj in bpy.context.scene.objects if obj.type == "MESH"
    ]
    candidates = [obj for obj in mesh_objects if obj.name == f"{name}_lod0"]
    if len(candidates) != 1:
        raise RuntimeError(f"{name}: expected one original LOD0; got {[o.name for o in mesh_objects]}")
    lod0 = candidates[0]
    # Retain the world transform while dropping the importer parent node.
    matrix = lod0.matrix_world.copy()
    lod0.parent = None
    lod0.matrix_world = matrix
    for obj in list(bpy.context.scene.objects):
        if obj != lod0:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    lod0.select_set(True)
    bpy.context.view_layer.objects.active = lod0
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lod0.data.calc_loop_triangles()
    if len(lod0.data.loop_triangles) != meta["triangles"][0]:
        raise RuntimeError(f"{name}: original LOD0 triangle count differs from the authored manifest")
    if not lod0.data.uv_layers:
        raise RuntimeError(f"{name}: original UVs missing")
    colors = lod0.data.color_attributes
    if "Col" not in colors:
        active = colors.active_color
        if active is None and len(colors) == 1:
            active = colors[0]
        if active is None:
            raise RuntimeError(f"{name}: original vertex colors are missing")
        active.name = "Col"
    # Material slot names are part of the Godot runtime's authored contract.
    # Reconstruct the very same shader node trees used by the original baker.
    kinds = []
    for slot in lod0.material_slots:
        original = slot.material
        if original is None:
            raise RuntimeError(f"{name}: empty original material slot")
        kind = "leaf" if original.name.startswith("leaf_") else "bark" if original.name.startswith("bark_") else ""
        if not kind:
            raise RuntimeError(f"{name}: unexpected material {original.name}")
        kinds.append(kind)
        slot.material = authored.material(
            f"{kind}_{meta[kind]}", meta["bark"], meta["leaf"], kind
        )
    if set(kinds) != {"leaf", "bark"}:
        raise RuntimeError(f"{name}: missing bark or leaf geometry")
    baked = authored.bake_impostor(name, lod0)
    # Check actual raster sizes and nonempty coverage, not just file existence.
    for mode in ("albedo", "normal"):
        raster = authored.TEX / f"impostor_{name}_{mode}.png"
        image = bpy.data.images.load(str(raster), check_existing=False)
        expected = (int(baked["frame_px"]) * int(baked["views"]), int(baked["frame_px"]))
        if tuple(image.size) != expected:
            raise RuntimeError(f"{name}: {mode} atlas has wrong dimensions: {tuple(image.size)}")
        if mode == "albedo":
            import numpy as np
            data = np.empty(expected[0] * expected[1] * 4, dtype=np.float32)
            image.pixels.foreach_get(data)
            alpha = data[3::4].reshape(expected[1], expected[0])
            for frame in range(int(baked["views"])):
                width = int(baked["frame_px"])
                if float(alpha[:, frame * width:(frame + 1) * width].max()) < .5:
                    raise RuntimeError(f"{name}: empty impostor frame {frame}")
        bpy.data.images.remove(image)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise RuntimeError(f"{name}: source GLB unexpectedly changed")
    meta["impostor"] = baked
    meta["impostor_source_sha256"] = digest
    print("VEGETATION_IMPOSTOR_BAKED", name, digest, flush=True)


def main():
    if bpy.app.version < (4, 0, 0):
        raise RuntimeError("Blender 4.0 or newer is required for the authored material nodes")
    path = authored.OUT / "manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    assets = data["assets"]
    for name, meta in assets.items():
        if meta["kind"] in ("cards", "vine") or complete(name, meta):
            continue
        bake(name, meta)
        temporary = path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        temporary.replace(path)
    print("VEGETATION_ORIGINAL_IMPOSTORS_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
