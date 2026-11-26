#!/usr/bin/env python3
"""Seeded PBR layers for the Valdora house family (58 BC, Aquileia countryside).

Writes three layered textures (Godot "2d_array_texture" sources, slices in a
4 x 4 grid) per resolution set:

    family_albedo_<n>.jpg   sRGB albedo
    family_normal_<n>.jpg   tangent-space normal, OpenGL convention (green = up)
    family_orm_<n>.jpg      R ambient occlusion, G roughness, B height

n = 1024 (Sehr hoch/Ultra; 4096 x 4096 images), n = 512 (Ausgewogen, Hoch) and
n = 256 (Leicht).
Every layer is periodic in both directions, so the house shader can repeat it
over a wall in metric coordinates without atlas seams. Layer order is the
contract with family_kit.py and valdora_house.gdshader (LAYERS below).

All patterns are generated here from fixed seeds with NumPy and Pillow; no
photographs, scans or downloaded textures are used.

    python3 art/architecture/valdora_family/family_textures.py --out prototype/assets/architecture/valdora
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

# name: physical size of one repeat in metres (used by the kit for UV density)
LAYERS = {
    "plaster_lime": 2.0,     # fresh lime render (intonaco), trowelled, sand grain
    "plaster_aged": 2.0,     # older render: stains, salts, hairline cracks
    "opus_incertum": 1.6,    # irregular stones in recessed lime mortar
    "rubble_socle": 1.6,     # large field and river stones, deep joints
    "ashlar": 1.5,           # dressed limestone, tooled faces, fine joints
    "daub": 1.6,             # clay daub with straw over wattle, limewash remnants
    "oak_grey": 1.0,         # weathered silver oak boards and posts
    "oak_brown": 1.0,        # oiled darker oak for doors, frames and shutters
    "tegula": 1.0,           # one fired roof tile per repeat (mapped 0..1 per tile)
    "tegula_old": 1.0,       # older tile: darker, kiln spots, worn sand face
    "mortar": 1.0,           # lime mortar bedding (ridge, verge, joints)
    "iron": 0.5,             # wrought iron fittings, hammered, light rust
    "paint_red": 2.0,        # red ochre wash on plaster (dado, bands)
    "paint_ochre": 2.0,      # yellow ochre wash
    "flagstone": 1.2,        # worn limestone threshold and floor slabs
    "cocciopesto": 1.6,      # opus signinum: lime with crushed tile
}
NAMES = list(LAYERS)
GRID = 4


def spectral(rng, n, beta, low=1.0, high=None):
    """Periodic 1/f^beta noise in [-1, 1] (seamless by construction)."""
    fx = np.fft.fftfreq(n)[:, None] * n
    fy = np.fft.fftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where(f >= low, 1.0 / np.maximum(f, 1e-6) ** beta, 0.0)
    if high:
        amp *= np.exp(-(f / high) ** 2)
    phase = rng.uniform(0, 2 * np.pi, (n, n))
    spectrum = amp * np.exp(1j * phase)
    out = np.real(np.fft.ifft2(spectrum))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def voronoi(rng, n, cells, jitter=0.9, aspect=1.0, weights=0.0, warp=None):
    """Periodic jittered-grid (power) Voronoi: F1, F2 distances in cell units and cell id.

    weights > 0 gives each site a random radius bonus so cells vary in size;
    warp (two periodic fields in cell units) bends the borders into irregular,
    hand-laid outlines instead of straight polygon edges.
    """
    gx, gy = cells, max(1, int(round(cells * aspect)))
    px = (np.arange(gx)[:, None] + 0.5 + jitter * rng.uniform(-0.5, 0.5, (gx, gy)))
    py = (np.arange(gy)[None, :] + 0.5 + jitter * rng.uniform(-0.5, 0.5, (gx, gy)))
    bonus = weights * rng.uniform(0, 1, (gx, gy)) ** 2
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (xs + 0.5) / n * gx
    v = (ys + 0.5) / n * gy
    if warp is not None:
        u = u + warp[0]
        v = v + warp[1]
    cu = np.floor(u).astype(int)
    cv = np.floor(v).astype(int)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    ident = np.zeros((n, n), np.int32)
    for dx in (-2, -1, 0, 1, 2):
        for dy in (-2, -1, 0, 1, 2):
            ix = cu + dx
            iy = cv + dy
            wx = ix % gx
            wy = iy % gy
            qx = px[wx, wy] + (ix - wx)
            qy = py[wx, wy] + (iy - wy)
            d = np.hypot(u - qx, v - qy) - bonus[wx, wy]
            cid = wx * gy + wy
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ident = np.where(closer, cid, ident)
            f1 = np.where(closer, d, f1)
    return f1, f2, ident


def per_cell(rng, ident, count):
    values = rng.uniform(0, 1, count)
    return values[ident]


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blur(field, radius):
    """Periodic box blur via FFT (cheap Gaussian stand-in)."""
    n = field.shape[0]
    f = np.fft.fftfreq(n)
    g = np.exp(-(np.add.outer(f * f, f * f)) * (np.pi * radius) ** 2 * 2)
    return np.real(np.fft.ifft2(np.fft.fft2(field) * g))


def palette(base, variation, *fields):
    rgb = np.ones(fields[0].shape + (3,), np.float32) * np.array(base, np.float32) / 255.0
    for field, tint in zip(fields, variation):
        rgb += field[..., None] * np.array(tint, np.float32)[None, None, :]
    return rgb


def cracks(rng, n, cells, width, density):
    warp = (spectral(rng, n, 1.3, 3) * 0.6, spectral(rng, n, 1.3, 3) * 0.6)
    f1, f2, ident = voronoi(rng, n, cells, 1.0, 1.0, 0.6, warp)
    edge = f2 - f1
    gate = smooth(spectral(rng, n, 1.4, 3) * 0.5 + 0.5, 1 - density, 1 - density + 0.08)
    wiggle = spectral(rng, n, 1.0, 16) * 0.03
    taper = smooth(spectral(rng, n, 0.9, 12) * 0.5 + 0.5, 0.2, 0.7)
    return (1 - smooth(edge + wiggle, 0, width * (0.4 + taper))) * gate


def plaster(rng, n, aged):
    swell = spectral(rng, n, 2.2, 1)                     # trowel passes, 2 m undulation
    passes = spectral(rng, n, 1.7, 4, 40)                # overlapping trowel strokes
    grain = spectral(rng, n, 0.4, 40)                    # sand aggregate
    pores = np.maximum(0, spectral(rng, n, 0.2, 80) - 0.55) * 2.2
    mottle = spectral(rng, n, 1.8, 2)
    crack = cracks(rng, n, 5, 0.012, 0.34 if aged else 0.12)
    height = 0.5 + 0.20 * swell + 0.10 * passes + 0.05 * grain - 0.12 * pores - 0.18 * crack
    base = (198, 186, 160) if aged else (214, 204, 181)
    rgb = palette(base, [(0.040, 0.037, 0.030), (0.020, 0.020, 0.018), (0.018, 0.018, 0.016)], mottle, grain, passes)
    if aged:
        stain = smooth(spectral(rng, n, 1.9, 2) * 0.5 + 0.5, 0.55, 0.9)
        salt = smooth(spectral(rng, n, 1.5, 3) * 0.5 + 0.5, 0.7, 0.95)
        rgb *= 1 - stain[..., None] * np.array([0.10, 0.11, 0.14])
        rgb += salt[..., None] * np.array([0.05, 0.05, 0.05])
    rgb *= 1 - crack[..., None] * 0.35 - pores[..., None] * 0.08
    rough = 0.90 + 0.05 * grain - 0.04 * passes
    return rgb, height, rough


def masonry(rng, n, cells, mortar_width, rounded, stone_rgb, mortar_rgb, aspect=1.0, deep=0.55, weights=0.45, warp_amount=0.22):
    """Hand-laid irregular stones in lime mortar (opus incertum, field stone socle)."""
    gy = max(1, int(round(cells * aspect)))
    warp = (spectral(rng, n, 1.5, 2) * warp_amount * 1.6, spectral(rng, n, 1.5, 2) * warp_amount * 1.6)
    f1, f2, ident = voronoi(rng, n, cells, 1.0, aspect, weights, warp)
    count = cells * gy
    edge = f2 - f1
    # Joints are wider where stones meet badly and narrow where faces fit.
    joint = mortar_width * (0.55 + 0.9 * (spectral(rng, n, 1.3, 4) * 0.5 + 0.5))
    stone = smooth(edge, joint, joint + rounded)
    tone = per_cell(rng, ident, count)
    hue = per_cell(rng, ident, count)
    tilt_a = per_cell(rng, ident, count) * 2 * np.pi
    ys, xs = np.mgrid[0:n, 0:n] / n
    tilt = np.sin(xs * np.cos(tilt_a) * 6 + ys * np.sin(tilt_a) * 6 + tone * 9)
    face = spectral(rng, n, 1.1, 10) * 0.55 + spectral(rng, n, 0.5, 40) * 0.45
    pits = np.maximum(0, spectral(rng, n, 0.3, 70) - 0.45) * 2.0 * stone
    veins = (1 - smooth(np.abs(spectral(rng, n, 1.6, 3)), 0.0, 0.035)) * stone * (hue > 0.6)
    chips = np.maximum(0, spectral(rng, n, 0.8, 30) - 0.5) * 2 * stone * (1 - smooth(edge, joint, joint + rounded * 2.5))
    mortar_grain = spectral(rng, n, 0.3, 60)
    mortar_lumps = spectral(rng, n, 1.2, 12)
    dome = np.clip(1 - f1 * 1.1, 0, 1) ** 0.5
    height = ((1 - deep) * 0.3 + 0.05 * mortar_lumps * (1 - stone) + 0.03 * mortar_grain * (1 - stone)
              + stone * (deep + 0.14 * dome + 0.05 * tilt + 0.06 * face) - pits * 0.05 - chips * 0.10)
    srgb = np.array(stone_rgb, np.float32) / 255.0
    mrgb = np.array(mortar_rgb, np.float32) / 255.0
    stone_col = srgb[None, None, :] * (0.86 + 0.22 * tone[..., None]) * (1 + 0.07 * face[..., None])
    stone_col *= 1 + (hue[..., None] - 0.5) * np.array([0.09, 0.03, -0.07])
    stone_col *= (1 - pits * 0.25 - veins * 0.10)[..., None]
    mortar_col = mrgb[None, None, :] * (0.92 + 0.07 * mortar_grain[..., None] + 0.05 * mortar_lumps[..., None])
    rgb = mortar_col * (1 - stone[..., None]) + stone_col * stone[..., None]
    rgb *= 1 - chips[..., None] * 0.12
    # Recessed joints hold dust and shade; they never outshine the stones.
    depth_shade = 1 - (1 - stone) * 0.22 * smooth(-(edge - joint), -joint, 0.0)
    rgb *= depth_shade[..., None]
    rough = 0.82 + 0.10 * (1 - stone) + 0.04 * face
    return rgb, height, rough


def ashlar(rng, n):
    """Dressed limestone in courses: drafted margins, claw-tooled faces, worn arrises."""
    rows = 5
    ys, xs = np.mgrid[0:n, 0:n] / n
    wob = spectral(rng, n, 1.6, 3) * 0.006
    row = np.floor((ys + wob) * rows).astype(int) % rows
    offsets = rng.uniform(0, 1, rows)
    lengths = rng.choice([2, 2, 3, 3, 4], rows)
    u = (xs * lengths[row] + offsets[row]) % 1.0
    v = ((ys + wob) * rows) % 1.0
    edge_u = np.minimum(u, 1 - u) / lengths[row] * rows
    edge_v = np.minimum(v, 1 - v)
    edge = np.minimum(edge_u, edge_v) + spectral(rng, n, 0.9, 20) * 0.012
    joint = 0.010
    block = smooth(edge, joint, joint + 0.035)
    margin = smooth(edge, 0.05, 0.08)
    bid = (row * 7 + np.floor(xs * lengths[row] + offsets[row]).astype(int)) % 97
    tone = rng.uniform(0, 1, 97)[bid]
    warmth = rng.uniform(0, 1, 97)[bid]
    angle = rng.uniform(0.6, 1.2, 97)[bid]
    tool = np.sin((xs * np.cos(angle) + ys * np.sin(angle)) * n * 0.45 + spectral(rng, n, 1.0, 20) * 3) * 0.5 + 0.5
    face = spectral(rng, n, 1.2, 8)
    speck = np.maximum(0, spectral(rng, n, 0.3, 80) - 0.5) * 2
    chips = np.maximum(0, spectral(rng, n, 0.7, 40) - 0.35) * 1.6 * (1 - smooth(edge, joint, 0.09)) * block
    height = 0.22 + block * (0.58 + 0.035 * tool * margin + 0.05 * face) - chips * 0.25 - speck * 0.02
    rgb = palette((176, 168, 148), [(0.07, 0.07, 0.06), (0.03, 0.03, 0.03), (-0.03, -0.03, -0.03)], (tone - 0.5) * 2, face, speck)
    rgb *= 1 + (warmth[..., None] - 0.5) * np.array([0.06, 0.02, -0.05])
    rgb *= (0.97 + 0.04 * tool * margin)[..., None]
    rgb *= (1 - chips * 0.10)[..., None]
    mortar_rgb = np.array((118, 110, 96), np.float32) / 255
    rgb = rgb * block[..., None] + mortar_rgb * (1 - block[..., None])
    rough = 0.76 + 0.10 * (1 - block) + 0.05 * tool
    return rgb, height, rough


def daub(rng, n):
    clay = spectral(rng, n, 1.8, 2)
    lumps = spectral(rng, n, 1.2, 6)
    grain = spectral(rng, n, 0.5, 40)
    straw = np.zeros((n, n), np.float32)
    ys, xs = np.mgrid[0:n, 0:n] / n
    for _ in range(160):
        cx, cy = rng.uniform(0, 1, 2)
        angle = rng.normal(0.0, 0.5)
        length = rng.uniform(0.02, 0.07)
        dx = ((xs - cx + 0.5) % 1 - 0.5)
        dy = ((ys - cy + 0.5) % 1 - 0.5)
        along = dx * np.cos(angle) + dy * np.sin(angle)
        across = -dx * np.sin(angle) + dy * np.cos(angle)
        straw = np.maximum(straw, (np.abs(along) < length) * np.exp(-(across / 0.0016) ** 2))
    crack = cracks(rng, n, 5, 0.02, 0.4)
    wash = smooth(spectral(rng, n, 1.9, 2) * 0.5 + 0.5, 0.68, 0.9) * 0.6
    height = 0.5 + 0.2 * lumps + 0.08 * clay + 0.04 * grain + 0.05 * straw - 0.3 * crack + 0.04 * wash
    rgb = palette((138, 112, 82), [(0.05, 0.04, 0.03), (0.04, 0.035, 0.03), (0.02, 0.02, 0.015)], clay, lumps, grain)
    rgb = rgb * (1 - straw[..., None] * 0.35) + straw[..., None] * np.array([0.50, 0.43, 0.29]) * 0.35
    rgb = rgb * (1 - wash[..., None] * 0.8) + wash[..., None] * np.array([0.78, 0.75, 0.68]) * 0.8
    rgb *= (1 - crack * 0.5)[..., None]
    rough = 0.93 - 0.03 * wash
    return rgb, height, rough


def grain_noise(rng, n, across_low, across_high, along_max, beta=1.0):
    """Periodic anisotropic noise: fine across the grain (x), long along it (y)."""
    fx = np.abs(np.fft.fftfreq(n)[None, :] * n)
    fy = np.abs(np.fft.fftfreq(n)[:, None] * n)
    amp = np.where((fx >= across_low) & (fx <= across_high), 1.0 / np.maximum(fx, 1.0) ** beta, 0.0) * np.exp(-(fy / along_max) ** 2)
    out = np.real(np.fft.ifft2(amp * np.exp(1j * rng.uniform(0, 2 * np.pi, (n, n)))))
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-9)


def oak(rng, n, weathered):
    """Riven and adze-dressed oak: irregular growth rings, rays, knots and drying checks.

    Grain runs along v (image vertical). Ring spacing varies and the lines
    wander and merge as on real boards instead of repeating as even stripes.
    """
    ys, xs = np.mgrid[0:n, 0:n] / n
    # Knots bend the grain around them.
    bend = np.zeros_like(xs)
    knot = np.zeros_like(xs)
    for _ in range(3):
        cx, cy = rng.uniform(0, 1, 2)
        radius = rng.uniform(0.012, 0.028)
        dx = (xs - cx + 0.5) % 1 - 0.5
        dy = ((ys - cy + 0.5) % 1 - 0.5) * 0.45
        d = np.hypot(dx, dy)
        bend += np.sign(dx) * np.exp(-(d / (radius * 4.5)) ** 2) * radius * 2.2
        knot = np.maximum(knot, np.exp(-(d / radius) ** 2))
    broad = grain_noise(rng, n, 3, 14, 2.2, 0.6)        # early/late wood bands of varying width
    rings = grain_noise(rng, n, 14, 70, 2.6, 0.5)       # growth rings
    fibre = grain_noise(rng, n, 60, 240, 7.0, 0.3)      # fibres and tool fuzz
    wander = spectral(rng, n, 2.0, 1) * 0.02
    shift = ((bend + wander) * n).astype(int)
    cols = (np.arange(n)[None, :] + shift) % n
    rows = np.arange(n)[:, None]
    broad, rings, fibre = broad[rows, cols], rings[rows, cols], fibre[rows, cols]
    late = smooth(rings * 0.75 + broad * 0.45, -0.05, 0.42)
    rays = np.maximum(0, grain_noise(rng, n, 30, 120, 28.0, 0.2) - 0.42) * 1.6      # medullary flecks
    streak = spectral(rng, n, 1.6, 2) * 0.5 + 0.5
    pores = np.maximum(0, fibre - 0.25) * (0.5 + late)
    checks = np.zeros_like(xs)
    for _ in range(7):
        cx, cy = rng.uniform(0, 1, 2)
        length = rng.uniform(0.08, 0.3)
        dx = ((xs - cx + 0.5) % 1 - 0.5) + 0.004 * np.sin(ys * 2 * np.pi * rng.integers(2, 6) + cx * 9)
        dy = ((ys - cy + 0.5) % 1 - 0.5)
        checks = np.maximum(checks, (np.abs(dy) < length) * np.exp(-(dx / 0.0016) ** 2) * (1 - np.abs(dy) / length))
    height = 0.55 + 0.05 * late + 0.03 * fibre - 0.07 * pores * (2.0 if weathered else 0.8) - 0.45 * checks - 0.10 * knot
    if weathered:
        height -= 0.07 * (1 - late)                        # soft early wood erodes first
        rgb = palette((126, 119, 105), [(-0.085, -0.08, -0.072), (0.03, 0.03, 0.028), (0.07, 0.065, 0.055), (0.05, 0.05, 0.045)],
                      late, fibre, streak - 0.5, rays)
        rgb *= (1 - pores * 0.30)[..., None]
        rough = 0.86 + 0.06 * late
    else:
        rgb = palette((104, 72, 44), [(-0.075, -0.055, -0.036), (0.022, 0.016, 0.01), (0.06, 0.04, 0.022), (0.05, 0.036, 0.02)],
                      late, fibre, streak - 0.5, rays)
        rgb *= (1 - pores * 0.22)[..., None]
        rough = 0.68 + 0.10 * late - 0.05 * rays
    rgb *= (1 - checks * 0.6 - knot * 0.45)[..., None]
    return rgb, height, rough


def tile(rng, n, old):
    ys, xs = np.mgrid[0:n, 0:n] / n
    sand = spectral(rng, n, 0.3, 60)
    kiln = spectral(rng, n, 1.9, 1)
    blotch = smooth(spectral(rng, n, 1.4, 3) * 0.5 + 0.5, 0.62, 0.9)
    strokes = np.sin((ys * 9 + spectral(rng, n, 1.5, 3) * 0.6) * 2 * np.pi) * 0.5 + 0.5
    wear = spectral(rng, n, 1.2, 8)
    height = 0.5 + 0.05 * sand + 0.06 * strokes + 0.05 * wear
    base = (150, 84, 56) if old else (176, 98, 62)
    rgb = palette(base, [(0.07, 0.035, 0.02), (0.025, 0.02, 0.018), (0.02, 0.015, 0.01)], kiln, sand, wear)
    rgb *= (1 - blotch * (0.22 if old else 0.12))[..., None]
    if old:
        lichen = smooth(spectral(rng, n, 0.9, 10) * 0.5 + 0.5, 0.72, 0.85)
        rgb = rgb * (1 - lichen[..., None] * 0.55) + lichen[..., None] * np.array([0.60, 0.60, 0.50]) * 0.55
        height += lichen * 0.04
    rough = 0.82 + 0.06 * sand
    return rgb, height, rough


def mortar(rng, n):
    agg = np.maximum(0, spectral(rng, n, 0.5, 50) - 0.35)
    base = spectral(rng, n, 1.6, 3)
    height = 0.5 + 0.12 * agg + 0.10 * base
    rgb = palette((168, 158, 138), [(0.03, 0.03, 0.03), (0.04, 0.035, 0.03)], base, agg)
    rough = 0.93
    return rgb, height, rough


def iron(rng, n):
    dents = spectral(rng, n, 1.3, 6)
    grain = spectral(rng, n, 0.5, 50)
    rust = smooth(spectral(rng, n, 1.4, 4) * 0.5 + 0.5, 0.55, 0.8)
    height = 0.5 + 0.18 * dents + 0.03 * grain + 0.05 * rust
    rgb = palette((58, 56, 52), [(0.02, 0.02, 0.02), (0.015, 0.015, 0.015)], dents, grain)
    rgb = rgb * (1 - rust[..., None]) + rust[..., None] * np.array([0.36, 0.20, 0.11])
    rough = 0.55 + 0.35 * rust
    return rgb, height, rough


def paint(rng, n, rgb_base):
    rgb, height, rough = plaster(rng, n, aged=False)
    strokes = spectral(rng, n, 1.5, 4, 30)
    fade = smooth(spectral(rng, n, 1.8, 2) * 0.5 + 0.5, 0.5, 1.1) * 0.6 + smooth(spectral(rng, n, 1.2, 6) * 0.5 + 0.5, 0.6, 0.9) * 0.3
    pigment = np.array(rgb_base, np.float32)[None, None, :] / 255.0 * (0.92 + 0.10 * strokes[..., None])
    mix = (0.92 - 0.35 * fade)[..., None]
    rgb = rgb * (1 - mix) + pigment * mix
    return rgb, height, rough - 0.03


def flagstone(rng, n):
    face = spectral(rng, n, 1.5, 3)
    fossils = np.maximum(0, spectral(rng, n, 0.4, 60) - 0.6) * 2
    polish = smooth(spectral(rng, n, 1.8, 2) * 0.5 + 0.5, 0.4, 0.8)
    height = 0.5 + 0.10 * face - 0.08 * fossils
    rgb = palette((170, 162, 144), [(0.05, 0.05, 0.045), (-0.05, -0.05, -0.05)], face, fossils)
    rough = 0.80 - 0.18 * polish
    return rgb, height, rough


def cocciopesto(rng, n):
    rgb, height, rough = masonry(rng, n, 46, 0.30, 0.10, (156, 84, 62), (182, 150, 124), deep=0.15)
    lime = spectral(rng, n, 1.7, 3)
    rgb *= (1 + 0.05 * lime)[..., None]
    return rgb, height * 0.5 + 0.25, rough - 0.08


def make_layer(name, n, seed):
    rng = np.random.default_rng(seed)
    if name == "plaster_lime":
        return plaster(rng, n, False)
    if name == "plaster_aged":
        return plaster(rng, n, True)
    if name == "opus_incertum":
        return masonry(rng, n, 10, 0.07, 0.07, (146, 138, 120), (140, 131, 114), aspect=0.85, weights=0.3)
    if name == "rubble_socle":
        return masonry(rng, n, 6, 0.07, 0.06, (124, 119, 106), (112, 105, 92), aspect=0.75, deep=0.7, weights=0.22, warp_amount=0.10)
    if name == "ashlar":
        return ashlar(rng, n)
    if name == "daub":
        return daub(rng, n)
    if name == "oak_grey":
        return oak(rng, n, True)
    if name == "oak_brown":
        return oak(rng, n, False)
    if name == "tegula":
        return tile(rng, n, False)
    if name == "tegula_old":
        return tile(rng, n, True)
    if name == "mortar":
        return mortar(rng, n)
    if name == "iron":
        return iron(rng, n)
    if name == "paint_red":
        return paint(rng, n, (138, 58, 40))
    if name == "paint_ochre":
        return paint(rng, n, (184, 140, 72))
    if name == "flagstone":
        return flagstone(rng, n)
    if name == "cocciopesto":
        return cocciopesto(rng, n)
    raise KeyError(name)


def normal_from_height(height, strength, metres):
    n = height.shape[0]
    texel = metres / n
    # Periodic central differences; +x right, +y up (image row 0 is the top).
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / (2 * texel)
    dy = (np.roll(height, 1, 0) - np.roll(height, -1, 0)) / (2 * texel)
    relief = strength * 0.004  # height 0..1 spans about 4 mm x strength
    nx, ny, nz = -dx * relief, -dy * relief, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], -1)


def ambient_occlusion(height):
    wide = blur(height, 6.0 / height.shape[0])
    near = blur(height, 2.0 / height.shape[0])
    cavity = np.clip((height - wide) * 2.5 + (height - near) * 2.5, -1, 1)
    return np.clip(0.88 + cavity * 0.5, 0.25, 1.0)


STRENGTH = {"plaster_lime": 3.0, "plaster_aged": 3.5, "opus_incertum": 9.0, "rubble_socle": 12.0, "ashlar": 6.0,
            "daub": 6.0, "oak_grey": 5.0, "oak_brown": 3.5, "tegula": 3.0, "tegula_old": 3.5, "mortar": 3.0,
            "iron": 3.0, "paint_red": 2.5, "paint_ochre": 2.5, "flagstone": 3.0, "cocciopesto": 3.0}


def build(out: Path, sizes=(1024, 512, 256)):
    out.mkdir(parents=True, exist_ok=True)
    master = 1024
    layers = {}
    for index, name in enumerate(NAMES):
        rgb, height, rough = make_layer(name, master, 9100 + index * 31)
        height = np.clip(height, 0, 1)
        rough = np.clip(rough if np.ndim(rough) else np.full_like(height, rough), 0.05, 1)
        normal = normal_from_height(height, STRENGTH[name], LAYERS[name])
        ao = ambient_occlusion(height)
        layers[name] = (np.clip(rgb, 0, 1), normal, np.stack([ao, rough, height], -1))
        print("FAMILY_LAYER", index, name, "albedo_mean", np.round(layers[name][0].mean((0, 1)), 3).tolist())
    report = {"layers": NAMES, "repeat_metres": LAYERS, "grid": GRID, "files": {}, "generator": "art/architecture/valdora_family/family_textures.py",
              "provenance": "Procedural, seeded NumPy/Pillow patterns authored for IMPERATHEN; no scans or downloads."}
    for size in sizes:
        for kind, channel in (("albedo", 0), ("normal", 1), ("orm", 2)):
            if size <= 256 and kind == "normal":
                continue  # Leicht shades without tangent-space normals
            sheet = np.zeros((size * GRID, size * GRID, 3), np.float32)
            for index, name in enumerate(NAMES):
                data = layers[name][channel]
                if kind == "normal":
                    data = data * 0.5 + 0.5
                image = Image.fromarray((np.clip(data, 0, 1) * 255 + 0.5).astype(np.uint8))
                if size != master:
                    image = image.resize((size, size), Image.Resampling.LANCZOS)
                r, c = divmod(index, GRID)
                sheet[r * size:(r + 1) * size, c * size:(c + 1) * size] = np.asarray(image, np.float32) / 255.0
            path = out / f"family_{kind}_{size}.jpg"
            Image.fromarray((sheet * 255 + 0.5).astype(np.uint8)).save(path, quality=(90 if size > 512 else 93) if kind == "albedo" else (92 if size > 512 else 95), subsampling=0)
            report["files"][path.name] = {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                          "slices": GRID * GRID, "slice_size": size}
            print("FAMILY_TEXTURE", path, path.stat().st_size)
    (out / "family_textures.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--preview", type=Path, help="optional contact sheet PNG")
    args = parser.parse_args()
    build(args.out)
    if args.preview:
        sheet = Image.open(args.out / "family_albedo_1024.jpg")
        sheet.resize((2048, 2048)).save(args.preview)
