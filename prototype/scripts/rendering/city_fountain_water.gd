extends RefCounted
## Muted, dielectric water on the two authored public fountains only.
## No extra geometry, lighting, draw batches, or changes to the shared GLB.
const FOUNTAINS := ["Forum_Fountain", "Northern_Fountain"]
const SOURCE_NAME := "Water_Surface"
const OWNER_META := "imperathen_fountain_water_v1"

static func apply(city: Node3D) -> int:
	if not is_instance_valid(city) or city.name != "RomanCity":
		return 0
	var shared: Dictionary = {}
	var tuned := 0
	for fountain_name: String in FOUNTAINS:
		var anchor := city.find_child(fountain_name, true, false)
		if anchor == null:
			continue
		var mesh_nodes: Array[Node] = anchor.find_children("*", "MeshInstance3D", true, false)
		if anchor is MeshInstance3D:
			mesh_nodes.push_front(anchor)
		for node: Node in mesh_nodes:
			var view := node as MeshInstance3D
			if view == null or view.mesh == null or view.material_override != null:
				continue
			for surface: int in view.mesh.get_surface_count():
				var original := view.mesh.surface_get_material(surface) as BaseMaterial3D
				if original == null or original.resource_name != SOURCE_NAME:
					continue
				var existing := view.get_surface_override_material(surface)
				var source_id := original.get_instance_id()
				if existing != null:
					# Preserve unrelated authoring overrides; our own is idempotent.
					if existing.get_meta(OWNER_META, false) == true:
						shared[source_id] = existing
						tuned += 1
					continue
				var water := shared.get(source_id) as BaseMaterial3D
				if water == null:
					water = original.duplicate() as BaseMaterial3D
					water.resource_name = "Imperathen_Fountain_Water"
					water.set_meta(OWNER_META, true)
					# Remove the saturated cyan and metallic reflection of the
					# opaque source. Keep imported texture/normal references.
					water.albedo_color = Color(0.20, 0.34, 0.36, original.albedo_color.a)
					water.metallic = 0.0
					water.roughness = 0.28
					water.emission_enabled = false
					shared[source_id] = water
				view.set_surface_override_material(surface, water)
				tuned += 1
	return tuned
