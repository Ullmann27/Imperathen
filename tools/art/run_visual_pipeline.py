#!/usr/bin/env python3
"""Run the third team's reproducible art gate without changing another team's code.

Default: validate existing GLBs, import in Godot, execute visual-only invariants.
Close the visual editor before running this command (both share the import cache).
Use --rebuild to regenerate the original source kit locally. No network calls.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "art/visual_benchmark"
EVIDENCE = PROJECT / "evidence"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--render-previews", action="store_true")
    parser.add_argument("--assets-only", action="store_true", help="Skip engine work; report this boundary explicitly")
    parser.add_argument("--use-existing-import", action="store_true", help="Use a previous successful import; do not run alongside an editor asset import")
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    report = {"schema_version":1,"created_at_utc":datetime.now(timezone.utc).isoformat(),
              "pipeline":"third-team-mobile-art", "primary_platform":"Android",
              "steps":[], "android_device_tested":False, "screenshots_verified_by_this_script":False}

    def run(name, command, timeout=600):
        started=time.monotonic()
        try:
            proc=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=timeout)
            output=proc.stdout+proc.stderr
            errors=[line for line in output.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
            success=proc.returncode==0 and not errors
            step={"name":name,"command":command,"passed":success,"exit_code":proc.returncode,
                  "duration_seconds":round(time.monotonic()-started,3),"engine_errors":errors}
        except (OSError,subprocess.TimeoutExpired) as error:
            output=str(error)
            step={"name":name,"command":command,"passed":False,"error":str(error)}
        (EVIDENCE/(name+".log")).write_text(output,encoding="utf-8")
        report["steps"].append(step)
        print(f"{name}: {'PASS' if step['passed'] else 'FAIL'}",flush=True)
        if not step["passed"]:
            raise RuntimeError(f"{name} failed; see evidence/{name}.log")
        return output

    try:
        if args.rebuild:
            blender=shutil.which("blender")
            if not blender: raise RuntimeError("Blender is required for --rebuild")
            run("materials",[sys.executable,"tools/art/generate_materials.py"])
            arch=[blender,"--background","--factory-startup","--python","tools/art/build_architecture.py","--"]
            chars=[blender,"--background","--factory-startup","--python","tools/art/build_characters.py","--"]
            if args.render_previews:
                arch.append("--render-previews")
                chars.append("--render-preview")
            run("architecture",arch)
            run("characters",chars)
        elif args.render_previews:
            raise RuntimeError("--render-previews requires --rebuild")

        run("asset_gate",[sys.executable,"tools/art/validate_visual_assets.py","--output",str(EVIDENCE/"asset_validation.json")])
        assets=json.loads((EVIDENCE/"asset_validation.json").read_text())
        expected={"frontier_house","house_foundation","village_well","civilian_youth","frontier_guard","civilian_youth_lod1","frontier_guard_lod1"}
        found={p.stem for p in (PROJECT/"assets").rglob("*.glb")}
        if not expected.issubset(found): raise RuntimeError("Missing contracted assets: "+str(sorted(expected-found)))
        report["asset_hashes"]={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((PROJECT/"assets").rglob("*.glb"))}
        source_files=[PROJECT/"project.godot",PROJECT/"quality_profiles.json",*(PROJECT/"scripts").glob("*.gd"),*(ROOT/"tools/art").glob("*.py")]
        report["source_hashes"]={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)}
        report["assets_checked"]=assets["assets_checked"]

        if not args.assets_only:
            godot=shutil.which("godot") or shutil.which("godot4")
            if not godot: raise RuntimeError("Godot is required unless --assets-only is selected")
            report["engine_version"]=subprocess.check_output([godot,"--version"],text=True).strip()
            if not args.use_existing_import:
                run("godot_import",[godot,"--headless","--path",str(PROJECT),"--import"])
            else:
                report["steps"].append({"name":"godot_import","skipped":True,"reason":"explicit --use-existing-import"})
            output=run("godot_invariants",[godot,"--headless","--path",str(PROJECT),"--","--verify"],60)
            rows=[line.partition("VISUAL_INVARIANTS ")[2] for line in output.splitlines() if line.startswith("VISUAL_INVARIANTS ")]
            if len(rows)!=1: raise RuntimeError("Missing unambiguous engine invariant receipt")
            invariant=json.loads(rows[0])
            if not invariant.get("passed"): raise RuntimeError("Engine invariant receipt failed")
            (EVIDENCE/"engine_invariants.json").write_text(json.dumps(invariant,indent=2)+"\n",encoding="utf-8")
            palette_output=run("character_palette",[godot,"--headless","--path",str(PROJECT),"--script","res://scripts/verify_character_materials.gd"],60)
            palette_rows=[line.partition("CHARACTER_PALETTE_VALIDATION ")[2] for line in palette_output.splitlines() if line.startswith("CHARACTER_PALETTE_VALIDATION ")]
            if len(palette_rows)!=1 or json.loads(palette_rows[0]).get("status")!="passed":
                raise RuntimeError("Character palette regression check failed")
        else:
            report["engine_skipped"]=True
        report["passed"]=True
    except (RuntimeError,OSError,ValueError,subprocess.SubprocessError) as error:
        report["passed"]=False
        report["error"]=str(error)
        print(str(error),file=sys.stderr)
    (EVIDENCE/"pipeline_receipt.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__=="__main__":
    sys.exit(main())
