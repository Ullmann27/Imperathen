#!/usr/bin/env python3
"""Read-only Unity CLI Cloud health probe. Never store raw account responses."""
from __future__ import annotations
import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

PROJECT_NAME = "Imperathen"
COMMAND_TIMEOUT_SECONDS = 40

def _status_class(stdout: str, stderr: str, exit_code: int) -> str:
    if exit_code == 0:
        return "COMMAND_SUCCEEDED"
    content = (stdout + "\n" + stderr).lower()
    for code in (401, 403, 404, 408, 409, 429, 500, 502, 503):
        if re.search(rf"(?<!\d){code}(?!\d)", content):
            return f"HTTP_{code}"
    if any(v in content for v in ("not authorized", "unauthorized", "not authenticated", "please sign in", "sign in", "login required")):
        return "AUTH_REQUIRED"
    if any(v in content for v in ("permission", "forbidden", "access denied")):
        return "PERMISSION_DENIED"
    if "organization" in content and any(v in content for v in ("select", "choose", "required", "default", "must specify")):
        return "ORGANIZATION_REQUIRED"
    if "not found" in content or "unknown organization" in content:
        return "NOT_FOUND"
    if any(v in content for v in ("network", "connection", "timed out")):
        return "NETWORK_FAILURE"
    if "invalid" in content and "command" in content:
        return "CLI_ARGUMENT_ERROR"
    return "UNKNOWN_FAILURE"

def _find_named_project(tree: Any, expected: str) -> bool:
    if isinstance(tree, dict):
        if any(isinstance(tree.get(k), str) and tree[k].casefold() == expected.casefold() for k in ("name", "projectName", "displayName")):
            return True
        return any(_find_named_project(v, expected) for v in tree.values())
    if isinstance(tree, list):
        return any(_find_named_project(v, expected) for v in tree)
    return False

def _run_read_only(unity: str, args: list[str], env: dict[str, str]) -> dict[str, Any]:
    try:
        p = subprocess.run([unity, "--non-interactive", *args], env=env, text=True,
                           capture_output=True, timeout=COMMAND_TIMEOUT_SECONDS, check=False)
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "exit_code": -1}
    except OSError:
        return {"status": "LOCAL_EXECUTION_ERROR", "exit_code": -1}
    data: dict[str, Any] = {"status": _status_class(p.stdout, p.stderr, p.returncode),
                            "exit_code": p.returncode}
    if p.returncode == 0:
        try:
            obj = json.loads(p.stdout)
            if isinstance(obj, dict) and obj.get("success") is False:
                data["status"] = "CLI_REPORTED_FAILURE"
            if "cloud" in args and any(a in args for a in ("projects", "project")):
                data["imperathen_visible"] = _find_named_project(obj, PROJECT_NAME)
        except (json.JSONDecodeError, ValueError):
            data["structured_result"] = "NON_JSON"
    return data

def probe(unity: str, org_candidate: str) -> dict[str, Any]:
    env = dict(os.environ)
    report: dict[str, Any] = {"schema": 1, "project": PROJECT_NAME, "probes": {}}
    if not env.get("UNITY_SERVICE_ACCOUNT_ID") or not env.get("UNITY_SERVICE_ACCOUNT_SECRET"):
        report["status"] = "MISSING_CI_SECRETS"
        return report
    commands = {
        "auth_status": ["auth", "status", "--format", "json"],
        "cloud_status": ["cloud", "status", "--format", "json"],
        "cloud_orgs": ["cloud", "org", "--format", "json"],
        "cloud_projects_default": ["cloud", "projects", "--format", "json"]
    }
    if org_candidate:
        commands["cloud_projects_org_candidate"] = [
            "cloud", "projects", "--cloud-org", org_candidate, "--format", "json"
        ]
    for name, args in commands.items():
        report["probes"][name] = _run_read_only(unity, args, env)
    # Official Unity CLI option: compare the brokered sign-in against a direct
    # service-account environment token path, without changing credentials.
    without_broker = dict(env)
    without_broker["UNITY_NO_AUTH_BROKER"] = "1"
    for name in ("cloud_orgs", "cloud_projects_default", "cloud_projects_org_candidate"):
        if name in commands:
            report["probes"][name + "_direct_auth"] = _run_read_only(unity, commands[name], without_broker)
    found = any(x.get("imperathen_visible") is True for x in report["probes"].values())
    report["status"] = "IMPERATHEN_VISIBLE" if found else "PROJECT_ACCESS_NOT_PROVEN"
    return report

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unity", default="unity")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--org-candidate", default="")
    args = parser.parse_args()
    report = probe(args.unity, args.org_candidate)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("UNITY_CLOUD_DIAGNOSTIC", report["status"])
    for name, row in report.get("probes", {}).items():
        print(name, row["status"], "visible" if row.get("imperathen_visible") else "")

if __name__ == "__main__":
    main()
