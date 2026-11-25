#!/usr/bin/env python3
"""Read verified, public APK signing identities without accessing a private key.

A matching certificate is one condition for an Android update, not an update
installation test. Key rotation and lineage migration require a separate review.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import re
import subprocess


class SigningIdentityError(RuntimeError):
    """An incomplete or mismatched signing identity; never a successful check."""


def normalize_certificate_sha256(value: str) -> str:
    if not isinstance(value, str):
        raise SigningIdentityError("Expected certificate SHA-256 must be a string.")
    value = value.strip()
    if not (re.fullmatch(r"[0-9a-fA-F]{64}", value)
            or re.fullmatch(r"(?:[0-9a-fA-F]{2}:){31}[0-9a-fA-F]{2}", value)):
        raise SigningIdentityError("Expected certificate SHA-256 must contain exactly 32 hexadecimal bytes.")
    return value.replace(":", "").lower()


def expected_certificate(cli_value: str | None, environment_value: str | None) -> str | None:
    """Never silently override a configured pin with another CLI certificate."""
    configured = [normalize_certificate_sha256(value) for value in (cli_value, environment_value)
                  if value is not None and value != ""]
    if len(set(configured)) > 1:
        raise SigningIdentityError("CLI and environment specify different expected signing certificates.")
    return configured[0] if configured else None


def verified_certificates(stdout: str, stderr: str, exit_code: int) -> list[str]:
    """Parse the numbered signing certificates from apksigner's verified output.

    Source-stamp and public-key fingerprints are deliberately not APK signer
    certificate fingerprints. SDK-dependent rotation output is not guessed.
    """
    if exit_code != 0 or re.search(r"DOES NOT VERIFY|^ERROR:", stdout + "\n" + stderr, re.MULTILINE):
        raise SigningIdentityError("apksigner did not verify the APK signature.")
    if not re.search(r"^Verifies\s*$", stdout, re.MULTILINE):
        raise SigningIdentityError("apksigner did not return its affirmative verification marker.")
    schemes = re.findall(r"^Verified using v\d(?:\.\d+)? scheme[^\n]*:\s*(true|false)\s*$",
                         stdout, re.MULTILINE)
    if "true" not in schemes:
        raise SigningIdentityError("apksigner did not verify any APK signature scheme.")
    if re.search(r"^Signer \(", stdout, re.MULTILINE):
        raise SigningIdentityError("SDK-dependent signing rotation requires an explicit lineage review.")
    counts = re.findall(r"^Number of signers:\s*([0-9]+)\s*$", stdout, re.MULTILINE)
    entries = re.findall(r"^Signer #([0-9]+) certificate SHA-256 digest:\s*([^\r\n]+)$",
                         stdout, re.MULTILINE)
    if len(counts) != 1 or not 0 < int(counts[0]) <= 32:
        raise SigningIdentityError("apksigner did not report a valid signer count.")
    count = int(counts[0])
    if len(entries) != count or sorted(int(index) for index, _ in entries) != list(range(1, count + 1)):
        raise SigningIdentityError("APK signer certificate coverage is missing, duplicated or incomplete.")
    certificates = sorted(normalize_certificate_sha256(value) for _, value in entries)
    if len(set(certificates)) != count:
        raise SigningIdentityError("APK signer certificates contain duplicate identities.")
    return certificates


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_signing_identity(apk: Path, apksigner: Path, *, expected_sha256: str | None = None,
                            timeout: int = 30, environment: dict[str, str] | None = None) -> dict:
    expected = normalize_certificate_sha256(expected_sha256) if expected_sha256 is not None else None
    if not apk.is_file() or apk.is_symlink() or apk.stat().st_size == 0:
        raise SigningIdentityError("Signing identity requires a nonempty regular APK file.")
    before = _sha256(apk)
    try:
        result = subprocess.run([str(apksigner), "verify", "--verbose", "--print-certs", str(apk)],
                                capture_output=True, text=True, encoding="utf-8", errors="replace",
                                timeout=timeout, env=environment, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SigningIdentityError("apksigner could not complete the signing identity check.") from error
    certificates = verified_certificates(result.stdout, result.stderr, result.returncode)
    if before != _sha256(apk):
        raise SigningIdentityError("APK bytes changed during the signing identity check.")
    if expected is not None and certificates != [expected]:
        raise SigningIdentityError("APK signing certificate differs from the expected certificate; no APK promoted.")
    return {
        "schema_version": 1,
        "status": "verified",
        "apk_sha256": before,
        "signer_certificates_sha256": certificates,
        "expected_certificate_sha256": expected,
        "comparison": "matched_expected_certificate" if expected is not None else "not_checked",
        "scope": "Certificate identity only; not proof of a successful update on an installed device.",
    }
