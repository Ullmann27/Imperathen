#!/usr/bin/env python3
"""Procedural, physically informed combat and footstep sound synthesis.

Every file is produced from this script with a fixed seed, so provenance is
complete (own work, released with the project). No recordings are used.

Model:
  * Impacts: a contact excitation (raised-cosine force pulse whose width
    follows material hardness, plus friction noise) drives the modal
    resonances of BOTH colliding objects (modal synthesis, cf. van den Doel,
    Kry & Pai 2001 "FoleyAutomatic"; Cook 2002 "Real Sound Synthesis").
  * Bow/crossbow strings: Karplus-Strong plucked string with tension-dependent
    pitch and damping, plus limb/stock body modes.
  * Swishes and arrow flight: band-pass filtered noise with swept centre and
    flutter (aerodynamic tones), amplitude envelope from the swing velocity.
  * Footsteps: heel and toe contact pulses filtered by surface spectra; gravel
    and grass add granular crunch.

Usage: python tools/audio/synth_sfx.py --out prototype/assets/audio/sfx
"""
import argparse, hashlib, json
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, lfilter

SR = 44100
VERSION = 1

# Modal descriptions: (frequency Hz, decay time s, relative amplitude).
MATERIALS = {
    # Iron/steel blade: inharmonic free-bar modes, long ring.
    "metal": {"pulse_ms": 0.25, "noise": 0.25, "noise_hp": 2500,
              "modes": [(612, 1.1, 1.0), (1687, 0.8, 0.7), (3307, 0.55, 0.5), (5467, 0.35, 0.35), (8164, 0.2, 0.2), (2390, 0.6, 0.3), (4120, 0.4, 0.25)]},
    # Wooden shield/haft: plate modes, short decays, strong body.
    "wood": {"pulse_ms": 1.2, "noise": 0.45, "noise_hp": 600,
             "modes": [(168, 0.09, 1.0), (342, 0.07, 0.8), (571, 0.05, 0.6), (893, 0.04, 0.45), (1420, 0.03, 0.3), (2210, 0.02, 0.2)]},
    # Leather-covered target / armour: heavily damped low body plus slap.
    "leather": {"pulse_ms": 3.5, "noise": 0.7, "noise_hp": 300,
                "modes": [(110, 0.05, 1.0), (240, 0.035, 0.6), (520, 0.02, 0.3)]},
    # Body: soft tissue thump with optional bone crack component.
    "flesh": {"pulse_ms": 7.0, "noise": 0.5, "noise_hp": 150,
              "modes": [(68, 0.07, 1.0), (130, 0.05, 0.7), (260, 0.03, 0.35)]},
    "bone": {"pulse_ms": 0.6, "noise": 0.6, "noise_hp": 1800,
             "modes": [(1300, 0.02, 1.0), (2700, 0.012, 0.6), (4100, 0.008, 0.4)]},
    "stone": {"pulse_ms": 0.5, "noise": 0.6, "noise_hp": 1200,
              "modes": [(900, 0.03, 1.0), (1850, 0.02, 0.6), (3300, 0.015, 0.4)]},
    "earth": {"pulse_ms": 5.0, "noise": 0.8, "noise_hp": 100,
              "modes": [(80, 0.04, 1.0), (170, 0.03, 0.5)]},
}
# How strongly a partner material damps the other body's ringing while in
# contact (a blade embedded in a shield or body stops ringing quickly).
CONTACT_DAMPING = {"metal": 1.0, "stone": 0.6, "wood": 0.3, "bone": 0.25, "leather": 0.12, "flesh": 0.05, "earth": 0.08}
# Relative loudness contribution of each body's resonance in a collision.
BODY_GAIN = {"metal": 0.8, "wood": 1.0, "leather": 0.9, "flesh": 1.0, "bone": 0.5, "stone": 0.8, "earth": 1.0}
IMPACT_PAIRS = ["metal_metal", "metal_wood", "metal_leather", "metal_flesh", "wood_wood", "wood_flesh", "flesh_flesh", "leather_flesh", "metal_bone"]


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, min(hi, SR / 2 - 100)], btype="band", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 100), btype="low", fs=SR, output="sos"), x)


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def pulse(ms):
    n = max(2, int(ms * SR / 1000))
    return 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / n)


def modal(excitation, modes, rng, detune=0.03, length=1.5, tau_scale=1.0, beating=0.0):
    n = int(length * SR)
    out = np.zeros(n)
    exc = np.zeros(n)
    exc[:len(excitation)] = excitation[:n]
    for f, tau, amp in modes:
        f = f * (1 + rng.uniform(-detune, detune))
        tau = tau * rng.uniform(0.85, 1.15) * tau_scale
        r = np.exp(-1.0 / (tau * SR))
        # Two-pole resonator driven by the excitation; an optional slightly
        # detuned twin mode gives the beating of real, imperfect blades.
        for ff, aa in ((f, amp), (f * (1 + rng.uniform(0.002, 0.007)), amp * beating)):
            if aa <= 0:
                continue
            w = 2 * np.pi * ff / SR
            out += lfilter([aa * np.sin(w)], [1, -2 * r * np.cos(w), r * r], exc)
    return out


def contact(material, energy, rng, length):
    m = MATERIALS[material]
    width = m["pulse_ms"] * (1.25 - 0.5 * energy) * rng.uniform(0.85, 1.15)
    p = pulse(width)
    n = int(length * SR)
    noise = rng.standard_normal(n) * env_exp(n, 0.004 + 0.01 * (1 - energy))
    noise = hp(noise, m["noise_hp"]) * m["noise"] * (0.5 + energy)
    return p, noise


def impact(a, b, energy, rng):
    length = 1.6 if "metal" in (a, b) else 0.6
    out = np.zeros(int(length * SR))
    for mat, partner in ((a, b), (b, a)):
        p, noise = contact(mat, energy, rng, length)
        res = modal(p, MATERIALS[mat]["modes"], rng, length=length, tau_scale=CONTACT_DAMPING[partner],
                    beating=0.6 if mat == "metal" else 0.0)
        res /= (np.max(np.abs(res)) + 1e-9)
        out += BODY_GAIN[mat] * res + 0.5 * noise[:len(out)]
    if a == "metal" and b == "metal":
        # Blade-on-blade scrape: short band-limited friction tail.
        n = int(0.18 * SR)
        scrape = bp(rng.standard_normal(n), 2500, 9000) * np.linspace(1, 0, n) ** 2 * 0.35 * energy
        out[:n] += scrape
    if b == "flesh" or a == "flesh":
        out = lp(out, 900 + 3000 * energy) + 0.15 * out
    return out


def karplus(f0, seconds, damping, rng, brightness=0.5):
    n = int(seconds * SR)
    period = int(SR / f0)
    buf = rng.uniform(-1, 1, period)
    buf = lp(buf, 1500 + 6000 * brightness)
    out = np.zeros(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = damping * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out


def swish(weight, rng):
    dur = (0.28 if weight == "light" else 0.42) * rng.uniform(0.9, 1.1)
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    envelope = np.sin(np.pi * t) ** (2.5 if weight == "light" else 1.8)
    centre = (700 if weight == "light" else 380) * (1 + 1.8 * np.sin(np.pi * t))
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    block = 512
    for i in range(0, n, block):
        c = centre[i]
        seg = noise[max(0, i - 2048):i + block]
        y = bp(seg, c * 0.6, c * 1.6)
        out[i:i + block] = y[-len(out[i:i + block]):]
    flutter = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(18, 30) * t * dur)
    return out * envelope * flutter


def bow_draw(rng):
    dur = 1.1 * rng.uniform(0.9, 1.1)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Wood limb creak: sparse friction grains with rising density + string stretch.
    grains = np.zeros(n)
    rate = 25 + 60 * (t / dur)
    pos = 0.0
    while pos < dur:
        k = int(pos * SR)
        g = modal(pulse(0.4), [(rng.uniform(380, 520), 0.015, 1.0), (rng.uniform(900, 1300), 0.01, 0.5)], rng, length=0.04)
        grains[k:k + len(g)] += g[:n - k] * rng.uniform(0.3, 1.0)
        pos += rng.exponential(1.0 / rate[min(k, n - 1)])
    stretch = bp(rng.standard_normal(n), 1500, 5000) * 0.05 * (t / dur)
    return (grains / (np.max(np.abs(grains)) + 1e-9)) * 0.6 + stretch


def string_release(kind, rng):
    if kind == "bow":
        f0, dur, damp, thump_f = rng.uniform(95, 125), 0.45, 0.996, 85
    else:  # crossbow: shorter, stiffer prod, heavier stock
        f0, dur, damp, thump_f = rng.uniform(150, 190), 0.3, 0.990, 120
    s = karplus(f0, dur, damp, rng, brightness=0.6 if kind == "bow" else 0.85)
    s *= env_exp(len(s), 0.08 if kind == "bow" else 0.05)
    n = len(s)
    body = modal(pulse(2.0), [(thump_f, 0.06, 1.0), (thump_f * 2.7, 0.03, 0.4)], rng, length=dur)
    body /= np.max(np.abs(body)) + 1e-9
    whap = hp(rng.standard_normal(n), 800) * env_exp(n, 0.006) * 0.6
    out = s / (np.max(np.abs(s)) + 1e-9) + 0.8 * body + whap
    if kind == "crossbow":
        click = modal(pulse(0.2), [(3200, 0.01, 1.0), (5100, 0.008, 0.6)], rng, length=0.05)
        pre = int(0.03 * SR)
        out = np.concatenate([np.zeros(pre), out])
        out[:len(click)] += click / (np.max(np.abs(click)) + 1e-9) * 0.5
    return out


def arrow_flight(rng):
    dur = 0.9
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    noise = rng.standard_normal(n)
    out = bp(noise, 900, 3500) * 0.5 + bp(noise, 250, 700) * 0.6
    flutter = 1 + 0.5 * np.sin(2 * np.pi * rng.uniform(35, 55) * t * dur)
    # Pass-by: rise, peak at 40 %, fall; slight high-frequency loss after the pass.
    envelope = np.exp(-((t - 0.4) / 0.22) ** 2)
    return out * flutter * envelope


def arrow_impact(target, rng):
    base = impact("wood" if target != "metal" else "metal", target, 0.8, rng)[: int(0.6 * SR)]
    n = len(base)
    # Shaft vibration ("thrum") after embedding in a soft or wooden target.
    if target in ("wood", "flesh", "earth", "leather"):
        f = rng.uniform(55, 80)
        tt = np.arange(n) / SR
        thrum = np.sin(2 * np.pi * f * 3 * tt) * (0.5 + 0.5 * np.sin(2 * np.pi * f * tt)) * env_exp(n, 0.09) * 0.35
        base = base / (np.max(np.abs(base)) + 1e-9) + thrum
    return base


def crank(rng):
    clicks = 9
    out = np.zeros(int(1.4 * SR))
    pos = 0.05
    for i in range(clicks):
        k = int(pos * SR)
        c = modal(pulse(0.15), [(rng.uniform(2600, 3000), 0.012, 1.0), (rng.uniform(4300, 4800), 0.008, 0.5), (rng.uniform(700, 900), 0.02, 0.3)], rng, length=0.06)
        c /= np.max(np.abs(c)) + 1e-9
        out[k:k + len(c)] += c * rng.uniform(0.6, 1.0)
        pos += rng.uniform(0.11, 0.15)
    n = len(out)
    creak = bp(rng.standard_normal(n), 300, 1200) * 0.04 * (np.sin(np.pi * np.linspace(0, 1, n)))
    return out + creak


def footstep(surface, rng):
    n = int(0.35 * SR)
    out = np.zeros(n)
    spec = {"dirt": (90, 1800, 0.012, 0.0), "stone": (300, 6000, 0.006, 0.0), "wood": (120, 3500, 0.01, 0.0),
            "grass": (150, 4000, 0.012, 0.6), "gravel": (150, 3000, 0.008, 1.0)}[surface]
    lo, hi, tau, grain = spec
    for offset, gain in ((0.0, 1.0), (rng.uniform(0.045, 0.07), 0.55)):  # heel then toe
        k = int(offset * SR)
        m = n - k
        burst = bp(rng.standard_normal(m), lo, hi) * env_exp(m, tau * rng.uniform(0.8, 1.2)) * gain
        if surface == "wood":
            burst += modal(pulse(1.0), [(rng.uniform(140, 190), 0.05, 1.0), (rng.uniform(380, 450), 0.03, 0.5)], rng, length=m / SR)[:m] * 0.02 * gain
        if surface == "stone":
            burst += modal(pulse(0.5), [(rng.uniform(800, 1000), 0.01, 1.0)], rng, length=m / SR)[:m] * 0.01 * gain
        out[k:] += burst
    if grain > 0:
        # Discrete crunch grains (stones shifting / blades of grass breaking),
        # densest at heel contact and thinning out over ~120 ms.
        g = np.zeros(n)
        for _ in range(int(30 * grain + 8)):
            k = int(rng.exponential(0.035) * SR)
            if k >= n - 400:
                continue
            if surface == "gravel":
                c = modal(pulse(0.1), [(rng.uniform(2000, 6000), 0.004, 1.0)], rng, length=0.008)
            else:
                d = int(rng.uniform(0.0008, 0.002) * SR)
                c = rng.standard_normal(d) * np.hanning(d)
            g[k:k + len(c)] += c / (np.max(np.abs(c)) + 1e-9) * rng.uniform(0.15, 1.0)
        out = out / (np.max(np.abs(out)) + 1e-9) + hp(g, 1200 if surface == "gravel" else 3000) * 0.35 * grain
    return out


def finish(x, peak_db=-3.0):
    x = np.asarray(x, dtype=np.float64)
    x = hp(x, 30, order=2)
    idx = np.where(np.abs(x) > 1e-4 * np.max(np.abs(x)))[0]
    x = x[: idx[-1] + 1] if idx.size else x
    f = min(int(0.005 * SR), len(x) // 4)
    if f > 0:
        x[-f:] *= np.linspace(1, 0, f)
    return (x / (np.max(np.abs(x)) + 1e-12) * 10 ** (peak_db / 20)).astype(np.float32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = Path(a.out)
    entries = []

    def save(event, name, i, data, seed, params, peak_db=-3.0):
        path = out / event / f"{name}_{i:02d}.wav"
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(path, finish(data, peak_db), SR, subtype="PCM_16")
        entries.append({"event": event, "name": name, "variant": i, "file": str(path.relative_to(out)), "seed": seed,
                        "params": params, "duration_s": round(sf.info(path).duration, 3),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})

    seed = 1000
    for pair in IMPACT_PAIRS:
        ma, mb = pair.split("_")
        for level, energy in (("light", 0.35), ("heavy", 0.9)):
            for i in range(4):
                seed += 1
                save("impact", f"{pair}_{level}", i, impact(ma, mb, energy, np.random.default_rng(seed)), seed,
                     {"materials": [ma, mb], "energy": energy}, -3.0 if level == "heavy" else -9.0)
    for weight in ("light", "heavy"):
        for i in range(4):
            seed += 1
            save("swish", weight, i, swish(weight, np.random.default_rng(seed)), seed, {"weight": weight}, -6.0)
    for i in range(3):
        seed += 1
        save("bow", "draw", i, bow_draw(np.random.default_rng(seed)), seed, {}, -12.0)
        seed += 1
        save("bow", "release", i, string_release("bow", np.random.default_rng(seed)), seed, {"kind": "bow"}, -4.0)
        seed += 1
        save("projectile", "arrow_flight", i, arrow_flight(np.random.default_rng(seed)), seed, {}, -8.0)
        seed += 1
        save("crossbow", "crank", i, crank(np.random.default_rng(seed)), seed, {}, -10.0)
        seed += 1
        save("crossbow", "release", i, string_release("crossbow", np.random.default_rng(seed)), seed, {"kind": "crossbow"}, -3.0)
    for target in ("wood", "flesh", "earth", "metal", "leather"):
        for i in range(3):
            seed += 1
            save("projectile", f"arrow_impact_{target}", i, arrow_impact(target, np.random.default_rng(seed)), seed, {"target": target}, -4.0)
    for surface in ("dirt", "stone", "wood", "grass", "gravel"):
        for i in range(4):
            seed += 1
            save("footstep", surface, i, footstep(surface, np.random.default_rng(seed)), seed, {"surface": surface}, -10.0)
    manifest = {"schema_version": 1, "generator": "tools/audio/synth_sfx.py", "generator_version": VERSION,
                "provenance": "Eigene prozedurale Synthese, keine Aufnahmen Dritter; Lizenz wie Projekt (CC0-Freigabe durch Projekt möglich).",
                "sample_rate": SR, "sounds": entries}
    (out / "sfx_manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    print("SYNTH_SFX_DONE", len(entries))


if __name__ == "__main__":
    main()
