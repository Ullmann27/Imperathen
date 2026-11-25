"""Original, wind-ready vegetation for IMPERATHEN. Blender 4.3+, metres.

Run from the repository root:
  blender --background --factory-startup -t 2 -P tools/world_art/vegetation.py
  blender --background --factory-startup -t 2 -P tools/world_art/vegetation.py -- --render-only

No downloaded models, textures or photographs are used. The plant forms are art
studies inspired by field elm, columnar cypress and laurel; they are not scans or
botanically measured specimens. COLOR_0 stores wind data, not albedo. The runtime
must install the matching wind shader before displaying these meshes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART_REL = Path("art/world_expansion/vegetation")
ASSET_REL = Path("prototype/assets/world_expansion/vegetation")
KINDS = ("field_elm", "cypress", "laurel")
SEEDS = {"field_elm": 25719, "cypress": 25607, "laurel": 25291}
TAU = math.tau


def smoothstep(lo: float, hi: float, value: float) -> float:
    t = max(0.0, min(1.0, (value - lo) / (hi - lo)))
    return t * t * (3.0 - 2.0 * t)


def image_noise(rng: np.random.Generator, size: int, grid: int) -> np.ndarray:
    """Deterministic low-frequency noise; local array, no procedural nodes."""
    small = rng.random((grid, grid), dtype=np.float32)
    im = Image.fromarray(small)
    return np.asarray(im.resize((size, size), Image.Resampling.BICUBIC), dtype=np.float32)


def write_texture(path: Path, pixels: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).save(path, optimize=True)


def normal_pixels(height: np.ndarray, strength: float) -> np.ndarray:
    # Positive green follows increasing image V after glTF UV conversion.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    norm = np.sqrt(1.0 + dx * dx + dy * dy)
    return np.stack((0.5 - 0.5 * dx / norm, 0.5 + 0.5 * dy / norm,
                     0.5 + 0.5 / norm), axis=-1) * 255.0


def generate_textures(kind: str, out: Path) -> dict[str, dict[str, Path]]:
    """Embedded 1K bark maps and a 1K atlas with four leaf colour variants."""
    size = 1024
    rng = np.random.default_rng(SEEDS[kind])
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    broad = image_noise(rng, size, 14)
    middle = image_noise(rng, size, 45)
    fine = image_noise(rng, size, 180)
    grain = rng.random((size, size), dtype=np.float32)
    warp = 0.21 * np.sin(TAU * (y * 2 + 0.2 * np.sin(x * TAU)))
    warp += 0.085 * np.sin(TAU * y * 7 + x * 12) + (broad - .5) * .65
    # Elongated, irregular bark plates. Distances to neighbouring jittered
    # feature points yield cracks without a regular striped/weave pattern.
    grid_x, grid_y = 43, 17
    gx, gy = x * grid_x + warp, y * grid_y + (middle - .5) * .24
    ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    features = rng.random((grid_y, grid_x, 2), dtype=np.float32)
    nearest = np.full_like(x, 1e6)
    second = np.full_like(x, 1e6)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            feature = features[(iy + oy) % grid_y, (ix + ox) % grid_x]
            dx = ix + ox + .1 + feature[..., 0] * .8 - gx
            dy = iy + oy + .1 + feature[..., 1] * .8 - gy
            distance = dx * dx + dy * dy
            second = np.minimum(second, np.maximum(nearest, distance))
            nearest = np.minimum(nearest, distance)
    fissures = np.exp(-((second - nearest) / .065) ** 2)
    height = .54 - fissures * .4 + broad * .16 + fine * .11 + grain * .025
    height += np.abs(np.sin(TAU * (x * 83 + warp))) * .035
    # Shallow oval knots interrupt the longitudinal bark instead of painting
    # uninterrupted stripes. Width is expressed relative to trunk circumference.
    for i in range(8):
        kx, ky = rng.uniform(0.03, 0.97), rng.uniform(0.04, 0.96)
        xx = (x - kx) / rng.uniform(0.015, 0.034)
        yy = (y - ky) / rng.uniform(0.025, 0.065)
        radius = np.sqrt(xx * xx + yy * yy)
        ring = np.exp(-((radius - 1.0) * 6.0) ** 2)
        center = np.exp(-radius * radius * 2.3)
        height += ring * 0.13 - center * 0.13
    bark_base = {"field_elm": (113, 99, 81), "cypress": (113, 89, 67),
                 "laurel": (115, 113, 89)}[kind]
    tone = 0.66 + height * 0.57
    bark_rgb = np.stack([tone * c for c in bark_base], axis=-1)
    lichen = np.clip((broad - 0.66) * 2.8, 0.0, 0.3) * np.clip(fine * 1.5, 0, 1)
    bark_rgb = bark_rgb * (1 - lichen[..., None]) + np.array((146, 153, 119)) * lichen[..., None]
    bark_rough = np.repeat(np.clip(202 + (1.0 - height) * 36, 0, 255)[..., None], 3, axis=-1)
    result: dict[str, dict[str, Path]] = {}
    for category in ("bark", "foliage"):
        result[category] = {suffix: out / f"{kind}_{category}_{suffix}.png"
                            for suffix in ("albedo", "normal", "roughness")}
    write_texture(result["bark"]["albedo"], bark_rgb)
    write_texture(result["bark"]["normal"], normal_pixels(height, 10.0))
    write_texture(result["bark"]["roughness"], bark_rough)

    leaf_rgb = np.zeros((size, size, 3), dtype=np.float32)
    leaf_height = np.zeros((size, size), dtype=np.float32)
    leaf_rough = np.zeros((size, size, 3), dtype=np.float32)
    leaf_base = {"field_elm": (72, 104, 42), "cypress": (41, 74, 46),
                 "laurel": (50, 87, 43)}[kind]
    cell = size // 2
    v, u = np.mgrid[0:cell, 0:cell].astype(np.float32) / cell
    for variant in range(4):
        local_rng = np.random.default_rng(SEEDS[kind] + variant * 91)
        n = image_noise(local_rng, cell, 30)
        distance = np.abs(u - 0.5)
        midrib = np.exp(-(distance / 0.012) ** 2)
        vein_phase = v * (12 if kind != "cypress" else 22) + distance * 3.1
        veins = np.exp(-(np.sin(TAU * vein_phase) / 0.15) ** 2)
        veins *= np.clip(distance * 4, 0, 1)
        leaf_surface = 0.15 * midrib + 0.045 * veins + 0.026 * n
        variation = (0.86, 1.04, 1.15, 0.95)[variant]
        lightness = variation * (0.91 + n * 0.13 + (1 - distance * 2) * 0.1)
        rgb = np.stack([lightness * c for c in leaf_base], axis=-1)
        rgb += midrib[..., None] * np.array((22, 24, 10))
        rgb += veins[..., None] * np.array((5, 7, 3))
        # Fine speckles remain albedo variation, without baked highlights.
        speckle = local_rng.random((cell, cell), dtype=np.float32)
        rgb += (speckle[..., None] - 0.5) * 3.0
        row, col = (variant // 2) * cell, (variant % 2) * cell
        leaf_rgb[row:row+cell, col:col+cell] = rgb
        leaf_height[row:row+cell, col:col+cell] = leaf_surface
        roughness = (166 if kind == "laurel" else 199) + n * 16
        leaf_rough[row:row+cell, col:col+cell] = np.repeat(roughness[..., None], 3, axis=-1)
    write_texture(result["foliage"]["albedo"], leaf_rgb)
    write_texture(result["foliage"]["normal"], normal_pixels(leaf_height, 6.0))
    write_texture(result["foliage"]["roughness"], leaf_rough)
    return result


def texture_lod(maps: dict[str, dict[str, Path]], lod: int) -> dict[str, dict[str, Path]]:
    """Near 1K, mid 512, far 256. Renormalize reduced tangent-space normals."""
    if lod == 0:
        return maps
    size = 1024 >> lod
    result = {}
    for category, channels in maps.items():
        result[category] = {}
        for channel, source in channels.items():
            target = source.with_name(source.stem + f"_lod{lod}.png")
            with Image.open(source) as image:
                reduced = image.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
                pixels = np.asarray(reduced, dtype=np.float32)
            if channel == "normal":
                normal = pixels / 127.5 - 1.0
                normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-6)
                pixels = (normal + 1.0) * 127.5
            write_texture(target, pixels)
            result[category][channel] = target
    return result


class PlantMesh:
    """Two material surfaces with retained scaffold and deterministic LODs."""

    def __init__(self, kind: str, lod: int):
        from mathutils import Vector
        self.Vector = Vector
        self.up = Vector((0, 0, 1))
        self.kind, self.lod = kind, lod
        self.vertices: list[tuple] = []
        self.faces: list[tuple] = []
        self.uvs: list[list[tuple]] = []
        self.materials: list[int] = []
        self.smooth: list[bool] = []
        self.colors: list[tuple] = []
        self.wood_segments = 0
        self.visible_leaves = 0
        self.logical_leaves = 0
        self.height = {"field_elm": 8.5, "cypress": 8.6, "laurel": 1.8}[kind]

    def vertex(self, position, color) -> int:
        self.vertices.append(tuple(position))
        self.colors.append(tuple(color))
        return len(self.vertices) - 1

    def face(self, vertices, uv, material: int, smooth: bool = False) -> None:
        self.faces.append(tuple(vertices))
        self.uvs.append(list(uv))
        self.materials.append(material)
        self.smooth.append(smooth)

    def radial(self, angle: float):
        return self.Vector((math.cos(angle), math.sin(angle), 0.0))

    def wood(self, points, radii, phase: float, major: bool = False,
             terminal: bool = False) -> None:
        # Far representation drops only tiny twig meshes. Their leaves remain.
        if terminal and self.lod == 2:
            return
        if terminal and self.lod == 1:
            points, radii = [points[0], points[-1]], [radii[0], radii[-1]]
        sides = (16, 10, 6)[self.lod] if major else (7, 5, 4)[self.lod]
        rows = []
        distance = [0.0]
        for i, (point, radius) in enumerate(zip(points, radii)):
            tangent = (points[min(i+1, len(points)-1)] - points[max(0, i-1)]).normalized()
            a = tangent.cross(self.Vector((1, 0, 0)))
            if a.length_squared < 0.001:
                a = tangent.cross(self.Vector((0, 1, 0)))
            a.normalize()
            b = tangent.cross(a).normalized()
            bend = smoothstep(0.08, self.height, point.z)
            bend *= 0.12 + 0.3 * (1.0 - min(1.0, radius / 0.33))
            row = []
            for j in range(sides):
                angle = TAU * j / sides
                rib = 1.0 + (0.11 if major else 0.035) * math.sin(angle * 5 + i * 0.6 + phase * 5)
                rib += (0.035 if major else 0.01) * math.cos(angle * 9 - i * 0.7)
                offset = (math.cos(angle) * a + math.sin(angle) * b) * radius * rib
                row.append(self.vertex(point + offset, (bend, 0.0, phase, 1.0)))
            rows.append(row)
            if i:
                distance.append(distance[-1] + (point - points[i-1]).length / 1.6)
        for i, (lo, hi) in enumerate(zip(rows, rows[1:])):
            for j in range(sides):
                k = (j+1) % sides
                self.face((lo[j], lo[k], hi[k], hi[j]),
                          ((j/sides, distance[i]), ((j+1)/sides, distance[i]),
                           ((j+1)/sides, distance[i+1]), (j/sides, distance[i+1])), 0, True)
        # Closed caps avoid open ends in standalone inspection and shadowing.
        for row, reverse in ((rows[0], True), (rows[-1], False)):
            ordered = list(reversed(row)) if reverse else row
            uv = [(.5+.45*math.cos(i*TAU/sides), .5+.45*math.sin(i*TAU/sides)) for i in range(sides)]
            ordered_uv = list(reversed(uv)) if reverse else uv
            for i in range(1, len(ordered)-1):
                self.face((ordered[0], ordered[i], ordered[i+1]),
                          (ordered_uv[0], ordered_uv[i], ordered_uv[i+1]), 0)
        self.wood_segments += 1

    def branch(self, start, end, radius: float, rng: random.Random,
               phase: float, major: bool = False, terminal: bool = False):
        delta = end - start
        lateral = self.Vector((-delta.y, delta.x, 0)).normalized()
        bend = rng.uniform(-0.09, 0.09) * delta.length
        mid = start.lerp(end, .38 if major else .46) + lateral * bend * (2.2 if major else 1)
        mid -= self.up * delta.length * (.12 if major else .035)
        shoulder = start.lerp(end, .72 if major else .77) + lateral * bend * (.9 if major else .5)
        shoulder -= self.up * delta.length * (.035 if major else 0)
        self.wood([start, mid, shoulder, end], [radius, radius*.73, radius*.4, radius*.12],
                  phase, major=major, terminal=terminal)
        return mid, shoulder

    def leaf(self, base, heading, length: float, width: float,
             twist: float, variant: int, phase: float) -> None:
        identifier = self.logical_leaves
        self.logical_leaves += 1
        stride = (1, 5, 12)[self.lod]
        if identifier % stride:
            return
        self.visible_leaves += 1
        scale = (1.0, 1.98, 2.75)[self.lod]
        length, width = length * scale, width * scale
        direction = heading.normalized()
        side = direction.cross(self.up)
        if side.length_squared < 0.001:
            side = self.Vector((1, 0, 0))
        side.normalize()
        normal = side.cross(direction).normalized()
        side = (side * math.cos(twist) + normal * math.sin(twist)).normalized()
        normal = side.cross(direction).normalized()
        bend = 0.23 + 0.65 * smoothstep(0.05, self.height, base.z)
        def point(t: float, lateral: float, ridge: bool = False):
            p = base + direction * (length * t) + side * (width * lateral)
            p += normal * length * (0.018 * math.sin(t * math.pi) + (0.023 if ridge else 0.0))
            # One stable phase per leaf. G rises from fixed petiole to loose tip.
            return self.vertex(p, (bend, t * t, phase, 1.0))
        def uv(u: float, v: float):
            # 2x2 atlas; leave a gutter to avoid cross-variant mip bleeding.
            return ((variant % 2 + 0.035 + u * 0.93) / 2,
                    (variant // 2 + 0.035 + v * 0.93) / 2)
        if self.lod == 2:
            ids = [point(0, 0), point(.45, -1), point(1, 0), point(.45, 1)]
            coords = [uv(.5, 0), uv(0, .45), uv(.5, 1), uv(1, .45)]
            self.face((ids[0], ids[1], ids[2]), (coords[0], coords[1], coords[2]), 1, True)
            self.face((ids[0], ids[2], ids[3]), (coords[0], coords[2], coords[3]), 1, True)
            return
        # Six-edge folded blade: pointed base/tip, broad shoulders, raised midrib.
        stations = ((0.0, 0.0), (.27, -.86), (.64, -1.0), (1.0, 0.0),
                    (.64, 1.0), (.27, .86)) if self.lod == 0 else (
                    (0.0,0.0),(.48,-1.0),(1.0,0.0),(.48,1.0))
        ids = [point(t, w) for t, w in stations]
        coords = [uv(.5 + .5*w, t) for t, w in stations]
        center = point(.48, 0, True)
        for i in range(len(ids)):
            nxt = (i + 1) % len(ids)
            self.face((ids[i], ids[nxt], center), (coords[i], coords[nxt], uv(.5, .48)), 1, True)

    def leafy_twig(self, start, end, rng: random.Random, phase: float,
                   leaf_length: float, count: int = 14, narrow: bool = False) -> None:
        direction = (end - start).normalized()
        self.branch(start, end, 0.012 if self.kind != "laurel" else 0.008,
                    rng, phase, terminal=True)
        side = direction.cross(self.up)
        if side.length_squared < .001:
            side = self.Vector((1, 0, 0))
        side.normalize()
        for row in range(count):
            t = .12 + .85 * (row + .35) / count
            origin = start.lerp(end, t)
            for sign in (-1, 1):
                ray = (direction * rng.uniform(.3, .55) + side * sign * rng.uniform(.65, .9)
                       + self.up * rng.uniform(-.18, .48)).normalized()
                ll = leaf_length * rng.uniform(.82, 1.22)
                width = ll * (.13 if narrow else (.26 if self.kind == "laurel" else .29))
                self.leaf(origin, ray, ll, width, rng.uniform(-.65, .65),
                          rng.randrange(4), phase)
        self.leaf(end, direction + self.up*.15, leaf_length, leaf_length*.24,
                  rng.uniform(-.4, .4), rng.randrange(4), phase)

    def grow_elm(self) -> None:
        V, up = self.Vector, self.up
        rng = random.Random(SEEDS[self.kind])
        trunk = [V(p) for p in ((0,0,0),(.05,.03,.35),(.02,.08,1.12),(.14,.04,2.05),
                                (.3,.01,3.3),(.19,.15,4.65),(.16,.22,5.9),(.35,.2,7.22))]
        self.wood(trunk, [.53,.39,.35,.285,.22,.146,.077,.022], .32, major=True)
        for i in range(8):
            angle = i * TAU / 8 + .23 + rng.uniform(-.14,.14)
            ray = self.radial(angle)
            root = [ray * rng.uniform(.54, .91), ray*.32+up*.12, ray*.13+up*.4]
            self.wood(root, [.012,.09,.19], .32, major=True)
        for i in range(10):
            sub = random.Random(SEEDS[self.kind] + i * 619)
            rank = i / 9
            phase = sub.random()
            angle = i * 2.39996 + .27 + sub.uniform(-.16, .16)
            z = 1.95 + rank * 3.5
            start = V((.18,.08,z))
            ray = self.radial(angle)
            reach = 3.2 * (1 - .48 * rank) * sub.uniform(.91,1.13)
            end = start + ray*reach
            end.z = 4.9 + rank*2.45 + sub.uniform(-.24,.24)
            mid, shoulder = self.branch(start, end, .139*(1-.62*rank), sub, phase, major=True)
            for j in range(6):
                t = .15 + .15*j
                origin = mid.lerp(end, t)
                heading = angle + j * 2.39996 + sub.uniform(-.3,.3)
                secondary = end + self.radial(heading)*sub.uniform(.42,1.04)
                secondary.z += sub.uniform(-.72,.86)
                self.branch(origin, secondary, .039*(1-.08*j), sub, phase)
                for k in range(4):
                    terminal_rng = random.Random(SEEDS[self.kind] + i*10000 + j*100 + k)
                    node = origin.lerp(secondary, .42+.16*k)
                    a = heading + k * TAU / 4 + terminal_rng.uniform(-.28,.28)
                    tip = secondary + self.radial(a)*terminal_rng.uniform(.28,.68)
                    tip.z += terminal_rng.uniform(-.38,.54)
                    self.leafy_twig(node, tip, terminal_rng, phase, .2, count=14)
        self.leafy_twig(trunk[-2], trunk[-1]+up*.62, random.Random(7181), .53, .18, count=24)

    def grow_cypress(self) -> None:
        V, up = self.Vector, self.up
        rng = random.Random(SEEDS[self.kind])
        points = [V((.075*math.sin(t*.8), .04*math.sin(t), t)) for t in (0,.25,1.3,2.6,4,5.5,7,8.1,8.6)]
        self.wood(points, [.3,.235,.2,.166,.13,.09,.052,.019,.0025], .45, major=True)
        for i in range(5):
            ray = self.radial(i*TAU/5)
            self.wood([ray*.53,ray*.25+up*.14,up*.3], [.015,.071,.16], .45, major=True)
        # Upright spiralling boughs produce an irregular column rather than a cone.
        for i in range(56):
            sub = random.Random(SEEDS[self.kind] + i*173)
            rank = i / 55
            z = .68 + rank*7.12
            width = .57 * math.sin((.22 + rank*.72)*math.pi)**.65
            angle = i*2.39996
            phase = sub.random()
            base = V((.04,0,z))
            end = base + self.radial(angle)*width
            end.z += .52 + .35*(1-rank)
            self.branch(base, end, .052*(1-.72*rank), sub, phase)
            for j in range(5):
                t = .24 + .18*j
                origin = base.lerp(end, t)
                a = angle + (1 if j%2 else -1)*sub.uniform(.48,1.18)
                tip = origin + self.radial(a)*sub.uniform(.13,.28) + up*sub.uniform(.36,.64)
                self.leafy_twig(origin, tip, sub, phase, .22, count=9, narrow=True)

    def grow_laurel(self) -> None:
        V, up = self.Vector, self.up
        for i in range(13):
            sub = random.Random(SEEDS[self.kind]+i*149)
            a = i*2.39996
            spread = .19 + .49*(i/12)**.7
            h = 1.47 + sub.uniform(-.24,.25) - .25*(i/12)
            start = self.radial(a)*sub.uniform(.02,.15)
            end = self.radial(a)*spread + up*h
            phase = sub.random()
            self.branch(start, end, sub.uniform(.024,.041), sub, phase, major=True)
            for j in range(5):
                origin = start.lerp(end, .31+j*.13)
                ray = self.radial(a + (1 if j%2 else -1)*sub.uniform(.55,1.4))
                tip = origin + ray*sub.uniform(.28,.54) + up*sub.uniform(.19,.39)
                self.leafy_twig(origin, tip, sub, phase, .2, count=8)

    def build(self):
        {"field_elm": self.grow_elm, "cypress": self.grow_cypress,
         "laurel": self.grow_laurel}[self.kind]()
        # Embed/export a bottom-centred plant, root tips exactly on the ground.
        lowest = min(p[2] for p in self.vertices)
        self.vertices = [(x, y, z - lowest) for x, y, z in self.vertices]
        # Anchor vertices at/below the first 8cm, including all root tip lobes.
        self.colors = [(0.0, 0.0, c[2], 1.0) if p[2] < .08 else
                       (0.6 * smoothstep(.08, self.height, p[2]), c[1], c[2], 1.0)
                       for p, c in zip(self.vertices, self.colors)]
        return self

    def object(self, name: str, materials):
        import bpy
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        for material in materials:
            mesh.materials.append(material)
        uv_layer = mesh.uv_layers.new(name="BarkAndLeafAtlas")
        wind = mesh.color_attributes.new(name="WindWeights", type="FLOAT_COLOR", domain="POINT")
        mesh.color_attributes.active_color_index = 0
        mesh.color_attributes.render_color_index = 0
        for index, color in enumerate(self.colors):
            wind.data[index].color = color
        for polygon, uv, mat_index, smooth in zip(mesh.polygons, self.uvs, self.materials, self.smooth):
            polygon.material_index = mat_index
            polygon.use_smooth = smooth
            for loop_index, coordinate in zip(polygon.loop_indices, uv):
                uv_layer.data[loop_index].uv = coordinate
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj["wind_contract"] = "COLOR_0: R=bend, G=leaf flutter, B=branch phase, A=1; never albedo"
        obj["units"] = "metres"
        obj["kind"] = self.kind
        obj["lod"] = self.lod
        obj["origin"] = "Original IMPERATHEN procedural art; not a scan"
        return obj


def make_material(name: str, paths: dict[str, Path], foliage: bool):
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = not foliage
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .78
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Specular IOR Level"].default_value = .28
    textures = {}
    for suffix, path in paths.items():
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.name = suffix
        tex.image = bpy.data.images.load(str(path), check_existing=True)
        if suffix != "albedo":
            tex.image.colorspace_settings.name = "Non-Color"
        tex.image.pack()
        tex.extension = "REPEAT"
        textures[suffix] = tex
    mat.node_tree.links.new(textures["albedo"].outputs["Color"], shader.inputs["Base Color"])
    mat.node_tree.links.new(textures["roughness"].outputs["Color"], shader.inputs["Roughness"])
    normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = .75 if foliage else .8
    mat.node_tree.links.new(textures["normal"].outputs["Color"], normal.inputs["Color"])
    mat.node_tree.links.new(normal.outputs["Normal"], shader.inputs["Normal"])
    # No ColorAttribute node: wind data must never tint the beauty source.
    return mat


def read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise ValueError(f"Not GLB: {path}")
    version, length = struct.unpack_from("<II", raw, 4)
    if version != 2 or length != len(raw):
        raise ValueError(f"Invalid GLB header: {path}")
    position, document, binary = 12, None, b""
    while position < len(raw):
        chunk_length, chunk_type = struct.unpack_from("<II", raw, position)
        body = raw[position+8:position+8+chunk_length]
        if len(body) != chunk_length:
            raise ValueError(f"Truncated GLB: {path}")
        if chunk_type == 0x4E4F534A:
            document = json.loads(body)
        elif chunk_type == 0x004E4942:
            binary = body
        position += 8 + chunk_length
    if document is None:
        raise ValueError(f"GLB has no JSON: {path}")
    return document, binary


def accessor_values(doc: dict, binary: bytes, index: int) -> np.ndarray:
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    types = {5126: "<f4", 5123: "<u2", 5121: "u1", 5125: "<u4"}
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    dtype = np.dtype(types[acc["componentType"]])
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", dtype.itemsize * components)
    values = np.ndarray((acc["count"], components), dtype=dtype, buffer=binary,
                        offset=offset, strides=(stride, dtype.itemsize)).astype(np.float64)
    if acc.get("normalized") and acc["componentType"] != 5126:
        values /= np.iinfo(dtype).max
    return values


def inspect_glb(path: Path) -> dict:
    doc, binary = read_glb(path)
    primitives = [p for mesh in doc.get("meshes", []) for p in mesh["primitives"]]
    if len(primitives) != 2:
        raise ValueError(f"Expected exactly two surfaces, found {len(primitives)}: {path}")
    triangles = 0
    color_ranges, positions = [], []
    for prim in primitives:
        attributes = prim["attributes"]
        for required in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
            if required not in attributes:
                raise ValueError(f"Missing {required}: {path}")
        points = accessor_values(doc, binary, attributes["POSITION"])
        colors = accessor_values(doc, binary, attributes["COLOR_0"])
        if not np.isfinite(points).all() or not np.isfinite(colors).all():
            raise ValueError(f"Non-finite geometry/wind: {path}")
        if np.min(colors) < -1e-5 or np.max(colors) > 1.00001:
            raise ValueError(f"Wind outside 0..1: {path}")
        if not np.allclose(colors[:, 3], 1):
            raise ValueError(f"Wind alpha must remain 1: {path}")
        positions.append(points)
        color_ranges.append({"min": colors.min(axis=0).tolist(), "max": colors.max(axis=0).tolist()})
        if "indices" in prim:
            triangles += doc["accessors"][prim["indices"]]["count"] // 3
        else:
            triangles += len(points) // 3
        material = doc["materials"][prim["material"]]
        pbr = material.get("pbrMetallicRoughness", {})
        if "baseColorTexture" not in pbr or "normalTexture" not in material or "metallicRoughnessTexture" not in pbr:
            raise ValueError(f"Missing exported PBR texture: {path}")
        if "Bark" in material.get("name", "") and not np.allclose(colors[:, 1], 0):
            raise ValueError(f"Bark has leaf flutter: {path}")
    joined = np.concatenate(positions)
    if abs(joined[:, 1].min()) > .001:
        raise ValueError(f"Export is not grounded Y-up: {path}")
    foliage = next(m for m in doc["materials"] if "Foliage" in m["name"])
    if not foliage.get("doubleSided") or foliage.get("alphaMode", "OPAQUE") != "OPAQUE":
        raise ValueError(f"Foliage must be opaque and double-sided: {path}")
    for im in doc.get("images", []):
        if "bufferView" not in im:
            raise ValueError(f"Textures must be embedded: {path}")
    return {"file": path.name, "triangles": triangles, "surfaces": len(primitives),
            "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bounds_gltf_y_up": {"min": joined.min(axis=0).tolist(), "max": joined.max(axis=0).tolist()},
            "wind_channels": color_ranges, "embedded_images": len(doc.get("images", []))}


def export_plant(kind: str, lod: int, root: Path, maps: dict) -> dict:
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    plant = PlantMesh(kind, lod).build()
    mats = [make_material(kind+"_Bark", maps["bark"], False),
            make_material(kind+"_Foliage", maps["foliage"], True)]
    obj = plant.object(f"{kind}_lod{lod}", mats)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.preferences.filepaths.save_version = 0
    if lod == 0:
        bpy.ops.wm.save_as_mainfile(filepath=str(root/ART_REL/f"{kind}.blend"), compress=True)
    destination = root/ASSET_REL/f"{kind}_lod{lod}.glb"
    settings = {"filepath": str(destination), "export_format": "GLB", "use_selection": True,
                "export_animations": False, "export_yup": True, "export_normals": True,
                "export_texcoords": True, "export_tangents": True, "export_extras": True,
                "export_cameras": False, "export_lights": False}
    properties = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_vertex_color" in properties:
        settings["export_vertex_color"] = "ACTIVE"
    elif "export_colors" in properties:
        settings["export_colors"] = True
    if "export_all_vertex_colors" in properties:
        settings["export_all_vertex_colors"] = True
    bpy.ops.export_scene.gltf(**settings)
    report = inspect_glb(destination)
    report.update({"kind": kind, "lod": lod, "texture_size": 1024 >> lod, "wood_segments": plant.wood_segments,
                   "leaf_meshes": plant.visible_leaves, "logical_leaves": plant.logical_leaves})
    print("VEGETATION_EXPORTED " + json.dumps(report), flush=True)
    return report


def preview_materials() -> None:
    """Match runtime's texture albedo while ignoring COLOR_0 wind data.

    glTF viewers multiply vertex colours into the material by specification. Our
    runtime wind shader does not; reconnect the imported base image the same way.
    Geometry, UVs, normal maps and roughness remain the exported asset bytes.
    """
    import bpy
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        shader = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        texture = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image
                        and ("albedo" in n.image.name.lower() or "base color" in n.label.lower())), None)
        if shader and texture:
            mat.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])


def setup_camera(position, target, scale: float):
    import bpy
    from mathutils import Vector
    bpy.ops.object.camera_add(location=position)
    camera = bpy.context.object
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = scale
    bpy.context.scene.camera = camera
    return camera


def render_review(root: Path, samples: int = 24) -> None:
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 6
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = .5
    world = bpy.data.worlds.new("Mediterranean daylight")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.50,.63,.78,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .58
    scene.world = world
    for kind, position in (("field_elm",(-3.1,0,0)),("cypress",(3.6,.5,0)),("laurel",(5.5,-1.8,0))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(root/ASSET_REL/f"{kind}_lod0.glb"))
        for obj in set(bpy.data.objects) - before:
            if obj.parent is None:
                obj.location += __import__("mathutils").Vector(position)
    preview_materials()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.015))
    ground = bpy.context.object
    mat = bpy.data.materials.new("Review sand")
    mat.diffuse_color = (.33,.29,.21,1)
    ground.data.materials.append(mat)
    bpy.ops.object.light_add(type="SUN", location=(0,0,12))
    light = bpy.context.object
    light.rotation_euler = (math.radians(28), math.radians(-23), math.radians(-35))
    light.data.energy = 3.1
    light.data.angle = math.radians(2.5)
    light.data.color = (1.0,.89,.72)
    setup_camera((13,-23,11),(.2,0,4.1),20.0)
    out = root/ART_REL/"review"
    out.mkdir(exist_ok=True)
    scene.render.filepath = str(out/"vegetation_overview.png")
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    camera = scene.camera
    from mathutils import Vector
    camera.location = Vector((-1.5,-3.8,1.65))
    target = Vector((-3.0,.05,1.55))
    camera.rotation_euler = (target-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = 2.7
    scene.render.filepath = str(out/"elm_bark_closeup.png")
    bpy.ops.render.render(write_still=True)
    camera.location = Vector((8.1,-5.0,2.0))
    target = Vector((5.5,-1.8,1.12))
    camera.rotation_euler = (target-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = 1.45
    scene.render.filepath = str(out/"laurel_leaf_closeup.png")
    bpy.ops.render.render(write_still=True)
    report = {"engine": "Blender Cycles CPU", "blender": bpy.app.version_string,
              "samples": samples, "threads": 2, "source": "reimported LOD0 GLBs",
              "wind": "static pose; COLOR_0 excluded from albedo exactly as runtime wind shader",
              "images": ["vegetation_overview.png", "elm_bark_closeup.png", "laurel_leaf_closeup.png"]}
    (out/"render_report.json").write_text(json.dumps(report, indent=2)+"\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--kinds", nargs="+", choices=KINDS, default=list(KINDS))
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--render-only", action="store_true")
    parser.add_argument("--samples", type=int, default=24)
    argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    args = parser.parse_args(argv)
    root = args.root.resolve()
    (root/ART_REL).mkdir(parents=True, exist_ok=True)
    (root/ASSET_REL).mkdir(parents=True, exist_ok=True)
    if not args.render_only:
        records = []
        for kind in args.kinds:
            maps = generate_textures(kind, root/ART_REL/"textures")
            per_kind = [export_plant(kind, lod, root, texture_lod(maps, lod)) for lod in range(3)]
            if not per_kind[0]["triangles"] > per_kind[1]["triangles"] > per_kind[2]["triangles"]:
                raise RuntimeError(f"LOD triangle count must strictly decrease: {kind}")
            records.extend(per_kind)
        report = {"generator": "tools/world_art/vegetation.py", "original_art": True,
                  "not_a_scan": True, "units": "metres, Y-up glTF",
                  "wind_contract": {"R": "bend weight", "G": "leaf flutter", "B": "stable branch phase", "A": "1"},
                  "texture_sizes_by_lod": [1024,512,256], "records": records}
        (root/ART_REL/"build_report.json").write_text(json.dumps(report, indent=2)+"\n")
    if args.render or args.render_only:
        render_review(root, args.samples)


if __name__ == "__main__":
    main()
