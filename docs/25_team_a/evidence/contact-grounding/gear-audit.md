# Gear clearance audit — 2616391

## Scope and result

Baseline: `261639105dcaa72f8dd92e73f4db1d9ab7d90a23` (PR #56).
Artifact: run `45564458686`, artifact `14999657350`.
Verified ZIP SHA-256: `fa3440215ffedfe8412534fb0556bfb14e71dec07e66f3e3a327363af46a000b`.

A real topology-cache defect is fixed in two files. It is separate from the
current service-gear invalid samples. The patch must not be reported as resolving
the eight equipment sampling entries.

## Cache defect and bounded fix

When two independently closed components touch, the existing cache includes their
coincident vertex pairs among the required welds. If the components then separate,
the old cache marks the geometry open even though reconstructing the exact same
current triangles proves it closed.

Baseline Godot reproducer:
`touching_closed=true; separated_cached_closed=false; separated_fresh_closed=true`.

The patch only erases and rebuilds a cached topology if its original closure was
verified and at least one previously welded pair has separated beyond the existing
EPSILON. Fresh construction runs the unchanged complete-link weld/edge-balance
checks. A real newly opened seam still fails. Vertex count/index change rejection,
EPSILON, penetration limits, grip volumes and fixture coverage are unchanged.

Patch: `gear-topology-cache.patch`.
SHA-256: `c47d023515503944a55edd8e889ebe9cb1facf45a046d39a721ed4d1206b32bb`.
Changed files:
- `prototype/tests/motion_mesh_clearance.gd`: 6 added lines.
- `prototype/tests/motion_mesh_clearance_test.gd`: 23 added lines.

## Meaningful regression

The existing 16 tests remain, including actual Scutum closure, sub-EPS rigid
transforms, a genuinely opened seam, the midpoint bridge, opened cached welds,
missing face rejection, and solid containment. Three new checks cover:
1. Two independently closed cubes are verified closed while touching.
2. After separation, cached and fresh closure agree and remain true.
3. A smaller object fully contained in the separated second component is still
   detected as an actual containment intersection.

Command:
```sh
godot --headless --path /tmp/imperathen-gear-audit-20261125/repo/prototype --script res://tests/motion_mesh_clearance_test.gd
```

Observed on Godot `4.7.2.stable.official.ed1daf0bf`:
`MOTION_CLEARANCE_TEST 19 checks; 0 failed` (exit 0).
`git diff --check` also passed.
No full suite or full motion fixture was run by this agent.

## Actual service fixture diagnosis

The diagnostic instantiates the real player Italia age 18 at LOD0, equips the
actual service props, evaluates `cut_inward`, samples actual posed skin vertices,
and compares cached geometry with an independently rebuilt current geometry.
The grip exclusions remain the production 0.08 m spheres.

| Phase | Actual body closed, cached/fresh | Scutum closed, cached/fresh | Scutum comparison | Gladius comparison |
| --- | --- | --- | --- | --- |
| 0 | false / false | true / true | Actual surface intersection; finite | Actual surface intersection; finite |
| 4/49 | false / false | true / true | Invalid in both cached/fresh | Actual surface intersection; finite |
| 8/49 | false / false | true / true | Invalid in both cached/fresh | Invalid in both cached/fresh |

Both props are closed in all five sampled phases (0, 4/49, 8/49, 0.5, 1).
At 4/49 all 13 actual hero skin component meshes also individually fail closure.
No skin-sampling errors occurred. Error text:
`Open or inconsistently oriented overlapping mesh: solid containment is not proven`.

Thus the reproduced service failures are caused by an already open body combined
with overlapping bounds and no unexcluded surface intersection to settle the
test. Cache rebuilding cannot certify that geometry as solid. The strict
invalid-sample rejection remains necessary under the existing measurement
contract. The four invalid Meshy prop subjects were read from the artifact but
were not separately reproduced in this local diagnostic.

Evidence: `pose_probe.gd`, `pose-probe-before.log`.

## Authored geometry is already open before skinning

A separate source-byte audit decodes original POSITION/index accessors from
`prototype/assets/characters/hero_quality_0.glb`, before any skinning, animation or
morph. It uses the same 0.00001 m complete-link closure criterion. GLB SHA-256:
`f0600db20ea4957fc50411439fa8b1591ec4fe4389326a27bde89aab6bb63f51`.

| Original component | Boundary edges before skinning |
| --- | ---: |
| HeroBody | 134 |
| HeroTunic | 148 |
| HeroTunicSkirt | 128 |
| HeroBelt | 96 |
| HeroCollarSeam | 12 |
| HeroEyes | 80 |
| HeroHair | 164 |
| Each HeroSandal | 80 |
| Each of four HeroSandalStrap components | 12 |

All 13 original components are already open. For each, the unbalanced-edge count
equals the boundary-edge count; this audit found no edges with more than two
incident triangles. These are therefore actual boundaries, not merely inconsistent
face orientation in this source audit.

The authoring script corroborates the exported bytes:
- `tools/characters/build_hero.py:323`, `body()`, omits body faces covered by
  clothing (`if not covered:selected.append(i)`).
- `tools/characters/build_hero.py:422`, `loft()`, constructs sides between rings
  without end caps.
- `tools/characters/build_hero.py:438`, `tube()`, similarly creates an open tube.
- `tools/characters/build_hero.py:450`, `tailored_top()`, cuts garment openings.

This establishes that the observed openness is not introduced solely by skinning.
It does not prove the absence of additional pose-specific deformation issues.

Evidence: `source_topology_probe.py`, `source-topology.json`.

## Gate accounting and remaining issue

The baseline equipment sampling group consists of two family-level sampling
errors plus six invalid clearance subjects (two service props; four Meshy props).
The full strict gate still had 536 entries in the downloaded baseline. This
focused cache fix has no verified reduction in that total.

The family values 0.389811515808105 m (service) and 0.428676933050156 m (Meshy)
are conservative AABB separation upper bounds produced after detected actual
surface intersections. They are not measured anatomical penetration depths.

No actual assets, animation poses, attachments, thresholds, exemptions or remote
branches were changed by this audit.
