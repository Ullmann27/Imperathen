"""Generate a quiet, original wind-and-birds prototype ambience; no external audio.

The periodic synthesis makes an eight-second mono loop without a hard seam.
Run with Python 3 from any directory; the output argument is a WAV file path.
"""

import argparse
import math
import random
import struct
import wave
from pathlib import Path


def generate(path: Path) -> None:
    rate = 22050
    seconds = 8
    rng = random.Random(20261122)
    bands = [(rng.randint(70, 2700), rng.random() * math.tau, 0.024 / (1 + k * 0.2)) for k in range(50)]
    data = bytearray()
    for index in range(rate * seconds):
        t = index / rate
        wind = sum(math.sin(math.tau * frequency * t / seconds + phase) * amplitude
                   for frequency, phase, amplitude in bands)
        wind *= 0.65 + 0.22 * math.sin(math.tau * t / seconds)
        bird = 0.0
        for start in (1.25, 1.52, 5.2, 5.52):
            age = t - start
            if 0.0 <= age < 0.16:
                envelope = math.sin(math.pi * age / 0.16) ** 2
                bird += 0.075 * envelope * math.sin(math.tau * (2200 * age + 2000 * age * age))
        sample = max(-1.0, min(1.0, wind + bird))
        data.extend(struct.pack("<h", int(sample * 32767)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(data)
    print(f"IMPERATHEN_AUDIO_OK: {path.name}, {seconds}s, mono, {rate} Hz")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    generate(parser.parse_args().output)
