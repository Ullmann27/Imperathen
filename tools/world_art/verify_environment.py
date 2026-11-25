#!/usr/bin/env python3
"""Import and test the world workshop in an isolated, disposable Godot project."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import struct

ROOT=Path(__file__).resolve().parents[2]
SCRIPT_DIRS=("assets/world_expansion","scripts/world_expansion","shaders/world_expansion","scenes/world_expansion")
PROJECT="""config_version=5
[application]
config/name="IMPERATHEN Weltwerkstatt Prüfung"
run/main_scene="res://scenes/world_expansion/preview.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
"""
def stage_project(target):
    target.mkdir(parents=True,exist_ok=True)
    source_hashes={}
    for relative in SCRIPT_DIRS:
        source=ROOT/"prototype"/relative
        if not source.is_dir():
            raise FileNotFoundError(source)
        for path in sorted(source.rglob("*")):
            if path.is_file() and not path.name.endswith((".import",".uid")):
                destination=target/relative/path.relative_to(source)
                destination.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(path,destination)
                source_hashes[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    (target/"assets/quality_profiles.json").parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/"prototype/assets/quality_profiles.json",target/"assets/quality_profiles.json")
    (target/"tests").mkdir(exist_ok=True)
    for source,relative in [
        (ROOT/"prototype/tests/world_expansion_environment_test.gd","tests/world_expansion_environment_test.gd"),
        (ROOT/"tools/world_art/capture.gd","tests/world_expansion_capture.gd")]:
        if source.is_file():
            shutil.copy2(source,target/relative)
            source_hashes[source.relative_to(ROOT).as_posix()]=hashlib.sha256(source.read_bytes()).hexdigest()
    (target/"project.godot").write_text(PROJECT)
    return source_hashes

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--output",type=Path,default=ROOT/"docs/26_world_expansion/evidence/engine")
    parser.add_argument("--render",action="store_true")
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    report={"schema_version":1,"created_at_utc":datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "status":"failed","render_requested":args.render,"android_device_tested":False,"steps":[]}
    try:
        if not args.godot:
            raise RuntimeError("Godot executable missing")
        with tempfile.TemporaryDirectory(prefix="imperathen-world-check-") as folder:
            stage=Path(folder)/"project"
            report["source_hashes"]=stage_project(stage)
            env=os.environ.copy()
            env.update({"XDG_DATA_HOME":str(Path(folder)/"data"),"XDG_CONFIG_HOME":str(Path(folder)/"config"),
                        "XDG_CACHE_HOME":str(Path(folder)/"cache"),"GODOT_SILENCE_ROOT_WARNING":"1",
                        "OPENBLAS_NUM_THREADS":"1"})
            def run(label,command,timeout):
                result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=timeout,check=False)
                log=result.stdout+"\n"+result.stderr
                (output/(label+".log")).write_text(log)
                errors=[line for line in log.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
                step={"name":label,"exit_code":result.returncode,"errors":errors}
                report["steps"].append(step)
                if result.returncode!=0 or errors:
                    raise RuntimeError(label+" failed; see log")
                return log
            report["engine_version"]=subprocess.check_output([args.godot,"--version"],text=True).strip()
            run("import",[args.godot,"--headless","--path",str(stage),"--editor","--quit"],120)
            log=run("runtime",[args.godot,"--headless","--path",str(stage),"--script","res://tests/world_expansion_environment_test.gd"],120)
            lines=[line.partition("WORLD_EXPANSION_TESTS ")[2] for line in log.splitlines() if line.startswith("WORLD_EXPANSION_TESTS ")]
            if len(lines)!=1:
                raise RuntimeError("Exactly one final WORLD_EXPANSION_TESTS receipt required")
            report["runtime"]=json.loads(lines[0])
            if report["runtime"].get("passed") is not True:
                raise RuntimeError("Runtime receipt does not confirm success")
            imports=report["runtime"].get("asset_import", {})
            if imports.get("checked") is not True or imports.get("passed") is not True or imports.get("asset_count") != 7:
                raise RuntimeError("Real seven-asset/21-LOD import is required; logic fixtures alone are insufficient")
            if args.render:
                capture=output/"captures"/uuid.uuid4().hex[:12];capture.mkdir(parents=True,exist_ok=False)
                prefix=[]
                if not env.get("DISPLAY"):
                    xvfb=shutil.which("xvfb-run")
                    if not xvfb:
                        raise RuntimeError("Actual graphical capture needs DISPLAY or xvfb-run; no blank headless substitutes")
                    prefix=[xvfb,"-a","-s","-screen 0 1280x720x24"]
                graphical_base=[*prefix,args.godot,"--path",str(stage),"--rendering-method","gl_compatibility","--display-driver","x11"]
                gpu_log=run("graphics_runtime",[*graphical_base,"--script","res://tests/world_expansion_environment_test.gd"],120)
                gpu_rows=[line.partition("WORLD_EXPANSION_TESTS ")[2] for line in gpu_log.splitlines() if line.startswith("WORLD_EXPANSION_TESTS ")]
                if len(gpu_rows)!=1:
                    raise RuntimeError("Missing graphical runtime receipt")
                report["graphics_runtime"]=json.loads(gpu_rows[0])
                if report["graphics_runtime"].get("passed") is not True or report["graphics_runtime"].get("multimesh_transform_readback") is not True:
                    raise RuntimeError("Actual MultiMesh renderer readback did not pass")
                command=[*graphical_base,"--script","res://tests/world_expansion_capture.gd","--",str(capture)]
                run("graphics",command,360)
                capture_report=capture/"capture.json"
                if not capture_report.is_file():
                    raise RuntimeError("Missing graphical receipt")
                report["capture"]=json.loads(capture_report.read_text())
                report["capture"]["directory"]=str(capture.relative_to(output))
                expected=["01_village_midday","02_village_sunset","03_village_night","04_vegetation_wind_t0","05_vegetation_wind_t2","06_vegetation_calm_t0","07_vegetation_calm_t2","08_capital_4000","09_regional_routes"]
                frames=report["capture"].get("frames",[])
                if [row.get("label") for row in frames] != expected:
                    raise RuntimeError("Graphical receipt does not contain exactly nine expected frames")
                for row in frames:
                    if row.get("file")!=row["label"]+".png" or row.get("diagnostics",{}).get("load_error")!="":
                        raise RuntimeError("Capture has wrong filename or unresolved asset failure")
                    picture=capture/row["file"]
                    data=picture.read_bytes()
                    if len(data)<1000 or data[:8]!=b"\x89PNG\r\n\x1a\n" or struct.unpack_from(">II",data,16)!=(1280,720):
                        raise RuntimeError("Missing or invalid 1280x720 PNG")
                    row["png_sha256"]=hashlib.sha256(data).hexdigest()
                    if not row.get("pixel_sha256"):
                        raise RuntimeError("Missing actual viewport-pixel fingerprint")
                if frames[3]["pixel_sha256"]==frames[4]["pixel_sha256"]:
                    raise RuntimeError("Wind time changed but actual vegetation pixels did not")
                if frames[5]["pixel_sha256"]!=frames[6]["pixel_sha256"]:
                    raise RuntimeError("Calm control changed despite zero wind and paused daylight")
                capital=frames[7]["diagnostics"].get("settlement",{})
                if capital.get("placed_buildings")!=4000 or capital.get("distance_enabled_buildings")!=4000:
                    raise RuntimeError("Capital capture does not prove 4000 actual placements")
            current={}
            for relative in report["source_hashes"]:
                current[relative]=hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()
            if current != report["source_hashes"]:
                raise RuntimeError("Sources changed during verification")
            report["status"]="passed"
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:
        report["error"]=str(error)
    (output/"report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print(json.dumps({"status":report["status"],"error":report.get("error"),"report":str(output/"report.json")}))
    return 0 if report["status"]=="passed" else 1

if __name__=="__main__":
    raise SystemExit(main())
