#!/usr/bin/env python3
"""Seeded ground layers for Roman paving and village paths (2 x 4 slice arrays).

    paving_albedo_<n>.jpg   sRGB albedo
    paving_normal_<n>.jpg   tangent normal, OpenGL convention (green = +V)
    paving_orm_<n>.jpg      R ambient occlusion, G roughness, B height (stone = high)

Layers (repeat in metres):
  0 cobbles      river cobbles of the Isonzo/Torre gravel beds set in soil (1.6)
  1 flags        irregular worn limestone flags, soil-filled joints (2.4)
  2 gravel       glarea: rammed gravel with fines and grit (1.6)
  3 soil         trodden earth used as joint fill and fringe (2.0)
  4 silex        polygonal basalt-like paving blocks of a via (2.4)
  5 kerb         dressed limestone for kerbs, steps and edge stones (1.2)
  6 turf_soil    thin turf breaking through soil (2.0)
  7 mud          wet trampled mud for puddle hollows (2.0)

Joints are narrow and filled with soil and dust: darker than the stones, never
bright mortar lines. The height channel doubles as stone mask for the organic
fringe (stones thin out one by one into the ground).

    python3 art/architecture/valdora_family/paving_textures.py --out prototype/assets/architecture/valdora
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from family_textures import (ambient_occlusion, normal_from_height, palette, per_cell, smooth, spectral, voronoi)

LAYERS = {"cobbles": 1.6, "flags": 2.4, "gravel": 1.6, "soil": 2.0, "silex": 2.4, "kerb": 1.2, "turf_soil": 2.0, "mud": 2.0}
NAMES = list(LAYERS)
COLS, ROWS = 4, 2
STRENGTH = {"cobbles": 14.0, "flags": 7.0, "gravel": 8.0, "soil": 4.0, "silex": 9.0, "kerb": 5.0, "turf_soil": 5.0, "mud": 3.0}


def soil(rng, n, darker=1.0):
    clods = spectral(rng, n, 1.3, 6)
    grit = np.maximum(0, spectral(rng, n, 0.3, 60) - 0.45) * 2
    dust = spectral(rng, n, 1.9, 2)
    prints = np.maximum(0, spectral(rng, n, 1.0, 10) - 0.6) * 1.5
    height = 0.32 + 0.06 * clods + 0.05 * grit - 0.06 * prints
    rgb = palette((112, 96, 76), [(0.05, 0.045, 0.04), (0.04, 0.04, 0.035), (0.03, 0.025, 0.02)], dust, grit, clods) * darker
    rgb *= (1 - prints * 0.12)[..., None]
    rough = 0.94 - 0.03 * grit
    return rgb, height, rough


def stones(rng, n, cells, joint, rounded, stone_rgb, aspect=1.0, weights=0.5, warp_amount=0.2, dome_power=0.6, tone_var=0.30, polish=0.0, soften=0.0):
    gy = max(1, int(round(cells * aspect)))
    warp = (spectral(rng, n, 1.5, 2) * warp_amount * 1.6, spectral(rng, n, 1.5, 2) * warp_amount * 1.6)
    f1, f2, ident = voronoi(rng, n, cells, 1.0, aspect, weights, warp)
    count = cells * gy
    edge = f2 - f1
    width = joint * (0.6 + 0.8 * (spectral(rng, n, 1.3, 4) * 0.5 + 0.5))
    mask = smooth(edge, width, width + rounded)
    if soften:
        # Clip each cell with an irregular oval: water-worn cobbles instead of polygons.
        reach = soften * (0.82 + 0.36 * per_cell(rng, ident, count)) + spectral(rng, n, 1.2, 8) * 0.05
        mask = mask * smooth(-f1, -reach, -reach + 0.10)
    tone = per_cell(rng, ident, count)
    hue = per_cell(rng, ident, count)
    tilt_a = per_cell(rng, ident, count) * 2 * np.pi
    sink = per_cell(rng, ident, count)
    ys, xs = np.mgrid[0:n, 0:n] / n
    tilt = np.sin(xs * np.cos(tilt_a) * 7 + ys * np.sin(tilt_a) * 7 + tone * 9)
    dome = np.clip(1 - f1 * 1.05, 0, 1) ** dome_power
    face = spectral(rng, n, 1.0, 12) * 0.5 + spectral(rng, n, 0.4, 50) * 0.5
    pits = np.maximum(0, spectral(rng, n, 0.3, 80) - 0.5) * 2 * mask
    rgb_soil, h_soil, r_soil = soil(rng, n, 0.86)
    srgb = np.array(stone_rgb, np.float32) / 255.0
    stone_col = srgb[None, None, :] * (1 - tone_var / 2 + tone_var * tone[..., None]) * (1 + 0.06 * face[..., None])
    stone_col *= 1 + (hue[..., None] - 0.5) * np.array([0.10, 0.03, -0.08])
    # Dust settles toward the joints: stone edges take the soil tint.
    dusty = 1 - smooth(edge, width, width + min(rounded * 3.0, 0.12))
    stone_col = stone_col * (1 - 0.35 * dusty[..., None]) + rgb_soil * 0.35 * dusty[..., None]
    stone_col *= (1 - pits * 0.2)[..., None]
    height = h_soil * (1 - mask) + mask * (0.55 + 0.22 * dome + 0.05 * tilt + 0.04 * face - 0.10 * sink) - pits * 0.04
    rgb = rgb_soil * (1 - mask[..., None]) + stone_col * mask[..., None]
    # Joints recede and shade (soil-filled, narrow): darker than the stones.
    rgb *= (1 - (1 - mask) * 0.18)[..., None]
    rough = r_soil * (1 - mask) + mask * (0.80 - polish * smooth(dome, 0.3, 0.9) + 0.04 * face)
    return rgb, height, rough


def gravel(rng, n, passes=((90, 0.32), (48, 0.36), (22, 0.40)), keep_rate=0.55, base_rgb=(0.55, 0.52, 0.47), dome=0.25):
    rgb_s, h_s, r_s = soil(rng, n, 0.95)
    out_rgb, out_h = rgb_s.copy(), h_s.copy()
    for cells, size in passes:
        f1, f2, ident = voronoi(rng, n, cells, 1.0, 1.0, 0.3, None)
        count = cells * cells
        keep = per_cell(rng, ident, count) < keep_rate
        r = size * (0.6 + 0.6 * per_cell(rng, ident, count))
        pebble = smooth(-f1, -r, -r * 0.55) * keep
        tone = per_cell(rng, ident, count)
        col = np.array(base_rgb)[None, None, :] * (0.75 + 0.5 * tone[..., None])
        col *= 1 + (per_cell(rng, ident, count)[..., None] - 0.5) * np.array([0.15, 0.05, -0.1])
        h = 0.4 + dome * np.clip(1 - f1 / np.maximum(r, 1e-3), 0, 1) ** 0.5
        sel = pebble > 0.5
        out_rgb = np.where(sel[..., None], col, out_rgb)
        out_h = np.where(sel, np.maximum(out_h, h), out_h)
    return out_rgb, out_h, 0.9


def turf_soil(rng, n):
    rgb, h, r = soil(rng, n, 0.92)
    cover = smooth(spectral(rng, n, 1.6, 3) * 0.5 + 0.5, 0.45, 0.7)
    blades = np.maximum(0, spectral(rng, n, 0.2, 100)) * cover
    green = palette((88, 98, 52), [(0.05, 0.06, 0.03), (0.05, 0.05, 0.02)], spectral(rng, n, 1.2, 6), blades)
    mix = np.clip(cover * (0.6 + 0.6 * blades), 0, 1)
    return rgb * (1 - mix[..., None]) + green * mix[..., None], h + 0.08 * blades, 0.92


def mud(rng, n):
    rgb, h, r = soil(rng, n, 0.70)
    slick = spectral(rng, n, 1.8, 2) * 0.5 + 0.5
    return rgb * (0.85 + 0.15 * slick[..., None]), 0.3 + 0.08 * slick, 0.55 - 0.2 * slick


def make(name, n, seed):
    rng = np.random.default_rng(seed)
    if name == "cobbles":
        # Rounded river cobbles of mixed size and rock type, bedded tightly in soil.
        return stones(rng, n, 13, 0.035, 0.07, (134, 130, 120), aspect=1.0, weights=0.15, warp_amount=0.10, dome_power=0.55, tone_var=0.50, polish=0.12, soften=0.60)
    if name == "flags":
        return stones(rng, n, 5, 0.022, 0.02, (164, 157, 140), aspect=1.0, weights=0.3, warp_amount=0.07, dome_power=1.6, tone_var=0.18, polish=0.25)
    if name == "gravel":
        return gravel(rng, n)
    if name == "soil":
        return soil(rng, n)
    if name == "silex":
        return stones(rng, n, 6, 0.028, 0.035, (98, 98, 94), aspect=1.0, weights=0.35, warp_amount=0.05, dome_power=1.2, tone_var=0.25, polish=0.35)
    if name == "kerb":
        return stones(rng, n, 2, 0.02, 0.02, (176, 168, 148), aspect=2.0, weights=0.1, warp_amount=0.02, dome_power=2.5, tone_var=0.15, polish=0.2)
    if name == "turf_soil":
        return turf_soil(rng, n)
    if name == "mud":
        return mud(rng, n)
    raise KeyError(name)


def build(out: Path, sizes=(1024, 512, 256)):
    out.mkdir(parents=True, exist_ok=True)
    master = 1024
    layers = {}
    for index, name in enumerate(NAMES):
        rgb, height, rough = make(name, master, 7300 + index * 41)
        height = np.clip(height, 0, 1)
        rough = np.clip(rough if np.ndim(rough) else np.full_like(height, rough), 0.05, 1)
        normal = normal_from_height(height, STRENGTH[name], LAYERS[name])
        ao = ambient_occlusion(height)
        layers[name] = (np.clip(rgb, 0, 1), normal, np.stack([ao, rough, height], -1))
        print("PAVING_LAYER", index, name, np.round(layers[name][0].mean((0, 1)), 3).tolist())
    report = {"layers": NAMES, "repeat_metres": LAYERS, "grid": [COLS, ROWS], "files": {},
              "generator": "art/architecture/valdora_family/paving_textures.py",
              "provenance": "Procedural, seeded NumPy/Pillow patterns authored for IMPERATHEN; no scans or downloads."}
    for size in sizes:
        for kind, channel in (("albedo", 0), ("normal", 1), ("orm", 2)):
            if size <= 256 and kind == "normal":
                continue
            sheet = np.zeros((size * ROWS, size * COLS, 3), np.float32)
            for index, name in enumerate(NAMES):
                data = layers[name][channel]
                if kind == "normal":
                    data = data * 0.5 + 0.5
                image = Image.fromarray((np.clip(data, 0, 1) * 255 + 0.5).astype(np.uint8))
                if size != master:
                    image = image.resize((size, size), Image.Resampling.LANCZOS)
                r, c = divmod(index, COLS)
                sheet[r * size:(r + 1) * size, c * size:(c + 1) * size] = np.asarray(image, np.float32) / 255.0
            path = out / f"paving_{kind}_{size}.jpg"
            Image.fromarray((sheet * 255 + 0.5).astype(np.uint8)).save(path, quality=(90 if size > 512 else 93) if kind == "albedo" else (92 if size > 512 else 95), subsampling=0)
            report["files"][path.name] = {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "slices": COLS * ROWS, "slice_size": size}
            print("PAVING_TEXTURE", path, path.stat().st_size)
    (out / "paving_textures.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    build(args.out)
    if args.preview:
        Image.open(args.out / "paving_albedo_1024.jpg").resize((2048, 1024)).save(args.preview)
