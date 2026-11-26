"""Analytic civilian tunic for the original Meshy youth (shape only).

The garment is defined once, in the bind space of the unchanged 35-joint rig,
from measured envelopes of the original LOD 0 shell. Every LOD tessellates the
same analytic surface, so the outfit keeps its shape between LODs.

Coordinates: glTF bind space, metres, +Y up, +Z the character's front,
+X the character's left.
"""
from __future__ import annotations

import math

import numpy as np

# --- Garment design. Values are design choices measured against the youth
# (1.50 m, knee joint 0.457 m, natural waist ~0.86 m); see the outfit doc.
HEM_Y = 0.522            # hem ~6.5 cm above the knee joint
BELT_Y = 0.862           # natural waist, just below the old cuirass edge
BELT_HALF_HEIGHT = 0.0135
WAIST_CINCH_M = 0.010    # the belt pulls the wool in
BLOUSE_M = 0.013         # wool bloused over the belt
TORSO_SHRINK_M = 0.010   # wool lies closer than the segmented plates did
BELLY_SHRINK_M = 0.010   # ... and the belt gear in front of the belly is gone
SKIRT_EASE_M = 0.002
SHOULDER_RING_Y = 1.150  # last horizontal ring; the shoulder yoke closes above
SLEEVE_HEM_T = 0.58      # the cloth falls over the upper arm to just past its middle
SLEEVE_START_T = 0.0     # the tube starts at the shoulder joint, closed by a dome above it
SLEEVE_EASE_M = 0.007    # wool over the measured upper arm
SHOULDER_WIDEN_M = 0.022 # the yoke runs out over the deltoid (dropped shoulder of a wide tunic)
ARM_PHI_BINS = 24
NECK_RING = {"front": 1.212, "side": 1.238, "back": 1.244}
NECK_RADIUS_M = 0.071
RING_STEP_M = 0.01


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def segment_distance(points, a, b):
    ab = b - a
    t = np.clip(((points - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(points - (a + t[:, None] * ab), axis=1), t


def segment_param(points, a, b):
    """Unclamped parameter and radial distance about the infinite axis a->b."""
    ab = b - a
    t = ((points - a) @ ab) / (ab @ ab)
    return t, np.linalg.norm(points - (a + t[:, None] * ab), axis=1)


def circular_smooth(values, sigma_bins):
    span = 3 * int(math.ceil(sigma_bins))
    k = np.arange(-span, span + 1)
    w = np.exp(-0.5 * (k / sigma_bins) ** 2)
    w /= w.sum()
    out = np.zeros(len(values))
    for offset, weight in zip(k, w):
        out += weight * np.roll(values, offset)
    return out


def fill_circular(values):
    """Linear circular interpolation of NaN bins."""
    n = len(values)
    good = np.flatnonzero(np.isfinite(values))
    if len(good) == 0:
        raise ValueError("Empty garment envelope ring")
    x = np.concatenate([good - n, good, good + n])
    y = np.concatenate([values[good]] * 3)
    return np.interp(np.arange(n), x, y)


def gaussian_rows(values, sigma):
    span = 3 * int(math.ceil(sigma))
    k = np.exp(-0.5 * (np.arange(-span, span + 1) / sigma) ** 2)
    k /= k.sum()
    pad = np.pad(values, ((span, span),) + ((0, 0),) * (values.ndim - 1), mode="edge")
    return np.array([np.tensordot(k, pad[i:i + len(k)], axes=(0, 0)) for i in range(len(values))])


class Rig:
    def __init__(self, joints: dict):
        self.j = {k: np.asarray(v, float) for k, v in joints.items()}

    def __getitem__(self, name):
        return self.j[name]

    def arm_distance(self, points):
        out = []
        for s in "LR":
            out.append(segment_distance(points, self["Arm_" + s], self["Forearm_" + s])[0])
            out.append(segment_distance(points, self["Forearm_" + s], self["Hand_" + s])[0])
            tip = self["FingerCurl_" + s] + (self["FingerCurl_" + s] - self["Hand_" + s])
            out.append(segment_distance(points, self["Hand_" + s], tip)[0])
        return np.min(out, axis=0)

    def hand_distance(self, points):
        out = []
        for s in "LR":
            tip = self["FingerCurl_" + s] + (self["FingerCurl_" + s] - self["Hand_" + s])
            out.append(segment_distance(points, self["Hand_" + s], tip)[0])
        return np.min(out, axis=0)


class Garment:
    """Analytic tunic: torso/skirt ring tube, shoulder yoke, two sleeves, belt."""

    THETA_BINS = 72

    def __init__(self, rig: Rig, vertices: np.ndarray):
        self.rig = rig
        self._fit(np.asarray(vertices, float))

    # ---------------------------------------------------------------- fitting
    def _fit(self, v):
        rig = self.rig
        torso_like = rig.arm_distance(v) > 0.075
        mid_x = 0.5 * (rig["Arm_L"][0] + rig["Arm_R"][0])
        lateral = abs(rig["Arm_L"][0] - rig["Arm_R"][0]) * 0.5
        ys = np.arange(HEM_Y - 0.01, SHOULDER_RING_Y + 0.0001, RING_STEP_M)
        rings, centres = [], []
        for y in ys:
            m = torso_like & (np.abs(v[:, 1] - y) < 0.012)
            if y > 1.06:
                # Above the armpit the pauldron flaps are not body width.
                m &= np.abs(v[:, 0] - mid_x) < lateral + 0.012
            if y < 0.80:
                m &= np.abs(v[:, 0]) < 0.215          # hands hang beside the skirt
            p = v[m]
            if len(p) < 20:
                raise ValueError(f"Too few envelope samples at {y:.2f} m")
            cx = 0.5 * (p[:, 0].min() + p[:, 0].max())
            cz = 0.5 * (p[:, 2].min() + p[:, 2].max())
            centres.append((cx, cz))
            ang = np.arctan2(p[:, 0] - cx, p[:, 2] - cz) % (2 * np.pi)
            rad = np.hypot(p[:, 0] - cx, p[:, 2] - cz)
            bins = (ang / (2 * np.pi) * self.THETA_BINS).astype(int) % self.THETA_BINS
            env = np.full(self.THETA_BINS, np.nan)
            for k in range(self.THETA_BINS):
                sel = rad[bins == k]
                if len(sel):
                    # 92nd percentile: rivets and strap edges are not cloth.
                    env[k] = np.percentile(sel, 92)
            rings.append(circular_smooth(fill_circular(env), 2.2))
        rings = gaussian_rows(np.array(rings), 2.2)
        # Wool hangs: below the seat the skirt never narrows toward the hem
        # (the old linen skirt ballooned in). Cumulative maximum downward.
        seat = int(np.searchsorted(ys, 0.76))
        for i in range(seat - 1, -1, -1):
            rings[i] = np.maximum(rings[i], rings[i + 1])
        self.ring_y = ys
        self.ring_r, self.ring_c = self._symmetrise(ys, rings, gaussian_rows(np.array(centres), 2.2))
        self.arm_r = {side: self._fit_arm(v, side) for side in "LR"}

    def midline(self, y):
        """Body midline x at height y (the rig leans a little to its left)."""
        rig = self.rig
        names = ("Pelvis", "Lumbar", "Chest", "Neck")
        return np.interp(y, [rig[n][1] for n in names], [rig[n][0] for n in names])

    def _symmetrise(self, ys, rings, centres):
        """Mirror the envelope about the body midline: the old shell carried
        asymmetric gear (belt fittings, the sword side) that wool does not."""
        n = self.THETA_BINS
        theta = np.arange(n) * 2 * np.pi / n
        out_r, out_c = np.empty_like(rings), np.empty_like(centres)
        for i, y in enumerate(ys):
            x0 = float(self.midline(y))
            cz = centres[i, 1]
            px = centres[i, 0] + rings[i] * np.sin(theta) - x0
            pz = rings[i] * np.cos(theta)
            ang = np.arctan2(px, pz) % (2 * np.pi)
            rad = np.hypot(px, pz)
            order = np.argsort(ang)
            a = np.concatenate([ang[order] - 2 * np.pi, ang[order], ang[order] + 2 * np.pi])
            r = np.concatenate([rad[order]] * 3)
            own = np.interp(theta, a, r)
            mirrored = np.interp((-theta) % (2 * np.pi), a, r)
            out_r[i] = 0.5 * (own + mirrored)
            out_c[i] = (x0, cz)
        return out_r, out_c

    def _fit_arm(self, v, side):
        """Envelope radius of the bare upper arm about its axis, per angle,
        measured between the old linen sleeve and the elbow."""
        a, b, axis, u, w = self.sleeve_axis(side)
        t, r = segment_param(v, a, b)
        sel = (t > 0.62) & (t < 0.90) & (r < 0.085)
        q = v[sel] - a
        phi = np.arctan2(q @ w, q @ u) % (2 * np.pi)
        bins = (phi / (2 * np.pi) * ARM_PHI_BINS).astype(int) % ARM_PHI_BINS
        env = np.full(ARM_PHI_BINS, np.nan)
        for k in range(ARM_PHI_BINS):
            m = r[sel][bins == k]
            if len(m) >= 4:
                env[k] = np.percentile(m, 90)
        return circular_smooth(fill_circular(env), 1.5)

    def arm_radius(self, side, phi):
        x = (np.asarray(phi, float) % (2 * np.pi)) / (2 * np.pi) * ARM_PHI_BINS - 0.5
        i0 = np.floor(x).astype(int)
        f = x - i0
        env = self.arm_r[side]
        return (1 - f) * env[i0 % ARM_PHI_BINS] + f * env[(i0 + 1) % ARM_PHI_BINS]

    # ------------------------------------------------------------ evaluation
    def _ring(self, y):
        y = np.clip(np.asarray(y, float), self.ring_y[0], self.ring_y[-1])
        i = np.clip(((y - self.ring_y[0]) / RING_STEP_M).astype(int), 0, len(self.ring_y) - 2)
        f = ((y - self.ring_y[i]) / RING_STEP_M)[..., None]
        return (1 - f) * self.ring_r[i] + f * self.ring_r[i + 1], (1 - f) * self.ring_c[i] + f * self.ring_c[i + 1]

    def body_radius(self, theta, y):
        """Smoothed envelope radius and ring centre (cx, cz) at (theta, y)."""
        theta, y = np.broadcast_arrays(np.asarray(theta, float), np.asarray(y, float))
        r, c = self._ring(y)
        x = (theta % (2 * np.pi)) / (2 * np.pi) * self.THETA_BINS
        i0 = np.floor(x).astype(int) % self.THETA_BINS
        f = x - np.floor(x)
        r0 = np.take_along_axis(r, i0[..., None], -1)[..., 0]
        r1 = np.take_along_axis(r, ((i0 + 1) % self.THETA_BINS)[..., None], -1)[..., 0]
        return (1 - f) * r0 + f * r1, (c[..., 0], c[..., 1])

    def tube_radius(self, theta, y, folds=True):
        """Final cloth radius about the ring centre (torso, waist, skirt)."""
        base, c = self.body_radius(theta, y)
        y = np.broadcast_to(np.asarray(y, float), base.shape)
        skirt = 1.0 - smoothstep(BELT_Y - 0.06, BELT_Y + 0.005, y)
        r = base - TORSO_SHRINK_M * (1.0 - skirt) + SKIRT_EASE_M * skirt
        front = np.maximum(np.cos(np.asarray(theta, float)), 0.0) ** 2
        r = r - BELLY_SHRINK_M * front * smoothstep(BELT_Y - 0.03, BELT_Y + 0.02, y) * (1 - smoothstep(0.97, 1.04, y))
        r = r + SHOULDER_WIDEN_M * np.sin(np.asarray(theta, float)) ** 2 * smoothstep(1.085, SHOULDER_RING_Y, y)
        r = r - WAIST_CINCH_M * np.exp(-0.5 * ((y - BELT_Y) / 0.012) ** 2)
        r = r + BLOUSE_M * np.exp(-0.5 * ((y - (BELT_Y + 0.028)) / 0.014) ** 2)
        # The wool hangs away from the thighs toward the hem.
        r = r + 0.008 * smoothstep(0.80, HEM_Y, y)
        if folds:
            r = r + self.fold(theta, y)
        return r, c

    @staticmethod
    def fold(theta, y):
        """Deterministic drape folds: hanging folds below the belt, a few soft
        diagonal folds where the wool is bloused above it."""
        theta = np.asarray(theta, float)
        y = np.asarray(y, float)
        skirt = smoothstep(BELT_Y - 0.01, HEM_Y + 0.05, y)          # 0 at belt, 1 near hem
        hem = (0.0030 + 0.0100 * skirt) * (
            0.55 * np.sin(7 * theta + 0.6 + 1.1 * skirt)
            + 0.30 * np.sin(12 * theta + 2.1 - 0.8 * skirt)
            + 0.15 * np.sin(19 * theta + 4.0 + 0.5 * skirt))
        lower = 1 - smoothstep(BELT_Y - 0.004, BELT_Y + 0.004, y)
        above = smoothstep(BELT_Y + 0.008, BELT_Y + 0.03, y) * (1 - smoothstep(0.96, 1.05, y))
        lean = (y - BELT_Y) * 9.0
        blouse = 0.0022 * (np.sin(5 * theta + lean + 0.3) + 0.6 * np.sin(8 * theta - lean + 1.9))
        return hem * lower + blouse * above

    def tube_point(self, theta, y, folds=True):
        r, (cx, cz) = self.tube_radius(theta, y, folds)
        theta, y = np.broadcast_arrays(np.asarray(theta, float), np.asarray(y, float))
        return np.stack([cx + r * np.sin(theta), y, cz + r * np.cos(theta)], -1)

    # -------------------------------------------------------------- neckline
    def neck_point(self, theta):
        rig = self.rig
        c = 0.5 * (rig["Neck"] + rig["Head"])
        theta = np.asarray(theta, float)
        front = np.maximum(np.cos(theta), 0)
        back = np.maximum(-np.cos(theta), 0)
        side = np.abs(np.sin(theta))
        y = (NECK_RING["front"] * front ** 2 + NECK_RING["side"] * side ** 2 + NECK_RING["back"] * back ** 2) / (
            front ** 2 + side ** 2 + back ** 2)
        r = NECK_RADIUS_M + 0.006 * front
        return np.stack([c[0] + r * np.sin(theta), y, c[2] + 0.004 + r * np.cos(theta)], -1)

    def shoulder_cap(self, theta, s):
        """Yoke from the top horizontal ring (s=0) to the neckline (s=1)."""
        theta = np.asarray(theta, float)
        p0 = self.tube_point(theta, np.full_like(theta, SHOULDER_RING_Y), folds=False)
        _, (cx, cz) = self.tube_radius(theta, np.full_like(theta, SHOULDER_RING_Y), folds=False)
        p1 = self.neck_point(theta)
        lateral = np.abs(np.sin(theta))
        mid = 0.55 * p0 + 0.45 * p1
        mid[..., 1] = np.maximum(p0[..., 1], p1[..., 1]) + 0.010 + 0.040 * lateral ** 1.5
        out = mid - np.stack([cx, mid[..., 1], cz], -1)
        out[..., 1] = 0
        mid = mid + 0.012 * out / np.maximum(np.linalg.norm(out, axis=-1, keepdims=True), 1e-9)
        s = np.asarray(s, float)[..., None]
        return (1 - s) ** 2 * p0 + 2 * s * (1 - s) * mid + s ** 2 * p1

    # ---------------------------------------------------------------- sleeves
    def sleeve_axis(self, side):
        a, b = self.rig["Arm_" + side], self.rig["Forearm_" + side]
        axis = (b - a) / np.linalg.norm(b - a)
        out = np.array([1.0 if side == "L" else -1.0, 0, 0])
        u = out - axis * (out @ axis)
        u /= np.linalg.norm(u)
        w = np.cross(axis, u)
        return a, b, axis, u, w

    def sleeve_radius(self, side, t, phi, folds=True):
        """Radius about the upper-arm axis: the measured arm plus ease, fuller
        over the deltoid, hanging away from the arm on the body side toward
        the hem. phi = 0 points away from the body, pi toward it."""
        t = np.asarray(t, float)
        phi = np.asarray(phi, float)
        open_hem = smoothstep(0.15, SLEEVE_HEM_T, t)
        r = self.arm_radius(side, phi) + SLEEVE_EASE_M + 0.008 * (1 - smoothstep(0.0, 0.45, t))
        r = r + 0.007 * open_hem * np.maximum(-np.cos(phi), 0)
        if folds:
            r = r + 0.0022 * (np.sin(4 * phi + 2.3 * t + 0.4) + 0.5 * np.sin(7 * phi - 1.7 * t + 2.0)) * open_hem
        return r

    def sleeve_point(self, side, t, phi, folds=True):
        a, b, axis, u, w = self.sleeve_axis(side)
        r = self.sleeve_radius(side, t, phi, folds)
        centre = a + (b - a) * np.asarray(t, float)[..., None]
        phi = np.asarray(phi, float)[..., None]
        return centre + r[..., None] * (np.cos(phi) * u + np.sin(phi) * w)

    def sleeve_dome(self, side, alpha, phi):
        """Shoulder dome closing the sleeve above the joint (alpha = 0 at the
        pole, pi/2 at the first tube ring). A sphere about the shoulder joint
        keeps its place under the yoke however the arm turns."""
        a, b, axis, u, w = self.sleeve_axis(side)
        phi = np.asarray(phi, float)
        alpha = np.asarray(alpha, float)[..., None]
        r0 = self.sleeve_radius(side, np.zeros_like(phi), phi, folds=False)
        height = float(np.mean(r0))
        phi = phi[..., None]
        return a - axis * height * np.cos(alpha) + r0[..., None] * np.sin(alpha) * (np.cos(phi) * u + np.sin(phi) * w)

    # ----------------------------------------------------------- containment
    def radial(self, points):
        """Polar angle/radius of points about the ring centre at their height."""
        _, c = self._ring(points[:, 1])
        theta = np.arctan2(points[:, 0] - c[:, 0], points[:, 2] - c[:, 1]) % (2 * np.pi)
        radius = np.hypot(points[:, 0] - c[:, 0], points[:, 2] - c[:, 1])
        return theta, radius, c

    def cap_height(self, theta, radius):
        """Yoke height above a point at (theta, horizontal radius), or NaN outside."""
        s = np.linspace(0, 1, 33)
        th = np.repeat(np.asarray(theta, float)[:, None], len(s), 1)
        pts = self.shoulder_cap(th, np.broadcast_to(s, th.shape))
        _, (cx, cz) = self.tube_radius(theta, np.full(len(theta), SHOULDER_RING_Y), folds=False)
        rad = np.hypot(pts[..., 0] - cx[:, None], pts[..., 2] - cz[:, None])
        out = np.full(len(theta), np.nan)
        for i in range(len(theta)):
            order = np.argsort(rad[i])
            if rad[i, order[0]] <= radius[i] <= rad[i, order[-1]]:
                out[i] = np.interp(radius[i], rad[i, order], pts[i, order, 1])
        return out

    def depth_inside(self, points):
        """Signed clearance of points inside the closed tunic volume (m, >0 inside).

        Inside the tube below the shoulder ring: R - r. In the yoke: the
        smaller of the horizontal and vertical clearance. Sleeves: R_s - r_s.
        Points outside every part get the (negative) best value.
        """
        p = np.asarray(points, float)
        best = np.full(len(p), -1.0)
        theta, radius, _ = self.radial(p)
        tube = (p[:, 1] >= HEM_Y) & (p[:, 1] <= SHOULDER_RING_Y)
        if tube.any():
            r, _ = self.tube_radius(theta[tube], p[tube, 1], folds=False)
            best[tube] = np.maximum(best[tube], np.minimum(r - radius[tube], p[tube, 1] - HEM_Y + 0.05))
        yoke = (p[:, 1] > SHOULDER_RING_Y) & (p[:, 1] < 1.30)
        if yoke.any():
            r0, _ = self.tube_radius(theta[yoke], np.full(yoke.sum(), SHOULDER_RING_Y), folds=False)
            h = self.cap_height(theta[yoke], radius[yoke])
            vertical = np.where(np.isfinite(h), h - p[yoke, 1], np.where(radius[yoke] < r0, -1.0, -1.0))
            # Points under the neck opening are outside (they are the neck).
            neck = self.neck_point(theta[yoke])
            ncx = 0.5 * (self.rig["Neck"][0] + self.rig["Head"][0])
            ncz = 0.5 * (self.rig["Neck"][2] + self.rig["Head"][2]) + 0.004
            neck_r = np.hypot(neck[:, 0] - ncx, neck[:, 2] - ncz)
            own_r = np.hypot(p[yoke, 0] - ncx, p[yoke, 2] - ncz)
            vertical = np.where(own_r < neck_r - 0.002, -1.0, vertical)
            best[yoke] = np.maximum(best[yoke], np.minimum(vertical, r0 - radius[yoke] + 0.25))
        for side in "LR":
            a, b, axis, u, w = self.sleeve_axis(side)
            t, rr = segment_param(p, a, b)
            phi = np.arctan2((p - a) @ w, (p - a) @ u)
            sel = (t >= SLEEVE_START_T) & (t <= SLEEVE_HEM_T)
            if sel.any():
                rs = self.sleeve_radius(side, t[sel], phi[sel], folds=False)
                best[sel] = np.maximum(best[sel], np.minimum(rs - rr[sel], (SLEEVE_HEM_T - t[sel]) * np.linalg.norm(b - a)))
            dome = t < SLEEVE_START_T
            if dome.any():
                r0 = self.sleeve_radius(side, np.zeros(dome.sum()), phi[dome], folds=False)
                best[dome] = np.maximum(best[dome], r0 - np.linalg.norm(p[dome] - a, axis=1))
        return best
