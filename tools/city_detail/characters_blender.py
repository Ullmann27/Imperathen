"""Inspect and render the real hero with the optional city material pass.

blender -b -t 4 -P tools/city_detail/characters_blender.py -- --render
Only the review copy receives new materials. The source GLB remains byte-identical.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from characters_package import externalize_images

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "prototype/assets/city_detail/characters"
SOURCE = ROOT / "prototype/assets/characters/hero_quality_0.glb"
DEFAULT_OUT = ROOT / "tools/city_detail/characters_review"
KNOWN = {"HeroSkin": "skin", "FrontierSkin": "skin", "HeroLinen": "linen",
         "FrontierCloth": "linen", "HeroLeather": "leather"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geometry_record(objects) -> dict:
    data = {}
    for obj in sorted(objects, key=lambda item: item.name):
        item = {"type": obj.type, "parent": obj.parent.name if obj.parent else None,
                "matrix_local": [float(v) for row in obj.matrix_local for v in row]}
        if obj.type == "MESH":
            mesh = obj.data
            digest = hashlib.sha256()
            for vertex in mesh.vertices:
                digest.update(struct.pack("<3f", *vertex.co))
                for group in vertex.groups:
                    digest.update(struct.pack("<If", group.group, group.weight))
            for polygon in mesh.polygons:
                for index in polygon.vertices:
                    digest.update(struct.pack("<I", index))
            for layer in mesh.uv_layers:
                for uv in layer.data:
                    digest.update(struct.pack("<2f", *uv.uv))
            shapes = []
            if mesh.shape_keys:
                for key in mesh.shape_keys.key_blocks:
                    shapes.append(key.name)
                    for vertex in key.data:
                        digest.update(struct.pack("<3f", *vertex.co))
            item.update(vertices=len(mesh.vertices), polygons=len(mesh.polygons),
                        shape_keys=shapes, geometry_weights_uv_sha256=digest.hexdigest())
        if obj.type == "ARMATURE":
            item["bones"] = [{"name": bone.name,
                              "parent": bone.parent.name if bone.parent else None,
                              "matrix": [float(v) for row in bone.matrix_local for v in row]}
                             for bone in obj.data.bones]
        data[obj.name] = item
    return data


def action_record() -> list:
    result = []
    for action in sorted(bpy.data.actions, key=lambda item: item.name):
        digest = hashlib.sha256()
        channels = 0
        if hasattr(action, "fcurves"):
            for curve in action.fcurves:
                channels += 1
                digest.update((curve.data_path + str(curve.array_index)).encode())
                for key in curve.keyframe_points:
                    digest.update(struct.pack("<2f", *key.co))
        result.append({"name": action.name, "channels": channels,
                       "keyframes_sha256": digest.hexdigest()})
    return result


def data_image(name: str):
    image = bpy.data.images.load(str(MAPS / name), check_existing=True)
    image.colorspace_settings.name = "Non-Color"
    image.pack()
    return image


def detailed_material(source):
    category = KNOWN.get(source.name)
    if category is None:
        return source
    material = source.copy()
    material.name = source.name + "_CityDetail"
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    normal_image = nodes.new("ShaderNodeTexImage")
    normal_image.image = data_image(category + "_detail_normal.png")
    normal_image.label = "City: authored surface detail; original colour retained"
    normal_node = nodes.new("ShaderNodeNormalMap")
    normal_node.inputs["Strength"].default_value = 1.0
    links.new(normal_image.outputs["Color"], normal_node.inputs["Color"])
    links.new(normal_node.outputs["Normal"], shader.inputs["Normal"])
    if category == "skin":
        roughness = nodes.new("ShaderNodeTexImage")
        roughness.image = data_image("skin_detail_roughness.png")
        links.new(roughness.outputs["Color"], shader.inputs["Roughness"])
    return material


def aim(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("City character review")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (.10, .12, .15, 1)
    background.inputs["Strength"].default_value = .3
    scene.view_settings.view_transform = "AgX"
    for name, position, energy, size in [
        ("Key", (-2.5, -3.5, 4), 350, 2.5),
        ("Fill", (2, -2, 2.5), 100, 2.0),
        ("Rim", (1.0, 2.2, 3.0), 220, 1.8),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = position
        aim(light, (0, 0, 1.05))
    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source_hash = sha(SOURCE)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    imported = list(bpy.context.scene.objects)
    for obj in imported:
        if obj.type == "ARMATURE":
            # Rest is an explicit studio display mode, not a rewritten animation.
            obj.data.pose_position = "REST"
    for action in bpy.data.actions:
        action.use_fake_user = True
    before = geometry_record(imported)
    actions_before = action_record()
    slots = [(obj, index, slot.material) for obj in imported if obj.type == "MESH"
             for index, slot in enumerate(obj.material_slots)]
    camera = studio()
    frames = {
        "face": ((.36, -1.55, 1.46), (0, -.01, 1.34), 100),
        "cloth": ((.38, -1.4, .98), (0, -.01, .89), 100),
    }
    captures = []
    cache = {}
    for variant in ["before", "after"]:
        if variant == "after":
            for obj, index, source in slots:
                if source.name not in cache:
                    cache[source.name] = detailed_material(source)
                obj.material_slots[index].material = cache[source.name]
        if args.render:
            for name, (position, target, lens) in frames.items():
                camera.location = position
                camera.data.lens = lens
                aim(camera, target)
                bpy.context.scene.render.filepath = str(out / (name + "_" + variant + ".png"))
                bpy.ops.render.render(write_still=True)
                path = Path(bpy.context.scene.render.filepath)
                captures.append({"view": name, "variant": variant, "file": path.name,
                                 "sha256": sha(path), "camera": list(position),
                                 "target": list(target), "lens_mm": lens})
    after = geometry_record(imported)
    actions_after = action_record()
    source_unchanged = sha(SOURCE) == source_hash
    geometry_unchanged = before == after
    animation_unchanged = actions_before == actions_after
    if not all([source_unchanged, geometry_unchanged, animation_unchanged]):
        raise RuntimeError("Character detail changed source bytes, geometry, rig or animations.")
    textures = externalize_images(out)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "hero_city_detail.blend"), compress=True)
    report = {
        "blender": bpy.app.version_string,
        "source": str(SOURCE.relative_to(ROOT)), "source_sha256": source_hash,
        "original_glb_unchanged": source_unchanged,
        "geometry_weights_uv_morphs_rig_unchanged": geometry_unchanged,
        "animation_curves_unchanged": animation_unchanged,
        "comparison": "Same source, camera, lights and exposure; material maps only",
        "studio_pose": "Rest; existing animation data retained, not a motion proof",
        "android_device_test": False, "renders_executed": bool(args.render),
        "objects": before, "animations": actions_before, "captures": captures,
        "blend_file": "hero_city_detail.blend",
        "blend_packaging": "Editable Blender file with complete original encoded images under relative //textures/ paths",
        "textures": textures,
        "blend_sha256": sha(out / "hero_city_detail.blend"),
    }
    (out / "character_detail_review.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k not in ["objects", "animations"]}, indent=2))

if __name__ == "__main__":
    main()
