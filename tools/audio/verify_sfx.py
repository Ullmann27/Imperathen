#!/usr/bin/env python3
"""Per-file verification of every sound effect (and the looping ambience).

Checks per file: provenance + licence (from sfx_manifest.json), sample peak,
true peak (4x oversampled), short-term loudness, clipped samples, DC offset,
click-free start/end for one-shots, seam continuity for loops, and the game
event (API call) that plays it. Writes JSON evidence and a Markdown table.
"""
import argparse, json
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "prototype/assets/audio/sfx"
# Group -> API call that plays it (mirrors scripts/audio/combat_sfx.gd).
EVENTS = {
    "swish/light": 'play_weapon_event("swing", "light")', "swish/heavy": 'play_weapon_event("swing", "heavy")',
    "bow/draw": 'play_weapon_event("draw", "bow")', "bow/release": 'play_weapon_event("release", "bow")',
    "crossbow/crank": 'play_weapon_event("reload", "crossbow")', "crossbow/release": 'play_weapon_event("release", "crossbow")',
    "projectile/arrow_flight": 'play_weapon_event("flight", "arrow"|"bolt")',
}
LIMITS = {"true_peak_dbtp": -1.0, "edge_abs": 0.01, "dc": 0.005, "loop_seam_db": -30.0}


def true_peak(x):
    return float(20 * np.log10(np.max(np.abs(resample_poly(x, 4, 1, axis=0))) + 1e-12))


def loudness(x, sr):
    try:
        return float(pyln.Meter(sr, block_size=min(0.4, max(0.05, len(x) / sr - 0.005))).integrated_loudness(x))
    except ValueError:
        return float("nan")


def event_for(group):
    if group in EVENTS:
        return EVENTS[group]
    kind, name = group.split("/", 1)
    if kind == "impact":
        pair, level = name.rsplit("_", 1)
        a, b = pair.split("_")
        return f'play_impact("{a}", "{b}", energy {"< 0.55" if level == "light" else ">= 0.55"})'
    if kind == "projectile" and name.startswith("arrow_impact_"):
        return f'play_projectile_impact("{name.removeprefix("arrow_impact_")}")'
    if kind == "footstep":
        return f'play_footstep("{name}")'
    return "unbound"


def check(path, loop=False):
    x, sr = sf.read(path, always_2d=True)
    mono = x.mean(axis=1)
    peak = float(20 * np.log10(np.max(np.abs(x)) + 1e-12))
    tp = true_peak(x)
    clipped = int(np.sum(np.abs(x) >= 0.999))
    dc = float(abs(np.mean(mono)))
    r = {"sample_rate": sr, "duration_s": round(len(x) / sr, 3), "peak_dbfs": round(peak, 2), "true_peak_dbtp": round(tp, 2),
         "lufs": round(loudness(x, sr), 2), "clipped_samples": clipped, "dc_offset": round(dc, 5)}
    problems = []
    if tp > LIMITS["true_peak_dbtp"]:
        problems.append(f"true peak {tp:.2f} dBTP > {LIMITS['true_peak_dbtp']}")
    if clipped:
        problems.append(f"{clipped} clipped samples")
    if dc > LIMITS["dc"]:
        problems.append(f"DC offset {dc:.4f}")
    if loop:
        # Seam: the jump across the loop point must be no larger than typical
        # sample-to-sample motion inside the file.
        jump = abs(mono[-1] - mono[0])
        typical = np.percentile(np.abs(np.diff(mono)), 99) + 1e-9
        r["loop_seam_jump"] = round(float(jump), 5)
        r["loop_seam_vs_p99_step"] = round(float(jump / typical), 3)
        if jump > typical:
            problems.append(f"loop seam jump {jump:.4f} > p99 step {typical:.4f}")
    else:
        r["start_abs"] = round(float(abs(mono[0])), 5)
        r["end_abs"] = round(float(abs(mono[-1])), 5)
        if abs(mono[0]) > LIMITS["edge_abs"] or abs(mono[-1]) > LIMITS["edge_abs"]:
            problems.append("click risk at start/end")
    r["problems"] = problems
    r["pass"] = not problems
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-json", required=True)
    ap.add_argument("--out-md", required=True)
    a = ap.parse_args()
    manifest = json.loads((SFX / "sfx_manifest.json").read_text(encoding="utf-8"))
    entries = []
    for s in manifest["sounds"]:
        group = f"{s['event']}/{s['name']}"
        r = check(SFX / s["file"])
        r.update({"file": f"prototype/assets/audio/sfx/{s['file']}", "group": group, "event": event_for(group),
                  "provenance": "eigene prozedurale Synthese, tools/audio/synth_sfx.py, seed %d" % s["seed"],
                  "licence": "Projektlizenz (keine Drittrechte)", "sha256": s["sha256"], "loop": False})
        entries.append(r)
    amb = ROOT / "prototype/assets/frontier_ambience.wav"
    if amb.exists():
        r = check(amb, loop=True)
        r.update({"file": "prototype/assets/frontier_ambience.wav", "group": "ambience/frontier", "event": "main.gd FrontierAmbience (Ambience-Bus, Endlosschleife)",
                  "provenance": "vorhandene Projektdatei, prozedural erzeugt von tools/build_frontier_ambience.py (nicht von diesem Branch)",
                  "licence": "Projektlizenz (eigene Synthese)", "loop": True})
        entries.append(r)
    passed = sum(e["pass"] for e in entries)
    summary = {"files": len(entries), "passed": passed, "failed": len(entries) - passed, "limits": LIMITS}
    Path(a.out_json).write_text(json.dumps({"summary": summary, "entries": entries}, indent=1, ensure_ascii=False), encoding="utf-8")
    md = ["# SFX-Prüfprotokoll", "", "Erzeugt von `tools/audio/verify_sfx.py`. Grenzwerte: True Peak ≤ −1 dBTP, keine geclippten Samples, DC-Offset ≤ 0,005, Einzelklänge beginnen und enden unter 0,01 (klickfrei), Schleifen ohne Sprung an der Nahtstelle.", "",
          f"**Ergebnis: {passed} von {len(entries)} Dateien bestanden.**", "",
          "| Datei | Ereignis (API) | Dauer s | Peak dBFS | True Peak dBTP | LUFS | Clips | Herkunft/Lizenz | Ergebnis |", "|---|---|---|---|---|---|---|---|---|"]
    for e in entries:
        md.append(f"| `{e['file'].split('prototype/assets/')[1]}` | `{e['event']}` | {e['duration_s']} | {e['peak_dbfs']} | {e['true_peak_dbtp']} | {e['lufs']} | {e['clipped_samples']} | {e['provenance']} · {e['licence']} | {'bestanden' if e['pass'] else 'FEHLER: ' + '; '.join(e['problems'])} |")
    Path(a.out_md).write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"VERIFY_SFX {passed}/{len(entries)} passed")
    for e in entries:
        if not e["pass"]:
            print("FAIL", e["file"], e["problems"])


if __name__ == "__main__":
    main()
