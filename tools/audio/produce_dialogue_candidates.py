#!/usr/bin/env python3
"""Generate missing authored German mission speech into isolated review artifacts.

No new recording replaces an existing runtime file. Existing fictional voices
are cloned only from checksum-verified accepted recordings. New speakers use
the registered synthetic cast. Publication still requires listening and import QA.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from voice_contract import track_errors

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "prototype/assets/audio/voice"
TOOLS = ROOT / "tools/audio"
ALIASES = {"chronik": "narrator", "wachmann": "severus"}
MAX_WER = 0.12


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text_key(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def speaker(label):
    label = label.strip().lower()
    return ALIASES.get(label, label)


def canonical_lines(band):
    base = ROOT / "prototype/assets/story/missions" / band
    index = load(base / "index.json")
    seen = set()
    for mission_id in index["order"]:
        mission = load(base / (mission_id + ".json"))
        if mission["mission"] != mission_id:
            raise ValueError("Mission index mismatch: " + mission_id)
        entries = []
        for item in mission.get("steps", []) + mission.get("bridges", []):
            if item.get("npc") and item.get("text"):
                entries.append((mission_id + "." + item["id"], item["npc"], item["text"]))
            if item.get("result"):
                entries.append((mission_id + "." + item["id"] + ".result", "chronik", item["result"]))
        for line_id, item in mission.get("slice", {}).get("lines", {}).items():
            entries.append((line_id, item["speaker_id"], item["text"]))
        for label, text in mission.get("slice", {}).get("contact_lines", {}).items():
            entries.append((mission_id + ".contact." + label, label, text))
        for line_id, label, text in entries:
            sid = speaker(label)
            k = text_key(text)
            if not text.strip() or not sid or (sid, k) in seen:
                continue
            seen.add((sid, k))
            yield {"line_id": line_id, "scope": mission_id, "speaker_id": sid,
                   "text": text, "text_key": k, "kind": "story", "source": str(base.relative_to(ROOT) / (mission_id + ".json"))}


def verify(row, field, checksum, directory):
    relative = Path(row[field])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Unsafe recording path")
    path = directory / relative
    if not path.is_file() or sha(path) != row[checksum]:
        raise ValueError("Missing or changed recording: " + str(path))
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", required=True)
    ap.add_argument("--band", default="band1", choices=["band1"])
    ap.add_argument("--authored", type=Path, help="Exact Godot runtime dialogue export")
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--attempts", type=int, default=8)
    ap.add_argument("--segmented", action="store_true")
    ap.add_argument("--seed-offset", type=int, default=0)
    ap.add_argument("--line-id", help="Only retry this exact authored identity")
    a = ap.parse_args()
    if not 1 <= a.attempts <= 32:
        ap.error("attempts must be 1–32")
    if not 0 <= a.seed_offset <= 1000000:
        ap.error("seed-offset out of bounds")
    cast = load(TOOLS / "voice_cast.json")
    if a.speaker not in cast["speakers"]:
        ap.error("Speaker not present in the established synthetic cast")
    manifest = load(AUDIO / "manifest.json")
    if manifest.get("language") != "de":
        raise ValueError("German manifest required")
    registry = load(AUDIO / "voice_registry.json")["speakers"]
    if a.speaker not in registry:
        raise ValueError("Registered fictional voice missing")
    work = a.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    out = a.out.resolve()
    if out.is_relative_to(AUDIO.resolve()):
        raise ValueError("Candidate output must not overwrite shipped audio")
    out.mkdir(parents=True, exist_ok=False)
    stage = work / "stage"
    stage.mkdir()
    (work / "refs").mkdir()
    existing = {}
    used_ids = set()
    for row in manifest["lines"]:
        used_ids.add(row["line_id"])
        if row.get("kind", "story") == "story":
            existing.setdefault((row["speaker_id"], row["text_key"]), []).append(row)
    wanted = []
    report = {"speaker": a.speaker, "band": a.band, "already_recorded": 0,
              "requested": [], "accepted": [], "rejected": [], "status": "candidate_only"}
    source_lines = load(a.authored)["lines"] if a.authored else canonical_lines(a.band)
    seen = set()
    for source in source_lines:
        line = {**source, "kind": "story"}
        if line["text_key"] != text_key(line["text"]):
            raise ValueError("Runtime export text hash mismatch: " + line["line_id"])
        identity = (line["speaker_id"], line["text_key"])
        if identity in seen:
            continue
        seen.add(identity)
        if line["speaker_id"] != a.speaker or (a.line_id and line["line_id"] != a.line_id):
            continue
        key = (line["speaker_id"], line["text_key"])
        if key in existing:
            rows = existing[key]
            if len(rows) != 1 or rows[0]["text"] != line["text"]:
                raise ValueError("Ambiguous existing recording " + line["line_id"])
            verify(rows[0], "file", "sha256", AUDIO)
            track = load(verify(rows[0], "visemes", "visemes_sha256", AUDIO))
            errors = track_errors(track, rows[0])
            if errors:
                report["rejected"].append({"line_id": rows[0]["line_id"], "reason": ",".join(errors)})
            else:
                report["already_recorded"] += 1
            continue
        lid = line["line_id"]
        if lid in used_ids:
            lid += "." + a.speaker + "." + line["text_key"]
        if lid in used_ids or not re.fullmatch(r"[A-Za-z0-9_.-]+", lid):
            raise ValueError("Unsafe or duplicate line ID " + lid)
        used_ids.add(lid)
        line["line_id"] = lid
        wanted.append(line)
    if a.line_id and not wanted and report["already_recorded"] != 1:
        raise ValueError("Requested exact line not found or not valid")
    report["requested"] = wanted
    save(out / "report.json", report)
    if not wanted:
        save(out / "manifest.fragment.json", {"language": "de", "lines": []})
        print("NO_MISSING_GERMAN_LINES", a.speaker)
        if report["rejected"]:
            raise SystemExit(1)
        return

    candidates = [row for row in manifest["lines"] if row["speaker_id"] == a.speaker
                  and row.get("model", "").startswith("Qwen/")
                  and 3 <= row.get("duration_s", 0) <= 20
                  and row.get("asr_wer", 1) <= MAX_WER and row.get("asr_text")]
    if candidates:
        row = min(candidates, key=lambda r: (r["asr_wer"], abs(r["duration_s"] - 9)))
        src = verify(row, "file", "sha256", AUDIO)
        wav = work / "refs" / (a.speaker + ".wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", str(src),
                        "-ac", "1", "-c:a", "pcm_s16le", str(wav)], check=True)
        refs = {a.speaker: {"seed": row["reference_seed"], "file": str(wav), "sha256": sha(wav),
                            "ref_text": row["asr_text"], "line_id": row["line_id"]}}
        save(work / "refs.json", refs)
        report["reference"] = {"type": "existing_verified_synthetic_recording", "line_id": row["line_id"]}
    else:
        profile = registry[a.speaker]
        spec = cast["speakers"][a.speaker]
        # For a voice with no shipped recording, recreate the registered
        # synthetic design seed, not a different stock voice.
        if profile.get("reference_seed") is not None:
            spec["seed"] = int(profile["reference_seed"])
            spec["attempts"] = 1
        report["reference"] = {"type": "registered_synthetic_design_candidate",
                               "seed": spec["seed"], "expected_sha256": profile.get("reference_sha256")}
    save(work / "cast.json", cast)
    save(work / "wanted.json", {"lines": wanted})
    save(out / "report.json", report)

    command = [sys.executable, "-I", str(TOOLS / "generate_voices.py"), "--strict",
               "--continue-on-rejected", "--attempts", str(a.attempts), "--seed-offset", str(a.seed_offset),
               "--lines", str(work / "wanted.json"), "--cast", str(work / "cast.json"),
               "--work", str(work), "--out", str(stage), "--only", a.speaker]
    if a.segmented:
        command.append("--segmented")
    subprocess.run(command,check=True)
    refs = load(work / "refs.json")
    if not candidates:
        ref = refs[a.speaker]
        lo, hi = cast["speakers"][a.speaker]["f0_target"]
        f0 = ref.get("metrics", {}).get("f0_median_hz")
        report["reference"].update(actual_sha256=ref["sha256"], f0_hz=f0, wer=ref.get("wer"))
        if not isinstance(f0, (int, float)) or not lo <= f0 <= hi or ref.get("wer", 1) > 0.10:
            report["rejected"] = [{"line_id": r["line_id"], "reason": "synthetic_reference_failed"} for r in wanted]
            save(out / "report.json", report)
            raise SystemExit("Unaccepted new voice reference; no audio candidate published")
    meta_path = work / "lines_meta.json"
    if meta_path.exists() and load(meta_path):
        subprocess.run([sys.executable, "-I", str(TOOLS / "align_visemes.py"), "--work", str(work), "--out", str(stage)], check=True)
    meta = load(meta_path) if meta_path.exists() else {}
    fields = ("line_id", "kind", "speaker_id", "text", "text_key", "spoken_text", "file", "sha256",
              "visemes", "visemes_sha256", "duration_s", "model", "voice_design_model", "reference_seed",
              "reference_audio_sha256", "reference_line_id", "seed", "post", "asr_wer", "asr_text", "lufs_integrated", "alignment",
              "generation_mode", "generation_phrases", "segment_seeds")
    accepted = []
    for request in wanted:
        lid = request["line_id"]
        row = meta.get(lid)
        try:
            if row is None:
                raise ValueError("No accepted generated line")
            if any(row[field] != request[field] for field in ("line_id", "speaker_id", "text", "text_key")):
                raise ValueError("Exact text/cast mismatch")
            if row.get("asr_wer", 1) > MAX_WER or not row.get("asr_text"):
                raise ValueError("Unaccepted German transcription")
            alignment = row.get("alignment", {})
            if not alignment.get("phonemes") or abs(alignment.get("onset_delta_ms", 1e9)) > 16.7:
                raise ValueError("Viseme alignment exceeds one 60 Hz frame")
            audio = verify(row, "file", "sha256", stage)
            track_path = verify(row, "visemes", "visemes_sha256", stage)
            track = load(track_path)
            errors = track_errors(track, row)
            if errors:
                raise ValueError("Invalid forced alignment: " + ",".join(errors))
            for field, src in (("file", audio), ("visemes", track_path)):
                dest = out / row[field]
                if dest.exists() or (AUDIO / row[field]).exists():
                    raise ValueError("Would overwrite existing audio")
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dest)
            entry = {name: row[name] for name in fields if name in row}
            entry["f0_median_hz"] = row.get("metrics", {}).get("f0_median_hz")
            accepted.append(entry)
            report["accepted"].append(lid)
        except (ValueError, KeyError, OSError) as exc:
            report["rejected"].append({"line_id": lid, "reason": str(exc)})
    save(out / "manifest.fragment.json", {"language": "de", "lines": accepted})
    save(out / "report.json", report)
    print(f"GERMAN_CANDIDATE {a.speaker}: accepted={len(accepted)} requested={len(wanted)} rejected={len(report['rejected'])}")
    if report["rejected"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
