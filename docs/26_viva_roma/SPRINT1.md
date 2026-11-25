# VIVA ROMA / Sprint 1 – Visual foundation
Base: city integration at 8515544599827fad5585fb085a7e24820d4821a1. This branch changes the city material generator and the free-exploration lighting/ground only. Geometry, colliders, population, mission/economy and saved positions remain owned by their respective teams.

- Ten material families with independent physically motivated relief, colour and roughness. Periodic noise, staggered masonry, irregular paving, curved roof profiles, wood grain, plaster wear, marble veins, woven linen and turned clay. The normal map derives from metric height, not the colour image.
- Default 1024 px texture baking; explicit 2048 option for offline art review and selective promotion after measured device budgeting. Legacy 512 px mode remains available for comparison. No new full-city GLB is claimed.
- The existing exploration scene uses a profile-aware single sun, reduced ambient wash, sky reflections, distant haze and metric ground shading. Keep GL Compatibility, no unsupported screen-space effects. No geometry displacement.
- Render preview samples increased to 48 with denoising. Legacy preview stays at 20 without denoising. For a strict material A/B use identical camera, lighting, sampling and exposure; compare in an offline fixture.

## Reproduce
```
python tools/world/check_viva_roma_surfaces.py
blender -b -t 2 --python tools/world/build_roman_test_city.py -- --output /tmp/viva --surface-style viva --texture-size 1024 --render
blender -b -t 2 --python tools/world/build_roman_test_city.py -- --output /tmp/legacy --surface-style legacy --render
godot --headless --path prototype --script res://tests/viva_roma_atmosphere_test.gd
```
Numerical material checks run locally on the exact baker blob 53a67f357fb7d492d166a0431594bae531e1572e: all ten families at 512, paving at 1024, stone at 2048; deterministic and cyclic sample shift equality, maximum decoded unit normal error 1.79e-7. Blender, Godot and Android not available locally; no new rendered city, GLB, visual quality sign-off or APK. Do not claim AAA or historical accuracy. City remains a fictional free-exploration area, including era-mixed monuments; narrative chronology is unaffected. No independent agents started in this session. No merge to main.
