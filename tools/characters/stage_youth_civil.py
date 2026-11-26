#!/usr/bin/env python3
"""Stage the civilian outfit variant of the original youth (D-032).

Runs, in order, the committed steps
  1. build_youth_civil_outfit.py on the staged ORIGINAL youth LODs,
  2. the unchanged retarget_accad_youth.py on its output,
  3. clear_youth_civil_arms.py, which keeps hands and forearms out of the wool
     in the retargeted clips (shoulder rotation and the returning guard elbow),
and installs the untracked runtime derivatives:
  prototype/assets/characters/hero_meshy_italia_civil_{0..3}.glb
  prototype/assets/animations/accad_youth_civil_motion.json
  docs/28_city_sandbox/youth-civil-build.json
Never commit these files (private user-owned Meshy derivative).

Run it after stage_original_youth.py and BEFORE the armoured retarget step
overwrites the staged originals, or point --source at a copy of them.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ORIGINAL_MANIFEST = ROOT / "docs/28_city_sandbox/original-youth-runtime.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--source", type=Path, default=ROOT / "prototype/assets/characters",
                        help="directory with the staged ORIGINAL hero_meshy_italia_{0..3}.glb")
    parser.add_argument("--accad-archive", type=Path, required=True)
    parser.add_argument("--work", type=Path, help="scratch directory (default: a temporary one)")
    parser.add_argument("--prototype", type=Path, default=ROOT / "prototype")
    args = parser.parse_args()
    manifest = json.loads(ORIGINAL_MANIFEST.read_text(encoding="utf-8"))
    for level in range(4):
        actual = digest(args.source / f"hero_meshy_italia_{level}.glb")
        if actual != manifest["lod_sha256"][level]:
            raise SystemExit(f"LOD {level} in {args.source} is not the staged original youth (retargeted already?)")
    with tempfile.TemporaryDirectory(prefix="imperathen-youth-civil-") as temporary:
        work = args.work or Path(temporary)
        src, retargeted, mocap = work / "civil-src", work / "civil-retarget", work / "civil-mocap"
        for path in (src, retargeted, mocap):
            path.mkdir(parents=True, exist_ok=True)
        build_report = work / "youth-civil-build.json"
        motion_report = work / "accad_youth_civil_motion.json"
        subprocess.run([sys.executable, str(HERE / "build_youth_civil_outfit.py"), "--input", str(args.source),
                        "--output", str(src), "--report", str(build_report)], check=True)
        subprocess.run([sys.executable, str(HERE / "retarget_accad_youth.py"), "--archive", str(args.accad_archive),
                        "--input", str(src), "--output", str(retargeted), "--report", str(motion_report)], check=True)
        arms_report = work / "youth-civil-arms.json"
        subprocess.run([sys.executable, str(HERE / "clear_youth_civil_arms.py"), "--input", str(retargeted),
                        "--output", str(mocap), "--report", str(arms_report)], check=True)
        characters = args.prototype / "assets/characters"
        installed = []
        for level in range(4):
            target = characters / f"hero_meshy_italia_civil_{level}.glb"
            shutil.copyfile(mocap / f"hero_meshy_italia_{level}.glb", target)
            installed.append({"path": str(target.relative_to(ROOT)) if target.is_relative_to(ROOT) else str(target),
                              "sha256": digest(target), "bytes": target.stat().st_size})
        shutil.copyfile(motion_report, args.prototype / "assets/animations/accad_youth_civil_motion.json")
        report = json.loads(build_report.read_text(encoding="utf-8"))
        report["installed"] = installed
        report["motion_report_sha256"] = digest(motion_report)
        report["arm_clearance"] = json.loads(arms_report.read_text(encoding="utf-8"))
        (ROOT / "docs/28_city_sandbox").mkdir(parents=True, exist_ok=True)
        (ROOT / "docs/28_city_sandbox/youth-civil-build.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("IMPERATHEN_YOUTH_CIVIL_STAGED", json.dumps([i["sha256"][:16] for i in installed]), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
