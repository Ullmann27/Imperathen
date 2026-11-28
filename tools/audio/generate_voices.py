#!/usr/bin/env python3
"""Generate the German dialogue lines with locally run, Apache-2.0 Qwen3-TTS.

Pipeline per speaker (official "Voice Design then Clone" workflow):
  1. VoiceDesign model renders the shared reference sentence from a text
     description of a fictional person (no recording of a real person).
     Seeds are tried in order until the median F0 falls into the speaker's
     target range from voice_cast.json.
  2. The Base model turns that synthetic clip into a reusable clone prompt so
     every line of the speaker keeps one timbre.
  3. Each line is generated with a deterministic seed, transcribed with Whisper
     and regenerated (next seed) when the word error rate is too high.
  4. Lines are loudness-normalised (BS.1770 integrated) and encoded to Ogg Vorbis.

Usage:
  python tools/audio/generate_voices.py --lines lines.json --work DIR --out prototype/assets/audio/voice
"""
import argparse, hashlib, json, os, re, subprocess, sys, time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import pyloudnorm as pyln

sys.path.insert(0, str(Path(__file__).resolve().parent))
from voice_metrics import measure  # noqa: E402

DESIGN = ("Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign", "5ecdb67327fd37bb2e042aab12ff7391903235d3")
BASE = ("Qwen/Qwen3-TTS-12Hz-1.7B-Base", "fd4b254389122332181a7c3db7f27e918eec64e3")
ASR = ("openai/whisper-small", "973afd24965f72e36ca33b3055d56a652f456b4d")
TARGET_LUFS = -20.0
PEAK_DBFS = -1.5
MAX_WER = 0.12
ATTEMPTS = 4


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def speakable(text):
    """Remove typographic quotes; the subtitle keeps them, the voice must not read them."""
    t = text.replace("»", "").replace("«", "").replace("„", "").replace("“", "").replace("”", "")
    t = t.replace("–", ", ").replace("—", ", ").replace("·", ",")
    t = re.sub(r"\s+", " ", t).strip()
    return t


def norm_words(text):
    t = text.lower().replace("’", "'").replace("ß", "ss")
    t = re.sub(r"[^a-zäöü0-9' ]+", " ", t)
    return t.split()


def wer(ref, hyp):
    r, h = norm_words(ref), norm_words(hyp)
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1]))
            prev, d[j] = d[j], cur
    return d[len(h)] / max(1, len(r))


def token_budget(text):
    """12.5 Hz codec: allow ~2x a slow 9 chars/s delivery plus 2 s, to stop run-on generations."""
    return int(12.5 * (len(text) / 9.0 * 2.0 + 2.0))


def too_long(seconds, text):
    return seconds > len(text) / 9.0 * 1.6 + 1.5


def age_transform(wave, sr, post):
    """Praat PSOLA 'Change gender': raise the median F0 to the target and scale
    formants (shorter vocal tract). Used only for speakers whose designed voice
    measures outside the child range; parameters are recorded per line."""
    import parselmouth
    from parselmouth.praat import call
    snd = parselmouth.Sound(np.asarray(wave, dtype=np.float64), sampling_frequency=sr)
    out = call(snd, "Change gender", 75, 600, float(post["formant_ratio"]), float(post["pitch_median_hz"]),
               float(post.get("pitch_range_factor", 1.0)), float(post.get("duration_factor", 1.0)))
    return out.values[0]


def trim_and_master(wave, sr):
    wave = np.asarray(wave, dtype=np.float64)
    # Trim leading/trailing silence below -50 dBFS, keep 60 ms pre-roll and 150 ms tail.
    env = np.abs(wave)
    thr = 10 ** (-50 / 20)
    idx = np.where(env > thr)[0]
    if idx.size:
        a = max(0, idx[0] - int(0.06 * sr))
        b = min(wave.size, idx[-1] + int(0.15 * sr))
        wave = wave[a:b]
    meter = pyln.Meter(sr)
    loud = meter.integrated_loudness(wave)
    wave = pyln.normalize.loudness(wave, loud, TARGET_LUFS)
    peak = np.max(np.abs(wave))
    limit = 10 ** (PEAK_DBFS / 20)
    if peak > limit:
        wave = wave * (limit / peak)
    fade = int(0.01 * sr)
    wave[:fade] *= np.linspace(0, 1, fade)
    wave[-fade:] *= np.linspace(1, 0, fade)
    return wave.astype(np.float32), meter.integrated_loudness(wave)


def split_exact_phrases(text):
    """Split only at existing punctuation. Every authored word is retained."""
    parts = [part.strip() for part in re.split(r"(?<=[.!?;])\s+", text) if part.strip()]
    if not parts or norm_words(" ".join(parts)) != norm_words(text):
        raise ValueError("Invalid exact speech segmentation")
    return parts


def join_generated_phrases(waves, sr):
    """Preserve same-speaker audio, trim only quiet outer padding, smooth joins."""
    if sr <= 0 or not waves:
        raise ValueError("No generated speech")
    result = []
    for index, raw in enumerate(waves):
        wave = np.asarray(raw, dtype=np.float64).reshape(-1)
        if not wave.size or not np.isfinite(wave).all():
            raise ValueError("Invalid generated speech segment")
        audible = np.flatnonzero(np.abs(wave) > 10 ** (-50 / 20))
        if not audible.size:
            raise ValueError("Silent generated speech segment")
        # Same -50 dBFS criterion as the existing mastering pass. Leave
        # 60 ms before/after audible samples; fade only the retained padding.
        lo = max(0, int(audible[0]) - round(.06 * sr))
        hi = min(wave.size, int(audible[-1]) + 1 + round(.06 * sr))
        wave = wave[lo:hi].copy()
        fade_in = min(round(.008 * sr), int(audible[0])-lo)
        fade_out = min(round(.008 * sr), hi-int(audible[-1])-1)
        if fade_in > 0:
            wave[:fade_in] *= np.linspace(0,1,fade_in)
        if fade_out > 0:
            wave[-fade_out:] *= np.linspace(1,0,fade_out)
        if index:
            result.append(np.zeros(round(.10*sr),dtype=np.float64))
        result.append(wave)
    return np.concatenate(result)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lines", required=True)
    ap.add_argument("--cast", default=str(Path(__file__).with_name("voice_cast.json")))
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", nargs="*", help="speaker ids")
    ap.add_argument("--strict", action="store_true", help="Reject output above the existing MAX_WER threshold")
    ap.add_argument("--attempts", type=int, default=ATTEMPTS,
                    help="Maximum distinct deterministic seeds per line (1-32)")
    ap.add_argument("--continue-on-rejected", action="store_true", help="With --strict, skip failed lines and preserve the other accepted candidate recordings")
    ap.add_argument("--segmented", action="store_true", help="Retry exact multi-sentence text in shorter phrases using the same voice reference; full joined waveform still must pass original ASR")
    ap.add_argument("--seed-offset", type=int, default=0, help="Offset deterministic attempt range without repeating previously rejected seeds")
    a = ap.parse_args()
    if not 1 <= a.attempts <= 32:
        ap.error("--attempts must be between 1 and 32")
    if not 0 <= a.seed_offset <= 1000000:
        ap.error("--seed-offset must be between 0 and 1000000")
    from qwen_tts import Qwen3TTSModel
    from transformers import pipeline

    work, out = Path(a.work), Path(a.out)
    (work / "refs").mkdir(parents=True, exist_ok=True)
    (work / "raw").mkdir(parents=True, exist_ok=True)
    (out / "lines").mkdir(parents=True, exist_ok=True)
    cast = json.loads(Path(a.cast).read_text(encoding="utf-8"))
    lines = json.loads(Path(a.lines).read_text(encoding="utf-8"))["lines"]
    speakers = cast["speakers"]
    wanted = set(a.only) if a.only else None
    ref_text = cast["reference_text"]
    torch.set_num_threads(os.cpu_count() or 4)

    asr = pipeline("automatic-speech-recognition", model=ASR[0], revision=ASR[1], device="cpu")

    def transcribe(path):
        return asr(str(path), generate_kwargs={"language": "german", "task": "transcribe"})["text"]

    # 1) Design references.
    refs_meta_path = work / "refs.json"
    refs_meta = json.loads(refs_meta_path.read_text()) if refs_meta_path.exists() else {}
    need_design = [s for s in speakers if (wanted is None or s in wanted) and s not in refs_meta and "derive_from" not in speakers[s]]
    if need_design:
        design = Qwen3TTSModel.from_pretrained(DESIGN[0], revision=DESIGN[1], dtype=torch.float32, device_map="cpu")
        for sid in need_design:
            spec = speakers[sid]
            lo, hi = spec["f0_target"]
            best = None
            for attempt in range(int(spec.get("attempts", 4))):
                seed = spec["seed"] + attempt * 1000
                torch.manual_seed(seed)
                w, sr = design.generate_voice_design(text=ref_text, language="German", instruct=spec["instruct"], max_new_tokens=token_budget(ref_text))
                p = work / "refs" / f"{sid}_{seed}.wav"
                sf.write(p, w[0], sr)
                m = measure(str(p))
                err = wer(ref_text, transcribe(p))
                f0 = m.get("f0_median_hz", 0)
                miss = 0 if lo <= f0 <= hi else min(abs(f0 - lo), abs(f0 - hi))
                score = miss + 400 * err + (500 if too_long(m.get("duration_s", 0), ref_text) else 0)
                print(f"design {sid} seed={seed} f0={f0} wer={err:.2f} score={score:.1f}", flush=True)
                if best is None or score < best[0]:
                    best = (score, seed, str(p), m, err)
                if miss == 0 and err <= 0.1 and not too_long(m.get("duration_s", 0), ref_text):
                    break
            refs_meta[sid] = {"seed": best[1], "file": best[2], "metrics": best[3], "wer": round(best[4], 3), "sha256": sha256(best[2])}
            refs_meta_path.write_text(json.dumps(refs_meta, indent=2, ensure_ascii=False))
        del design
        import gc
        gc.collect()

    # 1b) Derived references: one base timbre shifted to another age stage
    # (pitch/formant/tempo by PSOLA). The clone model re-synthesises every
    # line from this reference, so lines carry no PSOLA processing themselves.
    for sid, spec in speakers.items():
        if "derive_from" not in spec or sid in refs_meta or (wanted is not None and sid not in wanted):
            continue
        base = refs_meta[spec["derive_from"]]
        wave, sr = sf.read(base["file"])
        shifted = age_transform(wave, sr, spec["transform"])
        p = work / "refs" / f"{sid}_from_{spec['derive_from']}.wav"
        sf.write(p, shifted, sr)
        m = measure(str(p))
        err = wer(ref_text, transcribe(p))
        print(f"derive {sid} from {spec['derive_from']} f0={m.get('f0_median_hz')} wer={err:.2f}", flush=True)
        refs_meta[sid] = {"seed": base["seed"], "file": str(p), "metrics": m, "wer": round(err, 3), "sha256": sha256(p),
                          "derived_from": spec["derive_from"], "transform": spec["transform"]}
        refs_meta_path.write_text(json.dumps(refs_meta, indent=2, ensure_ascii=False))

    # 2) + 3) Clone and render lines.
    base = Qwen3TTSModel.from_pretrained(BASE[0], revision=BASE[1], dtype=torch.float32, device_map="cpu")
    prompts = {}
    manifest_path = work / "lines_meta.json"
    meta = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for i, line in enumerate(lines):
        sid = line["speaker_id"]
        if wanted is not None and sid not in wanted:
            continue
        if line["line_id"] in meta and meta[line["line_id"]]["text_key"] == line["text_key"]:
            continue
        if sid not in prompts:
            prompts[sid] = base.create_voice_clone_prompt(ref_audio=refs_meta[sid]["file"], ref_text=refs_meta[sid].get("ref_text", ref_text))
        text = speakable(line["text"])
        # Prosody-only alternatives must preserve every authored word. ASR
        # acceptance is always measured against the original canonical text.
        variants = [text, *line.get("synthesis_variants", [])]
        if any(norm_words(variant) != norm_words(text) for variant in variants):
            raise SystemExit(f"Non-canonical synthesis variant: {line['line_id']}")
        best = None
        base_seed = int(hashlib.sha256(line["line_id"].encode()).hexdigest()[:6], 16)
        for attempt in range(a.attempts):
            seed = base_seed + a.seed_offset + attempt
            # Preserve the first 16 deterministic attempts for the existing
            # repair; later attempts vary phrasing boundaries, not words.
            absolute_attempt = a.seed_offset + attempt
            variant = variants[0] if absolute_attempt < 16 else variants[(absolute_attempt - 16) % len(variants)]
            t0 = time.time()
            if a.segmented:
                parts = split_exact_phrases(variant)
                waves = []
                sr = None
                for index, part in enumerate(parts):
                    torch.manual_seed(seed + index * 1000003)
                    w, rate = base.generate_voice_clone(text=part, language="German", voice_clone_prompt=prompts[sid], max_new_tokens=token_budget(part))
                    if sr is not None and sr != rate:
                        raise ValueError("Inconsistent sample rates across speech segments")
                    sr = rate
                    waves.append(w[0])
                raw = join_generated_phrases(waves, sr)
            else:
                torch.manual_seed(seed)
                w, sr = base.generate_voice_clone(text=variant, language="German", voice_clone_prompt=prompts[sid], max_new_tokens=token_budget(text))
                raw = w[0]
            p = work / "raw" / f"{line['line_id']}_{seed}.wav"
            sf.write(p, raw, sr)
            hyp = transcribe(p)
            # Never score separate words independently in place of the real
            # delivered waveform. Same full-text WER and duration threshold.
            err = wer(text, hyp) + (1.0 if too_long(len(raw) / sr, text) else 0.0)
            print(f"line {line['line_id']} [{sid}] seed={seed} wer={err:.2f} gen={time.time()-t0:.0f}s :: {hyp}", flush=True)
            if best is None or err < best[0]:
                best = (err, seed, p, sr, hyp, variant)
            if err <= MAX_WER:
                break
        err, seed, p, sr, hyp, variant = best
        if a.strict and err > MAX_WER:
            if a.continue_on_rejected:
                print(f"REJECTED_VOICE {line['line_id']}: WER {err:.3f}", flush=True)
                continue
            raise SystemExit(f"Unaccepted transcription for {line['line_id']}: WER {err:.3f}")
        wave, _ = sf.read(p)
        post = speakers[sid].get("post")
        if post:
            wave = age_transform(wave, sr, post)
        mastered, lufs = trim_and_master(wave, sr)
        master_wav = work / "master" / f"{line['line_id']}.wav"
        master_wav.parent.mkdir(exist_ok=True)
        sf.write(master_wav, mastered, sr, subtype="PCM_16")
        ogg = out / "lines" / f"{line['line_id']}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(master_wav), "-c:a", "libvorbis", "-q:a", "6", "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(ogg)], check=True)
        meta[line["line_id"]] = {
            "line_id": line["line_id"], "speaker_id": sid, "text": line["text"], "text_key": line["text_key"],
            "kind": line.get("kind", "story"), "spoken_text": variant, "model": BASE[0] + "@" + BASE[1][:12], "voice_design_model": DESIGN[0] + "@" + DESIGN[1][:12],
            "reference_seed": refs_meta[sid]["seed"], "reference_audio_sha256": refs_meta[sid]["sha256"],
            "reference_line_id": refs_meta[sid].get("line_id"), "seed": seed, "asr_wer": round(err, 3), "asr_text": hyp.strip(),
            "generation_mode": "exact_joined_phrases" if a.segmented else "continuous",
            "generation_phrases": split_exact_phrases(variant) if a.segmented else [variant],
            "segment_seeds": [seed+i*1000003 for i in range(len(split_exact_phrases(variant)))] if a.segmented else [seed],
            "lufs_integrated": round(lufs, 2), "duration_s": round(len(mastered) / sr, 3), "sample_rate": sr,
            "master_wav_sha256": sha256(master_wav), "file": f"lines/{ogg.name}", "sha256": sha256(ogg),
            "metrics": measure(str(master_wav)), "post": post or None,
        }
        manifest_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print("GENERATE_VOICES_DONE", len(meta))


if __name__ == "__main__":
    main()
