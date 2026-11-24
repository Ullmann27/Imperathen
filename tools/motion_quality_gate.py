#!/usr/bin/env python3
"""Fail-closed motion acceptance for the supported Android export path.

A headless animation test cannot establish naturalness, weight or visual
quality on its own. Require measured limits, coverage, source-bound engine
proof and an actual reviewed capture for every active motion family.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MODEL_EXT = {".glb", ".gltf", ".fbx", ".obj", ".dae", ".blend", ".bvh", ".mesh", ".tscn", ".scn", ".tres", ".res"}
SCRIPT_EXT = {".gd", ".gdshader", ".gdshaderinc"}
RIG_LIMITS = {
    "max_segment_error_m": .005,
    "max_linear_speed_m_s": 12.0,
    "max_angular_speed_deg_s": 2400.0,
    "max_loop_seam_m": .03,
    "max_loop_seam_deg": 12.0,
    "frozen_required_clips": 0,
}
# Engineering acceptance bounds, not claims of universal biological constants.
# Contact errors are measured on actual support surfaces, not inferred from
# an animation name. Every metric is a worst-case value, never a mean.
FAMILY_LIMITS = {
    "human": {"max_support_slip_m": .015, "max_sole_penetration_m": .01,
              "max_transition_position_jump_m": .06, "max_transition_rotation_jump_deg": 20,
              "skin_edge_violations": 0},
    "human_world": {"max_root_step_m": .12, "max_collision_overlap_m": .01,
                    "max_support_slip_m": .015, "max_transition_position_jump_m": .06,
                    "max_transition_rotation_jump_deg": 20},
    "animal": {"max_segment_error_m": .005, "max_hoof_paw_slip_m": .02,
               "max_hoof_paw_penetration_m": .01, "max_transition_position_jump_m": .06,
               "max_transition_rotation_jump_deg": 20, "skin_edge_violations": 0},
    "rider": {"max_seat_drift_m": .025, "max_rein_grip_drift_m": .02,
              "max_stirrup_or_leg_anchor_drift_m": .025, "max_gait_phase_error_cycles": .08,
              "max_collision_overlap_m": .01, "max_transition_position_jump_m": .06},
    "attached": {"max_socket_drift_m": .002, "max_socket_orientation_error_deg": 2.0,
                 "max_unintended_penetration_m": .01, "max_transition_position_jump_m": .06},
    "crowd": {"max_visible_contact_slip_m": .04, "max_lod_pose_jump_m": .04,
              "max_root_step_m": .12, "max_transition_rotation_jump_deg": 20},
    "wheeled": {"max_rolling_distance_error_ratio": .03, "max_ground_slip_m": .015,
                "max_ground_penetration_m": .01, "max_axle_separation_m": .005,
                "max_root_step_m": .12, "max_uncommanded_speed_jump_m_s": .2},
    "articulated": {"max_joint_anchor_error_m": .005, "max_joint_limit_error_deg": 1.0,
                    "max_unintended_penetration_m": .01, "max_operator_grip_drift_m": .02,
                    "max_uncommanded_speed_jump_m_s": .2},
}
RIG_PROFILES = {"human", "animal"}
REQUIRED_ACTIVE = {"hero", "frontier_people", "legacy_people", "meshy_people", "battle_rigs",
                   "distant_ranks", "regional_workers", "service_gear", "meshy_gear",
                   "village_navigation", "raid_motion", "cinematic_people"}
REQUIRED_PLANNED = {"horse_and_other_animals": "animal", "mounted_units": "rider",
                    "rolling_machines": "wheeled", "articulated_equipment": "articulated"}
SUPPORT = {"assets/animations/hero_cc0_library.tres", "main.tscn",
           *(f"assets/characters/hero_hand_grip_{i}.res" for i in range(4))}
HASH_RE = re.compile(r"^[0-9a-f]{64}$")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def json_read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def excluded(relative: Path) -> bool:
    return (any(p in {".godot", ".git", "android", "__pycache__"} for p in relative.parts)
            or relative.as_posix().startswith("assets/meshy/source/"))


def inventory(project: Path) -> tuple[set[str], set[str]]:
    models, scripts = set(), set()
    for path in project.rglob("*"):
        rel = path.relative_to(project)
        if not path.is_file() or excluded(rel) or rel.parts[0] == "tests":
            continue
        if path.suffix.lower() in MODEL_EXT:
            models.add(rel.as_posix())
        if path.suffix.lower() in SCRIPT_EXT:
            scripts.add(rel.as_posix())
    return models, scripts


def source_commit(root: Path) -> str:
    value = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("Missing exact source revision")
    return value


def source_fingerprint(root: Path) -> str:
    """Bind evidence to actual project bytes, including textures and tests.

    Ignore only generated editor cache/UID files and unexported source staging.
    Tracked import settings are deliberately included.
    Review records are separate, so approving evidence does not change the
    production fingerprint. New untracked files are not silently ignored.
    """
    paths = []
    project = root / "prototype"
    for path in project.rglob("*"):
        rel = path.relative_to(project)
        if path.is_file() and not excluded(rel) and path.suffix not in {".uid", ".tmp", ".bak"}:
            paths.append(path)
    for name in ("quality/motion_contract.json", "tools/motion_quality_gate.py",
                 "tools/check_prototype.py", "tools/build_android_prototype.py",
                 "tools/publish_village_download.py", ".github/workflows/android-prototype.yml"):
        paths.append(root / name)
    h = hashlib.sha256()
    for path in sorted(paths):
        if not path.is_file() or path.is_symlink():
            raise ValueError("Unverifiable source file: " + str(path))
        h.update(path.relative_to(root).as_posix().encode() + b"\0")
        h.update(bytes.fromhex(digest(path)))
    return h.hexdigest()


def metric_errors(values: dict, limits: dict, label: str) -> list[str]:
    errors = []
    for key, limit in limits.items():
        v = values.get(key)
        if type(v) not in (int, float) or not math.isfinite(v) or v < 0:
            errors.append(f"{label}: missing/non-finite/non-positive-domain metric {key}")
        elif v > limit + 1e-9:
            errors.append(f"{label}: {key}={v:.6g} exceeds {limit:.6g}")
    return errors


def safe_relative(name: str) -> bool:
    return (isinstance(name, str) and bool(name) and "\\" not in name
            and not PurePosixPath(name).is_absolute()
            and ".." not in PurePosixPath(name).parts)


def inspect_static_glb(path: Path) -> bool:
    with path.open("rb") as f:
        header = f.read(20)
        if len(header) != 20:
            return False
        magic, version, length, chunk, kind = struct.unpack("<4sIIII", header)
        if magic != b"glTF" or version != 2 or length != path.stat().st_size or kind != 0x4E4F534A:
            return False
        if chunk > min(length - 20, 32 * 1024 * 1024):
            return False
        doc = json.loads(f.read(chunk))
    return not doc.get("animations") and not doc.get("skins")


def validate_inventory(root: Path, contract: dict) -> tuple[dict, list[str]]:
    failures = []
    project = root / "prototype"
    models, scripts = inventory(project)
    families = {}
    registered = {}
    if contract.get("schema_version") != 1 or contract.get("sample_hz") != 60:
        failures.append("Invalid contract schema or sampling frequency")
    for family in contract.get("families", []):
        key = family.get("id")
        status, profile = family.get("status"), family.get("profile")
        if not isinstance(key, str) or not key or key in families:
            failures.append("Missing/duplicate movement family")
            continue
        families[key] = family
        if status not in {"active", "inactive", "static", "support"}:
            failures.append(f"{key}: unknown status")
        if status in {"active", "inactive"} and profile not in FAMILY_LIMITS:
            failures.append(f"{key}: missing motion profile")
        if status == "active" and (not family.get("required_checks") or not family.get("review_scope")):
            failures.append(f"{key}: active motion requires tests and visual scenarios")
        if status == "inactive" and family.get("resources"):
            failures.append(f"{key}: inactive movement cannot ship a runtime model")
        for path in family.get("resources", []):
            if not safe_relative(path) or path in registered:
                failures.append(f"{key}: invalid/duplicate resource {path}")
                continue
            registered[path] = key
            if status == "static" and path in models:
                try:
                    if not path.endswith(".glb") or not inspect_static_glb(project / path):
                        failures.append(f"{path}: animated or unknown resource cannot be declared static")
                except (OSError, ValueError, struct.error) as e:
                    failures.append(f"{path}: static inspection failed: {e}")
            if status == "support" and path not in SUPPORT:
                failures.append(f"{path}: new support resource needs an explicit motion classification")
    for key in sorted(REQUIRED_ACTIVE):
        if families.get(key, {}).get("status") != "active":
            failures.append(f"{key}: existing live movement family was removed/disabled without a new contract review")
    for key, profile in REQUIRED_PLANNED.items():
        if families.get(key, {}).get("profile") != profile:
            failures.append(f"{key}: mandatory future motion profile is absent")
    for path in sorted(models - set(registered)):
        failures.append("Unclassified runtime 3D resource: " + path)
    for path in sorted(set(registered) - models):
        failures.append("Registered runtime resource missing: " + path)
    listed_scripts = contract.get("runtime_scripts", [])
    if len(listed_scripts) != len(set(listed_scripts)):
        failures.append("Duplicate executable source registration")
    for path in sorted(scripts - set(listed_scripts)):
        failures.append("Unclassified runtime script: " + path)
    for path in sorted(set(listed_scripts) - scripts):
        failures.append("Registered runtime script missing: " + path)
    for path, owners in contract.get("procedural_owners", {}).items():
        if path not in scripts or not owners or any(owner not in families for owner in owners):
            failures.append("Invalid procedural motion owner: " + path)
    # Staged Meshy source geometry must never slip into any export preset.
    presets = (project / "export_presets.cfg").read_text(encoding="utf-8")
    filters = re.findall(r'^exclude_filter="([^"]*)"', presets, re.M)
    if not filters or any("assets/meshy/source/*" not in f.split(",") for f in filters):
        failures.append("One or more export presets fail to quarantine raw Meshy sources")
    loadouts = json_read(project / "assets/meshy/loadouts.json")
    if any(x.get("runtime_enabled") is True and x.get("mount") for x in loadouts["loadouts"]):
        if any(families.get(x, {}).get("status") != "active" for x in ("horse_and_other_animals", "mounted_units")):
            failures.append("Mounted loadout enabled before animal and rider contracts")
    return families, failures


def review_errors(root: Path, family: dict, reviews: list, fingerprint: str) -> list[str]:
    key = family["id"]
    records = [x for x in reviews if x.get("family") == key]
    if len(records) != 1:
        return [f"{key}: exact-source visual review missing or duplicated"]
    review = records[0]
    errors = []
    if (review.get("status") != "approved" or review.get("source_fingerprint") != fingerprint
            or not isinstance(review.get("reviewer"), str) or not review["reviewer"].strip()):
        errors.append(f"{key}: visual review is not approved for these actual bytes")
    if set(review.get("scenarios", [])) != set(family.get("review_scope", [])):
        errors.append(f"{key}: visual review does not cover every required scenario")
    captures = review.get("captures", [])
    covered = set()
    for capture in captures:
        name = capture.get("path", "")
        if not safe_relative(name) or not name.startswith("docs/") or Path(name).suffix.lower() not in {".mp4", ".webm", ".gif"}:
            errors.append(f"{key}: missing valid visual capture path")
            continue
        path = root / name
        if (not path.is_file() or path.is_symlink() or path.stat().st_size <= 1024
                or not HASH_RE.fullmatch(str(capture.get("sha256", ""))) or digest(path) != capture["sha256"]):
            errors.append(f"{key}: capture bytes do not match reviewed evidence: {name}")
            continue
        covered.update(capture.get("scenarios", []))
    if not set(family["review_scope"]) <= covered:
        errors.append(f"{key}: reviewed captures do not cover all scenarios")
    return errors


def evaluate(root: Path, evidence: Path) -> dict:
    contract = json_read(root / "quality/motion_contract.json")
    families, failures = validate_inventory(root, contract)
    fingerprint = source_fingerprint(root)
    commit = source_commit(root)
    engine_path, measured_path = evidence / "validation_report.json", evidence / "motion-measurements.json"
    engine = json_read(engine_path) if engine_path.is_file() else {}
    measured = json_read(measured_path) if measured_path.is_file() else {}
    if engine.get("passed") is not True or engine.get("motion_source_fingerprint") != fingerprint or engine.get("source_commit") != commit:
        failures.append("Engine evidence is missing, failed or belongs to different source bytes/revision")
    if (measured.get("source_fingerprint") != fingerprint or measured.get("sample_hz") != 60
            or measured.get("schema_version") != 1):
        failures.append("Motion measurement evidence missing or stale")
    checks = {x.get("check"): x for x in engine.get("checks", [])}
    if len(checks) != len(engine.get("checks", [])):
        failures.append("Duplicate engine evidence identifiers")
    if checks.get("motion_measurement", {}).get("passed") is not True:
        failures.append("Actual Godot movement measurement did not complete")
    assets = measured.get("assets", {})
    family_metrics = measured.get("family_metrics", {})
    reviews = json_read(root / "quality/motion_reviews.json").get("reviews", [])
    results = []
    for key, family in families.items():
        status = family.get("status")
        errors = []
        if status in {"active", "support"}:
            for name in family.get("required_checks", []):
                if checks.get(name, {}).get("passed") is not True:
                    errors.append(f"{key}: required engine scenario not passed: {name}")
        if status == "active":
            profile = family["profile"]
            if profile in RIG_PROFILES:
                for path in family["resources"]:
                    if not path.endswith(".glb"):
                        errors.append(f"{key}: skeletal resource requires actual GLB motion measurement: {path}")
                        continue
                    record = assets.get(path, {})
                    if record.get("finite") is not True or type(record.get("sample_count")) is not int or record["sample_count"] < 60 or not record.get("clips"):
                        errors.append(f"{path}: missing/invalid actual skeletal sampling")
                    else:
                        errors.extend(metric_errors(record.get("metrics", {}), RIG_LIMITS, path))
                        if record.get("errors"):
                            errors.extend(f"{path}: {x}" for x in record["errors"])
            observed = family_metrics.get(key, {})
            subjects = set(family["resources"]) or {"family:" + key}
            if (set(observed.get("subjects", [])) != subjects or observed.get("sample_hz") != 60
                    or type(observed.get("sample_count")) is not int or observed["sample_count"] < 60
                    or not set(family["review_scope"]) <= set(observed.get("scenarios", []))):
                errors.append(f"{key}: incomplete measured subjects, frames or required motion scenarios")
            errors.extend(metric_errors(observed.get("metrics", {}), FAMILY_LIMITS[profile], key))
            for reason in family.get("open_requirements", []):
                errors.append(f"{key}: unresolved: {reason}")
            errors.extend(review_errors(root, family, reviews, fingerprint))
        failures.extend(errors)
        results.append({"id": key, "profile": family["profile"], "status": status,
                        "passed": not errors, "failures": errors})
    models, scripts = inventory(root / "prototype")
    return {"schema_version": 1, "passed": not failures, "source_commit": commit,
            "source_fingerprint": fingerprint, "sample_hz": 60, "resource_count": len(models),
            "script_count": len(scripts), "measured_assets": len(assets),
            "engine_report_sha256": digest(engine_path) if engine_path.is_file() else None,
            "measurement_report_sha256": digest(measured_path) if measured_path.is_file() else None,
            "rig_limits": RIG_LIMITS, "family_limits": FAMILY_LIMITS,
            "families": results, "failures": failures}


def require_export(root: Path, evidence: Path) -> dict:
    proof_path = evidence / "motion-gate.json"
    if not proof_path.is_file():
        raise ValueError("Motion Quality Gate proof is missing; APK export refused")
    previous = json_read(proof_path)
    current = evaluate(root, evidence)
    if previous != current or current.get("passed") is not True:
        raise ValueError("Motion Quality Gate did not pass for these source bytes; APK export refused")
    return current


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--evidence", type=Path, required=True)
    a = p.parse_args()
    a.evidence.mkdir(parents=True, exist_ok=True)
    try:
        report = evaluate(ROOT, a.evidence)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report = {"schema_version": 1, "passed": False, "failures": [str(error)]}
    (a.evidence / "motion-gate.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for failure in report["failures"]:
        print("MOTION_GATE_BLOCKER", failure)
    print("MOTION_QUALITY_GATE_PASS" if report["passed"] else "MOTION_QUALITY_GATE_BLOCKED",
          "blockers=", len(report["failures"]), "measured_assets=", report.get("measured_assets", 0))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
