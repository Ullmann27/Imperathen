"""Gleiche produktive Team-B-Prüfszenen vor/nach einer Änderung erfassen.

Die Import-/Quellenprüfung verwendet die bereits geprüften GLB-Herkunftsregeln
des Begleiter-Vergleichs. Dieses Werkzeug wechselt selbst keine Git-Revision.
"""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from capture_companion_comparison import (
    FAILURE, changed_sources, check_import_sources, digest, git_text,
    run_logged, source_hashes, validate_images, write_json,
)

SHOT_IDS = ["01_market_staff", "02_work_panel", "03_social_panel"]


def capture(args: argparse.Namespace) -> int:
    project, script, output = args.project.resolve(), args.script.resolve(), args.output.resolve()
    engine = shutil.which(args.godot)
    if not engine or not (project / "project.godot").is_file() or not script.is_file():
        raise SystemExit("Godot, Projekt oder externes Prüfszenenskript fehlt")
    if not args.check_only and not os.environ.get("DISPLAY"):
        raise SystemExit("Grafische Bilder benötigen DISPLAY; --check-only erzeugt keine Bilder")
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2."):
        raise SystemExit("Die eingefrorene Prüfumgebung benötigt Godot 4.7.2")
    output.mkdir(parents=True, exist_ok=True)
    original = source_hashes(project)
    commit = git_text(project, "rev-parse", "HEAD")
    manifest = {"source_commit": commit, "engine": version, "label": args.label,
                "review_script_sha256": digest(script), "check_only": args.check_only,
                "android_device_test": False, "passed": False, "source_sha256": original}
    errors = []
    with tempfile.TemporaryDirectory(prefix="imperathen-living-world-") as temporary:
        environment = os.environ.copy()
        environment.update(IMPERATHEN_ISOLATED_TEST="1", GODOT_SILENCE_ROOT_WARNING="1",
                           LIBGL_ALWAYS_SOFTWARE="1")
        for name in ("DATA", "CONFIG", "CACHE"):
            folder = Path(temporary) / name.lower()
            folder.mkdir()
            environment[f"XDG_{name}_HOME"] = str(folder)
        code, log = run_logged([engine, "--headless", "--path", str(project), "--import"],
                               environment, output / "import.log", 300, project.parent)
        prepared = source_hashes(project)
        audit = check_import_sources(project, original, prepared)
        manifest["import_source_check"] = audit
        if code or FAILURE.search(log) or not audit["passed"]:
            errors.append("Import oder Quellenprüfung fehlgeschlagen")
        if not errors:
            command = [engine, "--audio-driver", "Dummy", "--path", str(project),
                       "--resolution", "1280x720", "--fixed-fps", "60"]
            command += (["--headless"] if args.check_only else
                        ["--display-driver", "x11", "--rendering-method", "gl_compatibility",
                         "--rendering-driver", "opengl3", "--disable-render-loop"])
            command += ["--script", str(script), "--", "--output=" + str(output)]
            if args.check_only:
                command.append("--check-only")
            code, log = run_logged(command, environment, output / "runtime.log", 180, project.parent)
            if code or FAILURE.search(log) or "LIVING_WORLD_REVIEW_PASS" not in log:
                errors.append("Prüfszene fehlgeschlagen")
        receipt = output / "living-world-review.json"
        report = json.loads(receipt.read_text()) if receipt.exists() else {}
        if not report.get("passed") or [s["id"] for s in report.get("shots", [])] != SHOT_IDS:
            errors.append("Die drei vollständigen Prüfszenen fehlen")
        if report.get("review_script_sha256") != manifest["review_script_sha256"]:
            errors.append("Ausgeführte Prüfszene entspricht nicht der eingefrorenen Datei")
        if not args.check_only:
            errors.extend(validate_images(output, report))
        changed = changed_sources(prepared, source_hashes(project))
        if changed or commit != git_text(project, "rev-parse", "HEAD"):
            errors.append("Quellen oder Git-Revision änderten sich während der Aufnahme")
    manifest.update(passed=not errors, errors=errors, source_changed_paths=changed,
                    prepared_source_sha256=prepared, source_unchanged_during_run=not changed)
    write_json(output / "capture-manifest.json", manifest)
    print(json.dumps({"passed": not errors, "label": args.label, "errors": errors}, ensure_ascii=False))
    return int(bool(errors))


def compare(args: argparse.Namespace) -> int:
    directories = [args.before.resolve(), args.after.resolve()]
    manifests = [json.loads((p / "capture-manifest.json").read_text()) for p in directories]
    reports = [json.loads((p / "living-world-review.json").read_text()) for p in directories]
    errors = []
    if any(not m.get("passed") or m.get("check_only") for m in manifests):
        errors.append("Beide Aufnahmen müssen echte erfolgreiche Bilder enthalten")
    if manifests[0]["review_script_sha256"] != manifests[1]["review_script_sha256"]:
        errors.append("Prüfszenenskript unterscheidet sich")
    for directory, report in zip(directories, reports):
        errors.extend(validate_images(directory, report))
        if [s["id"] for s in report.get("shots", [])] != SHOT_IDS:
            errors.append("Unvollständige Szenenfolge")
    pairs = []
    matching = ("id", "scenario", "quality", "presentation_time", "output_pixels", "camera",
                "fov", "fixture_player_position", "pose")
    for before, after in zip(reports[0]["shots"], reports[1]["shots"]):
        different = [key for key in matching if before.get(key) != after.get(key)]
        if different:
            errors.append(f"Vergleichsbedingungen abweichend: {before['id']} {different}")
        pairs.append({"id": before["id"], "matched_conditions": not different,
                      "before_image": before.get("image"), "after_image": after.get("image")})
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {"passed": not errors, "errors": errors, "pairs": pairs,
              "baseline_commit": manifests[0]["source_commit"], "feature_commit": manifests[1]["source_commit"],
              "scope": "Echte Desktop-Bilder mit identischen Kameras und Eingabe-Fixtures; keine Geräte-/FPS-Messung"}
    write_json(output / "comparison.json", report)
    sections = []
    for pair in pairs:
        images = []
        for directory, field, title in zip(directories, ("before_image", "after_image"), ("Vorher", "Nachher")):
            relative = os.path.relpath(directory / str(pair[field]), output)
            images.append(f'<figure><figcaption>{title}</figcaption><img src="{html.escape(relative)}"></figure>')
        sections.append(f'<section><h2>{html.escape(pair["id"])}</h2><div>{"".join(images)}</div></section>')
    (output / "index.html").write_text('<!doctype html><meta charset="utf-8"><title>Team B – Bildvergleich</title>'
        '<style>body{background:#171d20;color:#eee;font:16px sans-serif;margin:24px}div{display:flex;gap:12px}'
        'figure{margin:0;width:50%}img{width:100%}</style><h1>Team B – identische Prüfszenen</h1>' + "".join(sections))
    print(json.dumps(report, ensure_ascii=False))
    return int(bool(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", type=Path)
    parser.add_argument("--script", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--label", default="after")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--compare", action="store_true")
    parser.add_argument("--before", type=Path)
    parser.add_argument("--after", type=Path)
    args = parser.parse_args()
    if args.compare:
        if not args.before or not args.after:
            parser.error("--compare benötigt --before und --after")
        return compare(args)
    if not args.project or not args.script:
        parser.error("Erfassung benötigt --project und --script")
    return capture(args)


if __name__ == "__main__":
    raise SystemExit(main())
