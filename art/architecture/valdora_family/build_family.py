"""Build the Valdora house family in Blender and export one GLB per variant.

    blender -b -t 3 --python-exit-code 1 -P art/architecture/valdora_family/build_family.py -- \
        [--variants valdora_t2_render,...] [--render] [--kit-sheet]

Inputs : texture layers in prototype/assets/architecture/valdora/ (family_textures.py)
Outputs: prototype/assets/architecture/valdora/<variant>.glb   (shell, detail, far, fixtures)
         prototype/assets/architecture/valdora/valdora_family.json (budgets, colliders, contract)
         art/architecture/valdora_family/source/valdora_family.blend (editable, textured)
         art/architecture/valdora_family/review/*.png with --render (Cycles, neutral light)

GLBs carry geometry, two UV sets (metric UV, texture layer + random) and the
ageing colour masks; the shared texture arrays stay separate files so all
variants share one set in video memory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
import time
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from family_houses import VARIANTS, BY_ID, House, FLOOR  # noqa: E402
from family_kit import LAYERS  # noqa: E402
from family_forge import Forge, FIXTURES as FORGE_FIXTURES  # noqa: E402

ASSETS = ROOT / "prototype/assets/architecture/valdora"
SOURCE = HERE / "source"
REVIEW = HERE / "review"
BUDGET = {1: 36000, 2: 38000, 3: 50000}       # LOD0 triangles (shell + detail + fixtures)
DETAIL_BUDGET = 6000
FORGE_BUDGET = 24000                          # forge with all stations and stock
FAR_BUDGET = 400


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"


def textured_material():
    mat = bpy.data.materials.get("VH_Family_Render")
    if mat:
        return mat
    mat = bpy.data.materials.new("VH_Family_Render")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    uv = nodes.new("ShaderNodeUVMap"); uv.uv_map = "UVMap"
    layer = nodes.new("ShaderNodeUVMap"); layer.uv_map = "Layer"
    sep = nodes.new("ShaderNodeSeparateXYZ"); links.new(uv.outputs[0], sep.inputs[0])
    lsep = nodes.new("ShaderNodeSeparateXYZ"); links.new(layer.outputs[0], lsep.inputs[0])
    def math_node(op, a=None, b=None, va=None, vb=None):
        n = nodes.new("ShaderNodeMath"); n.operation = op
        if a is not None: links.new(a, n.inputs[0])
        elif va is not None: n.inputs[0].default_value = va
        if b is not None: links.new(b, n.inputs[1])
        elif vb is not None: n.inputs[1].default_value = vb
        return n.outputs[0]
    idx = math_node("ROUND", lsep.outputs[0])
    col = math_node("MODULO", idx, vb=4.0)
    row = math_node("FLOOR", math_node("DIVIDE", idx, vb=4.0))
    fu = math_node("FRACT", sep.outputs[0])
    fv = math_node("FRACT", sep.outputs[1])
    au = math_node("DIVIDE", math_node("ADD", col, fu), vb=4.0)
    av = math_node("DIVIDE", math_node("ADD", math_node("SUBTRACT", None, row, va=3.0), fv), vb=4.0)
    comb = nodes.new("ShaderNodeCombineXYZ"); links.new(au, comb.inputs[0]); links.new(av, comb.inputs[1])
    def image(kind, colour):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(ASSETS / f"family_{kind}_1024.jpg"), check_existing=True)
        node.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        node.interpolation = "Linear"
        links.new(comb.outputs[0], node.inputs[0])
        return node
    alb, nrm, orm = image("albedo", True), image("normal", False), image("orm", False)
    attr = nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
    sepc = nodes.new("ShaderNodeSeparateColor"); links.new(attr.outputs[0], sepc.inputs[0])
    # Ageing: damp darkens, moss greens, soot blackens (same idea as the Godot shader).
    damp = nodes.new("ShaderNodeMix"); damp.data_type = "RGBA"; damp.blend_type = "MULTIPLY"
    links.new(sepc.outputs[0], damp.inputs[0]); links.new(alb.outputs[0], damp.inputs[6])
    damp.inputs[7].default_value = (0.62, 0.58, 0.52, 1)
    moss = nodes.new("ShaderNodeMix"); moss.data_type = "RGBA"
    links.new(sepc.outputs[1], moss.inputs[0]); links.new(damp.outputs[2], moss.inputs[6])
    moss.inputs[7].default_value = (0.20, 0.24, 0.11, 1)
    soot = nodes.new("ShaderNodeMix"); soot.data_type = "RGBA"; soot.blend_type = "MULTIPLY"
    links.new(sepc.outputs[2], soot.inputs[0]); links.new(moss.outputs[2], soot.inputs[6])
    soot.inputs[7].default_value = (0.25, 0.22, 0.20, 1)
    links.new(soot.outputs[2], bsdf.inputs["Base Color"])
    osep = nodes.new("ShaderNodeSeparateColor"); links.new(orm.outputs[0], osep.inputs[0])
    links.new(osep.outputs[1], bsdf.inputs["Roughness"])
    nmap = nodes.new("ShaderNodeNormalMap"); nmap.uv_map = "UVMap"; nmap.inputs["Strength"].default_value = 1.0
    links.new(nrm.outputs[0], nmap.inputs["Color"]); links.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return mat


def export_material():
    mat = bpy.data.materials.get("VH_ValdoraFamily") or bpy.data.materials.new("VH_ValdoraFamily")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.7, 0.66, 0.58, 1)
    return mat


def to_object(mesh_acc, name, collection, material, weighted=True):
    if not mesh_acc.faces:
        return None
    me = bpy.data.meshes.new(name)
    verts = [tuple(v) for v in mesh_acc.verts]
    me.from_pydata(verts, [], mesh_acc.faces)
    me.update()
    uv0 = me.uv_layers.new(name="UVMap")
    uv1 = me.uv_layers.new(name="Layer")
    # from_pydata keeps loop order = vertex order of each face (vertices are unique per face).
    flat_uv0, flat_uv1 = [], []
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            flat_uv0.extend(mesh_acc.uv[vi])
            flat_uv1.extend((float(mesh_acc.layer[vi][0]) + 0.0, mesh_acc.layer[vi][1]))
    uv0.data.foreach_set("uv", flat_uv0)
    uv1.data.foreach_set("uv", flat_uv1)
    col = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    flat_col = []
    for poly in me.polygons:
        for li in poly.loop_indices:
            flat_col.extend(mesh_acc.col[me.loops[li].vertex_index])
    col.data.foreach_set("color", flat_col)
    me.color_attributes.active_color = col
    me.materials.append(material)
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    # Weld coincident corners of each element so chamfers shade as rounded edges.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0002)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(50))
    if weighted:
        mod = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 50
    tri = obj.modifiers.new("Triangulate", "TRIANGULATE")
    tri.keep_custom_normals = True
    # Apply the modifier stack through the depsgraph (no operator context needed).
    graph = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(obj.evaluated_get(graph), preserve_all_data_layers=True, depsgraph=graph)
    obj.modifiers.clear()
    old = obj.data
    obj.data = baked
    baked.name = name
    bpy.data.meshes.remove(old)
    return obj


def triangles(obj):
    if obj is None:
        return 0
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    return lo, hi


def build_variant(variant, render_mat, export_mat, collection):
    started = time.time()
    house = House(variant).build()
    objs = {}
    objs["shell"] = to_object(house.shell, f"{variant.id}_shell", collection, render_mat)
    objs["detail"] = to_object(house.detail, f"{variant.id}_detail", collection, render_mat)
    objs["far"] = to_object(house.far, f"{variant.id}_far", collection, render_mat, weighted=False)
    fixture_names = {"table": "Fixture_Table", "bench": "Fixture_Bench", "jar": "Fixture_Jar"}
    for key, acc in house.fixtures.items():
        objs[key] = to_object(acc, f"{variant.id}_{fixture_names[key]}", collection, render_mat)
    counts = {k: triangles(o) for k, o in objs.items()}
    lod0 = counts["shell"] + counts["detail"] + counts["table"] + counts["bench"] + counts["jar"]
    lo, hi = bounds([o for o in objs.values() if o])
    report = {
        "id": variant.id, "tier": variant.tier, "label": variant.label, "walls": variant.walls, "roof": variant.roof,
        "file": f"{variant.id}.glb", "triangles": counts, "triangles_lod0_total": lod0,
        "budget_lod0": BUDGET[variant.tier], "budget_detail": DETAIL_BUDGET, "budget_far": FAR_BUDGET,
        "within_budget": lod0 <= BUDGET[variant.tier] and counts["detail"] <= DETAIL_BUDGET and counts["far"] <= FAR_BUDGET,
        "bounds_godot_min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        "bounds_godot_max": [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)],
        "colliders": house.colliders, "metadata": house.metadata, "seed": variant.seed,
        "features": {k: getattr(variant, k) for k in ("canopy", "porch", "upper", "paint", "quoins", "grilles", "antefixes")},
        "build_seconds": round(time.time() - started, 1),
    }
    return house, objs, report


def build_forge(render_mat, collection):
    """The smith's lean-to: shell, detail, far proxy and one node per work station."""
    started = time.time()
    forge = Forge().build()
    objs = {"shell": to_object(forge.shell, f"{forge.id}_shell", collection, render_mat),
            "detail": to_object(forge.detail, f"{forge.id}_detail", collection, render_mat),
            "far": to_object(forge.far, f"{forge.id}_far", collection, render_mat, weighted=False)}
    for name in FORGE_FIXTURES:
        objs[name] = to_object(forge.fixtures[name], f"{forge.id}_Fixture_{name}", collection, render_mat)
    counts = {k: triangles(o) for k, o in objs.items()}
    lod0 = sum(v for k, v in counts.items() if k != "far")
    lo, hi = bounds([o for o in objs.values() if o])
    report = {"id": forge.id, "label": "Schmiede des Nerva (Pultdach auf Eichenpfosten)", "file": f"{forge.id}.glb", "triangles": counts,
              "triangles_lod0_total": lod0, "budget_lod0": FORGE_BUDGET, "budget_far": FAR_BUDGET,
              "within_budget": lod0 <= FORGE_BUDGET and counts["far"] <= FAR_BUDGET,
              "bounds_godot_min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], "bounds_godot_max": [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)],
              "fixtures": ["Fixture_" + n for n in FORGE_FIXTURES], "metadata": forge.metadata, "build_seconds": round(time.time() - started, 1)}
    return forge, objs, report


def export_glb(variant, objs, export_mat, render_mat):
    bpy.ops.object.select_all(action="DESELECT")
    names = {"shell": f"{variant.id}_shell", "detail": f"{variant.id}_detail", "far": f"{variant.id}_far",
             "table": "Fixture_Table", "bench": "Fixture_Bench", "jar": "Fixture_Jar"}
    names.update({n: "Fixture_" + n for n in FORGE_FIXTURES})
    for key, obj in objs.items():
        if obj is None:
            continue
        obj.name = names[key]
        obj.data.materials[0] = export_mat
        obj.select_set(True)
    path = ASSETS / f"{variant.id}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_animations=False, export_draco_mesh_compression_enable=False, export_image_format="NONE")
    for key, obj in objs.items():
        if obj is not None:
            obj.data.materials[0] = render_mat
            obj.select_set(False)
            # Free the shared node names (Fixture_*) for the next variant's export.
            obj.name = f"{variant.id}__{key}"
    return path


def render_review(objs_by_variant, out, kit=False):
    """objs_by_variant: name -> list of (shot, eye, target) in world metres."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 3
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("Review sky")
    world.use_nodes = True
    sky = world.node_tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"; sky.sun_elevation = math.radians(38); sky.sun_rotation = math.radians(215); sky.sun_intensity = 0.35
    world.node_tree.links.new(sky.outputs[0], world.node_tree.nodes["Background"].inputs[0])
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN"); sun_data.energy = 3.2; sun_data.angle = math.radians(1.2)
    sun_data.color = (1.0, 0.93, 0.82)
    sun = bpy.data.objects.new("Sun", sun_data); scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52), 0, math.radians(215))
    ground_me = bpy.data.meshes.new("ground"); ground_me.from_pydata([(-80, -80, 0), (80, -80, 0), (80, 80, 0), (-80, 80, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("ground", ground_me); scene.collection.objects.link(g)
    gm = bpy.data.materials.new("ground"); gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.17, 0.12, 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    ground_me.materials.append(gm)
    cam_data = bpy.data.cameras.new("cam"); cam_data.lens = 40
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
    results = []
    for vid, shots in objs_by_variant.items():
        for shot, eye, target in shots:
            cam.location = eye
            cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
            path = out / f"blender_{vid}_{shot}.png"
            scene.render.filepath = str(path)
            started = time.time()
            bpy.ops.render.render(write_still=True)
            results.append({"file": path.name, "variant": vid, "shot": shot, "camera": list(eye), "target": list(target),
                            "source_commit": source_commit(), "lighting": {"sun_rotation_deg": [52, 0, 215], "sun_energy": 3.2, "sun_angle_deg": 1.2,
                            "sky": "Nishita, elevation 38 deg, rotation 215 deg, strength 0.35", "view_transform": "AgX Medium High Contrast"},
                            "lens_mm": 40, "renderer": "Blender %s Cycles CPU" % bpy.app.version_string, "samples": scene.cycles.samples,
                            "denoise": "OpenImageDenoise", "resolution": [scene.render.resolution_x, scene.render.resolution_y],
                            "render_seconds": round(time.time() - started, 1), "game_runtime_capture": False})
            print("VALDORA_BLENDER_RENDER", path.name, results[-1]["render_seconds"])
    return results


def source_commit():
    try:
        sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no"], text=True).strip()
        return sha + ("+worktree" if dirty else "")
    except Exception:  # noqa: BLE001 - provenance only
        return "unknown"


def review_cameras(offset):
    """Two fixed cameras per house: street three-quarter and doorway close-up."""
    return [("front", offset + Vector((7.2, -10.5, 3.4)), offset + Vector((0.2, 0, 1.9))),
            ("close", offset + Vector((-1.4, -6.4, 1.45)), offset + Vector((0.3, -2.4, 1.15)))]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", default="all")
    parser.add_argument("--render", default="", help="comma list of variant ids to render (or all)")
    parser.add_argument("--no-save", action="store_true")
    args = parser.parse_args(argv)
    chosen = VARIANTS if args.variants == "all" else [BY_ID[v] for v in args.variants.split(",") if v in BY_ID]
    reset()
    ASSETS.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    render_mat = textured_material()
    export_mat = export_material()
    manifest_path = ASSETS / "valdora_family.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest.setdefault("variants", {})
    manifest.update({
        "schema": 1,
        "family": "valdora_house_family",
        "period": "58 BC, late Republic, countryside of Aquileia (Gallia Cisalpina)",
        "units": "metres; Godot house-local axes (+Y up, street/door side +Z); collider boxes are centre/size/yaw",
        "texture_layers": LAYERS,
        "textures": {"very_high": ["family_albedo_1024.jpg", "family_normal_1024.jpg", "family_orm_1024.jpg"],
                     "balanced_high": ["family_albedo_512.jpg", "family_normal_512.jpg", "family_orm_512.jpg"],
                     "low": ["family_albedo_256.jpg", "family_orm_256.jpg"]},
        "mesh_roles": {"shell": "walls, roof, frames, doors (all profiles)", "detail": "fittings, nails, grilles, antefixes, pebbles (range per profile)",
                       "far": "silhouette beyond the far range", "Fixture_*": "interior contract furniture, separate nodes"},
        "budgets_triangles_lod0": {"tier_1": BUDGET[1], "tier_2": BUDGET[2], "tier_3": BUDGET[3], "detail": DETAIL_BUDGET, "far": FAR_BUDGET},
        "floor_abs": FLOOR,
        # Same keys as household_designs.contract() (interiors branch): every
        # variant keeps this ground-floor room, door and window set.
        "interior_contract": {
            "applies_to": "all variants (ground-floor room)", "floor_abs": FLOOR,
            "plaster_faces": {"W": -2.68, "E": 2.68, "N": -2.17, "S": 2.17}, "standing_limits": {"x": 2.635, "z": 2.125},
            "wall_plate_height": 2.8675, "ceiling_clear_min": 2.80,
            "door": {"wall": "S", "centre_x": 0.0, "clear_width": 1.12, "clear_height": 2.08,
                     "open_leaf": {"hinge": [-0.575, 2.15], "open_degrees": 100, "length": 1.12, "thickness": 0.064}},
            "windows": [{"wall": "S", "x": [-2.32, -1.28], "sill": 1.1275, "head": 2.0875}, {"wall": "S", "x": [1.28, 2.32], "sill": 1.1275, "head": 2.0875},
                        {"wall": "E", "z": [-0.52, 0.52], "sill": 1.1275, "head": 2.0875}, {"wall": "N", "x": [-0.48, 0.48], "sill": 1.3075, "head": 2.1075}],
            "fixtures": {"Fixture_Table": {"x": [-1.825, -0.375], "z": [-1.1525, -0.0675], "top": 0.85},
                         "Fixture_Bench": {"x": [1.68, 2.18], "z": [-0.95, 0.95], "top": 0.50},
                         "Fixture_Jar": {"centre": [-2.23, 1.47], "radius": 0.27, "height": 0.62}},
            "hearth_zone": {"centre": [1.62, 1.50], "smoke_vent": "roof hood above the hearth zone (detail mesh)"},
            "tier_extras": {"valdora_t3_upper": "upper floor (loft) above joists at 2.82 m clear; no inner stair yet",
                            "valdora_t3_portico": "covered porch 4.84 x 1.05 m at 0.445 m in front of the door"},
        },
        "generator": "art/architecture/valdora_family/build_family.py",
        "blender": bpy.app.version_string,
    })
    collection = bpy.context.scene.collection
    review_shots = {}
    spacing = 14.0
    for index, variant in enumerate(chosen):
        house, objs, report = build_variant(variant, render_mat, export_mat, collection)
        path = export_glb(variant, objs, export_mat, render_mat)
        report["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        report["bytes"] = path.stat().st_size
        manifest["variants"][variant.id] = report
        print("VALDORA_VARIANT", json.dumps({k: report[k] for k in ("id", "triangles", "triangles_lod0_total", "within_budget", "bytes", "build_seconds")}))
        offset = Vector((index * spacing, 0, 0))
        for obj in objs.values():
            if obj is not None:
                obj.location = offset
                if obj.name.endswith("__far"):
                    obj.hide_render = True
                    obj.hide_viewport = True
        review_shots[variant.id] = review_cameras(offset)
    if args.variants == "all" or "valdora_forge" in args.variants.split(","):
        forge, objs, report = build_forge(render_mat, collection)
        path = export_glb(forge, objs, export_mat, render_mat)
        report["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        report["bytes"] = path.stat().st_size
        manifest.setdefault("structures", {})[forge.id] = report
        print("VALDORA_VARIANT", json.dumps({k: report[k] for k in ("id", "triangles", "triangles_lod0_total", "within_budget", "bytes", "build_seconds")}))
        offset = Vector((len(chosen) * spacing + 14.0, 0, 0))
        for obj in objs.values():
            if obj is not None:
                obj.location = offset
                if obj.name.endswith("__far"):
                    obj.hide_render = True
                    obj.hide_viewport = True
        review_shots[forge.id] = [("front", offset + Vector((-7.4, -5.2, 2.7)), offset + Vector((0.3, 0, 1.25))),
                                  ("close", offset + Vector((-3.6, 4.6, 1.6)), offset + Vector((0.2, 1.6, 0.9)))]
    if args.render:
        # The previous shared house (frontier_house.glb, used by all 20 homes
        # before this family) from the identical relative cameras.
        before = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=str(ROOT / "prototype/assets/architecture/frontier_house.glb"))
        offset = Vector((len(chosen) * spacing, 0, 0))
        for name in set(bpy.data.objects.keys()) - before:
            obj = bpy.data.objects[name]
            if obj.parent is None:
                obj.location = offset
        review_shots["frontier_house_before"] = review_cameras(offset)
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    if not args.no_save:
        # Texture layers stay referenced (relative) in prototype/assets; not packed twice.
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "valdora_family.blend"), compress=True, relative_remap=True)
    if args.render:
        wanted = set(review_shots) if args.render == "all" else set(args.render.split(",")) | {"frontier_house_before"}
        manifest["blender_reviews"] = manifest.get("blender_reviews", [])
        done = render_review({k: v for k, v in review_shots.items() if k in wanted}, REVIEW)
        manifest["blender_reviews"] = [r for r in manifest["blender_reviews"] if r["file"] not in {d["file"] for d in done}] + done
        manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print("VALDORA_FAMILY_BUILD_COMPLETE", len(chosen))


if __name__ == "__main__":
    main()
