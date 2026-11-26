"""Hair and beards as real geometry on the fitted head (Blender).

Styles: cropped, long (to the shoulders), tied (nape tail), knot (side knot of
the kind Tacitus, Germania 38, c. AD 98, describes for the Suebi; the bog find
from Osterby is also later than 58 BC), braids. Beards: none, stubble, short,
full, long, moustache. All pieces are opaque geometry with a strand texture,
so mobile rendering needs no alpha-sorted hair cards.
"""
from __future__ import annotations

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import tailoring as T
from figure import Anatomy

TAU = math.tau


def face_landmarks(index, marks):
    """Geometric landmarks measured on the fitted body."""
    pts = index.points
    eye = (marks["eye_L"] + marks["eye_R"]) * .5
    head = [i for i, row in enumerate(index.weights) if row.get("Head", 0) > .6]
    top = max(pts[i].z for i in head)
    nose = min((i for i in head if abs(pts[i].x) < .006 and eye.z - .075 < pts[i].z < eye.z - .015),
               key=lambda i: pts[i].y)
    anatomy = Anatomy.get()
    lips = set()
    for bone, entries in anatomy["facial_weights"].items():
        if bone.startswith("oris"):
            for vertex, weight in entries:
                if weight > .2 and vertex in anatomy["index"]:
                    lips.add(anatomy["index"][vertex])
    lip_pts = [pts[i] for i in lips]
    mouth = sum(lip_pts, Vector()) / len(lip_pts)
    corner = max(abs(p.x) for p in lip_pts)
    chin_candidates = [i for i in head if abs(pts[i].x) < .01 and pts[i].z < mouth.z - .02 and pts[i].y < mouth.y + .03]
    chin = min(chin_candidates, key=lambda i: pts[i].y + .3 * (pts[i].z - (mouth.z - .045)) ** 2 * 40)
    skull = [pts[i] for i in head if pts[i].z > eye.z]
    centre = Vector((0.0, sum(p.y for p in skull) / len(skull), eye.z + .02))
    return {"eye": eye, "top": top, "nose": pts[nose].copy(), "mouth": mouth, "lips": lips,
            "corner": corner, "chin": pts[chin].copy(), "centre": centre, "head": set(head)}


def _azimuth(p, centre):
    rel = p - centre
    return math.atan2(rel.x, -rel.y)  # 0 front, +/-pi back, + = wearer's left


HAIRLINE = ((0.0, .058), (.45, .054), (.9, .042), (1.3, .030), (1.62, .022), (1.95, -.004),
            (2.4, -.040), (math.pi, -.058))


def hairline(phi, recede=0.0):
    a = abs(phi)
    for (a0, h0), (a1, h1) in zip(HAIRLINE, HAIRLINE[1:]):
        if a <= a1:
            t = (a - a0) / (a1 - a0)
            h = h0 + (h1 - h0) * t
            break
    else:
        h = HAIRLINE[-1][1]
    if recede:
        h += recede * max(0.0, math.cos(a)) ** 2
    return h


def scalp(name, arm, index, lm, material, style, thickness=.006, recede=0.0, knot=None, tile=.06):
    eye, centre = lm["eye"], lm["centre"]

    def inside(i, p, bone):
        if i not in lm["head"]:
            return False
        dz = p.z - eye.z
        phi = _azimuth(p, centre)
        if dz < hairline(phi, recede):
            return False
        if abs(p.x) > .068 and -.055 < dz < .035 and abs(phi) > 1.2:
            return False  # ears stay free
        return True

    def offset(p, n, bone):
        phi = _azimuth(p, centre)
        margin = (p.z - eye.z) - hairline(phi, recede)
        fade = max(0.0, min(1.0, margin / .014))
        fade = fade * fade * (3 - 2 * fade)
        crown = max(0.0, min(1.0, (p.z - eye.z - .06) / .06))
        volume = thickness * (1 + .5 * crown)
        if style in ("long", "braids", "tied"):
            back = max(0.0, -math.cos(phi))
            volume += .004 * back
        return .0015 + volume * fade

    if knot is not None:
        k = Vector(knot)

        def uv(p, i):
            d = p - k
            return math.atan2(d.y, d.x) / TAU * 3, -d.length / tile, 3.0
    else:
        top = Vector((centre.x, centre.y + .01, lm["top"]))

        def uv(p, i):
            phi = _azimuth(p, centre)
            return phi / TAU * 3, -(top - p).length / tile, 3.0

    obj, covered = T.region_garment(name, index, arm, inside, offset, material, uv=uv, fade=.012)
    snap_hairline(obj, index, lm, recede)
    return obj


def snap_hairline(obj, index, lm, recede):
    """Pull the cut edge of the scalp onto the smooth hairline on the skin.

    The region is cut along whole faces; without this the hairline shows the
    polygon steps of the head mesh.
    """
    from mathutils.bvhtree import BVHTree
    eye, centre = lm["eye"], lm["centre"]
    body = index.body
    tree = BVHTree.FromPolygons(index.points, [tuple(p.vertices) for p in body.data.polygons])
    loops = T.boundary_loops(obj)
    rim = {i for loop in loops for i in loop}
    for i in rim:
        v = obj.data.vertices[i]
        phi = _azimuth(v.co, centre)
        target_z = eye.z + hairline(phi, recede)
        if abs(v.co.x) > .066 and -.055 < target_z - eye.z < .035 and abs(phi) > 1.2:
            continue
        probe = Vector((v.co.x, v.co.y, target_z))
        for _ in range(3):
            location, normal, _, _ = tree.find_nearest(probe)
            if location is None:
                break
            probe = Vector((location.x, location.y, target_z))
        if location is not None:
            v.co = location + normal * .0006
    obj.data.update()


def knot_geometry(name, arm, lm, material, side=-1):
    """Side knot: hair twisted into a compact coil above and behind the ear."""
    eye, centre = lm["eye"], lm["centre"]
    phi = side * 1.85
    anchor = Vector((centre.x + math.sin(phi) * .080, centre.y - math.cos(phi) * .080, eye.z + .040))
    outward = (anchor - Vector((centre.x, centre.y, anchor.z))).normalized()
    up = Vector((0, 0, 1))
    tangent = outward.cross(up).normalized()
    core = anchor + outward * .016
    parts = []
    # Bun body: a flattened ellipsoid sitting on the scalp.
    path, radii = [], []
    for s in range(9):
        t = s / 8
        path.append(core + outward * (-.014 + .030 * t))
        radii.append(.0255 * math.sin(math.pi * (.08 + .84 * t)) ** .7 + .002)
    parts.append(T.tube(name, arm, path, radii, material, [{"Head": 1.0}] * len(path), sides=14, tile=.03))
    # Twisted strand wound twice round the bun.
    path, radii = [], []
    for s in range(41):
        t = s / 40
        a = t * TAU * 2.0
        r = .025 - .006 * t
        path.append(core + outward * (.004 + .010 * math.sin(math.pi * t)) + up * (math.sin(a) * r) + tangent * (math.cos(a) * r))
        radii.append(.0075 * (1 - .4 * t) + .002)
    parts.append(T.tube(name + "Coil", arm, path, radii, material, [{"Head": 1.0}] * len(path), sides=8, tile=.03))
    tail = path[-1]
    tuft_path = [tail, tail + up * -.03 + outward * .004, tail + up * -.06 + outward * .006]
    parts.append(T.tube(name + "Tuft", arm, tuft_path, [.008, .007, .002], material, [{"Head": 1.0}] * 3, sides=8, tile=.03))
    return parts, core


def nape_tail(name, arm, lm, material, length=.17, tie=None):
    eye, centre = lm["eye"], lm["centre"]
    start = Vector((0, centre.y + .085, eye.z - .045))
    path = [start + Vector((0, .006 * s, -length * s / 6)) + Vector((0, .02 * math.sin(s / 6 * math.pi), 0)) for s in range(7)]
    radii = [.020, .021, .019, .017, .014, .010, .004]
    rows = []
    for s in range(7):
        t = s / 6
        rows.append({"Head": 1 - .6 * t, "Spine": .6 * t})
    parts = [T.tube(name, arm, path, radii, material, rows, sides=12, tile=.04)]
    if tie is not None:
        band = [start + Vector((0, .004, -.012)), start + Vector((0, .005, -.030))]
        parts.append(T.tube(name + "Tie", arm, band, [.023, .022], tie, [{"Head": 1.0}] * 2, sides=12, tile=.02))
    return parts


def braids(name, arm, lm, material, tie, length=.26):
    eye, centre = lm["eye"], lm["centre"]
    parts = []
    for side in (-1, 1):
        root = Vector((side * .058, centre.y + .06, eye.z - .035))
        for strand in range(3):
            path, radii, rows = [], [], []
            for s in range(25):
                t = s / 24
                drop = Vector((side * .012 * t, .035 * t, -length * t))
                phase = t * TAU * 5 + strand * TAU / 3
                wiggle = Vector((math.cos(phase) * .006, math.sin(phase) * .004, 0))
                path.append(root + drop + wiggle)
                radii.append(.0065 * (1 - .4 * t))
                rows.append({"Head": 1 - .7 * t, "Spine": .7 * t})
            parts.append(T.tube(f"{name}_{side}_{strand}", arm, path, radii, material, rows, sides=6, tile=.03))
        end = root + Vector((side * .012, .035, -length))
        parts.append(T.tube(f"{name}Tie_{side}", arm, [end + Vector((0, 0, .012)), end - Vector((0, 0, .004))],
                            [.009, .009], tie, [{"Head": .3, "Spine": .7}] * 2, sides=8, tile=.02))
    return parts


def beard(name, arm, index, lm, material, style, tile=.05, with_moustache=False):
    eye, nose, mouth, chin = lm["eye"], lm["nose"], lm["mouth"], lm["chin"]
    lips = lm["lips"]
    corner = lm["corner"]
    cheek_line = nose.z - .004
    depth = {"stubble": .0012, "short": .007, "full": .013, "long": .015, "moustache": 0.0}[style]
    if style == "moustache":
        return []

    def inside(i, p, bone):
        if i not in lm["head"] or i in lips:
            return False
        rel = p - eye
        if rel.y > .055:
            return False
        side = abs(p.x)
        # Sideburn and cheek line rises towards the ears.
        limit = cheek_line - .012 + .018 * min(1.0, max(0.0, (side - .03) / .04))
        if p.z > limit:
            return False
        # Leave the mouth and a small margin around it.
        if side < corner + .008 and mouth.z - .014 < p.z < nose.z - .004 and p.y < mouth.y + .02:
            if p.z > mouth.z + .007:
                return with_moustache and side < corner + .004
            return style in ("full", "long") and p.z < mouth.z - .010
        return p.z > lm["chin"].z - .075 - (.0 if p.y < chin.y + .05 else .02)

    def offset(p, n, bone):
        side = abs(p.x)
        chinward = max(0.0, min(1.0, (cheek_line - p.z) / .07))
        edge = max(0.0, min(1.0, (cheek_line - .012 + .018 * min(1.0, max(0.0, (side - .03) / .04)) - p.z) / .012))
        return .0008 + depth * (.45 + .9 * chinward) * edge

    def uv(p, i):
        return p.x / tile * 1.5, p.z / tile, 0

    obj, _ = T.region_garment(name, index, arm, inside, offset, material, uv=uv, keep_keys=True, fade=.008)
    parts = [obj]
    if style == "long":
        top = chin + Vector((0, -.004, .020))
        path = [top, top + Vector((0, -.012, -.040)), top + Vector((0, -.004, -.090)), top + Vector((0, .012, -.130)),
                top + Vector((0, .020, -.150))]
        radii = [.036, .041, .036, .022, .006]  # across the chest; depth set by flatten
        rows = [{"Head": 1.0}, {"Head": .95, "Spine": .05}, {"Head": .8, "Spine": .2}, {"Head": .65, "Spine": .35},
                {"Head": .6, "Spine": .4}]
        parts.append(T.tube(name + "Fall", arm, path, radii, material, rows, sides=14, tile=.04, flatten=.5))
    return parts


def moustache(name, arm, lm, material, droop=.022, thickness=.0065):
    """Two locks over the upper lip, falling past the mouth corners."""
    nose, mouth, corner = lm["nose"], lm["mouth"], lm["corner"]
    parts = []
    lip_top = nose.z - .013
    for side in (-1, 1):
        path = [Vector((side * .001, nose.y + .011, lip_top + .003)),
                Vector((side * .011, nose.y + .012, lip_top - .001)),
                Vector((side * (corner - .006), mouth.y - .006, lip_top - .008)),
                Vector((side * (corner + .002), mouth.y - .001, lip_top - droop * .7)),
                Vector((side * (corner + .004), mouth.y + .002, lip_top - droop))]
        radii = [thickness * .7, thickness, thickness * .95, thickness * .6, thickness * .25]
        parts.append(T.tube(f"{name}_{side}", arm, path, radii, material, [{"Head": 1.0}] * 5, sides=8, tile=.02,
                            flatten=.7))
    return parts


def paint_region(albedo, body, vertex_set, colour, strength, seed, radius=5, speckle=True):
    """Splat a soft mask over the UVs of the given body vertices (stubble etc.)."""
    h, w = albedo.shape[:2]
    mesh = body.data
    layer = mesh.uv_layers.active
    mask = np.zeros((h, w))
    rng = np.random.default_rng(seed)
    seen = set()
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            if vi not in vertex_set or li in seen:
                continue
            seen.add(li)
            u, v = layer.data[li].uv
            x, y = int(u * (w - 1)), int(v * (h - 1))
            x0, x1, y0, y1 = max(0, x - radius), min(w, x + radius + 1), max(0, y - radius), min(h, y + radius + 1)
            if x0 >= x1 or y0 >= y1:
                continue
            yy, xx = np.mgrid[y0:y1, x0:x1]
            d = np.hypot(xx - x, yy - y) / radius
            mask[y0:y1, x0:x1] = np.maximum(mask[y0:y1, x0:x1], np.clip(1 - d, 0, 1))
    if speckle:
        dots = rng.random((h, w)) ** 3
        mask = mask * (.55 + .45 * dots)
    mask = np.clip(mask * strength, 0, 1)[..., None]
    return albedo * (1 - mask) + np.asarray(colour) * mask
