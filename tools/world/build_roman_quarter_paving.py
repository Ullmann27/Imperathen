"""Model and bake the paving of the original IMPERATHEN Roman street.

blender -b -t 4 --python tools/world/build_roman_quarter_paving.py -- --output DIRECTORY
Blender scene units are metres. Plans use Godot coordinates (X, Y up, Z).
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from viva_roma_surfaces import build_blender_material

SEED = 581126
HALF_LENGTH = 13.0
GUTTER = 3.1
EDGE = 4.5
WALK_HEIGHT = .159
SOURCE = Path(__file__).relative_to(Path(__file__).resolve().parents[2]).as_posix()


class Surface:
    def __init__(self, name, material, repeat):
        self.name = name
        self.material = material
        self.repeat = repeat
        self.vertices = []
        self.faces = []
        self.tones = []

    def stone(self, rim, bottom, height, bevel, tone, dip=0.0):
        """Three rings share vertices, with a weathered shoulder and a crowned top."""
        count = len(rim)
        cx = sum(x for x, _ in rim) / count
        cz = sum(z for _, z in rim) / count
        start = len(self.vertices)
        for layer in range(3):
            for x, z in rim:
                offset = Vector((cx - x, cz - z))
                step = min(bevel, offset.length * .35)
                if layer == 2 and offset.length:
                    offset = offset.normalized() * step
                    x += offset.x
                    z += offset.y
                y = bottom if layer == 0 else height(x, z) - (bevel if layer == 1 else 0)
                self.vertices.append((x, -z, y))
        self.vertices.append((cx, -cz, height(cx, cz) + dip))
        for i in range(count):
            j = (i + 1) % count
            self.faces.extend([
                (start + i, start + count + i, start + count + j, start + j),
                (start + count + i, start + 2 * count + i, start + 2 * count + j, start + count + j),
                (start + 2 * count + j, start + 2 * count + i, start + 3 * count),
            ])
            self.tones.extend([tone * .80, tone * .93, tone])

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        mesh.materials.append(self.material)
        mesh.uv_layers.new(name="Metric")
        mesh.color_attributes.new(name="Weathering", type="FLOAT_COLOR", domain="CORNER")
        # Adding one CustomData layer may reallocate earlier RNA handles.
        uv = mesh.uv_layers["Metric"]
        col = mesh.color_attributes["Weathering"]
        uv_values, color_values = [], []
        for face, tone in zip(mesh.polygons, self.tones):
            for idx in face.loop_indices:
                x, y, z = mesh.vertices[mesh.loops[idx].vertex_index].co
                # Avoid zero-area UVs on vertical edges.
                dx = z * .76 if abs(face.normal.x) > .7 else 0
                dy = z * .76 if abs(face.normal.y) > .7 else 0
                uv_values.extend(((x + dx) / self.repeat, (y + dy) / self.repeat))
                color_values.extend((tone, tone * .99, tone * .97, 1.0))
        uv.uv.foreach_set("vector", uv_values)
        col.data.foreach_set("color", color_values)
        mesh.color_attributes.active_color = col
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def clip(poly, nx, nz, distance):
    result = []
    previous = poly[-1]
    last = nx * previous[0] + nz * previous[1] - distance
    for point in poly:
        current = nx * point[0] + nz * point[1] - distance
        if (last <= 0) != (current <= 0):
            fraction = last / (last - current)
            result.append(tuple(a + fraction * (b - a) for a, b in zip(previous, point)))
        if current <= 0:
            result.append(point)
        previous, last = point, current
    return result


def voronoi(rng, xmin, xmax, zmin, zmax, columns, rows, margin):
    dx, dz = (xmax - xmin) / columns, (zmax - zmin) / rows
    sites = {
        (i, j): (xmin + (i + rng.uniform(.23, .77)) * dx,
                 zmin + (j + rng.uniform(.23, .77)) * dz)
        for i in range(columns) for j in range(rows)
    }
    for (i, j), (x, z) in sites.items():
        poly = [(xmin, zmin), (xmax, zmin), (xmax, zmax), (xmin, zmax)]
        for u in range(i - 2, i + 3):
            for v in range(j - 2, j + 3):
                if (u, v) == (i, j) or (u, v) not in sites or not poly:
                    continue
                p, q = sites[u, v]
                poly = clip(poly, p - x, q - z, .5 * (p * p + q * q - x * x - z * z))
        yield [(x + (px - x) * (1 - margin), z + (pz - z) * (1 - margin))
               for px, pz in poly]


def crown(x, z):
    rut_centre = .74 + .047 * math.sin(z * .32)
    rut = .021 * math.exp(-((abs(x) - rut_centre) / .13) ** 2)
    return .076 * (1 - abs(x / GUTTER)) - rut


def chamfer(x, z, w, l, rng):
    a, b = w / 2, l / 2
    cut = [rng.uniform(.028, .106) * min(w, l) for _ in range(8)]
    return [(x-a+cut[0], z-b), (x+a-cut[1], z-b), (x+a, z-b+cut[2]),
            (x+a, z+b-cut[3]), (x+a-cut[4], z+b), (x-a+cut[5], z+b),
            (x-a, z+b-cut[6]), (x-a, z-b+cut[7])]


def make_material(out, name, rgb, kind, metres, roughness, size=512):
    material = build_blender_material(name, rgb, kind, out, metres, roughness, 0, size,
                                      SEED + sum(map(ord, name)))
    # glTF exports COLOR_0. Multiply the same field into the Blender material
    # so review renders use the identical baked stone-to-stone variation.
    tree = material.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    texture = bsdf.inputs["Base Color"].links[0].from_socket
    variation = tree.nodes.new("ShaderNodeVertexColor")
    variation.layer_name = "Weathering"
    mix = tree.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    tree.links.new(texture, mix.inputs[1])
    tree.links.new(variation.outputs["Color"], mix.inputs[2])
    tree.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    return material


def make_street(out):
    rng = random.Random(SEED)
    basalt = make_material(out, "Basalt", (.134, .119, .101), "basalt", .95, .73, 1024)
    limestone = make_material(out, "Kalkstein", (.38, .306, .209), "limestone", .8, .83, 1024)
    sand = make_material(out, "Fugensand", (.164, .112, .068), "ground", .53, .93)
    paving = Surface("Basaltpflaster", basalt, .95)
    beds = Surface("Fugenbett", sand, .53)
    curbs = Surface("Bordsteine", limestone, .8)
    flags = Surface("Gehwegplatten", limestone, .8)
    grit = Surface("Kiesel_am_Rinnstein", limestone, .35)
    crossings = Surface("Trittsteine", basalt, .95)
    for i in range(13):
        x = -GUTTER + i * GUTTER * 2 / 13
        w = GUTTER * 2 / 13
        beds.stone([(x, -HALF_LENGTH), (x+w, -HALF_LENGTH), (x+w, HALF_LENGTH),
                    (x, HALF_LENGTH)], -.03, lambda a, b: crown(a, b) - .038, .0, .79)
    for cell in voronoi(rng, -GUTTER, GUTTER, -HALF_LENGTH, HALF_LENGTH, 13, 54, .065):
        off = rng.uniform(-.012, .014)
        tone = rng.uniform(.63, .99)
        paving.stone(cell, -.035, lambda x, z: crown(x, z) + off, rng.uniform(.018, .033), tone, .005)
    for side in (-1, 1):
        lo, hi = sorted((side*(GUTTER+.24), side*EDGE))
        beds.stone([(lo, -HALF_LENGTH), (hi, -HALF_LENGTH), (hi, HALF_LENGTH),
                    (lo, HALF_LENGTH)], -.012, lambda x, z: WALK_HEIGHT-.035, 0, .86)
        for cell in voronoi(rng, lo, hi, -HALF_LENGTH, HALF_LENGTH, 2, 39, .051):
            off = rng.uniform(-.006, .006)
            flags.stone(cell, .105, lambda x, z: WALK_HEIGHT+off, .015, rng.uniform(.70, .99))
        z = -HALF_LENGTH
        while z < HALF_LENGTH:
            length = min(rng.uniform(.44, .91), HALF_LENGTH - z)
            if length < .04:
                break
            top = WALK_HEIGHT+rng.uniform(.0, .027)
            curbs.stone(chamfer(side*(GUTTER+.11), z+length/2, .27, length-.022, rng),
                        -.005, lambda x, zz: top, .028, rng.uniform(.62, .99))
            z += length
        for _ in range(360):
            z = rng.uniform(-HALF_LENGTH+.1, HALF_LENGTH-.1)
            if math.sin(z * 1.7) + rng.random() < .25:
                continue
            x = side * rng.uniform(GUTTER-.24, GUTTER-.045)
            radius = rng.uniform(.008, .045)
            rim = [(x+radius*rng.uniform(.78, 1.18)*math.cos(i*math.tau/5),
                    z+radius*rng.uniform(.65, 1.13)*math.sin(i*math.tau/5))
                   for i in range(5)]
            height = crown(x, z)
            grit.stone(rim, height-.008, lambda a, b: height+radius*.45,
                       radius*.27, rng.uniform(.49, .88), radius*.13)
    fountain_landing = (-6.34, -4.488, -6.15, -2.4)
    x0, x1, z0, z1 = fountain_landing
    beds.stone([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], -.012,
               lambda x, z: WALK_HEIGHT-.038, 0, .81)
    for cell in voronoi(rng, *fountain_landing, 4, 7, .064):
        off = rng.uniform(-.005, .006)
        flags.stone(cell, .105, lambda x, z: WALK_HEIGHT+off, .015, rng.uniform(.71, .99))
    # Crossings between cart-wheel paths. Individual stones have separate
    # collision downstream; the pebble field does not affect player walking.
    for x in (-2.55, -1.85, -.13, 1.62, 2.39):
        top = WALK_HEIGHT + rng.uniform(-.005, .01)
        crossings.stone(chamfer(x, 6.2+rng.uniform(-.1, .1), .54, .86, rng),
                        crown(x, 6.2)-.02, lambda a, b: top, .048, rng.uniform(.69, .83))
    return [surface.finish() for surface in (beds, paving, curbs, flags, grit, crossings)]


def export(out, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    # The Principled texture link is direct for glTF. COLOR_0 multiplies this
    # in-engine. Reconnect the Blender-specific color mix after export.
    materials = {m for obj in objects for m in obj.data.materials}
    mixes = []
    for material in materials:
        tree = material.node_tree
        base = tree.nodes.get("Principled BSDF").inputs["Base Color"]
        mix = base.links[0].from_node
        tree.links.new(mix.inputs[1].links[0].from_socket, base)
        mixes.append((tree, base, mix))
    path = out / "paving.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_vertex_color="ACTIVE", export_active_vertex_color_when_no_material=True)
    for tree, base, mix in mixes:
        tree.links.new(mix.outputs[0], base)
    reports = {}
    for obj in objects:
        obj.data.calc_loop_triangles()
        reports[obj.name] = len(obj.data.loop_triangles)
    return {"source": SOURCE, "seed": SEED, "length_m": 2*HALF_LENGTH, "width_m": 2*EDGE,
            "triangles_by_mesh": reports, "sha256_glb": hashlib.sha256(path.read_bytes()).hexdigest()}


def light_scene(render, out):
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Tageslicht")
    scene.world.color = (.30, .30, .30)
    bpy.ops.object.light_add(type="SUN", rotation=(.54, -.53, -.77))
    bpy.context.object.data.energy = 2.35
    bpy.context.object.data.angle = math.radians(7)
    bpy.ops.object.camera_add(location=(2.68, -7.9, 1.65))
    camera = bpy.context.object
    direction = Vector((-1.23, 3.0, -.33)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 34
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 675
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(out / "Pflaster-Blender.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "paving.blend"), compress=True)
    if render:
        bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    out = args.output.resolve()
    (out / "textures").mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects = make_street(out)
    report = export(out, objects)
    light_scene(args.render, out)
    (out / "metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
