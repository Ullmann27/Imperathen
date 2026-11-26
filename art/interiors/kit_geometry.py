"""Geometry accumulator for the Valdora household kit (Blender 4.3, metres, Z up).

A Prop collects shared vertices and faces with per-face material, per-loop UVs
in physical units (metres / material tile) and per-loop sRGB tint. Front of
every prop is -Y (glTF +Z, Godot +Z); origin is the floor contact centre, or
the hanging point for props flagged as hanging.
"""
from __future__ import annotations

import math
import random
import zlib

import bmesh
import bpy
from mathutils import Matrix, Vector

WHITE = (1.0, 1.0, 1.0)
TILE: dict[str, float] = {}
WOOD = {"oak", "wood_rough"}
I4 = Matrix.Identity(4)


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(axis: str, angle: float):
    return Matrix.Rotation(angle, 4, axis)


def S(x: float, y: float, z: float):
    return Matrix.Diagonal((x, y, z, 1.0))


def basis(u: Vector, v: Vector, w: Vector, origin) -> Matrix:
    """4x4 frame with columns u, v, w and the given translation."""
    M = Matrix.Identity(4)
    for row in range(3):
        M[row][0], M[row][1], M[row][2], M[row][3] = u[row], v[row], w[row], origin[row]
    return M


def frame(direction: Vector):
    """Two unit vectors perpendicular to direction."""
    d = direction.normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < .9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    return u, v


class Prop:
    def __init__(self, name: str, bevel: float = .006, hanging: bool = False):
        self.name = name
        self.bevel = bevel
        self.hanging = hanging
        self.v: list[Vector] = []
        self.f: list[tuple] = []
        self.fm: list[str] = []
        self.fuv: list[list] = []
        self.fs: list[bool] = []
        self.fc: list[list] = []
        self.rng = random.Random(zlib.crc32(name.encode()))

    # -- low level -----------------------------------------------------------
    def _vert(self, p) -> int:
        self.v.append(Vector(p))
        return len(self.v) - 1

    def face(self, idx, mat, uvs, smooth=True, color=WHITE):
        if len(set(idx)) != len(idx) or len(idx) < 3:
            return
        cols = []
        for i in idx:
            cols.append(color(self.v[i]) if callable(color) else color)
        self.f.append(tuple(idx))
        self.fm.append(mat)
        self.fuv.append([tuple(uv) for uv in uvs])
        self.fs.append(smooth)
        self.fc.append(cols)

    def planar_face(self, idx, mat, smooth=True, color=WHITE, grain: Vector | None = None, offset=(0.0, 0.0)):
        """UVs projected on the face plane; wood grain follows `grain` when given."""
        pts = [self.v[i] for i in idx]
        n = Vector((0, 0, 0))
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        if n.length < 1e-12:
            return
        n.normalize()
        if grain is not None and abs(grain.normalized().dot(n)) < .9:
            u_axis = (grain - n * grain.dot(n)).normalized()
        else:
            u_axis = (pts[1] - pts[0]).normalized()
            if abs(n.z) < .7:
                up = Vector((0, 0, 1))
                u_axis = n.cross(up).normalized() if n.cross(up).length > .1 else u_axis
        v_axis = n.cross(u_axis).normalized()
        tile = TILE[mat]
        uvs = [(p.dot(u_axis) / tile + offset[0], p.dot(v_axis) / tile + offset[1]) for p in pts]
        self.face(idx, mat, uvs, smooth, color)

    # -- primitives ----------------------------------------------------------
    def box(self, center, size, mat, M=I4, color=WHITE, grain=None, smooth=True):
        """Axis-aligned box in the frame M, centred at `center`."""
        cx, cy, cz = center
        dx, dy, dz = (s / 2 for s in size)
        local = [(-dx, -dy, -dz), (dx, -dy, -dz), (dx, dy, -dz), (-dx, dy, -dz),
                 (-dx, -dy, dz), (dx, -dy, dz), (dx, dy, dz), (-dx, dy, dz)]
        base = len(self.v)
        for p in local:
            self.v.append(M @ Vector((cx + p[0], cy + p[1], cz + p[2])))
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        if M.determinant() < 0:
            faces = [tuple(reversed(f)) for f in faces]
        axes = [Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))]
        g = grain if grain is not None else axes[max(range(3), key=lambda i: size[i])]
        g = (M.to_3x3() @ Vector(g)).normalized()
        off = (self.rng.random() * 3, self.rng.random() * 3)
        for f in faces:
            self.planar_face([base + i for i in f], mat, smooth, color, g if mat in WOOD else None, off)

    def beam(self, a, b, width, depth, mat, color=WHITE, roll=0.0):
        """Rectangular timber from a to b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        u, v = frame(d)
        if roll:
            q = Matrix.Rotation(roll, 3, d.normalized())
            u, v = q @ u, q @ v
        M = basis(u, v, d.normalized(), (a + b) / 2)
        self.box((0, 0, 0), (width, depth, d.length), mat, M, color, grain=(0, 0, 1))

    def lathe(self, profile, mat, M=I4, sides=20, cap_bottom=True, cap_top=False, color=WHITE,
              smooth=True, phase=0.0, deform=None, arc=(0.0, math.tau)):
        """Revolve [(radius, z), ...] around local Z. A profile that returns down
        the inside of a vessel yields a real hollow with inward facing walls."""
        full = abs(arc[1] - arc[0] - math.tau) < 1e-6
        count = sides if full else sides + 1
        rings = []
        r_ref = max(r for r, _ in profile)
        tile = TILE[mat]
        for j, (r, z) in enumerate(profile):
            ring = []
            for i in range(count):
                a = arc[0] + (arc[1] - arc[0]) * i / sides + phase
                p = Vector((max(r, .0008) * math.cos(a), max(r, .0008) * math.sin(a), z))
                if deform:
                    p = deform(p, a, j)
                ring.append(self._vert(M @ p))
            rings.append(ring)
        arcs = [0.0]
        for j in range(1, len(profile)):
            arcs.append(arcs[-1] + math.dist(profile[j - 1], profile[j]))
        circ = (arc[1] - arc[0]) * r_ref
        flip = M.determinant() < 0
        for j in range(len(profile) - 1):
            for i in range(sides):
                i1 = (i + 1) % count if full else i + 1
                idx = [rings[j][i], rings[j][i1], rings[j + 1][i1], rings[j + 1][i]]
                uvs = [(circ * i / sides / tile, arcs[j] / tile), (circ * (i + 1) / sides / tile, arcs[j] / tile),
                       (circ * (i + 1) / sides / tile, arcs[j + 1] / tile), (circ * i / sides / tile, arcs[j + 1] / tile)]
                if flip:
                    idx.reverse(); uvs.reverse()
                self.face(idx, mat, uvs, smooth, color)
        if full and cap_bottom and profile[0][0] > .001:
            idx = list(reversed(rings[0]))
            self.planar_face(idx[::-1] if flip else idx, mat, False, color)
        if full and cap_top and profile[-1][0] > .001:
            idx = list(rings[-1])
            self.planar_face(idx[::-1] if flip else idx, mat, False, color)
        return rings

    def cylinder(self, r0, r1, h, mat, M=I4, sides=16, caps=(True, True), color=WHITE, smooth=True):
        return self.lathe([(r0, 0), (r1, h)], mat, M, sides, caps[0], caps[1], color, smooth)

    def rod(self, a, b, r0, mat, r1=None, sides=8, color=WHITE, caps=True):
        a, b = Vector(a), Vector(b)
        d = b - a
        u, v = frame(d)
        M = basis(u, v, d.normalized(), a)
        return self.cylinder(r0, r0 if r1 is None else r1, d.length, mat, M, sides, (caps, caps), color)

    def tube(self, points, radius, mat, sides=6, color=WHITE, caps=True, radii=None):
        """Swept circle along a polyline (handles, ropes, warp threads)."""
        pts = [Vector(p) for p in points]
        rings = []
        prev_u = None
        for k, p in enumerate(pts):
            t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
            if prev_u is None:
                u, _ = frame(t)
            else:
                u = (prev_u - t * prev_u.dot(t)).normalized()
            v = t.cross(u).normalized()
            prev_u = u
            r = radii[k] if radii else radius
            rings.append([self._vert(p + (u * math.cos(a) + v * math.sin(a)) * r)
                          for a in (i * math.tau / sides for i in range(sides))])
        tile = TILE[mat]
        length = 0.0
        for k in range(len(pts) - 1):
            seg = (pts[k + 1] - pts[k]).length
            for i in range(sides):
                i1 = (i + 1) % sides
                c = math.tau * radius
                self.face([rings[k][i], rings[k][i1], rings[k + 1][i1], rings[k + 1][i]], mat,
                          [(length / tile, c * i / sides / tile), (length / tile, c * (i + 1) / sides / tile),
                           ((length + seg) / tile, c * (i + 1) / sides / tile), ((length + seg) / tile, c * i / sides / tile)],
                          True, color)
            length += seg
        if caps:
            self.planar_face(list(reversed(rings[0])), mat, False, color)
            self.planar_face(list(rings[-1]), mat, False, color)

    def torus(self, R0, r, mat, M=I4, seg=24, sides=8, color=WHITE, arc=math.tau):
        full = abs(arc - math.tau) < 1e-6
        pts = [(math.cos(arc * i / seg) * R0, math.sin(arc * i / seg) * R0, 0.0) for i in range(seg + (0 if full else 1))]
        if full:
            pts.append(pts[0])
        self.tube([M @ Vector(p) for p in pts], r, mat, sides, color, caps=not full)

    def blob(self, center, radii, mat, M=I4, seg=16, rings=9, exponent=1.0, noise=0.0, color=WHITE, seed=0, flat_bottom=False):
        """Superellipsoid (exponent < 1 gives cushions and rounded boxes)."""
        rng = random.Random(seed)
        bumps = [(rng.uniform(0, math.tau), rng.uniform(0, math.tau), rng.uniform(.6, 1.4)) for _ in range(4)]

        def point(lat, lon):
            cl, sl = math.cos(lat), math.sin(lat)
            co, so = math.cos(lon), math.sin(lon)
            e = exponent
            x = math.copysign(abs(cl) ** e, cl) * math.copysign(abs(co) ** e, co)
            y = math.copysign(abs(cl) ** e, cl) * math.copysign(abs(so) ** e, so)
            z = math.copysign(abs(sl) ** e, sl)
            k = 1.0
            for p1, p2, amp in bumps:
                k += noise * amp * math.sin(lon * 3 + p1) * math.cos(lat * 2 + p2) / 4
            p = Vector((x * radii[0] * k, y * radii[1] * k, z * radii[2] * k))
            if flat_bottom and p.z < 0:
                p.z *= .15
            return self._vert(M @ (Vector(center) + p))
        south = point(-math.pi / 2, 0.0)
        north = point(math.pi / 2, 0.0)
        grid = []
        for j in range(1, rings):
            lat = -math.pi / 2 + math.pi * j / rings
            grid.append([point(lat, math.tau * i / seg) for i in range(seg)])
        tile = TILE[mat]
        cu = math.tau * max(radii[0], radii[1])
        cv = math.pi * max(radii)

        def uv(i, j):
            return (cu * i / seg / tile, cv * j / rings / tile)
        for i in range(seg):
            i1 = (i + 1) % seg
            self.face([south, grid[0][i1], grid[0][i]], mat, [uv(i + .5, 0), uv(i + 1, 1), uv(i, 1)], True, color)
            self.face([north, grid[-1][i], grid[-1][i1]], mat, [uv(i + .5, rings), uv(i, rings - 1), uv(i + 1, rings - 1)], True, color)
        for j in range(rings - 2):
            for i in range(seg):
                i1 = (i + 1) % seg
                idx = [grid[j][i], grid[j][i1], grid[j + 1][i1], grid[j + 1][i]]
                self.face(idx, mat, [uv(i, j + 1), uv(i + 1, j + 1), uv(i + 1, j + 2), uv(i, j + 2)], True, color)

    def rock(self, center, size, mat, seed, color=WHITE, subdivisions=1, rough=.18, M=I4, ground=False):
        """Irregular stone or lump from a displaced icosphere."""
        rng = random.Random(seed)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
        offsets = {}
        for vert in bm.verts:
            key = tuple(round(c, 4) for c in vert.co)
            offsets[key] = 1 + rng.uniform(-rough, rough)
        placed = {}
        for vert in bm.verts:
            k = offsets[tuple(round(c, 4) for c in vert.co)]
            p = Vector((vert.co.x * size[0] / 2 * k, vert.co.y * size[1] / 2 * k, vert.co.z * size[2] / 2 * k))
            placed[vert.index] = T(*center) @ M @ p
        if ground:
            # Rest the lowest vertex exactly on z = center.z - size.z / 2.
            drop = min(q.z for q in placed.values()) - (center[2] - size[2] / 2)
            for key in placed:
                placed[key].z -= drop
        index = {key: self._vert(q) for key, q in placed.items()}
        for f in bm.faces:
            self.planar_face([index[v.index] for v in f.verts], mat, True, color)
        bm.free()

    def sheet(self, fn, nu, nv, thickness, mat, size_u, size_v, color=WHITE, double=True):
        """Cloth or hide: fn(s, t) -> point for s, t in [0, 1]; given a thickness."""
        top = [[Vector(fn(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
        normals = []
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                du = top[j][min(i + 1, nu)] - top[j][max(i - 1, 0)]
                dv = top[min(j + 1, nv)][i] - top[max(j - 1, 0)][i]
                n = du.cross(dv)
                row.append(n.normalized() if n.length > 1e-9 else Vector((0, 0, 1)))
            normals.append(row)
        a = [[self._vert(top[j][i]) for i in range(nu + 1)] for j in range(nv + 1)]
        b = [[self._vert(top[j][i] - normals[j][i] * thickness) for i in range(nu + 1)] for j in range(nv + 1)]
        tile = TILE[mat]
        for j in range(nv):
            for i in range(nu):
                uv = [(size_u * i / nu / tile, size_v * j / nv / tile), (size_u * (i + 1) / nu / tile, size_v * j / nv / tile),
                      (size_u * (i + 1) / nu / tile, size_v * (j + 1) / nv / tile), (size_u * i / nu / tile, size_v * (j + 1) / nv / tile)]
                self.face([a[j][i], a[j][i + 1], a[j + 1][i + 1], a[j + 1][i]], mat, uv, True, color)
                if double:
                    self.face([b[j][i], b[j + 1][i], b[j + 1][i + 1], b[j][i + 1]], mat, [uv[0], uv[3], uv[2], uv[1]], True, color)
        if double:
            edge = [(i, 0) for i in range(nu)] + [(nu, j) for j in range(nv)] + [(i, nv) for i in range(nu, 0, -1)] + [(0, j) for j in range(nv, 0, -1)]
            for k in range(len(edge)):
                i0, j0 = edge[k]
                i1, j1 = edge[(k + 1) % len(edge)]
                # The loop runs counter-clockwise seen from the top face, so
                # (top, bottom, next bottom, next top) faces outward.
                self.planar_face([a[j0][i0], b[j0][i0], b[j1][i1], a[j1][i1]], mat, True, color)

    # -- export --------------------------------------------------------------
    def to_object(self, materials: dict, order: list[str], location=(0, 0, 0)):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([tuple(p) for p in self.v], [], self.f)
        if len(mesh.polygons) != len(self.f):
            raise RuntimeError("%s: %d polygons for %d faces" % (self.name, len(mesh.polygons), len(self.f)))
        used = [m for m in order if m in set(self.fm)]
        for m in used:
            mesh.materials.append(materials[m])
        # Create both layers before writing either: adding a layer reallocates
        # mesh custom data and would leave an earlier Python handle dangling.
        mesh.uv_layers.new(name="UVMap")
        mesh.color_attributes.new("Tint", "FLOAT_COLOR", "CORNER")
        uv = mesh.uv_layers["UVMap"]
        col = mesh.color_attributes["Tint"]
        mesh.polygons.foreach_set("material_index", [used.index(m) for m in self.fm])
        mesh.polygons.foreach_set("use_smooth", self.fs)

        def linear(c):
            return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
        flat_uv, flat_col = [], []
        for uvs, cols in zip(self.fuv, self.fc):
            for coordinate, c in zip(uvs, cols):
                flat_uv.extend(coordinate)
                flat_col.extend((linear(c[0]), linear(c[1]), linear(c[2]), 1.0))
        uv.data.foreach_set("uv", flat_uv)
        col.data.foreach_set("color", flat_col)
        mesh.color_attributes.active_color_name = "Tint"
        mesh.color_attributes.render_color_index = 0
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        obj["hanging"] = self.hanging
        if self.bevel > 0:
            mod = obj.modifiers.new("Softened edges", "BEVEL")
            mod.width = self.bevel
            mod.segments = 2
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(32)
            mod.harden_normals = True
            mod.use_clamp_overlap = True
        # Only n-gon caps are split; quads stay quads for tangent generation.
        tri = obj.modifiers.new("Caps to triangles", "TRIANGULATE")
        tri.min_vertices = 5
        return obj
