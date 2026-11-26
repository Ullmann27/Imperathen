"""Original household furniture and prop kit for Valdora interiors.

Valdora lies near Aquileia in Cisalpine Gaul, campaign year 58 BC. The kit
follows rural Late Republican and Late La Tene material culture; see
docs/35_interiors/INTERIORS.md for sources and design assumptions.

    blender -b --factory-startup --python-exit-code 1 -P art/interiors/build_interior_kit.py [-- --preview out.png]

Writes prototype/assets/interiors/interior_kit.glb (one mesh object per prop,
shared material slots named INT_<material>) and kit_manifest.json with each
prop's bounds and triangle count. Godot assigns the tiling PBR materials.
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
DEST = ROOT / "prototype/assets/interiors"
sys.path.insert(0, str(SOURCE))
import kit_geometry as kg  # noqa: E402
from kit_geometry import Prop, T, R, S, WHITE  # noqa: E402

MANIFEST = json.loads((DEST / "textures/manifest.json").read_text())
kg.TILE.update({k: v["tile_metres"] for k, v in MANIFEST["materials"].items()})
ORDER = list(MANIFEST["materials"])
PREVIEW = {"oak": (.44, .31, .20), "wood_rough": (.50, .42, .33), "wicker": (.59, .45, .28), "straw": (.74, .63, .38),
           "linen": (.78, .72, .60), "wool": (.84, .80, .72), "leather": (.42, .25, .14), "terracotta": (.71, .42, .27),
           "coarseware": (.36, .31, .27), "iron": (.30, .28, .27), "bronze": (.60, .45, .26), "stone": (.61, .58, .52),
           "food": (.89, .77, .56), "hearth_clay": (.60, .50, .41), "embers": (.12, .10, .09)}

# Dyes plausible for Late Iron Age / Republican textiles (madder/kermes reds,
# weld yellow, woad blue, undyed sheep browns). Linear multipliers on wool.
DYE = {"madder": (.70, .28, .20), "ochre": (.80, .60, .32), "woad": (.36, .45, .58), "natural": (1, .97, .90),
       "brown": (.52, .40, .30), "green": (.52, .58, .36), "grey": (.70, .70, .68)}
def SOOT(top, dark, base=0.0):
    """Darken a vessel towards its fire-blackened base."""
    return lambda p: tuple(dark + (1 - dark) * min(1.0, max(0.0, (p.z - base) / top)) for _ in range(3))


def mat_preview(name):
    m = bpy.data.materials.new("INT_" + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*PREVIEW[name], 1)
    info = MANIFEST["materials"][name]
    bsdf.inputs["Roughness"].default_value = info["roughness"]
    bsdf.inputs["Metallic"].default_value = info["metallic"]
    m.diffuse_color = (*PREVIEW[name], 1)
    return m


# --------------------------------------------------------------------------
# Vessels: profiles are (radius, z) outside up, then inside down.
def vessel(p: Prop, outer, wall, mat, M=kg.I4, sides=24, color=WHITE, floor=None):
    """Hollow vessel: outer profile up, inner wall down to a floor (default: the
    second profile point, giving a base as thick as the first step)."""
    floor = outer[1][1] if floor is None else floor
    inner = [(outer[-1][0] - wall, outer[-1][1])]
    for (r0, z0), (r1, z1) in zip(reversed(outer[1:]), reversed(outer[:-1])):
        if z1 <= floor < z0 or (z1 < floor and z0 <= floor):
            f = (floor - z0) / (z1 - z0) if z1 != z0 else 0.0
            inner.append((max(r0 + (r1 - r0) * f - wall, .002), floor))
            break
        if (r1, z1) != outer[0]:
            inner.append((max(r1 - wall, .002), z1))
        else:
            inner.append((max(r1 - wall, .002), floor))
    p.lathe(list(outer) + inner, mat, M, sides, True, True, color)


def jar_profile(h, r, mouth, foot=.55):
    return [(r * foot, 0), (r * .85, h * .06), (r, h * .38), (r * .93, h * .62), (mouth * 1.25, h * .84),
            (mouth, h * .9), (mouth * 1.12, h * .96), (mouth * 1.12, h)]


def cup(p: Prop, x, y, z, r=.042, h=.085, mat="terracotta", color=WHITE):
    vessel(p, [(r * .62, 0), (r * .68, .006), (r * .92, h * .35), (r, h * .8), (r * 1.02, h)], .004, mat, T(x, y, z), 16, color)


def bowl(p: Prop, x, y, z, r=.10, h=.055, mat="terracotta", color=WHITE):
    vessel(p, [(r * .45, 0), (r * .5, .004), (r * .82, h * .45), (r, h)], .006, mat, T(x, y, z), 20, color)


def plate(p: Prop, x, y, z, r=.12, color=WHITE, mat="terracotta"):
    vessel(p, [(r * .55, 0), (r * .6, .005), (r * .95, .022), (r, .03)], .006, mat, T(x, y, z), 22, color)


def jug(p: Prop, x, y, z, h=.27, r=.085, mat="terracotta", color=WHITE, yaw=0.0):
    M = T(x, y, z) @ R("Z", yaw)
    vessel(p, [(r * .6, 0), (r * .75, .01), (r, h * .35), (r * .9, h * .58), (r * .42, h * .78), (r * .38, h * .9),
               (r * .5, h * .97), (r * .52, h)], .005, mat, M, 20, color)
    pts = [M @ Vector((r * .42, 0, h * .9)), M @ Vector((r * 1.05, 0, h * .92)), M @ Vector((r * 1.25, 0, h * .75)),
           M @ Vector((r * 1.08, 0, h * .55)), M @ Vector((r * .9, 0, h * .5))]
    p.tube(pts, .011, mat, 6, color)


def loaf(p: Prop, x, y, z, r=.10, h=.075, color=(.66, .44, .25), seed=1):
    def scored(q):
        a = math.atan2(q.y - y, q.x - x)
        line = abs(math.sin(a * 4))
        top = max(0.0, (q.z - z) / h)
        k = .55 + .45 * min(1.0, line * 6) if top > .55 else 1.0
        return tuple(c * k for c in color)
    p.blob((x, y, z + h * .5 * .15), (r, r, h * .5), "food", seg=20, rings=10, exponent=.8, noise=.05, color=scored, seed=seed, flat_bottom=True)


def scroll(p: Prop, a, b, r=.024, color=(.86, .79, .62)):
    p.rod(a, b, r, "linen", sides=12, color=color)
    for end in (a, b):
        d = (Vector(b) - Vector(a)).normalized() * .012
        e = Vector(end) + (d if end is b else -d)
        p.rod(end, e, .009, "oak", sides=8, color=(.4, .3, .2))


# --------------------------------------------------------------------------
# Furniture
def bed_simple(name, dye, tick=(.92, .86, .74)):
    p = Prop(name, .006)
    L, W = 1.96, .90
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = .66 if sx < 0 else .40
            p.box((sx * (L / 2 - .04), sy * (W / 2 - .04), h / 2), (.075, .075, h), "oak")
        p.box((sx * (L / 2 - .035), 0, .31), (.05, W - .1, .12), "oak")
    for sy in (-1, 1):
        p.box((0, sy * (W / 2 - .03), .31), (L - .1, .05, .13), "oak")
    p.box((-L / 2 + .04, 0, .56), (.045, W - .08, .17), "oak")
    for i in range(7):
        p.box((-L / 2 + .2 + i * (L - .4) / 6, 0, .3825), (.10, W - .1, .025), "wood_rough")
    # Straw-stuffed linen tick on the boards.
    p.blob((0, 0, .395 + .07), (L / 2 - .05, W / 2 - .05, .07), "linen", seg=28, rings=10, exponent=.22, color=tick, seed=3)
    top = .395 + .14
    x0, x1 = -L / 2 + .55, L / 2 + .03

    def blanket(s, t):
        x = x0 + (x1 - x0) * s
        side = W / 2 + .035
        seg = [(-side, top - .22), (-side + .02, top - .02), (-side + .07, top + .012), (side - .07, top + .012),
               (side - .02, top - .02), (side, top - .22)]
        lengths = [math.dist(seg[k], seg[k + 1]) for k in range(len(seg) - 1)]
        d = t * sum(lengths)
        k = 0
        while k < len(lengths) - 1 and d > lengths[k]:
            d -= lengths[k]
            k += 1
        f = d / lengths[k]
        yy = seg[k][0] + (seg[k + 1][0] - seg[k][0]) * f
        zz = seg[k][1] + (seg[k + 1][1] - seg[k][1]) * f
        wave = math.sin(s * 9.0 + t * 3.0) * .008 + math.sin(s * 23 + 1.3) * .004
        if k in (0, len(lengths) - 1):
            yy += math.copysign(.006, yy) * math.sin(s * 17)
            zz += .01 * math.sin(s * 13)
        else:
            zz += wave
        if x > L / 2 - .01:
            zz -= (x - (L / 2 - .01)) * 6
        return (x, yy, zz)
    p.sheet(blanket, 18, 14, .012, "wool", x1 - x0, W + .5, DYE[dye])
    # Fold-back hem at the head end of the blanket.
    p.blob((x0 + .03, 0, top + .015), (.05, W / 2 + .02, .018), "wool", seg=16, rings=6, exponent=.35, color=DYE[dye], seed=5)
    p.blob((-L / 2 + .24, 0, top + .045), (.15, .30, .055), "linen", seg=20, rings=8, exponent=.4, color=(.95, .92, .84), seed=7)
    return p


def bed_fine():
    p = Prop("bed_fine", .005)
    L, W = 2.02, .98
    for sx in (-1, 1):
        for sy in (-1, 1):
            # Turned legs, a Late Republican lectus type (design assumption for Valdora).
            p.lathe([(.035, 0), (.045, .03), (.03, .09), (.05, .16), (.028, .24), (.045, .30), (.04, .36)], "oak",
                    T(sx * (L / 2 - .06), sy * (W / 2 - .06), 0), 14, True, True)
    for sy in (-1, 1):
        p.box((0, sy * (W / 2 - .035), .40), (L - .06, .06, .09), "oak")
    for sx in (-1, 1):
        p.box((sx * (L / 2 - .035), 0, .40), (.06, W - .1, .09), "oak")
    p.box((0, 0, .44), (L - .14, W - .14, .02), "wood_rough")
    # Head rest (fulcrum) with a bronze medallion.
    pts = [Vector((-L / 2 + .05, -W / 2 + .07, .45)), Vector((-L / 2 + .02, -W / 2 + .07, .62)), Vector((-L / 2 + .10, -W / 2 + .07, .78)),
           Vector((-L / 2 + .26, -W / 2 + .07, .84))]
    for sy in (0, W - .14):
        p.tube([q + Vector((0, sy, 0)) for q in pts], .028, "oak", 8)
        p.cylinder(.032, .032, .012, "bronze", T(-L / 2 + .03, -W / 2 + .07 + sy, .70) @ R("Y", math.pi / 2) @ R("X", 0), 16)
    p.box((-L / 2 + .06, 0, .63), (.04, W - .16, .28), "oak")
    p.blob((0, 0, .45 + .08), (L / 2 - .08, W / 2 - .08, .08), "wool", seg=28, rings=10, exponent=.22, color=(.86, .80, .70), seed=11)
    top = .45 + .16

    def cover(s, t):
        x = -L / 2 + .45 + (L / 2 + .02 - (-L / 2 + .45)) * s
        y = (-W / 2 - .03) + (W + .06) * t
        z = top + .01 + .006 * math.sin(s * 11 + t * 5)
        edge = min(t, 1 - t)
        if edge < .08:
            z -= (.08 - edge) * 2.6
        return (x, y, z)
    p.sheet(cover, 16, 14, .01, "wool", L, W, DYE["madder"])
    p.blob((-L / 2 + .27, 0, top + .06), (.16, .34, .065), "linen", seg=20, rings=8, exponent=.4, color=(.97, .94, .86), seed=12)
    return p


def pallet(name, dye):
    p = Prop(name, .0)
    p.blob((0, 0, .055 * .15), (.90, .38, .055), "straw", seg=24, rings=8, exponent=.25, seed=21, color=(.92, .86, .70), flat_bottom=True)

    def cover(s, t):
        x = -.45 + 1.25 * s
        y = -.40 + .80 * t
        z = .068 + .02 * math.sin(s * 7 + 1.0) * math.sin(t * 5) + .015 * math.sin(s * 19)
        if t < .1 or t > .9:
            z -= .05 * (abs(t - .5) - .4) * 10
        return (x, y, max(z, .022))
    p.sheet(cover, 14, 10, .01, "wool", 1.25, .8, DYE[dye])
    p.blob((-.70, 0, .095), (.12, .24, .045), "linen", seg=16, rings=6, exponent=.45, color=(.9, .86, .76), seed=22)
    return p


def bench(name="bench_plain", L=1.40):
    p = Prop(name, .006)
    p.box((0, 0, .425), (L, .30, .055), "oak")
    for sx in (-1, 1):
        p.box((sx * (L / 2 - .17), 0, .20), (.055, .26, .40), "oak", grain=(0, 0, 1))
        p.box((sx * (L / 2 - .17), 0, .01), (.07, .28, .02), "oak")
    p.box((0, .07, .14), (L - .30, .035, .06), "oak")
    return p


def stool_three():
    p = Prop("stool_three", .004)
    p.lathe([(0, .41), (.165, .41), (.172, .43), (.165, .455), (0, .455)], "wood_rough", sides=20, cap_bottom=False)
    for k in range(3):
        a = k * math.tau / 3 + .3
        p.rod((math.cos(a) * .11, math.sin(a) * .11, .415), (math.cos(a) * .19, math.sin(a) * .19, .0035), .024, "wood_rough", .018, 8)
    return p


def stool_log():
    p = Prop("stool_log", .006)

    def wobble(q, a, j):
        k = 1 + .04 * math.sin(a * 3 + 1) + .02 * math.sin(a * 7)
        return Vector((q.x * k, q.y * k, q.z))
    p.lathe([(.17, 0), (.18, .03), (.172, .40), (.168, .42)], "wood_rough", sides=18, cap_top=True, deform=wobble)
    return p


def chest(name, W=.92, D=.48, H=.50, plates=3, studs=False, metal="iron"):
    p = Prop(name, .005)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - .12), 0, .025), (.07, D, .05), "oak")
    body_h = H - .06
    planks = 3
    for side in (-1, 1):
        for i in range(planks):
            hz = body_h / planks
            p.box((0, side * (D / 2 - .012), .05 + hz * (i + .5)), (W, .024, hz - .004), "oak")
    for sx in (-1, 1):
        p.box((sx * (W / 2 - .012), 0, .05 + body_h / 2), (.024, D - .048, body_h), "oak", grain=(0, 0, 1))
    p.box((0, 0, .06), (W - .05, D - .05, .02), "wood_rough")
    lid = .05 + body_h
    p.box((0, 0, lid + .025), (W + .03, D + .03, .05), "oak")
    for i in range(plates):
        x = -W / 2 + .1 + i * (W - .2) / max(1, plates - 1)
        p.box((x, 0, lid + .052), (.035, D + .036, .005), metal)
        p.box((x, -D / 2 - .0175, lid + .025), (.035, .005, .055), metal)
        p.box((x, -D / 2 - .014, .05 + body_h * .55), (.035, .005, body_h * .9), metal)
        if studs:
            for z in (.12, .25, .38):
                p.box((x, -D / 2 - .019, z), (.016, .006, .016), metal)
    p.box((0, -D / 2 - .02, lid - .03), (.05, .008, .09), metal)
    p.torus(.022, .005, metal, T(0, -D / 2 - .03, lid - .085) @ R("X", math.pi / 2), 16, 6)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - .02), -D / 2 - .014, lid - .02), (.06, .005, .06), metal)
    return p


def shelf_rack(name="shelf_rack", W=1.10, D=.36, H=1.62, levels=(.30, .86, 1.42)):
    p = Prop(name, .005)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - .025), sy * (D / 2 - .025), H / 2), (.05, .05, H), "wood_rough")
    for lv in levels:
        p.box((0, 0, lv), (W - .01, D - .02, .03), "wood_rough")
        for sy in (-1, 1):
            p.box((0, sy * (D / 2 - .025), lv - .04), (W - .1, .03, .05), "wood_rough")
        for sx in (-1, 1):
            p.box((sx * (W / 2 - .025), 0, lv - .04), (.03, D - .1, .05), "wood_rough")
    p.beam((-W / 2 + .03, D / 2 - .02, levels[0] + .05), (W / 2 - .03, D / 2 - .02, levels[-1] - .12), .04, .025, "wood_rough")
    return p


def wall_shelf(name="wall_shelf", W=1.20, D=.26):
    p = Prop(name, .004)
    p.box((0, 0, .2175), (W, D, .035), "oak")
    for sx in (-1, 1):
        x = sx * (W / 2 - .14)
        p.box((x, D / 2 - .02, .11), (.04, .04, .22), "oak")
        p.beam((x, D / 2 - .035, .03), (x, -D / 2 + .05, .195), .035, .03, "oak")
    return p


def peg_rail(name="peg_rail", W=.90, pegs=4):
    p = Prop(name, .003)
    p.box((0, 0, .04), (W, .03, .08), "oak")
    for i in range(pegs):
        x = -W / 2 + .1 + i * (W - .2) / max(1, pegs - 1)
        p.rod((x, -.01, .045), (x, -.13, .07), .013, "wood_rough", .011, 8)
    return p


def hearth(name="hearth_ring", kind="plain"):
    p = Prop(name, .0)
    baker = kind == "baker"
    rng = random.Random({"plain": 77, "baker": 78, "cook": 79}[kind])
    p.lathe([(.43, 0), (.44, .012), (.42, .03), (0, .034)], "hearth_clay", sides=28, cap_bottom=True)
    p.lathe([(.36, .028), (.30, .05), (.16, .062), (0, .066)], "embers", sides=24, cap_bottom=True)
    for k in range(11):
        a = k * math.tau / 11 + rng.uniform(-.08, .08)
        size = (rng.uniform(.15, .19), rng.uniform(.11, .14), rng.uniform(.09, .12))
        rad = .43 + rng.uniform(-.01, .02)

        def sooty(q, a=a):
            inside = max(0.0, 1 - (math.hypot(q.x, q.y) - .36) / .14)
            k = 1 - .62 * inside * min(1.0, q.z / .08)
            return (k * .92, k * .9, k * .86)
        p.rock((math.cos(a) * rad, math.sin(a) * rad, size[2] / 2), size, "stone", 100 + k, sooty, 1, .16, R("Z", a), ground=True)
    for k in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, .17)
        p.rock((math.cos(a) * d, math.sin(a) * d, .07), (rng.uniform(.05, .08), rng.uniform(.04, .06), .035), "embers", 200 + k, WHITE, 1, .2)
    if kind == "cook":
        # Two logs burn under an iron tripod carrying the household's cooking pot.
        for a in (.9, 3.9):
            u = Vector((math.cos(a), math.sin(a), 0))
            outer = u * .50 + Vector((0, 0, .05))
            inner = u * .05 + Vector((0, 0, .1))
            mid = outer.lerp(inner, .6)
            p.tube([outer, mid], .042, "wood_rough", 7)
            p.tube([mid, inner], .04, "embers", 7)
        ring_z = .44
        p.torus(.135, .009, "iron", T(0, 0, ring_z), 24, 6)
        for k in range(3):
            a = k * math.tau / 3 + 2.4
            top = (math.cos(a) * .135, math.sin(a) * .135, ring_z)
            foot = (math.cos(a) * .30, math.sin(a) * .30, .045)
            p.rod(foot, top, .011, "iron", sides=6)
            p.box((foot[0], foot[1], .04), (.04, .04, .012), "iron")
        base = ring_z - .155
        vessel(p, [(.075, 0), (.10, .02), (.145, .10), (.15, .155), (.12, .215), (.11, .235), (.122, .25), (.12, .26)], .007,
               "coarseware", T(0, 0, base), 22, SOOT(.22, .3, base))
        p.lathe([(.108, .235), (0, .236)], "food", T(0, 0, base - .01), 20, False, True, (.45, .30, .18))
    elif not baker:
        for k, a in enumerate((.4, 2.5, 4.4)):
            u = Vector((math.cos(a), math.sin(a), 0))
            outer = u * .52 + Vector((0, 0, .05))
            inner = u * .06 + Vector((0, 0, .11))
            mid = outer.lerp(inner, .62)
            p.tube([outer, mid], .045, "wood_rough", 7)
            p.tube([mid, inner], .043, "embers", 7)
        # Iron firedog pair (Late La Tene type, simplified).
        for sx in (-1, 1):
            p.box((sx * .24, .10, .035), (.03, .42, .03), "iron")
            p.box((sx * .24, -.11, .09), (.03, .03, .14), "iron")
            p.blob((sx * .24, -.11, .17), (.025, .025, .03), "iron", seg=10, rings=6)
    else:
        # Earthenware baking cover (testum) over the embers, as in Cato, Agr. 75.
        p.lathe([(.22, .066), (.215, .12), (.18, .2), (.10, .245), (.04, .26), (.045, .30), (0, .305)], "hearth_clay",
                sides=24, cap_bottom=True, color=(.82, .7, .6))
    return p


def tripod_pot(name="tripod_pot", stew=(.45, .30, .18)):
    p = Prop(name, .0)
    ring_z = .40
    p.torus(.135, .009, "iron", T(0, 0, ring_z), 24, 6)
    for k in range(3):
        a = k * math.tau / 3
        top = (math.cos(a) * .135, math.sin(a) * .135, ring_z)
        foot = (math.cos(a) * .30, math.sin(a) * .30, .012)
        p.rod(foot, top, .011, "iron", sides=6)
        p.box((foot[0], foot[1], .006), (.04, .04, .012), "iron")
    # Cooking pot (olla) seated in the ring; soot rises from its base.
    base = ring_z - .155
    vessel(p, [(.075, 0), (.10, .02), (.145, .10), (.15, .155), (.12, .215), (.11, .235), (.122, .25), (.12, .26)], .007,
           "coarseware", T(0, 0, base), 22, SOOT(.22, .35, base))
    p.lathe([(.108, .235), (0, .236)], "food", T(0, 0, base - .01), 20, False, True, stew)
    return p


def firewood(name="firewood_stack", row_counts=(5, 4, 3), log_length=(.52, .6)):
    p = Prop(name, .004)
    rng = random.Random(9)
    for row, n in enumerate(row_counts):
        for i in range(n):
            x = (i - (n - 1) / 2) * .17
            r = rng.uniform(.06, .075)
            z = (r - .002 if row == 0 else .073) + row * .118
            a = rng.uniform(0, math.tau)
            sec = []
            for k in range(6):
                ang = a + k * math.tau / 6
                rr = r * (1 if k % 3 else .55)
                sec.append((math.cos(ang) * rr, math.sin(ang) * rr))
            length = rng.uniform(*log_length)
            y0 = -length / 2 + rng.uniform(-.03, .03)
            pts_a = [p._vert((x + sx, y0, z + sz)) for sx, sz in sec]
            pts_b = [p._vert((x + sx, y0 + length, z + sz)) for sx, sz in sec]
            for k in range(6):
                k1 = (k + 1) % 6
                p.planar_face([pts_a[k], pts_a[k1], pts_b[k1], pts_b[k]], "wood_rough", True, (1, .97, .92) if k % 2 else (.82, .76, .68), Vector((0, 1, 0)))
            p.planar_face(list(reversed(pts_a)), "wood_rough", False, (1.15, 1.05, .9))
            p.planar_face(pts_b, "wood_rough", False, (1.15, 1.05, .9))
    return p


def basket(name, content=None, r=.22, h=.28):
    p = Prop(name, .0)
    vessel(p, [(r * .76, 0), (r * .8, .01), (r * .97, h * .7), (r, h)], .012, "wicker", sides=24)
    p.torus(r + .004, .012, "wicker", T(0, 0, h), 28, 6)
    p.torus(r * .78, .01, "wicker", T(0, 0, .008), 24, 6)
    rng = random.Random(len(name) * 31)
    fill = h * .78
    if content == "wool":
        for k in range(7):
            a, d = rng.uniform(0, math.tau), rng.uniform(0, r * .55)
            dye = rng.choice(["natural", "natural", "brown", "madder", "ochre"])
            p.blob((math.cos(a) * d, math.sin(a) * d, fill + rng.uniform(-.01, .03)), (.06, .05, .045), "wool", seg=12, rings=7,
                   noise=.12, color=DYE[dye], seed=k)
    elif content in ("apples", "onions", "grapes"):
        for k in range(13):
            a, d = rng.uniform(0, math.tau), r * .72 * math.sqrt(rng.random())
            rad = {"apples": .036, "onions": .032, "grapes": .045}[content]
            tone = {"apples": (rng.uniform(.62, .78), rng.uniform(.38, .52), .22), "onions": (rng.uniform(.62, .72), .40, .26),
                    "grapes": (rng.uniform(.30, .38), .18, rng.uniform(.30, .36))}[content]
            if content == "apples" and k % 3 == 0:
                tone = (.62, .66, .30)
            radii = (rad, rad * .9, rad * 1.35) if content == "grapes" else (rad, rad, rad * (.92 if content == "apples" else 1.05))
            p.blob((math.cos(a) * d, math.sin(a) * d, fill + rad * (.6 + .9 * (k > 8))), radii, "food",
                   seg=10, rings=7, color=tone, seed=k, noise=.45 if content == "grapes" else 0.0)
    elif content in ("charcoal", "grain", "flour"):
        tone = {"charcoal": (.12, .11, .11), "grain": (.88, .72, .42), "flour": (1.05, 1.03, .98)}[content]
        mat = "stone" if content == "charcoal" else "food"
        p.blob((0, 0, fill), (r * .93, r * .93, .055), mat, seg=20, rings=8, exponent=.7, color=tone, seed=3, noise=.04)
        if content == "charcoal":
            for k in range(10):
                a, d = rng.uniform(0, math.tau), rng.uniform(0, r * .7)
                p.rock((math.cos(a) * d, math.sin(a) * d, fill + .04), (.06, .05, .04), "stone", 300 + k, tone, 0, .25)
    elif content == "bread":
        loaf(p, -.06, .03, fill - .02, .085, .07, seed=1)
        loaf(p, .07, -.04, fill - .01, .08, .065, seed=2)
    return p


def sack(name, tint=(.86, .78, .62), h=.62, r=.20, slump=0.0):
    p = Prop(name, .0)
    rng = random.Random(len(name))
    phases = [rng.uniform(0, math.tau) for _ in range(3)]

    def deform(q, a, j):
        k = 1 + .05 * math.sin(a * 3 + phases[0]) + .03 * math.sin(a * 5 + phases[1])
        lean = slump * (q.z / h) ** 2
        return Vector((q.x * k + lean, q.y * k, q.z))
    prof = [(r * .7, 0), (r * .95, .02), (r * 1.06, .14), (r * 1.04, h * .45), (r * .9, h * .70), (r * .5, h * .83),
            (r * .17, h * .88), (r * .15, h * .9), (r * .26, h * .96), (r * .12, h), (0, h * 1.005)]
    p.lathe(prof, "linen", sides=22, deform=deform, color=tint)
    p.torus(r * .17 + .006, .007, "straw", T(slump * (.88) ** 2, 0, h * .89), 14, 5, (.75, .6, .4))
    return p


def dolium(name="dolium"):
    p = Prop(name, .0)
    vessel(p, [(.24, 0), (.32, .05), (.40, .28), (.415, .52), (.37, .76), (.27, .90), (.24, .94), (.29, .965), (.30, 1.0)], .035,
           "terracotta", sides=32, color=lambda q: (.95, .92, .9) if q.z > .3 else (.82, .78, .74))
    p.lathe([(.30, 1.0), (.30, 1.02), (.27, 1.035), (.05, 1.04), (.04, 1.07), (0, 1.075)], "terracotta", T(0, 0, 0), 28, True, True)
    return p


def amphora(p: Prop, M, color=WHITE):
    # Dressel 1A wine amphora (Italian, c. 130-50 BC).
    prof = [(.0, 0), (.03, .005), (.033, .09), (.06, .16), (.14, .28), (.165, .40), (.168, .56), (.15, .68), (.10, .78),
            (.064, .82), (.058, .99), (.072, 1.03), (.074, 1.09)]
    vessel(p, prof, .01, "terracotta", M, 24, color, floor=.30)
    for sy in (-1, 1):
        pts = [Vector((0, sy * .062, 1.0)), Vector((0, sy * .13, 1.0)), Vector((0, sy * .155, .95)), Vector((0, sy * .14, .86)),
               Vector((0, sy * .12, .78))]
        p.tube([M @ q for q in pts], .016, "terracotta", 7, color)


def amphora_stand():
    p = Prop("amphora_stand", .004)
    p.torus(.14, .014, "wood_rough", T(0, 0, .33), 20, 6)
    for k in range(3):
        a = k * math.tau / 3 + .5
        p.rod((math.cos(a) * .265, math.sin(a) * .265, .012), (math.cos(a) * .14, math.sin(a) * .14, .35), .018, "wood_rough", sides=7)
        p.box((math.cos(a) * .27, math.sin(a) * .27, .01), (.05, .05, .02), "wood_rough")
    # Ring of radius .14 + .014 meets the body where its radius is about .15.
    amphora(p, T(0, 0, .344 - .284))
    return p


def amphora_lean():
    p = Prop("amphora_lean", .0)
    tilt = math.radians(11)
    amphora(p, R("X", -tilt) @ T(0, 0, 0))
    return p


def jar_olla(name="jar_olla", lid=True, h=.40, r=.17, mat="terracotta"):
    p = Prop(name, .0)
    vessel(p, jar_profile(h, r, r * .52), .01, mat, sides=24)
    if lid:
        p.lathe([(r * .62, h), (r * .62, h + .012), (r * .5, h + .025), (.02, h + .03), (.018, h + .05), (0, h + .052)], "coarseware",
                sides=20, cap_bottom=True, cap_top=True)
    return p


def pot_cook(name="pot_cook"):
    p = Prop(name, .0)
    vessel(p, [(.07, 0), (.10, .02), (.115, .09), (.11, .15), (.085, .18), (.092, .195), (.095, .2)], .006, "coarseware",
           sides=22, color=SOOT(.15, .3))
    return p


def tableware(name, kind):
    """Small clusters laid on tables and shelves; origin on the support."""
    p = Prop(name, .0)
    if kind == "meal":
        plate(p, 0, 0, 0)
        loaf(p, 0, 0, .006, .085, .06, seed=4)
        bowl(p, .22, .05, 0, .085, .05)
        cup(p, -.20, .06, 0)
        cup(p, -.17, -.10, 0, color=(.35, .3, .28))
        jug(p, .05, .20, 0, .24, .075)
    elif kind == "jars":
        for k, (x, y, h) in enumerate(((-.18, 0, .2), (.02, .02, .25), (.21, -.01, .18))):
            vessel(p, jar_profile(h, h * .38, h * .2), .006, "terracotta" if k != 1 else "coarseware", T(x, y, 0), 18)
    elif kind == "bowls":
        for k in range(3):
            bowl(p, 0, 0, k * .022, .10 - k * .006, .05, "oak" if k else "terracotta", (1.0, .92, .8))
        cup(p, .2, 0, 0)
        cup(p, .3, .02, 0)
    elif kind == "lamp":
        # Republican biconical oil lamp.
        p.lathe([(.035, 0), (.042, .012), (.038, .025), (.012, .03), (.012, .02), (0, .02)], "terracotta", sides=18, cap_bottom=True, cap_top=True)
        p.box((.055, 0, .016), (.05, .028, .02), "terracotta")
        p.torus(.012, .004, "terracotta", T(-.045, 0, .022) @ R("X", math.pi / 2), 12, 5)
        # Charred linen wick in the nozzle; the flame is added in the engine.
        p.rod((.072, 0, .022), (.080, 0, .034), .003, "embers", sides=5)
    elif kind == "candle":
        # Tallow candle (candela) stuck with its own drippings into a clay dish.
        p.lathe([(.03, 0), (.062, .012), (.066, .024), (.058, .022), (.03, .008), (0, .008)], "coarseware", sides=18, cap_bottom=True, cap_top=True)
        p.lathe([(.022, .008), (.016, .014), (.013, .02), (.012, .105), (.008, .112), (0, .112)], "food", sides=10, cap_bottom=False,
                cap_top=True, color=(.93, .86, .66))
        p.blob((.012, .004, .085), (.004, .004, .016), "food", seg=6, rings=4, color=(.93, .86, .66))
        p.rod((0, 0, .108), (.001, 0, .122), .003, "embers", .002, 5)
    elif kind == "cheese":
        for k, (x, y, z) in enumerate(((0, 0, 0), (.0, .0, .08), (.25, .02, 0))):
            p.blob((x, y, z + .04), (.11, .11, .04), "food", seg=20, rings=8, exponent=.25, color=(.98, .86, .55), seed=k, flat_bottom=False)
    elif kind == "bread":
        for k, (x, y) in enumerate(((0, 0), (.21, .03), (-.2, .02))):
            loaf(p, x, y, 0, .09, .07, seed=k)
    return p


def hanging(name, kind):
    p = Prop(name, .0, hanging=True)
    rng = random.Random(len(name))
    if kind == "onions":
        p.tube([(0, 0, 0), (.0, -.01, -.15), (.01, -.02, -.55)], .008, "straw", 5, (.8, .7, .45))
        for k in range(11):
            z = -.12 - k * .04
            a = k * 2.3
            p.blob((math.cos(a) * .035, -.03 + math.sin(a) * .02, z), (.03, .03, .033), "food", seg=10, rings=7,
                   color=(rng.uniform(.62, .72), .40, .25), seed=k)
    elif kind == "herbs":
        for k in range(14):
            a = k * 2.4
            tip = Vector((math.cos(a) * .08, -.04 + math.sin(a) * .05, -.42 + rng.uniform(-.05, .05)))
            p.tube([(0, -.04, -.02), (tip.x * .3, tip.y, -.12), tip], .004, "straw", 4, (.55, .60, .40))
            for j in range(3):
                q = Vector((0, -.04, -.12)).lerp(tip, .45 + j * .2)
                p.blob(q, (.025, .012, .04), "straw", seg=6, rings=4, color=(.45, .52, .32), seed=k * 3 + j)
        p.torus(.02, .006, "straw", T(0, -.04, -.04), 10, 5, (.7, .6, .4))
    elif kind == "cloak":
        # Woollen sagum hung by its neck fold: gathered at the peg, pleated below.
        dye = DYE[rng.choice(["brown", "madder", "ochre", "woad"])]

        def cloth(s, t):
            gather = .35 + .65 * min(1.0, t * 3.0)
            x = (s - .5) * (.62 + .22 * t) * gather
            z = -.03 - t * 1.0 - .03 * math.sin(s * math.pi) * t
            y = -.045 - .05 * t - (.022 + .045 * t) * math.sin(s * math.pi * 7 + .6) - .03 * math.sin(s * math.pi) * (1 - t)
            return (x, y, z)
        p.sheet(cloth, 22, 14, .012, "wool", .8, 1.05, dye)
        p.blob((0, -.06, -.06), (.17, .055, .07), "wool", seg=14, rings=7, exponent=.7, noise=.15, color=dye, seed=3)
    elif kind == "sickles":
        for k, dx in enumerate((-.12, .12)):
            p.rod((dx, -.04, -.02), (dx, -.04, -.17), .016, "wood_rough", sides=7)
            pts = [Vector((dx, -.04, -.17 - .2 * math.sin(a))) + Vector((.18 * (1 - math.cos(a)) * (1 if k else -1), 0, 0)) for a in
                   [i * math.pi * .55 / 8 for i in range(9)]]
            p.tube(pts, .012, "iron", 4)
    elif kind == "leather":
        p.tube([(0, -.02, 0), (.02, -.03, -.35), (.0, -.03, -.65)], .012, "leather", 6, (.8, .6, .45))
        p.blob((.0, -.05, -.32), (.12, .04, .14), "leather", seg=12, rings=8, exponent=.6, color=(.9, .75, .6), seed=4)
        p.tube([(-.08, -.04, -.18), (0, -.09, -.05), (.08, -.04, -.18)], .006, "leather", 5)
    return p


def lean_tools(name="farm_tools_lean"):
    p = Prop(name, .004)
    tops = [(-.25, .0, 1.25), (0, .0, 1.32), (.24, .0, 1.18)]
    feet = [(-.28, -.24, .032), (.02, -.26, .0195), (.30, -.22, .012)]
    # Spade (pala) with iron shoe, hoe (ligo), wooden hay fork.
    a, b = Vector(feet[0]), Vector(tops[0])
    d = (b - a).normalized()
    p.rod(a + d * .32, b, .017, "wood_rough", sides=8)
    p.beam(a + d * .02, a + d * .32, .19, .025, "wood_rough")
    p.beam(a, a + d * .06, .2, .03, "iron")
    a, b = Vector(feet[1]), Vector(tops[1])
    d = (b - a).normalized()
    p.rod(a + d * .05, b, .017, "wood_rough", sides=8)
    p.beam(a + Vector((0, .01, .0)), a + Vector((0, -.07, .19)), .11, .012, "iron")
    a, b = Vector(feet[2]), Vector(tops[2])
    d = (b - a).normalized()
    p.rod(a + d * .35, b, .017, "wood_rough", sides=8)
    for k in (-1, 0, 1):
        tip = a + Vector((k * .07, 0, 0))
        p.tube([tip, tip + d * .2 + Vector((k * .02, 0, 0)), a + d * .35], .01, "wood_rough", 5)
    return p


def loom(name="loom_warp", dye="natural"):
    """Warp-weighted loom leaning on the wall, with clay loom weights."""
    p = Prop(name, .004)
    lean = math.radians(13)
    H = 2.12
    top_y = math.sin(lean) * H
    for sx in (-1, 1):
        p.beam((sx * .80, -.20, .008), (sx * .80, -.20 + top_y, math.cos(lean) * H), .085, .07, "wood_rough")
    def on_plane(z):
        return -.20 + top_y * z / (math.cos(lean) * H)
    beam_z = 1.96
    p.rod((-.92, on_plane(beam_z) - .03, beam_z), (.92, on_plane(beam_z) - .03, beam_z), .045, "wood_rough", sides=12)
    p.rod((-.70, on_plane(beam_z) - .03, beam_z), (.70, on_plane(beam_z) - .03, beam_z), .075, "wool", sides=14, color=DYE[dye])
    cloth_low = 1.38

    def woven(s, t):
        z = beam_z - .06 - (beam_z - .06 - cloth_low) * t
        return ((s - .5) * 1.38, on_plane(z) - .045, z)
    p.sheet(woven, 6, 6, .006, "wool", 1.38, .6, DYE[dye])
    p.box((0, on_plane(cloth_low) - .045, cloth_low - .01), (1.40, .012, .02), "wool", color=DYE[dye])
    # Heddle bar on forked rests, shed rod lower down.
    heddle_z = 1.08
    for sx in (-1, 1):
        p.beam((sx * .80, on_plane(heddle_z) - .05, heddle_z - .04), (sx * .80, on_plane(heddle_z) - .26, heddle_z - .02), .04, .035, "wood_rough")
    p.rod((-.88, on_plane(heddle_z) - .25, heddle_z + .01), (.88, on_plane(heddle_z) - .25, heddle_z + .01), .02, "wood_rough", sides=8)
    shed_z = .78
    p.rod((-.86, on_plane(shed_z) + .03, shed_z), (.86, on_plane(shed_z) + .03, shed_z), .028, "wood_rough", sides=8)
    # Warp bundles split into front and back sheds, each tied to a weight.
    weight_z = .32
    for k in range(22):
        x = -.65 + k * 1.3 / 21
        front = k % 2 == 0
        top = Vector((x, on_plane(cloth_low) - .045, cloth_low))
        mid = Vector((x, on_plane(heddle_z) - (.25 if front else -.0) + (.0 if front else .03), heddle_z))
        low = Vector((x, on_plane(weight_z) - (.20 if front else -.04), weight_z + .12))
        p.tube([top, mid, low], .0035, "wool", 4, DYE[dye], caps=False)
        wx, wy = low.x, low.y
        # Pyramidal clay weight with a suspension hole.
        base = [(wx + sx * .035, wy + sy * .025) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        bottom = [p._vert((bx, by, weight_z - .02)) for bx, by in base]
        topv = [p._vert((wx + (bx - wx) * .45, wy + (by - wy) * .45, weight_z + .1)) for bx, by in base]
        tone = (.88 + .1 * math.sin(k * 3.1), .84, .8)
        p.planar_face(list(reversed(bottom)), "terracotta", False, tone)
        p.planar_face(topv, "terracotta", False, tone)
        for i in range(4):
            i1 = (i + 1) % 4
            p.planar_face([bottom[i], bottom[i1], topv[i1], topv[i]], "terracotta", False, tone)
    return p


def loom_weights_pile():
    p = Prop("loom_weights_pile", .0)
    rng = random.Random(4)
    spots = [(0, 0, 0, .1), (.09, .02, 0, -.3), (-.08, .05, 0, .6), (.02, .09, 0, 1.2), (.0, .03, .12, .4), (.12, -.07, 0, .9)]
    for k, (x, y, z, yaw) in enumerate(spots):
        M = T(x, y, z) @ R("Z", yaw)
        base = [M @ Vector((sx * .035, sy * .025, 0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        top = [M @ Vector((sx * .016, sy * .011, .11)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        if z > 0:
            # One weight lies on its side across two others.
            M = T(x, y, .045) @ R("Z", yaw) @ R("Y", math.pi / 2)
            base = [M @ Vector((sx * .035, sy * .025, -.055)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            top = [M @ Vector((sx * .016, sy * .011, .055)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        b = [p._vert(q) for q in base]
        t = [p._vert(q) for q in top]
        p.planar_face(list(reversed(b)), "terracotta", False)
        p.planar_face(t, "terracotta", False)
        for i in range(4):
            p.planar_face([b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i]], "terracotta", False)
    return p


def spinning_basket():
    p = basket("spinning_basket", "wool", .19, .22)
    # Distaff with a roved fleece and a drop spindle with a clay whorl across the rim.
    p.rod((-.16, .05, .2), (.22, -.05, .27), .009, "wood_rough", sides=6)
    p.blob((.2, -.045, .28), (.07, .05, .05), "wool", seg=12, rings=7, noise=.2, color=DYE["natural"], seed=8)
    p.rod((-.12, -.1, .23), (.15, -.12, .25), .006, "oak", sides=6)
    p.lathe([(.016, 0), (.018, .008), (.006, .016)], "terracotta", T(.12, -.118, .249) @ R("Y", math.pi / 2 - .07), 12, True, True)
    return p


def quern():
    p = Prop("quern", .0)
    dark = (.62, .6, .6)
    p.box((0, 0, .02), (.64, .64, .04), "wood_rough")
    p.lathe([(.22, .04), (.225, .10), (.19, .125), (0, .135)], "stone", sides=28, cap_bottom=True, color=dark)
    p.lathe([(.205, .128), (.21, .21), (.16, .215), (.05, .2), (.045, .16), (0, .16)], "stone", sides=28, cap_bottom=True, color=dark)
    p.rod((.16, 0, .2), (.16, 0, .37), .016, "wood_rough", sides=8)
    p.lathe([(.36, .04), (.36, .045), (.24, .048), (0, .048)], "food", sides=24, cap_bottom=False, cap_top=True, color=(1.05, 1.02, .95))
    return p


def kneading_trough():
    p = Prop("kneading_trough", .005)
    L, W = 1.04, .46
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.beam((sx * (L / 2 - .1), sy * (W / 2 - .07), 0), (sx * (L / 2 - .12), sy * (W / 2 - .09), .58), .05, .05, "oak")
    p.box((0, 0, .60), (L - .1, W - .14, .03), "oak")
    for sy in (-1, 1):
        M = T(0, sy * (W / 2 - .05), .70) @ R("X", sy * .22)
        p.box((0, 0, 0), (L, .03, .21), "oak", M)
    for sx in (-1, 1):
        M = T(sx * (L / 2 - .03), 0, .70) @ R("Y", -sx * .18)
        p.box((0, 0, 0), (.03, W - .02, .21), "oak", M, grain=(0, 1, 0))
    p.blob((-.1, 0, .64), (.30, .14, .07), "food", seg=18, rings=8, exponent=.8, noise=.08, color=(1.02, .97, .86), seed=2, flat_bottom=True)
    return p


def desk_writing():
    p = Prop("desk_writing", .005)
    L, W, H = .92, .52, .72
    p.box((0, 0, H - .02), (L, W, .04), "oak")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (L / 2 - .05), sy * (W / 2 - .05), (H - .04) / 2), (.05, .05, H - .04), "oak", grain=(0, 0, 1))
        p.box((sx * (L / 2 - .05), 0, .14), (.04, W - .1, .05), "oak")
    p.box((0, 0, .14), (L - .1, .04, .05), "oak")
    top = H
    # Wax tablet diptych, open scroll, rolled scrolls, inkwell and reed pen.
    for k, x in enumerate((-.26, -.08)):
        p.box((x, -.06, top + .006), (.16, .12, .012), "oak")
        p.box((x, -.06, top + .0125), (.13, .095, .002), "food", color=(.22, .16, .1))
    p.rod((-.17, -.12, top + .015), (-.17, .0, top + .015), .004, "oak", sides=5)
    def open_scroll(s, t):
        x = .02 + .30 * s
        y = -.02 + .20 * t
        z = top + .002 + .01 * (abs(s - .5) * 2) ** 3
        return (x, y, z)
    p.sheet(open_scroll, 8, 3, .002, "linen", .3, .2, (.9, .82, .64))
    scroll(p, (.02, -.03, top + .02), (.02, .2, top + .02), .016)
    scroll(p, (.32, -.03, top + .02), (.32, .2, top + .02), .016)
    p.cylinder(.025, .022, .05, "bronze", T(.38, -.16, top), 14, (True, True))
    p.rod((.33, -.16, top + .005), (.43, -.09, top + .045), .003, "straw", sides=4, color=(.8, .7, .45))
    scroll(p, (-.40, .14, top + .025), (-.12, .2, top + .025), .025)
    return p


def capsa():
    p = Prop("capsa", .0)
    vessel(p, [(.13, 0), (.135, .02), (.14, .34), (.142, .36)], .008, "leather", sides=24, color=(.9, .75, .6))
    for z in (.06, .3):
        p.torus(.143, .006, "bronze", T(0, 0, z), 24, 5)
    for k in range(7):
        a = k * math.tau / 7 + .3
        d = .065 if k else 0
        x, y = math.cos(a) * d, math.sin(a) * d
        scroll(p, (x, y, .02), (x + .01, y, .42 + .02 * (k % 3)), .028)
    return p


def workbench(name="workbench", L=1.40, W=.60, H=.80):
    p = Prop(name, .006)
    p.box((0, 0, H - .04), (L, W, .08), "oak")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (L / 2 - .09), sy * (W / 2 - .08), (H - .08) / 2), (.09, .09, H - .08), "wood_rough", grain=(0, 0, 1))
        p.box((sx * (L / 2 - .09), 0, .16), (.06, W - .16, .07), "wood_rough")
    p.box((0, 0, .16), (L - .18, .06, .07), "wood_rough")
    for x in (-.4, -.1, .25):
        p.cylinder(.012, .012, .002, "embers", T(x, .18, H), 10, (False, True), (.4, .35, .3))
    return p


def smith_tools(name="smith_tools"):
    p = Prop(name, .003)
    # Tongs, two hammers and a punch laid out on a surface.
    for s in (-1, 1):
        p.tube([(-.25, s * .015, .009), (.0, s * .004, .009), (.06, -s * .02, .009), (.12, -s * .03, .009)], .009, "iron", 5)
    p.cylinder(.012, .012, .016, "iron", T(.0, 0, .004), 10)
    for k, (y, size) in enumerate(((.14, .055), (.26, .042))):
        p.box((.1, y, size / 2 + .002), (size * 2.1, size, size), "iron")
        p.rod((.1, y, size / 2), (-.22, y + .01, .018), .014, "wood_rough", sides=7)
    p.rod((-.2, -.12, .01), (.05, -.13, .01), .008, "iron", sides=6)
    return p


def iron_bars():
    p = Prop("iron_bars", .002)
    for k in range(7):
        row = k // 4
        x = (k % 4 - 1.5) * .06 + row * .03
        p.box((x, 0, .012 + row * .024), (.035, .62, .024), "iron", color=(.9 + .1 * (k % 2), .9, .9))
    return p


def hides_stack():
    p = Prop("hides_stack", .0)
    for k in range(5):
        tone = (.85 + .08 * (k % 2), .70 + .06 * (k % 3) * .5, .55)
        p.blob((.01 * k, -.01 * k, .022 * .15 + k * .034), (.42 - .01 * k, .30, .022), "leather", seg=20, rings=6, exponent=.35,
               noise=.08, color=tone, seed=40 + k, flat_bottom=True)
    return p


def hide_frame():
    p = Prop("hide_frame", .003)
    lean = math.radians(12)
    up = Vector((0, math.sin(lean), math.cos(lean)))
    o = Vector((0, -.22, .025))
    corners = [o + Vector((-.55, 0, 0)), o + Vector((.55, 0, 0)), o + Vector((.55, 0, 0)) + up * 1.25, o + Vector((-.55, 0, 0)) + up * 1.25]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        d = (b - a).normalized()
        ext = .06 if abs(d.z) < .5 else 0.0
        p.rod(a - d * ext, b + d * ext, .025, "wood_rough", sides=7)
    def hide(s, t):
        x = (s - .5) * (.80 - .12 * math.sin(t * math.pi * 2) ** 2)
        q = o + Vector((x, 0, 0)) + up * (.15 + .95 * t) + Vector((0, -.02, 0))
        return tuple(q)
    p.sheet(hide, 8, 10, .004, "leather", .8, .95, (1.15, .95, .75))
    for k in range(8):
        t = .15 + k * .95 / 7
        for sx in (-1, 1):
            inner = o + Vector((sx * .40, -.02, 0)) + up * (.15 + .95 * (k / 7))
            outer = o + Vector((sx * .55, 0, 0)) + up * (.15 + .95 * (k / 7))
            p.tube([inner, outer], .003, "straw", 4, (.7, .6, .4))
    return p


def barrel(name="barrel", r=.27, h=.78, hoops="wicker"):
    p = Prop(name, .0)
    staves = 18
    gap = .012
    prof = [(r * .86, 0), (r * .95, h * .2), (r, h * .5), (r * .95, h * .8), (r * .86, h)]
    for k in range(staves):
        a0 = k * math.tau / staves + gap / 2
        a1 = (k + 1) * math.tau / staves - gap / 2
        tone = (.92 + .1 * math.sin(k * 2.7), .9 + .06 * math.sin(k * 1.3), .88)
        outer = p.lathe(prof, "oak", sides=3, cap_bottom=False, arc=(a0, a1), color=tone)
        inner = p.lathe([(rr - .018, z) for rr, z in reversed(prof)], "oak", sides=3, cap_bottom=False, arc=(a0, a1), color=tone)
        # Close the stave edges and end grain.
        n = len(prof)
        for j in range(n - 1):
            p.planar_face([outer[j][0], outer[j + 1][0], inner[n - 2 - j][0], inner[n - 1 - j][0]], "oak", False, tone)
            p.planar_face([outer[j][3], inner[n - 1 - j][3], inner[n - 2 - j][3], outer[j + 1][3]], "oak", False, tone)
        for i in range(3):
            p.planar_face([outer[0][i + 1], outer[0][i], inner[n - 1][i], inner[n - 1][i + 1]], "oak", False, tone)
            p.planar_face([outer[n - 1][i], outer[n - 1][i + 1], inner[0][i + 1], inner[0][i]], "oak", False, tone)
    p.cylinder(r * .86 - .015, r * .86 - .015, .03, "oak", T(0, 0, h - .06), 24, (True, True), (.85, .8, .75))
    p.cylinder(r * .86 - .015, r * .86 - .015, .03, "oak", T(0, 0, .03), 24, (True, True), (.85, .8, .75))
    for z in (.07, .2, h - .2, h - .07):
        rr = r * (.86 + .14 * math.sin(math.pi * z / h)) + .004
        p.torus(rr, .007, hoops, T(0, 0, z), 32, 5, (.8, .7, .5) if hoops == "wicker" else WHITE)
    return p


def staves_bundle():
    p = Prop("staves_bundle", .003)
    for k in range(9):
        x = (k - 4) * .07
        bow = .02
        p.tube([(x, -.38, .02 + (k % 2) * .03), (x, 0, .02 + bow + (k % 2) * .03), (x, .38, .02 + (k % 2) * .03)], .022, "oak", 4,
               (.95, .9, .85))
    for k in range(3):
        p.torus(.31 - k * .015, .007, "wicker", T(.0, .05, .09 + k * .016), 28, 5, (.8, .7, .5))
    return p


def bucket(name="bucket", milk=False):
    p = Prop(name, .0)
    staves = 12
    prof = [(.13, 0), (.15, .30)]
    for k in range(staves):
        a0 = k * math.tau / staves + .006
        a1 = (k + 1) * math.tau / staves - .006
        p.lathe(prof, "oak", sides=2, cap_bottom=False, arc=(a0, a1), color=(.95 + .05 * math.sin(k * 3), .92, .88))
        p.lathe([(.15 - .014, .30), (.13 - .014, .0)], "oak", sides=2, cap_bottom=False, arc=(a0, a1))
    p.cylinder(.125, .125, .02, "oak", T(0, 0, .015), 18)
    for z in (.05, .25):
        p.torus(.135 + .02 * z / .3 + .004, .005, "iron", T(0, 0, z), 24, 5)
    p.tube([(-.155, 0, .26), (-.12, 0, .36), (0, 0, .40), (.12, 0, .36), (.155, 0, .26)], .005, "iron", 5)
    if milk:
        p.lathe([(.143, .24), (0, .24)], "food", sides=18, cap_bottom=False, cap_top=True, color=(1.1, 1.08, 1.0))
    return p


def cheese_press():
    p = Prop("cheese_press", .004)
    p.box((0, 0, .30), (.70, .45, .05), "oak")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * .3, sy * .17, .14), (.05, .05, .28), "oak")
        p.box((sx * .2, 0, .62), (.05, .05, .62), "oak")
    p.box((0, 0, .95), (.52, .08, .06), "oak")
    vessel(p, [(.12, .325), (.12, .45)], .008, "wicker", sides=18)
    p.lathe([(.11, .45), (.11, .47), (0, .47)], "oak", sides=18, cap_bottom=True, cap_top=True)
    p.rock((0, 0, .55), (.20, .17, .15), "stone", 9, WHITE, 1, .12)
    p.box((.33, 0, .315), (.06, .06, .02), "oak")
    return p


def guard_kit():
    p = Prop("guard_kit", .003)
    # Spear (hasta) and oval shield (scutum) leaning on the wall, Montefortino helmet on the floor.
    p.rod((-.42, -.10, .06), (-.44, .0, 2.05), .016, "wood_rough", sides=8)
    p.lathe([(.016, 0), (.03, .06), (.022, .2), (.0, .28)], "iron", T(-.44, .0, 2.05) @ R("X", -.05), 8, False, True)
    p.lathe([(.0, 0), (.02, .045), (.014, .06)], "iron", T(-.42, -.10, .0), 8, False, True)
    lean = math.radians(9)
    c = Vector((.15, -.12, .62))

    def shield(s, t):
        a = (s - .5) * 1.0
        x = math.sin(a) * .35
        y = .12 - math.cos(a) * .12
        z = (t - .5) * 1.12
        w = 1 - (2 * t - 1) ** 2 * .35
        q = Vector((x * w, y, z))
        q = Matrix.Rotation(-lean, 3, "X") @ q
        return tuple(c + q)
    p.sheet(shield, 10, 12, .012, "leather", .75, 1.12, (.95, .62, .45))
    p.blob(tuple(c + Matrix.Rotation(-lean, 3, "X") @ Vector((0, -.012, 0))), (.07, .04, .055), "iron", seg=14, rings=7)
    p.beam(c + Matrix.Rotation(-lean, 3, "X") @ Vector((0, -.008, -.52)), c + Matrix.Rotation(-lean, 3, "X") @ Vector((0, -.008, .52)), .04, .012, "oak")
    p.lathe([(.12, 0), (.125, .02), (.118, .09), (.09, .16), (.05, .2), (.02, .215), (.022, .245), (.0, .25)], "bronze",
            T(.0, -.30, 0) @ R("Z", .4), 20, False, True)
    p.sheet(lambda s, t: (-.12 + .24 * s, -.30 + .11 + .04 * t, .026 - .02 * t), 4, 2, .004, "bronze", .24, .05)
    return p


def wheel_lean(name="wheel_lean"):
    p = Prop(name, .003)
    lean = math.radians(10)
    Rm = .52
    c = Vector((0, -.10, Rm + .004))
    M = T(*c) @ R("X", -lean) @ R("X", math.pi / 2)
    p.torus(Rm - .03, .035, "oak", M, 32, 6)
    p.torus(Rm, .012, "iron", M, 32, 5)
    p.cylinder(.075, .075, .22, "oak", M @ T(0, 0, -.11), 14)
    for k in range(10):
        a = k * math.tau / 10
        p.rod(M @ Vector((math.cos(a) * .07, math.sin(a) * .07, 0)), M @ Vector((math.cos(a) * (Rm - .05), math.sin(a) * (Rm - .05), 0)),
              .016, "oak", sides=6)
    return p


def rope_coil():
    p = Prop("rope_coil", .0)
    pts = []
    for i in range(180):
        a = i * math.tau / 28
        r = .14 + .008 * (i // 28)
        pts.append((math.cos(a) * r, math.sin(a) * r, .012 + .022 * (i / 180)))
    p.tube(pts, .011, "straw", 5, (.75, .62, .42))
    return p


def yoke():
    p = Prop("yoke", .004)
    p.tube([(-.75, 0, .06), (-.4, 0, .10), (0, 0, .07), (.4, 0, .10), (.75, 0, .06)], .045, "oak", 8)
    for sx in (-1, 1):
        p.tube([(sx * .40, -.0, .045), (sx * .52, -.14, .0165), (sx * .64, -.0, .045)], .018, "oak", 6)
    return p


def lararium():
    p = Prop("lararium", .004)
    p.box((0, 0, .02), (.52, .26, .04), "oak")
    for sx in (-1, 1):
        p.lathe([(.022, .04), (.02, .36), (.028, .38)], "oak", T(sx * .2, -.08, 0), 10, False, True)
    p.box((0, 0, .40), (.52, .26, .04), "oak")
    p.sheet(lambda s, t: (-.27 + .54 * s, -.1 + .0 * t, .42 + .10 * (1 - abs(2 * s - 1)) * (1 - t * 0)), 6, 1, .02, "oak", .54, .1)
    # Two bronze Lares and an offering bowl with a lamp (cf. Plautus, Aulularia, prologue).
    for sx in (-1, 1):
        x = sx * .09
        p.lathe([(.02, .04), (.022, .055), (.012, .07), (.016, .13), (.012, .16), (.013, .175), (0, .19)], "bronze", T(x, 0, 0), 10, True, True)
    bowl(p, 0, -.05, .04, .04, .022)
    return p


def broom():
    p = Prop("broom", .0)
    lean = math.radians(14)
    base = Vector((0, -.27, .027))
    top = base + Vector((0, math.sin(lean), math.cos(lean))) * 1.3
    p.rod(base + (top - base) * .25, top, .015, "wood_rough", sides=7)
    p.lathe([(.04, .0), (.11, .0), (.09, .18), (.03, .32), (.025, .34)], "straw", T(*base) @ R("X", -lean), 14, True, True, (.9, .82, .6))
    return p


def rush_mat():
    """Plaited rush floor mat: flat planks of straw texture with a bound edge."""
    p = Prop("rush_mat", .002)
    for k in range(9):
        y = -.40 + k * .10
        p.box((0, y, .005), (1.56, .098, .010), "straw", color=(.80 + .05 * (k % 2), .74, .58), grain=(1, 0, 0))
    for sy in (-1, 1):
        p.box((0, sy * .45, .006), (1.60, .025, .012), "straw", color=(.62, .55, .42), grain=(1, 0, 0))
    for sx in (-1, 1):
        p.box((sx * .79, 0, .006), (.025, .92, .012), "straw", color=(.62, .55, .42), grain=(0, 1, 0))
    return p


def cartibulum():
    p = Prop("cartibulum", .006)
    # Stone table by the impluvium (Varro, De lingua Latina 5.125).
    p.box((0, 0, .80), (1.20, .58, .07), "stone", color=(1.12, 1.1, 1.05))
    for sx in (-1, 1):
        x = sx * .42
        prof = [(-.06, 0), (.06, 0), (.07, .1), (.03, .3), (.06, .55), (.09, .76), (-.09, .76), (-.06, .55), (-.03, .3), (-.07, .1)]
        a = [p._vert((x - .03, y, z)) for y, z in prof]
        b = [p._vert((x + .03, y, z)) for y, z in prof]
        p.planar_face(list(reversed(a)), "stone", False, (1.08, 1.05, 1.0))
        p.planar_face(b, "stone", False, (1.08, 1.05, 1.0))
        n = len(prof)
        for i in range(n):
            i1 = (i + 1) % n
            p.planar_face([a[i], a[i1], b[i1], b[i]], "stone", False, (1.08, 1.05, 1.0))
    p.box((0, 0, .04), (.94, .14, .08), "stone", color=(1.05, 1.03, 1.0))
    return p


def candelabrum():
    p = Prop("candelabrum", .0)
    for k in range(3):
        a = k * math.tau / 3
        p.tube([(0, 0, .12), (math.cos(a) * .12, math.sin(a) * .12, .06), (math.cos(a) * .16, math.sin(a) * .16, 0.012)], .012, "bronze", 6)
        p.blob((math.cos(a) * .165, math.sin(a) * .165, .012), (.02, .02, .012), "bronze", seg=8, rings=5)
    p.lathe([(.022, .1), (.03, .14), (.014, .2), (.012, 1.10), (.03, 1.12), (.075, 1.15), (.08, 1.165), (0, 1.17)], "bronze",
            sides=14, cap_bottom=True, cap_top=True)
    # A wax candle on the pricket, in the Etruscan manner of the lamp stand.
    p.lathe([(.016, 1.168), (.0135, 1.175), (.013, 1.31), (.009, 1.318), (0, 1.318)], "food", sides=10, cap_bottom=False, cap_top=True,
            color=(.95, .88, .68))
    p.rod((0, 0, 1.314), (.001, 0, 1.33), .003, "embers", .002, 5)
    return p


def brazier():
    p = Prop("brazier", .003)
    for k in range(3):
        a = k * math.tau / 3
        p.rod((math.cos(a) * .25, math.sin(a) * .25, 0), (math.cos(a) * .2, math.sin(a) * .2, .5), .014, "iron", sides=6)
    vessel(p, [(.18, .46), (.27, .52), (.30, .58)], .01, "bronze", sides=28)
    p.lathe([(.26, .52), (.18, .55), (0, .56)], "embers", sides=24, cap_bottom=False, cap_top=True)
    return p


def armarium():
    p = Prop("armarium", .005)
    W, D, H = .92, .44, 1.62
    p.box((0, 0, .06), (W, D, .12), "oak")
    for sx in (-1, 1):
        p.box((sx * (W / 2 - .02), 0, H / 2 + .06), (.04, D, H - .12), "oak", grain=(0, 0, 1))
    p.box((0, D / 2 - .01, H / 2 + .06), (W - .08, .02, H - .12), "oak", grain=(0, 0, 1))
    p.box((0, 0, H + .01), (W + .06, D + .06, .06), "oak")
    for sx in (-1, 1):
        p.box((sx * (W / 4 - .01), -D / 2 + .012, H / 2 + .06), (W / 2 - .04, .024, H - .14), "oak", grain=(0, 0, 1))
        for z in (.45, 1.25):
            p.box((sx * (W / 4 - .01), -D / 2 - .002, z), (W / 2 - .12, .006, .22), "oak", color=(.8, .74, .66))
        p.torus(.02, .004, "bronze", T(sx * .05, -D / 2 - .01, .9) @ R("X", math.pi / 2), 12, 5)
    return p


def table_round():
    p = Prop("table_round", .0)
    p.lathe([(.36, .66), (.37, .675), (.36, .70), (0, .70)], "oak", sides=32, cap_bottom=True, cap_top=True)
    for k in range(3):
        a = k * math.tau / 3
        u = Vector((math.cos(a), math.sin(a), 0))
        p.tube([u * .22 + Vector((0, 0, .66)), u * .28 + Vector((0, 0, .45)), u * .22 + Vector((0, 0, .2)), u * .30 + Vector((0, 0, .02))],
               .025, "oak", 8)
        p.blob(tuple(u * .30 + Vector((0, 0, .02))), (.035, .03, .02), "oak", seg=8, rings=5)
    return p


def chair_wicker():
    p = Prop("chair_wicker", .0)
    vessel(p, [(.24, 0), (.25, .02), (.26, .42), (.27, .44)], .02, "wicker", sides=26, floor=.40)
    p.lathe([(.26, .44), (.27, .62), (.28, .80), (.285, .84)], "wicker", sides=13, cap_bottom=False, arc=(math.pi * .15, math.pi * .85))
    p.lathe([(.25, .84), (.24, .80), (.24, .44)], "wicker", sides=13, cap_bottom=False, arc=(math.pi * .15, math.pi * .85))
    p.blob((0, 0, .45), (.21, .21, .04), "wool", seg=20, rings=6, exponent=.4, color=DYE["ochre"], seed=2)
    return p


def bronze_vessels():
    """Bronze table set of a well-off household: jug, shallow handled dish
    (patera) and a small bucket (situla)."""
    p = Prop("bronze_vessels", .0)
    M = T(-.10, .02, 0)
    vessel(p, [(.045, 0), (.06, .02), (.085, .09), (.07, .16), (.035, .21), (.03, .25), (.045, .27)], .004, "bronze", M, 22)
    p.tube([M @ Vector((.03, 0, .25)), M @ Vector((.09, 0, .28)), M @ Vector((.11, 0, .2)), M @ Vector((.08, 0, .11))], .008, "bronze", 6)
    vessel(p, [(.06, 0), (.07, .005), (.12, .03), (.13, .04)], .004, "bronze", T(.14, -.02, 0), 26)
    p.rod((.27, -.02, .03), (.42, -.02, .036), .011, "bronze", sides=8)
    vessel(p, [(.05, 0), (.065, .015), (.075, .13), (.08, .14)], .003, "bronze", T(.05, .14, 0), 20)
    p.tube([(-.03, .14, .14), (.0, .14, .21), (.13, .14, .21), (.13, .14, .14)], .004, "bronze", 5)
    return p


def carpentry_tools():
    p = Prop("carpentry_tools", .003)
    # Frame-less pull saw, adze, mallet and two chisels laid on a bench top.
    p.box((-.12, .0, .002), (.46, .07, .004), "iron")
    p.rod((-.36, 0, .0165), (-.48, 0, .0165), .016, "wood_rough", sides=7)
    p.rod((.16, .16, .016), (.16, -.20, .016), .015, "wood_rough", sides=7)
    p.box((.16, .19, .02), (.09, .06, .03), "iron")
    p.lathe([(.045, 0), (.05, .02), (.05, .11), (.045, .13)], "oak", T(-.28, .2, .054) @ R("Y", math.pi / 2) @ T(0, 0, -.065), 14, True, True)
    p.rod((-.28, .2, .05), (-.02, .26, .02), .014, "wood_rough", sides=7)
    for k, y in enumerate((-.16, -.24)):
        p.rod((.0 + k * .05, y, .012), (.16 + k * .05, y, .012), .011, "wood_rough", sides=6)
        p.box((.22 + k * .05, y, .006), (.12, .018, .006), "iron")
    return p


def cloth_bolts(name="cloth_bolts"):
    """Folded lengths of dyed wool and linen, stacked for sale or storage."""
    p = Prop(name, .0)
    rng = random.Random(len(name) * 7)
    dyes = ["madder", "woad", "ochre", "natural", "brown", "green", "grey"]
    z = 0.0
    for k in range(5):
        h = rng.uniform(.045, .06)
        mat = "wool" if k % 3 else "linen"
        p.blob((rng.uniform(-.01, .01), rng.uniform(-.01, .01), z + h * .5), (.21, .15, h * .5), mat, seg=16, rings=6, exponent=.18,
               color=DYE[dyes[(k + len(name)) % len(dyes)]], seed=k)
        z += h
    return p


def mortar():
    p = Prop("mortar_pestle", .0)
    vessel(p, [(.08, 0), (.095, .02), (.10, .09), (.105, .11)], .025, "stone", sides=20, color=(.9, .88, .84))
    p.rod((.02, .0, .04), (.09, .04, .19), .016, "stone", r1=.012, sides=10, color=(.85, .83, .8))
    return p


def scroll_pile():
    p = Prop("scroll_pile", .0)
    for k, (x, y, z) in enumerate(((0, -.05, .025), (0, .0, .025), (0, .05, .025), (0, -.025, .068), (0, .025, .068))):
        scroll(p, (x - .15, y, z), (x + .15, y, z), .024)
    for k in range(2):
        p.box((.25, -.05 + k * .002, .006 + k * .012), (.16, .12, .012), "oak")
        p.box((.25, -.05 + k * .002, .0125 + k * .012), (.13, .095, .002), "food", color=(.22, .16, .1))
    return p


# Smithy (lean-to forge of the village smith), market and tavern.
def forge_shelter():
    """Lean-to of the smithy: four oak posts on stone pads, plates, rafters
    and split shingles falling towards the lane (-X). Origin is the forge
    origin; the posts stand at x -0.10 / 1.25, Godot z -3.15 / 3.0."""
    p = Prop("forge_shelter", .0)
    rng = random.Random(58)
    low, high = 2.36, 2.62
    xs = {-.10: low, 1.25: high}
    for x, top in xs.items():
        for y in (3.15, -3.0):
            p.rock((x, y, .05), (.34, .30, .10), "stone", int(900 + x * 10 + y), (.8, .78, .74), 1, .12, ground=True)
            p.box((x, y, .09 + (top - .09) / 2), (.14, .14, top - .09), "oak", grain=(0, 0, 1), color=(.8, .76, .72))
            for sy in (-1, 1):
                end = y + sy * .55
                if -3.2 <= end <= 3.3:
                    p.beam((x, y + sy * .05, top - .62), (x, end, top - .02), .07, .06, "wood_rough")
        p.box((x, .075, top + .06), (.13, 6.75, .12), "oak", grain=(0, 1, 0), color=(.78, .74, .7))
    x0, x1 = -.82, 1.42
    def roof_z(x):
        return low + .12 + (x + .10) * (high - low) / 1.35
    for k in range(9):
        y = 3.30 - k * (6.45 / 8)
        p.beam((x0, y, roof_z(x0) + .045), (x1, y, roof_z(x1) + .045), .07, .09, "wood_rough")
    # Battens and five courses of split shingles, lapped down the fall.
    courses = 6
    step = (x1 - x0) / courses
    pitch = math.atan2(roof_z(x1) - roof_z(x0), x1 - x0)
    for c in range(courses):
        xa = x0 - .04 + c * step
        xm = xa + step * .62
        p.box((xm - .2, .075, roof_z(xm - .2) + .10), (.05, 6.7, .03), "wood_rough", grain=(0, 1, 0))
        y = -3.32
        while y < 3.42:
            w = rng.uniform(.16, .26)
            w = min(w, 3.44 - y)
            lift = rng.uniform(0, .008)
            tone = rng.uniform(.62, .9)
            M = T(xm, y + w / 2, roof_z(xm) + .125 + lift) @ R("Y", -pitch - .05 + rng.uniform(-.012, .012))
            p.box((0, 0, 0), (step * 1.32, w - .006, .016), "wood_rough", M, (tone, tone * .97, tone * .93), grain=(1, 0, 0))
            y += w
    return p


def forge_hearth():
    """Waist-high smith's hearth with a clay shield towards the bellows, as on
    the smith's grave relief from Aquileia (1st c. AD; the type is older).
    Front (-Y) is the bellows side, the fire is worked from the flanks."""
    p = Prop("forge_hearth", .0)
    W, D, H = 1.10, 1.00, .70
    rng = random.Random(311)
    p.box((0, 0, H / 2), (W - .10, D - .10, H), "hearth_clay", color=(.62, .56, .50))
    rows = 4
    for row in range(rows):
        h = H / rows
        z = (row + .5) * h
        for side in range(4):
            length = W if side % 2 == 0 else D
            count = 5 if side % 2 == 0 else 4
            for k in range(count):
                t = (k + .5) / count - .5 + (.06 if row % 2 else -.06)
                along = t * (length - .14)
                off = (D if side % 2 == 0 else W) / 2 - .055
                x, y = ((along, -off), (off, along), (-along, off), (-off, -along))[side]
                size = (length / count * rng.uniform(.92, 1.08), rng.uniform(.10, .13), h * rng.uniform(.92, 1.04))
                tone = rng.uniform(.72, .95)
                p.rock((x, y, z), size, "stone", 400 + row * 40 + side * 10 + k, (tone, tone * .97, tone * .93), 1, .13,
                       R("Z", side * math.pi / 2), ground=row == 0)
    p.box((0, 0, H + .03), (W, D, .06), "hearth_clay", color=(.72, .62, .54))
    # Fire bed: charcoal around a glowing heart in front of the tuyere.
    p.lathe([(.30, H + .058), (.27, H + .085), (.14, H + .10), (0, H + .105)], "stone", T(0, -.05, 0), 20, False, True, (.13, .12, .12))
    p.lathe([(.15, H + .098), (.08, H + .118), (0, H + .122)], "embers", T(0, -.10, 0), 16, False, True)
    for k in range(16):
        a, d = rng.uniform(0, math.tau), rng.uniform(.05, .30)
        hot = d < .13
        p.rock((math.cos(a) * d, -.05 + math.sin(a) * d * .9, H + .10 + (.03 if hot else .0)), (rng.uniform(.05, .08), rng.uniform(.04, .06), .04),
               "embers" if hot else "stone", 520 + k, WHITE if hot else (.11, .10, .10), 0, .25)
    # Clay shield with the tuyere hole; the bellows nozzle ends in it.
    p.box((0, -D / 2 + .07, H + .06 + .17), (W * .72, .12, .34), "hearth_clay", color=(.66, .52, .44))
    p.rod((0, -D / 2 - .10, H + .17), (0, -D / 2 + .16, H + .14), .045, "hearth_clay", .032, 10, (.55, .42, .36))

    # Sooted back wall protects the house side.
    def sooty(q):
        k = .30 + .5 * min(1.0, max(0.0, (q.z - H) / .7)) * (.6 + .4 * min(1.0, abs(q.x) / (W / 2)))
        return (k, k * .97, k * .94)
    p.box((0, D / 2 - .08, H + .06 + .32), (W, .16, .64), "hearth_clay", color=sooty)
    # Tongs left with their jaws in the fire, and a poker.
    for s in (-1, 1):
        p.tube([(.50, -.05 + s * .02, H + .09), (.22, -.06 + s * .006, H + .125), (.12, -.07 - s * .012, H + .13), (.04, -.08 - s * .014, H + .13)],
               .008, "iron", 5)
    p.rod((-.52, .12, H + .075), (-.08, .0, H + .13), .007, "iron", sides=5)
    return p


def forge_bellows():
    """Pair of leather bag bellows on a trestle; the nozzles (+Y) meet in the
    tuyere of the hearth, the handles face the worker (-Y)."""
    p = Prop("forge_bellows", .004)
    top = .70
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * .23, sy * .36, (top - .04) / 2), (.07, .07, top - .04), "wood_rough", grain=(0, 0, 1))
        p.box((sx * .23, 0, .22), (.05, .68, .06), "wood_rough")
    p.box((0, 0, top - .02), (.58, .92, .04), "oak")
    for k, sx in enumerate((-1, 1)):
        x = sx * .145
        lift = .16 if k == 0 else .07
        tilt = math.radians(-4 if k == 0 else -2)
        boards = []
        for z, angle in ((top, 0.0), (top + lift, tilt)):
            M = T(x, 0, z) @ R("X", angle)
            p.lathe([(.001, 0), (.13, 0), (.13, .018), (.001, .018)], "oak", M @ S(1.0, 2.35, 1.0), 14, True, True)
            boards.append(M)
        p.blob((x, .0, top + lift / 2 + .009), (.125, .30, lift / 2 + .012), "leather", seg=16, rings=7, exponent=.6, noise=.06,
               color=(.8, .62, .5), seed=60 + k)
        for j in range(3):
            y = -.2 + j * .2
            p.torus(.128, .004, "leather", T(x, y, top + lift / 2 + .009) @ R("X", math.pi / 2) @ S(1.0, (lift / 2 + .014) / .128, 1.0), 14, 4,
                    (.5, .36, .28))
        p.rod(boards[1] @ Vector((0, -.26, .018)), boards[1] @ Vector((0, -.52, .05)), .017, "wood_rough", .014, 7)
        p.rod((x, .26, top + .045), (sx * .03, .50, top + .085), .034, "leather", .022, 8, (.55, .4, .3))
    p.rod((0, .46, top + .085), (0, .60, top + .115), .036, "hearth_clay", .03, 10, (.55, .42, .36))
    return p


def anvil_block():
    """Block anvil with its tang driven into an oak stump; hammers at hand."""
    p = Prop("anvil_block", .004)
    rng = random.Random(9)
    phases = [rng.uniform(0, math.tau) for _ in range(2)]

    def bark(q, a, j):
        k = 1 + .035 * math.sin(a * 5 + phases[0]) + .02 * math.sin(a * 9 + phases[1])
        return Vector((q.x * k, q.y * k, q.z))
    p.lathe([(.29, 0), (.305, .03), (.29, .50), (.275, .545), (0, .55)], "wood_rough", sides=18, deform=bark, color=(.82, .74, .66))
    for z in (.10, .44):
        p.torus(.303 - z * .03, .007, "iron", T(0, 0, z), 26, 5, (.8, .75, .72))
    p.lathe([(.075, .53), (.10, .60), (.118, .73), (.122, .775), (.115, .79), (0, .79)], "iron", R("Z", math.pi / 4), 4, False, True,
            (1.05, 1.03, 1.0), smooth=False)
    p.rod((.085, 0, .745), (.235, 0, .765), .034, "iron", .010, 8)
    p.box((.20, -.14, .585), (.11, .05, .05), "iron")
    p.rod((.20, -.14, .585), (-.06, -.20, .565), .014, "wood_rough", sides=7)
    p.box((-.17, .15, .574), (.075, .038, .038), "iron")
    p.rod((-.17, .15, .574), (.02, .22, .562), .012, "wood_rough", sides=7)
    return p


def tool_rack_smith():
    """Free-standing rail with the smith's tongs, hammers, files and punches."""
    p = Prop("tool_rack_smith", .004)
    L, H = 1.0, 1.62
    for sx in (-1, 1):
        x = sx * (L / 2 - .04)
        p.box((x, 0, H / 2 + .03), (.07, .07, H - .06), "wood_rough", grain=(0, 0, 1))
        p.box((x, 0, .03), (.08, .42, .06), "wood_rough")
        p.beam((x, -.17, .06), (x, -.02, .42), .045, .035, "wood_rough")
        p.beam((x, .17, .06), (x, .02, .42), .045, .035, "wood_rough")
    for z in (1.50, 1.02):
        p.box((0, 0, z), (L, .05, .08), "oak")
    p.box((0, .0, .55), (L - .1, .035, .06), "wood_rough")
    # Upper rail: tongs hang by one rein over iron hooks, jaws down.
    for x, length, jaw in ((-.36, .52, .03), (-.22, .44, .05), (-.08, .58, .02)):
        p.rod((x, -.025, 1.50), (x, -.075, 1.515), .006, "iron", sides=5)
        for s in (-1, 1):
            p.tube([(x + s * .012, -.07, 1.50), (x + s * .008, -.068, 1.50 - length * .62), (x - s * jaw, -.066, 1.50 - length * .82),
                    (x - s * jaw * .4, -.066, 1.50 - length)], .0075, "iron", 5)
        p.cylinder(.011, .011, .02, "iron", T(x, -.056, 1.50 - length * .64) @ R("X", math.pi / 2), 8)
    for x, head, handle in ((.12, .10, .40), (.26, .075, .34), (.40, .13, .62)):
        for s in (-1, 1):
            p.rod((x + s * .03, -.025, 1.50), (x + s * .03, -.085, 1.512), .006, "iron", sides=5)
        p.box((x, -.06, 1.535), (head, head * .42, head * .42), "iron")
        p.rod((x, -.06, 1.535), (x, -.058, 1.535 - handle), .013, "wood_rough", sides=7)
    # Lower rail: file, punches and a chisel stuck through holes of the rail.
    for k, x in enumerate((-.34, -.26, -.18, -.06, .04)):
        length = .22 + .03 * (k % 3)
        p.rod((x, -.0, 1.06 + .03), (x, -.0, 1.06 - length), .007 if k else .011, "iron", .004, 6)
    p.torus(.09, .007, "iron", T(.30, -.035, .93) @ R("X", math.pi / 2), 18, 5)
    p.rod((.30, -.025, 1.02), (.30, -.05, 1.025), .006, "iron", sides=5)
    return p


def quench_trough():
    """Slack tub: an open plank trough on cleats; the water is added in the engine."""
    p = Prop("quench_trough", .005)
    W, L, H = .74, .92, .56
    course = (H - .09) / 3
    for k in range(3):
        z = .09 + k * course + course / 2
        tone = (.78 - .09 * (2 - k), .75 - .09 * (2 - k), .73 - .09 * (2 - k))
        for sx in (-1, 1):
            p.box((sx * (W / 2 - .025), 0, z), (.05, L, course - .006), "oak", color=tone)
        for sy in (-1, 1):
            p.box((0, sy * (L / 2 - .025), z), (W - .10, .05, course - .006), "oak", color=tone)
    for sy in (-1, 1):
        for sx in (-1, 1):
            p.box((sx * (W / 2 - .09), sy * (L / 2 + .012), H / 2 + .03), (.06, .035, H - .06), "wood_rough", grain=(0, 0, 1))
        p.box((0, sy * (L / 2 - .12), .03), (W + .04, .08, .06), "wood_rough")
    p.box((0, 0, .08), (W - .10, L - .10, .04), "oak")
    p.rod((.18, .05, H + .055), (.30, -.16, .30), .012, "iron", sides=6)
    return p


def iron_blooms():
    """Raw material: sponge-iron blooms and a few lumps of ore as delivered."""
    p = Prop("iron_blooms", .0)
    rng = random.Random(77)
    spots = [(-.14, -.06, 0), (.10, -.10, 0), (.02, .12, 0), (-.20, .14, 0), (.24, .08, 0), (-.03, .0, .12), (.11, .04, .11)]
    for k, (x, y, z) in enumerate(spots):
        size = (rng.uniform(.16, .22), rng.uniform(.13, .18), rng.uniform(.10, .14))
        rust = rng.uniform(.0, 1.0)
        tone = (.62 + .25 * rust, .50 + .08 * rust, .44 - .05 * rust)
        p.rock((x, y, z + size[2] / 2), size, "iron" if k % 3 else "stone", 800 + k, tone if k % 3 else (.72, .42, .32), 1, .24,
               R("Z", rng.uniform(0, 3)), ground=z == 0)
    return p


def smith_wares(name="smith_wares", second=False):
    """Stock for sale laid out on a board: origin on the support."""
    p = Prop(name, .0)
    if not second:
        # Sickle blades, knives with wooden grips, a bowl of nails, a chain.
        for x in (-.36, -.24):
            pts = [(x + .0, -.10, .008), (x + .01, .0, .008), (x + .05, .08, .008), (x + .12, .11, .008), (x + .18, .08, .008)]
            p.tube(pts, .010, "iron", 4, radii=[.006, .008, .008, .007, .003])
            p.rod((x, -.10, .012), (x, -.19, .012), .012, "wood_rough", sides=7)
        for k, x in enumerate((-.02, .05, .12)):
            length = .13 + .03 * k
            p.box((x, .03 + length / 2 - .06, .003), (.026, length, .006), "iron")
            p.rod((x, -.03, .011), (x - .004, -.13, .011), .011, "wood_rough", sides=7)
        bowl(p, .30, .02, 0, .085, .05, "coarseware")
        rng = random.Random(4)
        for k in range(14):
            a, d = rng.uniform(0, math.tau), rng.uniform(0, .05)
            x, y = .30 + math.cos(a) * d, .02 + math.sin(a) * d
            p.rod((x, y, .02), (x + rng.uniform(-.03, .03), y + rng.uniform(-.03, .03), .045 + rng.uniform(0, .01)), .003, "iron", .0012, 4)
        for k in range(9):
            p.torus(.014, .003, "iron", T(.08 + k * .019, -.13 + .012 * math.sin(k * .7), .0175) @ R("X", (k % 2) * 1.2), 8, 4)
    else:
        # Axe heads, a ploughshare, a hoe blade, a pan and three door bolts.
        for x, y, yaw in ((-.33, .0, .2), (-.20, .03, -.1)):
            M = T(x, y, .022) @ R("Z", yaw) @ R("X", math.pi / 2) @ S(1.0, .32, 1.0)
            p.lathe([(.022, -.07), (.03, 0), (.062, .085), (.068, .10)], "iron", M, 4, True, True, smooth=False, phase=math.pi / 4)
        p.lathe([(.001, -.20), (.05, -.06), (.062, .08), (.04, .13), (.022, .16)], "iron", T(.0, .0, .014) @ R("X", math.pi / 2) @ S(1.0, .22, 1.0),
                10, True, True, (.95, .9, .88))
        p.box((.16, .02, .003), (.11, .15, .006), "iron")
        p.rod((.16, -.05, .019), (.15, -.12, .03), .016, "iron", .019, 8)
        vessel(p, [(.085, 0), (.09, .004), (.11, .028), (.113, .032)], .003, "iron", T(.33, .0, 0), 20)
        p.rod((.33, -.10, .028), (.33, -.26, .034), .008, "iron", sides=6)
        for k in range(3):
            p.rod((-.42, -.16 + k * .028, .008), (-.26, -.16 + k * .028, .008), .0045, "iron", sides=5)
            p.torus(.011, .003, "iron", T(-.43, -.16 + k * .028, .008), 8, 4)
    return p


def table_bread():
    """Family table without drinking vessels (the cups and the jug of the
    family home are story props): bread on a plate, porridge, cheese, knife."""
    p = Prop("table_bread", .0)
    plate(p, 0, 0, 0)
    loaf(p, 0, 0, .006, .085, .06, seed=7)
    bowl(p, .17, .10, 0, .08, .05)
    p.lathe([(.064, .034), (0, .036)], "food", T(.17, .10, 0), 14, False, True, (.9, .8, .58))
    p.rod((.13, .13, .05), (.26, .22, .075), .0045, "oak", sides=5)
    p.blob((-.15, .10, .03), (.06, .06, .03), "food", seg=14, rings=7, exponent=.3, color=(.98, .86, .55), seed=3, flat_bottom=False)
    p.box((-.12, -.12, .002), (.022, .13, .004), "iron")
    p.rod((-.12, -.185, .009), (-.12, -.27, .009), .009, "wood_rough", sides=6)
    return p


def stall_trestle(name="stall_trestle", dye="natural", stripes=None):
    """Market stall: board on two trestles under a cloth awning on poles.
    The seller stands behind (+Y), customers in front (-Y)."""
    p = Prop(name, .005)
    L, W, H = 1.80, .78, .82
    for k in range(3):
        y = (k - 1) * (W / 3)
        p.box((0, y, H - .02), (L, W / 3 - .008, .04), "oak", color=(.95 - .06 * (k % 2), .93, .9))
    for sx in (-1, 1):
        x = sx * (L / 2 - .28)
        p.box((x, 0, H - .07), (.07, W - .06, .06), "wood_rough")
        for sy in (-1, 1):
            p.beam((x, sy * .34, .0095), (x, sy * .10, H - .09), .06, .05, "wood_rough")
        p.box((x, 0, .30), (.04, .46, .05), "wood_rough")
    front, back = 2.02, 2.22
    posts = {}
    for sx in (-1, 1):
        for sy, top in ((-1, front), (1, back)):
            x, y = sx * (L / 2 + .06), sy * (W / 2 + .10)
            p.lathe([(.034, 0), (.03, top - .02), (.012, top + .05)], "wood_rough", T(x, y, 0), 8, True, True)
            posts[(sx, sy)] = Vector((x, y, top))
        a, b = posts[(sx, -1)], posts[(sx, 1)]
        p.rod(a - Vector((0, .12, .012)), b + Vector((0, .10, -.01)), .02, "wood_rough", sides=7)
    for sy in (-1, 1):
        p.rod(posts[(-1, sy)] - Vector((.08, 0, .02)), posts[(1, sy)] + Vector((.08, 0, .02)), .02, "wood_rough", sides=7)
    base = DYE[dye]

    def tint(q):
        if stripes is None:
            return base
        return base if int((q.x + 2.0) / .24) % 2 else DYE[stripes]

    def awning(s, t):
        x = (s - .5) * (L + .36)
        y = (t - .5) * (W + .52)
        ridge = front + (back - front) * t
        sag = .07 * math.sin(s * math.pi) * math.sin(t * math.pi)
        edge = .05 * (1 - math.sin(t * math.pi)) ** 3
        return (x, y, ridge + .024 - sag - edge)
    p.sheet(awning, 14, 8, .006, "linen", L + .36, W + .52, tint)
    return p


def balance_scale():
    """Equal-arm balance (libra) with two bronze pans; origin on the table."""
    p = Prop("balance_scale", .0)
    p.lathe([(.075, 0), (.08, .012), (.03, .025), (.014, .04), (.012, .40), (.02, .41), (0, .42)], "bronze", sides=14, cap_bottom=True)
    p.rod((-.20, 0, .385), (.20, 0, .40), .006, "bronze", sides=6)
    for sx, drop, load in ((-1, .215, True), (1, .23, False)):
        x = sx * .19
        top = .385 + (.015 if sx > 0 else 0)
        z = top - drop
        for k in range(3):
            a = k * math.tau / 3 + .4
            p.rod((x, 0, top), (x + math.cos(a) * .058, math.sin(a) * .058, z + .014), .0018, "bronze", sides=4)
        vessel(p, [(.02, 0), (.035, .002), (.06, .012), (.063, .016)], .003, "bronze", T(x, 0, z), 18)
        if load:
            p.blob((x, 0, z + .022), (.03, .03, .018), "food", seg=10, rings=6, color=(.88, .72, .42), seed=5)
        else:
            for k in range(2):
                p.cylinder(.014, .012, .016, "stone", T(x - .012 + k * .026, 0, z + .004), 8)
    return p


def crate_greens():
    """Open slatted crate of cabbages, leeks and turnips."""
    p = Prop("crate_greens", .004)
    W, D, H = .62, .44, .28
    p.box((0, 0, .015), (W, D, .03), "wood_rough")
    for sy in (-1, 1):
        for k in range(2):
            p.box((0, sy * (D / 2 - .012), .08 + k * .13), (W, .024, .09), "wood_rough", color=(.95 - .1 * k, .92, .9))
    for sx in (-1, 1):
        for k in range(2):
            p.box((sx * (W / 2 - .012), 0, .08 + k * .13), (.024, D - .05, .09), "wood_rough")
        for sy in (-1, 1):
            p.box((sx * (W / 2 - .035), sy * (D / 2 - .035), H / 2), (.035, .035, H), "wood_rough", grain=(0, 0, 1))
    rng = random.Random(21)
    for k in range(5):
        x, y = -.2 + (k % 3) * .19 + rng.uniform(-.02, .02), -.09 + (k // 3) * .19
        tone = (rng.uniform(.50, .62), rng.uniform(.68, .80), rng.uniform(.34, .42))
        p.blob((x, y, .19), (.095, .095, .085), "food", seg=12, rings=8, noise=.12, color=tone, seed=k)
    for k in range(4):
        x = .12 + k * .035
        p.rod((x, -.16, .25 + k * .004), (x + .02, .16, .27), .012, "food", .017, 6, (.92, .95, .8))
        p.rod((x + .02, .16, .27), (x + .04, .215, .285), .017, "food", .010, 6, (.42, .62, .32))
    for k in range(4):
        p.blob((-.22 + k * .07, .13, .255), (.04, .04, .035), "food", seg=8, rings=6, color=(.86, .78, .82), seed=30 + k)
    return p


def amphora_rack():
    """Wine amphorae (Dressel 1) standing in a plank rack against a wall."""
    p = Prop("amphora_rack", .004)
    L = 1.24
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (L / 2 - .04), sy * .17, .22), (.06, .06, .44), "wood_rough", grain=(0, 0, 1))
    for sy in (-1, 1):
        p.box((0, sy * .185, .40), (L, .04, .07), "wood_rough")
        p.box((0, sy * .185, .10), (L - .1, .04, .05), "wood_rough")
    for k in range(4):
        amphora(p, T(-.45 + k * .30, 0, .0), (1.0, .96 - .04 * (k % 2), .94))
    return p


def tavern_set():
    """Counter service of a wine seller: jug, mixing bowl, stacked and used
    cups, knucklebones for a game; origin on the support."""
    p = Prop("tavern_set", .0)
    jug(p, -.26, .04, 0, .26, .08, yaw=.6)
    vessel(p, [(.06, 0), (.07, .008), (.15, .09), (.16, .12), (.165, .125)], .007, "coarseware", T(.02, .05, 0), 22)
    p.lathe([(.138, .10), (0, .10)], "food", T(.02, .05, 0), 18, False, True, (.42, .12, .16))
    for k in range(3):
        cup(p, .26, .06, k * .03, .044 - k * .001, .085)
    cup(p, .12, -.14, 0, color=(.9, .85, .8))
    cup(p, -.08, -.15, 0, color=(.35, .3, .28))
    rng = random.Random(8)
    for k in range(4):
        x, y = .30 + rng.uniform(-.05, .05), -.13 + rng.uniform(-.04, .04)
        p.blob((x, y, .009), (.013, .009, .009), "food", seg=6, rings=5, exponent=.6, color=(.95, .92, .82), seed=k)
    return p


# --------------------------------------------------------------------------
def build_all():
    props = [
        bed_simple("bed_madder", "madder"), bed_simple("bed_ochre", "ochre"), bed_simple("bed_woad", "woad"),
        bed_simple("bed_natural", "natural"), bed_simple("bed_brown", "brown"), bed_fine(),
        pallet("pallet_brown", "brown"), pallet("pallet_madder", "madder"),
        bench(), bench("bench_short", 1.0), stool_three(), stool_log(),
        chest("chest_wood"), chest("chest_small", .62, .40, .40, 2), chest("arca", 1.0, .56, .62, 4, True, "bronze"),
        shelf_rack(), shelf_rack("shelf_low", 1.0, .40, 1.0, (.25, .62, .98)), wall_shelf(), wall_shelf("wall_shelf_deep", 1.20, .46), peg_rail(),
        hearth(), hearth("hearth_baker", "baker"), hearth("hearth_cook", "cook"), tripod_pot(), firewood(),
        firewood("firewood_small", (4, 3, 2), (.40, .44)),
        basket("basket_empty"), basket("basket_wool", "wool"), basket("basket_apples", "apples"), basket("basket_onions", "onions"),
        basket("basket_charcoal", "charcoal", .25, .34), basket("basket_grain", "grain"), basket("basket_bread", "bread", .25, .2),
        basket("basket_flour", "flour"),
        sack("sack_grain"), sack("sack_hemp", (.72, .62, .46), .58, .19, .03), sack("sack_flour", (1.0, .97, .9), .55, .19),
        dolium(), amphora_stand(), amphora_lean(), jar_olla(), jar_olla("jar_coarse", True, .34, .15, "coarseware"), pot_cook(),
        tableware("table_meal", "meal"), tableware("shelf_jars", "jars"), tableware("shelf_bowls", "bowls"),
        tableware("oil_lamp", "lamp"), tableware("candle_dish", "candle"), tableware("cheese_stack", "cheese"), tableware("bread_loaves", "bread"),
        hanging("hang_onions", "onions"), hanging("hang_herbs", "herbs"), hanging("hang_cloak", "cloak"),
        hanging("hang_sickles", "sickles"), hanging("hang_leather", "leather"),
        lean_tools(), loom(), loom("loom_madder", "madder"), loom_weights_pile(), spinning_basket(), quern(),
        kneading_trough(), desk_writing(), capsa(), workbench(), workbench("workbench_low", 1.2, .55, .62), smith_tools(),
        iron_bars(), hides_stack(), hide_frame(), barrel(), barrel("barrel_iron", .25, .7, "iron"), staves_bundle(),
        bucket(), bucket("bucket_milk", True), cheese_press(), guard_kit(), wheel_lean(), rope_coil(), yoke(), lararium(),
        broom(), rush_mat(), cartibulum(), candelabrum(), brazier(), armarium(), table_round(), chair_wicker(),
        bronze_vessels(), carpentry_tools(), cloth_bolts(), cloth_bolts("cloth_bolts_b"), mortar(), scroll_pile(), basket("basket_grapes", "grapes"),
        forge_shelter(), forge_hearth(), forge_bellows(), anvil_block(), tool_rack_smith(), quench_trough(), iron_blooms(), smith_wares(),
        smith_wares("smith_wares_b", True), table_bread(), stall_trestle(), stall_trestle("stall_trestle_b", "ochre", "madder"),
        balance_scale(), crate_greens(), amphora_rack(), tavern_set(),
    ]
    return props


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    materials = {name: mat_preview(name) for name in ORDER}
    props = build_all()
    objects = []
    cols = 10
    for i, prop in enumerate(props):
        objects.append(prop.to_object(materials, ORDER, ((i % cols) * 2.6, (i // cols) * 2.6, 0)))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    manifest = {"units": "metres", "front": "+Z (Godot)", "props": {}}
    total = 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        # Godot axes: x, y=z_blender, z=-y_blender.
        manifest["props"][obj.name] = {"triangles": tris, "hanging": bool(obj["hanging"]),
                                       "aabb_min": [round(min(xs), 4), round(min(zs), 4), round(-max(ys), 4)],
                                       "aabb_max": [round(max(xs), 4), round(max(zs), 4), round(-min(ys), 4)],
                                       "materials": [m.name for m in obj.data.materials]}
        total += tris
        evaluated.to_mesh_clear()
    manifest["total_triangles"] = total
    for name, info in manifest["props"].items():
        low = info["aabb_min"][1]
        if not info["hanging"] and not -.0015 <= low <= .0015:
            print("CONTACT %s lowest point %.4f m" % (name, low))
    DEST.mkdir(parents=True, exist_ok=True)
    for obj in objects:
        obj.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=str(DEST / "interior_kit.glb"), export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_normals=True, export_tangents=False,
                              export_texcoords=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_materials="EXPORT", export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=False)
    (DEST / "kit_manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    print("KIT props=%d triangles=%d" % (len(objects), total))
    if preview:
        for i, obj in enumerate(objects):
            obj.location = ((i % cols) * 2.6, -(i // cols) * 2.6, 0)
        render_preview(objects, preview, cols)


def render_preview(objects, path, cols):
    """Cycles CPU contact sheet (no GPU needed); material base colours only."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = 2000, 1800
    world = bpy.data.worlds.new("w")
    world.color = (.55, .58, .62)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    bpy.context.collection.objects.link(sun)
    rows = math.ceil(len(objects) / cols)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = cols * 2.6 + .6
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cx, cy = (cols - 1) * 2.6 / 2, -(rows - 1) * 2.6 / 2
    cam.location = (cx, cy - 20, 17)
    cam.rotation_euler = (math.radians(50), 0, 0)
    scene.camera = cam
    for i, obj in enumerate(objects):
        txt = bpy.data.curves.new("t%d" % i, "FONT")
        txt.body = obj.name
        txt.size = .2
        t = bpy.data.objects.new("label%d" % i, txt)
        t.location = (obj.location.x - 1.15, obj.location.y - 1.2, 0)
        bpy.context.collection.objects.link(t)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
