"""Render the in-game Roman HUD review (D-038 evidence) from the real main.tscn.

Runs prototype/tests/roman_hud_review.gd under xvfb with disposable user data
and adds source commit, working-tree state and source checksums to its JSON.
The same command renders a "before" tree (pass --tree) and the current tree,
so both captures show identical states at 1280 x 720 and 1384 x 1536.

Usage: python3 tools/ui/capture_roman_hud.py --godot <godot> --output <dir> --label after [--tree <checkout>]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)
SOURCES = ["prototype/scripts/ui/game_ui.gd", "prototype/scripts/ui/touch_pad.gd", "prototype/scripts/ui/touch_action.gd",
           "prototype/scripts/ui/roman_style.gd", "prototype/scripts/main.gd", "prototype/scripts/world/game_world.gd",
           "prototype/tests/roman_hud_review.gd"]


def git(tree: Path, *arguments: str) -> str:
    return subprocess.run(["git", "-C", str(tree), *arguments], text=True, capture_output=True, check=False).stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label", default="after")
    parser.add_argument("--tree", type=Path, default=ROOT, help="Checkout whose prototype is rendered.")
    parser.add_argument("--timeout", type=int, default=700)
    parser.add_argument("--parts", default="", help="Comma list of explore, world, fixtures; empty renders all in one run.")
    args = parser.parse_args()
    engine = shutil.which(args.godot) or args.godot
    tree = args.tree.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-roman-hud-") as temporary:
        env = os.environ.copy()
        env["IMPERATHEN_ISOLATED_TEST"] = "1"
        env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        for kind in ("DATA", "CONFIG", "CACHE"):
            location = Path(temporary) / kind.lower()
            location.mkdir()
            env[f"XDG_{kind}_HOME"] = str(location)
        command = ["xvfb-run", "-a", "-s", "-screen 0 1400x1560x24", engine, "--display-driver", "x11",
                   "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--path", str(tree / "prototype"),
                   "--resolution", "1280x720", "--script", "res://tests/roman_hud_review.gd", "--", str(output), args.label] + ([args.parts] if args.parts else [])
        try:
            result = subprocess.run(command, env=env, cwd=tree, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=args.timeout)
            log, code = result.stdout, result.returncode
        except subprocess.TimeoutExpired as error:
            log, code = f"TIMEOUT {error}", None
    suffix = "" if not args.parts or len(args.parts.split(",")) == 3 else "-" + "-".join(args.parts.split(","))
    (output / f"runtime-{args.label}{suffix}.log").write_text(log, encoding="utf-8")
    passed = code == 0 and "ROMAN_HUD_REVIEW_PASS" in log
    receipt = output / f"roman-hud-review-{args.label}{suffix}.json"
    if not receipt.exists():
        print(json.dumps({"passed": False, "exit": code, "log_tail": log[-4000:]}))
        return 1
    review = json.loads(receipt.read_text(encoding="utf-8"))
    review["source_commit"] = git(tree, "rev-parse", "HEAD")
    review["source_branch"] = git(tree, "rev-parse", "--abbrev-ref", "HEAD")
    review["working_tree_changes"] = [line for line in git(tree, "status", "--porcelain").splitlines()
                                      if "hero_meshy_italia_" not in line and "youth-build.json" not in line and "accad_youth_motion" not in line]
    review["source_sha256"] = {name: hashlib.sha256((tree / name).read_bytes()).hexdigest() for name in SOURCES if (tree / name).exists()}
    review["script_errors_in_log"] = len(FAILURE.findall(log))
    review["passed"] = passed
    receipt.write_text(json.dumps(review, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "label": args.label, "commit": review["source_commit"], "output": str(output),
                      "hud_area": [{k: m[k] for k in ("resolution", "geometric_share", "pixel_share", "pixel_noise_share")} for m in review.get("hud_area", [])]}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
