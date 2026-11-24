# External motion retargeting: review branch

Pinned source: KinemIQ Free Game Animations v1.0 GLB release, CC0-1.0, motion originally from Quaternius. Archive digest: `64ca5ab4a92c9da079c5e88ca509391b0a58a24ccf2a1307b16e2f0fc6b23ffc`.

The separate CI job obtains and validates the actual source bytes, rejects unsafe archives and external GLB references, reads the imported source skeleton and animations, aligns source and hero body frames and samples rotation tracks at 30 Hz. It uses the existing hero's actual 15 named joints and preserves rest segment lengths, not the source mannequin's proportions. No imported root translation or source geometry is copied into the output. Unknown mappings fail closed. The resulting review AnimationLibrary and detailed report are GitHub artifacts.

The library is not a runtime replacement yet: skin deformation, foot contacts, equipment placement and animation transitions must also pass the game's actual visual and integration gates. No claim is made that a generated clip is shipped merely because the staging or skeletal review succeeded.

## Animation-only GLB correction

The first real archive inspection found 36 GLBs: the common skinned mannequin and 35 animation-only files. The second stage binds only their animation accessors and named channels to the mannequin's existing skin and hierarchy. All 35 source clips plus the reference must survive import and retarget; success on the mannequin alone is no longer sufficient. Review results remain distinct from shipping approval.
