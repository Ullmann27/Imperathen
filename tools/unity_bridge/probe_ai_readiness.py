#!/usr/bin/env python3
"""Read-only, privacy-preserving Unity AI generator readiness diagnostics.

Never triggers generations, sets consent, accepts terms or spends Unity Credits.
It only queries the local CLI plugin and summarizes boolean/status information.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path

VALID_GENESIS_ID = re.compile(r"[0-9]{6,20}\Z")
TIMEOUT = 45
SIGNALS = {
    "sign_in": ("sign in", "sign-in", "login", "not authenticated", "authenticate"),
    "organization": ("organization", "org id", "genesisid", "set-default"),
    "subscription_or_seat": ("subscription", "seat", "entitlement", "license"),
    "terms": ("terms of service", "terms of use", "accept terms", "agreement"),
    "generator_permission": ("enable generators", "generator access", "generators enabled"),
    "credits": ("credit", "balance", "insufficient funds"),
    "agent_skills": ("agent skill", "skill install"),
    "preview": ("node.js", "preview"),
}

def run(unity: str, *args: str) -> tuple[int, str]:
    try:
        process = subprocess.run(
            [unity, "--non-interactive", *args],
            text=True, capture_output=True, check=False, timeout=TIMEOUT,
            env={**os.environ, "UNITY_NON_INTERACTIVE": "1"},
        )
    except (OSError, subprocess.TimeoutExpired):
        return -1, ""
    # Caller sees the output only in process memory; no raw output is recorded.
    return process.returncode, process.stdout + "\n" + process.stderr

def indicators(message: str) -> list[str]:
    """Diagnostics mention possible topics; these are NOT confirmed defects."""
    value = message.casefold()
    return sorted(key for key, patterns in SIGNALS.items() if any(token in value for token in patterns))

def inspect(unity: str, org_id: str) -> dict:
    report = {
        "schema": 1, "provider": "unity_ai_cli", "read_only": True,
        "new_generation_started": False, "credits_spent_by_probe": 0,
        "account_details_published": False,
    }
    # This changes the default org only inside the disposable GitHub runner.
    # It never changes Cloud data, remote settings, or personal credentials.
    if org_id and VALID_GENESIS_ID.fullmatch(org_id):
        code, _ = run(unity, "cloud", "org", "set-default", org_id)
        report["ephemeral_org_selection"] = ("CLI_SUCCESS" if code == 0 else "CLI_FAILED")
    else:
        report["ephemeral_org_selection"] = "ORG_GENESIS_ID_NOT_CONFIRMED"
    help_exit, help_body = run(unity, "ai", "help")
    report["ai_help_available"] = help_exit == 0
    report["ai_help_mentions_3d"] = help_exit == 0 and bool(re.search(r"\b3d\b|3-d|mesh", help_body, re.I))
    report["ai_help_mentions_models"] = help_exit == 0 and "model" in help_body.casefold()
    doctor_exit, doctor_body = run(unity, "ai", "doctor")
    report["doctor_passed"] = doctor_exit == 0
    report["doctor_failure_topics_mentioned"] = [] if doctor_exit == 0 else indicators(doctor_body)
    report["doctor_result"] = "READY_REPORTED" if doctor_exit == 0 else ("UNAVAILABLE" if doctor_exit == -1 else "REQUIRES_SETUP")
    consent_exit, _ = run(unity, "ai", "consent", "show")
    report["consent_readable"] = consent_exit == 0
    report["production_authorized"] = False  # Separate proof + explicit user cost approval always required.
    return report

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--unity", default="unity")
    p.add_argument("--report", type=Path, required=True)
    args = p.parse_args()
    result = inspect(args.unity, os.environ.get("UNITY_CLOUD_ORG_ID", ""))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("UNITY_AI_READINESS", result["doctor_result"], "HELP", result["ai_help_available"])
    print("UNITY_AI_SETUP_TOPICS", ",".join(result["doctor_failure_topics_mentioned"]) or "none")
    # No raw Unity CLI output, account IDs, tokens, credit balances or personal details.

if __name__ == "__main__":
    main()
