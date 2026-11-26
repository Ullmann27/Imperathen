"""Garments, hair and beards fitted to the actual posed-at-rest body (Blender).

Body-derived garments copy the skin weights of the body surface they cover, so
they move exactly with it; separately lofted parts (tunic skirts, capes, leg
wraps) get blended weights and are checked for clipping by measure.py.
"""
from __future__ import annotations

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

from figure import hero, vertex_weights

TAU = math.tau


class BodyIndex:
    """Rest positions, normals and weights of the fitted body for queries."""

    def __init__(self, body):
        body.data.update()
        self.body = body
        self.points = [v.co.copy() for v in body.data.vertices]
        self.normals = [v.normal.copy() for v in body.data.vertices]
        self.weights = vertex_weights(body)
        self.tree = KDTree(len(self.points))
        for i, p in enumerate(self.points):
            self.tree.insert(p, i)
        self.tree.balance()

    def dominant(self, i):
        row = self.weights[i]
        return max(row, key=row.get) if row else "Spine"

    def nearest_weights(self, p, k=4, limit=None):
        merged = {}
        near = self.tree.find_n(p, k)
        total = 0.0
        for _, i, d in near:
            w = 1.0 / max(d, .002) ** 2
            total += w
            for bone, amount in self.weights[i].items():
                if limit and bone not in limit:
                    continue
                merged[bone] = merged.get(bone, 0.0) + amount * w
        if not merged:
            return {"Spine": 1.0}
        s = sum(merged.values())
        return {b: v / s for b, v in merged.items()}


def _normalize(row, keep=4):
    pairs = sorted(row.items(), key=lambda kv: kv[1], reverse=True)[:keep]
    total = sum(w for _, w in pairs)
    return {b: w / total for b, w in pairs if w > 0} if total > 0 else {"Spine": 1.0}


def bind(obj, arm, rows):
    obj.vertex_groups.clear()
    for i, row in enumerate(rows):
        for name, weight in _normalize(row).items():
            group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            group.add([i], float(weight), "REPLACE")
    obj.parent = arm
    obj.matrix_parent_inverse = Matrix.Identity(4)
    modifier = obj.modifiers.new("Germanic skin", "ARMATURE")
    modifier.object = arm


def _cylinder_uv(p, origin, axis, ref, tile, periods):
    d = p - origin
    along = d.dot(axis)
    radial = d - axis * along
    x = radial.dot(ref)
    y = radial.dot(axis.cross(ref))
    angle = math.atan2(y, x) / TAU
    return angle * periods, along / tile


def set_uvs(obj, mapper):
    """mapper(point, vertex index) -> (u, v, period); faces crossing a wrap get unwrapped."""
    mesh = obj.data
    layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    cache = {}
    for v in mesh.vertices:
        cache[v.index] = mapper(v.co, v.index)
    for poly in mesh.polygons:
        coords = [cache[mesh.loops[li].vertex_index] for li in poly.loop_indices]
        period = coords[0][2]
        us = [c[0] for c in coords]
        if period and max(us) - min(us) > period * .5:
            us = [u + period if u < period * .5 else u for u in us]
        for li, u, c in zip(poly.loop_indices, us, coords):
            layer.data[li].uv = (u, c[1])


def region_garment(name, index, arm, select, offset, material, cuts=(), uv=None, keep_keys=False,
                   smooth_passes=0, fade=0.0):
    """Copy selected body faces, cut them by planes and lift them off the skin.

    select(i, p, bone) -> bool for body vertices; a face is copied when all its
    vertices are selected. cuts: (point, normal) planes; geometry on the
    normal side is removed. offset(p, n, bone) -> metres along the body normal.
    Returns the object and the set of body vertex indices it covers.
    """
    body = index.body
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = obj.data.name = name
    bpy.context.collection.objects.link(obj)
    if not keep_keys and obj.data.shape_keys:
        obj.shape_key_clear()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    chosen = [select(i, p, index.dominant(i)) for i, p in enumerate(index.points)]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if not all(chosen[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    for cut in cuts:
        point, normal = cut[0], cut[1]
        side = cut[2] if len(cut) > 2 else None
        if side is None:
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        else:
            # A sleeve cut must not slice the trunk: only faces on that arm.
            suffix = "_L" if side > 0 else "_R"

            def on_arm(v):
                bone = index.dominant(index.tree.find(v.co)[1])
                return bone in ("Arm" + suffix, "Forearm" + suffix, "Hand" + suffix)
            arm_verts = {v for v in bm.verts if on_arm(v)}
            faces = [f for f in bm.faces if all(v in arm_verts for v in f.verts)]
            edges = {e for f in faces for e in f.edges}
            verts = {v for f in faces for v in f.verts}
            geom = list(verts) + list(edges) + faces
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=point, plane_no=normal,
                               clear_outer=True, clear_inner=False)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    if smooth_passes:
        boundary = {v for e in bm.edges if e.is_boundary for v in e.verts}
        inner = [v for v in bm.verts if v not in boundary]
        for _ in range(smooth_passes):
            bmesh.ops.smooth_vert(bm, verts=inner, factor=.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    shape_layers = list(bm.verts.layers.shape.values()) if keep_keys else []
    edge_tree = None
    if fade:
        rim = [v.co.copy() for e in bm.edges if e.is_boundary for v in e.verts]
        if rim:
            edge_tree = KDTree(len(rim))
            for k, co in enumerate(rim):
                edge_tree.insert(co, k)
            edge_tree.balance()
    for v in bm.verts:
        _, i, _ = index.tree.find(v.co)
        n = index.normals[i]
        bone = index.dominant(i)
        d = offset(v.co, n, bone)
        if edge_tree is not None:
            _, _, distance = edge_tree.find(v.co)
            t = max(0.0, min(1.0, distance / fade))
            d = max(.0006, d * t * t * (3 - 2 * t))
        v.co += n * d
        for layer in shape_layers:
            v[layer] += n * d
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    if uv:
        set_uvs(obj, uv)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    covered = set()
    for i, p in enumerate(index.points):
        if not chosen[i]:
            continue
        bone = index.dominant(i)
        inside = all((p - Vector(c[0])).dot(Vector(c[1])) < -.03
                     or (len(c) > 2 and not bone.endswith("_L" if c[2] > 0 else "_R")) for c in cuts)
        if inside:
            covered.add(i)
    return obj, covered


def ring_extent(objects, z, band=.012, centre_x=0.0):
    """Horizontal extents of mesh vertices within a height slab."""
    xs, ys = [], []
    for obj in objects:
        for v in obj.data.vertices:
            if abs(v.co.z - z) < band:
                xs.append(v.co.x)
                ys.append(v.co.y)
    if not xs:
        return None
    return min(xs), max(xs), min(ys), max(ys)


def skirt(name, arm, index, under, waist, hem, ease, material, thigh_share=.6, rings=9, sides=64,
          flare=.02, fold=.006, seed=1, tile=.22):
    """Tunic skirt as a closed tube from the waist to the hem over trousers."""
    rng = np.random.default_rng(seed)
    phase = rng.random(6) * TAU
    vertices, faces, uv = [], [], []
    heights = [waist + (hem - waist) * k / (rings - 1) for k in range(rings)]
    profiles = []
    for z in heights:
        ext = ring_extent(under, z) or ring_extent(under, z, .03)
        x0, x1, y0, y1 = ext
        cy = (y0 + y1) * .5
        t = (waist - z) / max(waist - hem, .01)
        rx = max(abs(x0), abs(x1)) + ease + flare * t
        ry = (y1 - y0) * .5 + ease + flare * t * .8
        profiles.append((cy, rx, ry))
    # A tube never narrows downwards: cloth falls from the widest point.
    for k in range(1, rings):
        cy, rx, ry = profiles[k]
        profiles[k] = (cy, max(rx, profiles[k - 1][1]), max(ry, profiles[k - 1][2]))
    for k, z in enumerate(heights):
        cy, rx, ry = profiles[k]
        t = k / (rings - 1)
        for j in range(sides):
            a = j * TAU / sides
            f = fold * t * (math.sin(a * 9 + phase[0]) * .6 + math.sin(a * 17 + phase[1]) * .4)
            vertices.append((math.cos(a) * (rx + f), cy + math.sin(a) * (ry + f), z + .004 * t * math.sin(a * 5 + phase[2])))
    for k in range(rings - 1):
        for j in range(sides):
            n = (j + 1) % sides
            faces.append((k * sides + j, k * sides + n, (k + 1) * sides + n, (k + 1) * sides + j))
    obj = hero.mesh_object(name, vertices, faces, material=material)
    circumference = TAU * (profiles[-1][1] + profiles[-1][2]) * .5
    periods = max(1, round(circumference / tile))

    def mapper(p, i):
        k, j = divmod(i, sides)
        return j / sides * periods, (p.z - hem) / tile, periods

    set_uvs(obj, mapper)
    rows = []
    for v in obj.data.vertices:
        x, _, z = v.co
        lower = max(0.0, min(1.0, (waist - z) / max(.01, waist - hem)))
        lower = lower * lower * (3 - 2 * lower)
        left = max(0.0, min(1.0, (x + .10) / .20))
        left = left * left * (3 - 2 * left)
        leg = thigh_share * lower
        rows.append({"Pelvis": 1 - leg, "Thigh_L": leg * left, "Thigh_R": leg * (1 - left)})
    bind(obj, arm, rows)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def gather_points(objects, keep=None):
    """Rest-pose vertex positions of several meshes as one array (filterable)."""
    rows = []
    for obj in objects:
        weights = vertex_weights(obj) if keep else None
        for v in obj.data.vertices:
            if keep and not keep(v.co, weights[v.index]):
                continue
            rows.append(tuple(v.co))
    return np.array(rows)


def envelope(source, z, angles, band=.02, window=.35, centre=None):
    """Radial distance of the outermost surface at height z for each angle."""
    pts = source if isinstance(source, np.ndarray) else gather_points(source)
    near = pts[np.abs(pts[:, 2] - z) < band]
    if len(near) == 0:
        return None
    pts = near[:, :2]
    c = np.array(centre) if centre is not None else pts.mean(axis=0)
    rel = pts - c
    ang = np.arctan2(rel[:, 1], rel[:, 0])
    rad = np.hypot(rel[:, 0], rel[:, 1])
    result = []
    for a in angles:
        diff = np.abs((ang - a + math.pi) % TAU - math.pi)
        mask = diff < window
        result.append(float(rad[mask].max()) if mask.any() else float(rad.max()))
    return c, np.array(result)


def _column_radius(pts, ang, rad, a, z, window, band_down, band_up):
    mask = (np.abs((ang - a + math.pi) % TAU - math.pi) < window) & (pts[:, 2] > z - band_down) & (pts[:, 2] < z + band_up)
    return float(rad[mask].max()) if mask.any() else None


def cape(name, arm, index, points, material, z_top, z_hem, span, thickness=.012, ease=.02,
         columns=48, rows=16, drape=.06, fold=.008, follow_arms=.9, seed=2, hem_curve=None, tile=.25,
         centre=(0.0, .0), head=False, window=.3, pleats=5, settle=True, points_upper=None, collide=None):
    """A cloak, pelt or hair fall draped over the points of the body below it.

    span(t) -> (a0, a1) gives the covered angle range of each row (t = 0 at
    the top, 1 at the hem); angles run in the horizontal plane from +X towards
    +Y, so the back is +90 degrees and the front -90. Each column starts where
    the cloth first rests on the body (shoulder tops are higher at the sides
    than the collar suggests) and then hangs: below its support it never
    moves back inwards. The upper part copies the arm/spine weights of the
    body below it; the hanging part follows the spine (or the head for hair).
    """
    rng = np.random.default_rng(seed)
    phase = rng.random(4) * TAU
    c = np.array(centre)

    def polar(points_in):
        rel_ = points_in[:, :2] - c
        return points_in, np.arctan2(rel_[:, 1], rel_[:, 0]), np.hypot(rel_[:, 0], rel_[:, 1])

    pts, ang, rad = polar(points)
    upper = polar(points_upper) if points_upper is not None else (pts, ang, rad)
    vertices, faces = [], []
    previous = None
    tops = []
    a0, a1 = span(0.0)
    for j in range(columns):
        a = a0 + (a1 - a0) * j / (columns - 1)
        top = z_top
        if settle:
            # Settle the top edge onto the shoulder: highest body point in
            # this direction below the collar line. Computed once per column
            # so the rows below never fold back over each other.
            m = ((np.abs((ang - a + math.pi) % TAU - math.pi) < window * .6) & (pts[:, 2] < z_top + .01)
                 & (pts[:, 2] > z_top - .12))
            if m.any():
                outer = rad[m] > np.percentile(rad[m], 80)
                top = min(z_top, float(pts[m][outer, 2].max()) + .004)
        tops.append(top)
    # Smooth the settled edge along the columns.
    tops = [sum(tops[max(0, j - 2):j + 3]) / len(tops[max(0, j - 2):j + 3]) for j in range(columns)]
    for k in range(rows):
        t = k / (rows - 1)
        # Denser rows near the top follow the shoulder curvature.
        tz = t ** 1.35
        a0, a1 = span(t)
        row = []
        for j in range(columns):
            s = j / (columns - 1)
            a = a0 + (a1 - a0) * s
            top = tops[j]
            z = top + (z_hem - top) * tz
            # Over the shoulders the cloth also lies on the upper arms.
            src = upper if tz < .22 else (pts, ang, rad)
            r = _column_radius(src[0], src[1], src[2], a, z, window, .03, .08 if k else .02)
            if r is None:
                r = previous[j] if previous is not None else .12
            if previous is not None:
                r = max(r, previous[j] * .985)
            row.append(r)
            back = max(0.0, math.sin(a))
            hang = drape * tz * (.35 + .65 * back)
            pleat = fold * tz * (math.sin(s * TAU * pleats + phase[0]) * .7 + math.sin(s * TAU * pleats * 2.3 + phase[1]) * .3)
            radius = r + ease + thickness + hang + pleat
            zz = z + (hem_curve(a) * tz ** 2 if hem_curve is not None else 0.0)
            zz += .012 * tz ** 3 * math.sin(s * TAU * pleats + phase[0] + 1.3)
            vertices.append((c[0] + math.cos(a) * radius, c[1] + math.sin(a) * radius, zz))
        previous = row
    for k in range(rows - 1):
        for j in range(columns - 1):
            a, b = k * columns + j, k * columns + j + 1
            faces.append((a, b, b + columns, a + columns))
    obj = hero.mesh_object(name, vertices, faces, material=material)
    widths = []
    for k in range(rows):
        seg = vertices[k * columns:(k + 1) * columns]
        widths.append(sum((Vector(seg[j + 1]) - Vector(seg[j])).length for j in range(columns - 1)))
    lengths = [0.0]
    for k in range(1, rows):
        lengths.append(lengths[-1] + (Vector(vertices[k * columns + columns // 2]) - Vector(vertices[(k - 1) * columns + columns // 2])).length)

    def mapper(p, i):
        k, j = divmod(i, columns)
        return (j / (columns - 1) - .5) * widths[k] / tile, -lengths[k] / tile, 0

    set_uvs(obj, mapper)
    rows_w = []
    for v in obj.data.vertices:
        k = v.index // columns
        t = k / (rows - 1)
        near = index.nearest_weights(v.co, 6)
        # Only the cloth lying on the shoulder follows the arm a little; the
        # hanging part stays with the trunk so a raised arm cannot drag it.
        keep = max(0.0, 1 - t / .18) * follow_arms
        row = {}
        for bone, w in near.items():
            if bone.startswith(("Arm", "Forearm", "Hand")):
                if keep > 0:
                    row[bone] = row.get(bone, 0.0) + w * keep
                row["Spine"] = row.get("Spine", 0.0) + w * (1 - keep)
            elif bone == "Head" and head:
                row["Head"] = row.get("Head", 0.0) + w
            elif bone in ("Spine", "Head"):
                row["Spine"] = row.get("Spine", 0.0) + w
            else:
                row["Spine"] = row.get("Spine", 0.0) + w * .7
                row["Pelvis"] = row.get("Pelvis", 0.0) + w * .3
        rows_w.append(row)
    bind(obj, arm, rows_w)
    smooth_weights(obj, 3)
    if collide:
        push_out(obj, collide, thickness + ease * .6)
    solidify(obj, thickness)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def push_out(obj, inner, clearance, passes=3):
    """Rest-pose collision: lift cloth vertices that lie inside or too close to
    the layers below (skin, tunic, mail) out along those layers' normals,
    then relax the moved region so the drape stays smooth."""
    from mathutils.bvhtree import BVHTree
    trees = []
    for other in inner:
        other.data.update()
        trees.append(BVHTree.FromPolygons([v.co for v in other.data.vertices],
                                          [tuple(p.vertices) for p in other.data.polygons]))
    mesh = obj.data
    moved_total = 0
    for _ in range(passes):
        moved = set()
        for v in mesh.vertices:
            best = None
            for tree in trees:
                hit = tree.find_nearest(v.co, clearance * 3)
                if hit[0] is None:
                    continue
                depth = clearance - (v.co - hit[0]).dot(hit[1])
                if depth > 0 and (best is None or depth > best[0]):
                    best = (depth, hit[1])
            if best:
                v.co += best[1] * best[0]
                moved.add(v.index)
        moved_total += len(moved)
        if not moved:
            break
        # Relax: average moved vertices with their neighbours along edges.
        links = {}
        for e in mesh.edges:
            a, b = e.vertices
            links.setdefault(a, []).append(b)
            links.setdefault(b, []).append(a)
        positions = [v.co.copy() for v in mesh.vertices]
        for i in moved:
            near = links.get(i, [])
            if near:
                avg = sum((positions[j] for j in near), Vector()) / len(near)
                mesh.vertices[i].co = positions[i].lerp(avg, .3)
    mesh.update()
    obj["push_out_vertex_moves"] = moved_total
    return moved_total


def hull_loft(name, arm, index, points, heights, material, ease=.005, sides=40, bones=None, tile=.12,
              close_bottom=True, flat_bottom=True):
    """Closed shell around a point cloud (a shoe over the toes), slab by slab."""
    vertices, faces = [], []
    angles = np.array([j * TAU / sides for j in range(sides)])
    for z in heights:
        env = envelope(points, z, angles, band=.018, window=.35)
        c, r = env
        for j, a in enumerate(angles):
            vertices.append((c[0] + math.cos(a) * (r[j] + ease), c[1] + math.sin(a) * (r[j] + ease), z))
    for k in range(len(heights) - 1):
        for j in range(sides):
            n = (j + 1) % sides
            faces.append((k * sides + j, k * sides + n, (k + 1) * sides + n, (k + 1) * sides + j))
    if close_bottom:
        faces.append(tuple(reversed(range(sides))))
    obj = hero.mesh_object(name, vertices, faces, material=material)

    def mapper(p, i):
        k, j = divmod(i, sides)
        return j / sides * 3, p.z / tile, 3

    set_uvs(obj, mapper)
    rows = [index.nearest_weights(v.co, 6, bones) for v in obj.data.vertices]
    bind(obj, arm, rows)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def smooth_weights(obj, passes=2, blend=.4):
    names = [g.name for g in obj.vertex_groups]
    count = len(obj.data.vertices)
    values = np.zeros((count, len(names)))
    for v in obj.data.vertices:
        for g in v.groups:
            values[v.index, g.group] = g.weight
    edges = np.array([tuple(e.vertices) for e in obj.data.edges], dtype=np.int64)
    if len(edges) == 0:
        return
    a, b = edges[:, 0], edges[:, 1]
    for _ in range(passes):
        acc = np.zeros_like(values)
        deg = np.zeros(count)
        np.add.at(acc, a, values[b])
        np.add.at(acc, b, values[a])
        np.add.at(deg, a, 1)
        np.add.at(deg, b, 1)
        active = deg > 0
        values[active] = (1 - blend) * values[active] + blend * acc[active] / deg[active, None]
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    groups = {n: obj.vertex_groups.new(name=n) for n in names}
    for i, row in enumerate(values):
        chosen = np.argsort(row)[-4:]
        total = row[chosen].sum()
        for gi in chosen:
            if row[gi] > 0:
                groups[names[gi]].add([i], float(row[gi] / total), "REPLACE")


def solidify(obj, thickness):
    """Real cloth thickness: an inner shell and a closed rim, no backface tricks."""
    modifier = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
    modifier.thickness = thickness
    modifier.offset = -1
    modifier.use_rim = True
    modifier.use_even_offset = True
    bpy.context.view_layer.objects.active = obj
    order = [m.name for m in obj.modifiers]
    bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def loft_ring(name, arm, index, objects, z0, z1, material, ease=.004, sides=48, bone_limit=None, tile=.2):
    """Closed band (belt) around the outermost garments between two heights."""
    vertices, faces = [], []
    angles = np.array([j * TAU / sides for j in range(sides)])
    zs = (z0, z1)
    torso = gather_points(objects, lambda p, row: bool(row) and max(row, key=row.get) in ("Spine", "Pelvis", "Thigh_L", "Thigh_R"))
    for z in zs:
        c, r = envelope(torso, z, angles, band=.02, window=.25)
        for j, a in enumerate(angles):
            vertices.append((c[0] + math.cos(a) * (r[j] + ease), c[1] + math.sin(a) * (r[j] + ease), z))
    for j in range(sides):
        n = (j + 1) % sides
        faces.append((j, n, sides + n, sides + j))
    obj = hero.mesh_object(name, vertices, faces, material=material)
    periods = max(1, round(TAU * .17 / tile))

    def mapper(p, i):
        return (i % sides) / sides * periods * 4, (i // sides) * .25, periods * 4

    set_uvs(obj, mapper)
    rows = [index.nearest_weights(v.co, 8, bone_limit or ("Pelvis", "Spine")) for v in obj.data.vertices]
    bind(obj, arm, rows)
    solidify(obj, .004)
    return obj


def tube(name, arm, path, radii, material, rows, sides=10, tile=.05, flatten=1.0, caps=True):
    """Generic tube along a path with per-ring weight rows (hair locks, straps)."""
    vertices, faces = [], []
    ring_rows = []
    for k, point in enumerate(path):
        p = Vector(point)
        tangent = Vector(path[min(k + 1, len(path) - 1)]) - Vector(path[max(0, k - 1)])
        axis = tangent.normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))
        a = axis.cross(helper).normalized()
        b = axis.cross(a).normalized()
        for i in range(sides):
            ang = i * TAU / sides
            vertices.append(p + radii[k] * (a * math.cos(ang) * flatten + b * math.sin(ang)))
            ring_rows.append(rows[k])
    n = sides
    for k in range(len(path) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i))
    if caps:
        faces.append(tuple(reversed(range(n))))
        last = (len(path) - 1) * n
        faces.append(tuple(last + i for i in range(n)))
    obj = hero.mesh_object(name, vertices, faces, material=material)
    length = [0.0]
    for k in range(1, len(path)):
        length.append(length[-1] + (Vector(path[k]) - Vector(path[k - 1])).length)

    def mapper(p, i):
        k, j = divmod(i, n)
        if k >= len(path):
            return 0, 0, 0
        return j / n, length[k] / tile, 1.0

    set_uvs(obj, mapper)
    bind(obj, arm, ring_rows)
    return obj


def spiral_wrap(name, arm, index, objects, axis_a, axis_b, z_low, z_high, material, turns=7.0,
                width=.045, ease=.003, steps=220, side="L", tile=.2):
    """Leg wrap: a ribbon spiralling up the shin over the trouser leg."""
    a, b = Vector(axis_a), Vector(axis_b)
    axis = (b - a).normalized()
    ref = axis.cross(Vector((0, 1, 0))).normalized()
    other = axis.cross(ref).normalized()
    vertices, faces = [], []
    pts = []
    for obj in objects:
        for v in obj.data.vertices:
            if z_low - .02 < v.co.z < z_high + .02 and (v.co.x > 0) == (side == "L"):
                pts.append(v.co.copy())
    if not pts:
        raise RuntimeError("Leg wrap has no leg surface under it")
    pts_arr = np.array([tuple(p) for p in pts])
    for s in range(steps + 1):
        t = s / steps
        z = z_low + (z_high - z_low) * t
        ang = t * turns * TAU
        centre_t = (z - a.z) / (b.z - a.z) if abs(b.z - a.z) > 1e-6 else 0
        centre = a + (b - a) * centre_t
        dirn = ref * math.cos(ang) + other * math.sin(ang)
        rel = pts_arr - np.array(tuple(centre))
        near = (np.abs(pts_arr[:, 2] - z) < .02) & (np.hypot(rel[:, 0], rel[:, 1]) < .10)
        r = .055
        if near.any():
            radial = rel[near] @ np.array(tuple(dirn))
            sideways = rel[near] - np.outer(radial, tuple(dirn))
            off_ray = np.linalg.norm(sideways - np.outer(sideways @ np.array(tuple(axis)), tuple(axis)), axis=1)
            mask = (off_ray < .03) & (radial > 0)
            if mask.any():
                r = float(radial[mask].max())
        r += ease
        lo = centre + dirn * r + axis * (-width * .5)
        hi = centre + dirn * (r + .002) + axis * (width * .5)
        vertices.extend([lo, hi])
    for s in range(steps):
        i = s * 2
        faces.append((i, i + 2, i + 3, i + 1))
    obj = hero.mesh_object(name, vertices, faces, material=material)
    total = 0.0
    lengths = [0.0]
    for s in range(1, steps + 1):
        total += (vertices[s * 2] - vertices[s * 2 - 2]).length
        lengths.append(total)

    def mapper(p, i):
        s, k = divmod(i, 2)
        return k * width / tile, lengths[s] / tile, 0

    set_uvs(obj, mapper)
    rows = [index.nearest_weights(v.co, 4, ("Shin_" + side, "Foot_" + side, "Thigh_" + side)) for v in obj.data.vertices]
    bind(obj, arm, rows)
    solidify(obj, .003)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def remove_covered(body, covered):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if all(v.index in covered for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # Shape-key layers survive the bmesh round trip.
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    return len(drop)


def boundary_loops(obj):
    """Closed boundary loops of a mesh as ordered vertex index lists."""
    mesh = obj.data
    counts = {}
    for poly in mesh.polygons:
        for key in poly.edge_keys:
            counts[key] = counts.get(key, 0) + 1
    links = {}
    for (a, b), c in counts.items():
        if c == 1:
            links.setdefault(a, []).append(b)
            links.setdefault(b, []).append(a)
    loops, seen = [], set()
    for start in links:
        if start in seen:
            continue
        loop = [start]
        seen.add(start)
        prev, cur = None, start
        while True:
            nxt = [n for n in links[cur] if n != prev and n not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            seen.add(cur)
            loop.append(cur)
        if len(loop) > 5:
            loops.append(loop)
    return loops


def trim_loop(name, arm, obj, loop, material, radius=.006, out=.003, flatten=.45, step=1):
    """A woven band (tablet-woven border) laid along a garment edge loop.

    The edge vertices are ordered by angle round the loop's own axis (not by
    walking the boundary graph, which can jump at a branching vertex).
    """
    weights = vertex_weights(obj)
    points = np.array([tuple(obj.data.vertices[i].co) for i in loop])
    centre = points.mean(axis=0)
    rel = points - centre
    _, _, vt = np.linalg.svd(rel, full_matrices=False)
    u_axis, v_axis = vt[0], vt[1]
    angles = np.arctan2(rel @ v_axis, rel @ u_axis)
    order = np.argsort(angles)
    path, rows = [], []
    for k in order[::step]:
        p = Vector(points[k])
        d = p - Vector(centre)
        d -= Vector(vt[2]) * d.dot(Vector(vt[2]))
        path.append(p + (d.normalized() * out if d.length > 1e-6 else Vector()))
        rows.append(weights[loop[k]])
    radii = np.linalg.norm(rel - np.outer(rel @ vt[2], vt[2]), axis=1)
    if radii.max() > .40 or len(path) < 6:
        return None
    path.append(path[0])
    rows.append(rows[0])
    return tube(name, arm, path, [radius] * len(path), material, rows, sides=6, tile=.03, flatten=flatten, caps=False)
