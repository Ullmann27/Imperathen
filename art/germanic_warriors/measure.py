"""Measure clipping and ground contact of the exported Germanic figures.

    blender -b -P art/germanic_warriors/measure.py -- [figure ids]

Imports each exported LOD 0 GLB (the shipped bytes, not the Blender source),
plays idle, march and attack (plus block, run and hit) and samples every
exported frame. Reported per clip:

* layer clipping: how far a vertex of an inner layer (skin, trousers, tunic)
  comes through an outer layer (tunic skirt, mail, cloak, pelt) that covered
  it at rest, measured along the outer surface normal;
* equipment clipping: triangle intersections between carried gear and the
  body or clothing (the closed hand round its own grip is excluded);
* ground: sole penetration and sole slip of the non-locomotion clips with the
  rule of tools/characters/ground_death_clip.py (march and run move the root
  in the game; their contact is measured by the engine gate, not here).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/characters"))
import ground_death_clip  # noqa: E402

CLIPS = ("idle", "march", "attack", "block", "run", "hit")
OUTER = ("TunicSkirt", "MailSkirt", "Mail", "Cloak", "Pelt", "Tunic")
INNER_OF = {
    "TunicSkirt": ("Trousers",),
    "MailSkirt": ("TunicSkirt", "Trousers"),
    "Mail": ("Tunic",),
    "Tunic": ("GermanicBody",),
    "Cloak": ("Tunic", "Mail", "GermanicBody", "Pelt", "Belt", "TunicSkirt", "MailSkirt"),
    "Pelt": ("Tunic", "GermanicBody", "Mail"),
}
THRESHOLD_M = .005


def import_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    # Only the skinned figure meshes; the importer's bone-display helpers
    # (e.g. "Icosphere") are not part of the asset.
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"
              and any(m.type == "ARMATURE" for m in o.modifiers)]
    return arm, meshes


def base_name(obj):
    name = obj.name.split(".")[0]
    return name


def evaluated(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result = {}
    for obj in objects:
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        matrix = ev.matrix_world.copy()
        verts = [matrix @ v.co for v in mesh.vertices]
        polys = [tuple(p.vertices) for p in mesh.polygons]
        groups = None
        result[obj.name] = (verts, polys)
        ev.to_mesh_clear()
    return result


def hand_vertices(obj):
    names = {g.index: g.name for g in obj.vertex_groups}
    keep = set()
    for v in obj.data.vertices:
        w = sum(g.weight for g in v.groups if names.get(g.group, "").startswith(("Hand", "Forearm")))
        if w > .3:
            keep.add(v.index)
    return keep


def action_for(arm, name):
    for action in bpy.data.actions:
        if action.name == name or action.name.startswith(name + "_") or action.name.endswith("_" + name):
            return action
    tracks = arm.animation_data.nla_tracks if arm.animation_data else []
    for track in tracks:
        for strip in track.strips:
            if strip.action and (strip.action.name == name or track.name == name):
                return strip.action
    return None


def measure_figure(path):
    arm, meshes = import_glb(path)
    scene = bpy.context.scene
    by_name = {}
    for obj in meshes:
        by_name.setdefault(base_name(obj), []).append(obj)
    gear = [o for o in meshes if o.name.startswith("Gear_")]
    hands = {o.name: hand_vertices(o) for o in meshes if base_name(o) == "GermanicBody"}
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    rest = evaluated(meshes)
    # Which inner vertices lie under which outer layer at rest (within 6 cm,
    # on the inner side of the outer surface).
    pairs = []
    for outer_name, inner_names in INNER_OF.items():
        for outer in by_name.get(outer_name, []):
            o_verts, o_polys = rest[outer.name]
            if not o_polys:
                continue
            tree = BVHTree.FromPolygons(o_verts, o_polys)
            # Vertices near the outer layer's open edges (collar, cuffs, hem)
            # are beside it, not under it: skip a 2.5 cm band along the rims.
            edge_count = {}
            for poly in o_polys:
                for a, b in zip(poly, poly[1:] + poly[:1]):
                    key = (min(a, b), max(a, b))
                    edge_count[key] = edge_count.get(key, 0) + 1
            rim = [o_verts[i] for key, c in edge_count.items() if c == 1 for i in key]
            rim_tree = KDTree(max(1, len(rim)))
            for i, p in enumerate(rim):
                rim_tree.insert(p, i)
            rim_tree.balance()
            for inner_name in inner_names:
                for inner in by_name.get(inner_name, []):
                    i_verts, _ = rest[inner.name]
                    under = []
                    for k, v in enumerate(i_verts):
                        hit = tree.find_nearest(v, .06)
                        if hit[0] is None or (v - hit[0]).dot(hit[1]) >= 0:
                            continue
                        if rim and rim_tree.find(hit[0])[2] < .025:
                            continue
                        under.append(k)
                    if under:
                        pairs.append((outer, inner, under))
    results = {}
    for clip in CLIPS:
        action = action_for(arm, clip)
        if action is None:
            results[clip] = {"error": "clip missing"}
            continue
        arm.animation_data.action = action
        first, last = int(action.frame_range[0]), int(action.frame_range[1])
        layer_max, layer_count, gear_pairs, worst = 0.0, 0, 0, {}
        frames = list(range(first, last + 1))
        for frame in frames:
            scene.frame_set(frame)
            posed = evaluated(meshes)
            for outer, inner, under in pairs:
                o_verts, o_polys = posed[outer.name]
                tree = BVHTree.FromPolygons(o_verts, o_polys)
                i_verts, _ = posed[inner.name]
                for k in under:
                    hit = tree.find_nearest(i_verts[k], .08)
                    if hit[0] is None:
                        continue
                    depth = (i_verts[k] - hit[0]).dot(hit[1])
                    if depth > 0:
                        # The surface normal can flip at cloth rims; only a
                        # vertex really outside the layer counts.
                        if depth > THRESHOLD_M:
                            layer_count += 1
                        if depth > layer_max:
                            layer_max = depth
                            worst = {"outer": base_name(outer), "inner": base_name(inner), "frame": frame,
                                     "depth_m": round(depth, 4)}
            trees = {}
            for other in meshes:
                if other.name.startswith("Gear_") or base_name(other).startswith(("ArmRing", "TrimCuff")):
                    continue
                verts, polys = posed[other.name]
                if base_name(other) == "GermanicBody":
                    skip = hands[other.name]
                    polys = [p for p in polys if not any(i in skip for i in p)]
                if polys:
                    trees[other.name] = BVHTree.FromPolygons(verts, polys)
            grips = []
            for bone_name in ("Hand_L", "Hand_R"):
                bone = arm.pose.bones.get(bone_name)
                if bone:
                    grips.append(arm.matrix_world @ bone.head)  # the wrist joint
            for item in gear:
                g_verts, g_polys = posed[item.name]
                g_tree = BVHTree.FromPolygons(g_verts, g_polys)
                for name, o_tree in trees.items():
                    if "scabbard" in item.name and name.startswith("Belt"):
                        continue  # hung on the belt by design
                    hits = g_tree.overlap(o_tree)
                    # The shaft or handle passing through its own closed hand
                    # (and the cuff right at the wrist) is the grip, not clipping.
                    hits = [h for h in hits if min((sum((g_verts[i] for i in g_polys[h[0]]), Vector()) / len(g_polys[h[0]]) - g).length
                                                   for g in grips) > .11]
                    if hits:
                        gear_pairs += len(hits)
                        key = base_name(item) + "/" + name.split(".")[0]
                        worst_gear = results.setdefault("_gear_detail", {})
                        worst_gear.setdefault(clip, {})
                        worst_gear[clip][key] = max(worst_gear[clip].get(key, 0), len(hits))
        results[clip] = {"frames": len(frames), "max_layer_penetration_m": round(layer_max, 4),
                         "layer_vertex_samples_over_5mm": layer_count, "gear_intersecting_triangle_pairs": gear_pairs,
                         "worst_layer": worst}
    detail = results.pop("_gear_detail", {})
    return results, detail


def ground_metrics(path):
    glb = ground_death_clip.Glb(path)
    rig = ground_death_clip.Rig(glb)
    out = {}
    for clip in ("idle", "attack", "block", "hit", "death", "shoot"):
        try:
            out[clip] = {k: round(v, 4) for k, v in ground_death_clip.measure(rig, rig.animation(clip)).items()}
        except (KeyError, StopIteration, ValueError) as error:
            out[clip] = {"error": str(error)}
    return out


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    registry = json.loads((HERE / "registry.json").read_text())
    ids = args or [f["id"] for f in registry["figures"]]
    import os
    export = Path(os.environ.get("GERMANIC_EXPORT", HERE / "export"))
    report_path = Path(os.environ.get("GERMANIC_MEASUREMENTS", HERE / "measurements.json"))
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    report["method"] = __doc__.strip().split("\n\n", 1)[1]
    report.setdefault("figures", {})
    for fid in ids:
        path = export / "figures" / f"germanic_{fid}_0.glb"
        clips, gear = measure_figure(path)
        report["figures"][fid] = {"lod0_sha256": __import__("hashlib").sha256(path.read_bytes()).hexdigest(),
                                  "clips": clips, "gear_contacts": gear, "ground": ground_metrics(path)}
        print("GERMANIC_MEASURED", fid, json.dumps(clips))
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
