extends SceneTree
## Boots the actual campaign market. The player is placed for interception;
## soldiers move via Godot physics. The pressure, approach and answer buttons
## are exercised in their original controller rather than injecting UI results.
const World = preload("res://scripts/domain/world_model.gd")
const City = preload("res://scripts/world/city_exploration.gd")
const Watch = preload("res://scripts/domain/city_watch.gd")
const Registry = preload("res://scripts/domain/person_registry.gd")
var checks := 0
var failures: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			capture_dir = value.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			RenderingServer.render_loop_enabled = false
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960,576)
	root.content_scale_size = Vector2i.ZERO
	var world := World.new()
	world.new_game("italia",true,true)
	await _visit(world)
	var adult := World.new()
	adult.new_game("italia",true,false)
	if check(adult.pass_calendar_days(2195,"Erwachsenenprüfung","wait").ok and adult.data.player.age == 18,"Age on the campaign clock"):
		await _visit(adult)
	_adult_contact()
	print("CITY_WATCH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _visit(world: World) -> void:
	var visit := City.new()
	visit.profile = "balanced"
	visit.campaign = world
	visit.campaign_path = "user://watch_%d.json" % Time.get_ticks_usec()
	root.add_child(visit)
	for i in 3:
		await physics_frame
	if check(is_instance_valid(visit.street_watch),"The ordinary campaign visit installs the patrol"):
		await _walk_and_reply(visit,world)
	visit.free()
	check(not world.city_watch_observation.is_valid(),"Leaving releases the trusted observation adapter")
	check(not world.execute("city_watch_reply",{"choice":"argue"}).ok,"No village remote conversation")

func _walk_and_reply(visit: City, world: World) -> void:
	var patrol = visit.street_watch
	var adult := int(world.data.player.age) >= 18
	check(patrol.records.size() == 6 and patrol.bodies.size() == 6,"Six different army identities and six visible bodies")
	var identities := {}
	for body: CharacterBody3D in patrol.bodies:
		identities[body.get_meta("actor_uid")] = body.get_meta("display_name")
	check(identities.size() == 6 and identities.has(Watch.LEADER),"Every roster reference is unique")
	var leader: CharacterBody3D = patrol.bodies[0]
	var start := leader.position
	var sample_started := Time.get_ticks_usec()
	var max_step := 0.0
	var previous := start
	for i in 75:
		await physics_frame
		max_step = maxf(max_step,leader.position.distance_to(previous))
		previous = leader.position
	check(start.distance_to(leader.position)>1.2 and max_step < .15,"The unit advances in physical steps on the road")
	var travel := start.distance_to(leader.position)
	var sample_msec := (Time.get_ticks_usec()-sample_started)/1000.0
	var camera := visit.camera
	if not capture_dir.is_empty() and not adult:
		var centre := Vector3.UP*1.0
		for body: CharacterBody3D in patrol.bodies:
			centre += body.position / patrol.bodies.size()
		camera.global_position = centre + patrol._heading*4.4 + patrol._heading.cross(Vector3.UP)*4.7 + Vector3.UP*1.45
		camera.look_at(centre)
		await _capture(visit,"marktwache-marsch")
	check(not world.execute("city_watch_reply",{"choice":"argue"}).ok,"Passing residents incur no dispute")
	# Move the fixture player into the formation's lane. Repeated interference
	# sustains pressure; the commander has to leave formation to come closer.
	var warned := false
	var approached := false
	var approach_start := Vector3.ZERO
	var followed_frames := 0
	for i in 550:
		if patrol.phase == "march":
			var front: Vector3 = leader.position + patrol._heading*.85
			if not adult and patrol._warned:
				front = leader.position - patrol._heading * 4.05
				var stick: Vector3 = patrol._heading.rotated(Vector3.UP,-visit._yaw)
				visit._touch_move = Vector2(stick.x,stick.z)
				followed_frames += 1
			visit.player.global_position = Vector3(front.x,leader.position.y+visit.SOLE_OFFSET,front.z)
		elif patrol.phase == "approach" and not approached:
			approached = true
			visit._touch_move = Vector2.ZERO
			visit.player.velocity = Vector3.ZERO
			approach_start = leader.position
			var side: Vector3 = patrol._heading.cross(Vector3.UP)
			visit.player.global_position = leader.position + side*3.2 + Vector3.UP*visit.SOLE_OFFSET
		elif patrol.phase == "talk":
			break
		await physics_frame
		warned = warned or patrol._warned
	var approached_metres := approach_start.distance_to(leader.position)
	check(warned,"First obstruction produces a warning")
	if not adult:
		check(followed_frames >= 120,"Child fixture continues walking behind the warned column")
	if not check(approached and patrol.phase == "talk","Continued obstruction halts the column and opens the encounter"):
		return
	check(approach_start.distance_to(leader.position) > .8 and patrol._gap(leader)<1.9,"The commander walks up to the player")
	check(patrol._panel.is_visible_in_tree() and patrol._answer.text == "Widersprechen","Player chooses how to answer")
	patrol._answer.pressed.emit()
	check(patrol.phase == "dispute" and Watch.reputation(world.data) == -2,"An argument changes local standing exactly once")
	if not adult:
		check(not world.execute("city_watch_reply",{"choice":"resist"}).ok and not patrol._answer.visible,"A child can argue and withdraw safely")
	if not capture_dir.is_empty() and not adult:
		_frame_pair(visit,leader,patrol._heading)
		await _capture(visit,"marktwache-streit")
	if adult:
		var health: int = world.data.player.health
		patrol._answer.pressed.emit()
		check(patrol.phase == "scuffle" and world.data.player.health == health,"Adult choice starts an actual contact animation")
		for i in 60:
			await physics_frame
			if i == 8 and not capture_dir.is_empty():
				_frame_pair(visit,leader,patrol._heading)
				await _capture(visit,"marktwache-handgemenge")
			if patrol.phase != "scuffle":
				break
		check(world.data.player.health == health-3 and world.data.world_state.politics.street_watch.answer == "pushed","Animation reaches the adult and books one nonlethal contact")
	else:
		patrol._yield.pressed.emit()
	check(patrol.phase == "regroup" and Watch.reputation(world.data) == -2,"De-escalation ends the encounter")
	visit.player.position += Vector3(0,0,5)
	for i in 240:
		await physics_frame
		if patrol.phase == "march":
			break
	check(patrol.phase == "march","Commander rejoins before the column resumes")
	check(visit.save_state()==OK,"Watch record and original city checkpoint save together")
	var restored := World.new()
	var loaded := restored.load_game(visit.campaign_path)
	check(loaded.ok and Watch.reputation(restored.data) == -2,"Local standing persists after reload")
	if loaded.ok:
		check(Registry.collect(restored.data).people[Watch.LEADER].name == identities[Watch.LEADER],"The same named commander resolves after reload")
	print("CITY_WATCH_MOTION ",JSON.stringify({"age":world.data.player.age,"bodies":patrol.bodies.size(),"75_physics_frames_wall_ms":sample_msec,"march_m":travel,"largest_step_m":max_step,"approach_m":approached_metres,"circuit_m":patrol.circuit}))

func _adult_contact() -> void:
	# Exercise the damage/contact contract on a mature actor at the domain
	# boundary. Full adult career prerequisites belong to the military suite.
	var world := World.new()
	world.new_game("italia",true,false)
	var state: Dictionary = world.data.duplicate(true)
	state.player.age = 23
	var observed := {"world_id":state.world_id,"commander":Watch.LEADER,"day":int(state.calendar.clock.jdn),"phase":"talk","distance":1.22,"clear":true,"pressure":4.1,"guard":false,"contact_time":0.0}
	check(Watch.apply(state,"city_watch_reply",{"choice":"argue"},observed).ok,"Adult may object")
	observed.phase = "dispute"
	check(Watch.apply(state,"city_watch_reply",{"choice":"resist"},observed).ok,"Adult explicitly enters the scuffle")
	observed.phase = "scuffle"
	check(not Watch.apply(state,"city_watch_contact",{},observed).ok and state.player.health == 100,"No damage during windup")
	observed.contact_time = .26
	var blocked: Dictionary = state.duplicate(true)
	observed.guard = true
	check(Watch.apply(blocked,"city_watch_contact",{},observed).ok and blocked.player.health == 100,"Guard avoids the physical consequence")
	observed.guard = false
	check(Watch.apply(state,"city_watch_contact",{},observed).ok and state.player.health == 97 and state.village.health_delta == -3,"Contact arrives inside the animation window and balances health")
	check(not Watch.apply(state,"city_watch_contact",{},observed).ok and state.player.health == 97,"No repeated hit or extra record")
	observed.phase = "talk"
	check(not Watch.apply(state,"city_watch_reply",{"choice":"argue"},observed).ok and Watch.reputation(state) == -2,"One incident per day")

func check(ok: bool,message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: "+message)
	return ok

func _frame_pair(visit: City, leader: CharacterBody3D, heading: Vector3) -> void:
	var feet := visit.player.position - Vector3.UP*visit.SOLE_OFFSET
	var centre := (leader.position+feet)*.5 + Vector3.UP
	var axis := (feet-leader.position).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	if side.dot(heading) < 0:
		side = -side
	visit.camera.position = centre + (side+.25*axis).normalized()*3.6 + Vector3.UP*.35
	visit.camera.look_at(centre)

func _capture(visit: City, label: String) -> void:
	# Freeze the live scene and render its current pose from the selected
	# observation point. Allow delayed renderer updates before reading pixels.
	var view := Camera3D.new()
	root.add_child(view)
	view.global_transform = visit.camera.global_transform
	view.fov = visit.camera.fov
	view.environment = visit.camera.environment
	view.attributes = visit.camera.attributes
	view.make_current()
	visit.set_physics_process(false)
	visit.set_process(false)
	visit._hud.visible = label != "marktwache-marsch"
	RenderingServer.render_loop_enabled = true
	for frame in 2:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_webp(capture_dir.path_join(label+".webp"),true,.9)==OK,"Rendered "+label)
	RenderingServer.render_loop_enabled = false
	visit._hud.show()
	visit.set_physics_process(true)
	visit.set_process(true)
	visit.camera.make_current()
	view.free()
