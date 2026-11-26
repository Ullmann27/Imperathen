"""Original, seeded PBR maps for the Valdora look (no external sources).

Writes prototype/assets/village/look/:
  lime_plaster_albedo.png   sRGB, near-neutral lime; tinted per house in the shader
  lime_plaster_normal.png   tangent space, OpenGL +Y
  lime_plaster_mask.png     R roughness, G cavity, B tileable macro variation
  wear_detail_albedo.png    grey multiplier (mean ~0.94) for flat prop materials
  wear_detail_normal.png    fine dents, scratches and grain for the same props
  meadow_sod_color.png      sRGB turf: blades, dry strands, clover, soil gaps
  meadow_sod_relief.png     ground.gdshader relief layout: RG normal, B roughness
  trodden_earth_color.png   sRGB compacted lane earth: grit, pebbles, prints, damp hollows
  trodden_earth_relief.png  same relief layout as the sod
All maps tile seamlessly. Plaster 2 m, wear 0.75 m, sod 3.2 m, earth 2.4 m per tile.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "prototype/assets/village/look"


def value_noise(size, cells, rng, rows=None):
    """Periodic smooth value noise; `cells` lattice columns and `rows` lattice rows."""
    rows = rows or cells
    grid = rng.random((rows, cells), dtype=np.float32)
    def axis(n):
        coords = (np.arange(size, dtype=np.float32) + .5) * n / size
        i = np.floor(coords).astype(np.int32)
        f = coords - i
        return i % n, (i + 1) % n, f * f * (3 - 2 * f)
    x0, x1, fx = axis(cells)
    y0, y1, fy = axis(rows)
    a = grid[np.ix_(y0, x0)] * (1 - fx)[None, :] + grid[np.ix_(y0, x1)] * fx[None, :]
    b = grid[np.ix_(y1, x0)] * (1 - fx)[None, :] + grid[np.ix_(y1, x1)] * fx[None, :]
    return a * (1 - fy)[:, None] + b * fy[:, None]


def fbm(size, base, octaves, rng, gain=.5):
    total = np.zeros((size, size), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * value_noise(size, base * 2 ** o, rng)
        norm += amp
        amp *= gain
    return total / norm


def blur(field, radius):
    """Periodic box blur applied three times (close to Gaussian)."""
    out = field
    for _ in range(3):
        acc = np.zeros_like(out)
        for d in range(-radius, radius + 1):
            acc += np.roll(out, d, axis=0)
        out = acc / (2 * radius + 1)
        acc = np.zeros_like(out)
        for d in range(-radius, radius + 1):
            acc += np.roll(out, d, axis=1)
        out = acc / (2 * radius + 1)
    return out


def wrapped_delta(a, b):
    d = a - b
    return d - np.round(d)


def smooth(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def voronoi(size, cells, rng, jitter=.8):
    """Periodic Voronoi: distance to nearest and second nearest site, and the site id."""
    u = (np.arange(size, dtype=np.float32) + .5) / size
    U, V = np.meshgrid(u, u)
    n = cells * cells
    px = ((np.arange(n) % cells) + .5 + jitter * (rng.random(n) - .5)) / cells
    py = ((np.arange(n) // cells) + .5 + jitter * (rng.random(n) - .5)) / cells
    first = np.full((size, size), 9.0, np.float32)
    second = np.full((size, size), 9.0, np.float32)
    ident = np.zeros((size, size), np.int32)
    for k in range(n):
        d = np.hypot(wrapped_delta(U, px[k]), wrapped_delta(V, py[k]))
        closer = d < first
        second = np.where(closer, first, np.minimum(second, d))
        ident = np.where(closer, k, ident)
        first = np.minimum(first, d)
    return first * cells, second * cells, ident


def normals_from_height(height, metres_per_pixel, strength=1.0):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / (2 * metres_per_pixel)
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) / (2 * metres_per_pixel)
    # Image rows grow downward; OpenGL normal maps expect +Y up the texture.
    n = np.stack((-dx * strength, dy * strength, np.ones_like(height)), axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * .5 + .5


def to_srgb8(linear):
    linear = np.clip(linear, 0, 1)
    srgb = np.where(linear <= .0031308, linear * 12.92, 1.055 * np.power(linear, 1 / 2.4) - .055)
    return (srgb * 255 + .5).astype(np.uint8)


def to_u8(data):
    return (np.clip(data, 0, 1) * 255 + .5).astype(np.uint8)


def lime_plaster(size, seed):
    rng = np.random.default_rng(seed)
    metres = 2.0
    mpp = metres / size
    u = (np.arange(size, dtype=np.float32) + .5) / size
    U, V = np.meshgrid(u, u)
    height = np.zeros((size, size), np.float32)
    tone = np.zeros((size, size), np.float32)
    # Overlapping trowel passes: soft-edged, mostly horizontal swept patches. A
    # later pass covers an earlier one and leaves a slight ridge at its edge.
    for _ in range(260):
        cx, cy = rng.random(2)
        angle = rng.normal(0, .45)
        length = rng.uniform(.10, .26)
        width = rng.uniform(.035, .085)
        dx, dy = wrapped_delta(U, cx), wrapped_delta(V, cy)
        along = dx * np.cos(angle) + dy * np.sin(angle)
        across = -dx * np.sin(angle) + dy * np.cos(angle)
        curve = across - .9 * along * along / max(length, .05)
        r = np.sqrt((along / length) ** 2 + (curve / width) ** 2)
        mask = 1 - smooth(.72, 1.0, r)
        if mask.max() < .01:
            continue
        level = rng.normal(0, .00045)
        ridge = np.exp(-((r - .93) / .05) ** 2) * .00035
        height = height * (1 - mask) + (level + height * .35) * mask + ridge
        tone = tone * (1 - mask) + rng.normal(0, .022) * mask
    sand = fbm(size, 96, 3, rng) - .5
    grain = rng.random((size, size), dtype=np.float32) - .5
    height += .00055 * sand + .00012 * grain
    macro = fbm(size, 3, 4, rng)
    mottling = fbm(size, 8, 4, rng) - .5
    # Sparse hairline cracks follow Voronoi cell borders in a few regions only.
    first, second, _ = voronoi(size, 7, rng)
    crack_line = 1 - smooth(.0, .022, second - first)
    crack_zone = smooth(.56, .70, fbm(size, 5, 3, rng))
    cracks = crack_line * crack_zone
    height -= .0011 * cracks
    # Small pits and a few spalled patches that show the rubble core.
    pits = smooth(.80, .92, fbm(size, 48, 2, rng)) * .6
    height -= .0005 * pits
    spall_field = fbm(size, 6, 5, rng)
    spall = smooth(.776, .792, spall_field)
    sf, ss, sid = voronoi(size, 15, rng, .9)
    stone_face = smooth(.05, .22, ss - sf)
    stone_tone = rng.random(15 * 15)[sid]
    rubble_height = -.0035 + .0026 * stone_face + .0004 * sand
    height = height * (1 - spall) + rubble_height * spall
    plaster_rgb = np.array([.80, .755, .665], np.float32)
    # Rain and lime-wash runs: long in V, narrow in U, gathered in a few bands.
    runs = (value_noise(size, 46, rng, 3) * .65 + value_noise(size, 90, rng, 5) * .35) * smooth(.35, .75, value_noise(size, 4, rng, 2))
    rgb = plaster_rgb[None, None, :] * (1 + .075 * mottling[:, :, None] + tone[:, :, None] + .05 * (macro[:, :, None] - .5)
                                         + .022 * sand[:, :, None] - .10 * runs[:, :, None] * np.array([1.0, 1.05, 1.18])[None, None, :])
    rgb *= (1 - .22 * cracks - .10 * pits)[:, :, None]
    mortar = np.array([.46, .41, .33], np.float32)
    stone = np.array([.40, .37, .31], np.float32)[None, None, :] * (.78 + .42 * stone_tone[:, :, None])
    rubble = mortar[None, None, :] * (1 - stone_face[:, :, None]) + stone * stone_face[:, :, None]
    rubble *= (.92 + .16 * sand[:, :, None])
    edge = np.clip(smooth(.764, .776, spall_field) - spall, 0, 1)
    rgb = rgb * (1 - spall[:, :, None]) + rubble * spall[:, :, None]
    rgb *= (1 - .18 * edge)[:, :, None]
    rough = .90 + .05 * sand + .04 * cracks - .03 * (tone / .022).clip(-1, 1) * .5 + .02 * spall
    cavity = 1 - np.clip((blur(height, 6) - height) * 900, 0, .65)
    normal = normals_from_height(height, mpp, 1.0)
    mask = np.stack((np.clip(rough, .55, 1), cavity, macro), axis=2)
    return rgb, normal, mask


def wear_detail(size, seed):
    rng = np.random.default_rng(seed)
    mpp = 1.0 / size
    blotch = fbm(size, 4, 4, rng)
    mid = fbm(size, 16, 3, rng)
    fine = fbm(size, 64, 2, rng)
    grain = rng.random((size, size), dtype=np.float32)
    u = (np.arange(size, dtype=np.float32) + .5) / size
    U, V = np.meshgrid(u, u)
    scratches = np.zeros((size, size), np.float32)
    for _ in range(70):
        cx, cy = rng.random(2)
        angle = rng.uniform(0, np.pi)
        length = rng.uniform(.04, .16)
        dx, dy = wrapped_delta(U, cx), wrapped_delta(V, cy)
        along = dx * np.cos(angle) + dy * np.sin(angle)
        across = -dx * np.sin(angle) + dy * np.cos(angle)
        line = np.exp(-(across / .0016) ** 2) * (1 - smooth(.7, 1.0, np.abs(along) / length))
        scratches = np.maximum(scratches, line * rng.uniform(.4, 1))
    dents = smooth(.74, .9, fine)
    height = .0008 * (mid - .5) + .00025 * (fine - .5) + .00006 * (grain - .5) - .00025 * scratches - .0003 * dents
    # Mostly ~0.94 so it can multiply any flat prop colour without re-balancing it.
    albedo = .955 + .05 * (blotch - .5) + .04 * (mid - .5) + .02 * (grain - .5) - .07 * dents - .06 * scratches
    normal = normals_from_height(height, mpp, 1.0)
    return np.clip(albedo, 0, 1), normal


def meadow_sod(size, seed):
    """Turf seen from above, drawn as thousands of short wrapped blade strokes."""
    from PIL import ImageDraw
    rng = np.random.default_rng(seed)
    zones = fbm(size, 4, 4, rng)
    dryness = fbm(size, 7, 3, rng)
    soil = np.stack([fbm(size, 40, 3, rng)] * 3, axis=2) * np.array([30, 26, 16]) + np.array([58, 50, 32])
    color = Image.fromarray(np.clip(soil, 0, 255).astype(np.uint8), "RGB")
    relief = Image.fromarray(np.uint8(np.clip(fbm(size, 40, 3, rng) * 60 + 40, 0, 255)), "L")
    paint, bump = ImageDraw.Draw(color), ImageDraw.Draw(relief)
    greens = np.array([[78, 92, 44], [96, 108, 52], [118, 124, 60], [70, 84, 40], [104, 116, 58]])
    straw = np.array([[150, 136, 80], [128, 116, 70], [168, 150, 96]])
    def stroke(points, fill, height, width=1):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                shifted = [(int(px + ox), int(py + oy)) for px, py in points]
                paint.line(shifted, fill=fill, width=width)
                bump.line(shifted, fill=height, width=width)
    scale = size / 512
    for i in range(int(26000 * scale * scale)):
        x, y = rng.uniform(0, size, 2)
        zone = zones[int(y) % size, int(x) % size]
        dry = dryness[int(y) % size, int(x) % size]
        angle = rng.uniform(0, np.tau if hasattr(np, "tau") else 2 * np.pi)
        length = rng.uniform(3, 11) * scale
        bend = rng.uniform(-.6, .6)
        mid = (x + np.cos(angle) * length * .5 - np.sin(angle) * bend * 2, y + np.sin(angle) * length * .5 + np.cos(angle) * bend * 2)
        end = (x + np.cos(angle + bend * .4) * length, y + np.sin(angle + bend * .4) * length)
        if rng.random() < .10 + .35 * smooth(.55, .8, dry):
            rgb = straw[rng.integers(0, len(straw))] + rng.integers(-14, 15)
        else:
            rgb = greens[rng.integers(0, len(greens))] * (.82 + .3 * zone) + rng.integers(-10, 11)
        stroke([(x, y), mid, end], tuple(int(c) for c in np.clip(rgb, 0, 255)), int(120 + rng.integers(0, 90)), 1 if rng.random() < .7 else 2)
    for _ in range(int(260 * scale * scale)):
        # Clover and plantain rosettes.
        x, y = rng.uniform(0, size, 2)
        rgb = tuple(int(c) for c in np.array([66, 86, 38]) + rng.integers(-8, 9))
        for k in range(3 + int(rng.integers(0, 3))):
            a = rng.uniform(0, 2 * np.pi)
            r = rng.uniform(2.2, 3.6) * scale
            cx, cy = x + np.cos(a) * r, y + np.sin(a) * r
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    box = [cx - r * .7 + ox, cy - r * .7 + oy, cx + r * .7 + ox, cy + r * .7 + oy]
                    paint.ellipse(box, fill=rgb)
                    bump.ellipse(box, fill=150)
    for _ in range(int(90 * scale * scale)):
        # A few small, dark field stones; no bright speckles.
        x, y = rng.uniform(0, size, 2)
        r = rng.uniform(1.0, 2.6) * scale
        rgb = tuple(int(c) for c in np.array([104, 98, 82]) + rng.integers(-16, 12))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                box = [x - r + ox, y - r * .7 + oy, x + r + ox, y + r * .7 + oy]
                paint.ellipse(box, fill=rgb)
                bump.ellipse(box, fill=200)
    rgb = np.asarray(color, np.float32)
    rgb *= (.9 + .2 * zones)[:, :, None] * np.array([1.08, 1.0, 1.18])[None, None, :]
    h = blur(np.asarray(relief, np.float32) / 255, 1)
    normal = normals_from_height(h * .004, 3.2 / size)
    rough = np.clip(.93 - .05 * h + .03 * (dryness - .5), .6, 1)
    packed = np.stack((normal[:, :, 0], normal[:, :, 1], rough), axis=2)
    return np.clip(rgb, 0, 255).astype(np.uint8), to_u8(packed)


def trodden_earth(size, seed):
    """Compacted village lane: grit, pebbles, foot and hoof prints, damp hollows."""
    from PIL import ImageDraw
    rng = np.random.default_rng(seed)
    macro = fbm(size, 4, 4, rng)
    mid = fbm(size, 18, 3, rng)
    fine = fbm(size, 90, 2, rng)
    grit = rng.random((size, size), dtype=np.float32)
    damp = smooth(.56, .74, fbm(size, 5, 4, rng))
    height = .35 * mid + .12 * fine + .05 * grit
    soil_light = np.array([156, 128, 92], np.float32)
    soil_dark = np.array([100, 80, 57], np.float32)
    mixer = np.clip(.5 + 1.4 * (macro - .5) + .6 * (mid - .5), 0, 1)
    rgb = soil_dark[None, None, :] * (1 - mixer[:, :, None]) + soil_light[None, None, :] * mixer[:, :, None]
    rgb *= (.92 + .16 * fine + .06 * (grit - .5))[:, :, None]
    rgb *= (1 - .28 * damp)[:, :, None]
    color = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    relief = Image.fromarray(np.uint8(np.clip(height * 255, 0, 255)), "L")
    paint, bump = ImageDraw.Draw(color), ImageDraw.Draw(relief)
    scale = size / 512
    def wrapped(draw, shape, box, **kw):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                b = [box[0] + ox, box[1] + oy, box[2] + ox, box[3] + oy]
                getattr(draw, shape)(b, **kw)
    for _ in range(int(60 * scale * scale)):
        # Foot and hoof prints: shallow, barely darker ovals.
        x, y = rng.uniform(0, size, 2)
        w, h = rng.uniform(2.5, 4.5) * scale, rng.uniform(4, 7) * scale
        local = rgb[int(y) % size, int(x) % size]
        tone = tuple(int(c) for c in np.clip(local * .9, 0, 255))
        wrapped(paint, "ellipse", [x - w, y - h, x + w, y + h], fill=tone)
        wrapped(bump, "ellipse", [x - w, y - h, x + w, y + h], fill=int(40 + rng.integers(0, 30)))
    for _ in range(int(900 * scale * scale)):
        # Pebbles and grit in warm greys, lighter on top.
        x, y = rng.uniform(0, size, 2)
        r = rng.choice([.6, .9, 1.3, 2.0, 3.0], p=[.45, .3, .15, .07, .03]) * scale
        base = np.array([138, 124, 102]) + rng.integers(-30, 26)
        wrapped(paint, "ellipse", [x - r, y - r * .8, x + r, y + r * .8], fill=tuple(int(c) for c in base))
        wrapped(paint, "ellipse", [x - r * .5, y - r * .6, x + r * .3, y], fill=tuple(int(c) for c in np.clip(base + 18, 0, 255)))
        wrapped(bump, "ellipse", [x - r, y - r * .8, x + r, y + r * .8], fill=int(170 + rng.integers(0, 70)))
    for _ in range(int(120 * scale * scale)):
        # A few trodden straw bits.
        x, y = rng.uniform(0, size, 2)
        a = rng.uniform(0, 2 * np.pi)
        l = rng.uniform(4, 10) * scale
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                pts = [(x + ox, y + oy), (x + ox + np.cos(a) * l, y + oy + np.sin(a) * l)]
                paint.line(pts, fill=(158, 136, 86), width=1)
                bump.line(pts, fill=150, width=1)
    rgb = np.asarray(color, np.float32)
    h = blur(np.asarray(relief, np.float32) / 255, 1)
    normal = normals_from_height(h * .006, 2.4 / size)
    rough = np.clip(.9 - .14 * damp - .05 * (1 - mid) + .04 * grit, .55, 1)
    packed = np.stack((normal[:, :, 0], normal[:, :, 1], rough), axis=2)
    return np.clip(rgb, 0, 255).astype(np.uint8), to_u8(packed)


def save(folder, name, data, mode):
    folder.mkdir(parents=True, exist_ok=True)
    Image.fromarray(data, mode).save(folder / name, optimize=True)
    print("wrote", folder / name, data.shape)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    rgb, normal, mask = lime_plaster(args.size, 5821)
    save(args.out, "lime_plaster_albedo.png", to_srgb8(rgb), "RGB")
    save(args.out, "lime_plaster_normal.png", to_u8(normal), "RGB")
    save(args.out, "lime_plaster_mask.png", to_u8(mask), "RGB")
    albedo, normal = wear_detail(512, 7313)
    save(args.out, "wear_detail_albedo.png", to_srgb8(albedo), "L")
    save(args.out, "wear_detail_normal.png", to_u8(normal), "RGB")
    sod_color, sod_relief = meadow_sod(1024, 931)
    save(args.out, "meadow_sod_color.png", sod_color, "RGB")
    save(args.out, "meadow_sod_relief.png", sod_relief, "RGB")
    earth_color, earth_relief = trodden_earth(1024, 4421)
    save(args.out, "trodden_earth_color.png", earth_color, "RGB")
    save(args.out, "trodden_earth_relief.png", earth_relief, "RGB")


if __name__ == "__main__":
    main()
