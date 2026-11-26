"""Weapons and shields of the Germanic warrior families (Blender geometry).

Every item is authored in its grip frame: origin at the centre of the closed
hand, +Z along the handle or shaft (up when carried), -Y forward. Shields have
a vertical handle through the fist behind an iron or wooden boss. The same
geometry is baked into a figure (skinned 100 % to Hand_L/Hand_R or Pelvis) and
exported alone with a SOCKET_* empty at the grip, as the existing Meshy
equipment does.
"""
from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

import materials as M
import surfaces as S

TAU = math.tau


class Builder:
    def __init__(self, detail=0):
        self.detail = detail
        self.v, self.f, self.uv, self.mi = [], [], [], []
        self.materials = []

    def slot(self, material):
        if material not in self.materials:
            self.materials.append(material)
        return self.materials.index(material)

    def n(self, sides):
        return max(4, int(round(sides * (1.0, .6, .4, .25)[self.detail])))

    def add(self, points):
        start = len(self.v)
        self.v.extend(Vector(p) for p in points)
        return list(range(start, len(self.v)))

    def face(self, ids, uvs, material):
        self.f.append(tuple(ids))
        self.uv.append([tuple(u) for u in uvs])
        self.mi.append(self.slot(material))

    def tube(self, path, radii, material, sides=10, tile=.1, caps=True, section=None, twist=0.0):
        """section(j, sides) -> (x, y) unit offsets; default circle."""
        sides = self.n(sides)
        rings = []
        for k, p in enumerate(path):
            p = Vector(p)
            tangent = Vector(path[min(k + 1, len(path) - 1)]) - Vector(path[max(0, k - 1)])
            axis = tangent.normalized()
            helper = Vector((1, 0, 0)) if abs(axis.x) < .9 else Vector((0, 1, 0))
            a = axis.cross(helper).normalized()
            b = axis.cross(a).normalized()
            r = radii[k]
            ring = []
            for j in range(sides):
                if section:
                    sx, sy = section(j, sides)
                else:
                    ang = j * TAU / sides + twist * k
                    sx, sy = math.cos(ang), math.sin(ang)
                rx, ry = (r if not isinstance(r, tuple) else r[0]), (r if not isinstance(r, tuple) else r[1])
                ring.append(p + a * sx * rx + b * sy * ry)
            rings.append(self.add(ring))
        length = [0.0]
        for k in range(1, len(path)):
            length.append(length[-1] + (Vector(path[k]) - Vector(path[k - 1])).length)
        for k in range(len(path) - 1):
            for j in range(sides):
                n = (j + 1) % sides
                self.face((rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j]),
                          ((j / sides, length[k] / tile), ((j + 1) / sides, length[k] / tile),
                           ((j + 1) / sides, length[k + 1] / tile), (j / sides, length[k + 1] / tile)), material)
        if caps:
            for ring, rev in ((rings[0], True), (rings[-1], False)):
                ids = list(reversed(ring)) if rev else ring
                self.face(ids, [(.5 + .45 * math.cos(j * TAU / len(ids)), .5 + .45 * math.sin(j * TAU / len(ids))) for j in range(len(ids))], material)

    def lathe(self, profile, material, sides=16, axis="Y", flip=1.0, origin=(0, 0, 0), tile=.08):
        """Surface of revolution; profile = [(radius, height)] from rim to tip."""
        sides = self.n(sides)
        o = Vector(origin)
        rings = []
        for r, h in profile:
            ring = []
            for j in range(sides):
                a = j * TAU / sides
                if axis == "Y":
                    ring.append(o + Vector((math.cos(a) * r, -h * flip, math.sin(a) * r)))
                else:
                    ring.append(o + Vector((math.cos(a) * r, math.sin(a) * r, h)))
            rings.append(self.add(ring))
        for k in range(len(profile) - 1):
            for j in range(sides):
                n = (j + 1) % sides
                ids = (rings[k][j], rings[k][n], rings[k + 1][n], rings[k + 1][j])
                if axis == "Y" and flip > 0:
                    ids = tuple(reversed(ids))
                self.face(ids, ((j / sides, k / tile * .01), ((j + 1) / sides, k / tile * .01),
                                ((j + 1) / sides, (k + 1) / tile * .01), (j / sides, (k + 1) / tile * .01)), material)

    def obj(self, name):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.v], [], self.f)
        mesh.update()
        for m in self.materials:
            mesh.materials.append(m)
        layer = mesh.uv_layers.new(name="UVMap")
        for poly, uvs, mi in zip(mesh.polygons, self.uv, self.mi):
            poly.material_index = mi
            poly.use_smooth = True
            for li, uv in zip(poly.loop_indices, uvs):
                layer.data[li].uv = uv
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


# Shared library materials (made once per build session) --------------------------
def library(tier=0):
    size = 512 if tier == 0 else 256
    return {
        "ash": M.named("Ash", "wood", 501, size, colour="9a7a52"),
        "oak": M.named("Oak", "wood", 502, size, colour="6e5034"),
        "charred": M.pbr("Charred", S.wood(size, 503, "2a1d14")),
        "iron": M.named("Iron", "iron", 504, size, rust=.30),
        "iron_bright": M.named("IronBright", "iron", 505, size, rust=.10, polish=.6),
        "iron_rusty": M.named("IronRusty", "iron", 506, size, rust=.65),
        "bronze": M.named("Bronze", "bronze", 507, size, patina=.25),
        "rawhide": M.named("Rawhide", "leather", 508, size, colour="8c6a48", worn=.6),
        "leather": M.named("Leather", "leather", 509, size, colour="4a3020", worn=.5),
        "bone": M.pbr("Bone", S.leather(size, 510, "c9bb9a", .2)),
    }


def _lens(width, thickness, rib=0.0, single=False):
    """Blade cross-section: lens (double-edged) or wedge (single-edged)."""
    def section(j, sides):
        a = j * TAU / sides
        x, y = math.cos(a), math.sin(a)
        if single:
            return (x, y * (1.0 - .7 * (x + 1) * .5))
        lens = y * (.45 + .55 * (1 - abs(x)))
        return (x, lens + rib * (1 - abs(x)) * (1 if y >= 0 else -1))
    return section


def spear(b, lib, length=2.30, grip=.92, head=.20, width=.032, socket=.075, shaft_r=.0135, quality=2,
          stake=False):
    """Framea or thrusting spear; grip height measured from the butt."""
    wood = lib["ash"]
    z0 = -grip
    top = z0 + length - (0 if stake else head + socket)
    taper = [shaft_r * 1.05, shaft_r, shaft_r * .96, shaft_r * .9]
    zs = [z0, z0 + .3, (z0 + top) * .5, top]
    if stake:
        zs[-1] = top - .12
        b.tube([(0, 0, z) for z in zs], taper, wood, 10, tile=.25)
        b.tube([(0, 0, top - .12), (0, 0, top - .04), (0, 0, top)], [shaft_r * .9, shaft_r * .45, .0015], lib["charred"], 10, tile=.08)
        return
    b.tube([(0, 0, z) for z in zs], taper, wood, 10, tile=.25)
    metal = lib["iron_bright"] if quality >= 3 else (lib["iron"] if quality >= 2 else lib["iron_rusty"])
    b.tube([(0, 0, top - .005), (0, 0, top + socket * .5), (0, 0, top + socket)],
           [shaft_r * 1.25, shaft_r * 1.05, shaft_r * .8], metal, 10, tile=.05)
    if quality >= 3:
        for z in (top + .012, top + .03):
            b.tube([(0, 0, z), (0, 0, z + .006)], [shaft_r * 1.32, shaft_r * 1.32], lib["bronze"], 10, tile=.02)
    hb = top + socket
    path, radii = [], []
    steps = 9
    for k in range(steps + 1):
        t = k / steps
        # Leaf: widest at 30 %, a narrow point; framea heads are narrow.
        w = width * (math.sin(math.pi * min(1.0, t / .62) * .5) if t < .3 else max(.0, (1 - t) / .7)) + .0015
        th = .0045 * (1 - t) + .0012
        path.append((0, 0, hb + head * t))
        radii.append((w, th))
    b.tube(path, radii, metal, 8, tile=.06, section=_lens(1, 1, rib=.15 if quality >= 2 else 0))
    if quality >= 2:
        b.tube([(0, 0, z0 - .002), (0, 0, z0 + .04)], [shaft_r * .95, shaft_r * 1.1], metal, 10, tile=.04)


def javelin(b, lib, length=1.55, grip=.62, quality=1, offset=(0, 0, 0)):
    o = Vector(offset)
    z0 = -grip
    if quality <= 0:
        # Fire-hardened wooden point, no iron.
        top = z0 + length
        b.tube([o + Vector((0, 0, z)) for z in (z0, top - .14)], [.0105, .0095], lib["oak"], 8, tile=.25)
        b.tube([o + Vector((0, 0, top - .14)), o + Vector((0, 0, top - .05)), o + Vector((0, 0, top))],
               [.0095, .005, .0012], lib["charred"], 8, tile=.08)
        return
    top = z0 + length - .085
    b.tube([o + Vector((0, 0, z)) for z in (z0, top)], [.0095, .0088], lib["ash"], 8, tile=.25)
    metal = lib["iron"] if quality >= 2 else lib["iron_rusty"]
    b.tube([o + Vector((0, 0, top - .004)), o + Vector((0, 0, top + .03))], [.0115, .009], metal, 8, tile=.04)
    path, radii = [], []
    for k in range(7):
        t = k / 6
        w = .016 * (math.sin(math.pi * min(1.0, t / .5) * .5) if t < .35 else (1 - t) / .65) + .001
        path.append(o + Vector((0, 0, top + .03 + .055 * t)))
        radii.append((w, .0035 * (1 - t) + .001))
    b.tube(path, radii, metal, 6, tile=.05, section=_lens(1, 1))


def sword(b, lib, blade=.72, width=.046, single=False, quality=2, hilt="ash"):
    metal = lib["iron_bright"] if quality >= 3 else lib["iron"]
    b.tube([(0, 0, -.065), (0, 0, -.045)], [.020, .017], lib["bronze"] if quality >= 3 else metal, 10, tile=.03)
    b.tube([(0, 0, -.05), (0, 0, 0), (0, 0, .05)], [.0145, .0158, .0145], lib[hilt], 10, tile=.05)
    if quality >= 2:
        b.tube([(0, 0, -.03), (0, 0, -.02)], [.017, .017], lib["bronze"] if quality >= 3 else metal, 10, tile=.02)
    guard = [(-.042, 0, .056), (.042, 0, .056)]
    b.tube(guard, [(.009, .013)] * 2, metal if not quality >= 3 else lib["bronze"], 8, tile=.03)
    path, radii = [], []
    steps = 10
    for k in range(steps + 1):
        t = k / steps
        if single:
            w = width * (1 - .25 * t) if t < .82 else width * .75 * (1 - (t - .82) / .18) + .002
        else:
            w = width * (1 - .12 * t) if t < .9 else width * .88 * (1 - (t - .9) / .1) ** .6 + .002
        path.append((0, 0, .062 + blade * t))
        radii.append((w * .5, .0042))
    b.tube(path, radii, metal, 8, tile=.15, section=_lens(1, 1, rib=.1, single=single))


def scabbard(b, lib, blade=.72, quality=2):
    """Wood-and-leather scabbard; chape in iron or bronze."""
    path = [(0, 0, 0), (0, 0, -blade * .5), (0, 0, -blade - .03)]
    b.tube(path, [(.031, .011), (.030, .011), (.022, .010)], lib["leather"], 10, tile=.15)
    chape = lib["bronze"] if quality >= 3 else lib["iron"]
    b.tube([(0, 0, -blade - .045), (0, 0, -blade + .03)], [(.020, .012), (.034, .013)], chape, 10, tile=.05)
    b.tube([(0, 0, .002), (0, 0, -.025)], [(.035, .014), (.035, .014)], chape, 10, tile=.03)


def axe(b, lib, haft=.62, grip_from_bottom=.10, quality=1):
    z0 = -grip_from_bottom
    top = z0 + haft
    b.tube([(0, 0, z0), (0, 0, top - .08), (0, 0, top)], [.016, .015, .017], lib["ash"], 10, tile=.2)
    metal = lib["iron"] if quality >= 2 else lib["iron_rusty"]
    # Shaft-hole head: eye round the haft, blade widening forward (-Y).
    b.tube([(0, .012, top - .085), (0, .012, top - .02)], [.024, .024], metal, 10, tile=.04)
    pts = []
    for k in range(7):
        t = k / 6
        y = .0 - .15 * t
        half = .022 + .045 * t ** 1.6
        pts.append(((0, y, top - .052), (.012 * (1 - .8 * t) + .002, half)))
    b.tube([p for p, _ in pts], [(r[0], r[1]) for _, r in pts], metal, 8, tile=.05)


def club(b, lib, length=.78, grip_from_bottom=.12):
    z0 = -grip_from_bottom
    rng = np.random.default_rng(77)
    zs = [z0 + length * k / 8 for k in range(9)]
    radii = [.016 + .028 * (k / 8) ** 1.8 + .004 * rng.random() for k in range(9)]
    b.tube([(0, 0, z) for z in zs], radii, lib["oak"], 10, tile=.2)


def knife_sheath(b, lib):
    b.tube([(0, 0, 0), (.0, 0, -.16)], [(.022, .009), (.008, .006)], lib["leather"], 8, tile=.08)
    b.tube([(0, 0, .0), (0, 0, .075)], [.0105, .0115], lib["bone"], 8, tile=.05)


def _outline(shape, w, h, n):
    pts = []
    for i in range(n):
        a = i * TAU / n
        c, s = math.cos(a), math.sin(a)
        if shape == "rect":
            p = 6.0
            x = math.copysign(abs(c) ** (2 / p), c)
            z = math.copysign(abs(s) ** (2 / p), s)
        else:
            x, z = c, s
        pts.append((x * w * .5, z * h * .5))
    return pts


def shield(b, lib, face, shape="round", width=.66, height=.66, boss="iron", rim="rawhide", spine=False,
           quality=2, grip_depth=.055, dish=.014, thickness=.010):
    """Plank board with painted face, rim binding, boss and vertical handle."""
    n = b.n(40)
    outline = _outline(shape, width, height, n)
    back = lib["oak"]
    y_back = -grip_depth
    centre_front = b.add([(0, y_back - thickness - dish, 0)])[0]
    rim_front, rim_back = [], []

    def front_y(x, z):
        rr = min(1.0, (x / (width * .5)) ** 2 + (z / (height * .5)) ** 2)
        return y_back - thickness - dish * (1 - rr)

    for x, z in outline:
        rim_front.append(b.add([(x, front_y(x, z), z)])[0])
        rim_back.append(b.add([(x, y_back - dish * .3 * 0, z)])[0])
    centre_back = b.add([(0, y_back, 0)])[0]

    def uv_of(x, z):
        return (x / width + .5, z / height + .5)

    # Intermediate ring so the dish is smooth.
    mid = []
    for x, z in outline:
        mid.append(b.add([(x * .55, front_y(x * .55, z * .55), z * .55)])[0])
    for i in range(n):
        j = (i + 1) % n
        (x0, z0), (x1, z1) = outline[i], outline[j]
        b.face((centre_front, mid[i], mid[j]), (uv_of(0, 0), uv_of(x0 * .55, z0 * .55), uv_of(x1 * .55, z1 * .55)), face)
        b.face((mid[i], rim_front[i], rim_front[j], mid[j]),
               (uv_of(x0 * .55, z0 * .55), uv_of(x0, z0), uv_of(x1, z1), uv_of(x1 * .55, z1 * .55)), face)
        b.face((centre_back, rim_back[j], rim_back[i]), ((.5, .5), (x1 / width + .5, z1 / height + .5), (x0 / width + .5, z0 / height + .5)), back)
        b.face((rim_front[i], rim_back[i], rim_back[j], rim_front[j]), ((0, 0), (0, 1), (1, 1), (1, 0)), back)
    # Rim binding.
    if rim:
        path = [(x * 1.0, (front_y(x, z) + y_back) * .5, z) for x, z in outline] + [None]
        path[-1] = path[0]
        mat = lib["iron"] if rim == "iron" else lib["rawhide"]
        b.tube(path, [(.0085, .0105)] * len(path), mat, 6, tile=.06, caps=False)
    # Central spine (La Tene and earlier Northern boards): a raised wooden rib.
    if spine:
        b.tube([(0, y_back - thickness - dish - .004, -height * .44), (0, y_back - thickness - dish - .010, 0),
                (0, y_back - thickness - dish - .004, height * .44)], [(.022, .010), (.030, .016), (.022, .010)],
               lib["oak"], 8, tile=.15)
    # Boss.
    base = y_back - thickness - dish
    if boss == "iron":
        metal = lib["iron_bright"] if quality >= 3 else lib["iron"]
        b.lathe([(.088, 0), (.086, .004), (.070, .010), (.064, .016), (.058, .034), (.040, .058), (.012, .070),
                 (.003, .084 if quality >= 2 else .072), (0.0, .086 if quality >= 2 else .073)], metal, 18,
                axis="Y", origin=(0, base + .002, 0))
        studs = (5 if quality >= 3 else 4) if b.detail < 2 else 0
        for k in range(studs):
            a = k * TAU / studs + .3
            b.lathe([(.0075, 0), (.006, .004), (.0, .006)], lib["bronze"] if quality >= 3 else metal, 8, axis="Y",
                    origin=(math.cos(a) * .078, base - .001, math.sin(a) * .078))
    elif boss == "wood":
        b.lathe([(.072, 0), (.066, .012), (.050, .030), (.026, .042), (.0, .046)], lib["oak"], 14, axis="Y",
                origin=(0, base + .002, 0))
    # Handle through the fist, fixed to the board at both ends.
    if b.detail < 2:
        b.tube([(0, 0, -.085), (0, 0, .085)], [.0125, .0125], lib["ash"], 8, tile=.1)
        for z in (-.085, .085):
            b.tube([(0, .006, z), (0, y_back + .002, z)], [(.012, .014)] * 2, lib["ash"], 6, tile=.05)


def build_item(spec, faces, tier=0):
    """Return a Builder with the item geometry for a registry item spec.

    tier 0 and 1 are the library tiers; 2 and 3 are the far figure LODs."""
    b = Builder(detail=tier)
    lib = library(min(tier, 1))
    kind = spec["kind"]
    q = spec.get("quality", 2)
    if kind == "spear":
        spear(b, lib, spec.get("length", 2.3), spec.get("grip", .92), spec.get("head", .2), spec.get("width", .032),
              quality=q, stake=spec.get("stake", False))
    elif kind == "javelins":
        offsets = spec.get("offsets", [(0, 0, 0)])
        for k, off in enumerate(offsets):
            javelin(b, lib, spec.get("length", 1.55), spec.get("grip", .62), q, off)
    elif kind == "sword":
        sword(b, lib, spec.get("blade", .72), spec.get("width", .046), spec.get("single_edged", False), q, spec.get("hilt", "ash"))
    elif kind == "scabbard":
        scabbard(b, lib, spec.get("blade", .72), q)
    elif kind == "axe":
        axe(b, lib, spec.get("haft", .62), quality=q)
    elif kind == "club":
        club(b, lib)
    elif kind == "knife":
        knife_sheath(b, lib)
    elif kind == "shield":
        face = faces[spec["id"]] if tier == 0 else faces[spec["id"] + "_t1"]
        if tier >= 2:
            # Far tiers: fewer board steps, no rim binding detail.
            pass
        shield(b, lib, face, spec.get("shape", "round"), spec["width"], spec["height"], spec.get("boss", "iron"),
               spec.get("rim", "rawhide"), spec.get("spine", False), q)
    else:
        raise ValueError("Unknown equipment kind " + kind)
    return b


def shield_face_material(spec, group_spec, tier=0):
    paint = spec.get("paint", group_spec["shield_paint"])
    accent = spec.get("accent", group_spec["shield_accent"])
    motif = spec.get("motif", group_spec["shield_motif"])
    size = 1024 if tier == 0 else 256
    aspect = spec["height"] / spec["width"]
    surface = S.shield_face(size, spec.get("seed", 900), spec.get("board", "a88a62"), paint, motif, accent,
                            spec.get("wear", .35), spec.get("planks", 5), aspect,
                            "rect" if spec.get("shape") == "rect" else "oval")
    return M.pbr(spec["id"] + ("_face" if tier == 0 else "_face_t1"), surface)


def place(obj, frame, rotation=(0, 0, 0), offset=(0, 0, 0)):
    """Rest-pose placement of a grip-centred item at a hand grip frame."""
    rot = Matrix.Rotation(math.radians(rotation[2]), 4, "Z") @ Matrix.Rotation(math.radians(rotation[1]), 4, "Y") @ \
        Matrix.Rotation(math.radians(rotation[0]), 4, "X")
    align = Vector((0, 0, 1)).rotation_difference(Vector(frame["axis"])).to_matrix().to_4x4()
    m = Matrix.Translation(Vector(frame["centre"]) + Vector(offset)) @ align @ rot
    obj.data.transform(m)
    obj.data.update()
    return m
