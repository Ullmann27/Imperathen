extends RefCounted
## Loads the Blender-built vegetation (art/vegetation/build.py): per asset four
## mesh LODs plus an impostor card, and the herb/crop clump cards. Materials
## are shared per bark/leaf texture so profile, season and wind settings reach
## every instance through a few uniforms.

const Safe := preload("res://scripts/vegetation/vegetation_safe.gd")
const MANIFEST_PATH := "res://assets/vegetation/manifest.json"
const TEXTURES := "res://assets/vegetation/textures/"
const BARK_SHADER := preload("res://scripts/vegetation/vegetation_bark.gdshader")
const LEAF_SHADER := preload("res://scripts/vegetation/vegetation_leaf.gdshader")
const IMPOSTOR_SHADER := preload("res://scripts/vegetation/vegetation_impostor.gdshader")
const CARD_SHADER := preload("res://scripts/vegetation/vegetation_card.gdshader")
const GRASS_SHADER := preload("res://scripts/vegetation/vegetation_grass.gdshader")
const LODS := 4
## Wind stiffness per growth form (a shrub moves less than a poplar crown).
const SWAY := {"tree": 0.022, "shrub": 0.03, "vine": 0.012}

static var _manifest: Dictionary = {}
static var _assets: Dictionary = {}
static var _materials: Dictionary = {}
static var _cards: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file:
			_manifest = JSON.parse_string(file.get_as_text())
	return _manifest


static func asset_names() -> Array:
	return manifest().get("assets", {}).keys().filter(func(name: String) -> bool: return name != "herb_cards")


static func info(name: String) -> Dictionary:
	return manifest().get("assets", {}).get(name, {})


## {"lods": [Mesh x4], "impostor": Mesh or null, "height": float, "triangles": [int x5]}
static func asset(name: String) -> Dictionary:
	if _assets.has(name):
		return _assets[name]
	var meta := info(name)
	var result := {"lods": [], "impostor": null, "height": float(meta.get("height_m", 10.0)),
		"radius": float(meta.get("crown_radius_m", 4.0)), "kind": str(meta.get("kind", "tree")), "triangles": []}
	var packed := load("res://assets/vegetation/%s.glb" % name) as PackedScene
	if packed == null:
		push_error("Vegetation asset missing: " + name)
		return result
	var scene := packed.instantiate()
	var bark := bark_material(str(meta.get("bark", "oak")), result.height, result.kind)
	var leaf := leaf_material(str(meta.get("leaf", "oak")), result.height, result.kind)
	for lod in LODS:
		var node := scene.find_child("%s_lod%d" % [name, lod], true, false) as MeshInstance3D
		if node == null:
			push_error("Vegetation LOD missing: %s_lod%d" % [name, lod])
			continue
		var mesh: Mesh = Safe.copy_uncompressed(node.mesh) if Safe.active() else node.mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface)
			var leafy := source != null and source.resource_name.begins_with("leaf_")
			mesh.surface_set_material(surface, leaf if leafy else bark)
		result.lods.append(mesh)
		result.triangles.append(_triangles(mesh))
	scene.free()
	var impostor: Dictionary = meta.get("impostor", {})
	if not impostor.is_empty() and ResourceLoader.exists(TEXTURES + "impostor_%s_albedo.png" % name):
		result.impostor = _impostor_mesh(name, impostor, result.height, result.kind)
		result.triangles.append(_triangles(result.impostor))
	_assets[name] = result
	return result


static func bark_material(texture: String, height: float, kind: String) -> ShaderMaterial:
	var key := "bark_%s_%d_%s" % [texture, roundi(height * 10.0), kind]
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = Safe.BARK if Safe.active() else BARK_SHADER
	material.set_meta("vegetation_family","bark")
	material.set_shader_parameter("bark_albedo", load(TEXTURES + "bark_%s_albedo.png" % texture))
	material.set_shader_parameter("bark_normal", load(TEXTURES + "bark_%s_normal.png" % texture))
	_wind_defaults(material, height, kind)
	_materials[key] = material
	return material


static func leaf_material(texture: String, height: float, kind: String) -> ShaderMaterial:
	var key := "leaf_%s_%d_%s" % [texture, roundi(height * 10.0), kind]
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = Safe.LEAF if Safe.active() else LEAF_SHADER
	material.set_meta("vegetation_family","leaf")
	material.set_shader_parameter("leaf_albedo", load(TEXTURES + "leaf_%s_albedo.png" % texture))
	material.set_shader_parameter("leaf_normal", load(TEXTURES + "leaf_%s_normal.png" % texture))
	# Willow leaves are silvery and thin; alder leaves dark and leathery.
	if not Safe.active():
		material.set_shader_parameter("translucency", {"willow": .38, "alder": .32, "vine": .55}.get(texture, .5))
	_wind_defaults(material, height, kind)
	_materials[key] = material
	return material


static func card_material(atlas: String) -> ShaderMaterial:
	var key := "card_" + atlas
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = Safe.CARD if Safe.active() else CARD_SHADER
	material.set_meta("vegetation_family","card")
	material.set_shader_parameter("card_albedo", load(TEXTURES + "%s_albedo.png" % atlas))
	material.set_shader_parameter("crops", atlas == "crops")
	if not Safe.active():
		material.set_shader_parameter("plant_height", 1.0)
		material.set_shader_parameter("trunk_sway", 0.16 if atlas == "herbs" else 0.11)
		material.set_shader_parameter("branch_amplitude", 0.0)
		material.set_shader_parameter("leaf_amplitude", 0.025)
	_materials[key] = material
	return material


## Herb and crop clump meshes ("clump_near", "clump_far"), material per atlas.
static func card_mesh(variant: String, atlas: String) -> Mesh:
	var key := variant + "_" + atlas
	if _cards.has(key):
		return _cards[key]
	var packed := load("res://assets/vegetation/herb_cards.glb") as PackedScene
	var scene := packed.instantiate()
	var node := scene.find_child(variant, true, false) as MeshInstance3D
	var mesh: Mesh = Safe.copy_uncompressed(node.mesh) if Safe.active() else node.mesh.duplicate() as Mesh
	scene.free()
	mesh.surface_set_material(0, card_material(atlas))
	_cards[key] = mesh
	return mesh


## Blade tuft meshes ("grass_tuft_near", "grass_tuft_far") with one shared
## material: no texture, colour and wind per blade in the shader.
static func grass_mesh(variant: String) -> Mesh:
	if _cards.has(variant):
		return _cards[variant]
	var packed := load("res://assets/vegetation/herb_cards.glb") as PackedScene
	var scene := packed.instantiate()
	var node := scene.find_child(variant, true, false) as MeshInstance3D
	var mesh: Mesh = null
	if node != null:
		mesh = Safe.copy_uncompressed(node.mesh) if Safe.active() else node.mesh.duplicate() as Mesh
		mesh.surface_set_material(0, grass_material())
		_cards[variant] = mesh
	else:
		push_error("Vegetation grass tuft missing: " + variant)
	scene.free()
	return mesh


static func grass_material() -> ShaderMaterial:
	if _materials.has("grass"):
		return _materials["grass"]
	var material := ShaderMaterial.new()
	material.shader = Safe.GRASS if Safe.active() else GRASS_SHADER
	material.set_meta("vegetation_family","grass")
	_materials["grass"] = material
	return material


static func materials() -> Array:
	return _materials.values()


static func _wind_defaults(material: ShaderMaterial, height: float, kind: String) -> void:
	if Safe.active():
		return
	material.set_shader_parameter("plant_height", maxf(height, 1.0))
	material.set_shader_parameter("trunk_sway", SWAY.get(kind, 0.022))
	material.set_shader_parameter("branch_amplitude", 0.13 if kind == "tree" else 0.07)
	material.set_shader_parameter("leaf_amplitude", 0.045)


static func _impostor_mesh(name: String, meta: Dictionary, height: float, kind: String) -> ArrayMesh:
	var material := ShaderMaterial.new()
	material.shader = Safe.IMPOSTOR if Safe.active() else IMPOSTOR_SHADER
	material.set_meta("vegetation_family","impostor")
	material.set_shader_parameter("impostor_albedo", load(TEXTURES + "impostor_%s_albedo.png" % name))
	if not Safe.active():
		material.set_shader_parameter("impostor_normal", load(TEXTURES + "impostor_%s_normal.png" % name))
		material.set_shader_parameter("frame_size", float(meta.frame_size_m))
		material.set_shader_parameter("center_height", float(meta.center_height_m))
		material.set_shader_parameter("views", float(meta.views))
	_wind_defaults(material, height, kind)
	_materials["impostor_" + name] = material
	# The shader rebuilds the camera-facing quad; the vertices only carry UVs
	# and a bounding box that covers every orientation of the card.
	var size := float(meta.frame_size_m)
	var bottom := float(meta.center_height_m) - size * .5
	if Safe.active():
		return Safe.crossed_impostor(size,bottom,int(meta.views),material)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-size * .5, bottom, -size * .5), Vector3(size * .5, bottom, size * .5),
		Vector3(size * .5, bottom + size, size * .5), Vector3(-size * .5, bottom + size, -size * .5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh.custom_aabb = AABB(Vector3(-size * .5, bottom, -size * .5), Vector3(size, size, size))
	return mesh


static func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		count += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count
