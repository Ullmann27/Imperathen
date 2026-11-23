extends Node3D
## Original civic details around the existing authored architecture, in metres.

const Art = preload("res://scripts/world/village_art.gd")
var _detail_nodes: Array[Node3D] = []
var _wagon_axle: MeshInstance3D
var _materials: Dictionary = {}

func build() -> void:
	if not _materials.is_empty():
		return
	_materials = {
		"wood":Art.material(Color("#62503a")),
		"cut":Art.material(Color("#a2855d")),
		"iron":Art.material(Color("#333b39"),.42),
		"clay":Art.material(Color("#ac7254"),.86),
		"linen":Art.material(Color("#c8b888")),
		"stone":Art.material(Color("#acaa95")),
		"green":Art.material(Color("#6e7845")),
		"soil":Art.material(Color("#554535")),
		"chalk":Art.material(Color("#e4d7b6")),
	}
	_materials.iron.metallic = .65
	_make_wagon(Vector3(7.4,0,24))
	_make_scribe_desk(Vector3(15.7,0,-23.3))
	_make_market(Vector3(34,0,18))
	_make_pottery(Vector3(-14,0,-24))
	_make_bench(Vector3(5.2,0,-27.3),PI/2)
	_make_bench(Vector3(-10,0,-35.1),0)
	_make_milestone(Vector3(-2.9,0,26.8))
	for index in 4:
		_make_garden(Vector3(43.5,0,-37+index*14),index)
	_make_laundry(Vector3(35,0,-17.1))
	_make_laundry(Vector3(-14,0,-34.2))

func set_quality(profile: String) -> void:
	var range_end := float({"low":24,"balanced":42,"high":65,"very_high":90}.get(profile,42))
	for root: Node3D in _detail_nodes:
		for item: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			item.visibility_range_end = range_end
			item.visibility_range_end_margin = 3

func set_wagon_progress(progress: float) -> void:
	if _wagon_axle:
		_wagon_axle.material_override = _materials.wood if progress >= 1.0 else _materials.cut

func _group(label_text: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label_text
	node.position = at
	add_child(node)
	return node

func _make_wagon(at: Vector3) -> void:
	var wagon := _group("SupplyWagon",at)
	for index in 10:
		Art.box(wagon,Vector3(2.15,.085,.31),Vector3(0,.91,-1.4+index*.31),_materials.wood)
	for x in [-1.05,1.05]:
		for z in [-1.45,0,1.45]:
			Art.box(wagon,Vector3(.095,.76,.10),Vector3(x,1.22,z),_materials.cut)
		for level in 3:
			Art.box(wagon,Vector3(.075,.17,3.0),Vector3(x,1.06+level*.20,0),_materials.wood)
	for z in [-1.10,1.10]:
		var axle := Art.box(wagon,Vector3(2.74,.12,.12),Vector3(0,.62,z),_materials.cut)
		if z < 0:
			_wagon_axle = axle
		for side in [-1,1]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side*1.30,.62,z)
			wheel.rotation.z = PI/2
			wagon.add_child(wheel)
			var rim := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = .49
			ring.outer_radius = .61
			ring.rings = 16
			ring.ring_segments = 6
			rim.mesh = ring
			rim.material_override = _materials.wood
			wheel.add_child(rim)
			Art.cylinder(wheel,.15,.22,Vector3.ZERO,_materials.iron,.12)
			for index in 6:
				var spoke := Art.box(wheel,Vector3(1.03,.06,.05),Vector3.ZERO,_materials.cut)
				spoke.rotation.y = index*PI/6
	for x in [-.68,.68]:
		Art.box(wagon,Vector3(.095,.10,2.8),Vector3(x,.72,2.60),_materials.wood)
	for index in 4:
		Art.sphere(wagon,.36,Vector3(-.52+float(index%2)*.9,1.20,-.87+floori(index/2)*.9),_materials.linen,Vector3(.8,1.25,1))
	Art.box_collider(wagon,Vector3(2.3,1.62,3.2),Vector3(0,.81,0))
	# Shafts are visible and collide below knee height rather than forming an invisible wall.
	for x in [-.68,.68]:
		Art.box_collider(wagon,Vector3(.13,.12,2.8),Vector3(x,.72,2.60))

func _make_scribe_desk(at: Vector3) -> void:
	var desk := _group("ScribeDesk",at)
	Art.box(desk,Vector3(1.5,.09,.76),Vector3(0,.89,0),_materials.wood,true)
	for x in [-.63,.63]:
		for z in [-.27,.27]:
			Art.box(desk,Vector3(.075,.85,.075),Vector3(x,.42,z),_materials.cut)
	for index in 4:
		var scroll := Art.cylinder(desk,.052,.44,Vector3(-.46+index*.24,.99,.12),_materials.chalk)
		scroll.rotation.z = PI/2
	Art.box(desk,Vector3(.33,.035,.28),Vector3(.35,.96,-.13),_materials.cut)
	Art.box(desk,Vector3(.27,.012,.23),Vector3(.35,.986,-.13),_materials.iron)
	_detail_nodes.append(desk)

func _make_market(at: Vector3) -> void:
	var market := preload("res://assets/village/market.glb").instantiate() as Node3D
	market.name = "EasternClothMarket"
	market.position = at
	market.rotation.y = PI/2
	add_child(market)
	Art.box_collider(market,Vector3(3,.16,1.2),Vector3(0,.85,0))
	var crates := _group("MerchantBundles",at+Vector3(0,0,2.3))
	for index in 3:
		var paint := Art.material([Color("#866b4a"),Color("#7a8b84"),Color("#a87b65")][index])
		Art.box(crates,Vector3(.75,.24,.6),Vector3(0,.14+index*.24,0),paint)
	_detail_nodes.append(crates)

func _make_pottery(at: Vector3) -> void:
	var pots := _group("PotteryCourtyard",at)
	for index in 6:
		var local := Vector3(float(index%3)*.57,.04,floori(index/3)*.55)
		var body := Art.sphere(pots,.22,local+Vector3.UP*.28,_materials.clay,Vector3(1,1.40,1))
		body.name = "Pot%d" % index
		Art.cylinder(pots,.11,.17,local+Vector3.UP*.58,_materials.clay,.075)
		Art.cylinder(pots,.078,.011,local+Vector3.UP*.67,_materials.soil)
	_detail_nodes.append(pots)

func _make_bench(at: Vector3, yaw: float) -> void:
	var bench := _group("RestBench",at)
	bench.rotation.y = yaw
	Art.box(bench,Vector3(1.9,.13,.48),Vector3(0,.46,0),_materials.wood,true)
	for x in [-.72,.72]:
		Art.box(bench,Vector3(.16,.43,.38),Vector3(x,.215,0),_materials.cut)
	_detail_nodes.append(bench)

func _make_milestone(at: Vector3) -> void:
	var stone := _group("SouthernRoadMarker",at)
	Art.cylinder(stone,.27,1.3,Vector3(0,.65,0),_materials.stone,.24,true)
	var plaque := Art.label(stone,"VIA\nAD MERIDIEM",Vector3(0,.94,.255),Color("#4b4639"),25)
	plaque.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plaque.outline_size = 0
	plaque.pixel_size = .003
	plaque.rotation.y = 0

func _make_garden(at: Vector3, index: int) -> void:
	var patch := _group("KitchenGarden%d" % index,at)
	Art.box(patch,Vector3(3.5,.04,4.6),Vector3(0,.016,0),_materials.soil)
	for side in [-1,1]:
		Art.box(patch,Vector3(.10,.12,4.8),Vector3(side*1.80,.07,0),_materials.wood)
		Art.box(patch,Vector3(3.7,.12,.10),Vector3(0,.07,side*2.35),_materials.wood)
	for row in 5:
		for column in 4:
			var plant := Art.sphere(patch,.20,Vector3(-1.27+column*.84,.17,-1.88+row*.91),_materials.green,Vector3(1,.62,1))
			plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_detail_nodes.append(patch)

func _make_laundry(at: Vector3) -> void:
	var line := _group("DryingLinen",at)
	for x in [-1.2,1.2]:
		Art.cylinder(line,.055,1.9,Vector3(x,.95,0),_materials.wood)
	Art.box(line,Vector3(2.5,.024,.024),Vector3(0,1.8,0),_materials.wood)
	for index in 3:
		var fabric := PlaneMesh.new()
		fabric.size = Vector2(.60,.80+index*.09)
		fabric.subdivide_width = 4
		fabric.subdivide_depth = 6
		var mesh := MeshInstance3D.new()
		mesh.mesh = fabric
		mesh.position = Vector3(-.78+index*.77,1.34,0)
		mesh.rotation.x = PI/2
		var cloth := _materials.linen.duplicate() as StandardMaterial3D
		cloth.albedo_color = [Color("#bcaa83"),Color("#8b9d9c"),Color("#c5b395")][index]
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = cloth
		line.add_child(mesh)
	_detail_nodes.append(line)
