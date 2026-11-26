# Fold7 physical-device regression (26 November 2026)

Build #152 did not pass physical-device acceptance. Owner evidence: six in-game screenshots, persistent detached grass in the historical prologue, unreadable dark/overexposed film lighting and indoor geometry/shadow artifacts. Owner also reports a backwards-marching market escort and a water jug that remains attached to the boy.

## Changes and gates
- I-01: disallow optional early well fetch before the table is set; recover the previously legal stranded save via a real table placement transaction, preserve the water and recorded events, verify subsequent pouring and reload. Add explicit jug pickup/pour/release presentation and a two-bone carry overlay (not motion-capture animation).
- I-03: never parent a quest object to a disposable LOD skeleton; follow the new hand after replacement and release on delivery.
- Market escort: align company mesh's +Z front with the navigation body's -Z front; use measured travel for march phase; keep the six patrol characters animated at far distance.
- Android: replace grass MultiMesh with CPU-baked cell-local geometry. Retain authored placement and profile density; isolate Valdora vegetation from the historical camp, restore at handoff. Camera-local film exposure and ambient fill; lower film interior light energies; disable mobile window-glow cards and sun shafts until verified. These are targeted mitigations, not a proven Adreno driver diagnosis.
- Tests: state/reload, actual hand ownership and release, market facing and LOD change, grass chunk bounds and framebuffer, opening vegetation restoration, plus prior QA selection. The full suite and device acceptance remain independently required; no production release claim.

## Additional audit
The latest full run reported mission bridge and v2 migration failures from obsolete fixture schemas (v7 investigation fields and new screenplay keys), plus a hard-coded legacy Marcus model assertion. These tests now check the actual current migrations and authored model without weakening the state comparison or motion metrics. The later gate-watch water jug is now shown/released from the authoritative I-07 state. I-04 wood and documents are kept by the world-owned prop container across LOD replacements. Their rendering still needs the new full test evidence. Other combat, formation, bench and valley issues remain open; a successful selected QA build is not a full-suite pass.
