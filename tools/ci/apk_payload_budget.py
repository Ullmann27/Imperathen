#!/usr/bin/env python3
"""Inspect an actual QA APK without extracting or changing any signed bytes."""
import argparse
from collections import defaultdict, Counter
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile


def inspect(path):
    groups, extensions = Counter(), Counter()
    candidates = defaultdict(list)
    duplicate_bytes = 0
    duplicate_groups = 0
    with ZipFile(path) as apk:
        members = [member for member in apk.infolist() if not member.is_dir()]
        for member in members:
            groups[member.filename.split("/", 1)[0]] += member.compress_size
            if member.filename.startswith("assets/"):
                extensions[Path(member.filename).suffix] += member.compress_size
            if member.compress_size >= 8192:
                candidates[member.CRC, member.file_size].append(member)
        for matches in candidates.values():
            if len(matches) < 2:
                continue
            seen = set()
            duplicates = set()
            for member in matches:
                with apk.open(member) as source:
                    digest = hashlib.file_digest(source, "sha256").digest()
                if digest in seen:
                    duplicate_bytes += member.compress_size
                    duplicates.add(digest)
                seen.add(digest)
            duplicate_groups += len(duplicates)
        largest = sorted(members, key=lambda entry: -entry.compress_size)[:15]
    return {"apk_bytes": path.stat().st_size, "compressed_by_root": dict(groups.most_common()),
            "compressed_by_asset_extension": dict(extensions.most_common()),
            "largest_entries": {m.filename: m.compress_size for m in largest},
            "verified_duplicate_groups_min_8KiB": duplicate_groups,
            "duplicate_compressed_bytes_min_8KiB": duplicate_bytes}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    print(json.dumps(inspect(parser.parse_args().apk), indent=2))
