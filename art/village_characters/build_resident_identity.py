"""Individual identity layer for the village resident cast.

The three civilian frontier sources (art/frontier_people/civilian_man.blend,
civilian_woman.blend and elder.blend) stay unchanged. This pass opens each one,
adds per-person controls and exports the same runtime tiers
prototype/assets/characters/frontier_<kind>_<0..3>.glb, so the existing rig,
the eleven clips, the motion-gate family and every VillagePerson route remain.

Added on every tier (identity data is the same at every distance):
* face shape keys (ID_*) - bipolar geometry controls for nose, jaw, chin,
  cheeks, brow, lips, ears, face length and age sag;
* body keys (ID_Heavy, ID_Shoulders) applied identically to skin and garments
  so the clearance between them is preserved;
* hair keys (HAIR_*) - shorter, receding, fuller and longer at the nape;
* optional pieces, collapsed into the body until a resident enables ID_Show:
  IdentityBeard (+BEARD_Full), IdentityApron, IdentityMantle, IdentityVeil
  (+VEIL_Long), IdentityCap, and on the two near tiers IdentityPouch,
  IdentityBrooch, IdentityEarrings;
* ID_Hem on the tunic skirt (longer/shorter hem);
* a neutral linen texture so runtime dyes are actual colours, not a multiply
  on a fixed ochre.
Expression morphs (Blink/JawOpen/Smile/BrowDown) stay on the two near tiers only.

Also written: identity mask textures for the resident skin shader
(prototype/assets/village_characters/identity/<kind>_skin_mask.png: R beard,
G creases/age spots, B sun exposure, A flush; <kind>_skin_detail.png: RG
crease normal, B scalp, A eyebrow) and the shared strand/wool/leather textures embedded
in the GLBs. Everything is procedural; nothing is downloaded.

blender -b -t 2 -P art/village_characters/build_resident_identity.py [-- --kinds civilian_man]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import tempfile
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/frontier_people"
OUT = ROOT / "prototype/assets/characters"
TEXTURES = ROOT / "prototype/assets/village_characters/identity"
REPORT = ROOT / "art/village_characters/resident_identity_report.json"
KINDS = ("civilian_man", "civilian_woman", "elder")
LOD = ((0, .62, 1024), (1, .24, 512), (2, .075, 256), (3, .025, 128))
# The existing frontier_people_test budgets count every mesh, hidden or not.
BUDGET = (24000, 10000, 3500, 1300)
EXPRESSION = ("Blink_L", "Blink_R", "JawOpen", "Smile", "BrowDown")
FACE_KEYS = ("ID_NoseLength", "ID_NoseWidth", "ID_NoseBridge", "ID_JawWidth", "ID_Chin",
             "ID_FaceLength", "ID_Cheeks", "ID_Cheekbones", "ID_Brow", "ID_Lips", "ID_Ears",
             "ID_EyeDepth", "ID_Age")
BODY_KEYS = ("ID_Heavy", "ID_Shoulders")
HAIR_KEYS = ("HAIR_Short", "HAIR_Recede", "HAIR_Volume", "HAIR_Nape")
NEAR_ONLY = ("IdentityPouch", "IdentityBrooch", "IdentityEarrings")
PIECES = ("IdentityBeard", "IdentityHairBound", "IdentityApron", "IdentityMantle", "IdentityVeil", "IdentityCap") + NEAR_ONLY
KIND_PIECES = {
    "civilian_man": ("IdentityBeard", "IdentityApron", "IdentityMantle", "IdentityCap", "IdentityPouch", "IdentityBrooch"),
    "civilian_woman": ("IdentityHairBound", "IdentityApron", "IdentityMantle", "IdentityVeil", "IdentityPouch", "IdentityBrooch", "IdentityEarrings"),
    "elder": ("IdentityBeard", "IdentityApron", "IdentityMantle", "IdentityCap", "IdentityPouch", "IdentityBrooch"),
}
# Face controls are authored at a common scale; catalog weights stay in [-1, 1].
FACE_GAIN = 1.45
SEED = 58


# --------------------------------------------------------------------------
# small numeric helpers


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(P, c, r):
    d = (P - np.asarray(c, dtype=float)) / np.asarray(r, dtype=float)
    return np.exp(-(d * d).sum(axis=1))


def mirrored(P):
    """Symmetric features are authored for +x and mirrored by sign."""
    Q = P.copy()
    s = np.where(P[:, 0] < 0.0, -1.0, 1.0)
    Q[:, 0] = np.abs(Q[:, 0])
    return Q, s


def hash_noise(P, cell):
    """Deterministic value noise from 3D positions (no external library)."""
    q = np.floor(P / cell).astype(np.int64)
    h = (q[:, 0] * 73856093) ^ (q[:, 1] * 19349663) ^ (q[:, 2] * 83492791) ^ SEED
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(float) / 65535.0


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


# --------------------------------------------------------------------------
# mesh access


def coords(obj, key=None):
    data = (key.data if key is not None else obj.data.vertices)
    values = np.empty(len(data) * 3)
    data.foreach_get("co", values)
    return values.reshape(-1, 3)


def set_coords(target, values):
    target.foreach_set("co", np.ascontiguousarray(values, dtype=float).ravel())


def vertex_normals(obj):
    values = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("normal", values)
    return values.reshape(-1, 3)


def group_weight(obj, prefixes):
    """Summed deform weight of vertex groups whose names start with a prefix."""
    wanted = {g.index for g in obj.vertex_groups if g.name.startswith(prefixes)}
    result = np.zeros(len(obj.data.vertices))
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in wanted:
                result[v.index] += g.weight
    return np.clip(result, 0.0, 1.0)


def ensure_basis(obj):
    if not obj.data.shape_keys:
        obj.shape_key_add(name="Basis", from_mix=False)
    return obj.data.shape_keys.key_blocks[0]


def add_key(obj, name, delta):
    """Add a relative key from a per-vertex delta; skipped when it is a no-op."""
    if delta is None or np.abs(delta).max() < 5e-5:
        return False
    basis = ensure_basis(obj)
    key = obj.data.shape_keys.key_blocks.get(name) or obj.shape_key_add(name=name, from_mix=False)
    set_coords(key.data, coords(obj, basis) + delta)
    key.value = 0.0
    return True


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def check_identity_matrices():
    for obj in meshes():
        if (np.abs(np.array(obj.matrix_world) - np.eye(4)) > 1e-6).any():
            raise RuntimeError(obj.name + " must have an identity world matrix")


# --------------------------------------------------------------------------
# landmarks


def landmarks(body, eyes):
    P = coords(body)
    E = coords(eyes)
    head = P[P[:, 2] > 1.25]
    ez = float(E[:, 2].mean())
    ex = float(np.abs(E[:, 0]).mean())
    ey = float(E[:, 1].min())
    mid = head[np.abs(head[:, 0]) < .004]
    band = mid[(mid[:, 2] > ez - .06) & (mid[:, 2] < ez - .01)]
    tip = band[np.argmin(band[:, 1])]

    def front(z):
        s = head[(np.abs(head[:, 0]) < .006) & (np.abs(head[:, 2] - z) < .004)]
        return float(s[:, 1].min())

    nz, ny = float(tip[2]), float(tip[1])
    mz = nz - .033
    cz = nz - .058
    ear = head[(np.abs(head[:, 0]) > .066) & (head[:, 1] > -.07) & (head[:, 1] < .01) & (np.abs(head[:, 2] - ez) < .045)]
    return {"ez": ez, "ex": ex, "ey": ey, "nz": nz, "ny": ny, "mz": mz, "my": front(mz), "cz": cz, "cy": front(cz),
            "fy": front(ez + .045), "top": float(head[:, 2].max()),
            "ear_x": float(np.abs(ear[:, 0]).min()) if len(ear) else .068,
            "ear_low": float(ear[:, 2].min()) if len(ear) else ez - .035}


# --------------------------------------------------------------------------
# face, body and hair deltas (functions of rest position)


def face_delta(name, P, L):
    ez, ex, ny, nz, mz, my, cz, cy = L["ez"], L["ex"], L["ny"], L["nz"], L["mz"], L["my"], L["cz"], L["cy"]
    D = np.zeros_like(P)
    Q, s = mirrored(P)
    front = smooth(-.02, -.06, P[:, 1])  # never deform the back of the skull
    if name == "ID_NoseLength":
        w = gauss(P, (0, ny + .006, nz - .002), (.015, .016, .015)) * (P[:, 1] < ny + .03)
        D[:, 1] -= .0055 * w
        D[:, 2] -= .0022 * w
        b = gauss(P, (0, ny + .012, (ez + nz) / 2), (.008, .018, .018))
        D[:, 1] -= .0016 * b
    elif name == "ID_NoseWidth":
        w = gauss(Q, (.012, ny + .013, nz - .004), (.011, .014, .010))
        D[:, 0] += s * .0035 * w
        D[:, 1] -= .0008 * w
    elif name == "ID_NoseBridge":
        w = gauss(P, (0, ny + .013, (ez + nz) / 2 - .002), (.007, .018, .011))
        D[:, 1] -= .0032 * w
        t = gauss(P, (0, ny, nz - .002), (.008, .010, .007))
        D[:, 2] -= .0012 * t
    elif name == "ID_JawWidth":
        lateral = smooth(.010, .045, Q[:, 0])
        height = np.exp(-((P[:, 2] - (cz + .012)) / .026) ** 2) * smooth(1.252, 1.272, P[:, 2])
        w = lateral * height * front * (Q[:, 0] < .075)
        D[:, 0] += s * .0075 * w
    elif name == "ID_Chin":
        w = gauss(P, (0, cy, cz - .002), (.019, .022, .016)) * smooth(1.255, 1.270, P[:, 2])
        D[:, 1] -= .0060 * w
        D[:, 2] -= .0022 * w
    elif name == "ID_FaceLength":
        t = np.clip((nz - .004 - P[:, 2]) / (nz - .004 - (cz - .008)), 0.0, 1.0)
        below = smooth(1.250, 1.276, P[:, 2])
        w = t * below * front
        D[:, 2] -= .0095 * w
    elif name == "ID_Cheeks":
        w = gauss(Q, (.042, -.112, mz + .012), (.018, .020, .020))
        D[:, 0] += s * .0035 * w
        D[:, 1] -= .0028 * w
    elif name == "ID_Cheekbones":
        w = gauss(Q, (.050, -.106, ez - .018), (.013, .016, .011))
        D[:, 0] += s * .0030 * w
        D[:, 1] -= .0020 * w
        D[:, 2] += .0005 * w
    elif name == "ID_Brow":
        w = gauss(Q, (.020, L["ey"] - .010, ez + .018), (.026, .016, .009))
        D[:, 1] -= .0034 * w
        D[:, 2] += .0004 * w
    elif name == "ID_Lips":
        w = gauss(P, (0, my, mz), (.020, .012, .010))
        D[:, 1] -= .0024 * w
        D[:, 2] += .0014 * w * np.tanh((P[:, 2] - mz) / .003)
    elif name == "ID_Ears":
        ear = smooth(L["ear_x"] - .004, L["ear_x"] + .002, Q[:, 0]) * smooth(.02, -.01, P[:, 1]) * smooth(-.085, -.065, P[:, 1])
        ear *= np.exp(-((P[:, 2] - (ez - .006)) / .032) ** 2)
        root = np.array([L["ear_x"], -.035, ez - .006])
        local = Q - root
        D[:, 0] += s * (.22 * local[:, 0] + .0035) * ear
        D[:, 1] += .22 * local[:, 1] * ear
        D[:, 2] += .22 * local[:, 2] * ear
    elif name == "ID_EyeDepth":
        w = gauss(Q, (ex, L["ey"] + .004, ez + .009), (.014, .012, .006)) + .7 * gauss(Q, (ex, L["ey"] + .004, ez - .011), (.012, .010, .005))
        D[:, 1] += .0015 * w
    elif name == "ID_Age":
        jowl = gauss(Q, (.044, -.096, cz + .010), (.015, .020, .015))
        D[:, 0] += s * .0020 * jowl
        D[:, 1] -= .0010 * jowl
        D[:, 2] -= .0042 * jowl
        bag = gauss(Q, (ex, L["ey"] - .002, ez - .014), (.012, .010, .0055))
        D[:, 1] -= .0016 * bag
        D[:, 2] -= .0010 * bag
        fold = gauss(Q, (.027, -.129, nz - .012), (.008, .010, .012))
        D[:, 1] -= .0017 * fold
        tip = gauss(P, (0, ny, nz), (.008, .010, .008))
        D[:, 1] -= .0006 * tip
        D[:, 2] -= .0018 * tip
        wattle = gauss(P, (0, -.095, 1.268), (.022, .022, .012))
        D[:, 2] -= .0040 * wattle
        brow = gauss(Q, (.040, -.120, ez + .012), (.012, .012, .008))
        D[:, 2] -= .0015 * brow
        lips = gauss(P, (0, my, mz), (.020, .010, .008))
        D[:, 1] += .0010 * lips
    else:
        raise KeyError(name)
    D *= (P[:, 2] > 1.235)[:, None]
    return D * FACE_GAIN


def body_delta(name, P, arm):
    D = np.zeros_like(P)
    z = P[:, 2]
    torso = 1.0 - arm
    if name == "ID_Heavy":
        axis = np.array([0.0, -.025])
        radial = P[:, :2] - axis
        length = np.maximum(np.linalg.norm(radial, axis=1), 1e-6)
        direction = radial / length[:, None]
        amount = (.024 * np.exp(-((z - 1.00) / .105) ** 2) + .010 * np.exp(-((z - 1.17) / .070) ** 2)
                  + .010 * np.exp(-((z - .880) / .060) ** 2))
        amount *= 1.0 + .55 * np.clip(-direction[:, 1], 0.0, 1.0)
        amount *= torso * (np.abs(P[:, 0]) < .19)
        D[:, :2] = direction * amount[:, None]
        neck = np.exp(-((z - 1.255) / .02) ** 2) * (np.abs(P[:, 0]) < .07)
        D[:, :2] += direction * (.0035 * neck * torso)[:, None]
    elif name == "ID_Shoulders":
        side = np.where(P[:, 0] < 0.0, -1.0, 1.0)
        shoulder = smooth(1.08, 1.21, z) * smooth(.045, .15, np.abs(P[:, 0])) * (z < 1.30)
        D[:, 0] += side * .011 * np.maximum(shoulder * torso, arm)
    else:
        raise KeyError(name)
    return D


def hair_deltas(obj, bvh, L):
    P = coords(obj)
    short = np.zeros_like(P)
    recede = np.zeros_like(P)
    volume = np.zeros_like(P)
    nape = np.zeros_like(P)
    centre = np.array([0.0, -.045, L["ez"] + .02])
    for i, p in enumerate(P):
        hit = bvh.find_nearest(Vector(p))
        if hit[0] is None:
            continue
        surface = np.array(hit[0])
        normal = np.array(hit[1])
        out = p - surface
        height = float(np.dot(out, normal))
        if height > .0025:
            short[i] = -(height - .0025) * .62 * normal
        frontal = float(smooth(-.080, -.112, p[1:2])[0]) * float(smooth(L["ez"] + .028, L["ez"] + .050, p[2:3])[0])
        temple = float(smooth(.030, .055, abs(p[0:1]))[0]) * float(smooth(-.055, -.090, p[1:2])[0]) * float(smooth(L["ez"] + .005, L["ez"] + .030, p[2:3])[0])
        amount = max(frontal, .8 * temple)
        if amount > 0.0:
            recede[i] = (surface - .0045 * normal - p) * amount
        radial = p - centre
        radial /= max(np.linalg.norm(radial), 1e-6)
        volume[i] = radial * .0055 * (1.0 + .5 * math.sin(p[0] * 210.0) * math.sin(p[2] * 190.0))
        back = float(smooth(-.010, .025, p[1:2])[0]) * float(smooth(1.415, 1.36, p[2:3])[0])
        nape[i] = np.array([0.0, .004, -.026]) * back
    return {"HAIR_Short": short, "HAIR_Recede": recede, "HAIR_Volume": volume, "HAIR_Nape": nape}


# --------------------------------------------------------------------------
# procedural textures (embedded in the GLB or written next to the shader)


def image_from_array(name, values, colorspace="sRGB"):
    h, w, _ = values.shape
    image = bpy.data.images.new(name, width=w, height=h, alpha=True)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(np.clip(values, 0.0, 1.0).astype(np.float32).ravel())
    image.pack()
    return image


def height_to_normal(height, strength):
    gy, gx = np.gradient(height)
    n = np.dstack((-gx * strength, -gy * strength, np.ones_like(height)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * .5 + .5


def fbm(shape, scales, rng):
    h, w = shape
    total = np.zeros(shape)
    for scale, amp in scales:
        small = rng.random((max(2, h // scale), max(2, w // scale)))
        yy = np.linspace(0, small.shape[0] - 1.001, h)
        xx = np.linspace(0, small.shape[1] - 1.001, w)
        y0, x0 = yy.astype(int), xx.astype(int)
        fy, fx = (yy - y0)[:, None], (xx - x0)[None, :]
        a = small[y0][:, x0]
        b = small[y0][:, x0 + 1]
        c = small[y0 + 1][:, x0]
        d = small[y0 + 1][:, x0 + 1]
        total += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
    return total


def strand_textures(rng):
    h, w = 256, 256
    columns = rng.random(w)
    phase = np.cumsum(rng.normal(0, .35, (h, 1)), axis=0) * .15
    x = (np.arange(w)[None, :] + phase) % w
    xi = np.floor(x).astype(int)
    fx = x - xi
    strands = columns[xi] * (1 - fx) + columns[(xi + 1) % w] * fx
    clumps = fbm((h, w), ((32, .6), (8, .4)), rng)
    value = np.clip(.30 + .42 * strands + .28 * (clumps - .5), 0, 1)
    albedo = np.dstack((value, value * .96, value * .90, np.ones_like(value)))
    normal = height_to_normal(value, 2.5)
    return (image_from_array("IdentityStrands", albedo),
            image_from_array("IdentityStrands_normal", np.dstack((normal, np.ones_like(value))), "Non-Color"))


def woven_textures(name, base, weave_scale, fuzz, rng, size=512):
    x = np.arange(size)[None, :].repeat(size, 0).astype(float)
    y = np.arange(size)[:, None].repeat(size, 1).astype(float)
    warp = np.sin(x * weave_scale) * .5 + .5
    weft = np.sin(y * weave_scale * 1.07 + np.sin(x * .05)) * .5 + .5
    checker = np.where((np.floor(x * weave_scale / math.pi) + np.floor(y * weave_scale * 1.07 / math.pi)) % 2 == 0, warp, weft)
    noise = fbm((size, size), ((128, .45), (32, .35), (8, .20)), rng)
    slub = fbm((size, size), ((size // 4, 1.0),), rng)
    height = .55 * checker + fuzz * (noise - .5) + .15 * (slub - .5)
    value = np.clip(base * (.86 + .22 * height), 0, 1)
    albedo = np.dstack((value, value * .985, value * .955, np.ones_like(value)))
    normal = height_to_normal(height, 2.2)
    return (image_from_array(name, albedo),
            image_from_array(name + "_normal", np.dstack((normal, np.ones_like(value))), "Non-Color"))


def leather_textures(rng, size=256):
    cells = fbm((size, size), ((24, .6), (8, .4)), rng)
    grain = fbm((size, size), ((4, 1.0),), rng)
    height = cells * .7 + grain * .3
    value = np.clip(.62 + .28 * (height - .5), 0, 1)
    albedo = np.dstack((value, value, value, np.ones_like(value)))
    normal = height_to_normal(height, 4.0)
    return (image_from_array("IdentityLeather", albedo),
            image_from_array("IdentityLeather_normal", np.dstack((normal, np.ones_like(value))), "Non-Color"))


def textured_material(name, albedo, normal, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if albedo is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = albedo
        links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    else:
        shader.inputs["Base Color"].default_value = (1, 1, 1, 1)
    if normal is not None:
        ntex = nodes.new("ShaderNodeTexImage")
        ntex.image = normal
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], shader.inputs["Normal"])
    return mat


def save_png(name, values, colorspace="sRGB"):
    TEXTURES.mkdir(parents=True, exist_ok=True)
    h, w, _ = values.shape
    image = bpy.data.images.new(name, width=w, height=h, alpha=True)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(np.clip(values, 0.0, 1.0).astype(np.float32).ravel())
    path = TEXTURES / (name + ".png")
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    return {"path": str(path.relative_to(ROOT)), "edge": max(h, w), "sha256": digest(path)}


def write_shared_textures():
    """Strand, wool and leather maps shared by every kind and LOD tier."""
    rng = np.random.default_rng(SEED)
    records = {}
    for name, (albedo, normal) in (("strands", strand_textures(rng)), ("wool", woven_textures("IdentityWool", .78, .9, .55, rng, size=256)),
                                   ("leather", leather_textures(rng))):
        for suffix, image, space in (("", albedo, "sRGB"), ("_normal", normal, "Non-Color")):
            values = np.asarray(image.pixels[:]).reshape(image.size[1], image.size[0], 4)
            records[name + suffix] = save_png("resident_" + name + suffix, values, space)
            bpy.data.images.remove(image)
    return records


def neutral_cloth(rng):
    """Light undyed linen so runtime dyes give the intended colour."""
    mat = bpy.data.materials["FrontierCloth"]
    shader = mat.node_tree.nodes.get("Principled BSDF")
    size = 512
    x = np.arange(size)[None, :].repeat(size, 0).astype(float)
    y = np.arange(size)[:, None].repeat(size, 1).astype(float)
    weave = .035 * np.sin(x * 1.8) + .035 * np.sin(y * 2.1) + .025 * np.sin(x * .08 + np.sin(y * .03))
    slub = fbm((size, size), ((64, .6), (16, .4)), rng) - .5
    value = .80 * (1 + weave + .05 * slub)
    pixels = np.dstack((value, value * .975, value * .935, np.ones_like(value)))
    image = image_from_array("FrontierLinen_neutral", pixels)
    for link in mat.node_tree.links:
        if link.to_socket == shader.inputs["Base Color"] and link.from_node.type == "TEX_IMAGE":
            link.from_node.image = image


# --------------------------------------------------------------------------
# skin masks baked from 3D rest positions into the body UV layout


def rasterize(body, size):
    """Per-texel rest position and normal of the body surface."""
    me = body.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    P = coords(body)
    N = vertex_normals(body)
    pos = np.zeros((size, size, 3))
    nor = np.zeros((size, size, 3))
    filled = np.zeros((size, size), dtype=bool)
    for tri in me.loop_triangles:
        t = np.array([uv[i].uv[:] for i in tri.loops]) * size - .5
        x0, y0 = np.floor(t.min(0)).astype(int)
        x1, y1 = np.ceil(t.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        a, b, c = t
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / det
        l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / det
        l3 = 1 - l1 - l2
        inside = (l1 >= -.02) & (l2 >= -.02) & (l3 >= -.02)
        if not inside.any():
            continue
        v = list(tri.vertices)
        bary = np.stack((l1[inside], l2[inside], l3[inside]), 1)
        py, px = gy[inside], gx[inside]
        pos[py, px] = bary @ P[v]
        nor[py, px] = bary @ N[v]
        filled[py, px] = True
    return pos, nor, filled


def dilate(values, filled, steps=6):
    values = values.copy()
    filled = filled.copy()
    for _ in range(steps):
        acc = np.zeros_like(values)
        count = np.zeros(filled.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(values, dy, 0), dx, 1)
            mask = np.roll(np.roll(filled, dy, 0), dx, 1)
            acc[mask] += shifted[mask]
            count[mask] += 1
        grow = (~filled) & (count > 0)
        values[grow] = acc[grow] / count[grow][:, None]
        filled = filled | grow
    return values


def segment_distance(P2, a, b):
    a, b = np.asarray(a), np.asarray(b)
    ab = b - a
    t = np.clip(((P2 - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(P2 - (a + t[:, None] * ab), axis=1)


def skin_masks(body, L, kind, size=1024):
    pos, nor, filled = rasterize(body, size * 2)
    flat = pos.reshape(-1, 3)
    normals = nor.reshape(-1, 3)
    ez, ex, ny, nz, mz, cz = L["ez"], L["ex"], L["ny"], L["nz"], L["mz"], L["cz"]
    Q, _ = mirrored(flat)
    z, y = flat[:, 2], flat[:, 1]
    head = (z > 1.235).astype(float)
    front = smooth(-.035, -.07, y)
    follicle = hash_noise(flat, .0009)
    # Beard: below the ear-to-nose-wing line, moustache, chin, under the jaw.
    line = (ez - .030) + (nz - .006 - (ez - .030)) * np.clip((.064 - Q[:, 0]) / (.064 - .022), 0, 1)
    cheek = smooth(line + .004, line - .006, z) * smooth(-.030, -.060, y)
    moustache = gauss(flat, (0, ny + .012, nz - .016), (.024, .03, .008))
    lips = np.exp(-((Q[:, 0] / .022) ** 2 + ((z - mz) / .0075) ** 2))
    under = smooth(-.2, -.6, normals[:, 2]) * smooth(1.238, 1.258, z) * (z < cz + .005) * smooth(-.02, -.05, y)
    neck = smooth(1.232, 1.252, z) * smooth(-.04, -.07, y) * (z < 1.29)
    beard = np.clip(np.maximum.reduce([cheek, moustache, under, neck * .8]) * (1 - lips) * head, 0, 1)
    beard *= .55 + .45 * follicle
    # Creases: forehead, frown, crow's feet, lower lid, nasolabial, marionette, neck.
    crease = np.zeros(len(flat))
    forehead = smooth(-.10, -.125, y) * smooth(.050, .030, Q[:, 0])
    for k, zk in enumerate((ez + .034, ez + .044, ez + .054)):
        wave = .0016 * np.sin(Q[:, 0] * 70.0 + k)
        crease += forehead * np.exp(-((z - zk - wave) / .0011) ** 2) * (.9 - .15 * k)
    crease += np.exp(-(((Q[:, 0] - .006) / .0011) ** 2 + ((z - ez - .016) / .006) ** 2)) * front * .8
    corner = np.array([ex + .016, ez])
    rel = np.stack((Q[:, 0] - corner[0], z - corner[1]), 1)
    radius = np.linalg.norm(rel, axis=1)
    angle = np.arctan2(rel[:, 1], rel[:, 0])
    fan = sum(np.exp(-((angle - a) / .07) ** 2) for a in (-.40, -.05, .30))
    crease += fan * smooth(.003, .006, radius) * smooth(.020, .013, radius) * smooth(-.06, -.09, y) * .8
    lid = np.abs(np.hypot((Q[:, 0] - ex) / 1.3, z - (ez - .004)) - .0125)
    crease += np.exp(-(lid / .0011) ** 2) * (z < ez - .004) * smooth(-.10, -.12, y) * .55
    fold = segment_distance(np.stack((Q[:, 0], z), 1), (.019, nz - .004), (.031, mz - .006))
    crease += np.exp(-(fold / .0014) ** 2) * front
    mar = segment_distance(np.stack((Q[:, 0], z), 1), (.025, mz - .004), (.027, cz + .006))
    crease += .7 * np.exp(-(mar / .0012) ** 2) * front
    for zk in (1.236, 1.250):
        crease += .6 * np.exp(-((z - zk) / .0013) ** 2) * smooth(-.05, -.08, y) * (np.abs(flat[:, 0]) < .045)
    crease = np.clip(crease * head, 0, 1)
    spots = smooth(.80, .93, hash_noise(flat, .006)) * (.4 + .6 * head)
    wrinkles = np.clip(crease + .35 * spots, 0, 1)
    # Sun: head, forearms, hands, shins and feet are uncovered; upward faces get more.
    arm_out = (np.abs(flat[:, 0]) > .175) & (z > .66) & (z < 1.25)
    forearm = arm_out & (z < 1.06)
    exposed = np.maximum.reduce([head, forearm.astype(float), (arm_out & ~forearm) * .35,
                                 (z < .50).astype(float) * .85])
    sun = np.clip(exposed * (.55 + .45 * np.clip(normals[:, 2] + .35, 0, 1)), 0, 1)
    sun *= 1 - .35 * under
    flush = np.clip(np.maximum.reduce([gauss(Q, (.044, -.112, ez - .026), (.020, .02, .018)),
                                       .8 * gauss(flat, (0, ny, nz), (.012, .016, .012)),
                                       .6 * smooth(L["ear_x"] - .004, L["ear_x"] + .004, Q[:, 0]) * head * smooth(.02, -.01, y),
                                       .35 * gauss(flat, (0, L["cy"], cz), (.02, .02, .014))]), 0, 1)
    # Scalp: shaved/receding stubble shadow above the hairline.
    hairline = np.where(y < -.07, ez + .066, np.where(y < -.03, ez + .030, 1.330))
    scalp = smooth(hairline - .004, hairline + .006, z) * head
    scalp *= np.where((Q[:, 0] > L["ear_x"] - .006) & (y < .0) & (y > -.07) & (z < ez + .02), 0.0, 1.0)
    scalp *= .55 + .45 * follicle
    arch = ez + .017 + .0045 * (1 - ((Q[:, 0] - .026) / .024) ** 2)
    brow = np.exp(-((z - arch) / .0036) ** 2) * smooth(.006, .011, Q[:, 0]) * smooth(.050, .043, Q[:, 0])
    brow *= smooth(-.09, -.115, y) * head * (.5 + .5 * follicle)

    def finish(channels):
        image = np.stack(channels, -1).reshape(size * 2, size * 2, len(channels))
        image = dilate(image, filled, 8)
        image = image.reshape(size, 2, size, 2, len(channels)).mean((1, 3))
        return image

    mask = finish([beard, wrinkles, sun, flush])
    crease_image = finish([crease])[:, :, 0]
    blurred = (crease_image + np.roll(crease_image, 1, 0) + np.roll(crease_image, -1, 0)
               + np.roll(crease_image, 1, 1) + np.roll(crease_image, -1, 1)) / 5
    normal = height_to_normal(-blurred, 9.0)
    extra = finish([scalp, brow])
    detail = np.dstack((normal[:, :, 0], normal[:, :, 1], extra[:, :, 0], extra[:, :, 1]))
    TEXTURES.mkdir(parents=True, exist_ok=True)
    outputs = {}
    for label, values in (("skin_mask", mask), ("skin_detail", detail)):
        image = bpy.data.images.new(f"{kind}_{label}", width=size, height=size, alpha=True)
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(np.clip(values, 0, 1).astype(np.float32).ravel())
        path = TEXTURES / f"{kind}_{label}.png"
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
        bpy.data.images.remove(image)
        outputs[label] = {"path": str(path.relative_to(ROOT)), "edge": size, "sha256": digest(path)}
    return outputs


# --------------------------------------------------------------------------
# optional pieces


def copy_object(src, name):
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    obj.data.name = name
    for collection in src.users_collection:
        collection.objects.link(obj)
    return obj


def keep_faces(obj, keep):
    """Delete faces whose rest centre fails keep(centre, normal)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    doomed = [f for f in bm.faces if not keep(np.array(f.calc_center_median()), np.array(f.normal))]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def drop_keys(obj, keep=()):
    if not obj.data.shape_keys:
        return
    for key in list(obj.data.shape_keys.key_blocks)[1:]:
        if key.name not in keep:
            obj.shape_key_remove(key)
    if len(obj.data.shape_keys.key_blocks) == 1 and not keep:
        obj.shape_key_clear()


def offset_all(obj, amount):
    """Offset basis and every key along the basis vertex normals."""
    N = vertex_normals(obj)
    shift = N * amount[:, None]
    if obj.data.shape_keys:
        for key in obj.data.shape_keys.key_blocks:
            set_coords(key.data, coords(obj, key) + shift)
        set_coords(obj.data.vertices, coords(obj, obj.data.shape_keys.key_blocks[0]))
    else:
        set_coords(obj.data.vertices, coords(obj) + shift)
    obj.data.update()


def planar_uv(obj, u_fn, v_fn):
    me = obj.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    layer = me.uv_layers.new(name="UVMap")
    P = coords(obj)
    for loop in me.loops:
        p = P[loop.vertex_index]
        layer.data[loop.index].uv = (float(u_fn(p)), float(v_fn(p)))


def assign_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0


def boundary_rings(obj, depth=3):
    """Graph distance (in edge rings) of each vertex from an open border."""
    me = obj.data
    count = {}
    for poly in me.polygons:
        for key in poly.edge_keys:
            count[key] = count.get(key, 0) + 1
    ring = np.full(len(me.vertices), depth, dtype=float)
    frontier = {v for key, n in count.items() if n == 1 for v in key}
    neighbours = {i: set() for i in range(len(me.vertices))}
    for a, b in count:
        neighbours[a].add(b)
        neighbours[b].add(a)
    for level in range(depth):
        for v in frontier:
            ring[v] = min(ring[v], level)
        frontier = {n for v in frontier for n in neighbours[v] if ring[n] > level}
    return ring / depth


def build_beard(body, L, mat):
    beard = copy_object(body, "IdentityBeard")
    drop_keys(beard, keep=("JawOpen", "Smile"))
    ez, ny, nz, mz, cz = L["ez"], L["ny"], L["nz"], L["mz"], L["cz"]

    def region(c, n):
        q = abs(c[0])
        line = (ez - .028) + (nz - .007 - (ez - .028)) * min(max((.062 - q) / (.062 - .022), 0), 1)
        lips = (q / .021) ** 2 + ((c[2] - mz) / .0068) ** 2 < 1.0
        cheek = c[2] < line and c[1] < -.035 and c[2] > 1.262
        moustache = q < .024 and nz - .022 < c[2] < nz - .008 and c[1] < ny + .03
        under = c[2] > 1.247 and c[2] < cz + .004 and n[2] < -.25 and c[1] < -.045
        return (cheek or moustache or under) and not lips

    keep_faces(beard, region)
    # Thickness fades to the skin at every open border; the stubble mask
    # under it carries the transition instead of a hard shell edge.
    fade = .12 + .88 * smooth(0.0, 1.0, boundary_rings(beard, 3))
    P = coords(beard)
    q = np.abs(P[:, 0])
    chin = np.exp(-((q / .028) ** 2 + ((P[:, 2] - cz) / .022) ** 2))
    offset_all(beard, (.0020 + .0012 * chin) * fade)
    P = coords(beard)
    N = vertex_normals(beard)
    full = N * ((.0045 + .0090 * chin + .0030 * smooth(1.30, 1.27, P[:, 2])) * fade)[:, None]
    full[:, 2] -= .0075 * chin * smooth(cz + .01, cz - .01, P[:, 2]) * fade
    add_key(beard, "BEARD_Full", full)
    planar_uv(beard, lambda p: .5 + math.atan2(p[0], -p[1] - .02) / math.pi * 1.6, lambda p: (p[2] - 1.22) / .10)
    assign_material(beard, mat)
    return beard


class WeightSource:
    """Skin weights of the nearest authored vertices (inverse-distance blend)."""

    def __init__(self, objects):
        self.points, self.weights = [], []
        for obj in objects:
            names = {g.index: g.name for g in obj.vertex_groups}
            P = coords(obj, obj.data.shape_keys.key_blocks[0]) if obj.data.shape_keys else coords(obj)
            for v in obj.data.vertices:
                w = {names[g.group]: g.weight for g in v.groups if g.weight > 0 and g.group in names}
                if w:
                    self.points.append(P[v.index])
                    self.weights.append(w)
        self.tree = KDTree(len(self.points))
        for i, p in enumerate(self.points):
            self.tree.insert(p, i)
        self.tree.balance()

    def sample(self, p, n=4, bias=None):
        total, mix = 0.0, {}
        for _, i, d in self.tree.find_n(Vector(p), n):
            w = 1.0 / max(d, 1e-4) ** 2
            total += w
            for bone, value in self.weights[i].items():
                mix[bone] = mix.get(bone, 0.0) + w * value
        if bias:
            for bone, value in bias.items():
                mix[bone] = mix.get(bone, 0.0) + total * value
        norm = sum(mix.values())
        ranked = sorted(mix.items(), key=lambda kv: -kv[1])[:4]
        norm = sum(v for _, v in ranked)
        return {bone: v / norm for bone, v in ranked}


def bvh_of(objects):
    verts, polys = [], []
    for obj in objects:
        P = coords(obj, obj.data.shape_keys.key_blocks[0]) if obj.data.shape_keys else coords(obj)
        base = len(verts)
        verts.extend(map(tuple, P))
        polys.extend([tuple(base + i for i in poly.vertices) for poly in obj.data.polygons])
    return BVHTree.FromPolygons(verts, polys)


def cast(bvh, origin, direction):
    hit = bvh.ray_cast(Vector(origin), Vector(direction).normalized(), 2.0)
    return (np.array(hit[0]), np.array(hit[1])) if hit[0] is not None else (None, None)


def grid_object(name, grid, active, uv, mat, arm, weights, closed=False):
    rows, cols, _ = grid.shape
    verts = [tuple(grid[i, j]) for i in range(rows) for j in range(cols)]
    faces = []
    span = cols if closed else cols - 1
    for i in range(rows - 1):
        for j in range(span):
            k = (j + 1) % cols
            if active[i, j] and active[i, k] and active[i + 1, j] and active[i + 1, k]:
                # Rows run downward and columns run with the azimuth (or +x), so
                # this order makes the face normals point away from the body.
                faces.append((i * cols + j, (i + 1) * cols + j, (i + 1) * cols + k, i * cols + k))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    layer = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        i, j = divmod(loop.vertex_index, cols)
        layer.data[loop.index].uv = tuple(uv[i, j])
    _frontier_module().hero.bind(obj, arm, [weights(np.array(v)) for v in verts])
    assign_material(obj, mat)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.update()
    return obj


def build_apron(cloth_bvh, source, kind, mat, arm):
    # Above the knee: a single stiff panel cannot follow both legs further down.
    top, bottom = 1.205, (.565 if kind != "civilian_woman" else .60)
    rows, cols = 20, 11
    grid = np.zeros((rows, cols, 3))
    uv = np.zeros((rows, cols, 2))
    for i in range(rows):
        t = i / (rows - 1)
        z = top + (bottom - top) * t
        half = .080 + .060 * smooth(.05, .40, t)
        for j in range(cols):
            s = j / (cols - 1) * 2 - 1
            x = s * half * (1 - .06 * t * t * abs(s))
            hit, _ = cast(cloth_bvh, (x, -.6, z), (0, 1, 0))
            y = hit[1] - .0075 if hit is not None else (grid[i - 1, j, 1] if i else -.14)
            grid[i, j] = (x, y, z)
            uv[i, j] = (s * .5 + .5, t * 1.6)
        row = grid[i, :, 1]
        grid[i, :, 1] = .5 * row.min() + .5 * row
        if i:
            # Leather hangs from the belly rather than following the thighs.
            grid[i, :, 1] = np.minimum(grid[i, :, 1], grid[i - 1, :, 1] + .0035)
    active = np.ones((rows, cols), dtype=bool)

    def weights(p):
        # Below the hips each half of the panel follows its own thigh, so a
        # striding knee pushes the leather instead of passing through it.
        t = float(smooth(.84, .62, np.array([p[2]]))[0]) * float(smooth(.0, .05, np.array([abs(p[0])]))[0])
        return source.sample(p, bias={("Thigh_L" if p[0] > 0 else "Thigh_R"): .9 * t})

    apron = grid_object("IdentityApron", grid, active, uv, mat, arm, weights)
    hero = _frontier_module().hero
    straps = []
    for side in (-1, 1):
        corner = grid[0, 0 if side < 0 else -1]
        path = [tuple(corner), (side * .066, corner[1] + .012, 1.262), (side * .052, -.030, 1.300),
                (side * .030, .012, 1.296), (0.0, .026, 1.286)]
        straps.append(hero.tube("IdentityApronStrap", path, [.0042] * len(path), mat, arm, "Spine", 6))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [apron] + straps:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = apron
    bpy.ops.object.join()
    apron = bpy.context.object
    apron.name = apron.data.name = "IdentityApron"
    return apron


def build_mantle(cloth_bvh, source, kind, mat, arm):
    """Shoulder cape that narrows into a back panel; each row spans its own
    angular extent, so the front edges are continuous curves."""
    woman = kind == "civilian_woman"
    collar, cape, bottom = 1.300, 1.165, (.74 if woman else .80)
    rows, cols = 22, 30
    grid = np.zeros((rows, cols, 3))
    uv = np.zeros((rows, cols, 2))
    radius = np.zeros(cols)
    for i in range(rows):
        t = i / (rows - 1)
        z = collar + (bottom - collar) * t
        narrow = float(smooth(cape + .01, cape - .085, np.array([z]))[0])
        gap = .40 + (2.02 - .40) * narrow       # half-angle of the front opening
        for j in range(cols):
            a = gap + (2 * math.pi - 2 * gap) * j / (cols - 1)
            d = np.array([math.sin(a), -math.cos(a), 0.0])
            axis = np.array([0.0, -.02, z])
            hit, _ = cast(cloth_bvh, axis + d * .6, -d)
            r = float(np.linalg.norm((hit - axis)[:2])) if hit is not None else radius[j]
            r += .011 + .004 * t
            if i and z < cape:
                r = max(r, radius[j] - .0025)  # hang from the shoulder blades
            radius[j] = r
            grid[i, j] = axis + d * r
            uv[i, j] = (j / cols * 2.4, t * 2.2)
    active = np.ones((rows, cols), dtype=bool)
    return grid_object("IdentityMantle", grid, active, uv, mat, arm, source.sample)


def head_dome(name, head_bvh, centre, e_min, offset, rows, cols, mat, arm, weights, drape=False, uv_fn=None, top=89.5):
    """Closed cap of rays from a head centre; each column spans [e_min(a), top]
    so the border is a smooth curve instead of a stepped cell mask."""
    grid = np.zeros((rows, cols, 3))
    uv = np.zeros((rows, cols, 2))
    for j in range(cols):
        a = -math.pi + 2 * math.pi * j / cols
        widest = 0.0
        for i in range(rows):
            e = math.radians(top) + (e_min(a) - math.radians(top)) * (i / (rows - 1)) ** .85
            d = np.array([math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e)])
            hit, normal = cast(head_bvh, centre + d * .4, -d)
            if hit is None:
                hit, normal = centre + d * .085, d
            p = hit + normal * offset(d, hit)
            radial = np.linalg.norm((p - centre)[:2])
            if drape and e < 0 and radial < widest:
                p[:2] = centre[:2] + (p - centre)[:2] / max(radial, 1e-6) * widest
            widest = max(widest, radial)
            grid[i, j] = p
            uv[i, j] = uv_fn(d, i, j) if uv_fn else (j / cols * 2.0, i / rows * 1.5)
    active = np.ones((rows, cols), dtype=bool)
    return grid_object(name, grid, active, uv, mat, arm, weights, closed=True)


def build_veil(head_bvh, L, mat, arm):
    centre = np.array([0.0, -.035, L["ez"] + .005])

    def e_min(a):
        f = smooth(.55, 1.55, abs(a))
        # The front edge sits behind the hairline so the parted hair shows.
        return math.radians(52) * (1 - f) + math.radians(-42) * f

    def offset(d, hit):
        return .0095 + .006 * max(0.0, d[1] + .2)

    def weights(p):
        t = float(smooth(1.30, 1.23, np.array([p[2]]))[0])
        return {"Head": 1 - .7 * t, "Spine": .7 * t}

    veil = head_dome("IdentityVeil", head_bvh, centre, e_min, offset, 16, 32, mat, arm, weights, drape=True)
    P = coords(veil)
    low = smooth(1.33, 1.26, P[:, 2]) * smooth(-.07, -.03, P[:, 1])
    radial = P[:, :2] - centre[:2]
    radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-6)
    longer = np.zeros_like(P)
    longer[:, 2] = -.050 * low
    longer[:, :2] = radial * (.022 * low)[:, None]
    add_key(veil, "VEIL_Long", longer)
    return veil


def build_cap(scalp_bvh, L, mat, arm):
    centre = np.array([0.0, -.045, L["ez"] + .02])

    def e_min(a):
        f = smooth(.3, 2.7, abs(a))
        return math.radians(24) * (1 - f) + math.radians(-2) * f

    def offset(d, hit):
        return .0105 + .012 * max(0.0, d[2] - .82) / .18

    return head_dome("IdentityCap", scalp_bvh, centre, e_min, offset, 9, 28, mat, arm, lambda p: {"Head": 1.0})


def build_hair_bound(head_bvh, L, mat, arm):
    """Centre-parted hair drawn back to the existing bun (women)."""
    centre = np.array([0.0, -.04, L["ez"] + .01])

    def e_min(a):
        b = abs(a)
        if b < .55:
            return math.radians(43) - math.radians(10) * b / .55
        if b < 1.55:
            return math.radians(33) - math.radians(26) * (b - .55)
        return math.radians(7) - math.radians(50) * smooth(1.55, 2.6, b)

    def offset(d, hit):
        part = math.exp(-(hit[0] / .0055) ** 2) * (1.0 if hit[1] < -.005 else 0.3)
        return .0042 + .0012 * max(0.0, d[2]) - .0028 * part

    def uv_fn(d, i, j):
        lateral = math.degrees(math.asin(max(-1.0, min(1.0, d[0])))) / 90.0
        along = math.atan2(-d[1], d[2]) / math.pi
        return (along * 2.2 + (0.5 if lateral < 0 else 0.0), abs(lateral) * 1.8)

    return head_dome("IdentityHairBound", head_bvh, centre, e_min, offset, 14, 36, mat, arm,
                     lambda p: {"Head": 1.0}, uv_fn=uv_fn)


def bound_shape(name, verts, faces, mat, bone, arm):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.vertex_groups.new(name=bone).add(list(range(len(verts))), 1.0, "REPLACE")
    assign_material(obj, mat)
    planar_uv(obj, lambda p: p[0] * 8 + .5, lambda p: p[2] * 8)
    for poly in me.polygons:
        poly.use_smooth = True
    return obj


def ellipsoid(centre, radii, rings=6, segments=10):
    verts, faces = [], []
    for r in range(rings + 1):
        theta = math.pi * r / rings
        for s in range(segments):
            phi = 2 * math.pi * s / segments
            verts.append((centre[0] + radii[0] * math.sin(theta) * math.cos(phi),
                          centre[1] + radii[1] * math.sin(theta) * math.sin(phi),
                          centre[2] + radii[2] * math.cos(theta)))
    for r in range(rings):
        for s in range(segments):
            a = r * segments + s
            b = r * segments + (s + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    return verts, faces


def build_small_pieces(arm, L, leather, metal, kind, cloth_bvh):
    pieces = []
    hit, _ = cast(cloth_bvh, (.118, .6, .858), (0, -1, 0))
    side = hit[1] if hit is not None else -.04
    hit, _ = cast(cloth_bvh, (.6, -.06, .858), (-1, 0, 0))
    hip = hit[0] if hit is not None else .16
    v, f = ellipsoid((hip - .012, -.068, .842), (.016, .030, .040), 5, 9)
    pieces.append(bound_shape("IdentityPouch", v, f, leather, "Pelvis", arm))
    hit, _ = cast(cloth_bvh, (.088, -.6, 1.218), (0, 1, 0))
    front = hit[1] if hit is not None else -.10
    v, f = ellipsoid((.088, front - .022, 1.218), (.012, .005, .012), 3, 10)
    pieces.append(bound_shape("IdentityBrooch", v, f, metal, "Spine", arm))
    if kind == "civilian_woman":
        verts, faces = [], []
        for s in (-1, 1):
            vv, ff = ellipsoid((s * (L["ear_x"] + .001), -.040, L["ear_low"] - .007), (.0032, .0032, .0055), 3, 6)
            base = len(verts)
            verts += vv
            faces += [tuple(i + base for i in face) for face in ff]
        pieces.append(bound_shape("IdentityEarrings", verts, faces, metal, "Head", arm))
    return pieces


def build_identity(kind):
    """Open the unchanged frontier source and add every identity control."""
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE / (kind + ".blend")))
    check_identity_matrices()
    rng = np.random.default_rng(SEED + KINDS.index(kind))
    arm = bpy.data.objects["FrontierRig"]
    body = bpy.data.objects["HeroBody"]
    eyes = bpy.data.objects["HeroEyes"]
    hair = bpy.data.objects["HeroHair"]
    tunic = bpy.data.objects["HeroTunic"]
    skirt = bpy.data.objects["HeroTunicSkirt"]
    L = landmarks(body, eyes)
    neutral_cloth(rng)
    shared = write_shared_textures()
    # Piece materials carry no images: the runtime binds the shared textures
    # above once for every kind and tier instead of one embedded copy per GLB.
    beard_mat = textured_material("IdentityBeard", None, None, .78)
    wool_mat = textured_material("IdentityWool", None, None, .93)
    leather_mat = textured_material("IdentityLeather", None, None, .66)
    metal_mat = textured_material("IdentityMetal", None, None, .34, metallic=.85)
    # One mask set serves all three kinds: they share the body UV layout and
    # the masks follow landmarks that land on the same UV islands.
    masks = skin_masks(body, L, "resident") if kind == "civilian_man" or not (TEXTURES / "resident_skin_mask.png").exists() else {
        label: {"path": str((TEXTURES / f"resident_{label}.png").relative_to(ROOT)), "edge": 1024,
                "sha256": digest(TEXTURES / f"resident_{label}.png")} for label in ("skin_mask", "skin_detail")}
    masks["shared"] = shared
    hair_objects = [o for o in meshes() if o.name.startswith(("HeroHair", "FrontierHairBun", "FrontierBoundLocks"))]
    cloth = [tunic, skirt, bpy.data.objects["HeroBelt"], bpy.data.objects["HeroCollarSeam"]]
    cloth_bvh = bvh_of(cloth + [body])
    scalp_bvh = bvh_of([body])
    bun = [o for o in hair_objects if o.name.startswith("FrontierHairBun")]
    veil_bvh = bvh_of([body] + bun)
    source = WeightSource([tunic, skirt, bpy.data.objects["HeroCollarSeam"]])
    wanted = KIND_PIECES[kind]
    builders = {
        "IdentityBeard": lambda: build_beard(body, L, beard_mat),
        "IdentityHairBound": lambda: build_hair_bound(veil_bvh, L, beard_mat, arm),
        "IdentityApron": lambda: build_apron(cloth_bvh, source, kind, leather_mat, arm),
        "IdentityMantle": lambda: build_mantle(cloth_bvh, source, kind, wool_mat, arm),
        "IdentityVeil": lambda: build_veil(veil_bvh, L, wool_mat, arm),
        "IdentityCap": lambda: build_cap(scalp_bvh, L, wool_mat, arm),
    }
    pieces = [builders[name]() for name in PIECES if name in builders and name in wanted]
    pieces += [p for p in build_small_pieces(arm, L, leather_mat, metal_mat, kind, cloth_bvh) if p.name in wanted]
    # Hair controls first (they need the unmodified scalp), then identity keys
    # on every mesh from the same rest-position functions.
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get(), deform=False)
    for obj in hair_objects:
        for name, delta in hair_deltas(obj, bvh, L).items():
            add_key(obj, name, delta)
    for obj in meshes():
        if obj.name in ("HeroEyes",):
            continue
        P = coords(obj, obj.data.shape_keys.key_blocks[0]) if obj.data.shape_keys else coords(obj)
        arm_weight = group_weight(obj, ("Arm_", "Forearm_", "Hand_"))
        for name in FACE_KEYS:
            add_key(obj, name, face_delta(name, P, L))
        for name in BODY_KEYS:
            add_key(obj, name, body_delta(name, P, arm_weight))
    # Eyes follow only the keys that move the whole orbit region rigidly.
    if skirt.data.shape_keys is None or "ID_Hem" not in skirt.data.shape_keys.key_blocks:
        P = coords(skirt, skirt.data.shape_keys.key_blocks[0]) if skirt.data.shape_keys else coords(skirt)
        top = float(P[:, 2].max())
        hem = float(P[:, 2].min())
        t = np.clip((top - .06 - P[:, 2]) / max(top - .06 - hem, 1e-6), 0, 1)
        delta = np.zeros_like(P)
        delta[:, 2] = -(.17 if kind != "civilian_woman" else .06) * t
        add_key(skirt, "ID_Hem", delta)
    for obj in pieces:
        obj.data.update()
    path = Path(tempfile.gettempdir()) / f"resident_identity_{kind}.blend"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=False)
    return path, L, masks


# --------------------------------------------------------------------------
# export


def simplify(obj, ratio, keep):
    """Decimate while transferring the kept relative keys to the new vertices."""
    names = [k.name for k in obj.data.shape_keys.key_blocks[1:]] if obj.data.shape_keys else []
    kept = [n for n in names if keep(n)]
    if obj.name == "HeroBelt" or ratio >= 1 or len(obj.data.vertices) < 24:
        for name in names:
            if name not in kept:
                obj.shape_key_remove(obj.data.shape_keys.key_blocks[name])
        if obj.data.shape_keys and len(obj.data.shape_keys.key_blocks) == 1:
            obj.shape_key_clear()
        return
    source = coords(obj, obj.data.shape_keys.key_blocks[0]) if obj.data.shape_keys else coords(obj)
    deltas = {n: coords(obj, obj.data.shape_keys.key_blocks[n]) - source for n in kept}
    if obj.data.shape_keys:
        obj.shape_key_clear()
    tree = KDTree(len(source))
    for i, p in enumerate(source):
        tree.insert(p, i)
    tree.balance()
    bpy.context.view_layer.objects.active = obj
    decimator = obj.modifiers.new("Resident detail", "DECIMATE")
    decimator.ratio = ratio
    bpy.ops.object.modifier_move_to_index(modifier=decimator.name, index=0)
    bpy.ops.object.modifier_apply(modifier=decimator.name)
    obj.data.validate(verbose=False, clean_customdata=False)
    obj.data.update()
    if deltas:
        P = coords(obj)
        weights = []
        for p in P:
            near = tree.find_n(p, 3)
            total = sum(1 / max(1e-5, d) for _, _, d in near)
            weights.append([(i, (1 / max(1e-5, d)) / total) for _, i, d in near])
        obj.shape_key_add(name="Basis", from_mix=False)
        for name, values in deltas.items():
            delta = np.array([sum((values[i] * w for i, w in row), np.zeros(3)) for row in weights])
            key = obj.shape_key_add(name=name, from_mix=False)
            set_coords(key.data, P + delta)


def collapse_piece(obj):
    """Shrink a piece into the body; ID_Show restores its authored geometry."""
    basis = ensure_basis(obj)
    real = coords(obj, basis)
    anchor = real.mean(axis=0)
    anchor[1] = -.02 if anchor[2] < 1.25 else -.04
    tiny = anchor + (real - anchor) * .01
    for key in obj.data.shape_keys.key_blocks[1:]:
        set_coords(key.data, tiny + coords(obj, key) - real)
    set_coords(basis.data, tiny)
    set_coords(obj.data.vertices, tiny)
    show = obj.shape_key_add(name="ID_Show", from_mix=False)
    set_coords(show.data, real)
    obj.data.update()


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export(kind, source_path):
    records = []
    cap = {0: .85, 1: .45, 2: .16, 3: .06}
    for level, ratio, edge in LOD:
        near = level < 2

        def keep(name):
            return name not in EXPRESSION or near

        piece_ratio = cap[level]
        for attempt in range(6):
            bpy.ops.wm.open_mainfile(filepath=str(source_path))
            # Fingers, jaw and eyes on the near tiers; the resting hand in the
            # mesh of the distant tiers (tools/characters/extend_adult_rig.py).
            rig = _frontier_module().adult_rig.prepare(bpy.data.objects["FrontierRig"], level)
            raw = 0
            for obj in list(meshes()):
                if obj.name in NEAR_ONLY and not near:
                    bpy.data.objects.remove(obj, do_unlink=True)
                elif obj.name in PIECES:
                    raw += triangles(obj)
                else:
                    simplify(obj, ratio, keep)
            base = sum(triangles(o) for o in meshes() if o.name not in PIECES)
            # Hidden pieces still count in the existing all-mesh budget test.
            fitted = min(piece_ratio, max(.01, (BUDGET[level] * .985 - base) / max(raw, 1)))
            for obj in list(meshes()):
                if obj.name in PIECES:
                    simplify(obj, fitted, keep)
            total = sum(triangles(o) for o in meshes())
            if total <= BUDGET[level]:
                break
            piece_ratio = fitted * .9
        else:
            raise RuntimeError(f"{kind} LOD {level}: {total} triangles exceed {BUDGET[level]}")
        for name in PIECES:
            obj = bpy.data.objects.get(name)
            if obj:
                collapse_piece(obj)
        frontier = _frontier_module()
        belt_fit = frontier.hero.fit_belt_clearance(bpy.data.objects["HeroBelt"],
                                                    [bpy.data.objects["HeroTunic"], bpy.data.objects["HeroTunicSkirt"]])
        for image in bpy.data.images:
            if max(image.size) > edge:
                factor = edge / max(image.size)
                image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
                image.pack()
        bpy.ops.object.select_all(action="DESELECT")
        per_mesh = {}
        for obj in bpy.context.scene.objects:
            obj.select_set(obj.type in ("MESH", "ARMATURE"))
            if obj.type == "MESH":
                per_mesh[obj.name] = triangles(obj)
        path = OUT / ("frontier_%s_%d.glb" % (kind, level))
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                                  export_frame_step=1, export_animations=True, export_morph=True,
                                  export_morph_animation=False, export_def_bones=False)
        # The same post-export repairs as build_frontier_people.export():
        # grounded death and gather clips, closed skirt seam, kit rivets.
        death_ground = frontier.soldier.death_ground.ground(path)
        gather_ground = frontier.soldier.death_ground.ground(path, None, "gather")
        seam = frontier.skirt_seam.smooth(path)
        rivets = frontier.kit_rivets.rebind(path)
        keys = {}
        for obj in meshes():
            if obj.data.shape_keys:
                keys[obj.name] = [k.name for k in obj.data.shape_keys.key_blocks[1:]]
        records.append({"lod": level, "path": str(path.relative_to(ROOT)), "triangles": total,
                        "base_triangles": base, "piece_ratio": round(fitted, 4),
                        "piece_triangles": {n: per_mesh[n] for n in PIECES if n in per_mesh},
                        "bytes": path.stat().st_size, "sha256": digest(path), "texture_edge": edge,
                        "face_morphs": near, "belt_fit": belt_fit, "rig": rig,
                        "death_ground_contact": {key: death_ground[key] for key in ("before", "after", "maximum_floor_correction_m")},
                        "skirt_seam": {key: seam[key] for key in ("before", "after", "unchanged") if key in seam},
                        "gather_ground_contact": {key: gather_ground[key] for key in ("before", "after", "unchanged") if key in gather_ground},
                        "kit_rivets": {"rebound": sum(entry["applied"] for entry in rivets.get("islands", [])),
                                       "snapped": len(rivets.get("snapped", [])), **({"unchanged": rivets["unchanged"]} if "unchanged" in rivets else {})},
                        "shape_keys": keys})
        print("RESIDENT_LOD", kind, level, total, base, round(fitted, 4), per_mesh)
    return records


_FRONTIER = None


def _frontier_module():
    global _FRONTIER
    if _FRONTIER is None:
        import importlib.util
        spec = importlib.util.spec_from_file_location("resident_frontier_source", ROOT / "tools/characters/build_frontier_people.py")
        _FRONTIER = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_FRONTIER)
    return _FRONTIER


def update_frontier_report(records):
    path = SOURCE / "build_report.json"
    report = json.loads(path.read_text())
    by_kind = {r["identity"]: r for r in records}
    for entry in report["identities"]:
        if entry["identity"] in by_kind:
            entry["lods"] = [{k: v for k, v in lod.items() if k not in ("shape_keys", "piece_triangles")}
                             for lod in by_kind[entry["identity"]]["lods"]]
            entry["identity_pass"] = "art/village_characters/build_resident_identity.py"
    path.write_text(json.dumps(report, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--kinds", nargs="+", choices=KINDS, default=list(KINDS))
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    run(args.kinds)


def run(kinds):
    """Also called by tools/characters/build_frontier_people.py after it
    re-exports civilian kinds, so a frontier rebuild keeps the identity layer."""
    args = argparse.Namespace(kinds=[k for k in KINDS if k in kinds])
    OUT.mkdir(parents=True, exist_ok=True)
    previous = json.loads(REPORT.read_text()).get("identities", []) if REPORT.exists() else []
    records = []
    for kind in args.kinds:
        source_path, L, masks = build_identity(kind)
        lods = export(kind, source_path)
        records.append({"identity": kind, "landmarks": {k: round(v, 5) for k, v in L.items()},
                        "masks": masks, "lods": lods,
                        "source_blend_sha256": digest(SOURCE / (kind + ".blend"))})
        source_path.unlink(missing_ok=True)
    combined = [r for r in previous if r["identity"] not in args.kinds] + records
    combined.sort(key=lambda r: KINDS.index(r["identity"]))
    REPORT.write_text(json.dumps({"generator": str(Path(__file__).relative_to(ROOT)), "blender": bpy.app.version_string,
                                  "budget_per_lod": list(BUDGET), "face_keys": list(FACE_KEYS), "body_keys": list(BODY_KEYS),
                                  "hair_keys": list(HAIR_KEYS), "pieces": list(PIECES), "identities": combined,
                                  "limits": ["Procedural geometry controls on the existing CC0-derived anatomy; no new scans.",
                                             "Beard, veil and mantle are skinned shells, not strand hair or cloth simulation.",
                                             "No Android device measurement."]}, indent=2) + "\n")
    update_frontier_report(records)
    print("RESIDENT_IDENTITY_COMPLETE", ",".join(args.kinds))


if __name__ == "__main__":
    main()
