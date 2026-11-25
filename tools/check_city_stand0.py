#!/usr/bin/env python3
"""Fail closed until the combined city is actually ready for release."""
import json
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs/29_city_stand0/integration.json"

def main() -> int:
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    errors = ["unresolved merge: " + r["path"] for r in report["unresolved_conflicts"]]
    for path in report["missing_required_files"]:
        target = ROOT / path
        if not target.is_file() or target.stat().st_size == 0:
            errors.append("missing city file: " + path)
    for key, passed in report["release_gates"].items():
        if passed is not True:
            errors.append("unaccepted release gate: " + key)
    if report["status"] != "RELEASE_VERIFIED":
        errors.append("combined source is not released")
    print(json.dumps({"ok": not errors, "errors": errors}, indent=2))
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
