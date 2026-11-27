# I-00 – Aquileia camp scenery candidate (2026-11-27)

Stacked on PR #166, at its original source commit. This does not modify the active Blender production branch. Reconcile its tested asset commit before final visual review.

- Six presentation-only wedge tents, with subdivided sagging canvas, open entrances, timber ridge supports, four guy ropes and stakes per tent, and crate details. Fabric colors are restrained historical inspiration, not a reconstruction certified by archaeology.
- 48 × 56 vertex-colored mud cells, subtle center road and wheel ruts; 12 irregular, opaque low-roughness puddles in one mesh. No expensive reflections or screen textures.
- No changes to the 54 formation slots, character assets, camera anchors, narrative, gameplay state or collision. Static elements share materials and compatible meshes and are batched by tent.
- Engine tests are extended in i00_stage_test.gd, with an isolated workflow. This tests real mesh construction and preservation of the former stage contract, not visual acceptance. No claim of actual rain reflections, final historical likeness, Blender tent assets, or measured mobile FPS.
- Required before merge/release: successful Godot import and tests, reconcile the verified original banner from #166, render representative shots, visually review on the Fold7 and measure frame time, draw calls, memory and thermal behavior.
