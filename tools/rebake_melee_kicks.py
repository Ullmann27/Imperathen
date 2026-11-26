#!/usr/bin/env python3
"""Reconcile exactly three stale kick tracks with the measured production solver.

Never change motion tolerances, gameplay costs, health or other strike data.
A real Godot bake supplies every frame; unchanged moves are checked against
the original strict contract. The result is then independently remeasured.
Run only in a disposable build checkout or a dedicated correction branch.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "prototype"
TABLE = PROJECT / "scripts/domain/melee/melee_track_data.gd"
CATALOG = PROJECT / "scripts/domain/combat_actions.gd"
KICKS = ("front_kick", "side_kick", "high_kick")
ALLOWED = {"youth_unarmed/" + name for name in KICKS}
FATAL = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.M)
EXPECTED_WINDOWS = {"front_kick":(4,25,31,64), "side_kick":(5,29,36,73), "high_kick":(5,29,42,79)}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def constant(text, name):
    pattern = rf"(?m)^const {name} := (.+)$"
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1:
        raise ValueError("Missing or duplicated constant: " + name)
    return json.loads(matches[0].group(1)), matches[0]


def finite(value):
    if isinstance(value, dict):
        return all(finite(v) for v in value.values())
    if isinstance(value, list):
        return all(finite(v) for v in value)
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return math.isfinite(value)
    return isinstance(value, (str, bool)) or value is None


def compare_unaffected(old, new, key):
    for field in ("frames", "peak", "start", "end"):
        if old[field] != new[field]:
            raise ValueError(f"Unexpected {key} {field} drift")
    for field in ("base", "tip"):
        a,b = old[field],new[field]
        if len(a) != len(b) or max((abs(x-y) for x,y in zip(a,b)),default=0.0) > .002:
            raise ValueError(f"Unexpected {key} {field} geometry drift")


def reconcile(original, measured, catalog):
    old,_ = constant(original,"MOVES")
    fresh,_ = constant(measured,"MOVES")
    old_kits,_ = constant(original,"KITS")
    fresh_kits,_ = constant(measured,"KITS")
    old_guards,_ = constant(original,"GUARDS")
    fresh_guards,_ = constant(measured,"GUARDS")
    if not finite(fresh) or not finite(fresh_kits) or not finite(fresh_guards):
        raise ValueError("Nonfinite source measurement")
    if old.keys() != fresh.keys() or old_kits.keys() != fresh_kits.keys() or old_guards.keys() != fresh_guards.keys() or not ALLOWED <= old.keys():
        raise ValueError("Unexpected measured family, move or guard inventory")
    if fresh_kits["youth_unarmed"]["adult_scale_error_m"] > .002:
        raise ValueError("Adult rig scaling failed")
    for key, new in fresh.items():
        if not 1 <= new["start"] <= new["peak"] <= new["end"] < new["frames"]:
            raise ValueError("Invalid measured active window: " + key)
        if new["driving_bone_top_speed"] > 12.0 or new["support_slip_m"] > .015:
            raise ValueError("Motion threshold failed: " + key)
        if key not in ALLOWED:
            compare_unaffected(old[key],new,key)
    for key in ALLOWED:
        new = fresh[key]
        name = key.split("/")[1]
        if tuple(new[field] for field in ("start","peak","end","frames")) != EXPECTED_WINDOWS[name]:
            raise ValueError("Measured kick differs from previously recorded failing run: " + key)
        if new["kit"] != "youth_unarmed" or new["family"] != "foot" or new["duration"] != old[key]["duration"] or not 0 < new["radius"] < .2 or not 0 < new["reach"] < 2:
            raise ValueError("Invalid kick metadata: " + key)
        if len(new["base"]) != 3*new["frames"] or len(new["tip"]) != 3*new["frames"]:
            raise ValueError("Incomplete kick frame samples: " + key)
    # Preserve the original non-kick records and all body/shield data. Only
    # regenerate the three explicitly approved records from measured frames.
    _,match = constant(original,"MOVES")
    for key in sorted(ALLOWED):
        old[key] = fresh[key]
    value = json.dumps(old,ensure_ascii=False,separators=(",",":"),allow_nan=False)
    table = original[:match.start(1)] + value + original[match.end(1):]
    result = {}
    for name in KICKS:
        key = "youth_unarmed/" + name
        track = fresh[key]
        fields = {"windup":track["start"]/60, "active":(track["end"]-track["start"]+1)/60,
                  "reach":track["reach"]+old_kits["raider"]["radius"]}
        # The catalogue is informational. Derive these three fields from
        # the exact measured values rather than the rounded CI log.
        pattern = rf'(?m)^\t"{name}":\{{[^\n]+'
        matches = list(re.finditer(pattern,catalog))
        if len(matches) != 1:
            raise ValueError("Ambiguous catalogue entry: " + name)
        m = matches[0]
        entry = m.group(0)
        for field,value in fields.items():
            entry,count = re.subn(rf'("{field}":)\s*[0-9.]+',lambda x:x.group(1)+f"{value:.4f}",entry)
            if count != 1:
                raise ValueError("Missing catalogue field: " + field)
        catalog = catalog[:m.start()] + entry + catalog[m.end():]
        result[name] = {**fields,"start":track["start"],"peak":track["peak"],"end":track["end"],"support_slip_m":track["support_slip_m"],"bone_speed_m_s":track["driving_bone_top_speed"]}
    return table,catalog,result


def run(engine,args,env,log,marker=None,timeout=600):
    result = subprocess.run([engine,"--headless","--path",str(PROJECT),*args],cwd=ROOT,env=env,
                            text=True,encoding="utf-8",errors="replace",stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    log.write_text(result.stdout,encoding="utf-8")
    if result.returncode or FATAL.search(result.stdout) or (marker and marker not in result.stdout):
        print(result.stdout[-12000:],flush=True)
        raise RuntimeError("Godot measurement/check failed: " + log.name)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--report",required=True,type=Path)
    parser.add_argument("--apply",action="store_true",help="Apply measured changes in the disposable build checkout")
    args=parser.parse_args()
    report=args.report.resolve()
    report.mkdir(parents=True,exist_ok=True)
    original=TABLE.read_text(encoding="utf-8")
    catalog=CATALOG.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="imperathen-rebake-") as temp:
        scratch=Path(temp)
        env=os.environ.copy()
        env["GODOT_SILENCE_ROOT_WARNING"]="1"
        env["IMPERATHEN_ISOLATED_TEST"]="1"
        for key in ("DATA","CONFIG","CACHE"):
            path=scratch/key.lower()
            path.mkdir()
            env["XDG_"+key+"_HOME"]=str(path)
        run(args.godot,["--editor","--import"],env,report/"import.log")
        fresh=scratch/"measured.gd"
        run(args.godot,["--fixed-fps","60","--script","res://tests/melee_strike_bake.gd","--","--write","--output="+str(fresh)],
            env,report/"measure.log","MELEE_TRACKS_WRITTEN")
        table,new_catalog,metrics=reconcile(original,fresh.read_text(encoding="utf-8"),catalog)
        (report/"melee_track_data.gd").write_text(table,encoding="utf-8")
        (report/"combat_actions.gd").write_text(new_catalog,encoding="utf-8")
        (report/"receipt.json").write_text(json.dumps({"before_table":digest(original.encode()),"after_table":digest(table.encode()),"before_catalog":digest(catalog.encode()),"after_catalog":digest(new_catalog.encode()),"moves":metrics},indent=2)+"\n",encoding="utf-8")
        TABLE.write_text(table,encoding="utf-8")
        CATALOG.write_text(new_catalog,encoding="utf-8")
        verified=False
        try:
            # A new process loads the reconciled data. The original strict
            # comparison still runs and the real contact tests remain required.
            run(args.godot,["--fixed-fps","60","--script","res://tests/melee_strike_bake.gd"],env,report/"compare.log","MELEE_TRACKS_PASS")
            run(args.godot,["--script","res://tests/combat_actions_test.gd"],env,report/"combat-actions.log","COMBAT_ACTIONS_PASS")
            verified=True
        finally:
            if not args.apply or not verified:
                TABLE.write_text(original,encoding="utf-8")
                CATALOG.write_text(catalog,encoding="utf-8")
        print("MELEE_KICKS_REBAKE_PASS",json.dumps(metrics),flush=True)


if __name__=="__main__":
    main()
