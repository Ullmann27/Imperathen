"""Blender Cycles review plates of the exported vegetation GLBs (re-imported).

    blender -b -t 3 -P art/vegetation/render_review.py -- <out_dir> [lineup] [lods] [cards]

lineup  every tree, shrub and vine LOD0 side by side (one shared metre scale)
lods    quercus_robur LOD0..LOD3 and its impostor card, same scale
cards   herb and crop clump cards (every atlas tile)
The plates show the game files themselves: GLBs from prototype/assets/
vegetation are imported and only re-dressed with the committed PNG textures.
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
from build import OUT, TEX, material  # noqa: E402
from species import CROP_TILES, HERB_TILES, SHRUBS, TREES, VINES  # noqa: E402

ORDER = list(TREES) + list(SHRUBS) + list(VINES)


def setup(width, height, samples=24):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.transparent_max_bounces = 64
    scene.cycles.max_bounces = 4
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (.55, .66, .8, 1)
    bg.inputs["Strength"].default_value = .55
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(2.5)
    sun_obj = bpy.data.objects.new("sun", sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(8), math.radians(-35))
    scene.collection.objects.link(sun_obj)
    ground = bpy.data.meshes.new("ground")
    ground.from_pydata([(-400, -400, 0), (400, -400, 0), (400, 400, 0), (-400, 400, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("ground", ground)
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.23, .25, .16, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .95
    ground.materials.append(mat)
    scene.collection.objects.link(g)
    return scene


def import_asset(name, lods=("lod0",)):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT / f"{name}.glb"))
    objects = [o for o in bpy.data.objects if o not in before]
    keep = []
    for o in objects:
        if o.type != "MESH" or not any(o.name.startswith(f"{name}_{lod}") for lod in lods):
            continue
        keep.append(o)
        attr = o.data.color_attributes[0].name if o.data.color_attributes else "Col"
        for slot in o.material_slots:
            src = slot.material.name.split(".")[0]
            kind = "bark" if src.startswith("bark_") else "leaf"
            m = material(src + "_review", src[5:], src[5:], kind)
            for node in m.node_tree.nodes:
                if node.type == "VERTEX_COLOR":
                    node.layer_name = attr
            slot.material = m
    for o in objects:
        if o not in keep:
            o.hide_render = True
            o.hide_viewport = True
    return keep


def camera(scene, location, target, lens=50, ortho=None):
    cam = bpy.data.cameras.new("cam")
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    cam.lens = lens
    obj = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(obj)
    obj.location = location
    direction = Vector(target) - Vector(location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = obj


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("REVIEW_PLATE", path, flush=True)


def lineup(out):
    scene = setup(2400, 900)
    x = 0.0
    for name in ORDER:
        objs = import_asset(name)
        radius = max(max(math.hypot(v.co.x, v.co.y) for v in o.data.vertices) for o in objs)
        x += radius * .8
        for o in objs:
            o.location.x = x
        if name == "vitis_arbustum":
            support = import_asset("acer_campestre_arbustum")
            for o in support:
                o.location.x = x
        x += radius * .8 + .6
    camera(scene, (x / 2, -95, 9), (x / 2, 0, 8), ortho=x * 1.02)
    render(scene, out / "vegetation_lineup.png")


def lods(out):
    scene = setup(2000, 700)
    name = "quercus_robur"
    x = 0.0
    for i, lod in enumerate(("lod0", "lod1", "lod2", "lod3")):
        objs = import_asset(name, (lod,))
        for o in objs:
            o.location.x = x
        x += 15.5
    # Impostor frame 0 on a plane, exactly as the game card shows it.
    import json
    meta = json.loads((OUT / "manifest.json").read_text())["assets"][name].get("impostor")
    if meta:
        size = meta["frame_size_m"]
        mesh = bpy.data.meshes.new("impostor")
        cz = meta["center_height_m"]
        mesh.from_pydata([(-size / 2, 0, cz - size / 2), (size / 2, 0, cz - size / 2), (size / 2, 0, cz + size / 2), (-size / 2, 0, cz + size / 2)], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new()
        views = meta["views"]
        for loop, (u, v) in zip(mesh.polygons[0].loop_indices, ((0, 0), (1 / views, 0), (1 / views, 1), (0, 1))):
            uv.data[loop].uv = (u, v)
        obj = bpy.data.objects.new("impostor", mesh)
        obj.location.x = x
        scene.collection.objects.link(obj)
        mat = bpy.data.materials.new("impostor")
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(TEX / f"impostor_{name}_albedo.png"))
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mask = nodes.new("ShaderNodeMath")
        mask.operation = "GREATER_THAN"
        mask.inputs[1].default_value = .5
        links.new(tex.outputs["Alpha"], mask.inputs[0])
        links.new(mask.outputs[0], bsdf.inputs["Alpha"])
        mesh.materials.append(mat)
        x += 15.5
    camera(scene, ((x - 15.5) / 2, -90, 9), ((x - 15.5) / 2, 0, 8.5), ortho=x + 2)
    render(scene, out / "vegetation_lods_quercus_robur.png")


def cards(out):
    scene = setup(1800, 900, 16)
    objs = import_asset("herb_cards", ("clump_near",))
    base = objs[0]
    for atlas, tiles, row in (("herbs", HERB_TILES, 0), ("crops", CROP_TILES, 1)):
        mat = bpy.data.materials.new(atlas)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(TEX / f"{atlas}_albedo.png"), check_existing=True)
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mask = nodes.new("ShaderNodeMath")
        mask.operation = "GREATER_THAN"
        mask.inputs[1].default_value = .45
        links.new(tex.outputs["Alpha"], mask.inputs[0])
        links.new(mask.outputs[0], bsdf.inputs["Alpha"])
        for i, kind in enumerate(tiles):
            if not kind:
                continue
            obj = base.copy()
            obj.data = base.data.copy()
            obj.data.materials.clear()
            obj.data.materials.append(mat)
            du, dv = (i % 4) * .25, -(i // 4) * .25
            for loop in obj.data.uv_layers[0].data:
                loop.uv = (loop.uv[0] + du, loop.uv[1] + dv)
            obj.location = (i * 1.3, row * 3.0, 0)
            obj.scale = (1.0, 1.0, 1.6 if kind in ("reed", "reed_plume", "iris", "loosestrife") else 1.0)
            scene.collection.objects.link(obj)
    base.hide_render = True
    camera(scene, (10, -16, 4.5), (10, 1.5, .6), lens=45)
    render(scene, out / "vegetation_cards.png")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    plates = argv[1:] or ["lineup", "lods", "cards"]
    for plate in plates:
        {"lineup": lineup, "lods": lods, "cards": cards}[plate](out)


if __name__ == "__main__":
    main()
