"""Public apksigner output fixtures; no keystore, private key or APK signing.

The first digest is the publicly documented 0.3.0 APK certificate. The second
comes from the public recovery certificate and is only a distinct test value;
it is not asserted to be a production APK signer.
"""
from __future__ import annotations

import argparse
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("signing_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
SIGNER = "85a92850b4c4824c22bda2809617415ae26854155f754ed753380556acf69aab"
OTHER = "8244758115f8c88e14acc8d4b441833aa005e924edaadbb9369b08009eabf8c2"


def signer_output(digests=(SIGNER,), *, count=None, include_count=True, labels=None, rotation=False):
    lines = ["Verifies", "Verified using v1 scheme (JAR signing): false",
             "Verified using v2 scheme (APK Signature Scheme v2): true",
             "Verified using v3 scheme (APK Signature Scheme v3): true",
             "Verified using v3.1 scheme (APK Signature Scheme v3.1): " + str(rotation).lower(),
             "Verified using v4 scheme (APK Signature Scheme v4): false"]
    if include_count:
        lines.append("Number of signers: " + str(len(digests) if count is None else count))
    for index, digest in enumerate(digests):
        label = labels[index] if labels else f"Signer #{index + 1}"
        lines.extend([label + " certificate DN: CN=IMPERATHEN Prototype, O=IMPERATHEN, C=AT",
                      label + " certificate SHA-256 digest: " + digest,
                      label + " key algorithm: RSA", label + " key size (bits): 3072"])
    return "\n".join(lines) + "\n"


def tool_result(output, *, exit_code=0, error=None, stderr=""):
    return {"command":["/sdk/apksigner", "verify", "--verbose", "--print-certs", "fixture.apk"],
            "exit_code":exit_code, "error":error, "stdout":output, "stderr":stderr}


class AndroidSignerTest(unittest.TestCase):
    def inspect(self, output, expected=None, **tool_options):
        report = {"checks": []}
        with patch.object(VALIDATOR, "run_tool", return_value=tool_result(output, **tool_options)) as run:
            VALIDATOR.inspect_signing(Path("fixture.apk"), report, {"apksigner":"/sdk/apksigner"}, 45, expected)
            run.assert_called_once_with(["/sdk/apksigner", "verify", "--verbose", "--print-certs", "fixture.apk"], 45)
        return VALIDATOR.finish(report), {item["id"]: item for item in report["checks"]}

    def test_verified_certificate_digests_are_recorded_without_a_pin(self):
        report, checks = self.inspect(signer_output((SIGNER.upper(),)))
        self.assertEqual(report["overall_status"], "pass")
        self.assertNotIn("signer_identity", checks)
        evidence = checks["signature_verification"]["evidence"]
        self.assertEqual(evidence["reported_signer_count"], 1)
        self.assertEqual(evidence["signer_sha256"], [SIGNER])
        self.assertEqual(evidence["signer_certificates"], [{"signer":"Signer #1", "sha256":SIGNER}])
        self.assertEqual(evidence["certificate_parse_errors"], [])

    def test_matching_single_signer_passes_the_required_identity_check(self):
        report, checks = self.inspect(signer_output(), SIGNER.upper())
        self.assertTrue(report["passed"])
        self.assertEqual(checks["signer_identity"]["status"], "pass")
        self.assertTrue(checks["signer_identity"]["required"])
        self.assertEqual(checks["signer_identity"]["evidence"]["expected"], SIGNER)

    def test_different_certificate_fails_even_with_a_valid_signature(self):
        report, checks = self.inspect(signer_output((OTHER,)), SIGNER)
        self.assertEqual(checks["signature_verification"]["status"], "pass")
        self.assertEqual(checks["signer_identity"]["status"], "fail")
        self.assertEqual(report["overall_status"], "fail")

    def test_multiple_signers_are_recorded_when_no_identity_is_pinned(self):
        report, checks = self.inspect(signer_output((SIGNER, OTHER)))
        self.assertTrue(report["passed"])
        self.assertEqual(checks["signature_verification"]["evidence"]["signer_sha256"], [SIGNER, OTHER])
        self.assertNotIn("signer_identity", checks)

    def test_multiple_signers_cannot_satisfy_a_single_signer_pin(self):
        for digests in ((SIGNER, OTHER), (SIGNER, SIGNER)):
            with self.subTest(digests=digests):
                report, checks = self.inspect(signer_output(digests), SIGNER)
                self.assertEqual(checks["signature_verification"]["status"], "pass")
                self.assertEqual(checks["signer_identity"]["status"], "fail")
                self.assertFalse(report["passed"])

    def test_missing_or_malformed_certificate_evidence_cannot_pass(self):
        for digest in ("", SIGNER[:-1], SIGNER + "0", "g" * 64, ":".join(SIGNER[i:i + 2] for i in range(0, 64, 2))):
            with self.subTest(digest=digest):
                report, checks = self.inspect(signer_output((digest,)), SIGNER)
                self.assertEqual(checks["signature_verification"]["status"], "incomplete")
                self.assertEqual(checks["signer_identity"]["status"], "incomplete")
                self.assertFalse(report["passed"])
                self.assertTrue(checks["signature_verification"]["evidence"]["certificate_parse_errors"])

    def test_signer_count_and_numbered_certificates_must_agree(self):
        outputs = [signer_output(count=0), signer_output(count=2), signer_output(count="invalid"),
                   signer_output(include_count=False), signer_output(labels=["Signer #2"]),
                   signer_output() + "Number of signers: 2\n"]
        for output in outputs:
            with self.subTest(output=output):
                report, checks = self.inspect(output, SIGNER)
                self.assertEqual(checks["signature_verification"]["status"], "incomplete")
                self.assertFalse(report["passed"])

    def test_duplicate_signer_entries_are_ambiguous(self):
        report, checks = self.inspect(signer_output((SIGNER, OTHER), labels=["Signer #1", "Signer #1"]), SIGNER)
        self.assertEqual(checks["signature_verification"]["status"], "incomplete")
        self.assertFalse(report["passed"])

    def test_public_key_digest_is_not_a_certificate_digest(self):
        output = signer_output().replace("certificate SHA-256 digest", "public key SHA-256 digest")
        report, checks = self.inspect(output, SIGNER)
        self.assertEqual(checks["signature_verification"]["evidence"]["signer_sha256"], [])
        self.assertFalse(report["passed"])

    def test_source_stamp_is_excluded_from_apk_signer_identity(self):
        for actual, stamp, identity_status in ((SIGNER, OTHER, "pass"), (OTHER, SIGNER, "fail")):
            with self.subTest(actual=actual):
                output = signer_output((actual,)) + "Source Stamp Signer certificate SHA-256 digest: " + stamp + "\n"
                _, checks = self.inspect(output, SIGNER)
                self.assertEqual(checks["signature_verification"]["evidence"]["signer_sha256"], [actual])
                self.assertEqual(checks["signer_identity"]["status"], identity_status)

    def test_sdk_specific_rotation_certificates_are_recorded_but_do_not_satisfy_a_single_pin(self):
        output = signer_output((OTHER, SIGNER), count=1, rotation=True,
                               labels=["Signer (minSdkVersion=33, maxSdkVersion=2147483647)",
                                       "Signer (minSdkVersion=28, maxSdkVersion=32)"])
        report, checks = self.inspect(output)
        self.assertTrue(report["passed"])
        self.assertEqual(checks["signature_verification"]["evidence"]["signer_sha256"], [OTHER, SIGNER])
        report, checks = self.inspect(output, SIGNER)
        self.assertEqual(checks["signer_identity"]["status"], "fail")
        self.assertFalse(report["passed"])

    def test_certificate_match_does_not_replace_a_verified_signature_scheme(self):
        output = signer_output().replace(": true", ": false")
        report, checks = self.inspect(output, SIGNER)
        self.assertEqual(checks["signature_verification"]["status"], "incomplete")
        self.assertNotEqual(checks["signer_identity"]["status"], "pass")
        self.assertFalse(report["passed"])

    def test_failed_verification_and_tool_failures_cannot_pass_matching_identity(self):
        cases = [({"exit_code":1}, "fail"), ({"exit_code":None, "error":"timeout"}, "incomplete"),
                 ({"stderr":"DOES NOT VERIFY\n"}, "fail"), ({"stderr":"ERROR: invalid signature\n"}, "fail")]
        for options, status in cases:
            with self.subTest(options=options):
                report, checks = self.inspect(signer_output(), SIGNER, **options)
                self.assertEqual(checks["signature_verification"]["status"], status)
                self.assertNotEqual(checks["signer_identity"]["status"], "pass")
                self.assertFalse(report["passed"])

    def test_absent_apksigner_leaves_both_required_checks_unrun(self):
        report = {"checks": []}
        with patch.object(VALIDATOR, "run_tool") as run:
            VALIDATOR.inspect_signing(Path("fixture.apk"), report, {}, 45, SIGNER)
            run.assert_not_called()
        self.assertEqual({item["id"]: item["status"] for item in report["checks"]},
                         {"signature_verification":"not_run", "signer_identity":"not_run"})
        self.assertEqual(VALIDATOR.finish(report)["overall_status"], "incomplete")

    def test_validate_forwards_the_pin_and_records_the_expectation(self):
        with tempfile.TemporaryDirectory(prefix="imperathen-signing-unit-") as temporary:
            apk = Path(temporary) / "fixture.apk"
            apk.write_bytes(b"mocked structure and signer inspection")
            args = argparse.Namespace(apk=apk, sdk_root=[], source_root=Path(temporary) / "source",
                                      expected_package="at.heinz.imperathen", expected_abi="arm64-v8a",
                                      expected_signer_sha256=SIGNER.upper(), tool_timeout=45)
            with patch.object(VALIDATOR, "sdk_roots", return_value=[]), \
                 patch.object(VALIDATOR, "find_tool", side_effect=lambda name, *_: "/sdk/apksigner" if name == "apksigner" else None), \
                 patch.object(VALIDATOR, "inspect_zip", return_value=True), \
                 patch.object(VALIDATOR, "inspect_manifest"), \
                 patch.object(VALIDATOR, "run_tool", return_value=tool_result(signer_output())):
                report = VALIDATOR.validate(args)
            self.assertEqual(report["expected_signer_sha256"], SIGNER)
            self.assertEqual(next(item["status"] for item in report["checks"] if item["id"] == "signer_identity"), "pass")


class AndroidSignerCliTest(unittest.TestCase):
    def test_cli_accepts_one_hex_digest_and_normalizes_case(self):
        stdout = io.StringIO()
        with patch.object(VALIDATOR.sys, "argv", ["validator", "--apk", "fixture.apk", "--expected-signer-sha256", SIGNER.upper()]), \
             patch.object(VALIDATOR, "validate", return_value={"overall_status":"pass", "passed":True}) as validate, \
             patch.object(VALIDATOR.sys, "stdout", stdout):
            self.assertEqual(VALIDATOR.main(), 0)
        self.assertEqual(validate.call_args.args[0].expected_signer_sha256, SIGNER)
        self.assertTrue(json.loads(stdout.getvalue())["passed"])

    def test_cli_rejects_non_hex_wrong_length_lists_and_multiple_flags(self):
        arguments = [["--expected-signer-sha256", value] for value in
                     ("", "g" * 64, SIGNER[:-1], SIGNER + "0", SIGNER + "," + OTHER,
                      " " + SIGNER, SIGNER + " ", "SHA256:" + SIGNER)]
        arguments.append(["--expected-signer-sha256", SIGNER, "--expected-signer-sha256", OTHER])
        for extra in arguments:
            with self.subTest(extra=extra), \
                 patch.object(VALIDATOR.sys, "argv", ["validator", "--apk", "fixture.apk"] + extra), \
                 patch.object(VALIDATOR.sys, "stderr", io.StringIO()), \
                 patch.object(VALIDATOR, "validate") as validate:
                with self.assertRaises(SystemExit) as error:
                    VALIDATOR.main()
                self.assertEqual(error.exception.code, 2)
                validate.assert_not_called()


if __name__ == "__main__":
    unittest.main()
