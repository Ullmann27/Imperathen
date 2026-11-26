"""Modular building kit of the Valdora house family (Blender side, metres, Z up, front -Y).

Every piece writes into a Mesh accumulator instead of creating Blender objects,
so a whole house with thousands of stones, boards and tiles stays one compact
mesh per level of detail. Per corner the accumulator stores:

  UVMap  metric texture coordinates (layer repeats, see family_textures.LAYERS)
  Layer  (texture-array slice, per-element random 0..1)
  Col    ageing masks: R damp/dirt, G moss/lichen, B soot, A worn edge

The Godot shader (prototype/scripts/world/village/architecture/valdora_house.gdshader)
reads exactly these attributes. Nothing here is tied to one house: the house
recipes in family_houses.py assemble these pieces with their own seeds.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field

from mathutils import Matrix, Vector

LAYERS = ["plaster_lime", "plaster_aged", "opus_incertum", "rubble_socle", "ashlar", "daub", "oak_grey",
          "oak_brown", "tegula", "tegula_old", "mortar", "iron", "paint_red", "paint_ochre", "flagstone",
          "cocciopesto"]
REPEAT = {"plaster_lime": 2.0, "plaster_aged": 2.0, "opus_incertum": 1.6, "rubble_socle": 1.6, "ashlar": 1.5,
          "daub": 1.6, "oak_grey": 1.0, "oak_brown": 1.0, "tegula": 1.0, "tegula_old": 1.0, "mortar": 1.0,
          "iron": 0.5, "paint_red": 2.0, "paint_ochre": 2.0, "flagstone": 1.2, "cocciopesto": 1.6}
LAYER = {name: i for i, name in enumerate(LAYERS)}
Z = Vector((0, 0, 1))


def hash_noise(x, y, z=0.0, seed=0):
    """Smooth value noise in [-1, 1] without NumPy (deterministic, metres in)."""
    def lattice(ix, iy, iz):
        h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 974634243) & 0xFFFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 32767.5 - 1.0
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    sx, sy, sz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    def lerp(a, b, t):
        return a + (b - a) * t
    c = [[[lattice(ix + i, iy + j, iz + k) for k in (0, 1)] for j in (0, 1)] for i in (0, 1)]
    return lerp(lerp(lerp(c[0][0][0], c[1][0][0], sx), lerp(c[0][1][0], c[1][1][0], sx), sy),
                lerp(lerp(c[0][0][1], c[1][0][1], sx), lerp(c[0][1][1], c[1][1][1], sx), sy), sz)


def fbm(x, y, z=0.0, seed=0, octaves=3):
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        total += amp * hash_noise(x * freq, y * freq, z * freq, seed + o * 17)
        norm += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


@dataclass
class Ageing:
    """Global ageing field of one house: where damp, moss and soot collect."""
    seed: int = 0
    damp_height: float = 0.85      # rising damp reaches this high (m)
    moss: float = 0.5              # 0 clean roof .. 1 heavily overgrown
    soot_points: list = field(default_factory=list)  # (Vector, radius)

    def masks(self, p: Vector, n: Vector, layer: str, wear: float = 0.0):
        z = p.z
        noise = fbm(p.x * 0.9, p.y * 0.9, p.z * 0.9, self.seed)
        fine = hash_noise(p.x * 4.1, p.y * 4.1, p.z * 4.1, self.seed + 5)
        vertical = 1.0 - abs(n.z)
        # Rising damp and splash zone on walls and socle; ground contact on posts.
        damp = (1.0 - smoothstep(0.05, self.damp_height + 0.25 * noise, z)) * (0.55 + 0.45 * vertical)
        damp = max(damp, 0.6 * (1.0 - smoothstep(0.0, 0.35, z)))
        moss = 0.0
        if layer in ("tegula", "tegula_old", "mortar"):
            # Tiles: lichen and moss favour lower courses, the shaded rear and overlaps.
            rear = 0.5 + 0.5 * max(-1.0, min(1.0, p.y / 3.0))
            moss = self.moss * max(0.0, n.z) * (0.35 + 0.65 * rear) * smoothstep(-0.2, 0.55, noise + 0.25 * fine)
        elif layer in ("rubble_socle", "opus_incertum", "flagstone", "ashlar") and z < 0.9:
            moss = self.moss * 0.7 * (1.0 - smoothstep(0.0, 0.7, z)) * smoothstep(-0.1, 0.6, noise)
        elif layer in ("oak_grey",) and n.z > 0.5:
            moss = self.moss * 0.35 * smoothstep(0.0, 0.7, noise)
        soot = 0.0
        for point, radius in self.soot_points:
            d = (p - point).length
            soot = max(soot, (1.0 - smoothstep(radius * 0.25, radius, d)) * (0.75 + 0.25 * fine))
        return (max(0.0, min(1.0, damp)), max(0.0, min(1.0, moss)), max(0.0, min(1.0, soot)),
                max(0.0, min(1.0, wear)))


class Mesh:
    """Polygon soup with per-corner UV, layer and ageing masks."""

    def __init__(self, name, ageing: Ageing):
        self.name = name
        self.ageing = ageing
        self.verts = []
        self.faces = []
        self.uv = []
        self.layer = []
        self.col = []

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)

    def face(self, points, layer, rnd=0.0, outward=None, uv_basis=None, wear=0.0, uv=None, offset=(0.0, 0.0), colors=None):
        points = [Vector(p) for p in points]
        if len(points) < 3:
            return
        normal = Vector((0, 0, 0))
        for i in range(len(points)):
            a, b = points[i], points[(i + 1) % len(points)]
            normal += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        if normal.length < 1e-10:
            return
        normal.normalize()
        if outward is not None and normal.dot(outward) < 0:
            points.reverse()
            if uv is not None:
                uv = list(reversed(uv))
            if colors is not None:
                colors = list(reversed(colors))
            normal = -normal
        if uv is None:
            if uv_basis is not None:
                u_axis, v_axis = uv_basis
                u_axis = (u_axis - normal * u_axis.dot(normal))
                if u_axis.length < 1e-6:
                    u_axis = Vector((1, 0, 0))
                u_axis.normalize()
                v_axis = normal.cross(u_axis)
            elif abs(normal.z) < 0.9:
                u_axis = Z.cross(normal).normalized()
                v_axis = normal.cross(u_axis)
            else:
                u_axis = Vector((1, 0, 0))
                v_axis = normal.cross(u_axis)
            scale = 1.0 / REPEAT[layer]
            uv = [((p.dot(u_axis)) * scale + offset[0], (p.dot(v_axis)) * scale + offset[1]) for p in points]
        start = len(self.verts)
        self.verts.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))
        self.uv.extend(uv)
        self.layer.extend([(LAYER[layer], rnd)] * len(points))
        if colors is None:
            colors = [self.ageing.masks(p, normal, layer, wear) for p in points]
        self.col.extend(colors)

    # ----------------------------------------------------------------- solids
    def chamfer_box(self, centre, size, layer, basis=None, chamfer=0.02, rnd=0.0, grain=None,
                    skip=(), jitter=0.0, rng=None, wear=1.0, offset=None):
        """Cuboid whose 12 edges are chamfered (rounded look after weighted normals).

        skip: faces to omit, e.g. ('-z',) for a stone set on a bed.
        grain: local axis index (0,1,2) along which wood grain / texture v runs.
        """
        c = Vector(centre)
        basis = basis or Matrix.Identity(3)
        half = [s / 2 for s in size]
        ch = min(chamfer, *(h * 0.45 for h in half))
        corners = {}
        rng = rng or random.Random(0)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    s = (sx, sy, sz)
                    j = Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter))) if jitter else Vector()
                    for axis in range(3):
                        local = [s[k] * (half[k] - (0 if k == axis else ch)) for k in range(3)]
                        corners[s + (axis,)] = c + basis @ (Vector(local) + j)
        axes = [basis.col[0].normalized(), basis.col[1].normalized(), basis.col[2].normalized()]
        if offset is None:
            offset = (rnd * 7.31 % 1.0, rnd * 3.17 % 1.0)
        def uvb(normal):
            if grain is None:
                return None
            g = axes[grain]
            if abs(g.dot(normal)) > 0.9:
                return None
            v = g
            u = v.cross(normal)
            return (u, v)
        names = {0: 'x', 1: 'y', 2: 'z'}
        for axis in range(3):
            for sign in (-1, 1):
                if f"{'-' if sign < 0 else '+'}{names[axis]}" in skip:
                    continue
                pts = [corners[s + (axis,)] for s in self._ring(axis, sign)]
                normal = axes[axis] * sign
                self.face(pts, layer, rnd, outward=normal, uv_basis=uvb(normal), offset=offset)
        if ch <= 1e-5:
            return
        for a in range(3):
            for b in range(a + 1, 3):
                k = 3 - a - b
                for sa in (-1, 1):
                    for sb in (-1, 1):
                        pts = []
                        for sk in (-1, 1):
                            s = [0, 0, 0]
                            s[a], s[b], s[k] = sa, sb, sk
                            pts.append((tuple(s), a))
                            pts.append((tuple(s), b))
                        quad = [corners[pts[0][0] + (pts[0][1],)], corners[pts[1][0] + (pts[1][1],)],
                                corners[pts[3][0] + (pts[3][1],)], corners[pts[2][0] + (pts[2][1],)]]
                        normal = (axes[a] * sa + axes[b] * sb).normalized()
                        self.face(quad, layer, rnd, outward=normal, uv_basis=uvb(normal), offset=offset, wear=wear)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    s = (sx, sy, sz)
                    tri = [corners[s + (0,)], corners[s + (1,)], corners[s + (2,)]]
                    normal = (axes[0] * sx + axes[1] * sy + axes[2] * sz).normalized()
                    self.face(tri, layer, rnd, outward=normal, offset=offset, wear=wear)

    @staticmethod
    def _ring(axis, sign):
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        ring = []
        for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            s = [0, 0, 0]
            s[axis], s[a], s[b] = sign, sa, sb
            ring.append(tuple(s))
        return ring

    def beam(self, p1, p2, width, depth, layer, chamfer=0.015, rnd=0.0, roll=0.0, rng=None, skip=()):
        p1, p2 = Vector(p1), Vector(p2)
        d = p2 - p1
        z_axis = d.normalized()
        ref = Z if abs(z_axis.z) < 0.95 else Vector((1, 0, 0))
        x_axis = ref.cross(z_axis).normalized()
        y_axis = z_axis.cross(x_axis)
        basis = Matrix((x_axis, y_axis, z_axis)).transposed() @ Matrix.Rotation(roll, 3, 'Z')
        self.chamfer_box((p1 + p2) / 2, (width, depth, d.length), layer, basis, chamfer, rnd, grain=2, rng=rng, skip=skip)

    def prism(self, profile, start, end, layer, rnd=0.0, caps=(True, True), closed=True, uv_v=None, wear_edges=()):
        """Extrude a 2D profile [(x, z) in a local frame] from start to end.

        The local frame: x across (perpendicular to the path, horizontal), z up
        relative to the path. Used for tiles, mouldings, cornices and ridges.
        """
        start, end = Vector(start), Vector(end)
        d = (end - start)
        along = d.normalized()
        side = along.cross(Z)
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(along).normalized()
        rings = []
        for base in (start, end):
            rings.append([base + side * x + up * z for x, z in profile])
        n = len(profile)
        count = n if closed else n - 1
        for i in range(count):
            j = (i + 1) % n
            quad = [rings[0][i], rings[0][j], rings[1][j], rings[1][i]]
            mid = (Vector(profile[i]) + Vector(profile[j])) / 2
            out = side * mid.x + up * mid.y
            wear = 1.0 if i in wear_edges else 0.0
            self.face(quad, layer, rnd, outward=out if out.length > 1e-6 else up, uv_basis=(side, along), wear=wear)
        for k, cap in enumerate(caps):
            if cap and closed:
                pts = rings[k] if k == 1 else list(reversed(rings[k]))
                self.face(pts, layer, rnd, outward=along if k == 1 else -along)

    def lathe(self, profile, centre, layer, segments=12, rnd=0.0, axis=None, phase=0.0):
        """Revolve [(radius, height)] around a vertical axis at centre."""
        centre = Vector(centre)
        rings = []
        for r, h in profile:
            ring = []
            for s in range(segments):
                a = phase + 2 * math.pi * s / segments
                ring.append(centre + Vector((math.cos(a) * r, math.sin(a) * r, h)))
            rings.append(ring)
        for i in range(len(profile) - 1):
            for s in range(segments):
                t = (s + 1) % segments
                quad = [rings[i][s], rings[i][t], rings[i + 1][t], rings[i + 1][s]]
                mid = (quad[0] + quad[2]) / 2
                out = Vector((mid.x - centre.x, mid.y - centre.y, 0))
                if profile[i + 1][0] < 1e-4 and profile[i][0] < 1e-4:
                    continue
                if abs(profile[i + 1][0] - profile[i][0]) > abs(profile[i + 1][1] - profile[i][1]) * 2:
                    out = Vector((0, 0, 1 if profile[i + 1][0] < profile[i][0] else -1))
                a0 = 2 * math.pi * s / segments
                a1 = 2 * math.pi * (s + 1) / segments
                circumference = 2 * math.pi * max(profile[i][0], 0.01)
                u0, u1 = a0 / (2 * math.pi) * circumference / REPEAT[layer], a1 / (2 * math.pi) * circumference / REPEAT[layer]
                v0, v1 = profile[i][1] / REPEAT[layer], profile[i + 1][1] / REPEAT[layer]
                self.face(quad, layer, rnd, outward=out, uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
        top_r, top_h = profile[-1]
        if top_r > 1e-4:
            self.face(rings[-1], layer, rnd, outward=Z)

    def merge(self, other):
        offset = len(self.verts)
        self.verts.extend(other.verts)
        self.faces.extend(tuple(i + offset for i in f) for f in other.faces)
        self.uv.extend(other.uv)
        self.layer.extend(other.layer)
        self.col.extend(other.col)


# ------------------------------------------------------------------- walls
@dataclass
class Opening:
    u0: float
    u1: float
    v0: float
    v1: float
    kind: str = "window"       # window | door
    reveal: str = "plaster_lime"


def _breaks(lo, hi, cuts, cell):
    values = sorted(set([lo, hi] + [c for c in cuts if lo < c < hi]))
    out = [values[0]]
    for a, b in zip(values, values[1:]):
        steps = max(1, math.ceil((b - a) / cell - 1e-6))
        for k in range(1, steps + 1):
            out.append(a + (b - a) * k / steps)
    return out


def wall(mesh, origin, u_axis, length, top, thickness, openings, outer_layer, core_layer, rng,
         loss=0.0, cell=0.16, relief=0.006, loss_depth=0.024, inner_layer="plaster_lime", inner=True,
         bottom=0.0, seed=0, paint=None, start_cap=False, end_cap=False):
    """One wall: displaced outer render with real loss patches, flat inner face, reveals.

    origin: outer face, ground-level corner (start of the wall) in Blender metres
    u_axis: horizontal direction along the outer face (outside is u_axis x Z)
    top(u) -> height of the wall top along the wall (wall plate or gable line)
    openings: list of Opening in (u, height) coordinates
    paint: (layer, height) lime-wash band from 'bottom' to height on the outer face
    """
    origin = Vector(origin)
    u_axis = Vector(u_axis).normalized()
    out = u_axis.cross(Z).normalized()
    inward = -out
    max_top = max(top(0.0), top(length), top(length * 0.5))
    ucuts = [v for op in openings for v in (op.u0, op.u1)]
    vcuts = [v for op in openings for v in (op.v0, op.v1)]
    if paint:
        vcuts.append(paint[1])
    us = _breaks(0.0, length, ucuts, cell)
    vs = _breaks(bottom, max_top, vcuts, cell)

    def inside_opening(u, v):
        return any(op.u0 - 1e-6 <= u <= op.u1 + 1e-6 and op.v0 - 1e-6 <= v <= op.v1 + 1e-6 for op in openings)

    fixed_u = set(round(x, 5) for x in [0.0, length] + ucuts)
    fixed_v = set(round(x, 5) for x in [bottom] + vcuts)

    def point(i, j, depth=0.0):
        u, v = us[i], vs[j]
        v = min(v, top(u))
        du = dv = 0.0
        if round(us[i], 5) not in fixed_u:
            du = hash_noise(u * 7.3, vs[j] * 7.3, 0, seed) * cell * 0.28
        if round(vs[j], 5) not in fixed_v and vs[j] < top(u) - 1e-4:
            dv = hash_noise(u * 6.1, vs[j] * 6.1, 3, seed) * cell * 0.28
        bulge = relief * fbm(u * 1.1, v * 1.1, 0, seed + 9) + relief * 0.6 * hash_noise(u * 6, v * 6, 1, seed)
        return origin + u_axis * (u + du) + Z * (min(v + dv, top(u + du))) + out * (bulge - depth)

    nu, nv = len(us) - 1, len(vs) - 1
    lost = {}
    for i in range(nu):
        for j in range(nv):
            uc, vc = (us[i] + us[i + 1]) / 2, (vs[j] + vs[j + 1]) / 2
            if vc > top(uc) or inside_opening(uc, vc):
                lost[(i, j)] = None
                continue
            near_edge = min(uc, length - uc) < 0.12
            m = fbm(uc * 1.3, vc * 1.3, 7, seed + 21) + 0.35 * hash_noise(uc * 5, vc * 5, 2, seed)
            # Loss gathers near the ground, at corners and below openings.
            bias = 0.35 * (1 - smoothstep(0.2, 1.4, vc)) + (0.15 if near_edge else 0.0)
            lost[(i, j)] = loss > 0 and (m + bias) > (1.0 - loss)

    def layer_at(vc, uc=0.0):
        if paint and vc < paint[1]:
            return paint[0]
        # Old render shows lighter patches where it was repaired over the years.
        if outer_layer == "plaster_aged" and fbm(uc * 0.8, vc * 0.8, 11, seed + 33) > 0.42:
            return "plaster_lime"
        return outer_layer

    for i in range(nu):
        for j in range(nv):
            state = lost[(i, j)]
            if state is None:
                continue
            vc = (vs[j] + vs[j + 1]) / 2
            if state:
                quad = [point(i, j, loss_depth), point(i + 1, j, loss_depth), point(i + 1, j + 1, loss_depth), point(i, j + 1, loss_depth)]
                mesh.face(quad, core_layer, 0.0, outward=out)
                # Broken render edges toward intact neighbours (real thickness).
                for di, dj, a, b in ((-1, 0, (i, j + 1), (i, j)), (1, 0, (i + 1, j), (i + 1, j + 1)),
                                     (0, -1, (i, j), (i + 1, j)), (0, 1, (i + 1, j + 1), (i, j + 1))):
                    neighbour = lost.get((i + di, j + dj), None if not (0 <= i + di < nu and 0 <= j + dj < nv) else False)
                    if neighbour is False:
                        pa, pb = point(*a), point(*b)
                        qa, qb = point(*a, loss_depth), point(*b, loss_depth)
                        edge_out = (u_axis * -di + Z * -dj)
                        mesh.face([pa, pb, qb, qa], layer_at(vc), 0.0, outward=edge_out, wear=1.0)
            else:
                quad = [point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)]
                mesh.face(quad, layer_at(vc, (us[i] + us[i + 1]) / 2), 0.0, outward=out)
    # Reveals: plaster returns into each opening, sill and head included.
    for op in openings:
        a = origin + u_axis * op.u0
        b = origin + u_axis * op.u1
        lo, hi = Z * op.v0, Z * min(op.v1, top((op.u0 + op.u1) / 2))
        o, n = out * 0.0, inward * thickness
        mesh.face([a + lo + o, a + hi + o, a + hi + n, a + lo + n], op.reveal, outward=u_axis, wear=0.3)
        mesh.face([b + lo + o, b + lo + n, b + hi + n, b + hi + o], op.reveal, outward=-u_axis, wear=0.3)
        mesh.face([a + hi + o, b + hi + o, b + hi + n, a + hi + n], op.reveal, outward=-Z, wear=0.3)
        if op.kind == "window":
            mesh.face([a + lo + o, a + lo + n, b + lo + n, b + lo + o], op.reveal, outward=Z, wear=0.3)
    if start_cap or end_cap:
        for u, sign, wanted in ((0.0, -1, start_cap), (length, 1, end_cap)):
            if not wanted:
                continue
            base = origin + u_axis * u
            h = top(u)
            mesh.face([base + Z * bottom, base + Z * bottom + inward * thickness, base + Z * h + inward * thickness, base + Z * h],
                      outer_layer, outward=u_axis * sign)
    if not inner:
        return
    # Inner face: flat lime plaster (the interior contract plane), split at openings.
    iorigin = origin + inward * thickness
    ius = _breaks(0.0, length, ucuts, 1.0)
    ivs = _breaks(bottom, max_top, vcuts, 1.0)
    for i in range(len(ius) - 1):
        for j in range(len(ivs) - 1):
            uc, vc = (ius[i] + ius[i + 1]) / 2, (ivs[j] + ivs[j + 1]) / 2
            if inside_opening(uc, vc) or vc > top(uc):
                continue
            pts = []
            for (uu, vv) in ((ius[i], ivs[j]), (ius[i + 1], ivs[j]), (ius[i + 1], ivs[j + 1]), (ius[i], ivs[j + 1])):
                pts.append(iorigin + u_axis * uu + Z * min(vv, top(uu)))
            mesh.face(pts, inner_layer, 0.0, outward=inward)


# ------------------------------------------------------------------- stones
def stone_course(mesh, a, b, z0, height, depth, rng, layer="flagstone", nominal=0.42, protrude=0.04,
                 out=None, chamfer=0.03, jitter=0.012, min_len=0.16):
    """Irregular field-stone course along a->b, faces proud of the wall by 'protrude'."""
    a, b = Vector(a), Vector(b)
    axis = (b - a)
    length = axis.length
    axis.normalize()
    out = out if out is not None else axis.cross(Z).normalized()
    t = 0.0
    while t < length - 0.02:
        size = rng.uniform(nominal * 0.55, nominal * 1.45)
        size = min(size, length - t)
        if length - t - size < min_len:
            size = length - t
        h = height * rng.uniform(0.72, 1.0)
        centre = a + axis * (t + size / 2) + Z * (z0 + h / 2 + rng.uniform(-0.01, 0.01)) + out * (protrude - depth / 2 + rng.uniform(-0.012, 0.012))
        yaw = rng.uniform(-0.04, 0.04)
        x_axis = (Matrix.Rotation(yaw, 3, 'Z') @ axis)
        basis = Matrix((x_axis, Z.cross(x_axis), Z)).transposed() @ Matrix.Rotation(rng.uniform(-0.03, 0.03), 3, 'X')
        mesh.chamfer_box(centre, (size - 0.022, depth, h - 0.02), layer, basis, chamfer * rng.uniform(0.7, 1.4),
                         rnd=rng.random(), jitter=jitter, rng=rng, skip=())
        t += size


def mortar_bed(mesh, a, b, z0, z1, recess, layer="mortar"):
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    out = axis.cross(Z).normalized()
    pts = [a + Z * z0 - out * recess, b + Z * z0 - out * recess, b + Z * z1 - out * recess, a + Z * z1 - out * recess]
    mesh.face(pts, layer, outward=out)


# -------------------------------------------------------------------- roofs
def tegula_profile(width, thickness=0.024, flange=0.048, flange_w=0.034):
    w = width / 2
    return [(-w, flange), (-w + flange_w, flange), (-w + flange_w, thickness), (w - flange_w, thickness),
            (w - flange_w, flange), (w, flange), (w, 0.0), (-w, 0.0)]


def imbrex_profile(radius, thick=0.016, segments=6, taper=1.0):
    outer = [(math.cos(math.pi * k / segments) * radius * taper, math.sin(math.pi * k / segments) * radius * taper) for k in range(segments + 1)]
    inner = [(math.cos(math.pi * k / segments) * (radius - thick) * taper, math.sin(math.pi * k / segments) * (radius - thick) * taper) for k in range(segments + 1)]
    return outer + list(reversed(inner))


def roof_slope(mesh, detail, eave_left, eave_right, ridge_left, ridge_right, rng, age=0.5, sag=0.03,
               tile_w=0.44, tile_l=0.58, overlap=0.11, layer_mix=0.25, missing=0.0, antefix=False, ridge=True):
    """Tegulae with flanges and tapered imbrices over their joints, one slope.

    Corners are given in Blender metres: eave_left/right along the eave line,
    ridge_left/right along the ridge (left/right seen from below the eave).
    """
    eL, eR, rL, rR = (Vector(v) for v in (eave_left, eave_right, ridge_left, ridge_right))
    across = (eR - eL)
    width = across.length
    across.normalize()
    up_slope = ((rL + rR) / 2 - (eL + eR) / 2)
    slope_len = up_slope.length
    # Slope outline in (across, up) metres; a hip slope is a trapezoid or triangle.
    def local(p):
        d = p - eL
        return (d.dot(across), d.dot(up_slope.normalized()))
    outline = [local(eL), local(eR), local(rR), local(rL)]
    def inside(u, w, margin=0.0):
        n = len(outline)
        for i in range(n):
            ax, ay = outline[i]
            bx, by = outline[(i + 1) % n]
            if abs(ax - bx) < 1e-9 and abs(ay - by) < 1e-9:
                continue
            if (bx - ax) * (w - ay) - (by - ay) * (u - ax) < -margin:
                return False
        return True
    up_slope.normalize()
    normal = across.cross(up_slope).normalized()
    if normal.z < 0:
        normal = -normal
    columns = max(2, round(width / tile_w))
    cw = width / columns
    step = tile_l - overlap
    rows = max(2, math.ceil((slope_len - overlap) / step))
    step = (slope_len - tile_l * 0.25) / rows
    tile_rnd = {}
    for row in range(rows):
        for col in range(columns):
            if missing and rng.random() < missing and 0 < row < rows - 1:
                continue
            if not inside((col + 0.5) * cw, row * step + tile_l * 0.5, 0.12):
                continue
            old = rng.random() < layer_mix
            layer = "tegula_old" if old else "tegula"
            s = row * step
            u = (col + 0.5) * cw + rng.uniform(-0.008, 0.008)
            frac = u / width
            sag_here = sag * (1 - (2 * frac - 1) ** 2) * math.sin(math.pi * min(1.0, (s + tile_l / 2) / slope_len))
            base = eL + across * u + up_slope * s + normal * (0.004 * row - sag_here)
            lift = normal * (0.012 + 0.006 * rng.random())
            # Each tile rests on the one below: a slight tilt shows its lower edge.
            tilt = Matrix.Rotation(rng.uniform(-0.012, 0.012), 3, normal)
            a = base + lift
            b = base + lift + (tilt @ up_slope) * tile_l
            prof = tegula_profile(cw - 0.012 - rng.uniform(0, 0.006))
            rnd = rng.random()
            tile_rnd[(row, col)] = rnd
            _tile_prism(mesh, prof, a, b, normal, layer, rnd)
        # Imbrices cover the flange joints, laid from the eave upward.
        for col in range(columns + 1):
            if col in (0, columns) and not ridge:
                pass
            u = col * cw
            frac = u / width
            s = row * step
            if not inside(u, s + tile_l * 0.5, 0.06):
                continue
            sag_here = sag * (1 - (2 * frac - 1) ** 2) * math.sin(math.pi * min(1.0, (s + tile_l / 2) / slope_len))
            base = eL + across * u + up_slope * s + normal * (0.004 * row - sag_here + 0.040)
            a = base + across * rng.uniform(-0.006, 0.006)
            b = a + up_slope * (tile_l * 0.98)
            old = rng.random() < layer_mix
            _imbrex(mesh, a, b, normal, 0.075 if col not in (0, columns) else 0.07, "tegula_old" if old else "tegula", rng.random())
            if antefix and row == 0 and 0 < col < columns:
                _antefix(detail, a - up_slope * 0.01, normal, across, rng)
    return {"rows": rows, "columns": columns, "normal": normal, "up": up_slope, "across": across}


def _tile_prism(mesh, profile, a, b, normal, layer, rnd):
    """Extrude the tegula U-profile; the underside rests on boards and is omitted."""
    along = (b - a).normalized()
    side = along.cross(normal).normalized()
    rings = []
    for base, taper in ((a, 1.0), (b, 0.93)):
        rings.append([base + side * (x * taper) + normal * z for x, z in profile])
    # Outward direction per profile segment (tegula_profile order); None = hidden.
    outs = [normal, side, normal, -side, normal, side, None, -side]
    w = abs(profile[0][0])
    n = len(profile)
    for i in range(n):
        out = outs[i]
        if out is None:
            continue
        j = (i + 1) % n
        quad = [rings[0][i], rings[0][j], rings[1][j], rings[1][i]]
        u0 = 0.05 + 0.9 * (profile[i][0] / (2 * w) + 0.5)
        u1 = 0.05 + 0.9 * (profile[j][0] / (2 * w) + 0.5)
        uv = [(u0 + rnd, rnd * 3.7), (u1 + rnd, rnd * 3.7), (u1 + rnd, 1.0 + rnd * 3.7), (u0 + rnd, 1.0 + rnd * 3.7)]
        mesh.face(quad, layer, rnd, outward=out, uv=uv, wear=1.0 if i in (0, 4) else 0.0)
    # Lower (visible) end of the tile.
    mesh.face(list(rings[0]), layer, rnd, outward=-along, wear=0.6)


def _imbrex(mesh, a, b, normal, radius, layer, rnd):
    along = (b - a).normalized()
    side = along.cross(normal).normalized()
    seg = 6
    rings = []
    for base, taper, drop in ((a, 1.0, 0.0), (b, 0.82, -0.012)):
        ring = []
        for k in range(seg + 1):
            t = math.pi * k / seg
            ring.append(base + side * (math.cos(t) * radius * taper) + normal * (math.sin(t) * radius * taper * 0.85 + drop))
        rings.append(ring)
    for k in range(seg):
        quad = [rings[0][k], rings[0][k + 1], rings[1][k + 1], rings[1][k]]
        t = math.pi * (k + 0.5) / seg
        out = side * math.cos(t) + normal * math.sin(t)
        u0, u1 = k / seg, (k + 1) / seg
        mesh.face(quad, layer, rnd, outward=out, uv=[(u0 + rnd, 0 + rnd * 2.3), (u1 + rnd, 0 + rnd * 2.3), (u1 + rnd, 0.9 + rnd * 2.3), (u0 + rnd, 0.9 + rnd * 2.3)])
    # Thick lower lip (the front ring) catches light at the eave and each course.
    lip = []
    for k in range(seg + 1):
        t = math.pi * k / seg
        lip.append(a + side * (math.cos(t) * (radius - 0.016)) + normal * (math.sin(t) * (radius - 0.016) * 0.85))
    for k in range(seg):
        quad = [rings[0][k + 1], rings[0][k], lip[k], lip[k + 1]]
        mesh.face(quad, layer, rnd, outward=-along, wear=1.0)


def _antefix(mesh, at, normal, across, rng):
    """Terracotta antefix closing an eave imbrex (palmette plaque, Italic type)."""
    up = Z
    side = across
    face_n = side.cross(up).normalized()
    if face_n.dot(normal.cross(across)) > 0:
        pass
    pts = []
    h, w = 0.17, 0.14
    for k in range(9):
        t = math.pi * k / 8
        r = w / 2 * (1.0 + 0.12 * math.cos(5 * t))
        pts.append(at + side * (math.cos(t) * r) + up * (0.03 + h * 0.55 * math.sin(t) + h * 0.45 * (1 if 0 < k < 8 else 0) * math.sin(t) ** 3))
    pts = [at + side * (-w / 2) + up * 0.0] + list(reversed(pts)) + [at + side * (w / 2) + up * 0.0]
    depth = 0.025
    back = [p + face_n * depth for p in pts]
    out = -face_n if (-face_n).dot(at - (at + face_n)) >= 0 else face_n
    mesh.face(pts, "tegula", rng.random(), outward=-face_n, wear=0.5)
    mesh.face(list(reversed(back)), "tegula", rng.random(), outward=face_n)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        edge = pts[j] - pts[i]
        out = edge.cross(face_n).normalized()
        mesh.face([pts[i], pts[j], back[j], back[i]], "tegula", 0.3, outward=out, wear=1.0)


def ridge_line(mesh, a, b, rng, height=0.0, radius=0.13, layer="tegula", bed=True, sag=0.03):
    """Ridge imbrices bedded in lime mortar, overlapping courses with irregular joints."""
    a, b = Vector(a), Vector(b)
    axis = (b - a)
    length = axis.length
    axis.normalize()
    count = max(3, round(length / 0.40))
    step = length / count
    for i in range(count):
        t0 = i * step - 0.03
        t1 = t0 + step + 0.06
        frac = (i + 0.5) / count
        drop = sag * (1 - (2 * frac - 1) ** 2)
        p0 = a + axis * t0 + Z * (height - drop + rng.uniform(-0.006, 0.006))
        p1 = a + axis * t1 + Z * (height - drop + rng.uniform(-0.006, 0.006))
        _imbrex(mesh, p0, p1, Z, radius * rng.uniform(0.95, 1.05), "tegula_old" if rng.random() < 0.35 else layer, rng.random())
        if bed:
            side = axis.cross(Z).normalized()
            for s in (-1, 1):
                m0 = p0 + side * s * (radius + 0.015) + Z * -0.06
                m1 = p1 + side * s * (radius + 0.015) + Z * -0.06
                mesh.face([m0, m1, m1 + Z * 0.05 - side * s * 0.02, m0 + Z * 0.05 - side * s * 0.02], "mortar", rng.random(), outward=side * s + Z * 0.3)


# ------------------------------------------------------------- joinery bits
def plank_leaf(mesh, detail, hinge, width, height, angle, rng, layer="oak_brown", boards=5, thick=0.06,
               studs=False, ring=True, braces="z"):
    """Door leaf of vertical boards with battens, iron straps and nails; hinged at 'hinge'."""
    hinge = Vector(hinge)
    rot = Matrix.Rotation(angle, 3, 'Z')
    x = rot @ Vector((1, 0, 0))
    y = rot @ Vector((0, 1, 0))
    basis = Matrix((x, y, Z)).transposed()
    bw = width / boards
    for i in range(boards):
        w = bw - 0.006
        h = height - rng.uniform(0, 0.015)
        c = hinge + x * ((i + 0.5) * bw) + Z * (h / 2) + y * 0
        mesh.chamfer_box(c, (w, thick, h), layer, basis, 0.006, rng.random(), grain=2, rng=rng)
    # Battens on the inner face and a diagonal brace.
    for z in (0.25, height - 0.30):
        c = hinge + x * (width / 2) + Z * z + y * (thick / 2 + 0.018)
        mesh.chamfer_box(c, (width - 0.06, 0.036, 0.11), layer, basis, 0.008, rng.random(), grain=0, rng=rng)
    if braces == "z":
        p1 = hinge + x * 0.1 + Z * 0.33 + y * (thick / 2 + 0.018)
        p2 = hinge + x * (width - 0.1) + Z * (height - 0.40) + y * (thick / 2 + 0.018)
        mesh.beam(p1, p2, 0.10, 0.034, layer, 0.006, rng.random(), rng=rng)
    # Strap hinges on the outer face (detail mesh) with nail heads.
    for z in (0.25, height - 0.30):
        c = hinge + x * (width * 0.42) + Z * z - y * (thick / 2 + 0.005)
        detail.chamfer_box(c, (width * 0.80, 0.008, 0.045), "iron", basis, 0.002, rng.random())
        for k in range(5):
            n = hinge + x * (0.06 + k * width * 0.78 / 4) + Z * z - y * (thick / 2 + 0.011)
            detail.chamfer_box(n, (0.016, 0.008, 0.016), "iron", basis, 0.003, rng.random())
    if studs:
        for row in range(4):
            for col in range(3):
                n = hinge + x * (0.2 + col * (width - 0.4) / 2) + Z * (0.55 + row * 0.38) - y * (thick / 2 + 0.008)
                detail.chamfer_box(n, (0.024, 0.012, 0.024), "iron", basis, 0.005, rng.random())
    if ring:
        c = hinge + x * (width - 0.16) + Z * 1.02 - y * (thick / 2 + 0.03)
        seg = 10
        for k in range(seg):
            a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
            p0 = c + x * (math.cos(a0) * 0.05) + Z * (math.sin(a0) * 0.05)
            p1 = c + x * (math.cos(a1) * 0.05) + Z * (math.sin(a1) * 0.05)
            detail.beam(p0, p1, 0.011, 0.011, "iron", 0.002, rng.random())
        detail.chamfer_box(c + Z * 0.05 + y * 0.015, (0.03, 0.03, 0.03), "iron", basis, 0.006, rng.random())


def frame(mesh, centre_u, origin, u_axis, sill, head, width, depth, layer, rng, post=0.11, sill_layer=None,
          lintel_overhang=0.12, sill_overhang=0.06, outset=0.03, sill_depth=None):
    """Window/door frame: two posts, a lintel and a sill, flush with the outer face."""
    origin = Vector(origin)
    u_axis = Vector(u_axis).normalized()
    out = u_axis.cross(Z).normalized()
    basis = Matrix((u_axis, -out, Z)).transposed()
    c = origin + u_axis * centre_u + out * (outset - depth / 2)
    for s in (-1, 1):
        p = c + u_axis * s * (width / 2 + post / 2) + Z * ((sill + head) / 2)
        mesh.chamfer_box(p, (post, depth, head - sill + 0.02), layer, basis, 0.012, rng.random(), grain=2, rng=rng)
    lintel = c + Z * (head + 0.07)
    mesh.chamfer_box(lintel, (width + 2 * post + lintel_overhang * 2, depth + 0.02, 0.14), layer, basis, 0.014, rng.random(), grain=0, rng=rng)
    if sill_layer:
        sd = sill_depth or depth + 0.05
        s = origin + u_axis * centre_u + out * (outset + 0.03 - sd / 2) + Z * (sill - 0.05)
        mesh.chamfer_box(s, (width + 2 * post + sill_overhang * 2, sd, 0.10), sill_layer, basis, 0.016, rng.random(), grain=0, rng=rng)


def shutter(mesh, detail, hinge, width, height, angle, rng, layer="oak_grey", boards=3):
    hinge = Vector(hinge)
    rot = Matrix.Rotation(angle, 3, 'Z')
    x = rot @ Vector((1, 0, 0))
    y = rot @ Vector((0, 1, 0))
    basis = Matrix((x, y, Z)).transposed()
    bw = width / boards
    for i in range(boards):
        c = hinge + x * ((i + 0.5) * bw) + Z * (height / 2)
        mesh.chamfer_box(c, (bw - 0.008, 0.04, height - rng.uniform(0, 0.02)), layer, basis, 0.005, rng.random(), grain=2, rng=rng)
    for z in (0.12, height - 0.12):
        c = hinge + x * (width / 2) + Z * z + y * 0.03
        mesh.chamfer_box(c, (width - 0.03, 0.025, 0.07), layer, basis, 0.006, rng.random(), grain=0, rng=rng)
        d = hinge + x * (width * 0.35) + Z * z - y * 0.024
        detail.chamfer_box(d, (width * 0.6, 0.006, 0.03), "iron", basis, 0.002, rng.random())


def grille(detail, origin, u_axis, centre_u, sill, head, width, rng, bars=3, inset=0.10):
    origin = Vector(origin)
    u_axis = Vector(u_axis).normalized()
    out = u_axis.cross(Z).normalized()
    for k in range(bars):
        u = centre_u - width / 2 + width * (k + 1) / (bars + 1)
        p = origin + u_axis * u - out * inset
        detail.beam(p + Z * (sill - 0.04), p + Z * (head + 0.04), 0.026, 0.026, "iron", 0.004, rng.random(), roll=math.pi / 4)
    for z in (sill + (head - sill) * 0.5,):
        a = origin + u_axis * (centre_u - width / 2 - 0.03) - out * (inset + 0.02) + Z * z
        b = origin + u_axis * (centre_u + width / 2 + 0.03) - out * (inset + 0.02) + Z * z
        detail.beam(a, b, 0.018, 0.018, "iron", 0.003, rng.random())


def column(mesh, base_centre, height, radius, rng, layer="plaster_lime", base_layer="flagstone", segments=14):
    """Tuscan column (Republican Italic order): plinth, torus base, tapering shaft, echinus, abacus."""
    c = Vector(base_centre)
    mesh.chamfer_box(c + Z * 0.06, (radius * 2.6, radius * 2.6, 0.12), base_layer, None, 0.015, rng.random())
    torus = [(radius * 1.12, 0.12), (radius * 1.22, 0.15), (radius * 1.2, 0.19), (radius * 1.08, 0.215), (radius * 1.0, 0.23)]
    mesh.lathe(torus, c, base_layer, segments, rng.random())
    shaft_h = height - 0.23 - 0.24
    shaft = []
    for k in range(7):
        t = k / 6
        entasis = 1.0 - 0.16 * t + 0.035 * math.sin(math.pi * t)
        shaft.append((radius * entasis, 0.23 + shaft_h * t))
    mesh.lathe(shaft, c, layer, segments, rng.random())
    top = 0.23 + shaft_h
    rt = shaft[-1][0]
    cap = [(rt, top), (rt * 1.06, top + 0.03), (rt * 1.06, top + 0.045), (rt * 1.3, top + 0.12), (rt * 1.32, top + 0.13)]
    mesh.lathe(cap, c, layer, segments, rng.random())
    mesh.chamfer_box(c + Z * (top + 0.185), (rt * 2.9, rt * 2.9, 0.11), base_layer, None, 0.012, rng.random())


def bracket(mesh, wall_point, out, length, drop, size, layer, rng):
    """Inclined timber strut from the wall to the outer end of a canopy beam."""
    wall_point, out = Vector(wall_point), Vector(out)
    end = wall_point + out * length
    foot = wall_point - Z * drop
    mesh.beam(foot, end - out * 0.04, size, size, layer, 0.012, rng.random(), rng=rng)
