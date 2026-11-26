#!/usr/bin/env python3
"""Measure F0 statistics and mean formants (F1-F3) of voiced speech.

Uses Praat via parselmouth. The F0 floor/ceiling and formant ceiling are
chosen per expected speaker class so that child voices are not clipped.
"""
import argparse, json, sys
import numpy as np
import parselmouth
from parselmouth.praat import call


def measure(path, f0_min=60.0, f0_max=600.0, formant_ceiling=None):
    snd = parselmouth.Sound(path)
    pitch = snd.to_pitch_ac(time_step=0.01, pitch_floor=f0_min, pitch_ceiling=f0_max)
    f0 = pitch.selected_array["frequency"]
    voiced = f0[f0 > 0]
    if voiced.size == 0:
        return {"file": path, "voiced": 0}
    median = float(np.median(voiced))
    # Praat guidance: 5000 Hz for adult men, 5500 for women, higher for children.
    if formant_ceiling is None:
        formant_ceiling = 5000.0 if median < 160 else (5500.0 if median < 240 else 6500.0)
    formant = snd.to_formant_burg(time_step=0.01, max_number_of_formants=5, maximum_formant=formant_ceiling)
    times = pitch.xs()[f0 > 0]
    fs = {}
    for k in (1, 2, 3):
        vals = np.array([call(formant, "Get value at time", k, t, "Hertz", "Linear") for t in times])
        vals = vals[np.isfinite(vals)]
        fs["F%d" % k] = round(float(np.median(vals)), 1) if vals.size else None
    return {
        "file": path,
        "duration_s": round(snd.duration, 3),
        "voiced_fraction": round(voiced.size / max(1, f0.size), 3),
        "f0_median_hz": round(median, 1),
        "f0_p05_hz": round(float(np.percentile(voiced, 5)), 1),
        "f0_p95_hz": round(float(np.percentile(voiced, 95)), 1),
        "formant_ceiling_hz": formant_ceiling,
        **fs,
    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    for f in a.files:
        print(json.dumps(measure(f), ensure_ascii=False))
