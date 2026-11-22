extends RefCounted
## Preserve the original GLB character palette on engines that import COLOR_0
## but leave BaseMaterial3D.vertex_color_use_as_albedo disabled.
##
## Godot 4.7.2 was observed importing the authored colour arrays correctly while
## keeping this flag false. glTF COLOR_0 is a linear base-colour multiplier:
## https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#materials
## https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html
##
## Call apply_to(instance) once after instantiating a character GLB. This only
## repairs named character-palette surfaces that actually contain colours.
## Textured clothing, meshes, source resources and other materials stay intact.

static func apply_to(root: Node) -> int:
	var repaired := 0
	if root is MeshInstance3D:
		var instance := root as MeshInstance3D
		if instance.mesh != null:
			for surface in range(instance.mesh.get_surface_count()):
				var source := instance.get_active_material(surface) as BaseMaterial3D
				if source == null or not "_CharacterPalette" in source.resource_name:
					continue
				var arrays := instance.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_COLOR:
					continue
				if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
					continue
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if colors.is_empty():
					continue
				if source.vertex_color_use_as_albedo and not source.vertex_color_is_srgb:
					continue
				# Use an instance override; do not mutate cached imported materials.
				var palette := source.duplicate() as BaseMaterial3D
				palette.vertex_color_use_as_albedo = true
				palette.vertex_color_is_srgb = false
				instance.set_surface_override_material(surface, palette)
				repaired += 1
	for child in root.get_children():
		repaired += apply_to(child)
	return repaired
