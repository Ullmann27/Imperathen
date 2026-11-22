extends SceneTree
## Regression for the observed Godot 4.7.2 glTF character-palette import bug.
## godot --headless --path art/visual_benchmark \
##   --script res://scripts/verify_character_materials.gd

const CharacterMaterials = preload("res://scripts/character_materials.gd")
const ASSETS := ["civilian_youth", "frontier_guard", "civilian_youth_lod1", "frontier_guard_lod1"]

var failures: Array[String] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	for id in ASSETS:
		_verify_asset(id)
	var report := {
		"schema_version": 1,
		"engine": Engine.get_version_info().string,
		"status": "passed" if failures.is_empty() else "failed",
		"scope": "Imported GLB palette flags, complete colour/position arrays, source-resource isolation and idempotence; visual rendering is checked separately.",
		"assets_checked": results.size(),
		"failures": failures,
		"assets": results,
	}
	var output := "res://evidence/character_palette_runtime_validation.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write regression report: " + output)
		report.status = "failed"
	else:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("CHARACTER_PALETTE_VALIDATION " + JSON.stringify({
		"status": report.status,
		"assets_checked": results.size(),
		"failures": failures,
		"report": output,
	}))
	quit(0 if failures.is_empty() else 1)

func _verify_asset(id: String) -> void:
	var path := "res://assets/characters/" + id + ".glb"
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append(id + ": character scene could not be loaded")
		return
	var instance := packed.instantiate()
	var before := _snapshot(instance)
	var changes := CharacterMaterials.apply_to(instance)
	var after := _snapshot(instance)
	var second_changes := CharacterMaterials.apply_to(instance)
	var failure_start := failures.size()
	var palette_surfaces := 0
	var colour_count := 0
	var expected_changes := 0
	if before.size() != after.size():
		failures.append(id + ": material correction changed the surface count")
	for i in range(mini(before.size(), after.size())):
		var old: Dictionary = before[i]
		var current: Dictionary = after[i]
		if old.mesh_id != current.mesh_id or old.positions != current.positions:
			failures.append(id + ": geometry changed at " + old.node)
		if old.colours != current.colours:
			failures.append(id + ": vertex colours changed at " + old.node)
		if old.palette:
			palette_surfaces += 1
			colour_count += old.colours.size()
			if old.colours.is_empty():
				failures.append(id + ": named character palette has no vertex colours")
			if not old.vertex_albedo or old.vertex_srgb:
				expected_changes += 1
			if not current.vertex_albedo or current.vertex_srgb:
				failures.append(id + ": palette must use linear vertex colours as albedo")
			if old.albedo != current.albedo:
				failures.append(id + ": authored base-albedo factor changed")
			var source: BaseMaterial3D = old.source_material
			if source.vertex_color_use_as_albedo != old.vertex_albedo or source.vertex_color_is_srgb != old.vertex_srgb:
				failures.append(id + ": cached imported material was mutated")
		elif old.material_id != current.material_id:
			failures.append(id + ": non-palette material replaced at " + old.node)
	if palette_surfaces != 1:
		failures.append(id + ": expected exactly one authored palette surface")
	if changes != expected_changes:
		failures.append(id + ": repair count differs from imported palette flags")
	if second_changes != 0:
		failures.append(id + ": repeated application is not idempotent")
	results.append({
		"asset": id,
		"status": "passed" if failures.size() == failure_start else "failed",
		"surfaces": before.size(),
		"palette_surfaces": palette_surfaces,
		"palette_colour_count": colour_count,
		"repaired_surfaces": changes,
		"second_application_changes": second_changes,
	})
	instance.free()

func _snapshot(node: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				failures.append(str(node.name) + ": expected an imported BaseMaterial3D")
				continue
			var arrays := instance.mesh.surface_get_arrays(surface)
			var colours := PackedColorArray()
			if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				colours = (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
			var positions: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			out.append({
				"node": str(node.name),
				"material_id": material.get_instance_id(),
				"source_material": material,
				"mesh_id": instance.mesh.get_instance_id(),
				"palette": "_CharacterPalette" in material.resource_name,
				"vertex_albedo": material.vertex_color_use_as_albedo,
				"vertex_srgb": material.vertex_color_is_srgb,
				"albedo": material.albedo_color,
				"colours": colours,
				"positions": positions,
			})
	for child in node.get_children():
		out.append_array(_snapshot(child))
	return out
