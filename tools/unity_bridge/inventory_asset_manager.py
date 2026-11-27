#!/usr/bin/env python3
"""Read-only inventory of the real IMPERATHEN Unity Asset Manager project."""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, build_opener

from probe_asset_manager_api import ORGANIZATION_ID_PATTERN, RefuseRedirects

UUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\Z")
HOST = "https://services.api.unity.com"

def _read_json(opener, path, auth):
    request = Request(HOST + path, method="GET", headers={
        "Authorization": "Basic " + auth,
        "Accept": "application/json",
        "User-Agent": "Imperathen-Asset-Inventory/1.0"
    })
    try:
        with opener.open(request, timeout=30) as response:
            if response.status != 200:
                return None, "HTTP_" + str(response.status)
            raw = response.read(256 * 1024 + 1)
    except HTTPError as exc:
        return None, "HTTP_" + str(exc.code)
    except (URLError, OSError, TimeoutError):
        return None, "NETWORK_ERROR"
    if len(raw) > 256 * 1024:
        return None, "RESPONSE_TOO_LARGE"
    try:
        return json.loads(raw), "OK"
    except (ValueError, UnicodeError):
        return None, "INVALID_JSON"

def inventory(org: str, key_id: str, secret: str, opener=None) -> dict:
    report = {"schema": 1, "provider": "unity_asset_manager_api",
              "read_only": True, "project": "Imperathen", "project_visible": False}
    if not ORGANIZATION_ID_PATTERN.fullmatch(org) or not key_id or not secret:
        report["result"] = "MISSING_OR_INVALID_CONFIGURATION"
        return report
    encoded = base64.b64encode((key_id + ":" + secret).encode("utf-8")).decode("ascii")
    client = opener or build_opener(RefuseRedirects)
    project_data, status = _read_json(
        client, "/assets/v1/organizations/" + quote(org, safe="") + "/projects?Limit=100", encoded
    )
    if status != "OK":
        report["result"] = "PROJECT_QUERY_" + status
        return report
    projects = project_data.get("projects") if isinstance(project_data, dict) else None
    if not isinstance(projects, list):
        report["result"] = "INVALID_PROJECT_SHAPE"
        return report
    matches = [
        p for p in projects if isinstance(p, dict) and
        str(p.get("name", "")).strip().casefold() == "imperathen"
    ]
    if len(matches) != 1:
        report["result"] = "PROJECT_AMBIGUOUS" if matches else "PROJECT_NOT_VISIBLE"
        return report
    report["project_visible"] = True
    project_id = matches[0].get("id")
    if not isinstance(project_id, str) or not UUID.fullmatch(project_id):
        report["result"] = "INVALID_PROJECT_ID"
        return report
    count, status = _read_json(
        client, "/assets/v1/projects/" + quote(project_id, safe="") + "/assets/count", encoded
    )
    if status != "OK":
        report["result"] = "ASSET_COUNT_QUERY_" + status
        return report
    value = count.get("count") if isinstance(count, dict) else None
    if type(value) is not int or value < 0:
        report["result"] = "INVALID_COUNT_SHAPE"
    else:
        report["result"] = "ASSET_INVENTORY_CONFIRMED"
        report["asset_count"] = value
    return report

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    result = inventory(
        os.environ.get("UNITY_CLOUD_ORG_ID", ""),
        os.environ.get("UNITY_SERVICE_ACCOUNT_ID", ""),
        os.environ.get("UNITY_SERVICE_ACCOUNT_SECRET", ""),
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("IMPERATHEN_UNITY_INVENTORY", result["result"])
    if "asset_count" in result:
        print("IMPERATHEN_UNITY_ASSET_COUNT", result["asset_count"])
    # Do not publish Unity IDs, tokens, asset names or raw API responses.

if __name__ == "__main__":
    main()
