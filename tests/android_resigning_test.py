"""Synthetische ZIP-/Berichtsfixtures; keine echten APKs, Schlüssel oder SDK-Aufrufe."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("resign_android_apk", ROOT / "tools/resign_android_apk.py")
RESIGN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RESIGN)
COMMIT = "1" * 40
SIGNER = "a" * 64
PASSWORD_NAME = "IMPERATHEN_UNIT_TEST_PASSWORD"
PASSWORD = "synthetic-value-never-to-be-logged"


def write_archive(path, entries):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, value in entries:
                archive.writestr(name, value)


class AndroidResigningTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="imperathen-resign-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.apk = self.root / "IMPERATHEN-11111111-arm64.apk"
        self.entries = [("AndroidManifest.xml", b"synthetic manifest"),
                        ("classes.dex", b"synthetic dex"),
                        ("assets/story/mission.json", b'{"mission":"I-02"}'),
                        ("META-INF/license.txt", b"ordinary metadata is payload")]
        self.entries += [(name, b"old-signature") for name in sorted(RESIGN.SIGNATURE_FILES)]
        write_archive(self.apk, self.entries)
        self.build_path = self.root / "upstream.build.json"
        self.build = {"source_commit": COMMIT, "source_sha256": "2" * 64,
                      "apk": self.apk.name, "apk_sha256": RESIGN.digest(self.apk),
                      "apk_size_bytes": self.apk.stat().st_size, "package": RESIGN.PACKAGE,
                      "abi": "arm64-v8a", "status": "verified_debug_apk",
                      "godot_version": "4.7.2.stable.official.fixture", "requested_renderer": "compatibility",
                      "created_utc": "2026-11-24T00:00:00+00:00", "validation_report": "upstream.validation.json"}
        RESIGN.write_json(self.build_path, self.build)
        self.sdk = self.root / "sdk"
        signer = self.sdk / "build-tools" / "35.0.1" / "apksigner"
        signer.parent.mkdir(parents=True)
        signer.write_text("unit-test executable placeholder; never executed\n", encoding="utf-8")
        signer.chmod(0o700)
        (signer.parent / "source.properties").write_text("Pkg.Revision = 35.0.1\n", encoding="utf-8")
        self.keystore = self.root / "private-placeholder"
        self.keystore.write_bytes(b"Not a keystore. No private key exists in this fixture.")
        self.source = self.root / "project"
        self.source.mkdir()
        (self.source / "project.godot").write_text("; synthetic project marker; not an executable game\n")
        self.output = self.root / "published"
        self.argv = ["--apk", str(self.apk), "--build-report", str(self.build_path),
                     "--expected-commit", COMMIT, "--expected-apk-sha256", self.build["apk_sha256"],
                     "--expected-signer-sha256", SIGNER, "--sdk-root", str(self.sdk),
                     "--source-root", str(self.source), "--keystore", str(self.keystore),
                     "--keystore-user", "test-alias", "--password-env", PASSWORD_NAME,
                     "--output-dir", str(self.output)]
        self.commands = []
        self.transform = lambda entries: entries
        self.final_report_change = lambda report: None
        self.after_final_validation = lambda: None
        environment = patch.dict(os.environ, {PASSWORD_NAME: PASSWORD})
        environment.start()
        self.addCleanup(environment.stop)

    def fixture_tool(self, command, environment, label, timeout):
        self.commands.append(command)
        self.assertNotIn(PASSWORD, " ".join(command))
        if command[1] == "version":
            self.assertNotIn(PASSWORD_NAME, environment)
            return "0.9"
        if command[1] == "sign":
            self.assertEqual(command[command.index("--ks-pass") + 1], "env:" + PASSWORD_NAME)
            self.assertEqual(environment[PASSWORD_NAME], PASSWORD)
            self.assertEqual(command[command.index("--v1-signer-name") + 1], "IMPERATH")
            self.assertEqual(command[command.index("--v4-signing-enabled") + 1], "false")
            source, destination = Path(command[-1]), Path(command[command.index("--out") + 1])
            with zipfile.ZipFile(source) as archive:
                entries = [(name, b"new-signature" if name in RESIGN.SIGNATURE_FILES else archive.read(name))
                           for name in archive.namelist()]
            write_archive(destination, self.transform(entries))
            return
        self.assertTrue(command[1].endswith("validate_android_apk.py"))
        self.assertNotIn(PASSWORD_NAME, environment)
        apk = Path(command[command.index("--apk") + 1])
        checks = [{"id": name, "required": True, "status": "pass", "evidence": {}}
                  for name in ("signature_verification", "apk_unchanged", "package_identity")]
        report = {"passed": True, "overall_status": "pass", "apk": {"sha256": RESIGN.digest(apk),
                  "size_bytes": apk.stat().st_size}, "expected_package": RESIGN.PACKAGE,
                  "expected_abi": "arm64-v8a", "available_abis": ["arm64-v8a"], "checks": checks,
                  "source_snapshot": {"status": "recorded", "sha256": {
                      "project.godot": RESIGN.digest(self.source / "project.godot")}},
                  "manifest": {"package": RESIGN.PACKAGE, "version_code": "8", "version_name": "fixture"}}
        final = "--expected-signer-sha256" in command
        if final:
            self.assertEqual(command[command.index("--expected-signer-sha256") + 1], SIGNER)
            report["expected_signer_sha256"] = SIGNER
            checks.append({"id": "signer_identity", "required": True, "status": "pass",
                           "evidence": {"expected": SIGNER, "actual": [SIGNER]}})
            self.final_report_change(report)
        RESIGN.write_json(Path(command[command.index("--report") + 1]), report)
        if final:
            self.after_final_validation()

    def run_fixture(self):
        with patch.object(RESIGN, "run_tool", side_effect=self.fixture_tool):
            return RESIGN.resign(RESIGN.parse_args(self.argv))

    def assert_no_publication(self):
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".imperathen-resign-*")), [])

    def test_complete_pipeline_publishes_bound_proofs_and_preserves_origin(self):
        original_apk = RESIGN.digest(self.apk)
        original_build = RESIGN.digest(self.build_path)
        result = self.run_fixture()
        self.assertTrue(result["passed"])
        self.assertEqual(len(self.commands), 4)
        self.assertEqual(len(list(self.output.iterdir())), 7)
        final = self.output / self.apk.name
        self.assertNotEqual(RESIGN.digest(final), original_apk)
        self.assertEqual(RESIGN.digest(self.apk), original_apk)
        self.assertEqual(RESIGN.digest(self.build_path), original_build)
        proof = RESIGN.read_json(self.output / (self.apk.stem + ".signing.json"))
        build = RESIGN.read_json(self.output / (self.apk.stem + ".build.json"))
        self.assertEqual(build["source_commit"], COMMIT)
        self.assertEqual(build["source_sha256"], self.build["source_sha256"])
        self.assertEqual(build["upstream_apk_sha256"], original_apk)
        self.assertEqual(build["apk_sha256"], RESIGN.digest(final))
        self.assertEqual(RESIGN.digest(self.output / (self.apk.stem + ".upstream.build.json")), original_build)
        self.assertEqual(proof["payload_comparison"]["entry_count"], 4)
        self.assertEqual(proof["apksigner_version"], "0.9")
        self.assertEqual(proof["sdk_revision"]["version"], "35.0.1")
        self.assertFalse(proof["runtime_test_executed"])
        self.assertIn("identische Nutzlast", proof["runtime_scope"])
        self.assertIn("nicht die identische signierte Datei", proof["runtime_scope"])
        self.assertEqual((self.output / (self.apk.name + ".sha256")).read_text().split(),
                         [RESIGN.digest(final), self.apk.name])
        for path in self.output.glob("*.json"):
            self.assertNotIn(PASSWORD, path.read_text())
            self.assertNotIn(str(self.keystore), path.read_text())

    def test_wrong_commit_hash_size_name_or_build_contract_is_rejected(self):
        changes = {"source_commit": "3" * 40, "apk_sha256": "0" * 64, "apk_size_bytes": 1,
                   "apk": "other.apk", "package": "other.package", "abi": "x86",
                   "status": "pending", "godot_version": "4.8.stable.fake", "requested_renderer": "mobile"}
        for field, value in changes.items():
            with self.subTest(field=field):
                altered = dict(self.build, **{field: value})
                RESIGN.write_json(self.build_path, altered)
                with self.assertRaises(RESIGN.ResignError):
                    self.run_fixture()
                self.assert_no_publication()
        self.assertEqual(self.commands, [])

    def test_explicit_available_35_0_0_toolchain_is_recorded(self):
        (self.sdk / "build-tools/35.0.1").rename(self.sdk / "build-tools/35.0.0")
        (self.sdk / "build-tools/35.0.0/source.properties").write_text("Pkg.Revision = 35.0.0\n")
        self.argv += ["--build-tools-version", "35.0.0"]
        self.run_fixture()
        proof = RESIGN.read_json(self.output / (self.apk.stem + ".signing.json"))
        self.assertEqual(proof["selected_build_tools_directory"], "35.0.0")
        self.assertEqual(proof["sdk_revision"]["version"], "35.0.0")
        self.assertEqual(proof["apksigner_version"], "0.9")

    def test_mislabelled_sdk_package_is_rejected(self):
        (self.sdk / "build-tools/35.0.1/source.properties").write_text("Pkg.Revision = 36.0.0\n")
        with self.assertRaisesRegex(RESIGN.ResignError, "SDK-Paketrevision"):
            self.run_fixture()
        self.assert_no_publication()

    def test_independent_expected_apk_digest_is_required_to_match(self):
        self.argv[self.argv.index("--expected-apk-sha256") + 1] = "f" * 64
        with self.assertRaises(RESIGN.ResignError):
            self.run_fixture()
        self.assert_no_publication()

    def test_duplicate_json_fields_are_rejected(self):
        self.build_path.write_text('{"source_commit":"a","source_commit":"b"}')
        with self.assertRaisesRegex(RESIGN.ResignError, "doppeltem"):
            self.run_fixture()
        self.assert_no_publication()

    def test_payload_edits_additions_removals_and_metadata_changes_are_rejected(self):
        transforms = [lambda entries: [(name, b"changed" if name == "classes.dex" else data) for name, data in entries],
                      lambda entries: entries + [("assets/injected.gd", b"unexpected")],
                      lambda entries: [(name, data) for name, data in entries if name != "classes.dex"],
                      lambda entries: [(name, b"changed" if name == "META-INF/license.txt" else data) for name, data in entries]]
        for transform in transforms:
            with self.subTest(transform=transforms.index(transform)):
                self.transform = transform
                with self.assertRaisesRegex(RESIGN.ResignError, "Nutzlast verändert"):
                    self.run_fixture()
                self.assert_no_publication()

    def test_duplicate_zip_entries_are_rejected(self):
        self.transform = lambda entries: entries + [("classes.dex", b"hidden second entry")]
        with self.assertRaisesRegex(RESIGN.ResignError, "Doppelte ZIP"):
            self.run_fixture()
        self.assert_no_publication()

    def test_unapproved_signature_filename_is_not_an_exemption(self):
        self.transform = lambda entries: entries + [("META-INF/OTHER.RSA", b"unexpected")]
        with self.assertRaisesRegex(RESIGN.ResignError, "Unerwartete ZIP-Signaturdatei"):
            self.run_fixture()
        self.assert_no_publication()

    def test_missing_signature_file_is_rejected(self):
        self.transform = lambda entries: [(name, data) for name, data in entries if name != "META-INF/IMPERATH.SF"]
        with self.assertRaisesRegex(RESIGN.ResignError, "Unvollständiger Satz"):
            self.run_fixture()
        self.assert_no_publication()

    def test_unsafe_zip_paths_are_rejected(self):
        for path in ("../outside", "/absolute", "assets//ambiguous", "assets/./alias", "assets\\other", "C:/drive"):
            with self.subTest(path=path):
                self.transform = lambda entries, path=path: entries + [(path, b"unsafe")]
                with self.assertRaisesRegex(RESIGN.ResignError, "ZIP-Pfad"):
                    self.run_fixture()
                self.assert_no_publication()

    def test_symlink_zip_entry_is_rejected(self):
        entry = zipfile.ZipInfo("assets/link")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        write_archive(self.root / "links.apk", [("AndroidManifest.xml", b"fixture"), (entry, b"elsewhere")])
        with self.assertRaisesRegex(RESIGN.ResignError, "Link"):
            RESIGN.zip_payload(self.root / "links.apk")

    def test_false_or_missing_signer_pin_cannot_publish(self):
        def wrong_signer(report):
            report["checks"][-1]["evidence"]["actual"] = ["b" * 64]
        def missing_pin(report):
            report["checks"].pop()
        for change in (wrong_signer, missing_pin):
            with self.subTest(change=change.__name__):
                self.final_report_change = change
                with self.assertRaisesRegex(RESIGN.ResignError, "Signaturidentitätsnachweis"):
                    self.run_fixture()
                self.assert_no_publication()

    def test_failure_in_required_validation_is_not_hidden_by_passed_flag(self):
        self.final_report_change = lambda report: report["checks"][0].update(status="fail")
        with self.assertRaisesRegex(RESIGN.ResignError, "Verpflichtende APK"):
            self.run_fixture()
        self.assert_no_publication()

    def test_stale_validation_report_is_rejected(self):
        self.final_report_change = lambda report: report["apk"].update(sha256="0" * 64)
        with self.assertRaisesRegex(RESIGN.ResignError, "andere Bytes"):
            self.run_fixture()
        self.assert_no_publication()

    def test_missing_source_project_cannot_disable_payload_requirements(self):
        (self.source / "project.godot").unlink()
        with self.assertRaisesRegex(RESIGN.ResignError, "Godot-Quellprojekt"):
            self.run_fixture()
        self.assertEqual(self.commands, [])

    def test_validator_must_record_the_selected_source_project(self):
        self.final_report_change = lambda report: report.update(source_snapshot={"status": "not_run"})
        with self.assertRaisesRegex(RESIGN.ResignError, "Projektquellennachweis"):
            self.run_fixture()
        self.assert_no_publication()

    def test_manifest_version_must_remain_unchanged(self):
        self.final_report_change = lambda report: report["manifest"].update(version_code="9")
        with self.assertRaisesRegex(RESIGN.ResignError, "Manifestdaten"):
            self.run_fixture()
        self.assert_no_publication()

    def test_original_input_mutation_aborts_publication(self):
        self.after_final_validation = lambda: self.apk.write_bytes(b"concurrent input mutation")
        with self.assertRaisesRegex(RESIGN.ResignError, "während des Laufs verändert"):
            self.run_fixture()
        self.assert_no_publication()

    def test_keystore_inside_repository_is_rejected(self):
        self.argv[self.argv.index("--keystore") + 1] = str(ROOT / "AGENTS.md")
        with self.assertRaisesRegex(RESIGN.ResignError, "außerhalb"):
            self.run_fixture()
        self.assertEqual(self.commands, [])

    def test_missing_password_is_rejected_before_tools(self):
        with patch.dict(os.environ, {}, clear=True), self.assertRaisesRegex(RESIGN.ResignError, "Passwort"):
            self.run_fixture()
        self.assertEqual(self.commands, [])

    def test_existing_output_directory_is_never_overwritten(self):
        self.output.mkdir()
        marker = self.output / "untouched.txt"
        marker.write_text("existing")
        with self.assertRaisesRegex(RESIGN.ResignError, "existiert bereits"):
            self.run_fixture()
        self.assertEqual(marker.read_text(), "existing")
        self.assertEqual(self.commands, [])

    def test_atomic_publish_rejects_concurrently_created_even_empty_directory(self):
        self.after_final_validation = lambda: self.output.mkdir()
        with self.assertRaisesRegex(RESIGN.ResignError, "existiert bereits"):
            self.run_fixture()
        self.assertEqual(list(self.output.iterdir()), [])
        self.assertEqual(list(self.root.glob(".imperathen-resign-*")), [])

    def test_private_tool_errors_never_print_password_or_keystore(self):
        result = subprocess.CompletedProcess(["private command"], 2, stdout=PASSWORD.encode(),
                                             stderr=str(self.keystore).encode())
        capture = io.StringIO()
        with patch.object(RESIGN.subprocess, "run", return_value=result), contextlib.redirect_stderr(capture):
            status = RESIGN.main(self.argv)
        self.assertEqual(status, 1)
        self.assertNotIn(PASSWORD, capture.getvalue())
        self.assertNotIn(str(self.keystore), capture.getvalue())
        self.assert_no_publication()

    def test_tool_timeout_does_not_leak_command_or_environment(self):
        with patch.object(RESIGN.subprocess, "run", side_effect=subprocess.TimeoutExpired([PASSWORD], 1)):
            with self.assertRaises(RESIGN.ResignError) as raised:
                RESIGN.run_tool([PASSWORD], {PASSWORD_NAME: PASSWORD}, "Nachsignierung", 1)
        self.assertNotIn(PASSWORD, str(raised.exception))

    def test_cli_requires_expected_signer_and_rejects_inline_password_option(self):
        without_pin = list(self.argv)
        index = without_pin.index("--expected-signer-sha256")
        del without_pin[index:index + 2]
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            RESIGN.parse_args(without_pin)
        capture = io.StringIO()
        with contextlib.redirect_stderr(capture), self.assertRaises(SystemExit):
            RESIGN.parse_args(self.argv + ["--password", PASSWORD])
        self.assertNotIn(PASSWORD, capture.getvalue())


if __name__ == "__main__":
    unittest.main()
