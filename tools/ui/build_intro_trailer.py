"""Render the original trailer sound for the IMPERATHEN title sequence.

No samples or recordings: every sound is synthesised with numpy from this file.
Drum hits (taiko-style membranes with a sub boom), brass "braams" (detuned saw
clusters through a sweeping filter and saturation), a riser, the gladius swing
(filtered noise panned left to right), the impact with a steel ring, three hits
for VENI · VIDI · VICI and a closing cornu call over a D minor brass swell.
The marks match the constants in prototype/scripts/ui/imperial_intro.gd.
Output: WAV (16 bit stereo); encode to Ogg Vorbis with ffmpeg.
Usage: python3 tools/ui/build_intro_trailer.py out.wav
"""

import argparse
import wave
from pathlib import Path

import numpy as np

RATE = 44100
SEED = 20261124
LENGTH_S = 11.6
N = int(LENGTH_S * RATE)

# Timeline (seconds), shared with imperial_intro.gd.
HIT_LEGION = 0.45
HIT_STANDARDS = 1.45
HIT_EAGLE = 2.45
SWEEP_START = 3.55
SWEEP_END = 4.25
MOTTO_WORDS = (5.55, 6.15, 6.75)
EAGLE_SHEEN = 7.6


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def place(track, start_s, signal, pan=0.0):
    start = int(round(start_s * RATE))
    if start < 0:
        signal = signal[-start:]
        start = 0
    end = min(N, start + len(signal))
    if end <= start:
        return
    left = np.cos((pan + 1) * np.pi / 4)
    right = np.sin((pan + 1) * np.pi / 4)
    track[0, start:end] += signal[:end - start] * left
    track[1, start:end] += signal[:end - start] * right


def place_stereo(track, start_s, left, right):
    start = int(round(start_s * RATE))
    end = min(N, start + len(left))
    track[0, start:end] += left[:end - start]
    track[1, start:end] += right[:end - start]


def lowpass(signal, cutoff):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    spectrum /= np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(signal))


def highpass(signal, cutoff):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    spectrum *= 1 - 1 / np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(signal))


def sweep_filter(signal, centre, width_octaves, kind="band"):
    """Time-varying filter by short-time Fourier transform (overlap-add).
    centre(t) gives the band centre (or cutoff for kind="low") in Hz."""
    frame, hop = 2048, 512
    window = np.hanning(frame)
    padded = np.concatenate([np.zeros(frame), signal, np.zeros(frame)])
    out = np.zeros_like(padded)
    norm = np.zeros_like(padded)
    freqs = np.fft.rfftfreq(frame, 1 / RATE)
    safe = np.maximum(freqs, 1.0)
    for start in range(0, len(padded) - frame, hop):
        t = (start - frame + frame / 2) / RATE
        c = max(20.0, float(centre(t)))
        if kind == "low":
            mask = 1 / np.sqrt(1 + (safe / c) ** 6)
        else:
            mask = np.exp(-0.5 * (np.log2(safe / c) / width_octaves) ** 2)
        block = np.fft.irfft(np.fft.rfft(padded[start:start + frame] * window) * mask, frame)
        out[start:start + frame] += block * window
        norm[start:start + frame] += window ** 2
    out /= np.maximum(norm, 1e-6)
    return out[frame:frame + len(signal)]


def taiko(rng, size=1.0):
    n = int(1.6 * RATE)
    t = np.arange(n) / RATE
    f0 = 62.0 / size
    pitch = f0 * (1 + 0.9 * np.exp(-t * 28))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    body = np.sin(phase) * np.exp(-t * 4.5) + 0.45 * np.sin(1.59 * phase) * np.exp(-t * 9) + 0.2 * np.sin(2.14 * phase) * np.exp(-t * 14)
    skin = lowpass(rng.normal(0, 1, n), 1800) * np.exp(-t * 45) * 0.9
    slap = highpass(rng.normal(0, 1, n), 1500) * np.exp(-t * 120) * 0.25
    return (body + skin + slap) * np.minimum(1.0, t / 0.002)


def boom(rng, seconds=2.4, start_hz=110.0, end_hz=30.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    pitch = end_hz + (start_hz - end_hz) * np.exp(-t * 6)
    tone = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 1.8)
    rumble = lowpass(rng.normal(0, 1, n), 140) * np.exp(-t * 2.5) * 0.6
    return np.tanh((tone + rumble) * 1.8) * np.minimum(1.0, t / 0.004)


def braam(rng, pitches, seconds, attack=0.06, peak_hz=1900.0, release=1.2):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    voice = np.zeros(n)
    for midi in pitches:
        for detune in (-0.004, 0.0, 0.0037):
            f = hz(midi) * (1 + detune)
            phase = (f * t + rng.random()) % 1.0
            voice += 2 * phase - 1  # sawtooth
    voice /= len(pitches) * 3
    env = np.minimum(1.0, t / attack) * np.exp(-np.maximum(0.0, t - attack) / release)

    def cutoff(time):
        return 180 + peak_hz * np.exp(-max(0.0, time - attack) * 1.6) * min(1.0, time / max(0.01, attack))
    filtered = sweep_filter(voice, cutoff, 0, kind="low")
    return np.tanh(filtered * env * 3.2) * 0.9


def riser(rng, seconds):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = rng.normal(0, 1, n)
    band = sweep_filter(noise, lambda time: 400 * (12 ** (min(1.0, time / seconds))), 0.5)
    tone = np.sin(2 * np.pi * np.cumsum(110 * (4 ** (t / seconds))) / RATE) * 0.25
    env = (t / seconds) ** 2.2
    return (band * 0.8 + tone) * env


def whoosh(rng, seconds):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    u = t / seconds
    noise = rng.normal(0, 1, n)
    band = sweep_filter(noise, lambda time: 350 + 3200 * np.sin(np.pi * min(1.0, time / seconds)) ** 2, 0.45)
    env = np.sin(np.pi * np.clip(u, 0, 1)) ** 3
    sig = band * env
    left = sig * np.cos(u * np.pi / 2)
    right = sig * np.sin(u * np.pi / 2)
    return left, right


def steel_ring(rng, seconds=2.2):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp, decay in ((1.0, 1.0, 3.2), (2.76, 0.6, 4.5), (5.4, 0.35, 6.0), (8.93, 0.2, 9.0), (13.3, 0.1, 12.0)):
        out += amp * np.sin(2 * np.pi * 612 * ratio * t + rng.random() * 6) * np.exp(-t * decay)
    hit = highpass(rng.normal(0, 1, n), 2500) * np.exp(-t * 60)
    return (out * 0.35 + hit * 0.5) * np.minimum(1.0, t / 0.001)


def crash(rng, seconds=3.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    return highpass(rng.normal(0, 1, n), 3500) * np.exp(-t * 1.8) * np.minimum(1.0, t / 0.003)


def cornu(freq, seconds):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    attack = 0.07
    release = min(0.5, seconds * 0.45)
    env = np.minimum(1.0, t / attack) * np.clip((seconds - t) / release, 0, 1)
    phase = 2 * np.pi * freq * t * (1 + 0.003 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.4))
    out = np.zeros(n)
    for k in range(1, 20):
        if freq * k >= RATE * 0.45:
            break
        out += (1.0 / k) * env ** (1 + 0.3 * k) * np.sin(k * phase)
    return out


def drone(rng):
    t = np.arange(N) / RATE
    env = np.clip((t - HIT_LEGION) / 3.5, 0, 1) ** 1.5 * np.clip((LENGTH_S - t) / 1.5, 0, 1)
    tone = sum(np.sin(2 * np.pi * hz(m) * (1 + d) * t) for m, d in ((26, 0), (38, 0.0015), (45, -0.001)))
    rumble = lowpass(rng.normal(0, 1, N), 90) * 1.5
    return (tone / 3 + rumble) * env


def reverb(stereo, rng, seconds=2.8, mix=0.25):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    size = stereo.shape[1] + n
    wet = np.zeros((2, size))
    for channel in range(2):
        tail = rng.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        tail = lowpass(tail, 4500)
        tail[0] = 0.0
        wet[channel] = np.fft.irfft(np.fft.rfft(stereo[channel], size) * np.fft.rfft(tail, size), size)
    wet = wet[:, :stereo.shape[1]]
    wet *= np.max(np.abs(stereo)) / max(1e-9, np.max(np.abs(wet)))
    return stereo * (1 - mix) + wet * mix


def render():
    rng = np.random.default_rng(SEED)
    drums = np.zeros((2, N))
    brass = np.zeros((2, N))
    fx = np.zeros((2, N))
    low = np.zeros((2, N))
    place(low, 0.0, drone(rng) * 0.3)
    # Three opening hits, each bigger than the last.
    for index, mark in enumerate((HIT_LEGION, HIT_STANDARDS, HIT_EAGLE)):
        gain = 0.7 + 0.15 * index
        place(drums, mark, taiko(rng, 1.0) * gain, -0.1)
        place(drums, mark + 0.004, taiko(rng, 0.8) * gain * 0.6, 0.15)
        place(low, mark, boom(rng, 2.0) * gain)
        place(brass, mark, braam(rng, (26, 38, 45), 2.2 if index < 2 else 3.0, peak_hz=900 + 500 * index,
                                 release=0.45 if index < 2 else 0.8) * gain)
    # Riser into the sword, the swing itself, then the impact.
    place(fx, HIT_EAGLE + 0.4, riser(rng, SWEEP_START - HIT_EAGLE - 0.35) * 0.55)
    left, right = whoosh(rng, SWEEP_END - SWEEP_START + 0.15)
    place_stereo(fx, SWEEP_START - 0.05, left * 1.3, right * 1.3)
    place(drums, SWEEP_END, taiko(rng, 1.15) * 1.0, 0.0)
    place(drums, SWEEP_END + 0.003, taiko(rng, 0.7) * 0.7, 0.2)
    place(low, SWEEP_END, boom(rng, 3.2, 140, 26) * 1.2)
    place(fx, SWEEP_END, steel_ring(rng) * 0.6, 0.35)
    place(fx, SWEEP_END, crash(rng) * 0.22, -0.2)
    place(brass, SWEEP_END, braam(rng, (26, 38, 45, 50), 3.4, attack=0.03, peak_hz=2600, release=1.6) * 1.1)
    # VENI · VIDI · VICI: three drum strikes, rising.
    for index, mark in enumerate(MOTTO_WORDS):
        place(drums, mark, taiko(rng, 1.0 - 0.08 * index) * (0.75 + 0.1 * index), (-0.3, 0.3, 0.0)[index])
        place(low, mark, boom(rng, 1.4, 90, 34) * (0.5 + 0.1 * index))
    # Closing: D minor brass swell under a cornu call (D - A - D).
    place(brass, EAGLE_SHEEN - 0.2, braam(rng, (38, 41, 45, 50), 3.6, attack=0.9, peak_hz=1300, release=1.8) * 0.7)
    for start, length, midi in ((EAGLE_SHEEN, 0.32, 62), (EAGLE_SHEEN + 0.34, 0.32, 69), (EAGLE_SHEEN + 0.68, 2.2, 74)):
        for octave, gain in ((0, 0.55), (-12, 0.35)):
            place(brass, start, cornu(hz(midi + octave), length) * gain, 0.05)
    place(drums, EAGLE_SHEEN, taiko(rng, 1.1) * 0.8, 0.0)
    place(low, EAGLE_SHEEN, boom(rng, 3.0, 80, 28) * 0.7)

    def norm(track):
        return track / max(1e-9, np.max(np.abs(track)))

    # Suck-back: everything but the swing drops away just before the impact.
    t = np.arange(N) / RATE
    duck = 1 - 0.85 * np.clip((t - (SWEEP_END - 0.55)) / 0.35, 0, 1) * (t < SWEEP_END - 0.005)
    drums_n, brass_n, low_n = norm(drums), norm(brass), norm(low)
    drums, brass, low = drums_n * duck, brass_n * duck, low_n * duck
    mix = 0.62 * norm(drums) + 0.5 * norm(brass) + 0.42 * norm(fx) + 0.55 * norm(low)
    mix = reverb(mix, rng)
    mix = np.tanh(mix * 1.15) / np.tanh(1.15)
    fade = np.clip((LENGTH_S - np.arange(N) / RATE) / 0.8, 0, 1)
    mix *= fade
    mix *= 0.89 / np.max(np.abs(mix))  # peak -1 dBFS
    return mix


def write(path, mix):
    pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"IMPERATHEN_TRAILER_OK: {path.name}, {LENGTH_S:.2f}s, stereo, {RATE} Hz")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    write(parser.parse_args().output, render())
