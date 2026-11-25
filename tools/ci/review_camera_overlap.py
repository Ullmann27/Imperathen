#!/usr/bin/env python3
"""Compare one external camera test against exact baseline and head sources.

Actual graphical screenshots document controlled test geometry. This runner
does not claim a player walkthrough, Android performance or visual approval.
The baseline must reproduce only the designated overlap regression failures.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)
RESULT = re.compile(r"^CAMERA_COLLISION_RESULT checks=(\d+) failures=(\d+)\s*$", re.MULTILINE)
CAPTURES = ("cold-start.jpg", "sealed-volume.jpg", "recovered.jpg")
INLINE_LIMIT = 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root: Path, *arguments: str) -> str:
    return subprocess.check_output(
        ["git", *arguments], cwd=root, text=True, encoding="utf-8", errors="replace",
    ).strip()


def run_logged(command: list[str], root: Path, environment: dict[str, str],
               log: Path, timeout: int) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(
            command, cwd=root, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
            timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        log.write_text(output + f"\nTIMEOUT after {timeout} seconds\n", encoding="utf-8")
        raise RuntimeError(f"{log.name}: timed out after {timeout} seconds") from error
    log.write_text(result.stdout, encoding="utf-8")
    return result


def load_gate(root: Path, label: str):
    path = root / "tools/motion_quality_gate.py"
    specification = importlib.util.spec_from_file_location("camera_review_motion_gate_" + label, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"Cannot load source fingerprint implementation: {path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def snapshot(label: str, root: Path, expected_sha: str, harness: Path,
             godot: str, output: Path) -> dict:
    destination = output / label
    destination.mkdir(parents=True, exist_ok=False)
    record = {
        "label": label, "expected_source_commit": expected_sha,
        "expectation_met": False, "captures": [],
    }
    try:
        actual_sha = git(root, "rev-parse", "HEAD")
        record["source_commit"] = actual_sha
        if actual_sha != expected_sha:
            raise RuntimeError("Checkout differs from the requested exact source commit")
        changed = git(root, "diff", "--name-only", "HEAD")
        if changed:
            raise RuntimeError("Tracked source was already modified before import: " + changed)

        with tempfile.TemporaryDirectory(prefix="imperathen-camera-" + label + "-") as temporary:
            environment = os.environ.copy()
            environment["IMPERATHEN_ISOLATED_TEST"] = "1"
            environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
            environment["LIBGL_ALWAYS_SOFTWARE"] = "1"
            environment["IMPERATHEN_CAMERA_REVIEW_OUTPUT"] = str(destination)
            environment["IMPERATHEN_CAMERA_REVIEW_LABEL"] = (
                ("VORHER" if label == "before" else "NACHHER") + " " + actual_sha[:12]
            )
            for kind in ("DATA", "CONFIG", "CACHE"):
                location = Path(temporary) / kind.lower()
                location.mkdir()
                environment[f"XDG_{kind}_HOME"] = str(location)

            imported = run_logged(
                [godot, "--headless", "--path", str(root / "prototype"), "--import"],
                root, environment, destination / "import.log", 300,
            )
            record["import_exit_code"] = imported.returncode
            if imported.returncode != 0 or FAILURE.search(imported.stdout):
                raise RuntimeError("Godot import failed; inspect import.log")

            gate = load_gate(root, label)
            before = gate.source_fingerprint(root)
            record["source_fingerprint"] = before
            record["import_modified_tracked_paths"] = git(root, "diff", "--name-only", "HEAD").splitlines()
            record["source_commit_role"] = (
                "imported_worktree" if record["import_modified_tracked_paths"] else "clean_checkout"
            )
            record["external_harness_sha256"] = sha256(harness)
            record["production_camera_sha256"] = {
                path: sha256(root / path)
                for path in ("prototype/scripts/world/camera_obstruction.gd",
                             "prototype/scripts/world/game_world.gd")
            }

            result = run_logged(
                [
                    godot, "--display-driver", "x11", "--rendering-method", "gl_compatibility",
                    "--audio-driver", "Dummy", "--path", str(root / "prototype"),
                    "--resolution", "960x540", "--fixed-fps", "60",
                    "--script", str(harness),
                ],
                root, environment, destination / "runtime.log", 300,
            )
            record["engine_exit_code"] = result.returncode
            record["source_fingerprint_after"] = gate.source_fingerprint(root)
            record["source_unchanged_during_run"] = (
                before == record["source_fingerprint_after"]
                and git(root, "rev-parse", "HEAD") == actual_sha
                and sha256(harness) == record["external_harness_sha256"]
            )
            if not record["source_unchanged_during_run"]:
                raise RuntimeError("Source revision, project bytes or external harness changed")
            if FAILURE.search(result.stdout):
                raise RuntimeError("Godot logged a script, parse or engine error")

            summaries = RESULT.findall(result.stdout)
            if len(summaries) != 1:
                raise RuntimeError("Missing or duplicated camera test result summary")
            check_count, failure_count = map(int, summaries[0])
            failure_lines = [
                line.strip() for line in result.stdout.splitlines()
                if line.strip().startswith("FAIL:")
            ]
            record["test_count"] = check_count
            record["failure_count"] = failure_count
            record["failure_lines"] = failure_lines
            record["actual_regression_passed"] = result.returncode == 0 and failure_count == 0
            if check_count <= 0 or failure_count != len(failure_lines):
                raise RuntimeError("Camera result count differs from actual failure records")

            if label == "before":
                expectation_met = (
                    result.returncode == 1 and failure_count > 0
                    and re.search(r"^CAMERA_COLLISION_FAIL\s*$", result.stdout, re.MULTILINE) is not None
                    and any(line.startswith("FAIL: CAMERA_OVERLAP_COLD_START") for line in failure_lines)
                    and all(line.startswith("FAIL: CAMERA_OVERLAP_") for line in failure_lines)
                )
            else:
                expectation_met = (
                    result.returncode == 0 and failure_count == 0
                    and re.search(r"^CAMERA_COLLISION_PASS\s*$", result.stdout, re.MULTILINE) is not None
                )

            for name in CAPTURES:
                path = destination / name
                if not path.is_file():
                    raise RuntimeError("Expected actual camera screenshot is missing: " + name)
                data = path.read_bytes()
                if len(data) <= 128 or not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
                    raise RuntimeError("Camera screenshot is not a complete JPEG: " + name)
                record["captures"].append({
                    "path": str(path.relative_to(output)), "sha256": hashlib.sha256(data).hexdigest(),
                    "bytes": len(data), "inline_emitted": False,
                })
            record["expectation_met"] = bool(expectation_met)
            if not expectation_met:
                record["error"] = (
                    "Baseline did not reproduce only the designated overlap failures"
                    if label == "before" else "Changed source did not pass the camera regression"
                )
    except Exception as error:
        record["expectation_met"] = False
        record["error"] = str(error)
        for name in ("import.log", "runtime.log"):
            path = destination / name
            if path.is_file():
                print(f"CAMERA_REVIEW_DIAGNOSTIC {label} {name}\n"
                      + path.read_text(encoding="utf-8")[-8000:], flush=True)

    (destination / "review.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8",
    )
    print("CAMERA_REVIEW_RESULT", label, json.dumps({
        "source_commit": record.get("source_commit"), "test_count": record.get("test_count"),
        "failure_count": record.get("failure_count"),
        "actual_regression_passed": record.get("actual_regression_passed"),
        "expectation_met": record["expectation_met"], "error": record.get("error"),
    }, ensure_ascii=False), flush=True)
    for line in record.get("failure_lines", []):
        print(label + ": " + line, flush=True)
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--head", type=Path, required=True)
    parser.add_argument("--baseline-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    for value in (args.baseline_sha, args.head_sha):
        if re.fullmatch(r"[0-9a-f]{40}", value) is None:
            parser.error("Both source revisions must be exact 40-character commit SHAs")
    if not os.environ.get("DISPLAY"):
        parser.error("An actual graphical DISPLAY is required; run through xvfb-run")
    baseline, head, output = args.baseline.resolve(), args.head.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    harness = head / "prototype/tests/camera_collision_test.gd"
    if not harness.is_file():
        parser.error("The exact head camera_collision_test.gd harness is missing")
    initial_harness_hash = sha256(harness)
    report = {
        "schema_version": 1,
        "scope": "Identical external camera test against baseline and changed production sources",
        "visual_scope": "Actual Godot screenshots of controlled TEST GEOMETRY",
        "android_device_test": False, "measured_fps": False, "motion_quality_approval": False,
        "external_harness_sha256": initial_harness_hash, "records": [], "passed": False,
    }
    for label, root, expected in (
        ("before", baseline, args.baseline_sha), ("after", head, args.head_sha),
    ):
        report["records"].append(snapshot(label, root, expected, harness, args.godot, output))
    before, after = report["records"]
    report["same_test_count"] = (
        isinstance(before.get("test_count"), int) and before["test_count"] == after.get("test_count")
    )
    report["external_harness_unchanged"] = sha256(harness) == initial_harness_hash
    report["passed"] = (
        all(record.get("expectation_met") is True for record in report["records"])
        and report["same_test_count"] and report["external_harness_unchanged"]
    )
    emitted_bytes = 0
    for record in report["records"]:
        for capture in record["captures"]:
            path = output / capture["path"]
            encoded = base64.b64encode(path.read_bytes()).decode("ascii")
            line = f"CAMERA_REVIEW_JPEG {record['label']} {path.name} {encoded}"
            size = len(line.encode("utf-8")) + 1
            if emitted_bytes + size <= INLINE_LIMIT:
                print(line, flush=True)
                emitted_bytes += size
                capture["inline_emitted"] = True
            else:
                capture["inline_omission"] = "Aggregate inline JPEG limit; original retained in artifact"
        (output / record["label"] / "review.json").write_text(
            json.dumps(record, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8",
        )
    report["inline_payload_bytes"] = emitted_bytes
    report["inline_payload_limit_bytes"] = INLINE_LIMIT
    (output / "comparison.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8",
    )
    print("CAMERA_COMPARISON_PASS" if report["passed"] else "CAMERA_COMPARISON_FAIL", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
