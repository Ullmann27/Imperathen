#!/usr/bin/env python3
"""Read-only, unlimited branch and Godot literal-reference coverage audit.

Compare source changes against the actual target tree, not merely merge
ancestry. Never check out or execute source branches; never push or release.
Literal reference coverage is a review heuristic, not runtime verification.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
from datetime import date, datetime, timedelta
import json
from pathlib import Path
import re
import subprocess
from zoneinfo import ZoneInfo

RESOURCE = re.compile(r"""res://[^\s"'<>),;\]\}]+""")
RUNTIME_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json",
               ".glb", ".gltf", ".ogg", ".wav", ".mp3", ".png", ".jpg", ".webp", ".svg"}
PROTECTED = (".github/", "quality/", "docs/00_governance/", "AGENTS.md",
             "prototype/project.godot", "prototype/export_presets.cfg",
             "tools/validate_android_apk.py", "tools/build_unreleased_city_qa.py")


def git(*args, ok=(0,)):
    result = subprocess.run(["git", "--no-replace-objects", *args], check=False,
                            capture_output=True, encoding="utf-8", errors="surrogateescape",
                            timeout=300)
    if result.returncode not in ok:
        raise RuntimeError(f"git {args[0]} exited {result.returncode}: {result.stderr[-2000:]}")
    return result


def tree(revision):
    entries = {}
    for line in git("ls-tree", "-r", "-z", "--full-tree", revision).stdout.split("\0"):
        if not line:
            continue
        metadata, path = line.split("\t", 1)
        mode, kind, oid = metadata.split()
        entries[path] = (mode, kind, oid)
    return entries


def classify(base, source, target):
    if source == base:
        return "unchanged_in_source"
    if source == target:
        return "exact_in_target"
    if source is None:
        return "source_deletion_review"
    if target is None:
        return "source_only_addition" if base is None else "removed_from_target_review"
    if target == base:
        return "source_change_not_applied"
    return "diverged_review"


def runtime_candidate(path):
    return (path.startswith("prototype/") and not path.startswith(
            ("prototype/tests/", "prototype/scripts/tests/"))
            and Path(path).suffix.lower() in RUNTIME_EXT)


def resource_paths(line):
    return {"prototype/" + match[6:].rstrip(".") for match in RESOURCE.findall(line)}


def reachable(graph, roots):
    seen = set()
    todo = deque(roots)
    while todo:
        path = todo.popleft()
        if path in seen:
            continue
        seen.add(path)
        todo.extend(graph.get(path, ()))
    return seen


def reference_index(target, entries):
    graph = defaultdict(set)
    incoming = defaultdict(set)
    missing = defaultdict(set)
    result = git("grep", "-n", "-I", "-F", "-e", "res://", target, "--", "prototype", ok=(0, 1))
    for line in result.stdout.splitlines():
        parts = line.split(":", 3)
        if len(parts) != 4 or not parts[2].isdigit():
            continue
        _, owner, _, content = parts
        for path in resource_paths(content):
            if path in entries:
                graph[owner].add(path)
                incoming[path].add(owner)
            elif Path(path).suffix.lower() in RUNTIME_EXT and "%" not in path:
                missing[path].add(owner)
    # Main scene and autoload paths are read from the actual project settings.
    # Other scene roots must be reached through literal references to qualify.
    roots = ["prototype/project.godot"]
    live = reachable(graph, roots)
    return incoming, live, missing


def reference_status(path, incoming, live):
    if path in live:
        return "literal_reachable_from_project"
    owners = incoming.get(path, set())
    if any(runtime_candidate(owner) for owner in owners):
        return "runtime_literal_reference_not_reachability_proof"
    if owners:
        return "non_runtime_literal_reference_only"
    return "no_literal_reference_dynamic_load_possible"


def inspect(target, report, start, end):
    target = git("rev-parse", "--verify", target + "^{commit}").stdout.strip()
    target_tree = tree(target)
    incoming, live, missing = reference_index(target, target_tree)
    by_blob = defaultdict(list)
    for path, entry in target_tree.items():
        by_blob[entry].append(path)
    refs = {}
    for line in git("for-each-ref", "--format=%(refname:strip=3)%09%(objectname)",
                    "refs/remotes/origin").stdout.splitlines():
        name, oid = line.split("\t", 1)
        if name != "HEAD":
            refs[name] = oid
    if not refs:
        raise RuntimeError("No remote branches fetched")
    rows = []
    unresolved = defaultdict(set)
    cache = {}
    totals = Counter()
    vienna = ZoneInfo("Europe/Vienna")
    start_date, end_date = date.fromisoformat(start), date.fromisoformat(end)
    if end_date <= start_date:
        raise ValueError("Empty focus window")
    stamps = [(start_date + timedelta(days=i)).strftime("%Y%m%d") for i in range((end_date - start_date).days)]
    for name, source in sorted(refs.items()):
        tip_date = datetime.fromisoformat(git("show", "-s", "--format=%cI", source).stdout.strip()).astimezone(vienna)
        recent = start_date <= tip_date.date() < end_date or any(stamp in name for stamp in stamps)
        merge_bases = git("merge-base", "--all", target, source, ok=(0, 1)).stdout.splitlines()
        row = {"branch": name, "source_sha": source, "tip_local_time": tip_date.isoformat(),
               "focus_window": recent, "merge_bases": merge_bases, "files": []}
        rows.append(row)
        if not merge_bases:
            row["status"] = "no_common_ancestor_review"
            continue
        if source in merge_bases:
            row["status"] = "ancestor"
            continue
        base = sorted(merge_bases)[0]
        if base not in cache:
            cache[base] = tree(base)
        base_tree = cache[base]
        source_tree = tree(source)
        counts = Counter()
        for path in sorted(set(base_tree) | set(source_tree)):
            old, src, dst = base_tree.get(path), source_tree.get(path), target_tree.get(path)
            status = classify(old, src, dst)
            if status == "unchanged_in_source":
                continue
            counts[status] += 1
            entry = {"path": path, "status": status, "base": old, "source": src, "target": dst,
                     "protected": any(path == p or path.startswith(p.rstrip("/") + "/") for p in PROTECTED)}
            if runtime_candidate(path):
                entry["reference_status"] = reference_status(path, incoming, live)
                entry["reference_owners"] = sorted(incoming.get(path, ()))
            if src and status != "exact_in_target":
                entry["same_blob_other_paths"] = [p for p in by_blob.get(src, []) if p != path]
            if status != "exact_in_target":
                unresolved[path].add(name)
            row["files"].append(entry)
        row["counts"] = dict(counts)
        row["status"] = "exact_source_changes" if set(counts) <= {"exact_in_target"} else "review"
        totals.update(counts)
    candidates = [{"path": p, "reference_status": reference_status(p, incoming, live),
                   "reference_owners": sorted(incoming.get(p, ()))}
                  for p in sorted(target_tree) if runtime_candidate(p)]
    data = {"target_sha": target, "remote_heads_audited": len(rows),
            "focus_window": [start, end], "branch_status_counts": dict(Counter(r["status"] for r in rows)),
            "focus_branch_count": sum(r["focus_window"] for r in rows),
            "changed_path_occurrences": dict(totals), "unique_review_paths": len(unresolved),
            "unique_review_path_sources": {p: sorted(v) for p, v in sorted(unresolved.items())},
            "literal_reference_candidates": candidates,
            "missing_literal_reference_candidates": {p: sorted(v) for p, v in sorted(missing.items())},
            "limitations": ["A differing blob may be a valid later implementation; do not overwrite it blindly.",
                            "Multiple merge bases are reported; the lexically first is used for the file comparison.",
                            "Literal paths miss dynamic loaders, class_name links, generated assets and registries.",
                            "No runtime test, merge, build or release is implied by source coverage."],
            "branches": rows}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps({k: data[k] for k in ("target_sha", "remote_heads_audited", "focus_branch_count",
                                            "branch_status_counts", "unique_review_paths",
                                            "changed_path_occurrences")}, indent=2))


def self_test():
    a, b, c = ("100644", "blob", "a"), ("100644", "blob", "b"), ("100644", "blob", "c")
    assert classify(a, a, c) == "unchanged_in_source"
    assert classify(a, b, b) == "exact_in_target"
    assert classify(None, b, None) == "source_only_addition"
    assert classify(a, b, None) == "removed_from_target_review"
    assert classify(a, b, a) == "source_change_not_applied"
    assert classify(a, b, c) == "diverged_review"
    assert classify(a, None, b) == "source_deletion_review"
    assert classify(a, None, None) == "exact_in_target"
    assert resource_paths('const X = preload("res://scripts/example.gd")') == {"prototype/scripts/example.gd"}
    assert reachable({"project": {"main"}, "main": {"project", "asset"}}, ["project"]) == {"project", "main", "asset"}
    assert reference_status("asset", {}, {"asset"}) == "literal_reachable_from_project"
    assert not runtime_candidate("prototype/tests/example.gd")
    print("AGENT_RUNTIME_COVERAGE_SELF_TEST_PASS")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--since", default="2026-11-25")
    parser.add_argument("--until", default="2026-11-27")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.target or not args.report:
        parser.error("--target and --report are required")
    inspect(args.target, args.report, args.since, args.until)


if __name__ == "__main__":
    main()
