#!/usr/bin/env python3
"""Local three-agent coordination. No model APIs, credentials or shell commands."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "coordination/tasks.json"
LOCAL = "coordination/.local"
IGNORED = {".git", ".local", "node_modules", "__pycache__", "dist", ".godot"}
# Commands are code-owned argument arrays, never executable manifest strings.
CHECKS = {
    "frontend-syntax": (["node", "--check", "preview/app.mjs"], ["preview/app.mjs"]),
    "core-tests": (["node", "--test", "tests/core.test.mjs"], ["tests/core.test.mjs"]),
    "pipeline-tests": ([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "pipeline_test.py"], ["tests/pipeline_test.py"]),
    "unreal-static": ([sys.executable, "tools/verify_unreal.py"], ["tools/verify_unreal.py"]),
}


class PipelineError(Exception):
    """An actionable coordination or input error."""


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def safe_path(root, value, pattern=False):
    if not isinstance(value, str) or not value:
        raise PipelineError("Ein Pfad muss eine nichtleere Zeichenfolge sein.")
    clean = value[:-3] if pattern and value.endswith("/**") else value
    if (not clean or "\\" in clean or not re.fullmatch(r"[A-Za-z0-9_.@/-]+", clean)
            or any(part in ("", ".", "..") for part in clean.split("/"))
            or PurePosixPath(clean).is_absolute()):
        raise PipelineError(f"Unzulässiger relativer Pfad: {value!r}")
    path = (root / clean).resolve()
    if not path.is_relative_to(root.resolve()):
        raise PipelineError(f"Pfad verlässt das Repository: {value}")
    return path


def matches(path, pattern):
    return path == pattern or (pattern.endswith("/**") and
           (path == pattern[:-3] or path.startswith(pattern[:-3] + "/")))


def overlaps(left, right):
    return matches(left.removesuffix("/**"), right) or matches(right.removesuffix("/**"), left)


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise PipelineError(f"JSON nicht lesbar ({path}): {error}") from error


def load_manifest(root):
    manifest = read_json(root / MANIFEST)
    validate_manifest(root, manifest)
    return manifest


def validate_manifest(root, manifest):
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
        raise PipelineError("Unbekannte Manifestversion.")
    tasks = manifest.get("tasks")
    if not isinstance(tasks, list) or len(tasks) != 3:
        raise PipelineError("Die Pipeline erwartet genau drei Agentenaufgaben.")
    identifiers, agents, ownership = set(), set(), []
    for task in tasks:
        if not isinstance(task, dict):
            raise PipelineError("Jede Aufgabe muss ein JSON-Objekt sein.")
        task_id = task.get("id", "")
        agent = task.get("agent", "")
        if not isinstance(task_id, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", task_id) or task_id in identifiers:
            raise PipelineError(f"Ungültige oder doppelte Aufgabenkennung: {task_id!r}")
        if not isinstance(agent, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", agent) or agent in agents:
            raise PipelineError(f"Ungültige oder doppelte Agentenrolle: {agent!r}")
        identifiers.add(task_id)
        agents.add(agent)
        if not isinstance(task.get("title"), str) or not task["title"].strip() or "handoff" not in task:
            raise PipelineError(f"{task_id}: Titel oder Übergabefeld fehlt.")
        if task.get("status") not in ("open", "ready"):
            raise PipelineError(f"{task_id}: Manifeststatus muss open oder ready sein.")
        for field in ("allowed_paths", "depends_on", "checks"):
            values = task.get(field)
            if not isinstance(values, list) or not all(isinstance(x, str) for x in values) or len(set(values)) != len(values):
                raise PipelineError(f"{task_id}: {field} muss eindeutige Zeichenfolgen enthalten.")
        if not task["allowed_paths"] or not task["checks"]:
            raise PipelineError(f"{task_id}: Dateibesitz und Prüfungen fehlen.")
        for pattern in task["allowed_paths"]:
            safe_path(root, pattern, pattern=True)
            ownership.append((task_id, pattern))
        if any(check not in CHECKS for check in task["checks"]):
            raise PipelineError(f"{task_id}: Unbekannter Prüfschritt; freie Befehle sind nicht erlaubt.")
    integration = manifest.get("integration", {})
    if not isinstance(integration, dict) or not isinstance(integration.get("reserved_paths"), list):
        raise PipelineError("Integrationszuständigkeit fehlt.")
    for pattern in integration["reserved_paths"]:
        safe_path(root, pattern, pattern=True)
        ownership.append(("integration", pattern))
    for index, (owner, pattern) in enumerate(ownership):
        for other, candidate in ownership[index + 1:]:
            if owner != other and overlaps(pattern, candidate):
                raise PipelineError(f"Dateikonflikt: {owner} {pattern} / {other} {candidate}")
    by_id = {task["id"]: task for task in tasks}
    visiting, visited = set(), set()

    def visit(task_id):
        if task_id in visiting:
            raise PipelineError(f"Zyklische Abhängigkeit bei {task_id}.")
        if task_id in visited:
            return
        visiting.add(task_id)
        for dependency in by_id[task_id]["depends_on"]:
            if dependency not in by_id:
                raise PipelineError(f"{task_id}: Unbekannte Abhängigkeit {dependency}.")
            visit(dependency)
        visiting.remove(task_id)
        visited.add(task_id)
    for task_id in by_id:
        visit(task_id)


def load_state(root):
    path = safe_path(root, LOCAL + "/state.json")
    if not path.exists():
        return {"schema_version": 1, "manifest_sha256": digest(root / MANIFEST), "tasks": {}, "checks": {}}
    state = read_json(path)
    if (not isinstance(state, dict) or state.get("schema_version") != 1
            or not isinstance(state.get("tasks"), dict) or not isinstance(state.get("checks"), dict)):
        raise PipelineError("Lokaler Zustand beschädigt; vor weiteren Claims manuell prüfen.")
    if state.get("manifest_sha256") != digest(root / MANIFEST):
        raise PipelineError("Manifest geändert: lokale Claims/Übergaben abgleichen und .local/state.json anschließend archivieren oder entfernen.")
    return state


@contextmanager
def locked_state(root):
    directory = safe_path(root, LOCAL)
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / "state.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as error:
        raise PipelineError("Koordination gesperrt. Bei abgebrochener Sitzung zuerst PID in .local/state.lock prüfen; keinen fremden Lock löschen.") from error
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump({"pid": os.getpid(), "created_at": now()}, stream)
        state = load_state(root)
        yield state
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, prefix="state-", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(state, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.replace(temporary, directory / "state.json")
        finally:
            temporary.unlink(missing_ok=True)
    finally:
        lock.unlink(missing_ok=True)


def current_task(task, state):
    return state["tasks"].get(task["id"], {"status": task["status"], "agent": task["agent"], "handoff": task["handoff"]})


def files_in(root):
    for directory, children, files in os.walk(root):
        for child in sorted(children):
            path = Path(directory, child)
            if child not in IGNORED and path.is_symlink():
                yield path.relative_to(root).as_posix()
        children[:] = sorted(child for child in children if child not in IGNORED and not Path(directory, child).is_symlink())
        for filename in sorted(files):
            path = Path(directory, filename)
            yield path.relative_to(root).as_posix()


def scope_digest(root, task):
    hasher = hashlib.sha256()
    for name in sorted(name for name in files_in(root) if any(matches(name, p) for p in task["allowed_paths"])):
        if (root / name).is_symlink():
            raise PipelineError(f"Symlink im Aufgabenbereich nicht als eindeutiger Dateibesitz zulässig: {name}")
        hasher.update((name + "\0" + digest(root / name) + "\n").encode())
    return hasher.hexdigest()


def check_handoff(root, task, record):
    handoff = record.get("handoff")
    if not isinstance(handoff, dict) or not isinstance(handoff.get("summary"), str) or not handoff["summary"].strip():
        raise PipelineError(f"{task['id']}: Übergabezusammenfassung fehlt.")
    evidence = handoff.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        raise PipelineError(f"{task['id']}: Übergabenachweise fehlen.")
    for item in evidence:
        if not isinstance(item, dict):
            raise PipelineError(f"{task['id']}: Ungültiger Übergabenachweis.")
        path = safe_path(root, item.get("path"))
        if not path.is_file() or digest(path) != item.get("sha256"):
            raise PipelineError(f"{task['id']}: Fehlender oder seit Übergabe veränderter Nachweis {item.get('path')}.")
    if handoff.get("scope_sha256") != scope_digest(root, task):
        raise PipelineError(f"{task['id']}: Aufgaben-Dateien wurden nach Übergabe verändert; erneut prüfen und übergeben.")


def check(root, manifest, state, require_ready=False):
    by_id = {task["id"]: task for task in manifest["tasks"]}
    if set(state["tasks"]) - set(by_id):
        raise PipelineError("Lokaler Zustand enthält unbekannte Aufgaben.")
    for task in manifest["tasks"]:
        record = current_task(task, state)
        if not isinstance(record, dict) or record.get("status") not in ("open", "claimed", "ready") or record.get("agent") != task["agent"]:
            raise PipelineError(f"{task['id']}: Ungültiger lokaler Aufgabenstatus.")
        if record["status"] == "ready":
            check_handoff(root, task, record)
            pending = [dep for dep in task["depends_on"] if current_task(by_id[dep], state)["status"] != "ready"]
            if pending:
                raise PipelineError(f"{task['id']}: Abhängigkeiten noch nicht übergeben: {', '.join(pending)}")
        elif require_ready:
            raise PipelineError(f"{task['id']}: Noch keine geprüfte Übergabe.")
    for name in files_in(root):
        owners = [task["id"] for task in manifest["tasks"] if any(matches(name, p) for p in task["allowed_paths"])]
        if len(owners) > 1:
            raise PipelineError(f"Tatsächlicher Dateikonflikt {name}: {', '.join(owners)}")


def claim(root, manifest, task_id, agent, reopen=False):
    task = next((t for t in manifest["tasks"] if t["id"] == task_id), None)
    if task is None or agent != task["agent"]:
        raise PipelineError("Aufgabe und zuständige Agentenrolle stimmen nicht überein.")
    with locked_state(root) as state:
        record = current_task(task, state)
        if record["status"] == "ready" and not reopen:
            raise PipelineError("Aufgabe bereits übergeben; neue Bearbeitung mit --reopen ausdrücklich beginnen.")
        if record.get("agent") != agent:
            raise PipelineError("Die Aufgabe ist bereits von einer anderen Rolle beansprucht.")
        if record["status"] != "claimed" or reopen:
            state["tasks"][task_id] = {"status": "claimed", "agent": agent, "claimed_at": now(), "handoff": None}
    print(f"CLAIM {task_id}: {agent}; parallele Bearbeitung erlaubt, Abhängigkeiten gelten für die Übergabe.")


def handoff(root, manifest, task_id, agent, summary, evidence):
    task = next((t for t in manifest["tasks"] if t["id"] == task_id), None)
    if task is None or agent != task["agent"] or not summary.strip() or not evidence:
        raise PipelineError("Übergabe benötigt die zuständige Rolle, eine Zusammenfassung und vorhandene Nachweise.")
    with locked_state(root) as state:
        record = current_task(task, state)
        if record["status"] != "claimed" or record["agent"] != agent:
            raise PipelineError("Vor der Übergabe muss die eigene Aufgabe geclaimt sein.")
        current_digest = scope_digest(root, task)
        for check_id in task["checks"]:
            receipt = state["checks"].get(check_id, {})
            if (not isinstance(receipt, dict) or receipt.get("status") != "passed"
                    or not isinstance(receipt.get("scopes"), dict)
                    or receipt["scopes"].get(task_id) != current_digest):
                raise PipelineError(f"{task_id}: Aktueller bestandener Prüflauf {check_id} fehlt. Zuerst run --task {task_id} ausführen.")
        proofs = []
        for name in dict.fromkeys(evidence):
            path = safe_path(root, name)
            if not path.is_file():
                raise PipelineError(f"Nachweisdatei fehlt: {name}")
            proofs.append({"path": name, "sha256": digest(path)})
        record["status"] = "ready"
        record["handoff"] = {"summary": summary.strip(), "at": now(), "evidence": proofs, "scope_sha256": current_digest}
        state["tasks"][task_id] = record
        check(root, manifest, state)
    print(f"READY {task_id}: {len(proofs)} Dateinachweise; kein Merge und keine Veröffentlichung ausgelöst.")


def run(root, manifest, task_id=None):
    manifest_sha256 = digest(root / MANIFEST)
    state = load_state(root)
    check(root, manifest, state)
    selected = [task for task in manifest["tasks"] if task_id is None or task["id"] == task_id]
    if not selected:
        raise PipelineError(f"Unbekannte Aufgabe: {task_id}")
    identifiers = list(dict.fromkeys(check_id for task in selected for check_id in task["checks"]))
    if task_id is None:
        identifiers.append("unreal-static")
    outcomes = {}
    for check_id in identifiers:
        command, required = CHECKS[check_id]
        scopes = {task["id"]: scope_digest(root, task) for task in selected if check_id in task["checks"]}
        missing = [name for name in required if not safe_path(root, name).is_file()]
        if missing or not shutil.which(command[0]):
            reason = "Dateien fehlen: " + ", ".join(missing) if missing else "Werkzeug fehlt: " + command[0]
            print(f"NICHT GEPRÜFT {check_id}: {reason}", flush=True)
            outcomes[check_id] = {"status": "not_checked", "at": now(), "reason": reason, "scopes": scopes}
            continue
        print(f"PRÜFE {check_id}: {' '.join(command)}", flush=True)
        try:
            completed = subprocess.run(command, cwd=root, shell=False, timeout=120, check=False)
            status = "passed" if completed.returncode == 0 else "failed"
            returncode = completed.returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"FEHLER {check_id}: {error}", flush=True)
            status, returncode = "failed", None
        if any(scope_digest(root, task) != scopes[task["id"]] for task in selected if task["id"] in scopes):
            status = "stale"
        outcomes[check_id] = {"status": status, "at": now(), "returncode": returncode, "scopes": scopes}
        print(f"{status.upper()} {check_id}", flush=True)
    with locked_state(root) as state:
        if digest(root / MANIFEST) != manifest_sha256:
            raise PipelineError("Manifest während des Prüflaufs verändert; Ergebnisse erneut ermitteln.")
        state["checks"].update(outcomes)
    print("Prüfumfang: Quellcode/Logik; kein Unreal-Build, Rendering- oder Gerätetest.")
    if any(value["status"] in {"failed", "stale"} for value in outcomes.values()):
        return 1
    return 2 if any(value["status"] == "not_checked" for value in outcomes.values()) else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    check_parser = commands.add_parser("check")
    check_parser.add_argument("--require-ready", action="store_true")
    run_parser = commands.add_parser("run")
    run_parser.add_argument("--task")
    claim_parser = commands.add_parser("claim")
    claim_parser.add_argument("task")
    claim_parser.add_argument("--agent", required=True)
    claim_parser.add_argument("--reopen", action="store_true")
    handoff_parser = commands.add_parser("handoff")
    handoff_parser.add_argument("task")
    handoff_parser.add_argument("--agent", required=True)
    handoff_parser.add_argument("--summary", required=True)
    handoff_parser.add_argument("--evidence", action="append", required=True)
    args = parser.parse_args(argv)
    try:
        manifest = load_manifest(ROOT)
        if args.command == "claim":
            claim(ROOT, manifest, args.task, args.agent, args.reopen)
        elif args.command == "handoff":
            handoff(ROOT, manifest, args.task, args.agent, args.summary, args.evidence)
        elif args.command == "run":
            return run(ROOT, manifest, args.task)
        else:
            state = load_state(ROOT)
            check(ROOT, manifest, state, getattr(args, "require_ready", False))
            if args.command == "status":
                print(manifest["project"])
                for task in manifest["tasks"]:
                    record = current_task(task, state)
                    print(f"{task['id']:18} {record['status']:8} {task['title']}")
                print("Lokale Sitzung; Claims und Prüfläufe werden nicht versioniert.")
            else:
                print("OK: drei Rollen, eindeutiger Dateibesitz, azyklische Abhängigkeiten und gültige vorhandene Übergaben.")
        return 0
    except PipelineError as error:
        print(f"FEHLER: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
