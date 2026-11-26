"""Facade bay modules of the amphitheatre: three arcade orders and the attic.

Every module is built in the flat bay frame (x across, y inward, z up from the
storey base) and instanced 80 times per storey by the runtime.
Dimensions: Platner-Ashby (piers 2.40 x 2.70 m, ground arches 4.20 x 7.05 m,
entablature 2.35 m; upper arches 6.45 / 6.40 m).  Bay width is scaled to the
elliptical perimeter used here.
"""
import math

import ring as R

W = R.NOMINAL_W
PIER = 2.40 * W / 6.60
HW = (W - PIER) / 2
TRAV = "travertine"
STOREY = (R.Z1, R.Z2 - R.Z1, R.Z3 - R.Z2, R.HEIGHT - R.Z3)


def _entablature(mb, z0, z1, lod, proud=0.42):
    h = z1 - z0
    if lod:
        prof = [(0, z0), (-proud, z0), (-proud, z0 + h * 0.62), (-proud - 0.55, z0 + h * 0.8), (-proud - 0.55, z1), (0, z1)]
    else:
        a, f, c = z0 + h * 0.30, z0 + h * 0.62, z1
        prof = [(0, z0), (-proud, z0), (-proud, z0 + h * 0.13), (-proud - 0.04, z0 + h * 0.13), (-proud - 0.04, a - 0.07),
                (-proud - 0.10, a - 0.05), (-proud - 0.10, a), (-proud - 0.02, a), (-proud - 0.02, f),
                (-proud - 0.08, f + 0.04), (-proud - 0.12, f + 0.12), (-proud - 0.30, f + 0.26), (-proud - 0.52, f + 0.30),
                (-proud - 0.52, c - 0.20), (-proud - 0.60, c - 0.14), (-proud - 0.66, c - 0.04), (-proud - 0.66, c), (0, c)]
    mb.extrude_x(prof, -W / 2, W / 2, TRAV)
    if not lod:
        # dentil course under the corona
        f = z0 + h * 0.62
        n = 22
        for i in range(n):
            x = -W / 2 + (i + 0.25) * W / n
            mb.box(x, x + W / n * 0.5, -proud - 0.20, -proud - 0.02, f + 0.02, f + 0.13, TRAV, skip="y+z+", ao=0.85)


def _column(mb, order, z0, z1, lod, pedestal=0.0):
    """Engaged half column centred on the left bay edge."""
    cx = -W / 2
    seg = 5 if lod else 12
    r = 0.44
    a0, a1 = math.pi, math.tau
    zb = z0 + pedestal
    if pedestal > 0:
        mb.box(cx - 0.62, cx + 0.62, -0.56, 0.0, z0, zb, TRAV, skip="y+z-")
        if not lod:
            mb.box(cx - 0.68, cx + 0.68, -0.62, 0.0, zb - 0.16, zb, TRAV, skip="y+")
            mb.box(cx - 0.68, cx + 0.68, -0.62, 0.0, z0, z0 + 0.22, TRAV, skip="y+z-")
    cap = 0.5 if order == 0 else (0.55 if order == 1 else 1.0)
    zc = z1 - cap
    if lod:
        mb.lathe(cx, 0, [(r, zb), (r * 0.86, zc), (r * 1.25, z1)], seg, TRAV, a0, a1)
        return
    mb.box(cx - 0.6, cx + 0.6, -0.6, 0.0, zb, zb + 0.16, TRAV, skip="y+z-")
    base = [(r * 1.28, zb + 0.16), (r * 1.30, zb + 0.24), (r * 1.18, zb + 0.30), (r * 1.20, zb + 0.36), (r * 1.04, zb + 0.44), (r, zb + 0.5)]
    shaft = [(r, zb + 0.5), (r * 0.995, zb + (zc - zb) * 0.35), (r * 0.94, zb + (zc - zb) * 0.7), (r * 0.86, zc - 0.12)]
    mb.lathe(cx, 0, base + shaft[1:], seg, TRAV, a0, a1)
    if order == 0:      # Tuscan
        mb.lathe(cx, 0, [(r * 0.86, zc - 0.12), (r * 0.92, zc - 0.10), (r * 0.92, zc - 0.04), (r * 0.86, zc), (r * 0.88, zc + 0.14),
                         (r * 1.20, zc + 0.30)], seg, TRAV, a0, a1)
        mb.box(cx - 0.58, cx + 0.58, -0.58, 0.0, zc + 0.30, z1, TRAV, skip="y+")
    elif order == 1:    # Ionic
        mb.lathe(cx, 0, [(r * 0.86, zc - 0.12), (r * 0.92, zc - 0.08), (r * 0.88, zc), (r * 1.08, zc + 0.16)], seg, TRAV, a0, a1)
        for sx in (-1, 1):
            vx = cx + sx * 0.46
            for i in range(10):       # volute as a short horizontal drum
                t0, t1 = math.tau * i / 10, math.tau * (i + 1) / 10
                p = lambda t, y: (vx + 0.17 * math.cos(t), y, zc + 0.20 + 0.17 * math.sin(t))
                mb.quad(p(t0, -0.56), p(t1, -0.56), p(t1, 0.0), p(t0, 0.0), TRAV, (math.cos((t0 + t1) / 2), 0, math.sin((t0 + t1) / 2)), smooth=True)
            mb.face([(vx + 0.17 * math.cos(math.tau * i / 10), -0.56, zc + 0.20 + 0.17 * math.sin(math.tau * i / 10)) for i in range(10)], TRAV, (0, -1, 0))
            mb.face([(vx + 0.07 * math.cos(math.tau * i / 6), -0.59, zc + 0.20 + 0.07 * math.sin(math.tau * i / 6)) for i in range(6)], TRAV, (0, -1, 0), ao=0.8)
        mb.box(cx - 0.46, cx + 0.46, -0.56, 0.0, zc + 0.16, zc + 0.36, TRAV, skip="y+z-")
        mb.box(cx - 0.62, cx + 0.62, -0.60, 0.0, zc + 0.37, z1, TRAV, skip="y+")
    else:               # Corinthian (bell with two leaf collars)
        mb.lathe(cx, 0, [(r * 0.86, zc - 0.12), (r * 0.93, zc - 0.08), (r * 0.86, zc), (r * 0.90, zc + 0.30), (r * 1.10, zc + 0.36),
                         (r * 0.92, zc + 0.38), (r * 0.96, zc + 0.62), (r * 1.20, zc + 0.70), (r * 1.0, zc + 0.72),
                         (r * 1.30, zc + 0.88)], seg, TRAV, a0, a1)
        for i in range(9):            # acanthus tips breaking the silhouette
            t = math.pi + (i + 0.5) * math.pi / 9
            for zz, rr in ((zc + 0.30, 1.14), (zc + 0.62, 1.24)):
                c, s = math.cos(t), math.sin(t)
                tx, ty = -s * 0.07, c * 0.07
                p0 = (cx + r * 0.9 * c - tx, r * 0.9 * s - ty, zz - 0.2)
                p1 = (cx + r * 0.9 * c + tx, r * 0.9 * s + ty, zz - 0.2)
                p2 = (cx + r * rr * c, r * rr * s, zz + 0.08)
                mb.face([p0, p1, p2], TRAV, (c, s, 0.3))
        mb.box(cx - 0.64, cx + 0.64, -0.62, 0.0, zc + 0.88, z1, TRAV, skip="y+")


def arcade(mb, order, lod=0):
    """order 0 = ground (Tuscan), 1 = Ionic, 2 = Corinthian."""
    h = STOREY[order]
    ent = 2.35 if order == 0 else 2.10
    ped = 0.0 if order == 0 else (1.95 if order == 1 else 2.10)
    arch_h = (7.05, 6.45, 6.40)[order]
    zs = ped + arch_h - HW
    ze = h - ent
    seg = 6 if lod else 14
    mb.level_z = 0.0
    mb.arch_wall(-W / 2, W / 2, 0.0, ped, ze, 0.0, HW, zs, TRAV, -1, seg)
    mb.arch_wall(-W / 2, W / 2, R.PIER1[1], ped, ze, 0.0, HW, zs, TRAV, 1, seg, ao=0.8)
    mb.intrados(0.0, HW, ped, zs, 0.0, R.PIER1[1], TRAV, seg, ao=0.78)
    mb.quad((-W / 2, R.PIER1[1], ze), (W / 2, R.PIER1[1], ze), (W / 2, R.PIER1[1], h), (-W / 2, R.PIER1[1], h), TRAV, (0, 1, 0), ao=0.8)
    if ped > 0:
        # pedestal band; in the opening it is the 1.1 m parapet
        for x0, x1, top in ((-W / 2, -HW, ped), (HW, W / 2, ped), (-HW, HW, 1.1)):
            mb.box(x0, x1, 0.0, 0.5 if top < ped else R.PIER1[1], 0.0, top, TRAV, skip="z-x-x+" if top == ped else "z-")
        if not lod:
            mb.extrude_x([(0, 1.0), (-0.06, 1.02), (-0.06, 1.1), (0, 1.1)], -HW, HW, TRAV)
    if not lod:
        mb.archivolt(0.0, HW, zs, 0.0, 0.46, 0.07, TRAV, seg)
        mb.box(-0.27, 0.27, -0.16, 0.0, zs + HW - 0.12, zs + HW + 0.78, TRAV, skip="y+")
        for x0, x1 in ((-W / 2, -HW), (HW, W / 2)):
            mb.extrude_x([(0, zs - 0.34), (-0.07, zs - 0.30), (-0.13, zs - 0.06), (-0.13, zs), (0, zs)], x0, x1, TRAV)
            if order == 0:
                mb.extrude_x([(0, 0.0), (-0.12, 0.0), (-0.12, 0.42), (-0.05, 0.5), (0, 0.5)], x0, x1, TRAV)
        # impost return inside the opening
        for sx in (-1, 1):
            mb.box(sx * HW - 0.07 * (sx > 0), sx * HW + 0.07 * (sx < 0), 0.0, R.PIER1[1], zs - 0.3, zs, TRAV, skip="y-y+", ao=0.8)
    _column(mb, order, 0.0, ze, lod, ped)
    _entablature(mb, ze, h, lod)


def attic(mb, window, lod=0):
    h = STOREY[3]
    t = R.R_GALLERY[0]
    mb.level_z = 0.0
    if window and not lod:
        # wall with a rectangular window 1.3 x 1.7 m
        x0, x1, z0, z1 = -0.65, 0.65, 4.4, 6.1
        mb.quad((-W / 2, 0, 0), (W / 2, 0, 0), (W / 2, 0, z0), (-W / 2, 0, z0), TRAV, (0, -1, 0))
        mb.quad((-W / 2, 0, z1), (W / 2, 0, z1), (W / 2, 0, h), (-W / 2, 0, h), TRAV, (0, -1, 0))
        mb.quad((-W / 2, 0, z0), (x0, 0, z0), (x0, 0, z1), (-W / 2, 0, z1), TRAV, (0, -1, 0))
        mb.quad((x1, 0, z0), (W / 2, 0, z0), (W / 2, 0, z1), (x1, 0, z1), TRAV, (0, -1, 0))
        mb.box(x0, x1, 0.0, t, z0, z1, TRAV, skip="y-y+", inward=True, ao=0.6)
        for a, b, c, d in ((x0 - 0.12, x1 + 0.12, z1, z1 + 0.14), (x0 - 0.12, x1 + 0.12, z0 - 0.14, z0)):
            mb.box(a, b, -0.07, 0.0, c, d, TRAV, skip="y+")
    else:
        mb.quad((-W / 2, 0, 0), (W / 2, 0, 0), (W / 2, 0, h), (-W / 2, 0, h), TRAV, (0, -1, 0))
        if window:
            mb.quad((-0.65, -0.02, 4.4), (0.65, -0.02, 4.4), (0.65, -0.02, 6.1), (-0.65, -0.02, 6.1), TRAV, (0, -1, 0), ao=0.25)
    mb.quad((-W / 2, 0, h), (W / 2, 0, h), (W / 2, t, h), (-W / 2, t, h), TRAV, (0, 0, 1))
    if not window:
        # gilded bronze clipeus (added under Domitian)
        seg = 8 if lod else 20
        prof = [(0.0, -0.20), (0.35, -0.17), (0.75, -0.10), (0.92, -0.10), (1.0, -0.03), (1.0, 0.0)]
        for (ra, ya), (rb, yb) in zip(prof, prof[1:]):
            for i in range(seg):
                t0, t1 = math.tau * i / seg, math.tau * (i + 1) / seg
                p = lambda rr, yy, tt: (rr * math.cos(tt), yy, 5.3 + rr * math.sin(tt))
                pts = [p(ra, ya, t0), p(ra, ya, t1), p(rb, yb, t1), p(rb, yb, t0)]
                if ra == 0.0:
                    pts = pts[1:]
                mb.face(pts, "bronze_gilt", (0, -1, 0), smooth=True)
    # plinth and pilaster on the left edge
    mb.extrude_x([(0, 0), (-0.14, 0), (-0.14, 1.45), (-0.06, 1.6), (0, 1.6)], -W / 2, W / 2, TRAV)
    px = -W / 2
    top = h - 2.0
    mb.box(px - 0.46, px + 0.46, -0.13, 0.0, 1.6, top - 0.9, TRAV, skip="y+z-z+")
    if lod:
        mb.box(px - 0.6, px + 0.6, -0.2, 0.0, top - 0.9, top, TRAV, skip="y+")
    else:
        mb.box(px - 0.56, px + 0.56, -0.2, 0.0, 1.6, 1.95, TRAV, skip="y+z-")
        for i, (zz, ww, pp) in enumerate(((top - 0.9, 0.5, 0.17), (top - 0.6, 0.56, 0.22), (top - 0.3, 0.62, 0.27))):
            mb.box(px - ww, px + ww, -pp, 0.0, zz, zz + 0.3, TRAV, skip="y+")
    # mast corbels (three per bay) with their sockets
    for i in range(3):
        x = -W / 2 + W / 6 + i * W / 3
        zc = h - 4.3
        mb.box(x - 0.24, x + 0.24, -0.75, 0.0, zc, zc + 0.3, TRAV, skip="y+")
        if not lod:
            mb.face([(x - 0.2, 0, zc - 0.7), (x - 0.2, -0.7, zc), (x - 0.2, 0, zc)], TRAV, (-1, 0, 0))
            mb.face([(x + 0.2, 0, zc - 0.7), (x + 0.2, -0.7, zc), (x + 0.2, 0, zc)], TRAV, (1, 0, 0))
            mb.quad((x - 0.2, 0, zc - 0.7), (x + 0.2, 0, zc - 0.7), (x + 0.2, -0.7, zc), (x - 0.2, -0.7, zc), TRAV, (0, -1, -1))
    # crowning cornice
    if lod:
        mb.extrude_x([(0, top + 0.6), (-0.8, top + 1.6), (-0.8, h), (0, h)], -W / 2, W / 2, TRAV)
    else:
        mb.extrude_x([(0, top), (-0.10, top), (-0.10, top + 0.5), (-0.16, top + 0.56), (-0.16, top + 0.95), (-0.24, top + 1.0),
                      (-0.50, top + 1.25), (-0.80, top + 1.30), (-0.80, top + 1.62), (-0.90, top + 1.72), (-0.96, top + 1.9),
                      (-0.96, h), (0, h)], -W / 2, W / 2, TRAV)


def masts(mb, lod=0):
    """Three velarium masts per bay, seated on the corbels and passing the cornice."""
    h = STOREY[3]
    for i in range(3):
        x = -W / 2 + W / 6 + i * W / 3
        z0 = h - 4.0
        mb.lathe(x, -0.5, [(0.15, z0), (0.14, z0 + 6.0), (0.10, z0 + 12.5), (0.0, z0 + 12.6)], 4 if lod else 7, "wood_dark")
        if not lod:
            mb.lathe(x, -0.5, [(0.19, z0 + 11.6), (0.19, z0 + 11.8)], 7, "iron")


def far_bay(mb):
    """One bay of the far shell (HLOD): flat walls with recessed dark arches."""
    z = 0.0
    for order in range(3):
        h = STOREY[order]
        ped = 0.0 if order == 0 else 2.0
        zs = ped + (7.05, 6.45, 6.40)[order] - HW
        mb.zoff = z
        mb.arch_wall(("L", 0), ("R", 0), 0.0, 0.0, h, 0.0, HW, zs, TRAV, -1, 4)
        mb.quad((-HW, 2.7, ped), (HW, 2.7, ped), (HW, 2.7, zs + HW), (-HW, 2.7, zs + HW), TRAV, (0, -1, 0), ao=0.18)
        mb.quad((-HW, 0, ped), (-HW, 2.7, ped), (-HW, 2.7, zs + HW), (-HW, 0, zs + HW), TRAV, (1, 0, 0), ao=0.5)
        mb.quad((HW, 0, ped), (HW, 2.7, ped), (HW, 2.7, zs + HW), (HW, 0, zs + HW), TRAV, (-1, 0, 0), ao=0.5)
        mb.quad((("L", 0), -0.6, h - 0.5), (("R", 0), -0.6, h - 0.5), (("R", 0), 0, h), (("L", 0), 0, h), TRAV, (0, -1, 1))
        z += h
    mb.zoff = z
    h = STOREY[3]
    mb.quad((("L", 0), 0, 0), (("R", 0), 0, 0), (("R", 0), 0, h), (("L", 0), 0, h), TRAV, (0, -1, 0))
    mb.quad((("L", 0), 0, h), (("R", 0), 0, h), (("R", 0), 1.8, h), (("L", 0), 1.8, h), TRAV, (0, 0, 1))
    mb.quad((("L", 0), 1.8, 4.0), (("R", 0), 1.8, 4.0), (("R", 0), 1.8, h), (("L", 0), 1.8, h), TRAV, (0, 1, 0), ao=0.8)
    mb.zoff = 0.0


def backing(mb, order):
    """Dark plane behind one arch, shown while the sector interior is culled."""
    ped = 0.0 if order == 0 else (1.95 if order == 1 else 2.10)
    top = ped + (7.05, 6.45, 6.40)[order]
    mb.level_z = -99
    mb.quad((-HW - 0.1, 2.6, ped), (HW + 0.1, 2.6, ped), (HW + 0.1, 2.6, top), (-HW - 0.1, 2.6, top), "arch_shadow", (0, -1, 0), ao=1.0)
