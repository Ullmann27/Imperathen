"""Procedural textures for the Valdora vegetation (58 BC, Aquileia region).

Everything is painted from code: no photographs, scans or third-party images.
Run with a system Python that has NumPy and Pillow (Blender's bundled Python
has no Pillow):

    python3 art/vegetation/textures.py            # all textures
    python3 art/vegetation/textures.py bark leaf  # a subset

Outputs (prototype/assets/vegetation/textures/):
  bark_<type>_albedo.png / _normal.png   tileable 512 x 512, u around the stem
  leaf_<species>_albedo.png (RGBA) / _normal.png   1024 x 1024, 2 x 2 tiles:
      tiles 0-2 single twig sprays, tile 3 a dense cluster for far LODs
  herbs_albedo.png   2048 x 2048, 4 x 4 meadow and wetland clump cards
  crops_albedo.png   2048 x 2048, 4 x 4 field and garden clump cards
Normal maps use the OpenGL convention (+Y up), like Godot and Blender.
"""
import math
from pathlib import Path
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from species import CROP_TILES, HERB_TILES  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "prototype/assets/vegetation/textures"


# ---------------------------------------------------------------- helpers

def periodic_noise(size, scale, seed, power=1.0):
    """Tileable band-limited noise by spectral filtering of white noise.
    scale=(sx, sy) are feature counts across the tile in u and v."""
    h, w = size
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    radius = np.sqrt((fx / max(scale[0], .01)) ** 2 + (fy / max(scale[1], .01)) ** 2)
    filt = np.exp(-radius ** 2) * (1.0 + radius) ** (-power)
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    field -= field.mean()
    return field / (np.abs(field).max() + 1e-9)


def fbm(size, scale, seed, octaves=4, gain=.5):
    total = np.zeros(size)
    amp = 1.0
    for octave in range(octaves):
        total += amp * periodic_noise(size, (scale[0] * 2 ** octave, scale[1] * 2 ** octave), seed + octave * 31)
        amp *= gain
    return total / (2 - gain ** (octaves - 1))


def warp(field, du, dv):
    """Periodic domain warp with integer-rounded offsets (keeps tiling)."""
    h, w = field.shape
    rows = (np.arange(h)[:, None] + np.round(dv).astype(int)) % h
    cols = (np.arange(w)[None, :] + np.round(du).astype(int)) % w
    return field[rows, cols]


def worley(size, cells, seed, warp_u=None, warp_v=None, jitter=.85):
    """Tileable cellular noise on a jittered grid: returns (F1, F2, cell id)."""
    h, w = size
    gx, gy = cells
    rng = np.random.default_rng(seed)
    points = rng.uniform(.5 - jitter / 2, .5 + jitter / 2, (gy, gx, 2))
    ids = rng.uniform(0, 1, (gy, gx))
    v, u = np.mgrid[0:h, 0:w].astype(float)
    u = u / w * gx
    v = v / h * gy
    if warp_u is not None:
        u = u + warp_u * gx
    if warp_v is not None:
        v = v + warp_v * gy
    cu, cv = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = u - cu, v - cv
    f1 = np.full(size, 9.0)
    f2 = np.full(size, 9.0)
    cid = np.zeros(size)
    for dv in (-1, 0, 1):
        for du in (-1, 0, 1):
            nu, nv = (cu + du) % gx, (cv + dv) % gy
            px = points[nv, nu, 0] + du - fu
            py = points[nv, nu, 1] + dv - fv
            # Grid-space distance: each plate is as stretched as its grid cell.
            d = np.sqrt(px * px + py * py)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, ids[nv, nu], cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


def box_blur(a, radius):
    """Separable box blur with clamped edges (float arrays, any channel count)."""
    out = a
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (radius + 1, radius)
        c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
        hi = np.take(c, np.arange(2 * radius + 1, c.shape[axis]), axis=axis)
        lo = np.take(c, np.arange(0, c.shape[axis] - 2 * radius - 1), axis=axis)
        out = (hi - lo) / (2 * radius + 1)
    return out


def normalize01(a):
    a = a - a.min()
    return a / (a.max() + 1e-9)


def height_to_normal(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * .5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * .5
    n = np.dstack((-dx * strength, dy * strength, np.ones_like(height)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(np.uint8(np.clip((n * .5 + .5) * 255 + .5, 0, 255)), "RGB")


def to_rgb(arr):
    return Image.fromarray(np.uint8(np.clip(arr * 255 + .5, 0, 255)), "RGB")


def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


def srgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return np.array([int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# ------------------------------------------------------------------ bark
# Each type is described by botanical habit: furrow network (stretched,
# warped ridged noise), plate cracks, lichen, lenticels, streaks or peel.
BARK = {
    # Quercus robur: thick, deeply and longitudinally fissured grey-brown bark.
    "oak": dict(cells=(16, 3), fissure=.30, seed=11, furrow=(6.0, .55), depth=1.0, sharp=2.6, cracks=4.5, crack_depth=.55, warp=14,
                ridge="#8a8174", crevice="#2d251d", tint="#6f6253", lichen=.16, normal=7.5),
    # Quercus cerris: very deep fissures with orange-red bases.
    "cerris": dict(cells=(18, 3), fissure=.34, seed=17, furrow=(7.0, .6), depth=1.0, sharp=3.0, cracks=6.0, crack_depth=.5, warp=12,
                   ridge="#7f776c", crevice="#5e2e1a", tint="#6a5c50", lichen=.12, normal=8.0),
    # Ulmus minor: corky, interlaced ridges broken into small rectangles.
    "elm": dict(cells=(20, 5), fissure=.26, seed=23, furrow=(8.0, .9), depth=.85, sharp=2.0, cracks=9.0, crack_depth=.7, warp=10,
                ridge="#7b7064", crevice="#2b241e", tint="#695d50", lichen=.10, normal=7.0),
    # Fraxinus angustifolia: grey with a fine net of diamond-shaped fissures.
    "ash": dict(cells=(22, 7), fissure=.16, seed=29, furrow=(10.0, 2.0), depth=.6, sharp=1.6, cracks=0.0, crack_depth=0, warp=22,
                ridge="#8e8b80", crevice="#45403a", tint="#7d7a6f", lichen=.18, normal=5.0),
    # Carpinus betulus: smooth, fluted, silver-grey with paler vertical streaks.
    "hornbeam": dict(seed=31, furrow=(2.0, .5), depth=.18, sharp=1.0, cracks=0.0, crack_depth=0, warp=6,
                     ridge="#9a9890", crevice="#6d6a63", tint="#8c8a82", lichen=.22, normal=2.6, streaks=1.0),
    # Populus nigra: dark, very deep, coarse furrows; burrs on old trunks.
    "poplar": dict(cells=(12, 2), fissure=.38, seed=37, furrow=(5.0, .5), depth=1.0, sharp=2.2, cracks=3.0, crack_depth=.45, warp=18,
                   ridge="#6a6359", crevice="#1f1a16", tint="#55504a", lichen=.08, normal=8.5),
    # Salix alba: grey-brown, deep criss-crossing interlaced ridges.
    "willow": dict(cells=(15, 3), fissure=.30, seed=41, furrow=(6.5, .7), depth=.95, sharp=1.8, cracks=2.0, crack_depth=.35, warp=26,
                   ridge="#7e7566", crevice="#2c2620", tint="#6b6255", lichen=.20, normal=7.5),
    # Alnus glutinosa: dark grey-brown, small irregular plates.
    "alder": dict(cells=(22, 9), fissure=.2, seed=43, furrow=(9.0, 3.0), depth=.65, sharp=1.6, cracks=8.0, crack_depth=.6, warp=8,
                  ridge="#5a5650", crevice="#221e1b", tint="#4c4844", lichen=.12, normal=6.0, lenticels=.25),
    # Acer campestre: light brown corky ridges, frequently cracked across.
    "maple": dict(cells=(20, 7), fissure=.24, seed=47, furrow=(9.0, 1.4), depth=.75, sharp=1.8, cracks=11.0, crack_depth=.75, warp=8,
                  ridge="#8d7b63", crevice="#3a2d21", tint="#79684f", lichen=.14, normal=6.5),
    # Corylus avellana: smooth glossy grey-brown with pale horizontal lenticels.
    "hazel": dict(seed=53, furrow=(1.5, .5), depth=.12, sharp=1.0, cracks=0.0, crack_depth=0, warp=4,
                  ridge="#8a7660", crevice="#5d4b3a", tint="#7d6955", lichen=.10, normal=2.2, lenticels=1.0),
    # Crataegus / Prunus spinosa: dark grey, finely scaled.
    "thorn": dict(cells=(26, 12), fissure=.2, seed=59, furrow=(12.0, 4.0), depth=.55, sharp=1.5, cracks=12.0, crack_depth=.5, warp=6,
                  ridge="#5b5550", crevice="#1d1916", tint="#4b4642", lichen=.15, normal=5.0),
    # Sambucus nigra: pale corky ridges with deep furrows.
    "elder": dict(cells=(16, 4), fissure=.3, seed=61, furrow=(7.0, 1.0), depth=.8, sharp=1.4, cracks=5.0, crack_depth=.4, warp=12,
                  ridge="#9b8f7c", crevice="#4d4033", tint="#857965", lichen=.10, normal=6.0, lenticels=.3),
    # Vitis vinifera stem (left half) and weathered split oak stake (right half).
    "vine": dict(seed=67, furrow=(14.0, .45), depth=.75, sharp=1.2, cracks=0.0, crack_depth=0, warp=5,
                 ridge="#7a6450", crevice="#3a2a1d", tint="#6c5644", lichen=.0, normal=6.0, peel=1.0, stake=True),
}


def bark_texture(name, p, size=512):
    shape = (size, size)
    seed = p["seed"]
    # Base furrow network: ridged, strongly stretched noise, domain warped so
    # ridges braid and merge like real bark instead of running as stripes.
    wu = fbm(shape, (3, 2), seed + 1, 3) * p["warp"]
    wv = fbm(shape, (2, 3), seed + 2, 3) * p["warp"] * .6
    n = fbm(shape, p["furrow"], seed, 4, .55)
    n = warp(n, wu, wv)
    if p.get("cells"):
        # Plates are stretched Voronoi cells; the fissure is where the two
        # nearest plate centres are equally far (F2 - F1 -> 0). Low-frequency
        # warp makes the vertical furrows braid, merge and split.
        f1, f2, cid = worley(shape, p["cells"], seed, wu / size * 1.6, wv / size * .6)
        edge = (f2 - f1) * (1 + .35 * fbm(shape, (30, 6), seed + 19, 2))
        fw = p["fissure"]
        plates = np.clip(edge / fw, 0, 1)
        plates = np.sqrt(plates * plates * (3 - 2 * plates))  # rounded shoulders, V-shaped core
        core = 1 - np.clip(edge / (fw * .28), 0, 1)
        crown = 1 - np.clip(f1 / 1.2, 0, 1)
        ridges = plates
        height = (1.0 - (1.0 - plates) * p["depth"]) * (.82 + .18 * crown) * (.92 + .08 * cid)
        height *= 1 - .35 * core * p["depth"]
        plate_tone = cid
        # Fibrous texture inside the furrows and fine scaling on the plates.
        fibre = normalize01(fbm(shape, (40, 3), seed + 8, 3))
        height = height * (.88 + .12 * fibre) + (1 - plates) * .08 * fibre
    else:
        plate_tone = None
        a = np.abs(n) / (n.std() + 1e-9)
        width = 1.1 / p["sharp"]
        plates = np.clip(a / width, 0, 1)
        plates = plates * plates * (3 - 2 * plates)
        ridges = plates
        height = 1.0 - (1.0 - plates) * p["depth"]
        height *= .82 + .18 * normalize01(fbm(shape, (p["furrow"][0] * 1.5, p["furrow"][1] * 3), seed + 4, 3))
    if p.get("diamond"):
        # Young ash: fine interlocking diamond net.
        y, x = np.mgrid[0:size, 0:size] / size
        k = p["diamond"]
        d = np.abs(np.sin(math.pi * (k * x + 2.0 * k * y + .4 * n))) * np.abs(np.sin(math.pi * (k * x - 2.0 * k * y + .4 * n)))
        height = height * .55 + .45 * normalize01(1 - d ** .25)
    if p["cracks"] > 0:
        # Horizontal cracks split the ridges into plates (vertical spacing ~1/cracks).
        # Cross cracks: short, mostly horizontal breaks that cut ridges into plates.
        c = fbm(shape, (1.6, p["cracks"]), seed + 5, 3)
        c = c / (c.std() + 1e-9)
        segments = np.clip(fbm(shape, (p["cracks"] * .8, p["cracks"] * .5), seed + 6, 2) * 3 + .2, 0, 1)
        crack = (1 - np.clip(np.abs(c) / .12, 0, 1)) * segments * (.3 if p.get("cells") else 1.0)
        height = height * (1 - p["crack_depth"] * crack * ridges)
    if p.get("streaks"):
        y, x = np.mgrid[0:size, 0:size] / size
        streak = normalize01(fbm(shape, (14, .35), seed + 7, 3))
        height = height * .85 + .15 * streak
    if p.get("peel"):
        # Vine: long fibrous strips peeling away from the stem.
        strip = normalize01(fbm(shape, (18, .3), seed + 9, 4))
        height = height * .5 + .5 * (strip ** 1.6)
    fine = fbm(shape, (48, 36), seed + 3, 3) * .09
    height = normalize01(height + fine)
    ridge, crevice, tint = srgb(p["ridge"]), srgb(p["crevice"]), srgb(p["tint"])
    hue = fbm(shape, (2, 3), seed + 11, 3)
    base = lerp(tint, ridge, np.clip(hue * .5 + .5, 0, 1))
    color = lerp(crevice, base, np.clip(height ** 1.6, 0, 1))
    if plate_tone is not None:
        color *= (.9 + .2 * plate_tone)[..., None]
    color *= (1.0 + fine[..., None] * 1.6)
    if p["lichen"] > 0:
        lichen = np.clip((fbm(shape, (4, 5), seed + 13, 4) - .25) * 3.0, 0, 1) * p["lichen"] * 2.2
        lichen *= np.clip(height * 1.2, 0, 1)
        speck = np.clip((fbm(shape, (60, 60), seed + 17, 2) - .1) * 4, 0, 1)
        color = lerp(color, srgb("#9aa184"), np.clip(lichen * (.4 + .6 * speck), 0, .8))
    if p.get("lenticels"):
        rng = random.Random(seed)
        mask = Image.new("L", shape[::-1], 0)
        draw = ImageDraw.Draw(mask)
        for _ in range(int(900 * p["lenticels"])):
            x, y = rng.uniform(0, size), rng.uniform(0, size)
            length = rng.uniform(3, 9)
            for ox in (-size, 0, size):
                draw.line((x + ox - length, y, x + ox + length, y), fill=255, width=rng.choice((1, 2)))
        lent = np.asarray(mask.filter(ImageFilter.GaussianBlur(.6)), dtype=float) / 255
        color = lerp(color, srgb("#c4b49a"), lent * .7)
        height = np.clip(height + lent * .12, 0, 1)
    if p.get("stake"):
        # Right half: weathered split oak stake with grain and drying checks.
        half = size // 2
        y, x = np.mgrid[0:size, 0:half]
        grain = normalize01(fbm((size, half), (30, .7), seed + 21, 4))
        check = np.clip(1 - np.abs(fbm((size, half), (5, 1.2), seed + 23, 3)) * 14, 0, 1)
        wood_h = .55 + .35 * grain - .45 * check
        wood_c = lerp(srgb("#4f4a43"), srgb("#9b958a"), np.clip(grain * .9 + .1, 0, 1))
        wood_c = lerp(wood_c, srgb("#2b2724"), check * .8)
        height[:, half:] = wood_h
        color[:, half:] = wood_c
    # Crevices also receive less light: bake a mild cavity term into albedo.
    color *= (.62 + .38 * height[..., None])
    to_rgb(color).save(OUT / f"bark_{name}_albedo.png", optimize=True)
    height_to_normal(height, p["normal"]).save(OUT / f"bark_{name}_normal.png", optimize=True)


# ---------------------------------------------------------------- leaves
# Leaf length is in centimetres, card spans are the metres covered by a tile.
LEAVES = {
    "oak": dict(seed=101, shape="oak", length=10, width=.36, petiole=.04, color="#4c6a2c", under="#7f9466",
                veins=5, serr=0, phyllo="clustered", card=.55, cluster_card=1.3, density=1.0),
    "cerris": dict(seed=103, shape="cerris", length=11, width=.30, petiole=.12, color="#516f2f", under="#8c9a78",
                   veins=7, serr=0, phyllo="alternate", card=.55, cluster_card=1.3, density=1.0),
    "elm": dict(seed=107, shape="elm", length=8, width=.30, petiole=.06, color="#4f6d27", under="#7d9160",
                veins=12, serr=.05, phyllo="distichous", card=.5, cluster_card=1.25, density=1.1),
    "ash": dict(seed=109, shape="pinnate", length=5.5, width=.22, petiole=.0, color="#5a7a31", under="#88a06a",
                veins=8, serr=.03, phyllo="pinnate", leaflets=9, card=.6, cluster_card=1.4, density=.8),
    "hornbeam": dict(seed=113, shape="hornbeam", length=8, width=.30, petiole=.07, color="#4d7230", under="#7e9a62",
                     veins=13, serr=.05, phyllo="distichous", card=.5, cluster_card=1.25, density=1.15),
    "poplar": dict(seed=127, shape="deltoid", length=8, width=.48, petiole=.5, color="#567a2b", under="#8aa06a",
                   veins=6, serr=.03, phyllo="alternate", card=.55, cluster_card=1.35, density=.95),
    "willow": dict(seed=131, shape="lanceolate", length=9, width=.10, petiole=.05, color="#627b4c", under="#b7c0ad",
                   veins=16, serr=.02, phyllo="alternate", card=.5, cluster_card=1.25, density=1.3, two_tone=.45),
    "alder": dict(seed=137, shape="round", length=7.5, width=.45, petiole=.2, color="#3e5d26", under="#6f8a55",
                  veins=7, serr=.04, notch=True, phyllo="alternate", card=.5, cluster_card=1.25, density=1.0),
    "maple": dict(seed=139, shape="maple", length=6, width=1.0, petiole=.5, color="#58792f", under="#86a066",
                  veins=5, serr=0, phyllo="opposite", card=.45, cluster_card=1.15, density=1.1),
    "hazel": dict(seed=149, shape="hazel", length=9, width=.46, petiole=.12, color="#577530", under="#89a06a",
                  veins=7, serr=.06, phyllo="distichous", card=.5, cluster_card=1.2, density=.95),
    "hawthorn": dict(seed=151, shape="hawthorn", length=4, width=1.0, petiole=.3, color="#466a2a", under="#7b955f",
                     veins=4, serr=0, phyllo="clustered", card=.4, cluster_card=1.0, density=1.4),
    "blackthorn": dict(seed=157, shape="elliptic", length=3.5, width=.32, petiole=.1, color="#4b6a30", under="#7c9263",
                       veins=6, serr=.06, phyllo="clustered", card=.35, cluster_card=.95, density=1.5),
    "elder": dict(seed=163, shape="pinnate", length=7, width=.32, petiole=.0, color="#527a2c", under="#86a167",
                  veins=8, serr=.05, phyllo="pinnate", leaflets=5, card=.6, cluster_card=1.3, density=.85, umbels=True),
    "vine": dict(seed=167, shape="vine", length=13, width=1.0, petiole=.45, color="#5b7d2e", under="#94aa76",
                 veins=5, serr=0, phyllo="alternate", card=.6, cluster_card=1.3, density=.75, grapes=True),
}


def _tri(x):
    return 1 - 2 * np.abs((x % 1) - .5)


def leaf_outline(p, rng):
    """Leaf outline in leaf space: x along the midrib (0 base .. 1 tip), y across.
    Returns (polygon points, vein list)."""
    shape = p["shape"]
    n = 64
    t = np.linspace(0, 1, n)
    if shape in ("maple", "hawthorn", "vine"):
        # Palmate: polar outline around the petiole junction.
        lobes = {"maple": 5, "hawthorn": 5, "vine": 5}[shape]
        depth = {"maple": .52, "hawthorn": .64, "vine": .44}[shape]
        theta = np.linspace(-math.pi * .92, math.pi * .92, 140)
        lobe = np.abs(np.cos(theta * lobes / 2 / .92)) ** ({"maple": .9, "hawthorn": .35, "vine": .75}[shape])
        r = (1 - depth) + depth * lobe
        r *= .55 + .45 * np.cos(theta / 1.9) ** 2
        if shape == "vine":
            r *= 1 + .06 * _tri(theta * 9)
        if shape == "hawthorn":
            r *= .9 + .1 * np.cos(theta * 2)
        r *= rng.uniform(.92, 1.06)
        center = .42
        xs = center + r * np.cos(theta) * .55
        ys = r * np.sin(theta) * .55
        pts = list(zip(xs, ys))
        veins = [((center, 0), (center + .55 * math.cos(a), .55 * math.sin(a))) for a in np.linspace(-1.9, 1.9, lobes)]
        return [(0, 0)] + pts + [(0, 0)], veins
    if shape == "oak":
        env = np.sin(math.pi * np.clip(t, 0, 1) ** 1.25) ** .8
        lob = .55 + .45 * np.abs(np.cos(math.pi * 4.5 * t + .3)) ** .7
        auricle = 1 + .5 * np.exp(-((t - .05) / .04) ** 2)
        w = env * lob * auricle
    elif shape == "cerris":
        env = np.sin(math.pi * t ** 1.05) ** .9
        lob = .35 + .65 * _tri(t * 6.5 + .25) ** .8
        w = env * lob
    elif shape in ("elm", "hornbeam", "hazel", "elliptic"):
        a = {"elm": .95, "hornbeam": .95, "hazel": 1.1, "elliptic": 1.0}[shape]
        env = np.sin(math.pi * t ** a) ** .75
        if shape == "hazel":
            env = np.sin(math.pi * t ** 1.15) ** .55 * (1 - .35 * np.clip((t - .82) / .18, 0, 1))
        w = env
    elif shape == "lanceolate":
        w = np.sin(math.pi * t) ** .9
    elif shape == "deltoid":
        w = np.minimum(t / .2, (1 - t) / .8) ** .85
    elif shape == "round":
        w = np.sin(math.pi * t ** .85) ** .5
        if p.get("notch"):
            w *= 1 - .25 * np.exp(-((t - 1) / .06) ** 2)
    else:
        w = np.sin(math.pi * t) ** .8
    if p.get("serr"):
        w = w * (1 + p["serr"] * (_tri(t * 26) - .5) + p["serr"] * .6 * (_tri(t * 52) - .5))
    width = p["width"] * rng.uniform(.88, 1.1)
    left_scale = 1.0
    if shape == "elm":
        left_scale = 1.12  # elm: asymmetric leaf base
    left = [(float(x), float(y) * width * left_scale) for x, y in zip(t, w)]
    right = [(float(x), -float(y) * width) for x, y in zip(t, w)]
    if shape == "elm":
        left = [(x + .06 * (1 - x), y) for x, y in left]
    veins = []
    count = p["veins"]
    for k in range(count):
        x0 = .08 + .8 * (k + .5) / count
        idx = min(n - 1, int((x0 + .12) * (n - 1)))
        for side, pts in ((1, left), (-1, right)):
            x1, y1 = pts[idx]
            veins.append(((x0, 0), (x1, y1 * .9)))
    return left + right[::-1], veins


def draw_leaf(canvas, height, base, angle, length, p, rng, under=False, alpha_draw=None):
    """Draw one leaf (blade, midrib, veins) into colour/height canvases."""
    outline, veins = leaf_outline(p, rng)
    foreshorten = rng.uniform(.55, 1.0)
    roll = rng.uniform(-.2, .2)
    ca, sa = math.cos(angle), math.sin(angle)

    def tx(pt):
        x, y = pt
        y = y * foreshorten + roll * x * .2
        return (base[0] + (x * ca - y * sa) * length, base[1] + (x * sa + y * ca) * length)

    poly = [tx(pt) for pt in outline]
    top = srgb(p["under"] if under else p["color"])
    variation = rng.uniform(.78, 1.18)
    hue = np.array([rng.uniform(.96, 1.05), 1.0, rng.uniform(.9, 1.06)])
    color = np.clip(top * variation * hue, 0, 1)
    if rng.random() < .035 and not under:
        color = np.clip(color * np.array([1.45, 1.15, .55]), 0, 1)  # yellowing leaf
    rgb = tuple(int(c * 255) for c in color)
    cd = ImageDraw.Draw(canvas)
    hd = ImageDraw.Draw(height)
    # Petiole
    if p["petiole"] > 0:
        stalk_end = base
        stalk_start = (base[0] - ca * length * p["petiole"], base[1] - sa * length * p["petiole"])
        cd.line((stalk_start, stalk_end), fill=tuple(int(c * 205) for c in color) + (255,), width=max(2, int(length * .03)))
        hd.line((stalk_start, stalk_end), fill=150, width=max(2, int(length * .03)))
    cd.polygon(poly, fill=rgb + (255,))
    # The two blade halves fold slightly along the midrib.
    half = len(outline) // 2
    hd.polygon(poly[:half + 1] + [tx((0, 0))], fill=int(rng.uniform(150, 175)))
    hd.polygon(poly[half:] + [tx((0, 0))], fill=int(rng.uniform(120, 145)))
    vein_rgb = tuple(int(min(255, c * 255 * 1.28 + 18)) for c in color) + (255,)
    cd.line((tx((0, 0)), tx((.97, 0))), fill=vein_rgb, width=max(2, int(length * .022)))
    hd.line((tx((0, 0)), tx((.97, 0))), fill=95, width=max(2, int(length * .03)))
    for a, b in veins:
        cd.line((tx(a), tx(b)), fill=tuple(int(c * .55 + v * .45) for c, v in zip(rgb, vein_rgb[:3])) + (255,), width=max(1, int(length * .009)))
        hd.line((tx(a), tx(b)), fill=110, width=max(1, int(length * .014)))


def draw_pinnate(canvas, height, base, angle, length, p, rng):
    """Compound leaf: rachis with opposite leaflets and a terminal leaflet."""
    count = p["leaflets"]
    ca, sa = math.cos(angle), math.sin(angle)
    rachis = length * (count // 2 + 1) * .55
    end = (base[0] + ca * rachis, base[1] + sa * rachis)
    ImageDraw.Draw(canvas).line((base, end), fill=(86, 98, 48, 255), width=max(2, int(length * .04)))
    ImageDraw.Draw(height).line((base, end), fill=140, width=max(2, int(length * .04)))
    sub = dict(p, shape="elliptic" if p["seed"] != 109 else "lanceolate", width=p["width"] * 1.0, petiole=.05)
    pairs = count // 2
    for k in range(pairs):
        f = (k + .7) / (pairs + .6)
        at = (base[0] + ca * rachis * f, base[1] + sa * rachis * f)
        for side in (-1, 1):
            leaf_angle = angle + side * rng.uniform(.95, 1.25) - side * .25 * f
            draw_leaf(canvas, height, at, leaf_angle, length * rng.uniform(.85, 1.05), sub, rng)
    draw_leaf(canvas, height, end, angle, length * 1.05, sub, rng)


def branch_path(start, angle, length, bend, steps=12):
    pts = [start]
    a = angle
    x, y = start
    for i in range(steps):
        a += bend / steps
        x += math.cos(a) * length / steps
        y += math.sin(a) * length / steps
        pts.append((x, y))
    return pts


def draw_spray(canvas, height, origin, angle, span_px, p, rng, cluster=False):
    """A twig spray: woody axis with side shoots carrying individual leaves."""
    leaf_px = p["length"] / 100.0 / (p["cluster_card"] if cluster else p["card"]) * span_px
    if cluster:
        # Far LODs read as foliage mass: leaves are drawn larger than life.
        leaf_px *= 2.6
    path = branch_path(origin, angle, span_px * rng.uniform(.78, .92), rng.uniform(-.5, .5))
    cd = ImageDraw.Draw(canvas)
    hd = ImageDraw.Draw(height)
    for i in range(len(path) - 1):
        w = max(1, int(span_px * .018 * (1 - i / len(path)) + 1))
        cd.line((path[i], path[i + 1]), fill=(92, 78, 58, 255), width=w)
        hd.line((path[i], path[i + 1]), fill=170, width=w)
    phyllo = p["phyllo"]
    density = p["density"]
    nodes = int((22 if cluster else 15) * density) + rng.randint(0, 3)
    pinnate = phyllo == "pinnate"
    if pinnate:
        nodes = max(3, int(nodes * .45))
    items = []
    for k in range(nodes):
        f = .12 + .86 * k / max(1, nodes - 1)
        idx = min(len(path) - 1, int(f * (len(path) - 1)))
        at = path[idx]
        a0 = math.atan2(path[min(idx + 1, len(path) - 1)][1] - path[max(idx - 1, 0)][1],
                        path[min(idx + 1, len(path) - 1)][0] - path[max(idx - 1, 0)][0])
        sides = (-1, 1) if phyllo in ("opposite", "pinnate") else ((-1,) if k % 2 else (1,))
        for side in sides:
            if phyllo == "clustered" and k % 3 == 2:
                # Oak, hawthorn: leaves crowd at short shoots.
                for j in range(3):
                    items.append((at, a0 + side * rng.uniform(.4, 1.3) + (j - 1) * .45, leaf_px * rng.uniform(.75, 1.05)))
                continue
            spread = rng.uniform(.55, 1.15) if phyllo != "distichous" else rng.uniform(.95, 1.35)
            items.append((at, a0 + side * spread, leaf_px * rng.uniform(.8, 1.12) * (1 - .25 * f)))
    # Terminal leaf
    items.append((path[-1], math.atan2(path[-1][1] - path[-2][1], path[-1][0] - path[-2][0]), leaf_px * .85))
    rng.shuffle(items)
    for at, a, length in items:
        under = rng.random() < (p.get("two_tone", .12))
        if pinnate:
            draw_pinnate(canvas, height, at, a, length, p, rng)
        else:
            draw_leaf(canvas, height, at, a, length, p, rng, under)
    if p.get("grapes") and rng.random() < .8:
        # Ripening bunch of small dark grapes hanging below the shoot.
        at = path[len(path) // 2]
        for g in range(46):
            gx = at[0] + rng.gauss(0, span_px * .035)
            gy = at[1] + abs(rng.gauss(span_px * .09, span_px * .05))
            r = span_px * .012
            shade = rng.uniform(.75, 1.15)
            cd.ellipse((gx - r, gy - r, gx + r, gy + r), fill=(int(62 * shade), int(36 * shade), int(70 * shade), 255))
            hd.ellipse((gx - r, gy - r, gx + r, gy + r), fill=210)
    if p.get("umbels") and rng.random() < .7:
        # Elder: flat cream flower umbels at the shoot tip (early summer).
        at = path[-1]
        for g in range(90):
            a = rng.uniform(0, math.tau)
            d = span_px * .1 * math.sqrt(rng.random())
            r = span_px * .006
            gx, gy = at[0] + math.cos(a) * d, at[1] + math.sin(a) * d * .45
            cd.ellipse((gx - r, gy - r, gx + r, gy + r), fill=(236, 228, 196, 255))


def finish_atlas(canvas, height, name, out_size):
    """Supersampled -> output, colour dilated into transparent texels."""
    canvas = canvas.resize((out_size, out_size), Image.LANCZOS)
    height = height.resize((out_size, out_size), Image.LANCZOS)
    arr = np.asarray(canvas).astype(float) / 255
    alpha = arr[..., 3]
    rgb = arr[..., :3]
    # Premultiplied dilation: spread leaf colour outward so mip levels and
    # linear filtering never pull in black or background texels.
    filled = rgb * alpha[..., None]
    weight = alpha.copy()
    acc_c, acc_w = filled.copy(), weight.copy()
    for radius in (1, 2, 4, 8, 16, 32):
        blur_c = box_blur(filled, radius)
        blur_w = box_blur(weight, radius)
        need = acc_w < .5
        acc_c[need] = blur_c[need]
        acc_w[need] = blur_w[need]
    color = np.where(alpha[..., None] > .02, rgb, acc_c / np.maximum(acc_w[..., None], 1e-4))
    out = np.dstack((np.clip(color, 0, 1), alpha))
    Image.fromarray(np.uint8(out * 255 + .5), "RGBA").save(OUT / f"{name}_albedo.png", optimize=True)
    h = np.asarray(height.filter(ImageFilter.GaussianBlur(1.0))).astype(float) / 255
    height_to_normal(h, 3.2).save(OUT / f"{name}_normal.png", optimize=True)


def leaf_atlas(species, size=1024):
    p = LEAVES[species]
    rng = random.Random(p["seed"])
    big = size * 2
    tile = big // 2
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    height = Image.new("L", (big, big), 128)
    for variant in range(4):
        ox, oy = (variant % 2) * tile, (variant // 2) * tile
        tile_c = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
        tile_h = Image.new("L", (tile, tile), 128)
        if variant < 3:
            # Card base is the bottom centre of the tile (attachment point).
            draw_spray(tile_c, tile_h, (tile * .5, tile * .97), -math.pi / 2 + rng.uniform(-.12, .12), tile * .98, p, rng)
            for side in (-1, 1, -1, 1):
                draw_spray(tile_c, tile_h, (tile * .5 + rng.uniform(-12, 12), tile * rng.uniform(.45, .8)),
                           -math.pi / 2 + side * rng.uniform(.45, .9), tile * rng.uniform(.42, .6), p, rng)
        else:
            # Dense cluster for far LODs: many sprays radiating from the base.
            for k in range(16):
                a = -math.pi / 2 + (k - 7.5) * .12 + rng.uniform(-.08, .08)
                draw_spray(tile_c, tile_h, (tile * .5 + rng.uniform(-30, 30), tile * rng.uniform(.82, .97)), a, tile * rng.uniform(.5, .78), p, rng, cluster=True)
        # Fade the lower stem area slightly darker: inner foliage self-shadow.
        arr = np.asarray(tile_c).astype(float)
        yy = np.linspace(0, 1, tile)[:, None]
        arr[..., :3] *= (.82 + .18 * (1 - yy) ** .7)[..., None] if False else (.80 + .20 * (1 - yy))[..., None]
        tile_c = Image.fromarray(np.uint8(np.clip(arr, 0, 255)), "RGBA")
        canvas.paste(tile_c, (ox, oy))
        height.paste(tile_h, (ox, oy))
    finish_atlas(canvas, height, f"leaf_{species}", size)


# ----------------------------------------------------------- herb cards

def blade(draw, base, height_px, lean, width, color, rng, curl=.0):
    """Tapering grass blade as a quadratic curve polygon."""
    steps = 10
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        x = base[0] + lean * height_px * t ** 1.8 + curl * height_px * t ** 3
        y = base[1] - height_px * (t - .25 * abs(lean) * t ** 2)
        w = width * (1 - t) ** .8 + .6
        left.append((x - w, y))
        right.append((x + w, y))
    draw.polygon(left + right[::-1], fill=color)
    return left[-1]


def grass_tile(draw, tile, rng, kind):
    w, h = tile
    if kind == "meadow":
        greens = ["#5d7a35", "#6e8a3d", "#4e6a2d", "#7f9446", "#8d9a52"]
        for _ in range(170):
            x = w * .5 + rng.gauss(0, w * .13)
            hp = h * rng.uniform(.25, .7)
            c = srgb(rng.choice(greens)) * rng.uniform(.8, 1.15)
            blade(draw, (x, h), hp, rng.uniform(-.45, .45), rng.uniform(3, 7), tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng)
        # Tall oat grass and cocksfoot panicles above the leaves.
        for _ in range(16):
            x = w * .5 + rng.gauss(0, w * .12)
            top = blade(draw, (x, h), h * rng.uniform(.75, .96), rng.uniform(-.25, .25), 2.2, (128, 136, 86, 255), rng)
            for k in range(14):
                py = top[1] + k * h * .022
                px = top[0] + rng.uniform(-1, 1) * (8 + k * 1.6)
                draw.ellipse((px - 4, py - 7, px + 4, py + 7), fill=(150, 140, 98, 255) if k % 3 else (124, 118, 80, 255))
    elif kind == "pasture":
        for _ in range(230):
            x = w * .5 + rng.gauss(0, w * .17)
            c = srgb(rng.choice(["#5c7834", "#6a8a3a", "#557030", "#78914a"])) * rng.uniform(.8, 1.1)
            blade(draw, (x, h), h * rng.uniform(.12, .38), rng.uniform(-.7, .7), rng.uniform(3, 6), tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng)
        for _ in range(26):  # clover trefoils among the turf
            x, y = w * .5 + rng.gauss(0, w * .15), h * rng.uniform(.75, .95)
            for k in range(3):
                a = k * math.tau / 3 + rng.random()
                draw.ellipse((x + math.cos(a) * 9 - 8, y + math.sin(a) * 6 - 6, x + math.cos(a) * 9 + 8, y + math.sin(a) * 6 + 6), fill=(70, 104, 46, 255))
    elif kind == "dry":
        for _ in range(150):
            x = w * .5 + rng.gauss(0, w * .14)
            c = srgb(rng.choice(["#b39f62", "#a08b52", "#c2ae74", "#8c8a4c", "#6d7a3c"])) * rng.uniform(.85, 1.1)
            blade(draw, (x, h), h * rng.uniform(.3, .8), rng.uniform(-.6, .6), rng.uniform(2.5, 5), tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng)
        for _ in range(20):
            x = w * .5 + rng.gauss(0, w * .12)
            top = blade(draw, (x, h), h * rng.uniform(.7, .95), rng.uniform(-.3, .3), 2, (176, 156, 104, 255), rng)
            for k in range(9):
                draw.line((top[0], top[1] + k * 9, top[0] + rng.uniform(-22, 22), top[1] + k * 9 + 16), fill=(186, 168, 118, 255), width=2)
    elif kind == "sedge":
        for _ in range(120):
            x = w * .5 + rng.gauss(0, w * .08)
            lean = rng.uniform(-.9, .9)
            c = srgb(rng.choice(["#3f5d2a", "#4a6a2f", "#55703a"])) * rng.uniform(.85, 1.12)
            blade(draw, (x, h), h * rng.uniform(.45, .85), lean, rng.uniform(4, 7), tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng, curl=lean * .5)
        for _ in range(9):
            x = w * .5 + rng.gauss(0, w * .07)
            top = blade(draw, (x, h), h * rng.uniform(.8, .95), rng.uniform(-.15, .15), 2.2, (84, 92, 50, 255), rng)
            draw.ellipse((top[0] - 5, top[1], top[0] + 5, top[1] + 34), fill=(70, 58, 40, 255))
    elif kind == "rush":
        for _ in range(140):
            x = w * .5 + rng.gauss(0, w * .07)
            c = srgb(rng.choice(["#3e5a2c", "#4b6b34", "#567640"])) * rng.uniform(.85, 1.1)
            top = blade(draw, (x, h), h * rng.uniform(.55, .97), rng.uniform(-.18, .18), 2.6, tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng)
            if rng.random() < .12:
                for k in range(7):
                    gx, gy = top[0] + rng.uniform(-10, 10), top[1] + h * .1 + rng.uniform(-8, 8)
                    draw.ellipse((gx - 3, gy - 3, gx + 3, gy + 3), fill=(112, 88, 52, 255))
    elif kind in ("reed", "reed_plume"):
        stems = 9 if kind == "reed" else 8
        for _ in range(stems):
            x = w * .5 + rng.gauss(0, w * .1)
            lean = rng.uniform(-.08, .08)
            hp = h * rng.uniform(.8, .97)
            top = blade(draw, (x, h), hp, lean, 3.2, (118, 128, 76, 255), rng)
            for k in range(9):
                t = .18 + k * .085
                sy = h - hp * t
                sx = x + lean * hp * t ** 1.8
                side = 1 if k % 2 else -1
                c = srgb(rng.choice(["#5b7a3a", "#66844a", "#718d4e", "#8a9a5a"])) * rng.uniform(.85, 1.1)
                # Long arching reed leaves that droop at the tip.
                pts_l, pts_r = [], []
                length = w * rng.uniform(.25, .42)
                for i in range(9):
                    u = i / 8
                    px = sx + side * length * u
                    py = sy - length * .35 * u + length * .55 * u * u
                    wid = 7 * math.sin(math.pi * min(.98, u * .9 + .08))
                    pts_l.append((px, py - wid))
                    pts_r.append((px, py + wid))
                draw.polygon(pts_l + pts_r[::-1], fill=tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,))
            if kind == "reed_plume":
                for k in range(160):
                    a = rng.gauss(.1 * lean, .55)
                    d = rng.uniform(0, h * .16)
                    px = top[0] + math.sin(a) * d * .55
                    py = top[1] + d
                    draw.line((px, py, px + rng.uniform(-9, 9), py + rng.uniform(6, 16)),
                              fill=(int(rng.uniform(110, 150)), int(rng.uniform(88, 110)), int(rng.uniform(78, 100)), 255), width=2)


def flower_tile(draw, tile, rng, kind):
    w, h = tile
    leaf_greens = ["#56753a", "#4d6c32", "#64803f"]
    # A few grass blades so the flowers sit in sward rather than on bare soil.
    for _ in range(40):
        x = w * .5 + rng.gauss(0, w * .14)
        c = srgb(rng.choice(["#5d7a35", "#6e8a3d", "#4e6a2d"])) * rng.uniform(.8, 1.1)
        blade(draw, (x, h), h * rng.uniform(.15, .42), rng.uniform(-.5, .5), rng.uniform(2.5, 5), tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,), rng)
    count = {"poppy": 7, "cornflower": 9, "daisy": 10, "sage": 7, "knapweed": 8, "buttercup": 12, "carrot": 6,
             "iris": 4, "loosestrife": 6, "flax": 12}[kind]
    for _ in range(count):
        x = w * .5 + rng.gauss(0, w * .14)
        hp = h * rng.uniform(.45, .85) if kind not in ("iris", "loosestrife") else h * rng.uniform(.65, .92)
        lean = rng.uniform(-.18, .18)
        stem_c = srgb(rng.choice(leaf_greens))
        top = blade(draw, (x, h), hp, lean, 2.0, tuple(int(v * 255) for v in stem_c) + (255,), rng)
        if kind == "iris":
            for k in range(5):
                blade(draw, (x + rng.uniform(-8, 8), h), hp * rng.uniform(.7, 1.05), rng.uniform(-.2, .2), 7, (78, 110, 64, 255), rng)
        else:
            for k in range(3):  # stem leaves
                t = rng.uniform(.15, .6)
                sy = h - hp * t
                sx = x + lean * hp * t ** 1.8
                side = rng.choice((-1, 1))
                draw.polygon([(sx, sy), (sx + side * 26, sy - 18), (sx + side * 34, sy - 10), (sx + side * 10, sy + 3)],
                             fill=tuple(int(v * 255) for v in srgb(rng.choice(leaf_greens))) + (255,))
        cx, cy = top
        if kind == "poppy":
            r = rng.uniform(17, 24)
            for k in range(4):
                a = k * math.pi / 2 + rng.random() * .4
                draw.ellipse((cx + math.cos(a) * r * .55 - r * .7, cy + math.sin(a) * r * .4 - r * .55,
                              cx + math.cos(a) * r * .55 + r * .7, cy + math.sin(a) * r * .4 + r * .55),
                             fill=(int(rng.uniform(190, 220)), int(rng.uniform(28, 48)), 26, 255))
            draw.ellipse((cx - 5, cy - 4, cx + 5, cy + 4), fill=(32, 24, 26, 255))
        elif kind == "cornflower":
            r = rng.uniform(11, 15)
            for k in range(8):
                a = k * math.tau / 8
                draw.polygon([(cx, cy), (cx + math.cos(a - .25) * r, cy + math.sin(a - .25) * r * .7),
                              (cx + math.cos(a + .25) * r, cy + math.sin(a + .25) * r * .7)], fill=(52, 92, 196, 255))
            draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(70, 56, 128, 255))
        elif kind == "daisy":
            r = rng.uniform(14, 19)
            for k in range(16):
                a = k * math.tau / 16
                draw.line((cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r * .55), fill=(244, 242, 232, 255), width=4)
            draw.ellipse((cx - 5, cy - 4, cx + 5, cy + 4), fill=(226, 176, 40, 255))
        elif kind == "sage":
            for k in range(7):
                y = cy + k * 13
                for side in (-1, 1):
                    draw.ellipse((cx + side * 6 - 6, y - 5, cx + side * 6 + 6, y + 5), fill=(98, 72, 168, 255))
        elif kind == "knapweed":
            draw.ellipse((cx - 8, cy - 2, cx + 8, cy + 12), fill=(92, 78, 50, 255))
            for k in range(14):
                a = -math.pi * rng.uniform(.1, .9)
                draw.line((cx, cy + 2, cx + math.cos(a) * 14, cy + math.sin(a) * 12), fill=(176, 72, 156, 255), width=3)
        elif kind == "buttercup":
            r = rng.uniform(8, 11)
            for k in range(5):
                a = k * math.tau / 5
                draw.ellipse((cx + math.cos(a) * r * .6 - r * .5, cy + math.sin(a) * r * .45 - r * .4,
                              cx + math.cos(a) * r * .6 + r * .5, cy + math.sin(a) * r * .45 + r * .4), fill=(244, 206, 32, 255))
        elif kind == "carrot":
            for k in range(70):
                a = rng.uniform(0, math.tau)
                d = 26 * math.sqrt(rng.random())
                draw.ellipse((cx + math.cos(a) * d - 3, cy + math.sin(a) * d * .3 - 3, cx + math.cos(a) * d + 3, cy + math.sin(a) * d * .3 + 3),
                             fill=(238, 236, 224, 255))
        elif kind == "iris":
            draw.polygon([(cx, cy), (cx - 18, cy + 14), (cx - 4, cy + 8)], fill=(236, 200, 36, 255))
            draw.polygon([(cx, cy), (cx + 18, cy + 14), (cx + 4, cy + 8)], fill=(230, 192, 30, 255))
            draw.polygon([(cx - 5, cy), (cx, cy - 18), (cx + 5, cy)], fill=(246, 214, 60, 255))
        elif kind == "loosestrife":
            for k in range(16):
                y = cy + k * 7
                for side in (-1, 1):
                    draw.ellipse((cx + side * 5 - 5, y - 4, cx + side * 5 + 5, y + 4), fill=(186, 58, 142, 255))
        elif kind == "flax":
            r = 9
            for k in range(5):
                a = k * math.tau / 5
                draw.ellipse((cx + math.cos(a) * 6 - r * .55, cy + math.sin(a) * 4 - r * .45, cx + math.cos(a) * 6 + r * .55, cy + math.sin(a) * 4 + r * .45),
                             fill=(118, 146, 214, 255))


def crop_tile(draw, tile, rng, kind):
    w, h = tile
    if kind == "flax":
        flower_tile(draw, tile, rng, kind)
        return
    if kind in ("wheat", "wheat_green", "barley", "emmer"):
        ripe = kind != "wheat_green"
        stem = (178, 158, 92, 255) if ripe else (102, 130, 60, 255)
        for _ in range(72):
            x = w * .5 + rng.gauss(0, w * .16)
            lean = rng.uniform(-.12, .12)
            hp = h * rng.uniform(.68, .9)
            top = blade(draw, (x, h), hp, lean, 2.6, stem, rng)
            for k in range(2):
                t = rng.uniform(.2, .55)
                sy = h - hp * t
                sx = x + lean * hp * t ** 1.8
                side = rng.choice((-1, 1))
                c = (166, 150, 88, 255) if ripe else (96, 128, 58, 255)
                draw.polygon([(sx, sy), (sx + side * 46, sy - 34), (sx + side * 66, sy - 30), (sx + side * 5, sy + 3)], fill=c)
            ear = h * (.13 if kind != "emmer" else .11)
            cx, cy = top
            nod = (.55 if kind == "barley" else .1) * rng.uniform(.6, 1.2)
            for k in range(11):
                t = k / 10
                px = cx + math.sin(nod) * ear * t * (1 if lean >= 0 else -1)
                py = cy + ear * t * math.cos(nod) * (1 if kind == "barley" else -1) + (ear if kind != "barley" else 0)
                grain = (206, 176, 96, 255) if ripe else (128, 158, 76, 255)
                if kind == "emmer" and ripe:
                    grain = (190, 140, 84, 255)
                for side in (-1, 1):
                    draw.ellipse((px + side * 5 - 5, py - 6, px + side * 5 + 5, py + 6), fill=grain)
                    if kind in ("barley", "emmer", "wheat") and ripe or kind == "barley":
                        awn = 36 if kind == "barley" else (22 if kind == "emmer" else 10)
                        draw.line((px + side * 5, py, px + side * (9 + awn * .3), py - awn * (1 if kind != "barley" else -1)),
                                  fill=(220, 196, 130, 255) if ripe else (150, 170, 96, 255), width=1)
    elif kind in ("millet", "foxtail"):
        for _ in range(22):
            x = w * .5 + rng.gauss(0, w * .15)
            lean = rng.uniform(-.15, .15)
            hp = h * rng.uniform(.6, .85)
            top = blade(draw, (x, h), hp, lean, 3.2, (118, 134, 66, 255), rng)
            for k in range(4):
                t = rng.uniform(.15, .65)
                sy = h - hp * t
                sx = x + lean * hp * t ** 1.8
                side = rng.choice((-1, 1))
                draw.polygon([(sx, sy), (sx + side * 70, sy - 20), (sx + side * 95, sy + 6), (sx + side * 8, sy + 6)], fill=(96, 128, 58, 255))
            cx, cy = top
            if kind == "millet":
                for k in range(40):  # loose, drooping panicle
                    a = rng.uniform(-.7, .7)
                    d = rng.uniform(10, 70)
                    px, py = cx + math.sin(a) * d * .6, cy + d * .8
                    draw.line((cx, cy, px, py), fill=(150, 140, 82, 255), width=1)
                    draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill=(196, 170, 98, 255))
            else:
                for k in range(26):  # dense bristly cylinder, nodding
                    py = cy + k * 3
                    px = cx + k * 1.4
                    draw.ellipse((px - 8, py - 5, px + 8, py + 5), fill=(170, 160, 96, 255))
    elif kind == "bean":
        for _ in range(9):
            x = w * .5 + rng.gauss(0, w * .14)
            hp = h * rng.uniform(.5, .8)
            top = blade(draw, (x, h), hp, rng.uniform(-.08, .08), 5, (82, 112, 60, 255), rng)
            for k in range(7):
                sy = h - hp * (.2 + k * .11)
                for side in (-1, 1):
                    draw.ellipse((x + side * 22 - 16, sy - 10, x + side * 22 + 16, sy + 10), fill=(90, 124, 82, 255))
                if k in (2, 3):
                    draw.ellipse((x - 6, sy - 4, x + 6, sy + 6), fill=(238, 236, 226, 255))
                    draw.ellipse((x - 2, sy, x + 2, sy + 3), fill=(40, 30, 34, 255))
                if k == 1:
                    draw.polygon([(x + 4, sy), (x + 12, sy + 52), (x + 18, sy + 50), (x + 8, sy)], fill=(96, 136, 70, 255))
    elif kind == "kale":
        for k in range(16):
            a = -math.pi / 2 + rng.uniform(-1.3, 1.3)
            length = h * rng.uniform(.3, .6)
            base = (w * .5 + rng.uniform(-10, 10), h * .98)
            tip = (base[0] + math.cos(a) * length, base[1] + math.sin(a) * length)
            c = srgb(rng.choice(["#4a6a5a", "#557566", "#5f7f62", "#3e5c52"])) * rng.uniform(.9, 1.1)
            pts = []
            for i in range(16):
                u = i / 15
                pts.append((base[0] + (tip[0] - base[0]) * u + math.cos(a + 1.57) * 34 * math.sin(math.pi * u) * (1 + .15 * math.sin(u * 30)),
                            base[1] + (tip[1] - base[1]) * u + math.sin(a + 1.57) * 34 * math.sin(math.pi * u) * (1 + .15 * math.sin(u * 30))))
            for i in range(15, -1, -1):
                u = i / 15
                pts.append((base[0] + (tip[0] - base[0]) * u - math.cos(a + 1.57) * 34 * math.sin(math.pi * u) * (1 + .15 * math.sin(u * 27)),
                            base[1] + (tip[1] - base[1]) * u - math.sin(a + 1.57) * 34 * math.sin(math.pi * u) * (1 + .15 * math.sin(u * 27))))
            draw.polygon(pts, fill=tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,))
            draw.line((base, tip), fill=(168, 186, 160, 255), width=3)
    elif kind == "leek":
        for k in range(10):
            x = w * .5 + rng.gauss(0, w * .12)
            draw.rectangle((x - 9, h * .8, x + 9, h), fill=(222, 226, 200, 255))
            for j in range(4):
                blade(draw, (x + rng.uniform(-4, 4), h * .82), h * rng.uniform(.3, .55), rng.uniform(-.7, .7), 8, (74, 108, 86, 255), rng)
    elif kind == "lentil":
        for _ in range(60):
            x = w * .5 + rng.gauss(0, w * .16)
            top = blade(draw, (x, h), h * rng.uniform(.2, .45), rng.uniform(-.6, .6), 1.6, (96, 124, 62, 255), rng)
            for k in range(6):
                gx = top[0] + rng.uniform(-14, 14)
                draw.ellipse((gx - 4, top[1] + k * 8 - 3, gx + 4, top[1] + k * 8 + 3), fill=(110, 138, 72, 255))
    elif kind == "stubble":
        for _ in range(140):
            x = w * .5 + rng.gauss(0, w * .2)
            blade(draw, (x, h), h * rng.uniform(.06, .16), rng.uniform(-.3, .3), 2.4, (194, 174, 116, 255), rng)
        for _ in range(60):
            x = w * .5 + rng.gauss(0, w * .2)
            blade(draw, (x, h), h * rng.uniform(.05, .25), rng.uniform(-.9, .9), 3, (102, 124, 58, 255), rng)


def card_atlas(name, tiles, painter, size=2048):
    big = size * 2
    tile = big // 4
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    for i, kind in enumerate(tiles):
        if not kind:
            continue
        rng = random.Random(1000 + i * 17 + len(name))
        img = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
        painter(ImageDraw.Draw(img), (tile, tile), rng, kind)
        arr = np.asarray(img).astype(float)
        yy = np.linspace(0, 1, tile)[:, None]
        arr[..., :3] *= (.72 + .28 * (1 - yy) ** .6)[..., None]  # denser shade at the clump base
        canvas.paste(Image.fromarray(np.uint8(np.clip(arr, 0, 255)), "RGBA"), ((i % 4) * tile, (i // 4) * tile))
    height = Image.new("L", (big, big), 128)
    finish_atlas(canvas, height, name, size)
    (OUT / f"{name}_normal.png").unlink(missing_ok=True)  # cards use bent normals instead


def herb_painter(draw, tile, rng, kind):
    if kind in ("meadow", "pasture", "dry", "sedge", "rush", "reed", "reed_plume"):
        grass_tile(draw, tile, rng, kind)
    else:
        flower_tile(draw, tile, rng, kind)


def main(selection):
    OUT.mkdir(parents=True, exist_ok=True)
    if "bark" in selection:
        for name, params in BARK.items():
            bark_texture(name, params)
            print("bark", name, flush=True)
    if "leaf" in selection:
        for species in LEAVES:
            leaf_atlas(species)
            print("leaf", species, flush=True)
    if "herbs" in selection:
        card_atlas("herbs", HERB_TILES, herb_painter)
        print("herbs", flush=True)
    if "crops" in selection:
        card_atlas("crops", CROP_TILES, crop_tile)
        print("crops", flush=True)


if __name__ == "__main__":
    main(set(sys.argv[1:]) or {"bark", "leaf", "herbs", "crops"})
