extends RefCounted
## Local surface detail for the optional city preview. Never modifies a shared
## imported material, mesh, skeleton, animation or existing colour texture.
## Caller reapplies after a model/LOD/profile change, not every frame.

const ROOT := "res://assets/city_detail/characters/"
const SOURCE_META := &"city_detail_original_material"
const TIER_META := &"city_detail_profile"
const KNOWN := ["HeroSkin", "FrontierSkin", "HeroLinen", "FrontierCloth", "HeroLeather", "HeroHair", "FrontierGreyHair", "HeroEye", "FrontierEye", "FrontierGreyBeard"]
static var _materials: Dictionary = {}


static func apply_to(root: Node, profile: String = "high", lod: int = 0) -> int:
	if not is_instance_valid(root):
		return 0
	var tier := profile if profile in ["high", "very_high"] and lod in [0, 1] else "off"
	var changed := 0
	if root is MeshInstance3D:
		changed += _apply_mesh(root as MeshInstance3D, tier)
	for child: Node in root.get_children():
		changed += apply_to(child, profile, lod)
	# Weak values do not retain inactive LOD textures. Remove dead keys as well.
	if _materials.size() > 64:
		for key: String in _materials.keys():
			if (_materials[key] as WeakRef).get_ref() == null:
				_materials.erase(key)
	return changed


static func _apply_mesh(instance: MeshInstance3D, tier: String) -> int:
	if instance.mesh == null or instance.material_override != null:
		return 0
	var changed := 0
	for surface in instance.mesh.get_surface_count():
		var current := instance.get_active_material(surface) as StandardMaterial3D
		if current == null:
			continue
		var original := current
		if current.has_meta(SOURCE_META):
			original = current.get_meta(SOURCE_META) as StandardMaterial3D
			if original == null:
				continue
		if tier == "off":
			if current != original:
				instance.set_surface_override_material(surface, original)
				changed += 1
			continue
		if original.resource_name not in KNOWN:
			continue
		# A texture cannot safely reconstruct missing UVs or a tangent basis.
		var arrays := instance.mesh.surface_get_arrays(surface)
		if not has_normal_basis(arrays):
			continue
		if current.get_meta(TIER_META, "") == tier:
			continue
		var key := "%d/%s" % [original.get_instance_id(), tier]
		var detailed: StandardMaterial3D
		if _materials.has(key):
			detailed = (_materials[key] as WeakRef).get_ref() as StandardMaterial3D
		if detailed == null:
			detailed = _make_material(original, tier)
			if detailed == null:
				continue
			_materials[key] = weakref(detailed)
		instance.set_surface_override_material(surface, detailed)
		changed += 1
	return changed


static func has_normal_basis(arrays: Array) -> bool:
	if arrays.size() <= Mesh.ARRAY_TEX_UV:
		return false
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		return false
	if not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
		return false
	var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
	return vertices > 0 and arrays[Mesh.ARRAY_NORMAL].size() == vertices and arrays[Mesh.ARRAY_TEX_UV].size() == vertices and arrays[Mesh.ARRAY_TANGENT].size() == vertices * 4


static func _make_material(original: StandardMaterial3D, tier: String) -> StandardMaterial3D:
	var name := original.resource_name
	var category := "skin" if name in ["HeroSkin", "FrontierSkin"] else ("linen" if name in ["HeroLinen", "FrontierCloth"] else "leather")
	var material := original.duplicate() as StandardMaterial3D
	material.set_meta(SOURCE_META, original)
	material.set_meta(TIER_META, tier)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var full := tier == "very_high"
	# Never discard authored face normals, hair textures, opacity or roughness.
	if name in ["HeroHair", "FrontierGreyHair", "FrontierGreyBeard"]:
		if original.roughness_texture == null:
			material.roughness = clampf(original.roughness, 0.58, 0.86)
		material.metallic_specular = 0.28
		return material
	if name in ["HeroEye", "FrontierEye"]:
		if original.roughness_texture == null:
			material.roughness = clampf(original.roughness, 0.22, 0.34)
		material.metallic_specular = 0.45
		return material
	if not original.normal_enabled or original.normal_texture == null:
		var normal := load(ROOT + category + "_detail_normal.png") as Texture2D
		if normal == null:
			return null
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 1.0 if full else 0.8
	if category == "skin" and original.roughness_texture == null:
		var roughness := load(ROOT + "skin_detail_roughness.png") as Texture2D
		if roughness == null:
			return null
		material.roughness_texture = roughness
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.roughness = 1.0
	return material
