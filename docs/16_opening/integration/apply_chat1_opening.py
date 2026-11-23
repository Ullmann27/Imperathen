#!/usr/bin/env python3
"""Check an exact Chat-1 snapshot; apply only when --apply is explicitly passed."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


FILES = {
    "prototype/scripts/main.gd",
    "prototype/scripts/world/game_world.gd",
    "prototype/scripts/ui/game_ui.gd",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(message)


def check_sources(repo: Path, entries: list[dict]) -> None:
    for entry in entries:
        target = repo / entry["path"]
        if not target.is_file() or target.is_symlink():
            fail("Missing or symbolic target; no files changed: " + entry["path"])
        if digest(target) != entry["expected_peer_sha256"]:
            fail("Chat-1 file changed since the reviewed snapshot; no files changed: " + entry["path"])


def git_check(repo: Path, patch: Path) -> None:
    result = subprocess.run(
        ["git", "apply", "--check", str(patch)], cwd=repo,
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        fail("Patch check failed; no files changed:\n" + result.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path, help="Root of the intended Chat-1 checkout")
    parser.add_argument("--apply", action="store_true", help="Apply after all snapshot and patch checks pass")
    args = parser.parse_args()
    repo = args.repo.resolve(strict=True)
    folder = Path(__file__).resolve().parent
    manifest = json.loads((folder / "chat1-opening-guard.json").read_text())
    if manifest.get("format") != "imperathen-guarded-patch" or manifest.get("version") != 1:
        fail("Unknown guard format; no files changed.")
    entries = manifest.get("files", [])
    if len(entries) != 3 or {entry.get("path") for entry in entries} != FILES:
        fail("Guard must cover exactly the three reviewed existing files; no files changed.")
    if manifest.get("patch_file") != "chat1-opening.patch":
        fail("Unexpected patch filename; no files changed.")
    patch = folder / manifest["patch_file"]
    if digest(patch) != manifest.get("patch_sha256"):
        fail("Patch content differs from its manifest; no files changed.")
    patch_paths = {
        line.removeprefix("+++ b/")
        for line in patch.read_text().splitlines()
        if line.startswith("+++ b/")
    }
    if patch_paths != FILES:
        fail("Patch targets differ from the three reviewed files; no files changed.")
    for relative in manifest.get("required_additive_files", []):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts or not (repo / path).is_file():
            fail("Bring the additive opening modules into the checkout first: " + relative)
    check_sources(repo, entries)
    git_check(repo, patch)
    # Detect concurrent edits during the Git dry run before any requested write.
    check_sources(repo, entries)
    if not args.apply:
        print("CHECK PASS: exact Chat-1 snapshot, three target files, additive modules and patch verified. No files changed.")
        return
    result = subprocess.run(
        ["git", "apply", str(patch)], cwd=repo,
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        fail("Git could not apply the patch:\n" + result.stderr)
    for entry in entries:
        if digest(repo / entry["path"]) != entry["resolved_sha256"]:
            fail("The resulting file differs from the reviewed resolution; inspect concurrent changes: " + entry["path"])
    print("APPLY PASS: all three files match the reviewed resolution. No commit or index update was made.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Guard stopped: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error
