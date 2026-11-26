extends RefCounted
## Valdora house family: variant choice per household, shared materials per
## graphics profile and ageing state, visibility ranges per profile and the
## colliders that match the visible geometry. Assets and their manifest come
## from art/architecture/valdora_family/build_family.py.
##
## Every variant keeps the shared ground-floor room (interior contract in
## household_designs.gd on the interiors branch): paving at
## Layout.HOUSE_FLOOR, plaster faces at x = +-2.68 / z = +-2.17, door in the
## +Z wall (clear 1.12 x 2.08 m, leaf hinged at (-0.575, 2.15), open 100
## degrees), table, wall bench and corner jar as separate Fixture_* nodes.

const Art = preload("res://scripts/world/village_art.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const SHADER = preload("res://scripts/world/village/architecture/valdora_house.gdshader")
const MANIFEST = preload("res://assets/architecture/valdora/valdora_family.json")
const ASSET_DIR := "res://assets/architecture/valdora/"
const FORGE_SCENE := ASSET_DIR + "valdora_forge.glb"

## Wealth tier follows the household (docs/36_architecture/VALDORA_HOUSE_FAMILY.md).
const ASSIGNMENT := {
	"baker_home": "valdora_t2_render", "carpenter_home": "valdora_t2_hip", "weaver_home": "valdora_t2_eave",
	"farmer_home": "valdora_t1_daub", "potter_home": "valdora_t2_mixed", "healer_home": "valdora_t2_render",
	"elder_home": "valdora_t3_portico", "scribe_home": "valdora_t3_upper", "vintner_home": "valdora_t2_eave",
	"guard_home": "valdora_t1_rubble", "smith_home": "valdora_t2_mixed", "cloth_home": "valdora_t3_upper",
	"wagon_home": "valdora_t2_hip", "charcoal_home": "valdora_t1_daub", "leather_home": "valdora_t2_hip",
	"grain_home": "valdora_t2_render", "south_baker_home": "valdora_t2_hip", "south_weaver_home": "valdora_t1_rubble",
	"cooper_home": "valdora_t2_eave", "dairy_home": "valdora_t2_mixed",
}
## Ageing states: dirt/damp, moss and lichen, soot, worn edges.
const AGE_STATES := {
	"kept": [0.35, 0.22, 0.30, 0.25],
	"weathered": [0.60, 0.50, 0.55, 0.50],
	"worn": [0.82, 0.78, 0.72, 0.75],
	"dilapidated": [1.0, 1.0, 0.90, 1.0],
}
const AGE_BY_HOME := {
	"baker_home": "weathered", "carpenter_home": "worn", "weaver_home": "weathered", "farmer_home": "dilapidated",
	"potter_home": "worn", "healer_home": "kept", "elder_home": "kept", "scribe_home": "weathered", "vintner_home": "worn",
	"guard_home": "worn", "smith_home": "worn", "cloth_home": "kept", "wagon_home": "weathered", "charcoal_home": "dilapidated",
	"leather_home": "worn", "grain_home": "weathered", "south_baker_home": "weathered", "south_weaver_home": "dilapidated",
	"cooper_home": "weathered", "dairy_home": "worn",
}
## Visibility per profile: detail mesh end, full house end (far proxy beyond).
const RANGES := {
	"low": {"detail": 12.0, "house": 55.0},
	"balanced": {"detail": 26.0, "house": 95.0},
	"high": {"detail": 45.0, "house": 150.0},
	"very_high": {"detail": 70.0, "house": 220.0},
}

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _extra: Array[ShaderMaterial] = []
static var _wetness := 0.0


static func variant_for(home_id: String) -> String:
	return ASSIGNMENT.get(home_id, "valdora_t2_render")


static func manifest() -> Dictionary:
	return MANIFEST.data


static func variant_data(variant_id: String) -> Dictionary:
	return MANIFEST.data.variants.get(variant_id, {})


## Conservative 2D obstacle plan derived from the same authored manifest as
## build_collision(). Used by stateless navigation, not by the renderer.
static func navigation_footprints(home: Dictionary) -> Array[Rect2]:
	var data := variant_data(variant_for(str(home.id)))
	var shell := Layout.house_footprint(home)
	var extra: Array[Rect2] = []
	var pose := Transform3D(Basis(Vector3.UP, float(home.yaw)), home.at)
	for item: Dictionary in data.get("colliders", []):
		var size := _vec(item.size)
		var centre := _vec(item.centre)
		if centre.y + size.y * .5 < .1 or centre.y - size.y * .5 > 1.9:
			continue
		var local := Transform3D(Basis(Vector3.UP, float(item.get("yaw", 0.0))), centre)
		var box: AABB = pose * local * AABB(-size * .5, size)
		var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if str(item.name).begins_with("Wall") or str(item.name).begins_with("SocleSkirt"):
			shell = shell.merge(footprint)
		else:
			extra.append(footprint)
	var result: Array[Rect2] = [shell]
	for rect: Rect2 in extra:
		if not shell.encloses(rect):
			result.append(rect)
	return result


static func _texture_set(profile: String) -> Dictionary:
	# Leicht 256 px without normal maps, Ausgewogen/Hoch 512 px, Sehr hoch 1024 px.
	var size: int = {"low": 256, "very_high": 1024}.get(profile, 512)
	if not _textures.has(size):
		_textures[size] = {
			"size": size,
			"albedo": load(ASSET_DIR + "family_albedo_%d.jpg" % size),
			"orm": load(ASSET_DIR + "family_orm_%d.jpg" % size),
			"normal": null if size == 256 else load(ASSET_DIR + "family_normal_%d.jpg" % size),
		}
	return _textures[size]


## One shared ShaderMaterial per (profile, plaster tint, ageing state).
static func material(profile: String, tint: Color, age_state: String) -> ShaderMaterial:
	var key := "%s/%s/%s" % [profile, tint.to_html(false), age_state]
	if _materials.has(key):
		return _materials[key]
	var textures := _texture_set(profile)
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.resource_name = "VH_ValdoraFamily_" + key
	result.set_shader_parameter("albedo_layers", textures.albedo)
	result.set_shader_parameter("orm_layers", textures.orm)
	result.set_shader_parameter("use_normal_map", textures.normal != null)
	if textures.normal != null:
		result.set_shader_parameter("normal_layers", textures.normal)
	result.set_shader_parameter("use_parallax", profile == "very_high")
	result.set_shader_parameter("plaster_tint", tint)
	var age: Array = AGE_STATES.get(age_state, AGE_STATES.weathered)
	result.set_shader_parameter("age_dirt", age[0])
	result.set_shader_parameter("age_moss", age[1])
	result.set_shader_parameter("age_soot", age[2])
	result.set_shader_parameter("age_wear", age[3])
	result.set_shader_parameter("wetness", _wetness)
	_materials[key] = result
	return result


## Wetness follows the village season (village_scenery.WET); paving shares it.
static func set_wetness(value: float) -> void:
	_wetness = value
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter("wetness", value)
	for material: ShaderMaterial in _extra:
		material.set_shader_parameter("wetness", value)


static func register_material(material: ShaderMaterial) -> void:
	if material not in _extra:
		_extra.append(material)
	material.set_shader_parameter("wetness", _wetness)


static func instantiate(home: Dictionary, profile: String) -> Node3D:
	var variant_id := variant_for(home.id)
	var scene := load(ASSET_DIR + variant_id + ".glb") as PackedScene
	var model := scene.instantiate() as Node3D
	model.name = home.id
	model.set_meta("household_id", home.id)
	model.set_meta("house_variant", variant_id)
	model.set_meta("wealth_tier", int(variant_data(variant_id).get("tier", 2)))
	model.set_meta("age_state", AGE_BY_HOME.get(home.id, "weathered"))
	model.set_meta("plaster_tint", Color(home.tint))
	model.set_meta("porch", bool(variant_data(variant_id).get("features", {}).get("porch", false)))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.set_meta("valdora_family_shell", true)
	apply_quality(model, profile)
	return model


## Use the authored architecture but not its legacy fixture layout: the
## newer interior design owns the interactable workstations and their physics.
## The original detail mesh also contains fixture-specific decorations, so
## it must not be overlaid until those positions have been reconciled.
static func instantiate_forge_shell(profile: String) -> Node3D:
	if not ResourceLoader.exists(FORGE_SCENE, "PackedScene"):
		return null
	var scene := load(FORGE_SCENE) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	var shell_found := false
	var far_found := false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) == "valdora_forge_shell" and mesh.mesh != null:
			shell_found = true
		elif String(mesh.name) == "valdora_forge_far" and mesh.mesh != null:
			far_found = true
		else:
			mesh.free()
			continue
		mesh.set_meta("valdora_family_shell", true)
	if not shell_found or not far_found:
		model.free()
		return null
	model.name = "AuthoredForgeShell"
	model.set_meta("plaster_tint", Color("dfd4bd"))
	model.set_meta("age_state", "worn")
	apply_quality(model, profile)
	return model


static func is_family_house(model: Node) -> bool:
	return model.has_meta("house_variant")


static func apply_quality(model: Node3D, profile: String) -> void:
	var paint := material(profile, model.get_meta("plaster_tint", Color("dfd4bd")), model.get_meta("age_state", "weathered"))
	var ranges: Dictionary = RANGES.get(profile, RANGES.balanced)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# Preserve materials of the attached interiors, story props and yard objects.
		if not mesh.has_meta("valdora_family_shell"):
			continue
		mesh.material_override = paint
		mesh.visibility_range_end_margin = 4.0
		if mesh.name.ends_with("_far"):
			mesh.visibility_range_begin = ranges.house
			mesh.visibility_range_end = 0.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif mesh.name.ends_with("_detail"):
			mesh.visibility_range_end = ranges.detail
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if profile in ["low", "balanced"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif mesh.name.begins_with("Fixture_"):
			mesh.visibility_range_end = ranges.detail
		else:
			mesh.visibility_range_end = ranges.house


## Colliders: walls, socle skirt, porch and ramp cheeks from the manifest;
## floor, threshold landing, entry ramp, fixtures and the open leaf in the
## same planes as before (settlement, companion and interiors tests use them).
static func build_collision(model: Node3D) -> void:
	var data := variant_data(model.get_meta("house_variant"))
	var shapes := Node3D.new()
	shapes.name = "FamilyCollision"
	model.add_child(shapes)
	for item: Dictionary in data.get("colliders", []):
		var body := Art.box_collider(shapes, _vec(item.size), _vec(item.centre))
		body.name = str(item.name)
		body.rotation.y = float(item.get("yaw", 0.0))
	var floor_body := Art.box_collider(model, Vector3(5.28, Layout.HOUSE_FLOOR, 4.26), Vector3(0, Layout.HOUSE_FLOOR * .5, 0))
	floor_body.name = "WalkableFloor"
	floor_body.set_meta("surface_height", Layout.HOUSE_FLOOR)
	var entry: Dictionary = data.get("metadata", {}).get("entry", {"landing_top": .445, "ramp_start_z": 2.95, "ramp_run": 1.05, "width": 1.25})
	var landing := Art.box_collider(model, Vector3(1.25, .06, .90), Vector3(0, .415, 2.50))
	landing.name = "ThresholdLanding"
	var run := float(entry.ramp_run)
	var rise := float(entry.landing_top)
	var start := float(entry.ramp_start_z)
	var pitch := atan2(rise, run)
	var ramp := Art.box_collider(model, Vector3(float(entry.width), .06, Vector2(run, rise).length()),
		Vector3(0, rise * .5 - .03 * cos(pitch), start + run * .5 - .03 * sin(pitch)))
	ramp.name = "EntryRamp"
	ramp.rotation.x = pitch
	Art.box_collider(model, Vector3(1.45, .86, 1.10), Vector3(-1.1, Layout.HOUSE_FLOOR + .43, -.61)).name = "TableCollision"
	Art.box_collider(model, Vector3(.5, .52, 1.9), Vector3(1.93, Layout.HOUSE_FLOOR + .26, 0)).name = "BenchCollision"
	var door_angle := deg_to_rad(100)
	var leaf_center := Vector3(-.575, .415 + 1.04, 2.15) + Vector3(.56, 0, 0).rotated(Vector3.UP, door_angle)
	var leaf := Art.box_collider(model, Vector3(1.12, 2.08, .085), leaf_center)
	leaf.name = "OpenDoorLeafCollision"
	leaf.rotation.y = door_angle


static func _vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


## Godot-side triangle counts of the imported meshes, LOD levels included.
static func imported_stats(model: Node3D) -> Dictionary:
	var stats := {}
	for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node.mesh as ArrayMesh
		if mesh == null:
			continue
		var surface: Dictionary = mesh.get("_surfaces")[0]
		var lods: Array = surface.get("lods", [])
		var stride := 2 if int(surface.vertex_count) < 65536 else 4
		var levels: Array[int] = [int(surface.index_count) / 3]
		for i in range(1, lods.size(), 2):
			levels.append((lods[i] as PackedByteArray).size() / (3 * stride))
		stats[str(mesh_node.name)] = {"vertices": int(surface.vertex_count), "lod_triangles": levels, "surfaces": mesh.get_surface_count()}
	return stats
