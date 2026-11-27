"""Blender-only, static mobile review derivative; not a rig or collision asset."""
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

source, target = map(Path, sys.argv[sys.argv.index("--") + 1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and len(obj.data.polygons)]
if not objects:
    raise RuntimeError("no_meshes")
transforms = {obj.name: obj.matrix_world.copy() for obj in objects}
for obj in objects:
    transform = transforms[obj.name]
    obj.data = obj.data.copy()
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(transform)
    obj.data.update()
bpy.context.view_layer.update()
for obj in list(bpy.context.scene.objects):
    if obj not in objects:
        bpy.data.objects.remove(obj, do_unlink=True)
points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
span = max(high - low)
if span <= 0.00001:
    raise RuntimeError("zero_bounds")
center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))
transform = Matrix.Scale(2.2 / span, 4) @ Matrix.Translation(-center)
for obj in objects:
    obj.data.transform(transform)
    obj.data.calc_loop_triangles()
total = sum(len(obj.data.loop_triangles) for obj in objects)
ratio = min(1.0, 9000 / max(total, 1))
for obj in objects:
    if ratio < 1.0:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        mod = obj.modifiers.new("mobile_review", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)
for image in bpy.data.images:
    w, h = image.size
    if max(w, h) > 1024:
        factor = 1024 / max(w, h)
        image.scale(max(1, round(w * factor)), max(1, round(h * factor)))
    if w and h and image.source == "FILE":
        image.pack()
for obj in objects:
    obj.select_set(True)
target.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", use_selection=True,
                         export_animations=False, export_skins=False, export_morph=False)
