#!/usr/bin/env python3
"""Reconcile published agent branches with real Git merges, never main.

Only the dedicated recovery branch can receive commits. No code from candidate
trees is executed by this job. Runtime and release gates remain independent.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request

REPO = "Ullmann27/Imperathen"
BRANCH = "integration/imperathen-player-visible-recovery-20261126"
REPORT = "docs/44_integration/PUBLISHED_AGENT_RECOVERY.json"
PROTECTED = (
    ".github/workflows/", "docs/00_governance/", "quality/",
    "tools/validate_android_apk.py", "tools/build_unreleased_city_qa.py",
    "prototype/export_presets.cfg", "prototype/project.godot",
    "AGENTS.md", "tools/integration/recover_published_agent_work.py",
)

def git(*args, check=True, env=None):
    return subprocess.run(
        ["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false", *args],
        capture_output=True, text=True, check=check, env=env, timeout=360,
    )

def sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise RuntimeError("Invalid Git object identifier")
    return value

def ancestor(old, new):
    result = git("merge-base", "--is-ancestor", old, new, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr)
    return result.returncode == 0

def pull_heads():
    result = {}
    page = 1
    while True:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{REPO}/pulls?state=open&per_page=100&page={page}",
            headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"],
                     "Accept": "application/vnd.github+json", "User-Agent": "imperathen-recovery"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            values = json.load(response)
        for item in values:
            source = item["head"]
            if source.get("repo") and source["repo"]["full_name"].lower() == REPO.lower():
                result[source["ref"]] = {"pr": int(item["number"]), "sha": sha(source["sha"])}
        if len(values) < 100:
            return result
        page += 1

def commit(tree, parents, message):
    args = ["commit-tree", sha(tree)]
    for parent in parents:
        args.extend(["-p", sha(parent)])
    return sha(git(*args, "-m", message).stdout.strip())

def changed_paths(current, tree):
    output = git("diff", "--name-status", "--no-renames", "-z", current, tree).stdout
    fields = output.rstrip("\0").split("\0") if output else []
    if len(fields) % 2:
        raise RuntimeError("Unexpected Git diff output")
    return [{"status": fields[i], "path": fields[i + 1]} for i in range(0, len(fields), 2)]

def protected(item):
    path = item["path"]
    return any(path == p or path.startswith(p.rstrip("/") + "/") for p in PROTECTED) or (
        item["status"] == "D" and path.startswith("prototype/")
    )

def report_commit(current, report):
    blob = sha(git("hash-object", "-w", str(report)).stdout.strip())
    with tempfile.TemporaryDirectory(prefix="imperathen-recovery-") as directory:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(directory) / "index"))
        git("read-tree", current, env=env)
        git("update-index", "--add", "--cacheinfo", f"100644,{blob},{REPORT}", env=env)
        tree = sha(git("write-tree", env=env).stdout.strip())
    return commit(tree, [current], "Record source coverage and unresolved agent integration blockers")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    start = sha(args.expected_head)
    if os.environ.get("GITHUB_REPOSITORY") != REPO or os.environ.get("GITHUB_REF_NAME") != BRANCH:
        raise SystemExit("Only the isolated IMPERATHEN recovery branch is permitted")
    if git("rev-parse", "HEAD").stdout.strip() != start:
        raise SystemExit("Unexpected starting revision")
    git("config", "user.name", "imperathen-recovery")
    git("config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    git("fetch", "--no-tags", "--prune", "--filter=blob:none", "origin",
        "+refs/heads/*:refs/remotes/origin/*")
    refs = {}
    for line in git("for-each-ref", "--format=%(refname:strip=3)%09%(objectname)",
                    "refs/remotes/origin").stdout.splitlines():
        name, revision = line.split("\t", 1)
        if name != "HEAD":
            refs[name] = sha(revision)
    if refs.get(BRANCH) != start:
        raise SystemExit("Recovery branch advanced; refuse stale write")
    prs = pull_heads()
    races = [{"branch": name, "pr": item["pr"], "listed_head": item["sha"], "snapshot": refs.get(name)}
             for name, item in prs.items() if refs.get(name) != item["sha"]]
    order = sorted(refs, key=lambda name: (name not in prs, prs.get(name, {}).get("pr", 10**9), name))
    current = start
    rows = []
    for name in order:
        source = refs[name]
        row = {"branch": name, "sha": source, "pr": prs.get(name, {}).get("pr")}
        rows.append(row)
        if ancestor(source, current):
            row["status"] = "ancestor"
            continue
        result = git("merge-tree", "--write-tree", "--name-only", "--messages", current, source, check=False)
        lines = result.stdout.splitlines()
        if result.returncode == 1:
            conflicts = []
            for line in lines[1:]:
                if not line.strip():
                    break
                conflicts.append(line)
            row.update(status="conflict", conflict_paths=conflicts, diagnostic=result.stdout[-5000:])
            continue
        if result.returncode != 0 or not lines:
            row.update(status="merge_error", diagnostic=result.stderr[-5000:])
            continue
        tree = sha(lines[0].strip())
        diff = changed_paths(current, tree)
        row["changes"] = diff
        if not diff:
            row["status"] = "tree_equivalent"
            continue
        if name == "main" or (name not in prs and not name.endswith("20261126")):
            row["status"] = "historical_unique_review"
            continue
        held = [item["path"] for item in diff if protected(item)]
        if held:
            row.update(status="protected_review", protected_paths=held)
            continue
        current = commit(tree, [current, source], "Recover agent branch " + name + " (source integration; QA pending)")
        row.update(status="merged_clean", integration_commit=current)
    for row in rows:
        row["final_ancestry"] = ancestor(row["sha"], current)
    unresolved = [row for row in rows if row["status"] not in ("ancestor", "tree_equivalent", "merged_clean")
                  and not row["final_ancestry"]]
    report = {
        "repository": REPO, "branch": BRANCH, "start": start, "recovered_code_head": current,
        "remote_heads_audited": len(rows), "clean_source_merges": sum(row["status"] == "merged_clean" for row in rows),
        "source_snapshot_races": races, "unresolved_count": len(unresolved),
        "release_approved": False, "runtime_tests_passed": False, "branches": rows,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    final = report_commit(current, args.report)
    remote = git("ls-remote", "--heads", "origin", "refs/heads/" + BRANCH).stdout.split()
    if len(remote) != 2 or remote[0] != start or not ancestor(start, final):
        raise SystemExit("Remote moved: report retained; no push")
    git("push", "origin", final + ":refs/heads/" + BRANCH)
    print(json.dumps({"recovery_commit": final, "heads": len(rows), "clean_merges": report["clean_source_merges"],
                      "unresolved": len(unresolved), "snapshot_races": len(races), "release_approved": False}))
    return 1 if unresolved or races else 0

if __name__ == "__main__":
    raise SystemExit(main())
