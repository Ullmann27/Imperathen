"""Unique per-bay interior of the amphitheatre: ring corridors, radial passages,
dog-leg stairs, vomitoria, the seating bowl, podium, boxes, gates and arena.

Each function writes visual geometry into `mb` and simplified walkable geometry
into `col` (ramps instead of steps, slopes instead of seat rows).
"""
import math

import ring as R

TRAV, TUFF, BRICK, MARBLE, WOOD = "travertine", "tuff", "brick", "marble", "wood"
PAVE, SPIC, SAND, PLASTER = "travertine_paving", "brick_floor", "sand", "plaster"
AXIS_HALF = 2.2          # half width of the major-axis processional passage
AXIS_CUT_R = 44.2        # from here inward the major-axis passage is open to the sky
IMA_CUT_R = 46.3         # ground vomitoria are open cuts from here to the podium terrace
MEDIA_CUT_R = 31.6
FLANK = (1, 79, 39, 41)
LEVELS = ((0.0, R.Z1), (R.Z1, R.Z2), (R.Z2, R.Z3))


def hw_pass(k, r, cap=1.5):
    return min(cap, R.width(k, r) / 2 - 0.45)


def reaches_ima(k):
    return R.bay_type(k) in ("passage", "axis_minor") and k % R.BAYS not in FLANK and hw_pass(k, 48.5) >= 0.8


def has_l2_passage(k):
    return R.bay_type(k) != "stair"


def axis_side(k):
    """+1 / -1 when the bay touches the east / west major-axis band, else 0."""
    k %= R.BAYS
    if k <= 3 or k >= 77:
        return 1
    if 37 <= k <= 43:
        return -1
    return 0


def axis_interval(k, r, half):
    """u-interval of bay k at depth r lying inside the major-axis band |y| < half, or None."""
    if not axis_side(k):
        return None
    y0 = R.bay_point(k, 0.0, r)[1]
    y1 = R.bay_point(k, 1.0, r)[1]
    if abs(y1 - y0) < 1e-6:
        return None
    ua, ub = sorted(((-half - y0) / (y1 - y0), (half - y0) / (y1 - y0)))
    ua, ub = max(0.0, ua), min(1.0, ub)
    return (ua, ub) if ub - ua > 1e-4 else None


def subtract(intervals, cut):
    if cut is None:
        return intervals
    out = []
    for a, b in intervals:
        if cut[1] <= a or cut[0] >= b:
            out.append((a, b))
            continue
        if cut[0] - a > 0.02:
            out.append((a, cut[0]))
        if b - cut[1] > 0.02:
            out.append((cut[1], b))
    return out


def cuts_at(k, r):
    """u-intervals removed from the bowl surface of bay k at depth r."""
    k %= R.BAYS
    w = R.width(k, r)
    cuts = []
    if r > AXIS_CUT_R:
        cuts.append(axis_interval(k, r, AXIS_HALF + 0.3))
    if reaches_ima(k) and IMA_CUT_R < r < R.R_TERRACE[0]:
        h = hw_pass(k, r) + 0.3
        cuts.append((0.5 - h / w, 0.5 + h / w))
    if has_l2_passage(k) and MEDIA_CUT_R < r < R.R_PRAE1[0]:
        h = hw_pass(k, r, 1.3) + 0.3
        cuts.append((0.5 - h / w, 0.5 + h / w))
    if R.bay_type(k) == "axis_minor" and r > 47.3:
        cuts.append((0.0, 1.0))      # replaced by the box platform
    return [c for c in cuts if c]


def surface_intervals(k, r, start=0.0):
    iv = [(start, 1.0)]
    for c in cuts_at(k, r):
        iv = subtract(iv, c)
    return iv


# --------------------------------------------------------------------------
def tunnel(mb, col, k, y0, y1, zf0, zf1, h0, h1, wall, floor, cap=1.5, open_top=False, parapet=None):
    """Radial passage centred in the bay; width follows the wedge."""
    n = max(1, int(abs(y1 - y0) / 3.0 + 0.5))
    for i in range(n):
        ya, yb = y0 + (y1 - y0) * i / n, y0 + (y1 - y0) * (i + 1) / n
        za, zb = zf0 + (zf1 - zf0) * i / n, zf0 + (zf1 - zf0) * (i + 1) / n
        ha, hb = h0 + (h1 - h0) * i / n, h0 + (h1 - h0) * (i + 1) / n
        wa, wb = hw_pass(k, ya, cap), hw_pass(k, yb, cap)
        for m in (mb, col):
            m.quad((-wa, ya, za), (wa, ya, za), (wb, yb, zb), (-wb, yb, zb), floor, (0, 0, 1))
        for s in (-1, 1):
            if parapet:
                ta, tb = parapet(ya), parapet(yb)
            else:
                ta, tb = za + ha, zb + hb
            for m in (mb, col):
                m.quad((s * wa, ya, za), (s * wb, yb, zb), (s * wb, yb, tb), (s * wa, ya, ta), wall, (-s, 0, 0), ao=0.75)
            if parapet:
                # outer face and top of the parapet seen from the seating
                o = 0.3
                mb.quad((s * (wa + o), ya, ta - 1.0), (s * (wb + o), yb, tb - 1.0), (s * (wb + o), yb, tb), (s * (wa + o), ya, ta), MARBLE, (s, 0, 0))
                mb.quad((s * wa, ya, ta), (s * wb, yb, tb), (s * (wb + o), yb, tb), (s * (wa + o), ya, ta), MARBLE, (0, 0, 1))
        if not open_top:
            ca, cb = za + ha, zb + hb
            mb.quad((-wa, ya, ca - 0.5), (-wa * 0.5, ya, ca), (-wb * 0.5, yb, cb), (-wb, yb, cb - 0.5), wall, (1, 0, -1), ao=0.6)
            mb.quad((-wa * 0.5, ya, ca), (wa * 0.5, ya, ca), (wb * 0.5, yb, cb), (-wb * 0.5, yb, cb), wall, (0, 0, -1), ao=0.6)
            mb.quad((wa * 0.5, ya, ca), (wa, ya, ca - 0.5), (wb, yb, cb - 0.5), (wb * 0.5, yb, cb), wall, (-1, 0, -1), ao=0.6)


def flight(mb, col, x0, x1, ya, za, yb, zb, mat=TRAV):
    """Straight stair flight from (ya, za) up to (yb, zb); collision is a ramp."""
    n = max(2, round(abs(zb - za) / 0.185))
    d = 1 if yb > ya else -1
    for i in range(n):
        y_a, y_b = ya + (yb - ya) * i / n, ya + (yb - ya) * (i + 1) / n
        z_a, z_b = za + (zb - za) * i / n, za + (zb - za) * (i + 1) / n
        mb.quad((x0, y_a, z_a), (x1, y_a, z_a), (x1, y_a, z_b), (x0, y_a, z_b), mat, (0, -d, 0), ao=0.85)
        mb.quad((x0, y_a, z_b), (x1, y_a, z_b), (x1, y_b, z_b), (x0, y_b, z_b), mat, (0, 0, 1))
    mb.quad((x0, ya, za - 0.4), (x1, ya, za - 0.4), (x1, yb, zb - 0.4), (x0, yb, zb - 0.4), TUFF, (0, 0, -1), ao=0.55)
    col.quad((x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb), mat, (0, 0, 1))


def slab(mb, col, x0, x1, y0, y1, z, mat, thick=0.4):
    mb.quad((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), mat, (0, 0, 1))
    mb.quad((x0, y0, z - thick), (x1, y0, z - thick), (x1, y1, z - thick), (x0, y1, z - thick), TUFF, (0, 0, -1), ao=0.55)
    col.quad((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), mat, (0, 0, 1))


def wall_y(mb, col, x0, x1, y, z0, z1, mat, facing, ao=0.8, solid=True):
    mb.quad((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1), mat, (0, facing, 0), ao=ao)
    if solid:
        col.quad((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1), mat, (0, facing, 0))


def wall_x(mb, col, x, y0, y1, z0, z1, mat, facing, ao=0.8, z0b=None, z1b=None):
    z0b = z0 if z0b is None else z0b
    z1b = z1 if z1b is None else z1b
    for m in (mb, col):
        m.quad((x, y0, z0), (x, y1, z0b), (x, y1, z1b), (x, y0, z1), mat, (facing, 0, 0), ao=ao)


def door_wall(mb, col, k, y, z0, z1, hw, top, mat, facing, round_top=True, ao=0.8):
    """Full-width wall across the bay with a central opening."""
    L, Rr = ("L", 0), ("R", 0)
    if hw <= 0:
        wall_y(mb, col, L, Rr, y, z0, z1, mat, facing, ao)
        return
    if round_top:
        mb.arch_wall(L, Rr, y, z0, z1, 0.0, hw, top - hw, mat, facing, 8, ao=ao)
    else:
        mb.quad((L, y, z0), (-hw, y, z0), (-hw, y, z1), (L, y, z1), mat, (0, facing, 0), ao=ao)
        mb.quad((hw, y, z0), (Rr, y, z0), (Rr, y, z1), (hw, y, z1), mat, (0, facing, 0), ao=ao)
        mb.quad((-hw, y, top), (hw, y, top), (hw, y, z1), (-hw, y, z1), mat, (0, facing, 0), ao=ao)
    col.quad((L, y, z0), (-hw, y, z0), (-hw, y, z1), (L, y, z1), mat, (0, facing, 0))
    col.quad((hw, y, z0), (Rr, y, z0), (Rr, y, z1), (hw, y, z1), mat, (0, facing, 0))
    col.quad((-hw, y, top), (hw, y, top), (hw, y, z1), (-hw, y, z1), mat, (0, facing, 0))


# --------------------------------------------------------------------------
def corridors(mb, col, k):
    """Outer ambulatories A and B on three storeys, pier ring 2 and wall 3."""
    t = R.bay_type(k)
    k %= R.BAYS
    L, Rr = ("L", 0), ("R", 0)
    tstair = None
    for k0 in R.T_STAIRS:
        if 0 <= (k - k0) % R.BAYS <= 2:
            tstair = (k - k0) % R.BAYS
    for lvl, (z0, z1) in enumerate(LEVELS):
        mb.level_z = z0
        ceil = z1 - 0.5
        fmat = PAVE if lvl == 0 else SPIC
        # floors
        hole = lvl == 2 and t == "stair"
        if hole:
            for m in (mb, col):
                m.quad((L, 0.0, z0), (Rr, 0.0, z0), (Rr, 11.25, z0), (L, 11.25, z0), fmat, (0, 0, 1))
                m.quad((L, 11.25, z0), (0.15, 11.25, z0), (0.15, 14.0, z0), (L, 14.0, z0), fmat, (0, 0, 1))
            # railing around the stairwell
            for a, b in (((0.15, 11.25), (0.15, 14.0)),):
                for m in (mb, col):
                    m.box(0.03, 0.15, 11.25, 14.0, z0, z0 + 1.05, TRAV, skip="z-")
        else:
            for m in (mb, col):
                m.quad((L, 0.0, z0), (Rr, 0.0, z0), (Rr, 14.0, z0), (L, 14.0, z0), fmat, (0, 0, 1))
        if lvl == 0:
            for m in (mb, col):   # threshold apron in front of the arch
                m.quad((L, -1.6, 0.0), (Rr, -1.6, 0.0), (Rr, 0.0, 0.0), (L, 0.0, 0.0), PAVE, (0, 0, 1))
        # polygonal barrel vaults
        for (ya, yb), vault_mat in ((R.CORR_A, TRAV if lvl == 0 else PLASTER), (R.CORR_B, PLASTER)):
            if lvl == 2 and tstair is not None and ya < 5:
                continue
            ym = (ya + yb) / 2
            q = (yb - ya) / 4
            prof = [(ya, ceil - 1.25), (ya + q * 0.9, ceil - 0.3), (ym, ceil), (yb - q * 0.9, ceil - 0.3), (yb, ceil - 1.25)]
            for (p0, c0), (p1, c1) in zip(prof, prof[1:]):
                mb.quad((L, p0, c0), (Rr, p0, c0), (Rr, p1, c1), (L, p1, c1), vault_mat, (0, 0, -1), ao=0.62)
        # pier ring 2: half piers on both edges with an arch between
        hw2 = R.width(k, 8.6) / 2 - 1.1
        zs = z0 + 5.4
        for y, f in ((R.PIER2[0], -1), (R.PIER2[1], 1)):
            mb.arch_wall(L, Rr, y, z0, ceil - 1.25, 0.0, hw2, zs, TRAV, f, 8, ao=0.8)
        mb.intrados(0.0, hw2, z0, zs, R.PIER2[0], R.PIER2[1], TRAV, 8, ao=0.7)
        for s, e in ((-1, "L"), (1, "R")):
            for m in (col,):
                m.quad((s * hw2, R.PIER2[0], z0), (s * hw2, R.PIER2[1], z0), (s * hw2, R.PIER2[1], zs), (s * hw2, R.PIER2[0], zs), TRAV, (-s, 0, 0))
                m.quad(((e, 0), R.PIER2[0], z0), (s * hw2, R.PIER2[0], z0), (s * hw2, R.PIER2[0], zs), ((e, 0), R.PIER2[0], zs), TRAV, (0, -1, 0))
                m.quad(((e, 0), R.PIER2[1], z0), (s * hw2, R.PIER2[1], z0), (s * hw2, R.PIER2[1], zs), ((e, 0), R.PIER2[1], zs), TRAV, (0, 1, 0))
        # facade piers and parapets (collision for the instanced modules)
        for e in ("L", "R"):
            col.box((e, 0), (e, 1.23), 0.0, 2.7, z0, z0 + 7.0, TRAV, skip="z-z+")
        if lvl > 0:
            col.box(L, Rr, 0.0, 0.5, z0, z0 + 1.1, TRAV, skip="z-")
        # wall 3
        y3 = R.WALL3[0]
        top = ceil - 1.25
        if t == "stair":
            if lvl < 2:
                mb.quad((L, y3, top - 1.2), (Rr, y3, top - 1.2), (Rr, y3, top), (L, y3, top), BRICK, (0, -1, 0), ao=0.8)
                for e, s in (("L", 1), ("R", -1)):
                    for m in (mb, col):
                        m.quad(((e, 0), y3, z0), ((e, 0.45), y3, z0), ((e, 0.45), y3, top), ((e, 0), y3, top), BRICK, (0, -1, 0), ao=0.8)
            else:
                # level 3: solid on the left half, stair notch on the right half
                for m in (mb, col):
                    m.quad((L, y3, z0), (0.15, y3, z0), (0.15, y3, top), (L, y3, top), BRICK, (0, -1, 0), ao=0.8)
                    m.quad((0.15, y3, z0 + 2.6), (Rr, y3, z0 + 2.6), (Rr, y3, top), (0.15, y3, top), BRICK, (0, -1, 0), ao=0.8)
                    m.quad((("R", 0.45), y3, z0), (Rr, y3, z0), (Rr, y3, z0 + 2.6), (("R", 0.45), y3, z0 + 2.6), BRICK, (0, -1, 0), ao=0.8)
        elif lvl == 0 and k in FLANK:
            wall_y(mb, col, L, Rr, y3, z0, top, BRICK, -1)
        elif lvl == 0 and t == "axis_major":
            door_wall(mb, col, k, y3, z0, top, AXIS_HALF, z0 + 6.0, TRAV, -1)
        elif lvl == 2:
            door_wall(mb, col, k, y3, z0, top, 1.1, z0 + 2.7, BRICK, -1)
        else:
            door_wall(mb, col, k, y3, z0, top, hw_pass(k, 14.5, 1.5 if lvl == 0 else 1.3), z0 + (4.5 if lvl == 0 else 3.0), BRICK, -1)
    # tangential stair to the top gallery (three bays along the facade wall)
    if tstair is not None:
        rise = R.Z3 - R.Z2
        za, zb = R.Z2 + rise * tstair / 3, R.Z2 + rise * (tstair + 1) / 3
        n = 20
        for i in range(n):
            ua, ub = i / n, (i + 1) / n
            z_a, z_b = za + (zb - za) * ua, za + (zb - za) * ub
            mb.quad((("U", ua), 2.7, z_a), (("U", ua), 4.3, z_a), (("U", ua), 4.3, z_b), (("U", ua), 2.7, z_b), WOOD, (-1, 0, 0), ao=0.85)
            mb.quad((("U", ua), 2.7, z_b), (("U", ub), 2.7, z_b), (("U", ub), 4.3, z_b), (("U", ua), 4.3, z_b), WOOD, (0, 0, 1))
        col.quad((L, 2.7, za), (Rr, 2.7, za), (Rr, 4.3, zb), (L, 4.3, zb), WOOD, (0, 0, 1))
        mb.quad((L, 2.7, za - 0.3), (Rr, 2.7, zb - 0.3), (Rr, 4.3, zb - 0.3), (L, 4.3, za - 0.3), WOOD, (0, 0, -1), ao=0.6)
        # inner stringer wall / railing
        for m in (mb, col):
            m.quad((L, 4.3, za - 0.3), (Rr, 4.3, zb - 0.3), (Rr, 4.3, zb + 1.0), (L, 4.3, za + 1.0), WOOD, (0, 1, 0))
        mb.quad((L, 4.3, za - 0.3), (Rr, 4.3, zb - 0.3), (Rr, 4.3, zb + 1.0), (L, 4.3, za + 1.0), WOOD, (0, -1, 0), ao=0.8)


def gallery(mb, col, k):
    """Top gallery floor behind the wooden tier, attic inner wall, portico."""
    k %= R.BAYS
    L, Rr = ("L", 0), ("R", 0)
    z = R.Z3
    mb.level_z = z
    tstair = None
    for k0 in R.T_STAIRS:
        if 0 <= (k - k0) % R.BAYS <= 2:
            tstair = (k - k0) % R.BAYS
    y0, y1 = R.R_GALLERY
    u_hole = None if tstair in (None, 0) else (0.35 if tstair == 1 else 0.0)
    if u_hole is None:
        slab(mb, col, L, Rr, y0, y1, z, WOOD, 0.3)
    else:
        slab(mb, col, L, Rr, 4.5, y1, z, WOOD, 0.3)
        if u_hole > 0:
            slab(mb, col, L, ("U", u_hole), y0, 4.5, z, WOOD, 0.3)
        for m in (mb, col):   # guard rail along the stairwell
            m.box(("U", u_hole), Rr, 4.38, 4.5, z, z + 1.05, WOOD, skip="z-")
        if tstair == 2:
            for m in (mb, col):
                m.box(("R", 0.12), Rr, y0, 4.5, z, z + 1.05, WOOD, skip="z-")
    wall_y(mb, col, L, Rr, y0, z, R.HEIGHT, TRAV, 1, ao=0.85)
    # portico roof over the wooden tier
    zr0, zr1 = 40.6, 38.4
    yr1 = R.R_WALL5[1] + 0.4
    mb.quad((L, y0, zr0), (Rr, y0, zr0), (Rr, yr1, zr1), (L, yr1, zr1), "roof_tile", (0, 0, 1))
    mb.quad((L, y0, zr0 - 0.25), (Rr, y0, zr0 - 0.25), (Rr, yr1, zr1 - 0.25), (L, yr1, zr1 - 0.25), WOOD, (0, 0, -1), ao=0.6)
    mb.quad((L, yr1, zr1 - 0.25), (Rr, yr1, zr1 - 0.25), (Rr, yr1, zr1), (L, yr1, zr1), WOOD, (0, 1, 0))
    # colonnade column on the left edge, standing on the 5 m wall
    cy = R.R_WALL5[0] + 0.3
    zc0 = R.Z_WOOD0
    w = mb.width(cy)
    cx = -w / 2
    mb.lathe(cx, cy, [(0.36, zc0), (0.36, zc0 + 0.25), (0.28, zc0 + 0.35), (0.27, zc0 + 5.0), (0.24, zc0 + 9.9), (0.36, zc0 + 10.4),
                      (0.40, zc0 + 10.4), (0.40, zc0 + 10.7)], 8, MARBLE)
    col.box(cx - 0.3, cx + 0.3, cy - 0.3, cy + 0.3, zc0, zc0 + 3.0, MARBLE, skip="z-z+")
    # architrave beam between the columns
    mb.box(L, Rr, cy - 0.25, cy + 0.25, zc0 + 10.7, zr1 - 0.1, WOOD, skip="x-x+")


def passages(mb, col, k):
    """Radial passages on three levels, inner ring corridor C, dog-leg stairs."""
    t = R.bay_type(k)
    k %= R.BAYS
    L, Rr = ("L", 0), ("R", 0)
    flank = k in FLANK
    mb.level_z = 0.0
    # --- inner ground ring corridor C ---
    c0, c1 = R.CORR_C
    if t != "axis_major":
        cut = axis_interval(k, (c0 + c1) / 2, AXIS_HALF)
        ua, ub = 0.0, 1.0
        if cut:
            if cut[0] <= 0.001:
                ua = cut[1]
            else:
                ub = cut[0]
        xa, xb = ("U", ua), ("U", ub)
        for m in (mb, col):
            m.quad((xa, c0, 0.0), (xb, c0, 0.0), (xb, c1, 0.0), (xa, c1, 0.0), PAVE, (0, 0, 1))
        mb.quad((xa, c0, 4.2), (xb, c0, 4.2), (xb, c1, 4.2), (xa, c1, 4.2), TUFF, (0, 0, -1), ao=0.55)
        p_out = (t in ("passage", "axis_minor")) and not flank
        p_in = reaches_ima(k)
        if cut:
            wall_y(mb, col, xa, xb, c0, 0.0, 4.2, TUFF, 1, 0.7)
            wall_y(mb, col, xa, xb, c1, 0.0, 4.2, TUFF, -1, 0.7)
        else:
            door_wall(mb, col, k, c0, 0.0, 4.2, hw_pass(k, c0) if p_out else 0, 3.6, TUFF, 1, ao=0.7)
            door_wall(mb, col, k, c1, 0.0, 4.2, hw_pass(k, c1) if p_in else 0, 3.6, TUFF, -1, ao=0.7)
    # --- ground level ---
    if t in ("passage", "axis_minor") and not flank:
        tunnel(mb, col, k, 14.0, c0, 0.0, 0.0, 4.5, 4.5, TUFF, PAVE)
        if reaches_ima(k):
            zend = R.Z_PODIUM
            ytop = 47.6
            n = 21
            # stepped ramp up to the podium terrace
            tunnel(mb, col, k, c1, IMA_CUT_R, 0.0, zend * (IMA_CUT_R - c1) / (ytop - c1), 4.4, 2.5, TUFF, TRAV)
            par = lambda y: (R.cavea_z(min(y, R.R_TERRACE[0] - 0.01)) or zend) + 0.95
            tunnel(mb, col, k, IMA_CUT_R, ytop, zend * (IMA_CUT_R - c1) / (ytop - c1), zend, 0, 0, MARBLE, TRAV, open_top=True, parapet=par)
            tunnel(mb, col, k, ytop, R.R_TERRACE[0], zend, zend, 0, 0, MARBLE, TRAV, open_top=True, parapet=par)
    # --- level 2 passage to the praecinctio above the maenianum primum ---
    if has_l2_passage(k):
        mb.level_z = R.Z1
        tunnel(mb, col, k, 14.0, MEDIA_CUT_R, R.Z1, R.Z1, 2.9, 2.9, BRICK, SPIC, cap=1.3)
        par = lambda y: R.Z_MEDIA0 + (R.R_PRAE1[0] - y) / (R.R_PRAE1[0] - R.R_PRAE2[1]) * (R.Z2 - R.Z_MEDIA0) + 0.95
        tunnel(mb, col, k, MEDIA_CUT_R, R.R_PRAE1[0], R.Z1, R.Z1, 0, 0, MARBLE, SPIC, cap=1.3, open_top=True, parapet=par)
        # level 3 doorway through wall 3 and the 5 m wall
        mb.level_z = R.Z2
        tunnel(mb, col, k, 14.0, R.R_WALL5[1], R.Z2, R.Z2, 2.7, 2.7, BRICK, SPIC, cap=1.1)
    # --- dog-leg stairs ---
    if t == "stair":
        xl, xr = ("L", 0.45), ("R", 0.45)
        y0, ym, y1 = 15.0, 23.5, 25.2
        zl1, zl2 = 5.25, 15.6
        mb.level_z = 0.0
        # shell
        ztop = lambda y: R.cavea_z(y) - 0.5
        wall_x(mb, col, xl, 14.0, y1, 0.0, R.Z2 + 2.6, TUFF, 1, 0.7, z1b=ztop(y1))
        wall_x(mb, col, xr, 14.0, y1, 0.0, R.Z2 + 2.6, TUFF, -1, 0.7, z1b=ztop(y1))
        wall_y(mb, col, xl, xr, y1, 0.0, ztop(y1), TUFF, -1, 0.7)
        mb.quad((xl, y0, R.Z2 + 2.6), (xr, y0, R.Z2 + 2.6), (xr, y1, ztop(y1)), (xl, y1, ztop(y1)), TUFF, (0, 0, -1), ao=0.5)
        for m in (mb, col):
            m.quad((xl, 14.0, 0.0), (xr, 14.0, 0.0), (xr, y0, 0.0), (xl, y0, 0.0), PAVE, (0, 0, 1))
            m.box(-0.15, 0.15, y0, ym, 0.0, R.Z2 - 1.0, TUFF, skip="z-")
        # ground -> level 2
        flight(mb, col, xl, -0.15, y0, 0.0, ym, zl1)
        slab(mb, col, xl, xr, ym, y1, zl1, TRAV)
        flight(mb, col, 0.15, xr, ym, zl1, y0, R.Z1)
        slab(mb, col, xl, xr, 14.0, y0, R.Z1, SPIC)
        # level 2 -> level 3
        mb.level_z = R.Z1
        flight(mb, col, xl, -0.15, y0, R.Z1, ym, zl2)
        slab(mb, col, xl, xr, ym, y1, zl2, TRAV)
        flight(mb, col, 0.15, xr, ym, zl2, 11.25, R.Z2)
        # closing slab on the left half at level 3 behind wall 3
        mb.quad((xl, 14.0, R.Z2 - 0.5), (-0.15, 14.0, R.Z2 - 0.5), (-0.15, y0, R.Z2 - 0.5), (xl, y0, R.Z2 - 0.5), TUFF, (0, 0, -1), ao=0.5)
        # balustrade walls beside the upper flight where it crosses corridor B
        for x in (0.15, xr):
            for m in (mb, col):
                m.quad((x, 11.25, R.Z2 - 0.4), (x, 14.0, R.Z2 - 2.0), (x, 14.0, R.Z2 + 1.0), (x, 11.25, R.Z2 + 1.0), TRAV, (1, 0, 0))
            mb.quad((x, 11.25, R.Z2 - 0.4), (x, 14.0, R.Z2 - 2.0), (x, 14.0, R.Z2 + 1.0), (x, 11.25, R.Z2 + 1.0), TRAV, (-1, 0, 0))


def seating(mb, col, k):
    """Podium terrace, three seating tiers with scalaria, praecinctiones and dividing walls."""
    k %= R.BAYS
    L, Rr = ("L", 0), ("R", 0)
    mb.interior = 1.0
    mb.level_z = -99.0
    # podium terrace and its front wall
    y0, y1 = R.R_TERRACE
    zp = R.Z_PODIUM
    minor = R.bay_type(k) == "axis_minor"
    for a, b in surface_intervals(k, (y0 + y1) / 2):
        xa, xb = ("U", a), ("U", b)
        for m in (mb, col):
            m.quad((xa, y0, zp), (xb, y0, zp), (xb, y1, zp), (xa, y1, zp), MARBLE, (0, 0, 1))
            m.quad((xa, y1, 0.0), (xb, y1, 0.0), (xb, y1, zp + 0.95), (xa, y1, zp + 0.95), MARBLE, (0, 1, 0))
        mb.quad((xa, y1 - 0.3, zp), (xb, y1 - 0.3, zp), (xb, y1 - 0.3, zp + 0.95), (xa, y1 - 0.3, zp + 0.95), MARBLE, (0, -1, 0))
        mb.quad((xa, y1 - 0.3, zp + 0.95), (xb, y1 - 0.3, zp + 0.95), (xb, y1, zp + 0.95), (xa, y1, zp + 0.95), MARBLE, (0, 0, 1))
        # low platform for the senators' chairs
        mb.box(xa, xb, y0 + 0.2, y0 + 1.5, zp, zp + 0.18, MARBLE, skip="z-")
    if minor:
        # box platform (pulvinar on the north, magistrates' box on the south)
        zb = zp + 0.8
        for m in (mb, col):
            m.quad((L, 47.3, zb), (Rr, 47.3, zb), (Rr, y1, zb), (L, y1, zb), MARBLE, (0, 0, 1))
            m.quad((L, y1, 0.0), (Rr, y1, 0.0), (Rr, y1, zb + 1.0), (L, y1, zb + 1.0), MARBLE, (0, 1, 0))
            m.quad((L, 47.3, zp), (Rr, 47.3, zp), (Rr, 47.3, zb), (L, 47.3, zb), MARBLE, (0, -1, 0))
        mb.quad((L, y1 - 0.25, zb), (Rr, y1 - 0.25, zb), (Rr, y1 - 0.25, zb + 1.0), (L, y1 - 0.25, zb + 1.0), MARBLE, (0, -1, 0))
        mb.quad((L, y1 - 0.25, zb + 1.0), (Rr, y1 - 0.25, zb + 1.0), (Rr, y1, zb + 1.0), (L, y1, zb + 1.0), MARBLE, (0, 0, 1))
        for e in ("L", "R"):
            for yy in (47.8, y1 - 0.6):
                w = mb.width(yy)
                cx = (-w / 2 + 0.35) if e == "L" else (w / 2 - 0.35)
                mb.lathe(cx, yy, [(0.2, zb), (0.2, zb + 0.15), (0.14, zb + 0.25), (0.12, zb + 3.3), (0.2, zb + 3.5), (0.2, zb + 3.6)], 8, MARBLE)
        canopy = "canvas_purple" if k == 20 else "canvas"
        mb.quad((L, 47.5, zb + 3.6), (Rr, 47.5, zb + 3.6), (Rr, y1 - 0.3, zb + 3.9), (L, y1 - 0.3, zb + 3.9), canopy, (0, 0, 1))
        mb.quad((L, 47.5, zb + 3.58), (Rr, 47.5, zb + 3.58), (Rr, y1 - 0.3, zb + 3.88), (L, y1 - 0.3, zb + 3.88), canopy, (0, 0, -1), ao=0.7)
        # steps from the terrace level of the passage up to the box
        for m in (mb, col):
            m.quad((-0.9, 46.0, zp), (0.9, 46.0, zp), (0.9, 47.3, zb), (-0.9, 47.3, zb), MARBLE, (0, 0, 1))
    # tiers
    for tid, cls, r_in, r_out, z0, z1, rows in R.TIERS[1:]:
        mat = MARBLE if tid == "maenianum_primum" else (WOOD if "ligneis" in tid else TRAV)
        d = (r_in - r_out) / rows
        h = (z1 - z0) / rows
        if tid == "maenianum_primum":
            for a, b in surface_intervals(k, r_in - 0.01):
                mb.quad((("U", a), r_in, R.Z_PODIUM), (("U", b), r_in, R.Z_PODIUM), (("U", b), r_in, z0), (("U", a), r_in, z0), mat, (0, 1, 0))
        for j in range(rows):
            ra, rb = r_in - j * d, r_in - (j + 1) * d
            rm = (ra + rb) / 2
            zt = z0 + (j + 1) * h
            w = R.width(k, rm)
            us = 0.9 / w
            tint = 0.94 + 0.06 * ((j * 7 + k * 3) % 5) / 4
            for a, b in surface_intervals(k, rm, us):
                xa, xb = ("U", a), ("U", b)
                mb.quad((xa, ra, zt - h), (xb, ra, zt - h), (xb, ra, zt), (xa, ra, zt), mat, (0, 1, 0), ao=0.82 * tint)
                mb.quad((xa, ra, zt), (xb, ra, zt), (xb, rb, zt), (xa, rb, zt), mat, (0, 0, 1), ao=tint)
            for a, b in subtract_all([(0.0, us)], cuts_at(k, rm)):
                xa, xb = ("U", a), ("U", b)
                yh = (ra + rb) / 2
                for ya, yb2, za2, zb2 in ((ra, yh, zt - h, zt - h / 2), (yh, rb, zt - h / 2, zt)):
                    mb.quad((xa, ya, za2), (xb, ya, za2), (xb, ya, zb2), (xa, ya, zb2), TRAV, (0, 1, 0), ao=0.8)
                    mb.quad((xa, ya, zb2), (xb, ya, zb2), (xb, yb2, zb2), (xa, yb2, zb2), TRAV, (0, 0, 1), ao=0.95)
            for a, b in surface_intervals(k, rm):
                col.quad((("U", a), ra, zt - h), (("U", b), ra, zt - h), (("U", b), rb, zt), (("U", a), rb, zt), mat, (0, 0, 1))
    # praecinctio 1 with the balteus wall behind it
    for (ya, yb), z, zwall, wall_r, wm in ((R.R_PRAE1, R.Z1, R.Z_MEDIA0, R.R_PRAE1[0], MARBLE),):
        for m in (mb, col):
            m.quad((L, ya, z), (Rr, ya, z), (Rr, yb, z), (L, yb, z), TRAV, (0, 0, 1))
        for a, b in surface_intervals(k, wall_r + 0.01):
            for m in (mb, col):
                m.quad((("U", a), wall_r, z), (("U", b), wall_r, z), (("U", b), wall_r, zwall), (("U", a), wall_r, zwall), wm, (0, 1, 0))
    # praecinctio 2, the 5 m wall with its doors, base walkway of the wooden tier
    ya, yb = R.R_PRAE2
    for m in (mb, col):
        m.quad((L, ya, R.Z2), (Rr, ya, R.Z2), (Rr, yb, R.Z2), (L, yb, R.Z2), TRAV, (0, 0, 1))
    hw = hw_pass(k, 16.9, 1.1) if has_l2_passage(k) else 0
    door_wall(mb, col, k, R.R_WALL5[1], R.Z2, R.Z_WOOD0, hw, R.Z2 + 2.7, TRAV, 1, round_top=False, ao=1.0)
    for m in (mb, col):
        m.quad((L, R.R_WALL5[0], R.Z_WOOD0), (Rr, R.R_WALL5[0], R.Z_WOOD0), (Rr, R.R_WALL5[1], R.Z_WOOD0), (L, R.R_WALL5[1], R.Z_WOOD0), TRAV, (0, 0, 1))
    # parapet on top of the 5 m wall (front of the wooden tier)
    for m in (mb, col):
        m.box(L, Rr, R.R_WALL5[1] - 0.2, R.R_WALL5[1], R.Z_WOOD0, R.Z_WOOD0 + 0.95, TRAV, skip="z-x-x+")
    mb.interior = 0.62


def subtract_all(intervals, cuts):
    for c in cuts:
        intervals = subtract(intervals, c)
    return intervals


def numeral(mb, k):
    """Incised, red-painted entrance number above the ground arch (c. 34 cm tall)."""
    n = R.entrance_number(k)
    if not n:
        return
    text = R.roman(n)
    hh, y, z0 = 0.34, -0.012, 7.30
    widths = {"I": 0.07, "V": 0.26, "X": 0.26, "L": 0.2}
    total = sum(widths[c] + 0.07 for c in text) - 0.07
    x = -total / 2
    s = 0.035

    def stroke(xa, za, xb, zb):
        dx, dz = xb - xa, zb - za
        m = math.hypot(dx, dz)
        px, pz = -dz / m * s, dx / m * s
        mb.quad((xa - px, y, za - pz), (xa + px, y, za + pz), (xb + px, y, zb + pz), (xb - px, y, zb - pz), "numeral_red", (0, -1, 0), ao=1.0)

    for c in text:
        w = widths[c]
        if c == "I":
            stroke(x + w / 2, z0, x + w / 2, z0 + hh)
        elif c == "V":
            stroke(x, z0 + hh, x + w / 2, z0)
            stroke(x + w / 2, z0, x + w, z0 + hh)
        elif c == "X":
            stroke(x, z0, x + w, z0 + hh)
            stroke(x, z0 + hh, x + w, z0)
        else:
            stroke(x + s, z0, x + s, z0 + hh)
            stroke(x, z0 + s, x + w, z0 + s)
        x += w + 0.07
