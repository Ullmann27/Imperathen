# CharacterCore Phase 2A – equipment presentation

Base: db3153cb401963e7e54f1665b00a3efebb6358d9, #210 actual 79/79 Godot and 14/14 architecture checks. New derived scene equipment_character.tscn adds only EquipmentComponent to the original CharacterCore; existing campaign scenes, original rig, Phase 1 sources and tests unchanged.

## Interfaces
- ArmorPieceResource.from_catalog(id, tier, detail) resolves existing catalogue/LOD paths and explicitly supported authored socket profiles; no additional item IDs, combat stats, granting or prices.
- EquipmentComponent.sync_from_world(data, detail) is called by the authoritative world owner on equipment/era/LOD changes, never every frame. Uses GearMarket.validate, equipped_models, era_open and GearVisuals.instantiate (including quality materials). Unsupported wearable/invalid snapshots fail closed; mount slots remain mount-system responsibility.
- request_socket_switch(slot, place, clip, timeout_seconds) starts the existing spine-filtered upper-body layer only for an actual available clip. The external animation owner must call commit_socket_switch at its authored marker, then finish_socket_switch. Timeout cancels an uncommitted transition. No timers pretend to be contact markers. The new review test uses the real block clip as a layer test only.
- BoneAttachment3D follows the real rig, with full nested imported marker transform and rest-space placement, independent of prop LOD. One occupant per placement; rebind and removal clear owned nodes only. No idle per-frame work.

## Limits
This is rigid equipment infrastructure only, not a garment or historical asset acceptance. Original source model includes its authored kit, so independent modular body variants, actual sheaths, draw/dress clips, hand alignment and visual anti-clipping remain separate gates. The catalog itself notes Pompeii gladius/rectangular scutum geometry differs from Caesarian variants; this test does not certify their 58 BCE appearance. No new gear grants to a child, no change to age, economy, story, saves or attack authority. No new hosted Meshy tasks. WorldModel integration into the live campaign, separately skinned tunic/mail/greaves, morph corrections and SpringBoneSimulator3D chains require verified authored meshes and visual/device regression. The animation layer has exclusive ownership in this isolated scene; production combat and equipment must arbitrate the layer before campaign use.

## Verification
Focused CI runs the exact original 79-check regression and new Phase 2A test on the same revision, with the original GLB hash pinned. Adult fixture repeats existing GearMarket purchase/equip receipt path; real nested GLB sockets, marker residual 2 mm, movement while the upper layer blends, duplicate/occupied/timeout rejection, LOD, no mutation and child fail-closed. No claim of pass until actual CI log. No main merge or APK release.
