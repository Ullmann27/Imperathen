"""Original procedural Gladius + Scutum asset generator for IMPERATHEN.

Blender 4.x: blender -b --python tools/build_roman_weapons.py -- --output /absolute/output
Creates separate source .blend and review .glb files; metres, Z-up in Blender.
Godot glTF importer converts coordinate convention. No external assets.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent / "art"))
from common import material as textured_material, _project_uv


def mat(name, rgb, metallic=0.0, roughness=0.65, texture=None):
    if texture:
        return textured_material(name, (*rgb, 1), metallic=metallic,
                                 roughness=roughness, texture=texture)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    return m


def cube(name, dims, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Soft machined edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def cylinder(name, radius, depth, loc, material, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def mesh(name, vertices, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1


def socket(name, location, hand):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = .08
    obj["attachment_role"] = hand
    obj["purpose"] = "Local attachment marker; runtime bone binding is separate."
    return obj


def tube(name, points, radius, material):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    curve.use_fill_caps = True
    poly = curve.splines.new("POLY")
    poly.points.add(len(points) - 1)
    for point, co in zip(poly.points, points):
        point.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return obj


def finish_geometry():
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        # Curve conversion duplicates coincident end-cap seam vertices.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        _project_uv(obj, overwrite=True)
    # One mesh with material surfaces keeps each rivet from adding a draw item.
    # The empty socket remains a separate, mesh-free transform node.
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    bpy.context.object.name = "WeaponGeometry"


def make_gladius():
    steel = mat("Forged steel", (0.39, 0.43, 0.44), .84, .27)
    dark = mat("Oiled walnut", (.17, .085, .035), 0, .65, "oak")
    brass = mat("Aged bronze", (.43, .28, .095), .7, .35, "bronze")
    # Local origin at grip centre, longitudinal axis +Z, tip +Z.
    cylinder("Grip walnut", .023, .12, (0, 0, 0), dark)
    cube("Lower pommel", (.078, .065, .035), (0, 0, -.077), brass, .012)
    cube("Guard", (.115, .052, .031), (0, 0, .079), brass, .008)
    # Double-sided lenticular blade with a distinct point, no nonmanifold gaps.
    z0, z1, z2 = .098, .58, .70
    verts = [
        (-.041, 0, z0), (.041, 0, z0), (-.039, 0, z1), (.039, 0, z1),
        (0, .009, z0), (0, -.009, z0), (0, .009, z1), (0, -.009, z1),
        (0, 0, z2)
    ]
    faces = [
        (0, 4, 6, 2), (4, 1, 3, 6), (1, 5, 7, 3), (5, 0, 2, 7),
        (2, 6, 8), (6, 3, 8), (3, 7, 8), (7, 2, 8),
        (0, 5, 1, 4)
    ]
    mesh("Steel blade", verts, faces, steel)
    for z in (-.04, -.02, 0, .02, .04):
        bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6,
                                      location=(0, 0, z), major_radius=.023,
                                      minor_radius=.0018)
        bpy.context.object.name = "Grip incised band"
        bpy.context.object.data.materials.append(brass)
    socket("SOCKET_RIGHT_HAND", (0, 0, 0), "right_hand")


def make_scutum():
    wood = mat("Painted red shield", (.23, .027, .016), 0, .67, "linen")
    rim = mat("Iron edge", (.17, .17, .16), .73, .4)
    boss = mat("Bronze boss", (.49, .30, .10), .73, .32, "bronze")
    back = mat("Shield leather backing", (.23, .14, .075), 0, .83, "leather")
    # Front faces -Y. Shield curved across X; origin at rear grip.
    cols, rows = 24, 24
    verts = []
    def front_y(x):
        return -.065 - .085 * (1 - (x / .38) ** 2)
    # A closed bent wooden shell, 14 mm thick. Front faces -Y.
    for layer in (0, 1):
        for j in range(rows + 1):
            z = -.59 + j * 1.18 / rows
            for i in range(cols + 1):
                x = -.38 + i * .76 / cols
                verts.append((x, front_y(x) + layer * .014, z))
    faces = []
    stride = cols + 1
    layer_size = stride * (rows + 1)
    for j in range(rows):
        for i in range(cols):
            a = j * (cols + 1) + i
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    front_count = len(faces)
    faces += [tuple(n + layer_size for n in reversed(face)) for face in faces[:]]
    border = list(range(stride))
    border += [j * stride + cols for j in range(1, rows + 1)]
    border += [rows * stride + i for i in range(cols - 1, -1, -1)]
    border += [j * stride for j in range(rows - 1, 0, -1)]
    for a, b in zip(border, border[1:] + border[:1]):
        faces.append((a, a + layer_size, b + layer_size, b))
    shell = mesh("Closed curved scutum shell", verts, faces, wood)
    shell.data.materials.append(back)
    for poly in shell.data.polygons[front_count:front_count * 2]:
        poly.material_index = 1
    for z in (-.59, .59):
        points = [(x, front_y(x) + .007, z) for x in [-.38 + i * .76 / cols for i in range(cols + 1)]]
        tube("Curved iron end rim", points, .009, rim)
    for x in (-.38, .38):
        tube("Iron side rim", [(x, front_y(x)+.007, -.59),(x, front_y(x)+.007, .59)], .009, rim)
    # Rivets follow the actual curved surface, not a floating straight bar.
    for x in (-.35, .35):
        for z in (-.54, -.36, -.18, 0, .18, .36, .54):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                               location=(x, front_y(x)-.003, z))
            rivet = bpy.context.object
            rivet.name = "Shield rim rivet"
            rivet.scale = (.007, .004, .007)
            rivet.data.materials.append(boss)
    # Boss axis rotated to point forward.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=(0, -.17, 0))
    b = bpy.context.object
    b.name = "Raised shield boss"
    b.scale = (.12, .065, .12)
    b.data.materials.append(boss)
    for poly in b.data.polygons:
        poly.use_smooth = True
    for x in (-.105, .105):
        cube("Rear grip mount", (.026, .145, .042), (x, -.062, 0), back, .006)
    tube("Rear horizontal grip", [(-.12,.004,0),(.12,.004,0)], .017, back)
    socket("SOCKET_LEFT_HAND", (0, .004, 0), "left_hand")


def export(name, target, game_target):
    target.mkdir(parents=True, exist_ok=True)
    game_target.mkdir(parents=True, exist_ok=True)
    finish_geometry()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(target / (name + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(game_target / (name + ".glb")),
                             export_format="GLB", export_extras=True, export_tangents=True)


def preview(target, game_target):
    reset()
    for name, offset in (("scutum_lod0", (-.34, 0, .65)), ("gladius_lod0", (.48, -.05, .13))):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(game_target / (name + ".glb")))
        added = set(bpy.context.scene.objects) - before
        for obj in added:
            if obj.parent not in added:
                obj.location += Vector(offset)
    floor = mat("Review floor", (.055, .065, .068), 0, .78)
    cube("Review plinth", (2.0, .8, .06), (0, 0, .018), floor, .02)
    bpy.ops.object.camera_add(location=(2.25, -3.8, 2.05))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, -.04, .66)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.08
    bpy.context.scene.camera = camera
    for loc, power, size in (((-2,-3,4),650,3), ((3,-1,2),450,2), ((0,2,3),700,2)):
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0,0,.6))-light.location).to_track_quat("-Z","Y").to_euler()
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Weapon review world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.09,.11,.13,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .35
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(target / "weapons_studio_preview.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(target / "weapons_review.blend"))
    bpy.ops.render.render(write_still=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--game-output", type=Path)
    p.add_argument("--render-preview", action="store_true")
    args = p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, builder in (("gladius_lod0", make_gladius), ("scutum_lod0", make_scutum)):
        reset()
        builder()
        export(name, args.output, args.game_output or args.output)
        print("EXPORTED", name)
    if args.render_preview:
        preview(args.output, args.game_output or args.output)


if __name__ == "__main__":
    main()
