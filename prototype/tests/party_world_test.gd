extends "res://tests/companion_follow_test.gd"
## Reuse the regular I-01/I-03 playthrough. Player positions at conversations
## and pickups are fixture placement; companion displacement is engine physics.
## LEGIO_CAPTURE_DIR optionally saves a real viewport on a display-capable run.

const Party = preload("res://scripts/domain/travel_party.gd")
const DT := 1.0 / 60.0
var party_world: Node3D
var journey := {}


func _run() -> void:
	if not OS.get_environment("LEGIO_CAPTURE_DIR").is_empty():
		RenderingServer.render_loop_enabled = false
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	if _reach(model, "collect_kindling"):
		await _wood_run(model)
	if is_instance_valid(party_world):
		party_world.queue_free()
		await process_frame
	print("PARTY_WORLD_METRICS " + JSON.stringify(journey))
	print("PARTY_WORLD_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _wood_run(model: Model) -> void:
	party_world = World.new()
	root.add_child(party_world)
	party_world.setup(model.data)
	party_world.set_active(true)
	party_world.set_physics_process(false)
	model.npc_observations = party_world.npc_observations
	await physics_frame
	var walker = party_world._story_companions
	var marcus: CharacterBody3D = walker.actor("marcus")
	var father: CharacterBody3D = walker.actor("silvanus")
	var bodies := {Party.FRIEND:marcus, Party.FATHER:father}
	for uid: String in bodies:
		var body: CharacterBody3D = bodies[uid]
		_place(model, body.global_position + Vector3(1.2, 1.0, 0.0))
		if not _command(model, "party_invite", {"actor_uid":uid}):
			return
		_check(body.get_meta("actor_uid") == uid, "The original body retains its canonical UID " + uid)
	var destination: Vector2 = Childhood.POINTS.wood_bundle
	_place(model, Vector3(destination.x + 0.7, 1.0, destination.y + 0.5))
	if not _command(model, "party_assign", {"actor_uid":Party.FRIEND,"assignment":"guide"}) or not _command(model, "party_order", {"actor_uid":Party.FATHER,"order":"wait"}):
		return
	var initial_marcus := marcus.global_position
	var initial_father := father.global_position
	for frame in 600:
		await physics_frame
		walker.advance(DT)
		if initial_marcus.distance_to(marcus.global_position) > 1.0:
			break
	_check(initial_marcus.distance_to(marcus.global_position) > 0.5, "The guide starts walking to the task")
	_check(initial_father.distance_to(father.global_position) < 0.001, "An individual waiting request holds Silvanus at his actual location")
	if not _command(model, "party_assign", {"actor_uid":Party.FATHER,"assignment":"carry"}):
		return
	var site := Vector3(destination.x, 0, destination.y)
	if not await _arrive(site, bodies, "woodcamp"):
		return
	await _capture_group(site, "i04-holzlager")
	var before: Dictionary = model.data.resources.duplicate()
	if not _command(model, "village_childhood_action", {"action_id":"collect_kindling"}):
		return
	var members: Dictionary = model.data.world_state.party.members
	_check(int(members[Party.FRIEND].skills.get("navigation", 0)) == 1 and int(members[Party.FATHER].skills.get("endurance", 0)) == 1, "Two present helpers gain the skills of their actual assignments")
	_check(before == model.data.resources and model.data.village.childhood.carried.count("kindling_bundle") == 1, "Exactly one mission bundle is picked up without creating ordinary goods")
	_check(not model.execute("village_childhood_action", {"action_id":"collect_kindling"}).ok, "A duplicate pickup gives no experience")
	var path := "user://party_world_%d.json" % Time.get_ticks_usec()
	if not _check(model.save_game(path).ok, "Save both helpers at the woodcamp"):
		return
	var loaded := Model.new()
	if not _check(loaded.load_game(path).ok, "Load the shared mission and both humans"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	party_world.setup(loaded.data)
	party_world.set_active(true)
	loaded.npc_observations = party_world.npc_observations
	_check(marcus == walker.actor("marcus") and father == walker.actor("silvanus") and _flat_gap(marcus.global_position, site) < 3.5 and _flat_gap(father.global_position, site) < 3.5, "Save/load restores the same existing bodies at their observed locations")
	_check(loaded.data.world_state.party.members == members, "The individual assignments, memories and skill gains round-trip")
	if not _command(loaded, "party_dismiss", {"actor_uid":Party.FATHER}):
		return
	var craft_site: Vector2 = Life.actor_position(loaded.data, "sextus")
	var forge := Vector3(craft_site.x, 0.0, craft_site.y)
	_place(loaded, forge + Vector3(0.7, 1.0, 0.8))
	if not await _arrive(forge, {Party.FRIEND:marcus}, "forge"):
		return
	if not Life.relationship(loaded.data,"sextus").met:
		if not _command(loaded, "village_talk", {"npc_id":"sextus","choice":"meet"}):
			return
	if not _command(loaded, "village_childhood_action", {"action_id":"deliver_kindling"}):
		return
	members = loaded.data.world_state.party.members
	_check(int(members[Party.FRIEND].skills.navigation) == 2 and int(members[Party.FATHER].skills.endurance) == 1, "The task finishes when the carrier leaves; only its remaining guide gains the delivery memory")
	_check(not loaded.data.village.childhood.carried.has("kindling_bundle") and Childhood.current_step(loaded.data).id == "i04_work", "Sextus receives the bundle and opens the existing workshop visit")


func _command(model: Model, command: String, args: Dictionary) -> bool:
	var result: Dictionary = model.execute(command, args)
	if not _check(result.ok, "%s %s: %s" % [command, str(args), str(result.message)]):
		return false
	party_world.sync_state(model.data)
	return true


func _place(model: Model, point: Vector3) -> void:
	party_world.get_node("Player").global_position = point
	model.set_player_position(point)


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()


func _arrive(site: Vector3, bodies: Dictionary, label: String) -> bool:
	var walker = party_world._story_companions
	var previous := {}
	var travelled := {}
	for uid: String in bodies:
		previous[uid] = bodies[uid].global_position
		travelled[uid] = 0.0
	var largest_step := 0.0
	for frame in 4800:
		await physics_frame
		walker.advance(DT)
		var ready := true
		for uid: String in bodies:
			var at: Vector3 = bodies[uid].global_position
			var moved: float = _flat_gap(previous[uid], at)
			travelled[uid] += moved
			largest_step = maxf(largest_step, moved)
			previous[uid] = at
			ready = ready and _flat_gap(at, site) <= 3.0
		if ready:
			journey[label] = {"ticks":frame+1, "walked_metres":travelled, "maximum_step_m":largest_step}
			return _check(largest_step < 0.13, "The party walks to " + label + " without position jumps")
	return _check(false, "Helpers reach %s at %s (actual %s)" % [label, site, previous])


func _capture_group(site: Vector3, filename: String) -> void:
	var folder := OS.get_environment("LEGIO_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var camera := Camera3D.new()
	party_world.add_child(camera)
	camera.global_position = site + Vector3(3.0, 3.7, 6.5)
	camera.look_at(site + Vector3(0, 1.05, 0))
	camera.make_current()
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.save_png(folder.path_join(filename + ".png")) == OK, "Write the actual I-04 viewport")
	RenderingServer.render_loop_enabled = false
	camera.queue_free()
