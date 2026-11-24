"""Compose and render the original IMPERATHEN menu theme; no samples or recordings.

Everything is synthesised with numpy from the score in this file: a water-organ
(hydraulis) drone, a plucked lyre (Karplus-Strong), a reed melody in the style of
an aulos, a cornu-like horn call and a frame drum. The instruments are evocations
built from additive synthesis, not reconstructions of ancient Roman music.
Note tails and the room reverb wrap around the loop length so the file loops
without a seam. Output: WAV (16 bit stereo); encode to Ogg Vorbis with ffmpeg.
Usage: python3 tools/ui/build_menu_music.py out.wav
"""

import argparse
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 66.0
BARS = 16
BEAT = 60.0 / BPM
LENGTH = int(round(BARS * 4 * BEAT * RATE))
SEED = 20261124

# Chord per bar as MIDI pitches (root first).
CHORDS = [
    (50, 53, 57), (50, 53, 57), (50, 53, 57), (50, 53, 57),
    (50, 53, 57), (50, 53, 57), (55, 58, 62), (57, 61, 64),
    (46, 50, 53), (46, 50, 53), (48, 52, 55), (57, 61, 64),
    (50, 53, 57), (50, 53, 57), (55, 58, 62), (50, 53, 57),
]
DRONES = [(38, 45)] * 8 + [(34, 41), (34, 41), (36, 43), (33, 40)] + [(38, 45)] * 4

# (bar, beat in bar, duration in beats, MIDI pitch)
MELODY = [
    (4, 0, 1.5, 69), (4, 1.5, 0.5, 67), (4, 2, 1, 65), (4, 3, 1, 64),
    (5, 0, 2, 62), (5, 2, 1, 65), (5, 3, 1, 69),
    (6, 0, 1.5, 70), (6, 1.5, 0.5, 69), (6, 2, 1, 67), (6, 3, 0.5, 65), (6, 3.5, 0.5, 67),
    (7, 0, 4, 69),
    (8, 0, 1.5, 74), (8, 1.5, 0.5, 72), (8, 2, 1, 70), (8, 3, 1, 69),
    (9, 0, 1, 70), (9, 1, 1, 72), (9, 2, 2, 74),
    (10, 0, 1.5, 76), (10, 1.5, 0.5, 74), (10, 2, 1, 72), (10, 3, 0.5, 70), (10, 3.5, 0.5, 69),
    (11, 0, 2, 67), (11, 2, 2, 69),
    (12, 0, 1.5, 69), (12, 1.5, 0.5, 67), (12, 2, 1, 65), (12, 3, 1, 63),
    (13, 0, 1, 62), (13, 1, 1, 65), (13, 2, 1, 67), (13, 3, 1, 69),
    (14, 0, 1, 70), (14, 1, 1, 69), (14, 2, 1, 67), (14, 3, 1, 64),
    (15, 0, 3.5, 62),
]
# Horn calls: rising fifths at phrase starts.
HORN = [(0, [(0, 1, 50), (1, 1, 57), (2, 2, 62)]),
        (8, [(0, 1, 46), (1, 1, 53), (2, 2, 58)]),
        (12, [(0, 1, 50), (1, 0.5, 57), (1.5, 0.5, 57), (2, 2, 62)])]


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def at(bar, beat):
    return int(round((bar * 4 + beat) * BEAT * RATE))


def place(track, start, signal, pan=0.0):
    """Add a mono signal to a stereo track, wrapping around the loop end."""
    left = np.cos((pan + 1) * np.pi / 4)
    right = np.sin((pan + 1) * np.pi / 4)
    index = (start + np.arange(len(signal))) % LENGTH
    np.add.at(track[0], index, signal * left)
    np.add.at(track[1], index, signal * right)


def envelope(n, attack, release, sustain=1.0):
    env = np.full(n, sustain)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    env[:a] = np.linspace(0, sustain, a)
    env[-r:] *= np.linspace(1, 0, r)
    return env


def additive(freq, seconds, amplitudes, vibrato=0.0, vibrato_rate=5.0, brightness=None, rng=None):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    drift = 1.0 + vibrato * np.sin(2 * np.pi * vibrato_rate * t + (rng.random() * 6.28 if rng else 0.0))
    phase = 2 * np.pi * np.cumsum(freq * drift) / RATE
    out = np.zeros(n)
    for k, amp in enumerate(amplitudes, start=1):
        if freq * k >= RATE * 0.45:
            break
        weight = amp if brightness is None else amp * brightness ** (k - 1)
        out += weight * np.sin(k * phase)
    return out


def hydraulis(freq, seconds, rng):
    # Organ pipe: strong fundamental, octave and fifth partials, slow chorus.
    voice = sum(additive(freq * detune, seconds, [1.0, 0.55, 0.32, 0.18, 0.1, 0.05], 0.0015, 0.3, rng=rng)
                for detune in (0.998, 1.0, 1.002))
    return voice * envelope(len(voice), 1.6, 1.6)


def lyre(freq, seconds, rng):
    """Karplus-Strong plucked string, vectorised one period at a time."""
    n = int(seconds * RATE)
    period = int(RATE / freq)
    out = np.zeros(n + period + 1)
    out[:period] = rng.uniform(-1, 1, period)
    out[:period] = np.convolve(out[:period], np.ones(5) / 5, mode="same")  # warmer gut string
    position = period
    while position < n + 1:
        end = min(position + period, n + 1)
        prev = out[position - period:end - period]
        prev_next = out[position - period + 1:end - period + 1]
        out[position:end] = 0.4985 * (prev + prev_next)
        position = end
    pluck = out[:n]
    return pluck * envelope(n, 0.002, 0.25)


def aulos(freq, seconds, rng):
    # Double reed: bright odd/even mix with a nasal formant, breath noise and vibrato.
    partials = [1.0, 0.7, 0.85, 0.5, 0.55, 0.3, 0.25, 0.15, 0.12, 0.08]
    tone = additive(freq, seconds, partials, 0.006, 5.2, rng=rng)
    tone += 0.6 * additive(freq * 1.004, seconds, partials, 0.006, 4.7, rng=rng)
    n = len(tone)
    breath = np.convolve(rng.normal(0, 1, n), np.ones(30) / 30, mode="same") * 0.06
    return (tone + breath) * envelope(n, 0.07, min(0.25, seconds * 0.4), 0.9)


def cornu(freq, seconds, rng):
    # Brass: higher partials bloom with the envelope (brightness follows loudness).
    n = int(seconds * RATE)
    env = envelope(n, 0.09, min(0.35, seconds * 0.45))
    t = np.arange(n) / RATE
    phase = 2 * np.pi * freq * t * (1 + 0.002 * np.sin(2 * np.pi * 5 * t))
    out = np.zeros(n)
    for k in range(1, 18):
        if freq * k >= RATE * 0.45:
            break
        out += (1.0 / k) * env ** (1 + 0.35 * k) * np.sin(k * phase)
    return out


def drum(low, rng):
    n = int((0.7 if low else 0.25) * RATE)
    t = np.arange(n) / RATE
    if low:
        pitch = 70 + 40 * np.exp(-t * 30)
        body = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 7)
        skin = np.convolve(rng.normal(0, 1, n), np.ones(20) / 20, mode="same") * np.exp(-t * 40) * 0.5
        return (body + skin) * np.minimum(1.0, t / 0.003)
    noise = rng.normal(0, 1, n)
    tap = noise - np.convolve(noise, np.ones(6) / 6, mode="same")
    tap = np.convolve(tap, np.ones(4) / 4, mode="same")  # leather, not a click
    return (tap * 0.8 + np.sin(2 * np.pi * 320 * t) * 0.3) * np.exp(-t * 32) * np.minimum(1.0, t / 0.002)


def reverb(stereo, rng, seconds=2.4, mix=0.28):
    """Circular FFT convolution with a decaying, darkened noise tail (seamless loop)."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    wet = np.zeros_like(stereo)
    for channel in range(2):
        tail = rng.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        tail = np.convolve(tail, np.ones(8) / 8, mode="same")
        impulse = np.zeros(LENGTH)
        impulse[:n] = tail
        impulse[0] = 0.0
        wet[channel] = np.fft.irfft(np.fft.rfft(stereo[channel]) * np.fft.rfft(impulse), LENGTH)
    wet *= np.max(np.abs(stereo)) / max(1e-9, np.max(np.abs(wet)))
    return stereo * (1 - mix) + wet * mix


def render():
    rng = np.random.default_rng(SEED)
    drone = np.zeros((2, LENGTH))
    strings = np.zeros((2, LENGTH))
    reed = np.zeros((2, LENGTH))
    horn = np.zeros((2, LENGTH))
    drums = np.zeros((2, LENGTH))
    for bar, pitches in enumerate(DRONES):
        for offset, pitch in enumerate(pitches):
            place(drone, at(bar, 0) - int(0.8 * RATE), hydraulis(hz(pitch), 4 * BEAT + 1.6, rng),
                  -0.25 if offset == 0 else 0.25)
    pattern = (0, 7, 12, 16, 12, 7, 3, 7)
    for bar, chord in enumerate(CHORDS):
        root, third, fifth = chord
        offsets = {0: root, 7: fifth, 12: root + 12, 16: third + 12, 3: third}
        for step, interval in enumerate(pattern):
            pitch = offsets[interval]
            velocity = 0.9 if step % 2 == 0 else 0.65
            place(strings, at(bar, step * 0.5), velocity * lyre(hz(pitch), 1.8, rng), 0.35)
    for bar, beat, duration, pitch in MELODY:
        place(reed, at(bar, beat), aulos(hz(pitch), duration * BEAT * 0.98, rng), -0.15)
    for bar, notes in HORN:
        for beat, duration, pitch in notes:
            for octave, gain in ((0, 1.0), (-12, 0.6)):
                place(horn, at(bar, beat), gain * cornu(hz(pitch + octave), duration * BEAT * 0.95, rng), 0.0)
    for bar in range(2, BARS):
        for beat, low, gain in ((0, True, 1.0), (1.5, False, 0.5), (2, True, 0.8), (3, False, 0.6), (3.5, False, 0.45)):
            place(drums, at(bar, beat), gain * drum(low, rng), -0.1 if low else 0.2)

    def norm(track):
        return track / max(1e-9, np.max(np.abs(track)))

    mix = (0.30 * norm(drone) + 0.42 * norm(strings) + 0.40 * norm(reed)
           + 0.34 * norm(horn) + 0.30 * norm(drums))
    mix = reverb(mix, rng)
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix *= 0.63 / np.max(np.abs(mix))  # peak -4 dBFS: background level, headroom for the UI clicks
    return mix


def write(path, mix):
    pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"IMPERATHEN_MUSIC_OK: {path.name}, {LENGTH / RATE:.2f}s, stereo, {RATE} Hz, {BPM:g} BPM")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    write(parser.parse_args().output, render())
