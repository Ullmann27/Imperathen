extends SceneTree
## Actual collision shapes, entrance walking and personal-space sweeps.
## These are headless physics checks, not a device performance measurement.

const Regional = preload("res://scripts/world/regional_village.gd")
const Population = preload("res://scripts/world/village/village_population.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Art = preload("res://scripts/world/village_art.gd")
var failures: Array[String] = []
var checks := 0
var stage: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	Art.box_collider(stage,Vector3(300,.5,150),Vector3(30,-.26,0))
	var region := Regional.new()
	stage.add_child(region)
	region.show_origin("italia")
	var population := Population.new()
	stage.add_child(population)
	population.show_origin("italia",0.0,0)
	population.set_active(true)
	await physics_frame
	await physics_frame
	_check(region.house_count == 20,"Twenty authored households exist as actual scene instances")
	_check(population.actors.size() == 26,"Twenty-six ambient residents have unique bodies")
	_check(region.has_node("HouseholdsAndForge/VillageForge/Anvil"),"The smith's anvil is live geometry")
	_check(region.has_node("baker_home/FamilyHome/DrinkingCup"),"The family home contains a drinking cup")
	for home: Dictionary in Layout.HOMES:
		var building := region.get_node(NodePath(home.id)) as Node3D
		var probe := building.to_global(Vector3(.35,0,.35))
		var ray := PhysicsRayQueryParameters3D.create(probe+Vector3.UP*2,probe-Vector3.UP,1)
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty(),"A real floor supports "+home.id)
		if not hit.is_empty():
			_check(absf(float(hit.position.y)-Layout.HOUSE_FLOOR)<.015,"Floor matches the authored flagstones in "+home.id)
		for other: Dictionary in Layout.HOMES:
			if str(home.id)<str(other.id):
				_check(not Layout.house_footprint(home,.12).intersects(Layout.house_footprint(other,.12)),"House footprints remain separated: %s/%s" % [home.id,other.id])
	await _walk_into(region.get_node("baker_home"))
	await _walk_into(region.get_node("smith_home"))
	await _walk_into(region.get_node("AtriumHouse"),6.2,3.0,.065)
	await _test_people(population)
	# Physics-query the entire authored walking corridors, including intermediate
	# positions. Checking only waypoints would miss a wall between two points.
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Layout.CITIZEN_RADIUS
	capsule.height = 1.70
	query.shape = capsule
	query.collision_mask = 1
	query.margin = .012
	for person: Dictionary in Layout.RESIDENTS:
		var path: Array[Vector3] = [person.at]
		for point: Vector3 in person.route:
			path.append(point)
		for edge in maxi(1,path.size()-1):
			var start := path[edge]
			var finish := path[mini(edge+1,path.size()-1)]
			var samples := maxi(1,ceili(start.distance_to(finish)/.35))
			for sample in samples+1:
				var point := start.lerp(finish,float(sample)/samples)
				query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*1.02)
				_check(stage.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Clear house/forge route for %s at %s" % [person.id,point])
	stage.free()
	await process_frame
	print("SETTLEMENT_GEOMETRY_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for message: String in failures:
		printerr("FAIL: "+message)
	print("SETTLEMENT_GEOMETRY_PASS" if failures.is_empty() else "SETTLEMENT_GEOMETRY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _body(at: Vector3, layer: int, mask: int) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.position = at
	actor.collision_layer = layer
	actor.collision_mask = mask
	actor.floor_snap_length = .25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	shape.shape = capsule
	actor.add_child(shape)
	stage.add_child(actor)
	return actor


func _walk_into(home: Node3D, start_z := 4.6, destination_z := .85, floor_height := Layout.HOUSE_FLOOR) -> void:
	var actor := _body(home.to_global(Vector3(0,1,start_z)),2,1|Layout.CITIZEN_LAYER)
	var direction := -home.global_basis.z
	for frame in 180:
		await physics_frame
		actor.velocity.x = direction.x*1.6
		actor.velocity.z = direction.z*1.6
		actor.velocity.y = -.3 if actor.is_on_floor() else actor.velocity.y-19.6/60.0
		actor.move_and_slide()
		if home.to_local(actor.global_position).z < destination_z:
			break
	var local := home.to_local(actor.global_position)
	_check(local.z < destination_z+.1,"A real capsule walks over the doorstep into "+home.name)
	for frame in 18:
		await physics_frame
		actor.velocity = Vector3(0,-.3 if actor.is_on_floor() else actor.velocity.y-19.6/60.0,0)
		actor.move_and_slide()
	_check(absf(actor.global_position.y-.9-floor_height)<.025,"Feet rest on paving, not below it, in "+home.name)
	for frame in 90:
		await physics_frame
		actor.velocity = home.global_basis.x*2.0+Vector3.DOWN*.3
		actor.move_and_slide()
	_check(home.to_local(actor.global_position).x < 2.45,"The same capsule cannot walk through the house wall")
	actor.free()
	await physics_frame


func _test_people(population: Node3D) -> void:
	var first: CharacterBody3D = population.actors.livia
	var second: CharacterBody3D = population.actors.cassian
	first.position = Vector3(100,0,0)
	second.position = Vector3(102,0,0)
	await physics_frame
	for step in 24:
		first.move_and_collide(Vector3(.08,0,0))
		second.move_and_collide(Vector3(-.08,0,0))
		await physics_frame
	_check(first.global_position.distance_to(second.global_position)>=Layout.CITIZEN_RADIUS*2-.012,"Opposing resident bodies do not pass through each other")
	_check(first.global_position.x < second.global_position.x,"Opposing residents preserve their physical ordering")
	var player := _body(Vector3(100,.9,2),2,1|Layout.CITIZEN_LAYER)
	first.position = Vector3(101,0,2)
	await physics_frame
	player.move_and_collide(Vector3(2,0,0))
	_check(player.position.x < first.position.x-.54,"Player sweep is stopped by a resident body")
	player.free()
	population.advance_to(0,true)
	await physics_frame
	for index in 90:
		population.advance_to((index+1)*.10)
		await physics_frame
	var actors: Array = population.actors.values()
	for i in actors.size():
		_check(actors[i].collision_layer == Layout.CITIZEN_LAYER,"An unrecruited resident keeps solid personal space")
		for j in range(i+1,actors.size()):
			_check(actors[i].position.distance_to(actors[j].position)>=Layout.CITIZEN_RADIUS*2-.025,"Routines avoid intersecting residents: %s/%s" % [actors[i].name,actors[j].name])
	population.set_recruited(1)
	_check(population.actors.marius.collision_layer == 0,"A recruited civilian leaves no invisible blocking body")
