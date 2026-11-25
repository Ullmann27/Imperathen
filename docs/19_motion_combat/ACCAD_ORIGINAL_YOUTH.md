# Original youth – human motion retargeting, 25 November 2026

User device evidence: 34.522 s recording, Screen_Recording_20261125_185000_IMPERATHEN QA.mp4, supplied in the private Drive project. Visible stiff long steps and limited upper-body weight transfer. No private recording is copied into GitHub.

## Motion source and license

Open Motion Project by ACCAD/The Ohio State University, Creative Commons Attribution 3.0 Unported.
https://accad.ohio-state.edu/research/motion-lab/mocap-system-and-data
https://creativecommons.org/licenses/by/3.0/
Archive: Male2_bvh.zip, 149 human-recorded BVH files, SHA-256 f30dc56f8557d4b9f1bd6b8b0c4218c076471de0a9c1a20f3bc4a8b776cc14b1.

Changes: select measured gait cycles, crop/retime strikes to the existing authoritative gameplay windows, retarget joint directions to the original 35-bone character, preserve target segment lengths, remove horizontal root travel, ground sampled actual skin soles, resample at 60 Hz and close gait loop seams. Original mesh, texture, material, skin, inverse bind and binary data unchanged. The archive itself is not redistributed in the app. Attribution is included in the runtime manifest, GLB asset extras and QA release notes.

## Evidence from executed offline transfer

Four original LODs processed with all 11 new clips. Walk: B3 frames 249–369, 120 Hz source, duration 1.0 s, measured target cycle distance 1.36795 m. Run: C3 frames 16–39, 30 Hz source, duration 0.766666 s, measured target cycle distance 2.38253 m. Six punches, two kicks and high guard from named recorded takes. Original 35-joint hierarchy retained. Offline bone lengths preserved within floating-point precision; grounding samples used actual foot-skin vertices. This is not proof of complete surface deformation, world foot-contact drift, natural visual quality or phone performance.

At the previous 3.8 m/s run speed, the previous 1.75 m gait produced 2.17 cycles/s. The new measured stride produces about 1.59 cycles/s, roughly 27% fewer cycles at the same physical speed. The renderer uses actual movement speed and domain combat time. Preserve the mocap heel/toe roll and swing instead of freezing the entire ankle. Older characters and adult weapon actions retain their existing animations; further capture/retargeting and weapon contact acceptance remain open.

The strict production Motion Quality Gate is unchanged. This is an isolated QA candidate, not a visual quality sign-off. No new user secret is required.
