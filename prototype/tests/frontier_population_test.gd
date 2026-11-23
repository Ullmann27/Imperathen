extends SceneTree
## Actual scene, safe walking corridors, dialogue framing, time and recruitment checks.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var model := Model.new()
	model.new_game("italia")
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	await physics_frame
	await physics_frame
	require(world.regional.house_count == 13,"Italian quarter contains thirteen real residential instances")
	require(world.population.actors.size() == 18,"Eighteen unique resident nodes are present")
	var identities := {}
	var appearances := {}
	for person: Dictionary in Layout.RESIDENTS:
		require(not identities.has(person.id),"Resident identity must be unique: "+person.id)
		identities[person.id] = true
		appearances[person.appearance] = true
		require(not world.get_frontier_npc_info(person.id).is_empty(),"Resident is discoverable: "+person.id)
	require(appearances.size() >= 5,"Civilian, female, older, soldier and officer appearance roles exist")
	for home: Dictionary in Layout.HOMES:
		require(not Layout.house_footprint(home,.4).intersects(Rect2(4.7,-4.3,19.6,17.6)),"New home leaves the player's building land free: "+home.id)
		require(world.regional.has_node(NodePath(home.id)),"House definition resolves to live geometry: "+home.id)
	# Probe the real collision world, rather than only comparing authored rectangles.
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.70
	query.shape = capsule
	query.collision_mask = 1
	query.margin = .015
	var space := world.get_world_3d().direct_space_state
	for person: Dictionary in Layout.RESIDENTS:
		var path: Array[Vector3] = [person.at]
		for waypoint: Vector3 in person.route:
			path.append(waypoint)
		for edge in maxi(1,path.size()-1):
			var start := path[edge]
			var finish := path[mini(edge+1,path.size()-1)]
			var steps := maxi(1,ceili(start.distance_to(finish)/.45))
			for step in steps+1:
				var point := start.lerp(finish,float(step)/steps)
				query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*1.02)
				var blocked := not space.intersect_shape(query,1).is_empty()
				require(not blocked,"Resident route collides: %s at %s" % [person.id,point])
	world.set_frontier_time(37.25)
	var before: Array = world.population.snapshot()
	for profile in ["low","balanced","high","very_high"]:
		world.set_quality(profile)
		require(world.population.snapshot() == before,"Quality preserves people and positions: "+profile)
	world.set_active(false)
	world.set_frontier_time(238.0)
	require(world.population.snapshot() == before,"Pause does not advance resident routines")
	world.set_active(true)
	world.set_frontier_time(91.2)
	require(world.population.snapshot() != before,"At least one resident moves when world time advances")
	world.set_frontier_time(37.25)
	require(world.population.snapshot() == before,"Resident positions reproduce from saved world time")
	var actions: Array[Dictionary] = []
	world.action_requested.connect(func(action: String,payload: Dictionary): actions.append({"action":action,"payload":payload}))
	for id in ["livia","cassian","aulus","titus"]:
		var at: Vector3 = world.get_frontier_npc_position(id)
		world.get_node("Player").position = at+Vector3(0,1.02,2.2)
		world.get_node("Player").velocity = Vector3.ZERO
		actions.clear()
		world.perform_interaction()
		require(actions.size() == 1 and actions[0].action == "frontier_talk" and actions[0].payload.npc_id == id,"Walking up reaches the intended story person: "+id)
		require(world.focus_frontier_npc(id),"Conversation camera can focus "+id)
		world.set_active(false)
		world._update_camera(1.0)
		var screen: Vector2 = world._camera.unproject_position(at+Vector3.UP*1.48)
		require(screen.x < root.size.x*.5,"Speaker remains left of the dialogue panel: %s (x=%.1f, width=%d)" % [id,screen.x,root.size.x])
		require(world._camera.global_position.distance_to(at+Vector3.UP*1.48) > .7,"Conversation camera avoids an extreme face clipping position: "+id)
		world.clear_frontier_focus()
		world.set_active(true)
	var recruited: Dictionary = model.data.duplicate(true)
	recruited.squad.recruits = 1
	recruited.squad.alive = 1
	world.sync_state(recruited)
	require(not world.population.actors.marius.visible,"A recruited worker no longer appears twice as a civilian")
	require(world.population.actors.marcellus.visible,"Unrecruited worker remains in village")
	require(world.get_node("Squad").get_child_count() == 1,"The same recruitment creates the combat follower")
	model.new_game("han")
	world.setup(model.data)
	require(world.population.actors.is_empty(),"Roman residents do not overwrite another origin")
	require(world.regional.house_count == 4,"The other origin retains its established housing")
	require(not world.focus_frontier_npc("livia"),"Unknown regional speaker cannot open a camera")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("FRONTIER_POPULATION_OK: %d checks" % checks)
		quit(0)
	else:
		print("FRONTIER_POPULATION_FAILED: %d of %d checks" % [failures.size(),checks])
		quit(1)
