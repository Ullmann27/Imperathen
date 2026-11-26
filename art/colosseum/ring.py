"""Shared parametric description of the Flavian Amphitheatre (pure Python, no bpy).

Used by the Blender kit builder, the layout/anchor generator and the tests.
Blender axes: +X east, +Y north, +Z up.  Godot: (x, z, -y).

Sources for the figures are listed in docs/29_colosseum/SOURCES.md.  Values
marked DERIVED are fitted to make the simplified circulation geometrically
consistent and are not archaeological measurements.
"""
import math

A, B = 94.0, 78.0            # outer semi-axes: 188 x 156 m (Platner-Ashby)
BAYS = 80                    # arcades per storey
HEIGHT = 48.5                # Platner-Ashby
Z1, Z2, Z3 = 10.5, 22.35, 33.95   # storey floor levels (DERIVED from arch + entablature heights)
DEPTH = 52.5                 # facade line to arena wall (DERIVED: constant-width cavea)
# radial bands, metres inward from the facade line
PIER1 = (0.0, 2.7)           # facade piers 2.40 x 2.70 m (Platner-Ashby)
CORR_A = (2.7, 7.6)
PIER2 = (7.6, 9.6)
CORR_B = (9.6, 14.0)
WALL3 = (14.0, 15.0)
CORR_C = (36.0, 39.0)        # inner ground ring corridor (DERIVED)
R_PRAE1 = (33.9, 35.5)       # praecinctio above the maenianum primum
R_PRAE2 = (16.9, 18.5)       # praecinctio above the maenianum secundum
R_WALL5 = (16.3, 16.9)       # 5 m wall behind the maenianum secundum (Platner-Ashby)
R_GALLERY = (1.8, 8.0)       # top gallery behind the wooden tier
R_TERRACE = (49.5, 52.5)     # podium terrace (senatorial seats)
Z_PODIUM = 3.8               # podium height: sources give 3.6-5 m
Z_IMA0 = Z_PODIUM
Z_MEDIA0 = 11.5       # 1.0 m balteus above the first praecinctio
Z_WOOD0 = 27.35
IMA_ROWS, MEDIA_ROWS, WOOD_ROWS = 16, 24, 11

AXIAL = {0: "porta_libitinensis", 20: "north_imperial", 40: "porta_triumphalis", 60: "south_box"}
T_STAIRS = (9, 13, 29, 33, 49, 53, 69, 73)   # tangential stairs level 3 -> gallery, 3 bays each


def bay_type(k):
    k %= BAYS
    if k in AXIAL:
        return "axis_major" if k in (0, 40) else "axis_minor"
    return "stair" if k % 4 == 2 else "passage"


def entrance_number(k):
    """Public entrance number 1..76 (0 for the four axial entrances).
    Count starts beside the southern axial entrance; the north entrance lies
    between XXXVIII and XXXIX (attested).  Direction of travel is an assumption."""
    k %= BAYS
    if k in AXIAL:
        return 0
    order = [j % BAYS for j in range(59, 59 - BAYS, -1) if (j % BAYS) not in AXIAL]
    return order.index(k) + 1


def roman(n):
    out = ""
    for v, s in ((50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")):
        while n >= v:
            out += s
            n -= v
    # the amphitheatre uses additive forms (e.g. XXXXV, LIIII)
    return out.replace("XL", "XXXX").replace("IX", "VIIII").replace("IV", "IIII")


def _stations():
    n = 40000
    pts = [(A * math.cos(i * math.tau / n), B * math.sin(i * math.tau / n)) for i in range(n + 1)]
    acc = [0.0]
    for i in range(n):
        acc.append(acc[-1] + math.dist(pts[i], pts[i + 1]))
    total = acc[-1]
    out = []
    j = 0
    for k in range(BAYS):
        target = ((k - 0.5) % BAYS) * total / BAYS
        while j > 0 and acc[j] > target:
            j -= 1
        while acc[j + 1] < target:
            j += 1
        f = (target - acc[j]) / (acc[j + 1] - acc[j])
        t = (j + f) * math.tau / n
        nx, ny = math.cos(t) / A, math.sin(t) / B
        m = math.hypot(nx, ny)
        out.append(((A * math.cos(t), B * math.sin(t)), (-nx / m, -ny / m)))
    return out, total


BOUND, PERIMETER = _stations()   # BOUND[k]: boundary between bay k-1 and bay k


def edge_point(k, r):
    (px, py), (nx, ny) = BOUND[k % BAYS]
    return (px + nx * r, py + ny * r)


def width(k, r):
    return math.dist(edge_point(k, r), edge_point(k + 1, r))


def bay_point(k, u, r):
    """u in 0..1 across bay k (counter-clockwise), r metres inward."""
    a = edge_point(k, r)
    b = edge_point(k + 1, r)
    return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)


def bay_frame(k):
    """Chord midpoint, unit tangent (ccw), unit inward normal and chord length of the facade bay."""
    a = edge_point(k, 0.0)
    b = edge_point(k + 1, 0.0)
    w = math.dist(a, b)
    tx, ty = (b[0] - a[0]) / w, (b[1] - a[1]) / w
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), (tx, ty), (-ty, tx), w


NOMINAL_W = sum(width(k, 0.0) for k in range(BAYS)) / BAYS


def cavea_z(r):
    """Walking-surface height of the seating bowl at radial depth r (None outside the bowl)."""
    if r > DEPTH or r < R_GALLERY[0]:
        return None
    if r >= R_TERRACE[0]:
        return Z_PODIUM
    if r >= R_PRAE1[1]:
        return Z_IMA0 + (R_TERRACE[0] - r) / (R_TERRACE[0] - R_PRAE1[1]) * (Z1 - Z_IMA0)
    if r >= R_PRAE1[0]:
        return Z1
    if r >= R_PRAE2[1]:
        return Z_MEDIA0 + (R_PRAE1[0] - r) / (R_PRAE1[0] - R_PRAE2[1]) * (Z2 - Z_MEDIA0)
    if r >= R_PRAE2[0]:
        return Z2
    if r >= R_WALL5[0]:
        return Z_WOOD0
    if r >= R_GALLERY[1]:
        return Z_WOOD0 + (R_WALL5[0] - r) / (R_WALL5[0] - R_GALLERY[1]) * (Z3 - Z_WOOD0)
    return Z3


TIERS = (
    # id, class, r_low(inner), r_high(outer), z0, z1, rows
    ("podium", "senatores", R_TERRACE[1], R_TERRACE[0], Z_PODIUM, Z_PODIUM, 2),
    ("maenianum_primum", "equites", R_TERRACE[0], R_PRAE1[1], Z_IMA0, Z1, IMA_ROWS),
    ("maenianum_secundum", "plebs", R_PRAE1[0], R_PRAE2[1], Z_MEDIA0, Z2, MEDIA_ROWS),
    ("maenianum_summum_in_ligneis", "pullati_et_feminae", R_WALL5[0], R_GALLERY[1], Z_WOOD0, Z3, WOOD_ROWS),
)


def to_godot(x, y, z):
    return (x, z, -y)


if __name__ == "__main__":
    print("perimeter", round(PERIMETER, 2), "bay", round(NOMINAL_W, 3),
          "arena axes", round(2 * (A - DEPTH), 1), round(2 * (B - DEPTH), 1),
          "inner widths", [round(width(0, r), 2) for r in (0, 15, 36, 49.5, 52.5)], [round(width(20, r), 2) for r in (0, 15, 36, 49.5, 52.5)])
    print([roman(entrance_number(k)) for k in (59, 41, 39, 21, 19, 1, 79, 61)])
