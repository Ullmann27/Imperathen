# Separate adult anatomy candidate for Julia and Silvanus

The existing female base was originally an authored deformation of the male youth source. The owner supplied a contemporary historical-game reference for recognizable adult female facial anatomy, hair, proportions and material detail. It is a quality reference only, not an asset or identity to copy.

This branch vendors three byte-identical CC0 graphical morph targets from the existing pinned MakeHuman revision and checks their Git blob hashes during the source build. Julia's candidate uses the actual female young/older targets; Silvanus uses a mature male blend. The original youth source, player meshes, story and animation contract are retained. The old male-to-female narrowing is bypassed when creating the new female source, so it is not applied twice. The age mixtures are art direction values, not a validated age estimator.

A disposable CI build exports both adult identities and captures the real Godot actors (high and very high, close, talk, full, walk, live Valdora). It never installs candidate GLBs into the repository or publishes an APK. Review actual eye placement, skin, hairline, silhouette, garments, foot contacts, facial movement and frame-time before accepting them. The existing shared-rig fit and texture resolution are still limitations; this is not an AAA acceptance claim.
