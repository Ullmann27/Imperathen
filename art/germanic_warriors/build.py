"""Build the Germanic warrior families for IMPERATHEN (Blender 4.3.2).

    blender -b -t 4 -P art/germanic_warriors/build.py -- --export
    blender -b -t 4 -P art/germanic_warriors/build.py -- --export --figures river_spear
    blender -b -t 4 -P art/germanic_warriors/build.py -- --equipment

Figures: complete CC0 MakeHuman base body (adult target, as the hero), fitted
to the unchanged fifteen-bone company rig of art/soldiers/build.py, with
garments, hair, beard and the family's default loadout baked as separate
skinned meshes. Clips are the company clips (role spear or heavy), so battle
and raid code can drive them like the frontier soldiers; the skirmishers'
"shoot" clip is a javelin throw. Every export runs the shared post-export
death grounding (tools/characters/ground_death_clip.py).

Exports land in art/germanic_warriors/export/ (not in the Godot runtime tree):
registering runtime GLBs needs a motion-contract family and a human visual
review (tools/motion_quality_gate.py), see README.md.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/characters"))

import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import armoury as A  # noqa: E402
import figure as F  # noqa: E402
import materials as M  # noqa: E402
import outfit  # noqa: E402
import tailoring as T  # noqa: E402
import ground_death_clip  # noqa: E402

REGISTRY = HERE / "registry.json"
EXPORT = HERE / "export"
_scratch_dir = tempfile.TemporaryDirectory(prefix="imperathen-warriors-")
SCRATCH = Path(_scratch_dir.name)
CLIP_SECONDS = {"idle": 2, "march": 1, "run": .72, "attack": .8, "shoot": 1.28, "block": 1.2, "wall": 1.2,
                "testudo": 1.3, "hit": .48, "retreat": .88, "death": 1.2}
# Parts too small to keep at distance; they are removed at LOD 2 and 3.
FINE_DETAIL = ("ShoeLace", "Brooch", "ArmRing", "BeltRing", "HairKnotTuft", "TrimCuff", "TrimNeck", "HairTailTie",
               "HairBraidTie", "Moustache")
# Further parts dropped at LOD 3 (about 900 triangles for the whole figure).
FAR_DETAIL = ("TrimHem", "HairKnotCoil", "LegWrap")
# Attach orientation of baked items (degrees about X, Y, Z of the grip frame).
ATTACH = {
    "shield": {"rotation": (-6, 0, -12), "offset": (0, 0, 0)},
    # Swords are carried point up and a little forward, clear of the shoulder.
    "sword_R": {"rotation": (18, 0, 0), "offset": (0, 0, 0)},
    "javelins_L": {"rotation": (0, 0, 0), "offset": (0, 0, 0)},
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_registry():
    data = json.loads(REGISTRY.read_text())
    items = {item["id"]: item for item in data["equipment"]}
    return data, items


def javelin_throw(clip, t, role):
    """Overarm javelin throw for the company 'shoot' slot (skirmishers)."""
    wind = min(1.0, t / .45) if t < .45 else max(0.0, 1 - (t - .45) / .12)
    release = max(0.0, 1 - abs(t - .55) / .12)
    follow = max(0.0, min(1.0, (t - .55) / .25)) * max(0.0, 1 - (t - .80) / .20) if t > .55 else 0.0
    s = wind * wind * (3 - 2 * wind)
    angles = {
        "Spine": (-6 * s + 14 * release + 10 * follow, 0, 28 * s - 30 * release - 18 * follow),
        "Head": (0, 0, -20 * s + 18 * release),
        "Arm_R": (-150 * s - 120 * release - 40 * follow, -25 * s, 0),
        "Forearm_R": (-70 * s + 40 * release, 0, 0),
        "Hand_R": (25 * s - 20 * release, 0, 0),
        "Arm_L": (-50 * s + 20 * release, 10 * s, 0),
        "Forearm_L": (-30 * s, 0, 0),
        "Thigh_L": (-14 * s - 8 * release, 0, 0),
        "Shin_L": (10 * s, 0, 0),
        "Thigh_R": (10 * s, 0, 0),
    }
    return angles, 0.0


def animate(arm, role, throw):
    soldier = F.soldier
    soldier.LENGTHS = dict(CLIP_SECONDS)
    original = soldier.pose

    def pose(clip, t, r):
        if throw and clip == "shoot":
            return javelin_throw(clip, t, r)
        return original(clip, t, r)

    soldier.pose = pose
    try:
        soldier.animate(arm, role)
    finally:
        soldier.pose = original


def bake_item(spec, side_frame, arm, faces, belt_anchor=None, detail=0):
    builder = A.build_item(spec, faces, detail)
    obj = builder.obj("Gear_" + spec["id"] + ("" if detail == 0 else "__d%d" % detail))
    hand = spec["hand"]
    if hand == "belt":
        # Scabbard: hangs on the left hip, mouth at the belt, tip back and down.
        m = Matrix.Translation(belt_anchor) @ Matrix.Rotation(math.radians(24), 4, "X") @ Matrix.Rotation(math.radians(-8), 4, "Y")
        obj.data.transform(m)
        bone = "Pelvis"
    else:
        key = spec["kind"] if spec["kind"] == "shield" else spec["kind"] + "_" + hand
        attach = ATTACH.get(key, {"rotation": (0, 0, 0), "offset": (0, 0, 0)})
        rotation = list(attach["rotation"])
        if spec["kind"] == "shield" and hand == "L":
            rotation[2] = -rotation[2]
        m = A.place(obj, side_frame[hand], rotation, attach["offset"])
        bone = "Hand_" + hand
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = arm
    modifier = obj.modifiers.new("Germanic skin", "ARMATURE")
    modifier.object = arm
    # Rest transform of the grip frame in glTF/Godot axes (x, z, -y): a
    # library item attached to `bone` with this model-space transform lands
    # exactly where the baked copy is.
    c = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
    g = c @ m @ c.inverted()
    obj["attach"] = {"bone": bone, "basis_columns": [[g[r][col] for r in range(3)] for col in range(3)],
                     "origin": [g[r][3] for r in range(3)]}
    return obj


def make_faces(data, items, ids, tier):
    groups = data["groups"]
    faces = {}
    for item_id in ids:
        spec = items[item_id]
        if spec["kind"] != "shield":
            continue
        group = groups[spec["group"]]
        key = item_id if tier == 0 else item_id + "_t1"
        faces[key] = A.shield_face_material(spec, group, tier)
    return faces


def build_source(data, items, figure):
    family = next(t for t in data["tiers"] if t["id"] == figure["family"])
    arm, body, eyes, parts, frames, report = outfit.build_figure(figure, figure["family"], figure["group"], figure["seed"])
    loadout = figure["loadout"]
    ids = [v for v in loadout.values()]
    faces = make_faces(data, items, ids, 0)
    faces.update(make_faces(data, items, ids, 1))
    belt = parts.get("belt")
    anchor = None
    if belt:
        pts = [v.co for v in belt.data.vertices]
        anchor = max(pts, key=lambda p: p.x * .8 - p.y * .2) + Vector((.012, .03, -.01))
        # Hang clear of everything worn below the belt on that hip.
        reach = anchor.x
        for name in ("mail_skirt", "tunic_skirt", "trousers"):
            obj = parts.get(name)
            if obj:
                for v in obj.data.vertices:
                    if anchor.z - .45 < v.co.z < anchor.z and -.06 < v.co.y < .16 and v.co.x > 0:
                        reach = max(reach, v.co.x + .022)
        anchor.x = reach
    baked = []
    for slot, item_id in loadout.items():
        spec = dict(items[item_id])
        if slot == "L2":
            spec["hand"] = "L"
        obj = bake_item(spec, frames, arm, faces, anchor)
        baked.append(obj.name)
        # Simpler copies for the far LODs: gear is rebuilt with fewer sides,
        # never decimated (decimating a fan-shaped board tears it apart).
        for detail in (1, 2, 3):
            bake_item(spec, frames, arm, faces, anchor, detail)
        attach = obj["attach"].to_dict() if hasattr(obj["attach"], "to_dict") else dict(obj["attach"])
        report.setdefault("attachments", {})[item_id] = {"bone": attach["bone"],
            "basis_columns": [list(map(float, col)) for col in attach["basis_columns"]],
            "origin": [float(x) for x in attach["origin"]]}
    arm.name = "GermanicRig"
    arm.data.name = "GermanicRig"
    animate(arm, family["role"], figure["family"] == "skirmisher")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.data.update()
    report["baked_equipment"] = baked
    report["role"] = family["role"]
    report["source_triangles"] = triangles()
    SCRATCH.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    path = SCRATCH / (figure["id"] + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=False)
    return path, report


def triangles(objects=None):
    count = 0
    for obj in objects or bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            count += len(obj.data.loop_triangles)
    return count


def decimate(obj, ratio, morphs):
    if ratio >= .999 or len(obj.data.polygons) < 16:
        if not morphs and obj.data.shape_keys:
            obj.shape_key_clear()
        return
    F.frontier.simplify(obj, ratio, morphs)


def lod(path, level, spec):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    target = int(spec["max_triangles"] * .985)
    morphs = spec["face_morphs"]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # Keep the gear variant of this LOD (0, 1, 2, 3) under the plain name.
    for obj in list(meshes):
        if obj.name.startswith("Gear_"):
            base, _, tail = obj.name.partition("__d")
            detail = int(tail) if tail else 0
            if detail != level:
                bpy.data.objects.remove(obj, do_unlink=True)
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH" and "__d" in o.name]:
        obj.name = obj.name.split("__d")[0]
        obj.data.name = obj.name
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if level >= 2:
        for obj in list(meshes):
            if obj.name.startswith(FINE_DETAIL) or (level >= 3 and obj.name.startswith(FAR_DETAIL)):
                bpy.data.objects.remove(obj, do_unlink=True)
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    protected_small = 150 if level <= 1 else 0
    # Gear is never decimated: each LOD has its own rebuilt variant.
    meshes_all = meshes
    meshes = [o for o in meshes if not o.name.startswith("Gear_")]
    target -= triangles([o for o in meshes_all if o.name.startswith("Gear_")])
    # The face and hands carry the identity: they keep relatively more detail
    # (square root of the overall ratio) than cloth, gear and hair.
    important = ("GermanicBody", "HeroEyes", "Beard", "Scalp")
    for attempt in range(6):
        total = triangles(meshes)
        if total <= target:
            break
        fixed = sum(len(o.data.loop_triangles) for o in meshes if len(o.data.loop_triangles) < protected_small)
        movable = total - fixed
        ratio = max(.02, min(1.0, (target - fixed) / max(1, movable) * (.96 if attempt else 1.0)))
        keep = min(1.0, math.sqrt(ratio))
        heavy = sum(len(o.data.loop_triangles) for o in meshes
                    if len(o.data.loop_triangles) >= protected_small and o.name.startswith(important))
        light = movable - heavy
        rest = (target - fixed - heavy * keep) / max(1, light)
        if rest < .05:
            keep, rest = ratio, ratio
        for obj in meshes:
            if len(obj.data.loop_triangles) >= protected_small:
                decimate(obj, keep if obj.name.startswith(important) else max(.03, min(1.0, rest)), morphs)
    meshes = meshes_all
    if not morphs:
        for obj in meshes:
            if obj.data.shape_keys:
                obj.shape_key_clear()
    edge = spec["texture_edge"]
    for image in bpy.data.images:
        if image.size[0] > edge or image.size[1] > edge:
            factor = edge / max(image.size)
            image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
            image.pack()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type in ("MESH", "ARMATURE"))
    return triangles(meshes)


def export_figure(path, figure, levels):
    records = []
    out = EXPORT / "figures"
    out.mkdir(parents=True, exist_ok=True)
    for spec in levels:
        level = spec["lod"]
        count = lod(path, level, spec)
        glb = out / f"germanic_{figure['id']}_{level}.glb"
        bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                                  export_frame_step=1, export_animations=True, export_morph=True,
                                  export_morph_animation=False, export_def_bones=False,
                                  export_image_format="JPEG", export_image_quality=90)
        grounded = ground_death_clip.ground(glb)
        # Same shared rule for the throw; written only if contact improves.
        shoot = ground_death_clip.ground(glb, None, "shoot")
        meshes = {o.name: len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type == "MESH"}
        records.append({"lod": level, "path": str(glb.relative_to(ROOT)) if glb.is_relative_to(ROOT) else str(glb), "triangles": count,
                        "budget": spec["max_triangles"], "bytes": glb.stat().st_size, "sha256": digest(glb),
                        "texture_edge": spec["texture_edge"], "face_morphs": spec["face_morphs"],
                        "meshes": meshes, "death_grounding": {k: grounded.get(k) for k in
                                                              ("before", "after", "maximum_floor_correction_m", "keys")},
                        "shoot_grounding": {k: shoot.get(k) for k in ("before", "after", "unchanged")}})
        print("GERMANIC_LOD", figure["id"], level, count, glb.stat().st_size)
    return records


def export_equipment(data, items):
    """Grip-centred equipment library: two tiers each, SOCKET_* at the grip."""
    out = EXPORT / "equipment"
    out.mkdir(parents=True, exist_ok=True)
    records = []
    for item_id, spec in items.items():
        for tier in (0, 1):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            M.reset()
            faces = make_faces(data, items, [item_id], tier)
            builder = A.build_item(spec, faces, tier)
            obj = builder.obj(item_id)
            socket_name = {"R": "SOCKET_RIGHT_HAND", "L": "SOCKET_LEFT_HAND", "belt": "SOCKET_BELT_LEFT"}[spec["hand"]]
            socket = bpy.data.objects.new(socket_name, None)
            bpy.context.collection.objects.link(socket)
            socket.parent = obj
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            socket.select_set(True)
            path = out / f"{item_id}_{tier}.glb"
            bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                      export_animations=False, export_image_format="JPEG", export_image_quality=90)
            obj.data.calc_loop_triangles()
            records.append({"id": item_id, "tier": tier, "path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path), "socket": socket_name,
                            "triangles": len(obj.data.loop_triangles), "bytes": path.stat().st_size, "sha256": digest(path)})
            print("GERMANIC_ITEM", item_id, tier, len(obj.data.loop_triangles))
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", action="store_true")
    parser.add_argument("--equipment", action="store_true")
    parser.add_argument("--figures", nargs="*", default=None)
    parser.add_argument("--report", default=str(HERE / "build_report.json"))
    parser.add_argument("--export-dir", default=None, help="write GLBs elsewhere (reproducibility check)")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    global EXPORT
    if args.export_dir:
        EXPORT = Path(args.export_dir)
    data, items = load_registry()
    report_path = Path(args.report)
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    report.setdefault("figures", {})
    if args.export:
        wanted = args.figures or [f["id"] for f in data["figures"]]
        for figure in data["figures"]:
            if figure["id"] not in wanted:
                continue
            path, info = build_source(data, items, figure)
            info["lods"] = export_figure(path, figure, data["lod"]["levels"])
            report["figures"][figure["id"]] = info
    if args.equipment:
        report["equipment"] = export_equipment(data, items)
    report["generator"] = str(Path(__file__).relative_to(ROOT))
    report["blender"] = bpy.app.version_string
    report["registry_sha256"] = digest(REGISTRY)
    report["sources"] = {str(p.relative_to(ROOT)): digest(p) for p in sorted(HERE.glob("*.py"))}
    report["source_hero_sha256"] = digest(F.HERO_BLEND)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("GERMANIC_BUILD_COMPLETE")


if __name__ == "__main__":
    main()
