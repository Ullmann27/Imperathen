extends Node3D
## Original reusable household and craft props. No ledger or story side effects.

const Art = preload("res://scripts/world/village_art.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var _materials: Dictionary = {}
var _groups: Array[Node3D] = []
var _jar_mesh: ArrayMesh
var _cup_mesh: ArrayMesh
var _ember: MeshInstance3D
var _interactive: Array[Node] = []


func build(houses: Node3D) -> void:
	if not _materials.is_empty():
		return
	_materials = {
		"wood":Art.material(Color("74614a")), "cut":Art.material(Color("a48b62")),
		"clay":Art.material(Color("a56343")), "light_clay":Art.material(Color("c18b5e")),
		"stone":Art.material(Color("85867c")), "dark_stone":Art.material(Color("514f46")),
		"linen":Art.material(Color("c8b88d")), "red_cloth":Art.material(Color("8e5140")),
		"straw":Art.material(Color("a79558")), "iron":Art.material(Color("363b3b"),.48),
		"water":Art.material(Color("344b48"),.18), "leaf":Art.material(Color("6c7945")),
		"grain":Art.material(Color("b3a169")), "coal":Art.material(Color("242526")),
		"ember":Art.material(Color("b74724")), "bread":Art.material(Color("b68b4f")),
	}
	_materials.iron.metallic = .68
	_materials.ember.emission_enabled = true
	_materials.ember.emission = Color("d35e27")
	_materials.ember.emission_energy_multiplier = .6
	_jar_mesh = _vessel_mesh([Vector2(.15,0),Vector2(.25,.12),Vector2(.31,.36),Vector2(.24,.57),Vector2(.12,.65),Vector2(.115,.76),Vector2(.14,.77),Vector2(.14,.81),Vector2(.095,.81),Vector2(.095,.72),Vector2(.08,.66)])
	_cup_mesh = _vessel_mesh([Vector2(.07,0),Vector2(.075,.02),Vector2(.095,.13),Vector2(.105,.15),Vector2(.083,.15),Vector2(.071,.035)])
	for index in Layout.HOMES.size():
		var home: Dictionary = Layout.HOMES[index]
		var building := houses.get_node(NodePath(home.id)) as Node3D
		_furnish(building,home.id,index)
	_make_forge()
	_make_market_goods()
	_make_watering_place()
	_make_gardens()
	for group: Node3D in _groups:
		Art.batch_static(group,_interactive)


func set_quality(profile: String) -> void:
	var distance := float({"low":24,"balanced":38,"high":56,"very_high":72}.get(profile,38))
	for group: Node3D in _groups:
		for mesh: GeometryInstance3D in group.find_children("*","GeometryInstance3D",true,false):
			mesh.visibility_range_end = distance
			mesh.visibility_range_end_margin = 2.5


func _group(parent: Node3D, title: String, at := Vector3.ZERO) -> Node3D:
	var group := Node3D.new()
	group.name = title
	group.position = at
	parent.add_child(group)
	_groups.append(group)
	return group


func _furnish(house: Node3D, id: String, index: int) -> void:
	var room := _group(house,"Household",Vector3(0,Layout.HOUSE_FLOOR,0))
	room.set_meta("household_id",id)
	# The door axis and the standing spaces beside bed/bench stay clear.
	var bed := _group(room,"SleepingPlace",Vector3(.65,0,-1.65))
	Art.box(bed,Vector3(2.05,.12,.91),Vector3(0,.24,0),_materials.wood)
	Art.box(bed,Vector3(1.95,.15,.83),Vector3(0,.37,0),_materials.straw)
	Art.box(bed,Vector3(1.30,.045,.85),Vector3(.28,.467,0),_materials.red_cloth if index%3==0 else _materials.linen)
	Art.box(bed,Vector3(.42,.12,.70),Vector3(-.70,.49,0),_materials.linen)
	for x in [-.86,.86]:
		for z in [-.32,.32]:
			Art.box(bed,Vector3(.09,.30,.09),Vector3(x,.15,z),_materials.wood)
	Art.box_collider(bed,Vector3(2.05,.46,.91),Vector3(0,.23,0))
	var shelf := _group(room,"HouseholdShelf",Vector3(-2.32,0,1.05))
	for height in [.48,1.04]:
		Art.box(shelf,Vector3(.45,.065,1.15),Vector3(0,height,0),_materials.wood)
	for z in [-.49,.49]:
		Art.box(shelf,Vector3(.07,1.13,.07),Vector3(0,.565,z),_materials.wood)
	_jar(shelf,Vector3(0,.52,-.28),.52,index%2==0)
	_jar(shelf,Vector3(0,.52,.26),.44,false)
	_cup(shelf,Vector3(0,1.08,-.24))
	_cup(shelf,Vector3(0,1.08,.20))
	Art.box_collider(shelf,Vector3(.5,1.15,1.2),Vector3(0,.575,0))
	# Use the imported table and wall bench rather than placing a second table.
	_jar(room,Vector3(-1.52,.865,-.62),.48,true)
	_cup(room,Vector3(-.72,.865,-.29))
	_cup(room,Vector3(-.98,.865,-.88))
	Art.sphere(room,.17,Vector3(-1.15,.895,-.40),_materials.bread,Vector3(1.3,.32,.85))
	var jug := _jar(room,Vector3(1.93,.515,.18),.55,false)
	jug.name = "DrinkingJug"
	var cup := _cup(room,Vector3(1.93,.515,-.38))
	cup.name = "DrinkingCup"
	if id == "baker_home":
		_interactive.append(jug)
		_interactive.append(cup)
	var stool := _group(room,"Stool",Vector3(-1.45,0,1.32))
	Art.cylinder(stool,.27,.08,Vector3(0,.43,0),_materials.cut)
	for angle in [0.0,TAU/3,TAU*2/3]:
		Art.cylinder(stool,.04,.41,Vector3(cos(angle)*.18,.205,sin(angle)*.18),_materials.wood)
	Art.box_collider(stool,Vector3(.54,.47,.54),Vector3(0,.235,0))
	var yard := _group(house,"DoorstepSupplies")
	_jar(yard,Vector3(-1.90,0,2.98),.90,index%2==0)
	_jar(yard,Vector3(-2.35,0,2.80),.65,false)
	# Chopped wood is piled beside the door, outside the walking ramp.
	for row in 2:
		for column in 3-row:
			var log := Art.cylinder(yard,.075,.68,Vector3(2.17+(column-1)*.16,.10+row*.15,2.68),_materials.wood,.07)
			log.rotation.x = PI/2
	if id == "baker_home":
		room.name = "FamilyHome"
		room.set_meta("rest_anchor",Vector3(-12.05,Layout.HOUSE_FLOOR,10.55))
		room.set_meta("drink_anchor",Vector3(-12,Layout.HOUSE_FLOOR,11.7))


func _make_forge() -> void:
	var forge := _group(self,"VillageForge",Vector3(34.1,0,-26.2))
	forge.set_meta("smith_anchor",Vector3(32.8,0,-25.0))
	# A lean-to faces the street; its posts leave the approach and all work
	# stations clear. The shelter stays on the house side of the public lane.
	for z in [-3.15,3.0]:
		for x in [-.10,1.25]:
			Art.box(forge,Vector3(.12,2.55,.12),Vector3(x,1.275,z),_materials.wood,true)
	var cover := Art.box(forge,Vector3(2.45,.13,6.6),Vector3(.45,2.65,-.05),_materials.wood)
	cover.rotation.z = -.08
	for z in [-2.6,-1.3,0,1.3,2.6]:
		Art.box(forge,Vector3(2.6,.12,.10),Vector3(.45,2.54,z),_materials.cut)
	var hearth := _group(forge,"Hearth",Vector3(.05,0,-2.85))
	Art.box(hearth,Vector3(1.18,.72,.85),Vector3(0,.36,0),_materials.dark_stone,true)
	for side in [-1,1]:
		Art.box(hearth,Vector3(.16,.43,.90),Vector3(side*.53,.935,0),_materials.stone)
	Art.box(hearth,Vector3(1.14,.43,.16),Vector3(0,.935,-.37),_materials.stone)
	Art.box(hearth,Vector3(.65,1.8,.44),Vector3(.24,1.6,-.27),_materials.dark_stone)
	_ember = Art.box(hearth,Vector3(.70,.035,.48),Vector3(0,.75,0),_materials.ember)
	for index in 7:
		Art.sphere(hearth,.09,Vector3(-.28+(index%4)*.18,.80,-.12+floori(index/4)*.23),_materials.coal,Vector3(1.1,.55,.8))
	var bellows := _group(forge,"Bellows",Vector3(-.12,0,-1.95))
	Art.box(bellows,Vector3(.95,.16,.47),Vector3(0,.68,0),_materials.wood)
	Art.sphere(bellows,.29,Vector3(0,.80,0),_materials.red_cloth,Vector3(1.55,.38,.75))
	Art.box(bellows,Vector3(.95,.06,.47),Vector3(0,.91,0),_materials.cut)
	Art.box(bellows,Vector3(.08,.05,.50),Vector3(-.35,1.02,0),_materials.wood).rotation.z = -.18
	Art.box_collider(bellows,Vector3(1.05,1.06,.56),Vector3(0,.53,0))
	var anvil := _group(forge,"Anvil",Vector3(0,0,1.0))
	Art.cylinder(anvil,.32,.53,Vector3(0,.265,0),_materials.wood)
	Art.box(anvil,Vector3(.58,.14,.34),Vector3(0,.59,0),_materials.iron)
	Art.box(anvil,Vector3(.25,.20,.24),Vector3(0,.75,0),_materials.iron)
	Art.box(anvil,Vector3(.76,.12,.36),Vector3(0,.91,0),_materials.iron)
	var horn := Art.cylinder(anvil,.13,.45,Vector3(-.50,.91,0),_materials.iron,0)
	horn.rotation.z = PI/2
	Art.box_collider(anvil,Vector3(1.15,.97,.68),Vector3(-.16,.485,0))
	# Tongs, hammer and unfinished tools have readable silhouettes on a rack.
	var rack := _group(forge,"ToolRack",Vector3(.94,0,1.45))
	Art.box(rack,Vector3(.08,1.65,1.24),Vector3(0,.825,0),_materials.wood)
	for index in 4:
		var z := -.43+index*.27
		Art.box(rack,Vector3(.055,.58,.055),Vector3(-.12,1.11,z),_materials.cut)
		Art.box(rack,Vector3(.20,.10,.16),Vector3(-.12,1.42,z),_materials.iron)
	var tub := _group(forge,"QuenchTrough",Vector3(.10,0,2.40))
	for side in [-1,1]:
		Art.box(tub,Vector3(.10,.57,.90),Vector3(side*.39,.285,0),_materials.wood)
		Art.box(tub,Vector3(.72,.57,.09),Vector3(0,.285,side*.42),_materials.wood)
	Art.box(tub,Vector3(.70,.045,.76),Vector3(0,.44,0),_materials.water)
	Art.box_collider(tub,Vector3(.88,.59,.9),Vector3(0,.295,0))
	for z in [1.2,1.45,1.7]:
		var bar := Art.box(forge,Vector3(.055,.055,1.1),Vector3(.75,.10,z),_materials.iron)
		bar.rotation.y = .2


func _make_market_goods() -> void:
	var market := _group(self,"MarketDeliveries",Vector3(25,0,24))
	# The existing trading shelter supplies the table and roof. These goods
	# distinguish it from the working forge without occupying customer space.
	for index in 5:
		_jar(market,Vector3(-1.18+index*.55,.94,.10),.34,index%2==0)
	for index in 3:
		var sack := Art.sphere(market,.32,Vector3(-1.55+index*.5,.33,-.87),_materials.linen,Vector3(.73,1.0,.86))
		sack.rotation.z = -.12+index*.1
		Art.cylinder(market,.09,.08,Vector3(-1.55+index*.5,.64,-.87),_materials.straw)
	var crate := _group(market,"VegetableCrate",Vector3(1.20,0,-.65))
	Art.box(crate,Vector3(.67,.31,.65),Vector3(0,.155,0),_materials.wood)
	for index in 6:
		Art.sphere(crate,.10,Vector3(-.18+(index%3)*.18,.36,-.12+floori(index/3)*.23),_materials.leaf,Vector3(1,.8,1))
	var pennant := Art.box(market,Vector3(1.1,.48,.035),Vector3(0,1.84,1.36),_materials.red_cloth)
	pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_watering_place() -> void:
	var point := _group(self,"StreetWater",Vector3(33,0,1.4))
	for x in [-.58,.58]:
		Art.box(point,Vector3(.16,.54,1.55),Vector3(x,.27,0),_materials.stone)
	for z in [-.70,.70]:
		Art.box(point,Vector3(1.08,.54,.16),Vector3(0,.27,z),_materials.stone)
	Art.box(point,Vector3(1.0,.025,1.25),Vector3(0,.39,0),_materials.water)
	Art.box_collider(point,Vector3(1.32,.54,1.58),Vector3(0,.27,0))
	_jar(point,Vector3(.95,0,.40),.82,false)
	_cup(point,Vector3(.58,.55,0))


func _make_gardens() -> void:
	for row in 2:
		var patch := _group(self,"KitchenGarden_%d" % row,Vector3(-19.65,0,-31-row*8))
		Art.box(patch,Vector3(1.15,.035,4.0),Vector3(0,.01,0),_materials.dark_stone)
		for i in 8:
			for side in [-1,1]:
				var plant := Art.sphere(patch,.16,Vector3(side*.26,.15,-1.65+i*.46),_materials.leaf,Vector3(1,.58,1))
				plant.rotation.y = i*.73
		for end in [-1,1]:
			Art.box(patch,Vector3(1.27,.10,.07),Vector3(0,.09,end*2.0),_materials.wood)


func _jar(parent: Node3D, at: Vector3, size: float, lighter: bool) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = _jar_mesh
	item.material_override = _materials.light_clay if lighter else _materials.clay
	item.position = at
	item.scale = Vector3.ONE*size
	parent.add_child(item)
	return item


func _cup(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = _cup_mesh
	item.material_override = _materials.clay
	item.position = at
	parent.add_child(item)
	return item


func _vessel_mesh(profile: Array[Vector2]) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 12
	for row in profile.size()-1:
		for index in SEGMENTS:
			var a := TAU*index/SEGMENTS
			var b := TAU*(index+1)/SEGMENTS
			var low: Vector2 = profile[row]
			var high: Vector2 = profile[row+1]
			var points := [Vector3(cos(a)*low.x,low.y,sin(a)*low.x),Vector3(cos(b)*low.x,low.y,sin(b)*low.x),Vector3(cos(b)*high.x,high.y,sin(b)*high.x),Vector3(cos(a)*high.x,high.y,sin(a)*high.x)]
			for corner in [0,2,1,0,3,2]:
				mesh.add_vertex(points[corner])
	mesh.generate_normals()
	return mesh.commit()
