#!/usr/bin/env python3
"""Build one signed, installable, ISOLATED DEVELOPMENT QA APK.

This is intentionally NOT the original IMPERATHEN release path.
- Android ID is always at.heinz.imperathen.qa (can coexist with original).
- Exact original signer/keystore is never referenced or replaced.
- The strict original release Motion Quality Gate remains mandatory on the
  original package build. An unapproved QA APK is for testing these defects.
- All actual Android SDK signing, resource, ABI and package checks still run.
- APK is only promoted after exact bytes and signature are verified.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from types import SimpleNamespace

from build_android_prototype import (
    REPOSITORY, QA_PACKAGE, PACKAGE, PRESET, BUILD_TOOLS,
    BuildError, preflight, configure_copy, write_isolated_settings,
    run, source_fingerprint, atomic_copy, file_sha256,
)
from android_signing_identity import verify_signing_identity, SigningIdentityError


def build(args: argparse.Namespace) -> Path:
    # Only the isolated QA package is legal. The source Godot preset retains
    # the already installed original's ID and is never mutated by this script.
    source = REPOSITORY / "prototype"
    if args.output.suffix.lower() != ".apk":
        raise BuildError("Unreleased QA output must have the .apk extension.")
    if source.resolve() in args.output.resolve().parents:
        raise BuildError("Output cannot be placed inside the original Godot project.")
    if args.expected_package != QA_PACKAGE or QA_PACKAGE == PACKAGE:
        raise BuildError("Only a distinct, isolated QA package is permitted.")
    toolchain, environment = preflight(SimpleNamespace(
        godot=args.godot, project=source, sdk_root=args.sdk_root,
        java_home=args.java_home, template_dir=args.template_dir,
        keystore=args.keystore, keystore_user=args.keystore_user,
        abi="arm64-v8a", expected_signer_sha256=None))
    if toolchain["package"] != PACKAGE or environment.get("IMPERATHEN_EXPECTED_SIGNER_SHA256"):
        raise BuildError("Original signer pin must not affect an isolated QA test.")
    # Prevent accidental use of a real production signing alias on this branch.
    if args.keystore_user != "imperathen-qa":
        raise BuildError("Only the dedicated test key alias imperathen-qa is accepted.")
    original_preset = (source / "export_presets.cfg").read_bytes()
    baseline = source_fingerprint(source)
    output = args.output.resolve()
    with tempfile.TemporaryDirectory(prefix="imperathen-unreleased-qa-") as name:
        folder = Path(name)
        project = folder / "game"
        shutil.copytree(source,project,ignore=shutil.ignore_patterns(".godot",".git","android","*.tmp","*.bak"))
        if baseline != source_fingerprint(project):
            raise BuildError("Isolated project contains modified or missing source assets.")
        configure_copy(project,toolchain,"compatibility",QA_PACKAGE)
        write_isolated_settings(folder,toolchain,environment)
        export_path = folder / "IMPERATHEN-UNRELEASED-QA.apk"
        # The Godot importer MUST encounter the actual assembled 50MB
        # RomanCity and the independently generated city collision geometry.
        run([toolchain["godot"],"--headless","--path",str(project),"--editor","--import"],
            environment,"Import all real Roman city assets",timeout=args.timeout)
        run([toolchain["godot"],"--headless","--path",str(project),
             "--export-debug",PRESET,str(export_path)],
            environment,"Export separate signed Android ARM64 QA",timeout=args.timeout)
        if not export_path.is_file() or export_path.stat().st_size < 10_000_000:
            raise BuildError("Android QA export returned a missing or implausibly empty APK.")
        validator = REPOSITORY / "tools/validate_android_apk.py"
        verification = folder / "validation.json"
        sdk_tools = Path(toolchain["sdk_root"]) / "build-tools" / BUILD_TOOLS
        run([sys.executable,str(validator),"--apk",str(export_path),
             "--sdk-root",toolchain["sdk_root"],"--source-root",str(source),
             "--expected-package",QA_PACKAGE,"--expected-abi","arm64-v8a",
             "--report",str(verification),
             "--aapt",str(sdk_tools/"aapt"),
             "--apksigner",str(sdk_tools/"apksigner"),
             "--zipalign",str(sdk_tools/"zipalign")],
            environment,"Statically validate APK package, signature, ABI and all resources",
            timeout=args.timeout)
        static = json.loads(verification.read_text(encoding="utf-8"))
        if static.get("overall_status") != "pass":
            raise BuildError("The actual APK validator did not approve the isolated test package.")
        try:
            signing = verify_signing_identity(
                export_path,sdk_tools/"apksigner",
                expected_sha256=None,environment=environment,timeout=args.timeout)
        except SigningIdentityError as exc:
            raise BuildError("Unreleased QA APK signature invalid: "+str(exc)) from exc
        exact_hash = file_sha256(export_path)
        if signing.get("apk_sha256") != exact_hash or static.get("apk",{}).get("sha256") != exact_hash:
            raise BuildError("Signer and static APK report refer to different APK bytes.")
        if source_fingerprint(source) != baseline or (source/"export_presets.cfg").read_bytes() != original_preset:
            raise BuildError("The original game source or package preset was modified.")
        atomic_copy(export_path,output)
        report = {
            "schema_version":1,"status":"SIGNED_UNRELEASED_QA_APK",
            "package":QA_PACKAGE,
            "original_app_package":PACKAGE,
            "changes_original_installed_app":False,
            "update_compatible_with_original_app":False,
            "motion_quality_released":False,
            "known_motion_failures":"Strict Motion Quality Gate remains blocked; see artifacts/quality/motion-gate.json",
            "private_temple_released":False,
            "fold7_20_min_performance_test_completed":False,
            "device_install_test_completed":False,
            "apk":output.name,"apk_size_bytes":output.stat().st_size,
            "apk_sha256":exact_hash,
            "created_utc":datetime.now(timezone.utc).isoformat(),
            "source_commit":environment.get("GITHUB_SHA"),
            "renderer":"gl_compatibility",
            "abi":"arm64-v8a",
            "signature_verified":True,
            "measured_signing_identity":signing,
            "source_snapshot_sha256":baseline,
            "original_preset_unchanged":True,
            "validation_report":output.with_suffix(".validation.json").name,
        }
        atomic_copy(verification,output.with_suffix(".validation.json"))
        with tempfile.NamedTemporaryFile(mode="w",prefix="imperathen-qa-report-",suffix=".json",delete=False) as stream:
            temp_report=Path(stream.name)
            json.dump(report,stream,indent=2,ensure_ascii=False)
        try:
            atomic_copy(temp_report,output.with_suffix(".build.json"))
        finally:
            temp_report.unlink(missing_ok=True)
        output.with_suffix(".apk.sha256").write_text(f"{exact_hash}  {output.name}\n",encoding="utf-8")
    print("IMPERATHEN_UNRELEASED_QA_APK_PASS "+json.dumps({
        "package":QA_PACKAGE,"bytes":output.stat().st_size,"sha256":exact_hash,
        "original_installed_app_modified":False,
        "original_release_motion_gate_passed":False,
    }))
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--sdk-root",type=Path,required=True)
    parser.add_argument("--java-home",type=Path,required=True)
    parser.add_argument("--template-dir",type=Path,required=True)
    parser.add_argument("--keystore",type=Path,required=True)
    parser.add_argument("--keystore-user",default="imperathen-qa")
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--expected-package",default=QA_PACKAGE)
    parser.add_argument("--timeout",type=int,default=900)
    args=parser.parse_args()
    try:
        build(args)
        return 0
    except (BuildError, OSError,ValueError,TimeoutError) as exc:
        print("IMPERATHEN_UNRELEASED_QA_APK_FAIL "+str(exc),file=sys.stderr)
        return 1


if __name__=="__main__":
    raise SystemExit(main())
