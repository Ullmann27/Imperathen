# Meshy gait and rigid-foot audit — final isolated candidate

Base: `261639105dcaa72f8dd92e73f4db1d9ab7d90a23`. Baseline: run 45564458686, artifact 14999657350; verified artifact SHA256 `fa3440215ffedfe8412534fb0556bfb14e71dec07e66f3e3a327363af46a000b`. Final measurement source fingerprint: `e6fe4a34bd3f0cfb75de6f86ed6dd507fabaf44d7e6ddd8b9999b456a0699800`.

## Decision and scope

The 12 production changes are a narrow Meshy generator correction, eight regenerated GLBs, the corresponding build report, one independent Python regression, and an extension to the existing Godot skin regression. No Frontier asset, runtime character/IK source, measurement sampler, threshold, contract, or source lock is changed. The final checkout remains uncommitted for parent integration.

The eight subject diagnostics contain all 88 actual production clip observations (11 per GLB). All 16 march/run cases now have actual support-surface observations on both feet. Missing support clip records fall from 12 to 0; unchanged rig-gate validation errors fall from 28 to 0. Raw exported-clip rig validation remains 0 to 0. These diagnostic reports deliberately retain `complete=false`. This is not an overall motion-gate acceptance.

## What the original 92 sampling messages mean

The baseline has 92 failed clip records across 24 GLBs and six identities, not 92 independent skeletal defects. All failures are missing real sole-contact samples. There are 172 per-foot messages: 80 Frontier military records with both feet missing (four identities × four LODs × five actions), plus 12 Meshy records with the right foot missing (axe march × four LODs; signifer march/run × four LODs). Imported bindings and finite-pose sampling are valid. The existing measurement uses skinned vertices inside the existing 20 mm ground-contact band; it is exposing authored airborne support poses.

## Root causes and production fix

1. The Meshy authoring solver rotated in the sagittal YZ plane but used full 3D link lengths. It also clamped an unreachable ankle target without lowering the shared pelvis first. This raised the desired stance foot, which the runtime then faithfully anchored above the floor. The generator now uses the actual YZ projections, computes both targets first, lowers the single pelvis enough for both legs with 3 mm reach reserve, and then solves both legs. The independent forward-kinematic review sampled both fixed profiles and gaits over 10,001 phases: target error improved from as much as 54.44 mm to below 2.5e-12 mm. Extra pelvis lowering reaches approximately 64–65.8 mm; the lowest total authored pelvis offset is about -110 mm. This is a real posture change.

2. Existing LOD smoothing blurred vertices that were rigidly bound to a foot after decimation. The concrete axe LOD3 sole vertex 992 had Foot_R=0.808606088 and Shin_R=0.191378653 in Godot. Its corresponding Blender vertex was exactly Foot_R=1 after decimation and before the two smoothing passes. Over the stance, its ankle moved only 0.000213 mm, but the visible sole slid 17.269032 mm. The final generator saves exactly those post-decimation rows with one nonzero Foot_L/Foot_R assignment, runs both original smoothing passes unchanged, and restores only the saved rows. No geometric body zone is newly rebound.

The isolated sole correction reduced the real axe LOD3 march slip to 0.000246 mm. The existing Godot regression was extended to exercise actual imported skin in production locomotion, so a valid bone path alone cannot conceal this failure.

## Eight-model before/after result

Counts are clip records; contact-sample counts in the JSON are vertex observations over time, not independent contacts or defects. Final values below are the maximum across march and run for each GLB.

| Model / LOD | Missing-contact clips before → after | Final maximum slip (mm) | Final maximum penetration (mm) | Gait skin-edge violations |
|---|---:|---:|---:|---:|
| Axe LOD0 | 1 → 0 | 0.000358867 | 0.034710 | 0 |
| Axe LOD1 | 1 → 0 | 0.000245756 | 0.142362 | 0 |
| Axe LOD2 | 1 → 0 | 0.000242573 | 0.142362 | 0 |
| Axe LOD3 | 1 → 0 | 0.000245756 | 0.000000 | 0 |
| Signifer LOD0 | 2 → 0 | 0.000477201 | 0.045563 | 0 |
| Signifer LOD1 | 2 → 0 | 0.000477768 | 0.000000 | 0 |
| Signifer LOD2 | 2 → 0 | 0.000477070 | 0.000000 | 0 |
| Signifer LOD3 | 2 → 0 | 0.000358867 | 0.000000 | 0 |

The unchanged acceptance bounds are 15 mm support slip and 10 mm sole penetration. Every gait case remains finite and within these bounds. No missing measurement is replaced by zero.

| Rig / action | Runtime seam distance before → after (mm) | Seam rotation before → after (degrees) | Peak angular speed before → after (degrees/s) |
|---|---:|---:|---:|
| Axe / march | 27.254 → 5.281 | 5.1992 → 0.7078 | 815.5 → 515.8 |
| Axe / run | 98.078 → 19.566 | 14.4382 → 2.8396 | 929.0 → 713.4 |
| Signifer / march | 26.354 → 5.414 | 4.7734 → 0.7434 | 836.1 → 526.5 |
| Signifer / run | 98.742 → 19.485 | 14.8716 → 2.8985 | 905.5 → 726.3 |

## Geometry, animation, and provenance checks

`meshy-eight-accessor-comparison.json` compares the gait candidate with the original eight GLBs: mesh accessors are exactly equal, and only march/run animation channels change. `meshy-final-accessor-comparison.json` then compares the final rigid-foot version with that candidate: positions, normals, UVs, tangents where present, triangle indices, and all 11 animation channels are exactly equal. All nine non-gait clips remain accessor-identical to the baseline. Only JOINTS_0/WEIGHTS_0 change, and every changed vertex binding becomes exactly one Foot_L or Foot_R weight of 1.0. The two reports together establish unchanged geometry against the original assets.

Changed exported binding rows by LOD0–3: axe 126 / 134 / 96 / 56; signifer 179 / 147 / 95 / 48. UV/normal seam duplicates are included in those counts. The build report separately records the original Blender vertex counts preserved by the mask. All final GLB hashes match both the build report and the file manifest.

The two original Meshy source inputs are unchanged: signifer SHA256 `15b2afb0c22d187f45c37a84d272cb215ff39388ee4fde23c8cec668cb042370`, axe SHA256 `9c6cb7e4f57ce3b0c4178bb269cad830183bb0796ccd419d5c74ada31ba9bffc`. Rebuild command: `blender -b -t 2 -P tools/characters/build_meshy_people.py -- --types all` (Blender 4.3.2).

## Regression evidence

| Evidence | Result |
|---|---|
| `ground-regression-before.log` | New existing-test extension: 300 checks, exactly one failure, real axe LOD3 march slip 17.269032 mm. |
| `motion_skin_measurement_test-rigid-final.log` | 300 checks, zero failures; both rigs, LOD0/3, march/run, real skin and world contacts. |
| `meshy_character_test-rigid-final.log` | Existing Meshy acceptance: 304 checks, zero failures. |
| `gait-reach-final.log` | Independent Python FK: five methods pass; original generator fails all four profile × gait stance-target subcases. |
| `meshy-final/*.json` and `.log` | Eight 60 Hz subject diagnostics, all 11 raw and production clips per asset, no fatal/script errors; source fingerprint verified unchanged across all runs. |
| `geometry-final/capture-manifest.json` | Four actual Godot 4.7.2 viewport PNGs; identical runtime dictionaries before/after, canonical LOD3 asset paths, matching source hashes. |

The Python regression executes the actual production skeleton/animate/clamp functions extracted with AST, using small construction stubs and independently reconstructed forward kinematics. It does not copy the IK formula and has no Blender/NumPy/mathutils dependency. The Godot test retains the existing strict thresholds.

## Visual evidence

Final captures are under `geometry-final/`: axe and signifer, each before and after. The canonical GLBs were temporarily swapped and imported between separate engine processes, then the final bytes restored and SHA256-verified. The compared runtime dictionaries match exactly, including identity, home, appearance, phase=0, march at 1.45 m/s, LOD3, model path, scale, and equipment. Axe uses germania/spearman and its hand axe plus round shield; signifer uses italia/legionary and its signum. Source identity is not inferred from a temporary filename.

Actual first-pose sole heights improve from axe L/R 12.22/20.84 mm to 1.32/1.44 mm, and signifer 15.82/37.73 mm to 5.20/17.20 mm. The signifer sole is therefore still not exactly flush with zero; the contact sampler observes it inside its unchanged 20 mm contact band. The images demonstrate these particular poses and the corresponding posture change. They are not a complete visual approval of every animation. The renderer is actual Godot Compatibility with llvmpipe via the existing authenticated `capture_hero.start_display()` helper, LP_NUM_THREADS=2. No Android performance claim is made.

## Remaining measured problems and one newly exposed train threshold crossing

Equal animation channels do not guarantee equal deformed surfaces after a weight correction. All 72 non-gait production observations were therefore compared. Axe LOD3 attack worsens from 19.288395 to 21.312431 mm slip (+2.024036 mm); it already exceeded the same 15 mm bound before. The complete comparison JSON retains all other deltas, including small increases in existing attack/death measurements. The train landing diagnosis below is not generalized to attack or death without a corresponding causal probe. The final unchanged sampler still reports 19 slip violations (eight death, seven attack, four train), eight death penetration violations, and one axe LOD0 attack skin case with 18 edge observations. Maximum remaining death penetration is 192.334235 mm; maximum measured slip is 1045.891285 mm. These are not accepted by this change.

There is one new per-clip surface threshold crossing: signifer LOD3 train, 12.747829 → 23.202851 mm slip. LOD0–2 train already measured approximately 23 mm. `train-contact-probe.json` records the actual cause of the LOD3 number: mesh vertex 976 (key 1952), now Foot_L=1.0, enters the sampler's 20 mm band at frame 37 (y=19.608 mm) while `world_foot_supported("L")` is false. It remains unsupported in frame 38, lands at frame 39, and the unchanged sampler's maximum is frame 41. The sampler retains the airborne anchor through landing because train does not currently provide its supported callback. The independent probe measures at most 0.0000373 mm over actual supported intervals. That probe is causal evidence, not a replacement gate result: the official 23.202851 mm value remains in the final JSON and remains a failure. No sampler filter was changed in this patch.

## Frontier finding retained separately

The remaining 80 original missing-contact records belong to Frontier archer/legionary/officer/spearman. A one-model experiment confirmed that generic uniform foot retargeting plus a 3D rotation raises and tilts the original soles. Archer LOD3 idle started at L/R 38.926/30.879 mm. A floor-preserving foot fit removes its five missing-contact clip records, but a broad rebuild would silently import newer hero/equipment sources. The old build report hero SHA is `e7ebd5f7c0b84eff67694b35697187615085fc26a75468590b4a585d1252c63e`; the current source is `28076301cb241d4de450946c08e47c83329a88eae1f50235b9ed4971b9ec4db1`. Equipment source hashes also differ. Every Frontier production file was restored to the exact base.

The experiment remains only in `frontier-experiment/`. It also exposes existing retreat/death defects. Reusing the existing authoring death-ground fit on the actual bound death NLA action reduced the experiment's penetration from 160.486 to 4.760 mm and slip from 881.238 to 42.848 mm, still over the 15 mm bound. A future implementation must resolve the actual bound action (`death.001` in that scene), not a global action named `death`. These experiments are not included in the 12 production files.

## Exact production delivery

Full SHA256 values and byte sizes are in `final-file-manifest.json`; all eight mesh hashes are also in the accessor report and character build report. The exact paths are:

- `docs/20_meshy_assets/character-build.json`
- `prototype/assets/meshy/characters/unit_germanic_axe_fighter_0.glb`
- `prototype/assets/meshy/characters/unit_germanic_axe_fighter_1.glb`
- `prototype/assets/meshy/characters/unit_germanic_axe_fighter_2.glb`
- `prototype/assets/meshy/characters/unit_germanic_axe_fighter_3.glb`
- `prototype/assets/meshy/characters/unit_roman_signifer_0.glb`
- `prototype/assets/meshy/characters/unit_roman_signifer_1.glb`
- `prototype/assets/meshy/characters/unit_roman_signifer_2.glb`
- `prototype/assets/meshy/characters/unit_roman_signifer_3.glb`
- `prototype/tests/motion_skin_measurement_test.gd`
- `tests/meshy_gait_reach_test.py`
- `tools/characters/build_meshy_people.py`

## Complete evidence index

- `meshy-final-comparison.json`: all 88 baseline / gait-only / final records, exact gate validation, newly crossed and remaining surface limits.
- `meshy-final-accessor-comparison.json`: final eight GLB hashes and every changed skin-binding row.
- `meshy-eight-accessor-comparison.json`: baseline-to-gait accessor evidence.
- `sole-weight-probe.json`, `sole-candidate-authoring.json`, `sole-weight-candidate-probe.json`: concrete smoothing defect and isolated corrected GLB.
- `train-contact-probe.json` / `.log`: actual unsupported landing counted by the unchanged train sampler.
- `geometry-final/`: four canonical viewport PNGs, source/image hashes, exact runtime configuration and raw pose geometry.
- `final-file-manifest.json`: exact 12-file production delivery.
- `evidence/independent-gait-review/`: independent authoring regression, old/new generator proof.

The parent integration must run the full exact-head CI/gate after combining these changes with other authorized runtime work. The baseline global gate had 536 blockers; this isolated report does not predict a new global total.
