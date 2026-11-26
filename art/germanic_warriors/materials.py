"""Blender materials from the NumPy surfaces (albedo, normal, roughness/metal)."""
from __future__ import annotations

import bpy
import numpy as np

import surfaces

_cache = {}


def image(name, rgb, data=False):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, width=w, height=h, is_data=data)
    if data:
        # Set before the pixels: changing it later regenerates a blank image.
        img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((h, w, 4), dtype=np.float32)
    # Surface rows run along +V, as Blender's pixel rows do (bottom first).
    rgba[:, :, :3] = rgb if rgb.ndim == 3 else np.repeat(rgb[:, :, None], 3, axis=2)
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def pbr(name, surface, normal_strength=1.0, roughness_scale=1.0):
    """Principled material wired the way the glTF exporter packs it."""
    key = name
    if key in _cache:
        return _cache[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Specular IOR Level"].default_value = .35
    albedo = nodes.new("ShaderNodeTexImage")
    albedo.image = image(name + "_albedo", surface["albedo"])
    links.new(albedo.outputs["Color"], shader.inputs["Base Color"])
    orm = np.stack((np.ones_like(surface["roughness"]), np.clip(surface["roughness"] * roughness_scale, 0, 1),
                    surface["metallic"]), axis=2)
    finish = nodes.new("ShaderNodeTexImage")
    finish.image = image(name + "_orm", orm, data=True)
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(finish.outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Green"], shader.inputs["Roughness"])
    links.new(split.outputs["Blue"], shader.inputs["Metallic"])
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(name + "_normal", surface["normal"], data=True)
    mapper = nodes.new("ShaderNodeNormalMap")
    mapper.inputs["Strength"].default_value = normal_strength
    links.new(normal.outputs["Color"], mapper.inputs["Color"])
    links.new(mapper.outputs["Normal"], shader.inputs["Normal"])
    mat.use_backface_culling = False
    _cache[key] = mat
    return mat


def reset():
    _cache.clear()


def cloth(name, spec, seed, size=512):
    kind = spec.get("weave", "twill")
    threads = spec.get("threads", 96)
    if kind == "linen":
        surface = surfaces.linen(size, seed, spec["colour"], threads)
    else:
        check = None
        if spec.get("check"):
            c = spec["check"]
            check = (c["colour"], c["band"], c["period"])
        stripe = None
        if spec.get("stripe"):
            st = spec["stripe"]
            stripe = (st["colour"], st["start"], st["width"])
        surface = surfaces.wool(size, seed, spec["colour"], threads, kind, check, stripe, spec.get("fulled", .35))
    return pbr(name, surface)


def named(name, kind, seed, size=512, **kw):
    maker = {"leather": surfaces.leather, "fur": surfaces.fur, "hair": surfaces.hair,
             "wood": surfaces.wood, "iron": surfaces.iron, "bronze": surfaces.bronze}[kind]
    return pbr(name, maker(size, seed, **kw))


def mail(name, seed, size=512, rust=.25):
    """Riveted ring mail: interlinked rings as a height field over iron."""
    f = surfaces.Field(size, seed)
    rings = 24
    x, y = f.u * rings, f.v * rings * 1.15
    row = np.floor(y)
    xs = x + .5 * (row % 2)
    fx, fy = xs - np.floor(xs) - .5, y - row - .5
    r = np.hypot(fx * 1.0, fy * 1.15)
    ring = surfaces.smooth(.30, .36, r) * (1 - surfaces.smooth(.44, .50, r))
    base = surfaces.iron(size, seed + 3, rust)
    height = ring
    normal = surfaces.normal_from_height(height, .0035)
    albedo = base["albedo"] * (.25 + .85 * ring[..., None])
    rough = base["roughness"] * (.85 + .3 * (1 - ring))
    metal = base["metallic"] * ring
    return pbr(name, {"albedo": albedo, "normal": normal, "roughness": rough, "metallic": metal})


def eye(name, colour, size=512):
    """Opaque iris atlas for the existing two-eye UV layout (as neutral_eyes)."""
    n = size
    yy, xx = np.mgrid[0:n, 0:n] / (n - 1)
    pixels = np.ones((n, n, 3))
    pixels[:, :, :] = (.82, .835, .81)
    base = np.array(colour)
    for cx, cy in ((.291, .291), (.709, .709)):
        r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        a = np.arctan2(yy - cy, xx - cx)
        iris = r < .116
        pupil = r < .036
        fibres = .5 + .5 * np.sin(a * 103 + np.sin(a * 19) * 3 + r * 180)
        band = np.clip((.116 - r) / .012, 0, 1) * np.clip((r - .036) / .014, 0, 1)
        limbal = np.clip((r - .095) / .021, 0, 1)
        for c in range(3):
            colour_c = .02 + band * (base[c] * (.75 + .45 * fibres)) * (1 - .55 * limbal)
            pixels[:, :, c] = np.where(iris, colour_c, pixels[:, :, c])
            pixels[:, :, c] = np.where(pupil, .008, pixels[:, :, c])
    mat = bpy.data.materials.get("FrontierEye")
    copy = mat.copy()
    copy.name = name
    for node in copy.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            node.image = image(name + "_iris", pixels)
    return copy
