#!/usr/bin/env python3
"""Collect production menu/story renders; never execute unreviewed agent code."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PNG = b"\x89PNG\r\n\x1a\n"
MAX_IMAGE = 2_200_000
EXPECTED = ("menu.png", "01-prolog.png", "02-morgenwahl.png", "03-familienhaus.png",
            "04-brunnen.png", "04b-gefuellter-krug.png", "05-tischgespraech.png",
            "06-auf-der-schwelle.png")

def image_receipt(path):
    if path.is_symlink() or not path.is_file():
        return None
    data = path.read_bytes()
    if not 1024 < len(data) <= MAX_IMAGE or not data.startswith(PNG) or data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    if not (320 <= width <= 4096 and 240 <= height <= 4096):
        return None
    return {"file": path.name, "sha256": hashlib.sha256(data).hexdigest(),
            "width": width, "height": height, "bytes": len(data)}

def stage(name, argv, seconds, out, env, marker=None):
    log = out / (name + ".log")
    timed_out = False
    with log.open("wb") as stream:
        try:
            result = subprocess.run(argv, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=seconds, check=False)
            code = result.returncode
        except subprocess.TimeoutExpired:
            timed_out, code = True, None
    text = log.read_text(encoding="utf-8", errors="replace")
    found = marker is None or marker in text
    passed = code == 0 and found and not timed_out
    print("CAMPAIGN_CAPTURE", name, "pass" if passed else "fail", "exit", code, flush=True)
    return {"name": name, "exit_code": code, "timeout": timed_out, "marker_found": found,
            "passed": passed, "log": log.name}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    godot = str(Path(args.godot).resolve(strict=True))
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit("Output must be empty; evidence cannot be reused.")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    env = dict(os.environ, IMPERATHEN_ISOLATED_TEST="1", LIBGL_ALWAYS_SOFTWARE="1",
               GODOT_SILENCE_ROOT_WARNING="1")
    stages = []
    with tempfile.TemporaryDirectory(prefix="imperathen-journey-") as work:
        for name in ("import", "menu", "playthrough"):
            local_env = dict(env)
            for key, leaf in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                              ("XDG_CACHE_HOME", "cache")):
                target = Path(work) / name / leaf
                target.mkdir(parents=True)
                local_env[key] = str(target)
            if name == "import":
                cmd = [godot, "--headless", "--path", "prototype", "--import", "--quit"]
                stages.append(stage(name, cmd, 600, out, local_env))
                if not stages[-1]["passed"]:
                    break
            else:
                cmd = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", godot,
                       "--path", "prototype", "--audio-driver", "Dummy",
                       "--rendering-method", "gl_compatibility", "--resolution", "1280x720"]
                if name == "menu":
                    cmd += ["--script", "res://tests/menu_review.gd", "--", str(out), "menu"]
                    stages.append(stage(name, cmd, 120, out, local_env))
                else:
                    cmd += ["--fixed-fps", "60", "--script", "res://tests/i01_playthrough_test.gd",
                            "--", "--capture-dir=" + str(out)]
                    stages.append(stage(name, cmd, 1200, out, local_env, "I01_PLAYTHROUGH_PASS"))
    images = [item for name in EXPECTED if (item := image_receipt(out / name))]
    missing = [name for name in EXPECTED if not any(item["file"] == name for item in images)]
    report = {"schema": 1, "source_revision": revision,
              "capture": "actual Godot menu and production New Life I-01 playthrough",
              "renderer": "gl_compatibility / Linux software", "physical_device_pass": False,
              "visual_acceptance": False, "stages": stages, "images": images,
              "missing_or_invalid_images": missing,
              "engine_pass": len(stages) == 3 and all(s["passed"] for s in stages) and not missing}
    (out / "campaign-start-receipt.json").write_text(json.dumps(report, indent=2) + "\n")
    print("CAMPAIGN_START_RECEIPT", json.dumps(report), flush=True)
    return 0 if report["engine_pass"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
