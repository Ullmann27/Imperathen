#!/usr/bin/env python3
"""Loudness (ITU-R BS.1770-4 via pyloudnorm) and true peak (4x oversampled)
per mix bus, from the assets as they are routed with their player gains.

This measures the SOURCE signal per bus including the static player/bus gains
in the code (dialogue 0 dB, menu music MENU_MUSIC_DB = -9 dB, ambience -15 dB, SFX
event gains). It does NOT measure the live mix after the runtime compressor
and limiter: the headless/dummy audio driver here does not mix continuously.
"""
import argparse, json, subprocess, tempfile
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    path = Path(path)
    if path.suffix == ".ogg":
        with tempfile.TemporaryDirectory() as d:
            wav = Path(d) / "x.wav"
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(path), str(wav)], check=True)
            x, sr = sf.read(wav, always_2d=True)
    else:
        x, sr = sf.read(path, always_2d=True)
    return x, sr


def true_peak_db(x):
    up = resample_poly(x, 4, 1, axis=0)
    return float(20 * np.log10(np.max(np.abs(up)) + 1e-12))


def stats(files, gain_db=0.0):
    chunks, sr0, peaks, per = [], None, [], []
    for f in files:
        x, sr = read(f)
        x = x * 10 ** (gain_db / 20)
        if sr0 is None:
            sr0 = sr
        if sr != sr0:
            x = resample_poly(x, sr0, sr, axis=0)
        if x.shape[1] != (chunks[0].shape[1] if chunks else x.shape[1]):
            x = np.repeat(x.mean(axis=1, keepdims=True), chunks[0].shape[1], axis=1)
        chunks.append(x)
        chunks.append(np.zeros((int(0.3 * sr0), x.shape[1])))
        meter = pyln.Meter(sr0, block_size=min(0.4, max(0.1, len(x) / sr0 - 0.01)))
        try:
            l = meter.integrated_loudness(x)
        except ValueError:
            l = float("-inf")
        tp = true_peak_db(x)
        peaks.append(tp)
        per.append({"file": str(Path(f).relative_to(ROOT)), "lufs": round(l, 2) if np.isfinite(l) else None, "true_peak_dbtp": round(tp, 2)})
    allx = np.concatenate(chunks)
    meter = pyln.Meter(sr0)
    integ = meter.integrated_loudness(allx)
    # Momentary max (400 ms window, 100 ms hop) is the meaningful figure for transients.
    win, hop = int(0.4 * sr0), int(0.1 * sr0)
    mom = []
    for i in range(0, max(1, len(allx) - win), hop):
        try:
            mom.append(pyln.Meter(sr0, block_size=0.399).integrated_loudness(allx[i:i + win]))
        except ValueError:
            pass
    mom = [m for m in mom if np.isfinite(m)]
    return {"files": len(files), "gain_db": gain_db, "integrated_lufs": round(integ, 2),
            "momentary_max_lufs": round(max(mom), 2) if mom else None,
            "true_peak_max_dbtp": round(max(peaks), 2), "per_file": per}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    p = ROOT / "prototype/assets"
    voice = sorted((p / "audio/voice/lines").glob("*.ogg"))
    sfx = sorted((p / "audio/sfx").rglob("*.wav"))
    report = {
        "standard": "ITU-R BS.1770-4 integrated loudness (pyloudnorm 0.2.0), true peak by 4x polyphase oversampling",
        "scope": "source signal per bus with static gains; runtime compressor/limiter output not measured (no live mix in headless driver)",
        "buses": {
            "Voice": stats(voice, 0.0),
            "SFX": stats(sfx, 0.0),
            "Ambience": stats([p / "frontier_ambience.wav"], -15.0),
            "Music": stats([p / "ui/menu_theme.ogg"], -9.0),
        },
    }
    for bus in report["buses"].values():
        if len(bus["per_file"]) > 12:
            bus["per_file"] = sorted(bus["per_file"], key=lambda r: -r["true_peak_dbtp"])[:12]
    Path(a.out).write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
    for name, b in report["buses"].items():
        print(f"{name}: integrated {b['integrated_lufs']} LUFS, momentary max {b['momentary_max_lufs']} LUFS, true peak max {b['true_peak_max_dbtp']} dBTP ({b['files']} files)")


if __name__ == "__main__":
    main()
