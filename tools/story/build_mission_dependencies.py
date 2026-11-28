#!/usr/bin/env python3
"""Build a source-limited inventory of campaign mission records."""

import argparse
import csv
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARC_PATH = ROOT / "prototype/assets/story/campaign_arc.json"
MISSIONS_DIR = ROOT / "prototype/assets/story/missions/band1"
OUTPUT_PATH = ROOT / "docs/GENESIS/mission_dependencies.tsv"
BANDS = (("I", 32), ("II", 25), ("III", 25), ("IV", 31))
INSTALLED_IDS = {f"I-{number:02d}" for number in range(1, 15)}
DEPENDENCY_KEYS = {"dependency", "dependencies", "depends", "depends_on", "predecessor", "predecessors"}
PREREQUISITE_KEYS = {
    "prerequisite",
    "prerequisites",
    "precondition",
    "preconditions",
    "required_mission",
    "required_missions",
    "requires",
    "requires_mission",
    "requires_missions",
    "gated_by",
    "unlocks_after",
}
CHOICE_KEYS = {"choice", "choices"}
FIELDS = (
    "mission_id",
    "band",
    "title",
    "registry_status",
    "registry_source",
    "runtime_source",
    "explicit_dependencies",
    "explicit_choices",
    "explicit_prerequisites",
    "unknowns",
)


def compact(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def collect_relations(value):
    found = {"dependencies": [], "choices": [], "prerequisites": []}

    def visit(node, path="$"):
        if isinstance(node, dict):
            for key, child in node.items():
                normalized = key.lower().replace("-", "_").replace(" ", "_")
                child_path = f"{path}.{key}"
                if normalized in DEPENDENCY_KEYS:
                    found["dependencies"].append(f"{child_path}={compact(child)}")
                if normalized in PREREQUISITE_KEYS:
                    found["prerequisites"].append(f"{child_path}={compact(child)}")
                if (
                    normalized in CHOICE_KEYS
                    or normalized.endswith(("_choice", "_choices"))
                    or ".choice." in normalized
                ):
                    found["choices"].append(child_path)
                if normalized == "id" and isinstance(child, str) and "choice" in child.lower():
                    found["choices"].append(f"{child_path}={child}")
                visit(child, child_path)
        elif isinstance(node, list):
            for index, child in enumerate(node):
                visit(child, f"{path}[{index}]")

    visit(value, "$")
    return {key: sorted(set(items)) for key, items in found.items()}


def relation_cell(items):
    return "; ".join(items) if items else "none_explicit_in_scoped_json"


def merge_relations(*sources):
    merged = {"dependencies": [], "choices": [], "prerequisites": []}
    for source in sources:
        for key, values in collect_relations(source).items():
            merged[key].extend(values)
    return {key: sorted(set(values)) for key, values in merged.items()}


def load_records():
    arc = json.loads(ARC_PATH.read_text(encoding="utf-8"))
    if not isinstance(arc.get("bands"), list):
        raise ValueError("campaign_arc.json has no bands array")

    band_names = [band.get("roman") for band in arc["bands"]]
    if band_names != [name for name, _ in BANDS]:
        raise ValueError(f"expected campaign bands {[name for name, _ in BANDS]}, got {band_names}")
    bands = {band["roman"]: band for band in arc["bands"]}

    installed_paths = sorted(path for path in MISSIONS_DIR.glob("I-*.json") if path.name != "index.json")
    expected_paths = {f"{mission_id}.json" for mission_id in INSTALLED_IDS}
    actual_paths = {path.name for path in installed_paths}
    if actual_paths != expected_paths:
        raise ValueError(
            "installed mission JSON inventory changed: "
            f"missing={sorted(expected_paths - actual_paths)}, extra={sorted(actual_paths - expected_paths)}"
        )
    if (MISSIONS_DIR / "I-00.json").exists():
        raise ValueError("I-00 is expected to remain a special registry record, not an installed mission JSON")

    runtime_data = {}
    for path in installed_paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        mission_id = data.get("mission")
        if mission_id not in INSTALLED_IDS or path.stem != mission_id:
            raise ValueError(f"mission ID/path mismatch in {path.relative_to(ROOT)}")
        runtime_data[mission_id] = data

    rows = []
    seen = set()
    for band_name, expected_count in BANDS:
        band = bands[band_name]
        missions = band.get("main_missions")
        if not isinstance(missions, list) or len(missions) != expected_count:
            raise ValueError(f"Band {band_name} expected {expected_count} main missions")
        for number, record in enumerate(missions):
            mission_id = record.get("id")
            expected_id = f"{band_name}-{number:02d}"
            if mission_id != expected_id or mission_id in seen:
                raise ValueError(f"expected unique {expected_id}, got {mission_id!r}")
            if not isinstance(record.get("title"), str) or not record["title"].strip():
                raise ValueError(f"missing title for {mission_id}")
            seen.add(mission_id)

            runtime = runtime_data.get(mission_id)
            if mission_id == "I-00":
                status = "special_registry_only"
            elif runtime:
                status = "installed_json_present"
            else:
                status = "registry_only"

            registry_ref = (
                f"prototype/assets/story/campaign_arc.json#bands[{band_name}]"
                f".main_missions[id={mission_id}]"
            )
            runtime_ref = (
                f"prototype/assets/story/missions/band1/{mission_id}.json" if runtime else ""
            )
            relations = merge_relations(record, runtime) if runtime else merge_relations(record)

            if status == "special_registry_only":
                unknowns = (
                    "I-00 is a special registry entry; no mission JSON is installed, so runtime behavior "
                    "and gates are unknown; source screenplay originals are absent from this checkout."
                )
            elif status == "registry_only":
                unknowns = (
                    "No mission JSON is installed for this ID; runtime behavior, choices, dependencies, "
                    "and prerequisites are unknown; source screenplay originals are absent from this checkout."
                )
            else:
                unknowns = (
                    "Only structured fields in the registry and installed JSON are inventoried; "
                    "implicit/script-side gates and screenplay context are unknown; source screenplay "
                    "originals are absent from this checkout. JSON presence is not proof of complete "
                    "playable implementation."
                )

            rows.append(
                {
                    "mission_id": mission_id,
                    "band": band_name,
                    "title": record["title"],
                    "registry_status": status,
                    "registry_source": registry_ref,
                    "runtime_source": runtime_ref,
                    "explicit_dependencies": relation_cell(relations["dependencies"]),
                    "explicit_choices": relation_cell(relations["choices"]),
                    "explicit_prerequisites": relation_cell(relations["prerequisites"]),
                    "unknowns": unknowns,
                }
            )

    if len(rows) != 113:
        raise ValueError(f"expected 113 main-mission records, got {len(rows)}")
    return rows


def render(rows):
    from io import StringIO

    output = StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the checked-in TSV is stale")
    args = parser.parse_args()
    try:
        rows = load_records()
        content = render(rows)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"mission inventory error: {error}", file=sys.stderr)
        return 1

    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_text(encoding="utf-8") != content:
            print(f"stale or missing generated inventory: {OUTPUT_PATH.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print("mission inventory is current (113 main missions)")
        return 0

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(content, encoding="utf-8")
    print(f"wrote {OUTPUT_PATH.relative_to(ROOT)} ({len(rows)} main missions)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
