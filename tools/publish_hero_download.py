#!/usr/bin/env python3
"""Publish only the already built, verified hero APK; never build or run a soak test."""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import struct
import subprocess
import tempfile
import zipfile


REPO = "Ullmann27/Imperathen"
RUN_ID = 45058521723
RUN_NUMBER = 19
SOURCE = "d54478ec21db4c849dfa29bf7e39eab04b88c9d5"
BRANCH = "feature/hero-realism-20261122"
TAG = "hero-2026-11-22-d54478ec"
PREFIX = "IMPERATHEN-d54478ec"
PACKAGE = "at.heinz.imperathen"
APK_NAME = PREFIX + "-arm64.apk"
HERO_RESOURCES = {f"assets/characters/hero_quality_{level}.glb" for level in range(4)} | {
    "scripts/visuals/facial_motion.gd"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def gh(*arguments: str, missing_ok: bool = False) -> str | None:
    result = subprocess.run(["gh", *arguments], capture_output=True, text=True, timeout=240)
    if missing_ok and result.returncode and "HTTP 404" in result.stderr:
        return None
    require(result.returncode == 0, "GitHub operation failed: " + result.stderr.strip())
    return result.stdout


def api(path: str, *, missing_ok: bool = False):
    output = gh("api", f"repos/{REPO}/{path}", missing_ok=missing_ok)
    return None if output is None else json.loads(output)


def find_release() -> dict | None:
    pages = json.loads(gh("api", f"repos/{REPO}/releases?per_page=100", "--paginate", "--slurp"))
    matches = [release for page in pages for release in page if release.get("tag_name") == TAG]
    require(len(matches) <= 1, "Ambiguous hero release")
    return matches[0] if matches else None


def read_json(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), f"Missing regular evidence file: {path.name}")
    return json.loads(path.read_text(encoding="utf-8"))


def verify_run(run: dict) -> None:
    expected = {"id": RUN_ID, "run_number": RUN_NUMBER, "head_sha": SOURCE,
                "head_branch": BRANCH, "path": ".github/workflows/android-prototype.yml",
                "event": "push", "status": "completed", "conclusion": "success"}
    for key, value in expected.items():
        require(run.get(key) == value, f"Source build is not the expected successful run: {key}")
    require(run.get("repository", {}).get("full_name") == REPO, "Wrong source repository")


def verify_emulator_proof(android: Path, runtime_report: dict) -> None:
    name = PREFIX + "-emulator.apk"
    emulator = android / name
    require(emulator.is_file() and not emulator.is_symlink(), "The tested emulator package is missing")
    checksum = digest(emulator)
    require(runtime_report.get("apk_file") == name and runtime_report.get("apk_sha256") == checksum,
            "Runtime proof describes a different emulator package")
    build = read_json(android / (PREFIX + "-emulator.build.json"))
    for key, value in {"source_commit": SOURCE, "apk": name, "apk_sha256": checksum,
                       "apk_size_bytes": emulator.stat().st_size, "abi": "x86_64", "package": PACKAGE,
                       "status": "verified_debug_apk"}.items():
        require(build.get(key) == value, f"Emulator build proof mismatch: {key}")


def verify_and_stage(android: Path, runtime: Path, output: Path) -> dict:
    require((android / "source-commit.txt").read_text().strip() == SOURCE, "Artifact source SHA mismatch")
    apk = android / APK_NAME
    require(apk.is_file() and not apk.is_symlink(), "The ARM64 APK is missing")
    checksum, size = digest(apk), apk.stat().st_size
    require((android / (APK_NAME + ".sha256")).read_text().split() == [checksum, APK_NAME],
            "The APK's checksum file does not match")
    entries = [line.split() for line in (android / "SHA256SUMS.txt").read_text().splitlines()]
    require([checksum, "artifacts/" + APK_NAME] in entries, "The build checksum inventory does not match")
    build = read_json(android / (PREFIX + "-arm64.build.json"))
    for key, value in {"source_commit": SOURCE, "apk": APK_NAME, "apk_sha256": checksum,
                       "apk_size_bytes": size, "abi": "arm64-v8a", "package": PACKAGE,
                       "status": "verified_debug_apk"}.items():
        require(build.get(key) == value, f"Build proof mismatch: {key}")
    validation = read_json(android / (PREFIX + "-arm64.validation.json"))
    require(validation.get("overall_status") == "pass" and validation.get("passed") is True,
            "APK validation did not pass")
    require(validation.get("apk", {}).get("sha256") == checksum
            and validation["apk"].get("size_bytes") == size, "APK validation describes different bytes")
    require(validation.get("expected_package") == PACKAGE and validation.get("expected_abi") == "arm64-v8a"
            and validation.get("manifest", {}).get("package") == PACKAGE
            and validation.get("available_abis") == ["arm64-v8a"], "Package or ABI proof mismatch")
    checks = {item["id"]: item for item in validation["checks"]}
    require(len(checks) == len(validation["checks"]), "Duplicate validation check IDs")
    required_checks = {"apk_file", "zip_structure", "zip_crc", "godot_native_library",
                       "godot_project_content", "hero_character_content", "manifest_metadata",
                       "package_identity", "signature_verification", "apk_unchanged"}
    require(all(checks.get(key, {}).get("status") == "pass" for key in required_checks),
            "Required APK/package/signature/hero checks are missing or failed")
    require(all(item.get("status") == "pass" for item in checks.values() if item.get("required")),
            "An additional required APK check did not pass")
    hero = checks["hero_character_content"]["evidence"]
    resources = hero.get("resources", [])
    require(hero.get("required_by_source") is True and hero.get("missing_resources") == []
            and len(resources) == 5 and {item["source"] for item in resources} == HERO_RESOURCES,
            "The complete four-LOD hero and facial controller were not validated")
    with zipfile.ZipFile(apk) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate APK entries")
        with archive.open("lib/arm64-v8a/libgodot_android.so") as stream:
            native = stream.read(64)
        require(len(native) == 64 and native[:6] == b"\x7fELF\x02\x01"
                and struct.unpack_from("<HH", native, 16) == (3, 183), "The actual native payload is not ARM64")
        for resource in resources:
            entry = resource.get("entry", "")
            require(entry.startswith("assets/") and ".." not in PurePosixPath(entry).parts,
                    "Invalid hero payload path")
            with archive.open(entry) as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            require(actual == resource.get("sha256")
                    and archive.getinfo(entry).file_size == resource.get("size_bytes", 0)
                    and resource.get("size_bytes", 0) > 0, "Hero payload bytes differ from the proof")
            if resource.get("remap"):
                require(hashlib.sha256(archive.read(resource["remap"])).hexdigest() == resource.get("remap_sha256"),
                        "Hero resource remap differs from the proof")
    engine = read_json(android / "engine-checks/validation_report.json")
    require(engine.get("passed") is True and engine.get("checks")
            and all(item.get("passed") is True for item in engine["checks"])
            and any(item.get("check") == "hero_faces" for item in engine["checks"]), "Godot hero checks did not pass")
    runtime_paths = list(runtime.rglob("runtime-report.json"))
    require(len(runtime_paths) == 1, "Expected exactly one runtime report in the runtime artifact")
    runtime_report = read_json(runtime_paths[0])
    require(runtime_report.get("status") == "passed" and runtime_report.get("source_commit") == SOURCE
            and runtime_report.get("test_harness_commit") == SOURCE and runtime_report.get("errors") == []
            and runtime_report.get("checks")
            and all(item.get("passed") is True for item in runtime_report["checks"]), "Emulator proof mismatch or failure")
    require(runtime_report.get("arm64_package", {}).get("sha256") == checksum
            and runtime_report["arm64_package"].get("name") == APK_NAME, "Emulator run used a different ARM64 download")
    verify_emulator_proof(android, runtime_report)
    output.mkdir()
    shutil.copyfile(apk, output / APK_NAME)
    public = {"APK-Pruefung": validation, "Godot-Pruefungen": engine, "Emulatorpruefung": runtime_report,
              "Buildnachweis": {key: build[key] for key in ("source_commit", "apk", "apk_sha256", "apk_size_bytes",
                                                          "abi", "package", "status", "godot_version", "requested_renderer")}}
    public["Buildnachweis"].update(source_run=RUN_ID, source_branch=BRANCH,
                                   source_run_url=f"https://github.com/{REPO}/actions/runs/{RUN_ID}")
    for suffix, value in public.items():
        (output / f"{PREFIX}-{suffix}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    (output / f"{PREFIX}-source-commit.txt").write_text(SOURCE + "\n")
    return {"sha256": checksum, "size_bytes": size, "arm64_runtime_test": runtime_report.get("arm64_runtime_test") is True}


def add_source_video(output: Path) -> None:
    def source_bytes(path: str) -> bytes:
        item = api(f"contents/{path}?ref={SOURCE}")
        require(item.get("type") == "file" and item.get("encoding") == "base64", "Missing source video evidence")
        data = base64.b64decode(item["content"])
        require(len(data) == item["size"] and hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == item["sha"],
                "Source video evidence failed Git blob verification")
        return data
    folder = "docs/14_character_realism/evidence/after/"
    receipt = json.loads(source_bytes(folder + "motion_receipt.json"))
    video = source_bytes(folder + "hero_march.mp4")
    require(hashlib.sha256(video).hexdigest() == receipt["video_sha256"] and len(video) == receipt["video_bytes"],
            "Hero video differs from its source-commit evidence")
    (output / f"{PREFIX}-Hauptfigur.mp4").write_bytes(video)


def verify_existing_assets(release: dict, files: list[Path], temporary: Path) -> list[Path]:
    require(release.get("tag_name") == TAG and release.get("target_commitish") == SOURCE
            and release.get("prerelease") is True, "Existing release has a different source or purpose")
    existing = {asset["name"]: asset for asset in release.get("assets", [])}
    require(len(existing) == len(release.get("assets", [])), "Duplicate existing release asset names")
    require(set(existing) <= {path.name for path in files}, "Existing release contains unexpected assets; no changes made")
    missing = []
    for path in files:
        asset = existing.get(path.name)
        if asset is None:
            missing.append(path)
            continue
        require(asset.get("size") == path.stat().st_size, "Existing asset differs; refusing to overwrite " + path.name)
        expected = "sha256:" + digest(path)
        if asset.get("digest") is None:
            destination = temporary / ("existing-" + str(asset["id"]) + "-" + path.name)
            if not destination.exists():
                gh("release", "download", TAG, "--repo", REPO, "--pattern", path.name, "--output", str(destination))
            require(digest(destination) == expected[7:], "Existing asset hash differs; refusing to overwrite " + path.name)
        else:
            require(asset["digest"] == expected, "Existing asset hash differs; refusing to overwrite " + path.name)
    return missing


def publish(files: list[Path], notes: Path, temporary: Path) -> str:
    tag = api("git/ref/tags/" + TAG, missing_ok=True)
    if tag is not None:
        obj = tag["object"]
        for _ in range(4):
            if obj.get("type") != "tag":
                break
            obj = api("git/tags/" + obj["sha"])["object"]
        require(obj.get("type") == "commit" and obj.get("sha") == SOURCE, "Existing tag points to another source")
    release = find_release()
    if release is None:
        gh("release", "create", TAG, "--repo", REPO, "--target", SOURCE, "--draft", "--prerelease", "--latest=false",
           "--title", "IMPERATHEN – Hauptfigur · Android-Prüffassung", "--notes-file", str(notes))
        release = find_release()
        require(release is not None, "The draft release was not created")
    missing = verify_existing_assets(release, files, temporary)
    if missing:
        gh("release", "upload", TAG, "--repo", REPO, *(str(path) for path in missing))
    release = find_release()
    require(release is not None, "The release disappeared during upload")
    require(not verify_existing_assets(release, files, temporary), "Public download is still incomplete")
    if release.get("draft"):
        gh("release", "edit", TAG, "--repo", REPO, "--draft=false", "--prerelease", "--latest=false")
    release = find_release()
    require(release is not None and release.get("draft") is False and release.get("prerelease") is True,
            "The verified prerelease was not published")
    return f"https://github.com/{REPO}/releases/tag/{TAG}"


def main() -> None:
    require(os.environ.get("GH_REPO") == REPO and bool(os.environ.get("GH_TOKEN")), "Expected repository job token required")
    require(os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH, "Unexpected publication branch")
    verify_run(api(f"actions/runs/{RUN_ID}"))
    with tempfile.TemporaryDirectory(prefix="imperathen-hero-download-") as work:
        temporary = Path(work)
        android, runtime, public = (temporary / name for name in ("android", "runtime", "public"))
        for name, destination in ((f"imperathen-android-{RUN_NUMBER}", android),
                                  (f"imperathen-android-runtime-{RUN_NUMBER}", runtime)):
            gh("run", "download", str(RUN_ID), "--repo", REPO, "--name", name, "--dir", str(destination))
        verified = verify_and_stage(android, runtime, public)
        add_source_video(public)
        files = sorted(public.iterdir())
        sums = public / f"{PREFIX}-SHA256SUMS.txt"
        sums.write_text("".join(f"{digest(path)}  {path.name}\n" for path in files))
        files.append(sums)
        notes = temporary / "release-notes.md"
        notes.write_text(f"## Android-Prüffassung mit neuer Hauptfigur\n\n"
                         f"Für Android-Geräte mit ARM64: **{APK_NAME}**.\n\n"
                         f"Quellstand: `{SOURCE}`. [Erfolgreicher Bau und Emulatorprüfung]"
                         f"(https://github.com/{REPO}/actions/runs/{RUN_ID}). Paket: `{PACKAGE}`.\n\n"
                         "Enthalten sind vier Hero-Detailstufen und die Gesichtskomponente. "
                         "APK-Inhalt, ARM64-Bibliothek, Paketname und Prüfsummen wurden geprüft. "
                         "Die öffentlichen Prüfberichte liegen bei.\n\n"
                         "Dies ist eine technische Prüffassung. Die gewünschte visuelle Qualität "
                         "ist noch offen; ein Test auf einem physischen Fold7 ist damit nicht belegt. "
                         "Das beigefügte Video zeigt eine echte Godot-Studioaufnahme, keinen Android-Gerätelauf. "
                         "Der gestoppte Grafik-Dauertest wurde nicht neu gestartet.\n\n"
                         f"APK: {verified['size_bytes']} Bytes; SHA-256: `{verified['sha256']}`.\n", encoding="utf-8")
        print("HERO_DOWNLOAD_PUBLISHED", publish(files, notes, temporary))


if __name__ == "__main__":
    main()
