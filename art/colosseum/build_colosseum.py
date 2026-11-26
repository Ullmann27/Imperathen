"""Reproducible Blender build of the Flavian Amphitheatre kit.

Run (Blender >= 4.1):
  blender -b -P art/colosseum/build_colosseum.py -- --output prototype/assets/monuments/colosseum [--render DIR]

Outputs: colosseum_modules.glb (instanced facade bays, statues, fittings),
colosseum_structure.glb (16 sectors: corridors, stairs, seating), colosseum_arena.glb,
colosseum_far.glb (HLOD shell), colosseum_collision.glb, colosseum_layout.json.
Original project geometry; no external artwork.
"""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import facade  # noqa: E402
import interior  # noqa: E402
import ring as R  # noqa: E402
import statues  # noqa: E402
from meshkit import MeshBuffer  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = os.path.abspath(arg("--output", os.path.join(HERE, "../../prototype/assets/monuments/colosseum")))
RENDER = arg("--render")
TEXTURES = os.path.abspath(os.path.join(HERE, "../../prototype/assets/monuments/textures"))
SECTORS = 16

BASE = {
    "travertine": (0.80, 0.74, 0.62), "travertine_paving": (0.66, 0.62, 0.54), "tuff": (0.50, 0.42, 0.33),
    "brick": (0.62, 0.36, 0.24), "brick_floor": (0.60, 0.38, 0.27), "marble": (0.90, 0.88, 0.84),
    "marble_statue": (0.92, 0.90, 0.86), "plaster": (0.84, 0.78, 0.66), "wood": (0.42, 0.29, 0.17),
    "wood_dark": (0.27, 0.19, 0.12), "sand": (0.80, 0.69, 0.48), "bronze": (0.42, 0.30, 0.14),
    "bronze_gilt": (0.83, 0.62, 0.22), "iron": (0.14, 0.13, 0.12), "roof_tile": (0.62, 0.33, 0.22),
    "canvas": (0.86, 0.80, 0.66), "canvas_purple": (0.36, 0.10, 0.24), "numeral_red": (0.55, 0.10, 0.07), "arch_shadow": (0.05, 0.045, 0.04),
}
_materials = {}


def material(name):
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    c = BASE.get(name, (0.7, 0.7, 0.7))
    bsdf.inputs["Roughness"].default_value = 0.35 if "bronze" in name else 0.85
    bsdf.inputs["Metallic"].default_value = 1.0 if ("bronze" in name or name == "iron") else 0.0
    nodes, links = m.node_tree.nodes, m.node_tree.links
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[6].default_value = (*c, 1.0)
    links.new(col.outputs["Color"], mix.inputs[7])
    path = os.path.join(TEXTURES, name + "_albedo.jpg")
    if os.path.exists(path):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        links.new(tex.outputs["Color"], mix.inputs[6])
    links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    m.diffuse_color = (*c, 1.0)
    _materials[name] = m
    return m


def sector_of(k):
    return ((k + 2) % R.BAYS) // (R.BAYS // SECTORS)


def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def export(coll, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in coll.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = coll.objects[0]
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_image_format="NONE", export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=True, export_normals=True, export_tangents=False)
    return os.path.getsize(path)


class AxisBuffer(MeshBuffer):
    """Frame of the major-axis passages: local x across the axis, y = depth r, world-aligned."""

    def __init__(self, name, sign):
        super().__init__(name)
        self.sign = sign

    def width(self, y):
        return 1000.0

    def world(self, p):
        x, y, z = p
        return (self.sign * (R.A - y), self.sign * x, z + self.zoff)


def axis_passage(sign, name):
    mb, col = AxisBuffer(name, sign), AxisBuffer("C_" + name, sign)
    h = interior.AXIS_HALF
    cut = interior.AXIS_CUT_R
    c0, c1 = R.CORR_C
    for m in (mb, col):
        m.quad((-h, 14.0, 0.0), (h, 14.0, 0.0), (h, R.DEPTH, 0.0), (-h, R.DEPTH, 0.0), "travertine_paving", (0, 0, 1))
    for ya, yb in ((14.0, c0), (c1, cut)):
        for s in (-1, 1):
            for m in (mb, col):
                m.quad((s * h, ya, 0.0), (s * h, yb, 0.0), (s * h, yb, 5.2), (s * h, ya, 5.2), "travertine", (-s, 0, 0), ao=0.8)
    for ya, yb in ((14.0, cut),):
        mb.quad((-h, ya, 5.2), (-h * 0.5, ya, 6.0), (-h * 0.5, yb, 6.0), (-h, yb, 5.2), "plaster", (1, 0, -1), ao=0.62)
        mb.quad((-h * 0.5, ya, 6.0), (h * 0.5, ya, 6.0), (h * 0.5, yb, 6.0), (-h * 0.5, yb, 6.0), "plaster", (0, 0, -1), ao=0.62)
        mb.quad((h * 0.5, ya, 6.0), (h, ya, 5.2), (h, yb, 5.2), (h * 0.5, yb, 6.0), "plaster", (-1, 0, -1), ao=0.62)
    for s in (-1, 1):   # lintels over the crossing with ring corridor C
        mb.quad((s * h, c0, 4.2), (s * h, c1, 4.2), (s * h, c1, 5.2), (s * h, c0, 5.2), "travertine", (-s, 0, 0), ao=0.8)
    # open approach between retaining walls, cut through the lowest seating
    n = 8
    y_end = R.DEPTH - 0.8
    top = lambda y: (R.cavea_z(min(y, R.DEPTH - 0.01)) or R.Z_PODIUM) + 0.95
    for i in range(n):
        ya, yb = cut + (y_end - cut) * i / n, cut + (y_end - cut) * (i + 1) / n
        for s in (-1, 1):
            for m in (mb, col):
                m.quad((s * h, ya, 0.0), (s * h, yb, 0.0), (s * h, yb, top(yb)), (s * h, ya, top(ya)), "marble", (-s, 0, 0), ao=0.9)
            o = s * (h + 0.3)
            mb.quad((o, ya, top(ya) - 1.0), (o, yb, top(yb) - 1.0), (o, yb, top(yb)), (o, ya, top(ya)), "marble", (s, 0, 0))
            mb.quad((s * h, ya, top(ya)), (s * h, yb, top(yb)), (o, yb, top(yb)), (o, ya, top(ya)), "marble", (0, 0, 1))
    # face above the tunnel mouth
    mb.quad((-h - 0.3, cut, 5.2), (h + 0.3, cut, 5.2), (h + 0.3, cut, top(cut)), (-h - 0.3, cut, top(cut)), "marble", (0, 1, 0))
    # arena gate: jambs, lintel and open timber leaves
    for s in (-1, 1):
        for m in (mb, col):
            m.box(min(s * 1.7, s * 2.5), max(s * 1.7, s * 2.5), y_end, R.DEPTH, 0.0, 5.4, "marble", skip="z-")
            m.box(min(s * 1.58, s * 1.70), max(s * 1.58, s * 1.70), y_end - 1.65, y_end, 0.05, 4.3, "wood_dark", skip="")
        for zz in (0.6, 2.1, 3.6):
            mb.box(min(s * 1.54, s * 1.58), max(s * 1.54, s * 1.58), y_end - 1.6, y_end - 0.05, zz, zz + 0.12, "iron")
    mb.box(-2.5, 2.5, y_end, R.DEPTH, 4.4, 5.4, "marble")
    mb.extrude_x([(R.DEPTH, 5.4), (R.DEPTH + 0.12, 5.45), (R.DEPTH + 0.12, 5.6), (y_end - 0.1, 5.6), (y_end - 0.1, 5.4)], -2.6, 2.6, "marble", caps=True)
    return mb, col


def arena():
    out = []
    pts = [R.edge_point(k, R.DEPTH) for k in range(R.BAYS)]
    rim, deck, col = MeshBuffer("Arena_Floor_Rim"), MeshBuffer("Arena_Floor_Deck"), MeshBuffer("C_Arena")
    for m in (rim, deck):
        m.level_z = -99
    rings = (1.0, 0.9, 0.6, 0.3, 0.0)
    for k in range(R.BAYS):
        a, b = pts[k], pts[(k + 1) % R.BAYS]
        for i in range(len(rings) - 1):
            f0, f1 = rings[i], rings[i + 1]
            q = [(a[0] * f0, a[1] * f0, 0.0), (b[0] * f0, b[1] * f0, 0.0), (b[0] * f1, b[1] * f1, 0.0), (a[0] * f1, a[1] * f1, 0.0)]
            if f1 == 0.0:
                q = q[:3]
            (rim if i == 0 else deck).face(q, "sand", (0, 0, 1), ao=1.0)
        col.face([(a[0], a[1], 0.0), (b[0], b[1], 0.0), (0.0, 0.0, 0.0)], "sand", (0, 0, 1))
    # trapdoors of the Domitianic hypogeum (era-gated at runtime)
    traps = MeshBuffer("Arena_Trapdoors")
    traps.level_z = -99
    trap_list = []
    for yy in (-14.0, -6.5, 6.5, 14.0):
        half = (R.A - R.DEPTH - 6) * math.sqrt(max(0.0, 1 - (yy / (R.B - R.DEPTH - 2)) ** 2))
        n = int(half * 2 / 7.5)
        for i in range(n):
            x = -half + (i + 0.5) * half * 2 / n
            trap_list.append((x, yy))
            traps.box(x - 1.0, x + 1.0, yy - 0.7, yy + 0.7, 0.0, 0.035, "wood", skip="z-")
            for sx in (-1, 1):
                traps.box(x + sx * 1.0 - 0.06, x + sx * 1.0 + 0.06, yy - 0.76, yy + 0.76, 0.0, 0.06, "wood_dark", skip="z-")
            for sy in (-1, 1):
                traps.box(x - 1.06, x + 1.06, yy + sy * 0.7 - 0.06, yy + sy * 0.7 + 0.06, 0.0, 0.06, "wood_dark", skip="z-")
            traps.box(x - 0.06, x + 0.06, yy - 0.12, yy + 0.12, 0.035, 0.07, "iron", skip="z-")
    # hypogeum (schematic: corridors between parallel brick walls, 6 m deep)
    hyp = MeshBuffer("Hypogeum")
    hyp.level_z = -6.0
    hyp.interior = 1.0
    ax, by = (R.A - R.DEPTH) * 0.9, (R.B - R.DEPTH) * 0.9
    for k in range(R.BAYS):
        a, b = pts[k], pts[(k + 1) % R.BAYS]
        hyp.quad((a[0] * 0.9, a[1] * 0.9, -6.0), (b[0] * 0.9, b[1] * 0.9, -6.0), (b[0] * 0.9, b[1] * 0.9, 0.0), (a[0] * 0.9, a[1] * 0.9, 0.0),
                 "brick", (-a[0], -a[1], 0), ao=0.75)
        hyp.face([(a[0] * 0.9, a[1] * 0.9, -6.0), (b[0] * 0.9, b[1] * 0.9, -6.0), (0, 0, -6.0)], "tuff", (0, 0, 1), ao=0.6)
    for yy in (-17.0, -12.0, -7.0, -2.2, 2.2, 7.0, 12.0, 17.0):
        half = ax * math.sqrt(max(0.0, 1 - (yy / by) ** 2)) - 1.0
        seg = max(1, int(half / 6))
        for i in range(-seg, seg):
            x0, x1 = i * half / seg + 0.9, (i + 1) * half / seg - 0.9   # door gaps between wall lengths
            hyp.box(x0, x1, yy - 0.45, yy + 0.45, -6.0, -0.35, "brick" if abs(yy) > 3 else "tuff", skip="z-", ao=0.8)
    return [rim, deck, traps, hyp], col, trap_list


def velarium():
    mb = MeshBuffer("Velarium_Awning")
    mb.level_z = -99
    mb.interior = 1.0
    z_mast, z_ring, r_ring = R.HEIGHT + 7.6, 41.5, 31.0
    n = 9
    for k in range(R.BAYS):
        mb.bay = k
        tint = (1.0, 0.97, 0.9) if k % 2 else (0.96, 0.9, 0.8)
        for i in range(n):
            f0, f1 = i / n, (i + 1) / n
            p = lambda f: (-0.5 + (r_ring + 0.5) * f, z_mast + (z_ring - z_mast) * f - 3.2 * math.sin(math.pi * f))
            (ya, za), (yb, zb) = p(f0), p(f1)
            mb.quad((("U", 0.03), ya, za), (("U", 0.97), ya, za), (("U", 0.97), yb, zb), (("U", 0.03), yb, zb), "canvas", (0, 0, 1), tint=tint,
                    ao=0.9 + 0.1 * math.sin(math.pi * f0))
        # ring rope
        mb.box(("U", 0.0), ("U", 1.0), r_ring - 0.06, r_ring + 0.06, z_ring - 0.06, z_ring + 0.06, "wood_dark", skip="x-x+")
    mb.bay = None
    return mb


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    report = {"triangles": {}, "files": {}}

    # ---- instanced modules -------------------------------------------------
    c_mod = collection("Modules")
    modules = {}

    def module(name, fn):
        mb = MeshBuffer(name)
        fn(mb)
        mb.to_object(c_mod, material)
        modules[name] = mb.triangles()

    for lod in (0, 1):
        for order in range(3):
            module("Arcade_%d_LOD%d" % (order, lod), lambda m, o=order, l=lod: facade.arcade(m, o, l))
        module("Attic_Window_LOD%d" % lod, lambda m, l=lod: facade.attic(m, True, l))
        module("Attic_Shield_LOD%d" % lod, lambda m, l=lod: facade.attic(m, False, l))
        module("Masts_LOD%d" % lod, lambda m, l=lod: facade.masts(m, l))
    for order in range(3):
        module("Arch_Backing_%d" % order, lambda m, o=order: facade.backing(m, o))
    for v in range(statues.VARIANTS):
        module("Statue_%d" % v, lambda m, vv=v: statues.statue(m, vv, pedestal=1.3))
        module("Statue_%d_LOD1" % v, lambda m, vv=v: statues.statue(m, vv, pedestal=1.3, lod=1))
    module("Torch_Bracket", statues.torch_bracket)
    module("Brazier", statues.brazier)
    report["triangles"]["modules"] = modules

    # ---- unique sector geometry -----------------------------------------------
    c_struct, c_col, c_far, c_arena = collection("Structure"), collection("Collision"), collection("Far"), collection("Arena")
    structure = [MeshBuffer("S%02d_Structure" % s) for s in range(SECTORS)]
    seats = [MeshBuffer("S%02d_Seating" % s) for s in range(SECTORS)]
    cols = [MeshBuffer("C%02d" % s) for s in range(SECTORS)]
    far = MeshBuffer("Colosseum_Far")
    for k in range(R.BAYS):
        s = sector_of(k)
        a, b, c = MeshBuffer("a", k, k), MeshBuffer("b", k, k), MeshBuffer("c", k, k)
        interior.corridors(a, c, k)
        interior.passages(a, c, k)
        interior.numeral(a, k)
        interior.gallery(b, c, k)
        interior.seating(b, c, k)
        col_attic = MeshBuffer("ca", k, k)
        col_attic.box(("L", 0), ("R", 0), 0.0, R.R_GALLERY[0], R.Z3, R.HEIGHT, "travertine", skip="z-")
        structure[s].merge(a)
        seats[s].merge(b)
        cols[s].merge(c)
        cols[s].merge(col_attic)
        f = MeshBuffer("f", k, k)
        f.level_z = -99
        facade.far_bay(f)
        # coarse bowl for the far shell
        prof = [(R.DEPTH, 0.0), (R.DEPTH, R.Z_PODIUM), (R.R_PRAE1[1], R.Z1), (R.R_PRAE1[0], R.Z_MEDIA0), (R.R_PRAE2[1], R.Z2),
                (R.R_WALL5[1], R.Z2), (R.R_WALL5[1], 38.4), (R.R_GALLERY[0], 40.6)]
        for (ya, za), (yb, zb) in zip(prof, prof[1:]):
            f.quad((("L", 0), ya, za), (("R", 0), ya, za), (("R", 0), yb, zb), (("L", 0), yb, zb), "roof_tile" if za > 30 else "travertine",
                   (0, zb - za + 0.01, ya - yb + 0.01), ao=0.9)
        far.merge(f)
    axis_cols = []
    for sign, name, sec in ((1, "Porta_Libitinensis", sector_of(0)), (-1, "Porta_Triumphalis", sector_of(40))):
        mb, col = axis_passage(sign, name)
        structure[sec].merge(mb)
        cols[sec].merge(col)
    for s in range(SECTORS):
        structure[s].to_object(c_struct, material)
        seats[s].to_object(c_struct, material)
        cols[s].to_object(c_col, material)
    report["triangles"]["structure"] = sum(m.triangles() for m in structure)
    report["triangles"]["seating"] = sum(m.triangles() for m in seats)
    report["triangles"]["collision"] = sum(m.triangles() for m in cols)
    arena_parts, arena_col, trap_list = arena()
    for m in arena_parts:
        m.to_object(c_arena, material)
    awning = velarium()
    awning.to_object(c_arena, material)
    arena_col.to_object(c_col, material)
    report["triangles"]["arena"] = {m.name: m.triangles() for m in arena_parts + [awning]}
    pts = [R.edge_point(k, R.DEPTH) for k in range(R.BAYS)]
    for k in range(R.BAYS):
        a, b = pts[k], pts[(k + 1) % R.BAYS]
        far.face([(a[0], a[1], 0.0), (b[0], b[1], 0.0), (0.0, 0.0, 0.0)], "sand", (0, 0, 1))
    far.to_object(c_far, material)
    report["triangles"]["far_shell"] = far.triangles()

    report["files"]["colosseum_modules.glb"] = export(c_mod, "colosseum_modules.glb")
    report["files"]["colosseum_structure.glb"] = export(c_struct, "colosseum_structure.glb")
    report["files"]["colosseum_arena.glb"] = export(c_arena, "colosseum_arena.glb")
    report["files"]["colosseum_far.glb"] = export(c_far, "colosseum_far.glb")
    report["files"]["colosseum_collision.glb"] = export(c_col, "colosseum_collision.glb")

    # ---- layout for the runtime ------------------------------------------------
    bays = []
    lights = []
    for k in range(R.BAYS):
        (cx, cy), (tx, ty), (nx, ny), w = R.bay_frame(k)
        s = w / R.NOMINAL_W
        xf = [tx * s, 0.0, -ty * s, 0.0, 1.0, 0.0, -nx, 0.0, ny, cx, 0.0, -cy]   # basis x, y, z, origin (Godot)
        h = (k * 2654435761) & 0xFFFF
        bays.append({"bay": k, "sector": sector_of(k), "type": R.bay_type(k), "number": R.entrance_number(k),
                     "numeral": R.roman(R.entrance_number(k)) if R.entrance_number(k) else "",
                     "axial": R.AXIAL.get(k, ""), "transform": [round(v, 5) for v in xf],
                     "attic": "window" if k % 2 == 0 else "shield",
                     "statues": [h % statues.VARIANTS, (h >> 5) % statues.VARIANTS],
                     "statue_offset": [round(nx * 1.15, 4), 0.0, round(-ny * 1.15, 4)],
                     "reaches_podium": interior.reaches_ima(k), "level2_passage": interior.has_l2_passage(k)})
        if k % 2 == 1:
            px, py = R.bay_point(k, 0.0, R.PIER2[0] - 0.02)
            lights.append({"kind": "torch", "sector": sector_of(k), "position": [round(px, 3), 3.2, round(-py, 3)],
                           "facing": [round(-nx, 4), 0.0, round(ny, 4)]})
        if k in R.AXIAL:
            for side in (-1, 1):
                bx, by2 = cx - nx * 3.2 + tx * side * 3.9, cy - ny * 3.2 + ty * side * 3.9
                lights.append({"kind": "brazier", "sector": sector_of(k), "position": [round(bx, 3), 0.0, round(-by2, 3)], "facing": [0, 0, 1]})
    layout = {
        "format": "imperathen-colosseum-layout", "schema": 1,
        "era": {"content_id": "building.amphitheatrum_flavium", "hypogeum_content_id": "building.amphitheatrum_flavium.hypogeum"},
        "dimensions_m": {"major_axis": 2 * R.A, "minor_axis": 2 * R.B, "height": R.HEIGHT, "perimeter": round(R.PERIMETER, 2),
                         "arena_major": 2 * (R.A - R.DEPTH), "arena_minor": 2 * (R.B - R.DEPTH), "bay": round(R.NOMINAL_W, 3)},
        "levels_m": [0.0, R.Z1, R.Z2, R.Z3], "sectors": SECTORS, "bays": bays, "light_hooks": lights,
        "trapdoors": [[round(x, 2), 0.0, round(-y, 2)] for x, y in trap_list],
        "tiers": [{"id": t[0], "class": t[1], "r_inner": t[2], "r_outer": t[3], "z0": t[4], "z1": t[5], "rows": t[6]} for t in R.TIERS],
        "build": report,
    }
    with open(os.path.join(OUT, "colosseum_layout.json"), "w") as fh:
        json.dump(layout, fh, indent=1)
    print("COLOSSEUM_BUILD_COMPLETE", json.dumps(report))
    if RENDER:
        import render_views
        render_views.render(RENDER, c_mod, layout, material)


main()
