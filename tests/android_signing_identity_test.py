"""Regression checks for APK signer evidence; no private keys or network access."""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import android_signing_identity as IDENTITY
import build_android_prototype as BUILDER

SPEC = importlib.util.spec_from_file_location("signing_village_publisher", ROOT / "tools/publish_village_download.py")
PUBLISHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUBLISHER)

CERT_A = "ab" * 32
CERT_B = "cd" * 32


def verifier_output(*certificates: str) -> str:
    return ("Verifies\nVerified using v1 scheme (JAR signing): false\n"
            "Verified using v2 scheme (APK Signature Scheme v2): true\n"
            f"Number of signers: {len(certificates)}\n"
            + "".join(f"Signer #{index} certificate SHA-256 digest: {value}\n"
                      for index, value in enumerate(certificates, 1)))


def completed(output: str, *, code: int = 0, stderr: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(["apksigner", "verify"], code, output, stderr)


class VerifierIdentityTest(unittest.TestCase):
    def test_normalizes_only_valid_sha256_encodings(self):
        colon = ":".join(["AB"] * 32)
        self.assertEqual(IDENTITY.normalize_certificate_sha256(colon), CERT_A)
        self.assertEqual(IDENTITY.normalize_certificate_sha256("  " + CERT_A.upper() + "  "), CERT_A)
        for value in ("", "a" * 63, "a" * 65, "g" * 64, "ab:" * 32, "a:b" * 32, None, 123):
            with self.subTest(value=value), self.assertRaises(IDENTITY.SigningIdentityError):
                IDENTITY.normalize_certificate_sha256(value)

    def test_cli_cannot_override_different_environment_pin(self):
        self.assertIsNone(IDENTITY.expected_certificate(None, ""))
        self.assertEqual(IDENTITY.expected_certificate(CERT_A.upper(), CERT_A), CERT_A)
        with self.assertRaisesRegex(IDENTITY.SigningIdentityError, "different expected"):
            IDENTITY.expected_certificate(CERT_A, CERT_B)

    def test_reads_certificate_not_source_stamp_or_public_key(self):
        output = (verifier_output(CERT_A)
                  + f"Signer #1 public key SHA-256 digest: {CERT_B}\n"
                  + f"Source Stamp Signer certificate SHA-256 digest: {CERT_B}\n")
        self.assertEqual(IDENTITY.verified_certificates(output, "", 0), [CERT_A])

    def test_complete_multi_signer_set_is_preserved(self):
        self.assertEqual(IDENTITY.verified_certificates(verifier_output(CERT_B, CERT_A), "", 0),
                         [CERT_A, CERT_B])

    def test_zero_exit_does_not_substitute_for_real_verification(self):
        valid = verifier_output(CERT_A)
        cases = (valid.replace("Verifies\n", ""), valid.replace(": true", ": false"),
                 valid.replace("Number of signers: 1", "Number of signers: 2"),
                 valid.replace("Number of signers: 1", "Number of signers: 0"),
                 valid.replace(f"Signer #1 certificate SHA-256 digest: {CERT_A}\n", ""),
                 valid.replace("Signer #1", "Signer #2"),
                 valid + f"Signer #1 certificate SHA-256 digest: {CERT_B}\n",
                 valid.replace(CERT_A, "ab"),
                 verifier_output(CERT_A, CERT_A),
                 valid + "Number of signers: 1\n")
        for output in cases:
            with self.subTest(output=output), self.assertRaises(IDENTITY.SigningIdentityError):
                IDENTITY.verified_certificates(output, "", 0)

    def test_errors_and_nonzero_exit_never_pass(self):
        for code, stderr in ((1, ""), (0, "DOES NOT VERIFY"), (0, "ERROR: signature rejected")):
            with self.subTest(code=code, stderr=stderr), self.assertRaises(IDENTITY.SigningIdentityError):
                IDENTITY.verified_certificates(verifier_output(CERT_A), stderr, code)

    def test_rotation_output_requires_explicit_lineage_review(self):
        output = verifier_output(CERT_A) + f"Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: {CERT_B}\n"
        with self.assertRaisesRegex(IDENTITY.SigningIdentityError, "lineage"):
            IDENTITY.verified_certificates(output, "", 0)


class SigningIdentityFileTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="imperathen-signing-test-")
        self.addCleanup(self.work.cleanup)
        self.apk = Path(self.work.name) / "fixture.apk"
        self.apk.write_bytes(b"synthetic test bytes; not a real APK")

    def verify(self, output: str | None = None, expected: str | None = None):
        with mock.patch.object(IDENTITY.subprocess, "run", return_value=completed(output or verifier_output(CERT_A))) as run:
            result = IDENTITY.verify_signing_identity(self.apk, Path("/sdk/apksigner"), expected_sha256=expected)
        self.assertEqual(run.call_args.args[0], ["/sdk/apksigner", "verify", "--verbose", "--print-certs", str(self.apk)])
        return result

    def test_no_pin_records_identity_without_compatibility_claim(self):
        evidence = self.verify()
        self.assertEqual(evidence["apk_sha256"], hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(evidence["signer_certificates_sha256"], [CERT_A])
        self.assertEqual(evidence["comparison"], "not_checked")
        self.assertIsNone(evidence["expected_certificate_sha256"])

    def test_verification_supports_python_without_hashlib_file_digest(self):
        # Python 3.10 does not expose file_digest. Keep the documented build
        # runtime supported even when the test host itself has a newer Python.
        original = getattr(hashlib, "file_digest", None)
        if original is not None:
            delattr(hashlib, "file_digest")
        try:
            evidence = self.verify()
        finally:
            if original is not None:
                setattr(hashlib, "file_digest", original)
        self.assertEqual(evidence["apk_sha256"], hashlib.sha256(self.apk.read_bytes()).hexdigest())

    def test_pin_compares_certificate_identity(self):
        evidence = self.verify(expected=CERT_A.upper())
        self.assertEqual(evidence["comparison"], "matched_expected_certificate")
        self.assertEqual(evidence["expected_certificate_sha256"], CERT_A)

    def test_known_mismatch_and_extra_signer_are_rejected(self):
        for output in (verifier_output(CERT_B), verifier_output(CERT_A, CERT_B)):
            with self.subTest(output=output), self.assertRaisesRegex(IDENTITY.SigningIdentityError, "differs"):
                self.verify(output, CERT_A)

    def test_apk_mutation_invalidates_identity_proof(self):
        def mutate(*args, **kwargs):
            self.apk.write_bytes(b"different package bytes")
            return completed(verifier_output(CERT_A))
        with mock.patch.object(IDENTITY.subprocess, "run", side_effect=mutate), \
                self.assertRaisesRegex(IDENTITY.SigningIdentityError, "bytes changed"):
            IDENTITY.verify_signing_identity(self.apk, Path("/sdk/apksigner"))

    def test_missing_or_timed_out_verifier_never_creates_proof(self):
        for error in (OSError("missing"), subprocess.TimeoutExpired("apksigner", 1)):
            with self.subTest(error=error), mock.patch.object(IDENTITY.subprocess, "run", side_effect=error), \
                    self.assertRaisesRegex(IDENTITY.SigningIdentityError, "could not complete"):
                IDENTITY.verify_signing_identity(self.apk, Path("/sdk/apksigner"))

    def test_empty_and_symlink_apks_are_rejected_before_tool_invocation(self):
        self.apk.write_bytes(b"")
        link = self.apk.parent / "link.apk"
        link.symlink_to(self.apk)
        for apk in (self.apk, link, self.apk.parent / "missing.apk"):
            with self.subTest(apk=apk), mock.patch.object(IDENTITY.subprocess, "run") as run, \
                    self.assertRaises(IDENTITY.SigningIdentityError):
                IDENTITY.verify_signing_identity(apk, Path("/sdk/apksigner"))
            run.assert_not_called()


class BuildPromotionSigningTest(unittest.TestCase):
    def run_build(self, directory: Path, actual_certificate: str, expected: str | None):
        project = directory / "project"
        project.mkdir()
        (project / "project.godot").write_text("synthetic test project")
        output = directory / "out" / "candidate.apk"
        output.parent.mkdir()
        output.write_bytes(b"previous successful APK")
        previous_proof = output.with_suffix(".build.json")
        previous_proof.write_text('{"source_commit":"previous","apk_sha256":"old"}')
        args = argparse.Namespace(output=output, abi="arm64-v8a", renderer="compatibility", timeout=5)
        toolchain = {"project": str(project), "sdk_root": str(directory / "sdk"), "validator": "validator.py",
                     "godot": "godot", "godot_version": "test-fixture", "abi": "arm64-v8a",
                     "package": "at.heinz.imperathen", "expected_signer_sha256": expected}

        def run(command, environment, label, **kwargs):
            if "--export-debug" in command:
                Path(command[-1]).write_bytes(b"new export fixture")
            elif command[1] == "validator.py":
                apk = Path(command[command.index("--apk") + 1])
                report = Path(command[command.index("--report") + 1])
                report.write_text(json.dumps({"overall_status": "pass", "apk": {"sha256": BUILDER.file_sha256(apk)}}))
            return ""

        with mock.patch.object(BUILDER, "configure_copy"), mock.patch.object(BUILDER, "write_isolated_settings"), \
                mock.patch.object(BUILDER, "run", side_effect=run), \
                mock.patch.object(IDENTITY.subprocess, "run", return_value=completed(verifier_output(actual_certificate))):
            return BUILDER.build(args, toolchain, {"GITHUB_SHA": "a" * 40})

    def test_mismatch_preserves_previous_artifact_and_does_not_emit_success(self):
        with tempfile.TemporaryDirectory(prefix="imperathen-promotion-test-") as work:
            directory = Path(work)
            with mock.patch("builtins.print") as printed, self.assertRaisesRegex(BUILDER.BuildError, "differs"):
                self.run_build(directory, CERT_B, CERT_A)
            output = directory / "out/candidate.apk"
            self.assertEqual(output.read_bytes(), b"previous successful APK")
            self.assertEqual(json.loads(output.with_suffix(".build.json").read_text())["source_commit"], "previous")
            self.assertFalse(output.with_suffix(".validation.json").exists())
            self.assertFalse(any("ANDROID_BUILD_PASS" in str(call) for call in printed.call_args_list))

    def test_success_promotes_measured_identity_for_exact_export(self):
        with tempfile.TemporaryDirectory(prefix="imperathen-promotion-test-") as work:
            with mock.patch("builtins.print") as printed:
                output = self.run_build(Path(work), CERT_A, CERT_A)
            proof = json.loads(output.with_suffix(".build.json").read_text())
            self.assertEqual(output.read_bytes(), b"new export fixture")
            self.assertEqual(proof["signing_identity"]["apk_sha256"], BUILDER.file_sha256(output))
            self.assertEqual(proof["signing_identity"]["comparison"], "matched_expected_certificate")
            self.assertEqual(proof["device_test"], "not_run_by_build_tool")
            self.assertTrue(any("ANDROID_BUILD_PASS" in str(call) for call in printed.call_args_list))


def build_proof(certificate=CERT_A, expected=None, *, apk_hash="1" * 64):
    return {"apk_sha256": apk_hash, "expected_signer_sha256": expected,
            "signing_identity": {"schema_version": 1, "status": "verified", "apk_sha256": apk_hash,
                                 "signer_certificates_sha256": [certificate],
                                 "expected_certificate_sha256": expected,
                                 "comparison": "matched_expected_certificate" if expected else "not_checked"}}


class PublicationSigningTest(unittest.TestCase):
    def test_matching_signers_are_bound_to_each_abi_package(self):
        arm64 = build_proof()
        emulator = build_proof(apk_hash="2" * 64)
        self.assertEqual(PUBLISHER.verify_signing_pair(arm64, emulator), arm64["signing_identity"])

    def test_legacy_evidence_is_not_retroactively_certified(self):
        with self.assertRaisesRegex(RuntimeError, "missing"):
            PUBLISHER.verify_signing_pair({"apk_sha256": "1" * 64}, build_proof())

    def test_different_abi_signers_are_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "different signing certificates"):
            PUBLISHER.verify_signing_pair(build_proof(), build_proof(CERT_B))

    def test_forged_comparisons_and_wrong_package_proofs_are_rejected(self):
        baseline = build_proof()
        changes = ({"apk_sha256": "9" * 64}, {"status": "not_run"}, {"schema_version": True},
                   {"signer_certificates_sha256": []}, {"signer_certificates_sha256": [CERT_A, CERT_A]},
                   {"signer_certificates_sha256": ["bad"]}, {"comparison": "matched_expected_certificate"},
                   {"expected_certificate_sha256": CERT_B, "comparison": "matched_expected_certificate"})
        for change in changes:
            tampered = copy.deepcopy(baseline)
            tampered["signing_identity"].update(change)
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                PUBLISHER.verify_signing_pair(tampered, baseline)

    def test_pin_removal_from_one_build_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "different expected certificate contracts"):
            PUBLISHER.verify_signing_pair(build_proof(expected=CERT_A), build_proof())

    def test_known_pin_mismatch_cannot_be_hidden_in_comparison_field(self):
        proof = build_proof(expected=CERT_A)
        proof["expected_signer_sha256"] = CERT_B
        with self.assertRaisesRegex(RuntimeError, "configured signing certificate"):
            PUBLISHER.verify_signing_pair(proof, build_proof(expected=CERT_A))


if __name__ == "__main__":
    unittest.main()
