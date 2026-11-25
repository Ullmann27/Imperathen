"""Blender-free FK regression for the actual Meshy gait generator.

Execute the production skeleton/pose functions, not a copy of their IK solver.
Only Blender's armature construction is replaced with in-memory bone records.
This checks the authored rig; exported skin, runtime contacts and appearance
remain the responsibility of the existing Godot and visual checks.
"""
from __future__ import annotations

import ast
import math
from pathlib import Path
from types import SimpleNamespace
from typing import NamedTuple
import unittest


GENERATOR = Path(__file__).resolve().parents[1] / "tools/characters/build_meshy_people.py"
GAITS = {"march": (1.30, .56, .05), "run": (1.75, .40, .09)}
POSITION_TOLERANCE = .000002


class Vector(NamedTuple):
    x: float
    y: float
    z: float

    def __add__(self, other):
        return Vector(*(a + b for a, b in zip(self, other)))

    def __sub__(self, other):
        return Vector(*(a - b for a, b in zip(self, other)))

    def __mul__(self, factor):
        return Vector(*(value * factor for value in self))

    @property
    def length(self):
        return math.hypot(*self)


class Bone:
    def __init__(self, name):
        self.name = name
        self.head = self.tail = Vector(0, 0, 0)
        self.parent = None

    @property
    def head_local(self):
        return self.head

    @property
    def tail_local(self):
        return self.tail

    @property
    def length(self):
        return (self.tail - self.head).length


class Bones(dict):
    def new(self, name):
        bone = Bone(name)
        self[name] = bone
        return bone


def load_generator():
    def armature(_name):
        bones = Bones()
        return SimpleNamespace(edit_bones=bones, bones=bones)

    def unused_original_pose(*_args):
        raise AssertionError("A gait unexpectedly delegated to the unrelated clip provider")

    noop = lambda *_args, **_kwargs: None
    bpy = SimpleNamespace(
        data=SimpleNamespace(
            armatures=SimpleNamespace(new=armature),
            objects=SimpleNamespace(
                new=lambda _name, data: SimpleNamespace(data=data, select_set=noop))),
        context=SimpleNamespace(
            collection=SimpleNamespace(objects=SimpleNamespace(link=noop)),
            view_layer=SimpleNamespace(objects=SimpleNamespace(active=None))),
        ops=SimpleNamespace(object=SimpleNamespace(select_all=noop, mode_set=noop)))
    # Importing the authoring module would require Blender and NumPy. Compile
    # these exact production definitions without executing its import section.
    tree = ast.parse(GENERATOR.read_text(encoding="utf-8"), filename=str(GENERATOR))
    names = {"PROFILES", "CLIPS", "clamp", "skeleton", "animate"}
    selected = []
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            selected.append(node)
        elif isinstance(node, ast.Assign) and any(
                isinstance(target, ast.Name) and target.id in names for target in node.targets):
            selected.append(node)
    scope = {"math": math, "bpy": bpy, "Vector": lambda values: Vector(*values),
             "soldier": SimpleNamespace(animate=noop), "original_pose": unused_original_pose}
    exec(compile(ast.Module(body=selected, type_ignores=[]), str(GENERATOR), "exec"), scope)
    if not names <= scope.keys():
        raise AssertionError("Required production gait definitions were not found")
    return scope


def rotate_x(vector, degrees):
    angle = math.radians(degrees)
    c, s = math.cos(angle), math.sin(angle)
    return Vector(vector.x, c * vector.y - s * vector.z, s * vector.y + c * vector.z)


def leg_points(arm, angles, lift, side):
    thigh, shin, foot = (arm.data.bones[name + side] for name in ("Thigh_", "Shin_", "Foot_"))
    a = angles["Thigh_" + side][0]
    b = angles["Shin_" + side][0]
    hip = thigh.head_local + Vector(0, 0, lift)
    knee = hip + rotate_x(shin.head_local - thigh.head_local, a)
    ankle = knee + rotate_x(foot.head_local - shin.head_local, a + b)
    return hip, knee, ankle


class MeshyGaitReachTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        generator = load_generator()
        cls.arms = {}
        cls.poses = {}
        cls.samples = {}
        for identity, profile in generator["PROFILES"].items():
            arm = generator["skeleton"](profile)
            generator["animate"](arm)
            pose = generator["soldier"].pose
            cls.arms[identity] = arm
            cls.poses[identity] = pose
            for clip, (_stride, stance, _lift) in GAITS.items():
                phases = {index / 1000 for index in range(1001)}
                # Include both support/swing boundaries and actual 25-fps bake keys.
                for offset in (0, .5):
                    boundary = (stance - offset) % 1
                    phases.update((boundary, (boundary - .000001) % 1,
                                   (boundary + .000001) % 1))
                count = round(generator["CLIPS"][clip] * 25)
                phases.update(index / count for index in range(count + 1))
                cls.samples[identity, clip] = [
                    (phase, *pose(clip, phase, "civilian")) for phase in sorted(phases)]

    def test_existing_profiles_include_real_lateral_leg_offsets(self):
        self.assertEqual(set(self.arms), {"unit_roman_signifer", "unit_germanic_axe_fighter"})
        for identity, arm in self.arms.items():
            for side in ("L", "R"):
                with self.subTest(profile=identity, side=side):
                    thigh, shin, foot = (arm.data.bones[name + side]
                                         for name in ("Thigh_", "Shin_", "Foot_"))
                    self.assertLess((thigh.tail_local - shin.head_local).length, 1e-12)
                    self.assertLess((shin.tail_local - foot.head_local).length, 1e-12)
                    for bone in (thigh, shin):
                        link = bone.tail_local - bone.head_local
                        self.assertGreater(abs(link.x), .0001)
                        self.assertGreater(bone.length, math.hypot(link.y, link.z) + .000001)

    def test_finite_poses_preserve_actual_3d_segments(self):
        for (identity, clip), samples in self.samples.items():
            arm = self.arms[identity]
            with self.subTest(profile=identity, clip=clip):
                for phase, angles, lift in samples:
                    self.assertTrue(math.isfinite(lift), phase)
                    self.assertTrue(all(math.isfinite(value) for rotation in angles.values()
                                        for value in rotation), phase)
                    for side in ("L", "R"):
                        for name in ("Thigh_", "Shin_", "Foot_"):
                            self.assertEqual(angles[name + side][1:], (0, 0))
                        hip, knee, ankle = leg_points(arm, angles, lift, side)
                        self.assertAlmostEqual((knee - hip).length,
                                               arm.data.bones["Thigh_" + side].length, places=12)
                        self.assertAlmostEqual((ankle - knee).length,
                                               arm.data.bones["Shin_" + side].length, places=12)

    def test_both_stance_ankles_reach_ground_and_stride_targets(self):
        for (identity, clip), samples in self.samples.items():
            stride, stance, _lift = GAITS[clip]
            arm = self.arms[identity]
            with self.subTest(profile=identity, clip=clip):
                for side, offset in (("R", 0), ("L", .5)):
                    rest = arm.data.bones["Foot_" + side].head_local
                    errors, pitch_errors = [], []
                    for phase, angles, lift in samples:
                        u = (phase + offset) % 1
                        if u > stance:
                            continue
                        ankle = leg_points(arm, angles, lift, side)[2]
                        # The prescribed planted trajectory, independent of IK:
                        # unchanged sole height/lateral placement and stride-linear Y.
                        target = rest + Vector(0, stride * (u - stance / 2), 0)
                        errors.append((ankle - target).length)
                        pitch_errors.append(abs(sum(angles[name + side][0]
                                                    for name in ("Thigh_", "Shin_", "Foot_"))))
                    self.assertGreater(len(errors), 300, side)
                    self.assertLess(max(errors), POSITION_TOLERANCE, (side, max(errors)))
                    self.assertLess(max(pitch_errors), .000001, side)

    def test_both_swing_ankles_lift_without_falling_below_the_rest_plane(self):
        for (identity, clip), samples in self.samples.items():
            _stride, stance, required_lift = GAITS[clip]
            arm = self.arms[identity]
            with self.subTest(profile=identity, clip=clip):
                for side, offset in (("R", 0), ("L", .5)):
                    rest = arm.data.bones["Foot_" + side].head_local
                    heights = [leg_points(arm, angles, lift, side)[2].z - rest.z
                               for phase, angles, lift in samples if (phase + offset) % 1 > stance]
                    self.assertGreater(max(heights), required_lift, side)
                    self.assertGreaterEqual(min(heights), -POSITION_TOLERANCE, side)

    def test_loop_endpoints_match_for_both_legs_and_the_shared_pelvis(self):
        for identity, pose in self.poses.items():
            for clip in GAITS:
                with self.subTest(profile=identity, clip=clip):
                    first, first_lift = pose(clip, 0, "civilian")
                    last, last_lift = pose(clip, 1, "civilian")
                    self.assertAlmostEqual(first_lift, last_lift, places=12)
                    self.assertEqual(first.keys(), last.keys())
                    for bone in first:
                        for a, b in zip(first[bone], last[bone]):
                            self.assertAlmostEqual(a, b, places=10, msg=bone)
                    for side in ("L", "R"):
                        before = leg_points(self.arms[identity], first, first_lift, side)
                        after = leg_points(self.arms[identity], last, last_lift, side)
                        self.assertTrue(all((a - b).length < POSITION_TOLERANCE
                                            for a, b in zip(before, after)), side)


if __name__ == "__main__":
    unittest.main()
