extends Node3D
## Static settlement dressing never owns the player's building, labour or resource ledger.
const Art = preload("res://scripts/world/village_art.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Dressing = preload("res://scripts/world/village/frontier_dressing.gd")
const Settlement = preload("res://scripts/world/village/settlement_dressing.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Surfaces = preload("res://scripts/rendering/village_surfaces.gd")
var current_origin := ""
var quality := "balanced"
var frontier_details: Node3D
var settlement_details: Node3D
var house_count := 0
var worker: CharacterBody3D
var worker_figure: Node3D
var _worker_target := 0
var _worker_rest := 3.0
var _worker_blocked := false
var active := false
const WORKER_STATIONS := [Vector3(-4,0,7), Vector3(-2,0,7), Vector3(-2,0,9), Vector3(-4,0,9)]

func show_origin(id: String) -> void:
	if current_origin == id:
		return
	current_origin = id
	frontier_details = null
	settlement_details = null
	house_count = 0
	worker = null
	worker_figure = null
	_worker_target = 0
	_worker_rest = 3.0
	_worker_blocked = false
	for child in get_children():
		remove_child(child)
		child.free()
	var house: String = Origins.PEOPLES[id].house
	var places := [Vector3(-13,0,11),Vector3(-14,0,-11),Vector3(-5,0,-19),Vector3(20,0,-18)]
	if id == "italia":
		for home: Dictionary in Layout.HOMES:
			var model := _add_scene("res://assets/architecture/frontier_house.glb",home.at)
			model.name = home.id
			model.rotation.y = float(home.yaw)
			model.set_meta("household_id",home.id)
			_tint_house(model,Color(home.tint))
			_static_collision(model,"roman")
			house_count += 1
	for i in (0 if id == "italia" else places.size()):
		var path := "res://assets/landscape/%s.glb" % house
		if id == "italia":
			path = "res://assets/architecture/frontier_house.glb"
		elif id == "wa" and i != 0 and ResourceLoader.exists("res://assets/landscape/wa_house.glb"):
			path = "res://assets/landscape/wa_house.glb"
		var model := _add_scene(path,places[i])
		# Shared collision per wall profile keeps tiled roofs out of the physics broad phase.
		_static_collision(model,house if id != "italia" else "roman")
		house_count += 1
	if id == "italia":
		var atrium := _add_scene("res://assets/architecture/atrium_house.glb",Vector3(14,0,-30))
		atrium.name = "AtriumHouse"
		_static_collision(atrium,"atrium")
		var well := _add_scene("res://assets/architecture/village_well.glb",Vector3(-7,0,6))
		for i in 10:
			var a := TAU*i/10.0
			Art.box_collider(well,Vector3(.55,.80,.22),Vector3(sin(a)*.82,.40,cos(a)*.82)).rotation.y = a
		frontier_details = Dressing.new()
		frontier_details.name = "FrontierDetails"
		add_child(frontier_details)
		frontier_details.build()
		frontier_details.set_quality(quality)
		settlement_details = Settlement.new()
		settlement_details.name = "HouseholdsAndForge"
		add_child(settlement_details)
		settlement_details.build(self)
		settlement_details.set_quality(quality)
		# Household-specific furniture, hearth light and colliders (docs/35_interiors).
		var interiors: Node3D = preload("res://scripts/world/village/house_interiors.gd").new()
		interiors.name = "HouseInteriors"
		add_child(interiors)
		interiors.build(self, settlement_details)
		interiors.set_quality(quality)
	else:
		# A communal timber-lined water point for the regional encounter.
		var wood := Art.material(Color("#785538"))
		for k in 4:
			var yaw := k * PI * 0.5
			Art.box(self, Vector3(1.8,0.56,0.14), Vector3(-7+sin(yaw)*0.85,0.28,6+cos(yaw)*0.85),wood,true).rotation.y = yaw
	# The Italian farmer now belongs to the named population and can become a
	# recruit. Regional background figures retain their established model route.
	if id == "italia":
		return
	worker = CharacterBody3D.new()
	worker.name = "RegionalWorker"
	worker.collision_layer = 8
	worker.collision_mask = 1 | 2 | 4 | 8
	worker.safe_margin = .001
	worker.position = WORKER_STATIONS[0]
	add_child(worker)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = .86
	worker.add_child(collision)
	worker.rotation.y = 0.64
	worker_figure = Person.new()
	worker_figure.name = "Figure"
	worker_figure.position.y = .9
	worker.add_child(worker_figure)
	worker_figure.configure("regional_worker", id, 32)
	worker_figure.profile = quality
	worker_figure.set_process(active)


func set_active(enabled: bool) -> void:
	active = enabled
	if is_instance_valid(worker_figure):
		worker_figure.set_process(enabled)
		if not enabled:
			worker_figure.drive(0.0)


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(worker) or not is_visible_in_tree() or delta <= 0:
		return
	if _worker_rest > 0.0:
		_worker_rest = maxf(0.0, _worker_rest - delta)
		worker_figure.drive(0.0)
		if _worker_rest > .35 and not _worker_blocked:
			worker_figure.keep_working()
		elif worker_figure.clip == "work":
			worker_figure.cancel_action()
		if _worker_rest <= 0.0:
			if not _worker_blocked:
				_worker_target = (_worker_target + 1) % WORKER_STATIONS.size()
			_worker_blocked = false
		return
	var offset: Vector3 = WORKER_STATIONS[_worker_target] - worker.position
	offset.y = 0.0
	if offset.length() < .035:
		_worker_rest = 3.0
		worker_figure.drive(0.0)
		return
	var before := worker.position
	var step := offset.limit_length(1.05 * minf(delta, .1))
	var hit := worker.move_and_collide(step)
	var travel := worker.position - before
	worker_figure.drive(Vector2(travel.x, travel.z).length() / delta)
	if travel.length_squared() > .000001:
		worker.rotation.y = rotate_toward(worker.rotation.y, atan2(-travel.x, -travel.z), 3.0 * delta)
	if hit != null:
		# A player or obstacle blocks the body and the visible stride together.
		# Retry after a pause instead of walking through it or moving only skin.
		_worker_rest = .5
		_worker_blocked = true

func set_quality(profile: String) -> void:
	quality = profile
	if is_instance_valid(worker_figure):
		worker_figure.profile = profile
	if frontier_details:
		frontier_details.set_quality(profile)
	if settlement_details:
		settlement_details.set_quality(profile)
	if has_node("HouseInteriors"):
		get_node("HouseInteriors").set_quality(profile)

func _tint_house(model: Node3D, tint: Color) -> void:
	var overrides := {}
	for shape: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not shape.mesh:
			continue
		for surface in shape.mesh.get_surface_count():
			var original := shape.mesh.surface_get_material(surface) as StandardMaterial3D
			if not original or original.resource_name != "ARCH_Lime_Plaster":
				continue
			# Lime plaster with damp, cracks and trowel relief (rendering/village_surfaces.gd).
			if not overrides.has(original.get_instance_id()):
				overrides[original.get_instance_id()] = Surfaces.plaster(tint)
			shape.set_surface_override_material(surface,overrides[original.get_instance_id()])

func _add_scene(path: String,where: Vector3) -> Node3D:
	var scene: PackedScene = load(path)
	var node := scene.instantiate() as Node3D
	node.position = where
	add_child(node)
	return node

func _static_collision(model: Node3D,kind: String) -> void:
	if kind in ["roman","atrium"]:
		var x := 2.85 if kind == "roman" else 5.35
		var z := 2.35 if kind == "roman" else 4.90
		var door := 0.69 if kind == "roman" else 0.92
		for side in [-1,1]:
			Art.box_collider(model,Vector3(0.29,3.35,z*2),Vector3(x*side,1.68,0))
			Art.box_collider(model,Vector3(x-door,3.35,0.29),Vector3(side*(x+door)*0.5,1.68,z))
		Art.box_collider(model,Vector3(x*2,3.35,0.29),Vector3(0,1.68,-z))
		# These meshes contain raised floors. Wall-only collision left the
		# player's capsule on the landscape, burying both legs in the paving.
		if kind == "roman":
			var floor_body := Art.box_collider(model, Vector3(5.28,Layout.HOUSE_FLOOR,4.26),Vector3(0,Layout.HOUSE_FLOOR*.5,0))
			floor_body.name = "WalkableFloor"
			floor_body.set_meta("surface_height",Layout.HOUSE_FLOOR)
			_house_entry(model)
			# The imported table and wall bench are already visible geometry.
			Art.box_collider(model,Vector3(1.45,.86,1.10),Vector3(-1.1,Layout.HOUSE_FLOOR+.43,-.61)).name = "TableCollision"
			Art.box_collider(model,Vector3(.5,.52,1.9),Vector3(1.93,Layout.HOUSE_FLOOR+.26,0)).name = "BenchCollision"
			var door_angle := deg_to_rad(100)
			var leaf_center := Vector3(-.575,.415+1.04,2.15)+Vector3(.56,0,0).rotated(Vector3.UP,door_angle)
			var leaf := Art.box_collider(model,Vector3(1.12,2.08,.085),leaf_center)
			leaf.name = "OpenDoorLeafCollision"
			leaf.rotation.y = door_angle
		if kind == "atrium":
			var floor_body := Art.box_collider(model,Vector3(10.4,.065,9.7),Vector3(0,.0325,0))
			floor_body.name = "WalkableFloor"
			floor_body.set_meta("surface_height",.065)
			Art.box_collider(model,Vector3(1.83,.113,.60),Vector3(0,.0565,4.98)).name = "ThresholdCollision"
			var ramp_pitch := atan2(.113,.70)
			var ramp := Art.box(model,Vector3(1.68,.04,Vector2(.70,.113).length()),Vector3(0,.0565-.02*cos(ramp_pitch),5.62-.02*sin(ramp_pitch)),Art.material(Color("aaa38f")),true)
			ramp.name = "AtriumEntryRamp"
			ramp.rotation.x = ramp_pitch
			# The catch basin and rear furniture remain obstacles; the central
			# water surface is not an invisible walk-through shortcut.
			Art.box_collider(model,Vector3(3.26,.247,3.73),Vector3(0,.1235,0)).name = "BasinCollision"
			Art.box_collider(model,Vector3(1.94,.554,.56),Vector3(-3.13,.277,-4.09)).name = "BenchCollision"
			# The open door leaves lie against the side walls of the entrance passage.
			for side in [-1, 1]:
				Art.box_collider(model, Vector3(0.20, 2.65, 2.10), Vector3(side * 1.03, 1.325, 3.7))
				for end in [-1, 1]:
					Art.box_collider(model, Vector3(0.42, 3.02, 0.42), Vector3(side * 2.0, 1.51, end * 2.15))
		return
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D:
		meshes.append(model)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh != null:
			mesh.create_trimesh_collision()


func _house_entry(model: Node3D) -> void:
	# A visible oak board ramp bridges the two stone steps. Its top and its
	# collision share one transform, so walking does not need a height cheat.
	var entry := Node3D.new()
	entry.name = "WalkableEntrance"
	model.add_child(entry)
	var wood := Art.material(Color("8b795c"),.94)
	var landing := Art.box(entry,Vector3(1.25,.06,.90),Vector3(0,.415,2.50),wood,true)
	landing.name = "ThresholdLanding"
	var run := 1.05
	var rise := .445
	var pitch := atan2(rise,run)
	var ramp := Art.box(entry,Vector3(1.25,.06,Vector2(run,rise).length()),Vector3(0,rise*.5-.03*cos(pitch),3.475-.03*sin(pitch)),wood,true)
	ramp.name = "EntryRamp"
	ramp.rotation.x = pitch
	for side in [-1.0,1.0]:
		var strip := Art.box(entry,Vector3(.025,.018,Vector2(run,rise).length()),ramp.position+Vector3(side*.39,.04,0),wood)
		strip.rotation.x = pitch
