#!/usr/bin/env python3
"""Phoneme-level forced alignment and viseme tracks for the voice lines.

Method:
  * espeak-ng (German) converts the spoken text into IPA phonemes.
  * facebook/wav2vec2-xlsr-53-espeak-cv-ft (Apache-2.0) yields CTC phoneme
    posteriors every 20 ms; a Viterbi CTC forced alignment places exactly the
    espeak phoneme sequence on the audio (no free recognition).
  * Phonemes are mapped to a 15-class viseme set (sil, PP, FF, TH, DD, kk, CH,
    SS, nn, RR, aa, E, ih, oh, ou) with German specifics: rounded front vowels
    y/ø/œ take the rounded shapes, diphthongs are split, affricates pf/ts
    start with their closure.

Output per line: <out>/visemes/<line_id>.json, consumed by scripts/audio/face_driver.gd.
"""
import argparse, glob, hashlib, json, os, subprocess, sys
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

ALIGNER = ("facebook/wav2vec2-xlsr-53-espeak-cv-ft", "2c733782da5604684829819a5eb744c193fe9398")
VISEMES = ["sil", "PP", "FF", "TH", "DD", "kk", "CH", "SS", "nn", "RR", "aa", "E", "ih", "oh", "ou"]
# Single phoneme -> viseme. Multi-part phonemes are split below.
PHONE_VISEME = {
    "p": "PP", "b": "PP", "m": "PP",
    "f": "FF", "v": "FF", "ʋ": "FF",
    "θ": "TH", "ð": "TH",
    "t": "DD", "d": "DD",
    "k": "kk", "ɡ": "kk", "g": "kk", "ŋ": "kk", "x": "kk", "χ": "kk", "ç": "kk", "h": "kk", "q": "kk",
    "ʃ": "CH", "ʒ": "CH", "tʃ": "CH", "dʒ": "CH", "j": "CH",
    "s": "SS", "z": "SS",
    "n": "nn", "l": "nn", "n̩": "nn", "l̩": "nn",
    "r": "RR", "ɾ": "RR", "ʁ": "RR", "ɹ": "RR",
    "a": "aa", "aː": "aa", "ɑ": "aa", "ɑː": "aa", "ɐ": "aa", "ɜ": "aa",
    "e": "E", "eː": "E", "ɛ": "E", "ɛː": "E", "ə": "E",
    "i": "ih", "iː": "ih", "ɪ": "ih",
    "o": "oh", "oː": "oh", "ɔ": "oh", "ø": "oh", "øː": "oh", "œ": "oh",
    "u": "ou", "uː": "ou", "ʊ": "ou", "y": "ou", "yː": "ou", "ʏ": "ou", "w": "ou",
    "ʔ": "sil",
}
SPLIT = {"aɪ": ["a", "ɪ"], "aʊ": ["a", "ʊ"], "ɔø": ["ɔ", "ø"], "ɔɪ": ["ɔ", "ɪ"], "ts": ["t", "s"],
         "pf": ["p", "f"], "tʃ": ["t", "ʃ"], "dʒ": ["d", "ʒ"]}
STRESS = "ˈˌ"


def espeak_ipa(text):
    out = subprocess.run(["espeak-ng", "-v", "de", "-q", "--ipa"], input=text, text=True, capture_output=True, check=True).stdout
    return " ".join(out.split())


def tokenize(ipa, vocab):
    keys = sorted((k for k in vocab if not k.startswith("<")), key=len, reverse=True)
    tokens = []
    for word in ipa.split(" "):
        w = "".join(c for c in word if c not in STRESS)
        i = 0
        while i < len(w):
            for k in keys:
                if w.startswith(k, i):
                    tokens.append(k)
                    i += len(k)
                    break
            else:
                i += 1  # unmappable symbol (e.g. length mark alone) is skipped
    return tokens


def ctc_viterbi(logp, targets, blank):
    """Return per-target (first_frame, last_frame) of the best CTC path."""
    T = logp.shape[0]
    ext = [blank]
    for t in targets:
        ext += [t, blank]
    S = len(ext)
    neg = -1e30
    dp = np.full((T, S), neg)
    bp = np.zeros((T, S), dtype=np.int32)
    dp[0, 0] = logp[0, ext[0]]
    if S > 1:
        dp[0, 1] = logp[0, ext[1]]
    for t in range(1, T):
        prev = dp[t - 1]
        for s in range(S):
            best, arg = prev[s], s
            if s >= 1 and prev[s - 1] > best:
                best, arg = prev[s - 1], s - 1
            if s >= 2 and ext[s] != blank and ext[s] != ext[s - 2] and prev[s - 2] > best:
                best, arg = prev[s - 2], s - 2
            dp[t, s] = best + logp[t, ext[s]]
            bp[t, s] = arg
    s = S - 1 if dp[T - 1, S - 1] >= dp[T - 1, S - 2] else S - 2
    path = [0] * T
    for t in range(T - 1, -1, -1):
        path[t] = s
        s = bp[t, s]
    spans = {}
    for t, s in enumerate(path):
        if s % 2 == 1:
            k = (s - 1) // 2
            a, b = spans.get(k, (t, t))
            spans[k] = (min(a, t), max(b, t))
    return [spans.get(k) for k in range(len(targets))]


def refine_phrase_onsets(segments, wave, sr, threshold_db=-40.0, search=0.1):
    """CTC boundaries are quantised to 20 ms and spike late. For every phrase
    start (first phone or a phone after >= 120 ms of silence) move the start to
    the energy onset found within +-search seconds (same rule as audio_onset)."""
    win, hop = int(0.010 * sr), int(0.005 * sr)
    rms = np.array([np.sqrt(np.mean(wave[i:i + win] ** 2) + 1e-12) for i in range(0, len(wave) - win, hop)])
    db = 20 * np.log10(rms / rms.max())
    loud = db > threshold_db
    for i, seg in enumerate(segments):
        prev_end = segments[i - 1][1] if i > 0 else None
        if prev_end is not None and seg[0] - prev_end < 0.12:
            continue
        lo = max(0, int((seg[0] - search) / (hop / sr)))
        hi = min(len(loud) - 1, int((seg[0] + search) / (hop / sr)))
        for k in range(lo, hi + 1):
            if loud[k] and (k == 0 or not loud[k - 1]):
                new_start = k * hop / sr
                # Preserve the CTC phone end and the order of the next
                # phone. A later unrelated energy burst is not evidence that
                # this phone moved beyond its measured interval.
                candidate = round(new_start, 3)
                next_start = segments[i+1][0] if i+1 < len(segments) else float("inf")
                if ((prev_end is None or candidate >= prev_end)
                        and candidate < seg[1] and candidate <= next_start):
                    seg[0] = candidate
                    break
    return segments


def audio_onset(wave, sr, threshold_db=-40.0):
    """First 5 ms hop whose 10 ms RMS exceeds threshold_db relative to the line peak RMS."""
    win, hop = int(0.010 * sr), int(0.005 * sr)
    rms = np.array([np.sqrt(np.mean(wave[i:i + win] ** 2) + 1e-12) for i in range(0, len(wave) - win, hop)])
    ref = rms.max()
    idx = np.where(20 * np.log10(rms / ref) > threshold_db)[0]
    return float(idx[0] * hop / sr) if idx.size else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    from transformers import Wav2Vec2ForCTC, Wav2Vec2FeatureExtractor
    from huggingface_hub import hf_hub_download
    import librosa
    # The phoneme tokenizer class would pull in the GPL 'phonemizer' package
    # only to phonemize text; we phonemize with espeak-ng ourselves and need
    # just the vocabulary.
    proc = Wav2Vec2FeatureExtractor.from_pretrained(ALIGNER[0], revision=ALIGNER[1])
    model = Wav2Vec2ForCTC.from_pretrained(ALIGNER[0], revision=ALIGNER[1]).eval()
    vocab = json.loads(Path(hf_hub_download(ALIGNER[0], "vocab.json", revision=ALIGNER[1])).read_text(encoding="utf-8"))
    blank = vocab["<pad>"]
    work, out = Path(a.work), Path(a.out)
    (out / "visemes").mkdir(parents=True, exist_ok=True)
    meta = json.loads((work / "lines_meta.json").read_text(encoding="utf-8"))
    for line_id, line in meta.items():
        wav_path = work / "master" / f"{line_id}.wav"
        wave, sr = sf.read(wav_path)
        w16 = librosa.resample(wave.astype(np.float32), orig_sr=sr, target_sr=16000)
        ipa = espeak_ipa(line["spoken_text"])
        tokens = tokenize(ipa, vocab)
        ids = [vocab[t] for t in tokens]
        with torch.no_grad():
            inp = proc(w16, sampling_rate=16000, return_tensors="pt").input_values
            logits = model(inp).logits[0]
        logp = torch.log_softmax(logits, dim=-1).numpy()
        frame = len(w16) / 16000 / logp.shape[0]
        spans = ctc_viterbi(logp, ids, blank)
        phones = []
        for tok, span in zip(tokens, spans):
            if span is None:
                continue
            start, end = span[0] * frame, (span[1] + 1) * frame
            parts = SPLIT.get(tok, [tok])
            step = (end - start) / len(parts)
            for j, p in enumerate(parts):
                phones.append([round(start + j * step, 3), round(start + (j + 1) * step, 3), p])
        # CTC spikes are short; extend each phone to the next phone's start when the
        # gap is below 120 ms (inside a word/phrase), otherwise insert silence.
        segments = []
        for i, (s, e, p) in enumerate(phones):
            nxt = phones[i + 1][0] if i + 1 < len(phones) else None
            if nxt is not None and nxt - e < 0.12:
                e = nxt
            else:
                e = min(e + 0.06, nxt) if nxt is not None else e + 0.06
            vis = PHONE_VISEME.get(p.rstrip("ː"), PHONE_VISEME.get(p, "E"))
            segments.append([round(s, 3), round(e, 3), VISEMES.index(vis), p])
        segments = refine_phrase_onsets(segments, wave, sr)
        onset = audio_onset(wave, sr)
        # The first audible energy of a trimmed line is the start of its first
        # phoneme; CTC often fires late on initial plosives (up to ~0.5 s here).
        if segments and onset < segments[0][1]:
            segments[0][0] = round(onset, 3)
        track = {
            "schema_version": 1, "line_id": line_id, "text_key": line["text_key"], "speaker_id": line["speaker_id"],
            "method": "espeak-ng(de) + CTC Viterbi forced alignment " + ALIGNER[0] + "@" + ALIGNER[1][:12],
            "duration_s": line["duration_s"], "audio_onset_s": round(onset, 3),
            "visemes": VISEMES, "ipa": ipa,
            "segments": [[s, e, v] for s, e, v, _ in segments],
            "phonemes": [[s, e, p] for s, e, _, p in segments],
        }
        first = segments[0][0] if segments else 0.0
        track["first_phoneme_s"] = first
        path = out / "visemes" / f"{line_id}.json"
        path.write_text(json.dumps(track, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        line["visemes"] = f"visemes/{line_id}.json"
        line["visemes_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        line["alignment"] = {"phonemes": len(segments), "tokens": len(tokens), "audio_onset_s": round(onset, 3), "first_phoneme_s": first,
                             "onset_delta_ms": round((first - onset) * 1000, 1)}
        print(f"align {line_id}: tokens={len(tokens)} aligned={len(segments)} onset={onset:.3f} first={first:.3f}", flush=True)
    (work / "lines_meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print("ALIGN_DONE", len(meta))


if __name__ == "__main__":
    main()
