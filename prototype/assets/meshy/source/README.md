# Canonical Meshy authoring sources

This directory is intentionally ignored by Godot and its downloaded binaries
are not committed. Mobile builds use the fitted derivatives in `../characters`.

`../manifest.json` contains the canonical task IDs and intended paths.
`../lock.json` records the exact downloaded bytes, SHA-256 values, geometry,
materials and source rig/animation status. The seven inspected sources all
contain static geometry: none supplied a skeleton or motion clips.

The two source GLBs required to reproduce the current character derivatives are:

| Stable ID | Canonical Meshy task |
| --- | --- |
| `unit_roman_signifer` | `01a20922-65cb-74a8-9cc1-7479aec8622b` |
| `unit_germanic_axe_fighter` | `01a20922-3da8-7164-b3ef-0d60b4c04729` |

Download the GLB of the exact task using the connected Meshy account, place it
under `character/<stable-id>.glb`, and compare its SHA-256 with the lock before
building. Signed download URLs are deliberately not saved in the repository.
The build command from the repository root is:

```sh
blender -b -t 2 -P tools/characters/build_meshy_people.py -- --types all
godot --headless --editor --path prototype --import
godot --headless --path prototype --script res://tests/meshy_character_test.gd
```

The remaining five downloaded sources are not interchangeable standing humans:
two contain the entire horse and rider, one has crossed arms and a shield, one
contains a pedestal and fixed spear/shield, and one has a fixed raised arm and
prop across the shoulder. Their exact inspection results are recorded in
`docs/20_meshy_assets/CHARACTER_SOURCE_REVIEW.json`. They must be reworked before
being admitted to the biped runtime route.
