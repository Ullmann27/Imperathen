#!/usr/bin/env python3
"""Publish this run's verified village APK after the dependent build job passes.

Only the public ARM64 package and its matching non-secret evidence are admitted.
Existing releases are resumed by tag and verified; no asset is overwritten.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile

from validate_android_apk import FRONTIER_RESOURCES, HERO_RESOURCES, OPENING_RESOURCES, VILLAGE_LIFE_RESOURCES

REPO = "Ullmann27/Imperathen"
BRANCH = "feature/village-life-delivery-20261123"
PACKAGE = "at.heinz.imperathen"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def gh(*args: str, missing_ok: bool = False) -> str | None:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=240)
    if missing_ok and result.returncode and "HTTP 404" in result.stderr:
        return None
    require(result.returncode == 0, "GitHub operation failed: " + result.stderr.strip())
    return result.stdout


def api(path: str, *, missing_ok: bool = False):
    result = gh("api", f"repos/{REPO}/{path}", missing_ok=missing_ok)
    return None if result is None else json.loads(result)


def read_json(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), "Missing evidence: " + path.name)
    return json.loads(path.read_text(encoding="utf-8"))


def verify_run(source: str, run_id: str, number: str) -> None:
    run = api(f"actions/runs/{run_id}")
    for key, value in {"head_sha": source, "head_branch": BRANCH,
                       "path": ".github/workflows/android-prototype.yml",
                       "id": int(run_id), "run_number": int(number)}.items():
        require(run.get(key) == value, "Unexpected source build: " + key)
    require(run.get("repository", {}).get("full_name") == REPO, "Unexpected source repository")
    require(run.get("event") in {"push", "workflow_dispatch"}, "Unexpected build event")
    # This publication job is part of the same still-running workflow. Its
    # required predecessor, including the emulator step, must already be green.
    jobs = api(f"actions/runs/{run_id}/jobs?filter=latest&per_page=100")["jobs"]
    build_jobs = [job for job in jobs if job.get("name") == "build-and-check"]
    require(len(build_jobs) == 1 and build_jobs[0].get("status") == "completed"
            and build_jobs[0].get("conclusion") == "success", "The build/emulator job has not passed")


def verify_and_stage(android: Path, runtime: Path, public: Path, source: str, run_id: str) -> dict:
    prefix = "IMPERATHEN-" + source[:8]
    apk_name = prefix + "-arm64.apk"
    apk = android / apk_name
    require(apk.is_file() and not apk.is_symlink(), "Missing regular ARM64 package")
    checksum, size = digest(apk), apk.stat().st_size
    require((android / "source-commit.txt").read_text().strip() == source, "Wrong artifact source")
    require((android / (apk_name + ".sha256")).read_text().split() == [checksum, apk_name], "APK checksum mismatch")
    build = read_json(android / (prefix + "-arm64.build.json"))
    for key, value in {"source_commit": source, "apk": apk_name, "apk_sha256": checksum,
                       "apk_size_bytes": size, "abi": "arm64-v8a", "package": PACKAGE,
                       "status": "verified_debug_apk"}.items():
        require(build.get(key) == value, "Build proof mismatch: " + key)
    validation = read_json(android / (prefix + "-arm64.validation.json"))
    require(validation.get("passed") is True and validation.get("overall_status") == "pass",
            "APK validation did not pass")
    require(validation.get("apk", {}).get("sha256") == checksum
            and validation["apk"].get("size_bytes") == size, "Validation describes other bytes")
    require(validation.get("manifest", {}).get("package") == PACKAGE
            and validation["manifest"].get("version_code") == "3"
            and validation["manifest"].get("version_name") == "0.3.0-village"
            and validation.get("expected_abi") == "arm64-v8a"
            and validation.get("available_abis") == ["arm64-v8a"], "Package or ABI mismatch")
    checks = {item["id"]: item for item in validation["checks"]}
    require(len(checks) == len(validation["checks"]), "Duplicate check identifiers")
    required = {"apk_file", "zip_structure", "zip_crc", "godot_native_library", "godot_project_content",
                "hero_character_content", "living_frontier_content", "cinematic_opening_content", "village_life_content", "manifest_metadata",
                "package_identity", "signature_verification", "apk_unchanged"}
    require(all(checks.get(key, {}).get("status") == "pass" for key in required), "Missing required APK proof")
    require(all(item.get("status") == "pass" for item in checks.values() if item.get("required")),
            "An additional required check failed")
    with zipfile.ZipFile(apk) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate archive entries")
        for identifier, expected in (("hero_character_content", set(HERO_RESOURCES)),
                                     ("living_frontier_content", set(FRONTIER_RESOURCES)),
                                     ("cinematic_opening_content", set(OPENING_RESOURCES)),
                                     ("village_life_content", set(VILLAGE_LIFE_RESOURCES))):
            evidence = checks[identifier]["evidence"]
            resources = evidence.get("resources", [])
            require(evidence.get("required_by_source") is True and evidence.get("missing_resources") == []
                    and len(resources) == len(expected) and {r["source"] for r in resources} == expected,
                    "Incomplete feature proof: " + identifier)
            for resource in resources:
                entry = resource.get("entry", "")
                require(entry.startswith("assets/") and ".." not in PurePosixPath(entry).parts,
                        "Unsafe resource path")
                with archive.open(entry) as stream:
                    actual = hashlib.file_digest(stream, "sha256").hexdigest()
                require(actual == resource.get("sha256") and resource.get("size_bytes", 0) > 0
                        and archive.getinfo(entry).file_size == resource["size_bytes"], "Resource bytes differ")
                if resource.get("remap"):
                    require(hashlib.sha256(archive.read(resource["remap"])).hexdigest() == resource.get("remap_sha256"),
                            "Resource remap differs")
    engine = read_json(android / "engine-checks/validation_report.json")
    require(engine.get("passed") is True and engine.get("checks")
            and all(c.get("passed") is True for c in engine["checks"]), "Godot checks did not pass")
    names = {c.get("check") for c in engine["checks"]}
    require({"frontier_story", "frontier_population", "frontier_people", "frontier_integration",
             "village_economy", "village_life", "village_model", "village_experience", "opening_flow"} <= names,
            "Village gameplay, opening or people tests were not executed")
    candidates = list(runtime.rglob("runtime-report.json"))
    require(len(candidates) == 1, "Expected one emulator report")
    runtime_report = read_json(candidates[0])
    require(runtime_report.get("status") == "passed" and runtime_report.get("source_commit") == source
            and runtime_report.get("test_harness_commit") == source and runtime_report.get("errors") == []
            and runtime_report.get("checks") and all(c.get("passed") is True for c in runtime_report["checks"]),
            "Emulator check failed or belongs to another source")
    runtime_checks = {item.get("name") for item in runtime_report["checks"]}
    require({"opening_before_gameplay", "objective_hands_over_control", "village_actual_population",
             "village_touch_meets_decimus", "village_touch_work_permission", "village_actual_worker_assignment",
             "village_decisions_survive_restart"} <= runtime_checks, "The Android village journey was not exercised")
    require(runtime_report.get("arm64_package", {}).get("sha256") == checksum
            and runtime_report["arm64_package"].get("name") == apk_name, "ARM64 runtime proof mismatch")
    emulator = android / (prefix + "-emulator.apk")
    emulator_hash = digest(emulator)
    require(runtime_report.get("apk_file") == emulator.name and runtime_report.get("apk_sha256") == emulator_hash,
            "Runtime proof describes another emulator APK")
    emulator_build = read_json(android / (prefix + "-emulator.build.json"))
    require(emulator_build.get("source_commit") == source and emulator_build.get("apk_sha256") == emulator_hash
            and emulator_build.get("abi") == "x86_64" and emulator_build.get("status") == "verified_debug_apk",
            "Emulator package build proof mismatch")
    public.mkdir()
    shutil.copyfile(apk, public / apk_name)
    build_public = {key: build[key] for key in ("source_commit", "apk", "apk_sha256", "apk_size_bytes", "abi", "package", "status", "godot_version", "requested_renderer")}
    build_public.update(source_run=int(run_id), source_branch=BRANCH,
                        source_run_url=f"https://github.com/{REPO}/actions/runs/{run_id}")
    for suffix, value in {"APK-Pruefung": validation, "Godot-Pruefungen": engine,
                          "Emulatorpruefung": runtime_report, "Buildnachweis": build_public}.items():
        (public / f"{prefix}-{suffix}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (public / f"{prefix}-source-commit.txt").write_text(source + "\n", encoding="utf-8")
    files = sorted(public.iterdir())
    (public / f"{prefix}-SHA256SUMS.txt").write_text("".join(f"{digest(p)}  {p.name}\n" for p in files), encoding="utf-8")
    return {"apk": apk_name, "sha256": checksum, "size_bytes": size}


def publish(public: Path, temporary: Path, source: str, run_id: str, proof: dict) -> str:
    tag = "village-2026-11-23-" + source[:8]
    notes = ("## IMPERATHEN 0.3.0 – Wiederaufbau und Leben im Dorf\n\n"
             f"Android ARM64: **{proof['apk']}**. Größe: {proof['size_bytes']} Bytes.\n\n"
             "Überarbeiteter Spielbeginn unter Verwalter Decimus, vierzehn echte Arbeitskräfte, fünf Betriebe, "
             "Gespräche und Berufe sowie Dorfverteidigung. Die Android-Prüfung startet die Partie, spricht mit Decimus, "
             "erteilt einen tatsächlichen Arbeitsauftrag und prüft seine Erhaltung nach einem Prozessneustart.\n\n"
             f"Spielquellstand: `{source}`. [Bau und Emulatorprüfung](https://github.com/{REPO}/actions/runs/{run_id}). "
             "Die beigefügten Berichte gehören zu genau diesem Paket. Eine physische Fold7- oder thermische Dauerprüfung "
             "ist damit nicht belegt.\n\n"
             "**Installation:** Diese Prüffassung verwendet einen neuen privaten Debug-Signierschlüssel. "
             "Ein direktes Update über frühere Prüfbauten und die Übernahme ihrer App-Daten sind daher nicht zugesagt. "
             "Eine vorhandene Installation mit wichtigem Spielstand nicht ungeprüft deinstallieren.\n\n"
             f"SHA-256: `{proof['sha256']}`.\n")
    release = api("releases/tags/" + tag, missing_ok=True)
    if release is None:
        request = temporary / "create-release.json"
        request.write_text(json.dumps({"tag_name": tag, "target_commitish": source,
                                      "name": "IMPERATHEN · Dorfleben 0.3.0 · " + source[:8],
                                      "body": notes, "draft": True, "prerelease": True}), encoding="utf-8")
        release = json.loads(gh("api", f"repos/{REPO}/releases", "--method", "POST", "--input", str(request)))
    require(release.get("tag_name") == tag and release.get("target_commitish") == source
            and release.get("prerelease") is True, "Existing release has another purpose")
    release_id = release["id"]
    files = {p.name: p for p in public.iterdir() if p.is_file() and not p.is_symlink()}
    existing = {a["name"]: a for a in release.get("assets", [])}
    require(set(existing) <= set(files), "Existing release contains unexpected files")
    for name, asset in existing.items():
        require(asset.get("size") == files[name].stat().st_size, "Refusing to replace different asset")
        expected = "sha256:" + digest(files[name])
        if asset.get("digest") is not None:
            require(asset["digest"] == expected, "Existing release asset hash differs")
        else:
            target = temporary / ("existing-" + name)
            gh("release", "download", tag, "--repo", REPO, "--pattern", name, "--output", str(target))
            require(digest(target) == expected[7:], "Existing release bytes differ")
    missing = [str(path) for name, path in files.items() if name not in existing]
    if missing:
        gh("release", "upload", tag, "--repo", REPO, *missing)
    release = api(f"releases/{release_id}")
    assets = {a["name"]: a for a in release.get("assets", [])}
    require(set(assets) == set(files), "Uploaded file inventory is incomplete")
    for name, path in files.items():
        require(assets[name].get("state") == "uploaded" and assets[name].get("size") == path.stat().st_size,
                "Uploaded file has wrong size or state")
        if assets[name].get("digest") is not None:
            require(assets[name]["digest"] == "sha256:" + digest(path), "Uploaded hash differs")
        else:
            target = temporary / ("uploaded-" + name)
            gh("release", "download", tag, "--repo", REPO, "--pattern", name, "--output", str(target))
            require(digest(target) == digest(path), "Uploaded bytes differ")
    if release.get("draft"):
        request = temporary / "publish-release.json"
        request.write_text(json.dumps({"draft": False, "prerelease": True, "make_latest": "false", "body": notes}), encoding="utf-8")
        gh("api", f"repos/{REPO}/releases/{release_id}", "--method", "PATCH", "--input", str(request))
    require(api(f"releases/{release_id}").get("draft") is False, "Release remains a draft")
    return f"https://github.com/{REPO}/releases/tag/{tag}"


def main() -> None:
    source, run_id, number = (os.environ.get(key, "") for key in ("GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_NUMBER"))
    require(os.environ.get("GH_REPO") == REPO and bool(os.environ.get("GH_TOKEN"))
            and os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH, "Expected repository publication context is missing")
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None and run_id.isdigit() and number.isdigit(), "Invalid source/run identity")
    verify_run(source, run_id, number)
    with tempfile.TemporaryDirectory(prefix="imperathen-village-release-") as work:
        temporary = Path(work)
        android, runtime, public = (temporary / p for p in ("android", "runtime", "public"))
        for name, target in ((f"imperathen-android-{number}", android), (f"imperathen-android-runtime-{number}", runtime)):
            gh("run", "download", run_id, "--repo", REPO, "--name", name, "--dir", str(target))
        proof = verify_and_stage(android, runtime, public, source, run_id)
        print("VILLAGE_DOWNLOAD_PUBLISHED", publish(public, temporary, source, run_id, proof))


if __name__ == "__main__":
    main()
