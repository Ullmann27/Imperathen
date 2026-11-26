"""Reproducible Blender build of the Roman street-furniture kit in two era sets.

Run (Blender >= 4.1):
  blender -b -P art/street_furniture/build_street_furniture.py -- --output prototype/assets/city/street_furniture

Late Republic (usable in the 58 BC campaign city) and Imperial (Colosseum piazza).
Every item is original procedural geometry: origin on the ground, front towards
-Y in Blender (+Z in Godot), metres.  The catalogue JSON records the era set,
footprint, collision and the sources for each item (docs/29_colosseum/SOURCES.md).
"""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../colosseum"))
import statues  # noqa: E402
from meshkit import MeshBuffer  # noqa: E402
from statues import tube  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[ARGS.index("--output") + 1] if "--output" in ARGS else os.path.join(HERE, "../../prototype/assets/city/street_furniture"))
REP, IMP, BOTH = "late_republic", "imperial", "both"
CATALOG = {}
ITEMS = []


def item(name, era, radius, solid, source, kind="", lod=False, **extra):
    def wrap(fn):
        ITEMS.append((name, fn, lod))
        CATALOG[name] = {"era_set": era, "footprint_radius_m": radius, "solid": solid, "anchor_kind": kind, "source": source, **extra}
        return fn
    return wrap


def fresh(mb):
    mb.level_z = -99
    mb.interior = 1.0


def slab_box(mb, x0, x1, y0, y1, z0, z1, mat, ao=1.0, skip="z-"):
    mb.box(x0, x1, y0, y1, z0, z1, mat, skip=skip, ao=ao)


def moulded_block(mb, hx, hy, z0, z1, mat, lip=0.06, band=0.14):
    slab_box(mb, -hx - lip, hx + lip, -hy - lip, hy + lip, z0, z0 + band, mat)
    slab_box(mb, -hx, hx, -hy, hy, z0 + band, z1 - band, mat, skip="z-z+")
    slab_box(mb, -hx - lip, hx + lip, -hy - lip, hy + lip, z1 - band, z1, mat, skip="")


def column(mb, cx, cy, z0, h, r, mat, seg=10, capital=True):
    mb.lathe(cx, cy, [(r * 1.3, z0), (r * 1.3, z0 + 0.1), (r * 1.1, z0 + 0.2), (r, z0 + 0.3), (r * 0.97, z0 + h * 0.5), (r * 0.86, z0 + h - 0.3)]
             + ([(r * 0.95, z0 + h - 0.26), (r * 0.86, z0 + h - 0.2), (r * 1.25, z0 + h - 0.08)] if capital else [(r * 0.86, z0 + h)]), seg, mat)
    if capital:
        slab_box(mb, cx - r * 1.3, cx + r * 1.3, cy - r * 1.3, cy + r * 1.3, z0 + h - 0.08, z0 + h, mat, skip="")


def amphora_at(mb, x, y, z=0.0, s=1.0, mat="terracotta", lean=0.0):
    prof = [(0.0, 0.0), (0.03, 0.02), (0.07, 0.25), (0.16, 0.5), (0.17, 0.66), (0.11, 0.8), (0.05, 0.86), (0.05, 0.98), (0.065, 1.0), (0.0, 1.0)]
    mb.lathe(x, y, [(r * s, z + h * s) for r, h in prof], 8, mat)
    for sx in (-1, 1):
        tube(mb, (x + sx * 0.055 * s, y, z + 0.96 * s), (x + sx * 0.13 * s, y, z + 0.84 * s), 0.014 * s, 0.014 * s, 4, mat)
        tube(mb, (x + sx * 0.13 * s, y, z + 0.84 * s), (x + sx * 0.14 * s, y, z + 0.68 * s), 0.014 * s, 0.014 * s, 4, mat)
    del lean


def basket(mb, x, y, z, r, mat="wood", fill=None):
    mb.lathe(x, y, [(r * 0.75, z), (r, z + r * 0.9), (r * 0.92, z + r * 0.9), (r * 0.7, z + 0.05)], 8, mat)
    if fill:
        mb.lathe(x, y, [(r * 0.9, z + r * 0.8), (r * 0.5, z + r * 1.05), (0.0, z + r * 1.12)], 8, fill)


def lettering(mb, text, x0, z0, height, y, mat, depth=0.0):
    """Capital strokes for painted notices (programmata) and inscriptions."""
    s = height * 0.11
    glyphs = {
        "A": [((0, 0), (0.5, 1)), ((0.5, 1), (1, 0)), ((0.22, 0.4), (0.78, 0.4))], "C": [((1, 0.9), (0.1, 1)), ((0.05, 1), (0.05, 0)), ((0.1, 0), (1, 0.1))],
        "D": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.9, 0.7)), ((0.9, 0.7), (0.9, 0.3)), ((0.9, 0.3), (0.05, 0))], "E": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.9, 1)), ((0.05, 0.5), (0.7, 0.5)), ((0.05, 0), (0.9, 0))],
        "F": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.9, 1)), ((0.05, 0.5), (0.7, 0.5))], "I": [((0.5, 0), (0.5, 1))], "L": [((0.05, 0), (0.05, 1)), ((0.05, 0), (0.9, 0))],
        "M": [((0, 0), (0.1, 1)), ((0.1, 1), (0.5, 0.2)), ((0.5, 0.2), (0.9, 1)), ((0.9, 1), (1, 0))], "N": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.95, 0)), ((0.95, 0), (0.95, 1))],
        "O": [((0.1, 0.1), (0.1, 0.9)), ((0.1, 0.9), (0.5, 1)), ((0.5, 1), (0.9, 0.9)), ((0.9, 0.9), (0.9, 0.1)), ((0.9, 0.1), (0.5, 0)), ((0.5, 0), (0.1, 0.1))],
        "P": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.9, 0.9)), ((0.9, 0.9), (0.9, 0.6)), ((0.9, 0.6), (0.05, 0.5))], "R": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.9, 0.9)), ((0.9, 0.9), (0.9, 0.6)), ((0.9, 0.6), (0.05, 0.5)), ((0.3, 0.5), (0.95, 0))],
        "S": [((0.9, 0.9), (0.1, 1)), ((0.1, 1), (0.1, 0.55)), ((0.1, 0.55), (0.9, 0.45)), ((0.9, 0.45), (0.9, 0)), ((0.9, 0), (0.1, 0.1))], "T": [((0.5, 0), (0.5, 1)), ((0, 1), (1, 1))],
        "V": [((0, 1), (0.5, 0)), ((0.5, 0), (1, 1))], "X": [((0, 0), (1, 1)), ((0, 1), (1, 0))], "Q": [((0.1, 0.1), (0.1, 0.9)), ((0.1, 0.9), (0.9, 0.9)), ((0.9, 0.9), (0.9, 0.1)), ((0.9, 0.1), (0.1, 0.1)), ((0.6, 0.3), (1, -0.1))],
        "G": [((1, 0.9), (0.1, 1)), ((0.05, 1), (0.05, 0)), ((0.1, 0), (0.95, 0.1)), ((0.95, 0.1), (0.95, 0.5)), ((0.95, 0.5), (0.55, 0.5))], "B": [((0.05, 0), (0.05, 1)), ((0.05, 1), (0.8, 0.8)), ((0.8, 0.8), (0.05, 0.5)), ((0.05, 0.5), (0.9, 0.25)), ((0.9, 0.25), (0.05, 0))],
        "H": [((0.05, 0), (0.05, 1)), ((0.95, 0), (0.95, 1)), ((0.05, 0.5), (0.95, 0.5))],
    }
    x = x0
    for ch in text:
        if ch == " ":
            x += height * 0.5
            continue
        w = height * (0.25 if ch == "I" else 0.62)
        for (ax, az), (bx, bz) in glyphs.get(ch, []):
            pa, pb = (x + ax * w, z0 + az * height), (x + bx * w, z0 + bz * height)
            dx, dz = pb[0] - pa[0], pb[1] - pa[1]
            m = math.hypot(dx, dz) or 1.0
            px, pz = -dz / m * s / 2, dx / m * s / 2
            mb.quad((pa[0] - px, y, pa[1] - pz), (pa[0] + px, y, pa[1] + pz), (pb[0] + px, y, pb[1] + pz), (pb[0] - px, y, pb[1] - pz), mat, (0, -1, 0))
        x += w + height * 0.16
    del depth
    return x


# ----------------------------------------------------------------- water --
@item("lacus_republic", REP, 1.6, True, "Public basins (lacus) fed by the republican aqueducts; slab basin with spout stone as catalogued at Pompeii", "fountain", seats=4)
def lacus_republic(mb):
    fresh(mb)
    hx, hy, h, t = 0.95, 0.75, 0.78, 0.16
    for x0, x1, y0, y1 in ((-hx, hx, -hy, -hy + t), (-hx, hx, hy - t, hy), (-hx, -hx + t, -hy + t, hy - t), (hx - t, hx, -hy + t, hy - t)):
        slab_box(mb, x0, x1, y0, y1, 0.0, h, "tuff")
    mb.quad((-hx + t, -hy + t, 0.6), (hx - t, -hy + t, 0.6), (hx - t, hy - t, 0.6), (-hx + t, hy - t, 0.6), "water", (0, 0, 1))
    mb.quad((-hx + t, -hy + t, 0.1), (hx - t, -hy + t, 0.1), (hx - t, hy - t, 0.1), (-hx + t, hy - t, 0.1), "tuff", (0, 0, 1), ao=0.5)
    for sx in (-1, 1):   # iron clamps across the slab joints
        for sy in (-1, 1):
            slab_box(mb, sx * hx - 0.1, sx * hx + 0.1, sy * (hy - 0.05) - 0.025, sy * (hy - 0.05) + 0.025, h, h + 0.015, "iron")
    slab_box(mb, -0.22, 0.22, hy, hy + 0.3, 0.0, 1.25, "tuff", skip="z-")
    mb.lathe(0.0, hy - 0.02, [(0.0, 0.0), (0.13, 0.0), (0.15, 0.02)], 8, "tuff") if False else None
    for i in range(8):   # rosette relief on the spout stone
        t0, t1 = math.tau * i / 8, math.tau * (i + 1) / 8
        mb.face([(0, hy - 0.03, 1.0), (0.14 * math.cos(t0), hy - 0.01, 1.0 + 0.14 * math.sin(t0)), (0.14 * math.cos(t1), hy - 0.01, 1.0 + 0.14 * math.sin(t1))], "tuff", (0, -1, 0), ao=0.8)
    tube(mb, (0, hy + 0.02, 0.98), (0, hy - 0.3, 0.9), 0.025, 0.025, 5, "iron")
    tube(mb, (0, hy - 0.3, 0.9), (0, hy - 0.32, 0.62), 0.012, 0.03, 5, "water")


@item("lacus_imperial", IMP, 1.8, True, "Agrippa's programme of 33 BC: 700 lacus and 500 salientes (Pliny, NH 36.121)", "fountain", seats=4)
def lacus_imperial(mb):
    fresh(mb)
    hx, hy, h, t = 1.1, 0.85, 0.85, 0.14
    for x0, x1, y0, y1 in ((-hx, hx, -hy, -hy + t), (-hx, hx, hy - t, hy), (-hx, -hx + t, -hy + t, hy - t), (hx - t, hx, -hy + t, hy - t)):
        slab_box(mb, x0, x1, y0, y1, 0.12, h, "travertine")
    slab_box(mb, -hx - 0.12, hx + 0.12, -hy - 0.12, hy + 0.12, 0.0, 0.12, "travertine")
    slab_box(mb, -hx - 0.05, hx + 0.05, -hy - 0.05, hy + 0.05, h - 0.1, h, "travertine", skip="z-")
    mb.quad((-hx + t, -hy + t, 0.68), (hx - t, -hy + t, 0.68), (hx - t, hy - t, 0.68), (-hx + t, hy - t, 0.68), "water", (0, 0, 1))
    mb.quad((-hx + t, -hy + t, 0.2), (hx - t, -hy + t, 0.2), (hx - t, hy - t, 0.2), (-hx + t, hy - t, 0.2), "travertine", (0, 0, 1), ao=0.5)
    slab_box(mb, -0.3, 0.3, hy, hy + 0.34, 0.0, 1.5, "marble", skip="z-")
    slab_box(mb, -0.36, 0.36, hy - 0.04, hy + 0.38, 1.5, 1.62, "marble", skip="")
    # mask spout: head with open mouth
    mb.lathe(0.0, hy - 0.02, [(0.0, 0.0), (0.0, 0.0)], 3, "marble") if False else None
    for i in range(10):
        t0, t1 = math.tau * i / 10, math.tau * (i + 1) / 10
        mb.face([(0, hy - 0.12, 1.12), (0.2 * math.cos(t0), hy, 1.12 + 0.24 * math.sin(t0)), (0.2 * math.cos(t1), hy, 1.12 + 0.24 * math.sin(t1))], "marble", (0, -1, 0), smooth=True)
    tube(mb, (0, hy - 0.1, 1.02), (0, hy - 0.34, 0.98), 0.03, 0.03, 6, "bronze")
    tube(mb, (0, hy - 0.34, 0.98), (0, hy - 0.37, 0.7), 0.012, 0.035, 5, "water")


@item("meta_sudans", IMP, 8.2, True, "Flavian conical fountain beside the amphitheatre, Domitianic (c. AD 89-96); about 17 m high, basin about 16 m wide", "fountain", seats=16, era_id="building.meta_sudans")
def meta_sudans(mb):
    fresh(mb)
    seg = 32
    mb.lathe(0, 0, [(8.3, 0.0), (8.3, 0.25), (8.0, 0.25), (8.0, 1.15), (7.9, 1.25), (7.6, 1.25), (7.6, 0.3)], seg, "marble")
    mb.lathe(0, 0, [(7.6, 1.0), (3.6, 1.0)], seg, "water")
    mb.lathe(0, 0, [(7.6, 0.3), (3.6, 0.3)], seg, "travertine", ao=0.5)
    # drum with niches, then the "sweating" cone
    mb.lathe(0, 0, [(3.6, 0.0), (3.6, 0.6), (3.45, 0.7), (3.45, 4.2), (3.6, 4.3), (3.6, 4.55), (3.3, 4.7)], seg, "marble")
    mb.lathe(0, 0, [(3.3, 4.7), (2.9, 7.5), (2.3, 10.5), (1.6, 13.4), (0.95, 15.6), (0.8, 15.8), (0.9, 16.0), (0.55, 16.6), (0.0, 17.1)], seg, "brick")
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        c, s = math.cos(a), math.sin(a)
        tx, ty = -s, c
        for dz, w, hgt, mat, ao in ((1.4, 0.55, 2.2, "arch_shadow", 1.0),):
            p = lambda u, z, rr=3.47: (rr * c + tx * u, rr * s + ty * u, z)
            mb.quad(p(-w, dz), p(w, dz), p(w, dz + hgt), p(-w, dz + hgt), mat, (c, s, 0), ao=ao)
        mb.lathe(3.9 * c, 3.9 * s, [(0.0, 1.0), (0.05, 1.0), (0.03, 2.1), (0.0, 2.1)], 5, "water")
    mb.lathe(0, 0, [(0.25, 17.0), (0.32, 17.35), (0.0, 17.75)], 10, "bronze_gilt")


# ---------------------------------------------------------------- shrines --
@item("compital_shrine_republic", REP, 1.2, True, "Crossroads shrines of the Lares Compitales (Compitalia); painted masonry aedicula with altar", "shrine", seats=3)
def shrine_republic(mb):
    fresh(mb)
    slab_box(mb, -0.75, 0.75, -0.1, 0.5, 0.0, 1.1, "tuff")
    slab_box(mb, -0.8, 0.8, -0.15, 0.55, 1.1, 1.22, "tuff", skip="")
    for sx in (-1, 1):
        slab_box(mb, sx * 0.7 - 0.09, sx * 0.7 + 0.09, -0.08, 0.5, 1.22, 2.25, "plaster")
    slab_box(mb, -0.79, 0.79, 0.42, 0.5, 1.22, 2.25, "plaster")
    mb.quad((-0.6, 0.41, 1.3), (0.6, 0.41, 1.3), (0.6, 0.41, 2.2), (-0.6, 0.41, 2.2), "paint_red", (0, -1, 0))
    # two painted Lares and a serpent band
    for sx in (-1, 1):
        mb.lathe(sx * 0.3, 0.405, [(0.0, 1.42), (0.09, 1.42), (0.06, 1.75), (0.1, 1.78), (0.05, 1.98), (0.0, 2.0)], 6, "paint_ochre", a0=math.pi, a1=math.tau, sy=0.15)
    mb.quad((-0.55, 0.405, 1.32), (0.55, 0.405, 1.32), (0.55, 0.405, 1.38), (-0.55, 0.405, 1.38), "paint_black", (0, -1, 0))
    # tiled gable roof
    for sx in (-1, 1):
        mb.quad((0.0, -0.3, 2.75), (0.0, 0.6, 2.75), (sx * 0.95, 0.6, 2.2), (sx * 0.95, -0.3, 2.2), "roof_tile", (sx, 0, 2))
    mb.face([(-0.9, -0.2, 2.25), (0.9, -0.2, 2.25), (0.0, -0.2, 2.72)], "plaster", (0, -1, 0))
    # altar in front
    moulded_block(mb, 0.28, 0.24, 0.0, 0.85, "tuff")
    for v in mb.verts[-0:]:
        pass


@item("altar_tuff", BOTH, 0.6, True, "Street altars for offerings, tuff with pulvini", "shrine", seats=2)
def altar_tuff(mb):
    fresh(mb)
    moulded_block(mb, 0.34, 0.3, 0.0, 0.95, "tuff")
    for sx in (-1, 1):
        tube(mb, (sx * 0.3, -0.3, 1.0), (sx * 0.3, 0.3, 1.0), 0.07, 0.07, 7, "tuff")
    mb.lathe(0, 0, [(0.16, 0.95), (0.18, 1.0), (0.0, 0.97)], 8, "bronze")


@item("compital_shrine_imperial", IMP, 1.5, True, "Lares Augusti after the reorganisation of the vici in 7 BC; marble aedicula with altar", "shrine", seats=4)
def shrine_imperial(mb):
    fresh(mb)
    slab_box(mb, -1.0, 1.0, -0.2, 0.9, 0.0, 0.25, "travertine")
    slab_box(mb, -0.9, 0.9, -0.1, 0.8, 0.25, 1.2, "marble")
    slab_box(mb, -0.95, 0.95, -0.15, 0.85, 1.2, 1.32, "marble", skip="")
    for sx in (-1, 1):
        column(mb, sx * 0.72, 0.05, 1.32, 1.7, 0.1, "marble", 8)
    slab_box(mb, -0.85, 0.85, 0.55, 0.8, 1.32, 3.0, "marble")
    mb.quad((-0.55, 0.54, 1.45), (0.55, 0.54, 1.45), (0.55, 0.54, 2.85), (-0.55, 0.54, 2.85), "paint_red", (0, -1, 0))
    for sx in (-1, 0, 1):
        statues.statue(_sub(mb, sx * 0.34, 0.36, 1.32, 0.42 if sx else 0.5), 3 if sx == 0 else 0, pedestal=0.0, lod=1, mat="bronze", scale=1.0)
    slab_box(mb, -0.95, 0.95, -0.12, 0.85, 3.02, 3.2, "marble", skip="")
    for sx in (-1, 1):
        mb.quad((0.0, -0.14, 3.7), (0.0, 0.86, 3.7), (sx * 1.0, 0.86, 3.2), (sx * 1.0, -0.14, 3.2), "roof_tile", (sx, 0, 2))
    mb.face([(-0.95, -0.12, 3.2), (0.95, -0.12, 3.2), (0.0, -0.12, 3.68)], "marble", (0, -1, 0))
    lettering(mb, "LARIBVS AVG", -0.62, 3.05, 0.11, -0.125, "numeral_red")
    moulded_block(_sub(mb, 0.0, -0.9, 0.0, 1.0), 0.3, 0.26, 0.0, 0.9, "marble")


class _sub:
    """View of a MeshBuffer with a translated / scaled local frame."""

    def __init__(self, mb, dx, dy, dz, s=1.0, rot=0.0):
        self.mb, self.d, self.s, self.c, self.sn = mb, (dx, dy, dz), s, math.cos(rot), math.sin(rot)
        self.level_z, self.interior = -99, 1.0

    def _t(self, p):
        x, y, z = p[0] * self.s, p[1] * self.s, p[2] * self.s
        return (x * self.c - y * self.sn + self.d[0], x * self.sn + y * self.c + self.d[1], z + self.d[2])

    def face(self, pts, mat, n=None, **kw):
        if n is not None:
            n = (n[0] * self.c - n[1] * self.sn, n[0] * self.sn + n[1] * self.c, n[2])
        self.mb.face([self._t(p) for p in pts], mat, n, **kw)

    quad = lambda self, a, b, c, d, mat, n=None, **kw: self.face([a, b, c, d], mat, n, **kw)
    box = MeshBuffer.box
    lathe = MeshBuffer.lathe
    extrude_x = MeshBuffer.extrude_x


# ------------------------------------------------------------ way marking --
@item("milestone_republic", REP, 0.4, True, "Cylindrical milestones on the roads from the 2nd century BC; about 1.5 m high, 0.5 m diameter, square base", "")
def milestone_republic(mb):
    fresh(mb)
    slab_box(mb, -0.32, 0.32, -0.32, 0.32, 0.0, 0.3, "tuff")
    mb.lathe(0, 0, [(0.26, 0.3), (0.255, 1.7), (0.2, 1.8), (0.0, 1.82)], 12, "tuff")
    lettering(mb, "M P", -0.1, 1.3, 0.11, -0.262, "paint_black")
    lettering(mb, "VII", -0.09, 1.08, 0.13, -0.262, "paint_black")


@item("milestone_imperial", IMP, 0.4, True, "Imperial milestones with the emperor's titulature, numerals picked out in red", "")
def milestone_imperial(mb):
    fresh(mb)
    slab_box(mb, -0.34, 0.34, -0.34, 0.34, 0.0, 0.4, "travertine")
    mb.lathe(0, 0, [(0.27, 0.4), (0.265, 1.95), (0.3, 2.0), (0.3, 2.08), (0.0, 2.1)], 12, "marble")
    lettering(mb, "IMP CAES", -0.15, 1.62, 0.07, -0.272, "numeral_red")
    lettering(mb, "I", -0.02, 1.3, 0.2, -0.272, "numeral_red")


@item("stepping_stones", REP, 1.6, True, "Raised crossing stones between the kerbs; attested at Pompeii, used here for the unpaved-to-silex streets of the Republic", "")
def stepping_stones(mb):
    fresh(mb)
    for x in (-1.05, 0.0, 1.05):
        mb.lathe(x, 0, [(0.0, 0.0), (0.44, 0.0), (0.46, 0.2), (0.4, 0.27), (0.0, 0.28)], 8, "basalt", sx=1.0, sy=0.55)


@item("bollard_basalt", BOTH, 0.25, True, "Kerb-side guard stones protecting corners and fountains from cart wheels", "")
def bollard(mb):
    fresh(mb)
    mb.lathe(0, 0, [(0.2, 0.0), (0.18, 0.5), (0.12, 0.72), (0.0, 0.78)], 8, "basalt")


@item("cippus_amphitheatre", IMP, 0.45, True, "Travertine boundary stones around the amphitheatre pavement (five in situ on the east side), with sockets for barriers", "", era_id="building.amphitheatrum_flavium")
def cippus(mb):
    fresh(mb)
    hx, hy, h = 0.36, 0.28, 1.75
    slab_box(mb, -hx, hx, -hy, hy, 0.0, h - 0.25, "travertine", skip="z-z+")
    for i in range(6):   # rounded top
        t0, t1 = math.pi * i / 6, math.pi * (i + 1) / 6
        p = lambda t, y: (-hx * math.cos(t), y, h - 0.25 + 0.25 * math.sin(t))
        mb.quad(p(t0, -hy), p(t1, -hy), p(t1, hy), p(t0, hy), "travertine", (-math.cos((t0 + t1) / 2), 0, 1), smooth=True)
        for y, s in ((-hy, -1), (hy, 1)):
            mb.face([(0, y, h - 0.25), p(t0, y), p(t1, y)], "travertine", (0, s, 0))
    for z in (0.55, 0.85, 1.15, 1.42):   # four sockets on the face towards the building
        slab_box(mb, -0.07, 0.07, hy - 0.001, hy + 0.004, z, z + 0.1, "arch_shadow", skip="")


# ---------------------------------------------------------------- seating --
@item("bench_wood", REP, 1.0, True, "Plain timber benches outside houses and shops", "bench", seats=3)
def bench_wood(mb):
    fresh(mb)
    slab_box(mb, -0.9, 0.9, -0.2, 0.2, 0.42, 0.48, "wood", skip="")
    for sx in (-1, 1):
        slab_box(mb, sx * 0.75 - 0.04, sx * 0.75 + 0.04, -0.18, 0.18, 0.0, 0.42, "wood")
    slab_box(mb, -0.75, 0.75, -0.03, 0.03, 0.14, 0.22, "wood_dark", skip="")


@item("bench_tuff", REP, 1.1, True, "Masonry benches against house fronts, as at Pompeii", "bench", seats=3)
def bench_tuff(mb):
    fresh(mb)
    slab_box(mb, -1.0, 1.0, -0.22, 0.22, 0.0, 0.36, "tuff")
    slab_box(mb, -1.04, 1.04, -0.26, 0.26, 0.36, 0.45, "tuff", skip="")


@item("bench_marble_exedra", IMP, 1.9, True, "Curved public seat (schola) with lion-paw ends, a form known from Pompeian tomb benches", "bench", seats=5)
def bench_exedra(mb):
    fresh(mb)
    n, r0, r1 = 10, 1.2, 1.75
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        p = lambda rr, a, z: (rr * math.cos(a), rr * math.sin(a) - 0.6, z)
        am = (a0 + a1) / 2
        mb.quad(p(r0, a0, 0.45), p(r0, a1, 0.45), p(r1 - 0.2, a1, 0.45), p(r1 - 0.2, a0, 0.45), "marble", (0, 0, 1))
        mb.quad(p(r0, a0, 0.0), p(r0, a1, 0.0), p(r0, a1, 0.45), p(r0, a0, 0.45), "marble", (-math.cos(am), -math.sin(am), 0), ao=0.85)
        mb.quad(p(r1 - 0.2, a0, 0.45), p(r1 - 0.2, a1, 0.45), p(r1 - 0.12, a1, 1.0), p(r1 - 0.12, a0, 1.0), "marble", (-math.cos(am), -math.sin(am), 0.2))
        mb.quad(p(r1, a0, 0.0), p(r1, a1, 0.0), p(r1, a1, 1.0), p(r1, a0, 1.0), "marble", (math.cos(am), math.sin(am), 0))
        mb.quad(p(r1 - 0.12, a0, 1.0), p(r1 - 0.12, a1, 1.0), p(r1, a1, 1.0), p(r1, a0, 1.0), "marble", (0, 0, 1))
    for sx in (-1, 1):   # lion-paw terminals
        slab_box(mb, sx * 1.2 if sx > 0 else -1.75, 1.75 if sx > 0 else -1.2, -0.72, -0.6, 0.0, 1.0, "marble")
        mb.lathe(sx * 1.47, -0.78, [(0.0, 0.0), (0.16, 0.0), (0.12, 0.14), (0.14, 0.3), (0.0, 0.34)], 6, "marble")


# ---------------------------------------------------------------- commerce --
def _stall(mb, cloth, counter, goods):
    fresh(mb)
    for sx in (-1, 1):
        for sy, h in ((-0.75, 2.05), (0.75, 2.45)):
            tube(mb, (sx * 1.15, sy, 0.0), (sx * 1.15, sy, h), 0.04, 0.035, 5, "wood_dark")
        tube(mb, (sx * 1.15, -0.75, 2.05), (sx * 1.15, 0.75, 2.45), 0.03, 0.03, 4, "wood_dark")
    n = 6
    for i in range(n):   # sagging awning
        f0, f1 = i / n, (i + 1) / n
        z = lambda f, x: 2.05 + 0.4 * f - 0.12 * math.sin(math.pi * f) - 0.05 * (1 - abs(x) / 1.3)
        y = lambda f: -1.0 + 1.9 * f
        mb.quad((-1.3, y(f0), z(f0, -1.3)), (0.0, y(f0), z(f0, 0)), (0.0, y(f1), z(f1, 0)), (-1.3, y(f1), z(f1, -1.3)), cloth, (0, 0, 1))
        mb.quad((0.0, y(f0), z(f0, 0)), (1.3, y(f0), z(f0, 1.3)), (1.3, y(f1), z(f1, 1.3)), (0.0, y(f1), z(f1, 0)), cloth, (0, 0, 1))
    for i in range(8):   # scalloped valance
        x0, x1 = -1.3 + i * 0.325, -1.3 + (i + 1) * 0.325
        mb.face([(x0, -1.0, 2.0), (x1, -1.0, 2.0), ((x0 + x1) / 2, -1.0, 1.82)], cloth, (0, -1, 0))
    if counter == "wood":
        slab_box(mb, -1.1, 1.1, -0.55, 0.05, 0.82, 0.88, "wood", skip="")
        for sx in (-1, 1):
            tube(mb, (sx * 0.95, -0.45, 0.0), (sx * 0.8, -0.05, 0.82), 0.035, 0.035, 4, "wood_dark")
            tube(mb, (sx * 0.95, -0.05, 0.0), (sx * 0.8, -0.45, 0.82), 0.035, 0.035, 4, "wood_dark")
    else:
        slab_box(mb, -1.1, 1.1, -0.6, 0.0, 0.0, 0.85, "plaster")
        slab_box(mb, -1.14, 1.14, -0.64, 0.04, 0.85, 0.92, "marble", skip="")
        mb.quad((-1.0, -0.601, 0.15), (1.0, -0.601, 0.15), (1.0, -0.601, 0.7), (-1.0, -0.601, 0.7), "paint_red", (0, -1, 0))
    top = 0.88 if counter == "wood" else 0.92
    if goods == 0:      # bread and fruit
        for i in range(5):
            mb.lathe(-0.85 + i * 0.3, -0.3, [(0.11, top), (0.12, top + 0.05), (0.0, top + 0.09)], 7, "paint_ochre")
        basket(mb, 0.75, -0.25, top, 0.2, "wood", "paint_red")
        basket(mb, 0.75, 0.5, 0.0, 0.26, "wood", "foliage")
    elif goods == 1:    # oil and wine
        for i in range(4):
            amphora_at(mb, -0.8 + i * 0.3, 0.45, 0.0, 0.95)
        for i in range(3):
            mb.lathe(-0.5 + i * 0.5, -0.28, [(0.05, top), (0.09, top + 0.08), (0.06, top + 0.18), (0.07, top + 0.2), (0.0, top + 0.2)], 7, "terracotta")
    else:               # textiles and pottery
        for i in range(3):
            slab_box(mb, -0.95 + i * 0.5, -0.55 + i * 0.5, -0.5, -0.1, top, top + 0.07 + 0.04 * i, ("canvas_red", "canvas_ochre", "canvas")[i], skip="z-")
        for i in range(4):
            mb.lathe(0.55 + (i % 2) * 0.28, -0.45 + (i // 2) * 0.3, [(0.06, top), (0.11, top + 0.1), (0.08, top + 0.2), (0.0, top + 0.2)], 7, "terracotta")
        tube(mb, (-1.15, 0.75, 2.2), (1.15, 0.75, 2.2), 0.02, 0.02, 4, "wood_dark")
        for i in range(4):
            mb.quad((-0.9 + i * 0.5, 0.74, 2.2), (-0.55 + i * 0.5, 0.74, 2.2), (-0.55 + i * 0.5, 0.74, 1.3), (-0.9 + i * 0.5, 0.74, 1.3), ("canvas_red", "canvas", "canvas_ochre", "canvas_purple")[i], (0, -1, 0))


for _g, _cloth in enumerate(("canvas", "canvas_ochre", "canvas_red")):
    item("stall_wood_%d" % _g, REP, 1.7, True, "Trestle stalls of street vendors under cloth awnings", "stall", seats=3)(lambda mb, g=_g, c=_cloth: _stall(mb, c, "wood", g))
    item("stall_masonry_%d" % _g, IMP, 1.7, True, "Vendor stalls with plastered, painted counters (imperial tabernae and thermopolia)", "stall", seats=3)(lambda mb, g=_g, c=_cloth: _stall(mb, c, "masonry", g))


@item("thermopolium_counter", IMP, 1.9, True, "L-shaped masonry bar counter with embedded dolia, marble-faced (Pompeii, Herculaneum, Ostia)", "tavern_seat", seats=4)
def thermopolium(mb):
    fresh(mb)
    for x0, x1, y0, y1 in ((-1.5, 1.5, -0.35, 0.35), (0.8, 1.5, 0.35, 1.7)):
        slab_box(mb, x0, x1, y0, y1, 0.0, 0.92, "plaster")
        slab_box(mb, x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0.92, 0.98, "marble", skip="")
    mb.quad((-1.4, -0.351, 0.12), (0.7, -0.351, 0.12), (0.7, -0.351, 0.8), (-1.4, -0.351, 0.8), "paint_ochre", (0, -1, 0))
    for i, (x, y) in enumerate(((-1.0, 0.0), (-0.3, 0.0), (0.4, 0.0), (1.15, 0.9))):
        mb.lathe(x, y, [(0.2, 0.985), (0.17, 0.985), (0.2, 0.7), (0.0, 0.62)], 10, "terracotta", ao=0.7)
    for i in range(3):   # stepped shelf for cups
        slab_box(mb, 0.85, 1.45, 1.75 + i * 0.01, 1.95, 0.98 + i * 0.16, 1.14 + i * 0.16, "plaster")


@item("amphora_group", BOTH, 0.7, True, "Transport amphorae leaning by shop doors and stalls", "")
def amphora_group(mb):
    fresh(mb)
    for x, y, s in ((-0.3, 0.0, 1.0), (0.05, 0.12, 0.92), (0.36, -0.05, 1.05), (0.1, -0.3, 0.85)):
        amphora_at(mb, x, y, 0.0, s)


@item("dolium", BOTH, 0.6, True, "Large storage jar (dolium) for wine, oil or grain", "")
def dolium(mb):
    fresh(mb)
    mb.lathe(0, 0, [(0.0, 0.0), (0.2, 0.0), (0.5, 0.35), (0.55, 0.65), (0.42, 0.95), (0.3, 1.02), (0.34, 1.08), (0.26, 1.08), (0.24, 0.9)], 12, "terracotta")


@item("cart_plaustrum", BOTH, 1.8, True, "Two-wheeled ox cart (plaustrum) with solid wheels", "cart_stop", seats=2)
def cart(mb):
    fresh(mb)
    slab_box(mb, -0.7, 0.7, -1.2, 1.2, 0.72, 0.8, "wood", skip="")
    for sx in (-1, 1):
        slab_box(mb, sx * 0.7 - 0.03, sx * 0.7 + 0.03, -1.2, 1.2, 0.8, 1.15, "wood")
        for i in range(12):   # solid disc wheel
            t0, t1 = math.tau * i / 12, math.tau * (i + 1) / 12
            for xo, s in ((0.82, 1), (0.9, 1), (0.82, -1)):
                pass
            w = lambda t, x: (sx * x, 0.55 * math.cos(t), 0.55 + 0.55 * math.sin(t))
            mb.face([(sx * 0.9, 0, 0.55), w(t0, 0.9), w(t1, 0.9)], "wood_dark", (sx, 0, 0))
            mb.face([(sx * 0.8, 0, 0.55), w(t0, 0.8), w(t1, 0.8)], "wood_dark", (-sx, 0, 0))
            mb.quad(w(t0, 0.8), w(t1, 0.8), w(t1, 0.9), w(t0, 0.9), "iron", (0, math.cos((t0 + t1) / 2), math.sin((t0 + t1) / 2)))
    tube(mb, (-0.85, 0, 0.55), (0.85, 0, 0.55), 0.05, 0.05, 6, "wood_dark")
    tube(mb, (0, -1.2, 0.74), (0, -3.0, 0.9), 0.045, 0.04, 5, "wood_dark")
    for x, y in ((-0.3, 0.5), (0.3, 0.4), (0.0, -0.4)):
        amphora_at(mb, x, y, 0.8, 0.8)


# ----------------------------------------------------------------- honour --
@item("columna_rostrata", REP, 1.2, True, "Rostral column in the manner of the column of C. Duilius (260 BC): shaft with ship's beaks, statue on top", "gossip_spot", seats=4)
def columna_rostrata(mb):
    fresh(mb)
    moulded_block(mb, 0.8, 0.8, 0.0, 1.4, "tuff")
    mb.lathe(0, 0, [(0.55, 1.4), (0.55, 1.55), (0.45, 1.65), (0.42, 4.0), (0.36, 6.3), (0.5, 6.5), (0.5, 6.65)], 14, "travertine")
    for i, z in enumerate((2.4, 3.5, 4.6)):
        for sx in (-1, 1):   # bronze rams
            tube(mb, (sx * 0.38, 0, z), (sx * 1.0, 0, z + 0.1), 0.13, 0.05, 6, "bronze")
            for dz in (-0.1, 0.0, 0.1):
                slab_box(mb, min(sx * 0.9, sx * 1.12), max(sx * 0.9, sx * 1.12), -0.02, 0.02, z + 0.08 + dz, z + 0.12 + dz, "bronze", skip="")
    statues.statue(_sub(mb, 0, 0, 6.65), 2, pedestal=0.0, mat="bronze", scale=1.1)
    lettering(mb, "C DVILIOS M F", -0.62, 0.75, 0.11, -0.801, "paint_black")


@item("honorific_column_imperial", IMP, 1.4, True, "Marble honorific column with gilded bronze statue", "gossip_spot", seats=5)
def honorific_column(mb):
    fresh(mb)
    slab_box(mb, -1.2, 1.2, -1.2, 1.2, 0.0, 0.3, "travertine")
    moulded_block(mb, 0.85, 0.85, 0.3, 2.1, "marble")
    mb.lathe(0, 0, [(0.62, 2.1), (0.64, 2.25), (0.5, 2.4), (0.5, 2.45), (0.48, 5.5), (0.42, 9.0), (0.47, 9.05), (0.42, 9.12), (0.44, 9.4),
                    (0.62, 9.7), (0.5, 9.72), (0.7, 10.0)], 18, "marble")
    slab_box(mb, -0.7, 0.7, -0.7, 0.7, 10.0, 10.18, "marble", skip="")
    statues.statue(_sub(mb, 0, 0, 10.18), 1, pedestal=0.0, mat="bronze_gilt", scale=1.35)
    lettering(mb, "S P Q R", -0.5, 1.25, 0.2, -0.852, "numeral_red")


for _v in range(4):
    item("statue_bronze_%d" % _v, REP, 0.8, True, "Honorific bronze statues on tuff bases in public places of the late Republic", "gossip_spot", seats=3, lod_tris=True)(
        lambda mb, v=_v: (fresh(mb), moulded_block(mb, 0.5, 0.5, 0.0, 1.2, "tuff"), statues.statue(_sub(mb, 0, 0, 1.2), v, pedestal=0.0, mat="bronze", scale=1.12)))
    item("statue_marble_%d" % _v, IMP, 0.9, True, "Marble statues on inscribed, moulded bases", "gossip_spot", seats=3)(
        lambda mb, v=_v: (fresh(mb), slab_box(mb, -0.75, 0.75, -0.75, 0.75, 0.0, 0.2, "travertine"), moulded_block(mb, 0.55, 0.55, 0.2, 1.8, "marble"),
                          lettering(mb, ("DIVO AVG", "VICTORIAE", "FORTVNAE", "GENIO P R")[v], -0.46, 1.1, 0.1, -0.551, "numeral_red"),
                          statues.statue(_sub(mb, 0, 0, 1.8), v, pedestal=0.0, mat="marble_statue", scale=1.3)))


@item("sundial_column", BOTH, 0.5, True, "Public sundial (hemicyclium) on a column; Rome had public dials from the 3rd century BC", "gossip_spot", seats=2)
def sundial(mb):
    fresh(mb)
    slab_box(mb, -0.35, 0.35, -0.35, 0.35, 0.0, 0.2, "travertine")
    column(mb, 0, 0, 0.2, 2.2, 0.16, "travertine", 10)
    slab_box(mb, -0.34, 0.34, -0.1, 0.34, 2.4, 2.95, "marble", skip="z-")
    for i in range(8):   # hollowed dial face with hour lines
        t0, t1 = math.pi + math.pi * i / 8, math.pi + math.pi * (i + 1) / 8
        mb.face([(0, -0.1, 2.93), (0.3 * math.cos(t0), -0.11 + 0.12 * abs(math.sin(t0)), 2.93 + 0.5 * math.sin(t0) * 0.9), (0.3 * math.cos(t1), -0.11 + 0.12 * abs(math.sin(t1)), 2.93 + 0.5 * math.sin(t1) * 0.9)],
                "marble", (0, -1, 0), ao=0.75 + 0.1 * (i % 2))
    tube(mb, (0, -0.1, 2.93), (0, -0.32, 2.93), 0.008, 0.008, 3, "bronze")


# ------------------------------------------------------------- shop fronts --
@item("shop_shutter", BOTH, 1.6, True, "Taberna front: grooved threshold with vertical plank shutters and a night door", "doorway", seats=2)
def shutter(mb):
    fresh(mb)
    slab_box(mb, -1.5, 1.5, -0.2, 0.2, 0.0, 0.12, "travertine")
    for i in range(7):
        slab_box(mb, -1.48 + i * 0.3, -1.2 + i * 0.3, -0.03 - 0.012 * (i % 2), 0.03 - 0.012 * (i % 2), 0.12, 2.5, "wood" if i % 3 else "wood_dark")
    tube(mb, (-1.5, -0.06, 1.3), (0.6, -0.06, 1.3), 0.02, 0.02, 4, "iron")


@item("shop_awning", BOTH, 1.6, False, "Cloth awnings and projecting timber lean-tos (pergulae, maeniana) over shop fronts", "")
def awning(mb):
    fresh(mb)
    for sx in (-1, 1):
        tube(mb, (sx * 1.5, 0.0, 2.3), (sx * 1.5, -1.3, 2.85), 0.035, 0.03, 4, "wood_dark")
    n = 5
    for i in range(n):
        f0, f1 = i / n, (i + 1) / n
        z = lambda f: 2.9 - 0.75 * f - 0.1 * math.sin(math.pi * f)
        mb.quad((-1.6, -1.35 * f0, z(f0)), (1.6, -1.35 * f0, z(f0)), (1.6, -1.35 * f1, z(f1)), (-1.6, -1.35 * f1, z(f1)), "canvas_red" if i % 2 else "canvas", (0, -1, 1))


for _i, (_txt, _bg) in enumerate((("VINA", "paint_ochre"), ("PANIS", "plaster"), ("OLEVM", "paint_red"))):
    item("shop_sign_%d" % _i, BOTH, 0.6, False, "Painted shop signs on boards and plaster panels", "")(
        lambda mb, t=_txt, b=_bg: (fresh(mb), slab_box(mb, -0.55, 0.55, -0.02, 0.02, 2.2, 2.65, "wood_dark", skip=""),
                                   mb.quad((-0.5, -0.022, 2.24), (0.5, -0.022, 2.24), (0.5, -0.022, 2.61), (-0.5, -0.022, 2.61), b, (0, -1, 0)),
                                   lettering(mb, t, -0.42, 2.32, 0.2, -0.024, "paint_black" if b != "paint_red" else "plaster")))


for _i, (_lines, _col) in enumerate(((("C IVLIVM AED", "O V F"), "numeral_red"), (("M HOLCONIVM", "II VIR ROG"), "paint_black"), (("GLAD PAR XX", "PVGNAB"), "numeral_red"))):
    item("dipinto_%d" % _i, BOTH if _i < 2 else IMP, 1.0, False, "Painted wall notices: electoral programmata in red or black and edicta munerum announcing gladiator shows (Pompeii)", "")(
        lambda mb, ls=_lines, c=_col: (fresh(mb), mb.quad((-0.95, -0.004, 1.35), (0.95, -0.004, 1.35), (0.95, -0.004, 2.15), (-0.95, -0.004, 2.15), "plaster", (0, -1, 0)),
                                       lettering(mb, ls[0], -0.88, 1.8, 0.24, -0.008, c), lettering(mb, ls[1], -0.7, 1.45, 0.2, -0.008, c)))


@item("garland_swag", BOTH, 1.6, False, "Festival garlands (serta) of leaves and ribbons hung between posts and across doorways", "")
def garland(mb):
    fresh(mb)
    n = 10
    pts = [(-1.5 + 3.0 * i / n, 0.0, 2.9 - 0.55 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    for a, b in zip(pts, pts[1:]):
        tube(mb, a, b, 0.07, 0.07, 5, "foliage")
    for i in (0, n // 2, n):
        mb.quad((pts[i][0] - 0.05, 0, pts[i][2]), (pts[i][0] + 0.05, 0, pts[i][2]), (pts[i][0] + 0.09, 0, pts[i][2] - 0.5), (pts[i][0] - 0.02, 0, pts[i][2] - 0.5), "canvas_red", (0, -1, 0))


@item("torch_post", BOTH, 0.3, True, "Free-standing cresset for festivals and night watch; regular street lighting is not attested", "guard_post")
def torch_post(mb):
    fresh(mb)
    mb.lathe(0, 0, [(0.18, 0.0), (0.16, 0.06), (0.05, 0.12), (0.04, 1.75), (0.07, 1.8)], 6, "iron")
    mb.lathe(0, 0, [(0.07, 1.8), (0.16, 1.95), (0.17, 2.1), (0.14, 2.1), (0.0, 1.95)], 7, "iron")
    tube(mb, (0, 0, 1.95), (0, 0, 2.25), 0.07, 0.03, 5, "wood_dark")


# ------------------------------------------------------------- architecture --
@item("portico_bay_republic", REP, 2.6, True, "Timber-posted lean-to portico with tiled roof shading shop fronts", "gossip_spot", seats=4, bay_width_m=4.0)
def portico_republic(mb):
    fresh(mb)
    for sx in (-1,):
        slab_box(mb, sx * 2.0 - 0.2, sx * 2.0 + 0.2, -1.7, -1.3, 0.0, 0.35, "tuff")
        slab_box(mb, sx * 2.0 - 0.11, sx * 2.0 + 0.11, -1.61, -1.39, 0.35, 3.1, "wood_dark", skip="z-")
        tube(mb, (sx * 2.0, -1.5, 2.5), (sx * 2.0 + 0.6, -1.5, 3.1), 0.05, 0.05, 4, "wood_dark")
        tube(mb, (sx * 2.0, -1.5, 3.1), (sx * 2.0, 1.5, 3.9), 0.07, 0.07, 4, "wood_dark")
    slab_box(mb, -2.0, 2.0, -1.6, -1.4, 3.1, 3.3, "wood_dark", skip="x-x+")
    mb.quad((-2.0, -1.85, 3.2), (2.0, -1.85, 3.2), (2.0, 1.5, 4.1), (-2.0, 1.5, 4.1), "roof_tile", (0, -1, 3))
    mb.quad((-2.0, -1.85, 3.14), (2.0, -1.85, 3.14), (2.0, 1.5, 4.04), (-2.0, 1.5, 4.04), "wood", (0, 1, -3), ao=0.6)
    mb.quad((-2.0, -1.5, 0.02), (2.0, -1.5, 0.02), (2.0, 1.5, 0.02), (-2.0, 1.5, 0.02), "basalt", (0, 0, 1), ao=0.8)


@item("portico_bay_imperial", IMP, 2.8, True, "Colonnaded portico (porticus) with travertine columns, architrave and tiled roof, giving shade along a piazza", "gossip_spot", seats=5, bay_width_m=4.0)
def portico_imperial(mb):
    fresh(mb)
    column(mb, -2.0, -1.6, 0.25, 4.0, 0.26, "travertine", 12)
    slab_box(mb, -2.0, 2.0, -1.9, 1.6, 0.0, 0.25, "travertine", skip="x-x+z-")
    slab_box(mb, -2.0, 2.0, -1.88, -1.32, 4.25, 4.75, "travertine", skip="x-x+")
    mb.extrude_x([(-1.9, 4.75), (-2.05, 4.82), (-2.05, 4.95), (-1.3, 4.95)], -2.0, 2.0, "travertine")
    mb.quad((-2.0, -2.1, 4.95), (2.0, -2.1, 4.95), (2.0, 1.6, 5.9), (-2.0, 1.6, 5.9), "roof_tile", (0, -1, 3))
    mb.quad((-2.0, -1.3, 4.75), (2.0, -1.3, 4.75), (2.0, 1.6, 5.75), (-2.0, 1.6, 5.75), "wood", (0, 1, -3), ao=0.55)
    slab_box(mb, -2.0, 2.0, 1.6, 1.9, 0.0, 5.95, "plaster", skip="x-x+z-")
    mb.quad((-2.0, 1.595, 0.25), (2.0, 1.595, 0.25), (2.0, 1.595, 1.5), (-2.0, 1.595, 1.5), "paint_red", (0, -1, 0), ao=0.8)


@item("drain_grate", BOTH, 0.5, False, "Stone drain cover with slots over the street sewer; gutters lead rainwater from the pavement", "")
def drain(mb):
    fresh(mb)
    slab_box(mb, -0.45, 0.45, -0.45, 0.45, 0.0, 0.03, "travertine_paving")
    for i in range(5):
        slab_box(mb, -0.3, 0.3, -0.34 + i * 0.16, -0.28 + i * 0.16, 0.03, 0.032, "arch_shadow", skip="z-")


# ------------------------------------------------------------------ plants --
def _crown(mb, z, r, h, mat, seg=9, lobes=5):
    mb.lathe(0, 0, [(0.0, z), (r * 0.75, z + h * 0.15), (r, z + h * 0.45), (r * 0.8, z + h * 0.8), (r * 0.35, z + h), (0.0, z + h * 1.02)], seg, mat)
    for i in range(lobes):
        a = math.tau * i / lobes + 0.4
        mb.lathe(r * 0.62 * math.cos(a), r * 0.62 * math.sin(a), [(0.0, z + h * 0.2), (r * 0.5, z + h * 0.45), (r * 0.42, z + h * 0.8), (0.0, z + h * 0.95)], 6, mat, ao=0.85 + 0.15 * (i % 2))


@item("tree_stone_pine", BOTH, 3.5, True, "Umbrella pine (Pinus pinea), planted in Rome since the Republic", "gossip_spot", seats=3, vegetation=True)
def stone_pine(mb):
    fresh(mb)
    tube(mb, (0, 0, 0), (0.25, 0.1, 5.0), 0.32, 0.22, 8, "bark")
    tube(mb, (0.25, 0.1, 5.0), (0.1, 0.0, 8.6), 0.22, 0.14, 7, "bark")
    for a, ln in ((0.3, 2.8), (2.2, 2.6), (4.1, 3.0), (5.4, 2.2)):
        tube(mb, (0.15, 0.05, 7.6), (0.15 + ln * math.cos(a), 0.05 + ln * math.sin(a), 9.2), 0.1, 0.05, 5, "bark")
    mb.lathe(0.1, 0.0, [(0.0, 8.9), (3.6, 9.0), (4.5, 9.6), (4.0, 10.5), (2.4, 11.2), (0.0, 11.5)], 12, "foliage_dark")
    for i in range(7):
        a = math.tau * i / 7
        mb.lathe(0.1 + 3.0 * math.cos(a), 3.0 * math.sin(a), [(0.0, 9.0), (1.6, 9.3), (1.9, 10.0), (1.1, 10.8), (0.0, 11.0)], 7, "foliage" if i % 2 else "foliage_dark")


@item("tree_cypress", BOTH, 1.2, True, "Mediterranean cypress (Cupressus sempervirens), common by sanctuaries and tombs", "", vegetation=True)
def cypress(mb):
    fresh(mb)
    tube(mb, (0, 0, 0), (0, 0, 1.2), 0.16, 0.12, 6, "bark")
    mb.lathe(0, 0, [(0.0, 0.9), (0.75, 1.3), (0.95, 3.0), (0.8, 6.0), (0.45, 8.5), (0.0, 10.2)], 9, "foliage_dark")


@item("shrub_laurel", BOTH, 0.9, False, "Bay laurel (Laurus nobilis) and myrtle as low planting", "", vegetation=True)
def laurel(mb):
    fresh(mb)
    tube(mb, (0, 0, 0), (0, 0, 0.5), 0.05, 0.04, 5, "bark")
    _crown(mb, 0.3, 0.8, 1.5, "foliage")


def material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    return m


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.data.collections.new("StreetFurniture")
    bpy.context.scene.collection.children.link(coll)
    for i, (name, fn, _lod) in enumerate(ITEMS):
        mb = MeshBuffer(name, tint_seed=i * 1.37)
        fn(mb)
        mb.to_object(coll, material)
        CATALOG[name]["triangles"] = mb.triangles()
        zs = [v[2] for v in mb.verts]
        xs = [v[0] for v in mb.verts]
        ys = [v[1] for v in mb.verts]
        CATALOG[name]["bounds_m"] = [round(max(xs) - min(xs), 2), round(max(zs) - min(zs), 2), round(max(ys) - min(ys), 2)]
    for o in coll.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = coll.objects[0]
    path = os.path.join(OUT, "street_furniture.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_cameras=False, export_lights=False, export_animations=False)
    catalog = {"format": "imperathen-street-furniture-catalog", "schema": 1,
               "era_sets": {"late_republic": "decor.street_furniture.late_republic", "imperial": "decor.street_furniture.imperial",
                            "both": "usable in either set"},
               "front": "+Z in Godot (-Y in Blender)", "items": CATALOG}
    with open(os.path.join(OUT, "street_furniture_catalog.json"), "w") as fh:
        json.dump(catalog, fh, indent=1, sort_keys=True)
    print("STREET_FURNITURE_BUILD_COMPLETE", json.dumps({"items": len(ITEMS), "triangles": sum(c["triangles"] for c in CATALOG.values()), "bytes": os.path.getsize(path)}))


main()
