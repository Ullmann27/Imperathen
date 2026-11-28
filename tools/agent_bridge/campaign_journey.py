#!/usr/bin/env python3
"""Deterministic campaign queue. Only the trusted coordinator may record evidence.
No model/API invocation, shell execution, Git mutation or automatic quality approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import kimi_bridge as bridge

ROOT = Path(__file__).resolve().parent
SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"[0-9a-f]{64}")
RUN = re.compile(r"[0-9]{1,24}")
DONE = {"device_pending", "accepted"}
PHASES = {"baseline", "critique", "patch", "render", "compare", "blocked", *DONE}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def write(path, value):
    path = Path(path)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)

def catalog_hash(catalog):
    return hashlib.sha256(json.dumps(catalog, sort_keys=True, ensure_ascii=False).encode()).hexdigest()

def validate_catalog(catalog):
    require(catalog.get("schema") == 1 and SHA.fullmatch(catalog.get("source_revision", "")), "Invalid catalog")
    entries = catalog.get("entries")
    require(isinstance(entries, list) and entries and entries[0]["id"] == "MENU", "Menu must be first")
    ids = set()
    for e in entries:
        require(isinstance(e["id"], str) and e["id"] not in ids, "Duplicate milestone")
        ids.add(e["id"])
        require(1 <= len(e["files"]) <= 2 and all(bridge.common.allowed_path(p) for p in e["files"]), "Source outside bridge allowlist")
        require(isinstance(e["focus"], str) and e["focus"].strip(), "Missing focus")
    return entries

def initial(catalog):
    validate_catalog(catalog)
    return {"schema": 1, "catalog_sha256": catalog_hash(catalog), "work": {}, "serial": 201}

def validate_state(catalog, state):
    entries = validate_catalog(catalog)
    require(state.get("schema") == 1 and state.get("catalog_sha256") == catalog_hash(catalog), "Catalog changed: migrate ledger explicitly")
    require(type(state.get("serial")) is int and 201 <= state["serial"] <= 9999, "Invalid task serial")
    work = state.get("work")
    require(isinstance(work, dict) and set(work) <= {e["id"] for e in entries}, "Unknown milestone")
    for item in work.values():
        require(item.get("phase") in PHASES and type(item.get("iteration")) is int and item["iteration"] >= 1, "Invalid phase")
    return entries

def current(catalog, state):
    for entry in validate_state(catalog, state):
        item = state["work"].get(entry["id"], {"phase": "baseline", "iteration": 1})
        if item["phase"] not in DONE:
            return entry, item
    return None, None

def validate_evidence(evidence):
    require(isinstance(evidence, dict), "Missing independent engine evidence")
    for key in ("source_revision", "published_revision"):
        require(isinstance(evidence.get(key), str) and SHA.fullmatch(evidence[key]), "Full source/evidence SHA required")
    require(isinstance(evidence.get("run_id"), str) and RUN.fullmatch(evidence["run_id"]), "Workflow run ID required")
    require(type(evidence.get("engine_pass")) is bool, "Explicit engine result required")
    require(isinstance(evidence.get("images"), list) and 1 <= len(evidence["images"]) <= 2, "One or two actual review images required")
    seen = set()
    total = 0
    for image in evidence["images"]:
        path = image.get("path")
        require(bridge.allowed_image(path) and path not in seen, "Invalid or duplicate review image")
        seen.add(path)
        require(isinstance(image.get("sha256"), str) and DIGEST.fullmatch(image["sha256"]), "Image checksum required")
        require(type(image.get("bytes")) is int and 1024 < image["bytes"] <= bridge.MAX_IMAGE, "Image size outside limit")
        total += image["bytes"]
    require(total <= bridge.MAX_IMAGES, "Review image budget exceeded")

def record(catalog, state, event):
    entries = validate_state(catalog, state)
    require(isinstance(event, dict) and event.get("milestone") in {e["id"] for e in entries}, "Unknown milestone event")
    entry, active = current(catalog, state)
    ident = event["milestone"]
    old = state["work"].get(ident, {"phase": "baseline", "iteration": 1})
    phase = old["phase"]
    action = event.get("action")
    require((entry is not None and ident == entry["id"]) or (phase == "device_pending" and action == "device_accept"), "Out-of-order progression")
    new = dict(old)
    if action == "baseline" and phase == "baseline":
        e = event.get("evidence")
        validate_evidence(e)
        new.update(phase="critique", baseline=e)
    elif action == "critique" and phase == "critique":
        findings = event.get("findings")
        require(isinstance(findings, str) and 1 <= len(findings) <= 3000, "Concrete independent findings required")
        new.update(phase="patch", findings=findings)
        state["serial"] += 1
    elif action == "patch" and phase == "patch":
        revision = event.get("revision")
        require(isinstance(revision, str) and SHA.fullmatch(revision), "Reviewed candidate commit required")
        require(revision != old["baseline"]["source_revision"], "V2 must be a different candidate")
        new.update(phase="render", patch_revision=revision)
        state["serial"] += 1
    elif action == "render" and phase == "render":
        e = event.get("evidence")
        validate_evidence(e)
        require(e["source_revision"] == old["patch_revision"], "V2 evidence must match the candidate commit")
        require(e["run_id"] != old["baseline"]["run_id"], "V2 requires a new execution")
        new.update(phase="compare", v2=e)
    elif action == "compare" and phase == "compare":
        verdict = event.get("verdict")
        require(verdict in {"improve", "engine_reviewed"}, "Explicit independent verdict required")
        note = event.get("findings")
        require(isinstance(note, str) and 1 <= len(note) <= 3000, "Comparison findings required")
        require(verdict != "engine_reviewed" or old["v2"]["engine_pass"], "Failed engine run cannot pass")
        if verdict == "improve":
            new.update(phase="patch", iteration=old["iteration"] + 1, baseline=old["v2"], findings=note)
            new.pop("v2", None)
            new.pop("patch_revision", None)
        else:
            new.update(phase="device_pending", findings=note)
        state["serial"] += 1
    elif action == "block" and phase not in DONE:
        reason = event.get("reason")
        require(isinstance(reason, str) and reason.strip(), "Blocker must be documented")
        new.update(phase="blocked", reason=reason, resume_phase=phase)
    elif action == "unblock" and phase == "blocked":
        require(old.get("resume_phase") in PHASES - {"blocked", *DONE}, "Invalid resume phase")
        new.update(phase=old["resume_phase"])
        new.pop("reason", None)
        new.pop("resume_phase", None)
    elif action == "device_accept" and phase == "device_pending":
        require(event.get("physical_fold7_pass") is True and event.get("visual_review_pass") is True, "Physical and independent visual results required")
        require(isinstance(event.get("receipt_sha256"), str) and DIGEST.fullmatch(event["receipt_sha256"]), "Device receipt checksum required")
        require(event.get("source_revision") == old["v2"]["source_revision"], "Device receipt must match reviewed candidate")
        require(isinstance(event.get("run_id"), str) and RUN.fullmatch(event["run_id"]), "Device run ID required")
        new.update(phase="accepted", device_receipt={k: event[k] for k in ("receipt_sha256","source_revision","run_id")})
    else:
        raise ValueError("Invalid evidence transition")
    state["work"][ident] = new
    return state

def plan(catalog, state):
    entry, item = current(catalog, state)
    if entry is None:
        return {"action": "device_and_full_campaign_audit", "device_pending": [k for k,v in state["work"].items() if v["phase"]=="device_pending"]}
    phase = item["phase"]
    result = {"milestone": entry["id"], "title": entry["title"], "phase": phase, "iteration": item["iteration"]}
    if phase in {"baseline", "render", "blocked"}:
        result.update(action={"baseline": "capture_actual_game", "render": "render_reviewed_candidate", "blocked": "resolve_blocker"}[phase])
        if phase == "baseline":
            result["preferred_baseline_images"] = entry.get("baseline_images", [])
        if phase == "render":
            result["revision"] = item["patch_revision"]
        if phase == "blocked":
            result["reason"] = item["reason"]
        return result
    e = item["v2"] if phase == "compare" else item["baseline"]
    validate_evidence(e)
    note = item.get("findings", "")
    scope = ("Kritisiere exakt einen schwerwiegenden, aus diesen realen Aufnahmen und Quellen belegbaren Mangel."
             if phase == "critique" else "Liefere genau einen kleinen vollständigen Patch zur Behebung des dokumentierten Mangels."
             if phase == "patch" else "Vergleiche die gekennzeichneten V1- und V2-Aufnahmen direkt. Benenne sichtbare Verbesserungen, Regressionen und verbleibende Mängel; unabhängige Abnahme bleibt bei der Koordination.")
    task = {"revision": e["published_revision"],
            "task": f"{entry['id']} – {entry['title']}. {entry['focus']}\n{scope}\nBisherige unabhängige Befunde: {note or 'noch offen'}.\n"
                    "REALISM QUALITY GATE: historische/anatomische Plausibilität, PBR, reale V1/V2-Bilder, Animationen, persistente Spielautorität, Fold7-Profile. Keine erfundenen Test- oder Geräteergebnisse. Keine Änderung der CI oder Rechte.",
            "files": entry["files"], "images": [i["path"] for i in e["images"]],
            "max_tokens": 16384, "reasoning_effort": "max", "response_mode": "json"}
    # Use verified checksums even in the first review. For comparison, choose
    # the same capture name in both revisions where available.
    def image_ref(evidence, image, label):
        return {"revision": evidence["published_revision"], "path": image["path"],
                "sha256": image["sha256"], "label": label}
    if phase == "compare":
        old = item["baseline"]
        validate_evidence(old)
        pairs = [(a, b) for a in old["images"] for b in e["images"]
                 if Path(a["path"]).name == Path(b["path"]).name]
        require(pairs, "A comparable V1/V2 capture is required")
        a, b = pairs[0]
        task["evidence_images"] = [image_ref(old, a, "V1"), image_ref(e, b, "V2")]
    else:
        task["evidence_images"] = [image_ref(e, image, "baseline") for image in e["images"]]
    task["images"] = []
    bridge.validate_task(task)
    result.update(action="kimi_candidate", manifest={f"K{state['serial']}": task})
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["init", "plan", "record"])
    parser.add_argument("--catalog", type=Path, default=ROOT / "campaign_journey_catalog.json")
    parser.add_argument("--state", type=Path, default=ROOT / "campaign_journey_state.json")
    parser.add_argument("--event", type=Path)
    parser.add_argument("--manifest-out", type=Path)
    args = parser.parse_args()
    try:
        catalog = load(args.catalog)
        if args.command == "init":
            require(not args.state.exists(), "Refusing to overwrite an existing ledger")
            write(args.state, initial(catalog))
            return 0
        state = load(args.state)
        if args.command == "record":
            require(args.event is not None, "Independent event JSON required")
            write(args.state, record(catalog, state, load(args.event)))
        else:
            decision = plan(catalog, state)
            if args.manifest_out:
                require("manifest" in decision, "No model task is authorized by the current phase")
                write(args.manifest_out, decision["manifest"])
            print(json.dumps(decision, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, KeyError, TypeError, OSError, bridge.common.BridgeError) as error:
        print("JOURNEY_BLOCKED", str(error), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
