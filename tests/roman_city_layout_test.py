"""Blender-free layout regression for the actual Roman city generator.

Executes the production geometry, ``install``/``put`` and ``build_city`` code of
tools/world/build_roman_test_city.py; only Blender's object/mesh datablocks and
mathutils are replaced by in-memory records (see meshy_gait_reach_test.py for
the same approach). The measurements below are written independently of the
generator's own placement checker: they inspect the recorded world geometry.
Godot import, rendering and runtime collision stay covered by the Godot tests.
"""
from __future__ import annotations

from collections import defaultdict
import importlib.util
import math
from pathlib import Path
import sys
import types
import unittest

GENERATOR = Path(__file__).resolve().parents[1] / "tools/world/build_roman_test_city.py"
CITY_BOUNDS = (-410.0, -320.0, 410.0, 320.0)       # wall centre lines (manifest city_bounds_blender_m)
WALL_HALF_THICKNESS = 1.25
MAIN_STREETS = {"east_west": (-417.5, -72.725, 417.5, -57.275),   # paving plus both kerbs
                "north_south": (-106.5, -327.5, -93.5, 327.5)}
BUILDINGS = {"residential", "craft_shop", "civic", "baths", "portico", "fountain", "city_wall", "gate", "aqueduct"}
PROPS = {"street_detail", "vegetation", "market_stall"}
NOT_ON_STREET_CHECK = {"road", "ground", "public_space", "detail", "city_wall", "gate"}
ANCHOR_INDICES = range(28, 35)
SURFACE_GROUPS = ("City_Ground", "Main_Streets", "Residential_Roads")
PLAYER_STEP = 0.25  # CityExploration.MAX_STEP
TOLERANCE = 0.05   # a prop may touch a solid; 5 cm inside counts as penetration


class Vector(list):
    """Mutable stand-in for mathutils.Vector (normalize() works in place)."""

    def __init__(self, values):
        super().__init__(float(v) for v in values)

    def __add__(self, other):
        return Vector(a + b for a, b in zip(self, other))

    def __sub__(self, other):
        return Vector(a - b for a, b in zip(self, other))

    def __mul__(self, factor):
        return Vector(a * factor for a in self)

    __rmul__ = __mul__

    def cross(self, o):
        return Vector((self[1] * o[2] - self[2] * o[1], self[2] * o[0] - self[0] * o[2],
                       self[0] * o[1] - self[1] * o[0]))

    @property
    def length(self):
        return math.sqrt(sum(a * a for a in self))

    def normalized(self):
        length = self.length
        return Vector(a / length for a in self) if length else Vector(self)

    def normalize(self):
        length = self.length
        if length:
            self[:] = [a / length for a in self]


class FakeObject(dict):
    def __init__(self, name, data):
        super().__init__()
        self.name, self.data, self.parent = name, data, None
        self.location, self.rotation_euler, self.scale = (0.0, 0.0, 0.0), [0.0, 0.0, 0.0], (1.0, 1.0, 1.0)


def load_generator(path=GENERATOR):
    """Import the generator with Blender replaced by in-memory records."""
    saved = {name: sys.modules.get(name) for name in ("bpy", "mathutils", "viva_roma_surfaces", "numpy")}
    sys.modules["bpy"] = types.SimpleNamespace(data=types.SimpleNamespace(objects=types.SimpleNamespace(new=FakeObject)))
    sys.modules["mathutils"] = types.SimpleNamespace(Vector=Vector)
    sys.modules["viva_roma_surfaces"] = types.SimpleNamespace(build_blender_material=lambda name, *a: name)
    try:
        import numpy  # noqa: F401  (real NumPy whenever it is installed)
    except ImportError:
        # The geometry path only calls numpy.linspace; texture code is stubbed.
        sys.modules["numpy"] = types.SimpleNamespace(
            linspace=lambda a, b, n: [a + (b - a) * i / (n - 1) for i in range(n)])
    try:
        spec = importlib.util.spec_from_file_location("roman_city_generator_under_test", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    finally:
        for name, value in saved.items():
            if value is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = value
    boxes, cylinders = defaultdict(list), defaultdict(list)
    original_box, original_cylinder = module.Mesh.box, module.Mesh.cylinder

    def box(self, center, size, mat, angle=0):
        boxes[id(self)].append((tuple(center), tuple(size), angle, self.physical))
        original_box(self, center, size, mat, angle)

    def cylinder(self, center, radius, depth, mat, sides=12, r_top=None):
        cylinders[id(self)].append((tuple(center), radius, depth, self.physical))
        original_cylinder(self, center, radius, depth, mat, sides, r_top)

    module.Mesh.box, module.Mesh.cylinder = box, cylinder
    module.Mesh.finish = lambda self: (self, self if self.cf else None)
    module.CITY = types.SimpleNamespace(objects=_Links())
    module.COLLISION = types.SimpleNamespace(objects=_Links())
    return module, boxes, cylinders


class _Links(list):
    def link(self, item):
        self.append(item)


def build(path=GENERATOR):
    module, boxes, cylinders = load_generator(path)
    module.create_materials(Path("unused-texture-output"))
    module.build_city()
    return module, boxes, cylinders


def transform(obj, point):
    """Blender object transform (Z rotation, uniform scale) of a local point."""
    angle, scale = obj.rotation_euler[2], obj.scale[0]
    c, s = math.cos(angle), math.sin(angle)
    x, y, z = point[0] * scale, point[1] * scale, point[2] * scale
    ox, oy, oz = obj.location
    return (ox + x * c - y * s, oy + x * s + y * c, oz + z)


def world_vertices(obj):
    return [transform(obj, v) for v in obj.data.v]


def local_aabb(mesh):
    return tuple(tuple(f(p[i] for p in mesh.v) for i in range(3)) for f in (min, max))


def inside_obb(obj, bounds, point, shrink):
    """Point inside the object's local box (bounds) after the object transform."""
    angle, scale = obj.rotation_euler[2], obj.scale[0]
    c, s = math.cos(-angle), math.sin(-angle)
    dx, dy = point[0] - obj.location[0], point[1] - obj.location[1]
    lx, ly, lz = (dx * c - dy * s) / scale, (dx * s + dy * c) / scale, (point[2] - obj.location[2]) / scale
    (x0, y0, z0), (x1, y1, z1) = bounds
    m = shrink / scale
    return x0 + m < lx < x1 - m and y0 + m < ly < y1 - m and z0 + m < lz < z1 - m


def inside_box(obj, record, point, shrink):
    (cx, cy, cz), (sx, sy, sz), box_angle, _physical = record
    bounds = ((-sx / 2, -sy / 2, -sz / 2), (sx / 2, sy / 2, sz / 2))
    centre = transform(obj, (cx, cy, cz))
    proxy = FakeObject("box", None)
    proxy.location, proxy.rotation_euler, proxy.scale = centre, [0, 0, obj.rotation_euler[2] + box_angle], obj.scale
    return inside_obb(proxy, bounds, point, shrink)


class CityLayout:
    """World-space measurements of one generator run."""

    def __init__(self, path=GENERATOR):
        self.module, self.boxes, self.cylinders = build(path)
        self.objects = [o for o in self.module.CITY.objects if o.data is not None]
        self.groups = {o.name: o for o in self.module.CITY.objects if o.data is None}
        self.colliders = list(self.module.COLLISION.objects)
        self.by_name = {o.name: o for o in self.objects}

    def category(self, category):
        return [o for o in self.objects if o.get("category") == category]

    # D3: closed city wall ------------------------------------------------
    def wall_coverage(self):
        """Per side: open metres along the wall line, excluding only the gate arch."""
        x0, y0, x1, y1 = CITY_BOUNDS
        sides = {"north": (x0, x1, lambda p: p[0]), "south": (x0, x1, lambda p: p[0]),
                 "west": (y0, y1, lambda p: p[1]), "east": (y0, y1, lambda p: p[1])}
        report = {}
        for side, (start, end, along) in sides.items():
            blocked = []
            for wall in [o for o in self.category("city_wall") if o.name.split("_")[1] == side]:
                blocked += self._blocking(wall, along)
            gate = self.by_name["Porta_" + side]
            gate_parts = self._blocking(gate, along)
            centre = along(gate.location)
            arch = (max(b for a, b in gate_parts if b <= centre), min(a for a, b in gate_parts if a >= centre))
            walls_in_arch = sum(max(0.0, min(b, arch[1]) - max(a, arch[0])) for a, b in blocked)
            blocked += gate_parts + [arch]
            line = (start + WALL_HALF_THICKNESS, end - WALL_HALF_THICKNESS)
            report[side] = {"open_m": self._uncovered(line, blocked),
                            "beside_gate_m": self._uncovered((arch[0] - 40, arch[1] + 40), blocked),
                            "arch_width_m": arch[1] - arch[0], "walls_in_arch_m": walls_in_arch}
        return report

    def _blocking(self, obj, along):
        """Along-wall intervals where a physical solid closes the full wall
        thickness at 1 m (body) height."""
        result = []
        for (cx, cy, cz), (sx, sy, sz), angle, physical in self.boxes[id(obj.data)]:
            if physical and abs(angle) < 1e-9 and cz - sz / 2 <= 1.0 <= cz + sz / 2 and sy / 2 >= WALL_HALF_THICKNESS - 1e-9 \
                    and abs(cy) + WALL_HALF_THICKNESS <= sy / 2 + 1e-9:
                a, b = along(transform(obj, (cx - sx / 2, cy, 0))), along(transform(obj, (cx + sx / 2, cy, 0)))
                result.append((min(a, b), max(a, b)))
        for (cx, cy, cz), radius, depth, physical in self.cylinders[id(obj.data)]:
            if physical and cz - depth / 2 <= 1.0 <= cz + depth / 2 and radius > WALL_HALF_THICKNESS + abs(cy):
                half = math.sqrt(radius ** 2 - (WALL_HALF_THICKNESS + abs(cy)) ** 2)
                a, b = along(transform(obj, (cx - half, cy, 0))), along(transform(obj, (cx + half, cy, 0)))
                result.append((min(a, b), max(a, b)))
        return result

    @staticmethod
    def _uncovered(line, intervals):
        position, open_length = line[0], 0.0
        for a, b in sorted(intervals):
            if b <= position:
                continue
            if a > position + 1e-6:
                open_length += min(a, line[1]) - position
            position = max(position, b)
            if position >= line[1]:
                break
        return open_length + max(0.0, line[1] - position)

    # D4: props and trees against buildings and main streets ----------------
    def prop_intersections(self):
        buildings = [o for o in self.objects if o.get("category") in BUILDINGS]
        bounds = {id(o): local_aabb(o.data) for o in buildings}
        index = defaultdict(list)
        for building in buildings:
            for cell in self._cells(world_vertices(building)):
                index[cell].append(building)
        penetrating, inside_bounds = defaultdict(set), defaultdict(set)
        for prop in [o for o in self.objects if o.get("category") in PROPS]:
            points = sorted({tuple(round(c, 6) for c in p) for p in world_vertices(prop)})
            candidates = {id(b): b for cell in self._cells(points) for b in index[cell]}
            for building in candidates.values():
                # Every box lies inside the building's bounds: test only the
                # vertices that are inside those bounds against its boxes.
                near = [p for p in points if inside_obb(building, bounds[id(building)], p, 0.0)]
                if not near:
                    continue
                if any(inside_obb(building, bounds[id(building)], p, TOLERANCE) for p in near):
                    inside_bounds[prop["category"]].add((prop.name, building.name))
                walls = [r for r in self.boxes[id(building.data)] if r[0][2] + r[1][2] / 2 >= 0.5]
                if any(inside_box(building, r, p, TOLERANCE) for r in walls for p in near):
                    penetrating[prop["category"]].add((prop.name, building.name))
            # The amphitheatre is elliptical: its AABB would be meaningless.
            for p in points:
                if p[2] < 54 and ((p[0] - 181) / 97.5) ** 2 + ((p[1] - 42) / 81.5) ** 2 < 1:
                    inside_bounds[prop["category"]].add((prop.name, "Colosseum"))
                    break
        return penetrating, inside_bounds

    @staticmethod
    def _cells(points, size=20.0):
        xs, ys = [p[0] for p in points], [p[1] for p in points]
        return {(i, j) for i in range(math.floor(min(xs) / size), math.floor(max(xs) / size) + 1)
                for j in range(math.floor(min(ys) / size), math.floor(max(ys) / size) + 1)}

    def on_main_streets(self):
        found = set()
        for obj in self.objects:
            if obj.get("category") in NOT_ON_STREET_CHECK:
                continue
            for p in world_vertices(obj):
                if p[2] < 2.5 and any(x0 + TOLERANCE < p[0] < x1 - TOLERANCE and y0 + TOLERANCE < p[1] < y1 - TOLERANCE
                                      for x0, y0, x1, y1 in MAIN_STREETS.values()):
                    found.add(obj.name)
                    break
        return sorted(found)

    def house_fronts(self):
        """Blender point 1 m in front of every house front (local -Y side)."""
        fronts = []
        for house in self.category("residential"):
            (x0, y0, _), (x1, _, _) = local_aabb(house.data)
            fronts.append((house.name, transform(house, ((x0 + x1) / 2, y0 - 1.0, 0))))
        return fronts


class RomanCityLayoutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.city = CityLayout()

    def test_object_inventory_is_preserved(self):
        counts = defaultdict(int)
        for obj in self.city.objects:
            counts[obj.get("category")] += 1
        self.assertEqual(counts["residential"], 240)
        self.assertEqual(counts["market_stall"], 63)
        self.assertEqual(counts["street_detail"], 120)
        self.assertEqual(counts["vegetation"], 86)
        self.assertEqual(counts["gate"], 4)
        self.assertEqual(counts["craft_shop"], 3)
        self.assertEqual(counts["portico"], 2)
        self.assertEqual(counts["fountain"], 2)

    def test_city_wall_is_closed_up_to_every_gate(self):
        for side, row in self.city.wall_coverage().items():
            with self.subTest(side=side):
                self.assertLess(row["open_m"], 0.001, row)
                self.assertLess(row["beside_gate_m"], 0.001, row)
                self.assertEqual(row["walls_in_arch_m"], 0.0, row)
                self.assertGreater(row["arch_width_m"], 10.0, row)

    def test_no_prop_or_tree_intersects_a_building(self):
        penetrating, inside_bounds = self.city.prop_intersections()
        self.assertEqual({k: sorted(v) for k, v in penetrating.items() if v}, {})
        self.assertEqual({k: sorted(v) for k, v in inside_bounds.items() if v}, {})

    def test_nothing_stands_on_the_main_streets(self):
        self.assertEqual(self.city.on_main_streets(), [])

    def test_market_anchor_stalls_keep_their_authored_sites(self):
        stalls = {int(o.name.split("_")[1]) - 1: o for o in self.city.category("market_stall")}
        self.assertEqual(sorted(stalls), list(range(63)))
        moved = []
        for index, stall in stalls.items():
            expected = (-385 + index * 770 / 62, -47.0)
            if (stall.location[0], stall.location[1]) != expected:
                moved.append(index)
        self.assertTrue(set(ANCHOR_INDICES).isdisjoint(moved), moved)
        # Only a stand whose authored site lies on a main street may move.
        self.assertEqual(moved, [23])
        self.assertEqual(stalls[23].location[1], -47.0)

    def test_surface_tiles_partition_ground_and_streets(self):
        for group_name in SURFACE_GROUPS:
            with self.subTest(group=group_name):
                group = self.city.groups.get(group_name)
                self.assertIsNotNone(group, "group node keeps the runtime lookup name")
                self.assertEqual(tuple(group.location), (0.0, 0.0, 0.0))
                tiles = [o for o in self.city.objects if o.parent is group]
                self.assertGreater(len(tiles), 1)
                self.assertFalse(any(o.name == group_name for o in self.city.objects))
                colliders = [c for c in self.city.colliders if c.name == group_name + "_collision"]
                self.assertEqual(len(colliders), 1, "one unchanged collider per surface")
                self.assertFalse(any(c.name.startswith(group_name + "_Tile") for c in self.city.colliders))
                # The tiles' walkable boxes partition the collider exactly:
                # per height signature (centre z, thickness) the areas match.
                def areas(records):
                    out = defaultdict(float)
                    for (_x, _y, cz), (sx, sy, sz), _a, _p in records:
                        out[round(cz, 6), round(sz, 6)] += sx * sy
                    return out
                if group_name == "Main_Streets":
                    # The street is now an exterior shell, not a collection
                    # of independent boxes. Compare ALL actual upward faces
                    # by support plane and projected area, including slopes.
                    # This catches a missing or extra floor even if the
                    # overall footprint and volume happen to match.
                    def add_support_planes(out, obj, physical):
                        vertices = obj.data.cv if physical else obj.data.v
                        indices = obj.data.cf if physical else obj.data.f
                        for face in indices:
                            points = [Vector(transform(obj, vertices[i])) for i in face]
                            for i in range(1,len(points)-1):
                                normal = (points[i]-points[0]).cross(points[i+1]-points[0])
                                if normal[2] <= 1e-12:
                                    continue
                                plane = (round(normal[0]/normal[2],6),
                                         round(normal[1]/normal[2],6),
                                         round(sum(normal[k]*points[0][k] for k in range(3))/normal[2],6))
                                out[plane] += normal[2]*.5
                    solid, visual = defaultdict(float), defaultdict(float)
                    add_support_planes(solid,colliders[0],True)
                    for tile in tiles:
                        add_support_planes(visual,tile,False)
                else:
                    solid = areas([r for r in self.city.boxes[id(colliders[0].data)] if r[3]])
                    visual = defaultdict(float)
                    for tile in tiles:
                        for key, value in areas(self.city.boxes[id(tile.data)]).items():
                            visual[key] += value
                if group_name == "Main_Streets":
                    self.assertEqual(set(solid),set(visual),"visual/collision support plane signatures")
                # Residential plots intentionally include visual-only garden
                # covers; their pre-existing physical support contract stays.
                for key, value in solid.items():
                    self.assertAlmostEqual(visual[key], value, delta=1e-6 * value, msg=key)
                for tile in tiles:
                    (x0, y0, _), (x1, y1, _) = local_aabb(tile.data)
                    self.assertLessEqual(math.hypot(x1 - x0, y1 - y0) / 2, 145.0, tile.name)

    def test_every_house_front_and_gate_has_a_nearby_ground_tile(self):
        probes = self.city.house_fronts() + [(o.name, o.location) for o in self.city.category("gate")]
        self.assertEqual(len(probes), 244)
        tiles = [o for o in self.city.objects if o.parent is self.city.groups["City_Ground"]]
        for name, point in probes:
            found = []
            for tile in tiles:
                (x0, y0, _), (x1, y1, _) = local_aabb(tile.data)
                ox, oy, _ = tile.location
                if ox + x0 <= point[0] <= ox + x1 and oy + y0 <= point[1] <= oy + y1:
                    found.append(math.hypot(point[0] - ox - (x0 + x1) / 2, point[1] - oy - (y0 + y1) / 2))
            with self.subTest(probe=name):
                self.assertTrue(found)
                self.assertLessEqual(min(found), 145.0)

    def test_portico_steps_stay_below_the_player_step_limit(self):
        portico = self.city.by_name["Forum_Portico_West"]
        solids = [r for r in self.city.boxes[id(portico.data)] if r[3]]

        def height(lx, ly, base):
            top = base
            for (cx, cy, cz), (sx, sy, sz), _a, _p in solids:
                if abs(lx - cx) <= sx / 2 and abs(ly - cy) <= sy / 2 and cz - sz / 2 <= 0.05:
                    top = max(top, cz + sz / 2)
            return top

        for base in (0.0, 0.09):            # street and forum piazza levels
            for axis in ("width", "length"):
                with self.subTest(base=base, axis=axis):
                    profile = [height(0, -5 + i * .01, base) if axis == "width" else height(-37 + i * .01, 0, base)
                               for i in range(501)]
                    self.assertAlmostEqual(profile[-1], 0.36, places=6)
                    rises = [b - a for a, b in zip(profile, profile[1:])]
                    self.assertLessEqual(max(rises), 0.18 + 1e-9)
                    self.assertGreaterEqual(min(rises), -1e-9)

    def test_every_prop_stall_and_tree_has_a_collider_in_body_height(self):
        """Nobody walks through a market counter, a crate, a planter or a trunk."""
        colliders = {c.name: c for c in self.city.colliders}
        for category, expected in (("market_stall", 63), ("street_detail", 120), ("vegetation", 86)):
            objects = self.city.category(category)
            self.assertEqual(len(objects), expected)
            for obj in objects:
                with self.subTest(name=obj.name):
                    collider = colliders.get(obj.name + "_collision")
                    self.assertIsNotNone(collider, "no collider")
                    self.assertEqual(tuple(collider.location), tuple(obj.location))
                    self.assertEqual(tuple(collider.scale), tuple(obj.scale))
                    self.assertEqual(collider.rotation_euler[2], obj.rotation_euler[2])
                    heights = [v[2] * obj.scale[0] for v in collider.data.cv]
                    self.assertLessEqual(min(heights), PLAYER_STEP, "collider starts above the step limit")
                    self.assertGreaterEqual(max(heights), 0.8, "collider is lower than a body can step over")
                    # The collider never reaches outside what is drawn.
                    (x0, y0, z0), (x1, y1, z1) = local_aabb(obj.data)
                    for x, y, z in collider.data.cv:
                        self.assertTrue(x0 - 1e-6 <= x <= x1 + 1e-6 and y0 - 1e-6 <= y <= y1 + 1e-6
                                        and z0 - 1e-6 <= z <= z1 + 1e-6, (x, y, z))

    def test_main_street_kerbs_are_solid_low_and_open_at_the_crossing(self):
        collider = next(c for c in self.city.colliders if c.name == "Main_Streets_collision")
        tiles = [o for o in self.city.objects if o.parent is self.city.groups["Main_Streets"]]

        def faces(obj, physical):
            vertices, indices = (obj.data.cv, obj.data.cf) if physical else (obj.data.v, obj.data.f)
            return [[transform(obj, vertices[i]) for i in face] for face in indices]

        solid = faces(collider, True)
        visual = [f for tile in tiles for f in faces(tile, False)]

        def upward(rows):
            result = []
            for face in rows:
                a, b, c = (Vector(p) for p in face[:3])
                normal = (b-a).cross(c-a)
                if normal[2] <= 1e-12:
                    continue
                bounds = tuple(tuple(fn(p[k] for p in face) for k in range(2)) for fn in (min, max))
                result.append((a, normal, bounds))
            return result

        def height(rows, x, y):
            heights = []
            for a, n, ((x0, y0), (x1, y1)) in rows:
                # The tested street boxes and kerb strips are rectangular
                # in XY; all their top polygons have constant X/Y bounds.
                if x0-1e-8 <= x <= x1+1e-8 and y0-1e-8 <= y <= y1+1e-8:
                    heights.append(a[2]-(n[0]*(x-a[0])+n[1]*(y-a[1]))/n[2])
            return max(heights, default=0.0)

        def volume(rows):
            return sum(sum(Vector(face[0])[k]*Vector(face[i]).cross(Vector(face[i+1]))[k]
                           for k in range(3))/6.0
                       for face in rows for i in range(1,len(face)-1))

        physical_top = upward(solid)
        visual_top = upward(visual)
        crowns = defaultdict(list)
        for face in solid:
            if all(abs(p[2]-.16)<1e-9 for p in face) and max(p[1] for p in face)-min(p[1] for p in face)>.24:
                x0,x1=min(p[0] for p in face),max(p[0] for p in face)
                self.assertGreater(x1-x0,0.0)
                self.assertLessEqual(x1-x0,2.0+1e-8,"oversized kerb collision facet")
                centre=round(sum(p[1] for p in face)/len(face),6)
                crowns[centre].append((x0,x1))
            # The vertical road/kerb interfaces must not exist inside the
            # joined solid. Check actual recorded collision faces, not a flag.
            for boundary in (-72.0,-58.0):
                if all(abs(p[1]-boundary)<1e-9 for p in face):
                    x0,x1=min(p[0] for p in face),max(p[0] for p in face)
                    if max(p[2] for p in face)-min(p[2] for p in face)>1e-8:
                        for a,b in ((-407.5,-106.5),(-93.5,407.5)):
                            self.assertLessEqual(min(x1,b)-max(x0,a),1e-8,
                                                 "buried road/kerb interface exported")
        self.assertEqual(set(crowns),{-72.4,-57.6})
        for centre,intervals in crowns.items():
            merged=[]
            for a,b in sorted(intervals):
                if merged and abs(a-merged[-1][1])<1e-8:
                    merged[-1]=(merged[-1][0],b)
                else:
                    merged.append((a,b))
            self.assertEqual(merged,[(-407.5,-106.5),(-93.5,407.5)],centre)
        self.assertLessEqual(.16,PLAYER_STEP-.02)
        self.assertGreater(.16,.11)
        # Actual rendered and collision triangles preserve exactly the same
        # closed volume, rather than only comparing the former box records.
        solid_volume=volume(solid)
        self.assertGreater(solid_volume,0.0)
        self.assertAlmostEqual(volume(visual),solid_volume,delta=1e-6*solid_volume)
        for x in (-380,-272.01,-271.99,-250,-136.01,-135.99,-130,-60,-.01,.01,136.01,150,300,390):
            for centre in (-72.4,-57.6):
                with self.subTest(x=x,kerb=centre):
                    ys=[centre-.8+i*.01 for i in range(161)]
                    heights=[height(physical_top,x,y) for y in ys]
                    self.assertAlmostEqual(max(heights),.16,places=7)
                    for y,h in zip(ys,heights):
                        self.assertAlmostEqual(height(visual_top,x,y),h,places=7)
                    # No 7.5 cm notch between the street and curb and no
                    # facet steeper than the real controller's 46 degree floor.
                    self.assertLessEqual(max(abs(b-a) for a,b in zip(heights,heights[1:])),
                                         .01*math.tan(math.radians(46))+1e-8)
                    inner=-72.0 if centre<-65 else -58.0
                    self.assertAlmostEqual(height(physical_top,x,inner),.11,places=7)
                    outer=centre-.325 if centre<-65 else centre+.325
                    self.assertAlmostEqual(height(physical_top,x,outer),0.0,places=7)
        for i in range(129):
            x=-106.4+i*.1
            for y in (-72.4,-57.6):
                self.assertLessEqual(height(physical_top,x,y),.11+1e-9,
                                     "kerb crosses the north-south street")


if __name__ == "__main__":
    unittest.main()
