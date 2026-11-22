"""Create IMPERATHEN's original prototype hut with Blender's bundled Python.

Run: blender --background --python tools/build_frontier_hut.py -- --output prototype/assets
Optional: --preview /absolute/path/hut_preview.png
The exported asset uses metres, an origin at floor centre, and a south-facing door.
No external models, textures, fonts, add-ons or network services are used.
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def material(name, color, roughness=0.86):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1.0)
    item.use_nodes = True
    surface = item.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = (*color, 1.0)
    surface.inputs["Roughness"].default_value = roughness
    return item


def box(name, size, position, paint, bevel=0.02, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    obj.data.materials.append(paint)
    if bevel:
        modifier = obj.modifiers.new("Hand-cut edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def build(output, source, preview):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    stone = material("Local warm limestone", (0.44, 0.38, 0.29))
    plaster = material("Lime and earth plaster", (0.69, 0.60, 0.45))
    timber = material("Dark structural oak", (0.20, 0.115, 0.055))
    boards = material("Worn wood", (0.36, 0.22, 0.10))
    clay = material("Terracotta roof", (0.40, 0.155, 0.075))
    clay_light = material("Weathered terracotta", (0.50, 0.225, 0.12))
    linen = material("Linen bedding", (0.61, 0.56, 0.42))
    metal = material("Iron hinges", (0.115, 0.12, 0.115), 0.6)

    box("Stone threshold", (4.10, 3.90, 0.14), (0, 0, 0.07), stone)
    for side in (-1, 1):
        box("Side wall", (0.22, 3.60, 2.25), (side * 1.86, 0, 1.26), plaster)
    box("Rear wall", (3.70, 0.22, 2.25), (0, 1.75, 1.26), plaster)
    for side in (-1, 1):
        box("Door side wall", (1.30, 0.22, 2.25), (side * 1.20, -1.75, 1.26), plaster)
    box("Door lintel", (1.15, 0.30, 0.40), (0, -1.76, 2.19), timber)
    for x in (-1.81, 1.81):
        for y in (-1.71, 1.71):
            box("Corner post", (0.20, 0.20, 2.44), (x, y, 1.35), timber)
    for y in (-1.76, 1.76):
        box("Eaves beam", (3.92, 0.22, 0.18), (0, y, 2.38), timber)
    for side in (-1, 1):
        box("Side base timber", (0.24, 3.65, 0.18), (side * 1.86, 0, 0.41), timber)
    for y in (-1.76, 1.76):
        for x in (-1.30, 1.30):
            box("Visible foundation stone", (1.0, 0.26, 0.24), (x, y, 0.26), stone)

    # Gable infill and two roof planes. glTF exporter performs the Z-up -> Y-up conversion.
    mesh = bpy.data.meshes.new("Gable geometry")
    mesh.from_pydata([(-1.85, -1.75, 2.38), (1.85, -1.75, 2.38), (0, -1.75, 3.43),
                     (-1.85, 1.75, 2.38), (1.85, 1.75, 2.38), (0, 1.75, 3.43)], [],
                    [(0, 1, 2), (5, 4, 3)])
    mesh.update()
    gable = bpy.data.objects.new("Plastered gables", mesh)
    bpy.context.collection.objects.link(gable)
    gable.data.materials.append(plaster)
    slope = math.atan2(1.15, 2.17)
    plane_length = math.hypot(2.17, 1.15)
    for side in (-1, 1):
        box("Roof substrate", (plane_length, 4.15, 0.10),
            (side * 1.085, 0, 2.955), clay, rotation=(0, side * slope, 0))
        for row in range(6):
            x = 0.12 + row * 0.36
            z = 3.64 - x * math.tan(slope)
            for column in range(9):
                y = -1.85 + column * 0.46
                paint = clay_light if (row * 3 + column) % 5 == 0 else clay
                box("Overlapping fired tile", (0.47, 0.47, 0.055), (side * x, y, z),
                    paint, 0.012, (0, side * slope, 0))
    box("Ridge cap", (0.20, 4.24, 0.16), (0, 0, 3.66), clay_light)
    for side in (-1, 1):
        box("Gable rafter", (plane_length, 0.14, 0.14),
            (side * 1.085, -2.03, 2.97), timber, rotation=(0, side * slope, 0))

    # Open doorway with readable interior. Geometry is intentionally modest for this prototype.
    for index in range(9):
        box("Floor board", (0.39, 3.34, 0.04), (-1.56 + index * 0.39, 0, 0.16), boards, 0.005)
    box("Bed frame", (0.94, 1.72, 0.30), (-1.10, 0.48, 0.33), timber)
    box("Linen mattress", (0.86, 1.65, 0.11), (-1.10, 0.48, 0.54), linen, 0.045)
    box("Pillow", (0.62, 0.32, 0.10), (-1.10, 1.02, 0.64), linen, 0.045)
    box("Storage chest", (0.74, 0.48, 0.52), (1.12, 1.03, 0.43), boards)
    box("Chest iron band", (0.075, 0.50, 0.54), (0.94, 1.03, 0.43), metal, 0)
    box("Chest iron band", (0.075, 0.50, 0.54), (1.31, 1.03, 0.43), metal, 0)
    box("Open door", (0.07, 0.91, 1.85), (0.56, -1.19, 1.11), boards)

    # Consolidate by material to keep exported draw surfaces small and apply object transforms.
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    batches = {}
    for obj in meshes:
        batches.setdefault(obj.data.materials[0].name, []).append(obj)
    exports = []
    for name, objects in batches.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = name.replace(" ", "_")
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        exports.append(joined)
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exports:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / "frontier_hut.glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_texcoords=True,
                              export_normals=True, export_materials="EXPORT", export_extras=False)

    # Source scene includes a separate studio stage, excluded from the game asset export.
    ground = material("Preview ground", (0.19, 0.22, 0.16))
    box("Preview stage — not exported", (200, 200, 0.1), (0, 0, -0.08), ground, 0)
    bpy.ops.object.camera_add(location=(7.8, -10.5, 6.4))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 8.4
    look_at(camera, (0, 0, 1.35))
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(1.5, -4.0, 7.5))
    bpy.context.object.data.energy = 1000
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 5
    look_at(bpy.context.object, (0, 0, 1.0))
    scene = bpy.context.scene
    scene.world.color = (0.28, 0.32, 0.38)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    # CPU builds need not include the optional OpenImageDenoise component.
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    source.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    if preview:
        preview.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(preview)
        bpy.ops.render.render(write_still=True)
    print("IMPERATHEN_ASSET_OK: frontier_hut.glb and editable frontier_hut.blend")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "art/source/frontier_hut.blend")
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    build(args.output.resolve(), args.source.resolve(), args.preview.resolve() if args.preview else None)
