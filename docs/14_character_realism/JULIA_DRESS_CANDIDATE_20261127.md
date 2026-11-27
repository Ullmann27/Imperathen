# Julia: measured pose-driven garment candidate, 2026-11-27

Fitting implementation revision: 6b693f8d839f3cda9845fbf23c18600981e23d09. Actual original parent GLB input: GitHub Actions artifact 15186781067. The recorded measurement is offline 60 Hz sampling of exported clip geometry, not a Godot framebuffer or Android performance measurement.

- 3044 poses, 942938 interior radial surface samples, zero missed rays and zero severe skirt edge-stretch events.
- Forty non-fall clip/LOD combinations meet the 10 mm clearance gate. All four fall combinations remain rejected: LOD0 10.48 mm, LOD1 22.71 mm, LOD2 25.74 mm, LOD3 33.77 mm. LOD3's fall clearance is worse than the original (approximately 22 mm). Do not release.
- Minimum sampled world garment height is zero within floating-point tolerance in this isolated flat-floor measurement.
- Only the calibrated garment candidate is changed; no unrelated body mesh is removed. The far levels retain the medium skirt topology, increasing their garment geometry budget. Actual mobile costs are unverified.

The metric covers selected leg vertices against the outer radial intersection of skirt triangles, excluding an open-edge band of 25 mm. It does not certify all triangle intersections, self-intersection, sleeve contact, sloping floors, or the procedural Godot poses. The isolated candidate workflow rejects the failed fall rows before staging the new models. Further numerical fit and actual visual/runtime acceptance are mandatory.

Child art: the previous successful build generated four anatomy families (16 GLBs). New source changes distinguish skin textures, dyed fabric, fitted hair silhouettes and eyebrow/lash meshes. New output is not yet accepted. Preserve the original player and existing owner-created Meshy models.

Compact measurement receipt: evidence/julia-dress-60hz-summary.json.
