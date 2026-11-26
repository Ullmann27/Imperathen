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

## Resident identity layer (named residents and generic villagers)

`build_resident_identity.py` gives the adult village cast individual faces,
builds, hair, beards and clothing without new scans or downloads. It opens the
unchanged civilian frontier sources (`art/frontier_people/{civilian_man,
civilian_woman,elder}.blend`) and re-exports the same runtime files
`prototype/assets/characters/frontier_<kind>_<0..3>.glb`, so the rig, the
eleven clips, the motion-gate family, every `VillagePerson` route and the
frontier tests stay as they are. `tools/characters/build_frontier_people.py`
re-applies this pass whenever it exports a civilian kind, and every export of
this pass runs the same post-export repairs as the frontier exporter
(grounded death and gather clips, closed skirt seam, kit rivets).

What the pass adds to every tier:

* Face controls (`ID_NoseLength`, `ID_NoseWidth`, `ID_NoseBridge`, `ID_JawWidth`,
  `ID_Chin`, `ID_FaceLength`, `ID_Cheeks`, `ID_Cheekbones`, `ID_Brow`, `ID_Lips`,
  `ID_Ears`, `ID_EyeDepth`, `ID_Age`) and body controls (`ID_Heavy`,
  `ID_Shoulders`). They are functions of the rest position, applied to skin,
  hair, beard and garments alike, so the gap between body and cloth is kept.
* Hair controls on the existing hair (`HAIR_Short`, `HAIR_Recede`,
  `HAIR_Volume`, `HAIR_Nape`) and a centre-parted bound hairstyle for women
  (`IdentityHairBound`, drawn back to the existing bun).
* Optional pieces fitted by ray casting against the actual body and cloth:
  `IdentityBeard` (+`BEARD_Full`, borders fade into the skin), `IdentityApron`
  (leather, above the knee, lower halves follow the thighs), `IdentityMantle`
  (shoulder cape narrowing into a back panel), `IdentityVeil` (+`VEIL_Long`),
  `IdentityCap` (felt pileus), and on the two near tiers `IdentityPouch`,
  `IdentityBrooch`, `IdentityEarrings`. Each piece is shrunk into the body
  until `ID_Show` is set, so tools that load a GLB directly see the plain cast.
* `ID_Hem` (tunic length) and a neutral linen texture so runtime dyes are real
  colours.
* Shared textures in `prototype/assets/village_characters/identity/`: one skin
  mask set for all kinds (beard, creases/age spots, sun, flush; crease normal,
  scalp, eyebrows) and strand, wool and leather maps. They are not embedded in
  the GLBs.

Runtime: `scripts/visuals/resident_identity.gd` holds the catalog (one entry per
named resident; generic villagers get a stable look from appearance and
variation), `scripts/visuals/resident_look.gd` applies it to the loaded tier
with the shaders `resident_skin`, `resident_hair` and `resident_hair_cards`.
Both live builders pass the resident id to `VillagePerson.configure_resident`.

Rebuild and check (Blender 4.3.2, Godot 4.7.2):

```sh
blender -b -t 2 -P art/village_characters/build_resident_identity.py
godot --headless --path prototype --import
python3 tools/check_prototype.py --godot godot --only resident_identity frontier_people
```

`art/village_characters/resident_identity_report.json` lists landmarks,
triangles per tier and piece, shape keys, texture hashes and the limits.
