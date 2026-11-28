# I-01 breakfast bread

The family breakfast already references the `table_bread` prop at the imported kitchen table. Its replacement is authored as Godot-native mesh geometry in `prototype/assets/operation_prima/breakfast_bread.gd`: a shallow oval serving board, one irregular scored loaf, and three recessed score strips.

The mesh keeps the existing prop origin and `kit_manifest.json` bounds. The existing manifest remains the source of collision dimensions, and the mesh uses the interior kit's oak and food PBR materials plus a profile-managed toasted-cut tint. No external model, texture, paid service, save field, or mission-state change is introduced. The dedicated geometry/collision/triangle-budget test is `prototype/tests/operation_prima_art_test.gd`.

The engine render and baseline-to-after visual comparison are pending the parent-managed Godot preview; this authoring note is not a visual acceptance claim.
