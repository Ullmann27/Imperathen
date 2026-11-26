"""Procedural over-life-size statues and light fittings (flat local frame, z up, facing -y)."""
import math

VARIANTS = 4
MS = "marble_statue"


def tube(mb, p0, p1, r0, r1, seg, mat, ao=1.0):
    ax = [p1[i] - p0[i] for i in range(3)]
    ln = math.sqrt(sum(a * a for a in ax))
    ax = [a / ln for a in ax]
    ref = (0, 0, 1) if abs(ax[2]) < 0.9 else (1, 0, 0)
    u = [ax[1] * ref[2] - ax[2] * ref[1], ax[2] * ref[0] - ax[0] * ref[2], ax[0] * ref[1] - ax[1] * ref[0]]
    m = math.sqrt(sum(a * a for a in u))
    u = [a / m for a in u]
    v = [ax[1] * u[2] - ax[2] * u[1], ax[2] * u[0] - ax[0] * u[2], ax[0] * u[1] - ax[1] * u[0]]
    for i in range(seg):
        t0, t1 = math.tau * i / seg, math.tau * (i + 1) / seg
        d0 = [u[j] * math.cos(t0) + v[j] * math.sin(t0) for j in range(3)]
        d1 = [u[j] * math.cos(t1) + v[j] * math.sin(t1) for j in range(3)]
        q = [tuple(p0[j] + d0[j] * r0 for j in range(3)), tuple(p0[j] + d1[j] * r0 for j in range(3)),
             tuple(p1[j] + d1[j] * r1 for j in range(3)), tuple(p1[j] + d0[j] * r1 for j in range(3))]
        mb.face(q, mat, tuple((d0[j] + d1[j]) for j in range(3)), ao=ao, smooth=True)


def statue(mb, variant, pedestal=1.3, lod=0, mat=MS, scale=1.5):
    mb.level_z = -99
    mb.interior = 1.0
    seg = 6 if lod else 12
    z0 = pedestal
    if pedestal > 0:
        mb.box(-0.5, 0.5, -0.5, 0.5, 0.0, pedestal, "travertine", skip="z-")
        if not lod:
            mb.box(-0.56, 0.56, -0.56, 0.56, pedestal - 0.14, pedestal, "travertine", skip="z-")
            mb.box(-0.56, 0.56, -0.56, 0.56, 0.0, 0.16, "travertine", skip="z-")
    k = scale
    long_robe = variant in (0, 1, 3)
    hem = 0.25 if long_robe else 0.14
    body = [(0.0, 0.0), (hem, 0.0), (hem * 1.02, 0.25), (0.215, 0.62), (0.21, 0.92), (0.185, 1.08), (0.215, 1.27), (0.235, 1.40),
            (0.13, 1.47), (0.062, 1.50), (0.062, 1.56), (0.098, 1.60), (0.112, 1.68), (0.104, 1.76), (0.06, 1.82), (0.0, 1.835)]
    if lod:
        body = [body[i] for i in (0, 1, 3, 5, 7, 9, 11, 13, 15)]
    lean = 0.03 if variant % 2 else -0.03
    mb.lathe(lean * k, 0.0, [(r * k, z0 + z * k) for r, z in body], seg, mat, sx=1.0, sy=0.66)
    if not long_robe:   # legs under a short tunic / cuirass
        for sx in (-1, 1):
            tube(mb, (sx * 0.09 * k, 0, z0), (sx * 0.1 * k, 0, z0 + 0.5 * k), 0.06 * k, 0.085 * k, seg // 2 + 1, mat)
    sh = z0 + 1.38 * k
    arms = {
        0: (((-0.24, -0.02, 1.38), (-0.27, -0.06, 1.08), (-0.05, -0.2, 1.16)), ((0.24, 0, 1.38), (0.28, 0.0, 1.08), (0.27, -0.06, 0.82))),
        1: (((-0.24, 0, 1.38), (-0.42, -0.08, 1.5), (-0.5, -0.2, 1.78)), ((0.24, 0, 1.38), (0.27, -0.02, 1.08), (0.12, -0.18, 1.0))),
        2: (((-0.24, 0, 1.38), (-0.4, -0.05, 1.2), (-0.5, -0.1, 1.42)), ((0.24, 0, 1.38), (0.3, -0.05, 1.1), (0.3, -0.2, 1.05))),
        3: (((-0.24, 0, 1.38), (-0.3, -0.04, 1.1), (-0.2, -0.2, 1.2)), ((0.24, 0, 1.38), (0.36, -0.04, 1.14), (0.44, -0.16, 1.3))),
    }[variant]
    for arm in arms:
        pts = [(p[0] * k + lean * k, p[1] * k, z0 + p[2] * k) for p in arm]
        tube(mb, pts[0], pts[1], 0.075 * k, 0.06 * k, max(4, seg // 2), mat)
        tube(mb, pts[1], pts[2], 0.058 * k, 0.045 * k, max(4, seg // 2), mat)
        if not lod:
            mb.lathe(pts[2][0], pts[2][1], [(0.0, pts[2][2] - 0.06 * k), (0.05 * k, pts[2][2]), (0.0, pts[2][2] + 0.06 * k)], 5, mat)
    del sh
    if lod:
        return
    # drapery: diagonal sinus of the toga and vertical fold ridges
    if long_robe:
        for i in range(7):
            t = math.pi + (i + 0.5) * math.pi / 7
            c, s = math.cos(t), math.sin(t) * 0.66
            r0, r1 = hem * k * 1.03, 0.215 * k * 1.04
            mb.face([(lean * k + r0 * c - 0.03, r0 * s, z0 + 0.02), (lean * k + r0 * c + 0.03, r0 * s, z0 + 0.02),
                     (lean * k + r1 * c, r1 * s - 0.01, z0 + 0.9 * k)], mat, (c, s, 0.1), ao=0.88)
        for i in range(6):
            f0, f1 = i / 6, (i + 1) / 6
            p = lambda f, o: (lean * k + (-0.22 + 0.44 * f) * k, (-0.15 - 0.05 * math.sin(math.pi * f) - o) * k, z0 + (1.38 - 0.5 * f) * k)
            mb.quad(p(f0, 0), p(f1, 0), (p(f1, 0)[0], p(f1, 0.03)[1], p(f1, 0)[2] + 0.1 * k), (p(f0, 0)[0], p(f0, 0.03)[1], p(f0, 0)[2] + 0.1 * k),
                    mat, (0, -1, 0.2), ao=0.92)
    if variant == 2:
        # warrior: crested helmet, round shield and spear
        mb.lathe(lean * k, 0.0, [(0.118 * k, z0 + 1.70 * k), (0.12 * k, z0 + 1.78 * k), (0.07 * k, z0 + 1.86 * k), (0.0, z0 + 1.88 * k)], seg, mat)
        mb.box(lean * k - 0.02, lean * k + 0.02, -0.16 * k, 0.16 * k, z0 + 1.84 * k, z0 + 2.0 * k, mat)
        cx, cz = (-0.5 + lean) * k, z0 + 1.3 * k
        for i in range(10):
            t0, t1 = math.tau * i / 10, math.tau * (i + 1) / 10
            mb.face([(cx, -0.26 * k, cz), (cx + 0.34 * k * math.cos(t0), -0.2 * k, cz + 0.34 * k * math.sin(t0)),
                     (cx + 0.34 * k * math.cos(t1), -0.2 * k, cz + 0.34 * k * math.sin(t1))], mat, (0, -1, 0), smooth=True)
        tube(mb, ((0.3 + lean) * k, -0.2 * k, z0), ((0.3 + lean) * k, -0.2 * k, z0 + 2.25 * k), 0.018 * k, 0.018 * k, 4, "bronze")
        mb.lathe((0.3 + lean) * k, -0.2 * k, [(0.04 * k, z0 + 2.25 * k), (0.0, z0 + 2.45 * k)], 4, "bronze")
    elif variant == 1:
        # orator: scroll in the lowered hand, wreath
        mb.lathe(lean * k, 0.0, [(0.118 * k, z0 + 1.73 * k), (0.126 * k, z0 + 1.75 * k), (0.118 * k, z0 + 1.77 * k)], seg, mat)
    elif variant == 3:
        # goddess: diadem and cornucopia
        mb.lathe(lean * k, 0.0, [(0.11 * k, z0 + 1.74 * k), (0.12 * k, z0 + 1.80 * k), (0.09 * k, z0 + 1.80 * k)], seg, mat)
        tube(mb, ((0.44 + lean) * k, -0.16 * k, z0 + 1.2 * k), ((0.4 + lean) * k, -0.1 * k, z0 + 1.62 * k), 0.03 * k, 0.085 * k, 6, mat)


def torch_bracket(mb):
    """Iron wall bracket with a torch basket; mounted on a wall, pointing to -y."""
    mb.level_z = -99
    mb.interior = 1.0
    tube(mb, (0, 0, 0), (0, -0.42, 0.12), 0.022, 0.022, 4, "iron")
    tube(mb, (0, 0, -0.3), (0, -0.4, 0.08), 0.015, 0.015, 4, "iron")
    mb.lathe(0, -0.44, [(0.03, 0.02), (0.075, 0.1), (0.085, 0.3), (0.07, 0.3), (0.0, 0.14)], 7, "iron")
    tube(mb, (0, -0.44, 0.1), (0, -0.44, 0.5), 0.035, 0.05, 5, "wood_dark")


def brazier(mb):
    """Bronze tripod fire basin, about 1.2 m high."""
    mb.level_z = -99
    mb.interior = 1.0
    for i in range(3):
        t = math.tau * i / 3
        tube(mb, (0.36 * math.cos(t), 0.36 * math.sin(t), 0.0), (0.2 * math.cos(t), 0.2 * math.sin(t), 0.92), 0.025, 0.02, 5, "bronze")
    mb.lathe(0, 0, [(0.0, 0.84), (0.2, 0.86), (0.4, 1.0), (0.46, 1.16), (0.42, 1.16), (0.36, 1.04), (0.0, 0.98)], 12, "bronze")
    mb.lathe(0, 0, [(0.24, 0.42), (0.26, 0.45), (0.24, 0.48)], 10, "bronze")
