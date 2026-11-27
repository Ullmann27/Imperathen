# Original well: separate candidate integration from visual release approval

Producer: run 45989884335, source e1a374f6b40ea16801ea2dc616266eba24c314d1, artifact 15195336427.
The generated original GLB passed its static validator and seven-asset contract. The
full graphical I-01 run on Mesa llvmpipe stopped with timeout exit 124 after 1500
seconds; that is incomplete evidence, not proof of a failing imported mesh and
not a visual pass. CITY_LIFE_PASS checks=109 and LOCAL_WEATHER_PASS checks=4403
were observed on that run. The old committed asset remains the known binding blocker.

This independent branch recovers the exact artifact, validates producer revision,
GLB digest, triangle count and semantic moving parts, then runs the actual Godot
imported-scene animator contract and the unchanged complete I-01 headless regression.
If both pass, stage the exact generated GLB, editable Blender source and manifest
only as an integration candidate on this isolated branch. A failed test cannot stage
the files. No graphical or mobile release gate is waived. No merge to main, no APK
release, no visual quality assertion. A CI-token asset push may not trigger subsequent
workflows; the resulting candidate revision requires an explicit full regression,
render review and physical Fold7 acceptance. The ongoing Nemotron review remains
separate and must be reconciled before further gameplay modifications.
