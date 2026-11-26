"""Publish one #115 family into the adult muster. Run in Blender after build.py.

blender -b -P art/germanic_warriors/valley_export.py -- EXPORT/figures forest_spear
"""
import math
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np

source, family = sys.argv[sys.argv.index("--") + 1:]
source = Path(source)
target = Path(__file__).resolve().parents[2] / "prototype/assets/germanic_warriors"
target.mkdir(parents=True, exist_ok=True)
for tier in (0, 1):
    shutil.copyfile(source / f"germanic_{family}_{tier}.glb", target / f"{family}_{tier}.glb")

# Freeze the lowest authored mesh in its idle pose, preserving all surfaces.
# Each face samples its old pigment into a single small palette texture, so a
# whole company can be rendered with one material in the existing MultiMesh.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source / f"germanic_{family}_3.glb"))
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
arm.animation_data.use_nla = False
idle = next(a for a in bpy.data.actions if a.name.lower().startswith("idle"))
arm.animation_data.action = idle
bpy.context.scene.frame_set(int(idle.frame_range[0]))
deps = bpy.context.evaluated_depsgraph_get()
positions, faces, colors = [], [], []
images = {}


def pigment(material, uv):
    if not material or not material.use_nodes:
        return [0.25, 0.16, 0.09, 1.0]
    shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    socket = shader.inputs["Base Color"]
    node = socket.links[0].from_node if socket.is_linked else None
    if not node or node.type != "TEX_IMAGE" or not node.image:
        return list(socket.default_value)
    image = node.image
    if image.name not in images:
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        images[image.name] = pixels.reshape((image.size[1], image.size[0], 4))
    return images[image.name][int((uv[1] % 1) * image.size[1]), int((uv[0] % 1) * image.size[0])]


for obj in bpy.context.scene.objects:
    if obj.type != "MESH" or not obj.material_slots:
        continue
    evaluated = obj.evaluated_get(deps)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    offset = len(positions)
    positions.extend(tuple(evaluated.matrix_world @ vert.co) for vert in mesh.vertices)
    uv = mesh.uv_layers.active
    for tri in mesh.loop_triangles:
        faces.append(tuple(offset + idx for idx in tri.vertices))
        center = np.mean([tuple(uv.data[idx].uv) for idx in tri.loops], axis=0) if uv else (0.5, 0.5)
        material = obj.material_slots[tri.material_index].material if tri.material_index < len(obj.material_slots) else None
        colors.append(pigment(material, center))
    evaluated.to_mesh_clear()

base = bpy.data.meshes.new(family)
base.from_pydata(positions, [], faces)
actor = bpy.data.objects.new(family, base)
bpy.context.collection.objects.link(actor)
side = 2 ** math.ceil(math.log2(math.ceil(math.sqrt(len(faces)))))
pixels = np.ones((side * side, 4), dtype=np.float32)
pixels[:len(colors)] = np.array(colors)
# Duplicate each texel into a tile to retain pigments through the first mips.
pixels = np.repeat(np.repeat(pixels.reshape(side, side, 4), 4, axis=0), 4, axis=1)
atlas = bpy.data.images.new(family + "_pigments", width=side * 4, height=side * 4)
atlas.pixels.foreach_set(pixels.flatten())
atlas.pack()
material = bpy.data.materials.new(family + "_surface")
material.use_nodes = True
nodes = material.node_tree.nodes
shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
shader.inputs["Roughness"].default_value = 0.88
palette = nodes.new("ShaderNodeTexImage")
palette.image = atlas
material.node_tree.links.new(palette.outputs["Color"], shader.inputs["Base Color"])
base.materials.append(material)
uv = base.uv_layers.new()
for poly in base.polygons:
    center = ((poly.index % side + 0.5) / side, (poly.index // side + 0.5) / side)
    for loop in poly.loop_indices:
        uv.data[loop].uv = center
bpy.ops.object.select_all(action="DESELECT")
actor.select_set(True)
bpy.context.view_layer.objects.active = actor
bpy.ops.export_scene.gltf(filepath=str(target / f"{family}_far.glb"), export_format="GLB",
                          use_selection=True, export_animations=False)
print(f"VALLEY_SILHOUETTE {family} {len(faces)} triangles")
