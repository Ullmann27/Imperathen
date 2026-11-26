"""Valdora forge (fabrica ferraria) of the smith Nerva, built from the house kit.

A tiled lean-to on oak posts in front of the smith's house, 58 BC: raised
stone hearth with a clay-lined fire bed and smoke hood, double bellows with a
clay tuyere, block anvil set in an oak stump (Roman anvils were blocks without
a long horn), tool rack with tongs and hammers, quench trough, workbench with
finished goods, iron bar stock, bloom iron and charcoal baskets.

The footprint, posts and work stations keep the positions the village already
uses (settlement_dressing.gd: hearth, bellows, anvil, rack and trough; story
points of the forge lesson), so interaction points, colliders and navigation
stay valid. The path from the lane to the smith's house door crosses the
lean-to (Godot z -0.75..0.75) and stays free of fixtures. Blender axes: metres, Z up, Y = -Godot z; the street side is -X.
"""
from __future__ import annotations

import math
import random

from mathutils import Matrix, Vector

from family_kit import Ageing, Mesh, Z, ridge_line, roof_slope, stone_course  # noqa: F401

ID = "valdora_forge"
# Godot-local station origins (settlement_dressing.gd); Blender y = -z.
HEARTH = Vector((0.05, 2.85, 0))
BELLOWS = Vector((-0.12, 1.95, 0))
ANVIL = Vector((0.0, -1.0, 0))
RACK = Vector((0.94, -1.45, 0))
TROUGH = Vector((0.10, -2.40, 0))
POSTS = [(-0.10, 3.15), (1.25, 3.15), (-0.10, -3.0), (1.25, -3.0)]
# The lean-to stops at the house front (x = 1.40) below its gable verge.
EAVE_X, TOP_X = -0.98, 1.36
EAVE_Z, TOP_Z = 2.33, 2.95
Y0, Y1 = -3.42, 3.58
FIXTURES = ("Hearth", "Bellows", "Anvil", "ToolRack", "QuenchTrough", "Workbench", "Stock")


def rot_z(angle):
    return Matrix.Rotation(angle, 3, "Z")


class Forge:
    def __init__(self, seed=811):
        self.id = ID
        self.rng = random.Random(seed)
        self.ageing = Ageing(seed=seed, moss=0.45, damp_height=0.5)
        # Soot from the hearth blackens hood, rafters and tiles above it.
        self.ageing.soot_points = [(Vector((HEARTH.x, HEARTH.y, 1.9)), 1.7), (Vector((HEARTH.x, HEARTH.y, 0.8)), 0.9)]
        self.shell = Mesh(ID + "_shell", self.ageing)
        self.detail = Mesh(ID + "_detail", self.ageing)
        self.far = Mesh(ID + "_far", self.ageing)
        self.fixtures = {name: Mesh(f"{ID}_{name}", self.ageing) for name in FIXTURES}
        self.colliders = []
        self.metadata = {}

    def build(self):
        self.structure()
        self.roof()
        self.floor()
        self.hearth()
        self.bellows()
        self.anvil()
        self.rack()
        self.trough()
        self.workbench()
        self.stock()
        self.far_proxy()
        self.metadata.update({
            "function": "smithy of Nerva (smith_home): hearth, bellows, anvil, quench trough, tool rack, workbench with goods, bar stock, charcoal",
            "stations_godot": {"hearth": [HEARTH.x, -HEARTH.y], "bellows": [BELLOWS.x, -BELLOWS.y], "anvil": [ANVIL.x, -ANVIL.y],
                               "tool_rack": [RACK.x, -RACK.y], "quench_trough": [TROUGH.x, -TROUGH.y], "workbench": [1.02, -1.25],
                               "stock": [0.8, 1.45], "charcoal": [1.06, -2.52]},
            "roof": "mono-pitch lean-to, tegulae and imbrices, %.1f deg" % math.degrees(math.atan2(TOP_Z - EAVE_Z, TOP_X - EAVE_X)),
            "eave_height_m": EAVE_Z, "top_height_m": TOP_Z,
        })
        return self

    # structure ---------------------------------------------------------------
    def structure(self):
        rng, s = self.rng, self.shell
        pitch = (TOP_Z - EAVE_Z) / (TOP_X - EAVE_X)
        for x, y in POSTS:
            top = EAVE_Z + (x - EAVE_X) * pitch - 0.33
            # Pad stone keeps the post foot out of the wet ground.
            s.chamfer_box(Vector((x, y, 0.045)), (0.34, 0.32, 0.13), "flagstone", rot_z(rng.uniform(-0.2, 0.2)), 0.03, rng.random(), skip=("-z",), jitter=0.006, rng=rng)
            s.beam(Vector((x, y, 0.11)), Vector((x, y, top)), 0.15, 0.15, "oak_grey", 0.018, rng.random(), roll=rng.uniform(-0.04, 0.04), rng=rng)
            # Saddle block under the plate.
            s.chamfer_box(Vector((x, y, top + 0.04)), (0.17, 0.46, 0.08), "oak_grey", None, 0.012, rng.random(), grain=1, rng=rng)
        for x in (-0.10, 1.25):
            top = EAVE_Z + (x - EAVE_X) * pitch - 0.33 + 0.08
            s.beam(Vector((x, Y0 + 0.12, top + 0.08)), Vector((x, Y1 - 0.12, top + 0.08)), 0.16, 0.17, "oak_grey", 0.016, rng.random(), rng=rng)
            # Knee braces stiffen the frame along the plate.
            for py, direction in ((3.15, -1), (-3.0, 1)):
                s.beam(Vector((x, py, top - 0.62)), Vector((x, py + direction * 0.62, top + 0.0)), 0.09, 0.10, "oak_grey", 0.01, rng.random(), rng=rng)
        # Tie beams between the post pairs carry hooks and hanging stock.
        for y in (3.15, -3.0):
            z = EAVE_Z + (-0.10 - EAVE_X) * pitch - 0.42
            s.beam(Vector((-0.10, y, z)), Vector((1.25, y, z + 0.0)), 0.10, 0.13, "oak_grey", 0.012, rng.random(), rng=rng)
        # Wattle screen with daub behind the hearth (north end) against wind and sparks.
        y = 3.33
        for k in range(7):
            x = -0.02 + k * 0.205
            s.beam(Vector((x, y, 0.05)), Vector((x + rng.uniform(-0.015, 0.015), y, 2.02 + rng.uniform(-0.05, 0.05))), 0.05, 0.05, "oak_grey", 0.012, rng.random(), rng=rng)
        for index, (z0, z1) in enumerate(((0.10, 0.74), (0.75, 1.36), (1.37, 1.94))):
            wob = rng.uniform(-0.01, 0.01)
            for side, out in ((-1, Vector((0, -1, 0))), (1, Vector((0, 1, 0)))):
                yy = y + side * (0.035 + wob)
                pts = [Vector((-0.06, yy, z0)), Vector((1.27, yy, z0)), Vector((1.27, yy, z1)), Vector((-0.06, yy, z1))]
                s.face(pts, "daub", rng.random(), outward=out)
        for xx, out in ((-0.06, Vector((-1, 0, 0))), (1.27, Vector((1, 0, 0)))):
            s.face([Vector((xx, y - 0.035, 0.10)), Vector((xx, y + 0.035, 0.10)), Vector((xx, y + 0.035, 1.94)), Vector((xx, y - 0.035, 1.94))], "daub", outward=out)
        s.face([Vector((-0.06, y - 0.035, 1.94)), Vector((1.27, y - 0.035, 1.94)), Vector((1.27, y + 0.035, 1.94)), Vector((-0.06, y + 0.035, 1.94))], "daub", outward=Z)

    def roof(self):
        rng, s = self.rng, self.shell
        eL, eR = Vector((EAVE_X, Y1, EAVE_Z)), Vector((EAVE_X, Y0, EAVE_Z))
        rL, rR = Vector((TOP_X, Y1, TOP_Z)), Vector((TOP_X, Y0, TOP_Z))
        info = roof_slope(s, self.detail, eL, eR, rL, rR, rng, sag=0.035, layer_mix=0.5, missing=0.008)
        across = (eR - eL).normalized()
        up = (rL - eL).normalized()
        normal = across.cross(up).normalized()
        if normal.z < 0:
            normal = -normal
        count = 12
        # (rafters; the house door corridor below stays clear: Godot z -0.75..0.75)
        for k in range(count + 1):
            t = k / count
            a = eL.lerp(eR, t) - Z * 0.10 - up * 0.07
            b = rL.lerp(rR, t) - Z * 0.10
            s.beam(a, b, 0.10, 0.13, "oak_grey", 0.012, rng.random(), rng=rng)
        length = (rL - eL).length
        boards = 11
        for k in range(boards):
            t0, t1 = k / boards, (k + 1) / boards - 0.008 / length
            p0, p1 = eL.lerp(rL, t0) - normal * 0.02, eL.lerp(rL, t1) - normal * 0.02
            q0, q1 = eR.lerp(rR, t0) - normal * 0.02, eR.lerp(rR, t1) - normal * 0.02
            s.face([p0, q0, q1, p1], "oak_grey", rng.random(), outward=-normal, uv_basis=(up, across))
            lift = normal * 0.022
            s.face([p0 + lift, p1 + lift, q1 + lift, q0 + lift], "oak_grey", rng.random(), outward=normal, uv_basis=(up, across))
        s.beam(eL - across * 0.02 - Z * 0.04 - up * 0.03, eR + across * 0.02 - Z * 0.04 - up * 0.03, 0.035, 0.16, "oak_grey", 0.008, rng.random(), rng=rng)
        for e, r in ((eL, rL), (eR, rR)):
            s.beam(e + Z * 0.02, r + Z * 0.06, 0.04, 0.2, "oak_grey", 0.008, rng.random(), rng=rng)
        # Top course closed with imbrices in mortar where the lean-to meets the house eave.
        ridge_line(s, rL + Z * 0.03 - up * 0.05, rR + Z * 0.03 - up * 0.05, rng, height=0.04, radius=0.11, sag=0.0)
        self.metadata["tile_rows"] = info["rows"]
        self.metadata["tile_columns"] = info["columns"]

    def floor(self):
        """Rammed working floor: flag slabs at the anvil and hearth, scale and cinders."""
        rng, s = self.rng, self.shell
        slabs = [(-0.35, -1.12, 0.72, 0.62), (0.32, -1.17, 0.58, 0.70), (-0.45, 1.95, 0.60, 0.78), (-0.50, 2.80, 0.52, 0.80), (-0.62, 1.22, 0.56, 0.62)]
        for x, y, w, d in slabs:
            # Tops 12 mm above the ground: no step for feet, no collider needed.
            s.chamfer_box(Vector((x, y, -0.013)), (w, d, 0.05), "flagstone", rot_z(rng.uniform(-0.12, 0.12)), 0.018, rng.random(), skip=("-z",), jitter=0.005, rng=rng)

    # stations ----------------------------------------------------------------
    def hearth(self):
        """Raised hearth 1.18 x 0.85 m, 0.72 m high (collider box of the village)."""
        rng, m = self.rng, self.fixtures["Hearth"]
        c = HEARTH
        hx, hy = 0.59, 0.425
        runs = [((c.x - hx, c.y - hy), (c.x + hx, c.y - hy)), ((c.x + hx, c.y - hy), (c.x + hx, c.y + hy)),
                ((c.x + hx, c.y + hy), (c.x - hx, c.y + hy)), ((c.x - hx, c.y + hy), (c.x - hx, c.y - hy))]
        inset = 0.045
        for a, b in runs:
            a3, b3 = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
            axis = (b3 - a3).normalized()
            out = axis.cross(Z).normalized()
            z = -0.03
            for course in range(3):
                h = 0.215 * rng.uniform(0.94, 1.06) if course < 2 else 0.66 - z
                stone_course(m, a3 - out * inset + axis * 0.02, b3 - out * inset - axis * 0.02, z, h - 0.012, 0.22, rng,
                             layer="rubble_socle", nominal=0.30, protrude=0.04, chamfer=0.028, jitter=0.01)
                z += h
            m.face([a3 - out * (inset + 0.005) - Z * 0.03, b3 - out * (inset + 0.005) - Z * 0.03, b3 - out * (inset + 0.005) + Z * 0.64, a3 - out * (inset + 0.005) + Z * 0.64],
                   "mortar", outward=out)
        # Flag rim around a clay-lined fire bed 5 cm deep.
        top = 0.72
        rim = [(c.x - hx + 0.10, c.y, 0.20, 0.85), (c.x + hx - 0.10, c.y, 0.20, 0.85), (c.x, c.y - hy + 0.085, 0.78, 0.17), (c.x, c.y + hy - 0.085, 0.78, 0.17)]
        for x, y, w, d in rim:
            m.chamfer_box(Vector((x, y, top - 0.035)), (w - 0.006, d - 0.006, 0.07), "flagstone", None, 0.016, rng.random(), skip=("-z",), jitter=0.004, rng=rng)
        bed = top - 0.05
        m.face([Vector((c.x - 0.39, c.y - 0.26, bed)), Vector((c.x + 0.39, c.y - 0.26, bed)), Vector((c.x + 0.39, c.y + 0.26, bed)), Vector((c.x - 0.39, c.y + 0.26, bed))],
               "daub", outward=Z, colors=[(0.2, 0.0, 1.0, 0.0)] * 4)
        # Charcoal heaped in the bed (soot mask blackens the lumps).
        for _ in range(26):
            x = c.x + rng.uniform(-0.31, 0.31)
            y = c.y + rng.uniform(-0.19, 0.19)
            size = rng.uniform(0.045, 0.085)
            height = bed + size * 0.4 + 0.035 * (1 - (abs(x - c.x) / 0.33) ** 2)
            self._lump(m, Vector((x, y, height)), size, "iron", soot=1.0)
        # Back wall with the smoke hood: stones to 1.3 m, daub hood on a timber frame above.
        bx0, bx1, by = c.x - 0.085, c.x + 0.565, c.y + 0.27
        for side, out in ((-1, Vector((0, -1, 0))), (1, Vector((0, 1, 0)))):
            z = top
            y = by + side * 0.22
            for course in range(3):
                h = 0.2 * rng.uniform(0.94, 1.06)
                stone_course(m, Vector((bx0 if side < 0 else bx1, y - side * 0.045, 0)), Vector((bx1 if side < 0 else bx0, y - side * 0.045, 0)), z, h - 0.012, 0.2, rng,
                             layer="rubble_socle", nominal=0.26, protrude=0.04, out=out, chamfer=0.026, jitter=0.01)
                z += h
        for x, out in ((bx0, Vector((-1, 0, 0))), (bx1, Vector((1, 0, 0)))):
            m.face([Vector((x, by - 0.18, top)), Vector((x, by + 0.18, top)), Vector((x, by + 0.18, top + 0.6)), Vector((x, by - 0.18, top + 0.6))], "rubble_socle", outward=out)
        z_hood = top + 0.60
        m.chamfer_box(Vector(((bx0 + bx1) / 2, by, z_hood + 0.04)), (bx1 - bx0 + 0.10, 0.50, 0.08), "oak_grey", None, 0.012, rng.random(), grain=0, rng=rng)
        # Tapering daub flue.
        lo, hi = z_hood + 0.08, z_hood + 1.18
        a = [Vector((bx0, by - 0.22, lo)), Vector((bx1, by - 0.22, lo)), Vector((bx1, by + 0.22, lo)), Vector((bx0, by + 0.22, lo))]
        b = [Vector((bx0 + 0.12, by - 0.15, hi)), Vector((bx1 - 0.12, by - 0.15, hi)), Vector((bx1 - 0.12, by + 0.15, hi)), Vector((bx0 + 0.12, by + 0.15, hi))]
        centre = Vector(((bx0 + bx1) / 2, by, (lo + hi) / 2))
        for k in range(4):
            quad = [a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]]
            mid = (quad[0] + quad[1] + quad[2] + quad[3]) / 4
            m.face(quad, "daub", rng.random(), outward=mid - centre)
        m.face([b[0], b[1], b[2], b[3]], "daub", outward=Z, colors=[(0.0, 0.0, 1.0, 0.0)] * 4)
        # Clay tuyere (blast pipe) from the bellows through the hearth side.
        self._lathe_axis(m, [(0.0, 0.0), (0.055, 0.0), (0.045, 0.30), (0.03, 0.30), (0.0, 0.3)], Vector((c.x - 0.22, c.y - hy + 0.02, top + 0.035)), "tegula_old", 8, Vector((0.25, 1, -0.04)).normalized())

    def _lathe_axis(self, mesh, profile, centre, layer, segments, axis):
        """Lathe around an arbitrary axis (the kit turns around Z): turn, then rotate about the centre."""
        centre = Vector(centre)
        start = len(mesh.verts)
        mesh.lathe(profile, centre, layer, segments, self.rng.random())
        z_axis = Vector(axis).normalized()
        ref = Z if abs(z_axis.z) < 0.9 else Vector((1, 0, 0))
        x_axis = ref.cross(z_axis).normalized()
        turn = Matrix((x_axis, z_axis.cross(x_axis), z_axis)).transposed()
        for i in range(start, len(mesh.verts)):
            mesh.verts[i] = centre + turn @ (mesh.verts[i] - centre)

    def _lump(self, mesh, centre, size, layer, soot=0.0, wear=0.3):
        rng = self.rng
        basis = Matrix.Rotation(rng.uniform(0, 3.1), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 3, "X")
        start = len(mesh.col)
        mesh.chamfer_box(centre, (size * rng.uniform(0.8, 1.3), size * rng.uniform(0.7, 1.1), size * rng.uniform(0.6, 0.9)), layer, basis,
                         size * 0.28, rng.random(), rng=rng, wear=wear)
        if soot > 0:
            # Blacken the lump through the soot mask.
            for i in range(start, len(mesh.col)):
                r, g, b, a = mesh.col[i]
                mesh.col[i] = (r, 0.0, max(b, soot), a)

    def bellows(self):
        """Double bellows on a trestle: two pear-shaped boards, hide bags, a rocking lever."""
        rng, m = self.rng, self.fixtures["Bellows"]
        c = BELLOWS
        # Trestle (0.95 x 0.47 m at 0.60..0.68 m, as the collider expects).
        for x in (-0.36, 0.36):
            for y in (-0.17, 0.17):
                m.beam(Vector((c.x + x, c.y + y, 0.0)), Vector((c.x + x * 0.92, c.y + y * 0.9, 0.60)), 0.07, 0.07, "oak_grey", 0.01, rng.random(), rng=rng)
        m.chamfer_box(Vector((c.x, c.y, 0.63)), (0.95, 0.47, 0.06), "oak_grey", None, 0.012, rng.random(), grain=0, rng=rng)
        for side in (-1, 1):
            y = c.y + side * 0.115
            # Lower board, hide bag (folded), upper board; nozzle toward the hearth (+y).
            m.chamfer_box(Vector((c.x, y, 0.675)), (0.80, 0.20, 0.03), "oak_brown", None, 0.01, rng.random(), grain=0, rng=rng)
            lift = 0.13 if side < 0 else 0.07
            folds = 3
            for k in range(folds):
                z0 = 0.69 + lift * k / folds
                z1 = 0.69 + lift * (k + 1) / folds
                bulge = 0.022 if k % 2 == 0 else 0.008
                ring0 = self._oval(c.x, y, 0.385, 0.092, z0, 0.006 if k else 0.0)
                ring1 = self._oval(c.x, y, 0.385 + bulge, 0.092 + bulge * 0.6, (z0 + z1) / 2, 0.0)
                ring2 = self._oval(c.x, y, 0.385, 0.092, z1, 0.0)
                for lower, upper in ((ring0, ring1), (ring1, ring2)):
                    n = len(lower)
                    for i in range(n):
                        quad = [lower[i], lower[(i + 1) % n], upper[(i + 1) % n], upper[i]]
                        mid = (quad[0] + quad[2]) / 2
                        m.face(quad, "daub", 0.31, outward=mid - Vector((c.x, y, mid.z)), colors=[(0.55, 0.0, 0.35, 0.2)] * 4)
            top = 0.69 + lift
            m.chamfer_box(Vector((c.x, y, top + 0.015)), (0.80, 0.20, 0.03), "oak_brown", None, 0.01, rng.random(), grain=0, rng=rng)
            # Handle peg on the upper board and the nozzle of iron-bound wood.
            m.beam(Vector((c.x - 0.30, y, top + 0.03)), Vector((c.x - 0.30, y, top + 0.16)), 0.035, 0.035, "oak_brown", 0.008, rng.random(), rng=rng)
            self._lathe_axis(m, [(0.0, 0.0), (0.04, 0.0), (0.022, 0.22), (0.0, 0.22)], Vector((c.x + 0.36, y, 0.70)), "oak_brown", 8, Vector((1, 0.15 * -side, 0)).normalized())
            self._lathe_axis(m, [(0.043, 0.0), (0.043, 0.03), (0.0, 0.03)], Vector((c.x + 0.37, y, 0.70)), "iron", 8, Vector((1, 0.15 * -side, 0)).normalized())
        # Rocking lever over a forked post: pulling one side lifts the other board.
        m.beam(Vector((c.x - 0.42, c.y, 0.0)), Vector((c.x - 0.42, c.y, 1.02)), 0.07, 0.07, "oak_grey", 0.01, rng.random(), rng=rng)
        m.beam(Vector((c.x - 0.42, c.y - 0.27, 1.00)), Vector((c.x - 0.42, c.y + 0.27, 1.06)), 0.045, 0.05, "oak_brown", 0.01, rng.random(), rng=rng)

    @staticmethod
    def _oval(cx, cy, rx, ry, z, shrink):
        pts = []
        for i in range(12):
            a = 2 * math.pi * i / 12
            pts.append(Vector((cx + math.cos(a) * (rx - shrink), cy + math.sin(a) * (ry - shrink), z)))
        return pts

    def anvil(self):
        """Block anvil with a short beak, wedged into an oak stump with an iron hoop."""
        rng, m = self.rng, self.fixtures["Anvil"]
        c = ANVIL
        m.lathe([(0.0, 0.0), (0.335, 0.0), (0.32, 0.05), (0.305, 0.30), (0.31, 0.50), (0.295, 0.53), (0.0, 0.53)], c, "oak_grey", 14, rng.random())
        m.lathe([(0.312, 0.40), (0.322, 0.405), (0.322, 0.455), (0.312, 0.46)], c, "iron", 14, rng.random())
        # Tang in the stump, waist, working face 0.20 x 0.17 m at 0.94 m.
        m.chamfer_box(c + Vector((0, 0, 0.62)), (0.19, 0.17, 0.20), "iron", None, 0.02, rng.random(), rng=rng, wear=0.6)
        m.chamfer_box(c + Vector((0, 0, 0.78)), (0.15, 0.14, 0.14), "iron", None, 0.02, rng.random(), rng=rng, wear=0.6)
        m.chamfer_box(c + Vector((0, 0, 0.895)), (0.24, 0.18, 0.11), "iron", None, 0.014, rng.random(), rng=rng, wear=1.0)
        # Short beak toward the smith's left hand (-x) for bending.
        self._lathe_axis(m, [(0.0, 0.0), (0.05, 0.0), (0.012, 0.15), (0.0, 0.15)], c + Vector((-0.12, 0, 0.90)), "iron", 8, Vector((-1, 0, 0)))
        # Wedges holding the tang, a hand hammer and tongs lying on the stump.
        for s in (-1, 1):
            m.chamfer_box(c + Vector((0.0, s * 0.105, 0.545)), (0.12, 0.035, 0.05), "oak_brown", None, 0.008, rng.random(), rng=rng)
        self._hammer(m, c + Vector((0.20, -0.13, 0.555)), 0.9, 0.30, lying=True)
        self._tongs(self.detail, c + Vector((-0.20, 0.14, 0.545)), 2.3, 0.44)

    def _hammer(self, mesh, at, yaw, length, lying=False, head=(0.11, 0.045, 0.045)):
        rng = self.rng
        direction = Vector((math.cos(yaw), math.sin(yaw), 0)) if lying else Vector((0, 0, -1))
        a = Vector(at)
        b = a + direction * length
        mesh.beam(a, b, 0.028, 0.034, "oak_brown", 0.008, rng.random(), rng=rng)
        side = Vector((-direction.y, direction.x, 0)) if lying else Vector((1, 0, 0))
        basis = Matrix((side, direction.cross(side) if lying else Vector((0, 1, 0)), direction if lying else Vector((0, 0, 1)))).transposed()
        mesh.chamfer_box(a + direction * 0.02, head, "iron", basis, 0.008, rng.random(), rng=rng, wear=0.8)

    def _tongs(self, mesh, at, yaw, length):
        rng = self.rng
        d = Vector((math.cos(yaw), math.sin(yaw), 0))
        side = Vector((-d.y, d.x, 0))
        a = Vector(at) + Z * 0.008
        pivot = a + d * length * 0.22
        for s in (-1, 1):
            mesh.beam(a + side * s * 0.02, pivot - side * s * 0.004, 0.014, 0.012, "iron", 0.003, rng.random(), rng=rng)
            mesh.beam(pivot - side * s * 0.004, a + d * length + side * s * 0.03, 0.012, 0.012, "iron", 0.003, rng.random(), rng=rng)

    def rack(self):
        """Tool board on two posts: tongs, hammers, chisels and a rasp on iron hooks."""
        rng, m = self.rng, self.fixtures["ToolRack"]
        c = RACK
        for y in (-0.56, 0.56):
            m.beam(Vector((c.x, c.y + y, 0.0)), Vector((c.x, c.y + y, 1.66)), 0.08, 0.08, "oak_grey", 0.012, rng.random(), rng=rng)
        for z in (1.50, 1.02):
            m.chamfer_box(Vector((c.x - 0.03, c.y, z)), (0.035, 1.22, 0.16), "oak_brown", None, 0.008, rng.random(), grain=1, rng=rng)
        x = c.x - 0.075
        # Upper rail: three tongs of different jaws and two hammers.
        for k, y in enumerate((-0.47, -0.30, -0.13)):
            p = Vector((x, c.y + y, 1.53))
            self.detail.beam(p + Vector((0.03, 0, 0.01)), p + Vector((-0.02, 0, 0.01)), 0.012, 0.012, "iron", 0.003, rng.random(), rng=rng)
            length = 0.50 + 0.06 * k
            for s in (-1, 1):
                m.beam(p + Vector((0, s * 0.012, 0.0)), p + Vector((0, -s * 0.004, -length * 0.25)), 0.014, 0.013, "iron", 0.003, rng.random(), rng=rng)
                m.beam(p + Vector((0, -s * 0.004, -length * 0.25)), p + Vector((0, s * (0.03 + 0.008 * k), -length)), 0.012, 0.012, "iron", 0.003, rng.random(), rng=rng)
        for k, y in enumerate((0.10, 0.30)):
            p = Vector((x, c.y + y, 1.56))
            self._hammer(m, p, 0.0, 0.42 - 0.06 * k, head=(0.05, 0.13 - 0.03 * k, 0.05))
        m.beam(Vector((x, c.y + 0.48, 1.55)), Vector((x, c.y + 0.48, 1.13)), 0.03, 0.012, "iron", 0.004, rng.random(), rng=rng)   # rasp
        # Lower rail: chisels and punches in a row, a pair of shears.
        for k in range(6):
            y = -0.46 + k * 0.12
            length = rng.uniform(0.16, 0.26)
            m.beam(Vector((x, c.y + y, 1.08)), Vector((x, c.y + y, 1.08 - length)), 0.018, 0.018, "iron", 0.004, rng.random(), rng=rng)
        for s in (-1, 1):
            m.beam(Vector((x, c.y + 0.36 + s * 0.02, 1.07)), Vector((x, c.y + 0.36 - s * 0.03, 0.72)), 0.028, 0.008, "iron", 0.003, rng.random(), rng=rng)

    def trough(self):
        """Quench trough of oak planks with iron hoops (0.82 x 0.90 m, 0.57 m high)."""
        rng, m = self.rng, self.fixtures["QuenchTrough"]
        c = TROUGH
        for side in (-1, 1):
            for k in range(3):
                z = 0.095 + k * 0.19
                m.chamfer_box(Vector((c.x + side * 0.39, c.y, z)), (0.07, 0.92, 0.185), "oak_grey", None, 0.012, rng.random(), grain=1, rng=rng)
                m.chamfer_box(Vector((c.x, c.y + side * 0.42, z)), (0.71, 0.07, 0.185), "oak_grey", None, 0.012, rng.random(), grain=0, rng=rng)
        m.chamfer_box(Vector((c.x, c.y, 0.04)), (0.72, 0.78, 0.05), "oak_grey", None, 0.01, rng.random(), grain=1, rng=rng)
        for x in (-0.41, 0.41):
            for y in (-0.44, 0.44):
                m.beam(Vector((c.x + x, c.y + y, 0.0)), Vector((c.x + x, c.y + y, 0.60)), 0.075, 0.075, "oak_grey", 0.012, rng.random(), rng=rng)
        for z in (0.14, 0.46):
            for side in (-1, 1):
                self.detail.chamfer_box(Vector((c.x + side * 0.428, c.y, z)), (0.008, 0.80, 0.035), "iron", None, 0.002, rng.random(), rng=rng)

    def workbench(self):
        """Bench against the house side with finished goods: sickles, knives, nails, a plough share."""
        rng, m = self.rng, self.fixtures["Workbench"]
        cx, cy = 1.02, 1.25
        top = 0.80
        for k in range(3):
            m.chamfer_box(Vector((cx - 0.17 + k * 0.17, cy, top - 0.03)), (0.165, 0.95, 0.055), "oak_brown", None, 0.01, rng.random(), grain=1, rng=rng)
        for x in (-0.20, 0.20):
            for y in (-0.40, 0.40):
                m.beam(Vector((cx + x, cy + y, 0.0)), Vector((cx + x, cy + y, top - 0.055)), 0.08, 0.08, "oak_grey", 0.012, rng.random(), rng=rng)
        m.beam(Vector((cx, cy - 0.40, 0.28)), Vector((cx, cy + 0.40, 0.28)), 0.05, 0.08, "oak_grey", 0.01, rng.random(), rng=rng)
        d = self.detail
        # Sickle blades (curved in five segments) with tangs.
        for index, y in enumerate((-0.40, -0.27)):
            base = Vector((cx - 0.10, cy + y, top + 0.006))
            prev = base
            for k in range(1, 6):
                a = 0.5 * k
                p = base + Vector((0.16 * math.sin(a), 0.03 * index + 0.16 * (1 - math.cos(a)) * 0.6, 0))
                d.beam(prev, p, 0.022, 0.005, "iron", 0.002, rng.random(), rng=rng)
                prev = p
            d.beam(base, base + Vector((-0.09, -0.02, 0)), 0.024, 0.02, "oak_brown", 0.005, rng.random(), rng=rng)
        # Knives, a socketed axe head, a plough share and a tray of nails.
        for k in range(3):
            p = Vector((cx - 0.12 + 0.02 * k, cy - 0.10 + 0.07 * k, top + 0.006))
            d.beam(p, p + Vector((0.19, 0.01, 0)), 0.024, 0.005, "iron", 0.002, rng.random(), rng=rng)
            d.beam(p, p + Vector((-0.09, 0, 0)), 0.02, 0.016, "oak_brown", 0.004, rng.random(), rng=rng)
        m.chamfer_box(Vector((cx + 0.08, cy + 0.20, top + 0.03)), (0.17, 0.085, 0.05), "iron", rot_z(0.4), 0.012, rng.random(), rng=rng, wear=0.8)
        m.chamfer_box(Vector((cx - 0.02, cy + 0.37, top + 0.022)), (0.30, 0.12, 0.035), "iron", rot_z(-0.25), 0.012, rng.random(), rng=rng, wear=0.7)
        tray = Vector((cx + 0.10, cy - 0.25, top + 0.02))
        for a, b, w in ((Vector((-0.11, -0.08, 0)), Vector((0.11, -0.08, 0)), 0.012), (Vector((-0.11, 0.08, 0)), Vector((0.11, 0.08, 0)), 0.012),
                        (Vector((-0.11, -0.08, 0)), Vector((-0.11, 0.08, 0)), 0.012), (Vector((0.11, -0.08, 0)), Vector((0.11, 0.08, 0)), 0.012)):
            m.beam(tray + a, tray + b, w, 0.04, "oak_grey", 0.004, rng.random(), rng=rng)
        for _ in range(14):
            p = tray + Vector((rng.uniform(-0.09, 0.09), rng.uniform(-0.06, 0.06), -0.008))
            ang = rng.uniform(0, math.pi)
            d.beam(p, p + Vector((math.cos(ang) * 0.06, math.sin(ang) * 0.06, 0.004)), 0.006, 0.006, "iron", 0.0015, rng.random(), rng=rng)
        # Whetstone and a water bowl.
        m.chamfer_box(Vector((cx - 0.13, cy + 0.20, top + 0.02)), (0.16, 0.05, 0.035), "flagstone", rot_z(0.9), 0.008, rng.random(), rng=rng)
        m.lathe([(0.0, 0.0), (0.05, 0.0), (0.085, 0.045), (0.078, 0.045), (0.045, 0.012), (0.0, 0.012)], Vector((cx + 0.12, cy + 0.02, top)), "tegula_old", 10, rng.random())

    def stock(self):
        """Raw material: bar iron, bloom iron, charcoal in wicker-like tubs, slag and a water pail."""
        rng, m = self.rng, self.fixtures["Stock"]
        # Bar stock leaning in a bundle and lying on two billets (old position x .75, z 1.2..1.7).
        for k, y in enumerate((-1.2, -1.45, -1.7)):
            a = Vector((0.75 - 0.52 * math.cos(0.2), y + 0.52 * math.sin(0.2) * 0, 0.075 + 0.002 * k))
            m.beam(Vector((0.30, y + 0.10, 0.085)), Vector((1.30, y - 0.10, 0.085)), 0.05, 0.05, "iron", 0.008, rng.random(), roll=rng.uniform(0, 0.6), rng=rng)
            del a
        for x in (0.45, 1.15):
            m.beam(Vector((x, -1.85, 0.03)), Vector((x + 0.03, -1.08, 0.03)), 0.07, 0.06, "oak_grey", 0.01, rng.random(), rng=rng)
        # Blooms from the smelter: rough spongy lumps waiting to be consolidated.
        for _ in range(7):
            self._lump(m, Vector((1.30 + rng.uniform(-0.16, 0.16), -2.55 + rng.uniform(-0.2, 0.2), rng.uniform(0.05, 0.11))), rng.uniform(0.11, 0.17), "iron", soot=0.25, wear=0.9)
        # Two charcoal tubs of staves by the hearth, heaped.
        for cx, cy in ((1.06, 2.52),):
            c = Vector((cx, cy, 0))
            m.lathe([(0.0, 0.02), (0.22, 0.02), (0.22, 0.0), (0.24, 0.0), (0.275, 0.40), (0.25, 0.40), (0.225, 0.05), (0.0, 0.05)], c, "oak_grey", 12, rng.random())
            for z in (0.10, 0.31):
                r = 0.249 + 0.0875 * z
                m.lathe([(r, z), (r + 0.006, z + 0.002), (r + 0.006 + 0.003, z + 0.035), (r + 0.003, z + 0.037)], c, "iron", 12, rng.random())
            for _ in range(22):
                a = rng.uniform(0, 2 * math.pi)
                r = 0.19 * math.sqrt(rng.random())
                self._lump(m, c + Vector((math.cos(a) * r, math.sin(a) * r, 0.37 + 0.09 * (1 - r / 0.19) + rng.uniform(-0.01, 0.01))), rng.uniform(0.05, 0.09), "iron", soot=1.0)
        # Loose charcoal spilled beside the tub.
        for _ in range(10):
            self._lump(m, Vector((0.98 + rng.uniform(-0.14, 0.14), 2.02 + rng.uniform(-0.1, 0.1), rng.uniform(0.02, 0.05))), rng.uniform(0.05, 0.08), "iron", soot=1.0)
        # Slag and hammer scale swept aside, clear of the path to the house door.
        for _ in range(9):
            self._lump(self.detail, Vector((-0.62 + rng.uniform(-0.15, 0.15), 1.25 + rng.uniform(-0.25, 0.25), 0.02)), rng.uniform(0.04, 0.08), "iron", soot=0.6, wear=0.2)
        # Stave pail for quenching small work, beside the anvil.
        c = Vector((-0.38, -1.60, 0))
        m.lathe([(0.0, 0.015), (0.13, 0.015), (0.13, 0.0), (0.145, 0.0), (0.165, 0.30), (0.15, 0.30), (0.133, 0.04), (0.0, 0.04)], c, "oak_brown", 10, rng.random())
        m.lathe([(0.158, 0.21), (0.165, 0.212), (0.167, 0.24), (0.160, 0.242)], c, "iron", 10, rng.random())

    def far_proxy(self):
        far = self.far
        eL, eR = Vector((EAVE_X, Y1, EAVE_Z)), Vector((EAVE_X, Y0, EAVE_Z))
        rL, rR = Vector((TOP_X, Y1, TOP_Z)), Vector((TOP_X, Y0, TOP_Z))
        far.face([eL, eR, rR, rL], "tegula_old", outward=Vector((-0.3, 0, 1)))
        far.face([eL - Z * 0.14, rL - Z * 0.14, rR - Z * 0.14, eR - Z * 0.14], "oak_grey", outward=-Z)
        for x, y in POSTS:
            for out in (Vector((-1, 0, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0))):
                side = out.cross(Z)
                p = Vector((x, y, 0)) + out * 0.075
                far.face([p - side * 0.075, p + side * 0.075, p + side * 0.075 + Z * 2.3, p - side * 0.075 + Z * 2.3], "oak_grey", outward=out)
