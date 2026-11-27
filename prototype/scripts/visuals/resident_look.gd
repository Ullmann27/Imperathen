extends RefCounted
## Applies a ResidentIdentity look to an imported frontier resident model:
## identity blend shapes, optional pieces, and per-person materials.
## The imported meshes and their source materials are never modified; every
## colour lives in a duplicated or shader material owned by the live actor.

const SKIN_SHADER := preload("res://shaders/resident_skin.gdshader")
const HAIR_SHADER := preload("res://shaders/resident_hair.gdshader")
const HAIR_CARDS_SHADER := preload("res://shaders/resident_hair_cards.gdshader")
const EYE_SHADER := preload("res://shaders/resident_eye.gdshader")
const PIECES := ["IdentityBeard", "IdentityHairBound", "IdentityApron", "IdentityMantle", "IdentityVeil",
	"IdentityCap", "IdentityPouch", "IdentityBrooch", "IdentityEarrings"]
## Shared by all kinds and tiers (same body UV layout); see build_resident_identity.py.
const TEXTURE_PATH := "res://assets/village_characters/identity/resident_%s.png"
const CIVILIAN := ["civilian_man", "civilian_woman", "elder"]
const SILHOUETTE_KEYS := ["ID_Heavy", "ID_Shoulders", "ID_Hem", "ID_FaceLength"]
## Mean linear luminance of each strand texture (measured from the sources).
const HAIR_REFERENCE := {"HeroHair": 0.055, "FrontierGreyHair": 0.07, "IdentityBeard": 0.24}
static var _materials := {}
static var _textures := {}


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


static func _cached(key: String) -> Material:
	if _materials.has(key):
		var material := (_materials[key] as WeakRef).get_ref() as Material
		if material:
			return material
	return null


static func _store(key: String, material: Material) -> Material:
	# Weak references: an inactive LOD tier and its textures may unload.
	_materials[key] = weakref(material)
	return material


static func signature(look: Dictionary) -> String:
	return "%s/%s" % [look.get("id", ""), look.get("kind", "")]


static func weights(look: Dictionary) -> Dictionary:
	var result := {}
	for key: String in look.get("face", {}):
		result[key] = float(look.face[key])
	for key: String in look.get("build", {}):
		result[key] = float(look.build[key])
	var hair: Dictionary = look.get("hair", {})
	for key: String in hair.get("keys", {}):
		result[key] = float(hair.keys[key])
	var pieces: Dictionary = look.get("wear", {}).get("pieces", {})
	if pieces.has("IdentityCap"):
		# Hair is pressed under a felt cap instead of passing through it.
		result["HAIR_Short"] = maxf(float(result.get("HAIR_Short", 0.0)), 0.9)
	var beard: Dictionary = look.get("beard", {})
	result["BEARD_Full"] = float(beard.get("full", 0.0))
	result["VEIL_Long"] = float(look.get("wear", {}).get("veil_long", 0.0))
	result["ID_Hem"] = float(look.get("wear", {}).get("hem", 0.0))
	return result


static func visible_pieces(look: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if look.get("soldier", false):
		return result
	for name: String in look.get("wear", {}).get("pieces", {}):
		result.append(name)
	if not look.get("beard", {}).is_empty():
		result.append("IdentityBeard")
	if str(look.get("kind", "")) == "civilian_woman" and str(look.get("hair", {}).get("style", "")) == "bound":
		result.append("IdentityHairBound")
	return result


static func apply(body: Node3D, look: Dictionary, level: int) -> void:
	if look.is_empty() or not body:
		return
	var kind := str(look.kind)
	var mask_kind := kind
	var shown := visible_pieces(look)
	var bound_hair := shown.has("IdentityHairBound")
	var values := weights(look)
	if level >= 2:
		# Distant tiers keep the silhouette (build, hem, beard and veil length,
		# hair volume) but skip face detail nobody can see at 13 m or more:
		# every non-zero blend shape is one more skinning pass per frame.
		for key: String in values.keys():
			if key.begins_with("ID_") and key not in SILHOUETTE_KEYS:
				values.erase(key)
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh:
			continue
		var part := String(mesh.name)
		if part in PIECES:
			mesh.visible = shown.has(part)
		elif part == "FrontierBeard":
			# The flat legacy chin patch is replaced by the shaped identity beard.
			mesh.visible = false
		elif part == "HeroHair" or part.begins_with("FrontierBoundLocks"):
			mesh.visible = not bound_hair
		elif part == "FrontierHairBun":
			mesh.visible = true
		if not mesh.visible:
			continue
		for index in mesh.mesh.get_blend_shape_count():
			var shape := String(mesh.mesh.get_blend_shape_name(index))
			if shape == "ID_Show":
				mesh.set_blend_shape_value(index, 1.0)
			elif values.has(shape):
				mesh.set_blend_shape_value(index, values[shape])
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source:
				continue
			var material := _material_for(look, mask_kind, part, source)
			if material:
				mesh.set_surface_override_material(surface, material)


## The shipped legacy frontier meshes share the resident atlas UVs. Keep their
## geometry and clothing; use the existing age/crease shader only when both
## real detail maps exist. Never turn a missing optional asset into a blank skin.
static func parent_skin(look: Dictionary, source: StandardMaterial3D) -> ShaderMaterial:
	if source == null or source.resource_name != "FrontierSkin" or source.albedo_texture == null:
		return null
	if _texture(TEXTURE_PATH % "skin_mask") == null or _texture(TEXTURE_PATH % "skin_detail") == null:
		return null
	return _material_for(look, str(look.kind), "HeroBody", source) as ShaderMaterial


static func _material_for(look: Dictionary, mask_kind: String, part: String, source: StandardMaterial3D) -> Material:
	var name := source.resource_name
	var id := signature(look)
	var key := "%s|%s|%s|%d" % [id, part if name in ["IdentityWool", "IdentityLeather", "IdentityMetal", "IdentityBeard", "HeroLeather"] else "", name, source.get_instance_id()]
	var cached := _cached(key)
	if cached:
		return cached
	var wear: Dictionary = look.get("wear", {})
	var pieces: Dictionary = wear.get("pieces", {})
	match name:
		"FrontierSkin":
			return _store(key, _skin(look, mask_kind, source))
		"HeroHair", "FrontierGreyHair":
			return _store(key, _hair(look.hair.color, float(look.hair.grey), source))
		"IdentityBeard":
			if part == "IdentityBeard":
				var beard: Dictionary = look.get("beard", {})
				return _store(key, _hair(beard.get("color", look.hair.color), float(beard.get("grey", look.hair.grey)), source))
			return _store(key, _hair(look.hair.color, float(look.hair.grey), source))
		"FrontierEye":
			var eye := ShaderMaterial.new()
			eye.shader = EYE_SHADER
			eye.resource_name = "ResidentEye"
			eye.set_shader_parameter("albedo_texture", source.albedo_texture)
			eye.set_shader_parameter("iris_color", look.get("eyes", Color(0.17, 0.10, 0.05)))
			eye.set_shader_parameter("roughness", source.roughness)
			return _store(key, eye)
		"FrontierCloth":
			if look.get("soldier", false):
				return null
			return _store(key, _dyed(source, wear.get("tunic", Color.WHITE)))
		"HeroLeather":
			if part == "HeroBelt" and not look.get("soldier", false):
				return _store(key, _dyed(source, wear.get("belt", Color(0.5, 0.36, 0.25))))
			return null
		"IdentityWool", "IdentityLeather":
			var cloth := _dyed(source, pieces.get(part, Color.WHITE))
			var stem := "wool" if name == "IdentityWool" else "leather"
			cloth.albedo_texture = _texture(TEXTURE_PATH % stem)
			cloth.normal_enabled = true
			cloth.normal_texture = _texture(TEXTURE_PATH % (stem + "_normal"))
			cloth.uv1_scale = Vector3(1.6, 1.6, 1.0) if stem == "wool" else Vector3.ONE
			return _store(key, cloth)
		"IdentityMetal":
			var metal := _dyed(source, pieces.get(part, Color(0.75, 0.54, 0.29)))
			metal.metallic = 0.85
			metal.roughness = 0.38
			return _store(key, metal)
	return null


static func _dyed(source: StandardMaterial3D, colour: Color) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	material.albedo_color = Color(colour.r, colour.g, colour.b, source.albedo_color.a)
	return material


static func _skin(look: Dictionary, mask_kind: String, source: StandardMaterial3D) -> ShaderMaterial:
	var skin: Dictionary = look.get("skin", {})
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.resource_name = "ResidentSkin"
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("use_normal_texture", source.normal_enabled and source.normal_texture != null)
	if source.normal_texture:
		material.set_shader_parameter("normal_texture", source.normal_texture)
	material.set_shader_parameter("normal_strength", source.normal_scale)
	material.set_shader_parameter("use_roughness_texture", source.roughness_texture != null)
	if source.roughness_texture:
		material.set_shader_parameter("roughness_texture", source.roughness_texture)
		var channel := Vector4.ZERO
		channel[clampi(int(source.roughness_texture_channel), 0, 3)] = 1.0
		material.set_shader_parameter("roughness_channel", channel)
	material.set_shader_parameter("roughness", source.roughness)
	material.set_shader_parameter("identity_mask", _texture(TEXTURE_PATH % "skin_mask"))
	material.set_shader_parameter("identity_detail", _texture(TEXTURE_PATH % "skin_detail"))
	# Colour uniforms use source_color: Color values are converted from sRGB.
	material.set_shader_parameter("tone", skin.get("tone", Color.WHITE))
	for parameter: String in ["sun", "flush", "age", "stubble", "scalp", "brow"]:
		material.set_shader_parameter(parameter, float(skin.get(parameter, 0.0)))
	for parameter: String in ["stubble_color", "brow_color"]:
		material.set_shader_parameter(parameter, skin.get(parameter, Color(0.12, 0.09, 0.07)))
	var hair: Color = look.get("hair", {}).get("color", Color(0.15, 0.11, 0.08))
	material.set_shader_parameter("scalp_color", hair.lerp(Color(0.55, 0.42, 0.34), 0.35))
	return material


static func _hair(colour: Color, grey: float, source: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var cards := source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shader = HAIR_CARDS_SHADER if cards else HAIR_SHADER
	material.resource_name = "ResidentHair"
	var albedo := source.albedo_texture
	var normal := source.normal_texture if source.normal_enabled else null
	if source.resource_name == "IdentityBeard":
		albedo = _texture(TEXTURE_PATH % "strands")
		normal = _texture(TEXTURE_PATH % "strands_normal")
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("use_normal_texture", normal != null)
	if normal:
		material.set_shader_parameter("normal_texture", normal)
	material.set_shader_parameter("reference_luminance", float(HAIR_REFERENCE.get(source.resource_name, 0.12)))
	material.set_shader_parameter("hair_color", colour)
	material.set_shader_parameter("grey", clampf(grey, 0.0, 1.0))
	# Reduce the high-frequency, overbright grey/streak contrast observed
	# in the real parent framebuffer; age is not a white painted pattern.
	material.set_shader_parameter("grey_color", colour.lerp(Color(0.48,0.43,0.38),0.48))
	material.set_shader_parameter("normal_strength",0.46)
	material.set_shader_parameter("roughness", clampf(source.roughness, 0.55, 0.9))
	return material
