#!/usr/bin/env python3
"""Original periodic PBR surfaces for the Valdora household kit. No external art.

Every material is one tiling set of three PNGs: albedo (sRGB), tangent-space
normal (+Y, OpenGL convention) and ORM (R ambient occlusion, G roughness,
B metallic). `embers` adds an emission mask. The physical tile size in metres
is fixed per material and mirrored by the UVs written in build_interior_kit.py.

    python3 art/interiors/interior_surfaces.py [--size 512] [--out prototype/assets/interiors/textures]
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# name: (tile metres, sRGB base colour, base roughness, metallic, seed)
MATERIALS = {
    "oak": (0.60, (0.47, 0.33, 0.21), 0.72, 0.0, 11),
    "wood_rough": (0.60, (0.52, 0.44, 0.34), 0.86, 0.0, 12),
    "wicker": (0.24, (0.60, 0.46, 0.28), 0.82, 0.0, 13),
    "straw": (0.40, (0.70, 0.62, 0.43), 0.90, 0.0, 14),
    "linen": (0.20, (0.78, 0.72, 0.60), 0.92, 0.0, 15),
    "wool": (0.25, (0.84, 0.80, 0.72), 0.96, 0.0, 16),
    "leather": (0.35, (0.42, 0.25, 0.14), 0.62, 0.0, 17),
    "terracotta": (0.40, (0.62, 0.41, 0.30), 0.80, 0.0, 18),
    "coarseware": (0.40, (0.38, 0.33, 0.28), 0.90, 0.0, 19),
    "iron": (0.30, (0.30, 0.29, 0.28), 0.58, 0.72, 20),
    "bronze": (0.30, (0.62, 0.46, 0.26), 0.42, 0.85, 21),
    "stone": (0.60, (0.62, 0.59, 0.53), 0.90, 0.0, 22),
    "food": (0.20, (0.86, 0.74, 0.54), 0.78, 0.0, 23),
    "hearth_clay": (0.50, (0.58, 0.48, 0.39), 0.95, 0.0, 24),
    "embers": (0.40, (0.075, 0.065, 0.06), 0.93, 0.0, 25),
}


class Field:
    """Periodic value noise on a size x size torus, so every map tiles exactly."""

    def __init__(self, size: int, seed: int):
        self.size = size
        self.rng = np.random.default_rng(seed)
        axis = np.arange(size, dtype=np.float32) / size
        self.u, self.v = np.meshgrid(axis, axis)

    def noise(self, gx: int, gy: int, u=None, v=None):
        u = self.u if u is None else u
        v = self.v if v is None else v
        grid = self.rng.random((gy, gx), dtype=np.float32)
        x, y = (u % 1.0) * gx, (v % 1.0) * gy
        ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
        a, b = x - ix, y - iy
        a, b = a * a * (3 - 2 * a), b * b * (3 - 2 * b)
        ix, iy = ix % gx, iy % gy
        jx, jy = (ix + 1) % gx, (iy + 1) % gy
        return ((1 - b) * ((1 - a) * grid[iy, ix] + a * grid[iy, jx]) + b * ((1 - a) * grid[jy, ix] + a * grid[jy, jx])).astype(np.float32)

    def fbm(self, base: int, octaves: int, stretch=(1, 1)):
        total = np.zeros_like(self.u)
        weight, norm = 1.0, 0.0
        for i in range(octaves):
            f = base * 2 ** i
            total += weight * (self.noise(max(1, f * stretch[0]), max(1, f * stretch[1])) - .5)
            norm += weight
            weight *= .55
        return total / norm


def smooth(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def cells(f: Field, cols: int, rows: int, jitter=.75):
    """Periodic Voronoi: distance to nearest/second site and a per-cell random."""
    gx, gy = f.u * cols, f.v * rows
    ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    sites = f.rng.random((rows, cols, 3), dtype=np.float32)
    first = np.full_like(f.u, 100.0)
    second = np.full_like(f.u, 100.0)
    ident = np.zeros_like(f.u)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = ix + dx, iy + dy
            s = sites[cy % rows, cx % cols]
            d = (gx - cx - (.5 - jitter / 2) - jitter * s[:, :, 0]) ** 2 + (gy - cy - (.5 - jitter / 2) - jitter * s[:, :, 1]) ** 2
            closer = d < first
            second = np.where(closer, first, np.minimum(second, d))
            first = np.where(closer, d, first)
            ident = np.where(closer, s[:, :, 2], ident)
    return np.sqrt(first), np.sqrt(second), ident


def surface(name: str, size: int):
    metres, color, roughness, metallic, seed = MATERIALS[name]
    f = Field(size, seed)
    u, v = f.u, f.v
    tone = np.zeros_like(u)       # relative albedo change
    height = np.zeros_like(u)     # metres
    rough = np.full_like(u, roughness)
    metal = np.full_like(u, metallic)
    tint = np.zeros((size, size, 3), dtype=np.float32)  # additive colour shift
    emission = None
    macro = f.fbm(2, 3)
    fine = f.fbm(16, 3)
    if name in ("oak", "wood_rough"):
        # Grain runs along U; UVs put U along each board's length.
        warp = f.fbm(2, 2, (1, 3))
        fibres = f.noise(7, 160) - .5
        coarse = name == "wood_rough"
        rings = np.sin(2 * np.pi * (v * (9 if coarse else 13) + 2.2 * warp + .35 * macro))
        late = np.clip(rings, 0, 1) ** (3 if coarse else 4)
        pores = smooth(.72, .95, f.noise(41, 330)) * (0.9 if not coarse else 0.5)
        tone += .20 * fibres + .16 * rings * (.6 if coarse else 1) - .22 * late - .14 * pores + .18 * macro
        height += .0011 * fibres + .0006 * rings - .0007 * pores
        rough += .10 * pores + .08 * (fine) + (.06 * late if not coarse else 0)
        if coarse:
            # Seasoning checks: short dark splits along the grain.
            checks = (1 - smooth(.004, .018, np.abs(f.noise(3, 40) - .5))) * smooth(.62, .82, f.noise(9, 3))
            tone -= .45 * checks
            height -= .0025 * checks
            tint += np.stack([fibres * .02, fibres * .01, -fibres * .01], axis=2)
        else:
            tint += np.stack([.03 * macro, .0 * macro, -.03 * macro], axis=2)
    elif name == "wicker":
        rows, stakes = 12, 8
        row = np.floor(v * rows)
        phase = (np.floor(u * stakes) + row) % 2
        across = (v * rows) % 1.0
        rod = np.sin(np.pi * across) ** .6
        # Rods dip behind alternate stakes and swell in front of the others.
        weave = np.where(phase > 0, 1.0, .55) * (.6 + .4 * np.sin(np.pi * ((u * stakes) % 1.0)))
        stake_gap = smooth(.0, .06, np.minimum((u * stakes) % 1.0, 1 - (u * stakes) % 1.0))
        rod_id = f.rng.random((rows, stakes), dtype=np.float32)[row.astype(np.int32) % rows, np.floor(u * stakes).astype(np.int32) % stakes]
        tone += .30 * (rod * weave - .5) + .16 * (rod_id - .5) + .10 * (f.noise(5, 60) - .5) - .10 * (1 - stake_gap)
        height += .0045 * rod * weave
        rough += .08 * (1 - rod)
        tint += np.stack([.04 * (f.noise(3, 12) - .5)] * 3, axis=2)
    elif name == "straw":
        stalk = f.noise(3, 230)
        streak = f.noise(5, 90)
        node = smooth(.92, .98, f.noise(12, 230))
        tone += .38 * (stalk - .5) + .20 * (streak - .5) - .15 * node + .12 * macro
        height += .0022 * (stalk - .5) + .0012 * np.sin(2 * np.pi * v * 115)
        tint += np.stack([.02 * (streak - .5), .03 * (streak - .5), -.05 * (streak - .5)], axis=2)
    elif name in ("linen", "wool"):
        threads = 64 if name == "linen" else 40
        slub = f.noise(threads // 2, 3) - .5
        warp = np.cos(2 * np.pi * (u * threads + .25 * slub))
        weft = np.cos(2 * np.pi * (v * threads + .2 * (f.noise(3, threads // 2) - .5)))
        if name == "wool":
            # 2/2 twill diagonal plus fibre fuzz.
            diag = np.cos(2 * np.pi * ((u + v) * threads / 2))
            weave = .5 * warp * weft + .5 * diag
            fuzz = f.noise(180, 180) - .5
            tone += .13 * weave + .12 * fuzz + .10 * macro
            height += .0005 * weave + .0002 * fuzz
        else:
            weave = warp * weft
            tone += .11 * weave + .06 * (warp + weft) * .5 + .05 * slub + .08 * macro
            height += .00035 * weave
        rough += .03 * weave
    elif name == "leather":
        d1, d2, ident = cells(f, 34, 34, .9)
        pebble = smooth(.0, .32, d2 - d1)
        crease = (1 - smooth(.002, .009, np.abs(f.fbm(3, 2)))) * .35
        tone += .10 * (pebble - .5) + .22 * macro - .25 * crease + .06 * (ident - .5)
        height += .0004 * pebble - .0008 * crease
        rough += .14 * (1 - pebble) + .10 * crease + .10 * macro
    elif name in ("terracotta", "coarseware"):
        rings = np.sin(2 * np.pi * (v * (38 if name == "terracotta" else 22) + .2 * macro))
        grit = smooth(.80, .97, f.noise(140, 140))
        specks = smooth(.86, .99, f.noise(90, 90))
        tone += .05 * rings + .16 * macro + .10 * fine - .18 * grit + (.22 * specks if name == "terracotta" else -.10 * specks)
        height += .00045 * rings + .0006 * grit
        rough += .06 * grit
        if name == "coarseware":
            soot = smooth(.0, .35, f.fbm(2, 3) + .05)
            tone -= .35 * soot
            rough += .05 * soot
        else:
            tint += np.stack([.05 * macro, -.02 * macro, -.04 * macro], axis=2)
    elif name in ("iron", "bronze"):
        d1, d2, ident = cells(f, 12, 12, .9)
        dents = smooth(.0, .55, d1) * .6
        corrosion = smooth(.05, .30, f.fbm(3, 4) + .08 * (f.noise(60, 60) - .5))
        tone += .12 * macro + .05 * (ident - .5) - .05 * dents
        height += -.0006 * (1 - dents) + .0004 * corrosion
        if name == "iron":
            rust = corrosion
            tint += np.stack([.20 * rust, .02 * rust, -.10 * rust], axis=2)
            rough += .28 * rust + .05 * dents
            metal -= .55 * rust
        else:
            patina = corrosion
            tint += np.stack([-.22 * patina, .02 * patina, .02 * patina], axis=2)
            rough += .35 * patina
            metal -= .6 * patina
    elif name == "stone":
        d1, d2, ident = cells(f, 7, 7, .8)
        pores = smooth(.78, .97, f.noise(120, 120))
        seams = (1 - smooth(.0, .025, d2 - d1)) * smooth(.45, .7, f.noise(5, 5))
        tone += .14 * macro + .10 * fine - .20 * pores + .07 * (ident - .5) - .12 * seams
        height += .0015 * fine - .0012 * pores
        rough += .05 * pores
    elif name == "food":
        d1, d2, ident = cells(f, 26, 26, .9)
        crumb = smooth(.0, .25, d1)
        blister = smooth(.75, .95, f.noise(20, 20))
        tone += .18 * macro + .12 * (crumb - .5) - .12 * blister + .06 * fine
        height += .0012 * crumb - .0008 * blister
        rough -= .1 * blister
    elif name == "hearth_clay":
        d1, d2, ident = cells(f, 6, 6, .9)
        crack = (1 - smooth(.0, .018, d2 - d1)) * smooth(.35, .65, f.noise(4, 4))
        ash = smooth(.05, .3, f.fbm(2, 3))
        soot = smooth(.0, .4, -f.fbm(3, 2))
        tone += .12 * fine + .35 * ash - .35 * soot - .45 * crack + .05 * (ident - .5)
        height += -.002 * crack + .0006 * fine
        tint += np.stack([-.02 * ash, -.02 * ash, .0 * ash], axis=2)
    elif name == "embers":
        d1, d2, ident = cells(f, 9, 9, .9)
        edge = 1 - smooth(.0, .09, d2 - d1)
        ash = smooth(.0, .30, f.fbm(2, 3) + .1 * (ident - .5))
        heat = np.clip(edge * smooth(.15, .55, ident + .2 * macro) + .45 * smooth(.25, .5, -f.fbm(3, 2)) * (1 - ash), 0, 1)
        tone += 1.5 * ash + .3 * fine
        height += -.002 * edge + .0012 * (1 - edge)
        emission = np.stack([heat * 1.0, heat ** 1.6 * .42, heat ** 3 * .10], axis=2)
    base = np.asarray(color, dtype=np.float32)
    srgb = np.clip(base[None, None, :] * (1 + tone[:, :, None]) + tint, .01, .985)
    # Tangent-space normals from the height field; +Y up (OpenGL convention).
    texel = metres / size
    dhdu = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / (2 * texel)
    dhdv = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) / (2 * texel)
    normal = np.stack((-dhdu, dhdv, np.ones_like(height)), axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    blur = (np.roll(height, 3, 0) + np.roll(height, -3, 0) + np.roll(height, 3, 1) + np.roll(height, -3, 1)) / 4
    occlusion = np.clip(1 - 140 * np.clip(blur - height, 0, None) / max(1e-6, metres * 4), .55, 1)
    orm = np.stack((occlusion, np.clip(rough, .12, .99), np.clip(metal, 0, 1)), axis=2)
    return srgb, normal * .5 + .5, orm, emission


def save(path: Path, data):
    Image.fromarray(np.clip(np.round(data * 255), 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/interiors/textures/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=512, choices=(256, 512, 1024))
    parser.add_argument("--out", type=Path, default=ROOT / "prototype/assets/interiors/textures")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = {"size": args.size, "materials": {}}
    for name in MATERIALS:
        albedo, normal, orm, emission = surface(name, args.size)
        maps = {"albedo": albedo, "normal": normal, "orm": orm}
        if emission is not None:
            maps["emission"] = emission
        for kind, data in maps.items():
            filename = f"{name}_{kind}.png"
            save(args.out / filename, data)
            import_path = args.out / (filename + ".import")
            if not import_path.exists():
                import_path.write_text(IMPORT.format(name=filename, normal=1 if kind == "normal" else 2))
        manifest["materials"][name] = {"tile_metres": MATERIALS[name][0], "roughness": MATERIALS[name][2],
                                       "metallic": MATERIALS[name][3], "maps": sorted(maps)}
        print(name, "mean albedo", np.round(albedo.mean(axis=(0, 1)), 3).tolist())
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")


if __name__ == "__main__":
    main()
