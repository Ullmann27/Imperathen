#!/usr/bin/env python3
"""Generates the tileable landscape textures of prototype/assets/landscape.

Own procedural work (spectral noise and a toroidal Voronoi), deterministic:
  terrain_macro.png  R large moisture patches, G mottling, B ridged streaks
  scree_color.png    weathered limestone scree for steep slopes and summits
  brook_bed.png      rounded pebbles and silt of the brook bed
  water_ripple.png   tangent-space ripple normals for flowing water
Usage: python3 tools/world/landscape_textures.py [output directory]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "prototype/assets/landscape"


def spectral(size, beta, seed, low=1.0, high=None):
    """Tileable noise with a 1/f^beta spectrum between two wave numbers, 0..1."""
    rng = np.random.default_rng(seed)
    fx = np.fft.fftfreq(size) * size
    radius = np.hypot(*np.meshgrid(fx, fx))
    amplitude = np.where(radius >= low, radius.clip(1e-6) ** (-beta), 0.0)
    if high is not None:
        amplitude = amplitude * np.exp(-(radius / high) ** 4)
    field = np.fft.ifft2(amplitude * np.exp(2j * np.pi * rng.random((size, size)))).real
    low_value, high_value = np.percentile(field, [0.5, 99.5])
    return ((field - low_value) / (high_value - low_value)).clip(0, 1)


def voronoi(size, count, seed):
    """Toroidal F1, F2 distances and the owning cell of each texel."""
    rng = np.random.default_rng(seed)
    points = rng.random((count, 2)) * size
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    first = np.full((size, size), 1e9, np.float32)
    second = np.full((size, size), 1e9, np.float32)
    owner = np.zeros((size, size), np.int32)
    for index, (px, py) in enumerate(points):
        dx = np.abs(xs - px)
        dy = np.abs(ys - py)
        distance = np.hypot(np.minimum(dx, size - dx), np.minimum(dy, size - dy))
        closer = distance < first
        second = np.where(closer, first, np.minimum(second, distance))
        owner = np.where(closer, index, owner)
        first = np.where(closer, distance, first)
    return first, second, owner, rng


def save(name, array):
    Image.fromarray((array.clip(0, 1) * 255 + .5).astype(np.uint8)).save(OUT / name, optimize=True)
    print("LANDSCAPE_TEXTURE", name, array.shape, "mean", np.round(array.reshape(-1, array.shape[-1]).mean(0), 3))


def normals(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    length = np.sqrt(dx * dx + dy * dy + 1.0)
    return np.dstack([-dx / length * .5 + .5, -dy / length * .5 + .5, 1.0 / length * .5 + .5])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    patches = spectral(256, 2.4, 11, low=1, high=10)
    mottling = spectral(256, 1.6, 12, low=4, high=60)
    ridged = 1.0 - np.abs(spectral(256, 2.0, 13, low=2, high=40) * 2.0 - 1.0)
    save("terrain_macro.png", np.dstack([patches, mottling, ridged ** 2]))

    # Scree: angular fragments (Voronoi cells) over fractured bedrock.
    first, second, owner, rng = voronoi(512, 900, 21)
    tone = rng.random(900)[owner]
    crack = np.clip((second - first) / 3.0, 0, 1)
    grain = spectral(512, 1.2, 22, low=8)
    strata = spectral(512, 2.2, 23, low=2, high=30)
    value = .50 + .16 * (tone - .5) + .12 * (grain - .5) + .14 * (strata - .5)
    value *= .62 + .38 * crack
    warm = np.array([.66, .62, .55])
    cool = np.array([.56, .57, .56])
    rock = value[..., None] * (cool + (warm - cool) * strata[..., None]) / .58
    lichen = np.clip((spectral(512, 2.0, 24, low=3, high=24) - .72) * 5.0, 0, 1)[..., None]
    save("scree_color.png", rock * (1 - lichen * .35) + lichen * .35 * np.array([.45, .47, .30]))

    # Brook bed: rounded pebbles of mixed stone, silt in the gaps.
    first, second, owner, rng = voronoi(512, 520, 31)
    radius = (second - first) / 2.0
    dome = np.clip(radius / 5.0, 0, 1) ** .6
    kinds = np.array([[.52, .47, .38], [.40, .38, .34], [.60, .56, .47], [.36, .30, .24], [.47, .44, .42]])
    stone = kinds[rng.integers(0, len(kinds), 520)][owner] * (.85 + .3 * rng.random(520)[owner])[..., None]
    silt = np.array([.25, .22, .16]) * (.8 + .4 * spectral(512, 1.5, 32, low=6))[..., None]
    speck = (.9 + .2 * spectral(512, .8, 33, low=20))[..., None]
    save("brook_bed.png", (silt + (stone * (.55 + .45 * dome[..., None]) - silt) * np.clip(radius / 1.6, 0, 1)[..., None]) * speck)

    # Ripples: two scales of smooth waves; the shader scrolls two samples.
    waves = spectral(256, 2.6, 41, low=3, high=22) + .35 * spectral(256, 1.8, 42, low=14, high=60)
    save("water_ripple.png", normals(waves, 9.0))


if __name__ == "__main__":
    main()
