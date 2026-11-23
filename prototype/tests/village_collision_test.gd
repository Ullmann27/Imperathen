extends SceneTree
## Full production world: palisades, saved work slots and real child capsule.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	await physics_frame
	await physics_frame
	var old_wall := world.get_node("FrontierVillage/InnerLegacyPalisade") as Node3D
	_check(not old_wall.visible,"The obsolete inner wall does not cut through the inhabited settlement")
	for body: StaticBody3D in old_wall.find_children("*","StaticBody3D",true,false):
		_check(body.collision_layer == 0,"Hidden inner palisade does not retain an invisible collider")
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Layout.CITIZEN_RADIUS
	capsule.height = 1.70
	query.shape = capsule
	query.collision_mask = 1
	query.margin = .01
	var space := world.get_world_3d().direct_space_state
	var positions: Array[Vector3] = []
	for id: String in world.village_life_world.actors:
		var actor: StaticBody3D = world.village_life_world.actors[id]
		var canonical := Life.actor_position(model.data,id)
		_check(Vector2(actor.position.x,actor.position.z).is_equal_approx(canonical),"Visible and authoritative position agree for "+id)
		query.transform = Transform3D(Basis.IDENTITY,actor.position+Vector3.UP*1.02)
		var obstacles := space.intersect_shape(query,3)
		_check(obstacles.is_empty(),"Resident is outside walls and furniture: %s at %s, %s" % [id,actor.position,_hit_names(obstacles)])
		for previous: Vector3 in positions:
			_check(actor.position.distance_to(previous)>.59,"Economic residents have distinct personal spaces")
		positions.append(actor.position)
		_check(actor.collision_layer == Layout.CITIZEN_LAYER,"Living resident blocks player movement: "+id)
	for id: String in ["antonia","sextus","quintus"]:
		var at: Vector3 = world.village_life_world.actor_position(id)
		_check(world.village_life_world.nearest(at) == id,"Childhood family and smith can be reached through the live interaction lookup: "+id)
	for id: String in ["family_water","family_rest","bellows","anvil","quench","patrol_inner","patrol_road","patrol_gate"]:
		var point: Vector2 = Childhood.POINTS[id]
		var height := Layout.HOUSE_FLOOR if id.begins_with("family_") else 0.0
		query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,height+1.02,point.y))
		_check(space.intersect_shape(query,1).is_empty(),"The actual action standing space is unobstructed: "+id)
	# Explore all allowed workplace slots, not just today's initial allocation.
	for workplace: String in Economy.WORKPLACES:
		var fixture: Dictionary = model.data.duplicate(true)
		fixture.village.erase("childhood")
		for person: Dictionary in fixture.village.economy.people:
			person.assignment = "idle"
		for index in int(Economy.WORKPLACES[workplace].required):
			var person: Dictionary = fixture.village.economy.people[index]
			person.assignment = workplace
			var point := Life.actor_position(fixture,person.id)
			query.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,1.02,point.y))
			var obstacles := space.intersect_shape(query,3)
			_check(obstacles.is_empty(),"Work slot clears scenery and palisades: %s/%d at %s, %s" % [workplace,index,point,_hit_names(obstacles)])
	# This is the production Player, Figure and physics setup. No global height
	# adjustment is applied: gravity must settle the capsule on the real floor.
	var player: CharacterBody3D = world.get_node("Player")
	player.position = Vector3(-12,1.35,11.7)
	player.velocity = Vector3.ZERO
	for frame in 35:
		await physics_frame
		world._move_player(1.0/60.0)
	_check(absf(player.position.y-.9-Layout.HOUSE_FLOOR)<.025,"The production boy's foot origin rests on the raised family floor")
	_check((player.collision_mask & Layout.CITIZEN_LAYER) != 0,"The production player observes citizen collisions")
	var mother: Node3D = world.village_life_world.actors.antonia
	player.position = mother.position+Vector3(-1.5,.9,0)
	await physics_frame
	player.move_and_collide(Vector3(3,0,0))
	_check(player.position.x<mother.position.x-.54,"The production player cannot pass through his mother")
	# Explicit fixture placement checks the existing player-built hut using its
	# real imported shell and the production completed-building colliders.
	var hut: Node3D = world._create_building_view("GeometryProbeHut")
	hut.position = Vector3(52,0,6)
	hut.get_node("Scaffold").hide()
	world._add_finished_hut_collision(hut)
	player.position = hut.position+Vector3(0,1,3.5)
	player.velocity = Vector3.ZERO
	await physics_frame
	for frame in 160:
		await physics_frame
		player.velocity = Vector3(0,-.3 if player.is_on_floor() else player.velocity.y-19.6/60.0,-1.5)
		player.move_and_slide()
		if hut.to_local(player.global_position).z < .7:
			break
	_check(hut.to_local(player.global_position).z<.8,"The production capsule enters a completed buildable hut")
	for frame in 18:
		await physics_frame
		player.velocity = Vector3(0,-.3 if player.is_on_floor() else player.velocity.y-19.6/60.0,0)
		player.move_and_slide()
	_check(absf(player.position.y-.9-.14)<.025,"The buildable hut also supports feet on its visible threshold floor")
	world.free()
	await process_frame
	print("VILLAGE_COLLISION_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures:
		printerr("FAIL: "+failure)
	print("VILLAGE_COLLISION_PASS" if failures.is_empty() else "VILLAGE_COLLISION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _hit_names(hits: Array) -> String:
	var names: Array[String] = []
	for hit: Dictionary in hits:
		names.append(str(hit.collider.get_path()))
	return ", ".join(names)
