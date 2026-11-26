# Android visual QA targets

This branch records measurable **targets**, not completed GPU optimizations or FPS measurements.

1. Capture identical saved scene, camera, weather, time of day and combat state at each profile.
2. Record render resolution, device model, driver, average/p95/p99 frame times, peak temperature, battery state and 20-minute thermal trend on a **physical** Android device only when test is authorized.
3. Compare character skin, cloth, metal, building PBR, shadow stability, terrain/vegetation and silhouettes to project reference art.
4. Never change unit counts, combat rules, collision, economy or AI based on graphics preset.
5. A stopped soak test remains stopped until explicitly reauthorized.

Run: `python3 tools/check_android_graphics_targets.py`.

Profile IDs in this QA document are German UI labels; existing engine profile identifiers must be mapped during integration, not silently renamed.
