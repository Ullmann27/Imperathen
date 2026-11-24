"""Reale Godot-Prüfszenen erfassen und gleiche Kameras nachvollziehbar vergleichen.

Das Werkzeug ändert keine Git-Revision und erstellt keinen zusätzlichen Clone.
Eine einzige externe companion_review.gd wird für beide Projektstände verwendet.
Mit --check-only werden nur Szenenaufbau und Befehlsreise geprüft, keine Bilder.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile


FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)
SOURCE_SUFFIXES = {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".godot", ".glb",
                   ".res", ".wav", ".ogg", ".svg", ".ttf", ".json", ".webp", ".jpg", ".png"}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def source_hashes(project: Path) -> dict[str, str]:
    return {str(path.relative_to(project)): digest(path)
            for path in sorted(project.rglob("*"))
            if path.is_file() and ".godot" not in path.relative_to(project).parts
            and path.suffix in SOURCE_SUFFIXES}


def changed_sources(before: dict[str, str], after: dict[str, str]) -> list[str]:
    return sorted(name for name in before.keys() | after.keys()
                  if before.get(name) != after.get(name))


def embedded_glb_images(path: Path, relative: str, source_sha256: str) -> list[dict]:
    """Belege für unverändert extrahierbare PNG/JPEG-Bytes einer GLB v2.

    Godots Extract-Textures-Modus speichert eingebettete Bildbytes unverändert:
    https://docs.godotengine.org/en/stable/classes/class_gltfstate.html
    Andere Formate, externe Bilder oder umbenannte Derivate werden nicht erlaubt.
    """
    images = []
    with path.open("rb") as stream:
        header = stream.read(12)
        if len(header) != 12:
            raise ValueError("Unvollständiger GLB-Header")
        magic, version, total = struct.unpack("<4sII", header)
        if magic != b"glTF" or version != 2 or total != path.stat().st_size:
            raise ValueError("Ungültiger GLB-v2-Header")
        document = None
        binary_start, binary_length = 0, 0
        while stream.tell() < total:
            chunk_header = stream.read(8)
            if len(chunk_header) != 8:
                raise ValueError("Unvollständiger GLB-Chunk")
            size, kind = struct.unpack("<I4s", chunk_header)
            end = stream.tell() + size
            if size % 4 or end > total:
                raise ValueError("Ungültige GLB-Chunk-Grenzen")
            if kind == b"JSON":
                if document is not None:
                    raise ValueError("Mehrere GLB-JSON-Chunks")
                document = json.loads(stream.read(size))
            elif kind == b"BIN\x00":
                if binary_start:
                    raise ValueError("Mehrere GLB-BIN-Chunks")
                binary_start, binary_length = stream.tell(), size
            stream.seek(end)
        if not isinstance(document, dict) or not binary_start:
            raise ValueError("GLB-JSON oder eingebetteter Binärpuffer fehlt")
        views = document.get("bufferViews", [])
        for index, item in enumerate(document.get("images", [])):
            name = item.get("name", "")
            suffix = {"image/png": ".png", "image/jpeg": ".jpg"}.get(item.get("mimeType"))
            view_index = item.get("bufferView")
            if (not suffix or not isinstance(name, str) or not name or "/" in name or "\\" in name
                    or type(view_index) is not int or not 0 <= view_index < len(views)):
                continue
            view = views[view_index]
            offset, length = view.get("byteOffset", 0), view.get("byteLength", 0)
            if (view.get("buffer", 0) != 0 or type(offset) is not int or type(length) is not int
                    or offset < 0 or length <= 0 or offset + length > binary_length):
                continue
            stream.seek(binary_start + offset)
            raw = stream.read(length)
            target = Path(relative).with_name(path.stem + "_" + name + suffix)
            images.append({"path": str(target), "sha256": hashlib.sha256(raw).hexdigest(),
                           "source_glb": relative, "source_glb_sha256": source_sha256,
                           "image_index": index, "image_name": name, "mime_type": item["mimeType"],
                           "buffer_view": view_index, "buffer_offset": offset, "byte_length": length})
    return images


def check_import_sources(project: Path, before: dict[str, str], after: dict[str, str]) -> dict:
    """Nur nachweisbare neue GLB-Extrakte zulassen; vorhandene Quellen einfrieren."""
    existing_changes = sorted(name for name, value in before.items() if after.get(name) != value)
    added = set(after) - set(before)
    verified = {}
    provenance_errors = []
    for relative, source_sha256 in sorted(before.items()):
        source = Path(relative)
        candidates = {name for name in added if Path(name).parent == source.parent
                      and Path(name).name.startswith(source.stem + "_")
                      and Path(name).suffix in {".png", ".jpg"}}
        if source.suffix != ".glb" or after.get(relative) != source_sha256 or not candidates:
            continue
        try:
            for item in embedded_glb_images(project / source, relative, source_sha256):
                if item["path"] in candidates and after[item["path"]] == item["sha256"]:
                    verified[item["path"]] = item
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
            provenance_errors.append(f"{relative}: {error}")
    unexpected = sorted(added - verified.keys())
    return {"passed": not existing_changes and not unexpected and not provenance_errors,
            "existing_source_changes": existing_changes, "unexpected_added_paths": unexpected,
            "generated_import_textures": [verified[name] for name in sorted(verified)],
            "provenance_errors": provenance_errors}


def git_text(root: Path, *arguments: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *arguments], text=True,
                            encoding="utf-8", capture_output=True, check=True)
    return result.stdout.strip()


def run_logged(command: list[str], environment: dict[str, str], log: Path,
               timeout: int, cwd: Path) -> tuple[int, str]:
    try:
        result = subprocess.run(command, env=environment, cwd=cwd, text=True,
                                encoding="utf-8", errors="replace", stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        output = result.stdout
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output += f"\nTIMEOUT nach {timeout} Sekunden\n"
        code = 124
    log.write_text(output, encoding="utf-8")
    return code, output


def validate_images(directory: Path, report: dict) -> list[str]:
    errors = []
    for shot in report.get("shots", []):
        name = shot.get("image", "")
        if not name or Path(name).name != name:
            errors.append(f"Fehlender oder ungültiger Bildname: {shot.get('id')}")
            continue
        path = directory / name
        if not path.is_file():
            errors.append(f"Bild fehlt: {name}")
            continue
        with path.open("rb") as stream:
            header = stream.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            errors.append(f"Kein PNG-Bild: {name}")
        elif struct.unpack(">II", header[16:24]) != (1280, 720):
            errors.append(f"Falsche PNG-Auflösung: {name}")
        if digest(path) != shot.get("image_sha256"):
            errors.append(f"Bildprüfsumme abweichend: {name}")
    return errors


def capture(args: argparse.Namespace) -> int:
    if args.project is None or args.script is None:
        raise SystemExit("Erfassung benötigt --project und --script.")
    project, script, output = args.project.resolve(), args.script.resolve(), args.output.resolve()
    if not (project / "project.godot").is_file() or not script.is_file():
        raise SystemExit("Godot-Projekt oder externes Prüfszenenskript fehlt.")
    if not args.check_only and not os.environ.get("DISPLAY"):
        raise SystemExit("Echte Bilder benötigen DISPLAY, beispielsweise xvfb-run. --check-only erzeugt keine Bilder.")
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit(f"Godot nicht gefunden: {args.godot}")
    version = subprocess.run([engine, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    if not version.startswith("4.7.2."):
        raise SystemExit(f"Godot 4.7.2 erforderlich, gefunden: {version}")
    output.mkdir(parents=True, exist_ok=True)
    before = source_hashes(project)
    manifest = {"schema_version": 2, "label": args.label, "engine": version,
                "source_commit": git_text(project, "rev-parse", "HEAD"),
                "worktree_status": git_text(project, "status", "--porcelain=v1", "--", str(project)).splitlines(),
                "source_sha256": before, "review_script_sha256": digest(script),
                "check_only": args.check_only, "android_device_test": False, "passed": False}
    write_json(output / "capture-manifest.json", manifest)
    with tempfile.TemporaryDirectory(prefix="imperathen-companion-review-") as temporary:
        environment = os.environ.copy()
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
        environment["LIBGL_ALWAYS_SOFTWARE"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            directory = Path(temporary) / kind.lower()
            directory.mkdir()
            environment[f"XDG_{kind}_HOME"] = str(directory)
        code, log = run_logged([engine, "--headless", "--path", str(project), "--import"],
                               environment, output / "import.log", 300, project.parent)
        prepared = source_hashes(project)
        import_check = check_import_sources(project, before, prepared)
        prepared_commit = git_text(project, "rev-parse", "HEAD")
        import_errors = []
        if code or FAILURE.search(log):
            import_errors.append("Godot-Import fehlgeschlagen; siehe import.log")
        if not import_check["passed"]:
            import_errors.append("Import änderte Quellen oder erzeugte nicht belegbare Zusatzdateien")
        if prepared_commit != manifest["source_commit"]:
            import_errors.append("Git-HEAD änderte sich während der Importvorbereitung")
        manifest.update({"import_source_check": import_check, "prepared_source_sha256": prepared,
                         "source_commit_after_import": prepared_commit, "errors": import_errors})
        if import_errors:
            manifest.update({"source_changed_paths": sorted(import_check["existing_source_changes"]
                                                              + import_check["unexpected_added_paths"]),
                             "source_unchanged_during_run": False, "engine_exit_code": code})
        write_json(output / "capture-manifest.json", manifest)
        if import_errors:
            return 1
        command = [engine, "--audio-driver", "Dummy", "--path", str(project),
                   "--resolution", "1280x720", "--fixed-fps", "60"]
        command += (["--headless"] if args.check_only else
                    ["--display-driver", "x11", "--rendering-method", "gl_compatibility",
                     "--rendering-driver", "opengl3", "--disable-render-loop"])
        command += ["--script", str(script), "--", "--output=" + str(output)]
        if args.check_only:
            command.append("--check-only")
        if args.expect_companions:
            command.append("--expect-companions")
        code, log = run_logged(command, environment, output / "runtime.log", 600, project.parent)
    errors = []
    if code or FAILURE.search(log) or "COMPANION_REVIEW_PASS" not in log:
        errors.append("Prüfszenen fehlgeschlagen; siehe runtime.log")
    receipt = output / "companion-review.json"
    report = json.loads(receipt.read_text(encoding="utf-8")) if receipt.exists() else {}
    if not report.get("passed") or len(report.get("shots", [])) != 9:
        errors.append("Unvollständiger oder fehlgeschlagener Szenenbericht")
    if report.get("review_script_sha256") != manifest["review_script_sha256"]:
        errors.append("Ausgeführtes Prüfszenenskript stimmt nicht mit der Eingabe überein")
    if not args.check_only:
        errors.extend(validate_images(output, report))
    after = source_hashes(project)
    # Ab hier gilt auch für alle belegten Importderivate wieder der strikte Guard.
    changed = changed_sources(prepared, after)
    commit_after = git_text(project, "rev-parse", "HEAD")
    if changed:
        errors.append("Projektquellen änderten sich während der Erfassung")
    if commit_after != manifest["source_commit"]:
        errors.append("Git-HEAD änderte sich während der Erfassung")
    manifest.update({"passed": not errors, "errors": errors, "source_changed_paths": changed,
                     "source_commit_after": commit_after,
                     "source_unchanged_during_run": not changed and commit_after == manifest["source_commit"],
                     "engine_exit_code": code})
    write_json(output / "capture-manifest.json", manifest)
    print(json.dumps({"passed": not errors, "label": args.label, "shots": len(report.get("shots", [])),
                      "check_only": args.check_only, "output": str(output), "errors": errors}, ensure_ascii=False))
    return 1 if errors else 0


def compare(args: argparse.Namespace) -> int:
    if args.before is None or args.after is None:
        raise SystemExit("Vergleich benötigt --before und --after.")
    directories = [args.before.resolve(), args.after.resolve()]
    manifests = [json.loads((path / "capture-manifest.json").read_text(encoding="utf-8")) for path in directories]
    reports = [json.loads((path / "companion-review.json").read_text(encoding="utf-8")) for path in directories]
    errors = []
    if any(not item.get("passed") or item.get("check_only") for item in manifests):
        errors.append("Beide Eingaben müssen erfolgreiche tatsächliche Bilderfassungen sein")
    if manifests[0]["review_script_sha256"] != manifests[1]["review_script_sha256"]:
        errors.append("Vorher und nachher verwenden unterschiedliche Prüfszenenskripte")
    left = {item["id"]: item for item in reports[0].get("shots", [])}
    right = {item["id"]: item for item in reports[1].get("shots", [])}
    if list(left) != list(right) or len(left) != 9:
        errors.append("Die neun Prüfszenen stimmen nicht überein")
    same_fields = ("camera", "fixture_player_position", "player_position", "stage", "relation", "quality",
                   "output_pixels", "fixture_progress_sha256", "presentation_time", "pose")
    pairs = []
    for key in left.keys() & right.keys():
        a, b = left[key], right[key]
        differences = [field for field in same_fields if a.get(field) != b.get(field)]
        if differences:
            errors.append(f"Vergleichsbedingungen abweichend ({key}): {', '.join(differences)}")
        pairs.append({"id": key, "matched_conditions": not differences, "different_fields": differences,
                      "before_image": a.get("image"), "after_image": b.get("image"),
                      "before_actor_position": a["actor_position"], "after_actor_position": b["actor_position"]})
    for path, report in zip(directories, reports):
        errors.extend(validate_images(path, report))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = {"schema_version": 1, "passed": not errors, "errors": errors,
              "baseline_commit": manifests[0]["source_commit"], "feature_commit": manifests[1]["source_commit"],
              "review_script_sha256": manifests[0]["review_script_sha256"], "pairs": sorted(pairs, key=lambda item: item["id"]),
              "scope": "Identische Prüfbedingungen und echte Bilder bestätigt. Die visuelle Bewertung erfolgt anhand der Bilder; keine FPS-/Android-Leistungsmessung."}
    write_json(output / "comparison.json", result)
    sections = []
    for pair in result["pairs"]:
        images = []
        for directory, field, label in zip(directories, ("before_image", "after_image"), ("Vorher", "Nachher")):
            path = os.path.relpath(directory / str(pair[field]), output)
            images.append(f'<figure><figcaption>{label}</figcaption><img src="{html.escape(path, quote=True)}" alt="{label}: {html.escape(pair["id"], quote=True)}"></figure>')
        sections.append(f'<section><h2>{html.escape(pair["id"])}</h2><div class="pair">{"".join(images)}</div></section>')
    document = '<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>IMPERATHEN Begleiter – Vorher und Nachher</title><style>body{font:16px/1.5 system-ui,sans-serif;margin:24px;background:#151515;color:#f4f0e8}h1{font-size:1.6rem}h2{font-size:1.1rem;margin-top:30px}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}figure{margin:0}img{width:100%;height:auto}figcaption{font-weight:700;margin-bottom:6px}code{word-break:break-all}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style>'
    document += '<h1>IMPERATHEN: Begleiter im gleichen Kamerablick</h1><p>1280 × 720 · Ausgewogen · tatsächliche Godot-Renderbilder. Die Anreisen sind Prüffixtures; diese Bilder belegen weder Spielzeit noch Android-Bildrate.</p>'
    document += f'<p>Basis: <code>{html.escape(result["baseline_commit"])}</code><br>Änderung: <code>{html.escape(result["feature_commit"])}</code></p>'
    document += ''.join(sections) + '</html>'
    (output / "comparison.html").write_text(document, encoding="utf-8")
    print(json.dumps({"passed": not errors, "pairs": len(pairs), "errors": errors}, ensure_ascii=False))
    return 1 if errors else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path)
    parser.add_argument("--script", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--label", default="review")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--expect-companions", action="store_true")
    parser.add_argument("--compare", action="store_true")
    parser.add_argument("--before", type=Path)
    parser.add_argument("--after", type=Path)
    args = parser.parse_args()
    return compare(args) if args.compare else capture(args)


if __name__ == "__main__":
    raise SystemExit(main())
