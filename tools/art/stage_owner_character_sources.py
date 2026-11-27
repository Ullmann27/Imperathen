#!/usr/bin/env python3
"""Restore exact owner originals for the two explicit character candidates.

Usage: python tools/art/stage_owner_character_sources.py --local-models /private/extracted/models
Source files remain private; never commit the staging directory.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/20_meshy_assets/OWNER_CHARACTER_ASSIGNMENTS_20261127.json"
DEST = ROOT / "prototype/assets/meshy/source/character"
CHARACTERS = {"unit_legacy_blacksmith", "unit_legacy_tunic_villager"}

def digest(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-models", required=True, type=Path)
    args = parser.parse_args()
    if not args.local_models.is_dir():
        parser.error("local models directory does not exist")
    entries = [r for r in json.loads(MANIFEST.read_text())["assignments"] if r["stable_id"] in CHARACTERS]
    if {r["stable_id"] for r in entries} != CHARACTERS or len(entries) != len(CHARACTERS):
        raise ValueError("missing or duplicate source assignment")
    # Verify every original before copying anything.
    for row in entries:
        source = args.local_models / (row["task_id"] + ".glb")
        if source.stat().st_size != row["source_bytes"] or digest(source) != row["source_sha256"]:
            raise ValueError("source mismatch: " + row["stable_id"])
        target = DEST / (row["stable_id"] + ".glb")
        if target.exists() and digest(target) != row["source_sha256"]:
            raise ValueError("refusing to replace different original: " + row["stable_id"])
    DEST.mkdir(parents=True, exist_ok=True)
    for row in entries:
        target = DEST / (row["stable_id"] + ".glb")
        if not target.exists():
            with tempfile.NamedTemporaryFile(dir=DEST, suffix=".tmp", delete=False) as f:
                staged = Path(f.name)
            try:
                shutil.copyfile(args.local_models / (row["task_id"] + ".glb"), staged)
                if digest(staged) != row["source_sha256"]:
                    raise ValueError("source changed during copy")
                staged.replace(target)
            finally:
                staged.unlink(missing_ok=True)
        print("VERIFIED_OWNER_SOURCE", row["stable_id"])

if __name__ == "__main__":
    main()
