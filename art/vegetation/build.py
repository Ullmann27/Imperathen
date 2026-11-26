"""Reproducible Blender 4.3 build of the Valdora vegetation.

    python3 art/vegetation/textures.py                       # textures first (needs Pillow)
    blender -b -t 2 -P art/vegetation/build.py               # all meshes + impostors
    blender -b -t 2 -P art/vegetation/build.py -- quercus_robur --no-impostors

Writes prototype/assets/vegetation/<asset>.glb (objects <asset>_lod0..lod3,
geometry only; textures stay separate PNGs), impostor atlases
textures/impostor_<asset>_albedo.png / _normal.png (8 views), herb_cards.glb
and art/vegetation/metrics.json plus prototype/assets/vegetation/manifest.json.

Vertex colour channels drive the Godot wind shader (Crysis-style bending):
  R  branch bend weight   0 on the trunk, rising toward twig tips
  G  branch phase         random per branch, inherited by its leaves
  B  leaf flutter weight  0 at a card's attachment, 1 at its free end
  A  ambient occlusion    crown self-shadow estimate (inner and low = dark)
Leaf-card normals are bent toward the crown surface so cards light like a
volume instead of flat planes. All geometry is original and procedural.
"""
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Matrix, Vector

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
from species import SHRUBS, TREES, VINES  # noqa: E402

ROOT = SOURCE.parents[1]
OUT = ROOT / "prototype/assets/vegetation"
TEX = OUT / "textures"
UP = Vector((0, 0, 1))
TAU = math.tau
BARK_TILE_M = .9
LOD_SIDES = [(16, 8, 5, 3), (10, 6, 4, 0), (6, 4, 0, 0), (5, 3, 0, 0)]
LOD_STRIDE = [(1, 1, 1, 1), (1, 2, 2, 0), (2, 3, 0, 0), (3, 4, 0, 0)]
LOD_MIN_RADIUS = [(0, 0, 0, 0), (0, 0, .0, 0), (0, 0, .03, 0), (0, .05, 0, 0)]
IMPOSTOR_VIEWS = 8
IMPOSTOR_FRAME = 256


# ------------------------------------------------------------------ growth

def unit(rng):
    v = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
    return v.normalized() if v.length > 1e-6 else Vector((1, 0, 0))


def perpendicular(d):
    a = d.cross(UP)
    if a.length < 1e-4:
        a = d.cross(Vector((1, 0, 0)))
    return a.normalized()


def rotate(v, axis, angle):
    return Matrix.Rotation(angle, 3, axis) @ v


class Branch:
    def __init__(self, level, points, radii, phase, weights, parent=None):
        self.level = level
        self.points = points
        self.radii = radii
        self.phase = phase
        self.weights = weights
        self.parent = parent
        self.length = sum((b - a).length for a, b in zip(points, points[1:]))
        self.repeats = max(1, round(TAU * radii[0] / BARK_TILE_M))

    def at(self, t):
        """Point, tangent, radius and weight at fraction t of the length."""
        target = t * self.length
        walked = 0.0
        for i in range(len(self.points) - 1):
            seg = (self.points[i + 1] - self.points[i]).length
            if walked + seg >= target or i == len(self.points) - 2:
                f = 0 if seg == 0 else min(1, max(0, (target - walked) / seg))
                p = self.points[i].lerp(self.points[i + 1], f)
                d = (self.points[i + 1] - self.points[i]).normalized()
                r = self.radii[i] * (1 - f) + self.radii[i + 1] * f
                w = self.weights[i] * (1 - f) + self.weights[i + 1] * f
                return p, d, r, w
            walked += seg
        return self.points[-1], (self.points[-1] - self.points[-2]).normalized(), self.radii[-1], self.weights[-1]


def envelope_shape(kind, zr):
    if zr <= 0 or zr >= 1:
        return 0.0
    s = math.sin
    return {
        "dome": s(math.pi * (.1 + .9 * zr)) ** .5 * (1 - .12 * zr),
        "ovoid": s(math.pi * zr ** .85) ** .7,
        "vase": s(math.pi * zr ** .6) ** .6,
        "column": .25 + .75 * s(math.pi * zr) ** .5,
        "cone": (1 - zr) ** .85 * min(1, zr * 5),
        "ball": s(math.pi * zr) ** .6,
        "fountain": s(math.pi * zr ** .75) ** .5,
    }[kind]


class Tree:
    def __init__(self, name, spec, shrub=False):
        self.name = name
        self.spec = spec
        self.shrub = shrub
        self.rng = random.Random(spec["seed"])
        self.branches = []
        self.cards = []  # (position, up, normal, size, weight, phase, ao)
        H = spec["height"]
        self.crown_base = H * spec["crown_base"]
        self.crown_center = Vector((0, 0, (self.crown_base + H) * .5))

    # crown envelope ------------------------------------------------------
    def env_radius(self, z):
        H = self.spec["height"]
        zr = (z - self.crown_base) / max(.1, H - self.crown_base)
        return self.spec["radius"] * envelope_shape(self.spec["envelope"], zr)

    def ao(self, p):
        H = self.spec["height"]
        radial = Vector((p.x, p.y, 0)).length
        env = max(.3, self.env_radius(p.z))
        zr = max(0.0, min(1.0, p.z / H))
        if p.z < self.crown_base * .8:
            return min(1.0, .62 + .38 * min(1, p.z / 1.6))
        return max(.32, min(1.0, (.42 + .58 * min(1, radial / env) ** .9) * (.78 + .22 * zr)))

    # skeleton --------------------------------------------------------------
    def grow_branch(self, start, direction, length, r0, r1, level, tropism, wander, kink, parent_weight, phase, steps):
        rng = self.rng
        points, radii, weights = [start.copy()], [r0], [parent_weight]
        d = direction.normalized()
        p = start.copy()
        seg = length / steps
        gain = (0, .32, .36, .32)[level]
        for s in range(1, steps + 1):
            jolt = 1 + (kink * 3 if rng.random() < kink * .35 else 0)
            d = (d + UP * tropism + unit(rng) * wander * jolt * .5).normalized()
            p = p + d * seg
            t = s / steps
            points.append(p.copy())
            radii.append(max(.004, r0 * (1 - t) ** .9 + r1 * t))
            weights.append(min(1.0, parent_weight + gain * t ** 1.3))
        return Branch(level, points, radii, phase, weights)

    def prune_length(self, start, direction, length):
        """Shorten so the end stays inside the crown envelope (+8 %)."""
        for _ in range(6):
            end = start + direction * length
            env = self.env_radius(end.z) * 1.08
            radial = Vector((end.x, end.y, 0)).length
            if end.z > self.spec["height"] * 1.02 or (env > 0 and radial > env) or env == 0:
                length *= .82
            else:
                break
        return max(length, .05)

    def trunk(self):
        sp, rng = self.spec, self.rng
        H = sp["height"]
        lean_dir = Vector((math.cos(sp["seed"]), math.sin(sp["seed"]), 0))
        top = sp.get("pollard", H * (.55 + .4 * sp["leader"]) if sp["leader"] > 0 else self.crown_base * 1.15)
        rings = 16
        pts, radii = [], []
        phase_a, phase_b = rng.uniform(0, TAU), rng.uniform(0, TAU)
        for i in range(rings + 1):
            t = i / rings
            z = -.25 + (top + .25) * t
            off = lean_dir * sp["lean"] * z + Vector((math.sin(z * .9 + phase_a), math.cos(z * .7 + phase_b), 0)) * sp["wander"] * min(1, z / 3)
            pts.append(Vector((off.x, off.y, z)))
            if "pollard" in sp:
                radius = sp["trunk_radius"] * (1 - .25 * t) * (1 + .35 * math.exp(-((t - 1) / .08) ** 2))
            else:
                radius = sp["trunk_radius"] * (1 - t) ** sp["taper"] * (1 - .35 * t) + .03 * t
            radii.append(radius)
        trunk = Branch(0, pts, radii, rng.random(), [0.0] * len(pts))
        trunk.flare = sp["flare"]
        self.branches.append(trunk)
        return trunk

    def scaffold(self, parent, count, z_from, z_to, angle_range, length_scale=1.0, from_head=False):
        sp, rng = self.spec, self.rng
        golden = 2.39996
        az0 = rng.uniform(0, TAU)
        made = []
        for i in range(count):
            f = (i + rng.uniform(.15, .85)) / count
            if from_head:
                t = rng.uniform(.93, 1.0)
            else:
                t = (z_from + (z_to - z_from) * f) / max(.01, parent.points[-1].z)
                t = min(.98, max(.02, t))
            start, tangent, radius, weight = parent.at(t)
            az = az0 + i * golden + rng.uniform(-.25, .25)
            tilt = math.radians(angle_range[0] + (angle_range[1] - angle_range[0]) * f + rng.uniform(-8, 8))
            direction = Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
            if from_head:
                length = (sp["height"] - start.z) / max(.3, math.cos(tilt)) * rng.uniform(.75, 1.05)
            else:
                end_z = start.z + math.cos(tilt) * 2
                reach = max(.8, self.env_radius(min(sp["height"] * .95, end_z + 1.5)))
                length = reach / max(.35, math.sin(tilt)) * sp["reach1"] * rng.uniform(.8, 1.08) * length_scale
                length = self.prune_length(start, direction, length)
            r0 = max(.02, radius * (.62 if not from_head else .13) * rng.uniform(.85, 1.05))
            b = self.grow_branch(start - tangent * r0 * .5, direction, length, r0, .012, 1, sp["tropism1"], sp["wander1"],
                                 sp["kink1"], weight, rng.random(), 10)
            b.parent = parent
            self.branches.append(b)
            made.append(b)
        return made

    def children(self, parent, count, angle, ratio, tropism, wander, level, t_from=.25):
        rng = self.rng
        made = []
        az = rng.uniform(0, TAU)
        for i in range(count):
            t = t_from + (1 - t_from) * (i + rng.uniform(.1, .9)) / count
            start, tangent, radius, weight = parent.at(t)
            az += 2.39996 + rng.uniform(-.3, .3)
            side = perpendicular(tangent)
            side = rotate(side, tangent, az)
            tilt = math.radians(angle + rng.uniform(-12, 12))
            direction = (tangent * math.cos(tilt) + side * math.sin(tilt)).normalized()
            # Bias toward the crown surface (outward) and slightly toward light.
            outward = Vector((start.x, start.y, 0))
            outward = outward.normalized() if outward.length > .01 else side
            direction = (direction + outward * .35 + UP * .12).normalized()
            length = parent.length * ratio * (1.15 - .6 * t) * rng.uniform(.75, 1.15)
            length = self.prune_length(start, direction, length)
            r0 = max(.006, radius * .62)
            steps = 6 if level == 2 else 4
            b = self.grow_branch(start, direction, length, r0, .005, level, tropism, wander, .1, weight,
                                 (parent.phase + rng.uniform(0, .35)) % 1.0, steps)
            b.parent = parent
            self.branches.append(b)
            made.append(b)
        return made

    def grow(self):
        sp, rng = self.spec, self.rng
        H = sp["height"]
        if self.shrub:
            level1 = []
            for s in range(sp["stems"]):
                az = s * 2.39996 + rng.uniform(-.3, .3)
                tilt = math.radians(sp["stem_angle"] * rng.uniform(.4, 1.3))
                base = Vector((math.cos(az), math.sin(az), 0)) * rng.uniform(.02, .18) + Vector((0, 0, -.1))
                direction = Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
                length = H * rng.uniform(.65, 1.0) / max(.5, math.cos(tilt))
                stem = self.grow_branch(base, direction, length, sp["stem_radius"] * rng.uniform(.7, 1.2), .008, 0,
                                        sp["tropism1"] - .03, sp["wander"] + .05, .1, 0.0, rng.random(), 9)
                stem.weights = [min(1.0, .45 * (i / (len(stem.points) - 1)) ** 1.4) for i in range(len(stem.points))]
                self.branches.append(stem)
                level1 += self.children(stem, sp["n1"], sp["angle1"][0], .45, sp["tropism1"], sp["wander1"], 2, .3)
            for b in level1:
                if sp["n2"]:
                    self.children(b, sp["n2"], sp["angle2"], sp["ratio2"], sp["tropism2"], sp["wander2"], 3, .3)
        else:
            trunk = self.trunk()
            if "pollard" in sp:
                level1 = self.scaffold(trunk, sp["n1"], 0, 0, sp["angle1"], from_head=True)
            elif sp.get("split"):
                # Willow: the stem forks into leaders low in the crown.
                level1 = []
                head = trunk
                for k in range(sp["split"]):
                    start, tangent, radius, weight = trunk.at(.92)
                    az = rng.uniform(0, TAU) + k * math.pi
                    tilt = math.radians(28)
                    direction = Vector((math.sin(tilt) * math.cos(az), math.sin(tilt) * math.sin(az), math.cos(tilt)))
                    leader = self.grow_branch(start, direction, H * .55, radius * .72, .05, 1, .04, .08, .2, 0.0, rng.random(), 10)
                    leader.weights = [min(1.0, .18 * (i / 10) ** 1.5) for i in range(11)]
                    self.branches.append(leader)
                    level1 += self.scaffold(leader, sp["n1"] // sp["split"] + 1, leader.points[0].z + 1.0,
                                            leader.points[-1].z, sp["angle1"])
                del head
            else:
                level1 = self.scaffold(trunk, sp["n1"], self.crown_base, trunk.points[-1].z * .97, sp["angle1"])
            level2 = []
            for b in level1:
                level2 += self.children(b, sp["n2"], sp["angle2"], sp["ratio2"], sp["tropism2"], sp["wander2"], 2)
            if sp["n3"]:
                for b in level2:
                    self.children(b, sp["n3"], sp["angle3"], sp["ratio3"], sp["tropism2"], sp["wander2"] * 1.2, 3, .3)
        self.place_cards()

    def place_cards(self):
        sp, rng = self.spec, self.rng
        terminal_level = max(b.level for b in self.branches)
        for b in self.branches:
            if b.level < terminal_level - 1 or b.level == 0 or getattr(b, "stake", False):
                continue
            share = 1.0 if b.level == terminal_level else .35
            count = max(1, int(b.length * sp["cards_per_m"] * share + rng.random()))
            for k in range(count):
                t = .3 + .7 * (k + rng.uniform(.2, .9)) / count
                p, d, _, w = b.at(t)
                outward = p - self.crown_center
                outward = outward.normalized() if outward.length > .01 else UP
                up = (d * .65 + outward * .55 + UP * .2 + unit(rng) * .35).normalized()
                normal = (outward - up * outward.dot(up))
                normal = normal.normalized() if normal.length > .01 else perpendicular(up)
                normal = rotate(normal, up, rng.uniform(-1.0, 1.0))
                size = sp["card"] * rng.uniform(.8, 1.2)
                self.cards.append((p, up, normal, size, w, b.phase, self.ao(p + up * size * .5), rng.randrange(3)))


# ------------------------------------------------------------------- mesh

class MeshData:
    def __init__(self):
        self.verts, self.normals, self.colors, self.faces, self.uvs, self.mats = [], [], [], [], [], []

    def add_vertex(self, p, n, c):
        self.verts.append(tuple(p))
        self.normals.append(tuple(n.normalized()))
        self.colors.append(c)
        return len(self.verts) - 1

    def face(self, idx, uv, mat):
        self.faces.append(idx)
        self.uvs.append(uv)
        self.mats.append(mat)


def tube(mesh, tree, branch, sides, stride, lod):
    pts = branch.points
    indices = list(range(0, len(pts), stride))
    if indices[-1] != len(pts) - 1:
        indices.append(len(pts) - 1)
    sp = tree.spec
    rings = []
    frame = perpendicular((pts[1] - pts[0]).normalized())
    travel = 0.0
    previous = None
    trunk = branch.level == 0 and not tree.shrub
    for n, i in enumerate(indices):
        p = pts[i]
        if previous is not None:
            travel += (p - pts[previous]).length
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tangent = (b - a).normalized()
        frame = (frame - tangent * frame.dot(tangent)).normalized()
        other = tangent.cross(frame)
        ring = []
        radius = branch.radii[i]
        last = n == len(indices) - 1 and branch.level > 0
        for j in range(sides + (0 if last else 1)):
            ang = TAU * j / sides
            r = radius
            if trunk:
                z = p.z
                lobes = .5 + .5 * math.cos(sp["flare_roots"] * ang + 1.3 * math.sin(ang * 2))
                r *= 1 + sp["flare"] * math.exp(-max(0, z) / .55) * (.35 + .65 * lobes) * 1.6
                r *= 1 + sp["flute"] * math.sin(ang * 6 + z * .4) * (1 - math.exp(-max(0, z) / .8) * .5)
                r *= 1 + sp["burl"] * max(0, math.sin(ang * 3 + z * 2.3) * math.sin(z * 1.7 + ang)) ** 3
            elif branch.level == 1 and sp["flute"]:
                r *= 1 + sp["flute"] * .6 * math.sin(ang * 5)
            normal = frame * math.cos(ang) + other * math.sin(ang)
            pos = p + normal * (0 if last else r)
            weight = branch.weights[i]
            color = (weight, branch.phase, 0.0, tree.ao(p))
            ring.append((mesh.add_vertex(pos, normal, color), j / sides * branch.repeats, travel / BARK_TILE_M))
        rings.append(ring)
        previous = i
    for lo, hi in zip(rings, rings[1:]):
        for j in range(sides):
            a, b = lo[j], lo[j + 1]
            if len(hi) == len(lo):
                c, d = hi[j + 1], hi[j]
                mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2]), (d[1], d[2])), 0)
            else:  # tip: converge to a point ring (degenerate radius)
                c, d = hi[(j + 1) % sides], hi[j]
                mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1] if j + 1 < sides else b[1], c[2]), (d[1], d[2])), 0)


def tile_uv(tile, grid=2):
    col, row = tile % grid, tile // grid
    u0 = col / grid
    v0 = 1 - (row + 1) / grid
    inset = .004
    return u0 + inset, v0 + inset, u0 + 1 / grid - inset, v0 + 1 / grid - inset


def leaf_card(mesh, tree, card, size_scale, tile, folded):
    p, up, normal, size, weight, phase, ao, _ = card
    size *= size_scale
    side = up.cross(normal).normalized()
    radial = (p + up * size * .5 - tree.crown_center)
    radial = radial.normalized() if radial.length > .01 else normal
    bent = (normal * .35 + radial * .65).normalized()
    u0, v0, u1, v1 = tile_uv(tile)
    half = size * .5
    if folded:
        # Arched card: the middle row bows out along the card normal.
        ids = []
        for t in (0.0, .5, 1.0):
            center = p + up * size * t + normal * size * (.09 * math.sin(math.pi * t) - .03 * t)
            for s in (-1, 1):
                q = center + side * half * s * (1 - .1 * t)
                color = (min(1.0, weight + .08 * t), phase, t, ao)
                ids.append((mesh.add_vertex(q, bent, color), u0 if s < 0 else u1, v0 + (v1 - v0) * t))
        for r in range(2):
            a, b, c, d = ids[r * 2], ids[r * 2 + 1], ids[r * 2 + 3], ids[r * 2 + 2]
            mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2]), (d[1], d[2])), 1)
    else:
        ids = []
        for t in (0.0, 1.0):
            center = p + up * size * t
            for s in (-1, 1):
                q = center + side * half * s
                ids.append((mesh.add_vertex(q, bent, (min(1.0, weight + .08 * t), phase, t, ao)), u0 if s < 0 else u1, v0 + (v1 - v0) * t))
        a, b, c, d = ids[0], ids[1], ids[3], ids[2]
        mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2]), (d[1], d[2])), 1)


def cluster_cards(tree, cell):
    """Merge leaf cards into foliage clumps for the far LODs."""
    bins = {}
    for card in tree.cards:
        p = card[0]
        key = (math.floor(p.x / cell), math.floor(p.y / cell), math.floor(p.z / cell))
        bins.setdefault(key, []).append(card)
    clumps = []
    rng = random.Random(tree.spec["seed"] + int(cell * 100))
    for key in sorted(bins):
        group = bins[key]
        if len(group) < 2 and cell > 2.0 and rng.random() < .5:
            continue
        center = sum((c[0] for c in group), Vector()) / len(group)
        outward = (center - tree.crown_center)
        outward = outward.normalized() if outward.length > .01 else UP
        up = (UP * .55 + outward * .45 + unit(rng) * .2).normalized()
        normal = (outward - up * outward.dot(up))
        normal = normal.normalized() if normal.length > .01 else perpendicular(up)
        normal = rotate(normal, up, rng.uniform(-.6, .6))
        weight = sum(c[4] for c in group) / len(group)
        size = cell * rng.uniform(1.55, 1.9) * min(1.25, .75 + .1 * len(group))
        base = center - up * size * .45
        clumps.append((base, up, normal, size, weight, group[0][5], tree.ao(center), 3))
    return clumps


def build_lod(tree, lod):
    mesh = MeshData()
    for b in tree.branches:
        level = min(b.level, 3)
        sides = LOD_SIDES[lod][level]
        if sides:
            sides = min(sides, max(3, int(b.radii[0] * 70) + 3))
        if sides == 0 or b.radii[0] < LOD_MIN_RADIUS[lod][level]:
            continue
        if tree.shrub and lod >= 2 and b.level > 0:
            continue
        tube(mesh, tree, b, sides, max(1, LOD_STRIDE[lod][level]), lod)
    if lod == 0:
        for card in tree.cards:
            leaf_card(mesh, tree, card, 1.0, card[7], True)
    elif lod == 1:
        for i, card in enumerate(tree.cards):
            if (i * 2654435761 % 1000) / 1000 < .45:
                leaf_card(mesh, tree, card, 1.42, card[7], False)
    else:
        cell = (1.5 if lod == 2 else 3.0) * (.6 if tree.shrub else 1.0)
        for clump in cluster_cards(tree, cell):
            leaf_card(mesh, tree, clump, 1.0, 3, False)
    return mesh


# ---------------------------------------------------------------- vines

def build_vine(name, spec, lod):
    """Grapevine trained up a pollard support or a stake with a cross pole."""
    rng = random.Random(spec["seed"])
    tree = Tree(name, dict(TREES["acer_campestre_arbustum"], seed=spec["seed"], card=spec["card"],
                           cards_per_m=spec["cards_per_m"], height=spec["height"], radius=spec["radius"],
                           crown_base=.4, envelope="ball"))
    if spec["support"] == "tree":
        # Old vine stem spiralling up the 3.1 m pollard (support radius ~0.2 m).
        pts, radii = [], []
        for i in range(25):
            t = i / 24
            a = t * TAU * 1.15 + .4
            z = -.1 + 3.0 * t
            r = .23 + .02 * math.sin(t * 9)
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
            radii.append(.06 * (1 - .4 * t))
        stem = Branch(1, pts, radii, rng.random(), [min(1, .12 * (i / 24)) for i in range(25)])
        tree.branches.append(stem)
        # Canes festoon outward and droop from the head.
        for k in range(9):
            az = k * 2.39996 + rng.uniform(-.2, .2)
            start = Vector((0, 0, 3.0 + rng.uniform(0, .5)))
            direction = Vector((math.cos(az), math.sin(az), .35)).normalized()
            cane = tree.grow_branch(start, direction, rng.uniform(1.8, 2.6), .022, .006, 2, -.16, .1, .0, .12, rng.random(), 8)
            tree.branches.append(cane)
    else:
        # Stake (palus) and cross pole (iugum) in the right half of the vine bark texture.
        stake = Branch(1, [Vector((0, .0, -.3)), Vector((0, 0, 1.7))], [.04, .035], 0, [0, 0])
        stake.stake = True
        tree.branches.append(stake)
        pole = Branch(1, [Vector((-1.25, 0, 1.45)), Vector((1.25, 0, 1.45))], [.025, .025], 0, [0, 0])
        pole.stake = True
        tree.branches.append(pole)
        pts = [Vector((.07 + .02 * math.sin(i), .05 * math.cos(i * 1.3), -.1 + i * .14)) for i in range(11)]
        stem = Branch(1, pts, [.045 * (1 - .3 * i / 10) for i in range(11)], rng.random(), [.05 * i / 10 for i in range(11)])
        tree.branches.append(stem)
        for side in (-1, 1):
            for k in range(2):
                start = Vector((.05, 0, 1.4))
                direction = Vector((side, rng.uniform(-.2, .2), .05 + .1 * k)).normalized()
                cane = tree.grow_branch(start, direction, rng.uniform(1.0, 1.3), .016, .005, 2, -.05, .06, 0, .1, rng.random(), 7)
                tree.branches.append(cane)
        for k in range(4):
            start = Vector((.05, 0, 1.45))
            direction = Vector((rng.uniform(-.5, .5), rng.uniform(-.5, .5), 1)).normalized()
            cane = tree.grow_branch(start, direction, rng.uniform(.6, .9), .012, .004, 2, -.25, .2, 0, .15, rng.random(), 6)
            tree.branches.append(cane)
    tree.crown_center = Vector((0, 0, 3.4 if spec["support"] == "tree" else 1.4))
    tree.place_cards()
    mesh = MeshData()
    for b in tree.branches:
        sides = (8, 5, 4, 3)[lod] if b.level == 1 else (4, 3, 0, 0)[lod]
        if sides == 0:
            continue
        before = len(mesh.uvs)
        tube(mesh, tree, b, sides, 1 if lod < 2 else 3, lod)
        # Vine bark uses the left half of the texture; stakes the right half.
        offset = .5 if getattr(b, "stake", False) else 0.0
        for f in range(before, len(mesh.uvs)):
            mesh.uvs[f] = tuple((offset + min(u / b.repeats, 1.0) * .5, v) for u, v in mesh.uvs[f])
    if lod == 0:
        for card in tree.cards:
            leaf_card(mesh, tree, card, 1.0, card[7], True)
    elif lod == 1:
        for i, card in enumerate(tree.cards):
            if i % 2 == 0:
                leaf_card(mesh, tree, card, 1.4, card[7], False)
    else:
        for clump in cluster_cards(tree, 1.0 if lod == 2 else 1.8):
            leaf_card(mesh, tree, clump, .85, 3, False)
    return tree, mesh


# --------------------------------------------------------------- blender

def material(name, bark, leaf_tex, kind):
    """Export material (name only reaches Godot) with a full node tree for
    Cycles impostor/review renders."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = .85 if kind == "bark" else .6
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    path = TEX / (f"bark_{bark}" if kind == "bark" else f"leaf_{leaf_tex}")
    image = bpy.data.images.load(str(path) + "_albedo.png", check_existing=True)
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(attr.outputs["Color"], sep.inputs["Color"])
    mul = nodes.new("ShaderNodeVectorMath")
    mul.operation = "MULTIPLY"
    links.new(tex.outputs["Color"], mul.inputs[0])
    ao_rgb = nodes.new("ShaderNodeCombineColor")
    links.new(attr.outputs["Alpha"], ao_rgb.inputs["Red"])
    links.new(attr.outputs["Alpha"], ao_rgb.inputs["Green"])
    links.new(attr.outputs["Alpha"], ao_rgb.inputs["Blue"])
    links.new(ao_rgb.outputs["Color"], mul.inputs[1])
    links.new(mul.outputs["Vector"], bsdf.inputs["Base Color"])
    normal_img = bpy.data.images.load(str(path) + "_normal.png", check_existing=True)
    normal_img.colorspace_settings.name = "Non-Color"
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = normal_img
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if kind == "leaf":
        mask = nodes.new("ShaderNodeMath")
        mask.operation = "GREATER_THAN"
        mask.inputs[1].default_value = .45
        links.new(tex.outputs["Alpha"], mask.inputs[0])
        links.new(mask.outputs[0], bsdf.inputs["Alpha"])
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
        trans = bsdf.inputs.get("Transmission Weight")
        if trans:
            trans.default_value = .15
    mat["vegetation_kind"] = kind
    return mat


def to_object(name, mesh, materials):
    data = bpy.data.meshes.new(name)
    data.from_pydata(mesh.verts, [], mesh.faces)
    data.update()
    for m in materials:
        data.materials.append(m)
    uv = data.uv_layers.new(name="UVMap")
    for poly, coords, mat in zip(data.polygons, mesh.uvs, mesh.mats):
        poly.material_index = mat
        poly.use_smooth = True
        for loop, coordinate in zip(poly.loop_indices, coords):
            uv.data[loop].uv = coordinate
    col = data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    flat = []
    for c in mesh.colors:
        flat.extend(c)
    col.data.foreach_set("color", flat)
    data.color_attributes.active_color = col
    data.normals_split_custom_set_from_vertices(mesh.normals)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_image_format="NONE",
                              export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_normals=True, export_tangents=False, export_animations=False, export_yup=True,
                              export_apply=False)


# ------------------------------------------------------------- impostors

def bake_impostor(name, lod0):
    """Render LOD0 from 8 azimuths (orthographic) into albedo and camera-space
    normal atlases. Frame k shows the tree seen from azimuth k*45 degrees."""
    import numpy as np
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 0
    scene.cycles.transparent_max_bounces = 48
    scene.render.film_transparent = True
    scene.render.resolution_x = IMPOSTOR_FRAME
    scene.render.resolution_y = IMPOSTOR_FRAME
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filter_size = 1.0
    height = max(v.co.z for v in lod0.data.vertices)
    radius = max(math.hypot(v.co.x, v.co.y) for v in lod0.data.vertices) * 1.03
    size = max(height * 1.04, radius * 2.0)
    center_z = max(height * .5, size * .5 - .05) if size > height else height * .5
    cam_data = bpy.data.cameras.new("impostor_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size
    cam = bpy.data.objects.new("impostor_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -60, center_z)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    cam_data.clip_start, cam_data.clip_end = 1, 140
    scene.camera = cam
    world = bpy.data.worlds.new("w")
    scene.world = world
    # Emission-only overrides: one pass for AO-multiplied albedo, one for normals.
    originals = [slot.material for slot in lod0.material_slots]
    passes = {}
    for mode in ("albedo", "normal"):
        scene.view_settings.view_transform = "Standard" if mode == "albedo" else "Raw"
        scene.view_settings.look = "None"
        overrides = [emission_override(m, mode) for m in originals]
        for slot, m in zip(lod0.material_slots, overrides):
            slot.material = m
        frames = []
        for k in range(IMPOSTOR_VIEWS):
            lod0.rotation_euler = (0, 0, -k * TAU / IMPOSTOR_VIEWS)
            path = Path(bpy.app.tempdir) / f"imp_{name}_{mode}_{k}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(str(path))
            arr = np.empty(IMPOSTOR_FRAME * IMPOSTOR_FRAME * 4, dtype=np.float32)
            img.pixels.foreach_get(arr)
            arr = arr.reshape(IMPOSTOR_FRAME, IMPOSTOR_FRAME, 4)
            frames.append(arr)
            bpy.data.images.remove(img)
        passes[mode] = frames
    for slot, m in zip(lod0.material_slots, originals):
        slot.material = m
    lod0.rotation_euler = (0, 0, 0)
    for mode in ("albedo", "normal"):
        atlas = np.concatenate(passes[mode], axis=1)  # rows bottom-up (Blender pixel order)
        alpha = np.concatenate(passes["albedo"], axis=1)[..., 3]
        if mode == "albedo":
            atlas = dilate(atlas, alpha)
        else:
            atlas[..., 3] = 1.0
            atlas[..., :3] = np.where(alpha[..., None] > .01, atlas[..., :3], np.array([.5, .5, 1.0]))
        img = bpy.data.images.new(f"impostor_{name}_{mode}", IMPOSTOR_FRAME * IMPOSTOR_VIEWS, IMPOSTOR_FRAME, alpha=True)
        img.colorspace_settings.name = "sRGB" if mode == "albedo" else "Non-Color"
        img.pixels.foreach_set(atlas.ravel())
        img.filepath_raw = str(TEX / f"impostor_{name}_{mode}.png")
        img.file_format = "PNG"
        img.save()
    bpy.data.objects.remove(cam)
    return {"frame_size_m": size, "center_height_m": center_z, "views": IMPOSTOR_VIEWS, "frame_px": IMPOSTOR_FRAME}


def dilate(rgba, alpha):
    import numpy as np
    color = rgba[..., :3] * alpha[..., None]
    weight = alpha.copy()
    acc_c, acc_w = color.copy(), weight.copy()
    for step in (1, 2, 4, 8, 16):
        for axis in (0, 1):
            color = (np.roll(color, step, axis) + np.roll(color, -step, axis) + color) / 3
            weight = (np.roll(weight, step, axis) + np.roll(weight, -step, axis) + weight) / 3
        need = acc_w < .3
        acc_c[need] = color[need]
        acc_w[need] = weight[need]
    out = rgba.copy()
    filled = acc_c / np.maximum(acc_w[..., None], 1e-4)
    out[..., :3] = np.where(alpha[..., None] > .05, rgba[..., :3], filled)
    out[..., 3] = alpha
    return out


def emission_override(src, mode):
    name = f"{src.name}__{mode}"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    src_nodes = src.node_tree.nodes
    tex_images = [n for n in src_nodes if n.type == "TEX_IMAGE"]
    albedo = next(n.image for n in tex_images if n.image.colorspace_settings.name != "Non-Color")
    normal_img = next(n.image for n in tex_images if n.image.colorspace_settings.name == "Non-Color")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = albedo
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    if mode == "albedo":
        mul = nodes.new("ShaderNodeVectorMath")
        mul.operation = "MULTIPLY"
        links.new(tex.outputs["Color"], mul.inputs[0])
        ao = nodes.new("ShaderNodeCombineColor")
        for ch in ("Red", "Green", "Blue"):
            links.new(attr.outputs["Alpha"], ao.inputs[ch])
        links.new(ao.outputs["Color"], mul.inputs[1])
        links.new(mul.outputs["Vector"], emit.inputs["Color"])
    else:
        ntex = nodes.new("ShaderNodeTexImage")
        ntex.image = normal_img
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        xf = nodes.new("ShaderNodeVectorTransform")
        xf.vector_type = "NORMAL"
        xf.convert_from = "WORLD"
        xf.convert_to = "CAMERA"
        links.new(nmap.outputs["Normal"], xf.inputs["Vector"])
        # Blender camera space: x right, y up, z toward the viewer -> 0..1.
        scale = nodes.new("ShaderNodeVectorMath")
        scale.operation = "MULTIPLY_ADD"
        scale.inputs[1].default_value = (.5, .5, .5)
        scale.inputs[2].default_value = (.5, .5, .5)
        links.new(xf.outputs["Vector"], scale.inputs[0])
        links.new(scale.outputs["Vector"], emit.inputs["Color"])
    shader = emit
    if src.get("vegetation_kind") == "leaf":
        mask = nodes.new("ShaderNodeMath")
        mask.operation = "GREATER_THAN"
        mask.inputs[1].default_value = .45
        links.new(tex.outputs["Alpha"], mask.inputs[0])
        transparent = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(mask.outputs[0], mix.inputs["Fac"])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(emit.outputs[0], mix.inputs[2])
        shader = mix
    links.new(shader.outputs[0], out.inputs["Surface"])
    return mat


# ----------------------------------------------------------------- cards

def build_cards():
    """Herb/crop clump meshes: crossed, slightly bent cards. UVs cover tile 0
    of the 4 x 4 atlas; the shader offsets them per instance."""
    objects = []
    for name, planes, rows in (("clump_near", 3, 3), ("clump_far", 2, 1)):
        mesh = MeshData()
        for k in range(planes):
            yaw = k * math.pi / planes + .2
            axis = Vector((math.cos(yaw), math.sin(yaw), 0))
            facing = Vector((-axis.y, axis.x, 0))
            phase = (k * .37) % 1.0
            ids = []
            for r in range(rows + 1):
                t = r / rows
                lean = facing * .12 * t * t
                for s in (-1, 1):
                    q = axis * .5 * s * (1 - .15 * t) + UP * t + lean
                    n = (UP * .7 + facing * .3).normalized()
                    ids.append((mesh.add_vertex(q, n, (t * t, phase, t, .45 + .55 * t)), .002 if s < 0 else .248, .752 + .246 * t))
            for r in range(rows):
                a, b, c, d = ids[r * 2], ids[r * 2 + 1], ids[r * 2 + 3], ids[r * 2 + 2]
                mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2]), (d[1], d[2])), 0)
        mat = bpy.data.materials.get("herb_cards") or bpy.data.materials.new("herb_cards")
        objects.append(to_object(name, mesh, [mat]))
    objects += build_grass_tufts()
    return objects


def build_grass_tufts():
    """Meadow grass with individual blades (no texture, no alpha test): each
    blade is a tapered, curved strip. grass_tuft_near has 22 blades of four
    segments, grass_tuft_far 9 wider blades of two segments for the outer
    ring. Unit height 1 (instances scale it); footprint radius about 0.24 m.
    Vertex colour: R bend weight (t squared), G blade phase, B height along
    the blade (0 root .. 1 tip), A root occlusion. UV: u across, v along."""
    objects = []
    mat = bpy.data.materials.get("grass_blades") or bpy.data.materials.new("grass_blades")
    for name, blades, segments, width, seed in (("grass_tuft_near", 22, 4, .021, 9101), ("grass_tuft_far", 9, 2, .05, 9103)):
        rng = random.Random(seed)
        mesh = MeshData()
        for k in range(blades):
            az = k * 2.39996 + rng.uniform(-.4, .4)
            ring = math.sqrt((k + .5) / blades) * .24
            root = Vector((math.cos(az) * ring, math.sin(az) * ring, 0))
            # Blades lean outward from the tuft centre and arch over.
            heading = az + rng.uniform(-.9, .9)
            out = Vector((math.cos(heading), math.sin(heading), 0))
            side = Vector((-out.y, out.x, 0))
            tall = rng.uniform(.55, 1.0)
            lean = rng.uniform(.05, .22) * tall
            arch = rng.uniform(.08, .34) * tall
            w = width * rng.uniform(.75, 1.25)
            phase = rng.random()
            twist = rng.uniform(-.5, .5)
            ids = []
            for i in range(segments + 1):
                t = i / segments
                centre = root + out * (lean * t + arch * t * t) + UP * tall * (t - .16 * t * t)
                half = w * .5 * (1 - t) ** .7 if i < segments else 0.0
                across = (side * math.cos(twist * t) + out * math.sin(twist * t)).normalized()
                slope = (out * (lean + 2 * arch * t) + UP * tall * (1 - .32 * t)).normalized()
                face = across.cross(slope).normalized()
                normal = (UP * .7 + face * .3).normalized()
                color = (t * t, phase, t, .34 + .66 * t)
                if i < segments:
                    ids.append([(mesh.add_vertex(centre - across * half, normal, color), 0.0, t),
                                (mesh.add_vertex(centre + across * half, normal, color), 1.0, t)])
                else:
                    ids.append([(mesh.add_vertex(centre, normal, color), .5, 1.0)])
            for i in range(segments):
                lo, hi = ids[i], ids[i + 1]
                if len(hi) == 2:
                    a, b, c, d = lo[0], lo[1], hi[1], hi[0]
                    mesh.face((a[0], b[0], c[0], d[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2]), (d[1], d[2])), 0)
                else:
                    a, b, c = lo[0], lo[1], hi[0]
                    mesh.face((a[0], b[0], c[0]), ((a[1], a[2]), (b[1], b[2]), (c[1], c[2])), 0)
        objects.append(to_object(name, mesh, [mat]))
    return objects


# ------------------------------------------------------------------ main

def build_asset(name, kind, impostors):
    clear_scene()
    if kind == "vine":
        spec = VINES[name]
        bark_mat = material(f"bark_{spec['bark']}", spec["bark"], spec["leaf"], "bark")
        leaf_mat = material(f"leaf_{spec['leaf']}", spec["bark"], spec["leaf"], "leaf")
        objects, tree = [], None
        for lod in range(4):
            tree, mesh = build_vine(name, spec, lod)
            objects.append(to_object(f"{name}_lod{lod}", mesh, [bark_mat, leaf_mat]))
    else:
        spec = TREES.get(name) or SHRUBS[name]
        tree = Tree(name, spec, shrub=name in SHRUBS)
        tree.grow()
        bark_mat = material(f"bark_{spec['bark']}", spec["bark"], spec["leaf"], "bark")
        leaf_mat = material(f"leaf_{spec['leaf']}", spec["bark"], spec["leaf"], "leaf")
        objects = [to_object(f"{name}_lod{lod}", build_lod(tree, lod), [bark_mat, leaf_mat]) for lod in range(4)]
    path = OUT / f"{name}.glb"
    export(path, objects)
    record = {"asset": name, "kind": kind, "bark": spec["bark"], "leaf": spec["leaf"],
              "triangles": [triangles(o) for o in objects],
              "height_m": round(max(v.co.z for v in objects[0].data.vertices), 3),
              "crown_radius_m": round(max(math.hypot(v.co.x, v.co.y) for v in objects[0].data.vertices), 3),
              "branches": len(tree.branches) if tree else 0, "leaf_cards_lod0": len(tree.cards) if tree else 0,
              "bytes": path.stat().st_size}
    if impostors and kind != "vine":
        for o in objects[1:]:
            o.hide_render = True
        record["impostor"] = bake_impostor(name, objects[0])
    return record


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    impostors = "--no-impostors" not in argv
    wanted = [a for a in argv if not a.startswith("--")]
    assets = [(n, "tree") for n in TREES] + [(n, "shrub") for n in SHRUBS] + [(n, "vine") for n in VINES]
    if wanted:
        assets = [a for a in assets if a[0] in wanted]
    OUT.mkdir(parents=True, exist_ok=True)
    metrics_path = SOURCE / "metrics.json"
    metrics = json.loads(metrics_path.read_text()) if metrics_path.exists() else {}
    for name, kind in assets:
        record = build_asset(name, kind, impostors)
        if not impostors and name in metrics and "impostor" in metrics[name]:
            record["impostor"] = metrics[name]["impostor"]
        metrics[name] = record
        print("VEGETATION_ASSET", json.dumps(record), flush=True)
    if not wanted or "herb_cards" in wanted:
        clear_scene()
        objects = build_cards()
        export(OUT / "herb_cards.glb", objects)
        metrics["herb_cards"] = {"asset": "herb_cards", "kind": "cards", "triangles": [triangles(o) for o in objects]}
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n")
    manifest = {"schema_version": 1, "generator": "art/vegetation/build.py", "assets": {}}
    for name, record in sorted(metrics.items()):
        manifest["assets"][name] = {k: record[k] for k in ("kind", "bark", "leaf", "triangles", "height_m", "crown_radius_m", "impostor") if k in record}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("VEGETATION_BUILD_DONE", len(assets), flush=True)


if __name__ == "__main__":
    main()
