"""Build the original Valdora/Rome wax diptych in Blender 4.3.

Run: blender -b -t 3 --python tools/world/build_roman_tablet.py
Add -- --render to render a studio view beside the model.
Runtime files contain only original meshes and generated, embedded textures.
"""
from __future__ import annotations

import math
from pathlib import Path
import struct
import sys
from tempfile import TemporaryDirectory
import zlib

import bpy
from mathutils import Vector
import numpy as np


SOURCE = Path(__file__).resolve().parent
OUTPUT = SOURCE.parents[1] / "prototype/assets/roman_quarter/tablet"
LEAF_WIDTH = 0.145
LEAF_DEPTH = 0.190
SEAM = 0.005
LID_TOP = 0.013
WAX_TOP = 0.0094
SIZE = 512

# Block letters gouged by a stylus. Their uneven positions and line pressure
# come from the same fixed seed as the wax wear.
LETTERS = {
    "A": [[(0, 0), (.49, 1), (1, 0)], [(.22, .41), (.78, .41)]],
    "C": [[(.88, .83), (.59, 1), (.22, .86), (0, .52), (.19, .11), (.56, 0), (.92, .18)]],
    "E": [[(.89, .99), (0, .99), (0, 0), (.93, 0)], [(0, .52), (.72, .52)]],
    "F": [[(0, 0), (0, 1), (.94, 1)], [(0, .55), (.76, .55)]],
    "I": [[(.47, 0), (.49, 1)]],
    "L": [[(.05, 1), (0, 0), (.93, .03)]],
    "M": [[(0, 0), (.12, 1), (.51, .39), (.87, .96), (1, 0)]],
    "N": [[(0, 0), (.03, 1), (.92, 0), (.96, 1)]],
    "O": [[(.51, 1), (.83, .87), (1, .53), (.83, .16), (.49, 0), (.12, .14), (0, .52), (.17, .88), (.51, 1)]],
    "P": [[(0, 0), (0, 1), (.64, 1), (.91, .82), (.76, .57), (0, .53)]],
    "R": [[(0, 0), (0, 1), (.62, 1), (.86, .77), (.69, .56), (0, .53)], [(.36, .51), (.92, 0)]],
    "S": [[(.92, .91), (.51, 1), (.14, .81), (.04, .58), (.85, .42), (.93, .21), (.67, .05), (.17, .01), (0, .16)]],
    "V": [[(0, 1), (.49, 0), (1, 1)]],
    "X": [[(0, 0), (.97, 1)], [(.03, 1), (1, 0)]],
}


def png(path, rgb):
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    data = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    width, height = data.shape[1], data.shape[0]
    payload = b"".join(b"\0" + row.tobytes() for row in data)
    header = struct.pack(">2I5B", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(payload, 9)) + chunk(b"IEND", b""))


def normal_map(height, strength):
    dy, dx = np.gradient(height)
    normal = np.stack((-dx * strength, dy * strength, np.ones_like(height)), axis=-1)
    return 0.5 + normal * (0.5 / np.linalg.norm(normal, axis=-1, keepdims=True))


def rgb_grid():
    return np.meshgrid(np.arange(SIZE) / (SIZE - 1), np.arange(SIZE) / (SIZE - 1))


def wood_textures(base):
    rng = np.random.default_rng(12058)
    u, v = rgb_grid()
    noise = rng.normal(0, .019, size=u.shape)
    knot = np.arctan2((u - .71) * 1.5, (v - .27) * .36)
    grain = 2 * np.pi * (45 * u + .24 * np.sin(v * 21) + .16 * np.sin(v * 49 + 6 * u) + .81 * knot)
    broad = np.cos(grain * .27) * .08 + np.cos(grain * .12 + 1.1) * .073
    fine = np.sin(grain) * .07 - np.maximum(0, np.cos(grain * 2 + .6)) ** 6 * .049
    light = 1 + broad + fine + noise
    png(base / "Kastanienholz.png", light[:, :, None] * np.array([.46, .285, .145]))
    png(base / "Kastanienholz_Normal.png", normal_map(broad + fine, 3.5))


def stroke(field, start, end, width, depth):
    u, v = rgb_grid()
    ax, ay = start
    bx, by = end
    vx, vy = bx - ax, by - ay
    projection = np.clip(((u - ax) * vx + (v - ay) * vy) / (vx * vx + vy * vy), 0, 1)
    distance = np.hypot(u - ax - projection * vx, v - ay - projection * vy)
    return np.maximum(field, depth * np.clip(1 - distance / width, 0, 1))


def inscription(field, lines, rng):
    for row, text in enumerate(lines):
        x = .08
        baseline = .26 + .22 * row
        for char in text:
            if char == " ":
                x += .038
                continue
            letter_width = rng.uniform(.044, .058) if char != "I" else .025
            jitter = rng.uniform(-.014, .019)
            height = rng.uniform(.075, .093)
            if char == ".":
                field = stroke(field, (x+.008, baseline-.022), (x+.009, baseline-.021), .006, .86)
            else:
                for line in LETTERS[char]:
                    points = [(x + letter_width * u + rng.uniform(-.004, .004), baseline + jitter - height * v)
                              for u, v in line]
                    for start, end in zip(points, points[1:]):
                        field = stroke(field, start, end, rng.uniform(.0030, .0065), rng.uniform(.62, 1.0))
            x += letter_width + rng.uniform(.013, .021)
    return field


def wax_textures(base, suffix, lines, seed):
    u, v = rgb_grid()
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, .012, size=u.shape)
    swirls = .024 * np.sin(37 * v + 2 * np.sin(u * 9)) + .013 * np.sin(91 * u + np.sin(12 * v))
    wear = np.exp(-((u - .17) ** 2 + (v - .88) ** 2) * 130) + np.exp(-((u - .8) ** 2 + (v - .19) ** 2) * 90)
    erased = np.zeros_like(u)
    for _ in range(23):
        x, y = rng.uniform(.03, .91, 2)
        erased = stroke(erased, (x, y), (x + rng.uniform(.03, .12), y+.016), rng.uniform(.003, .013), rng.uniform(.02, .12))
    cuts = inscription(erased, lines, rng)
    cut_rim = np.maximum(0, np.roll(cuts, 1, axis=0) - cuts)
    light = .94 + 1.9 * swirls + noise + .25 * wear
    wax = light[:, :, None] * np.array([.137, .093, .059]) + cuts[:, :, None] * np.array([.139, .103, .064])
    wax += cut_rim[:, :, None] * np.array([.035, .026, .014])
    png(base / f"Wachs_{suffix}.png", wax)
    png(base / f"Wachs_{suffix}_Normal.png", normal_map(swirls * .36 - cuts, 3.5))


def material(name, color, roughness, texture=None, relief=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    surface = nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = (*color, 1.0)
    surface.inputs["Roughness"].default_value = roughness
    if texture:
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(texture))
        image.image.pack()
        links.new(image.outputs["Color"], surface.inputs["Base Color"])
    if relief:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(relief))
        tex.image.colorspace_settings.name = "Non-Color"
        tex.image.pack()
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = .72
        links.new(tex.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], surface.inputs["Normal"])
    return mat


def rounded_rect(center, width, depth, radius, z):
    result = []
    for index, (x_corner, y_corner) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        for corner_step in range(5):
            angle = index * math.pi / 2 + corner_step * math.pi / 8
            x = center + x_corner * (width / 2 - radius) + math.cos(angle) * radius
            y = y_corner * (depth / 2 - radius) + math.sin(angle) * radius
            result.append((x, y, z))
    return result


def profile_mesh(name, center, rings, mat, uv_width, uv_depth):
    ring_size = len(rings[0])
    vertices = [point for ring in rings for point in ring]
    faces = [list(reversed(range(ring_size)))]
    for layer in range(len(rings) - 1):
        offset = layer * ring_size
        upper = offset + ring_size
        for index in range(ring_size):
            right = (index + 1) % ring_size
            faces.append((offset + index, offset + right, upper + right, upper + index))
    faces.append(list(range(len(vertices) - ring_size, len(vertices))))
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    uv = data.uv_layers.new(name="Oberfläche")
    for poly in data.polygons:
        for loop_i in poly.loop_indices:
            point = data.vertices[data.loops[loop_i].vertex_index].co
            # The side gets a continuation of the stretching wood grain.
            v = point.y / uv_depth if abs(poly.normal.z) > .55 else (point.y + point.z * 2) / uv_depth
            uv.data[loop_i].uv = ((point.x - center) / uv_width + .5, v + .5)
    return obj


def drill(leaf, center_x, side, y):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.00155, depth=.019,
                                       location=(center_x + side * (LEAF_WIDTH / 2 - .006), y, .006))
    bore = bpy.context.object
    modifier = leaf.modifiers.new("Gebohrte Bindung", "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = bore
    bpy.context.view_layer.objects.active = leaf
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(bore, do_unlink=True)


def make_leaf(name, center, facing, timber, wax):
    outer = (LEAF_WIDTH, LEAF_DEPTH)
    inner = (LEAF_WIDTH - .024, LEAF_DEPTH - .025)
    profile = [
        (*outer, .0062, .0000, .0015),
        (*outer, .0067, .0021, 0),
        (*outer, .0067, .0116, 0),
        (*outer, .0061, LID_TOP, .0011),
        (*inner, .0046, LID_TOP, -.001),
        (*inner, .0040, .0103, 0),
        (*inner, .0038, .0076, .0009),
    ]
    rims = [rounded_rect(center, w-2*inset, d-2*inset, radius, z) for w, d, radius, z, inset in profile]
    plate = profile_mesh("Holzrahmen_" + name, center, rims, timber, LEAF_WIDTH, LEAF_DEPTH)
    for y in (-.068, .068):
        drill(plate, center, facing, y)
    width, depth = inner
    surface = [
        rounded_rect(center, width-.0012, depth-.0012, .0038, .0077),
        rounded_rect(center, width-.0011, depth-.0011, .0040, .0090),
        rounded_rect(center, width-.0021, depth-.0021, .0041, WAX_TOP),
    ]
    profile_mesh("Wachsfeld_" + name, center, surface, wax, width-.0021, depth-.0021)


def cord(name, coordinates, mat, radius=.0008):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(coordinates) - 1)
    for point, coordinate in zip(spline.bezier_points, coordinates):
        point.co = coordinate
        point.handle_left_type = point.handle_right_type = "AUTO"
    item = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(item)
    item.data.materials.append(mat)
    bpy.context.view_layer.objects.active = item
    bpy.ops.object.select_all(action="DESELECT")
    item.select_set(True)
    bpy.ops.object.convert(target="MESH")
    for face in item.data.polygons:
        face.use_smooth = len(face.vertices) == 4


def make_bindings(mat):
    for index, y in enumerate((-.068, .068)):
        for offset in (-.00045, .00045):
            cord("Doppelbindung_%d" % index,
                 [(-.0085, y+offset, .0029), (-.0085, y+offset, .0103), (-.006, y+offset, .0144),
                  (0, y+offset, .0150), (.006, y+offset, .0144), (.0085, y+offset, .0101),
                  (.0085, y+offset, .0028), (0, y+offset, .0012), (-.0085, y+offset, .0029)], mat)
        cord("Knoten_%d" % index,
             [(-.003, y+.0028, .0145), (-.0015, y+.0018, .0162), (.0001, y-.0017, .0165),
              (.002, y-.0020, .0154), (.0041, y-.0024, .0140)], mat, .00062)


def make_stylus(mat):
    center = Vector((.074, -.002, .0121))
    along = Vector((.31, .9507, 0)).normalized()
    across = Vector((along.y, -along.x, 0))
    rings = [(-.0615, .00045, .00042), (-.044, .0022, .0022), (-.028, .0027, .0027),
             (.027, .0027, .0027), (.043, .0030, .0024), (.052, .0042, .0018), (.0615, .0045, .0016)]
    vertices = []
    sides = 12
    for distance, width, height in rings:
        for edge in range(sides):
            angle = math.tau * edge / sides
            vertices.append(center + along * distance + across * (width * math.cos(angle)) + Vector((0, 0, height * math.sin(angle))))
    faces = [list(reversed(range(sides)))]
    for axis in range(len(rings) - 1):
        for edge in range(sides):
            near = axis * sides
            far = near + sides
            following = (edge + 1) % sides
            faces.append((near+edge, near+following, far+following, far+edge))
    faces.append(list(range(len(vertices)-sides, len(vertices))))
    mesh = bpy.data.meshes.new("Zugespitztes Buchsbaumholz")
    # The ring basis (across, up) points away from the long axis.
    mesh.from_pydata(vertices, [], [face[::-1] for face in faces])
    mesh.update()
    stylus = bpy.data.objects.new("Schreibgriffel_mit_Glätter", mesh)
    bpy.context.collection.objects.link(stylus)
    stylus.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = len(face.vertices) == 4
    uv = mesh.uv_layers.new(name="Buchsbaum")
    for loop in mesh.loops:
        point = mesh.vertices[loop.vertex_index].co - center
        # Grain runs along the tool and around the rolled edge.
        u = math.atan2(point.z, point.dot(across)) / math.tau + .5
        v = point.dot(along) / .128 + .5
        uv.data[loop.index].uv = (u, v)


def stamp_craft_wear(mat):
    for index, y in enumerate((-.085, .085)):
        cord("Schnitzspur_%d" % index, [(-.137, y, .0125), (-.131, y-.0008, .013), (-.123, y-.002, .0129)], mat, .00020)


def preview():
    floor_mat = material("Ateliertuch", (.096, .105, .113), .86)
    bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -.0005))
    bpy.context.object.name = "Ateliertuch (nur Vorschau)"
    bpy.context.object.data.materials.append(floor_mat)
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=(.28, -.34, .45))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, .004)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = .40
    scene.camera = camera
    for location, wattage, area, tint in (
        ((-.195, -.20, .33), 4.1, .26, (1.0, .89, .75)),
        ((.23, -.05, .39), 2.0, .33, (.78, .88, 1.0)),
        ((.035, .20, .22), 2.5, .24, (1.0, .94, .84)),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        lamp = bpy.context.object
        lamp.rotation_euler = (-lamp.location).to_track_quat("-Z", "Y").to_euler()
        lamp.data.energy = wattage
        lamp.data.shape = "DISK"
        lamp.data.size = area
        lamp.data.color = tint
    scene.world = bpy.data.worlds.new("Weiches Studiolicht")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (.20, .20, .20, 1.0)
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .35
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 91


def export_model():
    # The source keeps each handmade component editable. The runtime mesh
    # uses one draw call per material rather than one per wooden part or tie.
    bpy.ops.object.select_all(action="DESELECT")
    for part in list(bpy.context.scene.objects):
        copy = part.copy()
        copy.data = part.data.copy()
        bpy.context.collection.objects.link(copy)
        copy.select_set(True)
        bpy.context.view_layer.objects.active = copy
    bpy.ops.object.join()
    runtime = bpy.context.object
    runtime.name = "Valdora_Wachstafel"
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / "wax_tablet.glb"), export_format="GLB",
        use_selection=True, export_yup=True, export_apply=True,
    )
    bpy.data.objects.remove(runtime, do_unlink=True)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="imperathen-tablet-") as scratch:
        base = Path(scratch)
        wood_textures(base)
        wax_textures(base, "links", ["SAL . III", "OLEVM . VI", "CERA . II"], 58)
        wax_textures(base, "rechts", ["VINA . VII", "PANIS . IV", "FAR . IX"], 123)
        timber = material("Dunkles Kastanienholz", (.30, .135, .053), .66, base / "Kastanienholz.png", base / "Kastanienholz_Normal.png")
        left = material("Wachs mit Warenvermerken links", (.12, .078, .045), .71, base / "Wachs_links.png", base / "Wachs_links_Normal.png")
        right = material("Wachs mit Warenvermerken rechts", (.12, .078, .045), .73, base / "Wachs_rechts.png", base / "Wachs_rechts_Normal.png")
        boxwood = material("Geölter Buchsbaumgriffel", (.47, .258, .103), .59)
        linen = material("Gedrehte Flachsbindung", (.32, .207, .106), .87)
        wear = material("Helle Schnitzspur", (.22, .116, .046), .76)
    leaf_offset = (LEAF_WIDTH + SEAM) / 2
    make_leaf("links", -leaf_offset, 1, timber, left)
    make_leaf("rechts", leaf_offset, -1, timber, right)
    make_bindings(linen)
    make_stylus(boxwood)
    stamp_craft_wear(wear)
    export_model()
    preview()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "wax_tablet.blend"), compress=True)
    if "--render" in sys.argv:
        scene.render.filepath = str(SOURCE / "wax_tablet_blender.jpg")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()
