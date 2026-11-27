"""Build the living frontier cast from the already vendored anatomical hero.

No network requests, paid generation, or external assets are used. Adult faces,
eyes and skin inherit the source/provenance.json CC0 graphical-data provenance;
costumes, equipment, rig fitting and the civilian silhouettes are project work.

blender -b -t 4 -P tools/characters/build_frontier_people.py -- --export
blender -b -t 4 -P tools/characters/build_frontier_people.py -- --review-only
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/frontier_people"
OUT = ROOT / "prototype/assets/characters"
HERO = ROOT / "art/hero_quality/hero.blend"
TYPES = ("civilian_man", "civilian_woman", "elder", "legionary", "officer", "spearman", "archer")
SOLDIERS = {"legionary": "heavy", "officer": "officer", "spearman": "spear", "archer": "archer"}
LOD = ((0, .62, 1024), (1, .24, 512), (2, .075, 256), (3, .025, 128))


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


hero = module("frontier_hero_source", ROOT / "tools/characters/build_hero.py")
soldier = module("frontier_soldier_source", ROOT / "art/soldiers/build.py")
skirt_seam = module("frontier_skirt_seam", ROOT / "tools/characters/smooth_frontier_skirt_seam.py")
identity_shapes = module("frontier_identity_shapes", ROOT / "tools/characters/sculpt_roman_faces.py")
adult_rig = module("frontier_adult_rig", ROOT / "tools/characters/extend_adult_rig.py")
kit_rivets = module("frontier_kit_rivets", ROOT / "tools/characters/rebind_frontier_kit_rivets.py")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def reset_to_source(hero_source=HERO):
    bpy.ops.wm.open_mainfile(filepath=str(hero_source))
    for obj in list(bpy.context.scene.objects):
        if obj.type not in ("MESH", "ARMATURE") or obj.name == "PracticeBlade":
            bpy.data.objects.remove(obj, do_unlink=True)
    arm = bpy.data.objects["HeroRig"]
    arm.animation_data_clear()
    for bone in arm.pose.bones:
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
    bpy.context.scene.frame_set(0)
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or not obj.data.shape_keys:
            continue
        keys = obj.data.shape_keys.key_blocks
        mature = keys.get("Mature")
        if mature:
            basis = keys[0]
            deltas = [mature.data[i].co - basis.data[i].co for i in range(len(obj.data.vertices))]
            for key in keys:
                key.value = 0
                for i, v in enumerate(key.data):
                    v.co += deltas[i]
            for i, v in enumerate(obj.data.vertices):
                v.co = basis.data[i].co
            obj.shape_key_remove(mature)
        companion = obj.data.shape_keys.key_blocks.get("Companion") if obj.data.shape_keys else None
        if companion:
            obj.shape_key_remove(companion)
    return arm


def material_nodes(name):
    mat = bpy.data.materials.get(name)
    if not mat:
        raise RuntimeError("Missing source material " + name)
    return mat, mat.node_tree.nodes, mat.node_tree.links


def image_from_array(name, values):
    size_y, size_x, _ = values.shape
    image = bpy.data.images.new(name, width=size_x, height=size_y)
    image.pixels.foreach_set(values.astype(np.float32).ravel())
    image.pack()
    return image


def neutral_eyes():
    """Original eye atlas matched to the existing two-eye UV layout."""
    # The source includes a transparent corneal shell in the lower-right atlas
    # island. Remove that shell, keeping the underlying iris surface, so mobile
    # eyes need no transparent pass and cannot turn white with opaque shading.
    eyes = bpy.data.objects["HeroEyes"]
    eyes.shape_key_clear()
    bm = bmesh.new()
    bm.from_mesh(eyes.data)
    uv = bm.loops.layers.uv.active
    shell = [face for face in bm.faces if all(loop[uv].uv.x > .85 and loop[uv].uv.y < .15 for loop in face.loops)]
    bmesh.ops.delete(bm, geom=shell, context="FACES")
    bm.to_mesh(eyes.data)
    bm.free()
    n = 512
    yy, xx = np.mgrid[0:n, 0:n] / (n - 1)
    pixels = np.ones((n, n, 4))
    pixels[:, :, :3] = (.82, .835, .81)
    for cx, cy in ((.291, .291), (.709, .709)):
        r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        a = np.arctan2(yy - cy, xx - cx)
        iris = r < .116
        pupil = r < .037
        fibres = .5 + .5 * np.sin(a * 103 + np.sin(a * 19) * 3 + r * 180)
        band = np.clip((.116 - r) / .012, 0, 1) * np.clip((r - .037) / .014, 0, 1)
        for c, base in enumerate((.19, .145, .085)):
            colour = .028 + band * (base + .09 * fibres)
            pixels[:, :, c] = np.where(iris, colour, pixels[:, :, c])
            pixels[:, :, c] = np.where(pupil, .009, pixels[:, :, c])
    image = image_from_array("FrontierEye_hazel", pixels)
    mat, nodes, links = material_nodes("HeroEye")
    for node in nodes:
        if node.type == "TEX_IMAGE":
            node.image = image
    shader = nodes.get("Principled BSDF")
    for link in list(links):
        if link.to_socket == shader.inputs["Alpha"]:
            links.remove(link)
    shader.inputs["Alpha"].default_value = 1
    shader.inputs["Roughness"].default_value = .31
    mat.name = "FrontierEye"


def colour_cloth(kind):
    colours = {
        "civilian_man": (.52, .35, .20), "civilian_woman": (.20, .29, .34),
        "elder": (.42, .39, .30), "legionary": (.35, .055, .035),
        "officer": (.48, .16, .08), "spearman": (.20, .29, .24), "archer": (.26, .31, .18),
    }
    mat, nodes, links = material_nodes("HeroLinen")
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    wave = .035 * np.sin(xx * 1.8) + .035 * np.sin(yy * 2.1)
    weave = wave + .025 * np.sin(xx * .08 + np.sin(yy * .03))
    pixels = np.ones((n, n, 4))
    pixels[:, :, :3] = np.asarray(colours[kind])[None, None, :] * (1 + weave[:, :, None])
    image = image_from_array("FrontierLinen_" + kind, pixels)
    shader = nodes.get("Principled BSDF")
    for link in links:
        if link.to_socket == shader.inputs["Base Color"] and link.from_node.type == "TEX_IMAGE":
            link.from_node.image = image
    mat.name = "FrontierCloth"
    skin, nodes, links = material_nodes("HeroSkin")
    if kind != "civilian_woman":
        source = ROOT / "art/hero_quality/source/system_assets/skins/young_caucasian_male/young_lightskinned_male_diffuse.png"
        image = bpy.data.images.load(str(source), check_existing=True)
        image.pack()
        shader = nodes.get("Principled BSDF")
        for link in links:
            if link.to_socket == shader.inputs["Base Color"] and link.from_node.type == "TEX_IMAGE":
                link.from_node.image = image
    skin.name = "FrontierSkin"


def apply_position_function(obj, function):
    if obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:
            for vertex in key.data:
                vertex.co = function(vertex.co.copy())
        for i, vertex in enumerate(obj.data.vertices):
            vertex.co = obj.data.shape_keys.key_blocks[0].data[i].co
    else:
        for vertex in obj.data.vertices:
            vertex.co = function(vertex.co.copy())


def civilian_identity(kind, arm, authored_adult=False):
    # Different silhouettes are actual geometry. Runtime colour variations add
    # individual identity without duplicating another complete set of textures.
    body = bpy.data.objects["HeroBody"]
    def face(p):
        if p.z > 1.27:
            jaw = math.exp(-((p.z - 1.32) / .050) ** 2)
            if kind == "civilian_woman":
                p.x *= 1 - .13 * jaw
                p.y += .008 * jaw
                p.z += .005 * jaw
            elif kind == "elder":
                p.x *= 1 + .075 * jaw
                p.z -= .0045 * math.exp(-((p.z - 1.34) / .035) ** 2)
                p.y -= .005 * math.exp(-((p.z - 1.315) / .027) ** 2)
            else:
                p.x *= 1.025
        return p
    if not authored_adult:
        for obj in (body, bpy.data.objects["HeroEyes"]):
            apply_position_function(obj, face)
    if kind == "civilian_woman":
        def silhouette(p):
            torso = max(0., min(1., (p.z - .78) / .16)) * max(0., min(1., (1.30 - p.z) / .09))
            p.x *= 1 - .13 * torso
            p.y = -.025 + (p.y + .025) * (1 - .065 * torso)
            return p
        if not authored_adult:
            for obj in list(bpy.context.scene.objects):
                if obj.type == "MESH":
                    apply_position_function(obj, silhouette)
            bpy.context.view_layer.objects.active = arm
            bpy.ops.object.mode_set(mode="EDIT")
            for bone in arm.data.edit_bones:
                bone.head = silhouette(bone.head.copy())
                bone.tail = silhouette(bone.tail.copy())
            bpy.ops.object.mode_set(mode="OBJECT")
        hair = bpy.data.objects["HeroHair"]
        def sweep(p):
            back = max(0.0, min(1.0, (p.y + .06) / .10))
            p.y += .025 * back
            return p
        apply_position_function(hair, sweep)
        hairmat = bpy.data.materials["HeroHair"]
        # A separate bound bun makes the female silhouette legible from behind.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, location=(0, .072, 1.405))
        bun = bpy.context.object
        bun.name = "FrontierHairBun"
        bun.scale = (.058, .045, .055)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
        bun.data.materials.append(hairmat)
        hero.bind(bun, arm, [{"Head": 1.0} for _ in bun.data.vertices])
        for side in (-1, 1):
            hero.tube("FrontierBoundLocks", [(side*.059,-.048,1.443),(side*.071,-.018,1.404),(side*.061,.029,1.37),(side*.035,.068,1.40)],
                      [.014,.016,.015,.012], hairmat, arm, "Head", 12)
        # Long practical dress, with a wider hem and sewn pleats.
        skirt = bpy.data.objects["HeroTunicSkirt"]
        def dress(p):
            t = max(0.0, min(1.0, (.90 - p.z) / .36))
            p.z -= .43 * t
            p.x *= 1 + .12 * t
            p.y = -.025 + (p.y + .025) * (1 + .08 * t)
            p.x += .003 * math.sin(math.atan2(p.y + .025, p.x) * 20) * t
            return p
        apply_position_function(skirt, dress)
        for group in list(skirt.vertex_groups):
            skirt.vertex_groups.remove(group)
        for v in skirt.data.vertices:
            # Upper skirt follows the pelvis; the lower dress blends both thighs
            # to avoid opening a hole between two independently moving halves.
            fraction = max(0.0, min(.50, (.73 - v.co.z) / 1.2))
            weights = {"Pelvis": 1 - fraction, "Thigh_L": fraction * .5, "Thigh_R": fraction * .5}
            for name, weight in weights.items():
                group = skirt.vertex_groups.get(name) or skirt.vertex_groups.new(name=name)
                group.add([v.index], weight, "REPLACE")
    if kind == "elder":
        hair = bpy.data.objects["HeroHair"]
        material = bpy.data.materials["HeroHair"].copy()
        material.name = "FrontierGreyHair"
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = .82
        for link in material.node_tree.links:
            if link.to_socket == shader.inputs["Base Color"]:
                original = link.from_node.image
                pixels = np.asarray(original.pixels[:]).reshape(original.size[1], original.size[0], 4).copy()
                grey = pixels[:, :, :3].mean(axis=2)
                pixels[:, :, :3] = (.11 + .62 * grey)[:, :, None]
                link.from_node.image = image_from_array("FrontierGreyHair_albedo", pixels)
        hair.data.materials.clear()
        hair.data.materials.append(material)
        # Authored beard follows the face contour instead of a box under the head.
        beard_material = hero.texture_material("FrontierGreyBeard", (.26, .255, .24, 1), roughness=.92)
        cheek = [v.co.copy() for v in body.data.vertices if 1.265 < v.co.z < 1.35 and v.co.y < -.07 and abs(v.co.x) < .075]
        cheek_tree = KDTree(len(cheek))
        for i, p in enumerate(cheek):
            cheek_tree.insert(Vector((p.x, 0, p.z)), i)
        cheek_tree.balance()
        vertices, faces = [], []
        for row in range(6):
            z = 1.277 + row * .004
            width = .015 + .022 * row / 5
            for col in range(17):
                x = width * (col / 8 - 1)
                near = cheek_tree.find_n(Vector((x, 0, z)), 3)
                y = min(cheek[i].y for _, i, _ in near) - .0018
                vertices.append((x, y, z))
        for row in range(5):
            for col in range(16):
                a = row * 17 + col
                faces.append((a, a + 1, a + 18, a + 17))
        beard = hero.mesh_object("FrontierBeard", vertices, faces, material=beard_material)
        hero.bind(beard, arm, [{"Head": 1.0} for _ in vertices])
    hero.animate(arm)


def fit_to_company(source_arm, target_arm):
    transforms = {}
    for name in source_arm.data.bones.keys():
        src, dst = source_arm.data.bones[name], target_arm.data.bones[name]
        if name == "Head":
            transform = Matrix.Translation(dst.head_local) @ Matrix.Scale(1.18, 4) @ Matrix.Translation(-src.head_local)
        else:
            rotation = (src.tail_local - src.head_local).rotation_difference(dst.tail_local - dst.head_local).to_matrix().to_4x4()
            factor = dst.length / src.length
            transform = Matrix.Translation(dst.head_local) @ rotation @ Matrix.Scale(factor, 4) @ Matrix.Translation(-src.head_local)
        transforms[name] = transform
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        weights = []
        for vertex in obj.data.vertices:
            row = [(obj.vertex_groups[g.group].name, g.weight) for g in vertex.groups if obj.vertex_groups[g.group].name in transforms]
            total = sum(w for _, w in row)
            weights.append([(n, w / total) for n, w in row] if total else [("Spine", 1.0)])
        blocks = list(obj.data.shape_keys.key_blocks) if obj.data.shape_keys else []
        if blocks:
            for block in blocks:
                for i, vertex in enumerate(block.data):
                    vertex.co = sum(((transforms[n] @ vertex.co) * w for n, w in weights[i]), Vector())
            for i, vertex in enumerate(obj.data.vertices):
                vertex.co = blocks[0].data[i].co
        else:
            for i, vertex in enumerate(obj.data.vertices):
                vertex.co = sum(((transforms[n] @ vertex.co) * w for n, w in weights[i]), Vector())
        obj.parent = target_arm
        obj.matrix_parent_inverse = Matrix.Identity(4)
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = target_arm
    bpy.data.objects.remove(source_arm, do_unlink=True)


def kit_atlas():
    material = soldier.atlas_material()
    # Rebuild the small project atlas at 512px with finer authored surface grain.
    size, cell = 512, 128
    yy, xx = np.mgrid[0:size, 0:size]
    pixels = np.ones((size, size, 4))
    names = list(soldier.PALETTE)
    for i, name in enumerate(names):
        area = (xx // cell + 4 * (yy // cell)) == i
        colour = np.array([int(soldier.PALETTE[name][j:j + 2], 16) / 255 for j in (0, 2, 4)])
        grain = .016 * np.sin(xx * 1.83 + yy * .17) + .012 * np.sin(xx * .14 - yy * 2.11)
        if name in ("iron", "steel", "bronze", "trim"):
            grain += .025 * np.cos(xx * .067 + np.sin(yy * .073))
            grain += .012 * (np.mod(xx * 7 + yy * 31, 97) == 0)
        elif name in ("linen", "oxblood", "pine", "plume"):
            grain += .022 * np.sin(xx * math.pi / 2) + .018 * np.sin(yy * math.pi / 3)
        for c in range(3):
            pixels[:, :, c][area] = np.clip(colour[c] + grain[area], .01, .99)
    image = image_from_array("FrontierKit_pigments512", pixels)
    shader = material.node_tree.nodes.get("Principled BSDF")
    for link in material.node_tree.links:
        if link.to_socket == shader.inputs["Base Color"]:
            link.from_node.image = image
    material.name = "FrontierKit"
    return material


def soldier_identity(kind, source_arm):
    role = SOLDIERS[kind]
    # Retain the tested company skeleton exactly: gait, shielding and melee
    # contacts continue to use the existing, measured animation geometry.
    target_arm = soldier.skeleton(role)
    fit_to_company(source_arm, target_arm)
    # The company rig is taller and has a shorter trunk than the source hero.
    # Fit its cloth to the cuirass, rather than scaling the tunic past the metal.
    for name in ("HeroTunic", "HeroBelt", "HeroTunicSkirt"):
        obj = bpy.data.objects[name]
        def fit_cloth(p):
            if name == "HeroTunic":
                centre = max(0., min(1., (.285 - abs(p.x)) / .09))
                centre *= max(0., min(1., (1.46 - p.z) / .05))
                p.x *= 1 - .20 * centre
                p.y += ((p.y + .045) * .61 - p.y) * centre
            else:
                hem = max(0., min(1., (.86 - p.z) / .25)) if name == "HeroTunicSkirt" else 0.
                p.x *= .78 + .20 * hem
                p.y = (p.y + .045 - .035 * hem) * (.61 + .39 * hem)
            return p
        apply_position_function(obj, fit_cloth)
    if bpy.data.objects.get("HeroHair"):
        bpy.data.objects.remove(bpy.data.objects["HeroHair"], do_unlink=True)
    kit = soldier.Geometry(0)
    soldier.uniform(kit, role)
    soldier.equipment(kit, role)
    # The anatomical skull sits forward of the old stylised head centre.
    # Fit the shell and crest to it; otherwise the forehead clips through the
    # front of the helmet/cap, most visibly during the archer's aiming pose.
    fitted_head_parts = set(kit.modules.get("Helmet", [])) | set(kit.modules.get("Cap", []))
    fitted_head_parts.update(i for i in kit.modules.get("Command", []) if kit.weights[i] == "Head")
    for i in fitted_head_parts:
        x, y, z = kit.verts[i]
        kit.verts[i] = (x, y - .035, z)
    # Visible rivets, central straps and collar edging enrich the same source kit.
    kit.module = "Rivets"
    for side in (-1, 1):
        for z in (1.09, 1.145, 1.195, 1.245, 1.30):
            kit.rod([(side * .09, -.146, z), (side * .09, -.154, z)], [.006, .006], "bronze", "Spine", 8)
        for z in (1.32, 1.36, 1.40):
            kit.rod([(side * .185, -.10, z), (side * .185, -.108, z)], [.005, .005], "steel", "Spine", 8)
    kit.object("FrontierRomanKit", kit_atlas(), target_arm)
    soldier.LENGTHS = {"idle": 2, "march": 1, "run": .72, "attack": .8, "shoot": 1.28,
                       "block": 1.2, "wall": 1.2, "testudo": 1.3, "hit": .48,
                       "retreat": .88, "death": 1.2}
    soldier.animate(target_arm, role)
    return target_arm


def make_source(kind, hero_source=HERO, authored_adult=False):
    arm = reset_to_source(hero_source)
    neutral_eyes()
    colour_cloth(kind)
    if kind in SOLDIERS:
        arm = soldier_identity(kind, arm)
    else:
        civilian_identity(kind, arm, authored_adult)
    hero.fit_belt_clearance(bpy.data.objects["HeroBelt"],
                            [bpy.data.objects["HeroTunic"], bpy.data.objects["HeroTunicSkirt"]])
    arm.name = "FrontierRig"
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.data.update()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / (kind + ".blend")), compress=True)


def simplify(obj, ratio, morphs):
    if obj.name == "HeroBelt":
        # Its 96 triangles keep the closed fitted waist visible. A global LOD
        # ratio turns the ring into long chords that disappear into the tunic.
        if not morphs and obj.data.shape_keys:
            obj.shape_key_clear()
        return
    if ratio >= 1 or len(obj.data.vertices) < 24:
        return
    deltas = {}
    tree = KDTree(len(obj.data.vertices))
    source = [v.co.copy() for v in obj.data.vertices]
    for i, point in enumerate(source):
        tree.insert(point, i)
    tree.balance()
    if obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:
            if key.name != "Basis" and morphs:
                deltas[key.name] = [v.co - source[i] for i, v in enumerate(key.data)]
        obj.shape_key_clear()
    bpy.context.view_layer.objects.active = obj
    decimator = obj.modifiers.new("Frontier mobile detail", "DECIMATE")
    decimator.ratio = ratio
    bpy.ops.object.modifier_move_to_index(modifier=decimator.name, index=0)
    bpy.ops.object.modifier_apply(modifier=decimator.name)
    # Decimating disconnected, capped kit pieces can leave zero-area loops.
    # Repair these before reconstructing morph deltas and exporting glTF.
    obj.data.validate(verbose=False, clean_customdata=False)
    obj.data.update()
    if deltas:
        obj.shape_key_add(name="Basis")
        for name, values in deltas.items():
            shape = obj.shape_key_add(name=name)
            for v in obj.data.vertices:
                near = tree.find_n(v.co, 3)
                total = sum(1 / max(.00001, distance) for _, _, distance in near)
                delta = sum((values[i] / max(.00001, distance) for _, i, distance in near), Vector()) / total
                shape.data[v.index].co = v.co + delta


def export(kind):
    records = []
    for level, ratio, edge in LOD:
        bpy.ops.wm.open_mainfile(filepath=str(ART / (kind + ".blend")))
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                simplify(obj, ratio, level < 2)
            obj.select_set(obj.type in ("MESH", "ARMATURE"))
        belt_fit = hero.fit_belt_clearance(bpy.data.objects["HeroBelt"],
                                           [bpy.data.objects["HeroTunic"], bpy.data.objects["HeroTunicSkirt"]])
        for image in bpy.data.images:
            if max(image.size) > edge:
                factor = edge / max(image.size)
                image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
                image.pack()
        path = OUT / ("frontier_%s_%d.glb" % (kind, level))
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
            export_animation_mode="NLA_TRACKS", export_force_sampling=True,
            export_frame_step=1, export_animations=True, export_morph=True,
            export_morph_animation=False, export_def_bones=False)
        death_ground = soldier.death_ground.ground(path)
        gather_ground = soldier.death_ground.ground(path, None, "gather")
        seam = skirt_seam.smooth(path)
        # Civilian tunics whose local smoothing would expose the body stay as exported.
        tunic = skirt_seam.smooth(path, cloth="HeroTunic", strict=False)
        rivets = kit_rivets.rebind(path)
        if level < 2:
            identity_shapes.bake(path)
        count = 0
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                obj.data.calc_loop_triangles()
                count += len(obj.data.loop_triangles)
        records.append({"lod": level, "path": str(path.relative_to(ROOT)), "triangles": count,
                        "bytes": path.stat().st_size, "sha256": digest(path), "texture_edge": edge,
                        "face_morphs": level < 2, **({"identity_shapes": True} if level < 2 else {}), "belt_fit": belt_fit,
                        "death_ground_contact": {key: death_ground[key] for key in ("before", "after", "maximum_floor_correction_m")},
                        "skirt_seam": {key: seam[key] for key in ("before", "after", "unchanged") if key in seam},
                        "tunic_seam": {key: tunic[key] for key in ("before", "after", "unchanged") if key in tunic},
                        "gather_ground_contact": {key: gather_ground[key] for key in ("before", "after", "unchanged") if key in gather_ground},
                        "kit_rivets": {"rebound": sum(entry["applied"] for entry in rivets.get("islands", [])),
                                       "snapped": len(rivets.get("snapped", [])), **({"unchanged": rivets["unchanged"]} if "unchanged" in rivets else {})}})
    return records


def review(kind):
    bpy.ops.wm.open_mainfile(filepath=str(ART / (kind + ".blend")))
    camera = hero.setup_scene()
    scene = bpy.context.scene
    scene.cycles.samples = 12
    scene.render.resolution_x = 840
    scene.render.resolution_y = 1000
    tall = kind in SOLDIERS
    hero.camera_at(camera, (1.0, -3.8, 1.9), (0, 0, .97 if tall else .81), 76)
    scene.render.film_transparent = False
    scene.render.filepath = str(ART / "review" / (kind + "_full.png"))
    bpy.ops.render.render(write_still=True)
    hero.camera_at(camera, (.45, -1.17, 1.72 if tall else 1.48), (0, -.03, 1.59 if tall else 1.37), 73)
    scene.render.resolution_y = 840
    scene.render.filepath = str(ART / "review" / (kind + "_face.png"))
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", action="store_true")
    parser.add_argument("--review-only", action="store_true")
    parser.add_argument("--types", nargs="+", choices=TYPES, default=list(TYPES))
    parser.add_argument("--hero-source", type=Path, help="Explicit anatomy candidate source")
    parser.add_argument("--authored-adult", action="store_true", help="Avoid applying legacy male-to-female deformation twice")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if args.hero_source or args.authored_adult:
        if not args.hero_source or not args.authored_adult or args.export or args.review_only or len(args.types) != 1 or args.types[0] not in ("civilian_woman","civilian_man"):
            parser.error("Adult anatomy source is a one-kind disposable source build, not a release export")
        if not args.hero_source.is_file() or args.hero_source.resolve() == HERO.resolve():
            parser.error("A separate generated candidate .blend is required")
        if __import__("os").environ.get("IMPERATHEN_DISPOSABLE_PARENT_BUILD") != "1":
            parser.error("Use a disposable candidate checkout; original frontier source will be replaced there")
        receipt = json.loads((args.hero_source.parent / "anatomy.json").read_text(encoding="utf-8"))
        expected = "julia" if args.types[0] == "civilian_woman" else "silvanus"
        if receipt.get("candidate") != expected or receipt.get("blend_sha256") != digest(args.hero_source):
            parser.error("Candidate identity or source checksum mismatch")
    for path in (ART, OUT, ART / "review"):
        path.mkdir(parents=True, exist_ok=True)
    records = []
    for kind in args.types:
        if not args.review_only:
            make_source(kind, args.hero_source or HERO, args.authored_adult)
            if args.export:
                records.append({"identity": kind, "lods": export(kind)})
        else:
            review(kind)
    if records:
        report_path = ART / "build_report.json"
        previous = json.loads(report_path.read_text()).get("identities", []) if report_path.exists() else []
        combined = [r for r in previous if r["identity"] not in args.types] + records
        report = {"generator": str(Path(__file__).relative_to(ROOT)), "blender": bpy.app.version_string,
                  "source_hero_sha256": digest(HERO), "source_equipment_sha256": digest(ROOT / "art/soldiers/build.py"),
                  "source_provenance": "art/hero_quality/source/provenance.json", "identities": combined,
                  "limits": ["No physical Android performance claim.", "Female and elder faces are authored variants of the existing anatomical source, not new scans.",
                             "Distant levels omit facial morphs.", "Armour retains the project's stylised Roman equipment study; no archaeological reconstruction claim."]}
        report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("FRONTIER_PEOPLE_COMPLETE", ",".join(args.types))


if __name__ == "__main__":
    main()
