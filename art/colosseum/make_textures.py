"""Procedural, tileable PBR textures for the monument kits (numpy + Pillow, no external artwork).

Run: python3 art/colosseum/make_textures.py [--size 1024] [--output prototype/assets/monuments/textures]
Each material gets <name>_albedo.jpg and <name>_normal.jpg (JPEG keeps the repository small; Godot recompresses to ETC2/ASTC); one tile covers 3 x 3 m.
"""
import argparse
import os

import numpy as np
from PIL import Image

P = argparse.ArgumentParser()
P.add_argument("--size", type=int, default=1024)
P.add_argument("--output", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../prototype/assets/monuments/textures"))
A = P.parse_args()
N = A.size
RNG = np.random.default_rng(20261126)
FY, FX = np.meshgrid(np.fft.fftfreq(N) * N, np.fft.fftfreq(N) * N, indexing="ij")
FR = np.hypot(FX, FY)
FR[0, 0] = 1.0
YY, XX = np.meshgrid(np.arange(N) / N, np.arange(N) / N, indexing="ij")


def fbm(beta=2.0, lo=1.0, hi=None, aniso=(1.0, 1.0)):
    """Tileable spectral noise in 0..1; aniso stretches features along x / y."""
    spec = RNG.normal(size=(N, N)) + 1j * RNG.normal(size=(N, N))
    r = np.hypot(FX * aniso[0], FY * aniso[1])
    r[0, 0] = 1.0
    amp = r ** (-beta / 2.0)
    amp[r < lo] = 0
    if hi:
        amp[r > hi] = 0
    v = np.real(np.fft.ifft2(spec * amp))
    v -= v.min()
    return v / v.max()


def blur(img, sigma):
    return np.real(np.fft.ifft2(np.fft.fft2(img) * np.exp(-2 * (np.pi * sigma / N) ** 2 * (FX ** 2 + FY ** 2))))


def joints(courses, per_course, bond=0.5, width=0.006, jitter=0.0):
    """Height mask of mortar joints (1 = stone face, 0 = joint) and a per-block id map."""
    mask = np.ones((N, N))
    ids = np.zeros((N, N))
    v = YY * courses
    row = np.floor(v)
    fy = v - row
    shift = (row % 2) * bond + jitter * np.sin(row * 12.9898) * 0.5
    u = (XX + shift / per_course) * per_course
    col = np.floor(u)
    fx = u - col
    d = np.minimum(np.minimum(fy, 1 - fy) / courses, np.minimum(fx, 1 - fx) / per_course)
    mask = np.clip(d / width, 0, 1)
    ids = (np.sin(row * 78.233 + (col % per_course) * 37.719) * 43758.5453) % 1.0
    return mask, ids


def normal_from(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength * N / 1024
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength * N / 1024
    nz = np.ones_like(height)
    ln = np.sqrt(dx * dx + dy * dy + nz)
    return np.stack([(-dx / ln + 1) / 2, (dy / ln + 1) / 2, nz / ln * 0.5 + 0.5], -1)


def save(name, albedo, height, strength):
    os.makedirs(A.output, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(os.path.join(A.output, name + "_albedo.jpg"), quality=88)
    Image.fromarray((np.clip(normal_from(height, strength), 0, 1) * 255).astype(np.uint8)).save(os.path.join(A.output, name + "_normal.jpg"), quality=92, subsampling=0)
    print("TEXTURE", name)


def colour(base, v):
    return np.asarray(base)[None, None, :] * v[..., None]


def travertine(name, courses, per_course, base, joint_w, polish=0.0):
    band = fbm(2.2, 1, 90, aniso=(0.25, 2.2))        # horizontal bedding
    grain = fbm(1.6, 8)
    pits = fbm(0.6, 30, 220, aniso=(0.5, 1.6))
    cav = np.clip((pits - (0.70 + 0.08 * polish)) * 14, 0, 1)   # elongated cavities typical of travertine
    mask, ids = joints(courses, per_course, width=joint_w)
    stain = blur(fbm(2.6, 1, 12), 2)
    tone = 0.86 + 0.16 * band + 0.06 * grain + (ids - 0.5) * 0.10 - 0.16 * (stain > 0.62) * (stain - 0.62) * 4
    tone *= 1 - 0.38 * cav
    tone *= 0.62 + 0.38 * mask
    alb = colour(base, tone)
    alb[..., 2] *= 0.96 + 0.06 * band
    height = mask * 0.8 + band * 0.12 - cav * 0.5 + grain * 0.05
    save(name, alb, blur(height, 0.6), 5.0)


def brick(name, courses, per_course, base, floor=False):
    mask, ids = joints(courses, per_course, width=0.004 if not floor else 0.003, bond=0.5)
    grain = fbm(1.2, 12)
    soot = blur(fbm(2.4, 1, 10), 2)
    tone = 0.78 + 0.34 * ids + 0.10 * grain - 0.12 * soot
    alb = colour(base, tone)
    mortar = np.asarray((0.74, 0.70, 0.62))[None, None, :] * (0.85 + 0.15 * grain[..., None])
    alb = alb * mask[..., None] + mortar * (1 - mask[..., None])
    save(name, alb, blur(mask * 0.7 + grain * 0.1, 0.6), 4.0)


def main():
    travertine("travertine", 5, 2, (0.72, 0.65, 0.52), 0.0035)
    travertine("travertine_paving", 3, 3, (0.60, 0.56, 0.48), 0.004, polish=0.5)
    # tuff: rough, porous, in small squared blocks
    mask, ids = joints(8, 5, width=0.004, jitter=0.6)
    g = fbm(1.4, 6)
    p = np.clip((fbm(0.5, 40, 260) - 0.66) * 9, 0, 1)
    save("tuff", colour((0.50, 0.41, 0.31), (0.8 + 0.25 * ids + 0.15 * g) * (1 - 0.35 * p) * (0.6 + 0.4 * mask)), blur(mask * 0.6 - p * 0.4 + g * 0.15, 0.6), 5.0)
    brick("brick", 40, 7, (0.60, 0.33, 0.22))
    brick("brick_floor", 24, 12, (0.56, 0.35, 0.24), floor=True)
    # marble: veined, smooth slabs
    mask, ids = joints(4, 2, width=0.002)
    v1 = np.abs(fbm(2.4, 2, 60) - 0.5) * 2
    vein = np.clip(1 - v1 * 9, 0, 1) ** 2
    cloud = fbm(2.8, 1, 20)
    alb = colour((0.80, 0.78, 0.74), 0.9 + 0.1 * cloud + (ids - 0.5) * 0.04)
    alb -= vein[..., None] * np.asarray((0.22, 0.20, 0.17))[None, None, :]
    alb *= (0.8 + 0.2 * mask)[..., None]
    save("marble", alb, blur(mask * 0.5, 0.8), 2.5)
    save("marble_statue", colour((0.80, 0.78, 0.73), 0.92 + 0.08 * cloud) - vein[..., None] * 0.08, blur(cloud * 0.1, 1.0), 1.0)
    # plaster
    g = fbm(1.8, 3)
    cr = np.clip(1 - np.abs(fbm(2.0, 3, 80) - 0.5) * 60, 0, 1)
    save("plaster", colour((0.72, 0.66, 0.54), 0.86 + 0.16 * g - 0.25 * cr), blur(g * 0.3 - cr * 0.4, 0.7), 3.0)
    # raked arena sand
    g = fbm(1.0, 20)
    rip = fbm(2.0, 2, 30, aniso=(0.4, 2.0))
    save("sand", colour((0.66, 0.55, 0.38), 0.84 + 0.12 * g + 0.10 * rip), blur(g * 0.5 + rip * 0.6, 0.8), 3.5)
    # timber planks
    for name, base in (("wood", (0.50, 0.35, 0.21)), ("wood_dark", (0.30, 0.21, 0.13))):
        mask, ids = joints(1, 9, width=0.0025, bond=0.0)
        fib = fbm(1.6, 4, aniso=(3.0, 0.12))
        save(name, colour(base, (0.78 + 0.3 * fib + (ids - 0.5) * 0.18) * (0.6 + 0.4 * mask)), blur(mask * 0.6 + fib * 0.25, 0.5), 4.0)
    # terracotta roof: rows of imbrices
    u = (XX * 10) % 1.0
    v = (YY * 6) % 1.0
    imb = np.clip(1 - np.abs(u - 0.5) * 5, 0, 1)
    lap = np.clip(v * 8, 0, 1)
    g = fbm(1.4, 6)
    ids = (np.sin(np.floor(XX * 10) * 12.9 + np.floor(YY * 6) * 78.2) * 43758.5) % 1.0
    save("roof_tile", colour((0.72, 0.40, 0.26), (0.72 + 0.2 * ids + 0.12 * g) * (0.7 + 0.3 * lap) * (0.85 + 0.15 * imb)), blur(imb * 0.8 + lap * 0.3, 0.8), 6.0)
    # canvas weave with seams
    weave = 0.5 + 0.25 * np.sin(XX * N * 0.8) * np.sin(YY * N * 0.8)
    g = fbm(2.2, 1, 30)
    seam = np.clip(np.abs(((XX * 4) % 1.0) - 0.5) * 60, 0, 1)
    save("canvas", colour((0.78, 0.72, 0.58), (0.86 + 0.14 * g) * (0.75 + 0.25 * seam)), blur(weave * 0.15 + (1 - seam) * 0.4, 0.5), 2.0)
    # weathered bronze and wrought iron
    g = fbm(1.8, 3)
    pat = np.clip((fbm(2.2, 2, 40) - 0.55) * 5, 0, 1)
    alb = colour((0.52, 0.36, 0.17), 0.8 + 0.3 * g) * (1 - pat[..., None]) + colour((0.25, 0.42, 0.34), 0.8 + 0.2 * g) * pat[..., None]
    save("bronze", alb, blur(g * 0.3, 0.8), 2.0)
    save("bronze_gilt", colour((0.90, 0.68, 0.26), 0.82 + 0.25 * g), blur(g * 0.2, 0.8), 1.5)
    save("iron", colour((0.20, 0.18, 0.17), 0.7 + 0.5 * g), blur(g * 0.5, 0.6), 3.0)


main()
