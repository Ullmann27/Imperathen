"""Tessellate the analytic youth tunic into UV-mapped LOD meshes."""
from __future__ import annotations

import numpy as np

from youth_civil_shape import (BELT_HALF_HEIGHT, BELT_Y, HEM_Y, SHOULDER_RING_Y,
                               SLEEVE_HEM_T, SLEEVE_START_T, Garment)

# Texture atlas layout (u0, v0, u1, v1), glTF UV convention (v down). Region
# sizes follow the real surface extents so the weave keeps one density.
ATLAS = {
    "skirt": (0.0, 0.0, 1.0, 0.30),
    "torso": (0.0, 0.31, 1.0, 0.71),
    "sleeve_L": (0.0, 0.73, 0.48, 0.86),
    "sleeve_R": (0.52, 0.73, 1.0, 0.86),
    "belt": (0.0, 0.88, 1.0, 0.94),
}
PART_KIND = {"skirt": 1, "torso": 2, "sleeve_L": 3, "sleeve_R": 4, "belt": 5}
# (columns around the body, rows per metre of height) per LOD.
DENSITY = {0: (80, 92), 1: (56, 60), 2: (30, 32), 3: (16, 15)}


def _grid(points, uv):
    rows, cols = points.shape[:2]
    idx = np.arange(rows * cols).reshape(rows, cols)
    a, b, c, d = idx[:-1, :-1], idx[:-1, 1:], idx[1:, :-1], idx[1:, 1:]
    faces = np.stack([a, c, b, b, c, d], -1).reshape(-1, 3)
    return points.reshape(-1, 3), uv.reshape(-1, 2), faces


def _uv(region, cols, rows, v_values):
    u0, v0, u1, v1 = ATLAS[region]
    u = np.linspace(u0, u1, cols)
    v = v0 + (v1 - v0) * np.asarray(v_values, float)
    return np.stack(np.broadcast_arrays(u[None, :], v[:, None]), -1)


def tessellate(g: Garment, level: int):
    """Return vertices, uvs, faces, part kind per vertex and the parametric
    coordinates (theta or phi, height or t) used for texturing."""
    cols, per_m = DENSITY[level]
    folds = level <= 2
    # Wrap seam at the back centre, so the front of the tunic is seamless.
    theta = np.pi + np.linspace(0, 2 * np.pi, cols + 1)
    out = []

    def add(name, points, uv, param):
        v, t, f = _grid(points, uv)
        out.append((name, v, t, f, param.reshape(-1, 2)))

    # Skirt: inner hem turn-up -> hem -> belt.
    ys = np.linspace(HEM_Y, BELT_Y, max(4, int((BELT_Y - HEM_Y) * per_m)) + 1)
    rows = [g.tube_point(theta, np.full_like(theta, y), folds) for y in ys]
    heights = list(ys)
    if level <= 2:
        r, (cx, cz) = g.tube_radius(theta, np.full_like(theta, HEM_Y), folds)
        inner = []
        for dy, dr in ((0.016, -0.0065), (0.002, -0.0058)):
            inner.append(np.stack([cx + (r + dr) * np.sin(theta), np.full_like(theta, HEM_Y + dy),
                                   cz + (r + dr) * np.cos(theta)], -1))
        rows = inner + rows
        heights = [HEM_Y - 0.016, HEM_Y - 0.002] + heights
    rows = np.array(rows)
    param = np.stack(np.broadcast_arrays(theta[None, :], np.array(heights)[:, None]), -1)
    add("skirt", rows, _uv("skirt", cols + 1, len(rows), np.linspace(1, 0, len(rows))), param)

    # Torso: belt -> shoulder ring -> yoke -> neckline -> neckband turned in.
    ys = np.linspace(BELT_Y, SHOULDER_RING_Y, max(4, int((SHOULDER_RING_Y - BELT_Y) * per_m)) + 1)
    rows = [g.tube_point(theta, np.full_like(theta, y), folds) for y in ys]
    heights = list(ys)
    cap = max(3, int(0.14 * per_m))
    for k, s in enumerate(np.linspace(0, 1, cap + 1)[1:]):
        rows.append(g.shoulder_cap(theta, np.full_like(theta, s)))
        heights.append(SHOULDER_RING_Y + 0.12 * s)
    c = 0.5 * (g.rig["Neck"] + g.rig["Head"])
    edge = rows[-1].copy()
    d = edge - np.array([c[0], 0, c[2]])
    d[:, 1] = 0
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    rows.append(edge - 0.0055 * d - np.array([0, 0.009, 0]))
    heights.append(heights[-1] + 0.01)
    rows = np.array(rows)
    param = np.stack(np.broadcast_arrays(theta[None, :], np.array(heights)[:, None]), -1)
    add("torso", rows, _uv("torso", cols + 1, len(rows), np.linspace(1, 0, len(rows))), param)

    # Sleeves along the upper arm, with a turned hem.
    scol = max(10, (cols * 2) // 5)
    phi = np.linspace(0, 2 * np.pi, scol + 1)
    for side in "LR":
        a, b, axis, _, _ = g.sleeve_axis(side)
        length = np.linalg.norm(b - a) * (SLEEVE_HEM_T - SLEEVE_START_T)
        ts = list(np.linspace(SLEEVE_START_T, SLEEVE_HEM_T, max(3, int(length * per_m * 1.3)) + 1))
        rows = [g.sleeve_point(side, np.full_like(phi, t), phi, folds) for t in ts]
        # Shoulder dome above the joint; its small pole opening lies under the yoke.
        alphas = np.linspace(0.16, np.pi / 2, max(2, int(0.075 * per_m)) + 1)[:-1]
        rows = [g.sleeve_dome(side, np.full_like(phi, al), phi) for al in alphas] + rows
        ts = [SLEEVE_START_T - 0.25 * (1 - al / (np.pi / 2)) for al in alphas] + ts
        if level <= 2:
            centre = a + (b - a) * SLEEVE_HEM_T
            hem = rows[-1]
            radial = (hem - centre) / np.linalg.norm(hem - centre, axis=1, keepdims=True)
            rows.append(hem - 0.0055 * radial - 0.002 * axis)
            rows.append(hem - 0.0062 * radial - 0.016 * axis)
            ts += [SLEEVE_HEM_T + 0.01, SLEEVE_HEM_T + 0.02]
        rows = np.array(rows)
        param = np.stack(np.broadcast_arrays(phi[None, :], np.array(ts)[:, None]), -1)
        add("sleeve_" + side, rows, _uv("sleeve_" + side, scol + 1, len(rows), np.linspace(0, 1, len(rows))), param)

    # Belt: a narrow leather strap with rolled edges.
    rows = []
    base, _ = g.tube_radius(theta, np.full_like(theta, BELT_Y), folds=False)
    for dy, dr in ((-BELT_HALF_HEIGHT - 0.0006, 0.0006), (-BELT_HALF_HEIGHT, 0.0042),
                   (BELT_HALF_HEIGHT, 0.0042), (BELT_HALF_HEIGHT + 0.0006, 0.0006)):
        y = np.full_like(theta, BELT_Y + dy)
        r, (cx, cz) = g.tube_radius(theta, y, folds=False)
        r = np.maximum(r, base) + dr
        rows.append(np.stack([cx + r * np.sin(theta), y, cz + r * np.cos(theta)], -1))
    rows = np.array(rows)
    param = np.stack(np.broadcast_arrays(theta[None, :], np.array([-1.0, -0.8, 0.8, 1.0])[:, None]), -1)
    add("belt", rows, _uv("belt", cols + 1, 4, [0.0, 0.12, 0.88, 1.0]), param)

    verts, uvs, faces, kinds, params = [], [], [], [], []
    base = 0
    for name, v, t, f, prm in out:
        verts.append(v); uvs.append(t); faces.append(f + base); params.append(prm)
        kinds.append(np.full(len(v), PART_KIND[name]))
        base += len(v)
    v = np.concatenate(verts); uv = np.concatenate(uvs); f = np.concatenate(faces)
    kind = np.concatenate(kinds); param = np.concatenate(params)
    return v, uv, _orient(g, v, f, kind), kind, param


def _orient(g, v, f, kind):
    """Wind every face so its normal points away from the body."""
    t = v[f]
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    cen = t.mean(1)
    fk = kind[f[:, 0]]
    _, _, cc = g.radial(cen)
    ref = np.stack([cc[:, 0], cen[:, 1], cc[:, 1]], -1)
    yoke = (fk == 2) & (cen[:, 1] > SHOULDER_RING_Y)
    ref[yoke, 1] -= 0.15
    for side, k in (("L", 3), ("R", 4)):
        a, b, axis, _, _ = g.sleeve_axis(side)
        m = fk == k
        ref[m] = a + np.outer(np.maximum((cen[m] - a) @ axis, 0.0), axis)
    flip = (n * (cen - ref)).sum(1) < 0
    f = f.copy()
    f[flip] = f[flip][:, [0, 2, 1]]
    return f
