#!/usr/bin/env python3
"""Check an exact Chat-1 snapshot; apply only when --apply is explicitly passed."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


FILES = {
    "prototype/scripts/main.gd",
    "prototype/scripts/world/game_world.gd",
    "prototype/scripts/ui/game_ui.gd",
}
RUNTIME_MODULES = {
    "prototype/scripts/story/opening_story.gd",
    "prototype/scripts/cinematic/opening_director.gd",
    "prototype/scripts/cinematic/opening_checkpoint.gd",
    "prototype/scripts/ui/opening_overlay.gd",
    "prototype/scripts/world/village/opening_props.gd",
}
ADDITIVE_FILES = RUNTIME_MODULES | {path + ".uid" for path in RUNTIME_MODULES}


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


def additive_hashes(manifest: dict) -> dict[str, str]:
    required = manifest.get("required_additive_files")
    hashes = manifest.get("additive_sha256")
    if (
        not isinstance(required, list)
        or len(required) != len(ADDITIVE_FILES)
        or any(not isinstance(path, str) for path in required)
        or set(required) != ADDITIVE_FILES
        or not isinstance(hashes, dict)
        or set(hashes) != ADDITIVE_FILES
    ):
        fail("Guard must pin all five runtime modules and their five UID files; no files changed.")
    for path, value in hashes.items():
        if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
            fail("Missing or invalid additive SHA-256; no files changed: " + path)
    return hashes


def check_additives(repo: Path, hashes: dict[str, str], before_apply: bool = True) -> None:
    consequence = "; no files changed: " if before_apply else "; inspect concurrent changes after applying: "
    for relative, expected in hashes.items():
        target = repo / relative
        if not target.is_file() or target.is_symlink():
            fail("Missing or symbolic opening dependency" + consequence + relative)
        if digest(target) != expected:
            fail("Opening dependency differs from the reviewed runtime" + consequence + relative)


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
    if manifest.get("format") != "imperathen-guarded-patch" or manifest.get("version") != 2:
        fail("Unknown guard format; no files changed.")
    entries = manifest.get("files", [])
    if (
        not isinstance(entries, list)
        or len(entries) != 3
        or any(not isinstance(entry, dict) for entry in entries)
        or {entry.get("path") for entry in entries} != FILES
    ):
        fail("Guard must cover exactly the three reviewed existing files; no files changed.")
    dependencies = additive_hashes(manifest)
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
    check_sources(repo, entries)
    check_additives(repo, dependencies)
    git_check(repo, patch)
    # Detect concurrent edits during the Git dry run before any requested write.
    check_sources(repo, entries)
    check_additives(repo, dependencies)
    if not args.apply:
        print("CHECK PASS: exact Chat-1 snapshot, three target files, five runtime modules, five UID files and patch verified. No files changed.")
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
    check_additives(repo, dependencies, before_apply=False)
    print("APPLY PASS: three resolved files, five runtime modules and five UID files match the reviewed inputs. No commit or index update was made.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Guard stopped: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error
