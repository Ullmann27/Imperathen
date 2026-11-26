"""Plant the lead foot of the shared company attack (glTF post-export step).

The company attack (art/soldiers/build.py, reused by the field company, the
village soldiers and villagers, the frontier people and the Meshy units)
rotated the left thigh by -12 degrees times the swing envelope and back, with
no knee or ankle compensation, no lift and no pelvis motion. The straight leg
therefore swept its sole 13-19 cm forward and back over the floor while it
stayed inside the motion gate's 2 cm contact band: foot skating, not a step.
VillagePerson's world-foot solver could only hide part of it with corrective
turning steps (2-5 cm residual slip), and the battle Soldier, which plays the
clip without a solver, showed the full 17 cm.
The "train" clip of the frontier civilians and Meshy units reuses the same
pose (build_meshy_people.py maps it to the attack) and is planted the same way.

The pelvis and every other leg joint are static in this clip. With the sole
held at its planted first-pose contact, the two-bone leg below that fixed hip
has exactly one solution: its own first pose. This step therefore writes the
clip's first Thigh_L rotation key over the remaining keys of that one sampler,
in place. The cut's weight transfer stays in the authored spine, shoulder and
arm tracks. The source pose in art/soldiers/build.py no longer authors the
sweep, so a rebuild produces the same channel.

Preconditions are verified, not assumed: exactly one attack clip, a Thigh_L
rotation track whose first key is the node's rest rotation, every other leg
and pelvis channel constant, an output accessor used by no other sampler, and
a measured sole slip that falls to the gate bound without any penetration
increase. All other bytes stay unchanged (checked before writing); a marker in
the animation extras makes the step idempotent.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ground_death_clip as grounding  # noqa: E402  (shared glTF reader, CPU skinning and gate surface rule)

# The "train" clip of the frontier civilians and Meshy units reuses the same pose.
CLIPS = ("attack", "train")
JOINT = "Thigh_L"
MARKER = "imperathen_planted_attack"
GATE_SLIP_M = .015
STATIC_JOINTS = ("Pelvis", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R", "Toe_L", "Toe_R")


def _same_rotation(a: np.ndarray, b: np.ndarray, tolerance: float = 1e-5) -> bool:
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    return abs(abs(float(np.dot(a, b))) - 1.0) <= tolerance


def _plant_clip(glb, rig, clip_name: str, path: Path) -> dict | None:
    """Plant one company attack clip in memory; None when it has no lead-leg sweep."""
    names = {node.get("name"): index for index, node in enumerate(rig.nodes)}
    clip = rig.animation(clip_name)
    animation = clip["animation"]
    if MARKER in animation.get("extras", {}):
        return {"clip": clip_name, "skipped": "already planted"}
    joint = names[JOINT]
    track = clip["tracks"].get((joint, "rotation"))
    if track is None:
        raise ValueError(f"{path}: the {clip_name} clip has no {JOINT} rotation track")
    times, values, interpolation = track
    if float(np.abs(values - values[0]).max()) <= 1e-6:
        return None
    if interpolation != "LINEAR" or not _same_rotation(values[0], rig.rest[joint][1]):
        raise ValueError(f"{path}: {clip_name} {JOINT} does not start from its rest rotation")
    for (node, channel), (_, channel_values, _) in clip["tracks"].items():
        name = rig.nodes[node].get("name")
        if name in STATIC_JOINTS and float(np.abs(channel_values - channel_values[0]).max()) > 1e-6:
            raise ValueError(f"{path}: {name}/{channel} moves in {clip_name}; a constant thigh would not plant the sole")
    channel = next(c for c in animation["channels"] if c["target"]["node"] == joint and c["target"]["path"] == "rotation")
    output = int(animation["samplers"][channel["sampler"]]["output"])
    users = sum(1 for a in glb.document["animations"] for s in a["samplers"] if output in (s["input"], s["output"]))
    if users != 1:
        raise ValueError(f"{path}: the {clip_name} {JOINT} output accessor is shared")
    before = grounding.measure(rig, clip)
    planted = np.repeat(values[:1], len(values), axis=0)
    clip["tracks"][(joint, "rotation")] = (times, planted, interpolation)
    after = grounding.measure(rig, clip)
    if after["max_sole_slip_m"] > GATE_SLIP_M or after["max_sole_penetration_m"] > before["max_sole_penetration_m"] + 1e-6:
        raise ValueError(f"{path}: planting does not bring {clip_name} within the gate: {after}")
    sweep = max(2 * np.arccos(min(1.0, abs(float(np.dot(v / np.linalg.norm(v), values[0] / np.linalg.norm(values[0]))))))
                for v in values)
    glb.overwrite_accessor(output, planted)
    animation.setdefault("extras", {})[MARKER] = {
        "tool": "tools/characters/plant_company_attack.py", "joint": JOINT,
        "replaced_sampler_output_accessor": output,
        "max_sole_slip_before_m": round(before["max_sole_slip_m"], 6),
        "max_sole_slip_m": round(after["max_sole_slip_m"], 6),
        "max_sole_penetration_m": round(after["max_sole_penetration_m"], 6)}
    return {"clip": clip_name, "joint": JOINT, "keys": int(len(times)), "max_thigh_sweep_deg": float(np.degrees(sweep)),
            "before": before, "after": after}


def plant(path: Path, write: bool = True) -> dict:
    glb = grounding.Glb(path)
    rig = grounding.Rig(glb)
    present = {animation.get("name") for animation in glb.document.get("animations", [])}
    if "attack" not in present:
        raise ValueError(f"{path}: no company attack clip")
    report = {"path": str(path), "sha256_before": hashlib.sha256(path.read_bytes()).hexdigest(), "clips": []}
    for clip_name in CLIPS:
        if clip_name in present:
            result = _plant_clip(glb, rig, clip_name, path)
            if result is not None:
                report["clips"].append(result)
    if write and any("before" in clip for clip in report["clips"]):
        glb.write(path)
        report["sha256_after"] = hashlib.sha256(path.read_bytes()).hexdigest()
        report["bytes_after"] = path.stat().st_size
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("glb", nargs="+", type=Path)
    parser.add_argument("--check", action="store_true", help="measure only, do not write")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    reports = []
    for path in args.glb:
        report = plant(path, not args.check)
        reports.append(report)
        for clip in report["clips"]:
            if "skipped" in clip:
                print(f"PLANT {clip['clip']} {path} {clip['skipped']}")
                continue
            b, a = clip["before"], clip["after"]
            print(f"PLANT {clip['clip']} {path} sweep {clip['max_thigh_sweep_deg']:.1f} deg slip {b['max_sole_slip_m']:.4f}->"
                  f"{a['max_sole_slip_m']:.4f} penetration {b['max_sole_penetration_m']:.4f}->{a['max_sole_penetration_m']:.4f} "
                  f"contact slip {b['max_contact_slip_m']:.4f}->{a['max_contact_slip_m']:.4f}")
    if args.report:
        args.report.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
