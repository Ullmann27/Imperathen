"""Run unchanged city architecture checks with a real software OpenGL renderer.

Godot's headless/dummy backend returns identity MultiMesh transforms. Use the
existing authenticated Xorg helper for an actual placement readback instead.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"docs/26_city_support/evidence/architecture"
SOURCES=[
    "prototype/scripts/rendering/city_architecture_detail.gd",
    "prototype/scripts/tests/city_architecture_detail_test.gd",
    "prototype/assets/city_detail/architecture/city_architecture_library.glb",
    "prototype/assets/city_detail/architecture/architecture_manifest.json",
]


def main() -> int:
    OUT.mkdir(parents=True,exist_ok=True)
    engine=shutil.which("godot")
    if engine is None:
        raise RuntimeError("Godot executable is missing")
    version=subprocess.check_output([engine,"--version"],text=True).strip()
    spec=importlib.util.spec_from_file_location("city_capture_display",ROOT/"tools/characters/capture_hero.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("The existing authenticated display helper is missing")
    helper=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    hashes={path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in SOURCES}
    with tempfile.TemporaryDirectory(prefix="imperathen-city-architecture-check-") as tmp:
        directory=Path(tmp)
        env=os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"]="1"
        for kind in ("DATA","CONFIG","CACHE"):
            folder=directory/kind.lower();folder.mkdir()
            env[f"XDG_{kind}_HOME"]=str(folder)
        server=stream=None
        try:
            server,stream=helper.start_display(directory,env)
            result=subprocess.run([engine,"--display-driver","x11",
                "--rendering-method","gl_compatibility","--audio-driver","Dummy",
                "--path",str(ROOT/"prototype"),"--resolution","640x360","--script",
                "res://scripts/tests/city_architecture_detail_test.gd"],cwd=ROOT,env=env,
                stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
            (OUT/"godot_validation.log").write_text(result.stdout)
            counts=re.search(r"CITY_ARCHITECTURE_DETAIL_TEST: (\d+) checks, (\d+) failures",result.stdout)
            changed=[path for path,digest in hashes.items() if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=digest]
            passed=(result.returncode==0 and counts is not None and counts[2]=="0" and
                    "OpenGL API" in result.stdout and not helper.FAILURE.search(result.stdout) and not changed)
            receipt={"passed":passed,"exit_code":result.returncode,
                     "checks":int(counts[1]) if counts else 0,"failures":int(counts[2]) if counts else None,
                     "renderer":"OpenGL Compatibility, software Mesa via authenticated Xorg","engine":version,
                     "android_device_test":False,"source_sha256":hashes,"changed_during_run":changed}
            (OUT/"godot_validation.json").write_text(json.dumps(receipt,indent=2)+"\n")
            print(json.dumps(receipt,indent=2))
            if not passed: print(result.stdout)
            return 0 if passed else 1
        finally:
            if server is not None:
                server.terminate()
                try: server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill();server.wait()
            if stream is not None: stream.close()


if __name__=="__main__": raise SystemExit(main())
