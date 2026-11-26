# Weapon data contract v1 — design foundation

This folder contains **data only**. No weapon model, animation, combat wiring or Android benchmark is claimed by this commit.

- `weapon_catalog.v1.json`: initial balancing placeholders for seven weapon/shield types, in meters with Godot Y-up coordinates.
- `tools/validate_weapon_catalog.py`: stdlib-only structural validator; run `python3 tools/validate_weapon_catalog.py`.
- `asset` paths are **planned targets**, not evidence that GLB files exist.
- `grip_socket` names are proposed conventions; rig owners must confirm compatibility before connecting.
- Existing world state, save format, graphics profiles and Android export remain untouched.
- Do not bind damage to rendering/LOD. Animation hit windows and domain-authoritative damage require separate implementation and tests.

Next: issue #26 Blender GLBs; issue #27 rig/combat integration; issue #28 Android visual profiles.
