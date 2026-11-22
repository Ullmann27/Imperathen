#!/usr/bin/env python3
"""Export the actual Godot project as a verified, signed Android debug APK.

Linux build host, Python 3.10+, pinned Godot and Android build tools. No packages,
SDKs, keys or paid services are downloaded or created by this program. Machine
settings and any export credentials stay in a temporary project copy. The main
artifact is ARM64; --abi x86_64 builds the same sources for an Android emulator.
"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone


REPOSITORY = Path(__file__).resolve().parents[1]
EXPECTED_GODOT = "4.7.2.stable"
BUILD_TOOLS = "35.0.1"
PLATFORM = "android-35"
PACKAGE = "at.heinz.imperathen"
PRESET = "Android ARM64"
PASSWORD_ENV = "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"
ABIS = ("arm64-v8a", "x86_64")


class BuildError(RuntimeError):
    """An actionable, non-secret build or verification failure."""


def redact(text: str, environment: dict[str, str]) -> str:
    for key, value in environment.items():
        if value and ("PASSWORD" in key or "SECRET" in key or key.endswith("_TOKEN")):
            text = text.replace(value, "[REDACTED]")
    return text


def run(command: list[str], environment: dict[str, str], label: str,
        timeout: int = 180, echo: bool = True) -> str:
    print(f"ANDROID_BUILD_STEP {label}", flush=True)
    try:
        result = subprocess.run(command, env=environment, cwd=REPOSITORY,
                                text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout,
                                check=False)
    except subprocess.TimeoutExpired as error:
        raise BuildError(f"{label}: Zeitlimit von {timeout} Sekunden überschritten.") from error
    except OSError as error:
        raise BuildError(f"{label}: Werkzeug nicht ausführbar: {error}") from error
    output = redact(result.stdout or "", environment)
    if echo and output.strip():
        print(output.rstrip(), flush=True)
    if result.returncode:
        if not echo and output.strip():
            print(output.rstrip(), flush=True)
        raise BuildError(f"{label}: Exitcode {result.returncode}; kein APK-Erfolg behauptet.")
    return output


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inside(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def existing_file(path: Path, description: str, executable: bool = False) -> Path:
    path = path.expanduser().resolve()
    if not path.is_file():
        raise BuildError(f"Fehlt: {description}: {path}")
    if executable and not os.access(path, os.X_OK):
        raise BuildError(f"Nicht ausführbar: {description}: {path}")
    return path


def read_config(path: Path, project: bool = False) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    text = path.read_text(encoding="utf-8")
    parser.read_string(("[_root]\n" if project else "") + text)
    return parser


def unquote(value: str) -> str:
    return json.loads(value) if value.startswith('"') else value


def find_templates(path: Path | None, environment: dict[str, str]) -> Path:
    if path is None:
        data_root = Path(environment.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        path = data_root / "godot/export_templates" / EXPECTED_GODOT
    path = path.expanduser().resolve()
    for candidate in (path, path / EXPECTED_GODOT, path / "templates"):
        if (candidate / "android_debug.apk").is_file():
            version_file = candidate / "version.txt"
            version = version_file.read_text(encoding="utf-8").strip() if version_file.is_file() else candidate.name
            if version != EXPECTED_GODOT:
                raise BuildError(f"Exportvorlage nicht als {EXPECTED_GODOT} belegt: {candidate}. "
                                 "Die version.txt aus dem offiziellen Vorlagenpaket beilegen.")
            return candidate
    raise BuildError(f"android_debug.apk für {EXPECTED_GODOT} fehlt unter {path}.")


def source_fingerprint(project: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(project.rglob("*")):
        relative = path.relative_to(project)
        if not path.is_file() or any(part in {".godot", ".git", "android"} for part in relative.parts):
            continue
        if path.name.endswith((".tmp", ".bak")):
            continue
        digest.update(relative.as_posix().encode("utf-8") + b"\0")
        digest.update(bytes.fromhex(file_sha256(path)))
    return digest.hexdigest()


def preflight(args: argparse.Namespace) -> tuple[dict, dict[str, str]]:
    if not sys.platform.startswith("linux"):
        raise BuildError("Dieser reproduzierbare Baupfad ist für Linux eingerichtet; die APK selbst ist für Android.")
    environment = os.environ.copy()
    engine_name = args.godot or environment.get("IMPERATHEN_GODOT", "godot")
    engine_found = shutil.which(engine_name)
    if not engine_found:
        raise BuildError("Godot fehlt. --godot auf die ausführbare Godot-4.7.2-Datei setzen.")
    engine = existing_file(Path(engine_found), "Godot", True)
    engine_version = run([str(engine), "--version"], environment, "Godot-Version", echo=False).strip()
    if not engine_version.startswith(EXPECTED_GODOT + "."):
        raise BuildError(f"Godot-Version {engine_version!r} stimmt nicht mit {EXPECTED_GODOT} überein.")
    project = args.project.expanduser().resolve()
    existing_file(project / "project.godot", "Godot-Projekt")
    existing_file(project / "export_presets.cfg", "Android-Exportvorgabe")
    config = read_config(project / "project.godot", project=True)
    for key in ("renderer/rendering_method", "renderer/rendering_method.mobile"):
        if unquote(config.get("rendering", key, fallback='""')) != "gl_compatibility":
            raise BuildError(f"Android-Projekt benötigt explizit Compatibility: rendering/{key}.")
    if not config.getboolean("rendering", "textures/vram_compression/import_etc2_astc", fallback=False):
        raise BuildError("Android-Export benötigt rendering/textures/vram_compression/import_etc2_astc=true.")
    orientation = config.getint("display", "window/handheld/orientation", fallback=0)
    if orientation not in (0, 4):
        raise BuildError("Querformat erwartet: display/window/handheld/orientation muss 0 oder 4 sein.")
    preset_config = read_config(project / "export_presets.cfg")
    preset_section = next((section for section in preset_config.sections()
                           if re.fullmatch(r"preset\.\d+", section)
                           and unquote(preset_config.get(section, "name", fallback='""')) == PRESET), None)
    if preset_section is None:
        raise BuildError(f"Exportvorgabe {PRESET!r} fehlt.")
    options = preset_section + ".options"
    if unquote(preset_config.get(preset_section, "platform", fallback='""')) != "Android":
        raise BuildError("Der Export muss die Android-Plattform verwenden.")
    if unquote(preset_config.get(options, "package/unique_name", fallback='""')) != PACKAGE:
        raise BuildError(f"Die festgelegte Paketkennung lautet {PACKAGE}.")
    if preset_config.getboolean(options, "gradle_build/use_gradle_build", fallback=True):
        raise BuildError("Dieser Bauweg benötigt die vorgebaute APK-Vorlage ohne Gradle.")
    if not preset_config.getboolean(options, "package/signed", fallback=False):
        raise BuildError("Eine installierbare APK muss signiert werden.")
    sdk_value = args.sdk_root or environment.get("ANDROID_HOME") or environment.get("ANDROID_SDK_ROOT")
    if not sdk_value:
        raise BuildError("Android-SDK fehlt: --sdk-root oder ANDROID_HOME angeben.")
    sdk = Path(sdk_value).expanduser().resolve()
    existing_file(sdk / "platform-tools/adb", "Android Platform-Tools / adb", True)
    existing_file(sdk / "platforms" / PLATFORM / "android.jar", f"SDK Platform {PLATFORM}")
    for executable in ("aapt", "apksigner", "zipalign"):
        existing_file(sdk / "build-tools" / BUILD_TOOLS / executable, f"Build-Tools {BUILD_TOOLS} / {executable}", True)
    java_value = args.java_home or environment.get("JAVA_HOME_17_X64") or environment.get("JAVA_HOME")
    if not java_value:
        raise BuildError("JDK17 fehlt: --java-home oder JAVA_HOME_17_X64 angeben.")
    java = Path(java_value).expanduser().resolve()
    for executable in ("java", "javac", "keytool"):
        existing_file(java / "bin" / executable, "OpenJDK17 / " + executable, True)
    environment["JAVA_HOME"] = str(java)
    environment["ANDROID_HOME"] = str(sdk)
    environment["ANDROID_SDK_ROOT"] = str(sdk)
    environment["PATH"] = str(java / "bin") + os.pathsep + environment.get("PATH", "")
    java_version = run([str(java / "bin/java"), "-version"], environment, "Java-Version", echo=False)
    if not re.search(r'version "17(?:[.\-+" ]|$)', java_version):
        raise BuildError("Dieser festgelegte Baupfad benötigt JDK17; eine andere Java-Version wird nicht stillschweigend verwendet.")
    templates = find_templates(args.template_dir, environment)
    keystore_value = args.keystore or environment.get("GODOT_ANDROID_KEYSTORE_DEBUG_PATH")
    alias = args.keystore_user or environment.get("GODOT_ANDROID_KEYSTORE_DEBUG_USER")
    if not keystore_value or not alias or not environment.get(PASSWORD_ENV):
        raise BuildError("Private Debug-Signierung fehlt: --keystore, --keystore-user und "
                         f"{PASSWORD_ENV} in der Umgebung bereitstellen. Keine Passwörter als CLI-Argumente verwenden.")
    keystore = existing_file(Path(keystore_value), "privater Debug-Keystore")
    if inside(keystore, REPOSITORY) or inside(keystore, project):
        raise BuildError("Der private Keystore muss außerhalb des Repositorys und der Projektkopie liegen.")
    environment["GODOT_ANDROID_KEYSTORE_DEBUG_PATH"] = str(keystore)
    environment["GODOT_ANDROID_KEYSTORE_DEBUG_USER"] = alias
    run([str(java / "bin/keytool"), "-list", "-keystore", str(keystore), "-alias", alias,
         "-storepass:env", PASSWORD_ENV], environment, "Signierschlüssel prüfen", echo=False)
    validator = existing_file(REPOSITORY / "tools/validate_android_apk.py", "APK-Prüfläufer")
    return {
        "godot": str(engine), "godot_version": engine_version, "project": str(project),
        "sdk_root": str(sdk), "java_home": str(java), "java_version": java_version.splitlines()[0],
        "build_tools": BUILD_TOOLS, "sdk_platform": PLATFORM,
        "template_dir": str(templates), "template_sha256": file_sha256(templates / "android_debug.apk"),
        "package": PACKAGE, "preset": PRESET, "preset_section": preset_section,
        "abi": args.abi, "orientation": orientation, "validator": str(validator),
        "source_sha256": source_fingerprint(project),
    }, environment


def write_isolated_settings(directory: Path, toolchain: dict, environment: dict[str, str]) -> None:
    for kind in ("CONFIG", "CACHE", "DATA"):
        environment[f"XDG_{kind}_HOME"] = str(directory / kind.lower())
    settings = directory / "config/godot/editor_settings-4.7.tres"
    settings.parent.mkdir(parents=True)
    # Godot can otherwise discover a newer build-tools folder on a shared runner.
    # A directory of links pins the actual export tools without copying the SDK.
    original_sdk = Path(toolchain["sdk_root"])
    sdk_view = directory / "sdk"
    (sdk_view / "build-tools").mkdir(parents=True)
    (sdk_view / "platforms").mkdir()
    (sdk_view / "platform-tools").symlink_to(original_sdk / "platform-tools", target_is_directory=True)
    (sdk_view / "build-tools" / BUILD_TOOLS).symlink_to(original_sdk / "build-tools" / BUILD_TOOLS, target_is_directory=True)
    (sdk_view / "platforms" / PLATFORM).symlink_to(original_sdk / "platforms" / PLATFORM, target_is_directory=True)
    for optional in ("cmdline-tools", "licenses"):
        if (original_sdk / optional).is_dir():
            (sdk_view / optional).symlink_to(original_sdk / optional, target_is_directory=True)
    environment["ANDROID_HOME"] = str(sdk_view)
    environment["ANDROID_SDK_ROOT"] = str(sdk_view)
    values = {
        "export/android/java_sdk_path": toolchain["java_home"],
        "export/android/android_sdk_path": str(sdk_view),
        "export/android/debug_keystore": environment["GODOT_ANDROID_KEYSTORE_DEBUG_PATH"],
    }
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
                        "".join(f"{key} = {json.dumps(value)}\n" for key, value in values.items()),
                        encoding="utf-8")
    # Existing unrelated encryption/release credentials must not influence this debug build.
    environment.pop("GODOT_SCRIPT_ENCRYPTION_KEY", None)
    for suffix in ("PATH", "USER", "PASSWORD"):
        environment.pop("GODOT_ANDROID_KEYSTORE_RELEASE_" + suffix, None)


def configure_copy(project: Path, toolchain: dict) -> None:
    config = read_config(project / "export_presets.cfg")
    options = toolchain["preset_section"] + ".options"
    config.set(options, "custom_template/debug", json.dumps(str(Path(toolchain["template_dir"]) / "android_debug.apk")))
    release = Path(toolchain["template_dir"]) / "android_release.apk"
    if release.is_file():
        config.set(options, "custom_template/release", json.dumps(str(release)))
    for abi in ("armeabi-v7a", "arm64-v8a", "x86", "x86_64"):
        config.set(options, "architectures/" + abi, "true" if abi == toolchain["abi"] else "false")
    with (project / "export_presets.cfg").open("w", encoding="utf-8") as stream:
        config.write(stream, space_around_delimiters=False)


def atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix="." + destination.name + ".", dir=destination.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as output, source.open("rb") as origin:
            shutil.copyfileobj(origin, output)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def build(args: argparse.Namespace, toolchain: dict, environment: dict[str, str]) -> Path:
    output = (args.output or REPOSITORY / "builds/android" / f"IMPERATHEN-{args.abi}-debug.apk").expanduser().resolve()
    if output.suffix.lower() != ".apk":
        raise BuildError("Die Ausgabedatei muss die Endung .apk besitzen.")
    if inside(output, Path(toolchain["project"])):
        raise BuildError("Die APK-Ausgabe muss außerhalb des importierten Godot-Projekts liegen.")
    with tempfile.TemporaryDirectory(prefix="imperathen-android-build-") as temporary_name:
        temporary = Path(temporary_name)
        project = temporary / "project"
        shutil.copytree(toolchain["project"], project,
                        ignore=shutil.ignore_patterns(".godot", ".git", "android", "*.tmp", "*.bak"))
        configure_copy(project, toolchain)
        write_isolated_settings(temporary, toolchain, environment)
        apk = temporary / "IMPERATHEN.apk"
        run([toolchain["godot"], "--headless", "--path", str(project), "--editor", "--import"],
            environment, "Projekt und Assets importieren", timeout=args.timeout)
        run([toolchain["godot"], "--headless", "--path", str(project), "--export-debug", PRESET, str(apk)],
            environment, f"Android-{args.abi}-APK exportieren", timeout=args.timeout)
        if not apk.is_file() or apk.stat().st_size == 0:
            raise BuildError("Godot hat keine nichtleere APK erzeugt.")
        verification = temporary / "validation.json"
        build_tools = Path(toolchain["sdk_root"]) / "build-tools" / BUILD_TOOLS
        run([sys.executable, toolchain["validator"], "--apk", str(apk),
             "--sdk-root", toolchain["sdk_root"], "--source-root", toolchain["project"], "--expected-package", PACKAGE,
             "--expected-abi", args.abi, "--report", str(verification),
             "--aapt", str(build_tools / "aapt"), "--apksigner", str(build_tools / "apksigner"),
             "--zipalign", str(build_tools / "zipalign")],
            environment, "APK, Signatur, Manifest und ABI prüfen", timeout=args.timeout)
        if not verification.is_file():
            raise BuildError("Der APK-Prüfläufer hat keinen Prüfbericht erzeugt.")
        report = json.loads(verification.read_text(encoding="utf-8"))
        if report.get("overall_status") != "pass":
            raise BuildError("Der APK-Prüfbericht meldet keinen vollständigen statischen Erfolg.")
        checksum = file_sha256(apk)
        if report.get("apk", {}).get("sha256") != checksum:
            raise BuildError("Prüfbericht und tatsächlich erzeugte APK besitzen unterschiedliche Prüfsummen.")
        # A failed build never promotes an old or unverified APK as a new result.
        atomic_copy(apk, output)
        atomic_copy(verification, output.with_suffix(".validation.json"))
        sha_file = temporary / "artifact.sha256"
        sha_file.write_text(f"{checksum}  {output.name}\n", encoding="utf-8")
        atomic_copy(sha_file, output.with_suffix(".apk.sha256"))
        build_report = {key: value for key, value in toolchain.items()
                        if key not in {"preset_section", "validator"}}
        build_report.update({"status": "verified_debug_apk", "created_utc": datetime.now(timezone.utc).isoformat(),
                             "apk": output.name, "apk_sha256": checksum, "apk_size_bytes": output.stat().st_size,
                             "signing": "externally_supplied_debug_key", "device_test": "not_run_by_build_tool",
                             "validation_report": output.with_suffix(".validation.json").name})
        source_commit = environment.get("GITHUB_SHA", "")
        if re.fullmatch(r"[0-9a-fA-F]{40}", source_commit):
            build_report["source_commit"] = source_commit
        manifest = temporary / "build.json"
        manifest.write_text(json.dumps(build_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        atomic_copy(manifest, output.with_suffix(".build.json"))
    print(f"ANDROID_BUILD_PASS {output}", flush=True)
    print(f"SHA256 {checksum}", flush=True)
    return output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path/name of the Godot 4.7.2 executable")
    parser.add_argument("--project", type=Path, default=REPOSITORY / "prototype")
    parser.add_argument("--sdk-root", type=Path, help="Android SDK root, otherwise ANDROID_HOME")
    parser.add_argument("--java-home", type=Path, help="JDK17, otherwise JAVA_HOME_17_X64/JAVA_HOME")
    parser.add_argument("--template-dir", type=Path, help="Official templates directory including version.txt")
    parser.add_argument("--keystore", type=Path, help="Private debug key outside the repository")
    parser.add_argument("--keystore-user", help="Key alias; password is accepted only through the environment")
    parser.add_argument("--abi", choices=ABIS, default="arm64-v8a")
    parser.add_argument("--output", type=Path, help="Destination .apk; previous file remains untouched on export failure")
    parser.add_argument("--check", action="store_true", help="Check local prerequisites without exporting")
    parser.add_argument("--timeout", type=int, default=300, help="Per-tool timeout in seconds")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.timeout <= 0:
        print("ANDROID_BUILD_FAIL --timeout muss positiv sein.", file=sys.stderr)
        return 2
    try:
        toolchain, environment = preflight(args)
        if args.check:
            print(json.dumps({"status": "prerequisites_ready", **toolchain}, ensure_ascii=False, indent=2))
            print("ANDROID_PREFLIGHT_PASS")
            return 0
        build(args, toolchain, environment)
        return 0
    except (BuildError, OSError, ValueError, configparser.Error) as error:
        print("ANDROID_BUILD_FAIL " + redact(str(error), dict(os.environ)), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
