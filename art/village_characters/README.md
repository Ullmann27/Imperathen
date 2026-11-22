# Village people

The playable child and the companion use the project's sculpted civilian study from `tools/art/build_characters.py`. The Blender scene contains the 15-joint armature, age and companion shape keys, regional clothing, hair pieces, sandals, individually shaped fingers, nails, and eleven actions. The 12-year-old stands about 1.52 m tall. The adult has a longer silhouette and a broader chest and jaw. Italian adults use the project's two adult face references. Other adult origins keep their identity texture and acquire the mature mesh proportions.

The 256 × 256 face UV maps come from this repository’s own gallery renders. Eye landmarks align them to the sculpted face. The linen layers use the project’s woven color, normal and roughness maps. Mantles, brooches, wrapped lapels, sashes and woven bands are costume designs for these individuals in the fictional village.

| Render tier | Civilian base triangles | Officer | Recruit | Raider |
|---|---:|---:|---:|---:|
| 0 | 18,939 | 5,154 | 4,682 | 4,814 |
| 1 | 9,090 | 3,096 | 2,920 | 2,962 |
| 2 | 3,596 | 1,094 | 1,008 | 1,032 |
| 3 | 796 | 239 | 235 | 239 |

Clothing and hairstyle add visible triangles according to identity. NPCs reuse the corresponding original company rigs and animated equipment. The two inexpensive village soldier tiers retain the skeleton so that lowering the detail preserves movement and fallen poses.

Rebuild and check from the repository root:

```sh
python art/village_characters/face_maps.py
blender -b -t 2 -P art/village_characters/build.py
blender -b -t 2 -P art/village_characters/soldier_lods.py
godot --headless --path prototype --import
godot --headless --path prototype --script res://tests/village_person_test.gd
```

Python requires Pillow and NumPy for the UV maps. Camera reviews can call `refresh_lod(camera)` followed by `sample_pose(action, normalized_time)` on `Player/Figure`, `Marcus/Figure`, `TrainingGround/Mentor/Figure`, or a recruit or enemy's `Figure`. The names of the scene roots are stable across the five playable origins.
