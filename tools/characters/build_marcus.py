#!/usr/bin/env python3
"""Build Marcus from the CC0-based anatomical source, not the player's private Meshy GLB.

All source files are read-only. The four runtime meshes, a separate editable
Blend and matched-camera renders are produced in scratch/output directories.
The existing hero exporter preserves the 15 locomotion joints and adds two
independent eyeball joints; age/face morphs, PBR and animation keys remain.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import build_hero as hero


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def gauss(value, centre, width):
    return math.exp(-((value - centre) / width) ** 2)


def smooth(value):
    t = max(0.0, min(1.0, value))
    return t * t * (3.0 - 2.0 * t)


def apply_delta(obj, displacement):
    # Translate each age/expressive shape by the same authored rest delta:
    # the original expression displacements remain exact. Nothing on the
    # neck, hands, feet, weights or bind matrices is replaced.
    keys = obj.data.shape_keys
    if keys:
        basis = keys.key_blocks[0]
        offsets = [displacement(point.co.copy()) for point in basis.data]
        for key in keys.key_blocks:
            for i, point in enumerate(key.data):
                point.co += offsets[i]
            key.value = 0.0
    else:
        offsets = [displacement(vertex.co.copy()) for vertex in obj.data.vertices]
        for vertex, offset in zip(obj.data.vertices, offsets):
            vertex.co += offset
    obj.data.update()
    return max((offset.length for offset in offsets), default=0.0)


def pbr_recolour(material_name, factor, suffix):
    material = bpy.data.materials.get(material_name)
    if material is None or not material.use_nodes:
        raise ValueError("Missing authored PBR material: " + material_name)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    links = bsdf.inputs["Base Color"].links
    if len(links) != 1 or links[0].from_node.type != "TEX_IMAGE":
        raise ValueError("Expected a direct albedo image for " + material_name)
    texture_node = links[0].from_node
    image = texture_node.image
    if not image or min(image.size) <= 0:
        raise ValueError("Missing image pixels: " + material_name)
    # A new packed image, retaining original UVs, alpha, normals and roughness.
    # No illumination is painted into the albedo.
    width, height = image.size
    pixels = np.empty(width * height * 4, np.float32)
    image.pixels.foreach_get(pixels)
    rgba = pixels.reshape(-1, 4)
    rgba[:, :3] = np.clip(rgba[:, :3] * np.array(factor, np.float32), 0.0, 1.0)
    replacement = bpy.data.images.new(suffix, width=width, height=height, alpha=True)
    replacement.colorspace_settings.name = image.colorspace_settings.name
    replacement.pixels.foreach_set(pixels)
    replacement.update()
    replacement.pack()
    # The same original image node also supplies hair transparency.
    texture_node.image = replacement


def shape_identity():
    arm = bpy.data.objects["HeroRig"]
    body = bpy.data.objects["HeroBody"]
    hair = bpy.data.objects["HeroHair"]
    eye = bpy.data.objects["HeroEyes"]
    neck = arm.data.bones["Head"].head_local.z
    top = max(v.co.z for v in body.data.vertices)
    height = top - neck
    if not 0.12 < height < 0.40:
        raise ValueError("Unexpected head proportions")
    eye_centre = sum((v.co for v in eye.data.vertices), Vector()) / len(eye.data.vertices)

    def face(p):
        h = (p.z - neck) / height
        # A separate, subtle adolescent jaw, chin, nose and cheek silhouette.
        # Eye lids, mouth and the joint transition are deliberately protected.
        fade = smooth((h - .06) / .15)
        front = smooth((eye_centre.y + .035 - p.y) / .06)
        eye_protect = 1.0 - .95 * gauss(p.z, eye_centre.z, .020)
        mouth_protect = 1.0 - .85 * gauss(h, .23, .10)
        jaw = gauss(h, .30, .17)
        cheek = gauss(h, .53, .13) * smooth((abs(p.x) - .025) / .035)
        # Separate the nasal bridge, tip and paired alar volumes instead of
        # extruding the entire nose as a single bump. All values are metres.
        # The eye-protection mask leaves the eyelid/eyeball fit intact.
        bridge = gauss(h, .61, .105) * gauss(p.x, 0.0, .010)
        tip = gauss(h, .46, .065) * gauss(p.x, 0.0, .012)
        alae = gauss(h, .425, .055) * gauss(abs(p.x), .017, .008)
        root = gauss(h, .72, .09) * gauss(p.x, 0.0, .016)
        chin = gauss(h, .16, .07) * gauss(p.x, 0.0, .032)
        nose_profile = -.0028 * bridge - .0048 * tip - .0018 * alae + .0012 * root
        return Vector((p.x * fade * eye_protect * mouth_protect * (-.065 * jaw + .045 * cheek)
                       + p.x * fade * front * eye_protect * mouth_protect * .055 * alae,
                       fade * front * eye_protect * mouth_protect * (.0024 * jaw + nose_profile - .0023 * cheek - .0015 * chin),
                       -.0018 * fade * front * chin * mouth_protect))

    def haircut(p):
        h = (p.z - neck) / height
        t = smooth((h - .63) / .37)
        # Distinct crown and swept fringe without moving the scalp attachment.
        return Vector((.009 * t * math.sin(p.x * 21.0 + p.y * 8.0),
                       .006 * t * math.cos(p.x * 17.0),
                       t * (.004 + .008 * math.sin(p.x * 19.0 + p.y * 12.0) ** 2)))

    face_change = apply_delta(body, face)
    hair_change = apply_delta(hair, haircut)
    if not .001 < face_change < .020 or not .001 < hair_change < .030:
        raise ValueError("Identity sculpt outside expected scale")
    pbr_recolour("HeroSkin", (.97, .92, .86), "Marcus_skin_albedo")
    pbr_recolour("HeroHair", (.72, .61, .48), "Marcus_dark_brown_hair")
    pbr_recolour("HeroLinen", (1.27, 1.15, .91), "Marcus_warm_woven_tunic")
    leather = bpy.data.materials["HeroLeather"]
    leather.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.15,.082,.041,1)
    leather.diffuse_color = (.15,.082,.041,1)
    return {"max_face_delta_m": face_change, "max_hair_delta_m": hair_change,
            "head_height_m": height, "bones": list(arm.data.bones.keys())}


def install_eye_rig(arm):
    """Rebind the two actual MakeHuman eye surfaces, never the eyelid skin."""
    obj = bpy.data.objects["HeroEyes"]
    if obj.parent != arm or not obj.data.shape_keys:
        raise ValueError("Expected authored skinned eye mesh and age morph")
    keys = obj.data.shape_keys.key_blocks
    basis, mature = keys["Basis"], keys["Mature"]
    points = np.array([tuple(v.co) for v in basis.data], dtype=float)
    grown = np.array([tuple(v.co) for v in mature.data], dtype=float)
    if points.shape != grown.shape or not np.isfinite(points).all() or not np.isfinite(grown).all():
        raise ValueError("Invalid eye geometry")
    if np.any(np.abs(points[:, 0]) < .005):
        raise ValueError("Eye surface crosses the anatomical midline")
    records = {}
    for side, sign in (("L", 1), ("R", -1)):
        ids = np.flatnonzero(points[:, 0] * sign > 0)
        surface = points[ids]
        adult = grown[ids]
        span = np.ptp(surface, axis=0)
        if len(ids) < 40 or not np.all((span > .010) & (span < .055)):
            raise ValueError("Unrecognised eyeball geometry " + side)
        # Fit the centre to the actual eye surface bounds rather than a guessed
        # head joint offset. The source contains separate cornea/sclera islands
        # for each eye, all of which move together.
        centre = (surface.min(0) + surface.max(0)) * .5
        adult_centre = (adult.min(0) + adult.max(0)) * .5
        if np.linalg.norm(adult_centre - centre) > .035:
            raise ValueError("Unrecognised mature eye displacement " + side)
        if any(len({int(points[i, 0] > 0) for i in poly.vertices}) != 1 for poly in obj.data.polygons):
            raise ValueError("An eye polygon joins both eyes")
        delta = adult_centre - centre
        records[side] = {"ids": ids.tolist(), "centre": centre.tolist(),
                         "span_m": span.tolist(), "adult_delta": [float(delta[0]), float(delta[2]), float(-delta[1])]}
    old = {b.name: (b.matrix_local.copy(), b.parent.name if b.parent else None) for b in arm.data.bones}
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        for side, row in records.items():
            bone = arm.data.edit_bones.new("Eye_" + side)
            bone.head = Vector(row["centre"])
            bone.tail = bone.head + Vector((0.0, -.025, 0.0))
            bone.parent = arm.data.edit_bones["Head"]
            bone.use_connect = False
            bone.use_deform = True
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    for name, (matrix, parent) in old.items():
        bone = arm.data.bones[name]
        if any(abs(a - b) > 1e-6 for ar, br in zip(matrix, bone.matrix_local) for a, b in zip(ar, br)) or (bone.parent.name if bone.parent else None) != parent:
            raise ValueError("Existing locomotion rest changed: " + name)
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    for side, row in records.items():
        name = "Eye_" + side
        group = obj.vertex_groups.new(name=name)
        group.add(row.pop("ids"), 1.0, "REPLACE")
        arm.pose.bones[name].rotation_mode = "QUATERNION"
    return records


def render(output, arm, label, mature=0.0, action=None, frame=0, eye_yaw=0.0, views=None):
    scene = bpy.context.scene
    # Original studio camera and light setup; identical views for before/after.
    camera = scene.camera
    if camera is None:
        camera = hero.setup_scene()
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 1000
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        if obj.name == "PracticeBlade":
            obj.hide_render = True
        if obj.data.shape_keys:
            for key in obj.data.shape_keys.key_blocks:
                key.value = mature if key.name == "Mature" else 1.0 if key.name == "Companion" else 0.0
    if arm.animation_data:
        for track in arm.animation_data.nla_tracks:
            track.mute = True
        arm.animation_data.action = bpy.data.actions.get(action) if action else None
    if not action:
        for bone in arm.pose.bones:
            bone.rotation_quaternion = (1,0,0,0)
            bone.location = (0,0,0)
            bone.scale = (1,1,1)
    scene.frame_set(frame)
    if eye_yaw:
        from mathutils import Quaternion
        for side in ('L', 'R'):
            bone = arm.pose.bones['Eye_' + side]
            axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, 1))
            bone.rotation_quaternion = Quaternion(axis.normalized(), math.radians(eye_yaw))
        bpy.context.view_layer.update()
    camera_poses = {
        "front": ((0,-1.16,1.43),(0,-.015,1.36),78),
        "three-quarter": ((.52,-1.08,1.45),(0,-.015,1.36),78),
        "full": ((1.2,-3.5,1.78),(0,0,.77),70),
        "side": ((1.12,-.08,1.43),(0,0,1.36),78),
    }
    for name, (pos,target,lens) in camera_poses.items():
        if views is not None and name not in views:
            continue
        hero.camera_at(camera,pos,target,lens)
        scene.render.filepath = str(output / f"{label}-{name}.png")
        bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT/"prototype/assets/characters")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    source = ROOT/"art/hero_quality/hero.blend"
    args.output = args.output.resolve()
    args.evidence = args.evidence.resolve()
    args.output.mkdir(parents=True,exist_ok=True)
    args.evidence.mkdir(parents=True,exist_ok=True)
    source_hash = digest(source)
    with tempfile.TemporaryDirectory(prefix="imperathen-marcus-") as temp:
        scratch = Path(temp)
        bpy.ops.wm.open_mainfile(filepath=str(source))
        arm = bpy.data.objects["HeroRig"]
        if len(arm.data.bones) != 15:
            raise ValueError("Marcus must retain the existing compatible skeleton")
        identity = shape_identity()
        eye_rig = install_eye_rig(arm)
        identity["bones"] = list(arm.data.bones.keys())
        identity["eyes"] = eye_rig
        # Runtime age-offset calibration uses the exported Y-up rest frame.
        (args.output/"marcus_eye_calibration.json").write_text(json.dumps({
            "schema": 1, "mature_rest_offsets": {"Eye_"+side: row["adult_delta"] for side, row in eye_rig.items()}
        }, indent=2)+"\n")
        # Persist the modified source BEFORE activating any review pose.
        # Use the original exporter in a separate scratch directory.
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(scratch/"hero.blend"),compress=True)
        shutil.copyfile(scratch/"hero.blend",args.evidence/"marcus.blend")
        if args.render:
            bpy.ops.wm.open_mainfile(filepath=str(source))
            render(args.evidence,bpy.data.objects["HeroRig"],"anatomical-base")
            bpy.ops.wm.open_mainfile(filepath=str(scratch/"hero.blend"))
            render(args.evidence,bpy.data.objects["HeroRig"],"marcus-youth")
            bpy.ops.wm.open_mainfile(filepath=str(scratch/"hero.blend"))
            render(args.evidence,bpy.data.objects["HeroRig"],"marcus-eye-left",eye_yaw=12.0,views=("front","three-quarter"))
            bpy.ops.wm.open_mainfile(filepath=str(scratch/"hero.blend"))
            render(args.evidence,bpy.data.objects["HeroRig"],"marcus-eye-right",eye_yaw=-12.0,views=("front",))
            bpy.ops.wm.open_mainfile(filepath=str(scratch/"hero.blend"))
            render(args.evidence,bpy.data.objects["HeroRig"],"marcus-adult",mature=1.0)
            bpy.ops.wm.open_mainfile(filepath=str(scratch/"hero.blend"))
            render(args.evidence,bpy.data.objects["HeroRig"],"marcus-walk",action="march",frame=10)
        hero.ART = scratch
        hero.OUT = scratch
        # The connector-specific original hero PNG packaging is inappropriate
        # for an independent character. Build artifacts and APKs can embed
        # the complete new textures without external URI dependencies.
        levels = hero.export_lods(connector_delivery=False)
        for level, row in enumerate(levels):
            src = scratch/f"hero_quality_{level}.glb"
            dest = args.output/f"marcus_quality_{level}.glb"
            shutil.copyfile(src,dest)
            row["path"] = str(dest)
            row["sha256"] = digest(dest)
        if digest(source) != source_hash:
            raise RuntimeError("Original hero source changed")
    report = {"source_sha256": source_hash, "source": "CC0 MakeHuman graphical base; art/hero_quality/source/provenance.json",
              "identity": identity,"blender": bpy.app.version_string,"lods": levels,
              "scope":"Actual Blender export; not an AAA or physical-device acceptance claim"}
    (args.evidence/"marcus-build.json").write_text(json.dumps(report,indent=2)+"\n")
    print("MARCUS_BUILD_COMPLETE",json.dumps({"lods":len(levels),"source_unchanged":True,**identity}),flush=True)


if __name__ == "__main__":
    main()
