#!/usr/bin/env python3
"""Stage exact pre-existing synthetic German recordings into a disposable build.

Never alter authored dialogue, overwrite an existing line, or treat a failed
candidate as accepted. Retain the source receipts and recheck decoded audio.
This is technical staging, not subjective voice or physical device approval.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import subprocess
from voice_contract import recording_errors, track_errors

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "prototype/assets/audio/voice"
REQUIRED_VISEMES = ["sil","PP","FF","TH","DD","kk","CH","SS","nn","RR","aa","E","ih","oh","ou"]


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def key(row):
    return (row["speaker_id"], row["text_key"])


def safe_path(root, relative, directory, extension):
    path = PurePosixPath(relative)
    if path.parts != (directory, path.name) or path.suffix != extension or not re.fullmatch(r"[A-Za-z0-9_.-]+", path.name):
        raise ValueError("Unsafe candidate file: " + relative)
    result = root.joinpath(*path.parts)
    if not result.is_file() or result.is_symlink() or not result.resolve().is_relative_to(root.resolve()):
        raise ValueError("Missing or unsafe candidate bytes: " + relative)
    return result


def validated_bytes(root, row):
    files = {}
    for field, checksum, directory, extension in (("file","sha256","lines",".ogg"),("visemes","visemes_sha256","visemes",".json")):
        path = safe_path(root, row[field], directory, extension)
        data = path.read_bytes()
        if digest(data) != row[checksum]:
            raise ValueError("Candidate checksum mismatch: " + row["line_id"])
        files[row[field]] = data
    track = json.loads(files[row["visemes"]])
    errors = track_errors(track, row)
    if errors or track["visemes"] != REQUIRED_VISEMES or track["audio_onset_s"] < 0 or track["first_phoneme_s"] < 0:
        raise ValueError("Rejected viseme receipt: " + row["line_id"] + ": " + str(errors))
    alignment = row.get("alignment", {})
    if not alignment.get("phonemes") or abs(alignment.get("onset_delta_ms", math.inf)) > 16.7:
        raise ValueError("Rejected alignment: " + row["line_id"])
    path = root / row["file"]
    result = subprocess.run(["ffprobe","-v","error","-select_streams","a:0","-show_entries",
                             "stream=codec_name,channels:format=duration","-of","json",str(path)],
                            capture_output=True,text=True,check=True)
    metadata = json.loads(result.stdout)
    duration = float(metadata["format"]["duration"])
    if not math.isfinite(duration) or abs(duration-row["duration_s"]) > .08 or len(metadata["streams"]) != 1 or metadata["streams"][0]["channels"] < 1:
        raise ValueError("Decoded duration/stream mismatch: " + row["line_id"])
    # Full decode, not merely a header or file-extension check.
    subprocess.run(["ffmpeg","-nostdin","-v","error","-xerror","-i",str(path),"-map","0:a:0","-f","null","-"],check=True,capture_output=True)
    return files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--authored",type=Path,required=True)
    parser.add_argument("--candidates",type=Path,required=True)
    parser.add_argument("--report",type=Path,required=True)
    parser.add_argument("--missing",type=Path,required=True)
    parser.add_argument("--audio",type=Path,default=AUDIO)
    args = parser.parse_args()
    manifest_path = args.audio / "manifest.json"
    manifest = load(manifest_path)
    if manifest.get("language") != "de":
        raise ValueError("German catalogue required")
    authored = {}
    for row in load(args.authored)["lines"]:
        if digest(row["text"].encode("utf-8"))[:16] != row["text_key"]:
            raise ValueError("Changed authored text")
        if key(row) in authored and authored[key(row)]["text"] != row["text"]:
            raise ValueError("Authored key collision")
        authored[key(row)] = row
    existing = {}
    used_ids = set()
    for row in manifest["lines"]:
        if row["line_id"] in used_ids:
            raise ValueError("Existing duplicate line ID")
        used_ids.add(row["line_id"])
        if row.get("kind","story") == "story":
            if key(row) in existing:
                raise ValueError("Existing duplicate story identity")
            existing[key(row)] = row
    staged = {}
    pending = {}
    skipped = []
    fragments = sorted(args.candidates.rglob("manifest.fragment.json"))
    if not fragments:
        raise ValueError("No previous voice artifacts were downloaded")
    for fragment in fragments:
        data = load(fragment)
        if data.get("language") != "de":
            raise ValueError("Candidate language mismatch")
        report = load(fragment.parent / "report.json")
        accepted_ids = set(report.get("accepted", []))
        for row in data["lines"]:
            identity = key(row)
            if row["line_id"] not in accepted_ids or row["speaker_id"] != report.get("speaker"):
                raise ValueError("Candidate absent from accepted receipt")
            if identity not in authored:
                skipped.append({"line_id":row["line_id"],"reason":"not_in_current_runtime"})
                continue
            if row["text"] != authored[identity]["text"] or digest(row["text"].encode("utf-8"))[:16] != row["text_key"]:
                raise ValueError("Exact current text mismatch")
            if identity in existing:
                skipped.append({"line_id":row["line_id"],"reason":"already_in_manifest"})
                continue
            if identity in staged or row["line_id"] in used_ids:
                raise ValueError("Ambiguous candidate identity")
            if row.get("kind") != "story" or recording_errors(row,manifest["speakers"]):
                raise ValueError("Candidate recording contract failed")
            files = validated_bytes(fragment.parent,row)
            for relative, content in files.items():
                target = args.audio / relative
                if target.exists() or relative in pending or not target.resolve().is_relative_to(args.audio.resolve()):
                    raise ValueError("Candidate would overwrite an asset")
                pending[relative] = content
            used_ids.add(row["line_id"])
            staged[identity] = row
    # All checks before writes; keep all old recordings intact.
    for relative, content in pending.items():
        target = args.audio / relative
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open("xb") as output:
            output.write(content)
    manifest["lines"].extend(staged.values())
    manifest["lines"].sort(key=lambda row:row["line_id"])
    tmp = manifest_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    tmp.replace(manifest_path)
    missing = [row for identity,row in authored.items() if identity not in existing and identity not in staged]
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps({"staged":len(staged),"remaining_unrecorded":len(missing),"rows":[{"line_id":r["line_id"],"speaker_id":r["speaker_id"],"sha256":r["sha256"],"visemes_sha256":r["visemes_sha256"]} for r in staged.values()],"skipped":skipped,"technical_only":True},ensure_ascii=False,indent=2)+"\n")
    args.missing.parent.mkdir(parents=True,exist_ok=True)
    args.missing.write_text(json.dumps({"lines":missing},ensure_ascii=False,indent=2)+"\n")
    print(f"GERMAN_DIALOGUE_STAGED {len(staged)}; remaining={len(missing)}")


if __name__ == "__main__":
    main()
