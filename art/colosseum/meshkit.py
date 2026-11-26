"""Small procedural mesh toolkit for the monument builders (runs inside Blender).

All primitives are written in a local frame: x across the bay (metres from the
bay centre), y inward depth, z up.  A MeshBuffer maps that frame either flat
(instanced modules) or through the amphitheatre ring (unique sector geometry).
"""
import math

import bmesh
import bpy

import ring as R

TILE = 3.0  # metres per texture repeat for the box-projected UVs


def _hash(a, b=0.0, c=0.0):
    v = math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
    return v - math.floor(v)


class MeshBuffer:
    def __init__(self, name, bay=None, tint_seed=0.0):
        self.name = name
        self.bay = bay            # None = flat local frame
        self.seed = tint_seed
        self.verts = []
        self.faces = []
        self.mats = []
        self.uvs = []
        self.cols = []
        self.smooth = []
        self.matnames = []
        self.level_z = 0.0        # base of the current storey for grime shading
        self.interior = 0.62      # multiplier for faces deeper than the facade
        self.zoff = 0.0           # vertical offset applied to all following geometry

    # -- coordinate helpers -------------------------------------------------
    def width(self, y):
        return R.NOMINAL_W if self.bay is None else R.width(self.bay, y)

    def lx(self, x, y):
        """Resolve an x spec to metres from the bay centre at depth y."""
        if isinstance(x, tuple):
            w = self.width(y)
            if x[0] == "L":
                return -w / 2 + x[1]
            if x[0] == "R":
                return w / 2 - x[1]
            return (x[1] - 0.5) * w
        return x

    def world(self, p):
        x, y, z = p
        z += self.zoff
        if self.bay is None:
            return (x, y, z)
        w = R.width(self.bay, y)
        px, py = R.bay_point(self.bay, x / w + 0.5, y)
        return (px, py, z)

    def shade(self, p, ao):
        x, y, z = p
        g = ao
        h = z - self.level_z
        if 0.0 <= h < 1.2:
            g *= 0.80 + 0.2 * h / 1.2
        if y > 2.8:
            g *= self.interior
        elif y > 0.05:
            g *= 0.5 * (1.0 + self.interior) + 0.5 * (1.0 - self.interior) * (1.0 - y / 2.8)
        g *= 0.95 + 0.1 * _hash(round(x * 1.7), round(z * 0.9), self.seed)
        return max(0.0, min(1.0, g))

    # -- faces ----------------------------------------------------------------
    def face(self, pts, mat, n=None, ao=1.0, smooth=False, uv=None, tint=None):
        pts = [(self.lx(p[0], p[1]), p[1], p[2]) for p in pts]
        a, b, c = pts[0], pts[1], pts[2]
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        if n is not None and nx * n[0] + ny * n[1] + nz * n[2] < 0:
            pts = pts[::-1]
            if uv:
                uv = uv[::-1]
            nx, ny, nz = -nx, -ny, -nz
        if uv is None:
            ax, ay, az = abs(nx), abs(ny), abs(nz)
            if az >= ax and az >= ay:
                uv = [(p[0] / TILE, p[1] / TILE) for p in pts]
            elif ay >= ax:
                uv = [(p[0] / TILE, (p[2] + self.zoff) / TILE) for p in pts]
            else:
                uv = [(p[1] / TILE, (p[2] + self.zoff) / TILE) for p in pts]
        base = len(self.verts)
        for p in pts:
            self.verts.append(self.world(p))
            g = self.shade(p, ao)
            self.cols.append((g, g, g, 1.0) if tint is None else (g * tint[0], g * tint[1], g * tint[2], 1.0))
        self.uvs.extend(uv)
        self.faces.append(tuple(range(base, base + len(pts))))
        if mat not in self.matnames:
            self.matnames.append(mat)
        self.mats.append(self.matnames.index(mat))
        self.smooth.append(smooth)

    def quad(self, a, b, c, d, mat, n=None, **kw):
        self.face([a, b, c, d], mat, n, **kw)

    def box(self, x0, x1, y0, y1, z0, z1, mat, skip="", inward=False, ao=1.0, **kw):
        s = -1.0 if inward else 1.0
        if "x-" not in skip:
            self.quad((x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1), mat, (-s, 0, 0), ao=ao, **kw)
        if "x+" not in skip:
            self.quad((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1), mat, (s, 0, 0), ao=ao, **kw)
        if "y-" not in skip:
            self.quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), mat, (0, -s, 0), ao=ao, **kw)
        if "y+" not in skip:
            self.quad((x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1), mat, (0, s, 0), ao=ao, **kw)
        if "z-" not in skip:
            self.quad((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), mat, (0, 0, -s), ao=ao, **kw)
        if "z+" not in skip:
            self.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), mat, (0, 0, s), ao=ao, **kw)

    def extrude_x(self, profile, x0, x1, mat, caps=False, ao=1.0):
        """profile: open polyline of (y, z); the exposed side is to the left of travel (-y at start)."""
        for (ya, za), (yb, zb) in zip(profile, profile[1:]):
            dy, dz = yb - ya, zb - za
            self.quad((x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb), mat, (0, -dz, dy), ao=ao)
        if caps:
            for x, s in ((x0, -1), (x1, 1)):
                self.face([(x, y, z) for y, z in profile], mat, (s, 0, 0), ao=ao)

    def lathe(self, cx, cy, profile, seg, mat, a0=0.0, a1=math.tau, sx=1.0, sy=1.0, ao=1.0, tint=None):
        """Revolve (radius, z) about the vertical axis at (cx, cy). Angles from +x towards +y."""
        for (ra, za), (rb, zb) in zip(profile, profile[1:]):
            for i in range(seg):
                t0 = a0 + (a1 - a0) * i / seg
                t1 = a0 + (a1 - a0) * (i + 1) / seg
                c0, s0, c1, s1 = math.cos(t0), math.sin(t0), math.cos(t1), math.sin(t1)
                pts = [(cx + ra * c0 * sx, cy + ra * s0 * sy, za), (cx + ra * c1 * sx, cy + ra * s1 * sy, za),
                       (cx + rb * c1 * sx, cy + rb * s1 * sy, zb), (cx + rb * c0 * sx, cy + rb * s0 * sy, zb)]
                if ra < 1e-6:
                    pts = pts[1:] if False else [pts[0], pts[2], pts[3]]
                elif rb < 1e-6:
                    pts = pts[:3]
                tm = (t0 + t1) / 2
                slope = (ra - rb)
                self.face(pts, mat, (math.cos(tm), math.sin(tm), slope * 0.5 + (0.001 if zb >= za else -0.001)), ao=ao, smooth=True, tint=tint)

    def arch_wall(self, x0, x1, y, z0, z1, cx, hw, zs, mat, facing=-1, seg=12, ao=1.0):
        """Vertical wall in the plane y with an arched opening (jambs to zs, semicircle of radius hw)."""
        n = (0, facing, 0)
        self.quad((x0, y, z0), (cx - hw, y, z0), (cx - hw, y, zs), (x0, y, zs), mat, n, ao=ao)
        self.quad((cx + hw, y, z0), (x1, y, z0), (x1, y, zs), (cx + hw, y, zs), mat, n, ao=ao)
        self.face([(x0, y, zs), (cx - hw, y, zs), (x0, y, z1)], mat, n, ao=ao)
        self.face([(x1, y, zs), (cx + hw, y, zs), (x1, y, z1)], mat, n, ao=ao)
        for i in range(seg):
            t0, t1 = math.pi * (1 - i / seg), math.pi * (1 - (i + 1) / seg)
            a = (cx + hw * math.cos(t0), y, zs + hw * math.sin(t0))
            b = (cx + hw * math.cos(t1), y, zs + hw * math.sin(t1))
            self.quad(a, b, (self.lerpx(x0, x1, (i + 1) / seg, y), y, z1), (self.lerpx(x0, x1, i / seg, y), y, z1), mat, n, ao=ao)

    def lerpx(self, x0, x1, f, y):
        a, b = self.lx(x0, y), self.lx(x1, y)
        return a + (b - a) * f

    def intrados(self, cx, hw, z0, zs, y0, y1, mat, seg=12, ao=0.8, jambs=True):
        if jambs:
            self.quad((cx - hw, y0, z0), (cx - hw, y1, z0), (cx - hw, y1, zs), (cx - hw, y0, zs), mat, (1, 0, 0), ao=ao)
            self.quad((cx + hw, y0, z0), (cx + hw, y1, z0), (cx + hw, y1, zs), (cx + hw, y0, zs), mat, (-1, 0, 0), ao=ao)
        for i in range(seg):
            t0, t1 = math.pi * (1 - i / seg), math.pi * (1 - (i + 1) / seg)
            tm = (t0 + t1) / 2
            self.quad((cx + hw * math.cos(t0), y0, zs + hw * math.sin(t0)), (cx + hw * math.cos(t1), y0, zs + hw * math.sin(t1)),
                      (cx + hw * math.cos(t1), y1, zs + hw * math.sin(t1)), (cx + hw * math.cos(t0), y1, zs + hw * math.sin(t0)),
                      mat, (-math.cos(tm), 0, -math.sin(tm)), ao=ao)

    def archivolt(self, cx, hw, zs, y, band, proud, mat, seg=12):
        """Raised moulding ring around an arch on a wall facing -y."""
        for i in range(seg):
            t0, t1 = math.pi * (1 - i / seg), math.pi * (1 - (i + 1) / seg)
            p = [(cx + r * math.cos(t), zs + r * math.sin(t)) for t in (t0, t1) for r in (hw, hw + band)]
            (ax, az), (bx, bz), (cx2, cz), (dx, dz) = p[0], p[1], p[2], p[3]
            self.quad((ax, y - proud, az), (cx2, y - proud, cz), (dx, y - proud, dz), (bx, y - proud, bz), mat, (0, -1, 0))
            tm = (t0 + t1) / 2
            self.quad((bx, y - proud, bz), (dx, y - proud, dz), (dx, y, dz), (bx, y, bz), mat, (math.cos(tm), 0, math.sin(tm)))

    def merge(self, other):
        base = len(self.verts)
        self.verts.extend(other.verts)
        self.uvs.extend(other.uvs)
        self.cols.extend(other.cols)
        self.smooth.extend(other.smooth)
        for f, m in zip(other.faces, other.mats):
            self.faces.append(tuple(i + base for i in f))
            name = other.matnames[m]
            if name not in self.matnames:
                self.matnames.append(name)
            self.mats.append(self.matnames.index(name))

    def triangles(self):
        return sum(len(f) - 2 for f in self.faces)

    # -- Blender output -----------------------------------------------------------
    def to_object(self, collection, materials):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts, [], self.faces)
        for name in self.matnames:
            mesh.materials.append(materials(name))
        mesh.polygons.foreach_set("material_index", self.mats)
        mesh.polygons.foreach_set("use_smooth", self.smooth)
        uv = mesh.uv_layers.new(name="UVMap")
        flat = [c for pair in self.uvs for c in pair]
        uv.data.foreach_set("uv", flat)
        col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        col.data.foreach_set("color", [c for rgba in self.cols for c in rgba])
        mesh.color_attributes.active_color = col
        mesh.color_attributes.render_color_index = 0
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bm.to_mesh(mesh)
        bm.free()
        if any(self.smooth):
            mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
            mesh.set_sharp_from_angle(angle=0.75)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        return obj
