"""Assemble one figure from its registry entry (body, face, garments, grooming)."""
from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Vector

import figure as F
import grooming as G
import materials as M
import surfaces as S
import tailoring as T


def _skin(spec, seed, body, extra_masks):
    """Per-figure copy of the vendored CC0 male skin with tone and marks."""
    image = bpy.data.images.load(str(F.MALE_SKIN), check_existing=True)
    w, h = image.size
    buffer = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(buffer)
    pixels = buffer.reshape(h, w, 4).astype(np.float64)
    step = max(1, w // 1024)
    albedo = pixels[::step, ::step, :3].copy()
    albedo = S.skin_variant(albedo, seed, tuple(spec.get("tone", (1, 1, 1))), spec.get("weather", 0.0),
                            spec.get("freckles", 0.0))
    for colour, strength, vertex_set, radius in extra_masks:
        albedo = G.paint_region(albedo, body, vertex_set, colour, strength, seed + 7, radius)
    mat = bpy.data.materials["HeroSkin"].copy()
    mat.name = "GermanicSkin"
    shader = mat.node_tree.nodes.get("Principled BSDF")
    for link in mat.node_tree.links:
        if link.to_socket == shader.inputs["Base Color"] and link.from_node.type == "TEX_IMAGE":
            link.from_node.image = M.image("GermanicSkin_albedo", np.clip(albedo, 0, 1))
    return mat


def _scar_vertices(index, lm, scar):
    """Body vertices along a scar line given relative to the eye centre."""
    eye = lm["eye"]
    a = eye + Vector(scar["from"])
    b = eye + Vector(scar["to"])
    found = set()
    for s in range(24):
        p = a.lerp(b, s / 23)
        for _, i, d in index.tree.find_n(p, 3):
            if i in lm["head"]:
                found.add(i)
    return found


def build_figure(spec, family, group, seed):
    anatomy = F.Anatomy.get()
    M.reset()
    arm, body, eyes, marks = F.open_base(anatomy)
    report = {"id": spec["id"]}
    report["ground"] = F.ground_feet(body, eyes, arm)
    frames = F.grip_hands(body, marks, spec.get("hands", {"L": "fist", "R": "fist"}))
    F.shape_body(body, arm, spec["body"])
    F.shape_face(body, marks, spec["face"])
    index = T.BodyIndex(body)
    lm = G.face_landmarks(index, marks)
    cloth = spec["clothing"]
    covered = set()
    parts = {}
    rows = index.weights
    joints = {name: (arm.data.bones[name].head_local.copy(), arm.data.bones[name].tail_local.copy())
              for name in arm.data.bones.keys()}
    waist = joints["Spine"][0].z
    neck = joints["Head"][0].z
    ankle = joints["Foot_L"][0].z
    fold_rng = np.random.default_rng(seed)

    def wave(p, amount, scale=1.0):
        return amount * (math.sin(p.z * 61 * scale + p.x * 23) * .5 + math.sin(p.z * 23 * scale - p.y * 41) * .5)

    # Trousers ---------------------------------------------------------------
    if "trousers" in cloth:
        tr = cloth["trousers"]
        mat = M.cloth("Trousers", tr, seed + 1)
        hem = ankle + tr.get("hem_above_ankle", .035)
        top = waist + .025

        def sel(i, p, bone):
            return bone in ("Pelvis", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R") and p.z < top + .02

        def off(p, n, bone):
            knee = math.exp(-((p.z - .49) / .05) ** 2)
            low = max(0.0, min(1.0, (.32 - p.z) / .2))
            return tr.get("ease", .011) + .006 * knee + .006 * low + wave(p, .0025)

        def uv(p, i):
            side = "L" if p.x > 0 else "R"
            if p.z > waist - .06:
                return T._cylinder_uv(p, Vector((0, 0, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)), .25, 4)[0], p.z / .25, 4
            a, b = joints["Thigh_" + side][0], joints["Shin_" + side][1]
            axis = (a - b).normalized()
            uu, vv = T._cylinder_uv(p, b, axis, Vector((1, 0, 0)), .25, 2)
            return uu, vv, 2

        obj, cov = T.region_garment("Trousers", index, arm, sel, off, mat,
                                     cuts=[((0, 0, top), (0, 0, 1)), ((0, 0, hem), (0, 0, -1))], uv=uv)
        parts["trousers"] = obj
        covered |= cov

    # Shoes ---------------------------------------------------------------------
    if "shoes" in cloth:
        sh = cloth["shoes"]
        mat = M.named("Shoes", "leather", seed + 2, colour=sh["colour"], worn=.6)
        top = ankle + sh.get("height", .045)
        lace = M.named("ShoeLace", "leather", seed + 31, size=256, colour="2e2014", worn=.3)
        for side in ("L", "R"):
            foot_pts = T.gather_points([body], lambda p, row, side=side: p.z < top + .03 and max(row, key=row.get) in ("Foot_" + side, "Shin_" + side))
            heights = [0.0, .012, .03, .05, .075, .10, top - .02, top]
            parts["shoe_" + side] = T.hull_loft("Shoe_" + side, arm, index, foot_pts, heights, mat, ease=.006,
                                               bones=("Foot_" + side, "Shin_" + side))
            ring = [v.co.copy() for v in parts["shoe_" + side].data.vertices[-40:]]
            centre = sum(ring, Vector()) / len(ring)
            path = [centre + (p - centre) * 1.04 + Vector((0, 0, -.012)) for p in ring[::2]] 
            path.append(path[0])
            parts["lace_" + side] = T.tube("ShoeLace_" + side, arm, path, [.0035] * len(path), lace,
                                           [index.nearest_weights(p, 4, ("Shin_" + side, "Foot_" + side)) for p in path],
                                           sides=6, tile=.03, caps=False)
        foot_cov = {i for i, p in enumerate(index.points) if p.z < top - .01 and index.dominant(i) in ("Foot_L", "Foot_R", "Shin_L", "Shin_R")}
        covered |= foot_cov

    # Tunic body and sleeves ----------------------------------------------------
    if "tunic" in cloth:
        tu = cloth["tunic"]
        mat = M.cloth("Tunic", tu, seed + 3)
        sleeve = tu.get("sleeve", 1.0)  # fraction from shoulder to wrist
        cuts = [((0, 0, neck + .012), (0, 0, 1)), ((0, 0, waist - .035), (0, 0, -1))]
        for side in ("L", "R"):
            a, b = joints["Arm_" + side][0], joints["Forearm_" + side][1]
            if sleeve >= .99:
                point = b + (a - b).normalized() * .025
            else:
                upper = joints["Arm_" + side][1] - a
                lower = b - joints["Forearm_" + side][0]
                total = upper.length + lower.length
                d = sleeve * total
                point = a + upper.normalized() * d if d <= upper.length else joints["Forearm_" + side][0] + lower.normalized() * (d - upper.length)
            normal = (b - a).normalized() if sleeve >= .99 else ((joints["Arm_" + side][1] - a).normalized()
                                                                 if sleeve * 2 < 1 else (b - joints["Forearm_" + side][0]).normalized())
            cuts.append((tuple(point), tuple(normal), 1 if side == "L" else -1))

        def sel(i, p, bone):
            if bone in ("Arm_L", "Arm_R", "Forearm_L", "Forearm_R"):
                return True
            return bone in ("Spine", "Pelvis") and waist - .08 < p.z < neck + .03

        def off(p, n, bone):
            extra = .004 if bone.startswith("Forearm") else 0.0
            blouse = .010 * math.exp(-((p.z - (waist + .03)) / .04) ** 2)
            return tu.get("ease", .016) + extra + blouse + wave(p, .002, 1.3)

        def uv(p, i):
            _, ii, _ = index.tree.find(p)
            bone = index.dominant(ii)
            if bone.startswith(("Arm", "Forearm")):
                side = bone[-1]
                a, b = joints["Arm_" + side][0], joints["Forearm_" + side][1]
                uu, vv = T._cylinder_uv(p, a, (b - a).normalized(), Vector((0, 1, 0)), .22, 2)
                return uu, vv, 2
            uu, vv = T._cylinder_uv(p, Vector((0, -.01, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)), .22, 5)
            return uu, p.z / .22, 5

        obj, cov = T.region_garment("Tunic", index, arm, sel, off, mat, cuts=cuts, uv=uv)
        parts["tunic"] = obj
        covered |= cov
        under = [parts.get("trousers", body)]
        hem = tu.get("hem", .66)
        skirt = T.skirt("TunicSkirt", arm, index, under, waist - .005, hem, tu.get("skirt_ease", .028), mat,
                        tu.get("thigh_share", .62), seed=seed + 4)
        parts["tunic_skirt"] = skirt
        if tu.get("trim"):
            trim_mat = M.cloth("Trim", {"colour": tu["trim"], "weave": "tabby", "threads": 40,
                                        "check": {"colour": tu.get("trim_accent", "2a2622"), "band": 2, "period": 6}}, seed + 30, 256)
            loops = T.boundary_loops(skirt)
            hem_loop = min(loops, key=lambda lp: sum(skirt.data.vertices[i].co.z for i in lp) / len(lp))
            parts["trim_hem"] = T.trim_loop("TrimHem", arm, skirt, hem_loop, trim_mat, radius=.010, out=.002)
            for k, loop in enumerate(T.boundary_loops(obj)):
                cz = sum(obj.data.vertices[i].co.z for i in loop) / len(loop)
                cx = sum(obj.data.vertices[i].co.x for i in loop) / len(loop)
                if abs(cx) > .15 and cz < 1.30 and len(loop) > 12:
                    parts[f"trim_cuff_{k}"] = T.trim_loop(f"TrimCuff{k}", arm, obj, loop, trim_mat, radius=.008, out=.002)
            neck_loops = [lp for lp in T.boundary_loops(obj) if sum(obj.data.vertices[i].co.z for i in lp) / len(lp) > neck - .03]
            if neck_loops:
                parts["trim_neck"] = T.trim_loop("TrimNeck", arm, obj, max(neck_loops, key=len), trim_mat, radius=.007, out=.001)
            for key in [k for k, v in parts.items() if v is None]:
                del parts[key]

    # Mail shirt (rare) -------------------------------------------------------------
    if "mail" in cloth:
        ml = cloth["mail"]
        mat = M.mail("Mail", seed + 32)
        sleeve_cuts = []
        for side in ("L", "R"):
            a, b = joints["Arm_" + side]
            sleeve_cuts.append((tuple(a + (b - a) * .42), tuple((b - a).normalized()), 1 if side == "L" else -1))
        base = .016 + (cloth.get("tunic", {}).get("ease", .016))

        def sel(i, p, bone):
            if bone in ("Arm_L", "Arm_R"):
                return True
            return bone in ("Spine", "Pelvis") and waist - .08 < p.z < neck + .03

        def off(p, n, bone):
            return base + .006 * math.exp(-((p.z - (waist + .03)) / .04) ** 2)

        def uv(p, i):
            return T._cylinder_uv(p, Vector((0, -.01, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)), .12, 8)[0], p.z / .12, 8

        obj, _ = T.region_garment("Mail", index, arm, sel, off, mat, cuts=[((0, 0, neck - .006), (0, 0, 1)),
                                  ((0, 0, waist - .035), (0, 0, -1))] + sleeve_cuts, uv=uv)
        parts["mail"] = obj
        under = [o for o in (parts.get("tunic_skirt"), parts.get("trousers")) if o]
        parts["mail_skirt"] = T.skirt("MailSkirt", arm, index, under, waist - .005, ml.get("hem", .84), .012, mat,
                                      .55, seed=seed + 33, fold=.003, tile=.12)

    # Belt ----------------------------------------------------------------------
    if "belt" in cloth:
        bl = cloth["belt"]
        mat = M.named("Belt", "leather", seed + 5, colour=bl["colour"], worn=.5)
        objs = [o for o in (parts.get("mail"), parts.get("mail_skirt"), parts.get("tunic"), parts.get("tunic_skirt"), parts.get("trousers")) if o] or [body]
        z0 = waist - .045
        parts["belt"] = T.loft_ring("Belt", arm, index, objs, z0, z0 + bl.get("width", .038), mat, ease=.004)
        if bl.get("buckle"):
            metal = M.named("BeltMetal", bl["buckle"], seed + 6, size=256)
            front = min((v.co for v in parts["belt"].data.vertices if abs(v.co.x) < .02), key=lambda c: c.y)
            parts["buckle"] = T.tube("BeltRing", arm, [front + Vector((-.016, -.004, .019)), front + Vector((.016, -.004, .019))],
                                     [.012, .012], metal, [{"Pelvis": .6, "Spine": .4}] * 2, sides=12, tile=.02, flatten=.35)

    # Leg wraps -------------------------------------------------------------------
    if "leg_wraps" in cloth:
        lw = cloth["leg_wraps"]
        mat = M.cloth("LegWraps", lw, seed + 7)
        under = [o for o in (parts.get("trousers"), body) if o]
        for side in ("L", "R"):
            a = joints["Shin_" + side][1]
            b = joints["Shin_" + side][0]
            parts["wrap_" + side] = T.spiral_wrap("LegWrap_" + side, arm, index, [under[0]], a, b,
                                                  ankle + .03, lw.get("top", .42), mat, side=side,
                                                  turns=lw.get("turns", 7))

    # Cloak / pelt --------------------------------------------------------------
    shoulder = joints["Arm_L"][0].z
    torso_parts = [o for o in (parts.get("mail"), parts.get("mail_skirt"), parts.get("tunic"), parts.get("tunic_skirt"), parts.get("belt")) if o]
    drape_points = np.concatenate([
        T.gather_points([body], lambda p, row: max(row, key=row.get) in ("Spine", "Pelvis", "Head")
                        or (p.z > shoulder - .07 and max(row, key=row.get).startswith("Arm"))),
        T.gather_points(torso_parts, lambda p, row: max(row, key=row.get) in ("Spine", "Pelvis", "Thigh_L", "Thigh_R")
                        or p.z > shoulder - .07) if torso_parts else np.zeros((0, 3))])
    with_arms = np.concatenate([drape_points] + [T.gather_points(
        [o for o in (parts.get("mail"), parts.get("tunic"), body) if o],
        lambda p, row: max(row, key=row.get).startswith("Arm"))])
    if "cloak" in cloth:
        ck = cloth["cloak"]
        mat = M.cloth("Cloak", ck, seed + 8)
        top_span = [math.radians(x) for x in ck.get("top_span", (-38, 218))]
        low_span = [math.radians(x) for x in ck.get("low_span", (18, 162))]

        def span(t, top_span=top_span, low_span=low_span):
            u = min(1.0, t / .28)
            u = u * u * (3 - 2 * u)
            return (top_span[0] + (low_span[0] - top_span[0]) * u, top_span[1] + (low_span[1] - top_span[1]) * u)

        def hem_curve(a):
            return -.035 * max(0.0, math.sin(a)) ** 2

        parts["cloak"] = T.cape("Cloak", arm, index, drape_points, mat, neck - .004, ck.get("hem", .95), span,
                                thickness=ck.get("thickness", .006), ease=ck.get("ease", .012), drape=ck.get("drape", .07),
                                follow_arms=ck.get("follow_arms", .45), seed=seed + 9, hem_curve=hem_curve, rows=18, columns=56,
                                points_upper=with_arms, collide=[o for o in (body, parts.get("tunic"), parts.get("mail"),
                                                                             parts.get("tunic_skirt"), parts.get("mail_skirt"),
                                                                             parts.get("belt")) if o])
        if ck.get("brooch"):
            metal = M.named("Brooch", ck["brooch"], seed + 10, size=256)
            verts = [v.co.copy() for v in parts["cloak"].data.vertices[:56 * 3]]
            pin = min(verts, key=lambda c: (c - Vector((-.11, -.13, neck - .045))).length)
            out = Vector((pin.x, pin.y, 0)).normalized()
            parts["brooch"] = T.tube("Brooch", arm, [pin + out * .003, pin + out * .013],
                                     [.021, .017], metal, [{"Spine": 1.0}] * 2, sides=16, tile=.02)
    if "pelt" in cloth:
        pl = cloth["pelt"]
        mat = M.named("Pelt", "fur", seed + 11, colour=pl["colour"], tip=pl.get("tip"))

        def pelt_span(t):
            return (math.radians(-68 + 10 * t), math.radians(248 - 10 * t))

        parts["pelt"] = T.cape("Pelt", arm, index, drape_points, mat, neck - .002, pl.get("hem", 1.17), pelt_span,
                               thickness=pl.get("thickness", .016), ease=.010, drape=.015, follow_arms=.6,
                               seed=seed + 12, fold=.010, rows=10, columns=56, points_upper=with_arms,
                               collide=[o for o in (body, parts.get("tunic"), parts.get("mail"), parts.get("cloak")) if o])

    # Arm rings ---------------------------------------------------------------------
    if "arm_rings" in cloth:
        ar = cloth["arm_rings"]
        metal = M.named("ArmRing", ar.get("metal", "bronze"), seed + 34, size=256)
        sleeve = parts.get("tunic") or body
        for side in ar.get("sides", ["R"]):
            a, b = joints["Forearm_" + side]
            centre = a + (b - a) * .55
            axis = (b - a).normalized()
            ref = axis.cross(Vector((0, 0, 1))).normalized()
            other = axis.cross(ref).normalized()
            radius = .03
            for v in sleeve.data.vertices:
                d = v.co - centre
                along = d.dot(axis)
                radial = (d - axis * along).length
                if abs(along) < .02 and radial < .085:
                    radius = max(radius, radial)
            radius += .005
            path = [centre + (ref * math.cos(k * math.tau / 20) + other * math.sin(k * math.tau / 20)) * radius for k in range(21)]
            parts["ring_" + side] = T.tube("ArmRing_" + side, arm, path, [.0055] * 21, metal,
                                           [{"Forearm_" + side: 1.0}] * 21, sides=8, tile=.02, caps=False)

    # Hair and beard ------------------------------------------------------------
    hair_spec = spec["hair"]
    hair_mat = M.named("Hair", "hair", seed + 13, colour=hair_spec["colour"], grey=hair_spec.get("grey", 0.0))
    tie_mat = M.named("HairTie", "leather", seed + 14, size=256, colour="3b2a1c", worn=.2)
    knot_anchor = None
    style = hair_spec["style"]
    if style == "knot":
        pieces, knot_anchor = G.knot_geometry("HairKnot", arm, lm, hair_mat, side=-1)
        for k, piece in enumerate(pieces):
            parts[f"knot_{k}"] = piece
    parts["scalp"] = G.scalp("Scalp", arm, index, lm, hair_mat, style, hair_spec.get("thickness", .006),
                             hair_spec.get("recede", 0.0), knot_anchor)
    if style == "tied":
        for k, piece in enumerate(G.nape_tail("HairTail", arm, lm, hair_mat, hair_spec.get("length", .17), tie_mat)):
            parts[f"tail_{k}"] = piece
    if style == "braids":
        for k, piece in enumerate(G.braids("HairBraid", arm, lm, hair_mat, tie_mat, hair_spec.get("length", .26))):
            parts[f"braid_{k}"] = piece
    if style == "long":
        neck_points = T.gather_points([body], lambda p, row: p.z > shoulder - .05 and max(row, key=row.get) in ("Head", "Spine"))
        parts["hair_fall"] = T.cape("HairFall", arm, index, neck_points, hair_mat, lm["eye"].z - .005,
                                    hair_spec.get("hem", 1.40), lambda t: (math.radians(8 + 12 * t), math.radians(172 - 12 * t)),
                                    thickness=.010, ease=.004, drape=.008, follow_arms=0.0, seed=seed + 15,
                                    fold=.011, centre=(0.0, lm["centre"].y), head=True, rows=10, columns=40,
                                    pleats=9, collide=[body] + [o for o in (parts.get("tunic"), parts.get("cloak"), parts.get("pelt")) if o])
    beard_spec = spec.get("beard", {"style": "none"})
    stubble = None
    if beard_spec["style"] not in ("none",):
        beard_mat = M.named("Beard", "hair", seed + 16, colour=beard_spec.get("colour", hair_spec["colour"]),
                            grey=beard_spec.get("grey", hair_spec.get("grey", 0.0)))
        if beard_spec["style"] in ("short", "full", "long"):
            for k, piece in enumerate(G.beard("Beard", arm, index, lm, beard_mat, beard_spec["style"],
                                              with_moustache=bool(beard_spec.get("moustache")))):
                parts[f"beard_{k}"] = piece
        if beard_spec["style"] == "moustache" or beard_spec.get("moustache"):
            for k, piece in enumerate(G.moustache("Moustache", arm, lm, beard_mat, beard_spec.get("droop", .022))):
                parts[f"moustache_{k}"] = piece
        stubble = beard_spec.get("colour", hair_spec["colour"])
    # Skin ------------------------------------------------------------------------
    masks = []
    if stubble is not None or beard_spec.get("stubble"):
        region = set()
        eye = lm["eye"]
        for i in lm["head"]:
            p = index.points[i]
            if p.z < lm["nose"].z - .004 and p.y - eye.y < .055 and p.z > lm["chin"].z - .07 and i not in lm["lips"]:
                region.add(i)
        colour = S._rgb(stubble or hair_spec["colour"]) * .6
        masks.append((colour, .55 if stubble else .35, region, 6))
    for scar in spec.get("skin", {}).get("scars", []):
        masks.append(((.78, .55, .50), .9, _scar_vertices(index, lm, scar), 3))
    skin_mat = _skin(spec.get("skin", {}), seed + 17, body, masks)
    body.data.materials.clear()
    body.data.materials.append(skin_mat)
    eye_colour = spec.get("eyes", (.30, .36, .42))
    eyes.data.materials.clear()
    eyes.data.materials.append(M.eye("GermanicEye", eye_colour))
    removed = T.remove_covered(body, covered)
    report["covered_body_faces_removed"] = removed
    report["grip_frames"] = {side: {"centre": [round(x, 5) for x in f["centre"]], "axis": [round(x, 5) for x in f["axis"]],
                                    "wrist_turn_degrees": round(f["wrist_turn_degrees"], 2)}
                             for side, f in frames.items()}
    return arm, body, eyes, parts, frames, report
