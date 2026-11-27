#!/usr/bin/env python3
"""Civilian outfit variant of the original Meshy youth (D-032, campaign start 58 BC).

Input: the four staged original youth LODs (stage_original_youth.py), BEFORE
the ACCAD retarget. Output: the same four LOD files with
  * the anachronistic segmented cuirass, shoulder guards, military belt with
    hanging straps, bracers and greaves removed;
  * a new analytic wool tunic (torso, yoke, elbow sleeves, knee skirt with a
    turned hem) and a narrow leather belt, skinned to the unchanged 35-joint
    rig with cloth weights;
  * forearms and shins under the former bracers/greaves rebuilt as skin;
  * the original tunic collar kept and re-textured as the wool neckband.
Head, face, hair, hands, arms, legs, sandals/soles, rig nodes, inverse bind
matrices, clips and the PracticeBlade node are not changed. The output then
goes through the unchanged retarget step (retarget_accad_youth.py), which
regenerates the MoCap clips and the sole-plane report for this variant.

Never commit the outputs: they are derivatives of a private user-owned Meshy
asset. Only this tool and its tests are tracked.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from youth_anatomy import skin_color  # noqa: E402
from youth_civil_mesh import PART_KIND, tessellate  # noqa: E402
from youth_civil_shape import (BELT_Y, HEM_Y, SHOULDER_RING_Y, SLEEVE_HEM_T,  # noqa: E402
                               Garment, Rig, segment_distance, segment_param, smoothstep)
from youth_civil_texture import (WOOL_SRGB, dilate_into, garment_textures, jpeg_bytes,  # noqa: E402
                                 jpeg_keep, rasterize_uv, value_noise3)

MARKER = "imperathen_youth_civil_outfit"
SCHEMA = 1
# Existing per-LOD budgets of build_meshy_player.py: (body triangles, texture).
BUDGET = {0: (32000, 2048), 1: (16000, 1024), 2: (6000, 512), 3: (2000, 256)}
GARMENT_TEXTURE = {0: 1024, 1: 512, 2: 256, 3: 128}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPE = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
# The body of the tunic hangs from the trunk and the shoulder girdle. It does
# not follow the upper arms: only the sleeves do, turning on their shoulder
# domes. Wool pulled along by a raised arm would be driven into the forearm.
TORSO_JOINTS = ("Pelvis", "Lumbar", "Spine", "Chest", "Neck", "Clavicle_L", "Clavicle_R")
BELT_JOINTS = ("Pelvis", "Lumbar", "Spine")
FOOT_JOINTS = ("Foot_L", "Foot_R", "Toe_L", "Toe_R")
ARM_PREFIXES = ("Arm_", "Forearm_", "Hand_", "Clavicle_", "UpperArmTwist_", "ForearmTwist_", "Palm_", "FingerCurl_", "Thumb_")
HEAD_PROTECT_Y = 1.265
SKIN_ROUGHNESS = 0.55


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# --------------------------------------------------------------- glTF I/O
class Glb:
    def __init__(self, raw: bytes):
        if struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
            raise ValueError("Invalid GLB")
        n, kind = struct.unpack_from("<II", raw, 12)
        if kind != 0x4E4F534A:
            raise ValueError("GLB JSON chunk missing")
        self.d = json.loads(raw[20:20 + n])
        m, kind = struct.unpack_from("<II", raw, 20 + n)
        if kind != 0x004E4942 or 28 + n + m != len(raw):
            raise ValueError("GLB binary chunk missing")
        self.b = bytearray(raw[28 + n:])

    def read(self, i):
        a = self.d["accessors"][i]
        v = self.d["bufferViews"][a["bufferView"]]
        dt = np.dtype(DTYPE[a["componentType"]]).newbyteorder("<")
        n = TYPE_N[a["type"]]
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        out = np.ndarray((a["count"], n), dtype=dt, buffer=self.b, offset=start,
                         strides=(v.get("byteStride", dt.itemsize * n), dt.itemsize)).copy()
        if a.get("normalized"):
            out = out.astype(float) / np.iinfo(dt).max
        return out

    def view_bytes(self, view):
        v = self.d["bufferViews"][view]
        s = v.get("byteOffset", 0)
        return bytes(self.b[s:s + v["byteLength"]])

    def append_view(self, raw: bytes, target=None):
        self.b += b"\0" * (-len(self.b) % 4)
        start = len(self.b)
        self.b += raw
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(raw)}
        if target:
            view["target"] = target
        self.d["bufferViews"].append(view)
        return len(self.d["bufferViews"]) - 1

    def append(self, array, kind, component_type=5126, target=None, bounds=False):
        array = np.ascontiguousarray(np.asarray(array).reshape(-1, TYPE_N[kind]),
                                     dtype=np.dtype(DTYPE[component_type]).newbyteorder("<"))
        view = self.append_view(array.tobytes(), target)
        acc = {"bufferView": view, "componentType": component_type, "count": len(array), "type": kind}
        if bounds:
            acc["min"] = array.min(0).astype(float).tolist()
            acc["max"] = array.max(0).astype(float).tolist()
        self.d["accessors"].append(acc)
        return len(self.d["accessors"]) - 1

    def repack(self):
        """Drop unreferenced buffer views; keep every referenced byte exact."""
        used = sorted({a["bufferView"] for a in self.d["accessors"] if "bufferView" in a}
                      | {im["bufferView"] for im in self.d.get("images", []) if "bufferView" in im})
        remap, blob = {}, bytearray()
        views = []
        for old in used:
            v = dict(self.d["bufferViews"][old])
            data = self.view_bytes(old)
            blob += b"\0" * (-len(blob) % 4)
            v["byteOffset"] = len(blob)
            blob += data
            remap[old] = len(views)
            views.append(v)
        for a in self.d["accessors"]:
            if "bufferView" in a:
                a["bufferView"] = remap[a["bufferView"]]
        for im in self.d.get("images", []):
            if "bufferView" in im:
                im["bufferView"] = remap[im["bufferView"]]
        self.d["bufferViews"] = views
        self.b = blob

    def encode(self) -> bytes:
        self.d["buffers"][0]["byteLength"] = len(self.b)
        j = json.dumps(self.d, ensure_ascii=False, separators=(",", ":")).encode()
        j += b" " * (-len(j) % 4)
        b = bytes(self.b) + b"\0" * (-len(self.b) % 4)
        return (struct.pack("<4sII", b"glTF", 2, 28 + len(j) + len(b)) + struct.pack("<II", len(j), 0x4E4F534A)
                + j + struct.pack("<II", len(b), 0x004E4942) + b)


def rest_joints(d):
    nodes = d["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    cache = {}

    def world(i):
        if i in cache:
            return cache[i]
        n = nodes[i]
        m = np.eye(4)
        if "matrix" in n:
            m = np.array(n["matrix"], float).reshape(4, 4).T
        else:
            x, y, z, w = n.get("rotation", [0, 0, 0, 1])
            r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            m[:3, :3] = r @ np.diag(n.get("scale", [1, 1, 1]))
            m[:3, 3] = n.get("translation", [0, 0, 0])
        cache[i] = world(parent[i]) @ m if i in parent else m
        return cache[i]

    joints = d["skins"][0]["joints"]
    return {nodes[j]["name"]: world(j)[:3, 3] for j in joints}, [nodes[j]["name"] for j in joints]


# ------------------------------------------------------------------ geometry
def weld(v):
    _, first, inverse = np.unique(np.round(v, 5), axis=0, return_index=True, return_inverse=True)
    return inverse.reshape(-1), first


def components(faces, welded):
    wf = welded[faces]
    n = int(welded.max()) + 1
    e = np.concatenate([wf[:, [0, 1]], wf[:, [1, 2]], wf[:, [2, 0]]])
    _, label = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
    return label[wf[:, 0]]


def vertex_normals(v, f, welded=None):
    t = v[f]
    fn = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    key = welded if welded is not None else np.arange(len(v))
    acc = np.zeros((int(key.max()) + 1, 3))
    for k in range(3):
        np.add.at(acc, key[f[:, k]], fn)
    n = acc[key]
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def colours(tex, uv, faces):
    h, w, _ = tex.shape
    c = uv[faces].mean(1) % 1.0
    return tex[np.minimum(h - 1, (c[:, 1] * h).astype(int)), np.minimum(w - 1, (c[:, 0] * w).astype(int))]


# ---------------------------------------------------------- classification
def side_param(rig, c, a_name, b_name, left=None):
    """Axis parameter and distance on the limb of the face's own body side."""
    if left is None:
        mid_x = 0.5 * (rig["Arm_L"][0] + rig["Arm_R"][0])
        left = c[:, 0] >= mid_x
    tl, rl = segment_param(c, rig[a_name + "_L"], rig[b_name + "_L"])
    tr, rr = segment_param(c, rig[a_name + "_R"], rig[b_name + "_R"])
    return np.where(left, tl, tr), np.where(left, rl, rr), left


def face_side(joint_names, J, W, f):
    """True for faces skinned more to left-side joints than right-side ones."""
    left = np.array([n.endswith("_L") for n in joint_names])
    right = np.array([n.endswith("_R") for n in joint_names])
    wl = (W * left[J]).sum(1)[f].sum(1)
    wr = (W * right[J]).sum(1)[f].sum(1)
    return wl >= wr


def classify(rig, garment, joint_names, v, uv, f, J, W, base_rgb):
    """Face masks of the old shell. Returns a dict of boolean arrays."""
    c = v[f].mean(1)
    col = colours(base_rgb, uv, f)
    lum = col.mean(1)
    sat = col.max(1) - col.min(1)
    flesh = skin_color(col)
    skin = flesh & (lum > 0.38)
    cloth = (lum > 0.50) & (sat < 0.26) & ~skin
    foot_ids = [joint_names.index(n) for n in FOOT_JOINTS]
    foot = ((W * np.isin(J, foot_ids)).sum(1)[f].max(1) > 0.3)
    head = c[:, 1] > HEAD_PROTECT_Y
    hand_d = rig.hand_distance(c)
    left = face_side(joint_names, J, W, f)
    fore_t, fore_r, _ = side_param(rig, c, "Forearm", "Hand", left)
    # The fist is ~4 cm about its axis; the right fist still carries flesh-
    # coloured hilt slivers further out, the left hand does not.
    beyond_wrist = (fore_t > 1.0) & (hand_d < np.where(left, 0.07, 0.05))
    hand = beyond_wrist & flesh
    # Remnants of the original sword hilt (pommel, guard slivers) at the right
    # fist: everything beyond the right wrist that is not flesh.
    hilt = (fore_t > 1.04) & (hand_d < 0.09) & ~left & (~flesh | (hand_d >= 0.05))
    ua_t, ua, _ = side_param(rig, c, "Arm", "Forearm", left)
    ua = np.where((ua_t >= 0) & (ua_t <= 1), ua, np.inf)
    thigh = np.min([segment_distance(c, rig["Thigh_" + s], rig["Shin_" + s])[0] for s in "LR"], axis=0)
    # Body under the new garment that stays: the arms inside the sleeves and
    # the thighs under the skirt (any colour but the old linen; leather bits
    # there are hidden). They keep the sleeve and hem openings closed.
    # Above the old linen sleeve edge the shell has no arm, only gear.
    arm_core = ~cloth & (ua_t > 0.50) & (ua_t < 1.15) & (ua < 0.065)
    thigh_core = ~cloth & (thigh < 0.085) & (c[:, 1] < 0.70)
    depth = garment.depth_inside(c)
    in_garment = (depth > -0.03) & (c[:, 1] > HEM_Y - 0.05)
    # Shoulder guards: everything on the shoulders except the arm itself.
    mid_x = 0.5 * (rig["Arm_L"][0] + rig["Arm_R"][0])
    shoulder_armour = (c[:, 1] > 1.03) & (np.abs(c[:, 0] - mid_x) > 0.09) & ~arm_core & (c[:, 1] < HEAD_PROTECT_Y)
    # The old linen sleeve hangs almost to the elbow; it is replaced entirely.
    old_sleeve = cloth & (ua_t > -0.05) & (ua_t < 0.98) & (ua < 0.11)
    hand_cloth = (hand_d < 0.09) & cloth & (c[:, 1] < 0.85)
    welded, _ = weld(v)
    label = components(f, welded)
    sizes = np.bincount(label)
    main = np.argmax(sizes)
    small_debris = np.zeros(len(f), bool)
    for comp in np.unique(label[(label != main) & (sizes[label] < 300)]):
        m = label == comp
        if skin[m].mean() < 0.5:
            small_debris |= m
    # Fragments of the old skirt that Meshy fused to the hands lie under the
    # new skirt at rest but follow the arms: they would come out through the
    # wool in every arm swing. Anything there that the arms move goes.
    arm_ids = [k for k, n in enumerate(joint_names) if n.startswith(ARM_PREFIXES)]
    arm_weight = (W * np.isin(J, arm_ids)).sum(1)[f].max(1)
    fused = (depth > -0.005) & (c[:, 1] < BELT_Y) & (arm_weight > 0.05)
    protected = foot | head | hand | arm_core | thigh_core
    delete = (in_garment | shoulder_armour | old_sleeve | hand_cloth | small_debris | hilt) & ~protected
    delete |= fused & ~hand & ~foot
    # Collar: original tunic neckband, kept and re-textured as wool.
    neck_c = 0.5 * (rig["Neck"] + rig["Head"])
    neck_r = np.hypot(c[:, 0] - neck_c[0], c[:, 2] - neck_c[2])
    collar = cloth & (c[:, 1] > 1.17) & (c[:, 1] < 1.275) & (neck_r < 0.105)
    delete &= ~collar
    return {"delete": delete, "collar": collar, "skin": skin, "flesh": flesh, "cloth": cloth, "foot": foot,
            "head": head, "hand": hand, "hilt": hilt & ~protected, "arm_core": arm_core, "thigh_core": thigh_core,
            "depth": depth, "colour": col, "small_debris": small_debris}


def tidy_islands(f, keep, welded, masks, scale=1.0, hand_zone=None):
    """Remove tiny leftover fragments of deleted garment regions."""
    label = components(f[keep], welded)
    sizes = np.bincount(label)
    main = np.argmax(sizes)
    kept = np.flatnonzero(keep)
    drop = np.zeros(len(f), bool)
    limit = max(3, int(round(60 * scale)))
    for comp in np.unique(label):
        if comp == main or sizes[comp] >= limit:
            continue
        m = kept[label == comp]
        if masks["foot"][m].any() or masks["head"][m].any():
            continue
        if masks["hand"][m].sum() > len(m) // 2:
            # A real hand is one large piece; a few loose faces around the
            # fist are what is left of the fused hilt.
            if hand_zone is None or len(m) >= max(3, int(round(12 * scale))) or not hand_zone[m].all():
                continue
        drop[m] = True
    return drop


def peel_fins(f, keep, welded, zone, rounds=8):
    """Remove dangling fins: kept faces of `zone` with two or more open edges.

    The fused sword hilt left thin slivers around the fists that hang on by a
    single edge or float free. A closed hand surface has no such faces, so
    peeling them repeatedly removes the slivers and leaves the hand alone."""
    drop = np.zeros(len(f), bool)
    wf = welded[f]
    n = int(welded.max()) + 1
    for _ in range(rounds):
        live = np.flatnonzero(keep & ~drop)
        e = np.sort(np.concatenate([wf[live][:, [0, 1]], wf[live][:, [1, 2]], wf[live][:, [2, 0]]]), axis=1)
        key = e[:, 0] * n + e[:, 1]
        _, inverse, count = np.unique(key, return_inverse=True, return_counts=True)
        open_edges = (count[inverse.reshape(-1)] == 1).reshape(3, -1).sum(0)
        fins = live[(open_edges >= 2) & zone[live]]
        if not len(fins):
            break
        drop[fins] = True
    return drop


# ------------------------------------------------------------ limb rebuild
class Limb:
    """Cylindrical frame of a limb segment a->b (t along, phi around, r out)."""

    def __init__(self, a, b):
        self.a, self.b = np.asarray(a, float), np.asarray(b, float)
        self.ab = self.b - self.a
        self.axis = self.ab / np.linalg.norm(self.ab)
        ref = np.array([0.0, 0.0, 1.0])
        self.u = ref - self.axis * (ref @ self.axis)
        self.u /= np.linalg.norm(self.u)
        self.w = np.cross(self.axis, self.u)

    def coords(self, points):
        q = points - self.a
        t = q @ self.ab / (self.ab @ self.ab)
        radial = q - np.outer(q @ self.axis, self.axis)
        r = np.linalg.norm(radial, axis=1)
        phi = np.arctan2(radial @ self.w, radial @ self.u) % (2 * np.pi)
        return t, phi, r, radial / np.maximum(r, 1e-9)[:, None]


def fit_skin_radius(limb, points, t0, t1, tb=12, pb=16):
    """r_skin(t, phi) from real skin vertices of the limb; holes interpolated."""
    t, phi, r, _ = limb.coords(points)
    lo, span = t0 - 0.18, t1 - t0 + 0.36
    sel = (t > lo) & (t < lo + span) & (r < 0.09)
    t, phi, r = t[sel], phi[sel], r[sel]
    grid = np.full((tb, pb), np.nan)
    ti = np.clip(((t - lo) / span * tb).astype(int), 0, tb - 1)
    pi = (phi / (2 * np.pi) * pb).astype(int) % pb
    for a in range(tb):
        for b in range(pb):
            m = (ti == a) & (pi == b)
            if m.sum() >= 2:
                grid[a, b] = np.percentile(r[m], 65)
    for b in range(pb):
        good = np.isfinite(grid[:, b])
        if good.any():
            grid[:, b] = np.interp(np.arange(tb), np.flatnonzero(good), grid[good, b])
    for a in range(tb):
        good = np.isfinite(grid[a])
        if good.any():
            idx = np.flatnonzero(good)
            grid[a] = np.interp(np.arange(pb), np.concatenate([idx - pb, idx, idx + pb]), np.concatenate([grid[a, good]] * 3))
    if not np.isfinite(grid).any():
        raise ValueError("No skin to fit the limb radius")
    grid[~np.isfinite(grid)] = np.nanmedian(grid)
    k = np.array([0.25, 0.5, 0.25])
    for _ in range(3):
        grid = np.array([np.convolve(np.pad(row, 1, mode="wrap"), k, "valid") for row in grid])
        grid = np.array([np.convolve(np.pad(col, 1, mode="edge"), k, "valid") for col in grid.T]).T

    def fitted(tq, phiq):
        x = np.clip((tq - lo) / span * tb - 0.5, 0, tb - 1.0001)
        y = phiq / (2 * np.pi) * pb - 0.5
        xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = x - xi, y - yi
        g = lambda i, j: grid[np.clip(i, 0, tb - 1), j % pb]
        return ((1 - fx) * (1 - fy) * g(xi, yi) + fx * (1 - fy) * g(xi + 1, yi)
                + (1 - fx) * fy * g(xi, yi + 1) + fx * fy * g(xi + 1, yi + 1))
    return fitted, float(np.median(grid))


def limb_fade(t, t0, t1):
    return smoothstep(t0, t0 + 0.05, t) * (1 - smoothstep(t1 - 0.06, t1, t))


def project_limb(v, nrm, f, welded, span_faces, limb, t0, t1, fitted, locked_faces):
    """Project every vertex of the span onto the fitted skin surface.

    The bracer/greave and the skin under it collapse onto one smooth surface;
    analytic normals keep the shading clean. Returns new positions, normals,
    the faces folded under the surface (to delete) and moved vertex ids."""
    rv = np.unique(f[span_faces])
    rv = rv[~np.isin(welded[rv], welded[np.unique(f[locked_faces])])]
    t, phi, r, radial = limb.coords(v[rv])
    fade = limb_fade(t, t0, t1)
    target = fitted(t, phi)
    new_r = r + (target - r) * fade
    pos = v.copy()
    pos[rv] = limb.a + np.outer((v[rv] - limb.a) @ limb.axis, limb.axis) + radial * new_r[:, None]
    # Analytic normal: radial direction tilted by the taper dr/dt.
    eps = 0.01
    slope = (fitted(t + eps, phi) - fitted(t - eps, phi)) / (2 * eps * np.linalg.norm(limb.ab))
    analytic = radial - slope[:, None] * limb.axis
    analytic /= np.linalg.norm(analytic, axis=1, keepdims=True)
    normals = nrm.copy()
    blend = fade[:, None] * analytic + (1 - fade[:, None]) * nrm[rv]
    normals[rv] = blend / np.maximum(np.linalg.norm(blend, axis=1, keepdims=True), 1e-9)
    # Faces of the span that now face into the limb were the underside of
    # the gear (or skin under it) and lie on the same surface: remove them.
    faces = np.flatnonzero(span_faces)
    tri = pos[f[faces]]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    ft, _, _, frad = limb.coords(tri.mean(1))
    folded = faces[((fn * frad).sum(1) < 0) & (limb_fade(ft, t0, t1) > 0.6)]
    return pos, normals, folded, rv


# ------------------------------------------------------------- weights
def garment_weights(joint_names, gv, kind, gparam, gf, old_v, old_j, old_w, rig):
    n = len(gv)
    dense = np.zeros((n, len(joint_names)))
    tree = cKDTree(old_v)
    dist, idx = tree.query(gv, k=12)
    inv = 1.0 / np.maximum(dist, 0.004) ** 2
    for k in range(12):
        np.add.at(dense, (np.repeat(np.arange(n), 4), old_j[idx[:, k]].reshape(-1)),
                  (old_w[idx[:, k]] * inv[:, k:k + 1]).reshape(-1))
    allowed = np.zeros_like(dense, bool)
    torso_ids = [joint_names.index(x) for x in TORSO_JOINTS]
    belt_ids = [joint_names.index(x) for x in BELT_JOINTS]
    for part, k in PART_KIND.items():
        m = kind == k
        if part == "torso":
            allowed[np.ix_(m, torso_ids)] = True
        elif part == "belt":
            allowed[np.ix_(m, belt_ids)] = True
        elif part.startswith("sleeve"):
            side = part[-1]
            # The upper arm alone: the dome is a sphere about the shoulder
            # joint, so it stays seated under the yoke in every arm pose.
            ids = [joint_names.index(x) for x in ("Arm_" + side, "UpperArmTwist_" + side)]
            allowed[np.ix_(m, ids)] = True
    dense = np.where(allowed, dense, 0.0)
    # Skirt: wool hangs from the pelvis; the lower it is the more it follows
    # the thigh on its own side. No arm influence at all.
    m = kind == PART_KIND["skirt"]
    skirt_mask = m.copy()
    skirt_ids = [joint_names.index(x) for x in ("Pelvis","Lumbar","Thigh_L","Thigh_R")]
    allowed[np.ix_(m, skirt_ids)] = True
    y = gv[m, 1]
    theta = gparam[m, 0]
    h = np.clip((BELT_Y - y) / (BELT_Y - HEM_Y), 0, 1)
    leg = 0.90 * smoothstep(0.06, 0.95, h)
    left = smoothstep(-0.55, 0.55, np.sin(theta))
    lumbar = 0.22 * (1 - smoothstep(0.0, 0.18, h))
    sk = np.zeros((m.sum(), len(joint_names)))
    sk[:, joint_names.index("Thigh_L")] = leg * left
    sk[:, joint_names.index("Thigh_R")] = leg * (1 - left)
    sk[:, joint_names.index("Lumbar")] = lumbar
    sk[:, joint_names.index("Pelvis")] = 1 - leg - lumbar
    dense[m] = sk
    for side in "LR":
        m = (kind == PART_KIND["sleeve_" + side]) & (dense.sum(1) <= 1e-9)
        dense[m, joint_names.index("Arm_" + side)] = 1.0
    lonely = (kind == PART_KIND["torso"]) & (dense.sum(1) <= 1e-9)
    dense[lonely, joint_names.index("Chest")] = 1.0
    total = dense.sum(1, keepdims=True)
    if (total <= 0).any():
        dense[total[:, 0] <= 0, joint_names.index("Spine")] = 1.0
        total = dense.sum(1, keepdims=True)
    dense /= total
    # Laplacian smoothing over the garment surface (welded seams included).
    welded, _ = weld(gv)
    edges = np.concatenate([gf[:, [0, 1]], gf[:, [1, 2]], gf[:, [2, 0]]])
    we = welded[edges]
    nw = int(welded.max()) + 1
    for _ in range(4):
        acc_w = np.zeros((nw, dense.shape[1]))
        np.add.at(acc_w, welded, dense)
        cnt = np.bincount(welded, minlength=nw)[:, None]
        node = acc_w / cnt
        nb = np.zeros_like(node)
        deg = np.zeros(nw)
        np.add.at(nb, we[:, 0], node[we[:, 1]])
        np.add.at(nb, we[:, 1], node[we[:, 0]])
        np.add.at(deg, we[:, 0], 1)
        np.add.at(deg, we[:, 1], 1)
        smooth = 0.5 * node + 0.5 * nb / np.maximum(deg, 1)[:, None]
        dense = np.where(allowed, smooth[welded], 0.0)
        dense /= dense.sum(1, keepdims=True)
    order = np.argsort(-dense, axis=1)[:, :4]
    wts = np.take_along_axis(dense, order, 1)
    wts /= wts.sum(1, keepdims=True)
    if np.any((wts[skirt_mask] > 1e-7) & ~np.isin(order[skirt_mask], skirt_ids)):
        raise ValueError("Skirt weights escaped the pelvis/thigh contract")
    forbidden = [i for i,n in enumerate(joint_names) if n.startswith(("Forearm_","Hand_","Palm_","FingerCurl_","Thumb_","ForearmTwist_"))]
    if np.any((wts > 1e-7) & np.isin(order, forbidden)):
        raise ValueError("Garment was incorrectly weighted to a hand or forearm")
    return order.astype(np.uint16), wts.astype(np.float32)


def follow_cloth(garment, rig, v, f, keep, locked, depth, J, W, gv, gj, gw, joint_count):
    """Shell left under the wool moves with the wool.

    What remains of the old shell under the garment (thigh tops, arm stubs,
    a few faces Meshy skinned partly to a hand) keeps its own weights and
    would come out through the cloth when the joints turn. Away from the hem
    and sleeve openings such vertices take the weights of the nearest garment
    vertex, so they cannot move relative to it; toward the openings the limb
    keeps its own skinning and the blend fades out."""
    used = np.unique(f[keep])
    used = used[~np.isin(used, np.unique(f[locked]))]
    p = v[used]
    blend = smoothstep(0.002, 0.012, depth[used])
    below = p[:, 1] < BELT_Y
    blend = np.where(below, blend * smoothstep(HEM_Y + 0.02, HEM_Y + 0.07, p[:, 1]), blend)
    for side in "LR":
        a, b, _, _, _ = garment.sleeve_axis(side)
        t, r = segment_param(p, a, b)
        in_sleeve = (t > 0.25) & (t < SLEEVE_HEM_T + 0.05) & (r < 0.09)
        blend = np.where(in_sleeve, blend * (1 - smoothstep(SLEEVE_HEM_T - 0.14, SLEEVE_HEM_T - 0.05, t)), blend)
    move = blend > 1e-3
    if not move.any():
        return J, W, 0
    ids = used[move]
    k = blend[move][:, None]
    dense = np.zeros((len(ids), joint_count))
    rows = np.repeat(np.arange(len(ids)), 4)
    np.add.at(dense, (rows, J[ids].reshape(-1)), ((1 - k) * W[ids]).reshape(-1))
    _, near = cKDTree(gv).query(v[ids])
    np.add.at(dense, (rows, gj[near].astype(np.int64).reshape(-1)), (k * gw[near]).reshape(-1))
    order = np.argsort(-dense, axis=1)[:, :4]
    weights = np.take_along_axis(dense, order, 1)
    weights /= weights.sum(1, keepdims=True)
    J, W = J.copy(), W.copy()
    J[ids] = order
    W[ids] = weights
    return J, W, int(len(ids))


# ----------------------------------------------------------- texturing
def repaint_atlas(images, uv, f, v, regions, size):
    """Repaint base colour / normal / metallic-roughness texels of regions.

    regions: (face mask, mode, data). mode "limb": data = (Limb, t0, t1,
    tone_top, tone_bottom); texels blend into the original skin toward the
    span ends. mode "wool": the neckband."""
    base, normal, mr = (np.asarray(x).copy() for x in images)
    original = base.astype(float)
    owner, bary = rasterize_uv(uv, f, size)
    free = owner < 0
    painted = np.zeros(owner.shape, bool)
    for mask, mode, data in regions:
        faces = np.flatnonzero(mask)
        if not len(faces):
            continue
        sel = np.isin(owner, faces)
        ys, xs = np.nonzero(sel)
        tri = owner[ys, xs]
        p = (bary[ys, xs, :, None] * v[f[tri]]).sum(1)
        n1 = value_noise3(p, 0.030, 31)
        n2 = value_noise3(p, 0.007, 32)
        if mode == "limb":
            limb, t0, t1, top, bottom = data
            t, _, _, _ = limb.coords(p)
            k = np.clip((t - t0) / (t1 - t0), 0, 1)[:, None]
            tone = (1 - k) * top[None] + k * bottom[None]
            colour = tone * (1 + 0.035 * n1 + 0.015 * n2)[:, None]
            fade = limb_fade(t, t0, t1)[:, None]
            src = original[ys, xs]
            src_skin = skin_color(src / 255.0)[:, None]
            colour = np.where(src_skin, fade * colour + (1 - fade) * src, colour)
            rough = SKIN_ROUGHNESS + 0.04 * n2
            flat = fade[:, 0] > 0.5
        else:
            colour = WOOL_SRGB[None] * (1 + 0.04 * n1 + 0.03 * n2)[:, None]
            rough = 0.92 + 0.03 * n2
            flat = np.ones(len(ys), bool)
        base[ys, xs] = np.clip(colour, 0, 255).round()
        normal[ys[flat], xs[flat]] = (128, 128, 255)
        mr[ys, xs, 1] = np.clip(rough * 255, 0, 255).round()
        mr[ys, xs, 2] = 0
        painted |= sel
    base = dilate_into(base, painted, free)
    normal = dilate_into(normal, painted, free)
    mr = dilate_into(mr, painted, free)
    return base, normal, mr, int(painted.sum())


def tone(tex, uv, f, faces):
    if len(faces) < 6:
        return None
    return np.median(colours(tex, uv, f[faces]), axis=0) * 255


# ---------------------------------------------------------------- build
LIMBS = (("forearm_L", "Forearm_L", "Hand_L", (0.08, 1.10), (0.66, 1.0)),
         ("shin_L", "Shin_L", "Foot_L", (-0.035, 0.90), (0.13, 0.48)),
         ("forearm_R", "Forearm_R", "Hand_R", (0.08, 1.10), (0.66, 1.0)),
         ("shin_R", "Shin_R", "Foot_R", (-0.035, 0.90), (0.13, 0.48)))
KEEP, DELETE, COLLAR = 0, 1, 2          # labels >= 3 are LIMBS spans


class Plan:
    """Decisions made once on LOD 0 and transferred to LODs 1-3."""

    def __init__(self):
        self.labels = None
        self.centres = None
        self.tree = None
        self.limbs = {}


def _sample_points(v, f):
    c = v[f].mean(1)
    return [c] + [v[f[:, k]] * 0.75 + c * 0.25 for k in range(3)]


def transfer_labels(plan, v, f):
    """Majority label of the nearest LOD 0 faces at four points per face."""
    votes = np.zeros((len(f), 3 + len(LIMBS)), int)
    for pts in _sample_points(v, f):
        _, idx = plan.tree.query(pts)
        np.add.at(votes, (np.arange(len(f)), plan.labels[idx]), 1)
    return votes.argmax(1), votes


def build_lod(raw: bytes, level: int, garment: Garment, reference, plan: Plan) -> tuple[bytes, dict]:
    glb = Glb(raw)
    d = glb.d
    joints, joint_names = rest_joints(d)
    rig = Rig(joints)
    body_node = next(n for n in d["nodes"] if n.get("name") == "MeshyYouthBody")
    mesh = d["meshes"][body_node["mesh"]]
    if MARKER in mesh.get("extras", {}):
        raise ValueError("Input already carries the civilian outfit")
    prim = mesh["primitives"][0]
    a = prim["attributes"]
    v = glb.read(a["POSITION"]).astype(float)
    nrm = glb.read(a["NORMAL"]).astype(float)
    uv = glb.read(a["TEXCOORD_0"]).astype(float)
    J = glb.read(a["JOINTS_0"]).astype(np.int64)
    W = glb.read(a["WEIGHTS_0"]).astype(float)
    f = glb.read(prim["indices"]).reshape(-1, 3).astype(np.int64)
    material = d["materials"][prim["material"]]
    pbr = material["pbrMetallicRoughness"]
    tex_ids = {"base": pbr["baseColorTexture"]["index"], "normal": material["normalTexture"]["index"],
               "mr": pbr["metallicRoughnessTexture"]["index"]}
    image_ids = {k: d["textures"][t]["source"] for k, t in tex_ids.items()}
    image_raw = {k: glb.view_bytes(d["images"][i]["bufferView"]) for k, i in image_ids.items()}
    images = {k: np.asarray(Image.open(io.BytesIO(r)).convert("RGB")) for k, r in image_raw.items()}
    base_rgb = images["base"].astype(float) / 255
    size = images["base"].shape[0]
    if size > BUDGET[level][1]:
        raise ValueError("Source atlas exceeds the LOD texture budget")

    masks = classify(rig, garment, joint_names, v, uv, f, J, W, base_rgb)
    welded, _ = weld(v)
    c = v[f].mean(1)
    side_left = face_side(joint_names, J, W, f)
    # Geometric protection that holds at every LOD: sandals by their skin
    # weights, the head by its vertices, the hands beyond the wrists.
    head_v = ((v[f][:, :, 1].max(1) > HEAD_PROTECT_Y) & (v[f][:, :, 1].min(1) > 1.17)) | (c[:, 1] > 1.25) | (v[f][:, :, 1].max(1) > 1.30)
    locked = masks["foot"] | head_v | masks["hand"]
    if level == 0:
        labels = np.where(masks["delete"], DELETE, KEEP)
        labels[masks["delete"] & masks["collar"]] = KEEP
        labels[masks["collar"] & ~masks["delete"]] = COLLAR
        labels[tidy_islands(f, labels != DELETE, welded, masks)] = DELETE
        for k, (name, a_name, b_name, (t0, t1), (ylo, yhi)) in enumerate(LIMBS):
            limb = Limb(rig[a_name], rig[b_name])
            t, _, r, _ = limb.coords(c)
            side = side_left == name.endswith("_L")
            span = side & (labels != DELETE) & (t > t0) & (t < t1) & (r < 0.12) & (c[:, 1] > ylo) & (c[:, 1] < yhi) & ~locked
            if not (span & ~masks["skin"]).any():
                continue
            skin_ref = side & masks["skin"] & (labels != DELETE) & ~locked & (r < 0.09)
            fitted, radius = fit_skin_radius(limb, v[np.unique(f[skin_ref])], t0, t1)
            tones = []
            for lo, hi in ((t0 - 0.14, t0 + 0.03), (t1 - 0.03, t1 + 0.14), (t0, t1)):
                tones.append(tone(base_rgb, uv, f, np.flatnonzero(skin_ref & (t > lo) & (t < hi))))
            top = tones[0] if tones[0] is not None else tones[2]
            bottom = tones[1] if tones[1] is not None else tones[2]
            if top is None or bottom is None:
                raise ValueError(f"No reference skin tone for {name}")
            labels[span] = 3 + k
            plan.limbs[name] = {"limb": limb, "t": (t0, t1), "fitted": fitted, "radius": radius,
                                "top": top, "bottom": bottom, "gear_faces": int((span & ~masks["skin"]).sum())}
        plan.labels = labels
        plan.centres = c
        plan.tree = cKDTree(c)
    else:
        labels, _ = transfer_labels(plan, v, f)
        labels = np.where(locked & (labels != KEEP), KEEP, labels)

    keep = labels != DELETE
    # Kept faces that would lie on or through the new wool (old garment
    # remnants and large low-LOD triangles) are hidden material: remove them.
    vertex_depth = garment.depth_inside(v)
    shallow = (vertex_depth[f] > -0.02).all(1) & (vertex_depth[f] < 0.008).any(1)
    keep &= ~(shallow & ~locked & (labels == KEEP))
    moved = v.copy()
    limb_report = {}
    retexture = []
    folded_all = np.zeros(len(f), bool)
    for k, (name, a_name, b_name, _, _) in enumerate(LIMBS):
        if name not in plan.limbs:
            continue
        info = plan.limbs[name]
        textured = labels == 3 + k
        if level > 0:
            # Large low-LOD triangles that reach into the sandal or the hand
            # are locked for geometry but still carry the greave/bracer
            # texture; they are re-textured too.
            limb = info["limb"]
            t, _, r, _ = limb.coords(c)
            t0, t1 = info["t"]
            side = side_left == name.endswith("_L")
            band = (c[:, 1] > 0.19) if name.startswith("shin") else (t < 0.95)
            textured |= side & locked & ~head_v & (t > t0) & (t < t1) & (r < 0.12) & band & keep & ~masks["skin"]
        span = textured & ~locked
        if not textured.any():
            continue
        t0, t1 = info["t"]
        moved, nrm, folded, rv = project_limb(moved, nrm, f, welded, span, info["limb"], t0, t1, info["fitted"], locked)
        folded_all[folded] = True
        retexture.append((textured, "limb", (info["limb"], t0, t1, info["top"], info["bottom"])))
        limb_report[name] = {"span_faces": int(span.sum()), "lod0_gear_faces": info["gear_faces"],
                             "folded_faces_removed": int(len(folded)), "moved_vertices": int(len(rv)),
                             "median_skin_radius_m": round(info["radius"], 4),
                             "tone_top_srgb": [round(float(x), 1) for x in info["top"]],
                             "tone_bottom_srgb": [round(float(x), 1) for x in info["bottom"]]}
    keep &= ~folded_all
    fore_t = np.where(side_left, segment_param(c, rig["Forearm_L"], rig["Hand_L"])[0],
                      segment_param(c, rig["Forearm_R"], rig["Hand_R"])[0])
    hand_zone = (fore_t > 0.92) & (rig.hand_distance(c) < 0.16) & ~masks["foot"] & ~head_v
    fins = peel_fins(f, keep, welded, hand_zone)
    keep &= ~fins
    masks["hand"] = masks["hand"] & keep
    keep &= ~tidy_islands(f, keep, welded, masks, scale=len(f) / 31881.0, hand_zone=hand_zone)
    retexture = [(m & keep, mode, data) for m, mode, data in retexture]
    retexture.append(((labels == COLLAR) & keep, "wool", None))
    delete = ~keep
    masks["head"] = head_v

    base, normal, mr, painted = repaint_atlas([images["base"], images["normal"], images["mr"]], uv, f, moved,
                                              retexture, size)
    # Identity: face/hair texels must not change beyond JPEG requantisation.
    head_faces = np.flatnonzero(masks["head"])
    owner, _ = rasterize_uv(uv, f[head_faces], size)
    head_texels = owner >= 0

    # New tunic.
    gv, guv, gf, gkind, gparam = tessellate(garment, level)
    old_v, old_j, old_w = reference
    gj, gw = garment_weights(joint_names, gv, gkind, gparam, gf, old_v, old_j, old_w, rig)
    gn = vertex_normals(gv, gf, weld(gv)[0])
    J, W, followed = follow_cloth(garment, rig, v, f, keep, locked, vertex_depth, J, W, gv, gj, gw, len(joint_names))
    gsize = GARMENT_TEXTURE[level]
    gbase, gnormal, gmr = garment_textures(gsize, garment.fold)

    # Hand-cut caps (build_meshy_player.py): they closed the holes where the
    # right hand was cut from the old skirt and the sword. A cap stays only
    # where it still closes surviving shell; it follows a rebuilt forearm.
    # Caps of removed fragments would float around the fist as loose flakes.
    used_now = np.unique(f[keep])
    shell_tree = cKDTree(v[used_now])
    caps, caps_removed = 0, 0
    for cap in list(mesh["primitives"][1:]):
        cv = glb.read(cap["attributes"]["POSITION"]).astype(float)
        cf = glb.read(cap["indices"]).reshape(-1, 3).astype(np.int64)
        dist, near = shell_tree.query(cv)
        attached = dist < 0.0015
        cv[attached] = moved[used_now[near[attached]]]
        stay = attached[cf].all(1)
        caps_removed += int((~stay).sum())
        if not stay.any():
            mesh["primitives"].remove(cap)
            continue
        cap["attributes"]["POSITION"] = glb.append(cv.astype(np.float32), "VEC3", target=34962, bounds=True)
        cap["indices"] = glb.append(cf[stay].astype(np.uint32), "SCALAR", 5125, target=34963)
        caps += int(stay.sum())
    total = int(keep.sum()) + len(gf) + caps
    if total > BUDGET[level][0]:
        raise ValueError(f"LOD {level} exceeds its triangle budget: {total} > {BUDGET[level][0]}")

    # ---- write
    sole_before = digest(np.ascontiguousarray(v[np.unique(f[masks["foot"]])]).tobytes())
    # Compact: vertices of removed faces are dropped with them.
    used = np.unique(f[keep])
    remap = np.full(len(v), -1, np.int64)
    remap[used] = np.arange(len(used))
    prim["attributes"]["POSITION"] = glb.append(moved[used].astype(np.float32), "VEC3", target=34962, bounds=True)
    prim["attributes"]["NORMAL"] = glb.append(nrm[used].astype(np.float32), "VEC3", target=34962)
    prim["attributes"]["TEXCOORD_0"] = glb.append(uv[used].astype(np.float32), "VEC2", target=34962)
    joints_type = d["accessors"][a["JOINTS_0"]]["componentType"]
    prim["attributes"]["JOINTS_0"] = glb.append(J[used], "VEC4", joints_type, target=34962)
    prim["attributes"]["WEIGHTS_0"] = glb.append(W[used].astype(np.float32), "VEC4", target=34962)
    prim["indices"] = glb.append(remap[f[keep]].astype(np.uint32), "SCALAR", 5125, target=34963)
    for key, arr in (("base", base), ("normal", normal), ("mr", mr)):
        img = d["images"][image_ids[key]]
        img["bufferView"] = glb.append_view(jpeg_keep(image_raw[key], arr))
    new_images = []
    for key, arr in (("base", gbase), ("normal", gnormal), ("mr", gmr)):
        d["images"].append({"name": "YouthCivilWool_" + key, "mimeType": "image/jpeg",
                            "bufferView": glb.append_view(jpeg_bytes(arr, 92))})
        d["textures"].append({"sampler": d["textures"][tex_ids["base"]].get("sampler", 0),
                              "source": len(d["images"]) - 1})
        new_images.append(len(d["textures"]) - 1)
    d["materials"].append({"name": "YouthCivilWool", "doubleSided": True,
                           "pbrMetallicRoughness": {"baseColorTexture": {"index": new_images[0]},
                                                    "metallicRoughnessTexture": {"index": new_images[2]},
                                                    "metallicFactor": 1.0, "roughnessFactor": 1.0},
                           "normalTexture": {"index": new_images[1], "scale": 0.6}})
    mesh["primitives"].append({
        "attributes": {"POSITION": glb.append(gv.astype(np.float32), "VEC3", target=34962, bounds=True),
                       "NORMAL": glb.append(gn.astype(np.float32), "VEC3", target=34962),
                       "TEXCOORD_0": glb.append(guv.astype(np.float32), "VEC2", target=34962),
                       "JOINTS_0": glb.append(gj, "VEC4", 5123, target=34962),
                       "WEIGHTS_0": glb.append(gw, "VEC4", target=34962)},
        "indices": glb.append(gf.astype(np.uint32), "SCALAR", 5125, target=34963),
        "material": len(d["materials"]) - 1, "mode": 4})
    # Two modest lower-hem shapes on the actual generated wool primitive.
    # Every preexisting body primitive receives zero deltas; no face, hand,
    # sole or original body geometry changes. Distant tiers stay morph-free.
    if level < 2:
        if any(p.get("targets") for p in mesh["primitives"]):
            raise ValueError("Unexpected source morphs; do not overwrite them")
        skirt = gkind == PART_KIND["skirt"]
        h = np.clip((BELT_Y-gv[:,1])/(BELT_Y-HEM_Y),0,1)
        fade = smoothstep(0.45,1.0,h) * skirt
        delta = np.zeros_like(gv,dtype=np.float32)
        delta[:,0] = 0.012*fade
        for part in mesh["primitives"]:
            count = d["accessors"][part["attributes"]["POSITION"]]["count"]
            displacement = delta if part is mesh["primitives"][-1] else np.zeros((count,3),np.float32)
            part["targets"] = [{"POSITION":glb.append(-displacement,"VEC3",target=34962)}, {"POSITION":glb.append(displacement,"VEC3",target=34962)}]
        mesh.setdefault("extras",{})["targetNames"] = ["ClothHemLeft","ClothHemRight"]
        mesh["weights"] = [0.0,0.0]
    report = {
        "cloth_hem_morphs": level < 2,
        "skirt_hand_weight_max": 0.0,
        "level": level,
        "old_shell_faces": int(len(f)), "deleted_faces": int(delete.sum()), "kept_faces": int(keep.sum()),
        "old_shell_vertices": int(len(v)), "kept_vertices": int(len(used)),
        "garment_triangles": int(len(gf)), "garment_vertices": int(len(gv)), "hand_cut_cap_triangles": int(caps),
        "hand_cut_cap_triangles_removed": int(caps_removed),
        "body_triangles": total, "budget_triangles": BUDGET[level][0],
        "atlas_texture": size, "garment_texture": gsize, "budget_texture": BUDGET[level][1],
        "repainted_texels": painted, "head_texels": int(head_texels.sum()),
        "limbs": limb_report, "collar_faces": int((masks["collar"] & keep).sum()),
        "small_debris_faces": int(masks["small_debris"].sum()), "hand_fin_faces_removed": int(fins.sum()),
        "shell_vertices_following_cloth": followed,
        "sole_vertices_sha256": sole_before,
        "sole_vertices_unchanged": bool(np.array_equal(moved[np.unique(f[masks["foot"]])], v[np.unique(f[masks["foot"]])])),
        "sole_faces_kept": bool(keep[masks["foot"]].all()),
        "head_vertices_unchanged": bool(np.array_equal(moved[np.unique(f[masks["head"]])], v[np.unique(f[masks["head"]])])),
    }
    if not (report["sole_vertices_unchanged"] and report["sole_faces_kept"] and report["head_vertices_unchanged"]):
        raise ValueError(f"LOD {level}: sole or head geometry would change: {report}")
    # Face texels after JPEG requantisation.
    after = np.asarray(Image.open(io.BytesIO(glb.view_bytes(d["images"][image_ids["base"]]["bufferView"]))).convert("RGB")).astype(int)
    report["head_texel_max_abs_diff"] = int(np.abs(after[head_texels] - images["base"][head_texels].astype(int)).max())
    report["head_texel_mean_abs_diff"] = round(float(np.abs(after[head_texels] - images["base"][head_texels].astype(int)).mean()), 4)
    mesh.setdefault("extras", {})[MARKER] = {"schema": SCHEMA, "tool": "tools/characters/build_youth_civil_outfit.py",
                                             "garment_material": "YouthCivilWool",
                                             "removed": ["segmented cuirass", "shoulder guards", "military belt with straps",
                                                         "bracers", "greaves and calf straps"]}
    glb.repack()
    out = glb.encode()
    report["sha256"] = digest(out)
    report["bytes"] = len(out)
    return out, report


def build(input_dir: Path, output_dir: Path, report_path: Path | None):
    raws = [(input_dir / f"hero_meshy_italia_{i}.glb").read_bytes() for i in range(4)]
    lod0 = Glb(raws[0])
    joints, joint_names = rest_joints(lod0.d)
    body = next(n for n in lod0.d["nodes"] if n.get("name") == "MeshyYouthBody")
    p0 = lod0.d["meshes"][body["mesh"]]["primitives"][0]["attributes"]
    v0 = lod0.read(p0["POSITION"]).astype(float)
    garment = Garment(Rig(joints), v0)
    reference = (v0, lod0.read(p0["JOINTS_0"]).astype(np.int64), lod0.read(p0["WEIGHTS_0"]).astype(float))
    output_dir.mkdir(parents=True, exist_ok=True)
    report = {"schema": SCHEMA, "tool": "tools/characters/build_youth_civil_outfit.py",
              "decision": "D-032", "outfit": "civil", "rig_joints": len(joint_names),
              "inputs": [{"level": i, "sha256": digest(r)} for i, r in enumerate(raws)],
              "garment": {"hem_y_m": HEM_Y, "belt_y_m": BELT_Y, "shoulder_ring_y_m": SHOULDER_RING_Y,
                          "sleeve_hem_t": SLEEVE_HEM_T},
              "lods": []}
    plan = Plan()
    for level, raw in enumerate(raws):
        out, lod = build_lod(raw, level, garment, reference, plan)
        (output_dir / f"hero_meshy_italia_{level}.glb").write_bytes(out)
        report["lods"].append(lod)
        print("YOUTH_CIVIL_LOD", level, json.dumps({k: lod[k] for k in ("body_triangles", "deleted_faces", "garment_triangles", "sha256")}), flush=True)
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--input", type=Path, required=True, help="directory with the staged ORIGINAL youth LODs")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    build(args.input, args.output, args.report)
    print("YOUTH_CIVIL_OUTFIT_BUILT", flush=True)


if __name__ == "__main__":
    main()
