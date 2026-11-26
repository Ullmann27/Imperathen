#!/usr/bin/env python3
"""Seeded, data-only generator for the Colosseum piazza and its activity anchors.

Writes (Godot axes, metres, relative to the amphitheatre centre):
  prototype/assets/city/street_furniture/layouts/colosseum_piazza.json
  prototype/assets/city/street_furniture/layouts/republic_street_sample.json
  prototype/assets/city/activity_anchors/colosseum_piazza.json
  prototype/assets/city/activity_anchors/colosseum_interior.json
Deterministic: the same seed always gives byte-identical files.
"""
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "art/colosseum"))
import interior as I  # noqa: E402
import ring as R  # noqa: E402

SEED = 80
OPEN_END = 9999
FURN = ROOT / "prototype/assets/city/street_furniture"
ANCH = ROOT / "prototype/assets/city/activity_anchors"
CATALOG = json.loads((FURN / "street_furniture_catalog.json").read_text())["items"]
ERA_AMPHI = {"from_year": 80, "to_year": OPEN_END}
ALL_TIERS = ["poor", "common", "wealthy", "elite"]
rng = random.Random(SEED)
placed = []
entries = []
anchors_piazza = []
anchors_interior = []


def g(x, y, z=0.0):
    return [round(x, 3), round(z, 3), round(-y, 3)]


def out_point(k, u, r):
    """Point outside (r < 0) or inside the facade line of bay k."""
    return R.bay_point(k, u, r)


def yaw_towards(px, py, tx, ty):
    """Godot yaw (degrees) so that the item's front (+Z) looks from p to t (Blender coordinates)."""
    dx, dz = tx - px, -(ty - py)
    return round(math.degrees(math.atan2(dx, dz)), 2)


def place(item, x, y, yaw, scale=1.0, tint=None, era_id=None, check=True, pad=0.15):
    rad = CATALOG[item]["footprint_radius_m"] * scale
    if check and CATALOG[item]["solid"]:
        for (ox, oy, orad, oitem) in placed:
            if math.hypot(x - ox, y - oy) < rad + orad + pad:
                return False
        placed.append((x, y, rad, item))
    if tint is None:
        v = rng.uniform(0.9, 1.0)
        tint = [round(v * rng.uniform(0.97, 1.0), 3), round(v * rng.uniform(0.96, 1.0), 3), round(v * rng.uniform(0.93, 1.0), 3)]
    e = {"item": item, "position": g(x, y), "yaw_deg": yaw, "scale": round(scale, 3), "tint": tint}
    if era_id or CATALOG[item].get("era_id"):
        e["era_id"] = era_id or CATALOG[item]["era_id"]
    entries.append(e)
    return True


def anchor(target, aid, kind, pos, facing, capacity, hours, tiers, tags, era=None):
    target.append({"id": aid, "kind": kind, "position": pos, "facing_deg": facing, "capacity": capacity, "hours": hours,
                   "era": era or ERA_AMPHI, "wealth_tiers": tiers, "tags": tags})


def offset_walk(k0, k1, r, step):
    """Points every `step` metres along the offset curve at depth r between bays k0..k1."""
    pts = []
    carry = 0.0
    prev = None
    for k in range(k0, k1):
        for i in range(40):
            p = out_point(k, i / 40, r)
            if prev is not None:
                d = math.dist(prev, p)
                carry += d
                if carry >= step:
                    carry -= step
                    pts.append((p, k, i / 40))
            prev = p
    return pts


def centre_yaw(x, y):
    return yaw_towards(x, y, 0.0, 0.0)


def piazza():
    # boundary stones: two per bay on the edge of the travertine pavement
    for k in range(R.BAYS):
        for u in (0.25, 0.75):
            x, y = out_point(k, u, -17.5)
            place("cippus_amphitheatre", x, y, centre_yaw(x, y) + rng.uniform(-2.5, 2.5), rng.uniform(0.96, 1.04))
        if k % 5 == 3:
            x, y = out_point(k, 0.5, -17.95)
            place("drain_grate", x, y, centre_yaw(x, y), 1.0)
    # Meta Sudans (Domitianic) west-south-west of the building
    place("meta_sudans", -128.0, -34.0, 0.0, 1.0, tint=[1, 1, 1])
    anchor(anchors_piazza, "col.piazza.fountain.meta_sudans", "fountain", g(-128.0 + 8.9, -34.0), -90.0, 16, [5, 22], ALL_TIERS,
           ["meta_sudans", "water", "meeting_point"], {"from_year": 96, "to_year": OPEN_END})
    for i, a in enumerate((20, 140, 250)):
        ax, ay = -128.0 + 10.5 * math.cos(math.radians(a)), -34.0 + 10.5 * math.sin(math.radians(a))
        anchor(anchors_piazza, "col.piazza.gossip.meta_%d" % i, "gossip_spot", g(ax, ay), yaw_towards(ax, ay, -128.0, -34.0), 5, [7, 21], ALL_TIERS,
               ["meta_sudans", "idle"], {"from_year": 96, "to_year": OPEN_END})
    # honorific columns flanking the western (triumphal) and eastern approaches
    for k, tag in ((40, "porta_triumphalis"), (0, "porta_libitinensis")):
        for u in (-0.9, 1.9):
            x, y = out_point(k, u, -13.0)
            place("honorific_column_imperial", x, y, centre_yaw(x, y) + 180.0, rng.uniform(0.97, 1.03))
            ax, ay = out_point(k, u, -15.6)
            anchor(anchors_piazza, "col.piazza.gossip.column_%s_%s" % (tag, "a" if u < 0 else "b"), "gossip_spot", g(ax, ay), yaw_towards(ax, ay, x, y), 5,
                   [7, 21], ALL_TIERS, ["honorific_column", tag])
    # marble statues on bases along the pavement, turned outwards to the passers-by
    statue_bays = [5, 11, 15, 25, 29, 35, 45, 51, 55, 65, 69, 75]
    for i, k in enumerate(statue_bays):
        x, y = out_point(k, 0.5, -12.5 + rng.uniform(-0.8, 0.8))
        place("statue_marble_%d" % ((i * 3 + k) % 4), x, y, centre_yaw(x, y) + 180.0 + rng.uniform(-6, 6), rng.uniform(0.94, 1.06))
        ax, ay = out_point(k, 0.5, -15.2)
        anchor(anchors_piazza, "col.piazza.gossip.statue_%02d" % k, "gossip_spot", g(ax, ay), yaw_towards(ax, ay, x, y), 4, [7, 21], ALL_TIERS, ["statue", "idle"])
    # curved marble benches between the boundary stones, looking at the facade
    bench_bays = [3, 8, 13, 18, 23, 27, 33, 37, 43, 48, 53, 58, 63, 67, 73, 78]
    for k in bench_bays:
        x, y = out_point(k, 0.5, -15.9)
        if place("bench_marble_exedra", x, y, centre_yaw(x, y) + rng.uniform(-4, 4), rng.uniform(0.96, 1.04)):
            ax, ay = out_point(k, 0.5, -15.3)
            anchor(anchors_piazza, "col.piazza.bench.%02d" % k, "bench", g(ax, ay, 0.45), centre_yaw(x, y), 5, [6, 22], ALL_TIERS, ["marble_exedra", "shade_none"])
            lx, ly = out_point(k, 0.05, -15.0)
            place("shrub_laurel", lx, ly, rng.uniform(0, 360), rng.uniform(0.8, 1.15), check=False)
    # public basins on the street ring
    for i, k in enumerate((7, 31, 57, 71)):
        x, y = out_point(k, 0.3, -20.2)
        place("lacus_imperial", x, y, centre_yaw(x, y) + 180.0, 1.0)
        for du in (-0.02, 0.6):
            bx, by = out_point(k, du, -19.6)
            place("bollard_basalt", bx, by, rng.uniform(0, 360), rng.uniform(0.9, 1.1))
        ax, ay = out_point(k, 0.3, -22.0)
        anchor(anchors_piazza, "col.piazza.fountain.lacus_%d" % i, "fountain", g(ax, ay), yaw_towards(ax, ay, x, y), 4, [5, 21], ALL_TIERS, ["lacus", "water"])
    # shrines of the Lares Augusti north and south, with altars and cypresses
    for k, tag in ((22, "north"), (62, "south")):
        x, y = out_point(k, 0.5, -21.5)
        place("compital_shrine_imperial", x, y, centre_yaw(x, y) + 180.0, 1.0)
        ax, ay = out_point(k, 0.5, -24.3)
        anchor(anchors_piazza, "col.piazza.shrine.%s" % tag, "shrine", g(ax, ay), yaw_towards(ax, ay, x, y), 4, [5, 20], ALL_TIERS, ["lares_augusti", "offering"])
        for du in (-0.35, 1.35):
            cx, cy = out_point(k, du, -21.0)
            place("tree_cypress", cx, cy, rng.uniform(0, 360), rng.uniform(0.85, 1.1))
        bx, by = out_point(k, 1.1, -24.8)
        anchor(anchors_piazza, "col.piazza.beggar.shrine_%s" % tag, "beggar_spot", g(bx, by), yaw_towards(bx, by, 0, 0) + 180.0, 1, [6, 20], ["poor"], ["shrine", "alms"])
    place("sundial_column", *out_point(18, 0.5, -19.5), 0.0, 1.0)
    sx, sy = out_point(18, 0.5, -21.2)
    anchor(anchors_piazza, "col.piazza.gossip.sundial", "gossip_spot", g(sx, sy), yaw_towards(sx, sy, *out_point(18, 0.5, -19.5)), 3, [7, 19], ALL_TIERS, ["sundial", "time"])
    place("milestone_imperial", *out_point(42, 0.5, -31.0), centre_yaw(*out_point(42, 0.5, -31.0)) + 90.0, 1.0)
    # shaded porticoes on the north-east and south-east edges, with bars, signs and notices
    stall_index = 0
    for arc, (k0, k1) in enumerate(((3, 18), (62, 77))):
        pts = offset_walk(k0, k1, -36.0, 4.0)
        for j, ((x, y), k, u) in enumerate(pts):
            yaw = centre_yaw(x, y)
            place("portico_bay_imperial", x, y, yaw, 1.0, tint=[round(rng.uniform(0.93, 1.0), 3)] * 3, check=False)
            placed.append((x, y, 2.0, "portico"))
            if j % 6 == 2:
                tx, ty = out_point(k, u, -35.2)
                if place("thermopolium_counter", tx, ty, yaw + 180.0, 1.0, check=False):
                    ax, ay = out_point(k, u, -33.6)
                    anchor(anchors_piazza, "col.piazza.tavern.%d_%02d" % (arc, j), "tavern_seat", g(ax, ay), yaw_towards(ax, ay, tx, ty), 4, [9, 23],
                           ["poor", "common", "wealthy"], ["thermopolium", "portico", "shade"])
            if j % 6 == 5:
                ax, ay = out_point(k, u, -34.6)
                anchor(anchors_piazza, "col.piazza.gossip.portico_%d_%02d" % (arc, j), "gossip_spot", g(ax, ay), yaw + rng.uniform(-40, 40), 4, [7, 22], ALL_TIERS,
                       ["portico", "shade"])
            if j % 4 == 1:
                wx, wy = out_point(k, u, -37.55)
                place(rng.choice(["dipinto_0", "dipinto_1", "dipinto_2"]), wx, wy, yaw, 1.0, check=False)
            if j % 5 == 3:
                wx, wy = out_point(k, u, -34.45)
                place("shop_sign_%d" % rng.randrange(3), wx, wy, yaw, 1.0, check=False)
            if j % 7 == 4:
                wx, wy = out_point(k, u, -34.4)
                place("garland_swag", wx, wy, yaw, 1.0, check=False)
            if j % 9 == 6:
                wx, wy = out_point(k, u, -35.0)
                place("bench_wood", wx, wy, yaw, 1.0, check=False)
                anchor(anchors_piazza, "col.piazza.bench.portico_%d_%02d" % (arc, j), "bench", g(wx, wy, 0.48), yaw, 3, [6, 22], ALL_TIERS, ["portico", "shade"])
    # vendors along the outer edge of the street ring, in seeded clusters near the public entrances
    for k0 in (9, 12, 15, 26, 33, 36, 46, 49, 52, 66, 69, 72):
        u = rng.uniform(0.2, 0.8)
        x, y = out_point(k0, u, -28.0 + rng.uniform(-0.6, 0.6))
        name = "stall_masonry_%d" % (stall_index % 3)
        if place(name, x, y, centre_yaw(x, y) + rng.uniform(-10, 10), rng.uniform(0.95, 1.05)):
            ax, ay = out_point(k0, u, -29.0)
            anchor(anchors_piazza, "col.piazza.stall.%02d" % stall_index, "stall", g(ax, ay), centre_yaw(x, y), 1, [6, 19], ["poor", "common"],
                   ["vendor", ("bread_fruit", "oil_wine", "textiles_pottery")[stall_index % 3]])
            cx, cy = out_point(k0, u, -26.0)
            anchor(anchors_piazza, "col.piazza.queue.stall_%02d" % stall_index, "queue", g(cx, cy), yaw_towards(cx, cy, x, y), 3, [6, 19], ALL_TIERS,
                   ["customer", "stall"])
            for _ in range(rng.randrange(1, 3)):
                gx, gy = out_point(k0, u + rng.uniform(-0.35, 0.35), -29.6 + rng.uniform(-0.4, 0.4))
                place(rng.choice(["amphora_group", "dolium"]), gx, gy, rng.uniform(0, 360), rng.uniform(0.85, 1.1))
            stall_index += 1
    # carts wait on the basalt ring where goods are unloaded
    for i, k in enumerate((20, 44, 60, 76)):
        x, y = out_point(k, 0.5 if k not in (20, 60) else 2.6, -24.0)
        place("cart_plaustrum", x, y, centre_yaw(x, y) + 90.0 + rng.uniform(-12, 12), 1.0)
        anchor(anchors_piazza, "col.piazza.cart.%d" % i, "cart_stop", g(x, y), centre_yaw(x, y) + 90.0, 2, [5, 10], ["poor", "common"], ["delivery", "ox_cart"])
    # cressets at the four axial entrances
    for k in R.AXIAL:
        for u in (-0.25, 1.25):
            x, y = out_point(k, u, -6.5)
            place("torch_post", x, y, 0.0, 1.0)
    # planting: umbrella pines and cypresses beyond the street, laurel between
    tries = 0
    count = 0
    while count < 34 and tries < 4000:
        tries += 1
        k = rng.randrange(R.BAYS)
        if 3 <= k < 18 or 62 <= k < 77:
            r = -rng.uniform(44.0, 62.0)
        else:
            r = -rng.uniform(34.0, 60.0)
        x, y = out_point(k, rng.random(), r)
        if math.hypot(x + 128.0, y + 34.0) < 16.0:
            continue
        name = "tree_stone_pine" if rng.random() < 0.6 else "tree_cypress"
        if place(name, x, y, rng.uniform(0, 360), rng.uniform(0.8, 1.2), tint=[round(rng.uniform(0.85, 1.0), 3), round(rng.uniform(0.9, 1.0), 3), round(rng.uniform(0.85, 1.0), 3)]):
            count += 1
            if name == "tree_stone_pine" and count % 4 == 0:
                anchor(anchors_piazza, "col.piazza.gossip.pine_%02d" % count, "gossip_spot", g(x + 1.6, y + 1.2), rng.uniform(-180, 180), 4, [8, 20], ALL_TIERS, ["shade", "tree"])
    # open spots: children's games, loiterers, beggars at the busiest arches
    for i, k in enumerate((6, 16, 24, 34, 47, 56, 64, 74)):
        x, y = out_point(k, 0.5, -9.0 + rng.uniform(-1.5, 1.5))
        anchor(anchors_piazza, "col.piazza.play.%d" % i, "play_spot", g(x, y), rng.uniform(-180, 180), 5, [9, 18], ["poor", "common"], ["children", "nuts_game", "open_paving"])
    for i, k in enumerate((2, 10, 14, 21, 28, 38, 42, 50, 59, 68, 72, 77)):
        x, y = out_point(k, rng.uniform(0.2, 0.8), -6.0 + rng.uniform(-1.2, 1.2))
        anchor(anchors_piazza, "col.piazza.gossip.arcade_%02d" % k, "gossip_spot", g(x, y), rng.uniform(-180, 180), rng.randrange(3, 6), [7, 21], ALL_TIERS, ["arcade_front", "idle"])
    for i, k in enumerate((19, 23, 39, 43, 61, 79)):
        x, y = out_point(k, 0.02, -1.9)
        anchor(anchors_piazza, "col.piazza.beggar.%d" % i, "beggar_spot", g(x, y), centre_yaw(x, y) + 180.0, 1, [6, 20], ["poor"], ["pier", "alms"])


def interior():
    for k in range(R.BAYS):
        n = R.entrance_number(k)
        label = R.roman(n) if n else R.AXIAL[k]
        (cx, cy), (tx, ty), (nx, ny), w = R.bay_frame(k)
        inward = round(math.degrees(math.atan2(nx, -ny)), 2)
        outward = round(math.degrees(math.atan2(-nx, ny)), 2)
        tags = ["numbered", label] if n else ["axial", label]
        tiers = ALL_TIERS if n else (["elite"] if k == 20 else ["wealthy", "elite"])
        x, y = R.bay_point(k, 0.5, 1.35)
        anchor(anchors_interior, "col.entrance.%s" % label, "entrance", g(x, y), inward, 6, [6, 20], tiers, tags + ["open_daily"])
        if n:
            x, y = R.bay_point(k, 0.5, -4.5)
            anchor(anchors_interior, "col.queue.%s" % label, "queue", g(x, y), inward, 12, [7, 16], ALL_TIERS, ["entrance:" + label, "event_day"])
        else:
            for i, u in enumerate((0.12, 0.88)):
                x, y = R.bay_point(k, u, -1.4)
                anchor(anchors_interior, "col.guard.%s_%d" % (label, i), "guard_post", g(x, y), outward, 1, [0, 24], ["common"], ["axial_entrance", label])
        # seat blocks per tier and class
        for tid, cls, r_in, r_out, z0, z1, rows in R.TIERS:
            rm = (r_in + r_out) / 2
            iv = I.surface_intervals(k, rm, 0.9 / R.width(k, rm) if tid != "podium" else 0.0)
            if tid == "podium" and R.bay_type(k) == "axis_minor":
                iv = [(0.1, 0.9)]
            if not iv:
                continue
            a, b = max(iv, key=lambda q: q[1] - q[0])
            width = (b - a) * R.width(k, rm)
            if width < 0.9:
                continue
            x, y = R.bay_point(k, (a + b) / 2, rm)
            z = R.cavea_z(rm) if not (tid == "podium" and R.bay_type(k) == "axis_minor") else R.Z_PODIUM + 0.8
            wealth = {"senatores": ["elite"], "equites": ["wealthy", "elite"], "plebs": ["common", "wealthy"], "pullati_et_feminae": ["poor", "common"]}[cls]
            access = "level1" if tid in ("podium", "maenianum_primum") else ("level2" if tid == "maenianum_secundum" else "gallery")
            extra = []
            if tid == "podium" and k == 20:
                extra, wealth = ["pulvinar", "imperial_box"], ["elite"]
            elif tid == "podium" and k == 60:
                extra = ["magistrates_box"]
            if tid in ("maenianum_primum", "maenianum_secundum") and k % 8 == 3:
                extra.append("open_daily")      # visitors sit here on days without games
            capacity = max(2, int(width / 0.45)) * rows
            anchor(anchors_interior, "col.seat.%s.b%02d" % (tid, k), "seat_block", g(x, y, z), inward, capacity, [8, 18], wealth,
                   [tid, cls, "bay:%d" % k, "access:" + access, "rows:%d" % rows, "event_day"] + extra)
    # guards: arena gates, imperial box, level-2 landings
    for k, name in ((0, "porta_libitinensis"), (40, "porta_triumphalis")):
        s = 1 if k == 0 else -1
        for i, side in enumerate((-1, 1)):
            anchor(anchors_interior, "col.guard.arena_%s_%d" % (name, i), "guard_post", g(s * (R.A - R.DEPTH - 2.0), side * 3.4), 90.0 * -s, 1, [0, 24], ["common"],
                   ["arena_gate", name])
    for i, u in enumerate((0.15, 0.85)):
        x, y = R.bay_point(20, u, 46.5)
        anchor(anchors_interior, "col.guard.pulvinar_%d" % i, "guard_post", g(x, y, R.Z_PODIUM), 0.0, 1, [6, 20], ["common"], ["imperial_box", "praetorian"])
    for k in range(4, R.BAYS, 10):
        x, y = R.bay_point(k, 0.5, 11.8)
        anchor(anchors_interior, "col.guard.level2_b%02d" % k, "guard_post", g(x, y, R.Z1), 0.0, 1, [7, 18], ["common"], ["corridor", "level2", "event_day"])
    # places to linger inside on quiet days: corridor benches of the ground ambulatory, arena rail
    for k in range(5, R.BAYS, 6):
        if k in R.AXIAL:
            continue
        x, y = R.bay_point(k, 0.5, 5.2)
        anchor(anchors_interior, "col.gossip.ambulatory_b%02d" % k, "gossip_spot", g(x, y), 0.0, 4, [7, 20], ALL_TIERS, ["ambulatory", "shade", "open_daily"])
    for k in (27, 31, 51, 67):
        if I.reaches_ima(k):
            x, y = R.bay_point(k, 0.5, 51.0)
            (cx, cy), (tx, ty), (nx, ny), w = R.bay_frame(k)
            anchor(anchors_interior, "col.gossip.podium_rail_b%02d" % k, "gossip_spot", g(x, y, R.Z_PODIUM), round(math.degrees(math.atan2(nx, -ny)), 2), 3,
                   [8, 18], ["wealthy", "elite"], ["podium", "view_arena", "open_daily"])


def republic_sample():
    """A 64 m stretch of a late-republican street (two shop fronts), for the kit showcase and tests."""
    global entries, placed
    saved = (entries, placed)
    entries, placed = [], []
    r = random.Random(58)
    for side, yv in ((1, 4.2), (-1, -4.2)):
        yaw = 180.0 if side > 0 else 0.0
        for i in range(16):
            x = -30.0 + i * 4.0
            place("portico_bay_republic" if (i // 4) % 2 == 0 else "shop_shutter", x, yv + (1.4 if (i // 4) % 2 == 0 else 0.6) * side, yaw, 1.0, check=False,
                  tint=[round(r.uniform(0.9, 1.0), 3)] * 3)
            if i % 4 == 1:
                place("shop_awning", x, yv + 0.5 * side, yaw, 1.0, check=False)
            if i % 5 == 2:
                place("shop_sign_%d" % r.randrange(3), x + 1.0, yv + 0.45 * side, yaw, 1.0, check=False)
            if i % 3 == 0:
                place("dipinto_%d" % r.randrange(2), x - 1.0, yv + 0.9 * side, yaw, 1.0, check=False)
    place("compital_shrine_republic", 0.0, 3.3, 180.0, 1.0)
    place("lacus_republic", 14.0, -3.1, 0.0, 1.0)
    place("bollard_basalt", 15.3, -2.2, 0.0, 1.0)
    place("bollard_basalt", 12.7, -2.2, 0.0, 1.0)
    for x in (-22.0, 6.0, 26.0):
        place("stepping_stones", x, 0.0, 90.0, 1.0)
    place("milestone_republic", -29.0, -3.3, 0.0, 1.0)
    place("columna_rostrata", -12.0, -3.0, 0.0, 1.0)
    place("statue_bronze_1", 22.0, 3.2, 180.0, 1.0)
    place("statue_bronze_2", -24.0, 3.2, 180.0, 1.0)
    place("sundial_column", 8.0, 3.3, 180.0, 1.0)
    place("altar_tuff", 0.0, 1.9, 180.0, 1.0, check=False)
    for i, x in enumerate((-17.0, -6.0, 3.5, 18.0)):
        place("stall_wood_%d" % (i % 3), x, -2.6 if i % 2 else 2.6, 0.0 if i % 2 else 180.0, r.uniform(0.95, 1.05))
    for x, yv in ((-15.0, 3.4), (10.5, -3.4), (27.5, 3.4)):
        place("bench_wood" if x < 0 else "bench_tuff", x, yv, 180.0 if yv > 0 else 0.0, 1.0)
    for _ in range(7):
        place(r.choice(["amphora_group", "dolium"]), r.uniform(-28, 28), r.choice([-3.5, 3.5]) + r.uniform(-0.2, 0.2), r.uniform(0, 360), r.uniform(0.85, 1.1))
    place("cart_plaustrum", -3.0, -0.8, 80.0, 1.0)
    place("garland_swag", 0.0, 3.6, 180.0, 1.0, check=False)
    place("torch_post", 2.2, 3.0, 0.0, 1.0)
    sample = entries
    entries, placed = saved
    return sample


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1) + "\n")


def main():
    piazza()
    interior()
    head = {"format": "imperathen-street-furniture-layout", "schema": 1, "seed": SEED,
            "frame": "metres in Godot axes relative to the layout origin; yaw_deg rotates the item front (+Z) about Y"}
    write(FURN / "layouts/colosseum_piazza.json", {**head, "area": "colosseum_piazza", "era_set": "imperial", "entries": entries})
    write(FURN / "layouts/republic_street_sample.json", {**head, "seed": 58, "area": "republic_street_sample", "era_set": "late_republic",
                                                         "street_axis": "X", "entries": republic_sample()})
    ahead = {"format": "imperathen-activity-anchors", "schema": 1, "seed": SEED,
             "frame": "metres in Godot axes relative to the amphitheatre centre (monument root node)",
             "facing_convention": "facing_deg is the Godot yaw about Y: 0 looks along +Z, 90 along +X",
             "year_convention": "historical signed integers, no year 0; to_year 9999 means open-ended",
             "wealth_tier_values": ALL_TIERS,
             "tag_notes": {"event_day": "used only on days with games", "open_daily": "also used on days without games",
                           "access:*": "which circulation level serves the seat block"}}
    write(ANCH / "colosseum_piazza.json", {**ahead, "area": "colosseum_piazza", "anchors": anchors_piazza})
    write(ANCH / "colosseum_interior.json", {**ahead, "area": "colosseum_interior", "anchors": anchors_interior})
    kinds = {}
    for a in anchors_piazza + anchors_interior:
        kinds[a["kind"]] = kinds.get(a["kind"], 0) + 1
    print("DISTRICT_GENERATED", json.dumps({"furniture": len(entries), "anchors": len(anchors_piazza) + len(anchors_interior), "kinds": kinds}, sort_keys=True))


main()
