"""Original procedural Gladius + Scutum asset generator for IMPERATHEN.

Blender 4.x: blender -b --python tools/build_roman_weapons.py -- --output /absolute/output
Creates separate source .blend and game-ready .glb files; metres, Z-up in Blender.
Godot glTF importer converts coordinate convention. No external assets.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy


def mat(name, rgb, metallic=0.0, roughness=0.65):
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


def make_gladius():
    steel = mat("Forged steel", (0.39, 0.43, 0.44), .84, .27)
    dark = mat("Oiled walnut", (.17, .085, .035), 0, .65)
    brass = mat("Aged bronze", (.43, .28, .095), .7, .35)
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
    cube("Grip socket RIGHT_HAND", (.018, .018, .018), (0, 0, 0), dark, 0).hide_render = True


def make_scutum():
    wood = mat("Painted red shield", (.34, .055, .038), 0, .67)
    rim = mat("Iron edge", (.17, .17, .16), .73, .4)
    boss = mat("Bronze boss", (.49, .30, .10), .73, .32)
    back = mat("Shield leather backing", (.23, .14, .075), 0, .83)
    # Front faces -Y. Shield curved across X; origin at rear grip.
    cols, rows = 12, 18
    verts = []
    for j in range(rows + 1):
        z = -.59 + j * 1.18 / rows
        for i in range(cols + 1):
            x = -.38 + i * .76 / cols
            y = -.065 - .085 * (1 - (x / .38) ** 2)
            verts.append((x, y, z))
    faces = []
    for j in range(rows):
        for i in range(cols):
            a = j * (cols + 1) + i
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    mesh("Curved scutum face", verts, faces, wood)
    cube("Shield spine", (.028, .025, 1.18), (0, -.157, 0), rim, .006)
    cube("Upper iron rim", (.76, .03, .018), (0, -.08, .59), rim, .006)
    cube("Lower iron rim", (.76, .03, .018), (0, -.08, -.59), rim, .006)
    for x in (-.38, .38):
        cube("Side iron rim", (.018, .03, 1.18), (x, -.08, 0), rim, .004)
    # Boss axis rotated to point forward.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=(0, -.17, 0))
    b = bpy.context.object
    b.name = "Raised shield boss"
    b.scale = (.12, .047, .12)
    b.data.materials.append(boss)
    cube("Rear horizontal grip", (.22, .03, .038), (0, .004, 0), back, .008)
    cube("Grip socket LEFT_HAND", (.018, .018, .018), (0, .026, 0), back, 0).hide_render = True


def export(name, target):
    target.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(target / (name + ".blend")))
    # The GLB contains only geometry/materials; rig sockets are documented,
    # not actual skeleton attachments. Source empties may be added in rig pass.
    bpy.ops.export_scene.gltf(filepath=str(target / (name + ".glb")), export_format="GLB")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, builder in (("gladius_lod0", make_gladius), ("scutum_lod0", make_scutum)):
        reset()
        builder()
        export(name, args.output)
        print("EXPORTED", name)


if __name__ == "__main__":
    main()
