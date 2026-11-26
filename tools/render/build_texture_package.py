#!/usr/bin/env python3
"""Build a separate texture graphics package (D-034) as a Godot resource pack.

A package overrides imported textures at their res:// paths. It contains, for
every selected texture, the re-imported `.import` remap and its `.ctex` files,
built in a disposable copy of the project so tracked import settings and the
developer's own `.godot` cache stay untouched. The game mounts a package at
start with ProjectSettings.load_resource_pack(..., true)
(scripts/rendering/render_profile.gd mount_texture_package()).

Tiers:
  vram   every 3D texture that is imported lossless (compress/mode 0/1) becomes
         VRAM compressed (S3TC/BPTC on desktop, ETC2/ASTC on mobile). Same
         resolution; UI textures stay lossless.
  half   as vram, and textures whose longest side is >= --min-size get half
         their resolution (process/size_limit).

Usage:
  python3 tools/render/build_texture_package.py --godot GODOT --tier half \
      --work /path/to/scratch/copy --out prototype/packages/textures_half.pck [--lock FILE]
"""
from __future__ import annotations

import argparse
import configparser
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "prototype"
SKIP_PREFIXES = ("assets/ui/",)
PACKER = """extends SceneTree
func _initialize() -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var packer := PCKPacker.new()
	var status := packer.pck_start(OS.get_cmdline_user_args()[1])
	for entry: Dictionary in list:
		if status == OK:
			status = packer.add_file(entry.target, entry.source)
	if status == OK:
		status = packer.flush()
	print("TEXTURE_PACKAGE_PACKED ", status, " ", list.size())
	quit(0 if status == OK else 1)
"""


def image_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        data = handle.read(64 * 1024)
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    if data[:2] == b"\xff\xd8":
        index = 2
        while index < len(data) - 9:
            if data[index] != 0xFF:
                index += 1
                continue
            marker = data[index + 1]
            if marker in (0xC0, 0xC1, 0xC2):
                height, width = struct.unpack(">HH", data[index + 5:index + 9])
                return width, height
            index += 2 + struct.unpack(">H", data[index + 2:index + 4])[0]
    return 0, 0


def read_import(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def set_param(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    if pattern.search(text):
        return pattern.sub(f"{key}={value}", text)
    return text.rstrip("\n") + f"\n{key}={value}\n"


def select(project: Path, tier: str, min_size: int, vram_min: int = 256) -> list[dict]:
    chosen = []
    for imp in sorted(project.glob("assets/**/*.import")):
        source = imp.with_suffix("")
        relative = source.relative_to(project).as_posix()
        if source.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp") or relative.startswith(SKIP_PREFIXES):
            continue
        if not source.is_file():
            continue
        text = read_import(imp)
        if 'importer="texture"' not in text:
            continue
        mode = re.search(r"^compress/mode=(\d)", text, re.MULTILINE)
        width, height = image_size(source)
        longest = max(width, height)
        lossless = mode is not None and mode.group(1) in ("0", "1")
        halve = tier == "half" and longest >= min_size
        # Small lossless textures cost little memory; they keep their import.
        if (not lossless or longest < vram_min) and not halve:
            continue
        chosen.append({"source": relative, "width": width, "height": height, "lossless_before": lossless,
                       "size_limit": longest // 2 if halve else 0,
                       "normal_map": "normal" in source.name.lower()})
    return chosen


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--tier", choices=("vram", "half"), required=True)
    parser.add_argument("--work", type=Path, required=True, help="Disposable project copy location (scratch)")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--min-size", type=int, default=1024, help="half: halve textures with this longest side or more")
    parser.add_argument("--vram-min-size", type=int, default=256, help="Compress lossless textures from this longest side")
    parser.add_argument("--from-work", type=Path, help="Seed the copy from an earlier package work folder")
    parser.add_argument("--lock", type=Path)
    parser.add_argument("--timeout", type=int, default=5400)
    args = parser.parse_args()
    work = args.work.resolve()
    copy = work / "project"
    started = time.monotonic()
    if copy.exists():
        shutil.rmtree(copy)
    work.mkdir(parents=True, exist_ok=True)
    # A previous package copy (e.g. vram) can seed the next tier (half), so only
    # textures whose settings change are imported again.
    seed = (args.from_work.resolve() / "project") if args.from_work else PROJECT
    shutil.copytree(seed, copy, symlinks=True, ignore=shutil.ignore_patterns("packages"))
    # Selection always compares with the tracked project imports.
    chosen = select(PROJECT, args.tier, args.min_size, args.vram_min_size)
    for entry in chosen:
        imp = copy / (entry["source"] + ".import")
        before = read_import(imp)
        text = set_param(before, "compress/mode", "2")
        if entry["normal_map"]:
            text = set_param(text, "compress/normal_map", "1")
        if entry["size_limit"]:
            text = set_param(text, "process/size_limit", str(entry["size_limit"]))
        if text == before:
            continue
        # Remove the old artefacts so the importer must rebuild this texture.
        for dest in re.findall(r'res://(\.godot/imported/[^"]+)', before):
            for leftover in (copy / dest, copy / re.sub(r"(-[0-9a-f]{32})\..*$", r"\1.md5", dest)):
                leftover.unlink(missing_ok=True)
        imp.write_text(text, encoding="utf-8")
    env = os.environ.copy()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    env["IMPERATHEN_ISOLATED_TEST"] = "1"
    lock = None
    if args.lock:
        lock = open(args.lock, "a+")
        fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        imported = subprocess.run([args.godot, "--headless", "--path", str(copy), "--import"], env=env, text=True,
                                  capture_output=True, timeout=args.timeout)
        (work / "import.log").write_text(imported.stdout + imported.stderr, encoding="utf-8")
        files = []
        missing = []
        for entry in chosen:
            text = read_import(copy / (entry["source"] + ".import"))
            dests = re.findall(r'"res://(\.godot/imported/[^"]+)"', text.split("[params]")[0].split("dest_files=")[-1])
            entry["dest_files"] = dests
            entry["vram_after"] = '"vram_texture": true' in text
            files.append({"target": "res://" + entry["source"] + ".import", "source": str(copy / (entry["source"] + ".import"))})
            for dest in dests:
                if (copy / dest).is_file():
                    files.append({"target": "res://" + dest, "source": str(copy / dest)})
                else:
                    missing.append(dest)
        (copy / "pack_textures.gd").write_text(PACKER, encoding="utf-8")
        (work / "files.json").write_text(json.dumps(files), encoding="utf-8")
        args.out.parent.mkdir(parents=True, exist_ok=True)
        packed = subprocess.run([args.godot, "--headless", "--path", str(copy), "--script", "res://pack_textures.gd", "++",
                                 str(work / "files.json"), str(args.out.resolve())], env=env, text=True, capture_output=True, timeout=600)
        (work / "pack.log").write_text(packed.stdout + packed.stderr, encoding="utf-8")
    finally:
        if lock:
            fcntl.flock(lock, fcntl.LOCK_UN)
            lock.close()
    ok = packed.returncode == 0 and "TEXTURE_PACKAGE_PACKED 0" in packed.stdout and not missing and imported.returncode == 0
    report = {"schema": "imperathen-texture-package-1", "tier": args.tier, "min_size": args.min_size,
              "source_commit": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True, capture_output=True).stdout.strip(),
              "package": str(args.out), "package_bytes": args.out.stat().st_size if args.out.is_file() else 0,
              "package_sha256": hashlib.sha256(args.out.read_bytes()).hexdigest() if args.out.is_file() else "",
              "textures": len(chosen), "halved": sum(1 for e in chosen if e["size_limit"]),
              "made_vram": sum(1 for e in chosen if e.get("vram_after")), "missing_dest_files": missing,
              "import_exit": imported.returncode, "pack_exit": packed.returncode,
              "elapsed_s": round(time.monotonic() - started, 1), "entries": chosen, "ok": ok}
    args.out.with_suffix(".json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print("TEXTURE_PACKAGE", json.dumps({k: report[k] for k in ("tier", "textures", "halved", "made_vram", "package_bytes", "ok")}))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
