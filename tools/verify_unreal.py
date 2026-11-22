#!/usr/bin/env python3
"""Verify source consistency and native rules; never claim to compile Unreal."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game/Imperathen"


def verify():
    descriptor = json.loads((GAME / "Imperathen.uproject").read_text(encoding="utf-8"))
    modules = descriptor.get("Modules", [])
    assert [(m["Name"], m["Type"]) for m in modules] == [("Imperathen", "Runtime")], "Runtime module mismatch"
    for relative in (
        "Source/Imperathen.Target.cs", "Source/ImperathenEditor.Target.cs",
        "Source/Imperathen/Imperathen.Build.cs", "Source/Imperathen/Private/Imperathen.cpp",
        "Source/Imperathen/Public/ImperathenGameMode.h", "Source/Imperathen/Private/ImperathenGameMode.cpp",
        "Source/Imperathen/Public/ImperathenSaveGame.h", "Source/Imperathen/Public/ImperathenSettings.h",
        "Source/Imperathen/Private/SImperathenMenu.h", "Source/Imperathen/Private/SImperathenMenu.cpp",
    ):
        assert (GAME / relative).is_file(), f"Missing source {relative}"
    source = GAME / "Source/Imperathen"
    headers = {p.name for p in source.rglob("*.h")}
    for path in source.rglob("*.*"):
        if path.suffix not in {".cpp", ".h"}:
            continue
        code = path.read_text(encoding="utf-8")
        includes = re.findall(r'^#include\s+"([^"]+)"', code, re.M)
        if "UCLASS(" in code:
            assert includes and includes[-1] == path.stem + ".generated.h", f"Generated header must be last: {path.name}"
        for header in includes:
            if header.startswith("Imperathen") and not header.endswith(".generated.h"):
                assert header in headers, f"Missing local include {header}"
    config = (GAME / "Config/DefaultEngine.ini").read_text(encoding="utf-8")
    assert "GlobalDefaultGameMode=/Script/Imperathen.ImperathenGameMode" in config
    assert "GameDefaultMap=/Engine/Maps/Entry" in config
    assert "Slate" in (source / "Imperathen.Build.cs").read_text(encoding="utf-8")
    print("Unreal source structure: descriptor, targets, module, generated headers, local includes and bootstrap config passed.")

    compiler = shutil.which("c++") or shutil.which("g++") or shutil.which("clang++")
    if compiler:
        with tempfile.TemporaryDirectory(prefix="imperathen-native-") as directory:
            executable = str(Path(directory) / "native_entry_test")
            subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-I" + str(source / "Public"), str(ROOT / "tests/native_entry_test.cpp"), "-o", executable], check=True)
            subprocess.run([executable], check=True)
    else:
        print("Native rule tests: NOT RUN (C++ compiler unavailable).")
    print("Unreal Engine build, UnrealHeaderTool, cooked content and native UI: NOT RUN by this checker.")


if __name__ == "__main__":
    try:
        verify()
    except (AssertionError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
