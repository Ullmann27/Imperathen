"""House recipes of the Valdora family: three wealth tiers, several variants each.

Late Republican countryside of Aquileia, 58 BC. All variants keep the shared
ground-floor room of the village (interior contract of
prototype/scripts/world/village/household_designs.gd): plaster faces at
x = +-2.68 m and y = +-2.17 m, paving at 0.3925 m, door in the street wall
centred at x = 0 (clear width 1.12 m, leaf hinged at (-0.575, -2.15), opened
100 degrees inward), windows at the contract positions, the table, wall bench
and corner jar as separate fixture meshes. Blender axes: metres, Z up, the
street side is -Y (Godot +Z after glTF export).

Historic basis (summarised in docs/36_architecture/VALDORA_HOUSE_FAMILY.md):
rubble or field-stone socles with lime mortar, opus incertum walls, lime
render (intonaco), timber framing with wattle and daub for poorer houses,
tegula and imbrex roofs, wooden shutters and iron grilles instead of glass,
Tuscan (Italic) columns, terracotta antefixes and First Style painted bands
for well-off households. No imperial-era features (no brick-faced opus
testaceum/reticulatum facades, no glazed windows, no marble veneer).
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass

from mathutils import Matrix, Vector

from family_kit import (Ageing, Mesh, Opening, Z, bracket, column, frame, grille,
                        mortar_bed, plank_leaf, ridge_line, roof_slope, shutter, stone_course, wall)  # noqa: F401

FLOOR = 0.3925
HALF_X = 3.0
HALF_Y = 2.5
INNER_X = 2.68
INNER_Y = 2.17
PLATE = 3.26
DOOR = (-0.69, 0.69, FLOOR, 2.56)
FRONT_WINDOWS = [(-2.32, -1.28, 1.52, 2.48), (1.28, 2.32, 1.52, 2.48)]
REAR_WINDOW = (-0.48, 0.48, 1.70, 2.50)
EAST_WINDOW = (-0.52, 0.52, 1.52, 2.48)
LEAF_HINGE = Vector((-0.575, -2.15, FLOOR + 0.035))
LEAF_ANGLE = math.radians(100)
PORCH_DEPTH = 1.05


@dataclass
class Variant:
    id: str
    tier: int
    label: str
    walls: str            # render | daub | stone
    roof: str             # gable_front | eave_front
    seed: int
    canopy: bool = False
    porch: bool = False
    upper: bool = False
    paint: str | None = None
    quoins: bool = False
    grilles: bool = False
    antefixes: bool = False
    loss: float = 0.15
    moss: float = 0.5
    plate: float = PLATE
    pitch_deg: float = 24.0


VARIANTS = [
    Variant("valdora_t1_daub", 1, "Fachwerk mit Lehmflechtwerk, Bruchsteinsockel", "daub", "gable_front", 501, loss=0.0, moss=0.8, pitch_deg=25),
    Variant("valdora_t1_rubble", 1, "Bruchsteinhaus mit Lehmputzresten", "stone", "eave_front", 502, loss=0.0, moss=0.75, pitch_deg=23),
    Variant("valdora_t2_render", 2, "Kalkputzhaus mit Vordach", "render", "gable_front", 601, canopy=True, paint="paint_red", loss=0.12, moss=0.45),
    Variant("valdora_t2_eave", 2, "Traufständiges Putzhaus mit Ockerband", "render", "eave_front", 602, paint="paint_ochre", grilles=True, loss=0.2, moss=0.55, pitch_deg=22),
    Variant("valdora_t2_mixed", 2, "Teilverputztes Bruchsteinhaus mit Fenstergittern", "render", "gable_front", 603, grilles=True, loss=0.42, moss=0.6, pitch_deg=26),
    Variant("valdora_t2_hip", 2, "Putzhaus mit Walmdach und Ockersockel", "render", "hip", 604, paint="paint_ochre", grilles=True, loss=0.18, moss=0.5, pitch_deg=23),
    Variant("valdora_t3_portico", 3, "Haus mit tuskischer Vorhalle, Antefixen und Ziermalerei", "render", "eave_front", 701, porch=True, paint="paint_red",
            quoins=True, grilles=True, antefixes=True, loss=0.05, moss=0.3, pitch_deg=22),
    Variant("valdora_t3_upper", 3, "Zweigeschossiges Haus mit Holzbalkon (maenianum)", "render", "gable_front", 702, upper=True, paint="paint_ochre",
            quoins=True, grilles=True, loss=0.08, moss=0.35, plate=5.6, pitch_deg=23),
]
BY_ID = {v.id: v for v in VARIANTS}


class House:
    def __init__(self, variant: Variant):
        self.v = variant
        self.rng = random.Random(variant.seed)
        self.ageing = Ageing(seed=variant.seed, moss=variant.moss, damp_height=0.9 if variant.tier == 1 else 0.7)
        self.shell = Mesh(variant.id + "_shell", self.ageing)
        self.detail = Mesh(variant.id + "_detail", self.ageing)
        self.far = Mesh(variant.id + "_far", self.ageing)
        self.fixtures = {k: Mesh(f"{variant.id}_fixture_{k}", self.ageing) for k in ("table", "bench", "jar")}
        self.colliders = []   # Godot-local boxes: centre, size, yaw
        self.metadata = {}
        # Soot above the door (smoke left through door and roof vent over the hearth).
        self.ageing.soot_points = [(Vector((0.0, -2.52, 2.75)), 0.85), (Vector((1.62, -1.5, PLATE + 0.8)), 0.7)]

    # ------------------------------------------------------------- helpers
    def collider(self, centre, size, yaw=0.0, name="Collider"):
        """Record a Godot-local box (x, y, z with +Z toward the street)."""
        c = Vector(centre)
        self.colliders.append({"name": name, "centre": [round(c.x, 4), round(c.z, 4), round(-c.y, 4)],
                               "size": [round(size[0], 4), round(size[2], 4), round(size[1], 4)], "yaw": round(yaw, 5)})

    def top_flat(self, h):
        return lambda u: h

    # ------------------------------------------------------------- assembly
    def build(self):
        v = self.v
        self.socle()
        self.walls()
        if v.quoins:
            self.quoins()
        self.openings()
        self.floor_and_interior()
        self.roof()
        self.entrance()
        if v.canopy:
            self.canopy()
        if v.porch:
            self.porch()
        if v.upper:
            self.balcony()
        self.fixtures_build()
        self.far_proxy()
        self.wall_colliders()
        return self

    # socle ---------------------------------------------------------------
    def socle(self):
        v, rng = self.v, self.rng
        height = 0.72 if v.walls == "stone" else (0.62 if v.walls == "daub" else 0.55)
        courses = 3 if height > 0.6 else 2
        runs = [((-HALF_X, -HALF_Y), (HALF_X, -HALF_Y)), ((HALF_X, -HALF_Y), (HALF_X, HALF_Y)),
                ((HALF_X, HALF_Y), (-HALF_X, HALF_Y)), ((-HALF_X, HALF_Y), (-HALF_X, -HALF_Y))]
        for a, b in runs:
            a3, b3 = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
            axis = (b3 - a3).normalized()
            out = axis.cross(Z).normalized()
            # Door gap in the street wall: the threshold stone fills it.
            segments = [(a3, b3)]
            if a[1] == -HALF_Y and b[1] == -HALF_Y:
                segments = [(a3, Vector((DOOR[0] - 0.02, -HALF_Y, 0))), (Vector((DOOR[1] + 0.02, -HALF_Y, 0)), b3)]
            for s0, s1 in segments:
                mortar_bed(self.shell, s0 + out * 0.0, s1 + out * 0.0, -0.05, height, 0.0)
                z = -0.04
                for c in range(courses):
                    h = (height + 0.04) / courses * rng.uniform(0.9, 1.1)
                    if c == courses - 1:
                        h = height + 0.02 - z
                    stone_course(self.shell, s0, s1, z, h, 0.30, rng, "flagstone", nominal=0.50 if c == 0 else 0.36,
                                 protrude=0.05 if c == 0 else 0.032, out=out, chamfer=0.045, jitter=0.022)
                    z += h
            # Loose pebbles and a drip edge of small stones along the foot.
            for k in range(int((b3 - a3).length / 0.5)):
                p = a3 + axis * rng.uniform(0.1, (b3 - a3).length - 0.1) + out * rng.uniform(0.08, 0.32)
                if a[1] == -HALF_Y and b[1] == -HALF_Y and abs(p.x) < 1.0:
                    continue
                s = rng.uniform(0.04, 0.09)
                self.detail.chamfer_box(p + Z * (s * 0.25), (s * 1.3, s, s * 0.7), "rubble_socle",
                                        Matrix.Rotation(rng.uniform(0, math.pi), 3, 'Z'), s * 0.3, rng.random(), jitter=s * 0.12, rng=rng)
        self.socle_height = height
        self.metadata["socle_height_m"] = height

    # walls ---------------------------------------------------------------
    def wall_specs(self):
        v = self.v
        plate = v.plate
        ridge = self.ridge_height()
        def gable(u, length):
            # The gable wall rises to the underside of the roof boards (span
            # includes the 0.40 m eave overhang), so no slit shows under the verge.
            span = length / 2 + 0.40
            return min(ridge - 0.08, plate + (span - abs(u - length / 2)) * math.tan(math.radians(v.pitch_deg)) - 0.035)
        front_top = (lambda u: gable(u, 2 * HALF_X)) if v.roof == "gable_front" else (lambda u: plate)
        side_top = (lambda u: gable(u, 2 * HALF_Y)) if v.roof == "eave_front" else (lambda u: plate)
        if v.roof == "hip":
            front_top = side_top = (lambda u: plate)
        front_openings = [Opening(DOOR[0] + HALF_X, DOOR[1] + HALF_X, DOOR[2], DOOR[3], "door")]
        front_openings += [Opening(a + HALF_X, b + HALF_X, lo, hi) for a, b, lo, hi in FRONT_WINDOWS]
        rear_openings = [Opening(HALF_X - REAR_WINDOW[1], HALF_X - REAR_WINDOW[0], REAR_WINDOW[2], REAR_WINDOW[3])]
        east_openings = [Opening(EAST_WINDOW[0] + HALF_Y, EAST_WINDOW[1] + HALF_Y, EAST_WINDOW[2], EAST_WINDOW[3])]
        if v.upper:
            front_openings += [Opening(-1.9 + HALF_X, -1.2 + HALF_X, 4.05, 4.85), Opening(1.2 + HALF_X, 1.9 + HALF_X, 4.05, 4.85),
                               Opening(-0.55 + HALF_X, 0.55 + HALF_X, 3.55, 5.3, "door")]
            rear_openings += [Opening(HALF_X - 0.4, HALF_X + 0.4, 4.1, 4.8)]
        # (origin at the outer face corner, u axis, length, top(u), openings)
        return [
            ("front", Vector((-HALF_X, -HALF_Y, 0)), Vector((1, 0, 0)), 2 * HALF_X, front_top, front_openings, 0.33),
            ("east", Vector((HALF_X, -HALF_Y, 0)), Vector((0, 1, 0)), 2 * HALF_Y, side_top, east_openings, 0.32),
            ("rear", Vector((HALF_X, HALF_Y, 0)), Vector((-1, 0, 0)), 2 * HALF_X, front_top, rear_openings, 0.33),
            ("west", Vector((-HALF_X, HALF_Y, 0)), Vector((0, -1, 0)), 2 * HALF_Y, side_top, [], 0.32),
        ]

    def ridge_height(self):
        v = self.v
        span = (HALF_X if v.roof == "gable_front" else HALF_Y) + 0.40  # eave_front and hip span the depth
        return v.plate + span * math.tan(math.radians(v.pitch_deg))

    def walls(self):
        v, rng = self.v, self.rng
        outer = {"render": "plaster_lime" if v.tier >= 3 else "plaster_aged", "daub": "daub", "stone": "opus_incertum"}[v.walls]
        core = "opus_incertum" if v.walls != "daub" else "daub"
        for name, origin, u_axis, length, top, openings, thick in self.wall_specs():
            loss = v.loss
            if v.walls == "stone":
                loss = 0.0
            bottom = self.socle_height - 0.02
            paint = (v.paint, 1.05) if (v.paint and name == "front") else ((v.paint, 0.95) if v.paint and v.tier >= 3 else None)
            if v.walls == "daub":
                self.timber_frame(name, origin, u_axis, length, top, openings, thick, bottom)
                continue
            # The visible outer render sits on the wall line; reveals carry plaster.
            for op in openings:
                op.reveal = "plaster_aged" if v.tier < 3 else "plaster_lime"
                if v.walls == "stone":
                    op.reveal = "opus_incertum"
            wall(self.shell, origin, u_axis, length, top, thick, openings, outer, core, rng, loss=loss,
                 cell=0.15, relief=0.007 if v.walls == "render" else 0.012, bottom=bottom, seed=v.seed + len(name),
                 paint=paint if v.walls == "render" else None, inner_layer="plaster_lime")
            # Interior below the socle top (inner face of the footing).
            iu = Vector(u_axis)
            inward = -iu.cross(Z).normalized()
            io = origin + inward * thick
            # The doorway stays open down to the threshold.
            u = 0.0
            for op in sorted((o for o in openings if o.kind == "door" and o.v0 < bottom), key=lambda o: o.u0) + [None]:
                end = length if op is None else op.u0
                if end - u > 0.01:
                    self.shell.face([io + iu * u + Z * FLOOR, io + iu * end + Z * FLOOR, io + iu * end + Z * bottom, io + iu * u + Z * bottom], "plaster_aged", outward=inward)
                u = length if op is None else op.u1

    def timber_frame(self, name, origin, u_axis, length, top, openings, thick, bottom):
        """Oak posts, sill beam, rails and braces with daub panels between them."""
        rng = self.rng
        u_axis = Vector(u_axis)
        out = u_axis.cross(Z).normalized()
        # Daub infill (displaced, partly limewashed) slightly behind the timbers.
        infill = [Opening(op.u0, op.u1, op.v0, op.v1, op.kind, "daub") for op in openings]
        wall(self.shell, origin - out * 0.035, u_axis, length, top, thick - 0.035, infill, "daub", "daub", rng, loss=0.0,
             cell=0.2, relief=0.012, bottom=bottom, seed=self.v.seed + len(name), inner_layer="plaster_aged")
        plate = self.v.plate
        posts = sorted(set([0.09, length - 0.09] + [op.u0 - 0.06 for op in openings] + [op.u1 + 0.06 for op in openings]))
        extra = []
        for a, b in zip(posts, posts[1:]):
            mid = (a + b) / 2
            # No stud in the middle of a door or window.
            if b - a > 1.4 and not any(op.u0 - 0.1 <= mid <= op.u1 + 0.1 for op in openings):
                extra.append(mid)
        posts = sorted(posts + extra)
        for u in posts:
            p = origin + u_axis * u + out * 0.0
            self.shell.beam(p + Z * bottom, p + Z * min(top(u), plate + 0.02), 0.16, 0.16, "oak_grey", 0.02, rng.random(), rng=rng)
        for z in (bottom + 0.06, plate - 0.06):
            # The sill beam is cut at the doorway; the wall plate runs through.
            u = 0.0
            doors = sorted((o for o in openings if o.kind == "door" and o.v0 < z < o.v1), key=lambda o: o.u0)
            for op in doors + [None]:
                end = length if op is None else op.u0 - 0.14
                if end - u > 0.05:
                    self.shell.beam(origin + u_axis * u + Z * z, origin + u_axis * end + Z * z, 0.17, 0.17, "oak_grey", 0.02, rng.random(), rng=rng)
                u = length if op is None else op.u1 + 0.14
        rail = (bottom + plate) * 0.5 - 0.15
        for a, b in zip(posts, posts[1:]):
            mid = (a + b) / 2
            if any(op.u0 - 0.1 <= mid <= op.u1 + 0.1 for op in openings):
                continue
            pa = origin + u_axis * a + Z * rail
            pb = origin + u_axis * b + Z * rail
            self.shell.beam(pa, pb, 0.12, 0.12, "oak_grey", 0.015, rng.random(), rng=rng)
            if b - a > 0.8:
                self.shell.beam(origin + u_axis * a + Z * (bottom + 0.1), origin + u_axis * b + Z * (rail - 0.05), 0.11, 0.11, "oak_grey", 0.015, rng.random(), rng=rng)

    def quoins(self):
        rng = self.rng
        for sx in (-1, 1):
            for sy in (-1, 1):
                z = self.socle_height
                row = 0
                while z < self.v.plate - 0.3:
                    h = rng.uniform(0.24, 0.30)
                    long_x = row % 2 == 0
                    lx = 0.52 if long_x else 0.30
                    ly = 0.30 if long_x else 0.52
                    c = Vector((sx * (HALF_X - lx / 2 + 0.018), sy * (HALF_Y - ly / 2 + 0.018), z + h / 2))
                    self.shell.chamfer_box(c, (lx, ly, h - 0.012), "flagstone", None, 0.025, rng.random(), jitter=0.006, rng=rng)
                    z += h
                    row += 1

    # openings ------------------------------------------------------------
    def openings(self):
        v, rng = self.v, self.rng
        oak = "oak_brown" if v.tier >= 2 else "oak_grey"
        sill_layer = "flagstone" if v.tier >= 2 else None
        front_o, front_u = Vector((-HALF_X, -HALF_Y, 0)), Vector((1, 0, 0))
        # Door frame (stone jambs for tier 3, oak frame otherwise) and threshold.
        if v.tier >= 3:
            for s in (-1, 1):
                c = Vector((s * 0.635, -HALF_Y + 0.02, (FLOOR + 2.56) / 2 + 0.02))
                self.shell.chamfer_box(c, (0.15, 0.40, 2.56 - FLOOR + 0.04), "flagstone", None, 0.02, rng.random(), rng=rng)
            self.shell.chamfer_box(Vector((0, -HALF_Y + 0.02, 2.66)), (1.62, 0.42, 0.22), "flagstone", None, 0.025, rng.random(), rng=rng)
        else:
            frame(self.shell, HALF_X, front_o, front_u, FLOOR + 0.02, 2.49, 1.12, 0.26, oak, rng, outset=0.02)
        plank_leaf(self.shell, self.detail, LEAF_HINGE, 1.12, 2.08, LEAF_ANGLE, rng, oak, boards=5 if v.tier < 3 else 6,
                   studs=v.tier >= 3, ring=v.tier >= 2)
        for a, b, lo, hi in FRONT_WINDOWS:
            cu = (a + b) / 2 + HALF_X
            w = b - a - 0.14
            frame(self.shell, cu, front_o, front_u, lo + 0.04, hi - 0.05, w, 0.18, oak, rng, sill_layer=sill_layer, outset=0.025)
            if v.grilles and v.tier >= 2:
                grille(self.detail, front_o, front_u, cu, lo + 0.04, hi - 0.05, w, rng, bars=3, inset=0.12)
            # Shutters stand open against the facade (hinged on the frame posts).
            for side in (-1, 1):
                hinge = Vector(((a + b) / 2 + side * (w / 2 + 0.11), -HALF_Y - 0.05, lo + 0.05))
                # Swung open flat against the facade, a few degrees off the wall.
                angle = math.radians(0 if side > 0 else 180) + math.radians(side * -(4 + rng.uniform(0, 9)))
                if v.tier == 1 and side > 0 and rng.random() < 0.5:
                    angle = math.radians(-62)  # one leaf left half open
                shutter(self.shell, self.detail, hinge, w / 2 + 0.03, hi - lo - 0.1, angle, rng, "oak_grey" if v.tier < 3 else "oak_brown")
        east_o, east_u = Vector((HALF_X, -HALF_Y, 0)), Vector((0, 1, 0))
        cu = (EAST_WINDOW[0] + EAST_WINDOW[1]) / 2 + HALF_Y
        frame(self.shell, cu, east_o, east_u, EAST_WINDOW[2] + 0.04, EAST_WINDOW[3] - 0.05, 0.90, 0.18, oak, rng, sill_layer=sill_layer, outset=0.025)
        if v.grilles:
            grille(self.detail, east_o, east_u, cu, EAST_WINDOW[2] + 0.04, EAST_WINDOW[3] - 0.05, 0.90, rng, bars=3, inset=0.12)
        rear_o, rear_u = Vector((HALF_X, HALF_Y, 0)), Vector((-1, 0, 0))
        cu = HALF_X - (REAR_WINDOW[0] + REAR_WINDOW[1]) / 2
        frame(self.shell, cu, rear_o, rear_u, REAR_WINDOW[2] + 0.04, REAR_WINDOW[3] - 0.05, 0.86, 0.18, oak, rng, sill_layer=sill_layer, outset=0.025)
        if v.upper:
            for a, b in ((-1.9, -1.2), (1.2, 1.9)):
                frame(self.shell, (a + b) / 2 + HALF_X, front_o, front_u, 4.09, 4.80, b - a - 0.14, 0.18, oak, rng, sill_layer="flagstone", outset=0.025)
            frame(self.shell, HALF_X, front_o, front_u, 3.57, 5.25, 0.98, 0.22, oak, rng, outset=0.02)
            frame(self.shell, HALF_X, rear_o, rear_u, 4.14, 4.76, 0.66, 0.18, oak, rng, outset=0.025)

    # interior ------------------------------------------------------------
    def floor_and_interior(self):
        rng = self.rng
        # Paving whose top is exactly the collider (Layout.HOUSE_FLOOR).
        xs = [-INNER_X + 0.045]
        x = xs[0]
        while x < INNER_X - 0.045 - 0.2:
            x += rng.uniform(0.62, 0.92)
            xs.append(min(x, INNER_X - 0.045))
        xs[-1] = INNER_X - 0.045
        for i in range(len(xs) - 1):
            y = -INNER_Y + 0.045
            while y < INNER_Y - 0.06:
                depth = min(rng.uniform(0.52, 0.80), INNER_Y - 0.045 - y)
                c = Vector(((xs[i] + xs[i + 1]) / 2, y + depth / 2, FLOOR - 0.04))
                self.shell.chamfer_box(c, (xs[i + 1] - xs[i] - 0.012, depth - 0.012, 0.08), "flagstone", None, 0.008, rng.random(), skip=("-z",))
                y += depth
        # Trodden fill in the slab joints (dark, 6 mm below the walking surface).
        self.shell.face([Vector((-INNER_X, -INNER_Y, FLOOR - 0.006)), Vector((INNER_X, -INNER_Y, FLOOR - 0.006)),
                         Vector((INNER_X, INNER_Y, FLOOR - 0.006)), Vector((-INNER_X, INNER_Y, FLOOR - 0.006))], "mortar", outward=Z)

    # roof ----------------------------------------------------------------
    def roof(self):
        v, rng = self.v, self.rng
        plate = v.plate
        over_side, over_end = 0.40, 0.34
        ridge = self.ridge_height()
        sag = 0.045 if v.tier == 1 else (0.03 if v.tier == 2 else 0.015)
        layer_mix = {1: 0.45, 2: 0.3, 3: 0.12}[v.tier]
        # Poor roofs miss the odd tile; the boarding shows through the gap.
        missing = 0.012 if v.tier == 1 else 0.0
        if v.roof == "gable_front":
            # Ridge along Y, slopes fall to the east and west eaves.
            half_span = HALF_X + over_side
            y0, y1 = -HALF_Y - over_end, HALF_Y + over_end
            eave_z = plate - over_side * math.tan(math.radians(v.pitch_deg))
            slopes = [((-half_span, y1, eave_z), (-half_span, y0, eave_z), (0, y1, ridge), (0, y0, ridge)),
                      ((half_span, y0, eave_z), (half_span, y1, eave_z), (0, y0, ridge), (0, y1, ridge))]
            ridge_a, ridge_b = Vector((0, y0, ridge)), Vector((0, y1, ridge))
        else:
            half_span = HALF_Y + over_side
            x0, x1 = -HALF_X - over_end, HALF_X + over_end
            eave_z = plate - over_side * math.tan(math.radians(v.pitch_deg))
            # A porch sits under the prolonged street slope (one continuous roof).
            front_span = half_span + (PORCH_DEPTH if v.porch else 0.0)
            front_z = plate - (front_span - HALF_Y) * math.tan(math.radians(v.pitch_deg))
            self.front_eave = (front_span, front_z)
            slopes = [((x0, -front_span, front_z), (x1, -front_span, front_z), (x0, 0, ridge), (x1, 0, ridge)),
                      ((x1, half_span, eave_z), (x0, half_span, eave_z), (x1, 0, ridge), (x0, 0, ridge))]
            ridge_a, ridge_b = Vector((x0, 0, ridge)), Vector((x1, 0, ridge))
        if v.roof == "hip":
            hs = HALF_Y + over_side
            x0, x1 = -HALF_X - over_end, HALF_X + over_end
            eave_z = plate - over_side * math.tan(math.radians(v.pitch_deg))
            inset = hs  # equal pitch on all four slopes: the ridge is inset by the half span
            a, b = Vector((x0 + inset, 0, ridge)), Vector((x1 - inset, 0, ridge))
            slopes = [((x0, -hs, eave_z), (x1, -hs, eave_z), tuple(a), tuple(b)),
                      ((x1, hs, eave_z), (x0, hs, eave_z), tuple(b), tuple(a)),
                      ((x0, hs, eave_z), (x0, -hs, eave_z), tuple(a), tuple(a)),
                      ((x1, -hs, eave_z), (x1, hs, eave_z), tuple(b), tuple(b))]
            ridge_a, ridge_b = a, b
            self.hips = [(Vector((x0, -hs, eave_z)), a), (Vector((x0, hs, eave_z)), a), (Vector((x1, -hs, eave_z)), b), (Vector((x1, hs, eave_z)), b)]
        info = []
        for index, (eL, eR, rL, rR) in enumerate(slopes):
            front_slope = v.roof == "eave_front" and index == 0
            info.append(roof_slope(self.shell, self.detail, eL, eR, rL, rR, rng, sag=sag, layer_mix=layer_mix, missing=missing,
                                   antefix=v.antefixes and front_slope))
            self.roof_structure(Vector(eL), Vector(eR), Vector(rL), Vector(rR))
        ridge_line(self.shell, ridge_a, ridge_b, rng, height=0.07, sag=sag)
        for corner, end in getattr(self, "hips", []):
            ridge_line(self.shell, corner + Z * 0.02, end, rng, height=0.06, radius=0.12, sag=0.0)
        # Verge (barge) boards close the tile edge at both gables.
        for eL, eR, rL, rR in ([] if v.roof == "hip" else slopes):
            for e, r in ((Vector(eL), Vector(rL)), (Vector(eR), Vector(rR))):
                self.shell.beam(e + Z * 0.02, r + Z * 0.10, 0.04, 0.2, "oak_grey", 0.008, rng.random(), rng=rng)
        # Smoke vent hood over the hearth zone (Godot (1.62, 1.50)).
        hood = Vector((1.62, -1.5, 0))
        hood.z = self.roof_height_at(hood) + 0.06
        self.detail.chamfer_box(hood + Z * 0.08, (0.42, 0.34, 0.16), "tegula_old", None, 0.02, rng.random())
        self.detail.chamfer_box(hood + Z * 0.20, (0.50, 0.42, 0.04), "tegula_old", None, 0.01, rng.random())
        self.metadata.update({"ridge_height_m": round(ridge + 0.2, 3), "eave_height_m": round(eave_z, 3), "roof": v.roof,
                              "tile_rows": [i["rows"] for i in info], "tile_columns": [i["columns"] for i in info]})
        self.eave_z = eave_z

    def roof_height_at(self, p):
        v = self.v
        ridge = self.ridge_height()
        t = math.tan(math.radians(v.pitch_deg))
        if v.roof == "gable_front":
            return ridge - abs(p.x) * t + 0.05
        return ridge - abs(p.y) * t + 0.05

    def roof_structure(self, eL, eR, rL, rR):
        """Rafters showing under the eave and boards visible from inside."""
        rng = self.rng
        across = (eR - eL)
        width = across.length
        across.normalize()
        count = max(3, round(width / 0.58))
        for k in range(count + 1):
            t = k / count
            a = eL.lerp(eR, t) + Z * -0.10
            b = rL.lerp(rR, t) + Z * -0.10
            a = a + (a - b).normalized() * 0.08
            self.shell.beam(a, b, 0.11, 0.14, "oak_grey", 0.012, rng.random(), rng=rng)
        # Boarding on top of the rafters (underside seen from the room).
        up = ((rL + rR) / 2 - (eL + eR) / 2)
        length = up.length
        up.normalize()
        normal = across.cross(up).normalized()
        if normal.z < 0:
            normal = -normal
        boards = max(4, round(length / 0.24))
        for k in range(boards):
            t0 = k / boards
            t1 = (k + 1) / boards - 0.008 / length
            # Boards follow the slope outline (trapezoid or hip triangle).
            p0, p1 = eL.lerp(rL, t0) - normal * 0.02, eL.lerp(rL, t1) - normal * 0.02
            q0, q1 = eR.lerp(rR, t0) - normal * 0.02, eR.lerp(rR, t1) - normal * 0.02
            # Underside seen from the room, top 22 mm higher (no shared corners to weld).
            self.shell.face([p0, q0, q1, p1], "oak_grey", rng.random(), outward=-normal, uv_basis=(up, across))
            lift = normal * 0.022
            self.shell.face([p0 + lift, p1 + lift, q1 + lift, q0 + lift], "oak_grey", rng.random(), outward=normal, uv_basis=(up, across))
        # Fascia board along the eave.
        self.shell.beam(eL - across * 0.02 + Z * -0.04 - up * 0.03, eR + across * 0.02 + Z * -0.04 - up * 0.03, 0.035, 0.16, "oak_grey", 0.008, rng.random(), rng=rng)

    # entrance -------------------------------------------------------------
    def entrance(self):
        """Visible landing and ramp share the exact planes of the entry collider.

        regional_village.gd builds: landing box (1.25 x 0.06 x 0.90) centred at
        Godot (0, 0.415, 2.50) and a ramp from z = 2.95 (top 0.445) down to
        z = 4.0 (0) (porch houses: landing and ramp start further out).
        """
        v, rng = self.v, self.rng
        start = 2.95 + (0.55 if v.porch else 0.0)
        run, rise, width = 1.05, 0.445, 1.25
        top = 0.445
        if v.tier == 1:
            # Oak plank landing and cleated board ramp (as the collider).
            for k in range(5):
                x = -width / 2 + (k + 0.5) * width / 5
                self.shell.chamfer_box(Vector((x, -2.50, top - 0.03)), (width / 5 - 0.012, 0.90, 0.06), "oak_grey", None, 0.006, rng.random(), grain=1, rng=rng)
            pitch = math.atan2(rise, run)
            for k in range(5):
                x = -width / 2 + (k + 0.5) * width / 5
                a = Vector((x, -start, top - 0.03))
                b = Vector((x, -start - run, -0.03))
                self.shell.beam(a, b, width / 5 - 0.012, 0.06, "oak_grey", 0.006, rng.random(), rng=rng)
            for k in range(4):
                t = (k + 0.5) / 4
                p = Vector((0, -start - run * t, top * (1 - t) + 0.012))
                self.shell.chamfer_box(p, (width - 0.08, 0.04, 0.03), "oak_grey", Matrix.Rotation(-pitch, 3, 'X'), 0.006, rng.random(), grain=0, rng=rng)
        else:
            # Threshold slab (limen) and a dressed stone ramp with grip grooves.
            # With a porch the stylobate continues the threshold from the wall line.
            self.shell.chamfer_box(Vector((0, -2.50 if not v.porch else -2.275, top - 0.06)), (width + 0.05, 0.90 if not v.porch else 0.45, 0.12),
                                   "flagstone", None, 0.02, rng.random(), skip=("-z",))
            pitch = math.atan2(rise, run)
            length = math.hypot(run, rise)
            rot = Matrix.Rotation(pitch, 3, 'X')
            slabs = 3
            for k in range(slabs):
                t0, t1 = k / slabs, (k + 1) / slabs
                mid = (t0 + t1) / 2
                centre = Vector((0, -start - run * mid, top * (1 - mid) - 0.06))
                self.shell.chamfer_box(centre, (width, length / slabs - 0.01, 0.12), "flagstone", rot, 0.015, rng.random(), skip=("-z",))
                for g in range(2):
                    gt = t0 + (g + 0.5) * (t1 - t0) / 2
                    gp = Vector((0, -start - run * gt, top * (1 - gt) + 0.002))
                    self.detail.chamfer_box(gp, (width - 0.16, 0.025, 0.006), "mortar", rot, 0.002, rng.random())
            # Cheek walls of rubble either side of the ramp.
            for s in (-1, 1):
                for k in range(3):
                    t = (k + 0.5) / 3
                    h = top * (1 - t) + 0.05
                    p = Vector((s * (width / 2 + 0.12), -start - run * t, h / 2 - 0.02))
                    self.shell.chamfer_box(p, (0.22, run / 3 - 0.02, h + 0.02), "flagstone", None, 0.03, rng.random(), jitter=0.01, rng=rng)
                self.collider(Vector((s * (width / 2 + 0.12), -start - run * 0.5, 0.25)), (0.22, run, 0.5), 0, "RampCheek")
        self.metadata["entry"] = {"landing_top": top, "ramp_start_z": start, "ramp_run": run, "width": width}

    # canopy, porch, balcony ------------------------------------------------
    def canopy(self):
        """Pentice over the door: two oak struts, a beam and a small tile roof."""
        rng = self.rng
        depth, width, z = 1.05, 2.1, 2.92
        for s in (-1, 1):
            # Cantilevered joist let into the wall, braced by a short knee strut.
            self.shell.beam(Vector((s * 0.95, -HALF_Y + 0.12, z)), Vector((s * 0.95, -HALF_Y - depth - 0.05, z - 0.10)), 0.11, 0.13, "oak_grey", 0.012, rng.random(), rng=rng)
            self.shell.beam(Vector((s * 0.95, -HALF_Y - 0.03, z - 0.52)), Vector((s * 0.95, -HALF_Y - 0.55, z - 0.06)), 0.085, 0.085, "oak_grey", 0.01, rng.random(), rng=rng)
            self.detail.chamfer_box(Vector((s * 0.95, -HALF_Y - 0.02, z - 0.56)), (0.16, 0.04, 0.12), "oak_grey", None, 0.01, rng.random())
        self.shell.beam(Vector((-width / 2, -HALF_Y - depth, z - 0.10)), Vector((width / 2, -HALF_Y - depth, z - 0.10)), 0.12, 0.12, "oak_grey", 0.012, rng.random(), rng=rng)
        eL = Vector((-width / 2 - 0.1, -HALF_Y - depth - 0.18, z - 0.06))
        eR = Vector((width / 2 + 0.1, -HALF_Y - depth - 0.18, z - 0.06))
        rL = Vector((-width / 2 - 0.1, -HALF_Y - 0.02, z + 0.36))
        rR = Vector((width / 2 + 0.1, -HALF_Y - 0.02, z + 0.36))
        roof_slope(self.shell, self.detail, eL, eR, rL, rR, rng, sag=0.01, layer_mix=0.3)
        for k in range(6):
            t = k / 5
            a = eL.lerp(eR, t) + Z * -0.05
            b = rL.lerp(rR, t) + Z * -0.05
            self.shell.face([a + Vector((-0.04, 0, 0)), a + Vector((0.04, 0, 0)), b + Vector((0.04, 0, 0)), b + Vector((-0.04, 0, 0))], "oak_grey", rng.random(), outward=-Z)
        self.metadata["canopy"] = {"depth_m": depth, "width_m": width, "clear_height_m": round(z - 0.18, 2)}

    def porch(self):
        """Tuscan porch under the prolonged street slope: stylobate, two columns, beam."""
        rng = self.rng
        y_front = -HALF_Y - PORCH_DEPTH
        top = 0.445
        # Stylobate slabs (walkable; the collider top equals the slab top).
        for k in range(6):
            x0 = -2.4 + k * 0.8
            self.shell.chamfer_box(Vector((x0 + 0.4, (y_front - HALF_Y) / 2, top - 0.08)), (0.79, PORCH_DEPTH + 0.01, 0.16), "flagstone", None, 0.02, rng.random(), skip=("-z",))
        # Joint fill between the slabs, 6 mm below the walking surface.
        self.shell.face([Vector((-2.40, y_front + 0.01, top - 0.006)), Vector((2.40, y_front + 0.01, top - 0.006)), Vector((2.40, -HALF_Y, top - 0.006)), Vector((-2.40, -HALF_Y, top - 0.006))],
                        "mortar", outward=Z)
        self.shell.face([Vector((-2.42, y_front, -0.02)), Vector((2.42, y_front, -0.02)), Vector((2.42, y_front, top - 0.16)), Vector((-2.42, y_front, top - 0.16))], "rubble_socle", outward=Vector((0, -1, 0)))
        for s in (-1, 1):
            self.shell.face([Vector((s * 2.42, y_front, -0.02)), Vector((s * 2.42, -HALF_Y, -0.02)), Vector((s * 2.42, -HALF_Y, top - 0.16)), Vector((s * 2.42, y_front, top - 0.16))],
                            "rubble_socle", outward=Vector((s, 0, 0)))
        self.collider(Vector((0, (y_front - HALF_Y) / 2, top / 2)), (4.84, PORCH_DEPTH, top), 0, "PorchFloor")
        # Two dressed steps along the porch front either side of the ramp.
        for s in (-1, 1):
            x_in, x_out = 0.88, 2.42
            for k, (depth, height) in enumerate(((0.32, 0.30), (0.32, 0.15))):
                y0 = y_front - 0.32 * k
                y1 = y0 - depth
                x = 0.0
                cx = s * (x_in + x_out) / 2
                pieces = 2 + k
                width = (x_out - x_in) / pieces
                for j in range(pieces):
                    px = s * (x_in + width * (j + 0.5))
                    self.shell.chamfer_box(Vector((px, (y0 + y1) / 2, height / 2 - 0.02)), (width - 0.012, depth, height + 0.04), "flagstone", None, 0.02,
                                           rng.random(), skip=("-z",), jitter=0.004, rng=rng)
                self.collider(Vector((cx, (y0 + y1) / 2, height / 2)), (x_out - x_in, depth, height), 0, "PorchStep")
        y_col = y_front + 0.28
        t = math.tan(math.radians(self.v.pitch_deg))
        underside = self.v.plate - (-y_col - HALF_Y) * t - 0.10 - 0.07
        beam_h = 0.24
        height = underside - beam_h - top
        for s in (-1, 1):
            c = Vector((s * 1.75, y_col, top))
            column(self.shell, c, height, 0.145, rng, "plaster_lime", "flagstone")
            self.collider(Vector((s * 1.75, y_col, top + height / 2)), (0.40, 0.40, height), 0, "PorchColumn")
        self.shell.beam(Vector((-2.9, y_col, underside - beam_h / 2)), Vector((2.9, y_col, underside - beam_h / 2)), 0.20, beam_h, "oak_brown", 0.015, rng.random(), rng=rng)
        self.metadata["porch"] = {"columns": 2, "order": "Tuscan (Italic)", "depth_m": PORCH_DEPTH, "floor_top_m": top,
                                  "column_height_m": round(height, 3), "clear_height_m": round(underside - beam_h - top, 3)}

    def balcony(self):
        """Upper storey gallery (maenianum) on oak joists over the street door."""
        rng = self.rng
        z = 3.52
        depth = 0.95
        for k in range(7):
            x = -2.1 + k * 0.7
            self.shell.beam(Vector((x, -HALF_Y + 0.25, z - 0.08)), Vector((x, -HALF_Y - depth - 0.12, z - 0.08)), 0.12, 0.16, "oak_brown", 0.012, rng.random(), rng=rng)
        for k in range(14):
            x0 = -2.3 + k * (4.6 / 14)
            self.shell.chamfer_box(Vector((x0 + 4.6 / 28, -HALF_Y - depth / 2, z + 0.02)), (4.6 / 14 - 0.008, depth + 0.02, 0.05), "oak_grey", None, 0.006, rng.random(), grain=1, rng=rng)
        rail_z = z + 1.0
        for s in (-1, 1):
            self.shell.beam(Vector((s * 2.3, -HALF_Y - depth, z + 0.05)), Vector((s * 2.3, -HALF_Y - depth, rail_z + 0.05)), 0.10, 0.10, "oak_brown", 0.012, rng.random(), rng=rng)
            self.shell.beam(Vector((s * 2.3, -HALF_Y, rail_z)), Vector((s * 2.3, -HALF_Y - depth, rail_z)), 0.08, 0.10, "oak_brown", 0.01, rng.random(), rng=rng)
            # Struts down to the wall below the joists.
            bracket(self.shell, Vector((s * 2.1, -HALF_Y - 0.02, z - 0.16)), Vector((0, -1, 0)), depth - 0.05, 0.85, 0.12, "oak_brown", rng)
        self.shell.beam(Vector((-2.3, -HALF_Y - depth, rail_z)), Vector((2.3, -HALF_Y - depth, rail_z)), 0.08, 0.10, "oak_brown", 0.01, rng.random(), rng=rng)
        for k in range(17):
            x = -2.2 + k * (4.4 / 16)
            self.shell.beam(Vector((x, -HALF_Y - depth, z + 0.05)), Vector((x, -HALF_Y - depth, rail_z - 0.04)), 0.05, 0.05, "oak_brown", 0.008, rng.random(), rng=rng)
        self.metadata["balcony"] = {"depth_m": depth, "floor_z_m": z, "rail_height_m": 1.0}
        # Upper floor joists inside (the ground-floor ceiling) and a board floor.
        for k in range(9):
            x = -2.4 + k * 0.6
            self.shell.beam(Vector((x, -INNER_Y, 3.30)), Vector((x, INNER_Y, 3.30)), 0.13, 0.17, "oak_grey", 0.012, rng.random(), rng=rng)
        self.shell.face([Vector((-INNER_X, -INNER_Y, 3.40)), Vector((INNER_X, -INNER_Y, 3.40)), Vector((INNER_X, INNER_Y, 3.40)), Vector((-INNER_X, INNER_Y, 3.40))], "oak_grey", outward=-Z)

    # fixtures --------------------------------------------------------------
    def fixtures_build(self):
        rng = self.rng
        t = self.fixtures["table"]
        # Table NW (Godot x -1.825..-0.375, z -1.1525..-0.0675, top 0.85 above floor).
        x0, x1, y0, y1 = -1.825, -0.375, 0.0675, 1.1525
        for i in range(5):
            w = (y1 - y0) / 5
            t.chamfer_box(Vector(((x0 + x1) / 2, y0 + (i + 0.5) * w, FLOOR + 0.8175)), (x1 - x0, w - 0.01, 0.065), "oak_brown", None, 0.008, rng.random(), grain=0, rng=rng)
        for x in (x0 + 0.14, x1 - 0.14):
            for y in (y0 + 0.14, y1 - 0.14):
                t.chamfer_box(Vector((x, y, FLOOR + 0.39)), (0.09, 0.09, 0.78), "oak_brown", None, 0.012, rng.random(), grain=2, rng=rng)
        b = self.fixtures["bench"]
        b.chamfer_box(Vector((1.93, 0, FLOOR + 0.4575)), (0.5, 1.9, 0.085), "oak_grey", None, 0.012, rng.random(), grain=1, rng=rng)
        for y in (-0.72, 0.72):
            b.chamfer_box(Vector((1.93, y, FLOOR + 0.2075)), (0.34, 0.16, 0.415), "oak_grey", None, 0.012, rng.random(), grain=2, rng=rng)
        j = self.fixtures["jar"]
        prof = [(0.0, 0.0), (0.12, 0.0), (0.21, 0.08), (0.27, 0.27), (0.25, 0.45), (0.15, 0.56), (0.11, 0.58), (0.125, 0.62), (0.095, 0.62), (0.085, 0.57)]
        j.lathe(prof, Vector((-2.23, 1.47, FLOOR)), "tegula", 16, rng.random())

    def far_proxy(self):
        """Distant silhouette (> ~70 m): walls, roof planes, no openings detail."""
        v = self.v
        far = self.far
        plate = v.plate
        ridge = self.ridge_height()
        for name, origin, u_axis, length, top, openings, thick in self.wall_specs():
            u_axis = Vector(u_axis)
            out = u_axis.cross(Z).normalized()
            pts = [origin, origin + u_axis * length, origin + u_axis * length + Z * top(length), origin + u_axis * length * 0.5 + Z * top(length * 0.5), origin + Z * top(0)]
            layer = {"render": "plaster_aged", "daub": "daub", "stone": "opus_incertum"}[v.walls]
            far.face(pts, layer, outward=out)
        eave_z = self.eave_z
        if v.roof == "gable_front":
            hs, y0, y1 = HALF_X + 0.4, -HALF_Y - 0.34, HALF_Y + 0.34
            for s in (-1, 1):
                far.face([Vector((s * hs, y0, eave_z)), Vector((s * hs, y1, eave_z)), Vector((0, y1, ridge + 0.1)), Vector((0, y0, ridge + 0.1))], "tegula_old", outward=Vector((s, 0, 1)))
        elif v.roof == "hip":
            hs, x0, x1 = HALF_Y + 0.4, -HALF_X - 0.34, HALF_X + 0.34
            a, b = Vector((x0 + hs, 0, ridge + 0.1)), Vector((x1 - hs, 0, ridge + 0.1))
            for s in (-1, 1):
                far.face([Vector((x0, s * hs, eave_z)), Vector((x1, s * hs, eave_z)), b, a], "tegula_old", outward=Vector((0, s, 1)))
            far.face([Vector((x0, -hs, eave_z)), Vector((x0, hs, eave_z)), a], "tegula_old", outward=Vector((-1, 0, 1)))
            far.face([Vector((x1, hs, eave_z)), Vector((x1, -hs, eave_z)), b], "tegula_old", outward=Vector((1, 0, 1)))
        else:
            hs, x0, x1 = HALF_Y + 0.4, -HALF_X - 0.34, HALF_X + 0.34
            for s in (-1, 1):
                far.face([Vector((x0, s * hs, eave_z)), Vector((x1, s * hs, eave_z)), Vector((x1, 0, ridge + 0.1)), Vector((x0, 0, ridge + 0.1))], "tegula_old", outward=Vector((0, s, 1)))
        if v.porch:
            fs, fz = self.front_eave
            far.face([Vector((-HALF_X - 0.34, -fs, fz)), Vector((HALF_X + 0.34, -fs, fz)), Vector((HALF_X + 0.34, -HALF_Y - 0.4, eave_z)), Vector((-HALF_X - 0.34, -HALF_Y - 0.4, eave_z))], "tegula_old", outward=Vector((0, -1, 1)))

    def wall_colliders(self):
        """Walls (same planes as the visible faces), socle skirt and roof-independent room."""
        sh = self.socle_height
        # Godot-space boxes are recorded through the Blender->Godot conversion in collider().
        self.collider(Vector((-HALF_X + 0.16, 0, 1.7)), (0.32, 2 * HALF_Y, 3.4), 0, "WallWest")
        self.collider(Vector((HALF_X - 0.16, 0, 1.7)), (0.32, 2 * HALF_Y, 3.4), 0, "WallEast")
        self.collider(Vector((0, HALF_Y - 0.165, 1.7)), (2 * HALF_X, 0.33, 3.4), 0, "WallRear")
        for s in (-1, 1):
            w = HALF_X - 0.69
            self.collider(Vector((s * (0.69 + w / 2), -HALF_Y + 0.165, 1.7)), (w, 0.33, 3.4), 0, "WallFront")
        self.collider(Vector((0, -HALF_Y + 0.165, 2.98)), (1.38, 0.33, 0.84), 0, "DoorHead")
        # The socle stones stand 3-5 cm proud of the wall line: skirt colliders.
        for s in (-1, 1):
            self.collider(Vector((s * (HALF_X + 0.0225), 0, sh / 2)), (0.045, 2 * HALF_Y + 0.09, sh), 0, "SocleSkirt")
            self.collider(Vector((0, s * (HALF_Y + 0.0225), sh / 2)) if s > 0 else Vector((-(HALF_X + 0.69) / 2 - 0.0, -(HALF_Y + 0.0225), sh / 2)),
                          ((2 * HALF_X + 0.09) if s > 0 else (HALF_X - 0.69), 0.045, sh), 0, "SocleSkirt")
        self.collider(Vector(((HALF_X + 0.69) / 2, -(HALF_Y + 0.0225), sh / 2)), (HALF_X - 0.69, 0.045, sh), 0, "SocleSkirt")
        if self.v.upper:
            self.collider(Vector((0, -HALF_Y - 0.5, 3.52)), (4.7, 1.05, 0.12), 0, "BalconyFloor")
