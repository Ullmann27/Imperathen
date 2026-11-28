extends RefCounted
## Household prop kit built by art/interiors/build_interior_kit.py: shared
## meshes, tiling PBR materials and the physical catalog (support heights,
## collision footprints). Metres; every prop faces +Z with its origin on the
## floor contact centre, or on the hook point for hanging props.

const KIT_SCENE := "res://assets/interiors/interior_kit.glb"
const MANIFEST := "res://assets/interiors/kit_manifest.json"
const BreakfastBread = preload("res://assets/operation_prima/breakfast_bread.gd")
const TEXTURE := "res://assets/interiors/textures/%s_%s.png"
const MATERIALS := ["oak", "wood_rough", "wicker", "straw", "linen", "wool", "leather", "terracotta",
	"coarseware", "iron", "bronze", "stone", "food", "hearth_clay", "embers"]
# Flat surfaces other items may rest on, measured from the kit geometry.
const TOPS := {
	"chest_wood": [.54], "chest_small": [.44], "arca": [.66], "shelf_rack": [.315, .875, 1.435],
	"shelf_low": [.265, .635, .995], "wall_shelf": [.235], "workbench": [.80], "workbench_low": [.62],
	"desk_writing": [.72], "bench_plain": [.4525], "bench_short": [.4525], "stool_three": [.455],
	"stool_log": [.42], "table_round": [.70], "cartibulum": [.835], "armarium": [1.66],
	"wall_shelf_deep": [.235], "anvil_block": [.79], "stall_trestle": [.82], "stall_trestle_b": [.82],
}
# Leaning props touch the plaster with their top and the paving with their foot.
const LEANING := ["amphora_lean", "farm_tools_lean", "loom_warp", "loom_madder", "hide_frame", "guard_kit",
	"wheel_lean", "broom"]
const MOUNTED := ["wall_shelf", "wall_shelf_deep", "peg_rail", "lararium"]
# Round footprints use a cylinder; flat or high-only props have no collider.
const ROUND := ["hearth_ring", "hearth_cook", "hearth_baker", "dolium", "barrel", "barrel_iron", "amphora_stand",
	"quern", "stool_three", "stool_log", "basket_empty", "basket_wool", "basket_apples", "basket_onions",
	"basket_charcoal", "basket_grain", "basket_bread", "basket_flour", "basket_grapes", "sack_grain", "sack_hemp",
	"sack_flour", "jar_olla", "jar_coarse", "bucket", "bucket_milk", "spinning_basket", "brazier", "table_round",
	"chair_wicker", "capsa", "candelabrum", "tripod_pot", "pot_cook", "anvil_block", "iron_blooms"]
const NO_COLLISION := ["rush_mat", "peg_rail", "loom_weights_pile", "iron_bars", "staves_bundle", "rope_coil",
	"yoke", "hides_stack"]
# Colliders that follow the solid parts instead of the bounding box:
# [size, centre] boxes in prop space (a stall is its table and four poles).
const SOLIDS := {
	"stall_trestle": [[Vector3(1.80, .82, .78), Vector3(0, .41, 0)], [Vector3(.08, 2.1, .08), Vector3(-.96, 1.05, -.49)],
		[Vector3(.08, 2.1, .08), Vector3(.96, 1.05, -.49)], [Vector3(.08, 2.1, .08), Vector3(-.96, 1.05, .49)],
		[Vector3(.08, 2.1, .08), Vector3(.96, 1.05, .49)]],
	"forge_hearth": [[Vector3(1.10, .76, 1.00), Vector3(0, .38, 0)], [Vector3(1.10, .64, .16), Vector3(0, 1.08, -.42)],
		[Vector3(.80, .34, .12), Vector3(0, .93, .43)]],
	"forge_bellows": [[Vector3(.58, 1.0, .92), Vector3(0, .50, 0)]],
	"forge_shelter": [[Vector3(.14, 2.5, .14), Vector3(-.10, 1.25, -3.15)], [Vector3(.14, 2.5, .14), Vector3(-.10, 1.25, 3.0)],
		[Vector3(.14, 2.6, .14), Vector3(1.25, 1.3, -3.15)], [Vector3(.14, 2.6, .14), Vector3(1.25, 1.3, 3.0)]],
	"tool_rack_smith": [[Vector3(1.0, 1.62, .16), Vector3(0, .81, 0)]],
}
# Roofs that span other props: only their posts are obstacles.
const CANOPY := ["forge_shelter"]
# Flames the engine adds to a prop: [offset, height, light strength]. The
# first entry of a prop carries its light; a strength of 0 is flame only.
const FLAMES := {
	"oil_lamp": [[Vector3(.080, .036, 0), .042, .34]],
	"candle_dish": [[Vector3(.001, .123, 0), .036, .26]],
	"candelabrum": [[Vector3(.001, 1.331, 0), .040, .30]],
	"hearth_ring": [[Vector3(0, .10, 0), .36, 1.0], [Vector3(.09, .09, .06), .26, 0.0], [Vector3(-.08, .09, -.05), .22, 0.0],
		[Vector3(-.03, .09, .09), .18, 0.0]],
	# The pot starts at .285 m: keep the central flame under it and seat the
	# outer flame on the .062 m embers crown of the imported hearth.
	"hearth_cook": [[Vector3(.02, .067, -.02), .19, 1.0], [Vector3(-.09, .08, .05), .19, 0.0], [Vector3(.14, .063, .07), .16, 0.0]],
	"forge_hearth": [[Vector3(0, .82, .10), .22, 1.5], [Vector3(.07, .82, .06), .15, 0.0], [Vector3(-.06, .82, .13), .13, 0.0]],
}
# Fires without an open flame still light the room: [offset, strength].
const GLOWS := {"hearth_baker": [Vector3(0, .42, 0), 1.0], "brazier": [Vector3(0, .95, 0), .8]}
# Standing water the engine adds: [centre, size (x, z)].
const WATER := {"quench_trough": [Vector3(0, .455, 0), Vector2(.63, .81)]}
# Props at or below this size are clutter: no collider, nearer visibility range.
const DETAIL_SIZE := .42

static var meshes: Dictionary = {}
static var info: Dictionary = {}
static var materials: Dictionary = {}
static var _profile := ""


static func ensure() -> void:
	if not meshes.is_empty():
		return
	if not materials.is_empty():
		_load_meshes()
		return
	_load_meshes()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	info = parsed.props if parsed is Dictionary else {}
	for name: String in MATERIALS:
		materials[name] = _make_material(name)
	var bread_cut: StandardMaterial3D = (materials["food"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	bread_cut.resource_name = "Interior_bread_cut"
	bread_cut.albedo_color = Color(0.62, 0.40, 0.24)
	materials["bread_cut"] = bread_cut
	set_profile("balanced")


static func _load_meshes() -> void:
	var scene: Node = (load(KIT_SCENE) as PackedScene).instantiate()
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		meshes[String(node.name)] = node.mesh
	scene.free()
	if meshes.has("table_bread"):
		meshes["table_bread"] = BreakfastBread.build_mesh()


## Drops the source meshes once every room is merged; ensure() reloads them.
## Materials stay, the merged rooms reference them.
static func release_meshes() -> void:
	meshes.clear()


static func _make_material(name: String) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.resource_name = "Interior_" + name
	paint.albedo_texture = load(TEXTURE % [name, "albedo"])
	paint.normal_enabled = true
	paint.normal_texture = load(TEXTURE % [name, "normal"])
	paint.normal_scale = .85
	var orm: Texture2D = load(TEXTURE % [name, "orm"])
	paint.roughness_texture = orm
	paint.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	paint.roughness = 1.0
	paint.metallic_texture = orm
	paint.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	paint.metallic = 1.0 if name in ["iron", "bronze"] else 0.0
	paint.metallic_specular = .4
	paint.ao_enabled = true
	paint.ao_texture = orm
	paint.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	paint.ao_light_affect = .35
	paint.vertex_color_use_as_albedo = true
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if name == "embers":
		paint.emission_enabled = true
		paint.emission_texture = load(TEXTURE % [name, "emission"])
		paint.emission = Color(1, 1, 1)
		paint.emission_energy_multiplier = .9
	return paint


## Material detail follows the quality profile; geometry and collision do not.
static func set_profile(profile: String) -> void:
	if profile == _profile:
		return
	_profile = profile
	for name: String in materials:
		var paint: StandardMaterial3D = materials[name]
		paint.normal_enabled = profile != "low"
		paint.ao_enabled = profile in ["high", "very_high"]
		paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if profile in ["low", "balanced"] \
			else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func material_for(surface: Material) -> StandardMaterial3D:
	var key := surface.resource_name.trim_prefix("INT_") if surface else "oak"
	return materials.get(key, materials.oak)


static func aabb(prop: String) -> AABB:
	var entry: Dictionary = info.get(prop, {})
	if entry.is_empty():
		return AABB()
	var low := Vector3(entry.aabb_min[0], entry.aabb_min[1], entry.aabb_min[2])
	var high := Vector3(entry.aabb_max[0], entry.aabb_max[1], entry.aabb_max[2])
	return AABB(low, high - low)


static func is_detail(prop: String) -> bool:
	var size := aabb(prop).size
	return maxf(size.x, maxf(size.y, size.z)) <= DETAIL_SIZE


static func hanging(prop: String) -> bool:
	return bool(info.get(prop, {}).get("hanging", false))


## Local collision shapes for a prop: [{"shape": Shape3D, "offset": Vector3}].
static func collision(prop: String) -> Array:
	if prop == "stall_trestle_b":
		prop = "stall_trestle"
	if prop in NO_COLLISION or hanging(prop) or prop not in info:
		return []
	var box := aabb(prop)
	if is_detail(prop) and prop not in ROUND:
		return []
	var centre := box.get_center()
	if SOLIDS.has(prop):
		var parts: Array = []
		for solid: Array in SOLIDS[prop]:
			var part := BoxShape3D.new()
			part.size = solid[0]
			parts.append({"shape": part, "offset": solid[1]})
		return parts
	if prop.begins_with("hearth_"):
		# Stones and fire block walking; the tripod above stays visual.
		var ring := CylinderShape3D.new()
		ring.radius = maxf(box.size.x, box.size.z) * .5
		ring.height = .30
		return [{"shape": ring, "offset": Vector3(centre.x, .15, centre.z)}]
	if prop in ROUND:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(box.size.x, box.size.z) * .5
		cylinder.height = box.size.y
		return [{"shape": cylinder, "offset": centre}]
	var shape := BoxShape3D.new()
	shape.size = box.size
	return [{"shape": shape, "offset": centre}]
