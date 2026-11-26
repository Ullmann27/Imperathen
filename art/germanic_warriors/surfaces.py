"""Procedural, tileable PBR surfaces for the Germanic warrior families.

Pure NumPy, seeded and periodic, so Blender bakes identical bytes on every
rebuild and the same module can preview a surface outside Blender. Every
function returns linear-light arrays in [0, 1]:

    albedo (H, W, 3, sRGB-encoded values), normal (H, W, 3, OpenGL tangent
    space as glTF expects), roughness (H, W), metallic (H, W)

No photograph, scan or third-party texture is used. Pattern choices (twill,
herringbone, checks, painted shield motifs) are design reconstructions; the
registry records how far each one is attested.
"""
from __future__ import annotations

import math

import numpy as np


class Field:
    """Periodic coordinate field of one square tile."""

    def __init__(self, size: int, seed: int):
        if size not in (64, 128, 256, 512, 1024, 2048):
            raise ValueError("Surface size must be a power of two between 64 and 2048")
        self.size = size
        self.rng = np.random.default_rng(seed)
        axis = np.arange(size, dtype=np.float64) / size
        self.u, self.v = np.meshgrid(axis, axis)

    def noise(self, gx: int, gy: int | None = None, u=None, v=None) -> np.ndarray:
        """Smooth periodic value noise with gx * gy lattice cells per tile."""
        gy = gx if gy is None else gy
        u = self.u if u is None else u
        v = self.v if v is None else v
        grid = self.rng.random((gy, gx))
        x, y = (u % 1.0) * gx, (v % 1.0) * gy
        ix, iy = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
        a, b = x - ix, y - iy
        a, b = a * a * (3 - 2 * a), b * b * (3 - 2 * b)
        ix, iy = ix % gx, iy % gy
        jx, jy = (ix + 1) % gx, (iy + 1) % gy
        return ((1 - b) * ((1 - a) * grid[iy, ix] + a * grid[iy, jx])
                + b * ((1 - a) * grid[jy, ix] + a * grid[jy, jx]))

    def fbm(self, base: int, octaves: int = 4, gain: float = .5) -> np.ndarray:
        total, amplitude, norm = np.zeros_like(self.u), 1.0, 0.0
        for octave in range(octaves):
            total += amplitude * (self.noise(base * 2 ** octave) - .5)
            norm += amplitude
            amplitude *= gain
        return total / norm


def smooth(lo: float, hi: float, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    """Periodic central differences; +Y points along +V (OpenGL convention as glTF)."""
    size = height.shape[0]
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * .5 * size
    # Rows run along +V (Blender stores pixel rows bottom first).
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * .5 * size
    n = np.stack((-dx * strength, -dy * strength, np.ones_like(height)), axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * .5 + .5


def _pack(albedo, height, strength, roughness, metallic=None):
    albedo = np.clip(albedo, .004, .996)
    roughness = np.clip(roughness, .04, 1.0)
    metallic = np.zeros_like(roughness) if metallic is None else np.clip(metallic, 0, 1)
    return {"albedo": albedo, "normal": normal_from_height(height, strength),
            "roughness": roughness, "metallic": metallic}


def _rgb(colour) -> np.ndarray:
    if isinstance(colour, str):
        return np.array([int(colour[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    return np.asarray(colour, dtype=np.float64)


def wool(size: int, seed: int, colour, threads: int = 96, pattern: str = "twill",
         check=None, stripe=None, fulled: float = .35) -> dict:
    """Hand-spun wool cloth: 2/2 twill, herringbone or tabby, optional checks.

    ``threads`` is the number of warp threads per tile. ``check`` is
    (second colour, band threads, period threads) for a woven check; ``stripe``
    adds a woven border band (colour, start fraction, width fraction) along V.
    ``fulled`` softens the weave as fulled (felted) wool does.
    """
    f = Field(size, seed)
    x, y = f.u * threads, f.v * threads
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    if pattern == "tabby":
        over = ((ix + iy) % 2) < 1
    elif pattern == "herringbone":
        block = 8
        flip = (np.floor(ix / block) % 2) < 1
        diagonal = np.where(flip, ix + iy, ix - iy + 4 * threads)
        over = (diagonal % 4) < 2
    else:
        over = ((ix + iy) % 4) < 2
    # Each thread has its own spin irregularity (slubs) and slight colour drift.
    warp_slub = f.rng.random(threads)[ix.astype(np.int64) % threads]
    weft_slub = f.rng.random(threads)[iy.astype(np.int64) % threads]
    along_warp = .5 + .5 * np.sin(fy * math.pi)
    along_weft = .5 + .5 * np.sin(fx * math.pi)
    warp_round = np.sin(np.clip(fx, 0, 1) * math.pi) ** .6
    weft_round = np.sin(np.clip(fy, 0, 1) * math.pi) ** .6
    yarn = np.where(over, warp_round * (.85 + .15 * along_warp), weft_round * (.85 + .15 * along_weft))
    fuzz = f.fbm(64, 3)
    mottle = f.fbm(6, 4)
    height = (1 - fulled) * yarn * .8 + fulled * (.5 + fuzz) + .25 * mottle
    base = _rgb(colour)
    colour_map = np.ones((size, size, 3)) * base
    if check is not None:
        second, band, period = check
        warp_band = (ix % period) < band
        weft_band = (iy % period) < band
        thread_is_second = np.where(over, warp_band, weft_band)
        mix = thread_is_second.astype(np.float64)
        colour_map = colour_map * (1 - mix[..., None]) + _rgb(second) * mix[..., None]
    if stripe is not None:
        stripe_colour, start, width = stripe
        band = smooth(start - .004, start, f.v) * (1 - smooth(start + width, start + width + .004, f.v))
        colour_map = colour_map * (1 - band[..., None]) + _rgb(stripe_colour) * band[..., None]
    thread_tone = np.where(over, warp_slub, weft_slub)
    shade = (.80 + .26 * yarn) * (1 + .10 * (thread_tone - .5) + .22 * mottle + .08 * fuzz)
    albedo = colour_map * shade[..., None]
    roughness = .86 + .08 * fuzz - .04 * yarn
    return _pack(albedo, height, 1.6 / threads, roughness)


def linen(size: int, seed: int, colour, threads: int = 180) -> dict:
    return wool(size, seed, colour, threads, "tabby", fulled=.12)


def leather(size: int, seed: int, colour, worn: float = .5) -> dict:
    """Vegetable-tanned leather: pores, creases and lighter rubbed areas."""
    f = Field(size, seed)
    pores = f.noise(181)
    creases = np.abs(f.fbm(9, 4)) * 2
    crease_lines = 1 - smooth(0, .06, np.abs(f.noise(23, 11) - .5))
    mottle = f.fbm(5, 4)
    rub = smooth(.55, .85, f.noise(7) + .3 * mottle) * worn
    height = .5 * pores * .35 - .45 * crease_lines * .5 + .2 * mottle - .3 * creases * .2
    base = _rgb(colour)
    albedo = base * (1 + .28 * mottle[..., None] - .25 * crease_lines[..., None] - .08 * pores[..., None])
    albedo = albedo * (1 - rub[..., None]) + (base * 1.35 + .03) * rub[..., None]
    roughness = .62 + .14 * pores - .18 * rub + .08 * crease_lines
    return _pack(albedo, height, .018, roughness)


def fur(size: int, seed: int, colour, tip=None, length: float = 1.0) -> dict:
    """Directional pelt: strands run along -V (down the hanging cape)."""
    f = Field(size, seed)
    tip = _rgb(tip) if tip is not None else _rgb(colour) * 1.45
    strands = 160
    sx = f.u * strands
    column = np.floor(sx).astype(np.int64) % strands
    phase = f.rng.random(strands)[column]
    offset = f.rng.random(strands)[column] * .4
    within = sx - np.floor(sx)
    clump = f.noise(14, 3)
    warp = .08 * (f.noise(9, 3) - .5)
    t = ((f.v * (3 + 3 * length)) + phase + warp) % 1.0
    strand = np.sin(within * math.pi) ** 1.5 * (1 - .65 * t)
    height = .55 * strand + .35 * clump + .1 * f.noise(64)
    base = _rgb(colour)
    lift = smooth(.35, .95, t + offset)[..., None]
    albedo = base * (.55 + .55 * strand[..., None]) * (1 - lift) + tip * lift * (.7 + .3 * strand[..., None])
    albedo *= (.85 + .3 * clump[..., None])
    roughness = .78 + .14 * (1 - strand)
    return _pack(albedo, height, .022, roughness)


def hair(size: int, seed: int, colour, grey: float = 0.0) -> dict:
    """Combed hair strands along V for scalp caps, knots, braids and beards."""
    f = Field(size, seed)
    strands = 96
    jitter = .02 * (f.noise(7, 2) - .5)
    sx = (f.u + jitter) * strands
    column = np.floor(sx).astype(np.int64) % strands
    tone = f.rng.random(strands)[column]
    within = sx - np.floor(sx)
    clump = f.noise(18, 2)
    sheen = .5 + .5 * np.sin(f.v * math.tau * 3 + clump * 4)
    strand = np.sin(within * math.pi) ** 2
    height = .6 * strand + .4 * clump
    base = _rgb(colour)
    grey_tone = np.array([.62, .60, .57])
    albedo = base * (.70 + .32 * strand[..., None]) * (.90 + .20 * tone[..., None]) * (.92 + .16 * sheen[..., None])
    # Grey hairs blend in softly instead of reading as a knitted pattern.
    greying = (f.rng.random(strands)[column] < grey).astype(np.float64)[..., None] * .6 + grey * .25
    albedo = albedo * (1 - greying) + grey_tone * (.80 + .2 * strand[..., None]) * greying
    roughness = .52 + .22 * (1 - strand) - .06 * sheen
    return _pack(albedo, height, .014, roughness)


def wood(size: int, seed: int, colour, planks: int = 0) -> dict:
    """Split ash/oak or lime board with long grain along V."""
    f = Field(size, seed)
    warp = f.noise(3, 5)
    fibres = f.noise(5, 180)
    rings = np.sin(math.tau * (f.u * 21 + .9 * (warp - .5) + .25 * f.fbm(4, 3)))
    dark = np.clip(-rings, 0, 1) ** 4
    height = .25 * rings + .35 * (fibres - .5) - .2 * dark
    gap = np.zeros_like(f.u)
    tone = np.zeros_like(f.u)
    if planks:
        p = f.u * planks
        within = p - np.floor(p)
        gap = 1 - smooth(0, .025, np.minimum(within, 1 - within))
        tone = (f.rng.random(planks)[np.floor(p).astype(np.int64) % planks] - .5) * .18
        height -= .9 * gap
    base = _rgb(colour)
    albedo = base * (1 + .14 * (fibres[..., None] - .5) + .08 * rings[..., None] - .22 * dark[..., None]
                     + tone[..., None] - .45 * gap[..., None])
    roughness = .66 + .1 * dark + .2 * gap
    return _pack(albedo, height, .010, roughness)


def iron(size: int, seed: int, rust: float = .35, polish: float = .0) -> dict:
    """Bloomery iron: hammer facets, pitting and rust in sheltered spots."""
    f = Field(size, seed)
    facets = f.noise(23)
    pits = smooth(.70, .92, f.noise(97))
    patches = smooth(.55, .8, f.noise(6) + .25 * f.fbm(17, 3))
    rust_mask = np.clip(patches * rust * 1.6 + pits * rust * .6, 0, 1)
    height = .4 * facets - .5 * pits + .3 * rust_mask * f.noise(120)
    metal = np.array([.36, .37, .38]) * (1 + .5 * polish)
    rust_colour = np.array([.36, .17, .08])
    albedo = metal * (.8 + .4 * facets[..., None]) * (1 - rust_mask[..., None]) + rust_colour * (.7 + .5 * f.noise(60)[..., None]) * rust_mask[..., None]
    roughness = .48 - .22 * polish + .35 * rust_mask + .08 * pits
    metallic = .92 * (1 - rust_mask)
    return _pack(albedo, height, .006, roughness, metallic)


def bronze(size: int, seed: int, patina: float = .25) -> dict:
    f = Field(size, seed)
    tool = f.noise(41)
    cavity = smooth(.62, .9, f.noise(9) + .3 * f.fbm(30, 3))
    green = np.clip(cavity * patina * 1.8, 0, 1)
    height = .35 * tool - .4 * cavity
    metal = np.array([.71, .50, .28])
    albedo = metal * (.85 + .3 * tool[..., None]) * (1 - green[..., None]) + np.array([.24, .42, .33]) * green[..., None]
    roughness = .34 + .4 * green + .06 * tool
    return _pack(albedo, height, .005, roughness, .95 * (1 - green))


def blend(a: dict, b: dict, mask: np.ndarray) -> dict:
    m = mask[..., None]
    return {"albedo": a["albedo"] * (1 - m) + b["albedo"] * m,
            "normal": a["normal"] * (1 - m) + b["normal"] * m,
            "roughness": a["roughness"] * (1 - mask) + b["roughness"] * mask,
            "metallic": a["metallic"] * (1 - mask) + b["metallic"] * mask}


def shield_face(size: int, seed: int, board: str, paint, motif: str, accent,
                wear: float = .4, planks: int = 5, aspect: float = 1.0, outline: str = "oval") -> dict:
    """Painted plank board in shield space: U across, V up, centre at (.5, .5).

    The UV square spans the board's bounding box. ``aspect`` is height/width,
    so painted motifs stay round on an oval or rectangular board. Paint wears
    off in small chips, mostly towards the rim, exposing the boards below.
    """
    f = Field(size, seed)
    timber = wood(size, seed + 1, board, planks)
    if paint is None:
        return timber
    x = (f.u - .5) * 2
    y = (f.v - .5) * 2 * aspect
    r = np.hypot(x, y)
    theta = np.arctan2(y, x)
    design = np.zeros_like(x)
    if motif == "crescents":
        for sign in (-1, 1):
            c1 = np.hypot(x, y - .30 * sign) < .40
            c2 = np.hypot(x, y - .46 * sign) < .38
            design = np.maximum(design, (c1 & ~c2).astype(np.float64))
    elif motif == "wheel":
        ring = smooth(.58, .60, r) * (1 - smooth(.70, .72, r))
        spokes = (np.abs(np.sin(theta * 3)) < .09) & (r > .20) & (r < .64)
        design = np.maximum(ring, spokes.astype(np.float64))
    elif motif == "bands":
        design = np.clip((np.abs(x) < .09).astype(np.float64) + ((np.abs(y) < .08) & (np.abs(x) > .24)), 0, 1)
    elif motif == "rings":
        design = (smooth(.34, .36, r) * (1 - smooth(.42, .44, r))) + (smooth(.74, .76, r) * (1 - smooth(.82, .84, r)))
    elif motif == "triskele":
        arm = np.sin(theta * 3 + r * 5.5)
        design = ((arm > .55) & (r > .22) & (r < .80)).astype(np.float64)
    elif motif == "dots":
        for k in range(8):
            a = k * math.tau / 8
            design = np.maximum(design, (np.hypot(x - .60 * math.cos(a), y - .60 * math.sin(a)) < .075).astype(np.float64))
    elif motif == "halves":
        design = (x > 0).astype(np.float64)
    elif motif != "plain":
        raise ValueError("Unknown shield motif " + motif)
    design = np.clip(design, 0, 1)
    if outline == "rect":
        rim = np.maximum(np.abs(x), np.abs(y) / aspect)
    else:
        rim = np.hypot(x, y / aspect)
    near_rim = smooth(.70, .97, rim)
    chips = smooth(.74, .84, .65 * f.noise(56) + .35 * f.noise(170)) * (.25 + .75 * near_rim)
    scratches = (1 - smooth(0, .012, np.abs(f.noise(3, 40) - .5))) * smooth(.6, .8, f.noise(5)) * .6
    exposed = np.clip((chips + scratches * .5) * wear * 1.6, 0, 1)
    tint = 1 + .08 * f.fbm(8, 3) + .05 * (f.noise(120) - .5)
    paint_colour = _rgb(paint) * tint[..., None]
    accent_colour = _rgb(accent) * tint[..., None]
    paint_colour = paint_colour * (1 - design[..., None]) + accent_colour * design[..., None]
    grain = timber["albedo"].mean(axis=2) / max(float(timber["albedo"].mean()), 1e-3)
    paint_layer = {"albedo": paint_colour * (.94 + .06 * grain[..., None]),
                   "normal": timber["normal"] * .35 + np.array([.5, .5, 1.0]) * .65,
                   "roughness": .70 + .06 * f.noise(30), "metallic": np.zeros_like(x)}
    return blend(paint_layer, timber, exposed)


def skin_variant(albedo: np.ndarray, seed: int, tone=(1.0, 1.0, 1.0), weather: float = 0.0,
                 freckles: float = 0.0, scar=None, uv_face=None) -> np.ndarray:
    """Adjust the vendored CC0 skin albedo; scars are painted in UV space.

    ``scar`` is a list of (u0, v0, u1, v1, width) segments in the skin atlas.
    """
    size_y, size_x = albedo.shape[:2]
    rng = np.random.default_rng(seed)
    result = albedo[..., :3] * np.asarray(tone)[None, None, :]
    if weather:
        yy, xx = np.mgrid[0:size_y, 0:size_x] / max(size_x, size_y)
        g = np.sin(xx * 61 + rng.random() * 6) * np.sin(yy * 53 + rng.random() * 6)
        result = result * (1 - .06 * weather) + np.array([.08, .03, .0]) * weather * (.5 + .5 * g[..., None])
    if freckles:
        count = int(2600 * freckles)
        ys, xs = rng.integers(0, size_y, count), rng.integers(0, size_x, count)
        mask = np.zeros((size_y, size_x))
        mask[ys, xs] = rng.random(count) * .8 + .2
        mask = (mask + np.roll(mask, 1, 0) + np.roll(mask, 1, 1)) / 2.2
        result = result * (1 - .22 * np.clip(mask, 0, 1)[..., None])
    if scar:
        yy, xx = np.mgrid[0:size_y, 0:size_x]
        u, v = xx / size_x, 1 - yy / size_y
        for u0, v0, u1, v1, width in scar:
            d = np.array([u1 - u0, v1 - v0])
            length = np.hypot(*d)
            t = np.clip(((u - u0) * d[0] + (v - v0) * d[1]) / max(length ** 2, 1e-9), 0, 1)
            dist = np.hypot(u - (u0 + t * d[0]), v - (v0 + t * d[1]))
            core = 1 - smooth(0, width, dist)
            halo = (1 - smooth(width, width * 3, dist)) * .5
            result = result * (1 - .25 * halo[..., None]) + np.array([.80, .55, .50]) * .25 * halo[..., None]
            result = result * (1 - core[..., None]) + np.array([.86, .66, .60]) * core[..., None]
    return np.clip(result, 0, 1)


def preview(surface: dict, path: str) -> None:
    """Write a 2x2 contact sheet of the four maps (outside Blender only)."""
    from PIL import Image
    size = surface["albedo"].shape[0]
    sheet = np.zeros((size * 2, size * 2, 3))
    sheet[:size, :size] = surface["albedo"]
    sheet[:size, size:] = surface["normal"]
    sheet[size:, :size] = surface["roughness"][..., None]
    sheet[size:, size:] = surface["metallic"][..., None]
    Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8)).save(path)
