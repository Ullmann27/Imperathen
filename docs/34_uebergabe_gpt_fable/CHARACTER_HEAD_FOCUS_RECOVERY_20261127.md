# Character head/eye/conversation focus recovery — 2026-11-27

Base: 62bd372ad2aef997cf086d126a21fca95ba90657 (PR #150). Do not merge into the initial-only main branch.

## Root cause and boundaries
- Player and Marcus are separate identities. `VillagePerson._path` selects the original private Meshy youth (civil or armoured), or hero family; Marcus selects his own four authored GLBs.
- Both model families face +Z in skeleton rest space; Model rotates PI inside the -Z-facing gameplay Figure. The player Meshy branch preserves retargeted animation and previously had no final neutral head correction. Procedural Marcus already has small idle/talk head gestures, but no target-directed correction. Exact visual source of the reported persistent side gaze still requires a before/after rendered frame.
- Marcus has a 15-bone skeleton and blend shapes, but no separate eyes/neck. Original youth has weighted Neck/Jaw/Brow auxiliary bones, no eye pair; Neck is a Spine child alongside Head. No reparenting, bind matrix, private mesh, UV or eye texture modification.
- Final reversible head layer runs after manual AnimationPlayer, procedural motion, foot contacts and face animation. It removes its own pose before animation sampling/transition and does not write sprint/combat/posed attacks. Compatible independent eye pair support is optional and unverified on production models.
- Social selection uses actual actor identity and gaze anchors; explicit speaker overrides partner, proximity is bounded, ray queries are on the physics clock, and ambient dwell/cooldown avoid permanent staring. Dialogue player body aligns only when stationary; cinematic body blocking remains director-owned.
- Marcus source sculpt now separates bridge/tip/ala/root and moderates jaw/cheek; existing shape keys and UVs remain. Original private youth face is unchanged pending a verified close-up/mesh-landmark pass. Rebuild and compare real renders before accepting the sculpt.

## Acceptance
Existing `marcus_character` QA now includes actual model neutral front, speaker switch, near pass-by, walking and combat isolation checks. Existing full asset acceptance stages the private civil youth and rebuilds Marcus before running this suite. No device, render or APK pass is claimed by the source commit. Fold7 measurements and eye/face visual acceptance must remain open until actual evidence exists.
