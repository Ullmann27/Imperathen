#!/usr/bin/env python3
"""Publish this run's verified village APK after the dependent build job passes.

Only the public ARM64 package and its matching non-secret evidence are admitted.
Existing releases are resumed by tag and verified; no asset is overwritten.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile

from validate_android_apk import (FRONTIER_RESOURCES, HERO_RESOURCES, OPENING_RESOURCES,
                                 VILLAGE_LIFE_RESOURCES, CHILDHOOD_RESOURCES,
                                 CAMPAIGN_BIBLE_RESOURCES, MESHY_REGISTRY_RESOURCES,
                                 NPC_BEHAVIOR_RESOURCES, MESHY_CHARACTER_RESOURCES,
                                 MESHY_EQUIPMENT_RESOURCES, SERVICE_GEAR_RESOURCES, CC0_MOTION_RESOURCES)

REPO = "Ullmann27/Imperathen"
BRANCH = "feature/village-life-delivery-20261123"
PACKAGE = "at.heinz.imperathen"
LIVING_PROFILE = {
    "branch": "feature/living-npcs-meshy-movement-20261124",
    "version_code": "5", "version_name": "0.5.0-living-village",
    "tag_prefix": "living-village-2026-11-24-",
    "title": "IMPERATHEN · Lebendiges Dorf 0.5.0",
    "description": (
        "Die Arbeitsanimation lässt Gehen und Laufen wieder unmittelbar zu. "
        "Dorfbewohner berücksichtigen eigene Interessen, Erschöpfung, Begegnungen, Wetter und Gefahr. "
        "Zwei vorhandene Meshy-Figuren sind mit Skeletten, Bewegungsclips und vier Detailstufen angeschlossen; "
        "Axt, Schild und Feldzeichen folgen den animierten Händen. "
        "Fünf weitere Meshy-Quellen benötigen noch eine Bearbeitung ihrer verbundenen Körper, Requisiten oder Pferde. "
        "Der Kindheitsweg mit Julia, Silvanus und Sextus bleibt erhalten."
    ),
    "engine_checks": {"locomotion_regression", "npc_behavior", "npc_behavior_world", "npc_behavior_ui", "meshy_characters", "meshy_equipment"},
    "runtime_checks": {"actual_family_start", "native_interaction_reaches_mother",
                       "native_item_action_fills_family_jug", "family_actions_and_items_survive_restart",
                       "native_pad_moves_actual_player", "native_tap_selects_running",
                       "npc_behavior_connected", "npc_behavior_advances", "npc_behavior_saved_snapshot",
                       "npc_behavior_survives_restart", "meshy_severus_loaded",
                       "meshy_severus_loaded_after_restart", "native_walk_uses_locomotion_clip"},
}


MOTION_PROFILE = {
    **LIVING_PROFILE,
    "branch": "feature/npc-perception-rest-regression-20261124",
    "version_code": "6", "version_name": "0.6.0-motion-combat",
    "tag_prefix": "motion-combat-2026-11-24-",
    "title": "IMPERATHEN · Bewegung und Dorfleben 0.6.0",
    "description": (
        "Geprüfte Zwischenfassung mit lokaler NPC-Navigation, natürlichen Stand- und Gesprächsbewegungen, "
        "fünf Gladius-Techniken im bereits vorhandenen erwachsenen Ausbildungsweg und fünf sichtbaren Schildhaltungen. "
        "Gladius und Scutum sind die vorhandenen projektierten Waffen-GLBs; zwei Meshy-Körper bleiben integriert. "
        "Der kanonische Kindheitsweg bleibt zwölfjährig. Weitere Figuren, externe Motion-Capture-Clips und "
        "der vollständige spätere Lebensweg sind nicht Teil dieser Zwischenfassung."
    ),
    "engine_checks": LIVING_PROFILE["engine_checks"] | {"natural_motion", "character_motion", "combat_actions", "combat_model", "service_gear", "unarmed_combat", "action_world"},
}


CC0_PROFILE = {
    **MOTION_PROFILE,
    "branch": "integration/motion-combat-cc0-20261124",
    "version_code": "7", "version_name": "0.7.0-cc0-motion",
    "tag_prefix": "cc0-motion-2026-11-24-",
    "title": "IMPERATHEN · Bewegung, Dorfleben und CC0 0.7.0",
    "description": (
        "Geprüfte Zwischenfassung mit NPC-Navigation und fünf Gladius-Techniken im erwachsenen Ausbildungsweg. "
        "Die vollständige übertragene CC0-Bibliothek mit 35 Bewegungsclips und Referenzanimation liegt als Spielressource vor. "
        "Stand- und Gesprächsbewegungen nutzen begrenzte CC0-Überlagerungen am vorhandenen Hauptfiguren-Skelett; "
        "die übrigen Clips bleiben Prüfmaterial. Zwei Meshy-Figuren sind eingebunden, weitere Figuren und der "
        "vollständige spätere Lebensweg sind weiterhin nicht Bestandteil dieser Fassung."
    ),
    "engine_checks": MOTION_PROFILE["engine_checks"] | {"cc0_runtime_gestures"},
}


STRICT_MOTION_PROFILE = {
    **CC0_PROFILE,
    "branch": "feature/motion-quality-gate-20261124",
    "version_code": "8", "version_name": "0.8.0-motion-quality",
    "tag_prefix": "motion-quality-2026-11-24-",
    "title": "IMPERATHEN · geprüfter Bewegungsstandard 0.8.0",
    "description": "Zwischenfassung mit verpflichtender Motion Quality Gate-Freigabe; Nachweise gelten für genau diesen Quellstand.",
    "engine_checks": CC0_PROFILE["engine_checks"] | {"motion_measurement"},
}


def feature_groups(profile: dict | None = None) -> tuple:
    groups = (("hero_character_content", HERO_RESOURCES),
              ("living_frontier_content", FRONTIER_RESOURCES),
              ("cinematic_opening_content", OPENING_RESOURCES),
              ("village_life_content", VILLAGE_LIFE_RESOURCES))
    if profile is not None:
        groups += (("childhood_content", CHILDHOOD_RESOURCES),
                   ("campaign_bible_content", CAMPAIGN_BIBLE_RESOURCES),
                   ("meshy_registry_content", MESHY_REGISTRY_RESOURCES),
                   ("npc_behavior_content", NPC_BEHAVIOR_RESOURCES),
                   ("meshy_character_content", MESHY_CHARACTER_RESOURCES),
                   ("meshy_equipment_content", MESHY_EQUIPMENT_RESOURCES))
    if profile is not None and profile.get("branch") in {MOTION_PROFILE["branch"], CC0_PROFILE["branch"], STRICT_MOTION_PROFILE["branch"]}:
        groups += (("service_gear_content", SERVICE_GEAR_RESOURCES),)
    if profile is not None and profile.get("branch") in {CC0_PROFILE["branch"], STRICT_MOTION_PROFILE["branch"]}:
        groups += (("cc0_motion_content", CC0_MOTION_RESOURCES),)
    return groups


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
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, "Duplicate evidence field: " + key)
            value[key] = item
        return value

    def invalid_constant(value):
        raise RuntimeError("Invalid evidence number: " + value)

    def finite_float(value):
        number = float(value)
        require(math.isfinite(number), "Non-finite evidence number")
        return number

    result = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs,
                        parse_constant=invalid_constant, parse_float=finite_float)
    require(isinstance(result, dict), "Evidence must be an object: " + path.name)
    return result


def verify_motion_evidence(android: Path, build: dict, engine: dict, source: str) -> dict:
    """Recheck the gate/report chain before creating a public release directory."""
    gate_path = android / "engine-checks/motion-gate.json"
    measurement_path = android / "engine-checks/motion-measurements.json"
    motion, measured = read_json(gate_path), read_json(measurement_path)
    fingerprint = motion.get("source_fingerprint")
    require(isinstance(fingerprint, str) and re.fullmatch(r"[0-9a-f]{64}", fingerprint) is not None,
            "Motion quality proof has no valid source fingerprint")
    require(re.fullmatch(r"[0-9a-f]{64}", str(build.get("source_sha256", ""))) is not None,
            "Build proof has no exact project snapshot hash")
    require(type(motion.get("schema_version")) is int and motion["schema_version"] == 1
            and motion.get("passed") is True and motion.get("source_commit") == source
            and motion.get("sample_hz") == 60 and motion.get("failures") == []
            and fingerprint == build.get("motion_source_fingerprint")
            and engine.get("source_commit") == source
            and engine.get("motion_source_fingerprint") == fingerprint
            and motion.get("engine_report_sha256") == digest(android / "engine-checks/validation_report.json")
            and motion.get("measurement_report_sha256") == digest(measurement_path)
            and build.get("motion_gate_sha256") == digest(gate_path)
            and re.fullmatch(r"[0-9a-f]{64}", str(motion.get("review_report_sha256", ""))) is not None,
            "Motion quality evidence missing, failed or does not match the APK")
    families = motion.get("families")
    require(isinstance(families, list) and bool(families)
            and all(isinstance(family, dict) and isinstance(family.get("id"), str)
                    and family.get("passed") is True and family.get("failures") == [] for family in families),
            "A movement family did not pass")
    require(len({family["id"] for family in families}) == len(families), "Duplicate movement family proof")
    require(type(measured.get("schema_version")) is int and measured["schema_version"] == 1
            and measured.get("source_fingerprint") == fingerprint and measured.get("sample_hz") == 60
            and measured.get("fatal") == [] and measured.get("complete") is True and isinstance(measured.get("assets"), dict)
            and type(motion.get("measured_assets")) is int and motion["measured_assets"] == len(measured["assets"])
            and isinstance(measured.get("family_metrics"), dict),
            "Raw movement measurement is missing, failed or differs from the gate")
    active = {family["id"] for family in families if family.get("status") == "active"}
    require(bool(active) and active <= measured["family_metrics"].keys(),
            "Active movement families lack actual measurements")
    return motion


def find_release(tag: str) -> dict | None:
    # REST /releases/tags/{tag} only finds published releases. Resolve the
    # pending tag through GraphQL as gh release does, then read the known ID.
    # A failed or incomplete lookup must never create a second draft.
    owner, repository = REPO.split("/", 1)
    query = ("query($owner:String!,$repository:String!,$tag:String!){"
             "repository(owner:$owner,name:$repository){release(tagName:$tag){databaseId}}}")
    result = json.loads(gh("api", "graphql", "-f", "query=" + query,
                           "-f", "owner=" + owner, "-f", "repository=" + repository,
                           "-f", "tag=" + tag))
    require(not result.get("errors"), "Release lookup returned GraphQL errors")
    repository_result = (result.get("data") or {}).get("repository")
    require(isinstance(repository_result, dict) and "release" in repository_result,
            "Release lookup did not return repository data")
    release = repository_result["release"]
    if release is None:
        return None
    require(isinstance(release, dict) and type(release.get("databaseId")) is int
            and release["databaseId"] > 0, "Release lookup returned an invalid ID")
    return api(f"releases/{release['databaseId']}")


def verify_run(source: str, run_id: str, number: str, profile: dict | None = None) -> None:
    run = api(f"actions/runs/{run_id}")
    for key, value in {"head_sha": source, "head_branch": profile["branch"] if profile else BRANCH,
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


def verify_signing_pair(build: dict, emulator_build: dict) -> dict:
    """Bind signer evidence to both packages without asserting update compatibility.

    Older artifacts without identity evidence are not retroactively certified.
    Their existing releases remain unchanged; a new publication requires a new
    build proof containing the measured public certificate identities.
    """
    identities = []
    for label, proof in (("ARM64", build), ("emulator", emulator_build)):
        identity = proof.get("signing_identity")
        require(isinstance(identity, dict), label + " signing identity evidence is missing")
        certificates = identity.get("signer_certificates_sha256")
        require(type(identity.get("schema_version")) is int and identity["schema_version"] == 1
                and identity.get("status") == "verified"
                and isinstance(identity.get("apk_sha256"), str)
                and re.fullmatch(r"[0-9a-f]{64}", identity["apk_sha256"]) is not None
                and identity["apk_sha256"] == proof.get("apk_sha256"),
                label + " signing evidence describes another or unverified APK")
        require(isinstance(certificates, list) and 0 < len(certificates) <= 32
                and all(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
                        for value in certificates)
                and certificates == sorted(set(certificates)),
                label + " signing certificate fingerprints are incomplete or invalid")
        expected = identity.get("expected_certificate_sha256")
        comparison = identity.get("comparison")
        if expected is None:
            require(comparison == "not_checked", label + " signing comparison claims an unprovided certificate")
        else:
            require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected) is not None
                    and certificates == [expected] and comparison == "matched_expected_certificate",
                    label + " signing certificate differs from its expected identity")
        require(proof.get("expected_signer_sha256") == expected,
                label + " configured signing certificate differs from its comparison evidence")
        identities.append(identity)
    require(identities[0]["signer_certificates_sha256"] == identities[1]["signer_certificates_sha256"],
            "ARM64 and emulator APKs use different signing certificates")
    require(identities[0].get("expected_certificate_sha256") == identities[1].get("expected_certificate_sha256")
            and identities[0]["comparison"] == identities[1]["comparison"],
            "ARM64 and emulator builds used different expected certificate contracts")
    return identities[0]


def verify_and_stage(android: Path, runtime: Path, public: Path, source: str, run_id: str,
                     profile: dict | None = None) -> dict:
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
            and validation["manifest"].get("version_code") == (profile["version_code"] if profile else "3")
            and validation["manifest"].get("version_name") == (profile["version_name"] if profile else "0.3.0-village")
            and validation.get("expected_abi") == "arm64-v8a"
            and validation.get("available_abis") == ["arm64-v8a"], "Package or ABI mismatch")
    checks = {item["id"]: item for item in validation["checks"]}
    require(len(checks) == len(validation["checks"]), "Duplicate check identifiers")
    required = {"apk_file", "zip_structure", "zip_crc", "godot_native_library", "godot_project_content",
                "hero_character_content", "living_frontier_content", "cinematic_opening_content", "village_life_content", "manifest_metadata",
                "package_identity", "signature_verification", "apk_unchanged"}
    required.update(name for name, _ in feature_groups(profile))
    require(all(checks.get(key, {}).get("status") == "pass" for key in required), "Missing required APK proof")
    require(all(item.get("status") == "pass" for item in checks.values() if item.get("required")),
            "An additional required check failed")
    with zipfile.ZipFile(apk) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate archive entries")
        for identifier, paths in feature_groups(profile):
            expected = set(paths)
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
    if profile:
        require(profile["engine_checks"] <= names, "The living-village regression groups were not executed")
    motion = None
    if profile and profile.get("branch") == STRICT_MOTION_PROFILE["branch"]:
        gate_path = android / "engine-checks/motion-gate.json"
        measurement_path = android / "engine-checks/motion-measurements.json"
        motion = verify_motion_evidence(android, build, engine, source)
    candidates = list(runtime.rglob("runtime-report.json"))
    require(len(candidates) == 1, "Expected one emulator report")
    runtime_report = read_json(candidates[0])
    require(runtime_report.get("status") == "passed" and runtime_report.get("source_commit") == source
            and runtime_report.get("test_harness_commit") == source and runtime_report.get("errors") == []
            and runtime_report.get("checks") and all(c.get("passed") is True for c in runtime_report["checks"]),
            "Emulator check failed or belongs to another source")
    runtime_checks = {item.get("name") for item in runtime_report["checks"]}
    expected_runtime = profile["runtime_checks"] if profile else {
        "opening_before_gameplay", "objective_hands_over_control", "village_actual_population",
        "village_touch_meets_decimus", "village_touch_work_permission", "village_actual_worker_assignment",
        "village_decisions_survive_restart"}
    require(expected_runtime <= runtime_checks, "The Android village journey was not exercised")
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
    if motion is not None:
        require(emulator_build.get("motion_gate_sha256") == build.get("motion_gate_sha256")
                and emulator_build.get("motion_source_fingerprint") == build.get("motion_source_fingerprint")
                and emulator_build.get("source_sha256") == build.get("source_sha256")
                and build.get("requested_renderer") == emulator_build.get("requested_renderer") == "compatibility",
                "Android runtime package lacks matching motion quality evidence")
    signing_identity = verify_signing_pair(build, emulator_build)
    public.mkdir()
    shutil.copyfile(apk, public / apk_name)
    if motion is not None:
        shutil.copyfile(gate_path, public / f"{prefix}-Motion-Quality-Gate.json")
        shutil.copyfile(measurement_path, public / f"{prefix}-Motion-Messungen.json")
    build_public = {key: build[key] for key in ("source_commit", "apk", "apk_sha256", "apk_size_bytes", "abi", "package", "status", "godot_version", "requested_renderer")}
    if motion is not None:
        build_public.update(motion_gate_sha256=build["motion_gate_sha256"],
                            motion_source_fingerprint=build["motion_source_fingerprint"],
                            source_sha256=build["source_sha256"])
    build_public.update(source_run=int(run_id), source_branch=profile["branch"] if profile else BRANCH,
                        source_run_url=f"https://github.com/{REPO}/actions/runs/{run_id}",
                        signing_identity=signing_identity)
    for suffix, value in {"APK-Pruefung": validation, "Godot-Pruefungen": engine,
                          "Emulatorpruefung": runtime_report, "Buildnachweis": build_public}.items():
        (public / f"{prefix}-{suffix}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (public / f"{prefix}-source-commit.txt").write_text(source + "\n", encoding="utf-8")
    files = sorted(public.iterdir())
    (public / f"{prefix}-SHA256SUMS.txt").write_text("".join(f"{digest(p)}  {p.name}\n" for p in files), encoding="utf-8")
    return {"apk": apk_name, "sha256": checksum, "size_bytes": size}


def publish(public: Path, temporary: Path, source: str, run_id: str, proof: dict,
            profile: dict | None = None) -> str:
    tag = (profile["tag_prefix"] if profile else "village-2026-11-23-") + source[:8]
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
    if profile:
        notes = (f"## {profile['title']}\n\n{profile['description']}\n\n"
                 f"Android ARM64: **{proof['apk']}**, {proof['size_bytes']} Bytes.\n\n"
                 f"Spielquellstand: `{source}`. [Bau und Emulatorprüfung](https://github.com/{REPO}/actions/runs/{run_id}). "
                 "Die Prüfberichte und das Paket sind anhand ihrer Prüfsummen verbunden. "
                 "Die Android-Laufzeitprüfung stammt aus einem Emulator; ein physischer Fold7- und Wärmetest steht aus.\n\n"
                 "Diese Prüffassung verwendet einen eigenen Debug-Schlüssel. Vorhandene Spielstände vor einem Installationswechsel sichern.\n\n"
                 f"SHA-256: `{proof['sha256']}`.\n")
    release = find_release(tag)
    if release is None:
        request = temporary / "create-release.json"
        request.write_text(json.dumps({"tag_name": tag, "target_commitish": source,
                                      "name": (profile["title"] if profile else "IMPERATHEN · Dorfleben 0.3.0") + " · " + source[:8],
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
    profile = next((p for p in (LIVING_PROFILE, MOTION_PROFILE, CC0_PROFILE, STRICT_MOTION_PROFILE)
                    if os.environ.get("GITHUB_REF") == "refs/heads/" + p["branch"]), None)
    branch = profile["branch"] if profile else BRANCH
    require(os.environ.get("GH_REPO") == REPO and bool(os.environ.get("GH_TOKEN"))
            and os.environ.get("GITHUB_REF") == "refs/heads/" + branch, "Expected repository publication context is missing")
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None and run_id.isdigit() and number.isdigit(), "Invalid source/run identity")
    verify_run(source, run_id, number, profile)
    with tempfile.TemporaryDirectory(prefix="imperathen-village-release-") as work:
        temporary = Path(work)
        android, runtime, public = (temporary / p for p in ("android", "runtime", "public"))
        for name, target in ((f"imperathen-android-{number}", android), (f"imperathen-android-runtime-{number}", runtime)):
            gh("run", "download", run_id, "--repo", REPO, "--name", name, "--dir", str(target))
        proof = verify_and_stage(android, runtime, public, source, run_id, profile)
        print("VILLAGE_DOWNLOAD_PUBLISHED", publish(public, temporary, source, run_id, proof, profile))


if __name__ == "__main__":
    main()
