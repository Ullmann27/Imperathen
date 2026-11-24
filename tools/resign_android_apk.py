#!/usr/bin/env python3
"""Eine belegte CI-APK mit dem vorhandenen Schlüssel erneut signieren.

Linux, vorhandene Android Build-Tools 35.0.1 oder 35.0.0, kein Download oder Schlüsselbau.
Passwörter werden ausschließlich über benannte Umgebungsvariablen übergeben.
Das neue Ausgabeverzeichnis erscheint erst nach erfolgreicher Gesamtprüfung.
Ein Runtimebericht zur Eingangs-APK bezieht sich nach der Signierung auf deren
identische Nutzlast, nicht auf die identische signierte Datei.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
import errno
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile


REPOSITORY = Path(__file__).resolve().parents[1]
PACKAGE = "at.heinz.imperathen"
SIGNATURE_FILES = frozenset({"META-INF/MANIFEST.MF", "META-INF/IMPERATH.SF", "META-INF/IMPERATH.RSA"})
RUNTIME_SCOPE = ("Die Nachsignierung führt keinen Android-Runtimetest aus. Ein vorhandener "
                 "Runtimebericht zur Eingangs-APK betrifft die nachgewiesen identische Nutzlast, "
                 "nicht die identische signierte Datei; er wird nicht auf deren neue APK-Prüfsumme umgeschrieben.")


class ResignError(RuntimeError):
    """Abbruch ohne private Werkzeugausgabe oder teilweise veröffentlichte APK."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ResignError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def hex_value(value: str, length: int, label: str) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-fA-F]{" + str(length) + "}", value) is None:
        raise ResignError(f"{label}: genau {length} Hexadezimalzeichen ohne Trennzeichen erforderlich.")
    return value.lower()


def read_json(path: Path) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Mehrdeutiger JSON-Bericht mit doppeltem Schlüssel.")
            result[key] = value
        return result

    def invalid_constant(_value):
        raise ResignError("Nichtendliche Zahl im JSON-Bericht.")

    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique,
                       parse_constant=invalid_constant)
    require(isinstance(value, dict), "JSON-Bericht muss ein Objekt sein.")
    return value


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def is_within(path: Path, parent: Path) -> bool:
    return path == parent or parent in path.parents


def regular_file(path: Path, label: str) -> Path:
    require(not path.is_symlink() and path.is_file(), label + " muss eine reguläre Datei sein.")
    return path.resolve()


def check_build(apk: Path, build: dict, expected_commit: str, expected_apk_sha256: str) -> None:
    require(build.get("source_commit") == expected_commit, "Buildnachweis gehört zu einem anderen Quellcommit.")
    require(build.get("apk") == apk.name, "APK-Dateiname und Buildnachweis stimmen nicht überein.")
    require(build.get("apk_sha256") == expected_apk_sha256 and digest(apk) == expected_apk_sha256,
            "APK-Bytes, erwartete SHA256 und Buildnachweis stimmen nicht überein.")
    require(type(build.get("apk_size_bytes")) is int and build["apk_size_bytes"] == apk.stat().st_size,
            "APK-Größe und Buildnachweis stimmen nicht überein.")
    require(build.get("status") == "verified_debug_apk" and build.get("package") == PACKAGE,
            "Buildnachweis belegt keine geprüfte IMPERATHEN-Debug-APK.")
    require(build.get("abi") in {"arm64-v8a", "x86_64"}, "Nicht unterstützte Build-ABI.")
    require(isinstance(build.get("godot_version"), str)
            and build["godot_version"].startswith("4.7.2.stable."), "Buildnachweis benötigt Godot 4.7.2 stable.")
    require(build.get("requested_renderer") == "compatibility", "Buildnachweis benötigt den Compatibility-Renderer.")


def zip_payload(apk: Path) -> dict:
    """Jeden Eintrag lesen/CRC-prüfen; nur drei exakte Signaturpfade ausnehmen."""
    payload, signatures = {}, {}
    with zipfile.ZipFile(apk) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        require(len(names) == len(set(names)), "Doppelte ZIP-Einträge sind nicht zulässig.")
        for entry in sorted(entries, key=lambda item: item.filename):
            name = entry.filename
            pure = PurePosixPath(name)
            require(name == entry.orig_filename and name and not pure.is_absolute()
                    and "\\" not in name and not any(ord(char) < 32 for char in name)
                    and ":" not in name and ".." not in pure.parts
                    and pure.as_posix() == name.rstrip("/"), "Unsicherer oder mehrdeutiger ZIP-Pfad.")
            mode = entry.external_attr >> 16
            require(not stat.S_ISLNK(mode) and (stat.S_IFMT(mode) in {0, stat.S_IFREG, stat.S_IFDIR}),
                    "ZIP enthält einen Link oder einen besonderen Dateityp.")
            require(not entry.flag_bits & 1, "Verschlüsselte ZIP-Einträge sind nicht zulässig.")
            require(entry.compress_type in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED},
                    "Unerwartetes ZIP-Kompressionsverfahren.")
            require(not entry.is_dir() or entry.file_size == 0, "ZIP-Verzeichnis enthält unerwartete Nutzlast.")
            signature_like = (name.startswith("META-INF/") and "/" not in name[len("META-INF/"):]
                              and (name.upper().endswith((".SF", ".RSA", ".DSA", ".EC"))
                                   or name.upper().startswith("META-INF/SIG-")))
            require(not signature_like or name in SIGNATURE_FILES, "Unerwartete ZIP-Signaturdatei.")
            with archive.open(entry) as stream:
                value = hashlib.file_digest(stream, "sha256").hexdigest()
            record = {"sha256": value, "size_bytes": entry.file_size,
                      "kind": "directory" if entry.is_dir() else "file"}
            (signatures if name in SIGNATURE_FILES else payload)[name] = record
    require(payload and "AndroidManifest.xml" in payload, "APK-Nutzlast oder AndroidManifest.xml fehlt.")
    require(not signatures or set(signatures) == SIGNATURE_FILES, "Unvollständiger Satz bekannter v1-Signaturdateien.")
    return {"payload": payload, "signature_files": signatures, "zip_entry_count": len(entries)}


def compare_payloads(before: dict, after: dict) -> dict:
    old, new = before["payload"], after["payload"]
    added, removed = sorted(new.keys() - old.keys()), sorted(old.keys() - new.keys())
    changed = sorted(name for name in old.keys() & new.keys() if old[name] != new[name])
    require(not added and not removed and not changed,
            f"APK-Nutzlast verändert: {len(added)} neue, {len(removed)} fehlende, {len(changed)} geänderte Einträge.")
    canonical = json.dumps(old, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"passed": True, "entry_count": len(old), "entry_manifest_sha256": hashlib.sha256(canonical).hexdigest(),
            "entries": old, "excluded_signature_paths": sorted(SIGNATURE_FILES),
            "upstream_signature_files": before["signature_files"], "final_signature_files": after["signature_files"],
            "scope": "Unkomprimierte Bytes und Namen jedes ZIP-Nutzlasteintrags sind identisch. "
                     "Die APK-Signaturblöcke außerhalb der ZIP-Einträge und die drei genannten v1-Dateien dürfen sich ändern."}


def run_tool(command: list[str], environment: dict[str, str], label: str, timeout: int) -> str:
    # Insbesondere apksigner-Ausgaben können private Konfigurationsdaten enthalten.
    # Keine Befehlszeile, Passwörter, Toolausgaben oder Exception-Reprs ausgeben.
    try:
        result = subprocess.run(command, env=environment, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise ResignError(label + ": Werkzeug nicht erfolgreich abgeschlossen.") from None
    require(result.returncode == 0, f"{label}: Exitcode {result.returncode}; keine Ausgabe freigegeben.")
    return result.stdout.decode("utf-8", errors="replace").strip()


def checked_validation(apk: Path, report_path: Path, args: argparse.Namespace, build: dict,
                       environment: dict[str, str], signer: str | None = None) -> dict:
    validator = REPOSITORY / "tools/validate_android_apk.py"
    command = [sys.executable, str(validator), "--apk", str(apk), "--sdk-root", str(args.sdk_root),
               "--apksigner", str(args.apksigner), "--source-root", str(args.source_root),
               "--expected-package", PACKAGE, "--expected-abi", build["abi"], "--report", str(report_path)]
    if signer is not None:
        command += ["--expected-signer-sha256", signer]
    run_tool(command, environment, "Finale APK-Prüfung" if signer else "Eingangs-APK-Prüfung", args.timeout)
    report = read_json(report_path)
    require(report.get("passed") is True and report.get("overall_status") == "pass", "APK-Prüfbericht ist nicht vollständig grün.")
    require(report.get("apk", {}).get("sha256") == digest(apk)
            and report["apk"].get("size_bytes") == apk.stat().st_size, "APK-Prüfbericht betrifft andere Bytes.")
    require(report.get("expected_package") == PACKAGE and report.get("expected_abi") == build["abi"]
            and report.get("available_abis") == [build["abi"]]
            and report.get("manifest", {}).get("package") == PACKAGE, "APK-Prüfbericht betrifft ein anderes Paket oder eine andere ABI.")
    snapshot = report.get("source_snapshot", {})
    require(snapshot.get("status") == "recorded"
            and snapshot.get("sha256", {}).get("project.godot") == digest(args.source_root / "project.godot"),
            "APK-Prüfbericht enthält keinen passenden Projektquellennachweis.")
    checks = report.get("checks", [])
    require(isinstance(checks, list) and checks and all(isinstance(item, dict) for item in checks), "APK-Prüfungen fehlen.")
    by_id = {item.get("id"): item for item in checks}
    require(len(by_id) == len(checks) and None not in by_id, "Mehrdeutige APK-Prüfungen.")
    require(all(item.get("status") == "pass" for item in checks if item.get("required")), "Verpflichtende APK-Prüfung fehlgeschlagen.")
    require(by_id.get("signature_verification", {}).get("status") == "pass", "Kryptografischer Signaturnachweis fehlt.")
    if signer is not None:
        identity = by_id.get("signer_identity", {})
        require(report.get("expected_signer_sha256") == signer and identity.get("required") is True
                and identity.get("status") == "pass" and identity.get("evidence", {}).get("expected") == signer
                and identity["evidence"].get("actual") == [signer], "Gepinnter Signaturidentitätsnachweis fehlt oder weicht ab.")
    return report


def publish_directory(staged: Path, destination: Path) -> None:
    """Linux renameat2 garantiert atomare Freigabe und NOREPLACE auch bei Rennen."""
    libc = ctypes.CDLL(None, use_errno=True)
    rename = getattr(libc, "renameat2", None)
    require(rename is not None, "Atomare Veröffentlichung ohne Überschreiben benötigt Linux renameat2.")
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    if rename(-100, os.fsencode(staged), -100, os.fsencode(destination), 1) != 0:
        error = ctypes.get_errno()
        if error in {errno.EEXIST, errno.ENOTEMPTY}:
            raise ResignError("Ausgabeverzeichnis existiert bereits; nichts wurde überschrieben.")
        raise ResignError(f"Atomare Veröffentlichung fehlgeschlagen (errno {error}).")


def resign(args: argparse.Namespace) -> dict:
    require(sys.platform.startswith("linux"), "Dieser Nachsignierungsweg ist für Linux vorgesehen.")
    require(args.timeout > 0, "Zeitlimit muss positiv sein.")
    args.expected_commit = hex_value(args.expected_commit, 40, "Quellcommit")
    args.expected_apk_sha256 = hex_value(args.expected_apk_sha256, 64, "Eingangs-APK-SHA256")
    args.expected_signer_sha256 = hex_value(args.expected_signer_sha256, 64, "Signaturzertifikat-SHA256")
    apk = regular_file(args.apk.expanduser(), "Eingangs-APK")
    build_path = regular_file(args.build_report.expanduser(), "Buildnachweis")
    require(apk.suffix.lower() == ".apk", "Eingangsdatei muss eine APK sein.")
    keystore = regular_file(args.keystore.expanduser(), "Privater Keystore")
    args.source_root = args.source_root.expanduser().resolve()
    regular_file(args.source_root / "project.godot", "Godot-Quellprojekt")
    require(not is_within(keystore, REPOSITORY) and not is_within(keystore, args.source_root),
            "Privater Keystore muss außerhalb des Repositorys und der Projektquellen liegen.")
    require(args.keystore_user and not any(ord(char) < 32 for char in args.keystore_user), "Keystore-Alias fehlt oder ist ungültig.")
    environment = os.environ.copy()
    key_password_env = args.key_password_env or args.password_env
    for name in {args.password_env, key_password_env}:
        require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) is not None and bool(environment.get(name)),
                "Benannte Passwort-Umgebungsvariable fehlt oder ist ungültig.")
    validation_environment = environment.copy()
    for name in {args.password_env, key_password_env}:
        validation_environment.pop(name, None)
    args.sdk_root = args.sdk_root.expanduser().resolve()
    tool_directory = args.sdk_root / "build-tools" / args.build_tools_version
    args.apksigner = regular_file(tool_directory / "apksigner", "SDK-apksigner")
    require(os.access(args.apksigner, os.X_OK), "SDK-apksigner ist nicht ausführbar.")
    output = args.output_dir.expanduser().absolute()
    require(not output.exists() and not output.is_symlink(), "Ausgabeverzeichnis existiert bereits; nichts wird überschrieben.")
    output = output.parent.resolve() / output.name
    require(not is_within(output, args.source_root), "Ausgabe darf nicht in den Godot-Projektquellen liegen.")
    build = read_json(build_path)
    build_hash = digest(build_path)
    check_build(apk, build, args.expected_commit, args.expected_apk_sha256)
    signer_version = run_tool([str(args.apksigner), "version"], validation_environment, "apksigner-Version", args.timeout)
    require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", signer_version) is not None,
            "apksigner lieferte keine eindeutige öffentliche Versionsnummer.")
    sdk_revision = None
    properties = tool_directory / "source.properties"
    if properties.is_file():
        match = re.search(r"^Pkg\.Revision\s*=\s*([^\r\n]+)$", properties.read_text(encoding="utf-8"), re.MULTILINE)
        require(match is not None and match.group(1).strip() == args.build_tools_version,
                "SDK-Paketrevision stimmt nicht mit der gewählten Build-Tools-Version überein.")
        sdk_revision = {"version": match.group(1).strip(), "source_properties_sha256": digest(properties)}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".imperathen-resign-", dir=output.parent) as temporary:
        work = Path(temporary)
        source = work / apk.name
        shutil.copyfile(apk, source)
        require(digest(source) == args.expected_apk_sha256, "Eingangs-APK änderte sich während der Übernahme.")
        staged = work / "verified"
        staged.mkdir()
        final = staged / apk.name
        stem = final.stem
        upstream_validation = checked_validation(source, staged / (stem + ".upstream.validation.json"),
                                                 args, build, validation_environment)
        before = zip_payload(source)
        command = [str(args.apksigner), "sign", "--ks", str(keystore), "--ks-key-alias", args.keystore_user,
                   "--ks-pass", "env:" + args.password_env, "--key-pass", "env:" + key_password_env,
                   "--v1-signer-name", "IMPERATH", "--v1-signing-enabled", "true",
                   "--v2-signing-enabled", "true", "--v3-signing-enabled", "true",
                   "--v4-signing-enabled", "false", "--out", str(final), str(source)]
        run_tool(command, environment, "Nachsignierung", args.timeout)
        require(final.is_file() and not final.is_symlink(), "Nachsignierung erzeugte keine reguläre APK.")
        after = zip_payload(final)
        require(set(after["signature_files"]) == SIGNATURE_FILES, "Nachsignierung erzeugte nicht die festgelegten v1-Signaturdateien.")
        payload_proof = compare_payloads(before, after)
        final_hash = digest(final)
        final_validation = checked_validation(final, staged / (stem + ".validation.json"),
                                              args, build, validation_environment, args.expected_signer_sha256)
        require(digest(final) == final_hash, "Finale APK änderte sich während der Prüfung.")
        for field in ("package", "version_code", "version_name", "min_sdk", "target_sdk", "launchable_activity"):
            require(upstream_validation["manifest"].get(field) == final_validation["manifest"].get(field),
                    "Manifestdaten änderten sich durch die Nachsignierung.")
        require(digest(apk) == args.expected_apk_sha256 and digest(source) == args.expected_apk_sha256
                and digest(build_path) == build_hash, "Eingangs-APK oder Buildnachweis wurde während des Laufs verändert.")
        created = datetime.now(timezone.utc).isoformat()
        signing = {"schema_version": 1, "passed": True, "created_utc": created,
                   "source_commit": args.expected_commit, "upstream_apk": apk.name,
                   "upstream_apk_sha256": args.expected_apk_sha256, "upstream_build_sha256": build_hash,
                   "final_apk": final.name, "final_apk_sha256": final_hash,
                   "final_apk_size_bytes": final.stat().st_size,
                   "expected_signer_sha256": args.expected_signer_sha256,
                   "selected_build_tools_directory": args.build_tools_version,
                   "sdk_revision": sdk_revision, "apksigner_version": signer_version,
                   "apksigner_sha256": digest(args.apksigner), "validator_sha256": digest(REPOSITORY / "tools/validate_android_apk.py"),
                   "payload_comparison": payload_proof, "runtime_scope": RUNTIME_SCOPE,
                   "runtime_test_executed": False,
                   "signed_file_bytes_identical": final_hash == args.expected_apk_sha256}
        write_json(staged / (stem + ".signing.json"), signing)
        result_build = dict(build)
        result_build.update({"created_utc": created, "apk": final.name, "apk_sha256": final_hash,
                             "apk_size_bytes": final.stat().st_size, "signing": "resigned_with_pinned_existing_debug_key",
                             "validation_report": stem + ".validation.json", "signing_report": stem + ".signing.json",
                             "upstream_apk_sha256": args.expected_apk_sha256, "upstream_build_sha256": build_hash,
                             "device_test": "not_run_by_resigning_tool", "runtime_scope": RUNTIME_SCOPE})
        write_json(staged / (stem + ".build.json"), result_build)
        shutil.copyfile(build_path, staged / (stem + ".upstream.build.json"))
        require(digest(staged / (stem + ".upstream.build.json")) == build_hash, "Übernommener Buildnachweis änderte sich.")
        (staged / (final.name + ".sha256")).write_text(f"{final_hash}  {final.name}\n", encoding="utf-8")
        expected_files = {final.name, final.name + ".sha256", stem + ".build.json", stem + ".signing.json",
                          stem + ".validation.json", stem + ".upstream.build.json", stem + ".upstream.validation.json"}
        require({path.name for path in staged.iterdir()} == expected_files
                and all(path.is_file() and not path.is_symlink() for path in staged.iterdir()),
                "Unerwartete Dateien im Ausgabepaket.")
        for path in staged.iterdir():
            with path.open("rb") as stream:
                os.fsync(stream.fileno())
        directory_fd = os.open(staged, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        publish_directory(staged, output)
    return {"passed": True, "output_dir": str(output), "apk": apk.name, "apk_sha256": final_hash,
            "source_commit": args.expected_commit, "signer_sha256": args.expected_signer_sha256,
            "payload_entries": payload_proof["entry_count"], "runtime_scope": RUNTIME_SCOPE}


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse würde unbekannte Optionen samt versehentlich übergebenem
        # Passwort wiederholen. Nur die allgemeine Nutzung und sichere Hilfe.
        self.print_usage(sys.stderr)
        self.exit(2, "ANDROID_RESIGN_FAIL Ungültige oder fehlende CLI-Optionen. Passwörter ausschließlich über benannte Umgebungsvariablen bereitstellen.\n")


def parse_args(argv=None) -> argparse.Namespace:
    parser = SafeArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--build-report", type=Path, required=True)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--expected-apk-sha256", required=True)
    parser.add_argument("--expected-signer-sha256", required=True)
    parser.add_argument("--sdk-root", type=Path, required=True)
    parser.add_argument("--build-tools-version", choices=("35.0.1", "35.0.0"), default="35.0.1")
    parser.add_argument("--source-root", type=Path, default=REPOSITORY / "prototype")
    parser.add_argument("--keystore", type=Path, required=True)
    parser.add_argument("--keystore-user", required=True)
    parser.add_argument("--password-env", default="GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD")
    parser.add_argument("--key-password-env")
    parser.add_argument("--output-dir", type=Path, required=True, help="Neues, noch nicht vorhandenes Ausgabeverzeichnis")
    parser.add_argument("--timeout", type=int, default=300)
    return parser.parse_args(argv)


def main(argv=None) -> int:
    try:
        result = resign(parse_args(argv))
        print("ANDROID_RESIGN_PASS " + json.dumps(result, ensure_ascii=False))
        return 0
    except ResignError as error:
        print("ANDROID_RESIGN_FAIL " + str(error), file=sys.stderr)
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError):
        print("ANDROID_RESIGN_FAIL Datei- oder Prüfverarbeitung fehlgeschlagen; keine private Werkzeugausgabe veröffentlicht.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
