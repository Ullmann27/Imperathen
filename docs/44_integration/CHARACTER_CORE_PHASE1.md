# IMPERATHEN — Phase 1: CharacterCore / Locomotion / Terrain IK

Native Godot 4.6+ API target, project engine 4.7.2. Native TwoBoneIK3D does not exist in 4.4; no deprecated SkeletonIK3D substitute. This is a new isolated candidate, not an automatic replacement of existing GameWorld or an APK. Existing original imported frontier legionary rig is the demonstrator; Meshy youth and other rig adapters still require measured acceptance. No new motion-capture file is claimed.

## Exact scenes

Run `res://scenes/character_core/phase1_review.tscn` with F6 or use `imperathen_character.tscn` as a PackedScene. The imported GLB provides the real Skeleton3D and AnimationPlayer. The CharacterCore discovers them after instancing; it does not duplicate or edit the original GLB.

```text
ImperathenCharacter (CharacterBody3D / CharacterCore)
├── CollisionShape3D (CapsuleShape3D)
├── RigRoot (Node3D)
│   └── OriginalRig (frontier_legionary_0.glb)
│       ├── imported AnimationPlayer
│       └── imported Skeleton3D (existing hierarchy)
│           ├── BodyPoseModifier (SkeletonModifier3D, generated)
│           ├── LeftLegIK (TwoBoneIK3D, generated)
│           ├── RightLegIK (TwoBoneIK3D, generated)
│           ├── LeftFootNormal (SkeletonModifier3D, generated)
│           ├── RightFootNormal (SkeletonModifier3D, generated)
│           └── HeadLook (LookAtModifier3D, generated)
├── AnimationTree
├── FootPlacement (Node3D)
│   ├── LeftRay / RightRay (RayCast3D)
│   ├── LeftTarget / RightTarget (Marker3D)
│   ├── LeftPole / RightPole (Marker3D)
│   └── HeadTarget (Marker3D)
└── NavigationAgent3D (inactive until a navigation owner is implemented)
```

The exact imported hierarchy is inside the GLB and not a guessed hand-written Skeleton3D. Runtime discovery rejects an ambiguous skeleton or animation player. Configurable bone names: Pelvis, Spine, Head, Thigh_L / Shin_L / Foot_L and corresponding _R. The rest-pose sole lift is obtained from the existing AuthoredGround script.

## Inspector / authored values

| Parameter | Value |
|---|---|
| Character collision layer / mask | 2 / 1 |
| Capsule radius / height / Y | .29 m / 1.78 m / .89 m |
| Floor max angle / snap / margin | 48° / .32 m / .001 m |
| Walk / run / sprint | 1.45 / 3.8 / 5.4 m/s |
| Acceleration / braking | 5.5 / 8.0 m/s² |
| Exponential response | 8 s^-1 |
| Yaw speed | 5 rad/s |
| Gravity / swept step | 19.6 m/s² / .25 m |
| Ray up / down (plus measured ankle height) | .32 / .48 m |
| Pelvis max drop / plant drift | .18 / .24 m |
| Swing height threshold / procedural turn step | .055 / .085 m |
| Head limit / damping | 55° yaw, 30° pitch, .18 s, target follow 7 s^-1 |
| NavigationAgent3D | planar avoidance, radius .29, height 1.78, max speed 5.4, disabled until an actual navigation map/owner (Phase 4) |

Graph (runtime generated per instance): Root BlendTree, Base state machine with Locomotion (BlendSpace2D) and Airborne (idle baseline), upper-body AnimationNodeBlend2 using only actual Spine-descendant tracks. Blend points X = -1, 0, +1; Y = 0, 1.45, 3.8, 5.4. At Y=0, turn steps are procedural alternating IK on original idle. At Y=5.4, original run is retimed by 5.4/3.8. No dedicated authored sprint/turn clips or mocap database are claimed. Actual movement is collision-resolved; blocked speed drives idle rather than running in place. A later motion-matching adapter can subscribe to animation_intent_sampled and read the skeleton/AnimationTree; no external plugin installed or required.

## Public interface

```gdscript
signal rig_bound(skeleton: Skeleton3D)
signal motion_state_changed(previous: int, current: int)
signal grounded_changed(grounded: bool)
signal movement_sampled(world_velocity: Vector3, grounded: bool)
signal animation_intent_sampled(world_velocity: Vector3, speed: float, yaw_rate: float, grounded: bool)
signal command_rejected(reason: String)

func is_character_ready() -> bool
func request_motion(world_direction: Vector3, amount: float, gait: int = Gait.WALK) -> bool
func stop_motion() -> void
func request_facing(world_direction: Vector3) -> bool
func clear_facing() -> void
func set_movement_enabled(value: bool) -> void
func set_speed_multiplier(value: float) -> bool
func set_ik_enabled(value: bool) -> void
func set_look_target(world_point: Vector3) -> void
func clear_look_target() -> void
func set_upper_body_clip(clip: StringName, weight: float) -> bool
func clear_upper_body() -> void
func get_character_skeleton() -> Skeleton3D
func get_animation_tree() -> AnimationTree
func get_motion_state() -> int
func get_planar_speed() -> float
func get_yaw_rate() -> float
func get_foot_contact(side: int) -> Dictionary
func get_pelvis_offset() -> float
func get_upper_filter_paths() -> Array[NodePath]
func get_bone_world_transform(bone_name: StringName) -> Transform3D
```

Equipment, combat, and formation owners later use these contracts after `rig_bound` or `is_character_ready()`. For a final modified bone sample use Skeleton3D.skeleton_updated; ordinary pose reads outside the modifier callback are not a guarantee of the final rendered transform.

## Verification

Run the isolated CI workflow or:
```sh
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 --script res://tests/character_core_phase1_test.gd
```
The test checks the actual original imported rig, graph, upper layer filters, finite native foot IK, speeds, stopping, turning, swept stair and wall contact, slope and LOD toggle. A source commit is not an engine PASS. No final campaign integration, image quality, private youth, physical Fold7 or APK approval is implied.

## First real engine failure and correction candidate

Run 46116191468 at d467b29e13253f58f98acc6d2b74acfe2bf4216a compiled and executed 64 checks (62 passed). Actual 18 cm step and distinct foot heights on a lateral slope failed. The revised step path verifies the raised capsule corridor and landing beyond its curved edge, moves only the requested per-tick distance, and revalidates the top during entry. Foot placement computes the shared pelvis offset before clamping either ankle to reachable length. Added raw ground/desired target diagnostics, unchanged 40 mm and 15 mm thresholds, and traversal/speed assertions. Correction requires a new passing real engine run; not a visual or device acceptance.

## Adapter lifecycle hardening (independent Phase 1 candidate)

Before `_ready` or on a malformed adapter, rig/graph queries return null, missing bone queries retain the existing nonfinite sentinel, contacts and filter lists are empty, and pelvis offset is neutral. Gaze/IK/upper-body commands cannot dereference absent dependencies. Binding rejects absent core children or any required foot ray, pole, target or head target before creating native IK; an invalid adapter emits `command_rejected`, warns and stops physics. A failed foot adapter leaves the animation graph inactive. This correction retains every original motion/contact threshold and the existing rig. Additional tests exercise actual engine construction of an unbound instance and two incomplete scenes. Existing Phase 1 79/79 evidence applies to its original revision, not this successor until the new engine run passes. Full campaign, formations, visuals and physical device acceptance remain separate.

## Phase 1 LOD contact-query budget (successor)

Exact preceding null-contract revision `8e8bda546dbd91f9b1050edaaad6a48f122793d7` passed actual Godot run [46121772634](https://github.com/Ullmann27/Imperathen/actions/runs/46121772634), 101/101, artifact 15254241890. Native step 0.184476 m, peak planar speed 1.465498 m/s; separate slope samples 0.580133 and 0.526569 m. This successor fixes an independently identified unnecessary physics workload: the old disabled-IK path still enabled two automatic RayCast3D nodes and explicitly forced two casts each physics tick. Disabling IK now disables both automatic rays, immediately clears planted contacts, and skips explicit casts unless IK is enabled and the body grounded. Existing animation, collision locomotion, and native target processing remain; no performance/FPS or 100-actor device claim. The new tests assert actual ray state, invalidation, disabled locomotion, and restoration; all original tests and thresholds are retained. The successor requires its own engine run. No phase 2, campaign replacement or device acceptance.

## Physical adapter admission and airborne ray budget

Predecessor `2ab80c89d8f57a1b8ed5760e6ff44db26955811a` passed actual Godot 4.7.2 run [46127442377](https://github.com/Ullmann27/Imperathen/actions/runs/46127442377), job 140925065453, 110/110 checks and review scene load. This successor rejects a missing, disabled or non-capsule collision shape before graph binding, rejects duplicate bone names before constructing leg solvers, and keeps both authored rays disabled until a grounded pose actually needs them. Re-enabling IK in air must not start automatic physics queries. Tests add real malformed adapters and an actual fall/landing on the existing floor; previous assertions and thresholds are unchanged. Public declarations are unchanged. Successor engine evidence is pending; no device/visual acceptance or Phase 2 approval.

## Runtime dependency-loss contract

Predecessor `c53384c3ff0ffed7425b830c9833c961f5d85e7b` passed [actual Godot 4.7.2 run 46130455319](https://github.com/Ullmann27/Imperathen/actions/runs/46130455319), job 140934207194, 141/141; artifact 15257686020 and review scene passed. The successor checks the live capsule and actual foot adapter dependencies instead of only the enclosing wrappers. Freeing a live ray, detaching a still-valid target or disabling the live capsule invalidates public receipts immediately and stops physics, the animation graph and surviving ray/solver work at the next tick. Native bindings are not automatically reconstructed; malformed adapters require replacement. Regression cases cover all three paths; prior assertions and motion gates retained. Internal checks only, no changed public declarations; no production rig, Phase 2, campaign replacement or device acceptance. Successor engine evidence pending.

## Synchronous signal lifecycle safety

Predecessor `73548f99d3324a9b09f0d66a3c5d415c10f2b356` passed [actual Godot 4.7.2 run 46134646882](https://github.com/Ullmann27/Imperathen/actions/runs/46134646882), job 140947122369, 166/166 and review scene load. The successor revalidates the live contract immediately after state/ground signals, native animation and skeleton evaluation, and the movement sample. A synchronous listener can detach a required node after the tick's initial readiness check; the old code could still evaluate the detached graph or publish a stale animation receipt. New real-engine fixtures detach a target during landing, detach the graph on walking state, and invalidate a dependency during movement publication. No public declaration, asset, threshold or existing assertion changed. Additional allocation-free readiness checks are not a measured frame-time benefit; mass-actor and device performance remain unverified. Successor engine evidence pending. No campaign, Phase 2, visual or device acceptance.
