extends RefCounted
## Shared look-development materials for Valdora: house lime plaster and the
## fine wear detail on flat prop colours. Visual only; one material per tint.
## Texture budget, VRAM-compressed with mipmaps (ETC2 on Android, S3TC/BPTC on
## desktop, identical sizes), shared by every house, prop and profile:
##   lime plaster 1024^2: albedo 0.67 MiB, normal (RG) 1.33 MiB, mask 0.67 MiB
##   wear detail 512^2: grey 0.17 MiB, normal 0.33 MiB
##   ground (village_scenery.gd) 1024^2: sod and earth colour + relief, 4 x 0.67 MiB
##   total 5.8 MiB; replaces 0.7 MiB of 512^2 ground maps. "low" skips the
##   plaster/wear texture fetches (flat colours) but keeps the same residency.

const PLASTER_SHADER := preload("res://scripts/world/village/lime_plaster.gdshader")
const PLASTER_ALBEDO := preload("res://assets/village/look/lime_plaster_albedo.png")
const PLASTER_NORMAL := preload("res://assets/village/look/lime_plaster_normal.png")
const PLASTER_MASK := preload("res://assets/village/look/lime_plaster_mask.png")
const WEAR_ALBEDO := preload("res://assets/village/look/wear_detail_albedo.png")
const WEAR_NORMAL := preload("res://assets/village/look/wear_detail_normal.png")
const WEAR_METRES := 0.75
static var _plasters: Dictionary = {}
static var _worn: Array[WeakRef] = []
static var _detail := 1.0


static func plaster(tint: Color) -> ShaderMaterial:
	var key := tint.to_html(false)
	if _plasters.has(key):
		return _plasters[key]
	var result := ShaderMaterial.new()
	result.resource_name = "ARCH_Lime_Plaster"
	result.shader = PLASTER_SHADER
	result.set_shader_parameter("tint", tint)
	result.set_shader_parameter("albedo_map", PLASTER_ALBEDO)
	result.set_shader_parameter("normal_map", PLASTER_NORMAL)
	result.set_shader_parameter("mask_map", PLASTER_MASK)
	result.set_shader_parameter("detail", _detail)
	_plasters[key] = result
	return result


## Fine dents, scratches and grain on a flat prop colour. Object-space
## triplanar, so moving props and carried gear do not swim through it.
static func add_wear(material: StandardMaterial3D) -> void:
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3.ONE / WEAR_METRES
	_set_wear(material, _detail > .5)
	_worn.append(weakref(material))


static func _set_wear(material: StandardMaterial3D, enabled: bool) -> void:
	material.albedo_texture = WEAR_ALBEDO if enabled else null
	material.normal_enabled = enabled
	material.normal_texture = WEAR_NORMAL if enabled else null
	material.normal_scale = .75


## "low" keeps flat colours and plaster without texture fetches; other profiles are detailed.
static func set_profile(profile: String) -> void:
	_detail = 0.0 if profile == "low" else 1.0
	for material: ShaderMaterial in _plasters.values():
		material.set_shader_parameter("detail", _detail)
	var alive: Array[WeakRef] = []
	for reference in _worn:
		var material := reference.get_ref() as StandardMaterial3D
		if material != null:
			_set_wear(material, _detail > .5)
			alive.append(reference)
	_worn = alive
