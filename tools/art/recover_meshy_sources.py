#!/usr/bin/env python3
"""Read-only recovery of existing, hash-pinned Meshy tasks. No generation or upload."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError
from inspect_meshy_glb import inspect_glb

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "docs/20_meshy_assets/ACCOUNT_RUNTIME_RECOVERY_20261127.json"
LIMIT = 200 * 1024 * 1024
API = {"text-to-3d": "/openapi/v2/text-to-3d/", "image-to-3d": "/openapi/v1/image-to-3d/"}

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

OPENER = build_opener(NoRedirect())

def candidates(rows):
    result = {}
    for row in rows:
        if (row.get("state") != "needs_source_or_derivative_review"
                or row.get("status") != "SUCCEEDED" or not row.get("has_glb")
                or row.get("api") not in API or not row.get("source_sha256")
                or row.get("role") == "duplicate_refine"
                or not 0 < int(row.get("source_bytes") or 0) <= LIMIT):
            continue
        key = row["stable_id"]
        if not re.fullmatch(r"[a-z0-9_]+", key):
            continue
        old = result.get(key)
        if old is None or (row.get("textured", False) and not old.get("textured", False)):
            result[key] = row
    return [result[k] for k in sorted(result)]

def fetch(row, key, directory):
    task = row["task_id"]
    if not re.fullmatch(r"[0-9a-f-]{36}", task):
        raise ValueError("invalid_task_id")
    with OPENER.open(Request("https://api.meshy.ai" + API[row["api"]] + task,
                             headers={"Authorization": "Bearer " + key}), timeout=30) as response:
        data = json.loads(response.read(1024 * 1024))
    if data.get("id") != task or data.get("status") != "SUCCEEDED":
        raise ValueError("task_identity_or_status_mismatch")
    url = data.get("model_urls", {}).get("glb", "")
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname != "assets.meshy.ai"
            or parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError("unapproved_asset_host")
    target = directory / (row["stable_id"] + ".glb")
    digest = hashlib.sha256()
    size = 0
    with OPENER.open(Request(url), timeout=45) as response, target.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            size += len(chunk)
            if size > row["source_bytes"] or size > LIMIT:
                raise ValueError("source_size_exceeded")
            digest.update(chunk)
            output.write(chunk)
    if size != row["source_bytes"] or digest.hexdigest() != row["source_sha256"]:
        raise ValueError("source_hash_or_size_mismatch")
    metrics = inspect_glb(target)
    if not metrics["self_contained"] or metrics["triangles"] <= 0:
        raise ValueError("invalid_source_glb")
    return target

def fetch_backup(row, directory, backup):
    """Recover only the exact pinned original; do not modify the backup."""
    task = row["task_id"]
    if not re.fullmatch(r"[0-9a-f-]{36}", task):
        raise ValueError("invalid_task_id")
    original = backup / (task + ".glb")
    target = directory / (row["stable_id"] + ".glb")
    digest = hashlib.sha256()
    size = 0
    with original.open("rb") as source, target.open("wb") as output:
        while chunk := source.read(1024 * 1024):
            size += len(chunk)
            if size > row["source_bytes"] or size > LIMIT:
                raise ValueError("source_size_exceeded")
            digest.update(chunk)
            output.write(chunk)
    if size != row["source_bytes"] or digest.hexdigest() != row["source_sha256"]:
        raise ValueError("source_hash_or_size_mismatch")
    metrics = inspect_glb(target)
    if not metrics["self_contained"] or metrics["triangles"] <= 0:
        raise ValueError("invalid_source_glb")
    return target

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--blender", default="blender")
    parser.add_argument("--local-models", type=Path, help="Private, extracted task-ID GLBs; preferred over provider downloads")
    args = parser.parse_args()
    if args.local_models is not None and not args.local_models.is_dir():
        parser.error("--local-models must be an existing directory")
    rows = candidates(json.loads(AUDIT.read_text())["rows"])
    key = os.getenv("MESHY_API_KEY", "").strip()
    dest = ROOT / "prototype/assets/meshy/recovery"
    catalog = dest.parent / "recovery_catalog.json"
    dest.mkdir(parents=True, exist_ok=True)
    report = {"mode": "existing_tasks_read_only", "credential_available": bool(key),
              "local_backup_available": args.local_models is not None,
              "requested": len(rows), "assets": []}
    families = []
    with tempfile.TemporaryDirectory(prefix="meshy-source-") as scratch:
        for row in rows:
            name = row["stable_id"]
            entry = {"stable_id": name, "task_id": row["task_id"], "source_sha256": row["source_sha256"],
                     "status": "missing_repository_credential"}
            report["assets"].append(entry)
            local = args.local_models is not None and (args.local_models / (row["task_id"] + ".glb")).is_file()
            if not local and not key:
                entry["status"] = "source_not_available"
                continue
            try:
                entry["source_origin"] = "verified_local_backup" if local else "meshy_api"
                source = fetch_backup(row, Path(scratch), args.local_models) if local else fetch(row, key, Path(scratch))
                path = dest / (name + "_1.glb")
                path.unlink(missing_ok=True)
                with tempfile.TemporaryDirectory(prefix="meshy-optimized-") as output_dir:
                    temporary = Path(output_dir) / "review.glb"
                    # No provider credential in Blender or its subprocess logs.
                    env = dict(os.environ)
                    env.pop("MESHY_API_KEY", None)
                    run = subprocess.run([args.blender, "-b", "-t", "2", "--python-exit-code", "1",
                                          "--python", str(ROOT / "tools/art/build_meshy_review.py"),
                                          "--", str(source), str(temporary)],
                                         env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)
                    if run.returncode != 0 or not temporary.is_file():
                        raise ValueError("blender_optimization_failed")
                    metrics = inspect_glb(temporary)
                    if (not metrics["self_contained"] or not 0 < metrics["triangles"] <= 12000
                            or metrics["primitives_with_normals"] != metrics["primitives"]
                            or (row.get("textured") and not metrics["static_binary_gate"])
                            or any(not item["size"] or max(item["size"]) > 1024 for item in metrics["images"])):
                        raise ValueError("optimized_glb_validation_failed")
                    path.write_bytes(temporary.read_bytes())
                entry.update(status="review_derivative_staged", triangles=metrics["triangles"],
                             sha256=metrics["sha256"], bytes=metrics["size_bytes"])
                families.append({"id": "recovered_" + name, "name": name.replace("_", " ").title(),
                                 "category": "source_review", "scale_status": "unverified_source_units",
                                 "rig_status": "review_only_not_an_npc", "source_task_id": row["task_id"],
                                 "tiers": [{"level": 1, "path": "res://assets/meshy/recovery/" + path.name}]})
            except HTTPError as exc:
                entry["status"] = "provider_http_" + str(exc.code)
            except (OSError, ValueError, subprocess.SubprocessError, TypeError, KeyError) as exc:
                # Never expose URLs, credentials, API bodies or exception text.
                entry["status"] = "recovery_failed_" + type(exc).__name__
            finally:
                (Path(scratch) / (name + ".glb")).unlink(missing_ok=True)
    report["staged"] = len(families)
    catalog.write_text(json.dumps({"format": "imperathen-meshy-recovery-catalog", "families": families}, indent=2) + "\n")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print("MESHY_RECOVERY", report["staged"], "/", report["requested"],
          "credential_available", report["credential_available"])

if __name__ == "__main__":
    main()
