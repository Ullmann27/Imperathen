#!/usr/bin/env python3
"""Read only Unity Asset Manager REST API with service-account Basic auth.
No raw API response, token, project ID, or organization ID is printed or stored.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import HTTPRedirectHandler, Request, build_opener

ORGANIZATION_ID_PATTERN = re.compile(r"(?:[0-9]{4,20}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")
EXPLICIT_ORGANIZATION_KEYS = {
    "activeOrganizationId", "activeCloudOrganizationId",
    "organizationGenesisId", "organizationId", "orgGenesisId"
}
NESTED_ORG_KEYS = {"organization", "activeOrganization", "activeOrg"}

class RefuseRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def _org_id_from_data(obj):
    """Only trusted explicit org-id keys. Never fall back to unlabelled IDs."""
    if isinstance(obj, dict):
        for key in EXPLICIT_ORGANIZATION_KEYS:
            candidate = obj.get(key)
            if isinstance(candidate, str) and ORGANIZATION_ID_PATTERN.fullmatch(candidate):
                return candidate
            if isinstance(candidate, int) and ORGANIZATION_ID_PATTERN.fullmatch(str(candidate)):
                return str(candidate)
        for key in NESTED_ORG_KEYS:
            value = obj.get(key)
            if isinstance(value, dict):
                candidate = value.get("genesisId") or value.get("id")
                if isinstance(candidate, (str, int)) and ORGANIZATION_ID_PATTERN.fullmatch(str(candidate)):
                    return str(candidate)
        # Controlled recursive traversal only through the documented data envelope.
        if isinstance(obj.get("data"), dict):
            return _org_id_from_data(obj["data"])
    return None

def discover_org_id(unity):
    explicit = os.getenv("UNITY_CLOUD_ORG_ID", "").strip()
    if explicit and ORGANIZATION_ID_PATTERN.fullmatch(explicit):
        return explicit, "ENV"
    for args in (
        ["cloud", "status", "--format", "json"],
        ["cloud", "org", "current", "--format", "json"],
    ):
        try:
            proc = subprocess.run([unity, "--non-interactive", *args],
                                  check=False, capture_output=True, text=True, timeout=20)
            if proc.returncode == 0:
                result = _org_id_from_data(json.loads(proc.stdout))
                if result:
                    return result, "CLI"
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    return None, "UNKNOWN"

def check_api(org_id: str, key_id: str, secret: str) -> dict:
    if not ORGANIZATION_ID_PATTERN.fullmatch(org_id):
        return {"result": "ORG_ID_INVALID"}
    # Unity's documented Asset Manager API supports Basic service account auth.
    auth = base64.b64encode(f"{key_id}:{secret}".encode("utf-8")).decode("ascii")
    url = ("https://services.api.unity.com/assets/v1/organizations/"
           + quote(org_id, safe="") + "/projects?Limit=50")
    req = Request(url, method="GET", headers={
        "Authorization": "Basic " + auth,
        "Accept": "application/json",
        "User-Agent": "Imperathen-GitHub-Readonly/1.0"
    })
    opener = build_opener(RefuseRedirects)
    try:
        with opener.open(req, timeout=25) as response:
            if response.status != 200:
                return {"result": "HTTP_" + str(response.status)}
            raw = response.read(128 * 1024 + 1)
            if len(raw) > 128 * 1024:
                return {"result": "RESPONSE_TOO_LARGE"}
            data = json.loads(raw)
    except HTTPError as exc:
        # Never inspect/print the error body's potentially private data.
        return {"result": "HTTP_" + str(exc.code)}
    except (URLError, TimeoutError, OSError):
        return {"result": "NETWORK_ERROR"}
    except (ValueError, UnicodeError):
        return {"result": "INVALID_JSON"}
    projects = data.get("projects") if isinstance(data, dict) else None
    if not isinstance(projects, list):
        return {"result": "INVALID_RESPONSE_SHAPE"}
    seen = any(
        isinstance(p, dict) and str(p.get("name", "")).strip().casefold() == "imperathen"
        for p in projects
    )
    count = len(projects)
    # Count is safe diagnostic metadata; do not expose project names, IDs, or Cloud metadata.
    return {"result": ("IMPERATHEN_VISIBLE" if seen else "NO_PROJECTS_VISIBLE" if count == 0
                       else "IMPERATHEN_NOT_IN_RETURNED_PAGE"),
            "project_seen": seen, "project_count_on_page": count}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--unity", default="unity")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    secret = os.getenv("UNITY_SERVICE_ACCOUNT_SECRET", "")
    key = os.getenv("UNITY_SERVICE_ACCOUNT_ID", "")
    output = {"schema": 1, "provider": "unity_asset_manager_api", "read_only": True}
    if not key or not secret:
        output["result"] = "SECRETS_MISSING"
    else:
        org, origin = discover_org_id(args.unity)
        output["org_id_source"] = origin
        output["org_id_available"] = bool(org)
        if not org:
            output["result"] = "ORGANIZATION_ID_REQUIRED"
        else:
            output.update(check_api(org, key, secret))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print("UNITY_ASSET_MANAGER_API", output["result"])

if __name__ == "__main__":
    main()
