"""Texture helpers for the civilian youth outfit: UV rasterisation and wool.

All patterns are deterministic (fixed seeds); a rebuild is byte-reproducible
for the same numpy/Pillow versions.
"""
from __future__ import annotations

import io

import numpy as np
from PIL import Image

from youth_civil_mesh import ATLAS


# ------------------------------------------------------------------ helpers
def value_noise3(points, scale, seed):
    """Smooth 3D value noise in [-1, 1] at world points (metres)."""
    rng = np.random.default_rng(seed)
    table = rng.uniform(-1, 1, 4096)
    p = np.asarray(points, float) / scale
    i = np.floor(p).astype(np.int64)
    f = p - i
    f = f * f * (3 - 2 * f)

    def h(ix, iy, iz):
        return table[(ix * 73856093 ^ iy * 19349663 ^ iz * 83492791) % 4096]

    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out


def value_noise2(shape, cells, seed):
    """Tileable-enough 2D value noise image in [-1, 1]."""
    rng = np.random.default_rng(seed)
    grid = rng.uniform(-1, 1, (cells[0] + 1, cells[1] + 1))
    grid[:, -1] = grid[:, 0]
    ys = np.linspace(0, cells[0], shape[0], endpoint=False)
    xs = np.linspace(0, cells[1], shape[1], endpoint=False)
    iy = np.floor(ys).astype(int)
    ix = np.floor(xs).astype(int)
    fy = ys - iy
    fx = xs - ix
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[iy][:, ix]
    b = grid[iy][:, ix + 1]
    c = grid[iy + 1][:, ix]
    d = grid[iy + 1][:, ix + 1]
    top = a * (1 - fx) + b * fx
    bottom = c * (1 - fx) + d * fx
    return top * (1 - fy)[:, None] + bottom * fy[:, None]


def rasterize_uv(uv, faces, size):
    """Owner face and barycentric coordinates per texel (texel centres).

    glTF UV (0,0) is the top-left of the image; uv wraps (modulo 1)."""
    owner = np.full((size, size), -1, np.int64)
    bary = np.zeros((size, size, 3), np.float32)
    tri = (uv[faces] % 1.0) * size
    for k in range(len(faces)):
        p = tri[k]
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, size - 1); y1 = min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-12:
            continue
        w0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        w1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        w2 = 1 - w0 - w1
        m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not m.any():
            continue
        yy = ys[m].astype(int)
        xx = xs[m].astype(int)
        owner[yy, xx] = k
        bary[yy, xx] = np.stack([w0[m], w1[m], w2[m]], -1)
    return owner, bary


def dilate_into(image, painted, free, steps=3):
    """Extend painted texels into free (unowned) gutter texels."""
    img = image.copy()
    done = painted.copy()
    for _ in range(steps):
        grow = np.zeros_like(done)
        acc = np.zeros(img.shape, float)
        cnt = np.zeros(done.shape, float)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            shifted = np.roll(np.roll(done, dy, 0), dx, 1)
            src = np.roll(np.roll(img, dy, 0), dx, 1).astype(float)
            m = shifted & ~done & free
            acc[m] += src[m]
            cnt[m] += 1
            grow |= m
        img[grow] = (acc[grow] / cnt[grow][:, None]).round().astype(img.dtype)
        done |= grow
    return img


def jpeg_bytes(array, quality=92):
    buf = io.BytesIO()
    Image.fromarray(array.astype(np.uint8), "RGB").save(buf, "JPEG", quality=quality, subsampling=0, optimize=True)
    return buf.getvalue()


def jpeg_keep(original_bytes, array):
    """Re-encode with the source JPEG's own quantisation and subsampling."""
    src = Image.open(io.BytesIO(original_bytes))
    out = Image.fromarray(array.astype(np.uint8), "RGB")
    buf = io.BytesIO()
    out.save(buf, "JPEG", qtables=src.quantization, subsampling=_sampling(src))
    return buf.getvalue()


def _sampling(image):
    from PIL import JpegImagePlugin
    value = JpegImagePlugin.get_sampling(image)
    return value if value >= 0 else 0


# ----------------------------------------------------------------- palettes
# Undyed natural sheep's wool (oatmeal/cream) in sRGB; the leather belt is
# vegetable-tanned. Values are reviewed design choices, not measurements.
WOOL_SRGB = np.array([176.0, 160.0, 133.0])
LEATHER_SRGB = np.array([96.0, 64.0, 42.0])


def _region_pixels(size, region):
    u0, v0, u1, v1 = ATLAS[region]
    x0, x1 = int(round(u0 * size)), int(round(u1 * size))
    y0, y1 = int(round(v0 * size)), int(round(v1 * size))
    return x0, x1, y0, y1


def garment_textures(size, fold_fn):
    """Base colour, tangent-space normal and metallic-roughness for the tunic.

    fold_fn(theta, y) gives the analytic drape so fold valleys darken."""
    base = np.zeros((size, size, 3), float)
    height = np.zeros((size, size), float)
    rough = np.full((size, size), 0.92)
    metal = np.zeros((size, size))
    yy, xx = np.mgrid[0:size, 0:size]
    # Woollen 2/2 twill: diagonal ribs, ~3 texels at 1024 (about 2.5 mm).
    period = max(2.0, 3.0 * size / 1024)
    twill = np.sin(2 * np.pi * (xx + yy) / period)
    thread = value_noise2((size, size), (size // 6, size // 6), 11)
    slub = value_noise2((size, size), (max(4, size // 48), max(4, size // 12)), 12)
    heather = value_noise2((size, size), (max(4, size // 64), max(4, size // 64)), 13)
    wool_height = 0.45 * twill + 0.35 * thread + 0.20 * slub
    tone = 1.0 + 0.045 * heather + 0.025 * slub + 0.018 * thread

    for region in ("skirt", "torso", "sleeve_L", "sleeve_R"):
        x0, x1, y0, y1 = _region_pixels(size, region)
        u = (xx[y0:y1, x0:x1] - x0 + .5) / (x1 - x0)
        v = (yy[y0:y1, x0:x1] - y0 + .5) / (y1 - y0)
        shade = np.ones_like(u)
        if region in ("skirt", "torso"):
            theta = np.pi + 2 * np.pi * u
            if region == "skirt":
                y = 0.522 + (0.862 - 0.522) * (1 - v)
                # Hem wear and road dust in the lowest centimetres.
                shade *= 1 - 0.10 * np.clip((0.60 - y) / 0.08, 0, 1)
                hem_line = np.exp(-0.5 * ((y - 0.537) / 0.0012) ** 2)
                shade *= 1 - 0.18 * hem_line * (0.6 + 0.4 * (np.sin(theta * 160) > 0))
            else:
                y = 0.862 + (1.27 - 0.862) * (1 - v)
                neck = np.exp(-0.5 * ((v - 0.012) / 0.006) ** 2)
                shade *= 1 - 0.12 * neck
            fold = fold_fn(theta, y)
            shade *= 1 + 9.0 * np.clip(fold, -0.02, 0.02)        # valleys darker
            side_seam = np.exp(-0.5 * (np.minimum(np.abs(theta % (2 * np.pi) - np.pi / 2),
                                                  np.abs(theta % (2 * np.pi) - 3 * np.pi / 2)) / 0.004) ** 2)
            shade *= 1 - 0.14 * side_seam
            height[y0:y1, x0:x1] -= 0.6 * side_seam
        else:
            hem = np.exp(-0.5 * ((v - 0.86) / 0.012) ** 2)
            shade *= 1 - 0.12 * hem
            shade *= 1 - 0.06 * np.sin(2 * np.pi * u * 7 + 1.0) * v
        base[y0:y1, x0:x1] = WOOL_SRGB * (tone[y0:y1, x0:x1] * shade)[..., None]
        height[y0:y1, x0:x1] += wool_height[y0:y1, x0:x1]
        rough[y0:y1, x0:x1] = 0.90 + 0.05 * thread[y0:y1, x0:x1]

    # Leather belt with stitched edges and a small bronze ring buckle.
    x0, x1, y0, y1 = _region_pixels(size, "belt")
    u = (xx[y0:y1, x0:x1] - x0 + .5) / (x1 - x0)
    v = (yy[y0:y1, x0:x1] - y0 + .5) / (y1 - y0)
    grain = value_noise2((size, size), (size // 8, size // 2), 21)[y0:y1, x0:x1]
    scuff = value_noise2((size, size), (max(4, size // 64), max(4, size // 16)), 22)[y0:y1, x0:x1]
    edge = np.exp(-0.5 * ((np.minimum(v, 1 - v)) / 0.05) ** 2)
    stitch = (np.exp(-0.5 * ((np.minimum(np.abs(v - 0.22), np.abs(v - 0.78))) / 0.025) ** 2)
              * (np.sin(2 * np.pi * u * 260) > 0.2))
    leather = LEATHER_SRGB * (1 + 0.10 * grain + 0.12 * scuff - 0.35 * edge - 0.25 * stitch)[..., None]
    theta = np.pi + 2 * np.pi * u
    # Buckle at the front, slightly to the wearer's right.
    du = ((theta - 0.20 + np.pi) % (2 * np.pi) - np.pi) * 0.39       # metres along the belt
    dv = (v - 0.5) * 0.027
    ring = np.abs(np.hypot(du / 1.2, dv) - 0.0085) < 0.0019
    bronze = np.array([150.0, 112.0, 62.0])
    leather[ring] = bronze * (1 + 0.15 * scuff[ring])[..., None]
    base[y0:y1, x0:x1] = leather
    height[y0:y1, x0:x1] = 0.3 * grain - 0.6 * stitch + 1.2 * ring
    rough[y0:y1, x0:x1] = np.where(ring, 0.45, 0.62 + 0.08 * grain)
    metal[y0:y1, x0:x1] = np.where(ring, 1.0, 0.0)

    # Unused atlas texels: neutral wool (mip-map bleeding stays on-colour).
    used = np.zeros((size, size), bool)
    for region in ATLAS:
        x0, x1, y0, y1 = _region_pixels(size, region)
        used[y0:y1, x0:x1] = True
    base[~used] = WOOL_SRGB

    gy, gx = np.gradient(height)
    strength = 0.9
    n = np.stack([-gx * strength, gy * strength, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    normal = ((n * 0.5 + 0.5) * 255).round()
    mr = np.stack([np.full_like(rough, 255), rough * 255, metal * 255], -1).round()
    return np.clip(base, 0, 255).round().astype(np.uint8), normal.astype(np.uint8), mr.astype(np.uint8)
