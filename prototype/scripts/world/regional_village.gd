extends Node3D
## Static settlement dressing never owns the player's building, labour or resource ledger.
const Art = preload("res://scripts/world/village_art.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Dressing = preload("res://scripts/world/village/frontier_dressing.gd")
var current_origin := ""
var quality := "balanced"
var frontier_details: Node3D
var house_count := 0

func show_origin(id: String) -> void:
	if current_origin == id:
		return
	current_origin = id
	frontier_details = null
	house_count = 0
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
		_static_collision(_add_scene("res://assets/architecture/atrium_house.glb",Vector3(14,0,-30)),"atrium")
		var well := _add_scene("res://assets/architecture/village_well.glb",Vector3(-7,0,6))
		for i in 10:
			var a := TAU*i/10.0
			Art.box_collider(well,Vector3(.55,.80,.22),Vector3(sin(a)*.82,.40,cos(a)*.82)).rotation.y = a
		frontier_details = Dressing.new()
		frontier_details.name = "FrontierDetails"
		add_child(frontier_details)
		frontier_details.build()
		frontier_details.set_quality(quality)
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
	var farmer_path := "res://assets/landscape/farmer.glb"
	if id in ["wa","han"] and ResourceLoader.exists("res://assets/landscape/%s_farmer.glb" % id):
		farmer_path = "res://assets/landscape/%s_farmer.glb" % id
	var worker := _add_scene(farmer_path,Vector3(-4,0,7))
	worker.rotation.y = 0.64
	for player: AnimationPlayer in worker.find_children("*","AnimationPlayer",true,false):
		if player.has_animation("idle"):
			player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			player.play("idle")

func set_quality(profile: String) -> void:
	quality = profile
	if frontier_details:
		frontier_details.set_quality(profile)

func _tint_house(model: Node3D, tint: Color) -> void:
	var overrides := {}
	for shape: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not shape.mesh:
			continue
		for surface in shape.mesh.get_surface_count():
			var original := shape.mesh.surface_get_material(surface) as StandardMaterial3D
			if not original or original.resource_name != "ARCH_Lime_Plaster":
				continue
			if not overrides.has(original.get_instance_id()):
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color = tint
				overrides[original.get_instance_id()] = material
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
		if kind == "atrium":
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
