#!/usr/bin/env python3
"""Check or apply only the source-pinned cloud shader correction."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


TARGET = "prototype/scripts/world/village/clouds.gdshader"
PACKAGE = Path(__file__).resolve().parent


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    repo = args.repo.resolve(strict=True)
    require(repo.is_dir(), "Target checkout must be a directory")
    manifest = json.loads((PACKAGE / "sky-seam-guard.json").read_text())
    require(manifest.get("format_version") == 1, "Unsupported sky manifest version")
    require(manifest.get("kind") == "imperathen-sky-seam", "Wrong manifest kind")
    require(manifest.get("target") == TARGET, "Unexpected shader target")
    require(manifest.get("patch_file") == "sky-seam.patch", "Unexpected patch filename")
    for key in ("expected_before_sha256", "expected_after_sha256", "patch_sha256"):
        require(isinstance(manifest.get(key), str) and
                re.fullmatch(r"[0-9a-f]{64}", manifest[key]) is not None,
                "Missing or invalid hash: " + key)

    target = repo / TARGET
    part = repo
    for name in Path(TARGET).parts:
        part = part / name
        require(not part.is_symlink(), "Symlink target component: " + str(part))
    require(target.is_file(), "Shader missing: " + str(target))
    patch = PACKAGE / "sky-seam.patch"
    require(patch.is_file() and not patch.is_symlink(), "Patch missing or symlinked")

    def verify_inputs() -> None:
        require(digest(patch) == manifest["patch_sha256"], "Patch hash mismatch")
        require(digest(target) == manifest["expected_before_sha256"],
                "Shader hash mismatch; review and merge the current shader first")

    verify_inputs()
    changes = subprocess.run(["git", "apply", "--numstat", str(patch)], cwd=repo,
                             check=True, capture_output=True, text=True).stdout.splitlines()
    require(len(changes) == 1 and changes[0].split("\t")[-1] == TARGET,
            "Patch must change exactly the declared shader")
    subprocess.run(["git", "apply", "--check", str(patch)], cwd=repo, check=True)
    verify_inputs()
    if not args.apply:
        print("PASS: exact shader and patch verified; git apply --check passed; no files changed")
        return 0
    subprocess.run(["git", "apply", str(patch)], cwd=repo, check=True)
    require(digest(target) == manifest["expected_after_sha256"],
            "Applied shader hash mismatch; inspect target before continuing")
    print("PASS: cloud shader patch applied; exact result hash verified")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("REJECTED: " + str(exc), file=sys.stderr)
        sys.exit(2)
