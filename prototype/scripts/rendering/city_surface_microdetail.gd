class_name CitySurfaceMicrodetail
extends RefCounted
## Procedural Roman facade and street microgeometry on existing *real* city meshes.
## Visual only: never replaces houses, roads, pedestrians, physics or campaign data.

const FountainWater := preload("res://scripts/rendering/city_fountain_water.gd")
const GROUP := "ImperathenFacadeMicrodetail"
const OWNER_META := "imperathen_city_facade_microdetail_v1"
const PROFILES := {
	"low":{"houses":0,"distance":0.0},
	"balanced":{"houses":14,"distance":75.0},
	"high":{"houses":28,"distance":115.0},
	"very_high":{"houses":36,"distance":145.0}
}
const PLAYER_START := Vector3(0.0,0.92,24.0)
const HOUSE_FRONT := {
	"insula":{"width":18.0,"depth":18.0,"height":3.5},
	"artisan":{"width":13.5,"depth":16.0,"height":3.4},
	"atrium":{"width":20.0,"depth":24.0,"height":3.3},
	"domus":{"width":26.0,"depth":30.0,"height":3.3}
}
const THEMES := [
	Color("b46b4a"), Color("8b5749"), Color("ac7964"),
	Color("a78768"), Color("a66e50"), Color("826755")
]
const PLASTER := [
	Color("d7c29d"),Color("c3b59b"),Color("cdb3a0"),
	Color("b7a58a"),Color("c1af82"),Color("bca08f")
]


static func install(city: Node3D, profile: String = "balanced") -> Dictionary:
	var report := {"ok":false,"status":"unsupported_city","houses":0,
		"brick_instances":0,"plaster_instances":0,"wood_instances":0,
		"street_instances":0,"added_colliders":0,"replaced_original_meshes":0,
		"materials":3,"profile":profile,"fountain_water_surfaces":0}
	if not is_instance_valid(city) or city.name != "RomanCity":
		return report
	if not PROFILES.has(profile):
		report.status = "unsupported_profile"
		return report
	var prior := city.get_node_or_null(NodePath(GROUP))
	if is_instance_valid(prior) and prior.get_meta(OWNER_META,false) != true:
		report.status = "foreign_group_conflict"
		return report
	if profile == "low":
		if is_instance_valid(prior):
			city.remove_child(prior)
			prior.free()
		report.status = "disabled_for_low"
		report.fountain_water_surfaces = FountainWater.apply(city)
		report.ok = true
		return report
	var existing_road: Node3D = city.find_child("Main_Streets",true,false) as Node3D
	if not is_instance_valid(existing_road):
		report.status = "missing_original_street"
		return report
	var houses: Array[Node3D] = []
	for node: Node in city.find_children("Residential_*","MeshInstance3D",true,false):
		var building := node as Node3D
		var family := _family(str(building.name))
		if family.is_empty():
			continue
		if building.global_position.distance_to(PLAYER_START) > 185.0:
			continue
		houses.append(building)
	houses.sort_custom(func(a: Node3D,b: Node3D) -> bool:
		var da := a.global_position.distance_squared_to(PLAYER_START)
		var db := b.global_position.distance_squared_to(PLAYER_START)
		return da < db if not is_equal_approx(da,db) else str(a.name) < str(b.name))
	if houses.is_empty():
		report.status = "no_compatible_houses"
		return report
	var brick: Array[Transform3D] = []
	var brick_tones: Array[Color] = []
	var plaster: Array[Transform3D] = []
	var plaster_tones: Array[Color] = []
	var wood: Array[Transform3D] = []
	var wood_tones: Array[Color] = []
	var max_houses: int = int(PROFILES[profile].houses)
	for i: int in mini(max_houses,houses.size()):
		var house: Node3D = houses[i]
		var family := _family(str(house.name))
		var shape: Dictionary = HOUSE_FRONT[family]
		var seed := absi(str(house.name).hash())
		var house_to_city: Transform3D = city.global_transform.affine_inverse()*house.global_transform
		var half_width := float(shape.width)*0.5
		var facade_depth := float(shape.depth)*0.5+0.24
		# Brick quoins visibly differ in hue, erosion pattern and spacing.
		# They stay on exterior corner masonry, away from open doorways.
		for side in [-1.0,1.0]:
			for row in 5:
				if (seed+row*7+int(side*13))%11 == 0:
					continue
				var shift := 0.04 if row%2==0 else -0.06
				_add(brick,brick_tones,house_to_city,
					Vector3(side*(half_width-0.28+shift),0.58+float(row)*0.50,facade_depth),
					Vector3(0.38,0.19,0.105),
					THEMES[(seed+row+i)%THEMES.size()])
		# Flaked limewash reads as rough historic repairs, not a flat wall
		# rectangle that would cover windows or an accessible doorway.
		for patch in 3:
			var xsign := -1.0 if patch%2==0 else 1.0
			_add(plaster,plaster_tones,house_to_city,
				Vector3(xsign*(half_width-1.0-float((seed+patch)%3)*0.27),
					0.85+float(patch)*0.77,facade_depth-0.01),
				Vector3(0.34+float((seed+patch)%3)*0.14,0.19+float(patch%2)*0.09,0.028),
				PLASTER[(seed+patch+i)%PLASTER.size()])
		# Timber edging and working joints are staggered per facade. Their
		# narrow silhouette is safe over existing doors and on low-end GPUs.
		for strip in 3:
			var x := -half_width+2.0+float(strip)*(half_width-2.0)
			_add(wood,wood_tones,house_to_city,
				Vector3(x,3.08+float((seed+strip)%2)*0.08,facade_depth+0.01),
				Vector3(0.90,0.10,0.12),
				Color("6e4b36") if (seed+strip)%2==0 else Color("806448"))
		report.houses += 1
	# Superficial chipped paving is under 17 mm high and has NO collision.
	# The existing overlay's physical street and the original city stay authoritative.
	var chips: Array[Transform3D] = []
	var chip_colors: Array[Color] = []
	for index in 60:
		var col := index%15
		var row := int(index/15)
		var x := -8.25+float(col)*1.13+float((index*3)%5)*0.025
		var z := 60.5+float(row)*2.35+float((index*7)%9)*0.03
		_add(chips,chip_colors,Transform3D.IDENTITY,Vector3(x,0.126,z),
			Vector3(0.12+float(index%3)*0.05,0.009,0.17+float(index%4)*0.04),
			Color("6c665a") if index%3 else Color("817a69"))
	var group := Node3D.new()
	group.name = GROUP
	group.set_meta(OWNER_META,true)
	group.set_meta("facade_source","Existing RomanCity residential meshes, no replacements")
	var limit: float = float(PROFILES[profile].distance)
	_batch(group,"BrickQuoins",brick,brick_tones,limit,0.96)
	_batch(group,"LimewashRepairs",plaster,plaster_tones,limit,0.98)
	_batch(group,"TimberJoints",wood,wood_tones,limit,0.87)
	_batch(group,"WornBasoliChips",chips,chip_colors,limit,0.98)
	if is_instance_valid(prior):
		city.remove_child(prior)
		prior.free()
	city.add_child(group)
	report.fountain_water_surfaces = FountainWater.apply(city)
	report.brick_instances = brick.size()
	report.plaster_instances = plaster.size()
	report.wood_instances = wood.size()
	report.street_instances = chips.size()
	report.ok = true
	report.status = "installed"
	return report


static func _family(node_name: String) -> String:
	for name: String in HOUSE_FRONT:
		if node_name.ends_with("_"+name):
			return name
	return ""


static func _add(transforms: Array[Transform3D],colors: Array[Color],
		anchor: Transform3D,at: Vector3,dimensions: Vector3,tone: Color) -> void:
	var detail := Transform3D(Basis.IDENTITY.scaled(dimensions),at)
	transforms.append(anchor*detail)
	colors.append(tone)


static func _batch(parent: Node3D,name: String,
		transforms: Array[Transform3D],tones: Array[Color],
		max_distance: float,roughness: float) -> void:
	var view := MultiMeshInstance3D.new()
	view.name = name
	var geometry := BoxMesh.new()
	geometry.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = roughness
	material.metallic = 0.0
	material.vertex_color_use_as_albedo = true
	geometry.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = geometry
	instances.instance_count = transforms.size()
	for index in transforms.size():
		instances.set_instance_transform(index,transforms[index])
		instances.set_instance_color(index,tones[index])
	view.multimesh = instances
	view.visibility_range_end = max_distance
	view.visibility_range_end_margin = 8.0
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
